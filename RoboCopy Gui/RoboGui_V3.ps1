# Load required assemblies
Add-Type -AssemblyName PresentationFramework

# Import BurntToast module for toast notifications
Import-Module BurntToast

# Create the WPF window
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Robocopy GUI" Height="500" Width="700">
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
        </Grid.ColumnDefinitions>

        <TextBlock Grid.Row="0" Grid.Column="0" Margin="10" VerticalAlignment="Center">Source Path:</TextBlock>
        <TextBox Name="SourcePath" Grid.Row="0" Grid.Column="1" Margin="10"/>

        <TextBlock Grid.Row="1" Grid.Column="0" Margin="10" VerticalAlignment="Center">Destination Path:</TextBlock>
        <TextBox Name="DestinationPath" Grid.Row="1" Grid.Column="1" Margin="10"/>

        <StackPanel Grid.Row="2" Grid.Column="0" Grid.ColumnSpan="2" Margin="10">
            <CheckBox Name="ChkMirror" Content="Mirror (Deletes files not in the source)" ToolTip="Mirrors a directory tree (deletes files not in the source)."/>
            <CheckBox Name="ChkMove" Content="Move (Move files and directories)" ToolTip="Moves files and directories, deleting them from the source after they are copied."/>
            <CheckBox Name="ChkPurge" Content="Purge (Delete destination files/dirs that no longer exist in source)" ToolTip="Deletes destination files/dirs that no longer exist in the source."/>
            <CheckBox Name="ChkE" Content="E (Copies subdirectories, including empty ones)" ToolTip="Copies all subdirectories, including empty ones."/>
            <CheckBox Name="ChkXO" Content="XO (Excludes older files)" ToolTip="Excludes older files (files that are older in the destination)."/>
            <CheckBox Name="ChkXN" Content="XN (Excludes newer files)" ToolTip="Excludes newer files (files that are newer in the destination)."/>
            <CheckBox Name="ChkR" Content="R (Retries on failed copies)" ToolTip="Specifies the number of retries on failed copies."/>
        </StackPanel>

        <!-- Status display section -->
        <TextBlock Name="StatusText" Grid.Row="3" Grid.Column="0" Grid.ColumnSpan="2" Margin="10" FontWeight="Bold">Ready</TextBlock>
        <ProgressBar Name="ProgressBar" Grid.Row="4" Grid.Column="0" Grid.ColumnSpan="2" Margin="10" Height="20" Minimum="0" Maximum="100" Value="0"/>
        
        <Button Name="BtnRun" Grid.Row="5" Grid.Column="1" Margin="10" HorizontalAlignment="Right" Width="100">Run</Button>
    </Grid>
</Window>
"@

# Load the XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Assign variables to the controls
$SourcePath = $window.FindName("SourcePath")
$DestinationPath = $window.FindName("DestinationPath")
$ChkMirror = $window.FindName("ChkMirror")
$ChkMove = $window.FindName("ChkMove")
$ChkPurge = $window.FindName("ChkPurge")
$ChkE = $window.FindName("ChkE")
$ChkXO = $window.FindName("ChkXO")
$ChkXN = $window.FindName("ChkXN")
$ChkR = $window.FindName("ChkR")
$BtnRun = $window.FindName("BtnRun")
$StatusText = $window.FindName("StatusText")
$ProgressBar = $window.FindName("ProgressBar")

