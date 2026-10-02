#requires -Version 5.1
<#
.SYNOPSIS
Recycles PNG screenshots older than seven days.
.DESCRIPTION
Processes only PNG files directly in the specified Screenshots folder.
Both creation and modification time must be older than KeepDays full UTC days.
DryRun creates no folders or logs and recycles nothing.
Scheduling is configured separately; this script never registers tasks.
.EXAMPLE
.\Remove-OldScreenshots.ps1 -DryRun
.EXAMPLE
.\Remove-OldScreenshots.ps1 -ScreenshotPath 'C:\Pictures\Screenshots' -KeepDays 7
.NOTES
Requires an interactive Windows session for recycling. Exit 0 means success;
exit 1 means an error. Recycling in a OneDrive folder also removes the file
from that synced folder on other devices. The Recycle Bin is never emptied.
#>
[CmdletBinding()]
param(
    [string]$ScreenshotPath,
    [ValidateRange(1, 36500)]
    [int]$KeepDays = 7,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$script:hadErrors = $false
$script:logFile = $null

function Write-ConsoleStatus {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification='Display status and dry-run previews without adding pipeline results; PowerShell 5.1+ supports the information stream.')]
    param([string]$Message)
    Write-Host $Message
}

function Write-Status {
    param([string]$Level, [string]$Message)
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-ConsoleStatus $line
    if ($script:logFile) {
        # Stop before further recycling if the audit log becomes unavailable.
        Add-Content -LiteralPath $script:logFile -Value $line -Encoding UTF8
    }
}

function Send-ScreenshotToRecycleBin {
    param([string]$LiteralPath)
    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
        $LiteralPath,
        [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
        [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin,
        [Microsoft.VisualBasic.FileIO.UICancelOption]::ThrowException
    )
}

try {
    if (-not $PSBoundParameters.ContainsKey('ScreenshotPath')) {
        $pictures = [Environment]::GetFolderPath('MyPictures')
        if ([string]::IsNullOrWhiteSpace($pictures)) { throw 'Windows Pictures folder is unavailable.' }
        $ScreenshotPath = Join-Path $pictures 'Screenshots'
    }
    # Require a fully qualified Windows path, not drive-relative or root-relative.
    if ([string]::IsNullOrWhiteSpace($ScreenshotPath) -or
        $ScreenshotPath -notmatch '^(?:[A-Za-z]:[\\/]|\\\\[^\\/]+[\\/][^\\/]+[\\/])') {
        throw 'ScreenshotPath must be a fully qualified Windows folder path.'
    }
    $folder = Get-Item -LiteralPath $ScreenshotPath -Force
    if (-not $folder.PSIsContainer) { throw 'ScreenshotPath is not a folder.' }
    # Explicitly avoid traversing directory junctions/symbolic links. Cloud
    # placeholders alone are not considered symbolic links.
    if ($folder.LinkType) { throw 'ScreenshotPath must not be a symbolic link or junction.' }
    $files = @(Get-ChildItem -LiteralPath $folder.FullName -File -Force | Sort-Object Name)
    $cutoff = [DateTime]::UtcNow.AddDays(-$KeepDays)
    if (-not $DryRun) {
        if (-not [Environment]::UserInteractive) { throw 'Recycling requires a logged-in interactive Windows session.' }
        Add-Type -AssemblyName Microsoft.VisualBasic
        $localData = [Environment]::GetFolderPath('LocalApplicationData')
        if ([string]::IsNullOrWhiteSpace($localData)) { throw 'LocalApplicationData is unavailable.' }
        $logDir = Join-Path $localData 'DesktopCleanup\Logs'
        [void][IO.Directory]::CreateDirectory($logDir)
        $script:logFile = Join-Path $logDir ('screenshots-{0}-{1}.log' -f
            (Get-Date -Format 'yyyyMMdd-HHmmss-fff'), [guid]::NewGuid().ToString('N'))
        Set-Content -LiteralPath $script:logFile -Value 'Screenshot retention' -Encoding UTF8
    }
    $recycled = 0; $planned = 0; $skipped = 0
    Write-Status 'START' "Keep days: $KeepDays. Folder: $($folder.FullName). UTC cutoff: $($cutoff.ToString('o'))"
    foreach ($file in $files) {
        if ($file.Extension -ine '.png') { continue }
        $file.Refresh()
        if (-not $file.Exists) { throw "File disappeared: $($file.FullName)" }
        if ($file.LinkType -or $file.CreationTimeUtc -ge $cutoff -or $file.LastWriteTimeUtc -ge $cutoff) {
            $skipped++
            Write-Status 'SKIP' $file.FullName
            continue
        }
        if ($DryRun) {
            $planned++
            Write-Status 'DRYRUN' "$($file.FullName) -> Recycle Bin"
            continue
        }
        Write-Status 'RECYCLE' $file.FullName
        try {
            Send-ScreenshotToRecycleBin -LiteralPath $file.FullName
            if (Test-Path -LiteralPath $file.FullName) { throw 'File still exists after recycling.' }
            $recycled++
        }
        catch {
            $script:hadErrors = $true
            Write-Status 'ERROR' "$($file.FullName): $($_.Exception.Message)"
            continue
        }
        Write-Status 'RECYCLED' $file.FullName
    }
    Write-Status 'END' "Recycled: $recycled. Planned (DryRun): $planned. Skipped: $skipped."
}
catch {
    $script:hadErrors = $true
    Write-ConsoleStatus "ERROR: $($_.Exception.Message)"
}
if ($script:hadErrors) { exit 1 }
exit 0
