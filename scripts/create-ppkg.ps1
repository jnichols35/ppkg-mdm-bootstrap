<#
    .SYNOPSIS 
        Creates a Windows Provisioning Package that runs get-agent-info.ps1 during device setup
    .NOTES 
        Min OS: Windows 10 1809+ 
        Context: SYSTEM (PPKG)
        Exit Codes: 
            0 = Success
            1 = WCD Installation Failed
            2 = Package Creation Failed
            3 = Required Files Missing
    .REQUIREMENTS
        - Windows 10 1809+ with App Installer (winget)
        - ~3GB free disk space for ADK installation
        - Internet connectivity for WCD installation
#>

# Error handling
$ErrorActionPreference = 'Stop'

# Paths
$wcdPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\icd.exe"
$agentScript = Resolve-Path '.\scripts\get-agent-info.ps1'

# Verify agent script exists
if (-not (Test-Path $agentScript)) {
    Write-Error "Required script not found: $agentScript"
    exit 3
}

# Install Windows Configuration Designer if needed
if (-not (Test-Path $wcdPath)) {
    Write-Host "Checking Windows Configuration Designer installation..."
    try {
        # Verify winget availability
        if (-not (Get-Command 'winget' -ErrorAction SilentlyContinue)) {
            Write-Error "Winget not found. Please ensure Windows 10 1809+ with App Installer is installed."
            exit 1
        }

        # Check if WCD is already installed
        $wcdInstalled = winget list 9NBLGGH4TX22 | Select-String "Windows Configuration Designer"
        
        if (-not $wcdInstalled) {
            Write-Host "Installing Windows Configuration Designer..."
            # Install WCD
            $process = Start-Process -FilePath 'winget' `
                -ArgumentList "install --id 9NBLGGH4TX22 --silent --accept-source-agreements --accept-package-agreements" `
                -Wait -PassThru -NoNewWindow

            if ($process.ExitCode -ne 0) {
                Write-Error "WCD installation failed with exit code: $($process.ExitCode)"
                exit 1
            }
        }

        # Verify installation with new path
        if (-not (Test-Path $wcdPath)) {
            Write-Error "WCD installation completed but executable not found at: $wcdPath"
            exit 1
        }
    }
    catch {
        Write-Error "Failed to install WCD: $_"
        exit 1
    }
}

# Create working directory
$tempDir = Join-Path $env:TEMP "PPKGContent_$(Get-Random)"
$assetsDir = Join-Path $tempDir "Assets"

New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null

# Copy agent script to assets
Copy-Item -Path $agentScript -Destination $assetsDir

# Create customization XML
$customizationXml = @"
<?xml version="1.0" encoding="utf-8"?>
<WindowsCustomizations>
  <PackageConfig xmlns="urn:schemas-Microsoft-com:Windows-ICD-Package-Config.v1.0">
    <ID>{b25eb611-f61f-4788-b80e-319d8a6923b4}</ID>
    <Name>Deploy-MDM-Agent</Name>
    <Version>0.3</Version>
    <OwnerType>ITAdmin</OwnerType>
    <Rank>0</Rank>
    <Notes></Notes>
  </PackageConfig>
  <Settings xmlns="urn:schemas-microsoft-com:windows-provisioning">
    <Customizations>
      <Common>
        <ProvisioningCommands>
          <PrimaryContext>
            <Command>
              <CommandConfig Name="Install-MDM-Agent">
                <CommandFile>$($agentScript.Path)</CommandFile>
                <CommandLine>PowerShell.exe -ExecutionPolicy Bypass -File get-agent-info.ps1</CommandLine>
                <ContinueInstall>True</ContinueInstall>
              </CommandConfig>
            </Command>
          </PrimaryContext>
        </ProvisioningCommands>
      </Common>
    </Customizations>
  </Settings>
</WindowsCustomizations>
"@

# Save customization XML
$customizationXmlPath = Join-Path $tempDir "customizations.xml"
$customizationXml | Out-File -FilePath $customizationXmlPath -Encoding UTF8

$storePath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.WindowsConfigurationDesigner_*_*__8wekyb3d8bbwe\icd\Microsoft-Desktop-Provisioning.dat"

try {
    # Create output directory if it doesn't exist
    $outputDir = ".\output"
    New-Item -ItemType Directory -Path $outputDir -Force -ErrorAction SilentlyContinue | Out-Null
    
    $outputPath = Join-Path $outputDir "DeviceSetup.ppkg"
    
    # Create the provisioning package
    $process = Start-Process -FilePath $wcdPath `
        -ArgumentList "/Build-ProvisioningPackage /PackagePath:`"$outputPath`" /CustomizationXML:`"$customizationXmlPath`" /StoreFile:`"$storePath`" " `
        -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -ne 0) {
        Write-Error "Failed to create provisioning package (Exit code: $($process.ExitCode))"
        exit 2
    }
    
    Write-Host "Successfully created provisioning package at: $outputPath"
    exit 0
}
catch {
    Write-Error "Error creating provisioning package: $_"
    exit 2
}
finally {
    # Cleanup temp directory
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
