# Desktop Cleanup

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

**Check `$dest` before your first run.** The last active assignment determines the destination. If the audio script contains an uncommented `$dest = 'D:\Audio'` line, it uses that folder rather than Music.

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

Create a separate task for each script you want to run. This makes schedules and results easier to manage.

1. Open **Task Scheduler** and choose **Create Task**.
2. On **General**, select your own account and **Run only when user is logged on**. This is required for the shortcut script's interactive recycling operation and is a straightforward setup for all four scripts. Do not use `SYSTEM`: the media folders are resolved for the account running the task.
3. On **Triggers**, choose a schedule, such as once each day while you normally use the computer.
4. On **Actions**, choose **Start a program** and configure the fields below.
5. On **Settings**, set **If the task is already running** to **Do not start a new instance**. This prevents overlapping scheduled runs of the same task, as described by [Microsoft's task instance policy](https://learn.microsoft.com/en-us/windows/win32/api/taskschd/ne-taskschd-task_instances_policy).
6. Save the task, right-click it and choose **Run**, then check the log and **Last Run Result**.

For example, with scripts stored in `C:\Scripts\DesktopCleanup`:

| Action field | Value |
| --- | --- |
| Program/script | `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` |
| Add arguments | `-NoProfile -File "C:\Scripts\DesktopCleanup\Move-Audio.ps1" -MinAgeMinutes 60` |
| Start in | `C:\Scripts\DesktopCleanup` |

Adjust the paths to your installation. The executable above runs Windows PowerShell; use the full path to `pwsh.exe` if you prefer your installed PowerShell 7. The argument structure places script options after `-File`, following [Microsoft's command-line documentation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_powershell_exe?view=powershell-5.1).

Change the script filename for images or video. For shortcut cleanup, use:

```text
-NoProfile -File "C:\Scripts\DesktopCleanup\Remove-DesktopShortcuts.ps1"
```

Add `-IncludePublicDesktop` if wanted. For public desktop permissions, **Run with highest privileges** may be needed when using an administrator account. It is not normally needed for your own media folders.

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
