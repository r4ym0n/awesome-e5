#!/usr/bin/env pwsh
#Requires -Version 5.1
<#
.SYNOPSIS
    RongYue E5 full-flow guided run (interactive)
.DESCRIPTION
    Runs: env check -> backup -> flash -> root -> verify.
    Every step asks for confirmation; stops on first failure.
.EXAMPLE
    ./quickstart.ps1 -Rom E:\e5flash\rom
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Rom,
    [string]$BackupRoot = 'E:\e5flash\backup',
    [string]$OpenWrtPkg,
    [switch]$SkipFlash,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$cli  = Join-Path $here 'e5.ps1'

function Step([string]$n) {
    Write-Host ""
    Write-Host ("#" * 62) -ForegroundColor Magenta
    Write-Host "  $n" -ForegroundColor Magenta
    Write-Host ("#" * 62) -ForegroundColor Magenta
}

function Ask([string]$q) {
    if ($Yes) { return $true }
    $a = Read-Host "  $q (y/N)"
    return ($a -match '^(y|yes|Y|YES)$')
}

function Run([string[]]$cliArgs) {
    & $cli @cliArgs
    return $LASTEXITCODE
}

$promptBrom = @'
  On the phone:
    power off -> pull battery -> wait 3s -> put back
    -> hold BACK -> plug USB -> keep holding 10s
'@

$promptBoot = @'
  Unplug, put battery back, long-press power to boot (first boot is slow).
  After boot, connect USB and enable USB debugging.
'@

$promptPatch = @'
  On the phone now:
    Magisk -> Install -> Select and Patch a File
    -> Download/init_boot.img -> LET'S GO -> wait for "All done!"
'@

$promptGrant = @'
  Boot the phone and grant Shell superuser in the Magisk app.
'@

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue

Step '0/5  environment check'
if ((Run @('detect', '-Rom', $Rom)) -ne 0) {
    Write-Host "  environment not ready - fix the issues above first." -ForegroundColor Red
    exit 1
}
if (-not (Ask 'environment OK, continue?')) { exit 0 }

Step '1/5  full partition backup (read-only, required)'
$bk = Join-Path $BackupRoot (Get-Date -Format 'yyyyMMdd_HHmmss')
Write-Host "  backup to: $bk" -ForegroundColor White
Write-Host $promptBrom -ForegroundColor Yellow
if (-not (Ask 'ready?')) { exit 0 }

if ((Run @('backup', '-Rom', $Rom, '-Out', $bk, '-Timeout', '600')) -ne 0) {
    Write-Host "  backup failed - do NOT flash" -ForegroundColor Red
    exit 1
}
Write-Host "  backup complete: $bk" -ForegroundColor Green

if ($SkipFlash) {
    Write-Host "  -SkipFlash given, done." -ForegroundColor Gray
    exit 0
}

Step '2/5  flash mod ROM'
Write-Host "  this erases userdata (all user data)" -ForegroundColor Yellow
if (-not (Ask 'confirm flash?')) { exit 0 }

if ((Run @('flash', '-Rom', $Rom, '-Mode', 'full', '-Yes')) -ne 0) {
    Write-Host "  flash failed. If it disconnected mid-write:" -ForegroundColor Red
    Write-Host "  pull battery 10s -> back to BROM -> full reflash" -ForegroundColor Red
    exit 1
}

Step '3/5  boot and confirm unlock'
Write-Host $promptBoot -ForegroundColor White
Read-Host '  press Enter when booted' | Out-Null

if ((Run @('verify')) -ne 0) {
    Write-Host "  verification failed - check verifiedbootstate is orange" -ForegroundColor Red
    exit 1
}
Write-Host "  bootloader unlocked + AVB disabled" -ForegroundColor Green

Step '4/5  Magisk root'
$stock = Join-Path $Rom 'data\init_boot_a.bin'
if (-not (Test-Path $stock)) {
    Write-Host "  not found: $stock" -ForegroundColor Red
    exit 1
}

if ((Run @('magisk-prepare', '-Image', $stock)) -ne 0) { exit 1 }
Write-Host $promptPatch -ForegroundColor Yellow
Read-Host '  press Enter after patching' | Out-Null

$dest = Join-Path (Split-Path $BackupRoot -Parent) 'magisk'
if ((Run @('magisk-fetch', '-Dest', $dest)) -ne 0) { exit 1 }

$patched = Get-ChildItem $dest -Filter 'magisk_patched-*.img' -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $patched) {
    Write-Host "  patched image not found" -ForegroundColor Red
    exit 1
}

Write-Host "  next: enter BROM to write the patched image" -ForegroundColor Yellow
Write-Host $promptBrom -ForegroundColor Yellow
if (-not (Ask 'ready?')) { exit 0 }

if ((Run @('flash-initboot', '-Image', $patched.FullName, '-Rom', $Rom)) -ne 0) { exit 1 }

Write-Host $promptGrant -ForegroundColor White
Read-Host '  press Enter after granting' | Out-Null

if ((Run @('verify')) -ne 0) {
    Write-Host "  root not active - check the Magisk app" -ForegroundColor Red
    exit 1
}
Write-Host "  root active" -ForegroundColor Green

Step '5/5  OpenWrt (optional)'
if (-not $OpenWrtPkg) {
    Write-Host "  no -OpenWrtPkg given, skipping." -ForegroundColor Gray
    Write-Host "  later: ./e5.ps1 openwrt-tf -Package <dir> -CheckOnly" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  all done. device is rooted; UFI-TOOLS modules can be installed." -ForegroundColor Green
    exit 0
}

if (-not (Ask 'install OpenWrt to TF card? (erases the card)')) { exit 0 }

if ((Run @('openwrt-tf', '-Package', $OpenWrtPkg, '-CheckOnly')) -ne 0) {
    Write-Host "  preflight failed" -ForegroundColor Red
    exit 1
}
if ((Run @('openwrt-tf', '-Package', $OpenWrtPkg, '-Yes')) -ne 0) {
    Write-Host "  install failed. If 'SD capacity is insufficient':" -ForegroundColor Red
    Write-Host "  run ./e5.ps1 wipe-tf first, then retry" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "  install complete. reboot manually:" -ForegroundColor Green
Write-Host "  first reboot may fall back to Android (trial boot) -> reboot again" -ForegroundColor Green
Write-Host "  then: http://192.168.9.1   root / root" -ForegroundColor Green
