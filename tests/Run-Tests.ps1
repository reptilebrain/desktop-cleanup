#requires -Version 5.1
# No modules required. Run each script in a child of the current PowerShell engine.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$engine = (Get-Process -Id $PID).Path
$root = Join-Path ([IO.Path]::GetTempPath()) ('desktop-cleanup-tests-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($root)
$script:passed = 0
$script:failed = 0

function Assert-True($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function New-Fixture {
    $dir = Join-Path $root ([guid]::NewGuid().ToString('N'))
    $f = @{ Root = $dir; Desktop = "$dir\inbox-desktop"; MyDocuments = "$dir\inbox-documents";
        Destination = "$dir\vault"; LocalApplicationData = "$dir\local-data";
        CommonDesktopDirectory = "$dir\public-desktop" }
    foreach ($key in @('Desktop', 'MyDocuments', 'CommonDesktopDirectory')) {
        [void][IO.Directory]::CreateDirectory($f[$key])
    }
    return $f
}

function New-File([string]$Path, [int]$Seed = 1, [int]$CreatedMinutes = 120, [int]$ModifiedMinutes = 120) {
    [void][IO.Directory]::CreateDirectory((Split-Path $Path -Parent))
    [IO.File]::WriteAllBytes($Path, [byte[]](0, 255, 13, 10, $Seed, 128, 0))
    [IO.File]::SetCreationTimeUtc($Path, [DateTime]::UtcNow.AddMinutes(-$CreatedMinutes))
    [IO.File]::SetLastWriteTimeUtc($Path, [DateTime]::UtcNow.AddMinutes(-$ModifiedMinutes))
}

function Snapshot($Fixture) {
    # Include directories, file bytes and write times, but not access times.
    return (@(Get-ChildItem -LiteralPath $Fixture.Root -Recurse -Force | Sort-Object FullName | ForEach-Object {
        if ($_.PSIsContainer) { 'D|' + $_.FullName }
        else { 'F|' + $_.FullName + '|' + (Get-FileHash -LiteralPath $_.FullName).Hash + '|' + $_.LastWriteTimeUtc.Ticks }
    }) -join "`n")
}

function Invoke-Isolated([string]$Name, $Fixture, [string[]]$Arguments = @(), [int]$ExpectedExit = 0) {
    $source = Get-Content -LiteralPath (Join-Path $repo $Name) -Raw
    $tokens = $null; $parseErrors = $null
    $ast = [Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$parseErrors)
    Assert-True ($parseErrors.Count -eq 0) "Syntax errors in $Name"
    $edits = @()
    # Replace configuration assignments by AST extent, not arbitrary script logic.
    $assignments = @($ast.FindAll({ param($n)
        $n -is [Management.Automation.Language.AssignmentStatementAst] -and
        $n.Left -is [Management.Automation.Language.VariableExpressionAst] -and
        $n.Left.VariablePath.UserPath -eq 'dest' -and
        ($n.Right.Extent.Text -match '^\[Environment\]::GetFolderPath\(' -or
         $n.Right.Extent.Text -match '^[''"]')
    }, $true))
    foreach ($assignment in $assignments) {
        $edits += @{ Start = $assignment.Right.Extent.StartOffset; End = $assignment.Right.Extent.EndOffset;
            Text = "'" + $Fixture.Destination.Replace("'", "''") + "'" }
    }
    $calls = @($ast.FindAll({ param($n)
        $n -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
        $n.Expression.Extent.Text -eq '[Environment]' -and $n.Member.Value -eq 'GetFolderPath'
    }, $true))
    foreach ($call in $calls) {
        if (@($edits | Where-Object { $call.Extent.StartOffset -ge $_.Start -and $call.Extent.EndOffset -le $_.End }).Count) { continue }
        $key = $call.Arguments[0].Value
        Assert-True ($Fixture.ContainsKey($key)) "Unmapped Windows folder: $key"
        $edits += @{ Start = $call.Extent.StartOffset; End = $call.Extent.EndOffset;
            Text = "'" + $Fixture[$key].Replace("'", "''") + "'" }
    }
    foreach ($edit in ($edits | Sort-Object { $_.Start } -Descending)) {
        $source = $source.Substring(0, $edit.Start) + $edit.Text + $source.Substring($edit.End)
    }
    Assert-True ($source -notmatch '::GetFolderPath\s*\(') 'Refusing to execute an unresolved Windows folder lookup'
    Assert-True ($source -notmatch "(?m)^\s*\`$dest\s*=\s*'D:") 'Refusing a real configured destination'
    # Shortcut tests only preview; never call the real Recycle Bin API.
    if ($Name -eq 'Remove-DesktopShortcuts.ps1') {
        Assert-True ($Arguments -contains '-DryRun') 'Shortcut tests must use DryRun'
    }
    $copy = Join-Path $root ([guid]::NewGuid().ToString('N') + '.ps1')
    [IO.File]::WriteAllText($copy, $source)
    $output = & $engine -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $copy @Arguments 2>&1
    $code = $LASTEXITCODE
    Assert-True ($code -eq $ExpectedExit) "Expected exit $ExpectedExit, got $code in ${Name}: $output"
    return ($output -join "`n")
}

function Test-Case([string]$CaseLabel, [scriptblock]$Body) {
    try { & $Body; $script:passed++; Write-Host "PASS $CaseLabel" }
    catch { $script:failed++; Write-Host "FAIL ${CaseLabel}: $_" -ForegroundColor Red }
}

try {
    Write-Host "Testing with PowerShell $($PSVersionTable.PSVersion)"
    foreach ($spec in @(@('Move-Audio.ps1', '.wav'), @('Move-Images.ps1', '.png'), @('Move-Video.ps1', '.mp4'))) {
        $name = $spec[0]; $ext = $spec[1]
        Test-Case "$name dry run has no side effects and reserves duplicate names" {
            $f = New-Fixture
            New-File "$($f.Desktop)\same$ext"
            New-File "$($f.MyDocuments)\same$ext" 2
            $before = Snapshot $f
            $out = Invoke-Isolated $name $f @('-DryRun')
            Assert-True ($before -ceq (Snapshot $f)) 'Dry run changed the fixture'
            Assert-True ($out -match 'Planned \(DryRun\): 2') 'Expected two planned moves'
            $targets = @($out -split "`n" | Where-Object { $_ -match '\[DRYRUN\]' } | ForEach-Object { ($_ -split ' -> ')[1] })
            Assert-True (($targets | Select-Object -Unique).Count -eq 2) 'Dry run reused a target'
        }
        Test-Case "$name import preserves content and resolves existing/source conflicts" {
            $f = New-Fixture
            New-File "$($f.Desktop)\same$ext" 1
            New-File "$($f.MyDocuments)\same$ext" 2
            New-File "$($f.Destination)\same$ext" 3
            $original = (Get-FileHash -LiteralPath "$($f.Destination)\same$ext").Hash
            $expected = @(Get-ChildItem -LiteralPath $f.Root -Recurse -File | Get-FileHash | Select-Object -ExpandProperty Hash | Sort-Object)
            $null = Invoke-Isolated $name $f
            $actual = @(Get-ChildItem -LiteralPath $f.Destination -File | Get-FileHash | Select-Object -ExpandProperty Hash | Sort-Object)
            Assert-True (($actual -join ',') -ceq ($expected -join ',')) 'Imported bytes or file count changed'
            Assert-True ((Get-FileHash -LiteralPath "$($f.Destination)\same$ext").Hash -ceq $original) 'Existing target overwritten'
            Assert-True (@(Get-ChildItem $f.Desktop,$f.MyDocuments -File).Count -eq 0) 'Sources not moved'
        }
        Test-Case "$name age checks creation and modification; zero disables limit" {
            $f = New-Fixture
            New-File "$($f.Desktop)\old$ext"
            New-File "$($f.Desktop)\new-creation$ext" 2 0 120
            New-File "$($f.Desktop)\new-write$ext" 3 120 0
            $out = Invoke-Isolated $name $f
            Assert-True ($out -match 'Moved: 1.*Skipped: 2') 'Age filter did not check both timestamps'
            Assert-True (Test-Path "$($f.Destination)\old$ext") 'Old file not imported'
            $out = Invoke-Isolated $name $f @('-MinAgeMinutes', '0')
            Assert-True ($out -match 'Moved: 2.*Skipped: 0') 'Zero did not disable age check'
        }
        Test-Case "$name ignores subfolders and unsupported formats; includes hidden files" {
            $f = New-Fixture
            New-File "$($f.Desktop)\nested\leave$ext"
            New-File "$($f.Desktop)\leave.xmp"
            New-File "$($f.Desktop)\hidden$ext"
            (Get-Item "$($f.Desktop)\hidden$ext").Attributes = [IO.FileAttributes]::Hidden
            $out = Invoke-Isolated $name $f
            Assert-True ($out -match 'Moved: 1') 'Hidden file not processed'
            Assert-True (Test-Path "$($f.Desktop)\nested\leave$ext") 'Nested file moved'
            Assert-True (Test-Path "$($f.Desktop)\leave.xmp") 'Unsupported file moved'
        }
        Test-Case "$name empty inbox does not create vault" {
            $f = New-Fixture
            $null = Invoke-Isolated $name $f
            Assert-True (-not (Test-Path $f.Destination)) 'Empty run created destination'
        }
        Test-Case "$name source equals destination is skipped" {
            $f = New-Fixture; $f.Destination = $f.Desktop
            New-File "$($f.Desktop)\keep$ext"
            $out = Invoke-Isolated $name $f
            Assert-True ($out -match 'Source equals destination') 'Equal paths not detected'
            Assert-True (Test-Path "$($f.Desktop)\keep$ext") 'Equal-path file changed'
        }
        foreach ($bad in @('', 'relative-folder')) {
            Test-Case "$name rejects invalid destination '$bad'" {
                $f = New-Fixture; $f.Destination = $bad
                $before = Snapshot $f
                $out = Invoke-Isolated $name $f @() 1
                Assert-True ($out -match 'empty or invalid folder path') 'Wrong configuration error'
                Assert-True ($before -ceq (Snapshot $f)) 'Invalid configuration changed files'
            }
        }
        Test-Case "$name rejects a file as vault" {
            $f = New-Fixture; New-File $f.Destination
            $before = Snapshot $f
            $out = Invoke-Isolated $name $f @() 1
            Assert-True ($out -match 'destination is not a folder') 'Wrong destination error'
            Assert-True ($before -ceq (Snapshot $f)) 'Invalid vault changed files'
        }
        Test-Case "$name missing inbox fails but processes other inbox" {
            $f = New-Fixture; $f.Desktop = Join-Path $f.Root 'missing-inbox'
            New-File "$($f.MyDocuments)\move$ext"
            $out = Invoke-Isolated $name $f @() 1
            Assert-True ($out -match 'Cannot read folder') 'Missing source not reported'
            Assert-True (Test-Path "$($f.Destination)\move$ext") 'Other inbox not processed'
        }
        Test-Case "$name logging failure prevents import" {
            $f = New-Fixture; New-File $f.LocalApplicationData
            New-File "$($f.Desktop)\keep$ext"
            $before = Snapshot $f
            $null = Invoke-Isolated $name $f @() 1
            Assert-True ($before -ceq (Snapshot $f)) 'Logging failure moved files'
        }
        Test-Case "$name locked file reports failure and preserves bytes" {
            $f = New-Fixture; $path = "$($f.Desktop)\locked$ext"; New-File $path
            $hash = (Get-FileHash $path).Hash
            $handle = [IO.File]::Open($path, 'Open', 'Read', 'None')
            try { $out = Invoke-Isolated $name $f @() 1 }
            finally { $handle.Dispose() }
            Assert-True ($out -match '\[ERROR\]') 'Move failure not reported'
            Assert-True ((Get-FileHash $path).Hash -ceq $hash) 'Locked source changed'
            Assert-True (@(Get-ChildItem $f.Destination -File).Count -eq 0) 'Failed move left a target'
        }
    }
    Test-Case 'shortcut dry run isolates private and public desktops' {
        $f = New-Fixture
        New-File "$($f.Desktop)\private.lnk"
        New-File "$($f.CommonDesktopDirectory)\public.lnk"
        New-File "$($f.Desktop)\nested\leave.lnk"
        New-File "$($f.Desktop)\leave.txt"
        $before = Snapshot $f
        $out = Invoke-Isolated 'Remove-DesktopShortcuts.ps1' $f @('-DryRun')
        Assert-True ($out -match 'Planned \(DryRun\): 1') 'Wrong private shortcut count'
        $out = Invoke-Isolated 'Remove-DesktopShortcuts.ps1' $f @('-DryRun', '-IncludePublicDesktop')
        Assert-True ($out -match 'Planned \(DryRun\): 2') 'Wrong public shortcut count'
        Assert-True ($before -ceq (Snapshot $f)) 'Shortcut preview changed files'
    }
}
finally {
    # Resolve and check the exact generated root before recursive cleanup.
    $resolved = [IO.Path]::GetFullPath($root)
    $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -or
        (Split-Path $resolved -Leaf) -notmatch '^desktop-cleanup-tests-[a-f0-9]{32}$') {
        throw "Refusing cleanup outside the generated test root: $resolved"
    }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
Write-Host "Results: $script:passed passed, $script:failed failed"
if ($script:failed -gt 0) { exit 1 }
exit 0
