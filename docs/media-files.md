# Moving media files

`Move-Audio.ps1`, `Move-Video.ps1` and `Move-Images.ps1` each run independently.
They process supported files directly in the current Windows user's Desktop and
Documents folders, including hidden files. They do not scan subfolders or
Downloads. Redirected Windows folders, such as a OneDrive Desktop, are resolved
automatically.

## Destinations

The defaults are the Windows Music, Videos and Pictures folders. Check `$dest`
in the script before the first run. To use a custom location, set `$dest` to a
full path, for example:

```powershell
$dest = [Environment]::GetFolderPath('MyMusic')
# $dest = 'D:\Audio'
```

The video and image scripts use `MyVideos` and `MyPictures`. The last active
assignment wins, so an uncommented custom assignment overrides the Windows
folder. A missing destination is created only when a file is ready to move; a
normal run still creates its log.

## Minimum age

Media scripts default to `-MinAgeMinutes 60`. A file is skipped if its creation
time **or** last modification time is within that period. This helps avoid
moving recently copied files that retain an older modification date, but file
timestamps do not reliably indicate when a file was last used.

```powershell
./Move-Images.ps1 -MinAgeMinutes 120
./Move-Images.ps1 -MinAgeMinutes 0
```

Use `-DryRun` with either example to preview. Setting the age to zero disables
the age check. To change the default permanently, edit
`[int]$MinAgeMinutes = 60` in the script.

## Supported formats

Matching uses file extensions and is case-insensitive.

| Type | Extensions |
| --- | --- |
| Audio | `.mp3`, `.wav`, `.flac`, `.aac`, `.m4a`, `.ogg`, `.wma`, `.aiff`, `.aif`, `.opus` |
| Video | `.mp4`, `.mov`, `.mkv`, `.avi`, `.wmv`, `.m4v`, `.webm`, `.mts`, `.m2ts`, `.3gp`, `.flv` |
| Images | `.jpg`, `.jpeg`, `.png`, `.webp`, `.avif`, `.gif`, `.bmp`, `.tif`, `.tiff`, `.heic`, `.heif` |

Edit `$exts` in a script to change its list. RAW files and XMP sidecars are not
processed. There is no sidecar pairing, including for JPEG or TIFF images.

## Name conflicts and limits

Existing destination files are not overwritten. When a name is taken, the script
tries timestamped names with a counter, checking each candidate. The scripts do
not compare file contents or remove duplicates.

```text
recording.wav
recording - flytt 20260915-120658-1.wav
recording - flytt 20260915-120658-2.wav
```

“Flytt” is Swedish for “move”.

Moving media can break references in Reaper, DaVinci Resolve and other
applications; the age limit does not protect project dependencies. OneDrive
files are not excluded just because they have a reparse-point attribute.
Online-only files may need downloading, and moving a file out of a synced folder
also changes that folder on your other synced devices. A file can change between
preview and execution. Moves across drives involve copying and removing the
source, so an interruption may leave work to inspect.

See [logs and troubleshooting](troubleshooting.md) for run results and error
handling.
