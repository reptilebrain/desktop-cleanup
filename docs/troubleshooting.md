# Logs and troubleshooting

## Downloaded scripts are blocked

If PowerShell reports that a downloaded script is not digitally signed, inspect
the script, then unblock that specific file:

```powershell
Unblock-File -LiteralPath .\Move-Audio.ps1
```

Repeat for other scripts as needed. This removes the downloaded-file marker; it
does not change the execution policy. It allows unsigned downloaded scripts
under `RemoteSigned`, but does not override `AllSigned` or an organisation's
policy. To inspect configured policies, run:

```powershell
Get-ExecutionPolicy -List
```

See Microsoft's [Unblock-File documentation](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/unblock-file).

## Logs and results

Normal cleanup runs write timestamped logs under:

```text
%LOCALAPPDATA%\DesktopCleanup\Logs
```

Prefixes identify the script: `audio-`, `video-`, `images-`, `shortcuts-` and
`screenshots-`. Logs are not deleted automatically. Paste the path into
File Explorer's address bar to open the folder.

| Log message | Meaning |
| --- | --- |
| `DRYRUN` | A proposed action; nothing was changed. |
| `MOVED` | A media file was moved. |
| `RECYCLED` | A shortcut or screenshot was sent to the Recycle Bin. |
| `SKIP` / `Too recent` | A media file did not meet the age limit; this is not an error. |
| `KEEP` | A shortcut matched the keep list. |
| `ERROR` | An operation failed; inspect the accompanying message. |

Exit code `0` means the script reported no errors, even if no files qualified.
Exit code `1` means an error was reported. Task Scheduler commonly displays
these as `0x0` and `0x1`. Startup failures may produce other results and no
script log.

A failure on one file is generally logged and processing continues. Setup
failures stop the run. For media scripts, a log write failure after setup stops
further logging but the script continues with console output and returns an
error status. For screenshot cleanup, a later log write failure stops further
processing so it does not continue recycling without an audit log.

## Practical limits

- A dry run is a preview, not a reservation of filenames or a guarantee that a later move or recycle operation will succeed. A file can change after preview.
- These scripts tidy loose files; they do not understand projects and do not provide a backup. Moving media can break references in editing applications.
- OneDrive files are not excluded merely because they have a reparse-point attribute. Online-only files may need downloading, and moves or recycling inside a synced folder also affect that folder on other devices.
- Moves between drives involve copying and removing the source. An interruption can leave work to inspect; there is no automatic rollback or content verification.
- The scripts never empty the Recycle Bin.

For Task Scheduler setup and run checks, see the [scheduling guide](task-scheduler.md).
