# PPKG MDM Bootstrap — Autopilot without Autopilot

This repository builds Windows Provisioning Packages (PPKG) that enroll new Windows devices into an MDM solution (e.g. JumpCloud or NinjaOne) during OOBE, without requiring Windows Autopilot or Intune. Devices launch into the standard Windows setup experience, and the MDM agent is installed automatically during initial device setup.

## How it Works

The GitHub Action workflow automatically:
1. Runs on a Windows virtual machine
2. Installs the Windows Configuration Designer (WCD) tool
3. Creates a provisioning package that will:
   - Run during initial device setup (OOBE)
   - Execute the included PowerShell script
   - Download and install the MDM agent for the device
4. Publishes the PPKG file as a GitHub release with an auto-incrementing version number

## Requirements

- Windows 10 1809 or later
- Windows Configuration Designer (installed automatically)
- ~3GB free disk space for ADK installation
- Internet connectivity for WCD installation
- A GitHub repository variable named `REMOTE_SCRIPT_URL` containing the URL of the PowerShell script the PPKG should download and run during device setup

## Release Versioning

Releases follow semantic versioning (MAJOR.MINOR.PATCH):
- Initial version starts at 0.0.1
- Each new build auto-increments the PATCH version
- Manual version changes can be made by creating a new tag

## Usage

### Automatic Builds
- Push to the `main` branch triggers a new build
- New release is created automatically with the PPKG file

### Manual Builds
1. Go to Actions tab
2. Select "Build PPKG" workflow
3. Click "Run workflow"

## Output

The action produces a `DeviceSetup.ppkg` file that can be used for Windows device provisioning.

> **Security note:** The generated PPKG downloads a PowerShell script at provisioning time (from the URL in the `REMOTE_SCRIPT_URL` variable) and executes it as `SYSTEM` on the target device. Only point the variable at content you control and trust, and keep the repository private if the URL exposes non-public resources.

## Exit Codes

- 0: Success
- 1: WCD Installation Failed
- 2: Package Creation Failed
- 3: Required Files Missing 