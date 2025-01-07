<#
    .SYNOPSIS
        Installs JumpCloud or NinjaOne agent based on device serial number match from remote configuration
    .NOTES
        Min OS: Windows 10+
        Context: SYSTEM (PPKG)
        Exit Codes: 
            0 = Success
            1 = Internet connection failed
            2 = Serial number not found in config
            3 = Invalid MDM type
            4 = Installation failed
#>

# Get system serial number using CIMInstance
try {
    $serialNumber = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber
    Write-Host "Device Serial Number: $serialNumber"
} catch {
    Write-Error "Failed to get system serial number: $_"
    exit 1
}

# Configuration
$configUrl = "YOUR_GIST_URL_HERE"
$maxAttempts = 5
$retryDelay = 10

# Function to test connection and get config
function Get-RemoteConfig {
    param ($url)
    try {
        $config = Invoke-RestMethod -Uri $url -Method Get -UseBasicParsing
        return @{
            success = $true
            data = $config
        }
    } catch {
        return @{
            success = $false
            error = $_
        }
    }
}

# Attempt to get configuration
$attempt = 1
$configResult = $null

while ($attempt -le $maxAttempts) {
    Write-Host "Attempting to fetch configuration (Attempt $attempt of $maxAttempts)..."
    $configResult = Get-RemoteConfig -url $configUrl
    
    if ($configResult.success) {
        break
    }
    
    Write-Host "Failed to fetch configuration. Retrying in $retryDelay seconds..."
    Start-Sleep -Seconds $retryDelay
    $attempt++
}

if (-not $configResult.success) {
    Write-Error "Failed to establish connection after $maxAttempts attempts."
    exit 1
}

# Find matching device configuration
$deviceConfig = $configResult.data.devices | Where-Object { $_.serialNumber -eq $serialNumber }

if (-not $deviceConfig) {
    Write-Error "Device with serial number $serialNumber not found in configuration"
    exit 2
}

# Install based on MDM type
switch ($deviceConfig.mdmType) {
    "JumpCloud" {
        try {
            $installerPath = Join-Path $env:TEMP "InstallWindowsAgent.ps1"
            Invoke-RestMethod -Method Get -Uri "https://raw.githubusercontent.com/TheJumpCloud/support/master/scripts/windows/InstallWindowsAgent.ps1" -OutFile $installerPath
            
            # Execute installer with token from config
            & $installerPath -JumpCloudConnectKey $deviceConfig.installation.value
            
            # Cleanup
            Remove-Item $installerPath -Force
        } catch {
            Write-Error "JumpCloud installation failed: $_"
            exit 4
        }
    }
    "NinjaOne" {
        try {
            $installerPath = Join-Path $env:TEMP "NinjaOneInstaller.msi"
            Invoke-WebRequest -Uri $deviceConfig.installation.value -OutFile $installerPath
            
            # Install NinjaOne agent
            $result = Start-Process msiexec.exe -ArgumentList "/i `"$installerPath`" /qn" -Wait -PassThru
            
            # Cleanup
            Remove-Item $installerPath -Force
            
            if ($result.ExitCode -ne 0) {
                throw "MSI installation failed with exit code: $($result.ExitCode)"
            }
        } catch {
            Write-Error "NinjaOne installation failed: $_"
            exit 4
        }
    }
    default {
        Write-Error "Invalid MDM type: $($deviceConfig.mdmType)"
        exit 3
    }
}

Write-Host "Installation completed successfully"
exit 0