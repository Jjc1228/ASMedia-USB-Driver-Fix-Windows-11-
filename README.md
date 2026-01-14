# ASMedia USB Driver Fix (Windows 11)

A small PowerShell utility to install ASMedia USB 3.x controller/root hub drivers on Windows 11 using **pnputil** (INF-based install), which is often required when vendor installers refuse to run and Windows leaves the controller as an **Unknown Device** (e.g. `USB\ASMEDIAROOT_HUB\...`).

This script is built for the common “Upgraded to Windows 11 → USB-C ports stop working” scenario on systems using **ASMedia USB controllers** (frequently seen on older Intel chipsets/motherboards).

## What this fixes

Symptoms this script targets:

- USB-C ports stopped working after Windows 11 upgrade
- Device Manager shows **Unknown Device** / **ASMedia Root Hub** (`USB\ASMEDIAROOT_HUB`)
- Vendor EXE installer says **“This driver does not support your device.”**
- High-bandwidth USB devices (capture cards, etc.) won’t enumerate properly

Why it happens:
- Windows may bind a generic USB stack and/or partial device enumeration occurs.
- Vendor installers often require an exact hardware match and bail out.
- Windows Update can immediately replace a working driver with a generic one.

This script:
- Recursively scans an extracted driver folder for ASMedia-related `.inf` files
- Installs them using `pnputil /add-driver /install`
- Prioritizes known ASMedia INFs (`ASMTHUB3.inf`, `ASMTXHCI.inf`) if present
- Optionally disables Windows automatic driver retrieval to prevent reversion

## Requirements

- Windows 10/11
- PowerShell
- **Run as Administrator**
- Extracted ASMedia driver package containing `.inf` files (ZIP/EXE extracted)

> Note: You do NOT need Intel Driver & Support Assistant (IDSA) for this.  
> This is specifically for ASMedia USB controller/hub driver binding.

## Usage

1. Extract your ASMedia driver package to a folder, e.g.:
   `C:\Drivers\ASMedia\`

2. Save the script as:
   `Install-ASMediaUsb.ps1`

3. Open **PowerShell as Administrator** and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\Install-ASMediaUsb.ps1 -DriverRoot "C:\Drivers\ASMedia" -DisableAutoDriverInstall
