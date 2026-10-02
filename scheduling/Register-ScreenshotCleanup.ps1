#requires -Version 5.1
<#
.SYNOPSIS
Installs a standalone screenshot cleanup copy and registers its daily task.
.DESCRIPTION
Run explicitly once; never called by the cleanup script. Does not start cleanup.
An existing task is not overwritten. Run as the Windows user whose screenshots
should be recycled, with that user logged in. No password is stored.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ScreenshotPath,
    [ValidateRange(1, 36500)]
    [int]$KeepDays = 7,
    [ValidatePattern('^(?:[01][0-9]|2[0-3]):[0-5][0-9]$')]
    [string]$At = '03:00'
)
$ErrorActionPreference = 'Stop'
$taskName = 'DesktopCleanup-Screenshots'
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    throw "Task $taskName already exists. Review it before making changes."
}
if ($ScreenshotPath.Contains('"') -or $ScreenshotPath -notmatch '^[A-Za-z]:\\') {
    throw 'Use an absolute local screenshot folder path without quotes.'
}
$folder = Get-Item -LiteralPath $ScreenshotPath -Force
if (-not $folder.PSIsContainer -or $folder.LinkType) { throw 'Use a real screenshot directory.' }
$source = Join-Path (Split-Path $PSScriptRoot -Parent) 'Remove-OldScreenshots.ps1'
$installDir = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'DesktopCleanup\Scripts'
$installed = Join-Path $installDir 'Remove-OldScreenshots.ps1'
if (Test-Path -LiteralPath $installed) { throw "A runtime copy already exists: $installed" }
[void][IO.Directory]::CreateDirectory($installDir)
$staged = Join-Path $installDir ('Remove-OldScreenshots.{0}.tmp.ps1' -f [guid]::NewGuid().ToString('N'))
$installedByThisRun = $false
try {
    # Stage and verify first, so a failed or interrupted copy cannot leave a
    # partial runtime file that blocks a later installation attempt.
    Copy-Item -LiteralPath $source -Destination $staged
    if ((Get-FileHash $source).Hash -ne (Get-FileHash $staged).Hash) { throw 'Runtime copy verification failed.' }
    Move-Item -LiteralPath $staged -Destination $installed
    $installedByThisRun = $true
    $executable = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -ScreenshotPath "{1}" -KeepDays {2}' -f $installed, $folder.FullName, $KeepDays
    $action = New-ScheduledTaskAction -Execute $executable -Argument $arguments -WorkingDirectory $installDir
    $nextRun = [DateTime]::Today.Add([TimeSpan]::Parse($At))
    if ($nextRun -le (Get-Date)) { $nextRun = $nextRun.AddDays(1) }
    $trigger = New-ScheduledTaskTrigger -Daily -At $nextRun
    $principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 1)
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'Recycle PNG screenshots older than seven days; interactive user session required. Retention is set in action arguments.'
}
catch {
    # A failed install must not leave a runtime copy that blocks the next attempt.
    # Existing copies are rejected above and are never removed here.
    if (Test-Path -LiteralPath $staged) {
        Remove-Item -LiteralPath $staged -Force -ErrorAction SilentlyContinue
    }
    if ($installedByThisRun -and (Test-Path -LiteralPath $installed)) {
        Remove-Item -LiteralPath $installed -Force -ErrorAction SilentlyContinue
    }
    throw
}