# Function to check if the PowerShell process is still running
$updateUI = [System.Windows.Threading.DispatcherTimer]::new()
$updateUI.Interval = [TimeSpan]::FromMilliseconds(1000)
$updateUI.Add_Tick({
    if ($script:process -and !$script:process.HasExited) {
        # Process is still running, update status
        $StatusText.Text = "RoboCopy is running in PowerShell window..."
    } else {
        # Process has completed
        $updateUI.Stop()
        $StatusText.Text = "Transfer completed!"
        $ProgressBar.Value = 100
        
        # Display completion toast notification
        New-BurntToastNotification -Text "RoboCopy Transfer", "File transfer completed successfully!" -AppLogo "$PSScriptRoot\robocopy-icon.png" -ErrorAction SilentlyContinue
        
        # Re-enable the Run button
        $BtnRun.IsEnabled = $true
        
        # Clean up the process reference
        $script:process = $null
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

    # Construct the Robocopy command
    $options = ""
    if ($ChkMirror.IsChecked) { $options += "/MIR " }
    if ($ChkMove.IsChecked) { $options += "/MOV " }
    if ($ChkPurge.IsChecked) { $options += "/PURGE " }
    if ($ChkE.IsChecked) { $options += "/E " }
    if ($ChkXO.IsChecked) { $options += "/XO " }
    if ($ChkXN.IsChecked) { $options += "/XN " }
    if ($ChkR.IsChecked) { $options += "/R:5 " }
    
    # Add progress monitoring options
    $options += "/bytes /v /eta "
    
    $command = "Robocopy `"$src`" `"$dst`" $options"
    Write-Output "Executing: $command"
    
    # Update UI to show that a transfer is starting
    $StatusText.Text = "Starting transfer..."
    $ProgressBar.Value = 0
    $BtnRun.IsEnabled = $false
    
    # Display start toast notification
    New-BurntToastNotification -Text "RoboCopy Transfer", "Starting file transfer from $src to $dst" -AppLogo "$PSScriptRoot\robocopy-icon.png" -ErrorAction SilentlyContinue
    
        # Create a PowerShell script file to execute
    $tempScriptPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "RoboCopyGUI_$(Get-Random).ps1")
    
    # Write the script content to the temp file
    @"
# Set window title
`$host.UI.RawUI.WindowTitle = "RoboCopy Transfer: $src to $dst"

# Display the command being executed
Write-Host "Executing: $command" -ForegroundColor Yellow
Write-Host "The window will remain open until you press a key after the transfer completes..." -ForegroundColor Cyan
Write-Host ""

# Execute the command
$command

# Check the exit code to determine success
`$exitCode = `$LASTEXITCODE
Write-Host ""
if (`$exitCode -lt 8) {
    Write-Host "Transfer completed successfully with exit code `$exitCode" -ForegroundColor Green
} else {
    Write-Host "Transfer encountered errors with exit code `$exitCode" -ForegroundColor Red
}

# Explain the exit code
switch (`$exitCode) {
    0 { Write-Host "No files were copied. No failure was encountered. No files were mismatched." -ForegroundColor Gray }
    1 { Write-Host "All files were copied successfully." -ForegroundColor Green }
    2 { Write-Host "Extra files or directories were detected in the destination." -ForegroundColor Yellow }
    3 { Write-Host "Some files were copied. Additional files were present." -ForegroundColor Yellow }
    4 { Write-Host "Some mismatched files or directories were detected." -ForegroundColor Yellow }
    5 { Write-Host "Some files were copied. Some files were mismatched." -ForegroundColor Yellow }
    6 { Write-Host "Additional files and mismatched files exist." -ForegroundColor Yellow }
    7 { Write-Host "Files were copied, a file mismatch was present, and additional files were present." -ForegroundColor Yellow }
    8 { Write-Host "Several files did not copy." -ForegroundColor Red }
    default { Write-Host "Serious error. Error code `$exitCode." -ForegroundColor Red }
}

Write-Host ""
Write-Host "Press any key to close this window..." -ForegroundColor Cyan

# Wait for a key press before closing
`$null = `$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
"@ | Out-File -FilePath $tempScriptPath -Encoding utf8
    
    # Start PowerShell with the script file
    $script:process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy", "Bypass", "-File", $tempScriptPath -PassThru
    
    # Start the UI update timer
    $updateUI.Start()
})

# Show the window
$window.ShowDialog()
