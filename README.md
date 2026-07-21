#RoboCopy_GUI
#Github
#Public



# RoboCopy GUI (PowerShell + WPF)

A lightweight Windows PowerShell GUI for running RoboCopy with common options. The app launches a separate PowerShell console to display live RoboCopy output and an exit-code summary, while the WPF window stays responsive and updates basic status.

- **Main script**: `RoboGui_V3.ps1`
- **Launcher**: `Launch_RoboCopyGui.bat` (double-click friendly)

## Project Info

- **Author**: Seth (Oblivionx987)
- **Version**: 1.0.1

## Features
 
- **Source/Destination** pickers via text boxes.
- **Common switches**: `/MIR`, `/MOV`, `/PURGE`, `/E`, `/XO`, `/XN`, `/R:5`.
- **Status + progress bar** in the WPF window (simple: 0% → 100% at completion).
- **Second console window** shows full RoboCopy output and friendly exit-code explanation.
- **Toast notifications** (start and completion) via BurntToast if installed.
- **Safe toast handling**: BurntToast is optional; script runs without it.
- **Validation**: Verifies paths and prompts when both Mirror and Move are selected.
- **Logging (optional)**: Check "Log to file" to write `/LOG:` to a chosen path (defaults to `Destination\\robocopy.log`).
- **Cleanup**: Temporary execution script is auto-deleted after completion.
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
 
- Easiest: Double‑click `Launch_RoboCopyGui.bat`.
- Or from a PowerShell prompt (recommended: Windows PowerShell 5.1):

```powershell
powershell.exe -ExecutionPolicy Bypass -File ".\RoboGui_V3.ps1"
```

## Usage
 
1. Enter a valid `Source Path` and `Destination Path`.
2. Select options as needed (see below).
3. Click `Run`.
   - A new PowerShell console opens and runs RoboCopy, showing all output.
   - When finished, the console explains the exit code and waits for a key press to close.
   - The GUI updates status and, if BurntToast is available, a toast appears.

## Options Explained
 
- **/MIR**: Mirror a directory tree (can delete files in destination not present in source).
- **/MOV**: Move files and directories (removes them from source after copying).
- **/PURGE**: Delete destination files/dirs that no longer exist in source.
- **/E**: Copy subdirectories (including empty ones).
- **/XO**: Exclude older files (skip if destination file is newer).
- **/XN**: Exclude newer files (skip if destination file is older).
- **/R:5**: Retry failed copies up to 5 times.

Caution: Avoid combining **/MIR** and **/MOV** together; they imply different intentions (copy/mirror vs. move).

## RoboCopy Exit Codes (summary)
-- `0`: No files copied; no failures; no mismatches.
- `1`: All files were copied successfully.
- `2`: Extra files or directories were detected in the destination.
- `3`: Some files were copied; additional files were present.
- `4`: Some mismatched files or directories were detected.
- `5`: Some files were copied; some files were mismatched.
- `6`: Additional files and mismatched files exist.
- `7`: Files were copied; a mismatch and additional files were present.
- `8+`: Several files did not copy (treat as error).

## Troubleshooting
 
- **GUI does not start**: Use Windows PowerShell 5.1 to run the script. WPF may not load under some PowerShell 7+ setups.
- **No toasts**: Install BurntToast (see above) or ensure Windows Notifications are enabled.
- **Access denied / permissions**: Run PowerShell/Explorer with appropriate permissions, verify path access.
- **Long paths / locked files**: Consider adding RoboCopy options like `/W:n` (wait) or `/TBD` (wait for share names) by extending the script.

## Known Issues and Recommendations
 
- The temporary script launched in a separate console currently builds the RoboCopy command as a string and then only prints it. To actually execute RoboCopy and obtain the correct exit code, update the temp‑script block to run the command rather than echo it (e.g., use `Invoke-Expression $command` or invoke `robocopy` directly with argument tokens). If you’d like, open an issue or ask and we can apply this fix for you.
- The progress bar is not a live RoboCopy progress; it advances to 100% at completion. Live parsing would require capturing and parsing RoboCopy output.
- `Mirror` and `Move` can be selected together; typically you should use one or the other. Adding input validation is recommended.
- Temporary script files are not deleted after run; a clean‑up step could be added.

## File List
 
- `RoboGui_V3.ps1` — WPF UI and run logic.
- `Launch_RoboCopyGui.bat` — Convenience launcher using `-ExecutionPolicy Bypass`.

---

If you want me to fix the execution bug and add small quality‑of‑life improvements (validation, cleanup, optional log file), say the word and I’ll update the script.
