#RoboCopy_GUI
#Github
#Public



# RoboCopy GUI (PowerShell + WPF)

A lightweight Windows PowerShell GUI for running RoboCopy with common options. The app launches a separate PowerShell console to display live RoboCopy output and an exit-code summary, while the WPF window stays responsive and shows live status. The GUI status updates the moment RoboCopy finishes — it does not wait for you to close the console window.

- **Main script**: `RoboGui_V3.ps1`
- **Launcher**: `Launch_RoboCopyGui.bat` (double-click friendly)

## Project Info

- **Author**: Seth (Oblivionx987)
- **Version**: 1.1.0

## Features

- **Source/Destination** pickers via text boxes **and** Browse... buttons (folder dialog).
- **Common switches**: `/MIR`, `/MOV`, `/PURGE`, `/E`, `/XO`, `/XN`, `/R:5`.
- **Multi-threaded copy** (`/MT:8`) for faster large transfers.
- **Dry Run** (`/L`) to preview what RoboCopy would copy without writing anything.
- **Indeterminate progress bar** while a transfer runs; fills to 100% at completion, resets on cancel.
- **Live status** in the GUI: `Ready` → `Running...` → `Completed (exit code N)` or `Completed with errors (N)` — updated as soon as RoboCopy exits, independently of the console.
- **Second console window** shows full RoboCopy output and a friendly exit-code explanation.
- **Cancel button** stops a running transfer (kills the RoboCopy process tree) and resets the GUI.
- **Window-close guard** warns before closing mid-transfer and cleans up temporary files.
- **Toast notifications** (start and completion) via BurntToast if installed.
- **Safe toast handling**: BurntToast is optional; the script runs without it. The toast logo (`robocopy-icon.png`) is also optional.
- **Validation**: Verifies paths, prompts when the destination is missing, and warns when both Mirror and Move are selected.
- **Logging (optional)**: Check "Log to file" to write `/LOG:` to a chosen path (defaults to `Destination\robocopy.log`).
- **Settings persistence**: Window size/position, last Source/Destination, log path, and checkbox states are saved to `settings.json` and restored on next launch (gitignored).
- **Robust invocation**: RoboCopy is launched with an argument array (no fragile string quoting); paths with spaces and special characters work correctly. User data is passed via a temporary job file, never interpolated into script source.
- **Cleanup**: Temporary execution script, job file, and done-sentinel files are auto-deleted after completion, cancellation, and window close. Stale temp files from prior crashes are swept at startup.
- **STA enforcement**: The launcher uses `-STA`; if run otherwise, the script detects it and shows a clear message (WPF requires STA).
- **Versioned UI**: Window title shows the current version.

## Requirements

