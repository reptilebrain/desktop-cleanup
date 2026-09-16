#requires -Version 5.1
<#
.SYNOPSIS
Moves loose video files from Desktop and Documents to a destination folder.
.DESCRIPTION
Only processes files directly in the source folders, including hidden files.
Does not inspect project references: moving video can break links in an editor.

DryRun writes only to the console and does not create folders or logs.
Normal runs write one log per run under:
%LOCALAPPDATA%\DesktopCleanup\Logs

Old logs are not deleted automatically.
Run as your own Windows user, also when using Task Scheduler.
.EXAMPLE
.\Move-Video.ps1 -DryRun
.EXAMPLE
.\Move-Video.ps1 -MinAgeMinutes 120
.EXAMPLE
.\Move-Video.ps1 -DryRun -MinAgeMinutes 0
.NOTES
Exit code 0 = completed without reported errors.
Exit code 1 = one or more errors.

Intended for Windows PowerShell 5.1 and PowerShell 7 on Windows.
#>

[CmdletBinding()]
param(
    [switch]$DryRun,

    # Skip files created or modified within this many minutes.
    # Set to 0 to disable the age check.
    [ValidateRange(0, 5256000)]
    [int]$MinAgeMinutes = 60
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
    param(
        [string]$Level,
        [string]$Message
    )

    $line = '{0} [{1}] {2}' -f (
        Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    ), $Level, $Message

    Write-ConsoleStatus $line

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
    # Only files directly in these folders are processed.
    # Subfolders are not scanned.
    $sources = @(
        [Environment]::GetFolderPath('Desktop'),
        [Environment]::GetFolderPath('MyDocuments')
    )

    # Destination: Windows Videos folder by default.
    # To use another folder, uncomment the second $dest line and change its path.
    # A missing destination folder is created only when a file is moved.
    $dest = [Environment]::GetFolderPath('MyVideos')
    # $dest = 'D:\Video'

    foreach ($path in (@($sources) + @($dest))) {
        if (
            [string]::IsNullOrWhiteSpace($path) -or
            -not [IO.Path]::IsPathRooted($path)
        ) {
            throw 'An empty or invalid folder path was provided.'
        }
    }

    $dest = [IO.Path]::GetFullPath($dest)

    if (Test-Path -LiteralPath $dest) {
        if (-not (Test-Path -LiteralPath $dest -PathType Container)) {
            throw "The destination is not a folder: $dest"
        }
    }

    if (-not $DryRun) {
        $localData = [Environment]::GetFolderPath('LocalApplicationData')

        if ([string]::IsNullOrWhiteSpace($localData)) {
            throw 'LocalApplicationData is unavailable.'
        }

        $logDir = Join-Path $localData 'DesktopCleanup\Logs'
        [void][IO.Directory]::CreateDirectory($logDir)

        $logName = 'video-{0}-{1}.log' -f (
            Get-Date -Format 'yyyyMMdd-HHmmss-fff'
        ), ([guid]::NewGuid().ToString('N'))

        $script:logFile = Join-Path $logDir $logName

        # Verify logging before moving any files.
        Set-Content -LiteralPath $script:logFile -Value 'Video cleanup' -Encoding UTF8
        Write-ConsoleStatus "Log: $script:logFile"
    }

    $exts = @(
        '.mp4', '.mov', '.mkv', '.avi', '.wmv', '.m4v',
        '.webm', '.mts', '.m2ts', '.3gp', '.flv'
    )

    $cutoff = [DateTime]::UtcNow.AddMinutes(-$MinAgeMinutes)

    # Reserve proposed names during DryRun to simulate name conflicts.
    $reserved = @{}

    $moved = 0
    $planned = 0
    $skipped = 0

    Write-Status 'START' "Minimum age: $MinAgeMinutes minutes. Destination: $dest"

    foreach ($src in ($sources | Select-Object -Unique)) {
        if (
            [IO.Path]::GetFullPath($src).TrimEnd('\') -ieq
            $dest.TrimEnd('\')
        ) {
            Write-Status 'SKIP' "Source equals destination: $src"
            continue
        }

        try {
            $files = @(
                Get-ChildItem -LiteralPath $src -File -Force |
                    Sort-Object Name
            )
        }
        catch {
            $script:hadErrors = $true
            Write-Status 'ERROR' "Cannot read folder ${src}: $($_.Exception.Message)"
            continue
        }

        foreach ($file in $files) {
            if ($exts -notcontains $file.Extension) {
                continue
            }

            try {
                $file.Refresh()

                if (-not $file.Exists) {
                    throw "File is no longer available: $($file.FullName)"
                }

                # Creation time also helps protect recently copied files
                # that retain an older modification date.
                if (
                    $MinAgeMinutes -gt 0 -and (
                        $file.LastWriteTimeUtc -gt $cutoff -or
                        $file.CreationTimeUtc -gt $cutoff
                    )
                ) {
                    $skipped++
                    Write-Status 'SKIP' "Too recent: $($file.FullName)"
                    continue
                }

                $target = Join-Path $dest $file.Name
                $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
                $number = 0

                # Check every candidate name, including numbered alternatives.
                while (
                    (Test-Path -LiteralPath $target) -or
                    $reserved.ContainsKey($target)
                ) {
                    $number++

                    $name = '{0} - flytt {1}-{2}{3}' -f (
                        $file.BaseName
                    ), $stamp, $number, $file.Extension

                    $target = Join-Path $dest $name
                }

                if ($DryRun) {
                    $reserved[$target] = $true
                    $planned++
                    Write-Status 'DRYRUN' "$($file.FullName) -> $target"
                }
                else {
                    # Create the destination only when a file is ready to move.
                    [void][IO.Directory]::CreateDirectory($dest)

                    # This overload refuses to overwrite an existing destination,
                    # even if another process creates it after our name check.
                    [IO.File]::Move($file.FullName, $target)

                    if (Test-Path -LiteralPath $file.FullName) {
                        throw "Source still exists after move; inspect both paths. Destination: $target"
                    }

                    $moved++
                    Write-Status 'MOVED' "$($file.FullName) -> $target"
                }
            }
            catch {
                $script:hadErrors = $true
                Write-Status 'ERROR' "$($file.FullName): $($_.Exception.Message)"
            }
        }
    }

    Write-Status 'END' "Moved: $moved. Planned (DryRun): $planned. Skipped: $skipped."
}
catch {
    $script:hadErrors = $true
    Write-Status 'ERROR' $_.Exception.Message
}

if ($script:hadErrors) {
    exit 1
}

exit 0
