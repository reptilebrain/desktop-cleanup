# Isolated Windows tests

Run from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/Run-Tests.ps1
pwsh -NoProfile -File tests/Run-Tests.ps1
```

No test modules or package downloads are required. The runner reports each case,
continues after assertion failures, and exits 1 if any case fails. Setup errors
also fail the process. GitHub Actions runs both engines independently on Windows
for pull requests targeting main, pushes to main, and manual dispatch.

## Isolation

Every case creates a GUID-named fixture inside a dedicated temporary root. The
test harness parses each production script and writes a temporary copy, replacing
only destination configuration assignments and Windows `GetFolderPath` calls
with fixture paths. This includes the active D: overrides in Images and Video,
both source folders, the public desktop and LocalApplicationData. Path
normalization, validation, filtering, moving, logging and exit handling remain
the production code. Unmapped Windows folder calls stop execution.

Each copy runs in a child process using the same PowerShell executable as the
test runner, so real exit codes are checked. Only synthetic files are moved.
Shortcut tests are restricted to dry runs and never invoke the Recycle Bin.
The temporary root is checked before recursive cleanup in a finally block.
Production scripts are not modified.

## Coverage: 37 cases per engine

Each of Audio, Images and Video has 12 cases:

- Dry run preserves directory structure, file hashes and write timestamps,
  creates no destination or logs, and reserves distinct names across sources.
- Import resolves existing destination and duplicate source names without
  overwriting; SHA-256 hashes and counts match all original binary fixtures.
- Old files move; recent creation or modification independently prevents moving;
  `MinAgeMinutes 0` disables the age filter.
- Hidden files are included; nested files and unsupported extensions stay put.
- Empty sources do not create a destination; source equal to destination is skipped.
- Empty and relative destinations fail without side effects.
- A regular file used as the destination fails without side effects.
- A missing source produces exit 1 while the other source is still processed.
- A regular file blocking LocalApplicationData simulates log initialization failure
  and prevents imports.
- An exclusively locked source simulates a move failure, produces exit 1 and
  preserves source bytes without creating a destination file.

One shortcut case checks private/public desktop opt-in, extension and recursion
filtering, and no changes to the fixture during previews.

The current scripts have no separate vault, inbox, or import subsystem: these
terms map here to destination, Desktop/Documents sources, and file moves.
Tests cover their existing checks; they do not invent vault markers, containment
policies or new production behavior. Actual Recycle Bin operations, Windows known
folder resolution, permission/ACL failures, mid-run log failures and race timing
between name selection and moving are not exercised by this suite.
