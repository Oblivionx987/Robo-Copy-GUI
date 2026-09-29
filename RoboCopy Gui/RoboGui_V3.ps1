#RoboCopy_GUI

# Load required assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Windows.Forms

# Metadata
# Author: Seth (Oblivionx987)
# Version: 1.1.0
$script:Author = 'Seth (Oblivionx987)'
$script:Version = '1.1.0'

# STA check (WPF ShowDialog requires STA)
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
    [System.Windows.MessageBox]::Show("RoboCopy GUI must run in STA mode. Relaunch with powershell.exe -STA.", "STA Required", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    exit
}

# Import BurntToast module for toast notifications (optional)
$script:CanToast = $false
try {
    if (Get-Module -ListAvailable -Name BurntToast) {
        Import-Module BurntToast -ErrorAction Stop
        $script:CanToast = $true
    }
} catch {
    $script:CanToast = $false
}

# Toast logo (optional, skipped if missing)
$script:ToastLogo = $null
if (Test-Path "$PSScriptRoot\robocopy-icon.png") {
    $script:ToastLogo = "$PSScriptRoot\robocopy-icon.png"
}

# Settings persistence
$script:SettingsPath = Join-Path $PSScriptRoot 'settings.json'

function Load-Settings {
    try {
        if (Test-Path -LiteralPath $script:SettingsPath) {
            return (Get-Content -LiteralPath $script:SettingsPath -Raw | ConvertFrom-Json)
        }
    } catch {}
    return $null
}

function Save-Settings {
    try {
        $settings = [ordered]@{
            Window      = [ordered]@{
                Width  = [int]$window.ActualWidth
                Height = [int]$window.ActualHeight
                Left   = [int]$window.Left
                Top    = [int]$window.Top
            }
            Source      = $SourcePath.Text
            Destination = $DestinationPath.Text
            LogPath     = $LogPath.Text
            Options     = [ordered]@{
                Mirror = [bool]$ChkMirror.IsChecked
                Move   = [bool]$ChkMove.IsChecked
                Purge  = [bool]$ChkPurge.IsChecked
                E      = [bool]$ChkE.IsChecked
                XO     = [bool]$ChkXO.IsChecked
                XN     = [bool]$ChkXN.IsChecked
                R      = [bool]$ChkR.IsChecked
                MT     = [bool]$ChkMT.IsChecked
                DryRun = [bool]$ChkDryRun.IsChecked
                Log    = [bool]$ChkLog.IsChecked
            }
        }
        $settings | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $script:SettingsPath -Encoding UTF8
    } catch {}
}

# Sweep stale temp files from prior crashes (>1 day old)
try {
    Get-ChildItem -Path $env:TEMP -Filter 'RoboCopyGUI_*.ps1' -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-1) } |
        Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $env:TEMP -Filter 'RoboCopyGUI_*.done' -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-1) } |
        Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $env:TEMP -Filter 'RoboCopyGUI_*.job.json' -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-1) } |
        Remove-Item -Force -ErrorAction SilentlyContinue
} catch {}

