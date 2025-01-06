# Windows Provisioning Package Builder

This repository contains automation for building Windows Provisioning Packages (PPKG) that deploy MDM agents during Windows device setup.

## How it Works

The GitHub Action workflow automatically:
1. Runs on a Windows virtual machine
2. Installs the Windows Configuration Designer (WCD) tool
3. Creates a provisioning package that will:
   - Run during initial device setup
   - Execute the included PowerShell script
   - Handle MDM agent deployment
4. Publishes the PPKG file as a GitHub release with an auto-incrementing version number

## Requirements

- Windows 10 1809 or later
- Windows Configuration Designer (installed automatically)
- ~3GB free disk space for ADK installation
- Internet connectivity for WCD installation

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

## Exit Codes

- 0: Success
- 1: WCD Installation Failed
- 2: Package Creation Failed
- 3: Required Files Missing 