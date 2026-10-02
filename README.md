# Desktop Cleanup

[![Tests](https://github.com/reptilebrain/desktop-cleanup/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/reptilebrain/desktop-cleanup/actions/workflows/tests.yml)
[![Code analysis](https://github.com/reptilebrain/desktop-cleanup/actions/workflows/analysis.yml/badge.svg?branch=main)](https://github.com/reptilebrain/desktop-cleanup/actions/workflows/analysis.yml)
[![PowerShell: 5.1 & 7](https://img.shields.io/badge/PowerShell-5.1%20%26%207-blue)](tests/README.md)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows-blue)](#requirements)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Small PowerShell tools for sorting loose media, cleaning desktop shortcuts and
retaining screenshots. Preview changes with `-DryRun` before running a cleanup.

## Scripts

| Script | What it does |
| --- | --- |
| `Move-Audio.ps1` | Moves supported audio files from Desktop and Documents to Music or a configured folder. |
| `Move-Video.ps1` | Moves supported video files from Desktop and Documents to Videos or a configured folder. |
| `Move-Images.ps1` | Moves supported image files from Desktop and Documents to Pictures or a configured folder. |
| `Remove-DesktopShortcuts.ps1` | Sends selected `.lnk` shortcuts from your Desktop to the Recycle Bin; the public desktop is optional. |
| `Remove-OldScreenshots.ps1` | Recycles PNG files older than the retention period from Pictures/Screenshots or a configured folder. |

Each script runs independently. Requirements, file selection and settings are in
the [media guide](docs/media-files.md) and [desktop cleanup guide](docs/desktop-cleanup.md).

## Requirements

- Windows with Windows PowerShell 5.1 or PowerShell 7.
- Read and write access to the folders being processed.
- Your own Windows account when running manually or through Task Scheduler.

No additional PowerShell modules are required to run the scripts.

## Quick start

Download or clone the repository, inspect the destination settings, then preview
a run:

```powershell
./Move-Audio.ps1 -DryRun
./Remove-OldScreenshots.ps1 -DryRun
```

For a custom screenshot folder, pass its path explicitly:

```powershell
./Remove-OldScreenshots.ps1 -ScreenshotPath 'C:\Pictures\Screenshots' -DryRun
```

Remove `-DryRun` only after checking the proposed actions. A preview changes no
files, folders or logs; it does not guarantee that a later run will succeed.

## Guides

- [Moving audio, video and image files](docs/media-files.md)
- [Desktop shortcuts and screenshot retention](docs/desktop-cleanup.md)
- [Scheduling cleanup scripts](docs/task-scheduler.md), including the separate
  [screenshot task installer guide](scheduling/README.md)
- [Logs, execution policy and practical limits](docs/troubleshooting.md)
- [Automated tests and code analysis](tests/README.md)

The scripts use the Windows folders of the account running them. A scheduled
task is also account-specific; configure a separate task and path for each user
who wants automatic cleanup. OneDrive deletions sync to that account's other
devices. Read the relevant guide before scheduling a real cleanup.

## License

Released under the [MIT License](LICENSE).