# Create the WPF window
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Robocopy GUI" Height="560" Width="700">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>

        <TextBlock Grid.Row="0" Grid.Column="0" Margin="10" VerticalAlignment="Center">Source Path:</TextBlock>
        <TextBox Name="SourcePath" Grid.Row="0" Grid.Column="1" Margin="10"/>
        <Button Name="BtnBrowseSrc" Grid.Row="0" Grid.Column="2" Margin="10" Width="80" Content="Browse..."/>

        <TextBlock Grid.Row="1" Grid.Column="0" Margin="10" VerticalAlignment="Center">Destination Path:</TextBlock>
        <TextBox Name="DestinationPath" Grid.Row="1" Grid.Column="1" Margin="10"/>
        <Button Name="BtnBrowseDst" Grid.Row="1" Grid.Column="2" Margin="10" Width="80" Content="Browse..."/>

        <StackPanel Grid.Row="2" Grid.Column="0" Grid.ColumnSpan="3" Margin="10">
            <CheckBox Name="ChkMirror" Content="Mirror (Deletes files not in the source)" ToolTip="Mirrors a directory tree (deletes files not in the source)."/>
            <CheckBox Name="ChkMove" Content="Move (Move files and directories)" ToolTip="Moves files and directories, deleting them from the source after they are copied."/>
            <CheckBox Name="ChkPurge" Content="Purge (Delete destination files/dirs that no longer exist in source)" ToolTip="Deletes destination files/dirs that no longer exist in the source."/>
            <CheckBox Name="ChkE" Content="E (Copies subdirectories, including empty ones)" ToolTip="Copies all subdirectories, including empty ones."/>
            <CheckBox Name="ChkXO" Content="XO (Excludes older files)" ToolTip="Excludes older files (files that are older in the destination)."/>
            <CheckBox Name="ChkXN" Content="XN (Excludes newer files)" ToolTip="Excludes newer files (files that are newer in the destination)."/>
            <CheckBox Name="ChkR" Content="R (Retries on failed copies)" ToolTip="Specifies the number of retries on failed copies."/>
            <CheckBox Name="ChkMT" Content="MT (Multi-threaded, 8 threads)" ToolTip="Uses 8 threads for multi-threaded copying."/>
            <CheckBox Name="ChkDryRun" Content="Dry Run /L (preview only, no changes)" ToolTip="Lists files that would be copied without actually copying them."/>
            <Separator Margin="0,6,0,6"/>
            <CheckBox Name="ChkLog" Content="Log to file" ToolTip="Write Robocopy output to a log file."/>
            <TextBox Name="LogPath" Margin="0,2,0,0" ToolTip="Optional: path to log file. If empty, defaults to Destination\robocopy.log."/>
        </StackPanel>

        <!-- Status display section -->
        <TextBlock Name="StatusText" Grid.Row="3" Grid.Column="0" Grid.ColumnSpan="3" Margin="10" FontWeight="Bold">Ready</TextBlock>
        <ProgressBar Name="ProgressBar" Grid.Row="4" Grid.Column="0" Grid.ColumnSpan="3" Margin="10" Height="20" Minimum="0" Maximum="100" Value="0" IsIndeterminate="False"/>

        <StackPanel Grid.Row="5" Grid.Column="0" Grid.ColumnSpan="3" Margin="10" HorizontalAlignment="Right" Orientation="Horizontal">
            <Button Name="BtnCancel" Width="100" Margin="0,0,10,0" Content="Cancel" IsEnabled="False"/>
            <Button Name="BtnRun" Width="100" Content="Run"/>
        </StackPanel>
    </Grid>
</Window>
"@

# Load the XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Update window title with version
$window.Title = "Robocopy GUI v$script:Version"

# Assign variables to the controls
$SourcePath = $window.FindName("SourcePath")
$DestinationPath = $window.FindName("DestinationPath")
$BtnBrowseSrc = $window.FindName("BtnBrowseSrc")
$BtnBrowseDst = $window.FindName("BtnBrowseDst")
$ChkMirror = $window.FindName("ChkMirror")
$ChkMove = $window.FindName("ChkMove")
$ChkPurge = $window.FindName("ChkPurge")
$ChkE = $window.FindName("ChkE")
$ChkXO = $window.FindName("ChkXO")
$ChkXN = $window.FindName("ChkXN")
$ChkR = $window.FindName("ChkR")
$ChkMT = $window.FindName("ChkMT")
$ChkDryRun = $window.FindName("ChkDryRun")
$ChkLog = $window.FindName("ChkLog")
$LogPath = $window.FindName("LogPath")
$BtnRun = $window.FindName("BtnRun")
$BtnCancel = $window.FindName("BtnCancel")
$StatusText = $window.FindName("StatusText")
$ProgressBar = $window.FindName("ProgressBar")

$ProgressBar.IsIndeterminate = $false

