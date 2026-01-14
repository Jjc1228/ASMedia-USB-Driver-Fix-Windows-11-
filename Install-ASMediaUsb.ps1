<# 
ASMedia USB driver installer (Win11)
- Installs ASMedia USB hub/controller drivers from extracted INF files.
- Uses pnputil to add + install drivers.
- Optionally disables Windows automatic driver updates for devices.

USAGE:
1) Extract your ASMedia driver package somewhere (folder containing ASMTHUB3.inf / ASMTXHCI.inf).
2) Run PowerShell as Admin.
3) Example:
   .\Install-ASMediaUsb.ps1 -DriverRoot "C:\Drivers\ASMedia" -DisableAutoDriverInstall

#>

param(
  [Parameter(Mandatory=$true)]
  [string]$DriverRoot,

  [switch]$DisableAutoDriverInstall
)

function Assert-Admin {
  $isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
  ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

  if (-not $isAdmin) {
    Write-Error "Run this script as Administrator."
    exit 1
  }
}

function Set-DeviceInstallPolicy {
  param([bool]$Disable)

  # This is what the GUI "Device Installation Settings" flips in practice.
  # 0 = allow Windows Update drivers, 1 = do not allow
  $path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching"
  if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }

  $value = if ($Disable) { 0 } else { 1 }
  # SearchOrderConfig: 1 = search Windows Update, 0 = do not
  Set-ItemProperty -Path $path -Name "SearchOrderConfig" -Type DWord -Value $value

  if ($Disable) {
    Write-Host "Set Device Installation Settings: NO (do not download drivers from Windows Update)."
  } else {
    Write-Host "Set Device Installation Settings: YES (allow Windows Update drivers)."
  }
}

function Install-InfWithPnPUtil {
  param([string]$InfPath)

  if (-not (Test-Path $InfPath)) {
    Write-Warning "INF not found: $InfPath"
    return $false
  }

  Write-Host "`n==> Installing INF: $InfPath"
  $args = @("/add-driver", "`"$InfPath`"", "/install")
  $p = Start-Process -FilePath "pnputil.exe" -ArgumentList $args -NoNewWindow -PassThru -Wait

  if ($p.ExitCode -eq 0) {
    Write-Host "OK: pnputil succeeded for $InfPath"
    return $true
  } else {
    Write-Warning "pnputil exit code $($p.ExitCode) for $InfPath"
    return $false
  }
}

function Find-AsmediaInfs {
  param([string]$Root)

  if (-not (Test-Path $Root)) {
    Write-Error "DriverRoot does not exist: $Root"
    exit 1
  }

  # Prefer the known filenames but also catch any ASMedia-related INF
  $known = @("ASMTHUB3.inf","ASMTXHCI.inf")

  $foundKnown = @()
  foreach ($k in $known) {
    $m = Get-ChildItem -Path $Root -Recurse -Filter $k -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($m) { $foundKnown += $m.FullName }
  }

  $foundAsmedia = Get-ChildItem -Path $Root -Recurse -Filter "*.inf" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match "ASMT|ASMedia|ASMTHUB|ASMTXHCI" } |
    Select-Object -ExpandProperty FullName

  # De-dup while keeping known first
  $all = @($foundKnown + $foundAsmedia) | Select-Object -Unique
  return $all
}

function Show-AsmediaStatus {
  Write-Host "`n--- Current USB controller/hub status (ASMedia / xHCI) ---"
  # PnP device view:
  Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
    Where-Object { $_.FriendlyName -match "ASMedia|xHCI|USB Root Hub|USB Host Controller" -or $_.InstanceId -match "ASMEDIAROOT_HUB" } |
    Sort-Object Status, FriendlyName |
    Format-Table -AutoSize Status, Class, FriendlyName, InstanceId
}

# MAIN
Assert-Admin

Write-Host "Driver root: $DriverRoot"

if ($DisableAutoDriverInstall) {
  Set-DeviceInstallPolicy -Disable $true
}

$infs = Find-AsmediaInfs -Root $DriverRoot
if (-not $infs -or $infs.Count -eq 0) {
  Write-Error "No INF files found under: $DriverRoot"
  Write-Host "Make sure you've extracted the ASMedia driver package and point -DriverRoot at that folder."
  exit 1
}

Write-Host "`nINF files to install (in order):"
$infs | ForEach-Object { Write-Host " - $_" }

# Install known ones first if present
$ordered = @()
$hub = $infs | Where-Object { $_ -match "ASMTHUB3\.inf$" }
$xhci = $infs | Where-Object { $_ -match "ASMTXHCI\.inf$" }
$rest = $infs | Where-Object { $_ -notmatch "ASMTHUB3\.inf$|ASMTXHCI\.inf$" }

if ($hub)  { $ordered += $hub }
if ($xhci) { $ordered += $xhci }
$ordered += $rest

$successAny = $false
foreach ($inf in $ordered) {
  $ok = Install-InfWithPnPUtil -InfPath $inf
  if ($ok) { $successAny = $true }
}

Show-AsmediaStatus

if ($successAny) {
  Write-Host "`nDone. If the device still shows Unknown, reboot (full shutdown) and re-check."
  Write-Host "If it still won't bind, try temporarily disabling Memory Integrity (Core Isolation) and run again."
} else {
  Write-Warning "`nNo INF installed successfully. Capture the output above (pnputil exit codes) and paste it here."
}
