# Screenshot cleanup scheduling

Scheduling is separate from `Remove-OldScreenshots.ps1`. The cleanup script never
creates or edits scheduled tasks. To register a daily task at 03:00 local Windows
time, run as your own Windows account:

```powershell
./scheduling/Register-ScreenshotCleanup.ps1 -ScreenshotPath 'C:\Pictures\Screenshots'
```

Replace the example with your actual screenshots directory. Preview the cleanup
with `-DryRun` before installing. Optional installer parameters: `-KeepDays 7`
and `-At '03:00'`.

The installer copies the cleanup script to
`%LOCALAPPDATA%\DesktopCleanup\Scripts\Remove-OldScreenshots.ps1`, verifies its
SHA-256 hash, and registers `DesktopCleanup-Screenshots`. That stable copy avoids
depending on a Git branch checkout. Repository updates do not automatically
update it; deploy a reviewed copy explicitly when needed. Existing tasks or
runtime copies cause installation to stop rather than being overwritten.

The task uses Windows PowerShell 5.1, the current user, no stored password and
no elevation. It runs only while that user is logged on because the Windows
Recycle Bin API requires an interactive session. Windows may show error dialogs.
Missed starts use StartWhenAvailable; the computer is not woken automatically.
Default Task Scheduler battery restrictions remain in effect. Only one instance
may run at once, with a one-hour execution limit. Registration does not run cleanup.

Inspect the task in Task Scheduler and check Last Run Result and
`%LOCALAPPDATA%\DesktopCleanup\Logs\screenshots-*.log` after execution.
Disable the task to pause it; changing its action arguments changes retention.
Recycling files in OneDrive also removes them from that synced folder on other
devices. The script never empties any Recycle Bin.