# Apply saved settings
$saved = Load-Settings
if ($saved) {
    if ($saved.Source)      { $SourcePath.Text = $saved.Source }
    if ($saved.Destination) { $DestinationPath.Text = $saved.Destination }
    if ($saved.LogPath)     { $LogPath.Text = $saved.LogPath }
    if ($saved.Options) {
        if ($null -ne $saved.Options.Mirror) { $ChkMirror.IsChecked = [bool]$saved.Options.Mirror }
        if ($null -ne $saved.Options.Move)   { $ChkMove.IsChecked   = [bool]$saved.Options.Move }
        if ($null -ne $saved.Options.Purge)  { $ChkPurge.IsChecked  = [bool]$saved.Options.Purge }
        if ($null -ne $saved.Options.E)      { $ChkE.IsChecked      = [bool]$saved.Options.E }
        if ($null -ne $saved.Options.XO)     { $ChkXO.IsChecked     = [bool]$saved.Options.XO }
        if ($null -ne $saved.Options.XN)     { $ChkXN.IsChecked     = [bool]$saved.Options.XN }
        if ($null -ne $saved.Options.R)      { $ChkR.IsChecked     = [bool]$saved.Options.R }
        if ($null -ne $saved.Options.MT)     { $ChkMT.IsChecked    = [bool]$saved.Options.MT }
        if ($null -ne $saved.Options.DryRun) { $ChkDryRun.IsChecked = [bool]$saved.Options.DryRun }
        if ($null -ne $saved.Options.Log)    { $ChkLog.IsChecked   = [bool]$saved.Options.Log }
    }
    if ($saved.Window) {
        if ($saved.Window.Width -gt 0)  { $window.Width  = $saved.Window.Width }
        if ($saved.Window.Height -gt 0) { $window.Height = $saved.Window.Height }
        if ($saved.Window.Left -ge 0)   { $window.Left   = $saved.Window.Left }
        if ($saved.Window.Top -ge 0)    { $window.Top    = $saved.Window.Top }
    }
}

# Run-state tracking
$script:process = $null
$script:tempScriptPath = $null
$script:doneFile = $null
$script:jobFile = $null
$script:doneProcessed = $false
$script:cancelRequested = $false

# UI update timer
$updateUI = [System.Windows.Threading.DispatcherTimer]::new()
$updateUI.Interval = [TimeSpan]::FromMilliseconds(500)

$updateUI.Add_Tick({
    # Robocopy finished: a done sentinel exists (even before console keypress)
    if (-not $script:doneProcessed -and $script:doneFile -and (Test-Path -LiteralPath $script:doneFile)) {
        $exitCode = 0
        try { $exitCode = [int](Get-Content -LiteralPath $script:doneFile -Raw).Trim() } catch {}
        if ($exitCode -lt 8) {
            $StatusText.Text = "Completed (exit code $exitCode)"
        } else {
            $StatusText.Text = "Completed with errors (exit code $exitCode)"
        }
        $ProgressBar.IsIndeterminate = $false
        $ProgressBar.Value = 100
        if ($script:CanToast) {
            if ($script:ToastLogo) {
                New-BurntToastNotification -Text "RoboCopy Transfer", "File transfer completed (exit code $exitCode)." -AppLogo $script:ToastLogo -ErrorAction SilentlyContinue
            } else {
                New-BurntToastNotification -Text "RoboCopy Transfer", "File transfer completed (exit code $exitCode)." -ErrorAction SilentlyContinue
            }
        }
        $BtnRun.IsEnabled = $true
        $BtnCancel.IsEnabled = $false
        $script:doneProcessed = $true
    }

    # When the console process has fully exited, finalize cleanup
    if ($null -eq $script:process -or $script:process.HasExited) {
        $updateUI.Stop()
        if (-not $script:doneProcessed) {
            if ($script:cancelRequested) {
                $StatusText.Text = "Cancelled"
            } else {
                $StatusText.Text = "Process ended"
            }
            $ProgressBar.IsIndeterminate = $false
            $ProgressBar.Value = 0
            $BtnRun.IsEnabled = $true
            $BtnCancel.IsEnabled = $false
        }
        if ($script:tempScriptPath) { try { Remove-Item -LiteralPath $script:tempScriptPath -ErrorAction SilentlyContinue } catch {} }
        if ($script:doneFile)        { try { Remove-Item -LiteralPath $script:doneFile -ErrorAction SilentlyContinue } catch {} }
        if ($script:jobFile)         { try { Remove-Item -LiteralPath $script:jobFile -ErrorAction SilentlyContinue } catch {} }
        $script:process = $null
        $script:tempScriptPath = $null
        $script:doneFile = $null
        $script:jobFile = $null
        $script:doneProcessed = $false
        $script:cancelRequested = $false
    } else {
        if (-not $script:doneProcessed) {
            $StatusText.Text = "RoboCopy is running in PowerShell window..."
        }
    }
})

