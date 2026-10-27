<#
.SYNOPSIS
  Registra el panel interno de un portatil ASUS (pantalla reemplazada) en el software de ASUS.

.DESCRIPTION
  Tras cambiar la pantalla de un portatil ASUS, Armoury Crate muestra "GameVisual puede que no
  se admita" y no ofrece "Ahorro de energia del panel". Los motivos:
    1. ASUS Smart Display Control solo cambia los Hz con paneles de su lista (FRQ_Config.txt).
    2. GameVisual busca un perfil de color con el nombre <MODELO>_<GPU>_<FABRICANTE><PRODUCTO>.icm.

  Este script lee los datos del panel (EDID) y:
    - agrega el panel a FRQ_Config.txt (con copia de respaldo),
    - crea el perfil .icm que GameVisual espera, copiando uno que ya exista en el equipo.

  Necesita ejecutarse como administrador. Reinicia el equipo al terminar.

.PARAMETER DryRun
  Solo muestra lo que haria, sin cambiar nada (no requiere administrador).

.PARAMETER Undo
  Quita la linea del panel y borra los perfiles que creo este script.

.PARAMETER MaxHz
  Frecuencia maxima del panel. Por defecto se lee del EDID.

.PARAMETER SourceIcm
  Perfil .icm existente a copiar. Por defecto, el primero que haya en la carpeta de GameVisual.
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
$backupDir  = Join-Path $PSScriptRoot 'respaldo'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $DryRun) { throw 'Ejecuta este script como administrador (o usa -DryRun para solo ver).' }
if (-not (Test-Path $frq)) { throw "No encuentro $frq. Instala ASUS Armoury Crate / Smart Display Control primero." }

# --- Panel interno -------------------------------------------------------------------------
$internal = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorConnectionParams |
  Where-Object { $_.Active -and [uint32]$_.VideoOutputTechnology -eq 2147483648 } | Select-Object -First 1
if (-not $internal) { throw 'No encontre una pantalla interna activa.' }
$instance = $internal.InstanceName -replace '_\d+$', ''

$edid = $null
foreach ($k in Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY' -Recurse -ErrorAction SilentlyContinue) {
  if ($k.PSChildName -eq 'Device Parameters') {
    $path = $k.Name -replace '^HKEY_LOCAL_MACHINE\\', ''
    $id = ($path -split '\\')[-3..-2] -join '\'
    if ($instance -like "DISPLAY\$id*") { $edid = (Get-ItemProperty $k.PSPath).EDID; break }
  }
}
if (-not $edid) { throw "No pude leer el EDID de $instance." }

$mfr  = '{0:X2}{1:X2}' -f $edid[9],  $edid[8]
$prod = '{0:X2}{1:X2}' -f $edid[11], $edid[10]

if ($MaxHz -le 0) {
  foreach ($o in 54, 72, 90, 108) {
    if ($edid[$o] -eq 0 -and $edid[$o + 1] -eq 0 -and $edid[$o + 3] -eq 0xFD) { $MaxHz = $edid[$o + 6]; break }
  }
}
if ($MaxHz -le 0) { throw 'No pude leer los Hz maximos del EDID. Indica -MaxHz 144 (o el valor de tu panel).' }

$model = (((Get-CimInstance Win32_ComputerSystem).Model -split '_')[0] -split '\s+')[-1]
$line  = '{0},{1},{2},60' -f $mfr, $prod, $MaxHz

Write-Host "Panel interno : $instance"
Write-Host "Fabricante    : $mfr   Producto: $prod   Hz max: $MaxHz"
Write-Host "Modelo equipo : $model"
Write-Host "Linea ASUS    : $line"

# --- Undo ----------------------------------------------------------------------------------
if ($Undo) {
  if ($DryRun) { Write-Host '[DryRun] Quitaria la linea y los .icm creados.'; return }
  $lines = Get-Content $frq | Where-Object { $_.Trim() -ne $line }
  Set-Content $frq $lines
  foreach ($d in $icmTargets) {
    Get-ChildItem $d -Filter "${model}_*_${mfr}${prod}.icm" -ErrorAction SilentlyContinue | Remove-Item -Force
  }
  Write-Host 'Deshecho. Reinicia el equipo.'; return
}

# --- Lista de paneles ----------------------------------------------------------------------
$present = (Get-Content $frq) -contains $line
if ($DryRun) {
  Write-Host ("[DryRun] FRQ_Config.txt: " + $(if ($present) { 'ya tiene la linea.' } else { 'agregaria la linea.' }))
} elseif (-not $present) {
  New-Item -ItemType Directory -Force $backupDir | Out-Null
  Copy-Item $frq (Join-Path $backupDir 'FRQ_Config.txt.bak') -Force
  $raw = Get-Content $frq -Raw
  if ($raw.Length -gt 0 -and -not $raw.EndsWith("`n")) { Add-Content $frq '' }
  Add-Content $frq $line
  Write-Host 'FRQ_Config.txt: linea agregada.'
} else { Write-Host 'FRQ_Config.txt: ya tenia la linea.' }

# --- Perfil de color de GameVisual ---------------------------------------------------------
foreach ($gpu in '8086', '10DE') {
  $name = "${model}_${gpu}_${mfr}${prod}.icm"
  $src = if ($SourceIcm) { $SourceIcm } else {
    Get-ChildItem $gvDir -Filter "${model}_${gpu}_*.icm" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
  }
  if (-not $src) { Write-Host "Sin perfil de origen para GPU $gpu; se omite."; continue }
  foreach ($d in $icmTargets) {
    if (-not (Test-Path $d)) { continue }
    $dst = Join-Path $d $name
    if ($DryRun) { Write-Host "[DryRun] Copiaria $(Split-Path $src -Leaf) -> $dst" }
    elseif (-not (Test-Path $dst)) { Copy-Item $src $dst; Write-Host "Creado $dst" }
  }
}
if (-not $DryRun) { Write-Host 'Listo. Reinicia el equipo.' }
