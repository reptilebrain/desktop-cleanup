# Desktop shortcuts and screenshots

## Desktop shortcuts

Preview shortcuts on your own desktop:

```powershell
./Remove-DesktopShortcuts.ps1 -DryRun
```

Remove `-DryRun` to send them to the Recycle Bin. Only `.lnk` files are
processed; the shortcuts' targets are not deleted. Internet shortcuts (`.url`),
folders and special desktop icons such as the Recycle Bin are left alone.

To preserve selected shortcuts, edit `$keep` with exact filenames, including
`.lnk`:

```powershell
$keep = @(
    'Firefox.lnk'
    'REAPER.lnk'
)
```

Matching is case-insensitive and applies to both desktops. An empty list keeps no
`.lnk` shortcuts. Windows may hide the extension in Explorer; use the filenames
shown by `-DryRun`.

The public desktop is excluded unless `-IncludePublicDesktop` is supplied. For a
preview:

```powershell
./Remove-DesktopShortcuts.ps1 -DryRun -IncludePublicDesktop
```

Changes to the public desktop affect every user and may require administrator
permissions. Run this script in a logged-in desktop session; Windows may display
error dialogs while recycling.

## Screenshot retention

`Remove-OldScreenshots.ps1` keeps seven full days of PNG files by default. Both
the creation time and last modification time must be older than the UTC cutoff.
Only files directly in the selected folder are considered. Subfolders, symbolic
links and other file formats are skipped. Every PNG in that folder is in scope,
regardless of its name. A missing folder is an error; the script does not create
it.

Preview the default Pictures/Screenshots folder for the account running the
script:

```powershell
./Remove-OldScreenshots.ps1 -DryRun
```

Use `-ScreenshotPath` to specify a different folder and `-KeepDays` to change
the retention period:

```powershell
./Remove-OldScreenshots.ps1 -ScreenshotPath 'C:\Pictures\Screenshots' -KeepDays 14 -DryRun
```

The default path follows the Windows Pictures folder for the current account,
including a redirected OneDrive Pictures folder. No personal path is embedded
in the script. Normal runs require a logged-in interactive Windows session and
send qualifying files to the Recycle Bin. The Recycle Bin is never emptied.
Recycling from OneDrive also removes the files from that synced folder on other
devices.

Normal runs write a `screenshots-*.log` file. A log initialization failure stops
the run before recycling; a later log write failure stops further processing.
Recycling errors produce exit code 1. Dry runs create no logs or folders.

For nightly cleanup, use the separate
[screenshot scheduling guide](../scheduling/README.md). The installer registers
an activity for the account running it and the folder passed to it. Each user
who wants automatic cleanup must configure their own scheduled task.
