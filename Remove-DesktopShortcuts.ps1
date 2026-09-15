#requires -Version 5.1
<#
.SYNOPSIS
Sends desktop shortcuts to the Recycle Bin.
.DESCRIPTION
Only processes .lnk files directly on your Desktop.
Shortcut targets are not deleted. Subfolders are not scanned.

Use -IncludePublicDesktop to also process the shared desktop.
This affects all users and may require administrator permissions.

Add exact shortcut filenames to $keep to preserve selected shortcuts.

DryRun writes only to the console and does not create folders or logs.
Normal runs write one log per run under:
%LOCALAPPDATA%\DesktopCleanup\Logs

Old logs are not deleted automatically.
For Task Scheduler, use your own account and:
"Run only when user is logged on".
Windows may display error dialogs during recycling.
.EXAMPLE
.\Remove-DesktopShortcuts.ps1 -DryRun
.EXAMPLE
.\Remove-DesktopShortcuts.ps1
.EXAMPLE
.\Remove-DesktopShortcuts.ps1 -DryRun -IncludePublicDesktop
.NOTES
Exit code 0 = completed without reported errors.
Exit code 1 = one or more errors.

Intended for Windows PowerShell 5.1 and PowerShell 7 on Windows.
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$IncludePublicDesktop
)

$ErrorActionPreference = 'Stop'
$script:hadErrors = $false
$script:logFile = $null

# Shortcuts to keep: exact filenames including .lnk.
# Matching is case-insensitive and applies to both desktops.
# Uncomment example lines or add your own, one per line.
$keep = @(
    # 'Firefox.lnk'
    # 'REAPER.lnk'
)

function Write-Status {
    param(
        [string]$Level,
        [string]$Message
    )

    $line = '{0} [{1}] {2}' -f (
        Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    ), $Level, $Message

    Write-Host $line

    if ($script:logFile) {
        try {
            Add-Content -LiteralPath $script:logFile -Value $line -Encoding UTF8
        }
        catch {
            $script:hadErrors = $true
            $script:logFile = $null
            Write-Warning "Log writing failed; continuing with console output: $($_.Exception.Message)"
        }
    }
}

try {
    $targets = @(
        [Environment]::GetFolderPath('Desktop')
    )

    if ($IncludePublicDesktop) {
        $targets += [Environment]::GetFolderPath('CommonDesktopDirectory')
    }

    foreach ($folder in $targets) {
        if (
            [string]::IsNullOrWhiteSpace($folder) -or
            -not [IO.Path]::IsPathRooted($folder)
        ) {
            throw 'Windows returned an empty or invalid desktop path.'
        }
    }

    if (-not $DryRun) {
        # Recycling requires an interactive Windows session.
        if (-not [Environment]::UserInteractive) {
            throw 'Run in an interactive session. In Task Scheduler, select "Run only when user is logged on".'
        }

        Add-Type -AssemblyName Microsoft.VisualBasic

        $localData = [Environment]::GetFolderPath('LocalApplicationData')

        if ([string]::IsNullOrWhiteSpace($localData)) {
            throw 'LocalApplicationData is unavailable.'
        }

        $logDir = Join-Path $localData 'DesktopCleanup\Logs'
        [void][IO.Directory]::CreateDirectory($logDir)

        $logName = 'shortcuts-{0}-{1}.log' -f (
            Get-Date -Format 'yyyyMMdd-HHmmss-fff'
        ), ([guid]::NewGuid().ToString('N'))

        $script:logFile = Join-Path $logDir $logName

        # Verify logging before processing any shortcuts.
        Set-Content -LiteralPath $script:logFile -Value 'Desktop shortcut cleanup' -Encoding UTF8
        Write-Host "Log: $script:logFile"
    }

    $recycled = 0
    $planned = 0
    $skipped = 0

    Write-Status 'START' "Include public desktop: $IncludePublicDesktop"

    foreach ($folder in ($targets | Select-Object -Unique)) {
        try {
            $files = @(
                Get-ChildItem -LiteralPath $folder -File -Filter '*.lnk' -Force |
                    Sort-Object Name
            )
        }
        catch {
            $script:hadErrors = $true
            Write-Status 'ERROR' "Cannot read folder ${folder}: $($_.Exception.Message)"
            continue
        }

        foreach ($file in $files) {
            if ($keep -contains $file.Name) {
                $skipped++
                Write-Status 'KEEP' $file.FullName
                continue
            }

            if ($DryRun) {
                $planned++
                Write-Status 'DRYRUN' "$($file.FullName) -> Recycle Bin"
                continue
            }

            try {
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                    $file.FullName,
                    [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                    [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin,
                    [Microsoft.VisualBasic.FileIO.UICancelOption]::ThrowException
                )

                if (Test-Path -LiteralPath $file.FullName) {
                    throw 'Shortcut still exists after the recycle operation.'
                }

                $recycled++
                Write-Status 'RECYCLED' $file.FullName
            }
            catch {
                $script:hadErrors = $true
                Write-Status 'ERROR' "$($file.FullName): $($_.Exception.Message)"
            }
        }
    }

    Write-Status 'END' "Recycled: $recycled. Planned (DryRun): $planned. Kept: $skipped."
}
catch {
    $script:hadErrors = $true
    Write-Status 'ERROR' $_.Exception.Message
}

if ($script:hadErrors) {
    exit 1
}

exit 0