# Define the event handler for the Run button
$BtnRun.Add_Click({
    $src = $SourcePath.Text
    $dst = $DestinationPath.Text

    # Validate input paths
    if (-not $src -or -not $dst) {
        [System.Windows.MessageBox]::Show("Please specify both source and destination paths.", "Input Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        return
    }

    if (-not (Test-Path -LiteralPath $src)) {
        [System.Windows.MessageBox]::Show("Source path does not exist.", "Path Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        return
    }

    if (-not (Test-Path -LiteralPath $dst)) {
        $resp = [System.Windows.MessageBox]::Show("Destination path does not exist. Robocopy can create it. Continue?", "Destination Missing", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ($resp -ne [System.Windows.MessageBoxResult]::Yes) { return }
    }

    # Warn if Mirror and Move both selected
    if ($ChkMirror.IsChecked -and $ChkMove.IsChecked) {
        $resp = [System.Windows.MessageBox]::Show("Mirror (/MIR) and Move (/MOV) have conflicting intents. MIR copies, MOV deletes source. Continue?", "Option Warning", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ($resp -ne [System.Windows.MessageBoxResult]::Yes) { return }
    }

    # Build options array (injection-safe; passed via job file, not interpolated)
    $opts = @()
    if ($ChkMirror.IsChecked) { $opts += '/MIR' }
    if ($ChkMove.IsChecked)   { $opts += '/MOV' }
    if ($ChkPurge.IsChecked)  { $opts += '/PURGE' }
    if ($ChkE.IsChecked)      { $opts += '/E' }
    if ($ChkXO.IsChecked)     { $opts += '/XO' }
    if ($ChkXN.IsChecked)     { $opts += '/XN' }
    if ($ChkR.IsChecked)      { $opts += '/R:5' }
    if ($ChkMT.IsChecked)     { $opts += '/MT:8' }
    if ($ChkDryRun.IsChecked) { $opts += '/L' }
    $logFile = ''
    if ($ChkLog.IsChecked) {
        $logFile = $LogPath.Text
        if (-not $logFile) { $logFile = Join-Path -Path $dst -ChildPath 'robocopy.log' }
        $opts += "/LOG:$logFile"
    }
    $opts += '/bytes'
    $opts += '/v'
    $opts += '/eta'

    # Update UI to show that a transfer is starting
    $StatusText.Text = "Starting transfer..."
    $ProgressBar.IsIndeterminate = $true
    $ProgressBar.Value = 0
    $BtnRun.IsEnabled = $false
    $BtnCancel.IsEnabled = $true

    # Display start toast notification
    if ($script:CanToast) {
        if ($script:ToastLogo) {
            New-BurntToastNotification -Text "RoboCopy Transfer", "Starting file transfer from $src to $dst" -AppLogo $script:ToastLogo -ErrorAction SilentlyContinue
        } else {
            New-BurntToastNotification -Text "RoboCopy Transfer", "Starting file transfer from $src to $dst" -ErrorAction SilentlyContinue
        }
    }

    # Create temp paths
    $script:tempScriptPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "RoboCopyGUI_$(Get-Random).ps1")
    $script:doneFile       = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "RoboCopyGUI_$(Get-Random).done")
    $script:jobFile        = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "RoboCopyGUI_$(Get-Random).job.json")
    $script:doneProcessed  = $false
    $script:cancelRequested = $false

    # Write job config (injection-safe: user data lives in a file, not in script source)
    $job = [ordered]@{
        Source      = $src
        Destination = $dst
        Options     = $opts
        LogFile     = $logFile
        DoneFile    = $script:doneFile
    }
    $job | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $script:jobFile -Encoding UTF8

    # Fixed-template temp script (no user data interpolated into source)
    $template = @'
param([string]$JobFile)
$job = Get-Content -LiteralPath $JobFile -Raw | ConvertFrom-Json
$host.UI.RawUI.WindowTitle = "RoboCopy Transfer"
$roboArgs = @($job.Source, $job.Destination) + @($job.Options)
Write-Host ('Executing: robocopy ' + ($roboArgs -join ' ')) -ForegroundColor Yellow
Write-Host 'The window will remain open until you press a key after the transfer completes...' -ForegroundColor Cyan
Write-Host ''
try {
    & robocopy @roboArgs
    $exitCode = $LASTEXITCODE
} catch {
    $exitCode = 16
    Write-Host "Failed to launch robocopy: $_" -ForegroundColor Red
}
try { Set-Content -LiteralPath $job.DoneFile -Value $exitCode -ErrorAction Stop } catch {}
Write-Host ''
if ($exitCode -lt 8) {
    Write-Host "Transfer completed successfully with exit code $exitCode" -ForegroundColor Green
} else {
    Write-Host "Transfer encountered errors with exit code $exitCode" -ForegroundColor Red
}
switch ($exitCode) {
    0 { Write-Host "No files were copied. No failure was encountered. No files were mismatched." -ForegroundColor Gray }
    1 { Write-Host "All files were copied successfully." -ForegroundColor Green }
    2 { Write-Host "Extra files or directories were detected in the destination." -ForegroundColor Yellow }
    3 { Write-Host "Some files were copied. Additional files were present." -ForegroundColor Yellow }
    4 { Write-Host "Some mismatched files or directories were detected." -ForegroundColor Yellow }
    5 { Write-Host "Some files were copied. Some files were mismatched." -ForegroundColor Yellow }
    6 { Write-Host "Additional files and mismatched files exist." -ForegroundColor Yellow }
    7 { Write-Host "Files were copied; a file mismatch was present; additional files were present." -ForegroundColor Yellow }
    8 { Write-Host "At least one file did not copy." -ForegroundColor Red }
    16 { Write-Host "Robocopy did not run: serious error or bad arguments." -ForegroundColor Red }
    default { Write-Host "Exit code $exitCode (combination of the above flags)." -ForegroundColor Yellow }
}
Write-Host ""
Write-Host "Press any key to close this window..." -ForegroundColor Cyan
$null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
'@

    Set-Content -LiteralPath $script:tempScriptPath -Value $template -Encoding UTF8

    # Start PowerShell with the script file (paths quoted; job file carries all data)
    $argString = "-NoProfile -ExecutionPolicy Bypass -STA -File `"$($script:tempScriptPath)`" -JobFile `"$($script:jobFile)`""
    $script:process = Start-Process -FilePath "powershell.exe" -PassThru -WindowStyle Normal -ArgumentList $argString

    # Start the UI update timer
    $updateUI.Start()
})

# Cancel button: kill the robocopy process tree
$BtnCancel.Add_Click({
    if ($script:process -and -not $script:doneProcessed -and -not $script:process.HasExited) {
        $script:cancelRequested = $true
        $StatusText.Text = "Cancelling..."
        try {
            & taskkill /T /F /PID $script:process.Id 2>$null
        } catch {
            try { Stop-Process -Id $script:process.Id -Force -ErrorAction SilentlyContinue } catch {}
        }
    }
})

# Browse buttons
$BtnBrowseSrc.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select source folder"
    if ($SourcePath.Text -and (Test-Path -LiteralPath $SourcePath.Text)) {
        $dialog.SelectedPath = $SourcePath.Text
    }
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $SourcePath.Text = $dialog.SelectedPath
    }
})