- Windows 10/11
- Windows PowerShell 5.1 (recommended for WPF compatibility). PowerShell 7+ may not load `PresentationFramework` the same way.
- RoboCopy (bundled with Windows)
- Optional: [BurntToast](https://www.powershellgallery.com/packages/BurntToast) for Windows toast notifications

## Install BurntToast (optional)

If you want toast notifications when a job starts/completes:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name BurntToast -Scope CurrentUser -Force
```

Verify:

```powershell
Import-Module BurntToast
New-BurntToastNotification -Text 'BurntToast installed', 'This is a test toast.'
```

Note: If `robocopy-icon.png` is not present in this folder, toasts still work; the icon will be skipped.

## How to Run

- Easiest: Double-click `Launch_RoboCopyGui.bat`.
- Or from a PowerShell prompt (recommended: Windows PowerShell 5.1):

```powershell
powershell.exe -STA -ExecutionPolicy Bypass -File ".\RoboGui_V3.ps1"
```

> The `-STA` flag is required for WPF. The `.bat` launcher already includes it. If you launch without `-STA`, the script will detect this and prompt you to relaunch correctly.

## Usage

1. Enter a valid `Source Path` and `Destination Path` (or use the **Browse...** buttons).
2. Select options as needed (see below).
3. Click `Run`.
   - A new PowerShell console opens and runs RoboCopy, showing all output.
   - When RoboCopy finishes, the GUI status updates to show the exit code immediately.
   - The console explains the exit code and waits for a key press to close (so you can read the summary). Closing it does not affect the GUI.
   - If BurntToast is available, a completion toast appears.
4. To stop a transfer in progress, click `Cancel`. The RoboCopy process tree is terminated and the GUI resets.
5. Closing the GUI while a transfer is running prompts you to cancel first; temp files are cleaned up either way.

## Options Explained

- **/MIR**: Mirror a directory tree (can delete files in destination not present in source).
- **/MOV**: Move files and directories (removes them from source after copying).
- **/PURGE**: Delete destination files/dirs that no longer exist in source.
- **/E**: Copy subdirectories (including empty ones).
- **/XO**: Exclude older files (skip if destination file is newer).
- **/XN**: Exclude newer files (skip if destination file is older).
- **/R:5**: Retry failed copies up to 5 times.
- **/MT:8**: Use 8 threads for multi-threaded copying (faster for large trees).
- **/L**: Dry run — list files that would be copied without actually copying them. Safe for previewing.
- **Log to file**: Write RoboCopy output to a log file (defaults to `Destination\robocopy.log` if the path field is empty).

Caution: Avoid combining **/MIR** and **/MOV** together; they imply different intentions (copy/mirror vs. move). The GUI warns you if both are selected.

## RoboCopy Exit Codes

RoboCopy uses a bit-flag exit code. Treat codes below 8 as success/no-fatal-error, and 8+ as errors.

- `0`: No files copied; no failures; no mismatches.
- `1`: All files were copied successfully.
- `2`: Extra files or directories were detected in the destination.
- `3`: Some files were copied; additional files were present.
- `4`: Some mismatched files or directories were detected.
- `5`: Some files were copied; some files were mismatched.
- `6`: Additional files and mismatched files exist.
- `7`: Files were copied; a mismatch and additional files were present.
- `8`: At least one file did not copy (treat as error).
- `9`-`15`: Combinations of the above flags (copies + extras + mismatches). Treat as errors if bit 3 (value 8) is set.
- `16`: RoboCopy did not run — serious error or bad arguments.

## Troubleshooting

- **GUI does not start**: Use Windows PowerShell 5.1 to run the script. WPF may not load under some PowerShell 7+ setups. Ensure you launch with `-STA` (the `.bat` launcher does this for you).
- **"STA Required" message**: Relaunch with `powershell.exe -STA ...` or just use `Launch_RoboCopyGui.bat`.
- **No toasts**: Install BurntToast (see above) or ensure Windows Notifications are enabled. The app works fine without toasts.
- **Access denied / permissions**: Run PowerShell/Explorer with appropriate permissions; verify path access. Some system folders require elevation.
- **Long paths / locked files**: Consider adding RoboCopy options like `/W:n` (wait between retries) or `/TBD` (wait for share names) by extending the script. `/MT:8` is already available for speed.
- **Paths with spaces**: These work correctly. RoboCopy is invoked with an argument array rather than a single command string.

## Known Issues and Limitations

- **Progress is not a live percentage.** The progress bar is indeterminate (marquee) during a transfer and fills to 100% at completion. Live parsing of RoboCopy output to drive a real percentage is not implemented; it could be added later by capturing RoboCopy stdout.
- **The console window stays open until you press a key** after RoboCopy finishes. This is by design so you can read the exit-code summary. The GUI status and progress update independently (the moment RoboCopy exits), so you do not need to close the console to see results in the GUI.
- **BurntToast is optional.** Without it, toast notifications are skipped; everything else works.
- **PowerShell 7+ WPF not guaranteed.** Use Windows PowerShell 5.1 for best compatibility.
- **`/MT` thread count is fixed at 8.** It is not yet a configurable numeric field; extend the script if you need a different count.

## File List

- `RoboGui_V3.ps1` — WPF UI and run logic (v1.1.0).
- `Launch_RoboCopyGui.bat` — Convenience launcher using `-STA -ExecutionPolicy Bypass`.
- `.gitignore` — Ignores `settings.json` and `*.log`.
- `settings.json` — Auto-generated on first close; stores window geometry, last paths, and checkbox states (gitignored).
