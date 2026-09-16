# Desktop Cleanup

[![Tests](https://github.com/reptilebrain/desktop-cleanup/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/reptilebrain/desktop-cleanup/actions/workflows/tests.yml)
[![Code analysis](https://github.com/reptilebrain/desktop-cleanup/actions/workflows/analysis.yml/badge.svg?branch=main)](https://github.com/reptilebrain/desktop-cleanup/actions/workflows/analysis.yml)
[![PowerShell: 5.1 & 7](https://img.shields.io/badge/PowerShell-5.1%20%26%207-blue)](tests/README.md)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows-blue)](#requirements)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

PowerShell scripts to tidy your desktop: sort images, audio and video into folders, and send unwanted shortcuts to the Recycle Bin.

I like a clean desktop. My ability to put files in the right place suggests otherwise. These scripts handle the routine tidying so good intentions no longer have to do all the work.

## Scripts

| Script | Source | Destination or action |
| --- | --- | --- |
| `Move-Audio.ps1` | Desktop and Documents | Music, or a custom folder |
| `Move-Video.ps1` | Desktop and Documents | Videos, or a custom folder |
| `Move-Images.ps1` | Desktop and Documents | Pictures, or a custom folder |
| `Remove-DesktopShortcuts.ps1` | Your Desktop; optionally the public desktop | Sends `.lnk` shortcuts to the Recycle Bin |

Each script runs independently. Use whichever ones you need.

The media scripts process files directly in Desktop and Documents, including hidden files. They do not scan subfolders or Downloads. Sources are resolved through Windows, so redirected folders such as a OneDrive Desktop are picked up automatically.

**Check `$dest` before your first run.** The last active assignment determines the destination. An uncommented custom path overrides the Windows folder above it.

## Automated tests

Windows PowerShell 5.1 and PowerShell 7 tests run through GitHub Actions.
See [the test guide](tests/README.md) for local commands, isolation, coverage and
simulated failure paths.

## Requirements

- Windows with Windows PowerShell 5.1 or PowerShell 7. The scripts are written for both; this is not a claim of testing every version.
- Read and write access to the folders being processed.
- Your own Windows account when running manually or through Task Scheduler.

No additional PowerShell modules are required. Cleaning the public desktop may require administrator permissions.

## Quick start

Download and extract the repository ZIP, or clone the repository. Keep the scripts in a permanent folder before scheduling them.

Open PowerShell in that folder, check the destination settings, and preview one script:

```powershell
.\Move-Audio.ps1 -DryRun
```

To preview a freshly copied test file without waiting for the age limit:

```powershell
.\Move-Audio.ps1 -DryRun -MinAgeMinutes 0
```

When the proposed paths look right, run without `-DryRun`:

```powershell
.\Move-Audio.ps1
```

This restores the default 60-minute age limit. To move your new test file immediately, also pass `-MinAgeMinutes 0` on the real run.

The same options work with `Move-Video.ps1` and `Move-Images.ps1`. `-DryRun` creates no folders or logs and moves or removes nothing. It is a preview, not a test of write permissions or file availability at a later time.

### Downloaded scripts are blocked

If PowerShell reports that a downloaded script is not digitally signed, review the file and then unblock that specific script:

```powershell
Unblock-File -LiteralPath .\Move-Audio.ps1
```

Repeat for the other scripts as needed. This removes the downloaded-file marker without changing your execution policy. It allows unsigned downloaded scripts under `RemoteSigned`; it does not override `AllSigned` or an organisation's policy. See [Microsoft's Unblock-File documentation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/unblock-file).

If execution is still blocked, inspect the policies:

```powershell
Get-ExecutionPolicy -List
```

## Media settings

### Destination

Edit the destination section in each media script. For example, to use Music:

```powershell
$dest = [Environment]::GetFolderPath('MyMusic')
# $dest = 'D:\Audio'
```

To use a custom folder, uncomment the second assignment and change its path:

```powershell
$dest = [Environment]::GetFolderPath('MyMusic')
$dest = 'D:\Audio'
```

The video and image scripts use `MyVideos` and `MyPictures` respectively. Use a full absolute path for a custom destination.

A missing destination folder is created immediately before a file move is attempted. If no files qualify, the destination is not created. A normal run still creates its log.

### Minimum age

By default, a file is skipped if its creation time **or** last modification time is within the previous 60 minutes. This also catches many recently copied files that retain an older modification date. File timestamps are not a reliable measure of when you last used a file.

Use a different limit for a run:

```powershell
.\Move-Images.ps1 -MinAgeMinutes 120
```

Disable the age check:

```powershell
.\Move-Images.ps1 -MinAgeMinutes 0
```

To change the default permanently, edit `[int]$MinAgeMinutes = 60` in the script. The shortcut script has no age limit.

### File formats

Matching uses file extensions and is case-insensitive.

| Type | Extensions |
| --- | --- |
| Audio | `.mp3`, `.wav`, `.flac`, `.aac`, `.m4a`, `.ogg`, `.wma`, `.aiff`, `.aif`, `.opus` |
| Video | `.mp4`, `.mov`, `.mkv`, `.avi`, `.wmv`, `.m4v`, `.webm`, `.mts`, `.m2ts`, `.3gp`, `.flv` |
| Images | `.jpg`, `.jpeg`, `.png`, `.webp`, `.avif`, `.gif`, `.bmp`, `.tif`, `.tiff`, `.heic`, `.heif` |

Edit `$exts` to change the list. RAW files and XMP sidecars are not processed. There is no sidecar pairing, including for JPEG or TIFF images.

### Name conflicts

Existing destination files are not overwritten. If a name is taken, the script tries a timestamp and counter, checking each candidate:

```text
recording.wav
recording - flytt 20260915-120658-1.wav
recording - flytt 20260915-120658-2.wav
```

“Flytt” is Swedish for “move”. The scripts do not compare file contents or remove duplicates.

## Desktop shortcuts

Preview the shortcuts on your own desktop:

```powershell
.\Remove-DesktopShortcuts.ps1 -DryRun
```

Send them to the Recycle Bin:

```powershell
.\Remove-DesktopShortcuts.ps1
```

Only `.lnk` files are processed. Their targets are not deleted. Internet shortcuts (`.url`), folders and special desktop icons such as the Recycle Bin are not processed.

### Keep selected shortcuts

Edit `$keep` with exact filenames, including `.lnk`:

```powershell
$keep = @(
    'Firefox.lnk'
    'REAPER.lnk'
)
```

Matching is case-insensitive and applies to both desktops. An empty list keeps no `.lnk` shortcuts. Windows may hide the `.lnk` extension in Explorer; use the filenames printed by `-DryRun`.

### Include the public desktop

```powershell
.\Remove-DesktopShortcuts.ps1 -DryRun -IncludePublicDesktop
```

Remove `-DryRun` to perform the cleanup. Changes to the public desktop affect all users. Run PowerShell as administrator if access is denied. The public desktop is excluded unless this switch is supplied.

The script requests recycling through Windows. Use it in a logged-in desktop session; Windows may display error dialogs. The recycling options are not supported in non-interactive applications. See [Microsoft's DeleteFile documentation](https://learn.microsoft.com/en-us/dotnet/api/microsoft.visualbasic.fileio.filesystem.deletefile?view=net-10.0).

## Task Scheduler

Use a separate task for each script you want to run. If you already have scheduled cleanup tasks, you can replace the code in your existing script files and update each task's arguments. There is no need to rename those files: the path after `-File` must match the file you actually use.

### Create or update a task

1. Open **Task Scheduler**. Choose **Create Task** for a new task, or open **Properties** on an existing one.
2. On **General**, select your own Windows account. The scripts resolve Desktop and Documents for the account running them, so do not use `SYSTEM`.
3. Select **Run only when user is logged on**. This is required for the shortcut script's recycling operation and is a straightforward setup for all four scripts.
4. On **Triggers**, choose when to run, such as once each day while you normally use the computer. Keep your existing triggers if they already suit you.
5. On **Actions**, choose **Start a program** and use the appropriate example below.
6. On **Settings**, set **If the task is already running** to **Do not start a new instance** to avoid overlapping scheduled runs of that task.
7. Save the task, right-click it and choose **Run**, then check the log and **Last Run Result**.

### Audio, images and video

These examples assume the repository scripts are stored in `C:\Scripts\DesktopCleanup`. Adjust every path to match your installation.

| Action field | Value |
| --- | --- |
| Program/script | `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` |
| Start in | `C:\Scripts\DesktopCleanup` |

Enter one of the following lines in **Add arguments**, depending on the task.

**Audio:**

```text
-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Scripts\DesktopCleanup\Move-Audio.ps1" -MinAgeMinutes 60
```

**Images:**

```text
-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Scripts\DesktopCleanup\Move-Images.ps1" -MinAgeMinutes 60
```

**Video:**

```text
-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Scripts\DesktopCleanup\Move-Video.ps1" -MinAgeMinutes 60
```

The executable above runs Windows PowerShell. If you use PowerShell 7, select the full path to your installed `pwsh.exe` instead. Keep **Program/script** separate from **Add arguments**; the argument lines are not standalone commands to paste into a PowerShell prompt.

### What the switches do

| Switch | Purpose |
| --- | --- |
| `-NoProfile` | Starts PowerShell without loading profile scripts. |
| `-NonInteractive` | Makes interactive PowerShell prompts fail instead of waiting for input. It does not suppress every Windows or application dialog. |
| `-WindowStyle Hidden` | Hides the PowerShell window. |
| `-ExecutionPolicy Bypass` | Requests execution-policy bypass for this process; it does not permanently change the configured policy. Group Policy can take precedence. |
| `-File "..."` | Selects the script to run. PowerShell's own switches go before this option. |
| `-MinAgeMinutes 60` | A media-script parameter: skips files created or modified within the previous 60 minutes. Use `0` to disable the age check. |

The first four switches configure PowerShell. Parameters after the script path belong to the script. See [Microsoft's PowerShell command-line documentation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_powershell_exe?view=powershell-5.1).

`Bypass` does not grant administrator rights or bypass filesystem permissions. It also does not override `MachinePolicy` or `UserPolicy` set through Group Policy. You can omit it if your existing execution policy already permits these scripts. See [Microsoft's execution-policy documentation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies).

### Desktop shortcuts

Use the same executable and working folder, with this **Add arguments** line:

```text
-NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\DesktopCleanup\Remove-DesktopShortcuts.ps1"
```

To include the public desktop:

```text
-NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\DesktopCleanup\Remove-DesktopShortcuts.ps1" -IncludePublicDesktop
```

These examples deliberately omit `-NonInteractive` and `-WindowStyle Hidden` because recycling may involve Windows error dialogs. `-NonInteractive` itself is not the same as running outside a logged-in desktop session; the task's **Run only when user is logged on** setting is what matters here.

The shortcut script does not accept `-MinAgeMinutes`. For public desktop permissions, **Run with highest privileges** may be needed when using an administrator account. It is not normally needed for your own media folders.

### Check the task before leaving it to run

Test the script manually with `-DryRun` first. Then run the task and inspect its log. For troubleshooting a media task, temporarily remove `-WindowStyle Hidden` so the console is not deliberately hidden; run the command manually if you need to read startup errors before the window closes.

A scheduled dry run produces no log, so a hidden `-DryRun` task will not give you a saved preview. Use the visible manual preview for that.

## Logs and results

Normal runs write a separate timestamped log under:

```text
%LOCALAPPDATA%\DesktopCleanup\Logs
```

Paste that path into Explorer's address bar. Log prefixes identify the script: `audio-`, `video-`, `images-` and `shortcuts-`. Old logs are not deleted automatically.

| Message | Meaning |
| --- | --- |
| `DRYRUN` | A proposed action; nothing was changed |
| `MOVED` | A media file was moved |
| `RECYCLED` | A shortcut's recycle operation completed |
| `SKIP` / `Too recent` | A media file did not meet the age limit; this is not an error |
| `KEEP` | A shortcut matched the keep list |
| `ERROR` | An operation failed; inspect the accompanying message |

Exit code `0` means the script reported no errors, including runs where nothing qualified. Exit code `1` means at least one error was reported. Task Scheduler commonly displays these as `0x0` and `0x1`. Startup failures may produce other results and no script log.

A failure on one file is logged and processing continues. Setup failures stop the run. If log writing fails after setup, the script continues with console output and returns an error status.

## Practical limits

These scripts tidy loose files. They do not understand your projects or provide a backup.

- Moving media can break references in Reaper, DaVinci Resolve and other applications. The age limit does not protect project dependencies.
- OneDrive files are not excluded merely because they carry a reparse-point attribute. Online-only files may need downloading, and unavailable files can fail to move. Moving a file out of a synced folder also changes what remains in that folder across your synced devices.
- A file can change between preview and execution. A dry run does not reserve names on disk or guarantee that a later move will succeed.
- Moves between drives involve copying and removing the source, so interruption can leave work to inspect. There is no automatic rollback or content verification.

A clean desktop is achievable. A filing system with sound judgement remains your department.

## License

Released under the [MIT License](LICENSE).
