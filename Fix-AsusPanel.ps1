<#
.SYNOPSIS
  Registers the internal panel of an ASUS laptop (replaced screen) in ASUS software.

.DESCRIPTION
  After replacing the screen of an ASUS laptop, Armoury Crate shows "GameVisual may not be
  supported" and does not offer "Panel Power Saver". The reasons:
    1. ASUS Smart Display Control only switches refresh rates for panels in its list (FRQ_Config.txt).
    2. GameVisual looks for a colour profile named <MODEL>_<GPU>_<MANUFACTURER><PRODUCT>.icm.

  This script reads the panel data (EDID) and:
    - adds the panel to FRQ_Config.txt (backup saved first),
    - creates the .icm profile GameVisual expects, copying one that already exists on the laptop.

  Must be run as administrator. Restart the laptop afterwards.

.PARAMETER DryRun
  Only shows what would be done, changes nothing (does not require administrator).

.PARAMETER Undo
  Removes the panel line and deletes the profiles this script created.

.PARAMETER MaxHz
  Maximum refresh rate of the panel. Read from the EDID by default.

.PARAMETER SourceIcm
  Existing .icm profile to copy. Defaults to the first one found in the GameVisual folder.
#>
[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$Undo,
  [int]$MaxHz = 0,
  [string]$SourceIcm
)

$ErrorActionPreference = 'Stop'
$frq        = 'C:\ProgramData\ASUS\ASUS Smart Display Control\FRQ_Config.txt'
$gvDir      = 'C:\ProgramData\ASUS\GameVisual'
$icmTargets = @($gvDir, "$gvDir\Backup", 'C:\Windows\System32\spool\drivers\color\AsusICM')
$backupDir  = Join-Path $PSScriptRoot 'backup'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $DryRun) { throw 'Run this script as administrator (or use -DryRun to only preview).' }
if (-not (Test-Path $frq)) { throw "Cannot find $frq. Install ASUS Armoury Crate / Smart Display Control first." }

# --- Internal panel ------------------------------------------------------------------------
$internal = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorConnectionParams |
  Where-Object { $_.Active -and [uint32]$_.VideoOutputTechnology -eq 2147483648 } | Select-Object -First 1
if (-not $internal) { throw 'No active internal display found.' }
$instance = $internal.InstanceName -replace '_\d+$', ''

$edid = $null
foreach ($k in Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY' -Recurse -ErrorAction SilentlyContinue) {
  if ($k.PSChildName -eq 'Device Parameters') {
    $path = $k.Name -replace '^HKEY_LOCAL_MACHINE\\', ''
    $id = ($path -split '\\')[-3..-2] -join '\'
    if ($instance -like "DISPLAY\$id*") { $edid = (Get-ItemProperty $k.PSPath).EDID; break }
  }
}
if (-not $edid) { throw "Could not read the EDID of $instance." }

$mfr  = '{0:X2}{1:X2}' -f $edid[9],  $edid[8]
$prod = '{0:X2}{1:X2}' -f $edid[11], $edid[10]

if ($MaxHz -le 0) {
  foreach ($o in 54, 72, 90, 108) {
    if ($edid[$o] -eq 0 -and $edid[$o + 1] -eq 0 -and $edid[$o + 3] -eq 0xFD) { $MaxHz = $edid[$o + 6]; break }
  }
}
if ($MaxHz -le 0) { throw 'Could not read the maximum Hz from the EDID. Pass -MaxHz 144 (or your panel''s value).' }

$model = (((Get-CimInstance Win32_ComputerSystem).Model -split '_')[0] -split '\s+')[-1]
$line  = '{0},{1},{2},60' -f $mfr, $prod, $MaxHz

Write-Host "Internal panel : $instance"
Write-Host "Manufacturer   : $mfr   Product: $prod   Max Hz: $MaxHz"
Write-Host "Laptop model   : $model"
Write-Host "ASUS list line : $line"

# --- Undo ----------------------------------------------------------------------------------
if ($Undo) {
  if ($DryRun) { Write-Host '[DryRun] Would remove the line and the created .icm files.'; return }
  $lines = Get-Content $frq | Where-Object { $_.Trim() -ne $line }
  Set-Content $frq $lines
  foreach ($d in $icmTargets) {
    Get-ChildItem $d -Filter "${model}_*_${mfr}${prod}.icm" -ErrorAction SilentlyContinue | Remove-Item -Force
  }
  Write-Host 'Undone. Restart the laptop.'; return
}

# --- Panel list ----------------------------------------------------------------------------
$present = (Get-Content $frq) -contains $line
if ($DryRun) {
  Write-Host ("[DryRun] FRQ_Config.txt: " + $(if ($present) { 'already has the line.' } else { 'would add the line.' }))
} elseif (-not $present) {
  New-Item -ItemType Directory -Force $backupDir | Out-Null
  Copy-Item $frq (Join-Path $backupDir 'FRQ_Config.txt.bak') -Force
  $raw = Get-Content $frq -Raw
  if ($raw.Length -gt 0 -and -not $raw.EndsWith("`n")) { Add-Content $frq '' }
  Add-Content $frq $line
  Write-Host 'FRQ_Config.txt: line added.'
} else { Write-Host 'FRQ_Config.txt: already has the line.' }

# --- GameVisual colour profile -------------------------------------------------------------
foreach ($gpu in '8086', '10DE') {
  $name = "${model}_${gpu}_${mfr}${prod}.icm"
  $src = if ($SourceIcm) { $SourceIcm } else {
    Get-ChildItem $gvDir -Filter "${model}_${gpu}_*.icm" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
  }
  if (-not $src) { Write-Host "No source profile for GPU $gpu; skipping."; continue }
  foreach ($d in $icmTargets) {
    if (-not (Test-Path $d)) { continue }
    $dst = Join-Path $d $name
    if ($DryRun) { Write-Host "[DryRun] Would copy $(Split-Path $src -Leaf) -> $dst" }
    elseif (-not (Test-Path $dst)) { Copy-Item $src $dst; Write-Host "Created $dst" }
  }
}
if (-not $DryRun) { Write-Host 'Done. Restart the laptop.' }
