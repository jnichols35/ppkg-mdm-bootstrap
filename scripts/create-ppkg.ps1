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
        - REMOTE_SCRIPT_URL environment variable set to the URL of the script to download at provisioning time
#>

# Error handling
$ErrorActionPreference = 'Stop'

# Paths
$wcdPath = Join-Path ${Env:ProgramFiles(x86)} "Windows Kits\10\Assessment and Deployment Kit\Imaging and Configuration Designer\x86\ICD.exe"
$agentScript = 'get-remote-script.ps1'
$agentScriptPath = Resolve-Path ".\scripts\$agentScript"
$adkInstallerPath = Join-Path $env:TEMP "adksetup.exe"

# Verify agent script exists
if (-not (Test-Path $agentScriptPath)) {
    Write-Error "Required script not found: $agentScriptPath"
    exit 3
}

# Resolve remote script URL from environment
$remoteScriptUrl = $env:REMOTE_SCRIPT_URL
if (-not $remoteScriptUrl) {
    Write-Host "ERROR: REMOTE_SCRIPT_URL environment variable is not set. Set it to the URL of the script the PPKG should download at provisioning time."
    exit 3
}

# Install Windows ADK with Configuration Designer if needed
if (-not (Test-Path $wcdPath)) {
    Write-Host "Installing Windows ADK with Configuration Designer..."
    try {
        # Download ADK installer
        Write-Host "Downloading Windows ADK installer..."
        $adkUrl = "https://go.microsoft.com/fwlink/?linkid=2196127"
        Invoke-WebRequest -Uri $adkUrl -OutFile $adkInstallerPath
        
        # Install ADK with required features
        Write-Host "Installing Windows ADK..."
        $process = Start-Process -FilePath $adkInstallerPath -ArgumentList "/quiet /features OptionId.ImagingAndConfigurationDesigner" -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -ne 0) {
            Write-Error "ADK installation failed with exit code: $($process.ExitCode)"
            exit 1
        }

        # Verify installation
        if (-not (Test-Path $wcdPath)) {
            Write-Error "ADK installation completed but WCD not found at: $wcdPath"
            exit 1
        }
        
        Write-Host "Windows ADK installed successfully"
    }
    catch {
        Write-Error "Failed to install Windows ADK: $_"
        exit 1
    }
    finally {
        # Cleanup installer
        Remove-Item -Path $adkInstallerPath -ErrorAction SilentlyContinue
    }
}

# Create working directory
$tempDir = Join-Path $env:TEMP "PPKGContent_$(Get-Random)"
$assetsDir = Join-Path $tempDir "Assets"

New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null

# Copy agent script to assets and inject the remote script URL
Copy-Item -Path $agentScriptPath -Destination $assetsDir
$agentScriptTarget = Join-Path $assetsDir $agentScript
(Get-Content -Raw -Path $agentScriptTarget).Replace('__REMOTE_SCRIPT_URL__', $remoteScriptUrl) |
    Set-Content -Path $agentScriptTarget -NoNewline

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
                <CommandFile>$($agentScriptPath.Path)</CommandFile>
                <CommandLine>PowerShell.exe -ExecutionPolicy Bypass -File $agentScript</CommandLine>
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

# Update store path for ADK installation
$storePath = Join-Path ${Env:ProgramFiles(x86)} "Windows Kits\10\Assessment and Deployment Kit\Imaging and Configuration Designer\x86\Microsoft-Desktop-Provisioning.dat"

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
