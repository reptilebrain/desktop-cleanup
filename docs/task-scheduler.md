# Task Scheduler

Use one scheduled task for each script you want to run. Keep the repository
scripts in a permanent folder; the task's `-File` argument must name the actual
script path. The examples below assume `C:\Scripts\DesktopCleanup`.

## Create or update a task

1. Open **Task Scheduler**. Choose **Create Task**, or open **Properties** on an existing task.
2. On **General**, select your Windows account. Do not use `SYSTEM`; the scripts resolve Windows folders for the account that runs them.
3. Select **Run only when user is logged on**. Recycling shortcuts and screenshots needs an interactive desktop session.
4. On **Triggers**, choose when to run, for example daily while you normally use the computer.
5. On **Actions**, select **Start a program** and configure the executable, working folder and arguments below.
6. On **Settings**, set **If the task is already running** to **Do not start a new instance**.
7. Save the task, right-click it and select **Run**. Check its log and **Last Run Result**.

Use a separate task for audio, images, video or shortcuts. You can also update an
existing task's arguments when replacing a script file; renaming the script is
not required.

## Audio, images and video

For these media tasks, set:

| Task field | Value |
| --- | --- |
| Program/script | `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` |
| Start in | `C:\Scripts\DesktopCleanup` |

Use the matching line in **Add arguments**:

```text
-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Scripts\DesktopCleanup\Move-Audio.ps1" -MinAgeMinutes 60
-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Scripts\DesktopCleanup\Move-Images.ps1" -MinAgeMinutes 60
-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Scripts\DesktopCleanup\Move-Video.ps1" -MinAgeMinutes 60
```

If you use PowerShell 7, select its full `pwsh.exe` path instead. Keep
**Program/script** separate from **Add arguments**; those lines are not commands
to paste into a PowerShell prompt.

## Desktop shortcuts

Use the same executable and working folder, with one of these **Add arguments**
values:

```text
-NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\DesktopCleanup\Remove-DesktopShortcuts.ps1"
-NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\DesktopCleanup\Remove-DesktopShortcuts.ps1" -IncludePublicDesktop
```

These examples omit `-NonInteractive` and `-WindowStyle Hidden` because
recycling may display Windows error dialogs. **Run only when user is logged on**
is still required. The public desktop affects all users and may require
administrator permissions. **Run with highest privileges** may be needed for
public desktop permissions when using an administrator account; it is not
normally needed for personal media folders.

## Screenshot retention

Screenshot scheduling uses a separate installer, which copies the script to a
stable per-user location and registers a daily task at 03:00 local time. Set the
folder path for the Windows account being configured. See the
[screenshot scheduling guide](../scheduling/README.md) for the install command,
retention options, verification and update procedure.

## PowerShell switches

| Switch | Purpose |
| --- | --- |
| `-NoProfile` | Starts PowerShell without loading profile scripts. |
| `-NonInteractive` | Makes interactive PowerShell prompts fail instead of waiting. It does not suppress every Windows or application dialog. |
| `-WindowStyle Hidden` | Hides the PowerShell window. |
| `-ExecutionPolicy Bypass` | Requests a process-scoped policy bypass; it does not permanently change policy, grant administrator rights or override Group Policy. Omit it if the configured policy already permits the script. |
| `-File "..."` | Selects the script to run. PowerShell's switches come before this option. |
| `-MinAgeMinutes 60` | Media-script parameter: skips files created or modified within the previous 60 minutes. Use 0 to disable the age check. |

Script parameters such as `-MinAgeMinutes` go after the script path. The first
four switches configure PowerShell itself.

For media tasks, preview manually with `-DryRun` before scheduling a real run. A
scheduled dry run creates no log, so use the visible manual preview to inspect
proposed paths. For logs and exit codes, see [troubleshooting](troubleshooting.md).