$BtnBrowseDst.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select destination folder"
    if ($DestinationPath.Text -and (Test-Path -LiteralPath $DestinationPath.Text)) {
        $dialog.SelectedPath = $DestinationPath.Text
    }
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $DestinationPath.Text = $dialog.SelectedPath
    }
})

# Window close guard: save settings, warn if running, clean up temp files
$window.Add_Closing({
    param($sender, $e)
    Save-Settings
    if ($script:process -and -not $script:doneProcessed -and -not $script:process.HasExited) {
        $resp = [System.Windows.MessageBox]::Show("A transfer is running. Cancel it and close the window?", "Transfer Running", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ($resp -ne [System.Windows.MessageBoxResult]::Yes) {
            $e.Cancel = $true
            return
        }
        try { & taskkill /T /F /PID $script:process.Id 2>$null } catch {}
    }
    if ($script:tempScriptPath) { try { Remove-Item -LiteralPath $script:tempScriptPath -ErrorAction SilentlyContinue } catch {} }
    if ($script:doneFile)        { try { Remove-Item -LiteralPath $script:doneFile -ErrorAction SilentlyContinue } catch {} }
    if ($script:jobFile)         { try { Remove-Item -LiteralPath $script:jobFile -ErrorAction SilentlyContinue } catch {} }
})

# Show the window
$window.ShowDialog()
