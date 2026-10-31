#Requires -Version 5.1
<#
.SYNOPSIS
    RongYue E5 (Unisoc T158) flashing toolkit - single entry CLI
.DESCRIPTION
    Wraps BROM backup, ROM flashing, Magisk root, module install, OpenWrt TF-card install.
    Every write operation has a validation gate; refuses to write when backup is missing.
.EXAMPLE
    ./e5.ps1 detect
    ./e5.ps1 wait-brom -Timeout 600
    ./e5.ps1 backup -Out E:\e5flash\backup\20261031
    ./e5.ps1 flash -Rom E:\e5flash\rom -Mode full
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('detect','wait-brom','backup','flash','flash-initboot',
                 'magisk-prepare','magisk-fetch','magisk-install',
                 'openwrt-tf','wipe-tf','probe','verify','reboot','help')]
    [string]$Command,

    [string]$Rom,
    [ValidateSet('full','keepdata','raw')]
    [string]$Mode = 'full',
    [string]$Out,
    [string]$Image,
    [string]$Module,
    [string]$Package,
    [string]$Ssid = 'E5-OpenWrt',
    [string]$Dest,
    [string]$SpdDir,
    [string]$BackupRoot,
    [string]$WorkDir,
    [int]$Timeout = 300,
    [switch]$CheckOnly,
    [switch]$Full,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'
$script:Failures = 0

# ---------------------------------------------------------------- helpers

function Write-Head([string]$t) {
    Write-Host ""
    Write-Host ("=" * 62) -ForegroundColor DarkCyan
    Write-Host "  $t" -ForegroundColor Cyan
    Write-Host ("=" * 62) -ForegroundColor DarkCyan
}
function Write-Ok([string]$t)   { Write-Host "  [OK]   $t" -ForegroundColor Green }
function Write-Warn2([string]$t){ Write-Host "  [WARN] $t" -ForegroundColor Yellow }
function Write-Err2([string]$t) { Write-Host "  [FAIL] $t" -ForegroundColor Red; $script:Failures++ }
function Write-Info([string]$t) { Write-Host "  $t" -ForegroundColor Gray }
function Write-Step([string]$t) { Write-Host ""; Write-Host "  >> $t" -ForegroundColor White }

$script:EnvReady = $false
function Initialize-Env {
    # 只初始化一次。注意：不能用 [IO.Path]::GetTempPath()——它会读 $env:TMP，
    # 而本函数自己会改 $env:TMP，同一 shell 里多次调用就会拼成 ...\tmp\tmp\...
    if ($script:EnvReady) { return }
    if (-not $WorkDir) {
        $base = Join-Path $env:LOCALAPPDATA 'Temp'
        if (-not (Test-Path $base)) { $base = $env:USERPROFILE }
        $WorkDir = Join-Path $base ("e5-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
    }
    $dirs = @($WorkDir, (Join-Path $WorkDir 'tmp'), (Join-Path $WorkDir 'home'))
    foreach ($d in $dirs) {
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
    }
    $env:TMP  = Join-Path $WorkDir 'tmp'
    $env:TEMP = $env:TMP
    $env:HOME = Join-Path $WorkDir 'home'
    $env:ANDROID_USER_HOME = $env:HOME
    $script:WorkDir = $WorkDir
    $script:EnvReady = $true
    Write-Info "workdir: $WorkDir"
}

function Get-Adb {
    $cands = New-Object System.Collections.ArrayList
    if ($env:ADB_EXE) { [void]$cands.Add($env:ADB_EXE) }
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd) { [void]$cands.Add($cmd.Source) }
    [void]$cands.Add("$PSScriptRoot\..\..\..\e5-work\unpack\e5\scrcpy\scrcpy-win64-v5.0.1\adb.exe")
    [void]$cands.Add("E:\e5flash\tools\adb.exe")
    [void]$cands.Add("C:\Android\platform-tools\adb.exe")
    foreach ($c in $cands) {
        if ($c -and (Test-Path $c)) { return (Resolve-Path $c).Path }
    }
    return $null
}

function Invoke-Adb {
    param([string[]]$AdbArgs, [switch]$AllowFail)
    $adb = Get-Adb
    if (-not $adb) { throw "adb.exe not found. Set env ADB_EXE." }
    $output = & $adb @AdbArgs 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -and -not $AllowFail) {
        throw ("adb " + ($AdbArgs -join ' ') + " failed:`n" + $output)
    }
    return $output
}

function Get-AdbDevice {
    $output = Invoke-Adb -AdbArgs @('devices') -AllowFail
    $line = ($output -split "`r?`n" | Where-Object { $_ -match "\tdevice$" } | Select-Object -First 1)
    if ($line) { return ($line -split "\t")[0] }
    return $null
}

function Resolve-SpdDir {
    param([string]$RomPath)
    $cands = New-Object System.Collections.ArrayList
    if ($SpdDir) { [void]$cands.Add($SpdDir) }
    if ($RomPath) { [void]$cands.Add((Join-Path $RomPath 'bin')) }
    if ($env:E5_SPD_DIR) { [void]$cands.Add($env:E5_SPD_DIR) }
    [void]$cands.Add("E:\e5flash\rom\bin")
    [void]$cands.Add((Join-Path $PSScriptRoot '..\rom\bin'))

    foreach ($c in $cands) {
        if (-not $c) { continue }
        $exe = Join-Path $c 'spd_dump.exe'
        $f1  = Join-Path $c 'fdl1-dl.bin'
        $f2  = Join-Path $c 'fdl2-dl.bin'
        if ((Test-Path $exe) -and (Test-Path $f1) -and (Test-Path $f2)) {
            return [pscustomobject]@{
                Dir  = (Resolve-Path $c).Path
                Exe  = (Resolve-Path $exe).Path
                Fdl1 = (Resolve-Path $f1).Path
                Fdl2 = (Resolve-Path $f2).Path
            }
        }
    }
    throw "spd_dump.exe + fdl1-dl.bin + fdl2-dl.bin not found. Use -SpdDir <dir>."
}

$script:ExecAddr = '0x65017f08'
$script:Fdl1Addr = '0x65000800'
$script:Fdl2Addr = '0xbefffe00'

function Invoke-Spd {
    param(
        [string]$SpdExe, [string]$Fdl1, [string]$Fdl2,
        [string[]]$Tail, [int]$Wait = 300, [switch]$UseKickto, [switch]$Echo
    )
    $spdArgs = New-Object System.Collections.ArrayList
    if ($UseKickto) { [void]$spdArgs.AddRange(@('--kickto','2')) }
    [void]$spdArgs.AddRange(@('--wait', "$Wait"))
    [void]$spdArgs.AddRange(@('exec_addr2', $script:ExecAddr))
    [void]$spdArgs.AddRange(@('fdl', $Fdl1, $script:Fdl1Addr))
    [void]$spdArgs.AddRange(@('fdl', $Fdl2, $script:Fdl2Addr))
    [void]$spdArgs.Add('exec')
    [void]$spdArgs.AddRange($Tail)

    Write-Info ("spd_dump " + ($spdArgs -join ' '))
    $output = & $SpdExe @spdArgs 2>&1 | Out-String
    if ($Echo) { Write-Host $output }
    return $output
}

function Get-BromDevice {
    return (Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
            Where-Object { $_.InstanceId -match 'VID_1782&PID_4D00' -and $_.Status -eq 'OK' })
}

function Wait-BromDevice {
    param([int]$Seconds = 300)
    Write-Info "waiting for BROM device (200ms poll, max $Seconds s) ..."
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        $d = Get-BromDevice
        if ($d) { return $d }
        Start-Sleep -Milliseconds 200
    }
    return $null
}

function Get-PartitionNames {
    return @(
        'splloader','prodnv','miscdata','misc','trustos_a','trustos_b','sml_a','sml_b',
        'uboot_a','uboot_b','uboot_log','logo','fbootlogo','nr_fixnv1_a','nr_fixnv1_b',
        'nr_fixnv2_a','nr_fixnv2_b','nr_runtimenv1','nr_runtimenv2','persist','nr_modem_a',
        'nr_modem_b','nr_deltanv_a','nr_deltanv_b','nr_phy_a','nr_phy_b','l_agdsp_a',
        'l_agdsp_b','pm_sys_a','pm_sys_b','ch_sys_a','ch_sys_b','teecfg_a','teecfg_b',
        'hypervsior_a','hypervsior_b','boot_a','boot_b','vendor_boot_a','vendor_boot_b',
        'init_boot_a','init_boot_b','dtb_a','dtb_b','dtbo_a','dtbo_b','super','cache',
        'blackbox','vbmeta_a','vbmeta_b','metadata','sysdumpdb','vbmeta_system_a',
        'vbmeta_system_b','vbmeta_vendor_a','vbmeta_vendor_b','vbmeta_system_ext_a',
        'vbmeta_system_ext_b','vbmeta_product_a','vbmeta_product_b','vbmeta_odm_a',
        'vbmeta_odm_b','avbmeta_rs_a','avbmeta_rs_b','common_rs1_a','common_rs1_b',
        'common_rs2_a','common_rs2_b','calinv','userdata'
    )
}

function Measure-ImageDensity {
    param([string]$Path)
    $fi = Get-Item $Path
    $fs = [IO.File]::OpenRead($Path)
    try {
        $buf = New-Object byte[] 1048576
        $blocks = 0
        $nonzero = 0
        while (($n = $fs.Read($buf, 0, $buf.Length)) -gt 0) {
            $blocks++
            $hit = $false
            for ($i = 0; $i -lt $n; $i++) {
                if ($buf[$i] -ne 0) { $hit = $true; break }
            }
            if ($hit) { $nonzero++ }
        }
        $density = 0.0
        if ($blocks -gt 0) { $density = [math]::Round(100.0 * $nonzero / $blocks, 1) }
    } finally { $fs.Close() }
    return [pscustomobject]@{
        Name = $fi.Name
        SizeMB = [math]::Round($fi.Length / 1MB, 1)
        DensityPct = $density
    }
}

# ---------------------------------------------------------------- commands

function Cmd-Detect {
    Write-Head 'environment check'

    Write-Step 'host'
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
               ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Write-Info "OS    : $([Environment]::OSVersion.VersionString)"
    Write-Info "User  : $([Environment]::UserName)"
    Write-Info "Admin : $isAdmin"
    if (-not $isAdmin) { Write-Warn2 'not elevated - driver install will fail, run pnputil as admin' }

    Write-Step 'disk free'
    Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
        $freeGB = [math]::Round($_.FreeSpace / 1GB, 1)
        $mark = 'OK'
        if ($freeGB -lt 8) { $mark = 'LOW' } elseif ($freeGB -lt 16) { $mark = 'tight' }
        Write-Info ("{0} free {1,7} GB  [{2}]" -f $_.DeviceID, $freeGB, $mark)
    }

    Write-Step 'SPRD driver'
    $drv = pnputil /enum-drivers 2>&1 | Out-String
    if ($drv -match 'sprdvcom') { Write-Ok 'sprdvcom.inf installed' }
    else { Write-Err2 'sprdvcom.inf missing - see SKILL.md stage 1' }

    Write-Step 'spd_dump toolchain'
    try {
        $s = Resolve-SpdDir -RomPath $Rom
        Write-Ok "spd_dump : $($s.Exe)"
        Write-Ok "fdl1     : $($s.Fdl1)"
        Write-Ok "fdl2     : $($s.Fdl2)"
    } catch { Write-Err2 $_.Exception.Message }

    Write-Step 'adb'
    $adb = Get-Adb
    if ($adb) {
        Write-Ok "adb: $adb"
        $dev = Get-AdbDevice
        if ($dev) { Write-Ok "android device: $dev" }
        else { Write-Info 'no adb device (powered off or in BROM)' }
    } else { Write-Warn2 'adb.exe not found - set env ADB_EXE' }

    Write-Step 'BROM device'
    $brom = Get-BromDevice
    if ($brom) {
        Write-Ok "BROM: $($brom.FriendlyName)"
        Write-Warn2 'already in BROM. If a previous run was interrupted, pull the battery for 10s first.'
    } else { Write-Info 'no BROM device present' }

    Write-Host ""
    if ($script:Failures -gt 0) {
        Write-Host "  $($script:Failures) item(s) need attention" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  environment ready" -ForegroundColor Green
}

function Cmd-WaitBrom {
    Write-Head 'wait for BROM'
    Write-Host @'
  On the phone:
    1. power off
    2. pull the battery, wait 3s, put it back
    3. hold the BACK key
    4. plug in USB
    5. keep holding 10s, then release
'@ -ForegroundColor White
    $d = Wait-BromDevice -Seconds $Timeout
    if ($d) { Write-Ok "BROM ready: $($d.FriendlyName)" }
    else { Write-Err2 "no BROM device within $Timeout s"; exit 1 }
}

function Cmd-Backup {
    Write-Head 'full partition backup (read-only)'
    $s = Resolve-SpdDir -RomPath $Rom

    if (-not $Out) {
        if (-not $BackupRoot) { $BackupRoot = 'E:\e5flash\backup' }
        $Out = Join-Path $BackupRoot (Get-Date -Format 'yyyyMMdd_HHmmss')
    }
    if (-not (Test-Path $Out)) { New-Item -ItemType Directory -Force -Path $Out | Out-Null }
    Write-Info "output: $Out"

    $d = Get-BromDevice
    if (-not $d) {
        Write-Warn2 'no BROM device yet, waiting ...'
        $d = Wait-BromDevice -Seconds $Timeout
        if (-not $d) { Write-Err2 'no BROM device'; exit 1 }
    }
    Write-Ok "BROM: $($d.FriendlyName)"

    Write-Step 'reading (r all, skips blackbox/cache/userdata)'
    $log = Invoke-Spd -SpdExe $s.Exe -Fdl1 $s.Fdl1 -Fdl2 $s.Fdl2 -UseKickto -Wait $Timeout `
                      -Tail @('path', $Out, 'r', 'all', 'reset') -Echo

    Write-Step 'validation'
    $files = @(Get-ChildItem $Out -File -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) { Write-Err2 'backup dir empty - check spd_dump output above'; exit 1 }

    $totalGB = [math]::Round((($files | Measure-Object Length -Sum).Sum) / 1GB, 2)
    $zero = @($files | Where-Object { $_.Length -eq 0 })
    Write-Info "files: $($files.Count)   total: $totalGB GB"

    if ($files.Count -lt 60) { Write-Err2 "too few files ($($files.Count) < 60), likely interrupted" }
    if ($zero.Count -gt 0) {
        Write-Err2 "$($zero.Count) zero-byte file(s): $(($zero | ForEach-Object { $_.Name }) -join ', ')"
    }

    $must = @('splloader','uboot_a','trustos_a','sml_a','boot_a','vbmeta_a','misc','prodnv','persist','nr_fixnv1_a')
    foreach ($m in $must) {
        $f = $files | Where-Object { $_.BaseName -eq $m } | Select-Object -First 1
        if (-not $f) { Write-Err2 "missing critical partition: $m" }
        elseif ($f.Length -eq 0) { Write-Err2 "critical partition empty: $m" }
        else { Write-Ok "$m ($([math]::Round($f.Length/1MB,1)) MB)" }
    }

    if (-not ($files | Where-Object { $_.BaseName -eq 'prodnv' })) {
        Write-Warn2 'prodnv missing - baseband/IMEI cannot be restored'
    }

    Write-Host ""
    if ($script:Failures -gt 0) {
        Write-Host "  backup validation failed ($($script:Failures)) - do NOT flash" -ForegroundColor Red
        exit 1
    }
    Write-Host "  backup complete and verified: $Out" -ForegroundColor Green
    Write-Host "  device was reset back to Android, this is expected." -ForegroundColor Gray
}

function Cmd-Flash {
    Write-Head "flash (Mode=$Mode)"

    if (-not $Rom) { Write-Err2 'need -Rom <rom root | backup dir>'; exit 1 }
    if (-not (Test-Path $Rom)) { Write-Err2 "path not found: $Rom"; exit 1 }

    if ($Mode -eq 'raw') {
        $src = (Resolve-Path $Rom).Path
        $s = Resolve-SpdDir
        Write-Warn2 "restore mode: write every .bin under $src back to its namesake partition"
        if (-not $Yes) {
            $ans = Read-Host '  confirm (type yes)'
            if ($ans -ne 'yes') { Write-Info 'cancelled'; exit 0 }
        }
        $d = Wait-BromDevice -Seconds $Timeout
        if (-not $d) { Write-Err2 'no BROM device'; exit 1 }
        Invoke-Spd -SpdExe $s.Exe -Fdl1 $s.Fdl1 -Fdl2 $s.Fdl2 -Wait $Timeout `
                   -Tail @('path', (Join-Path $WorkDir 'tmp'), 'write_parts', ($src + '\'), 'reset') -Echo
        Write-Ok 'restore written - check the device boots'
        return
    }

    $romRoot = (Resolve-Path $Rom).Path
    $dataDir = Join-Path $romRoot 'data'
    if (-not (Test-Path $dataDir)) {
        if ((Split-Path $romRoot -Leaf) -eq 'data') {
            $dataDir = $romRoot
            $romRoot = Split-Path $romRoot -Parent
        } else { Write-Err2 "no data\ dir: $dataDir"; exit 1 }
    }
    $s = Resolve-SpdDir -RomPath $romRoot

    Write-Step 'gate 1: image names match partition table'
    $parts = Get-PartitionNames
    $bins = @(Get-ChildItem $dataDir -Filter '*.bin' -File)
    if ($bins.Count -eq 0) { Write-Err2 "no .bin in $dataDir"; exit 1 }
    $unknown = @($bins | Where-Object { $parts -notcontains $_.BaseName })
    Write-Info "images: $($bins.Count)"
    if ($unknown.Count -gt 0) {
        Write-Err2 "unknown partition names: $(($unknown | ForEach-Object { $_.Name }) -join ', ')"
        exit 1
    }
    Write-Ok 'all names match real partitions'

    Write-Step 'gate 2: all-zero images (verify against backup)'
    $zeroish = New-Object System.Collections.ArrayList
    foreach ($b in $bins) {
        if ($b.Length -eq 0) { [void]$zeroish.Add("$($b.Name) (0 bytes)"); continue }
        $den = Measure-ImageDensity -Path $b.FullName
        if ($den.DensityPct -lt 0.1) { [void]$zeroish.Add("$($b.Name) (all-zero, $($den.SizeMB) MB)") }
    }
    if ($zeroish.Count -gt 0) {
        Write-Warn2 'these images are all-zero; the matching device partitions are likely empty too:'
        foreach ($z in $zeroish) { Write-Info "    $z" }
        Write-Warn2 'cross-check with the backup. If the backup is also all-zero there -> normal, continue.'
    } else { Write-Ok 'no all-zero images' }

    Write-Step 'gate 3: device in BROM'
    $d = Get-BromDevice
    if (-not $d) {
        Write-Warn2 'no BROM device yet, waiting ...'
        $d = Wait-BromDevice -Seconds $Timeout
        if (-not $d) { Write-Err2 'no BROM device'; exit 1 }
    }
    Write-Ok "BROM: $($d.FriendlyName)"

    if ($Mode -eq 'full') {
        Write-Warn2 'full mode erases userdata (all user data)'
        if (-not $Yes) {
            $ans = Read-Host '  confirm (type yes)'
            if ($ans -ne 'yes') { Write-Info 'cancelled'; exit 0 }
        }
        $tail = @('path', (Join-Path $WorkDir 'tmp'), 'write_parts', ($dataDir + '\'),
                  'e', 'userdata', 'verity', '0', 'reset')
    } else {
        $need = @('init_boot_a','boot_a','uboot_a','trustos_a','super')
        foreach ($n in $need) {
            if (-not (Test-Path (Join-Path $dataDir "$n.bin"))) { Write-Err2 "keepdata needs $n.bin"; exit 1 }
        }
        Write-Warn2 'keepdata only applies to devices already running the same author mod'
        if (-not $Yes) {
            $ans = Read-Host '  confirm (type yes)'
            if ($ans -ne 'yes') { Write-Info 'cancelled'; exit 0 }
        }
        $tail = @('path', (Join-Path $WorkDir 'tmp'))
        foreach ($n in $need) { $tail += @('w', $n, (Join-Path $dataDir "$n.bin")) }
        $tail += @('verity', '0', 'reset')
    }

    Write-Step 'writing (do not unplug, keep holding BACK)'
    $log = Invoke-Spd -SpdExe $s.Exe -Fdl1 $s.Fdl1 -Fdl2 $s.Fdl2 -Wait $Timeout -Tail $tail -Echo

    Write-Step 'result'
    if ($log -match 'device removed') {
        Write-Err2 'device disconnected mid-write'
        Write-Warn2 'fix: pull battery 10s -> back to BROM -> full reflash from scratch'
        Write-Warn2 'device will not boot now; that is expected (boot chain changed, super maybe unwritten)'
        exit 1
    }
    $done = [regex]::Matches($log, 'Write Part Done:\s*(\w+),\s*target:\s*(0x[0-9a-fA-F]+),\s*written:\s*(0x[0-9a-fA-F]+)')
    if ($done.Count -eq 0) { Write-Err2 'no successful write record'; exit 1 }
    $bad = New-Object System.Collections.ArrayList
    foreach ($m in $done) {
        if ($m.Groups[2].Value -ne $m.Groups[3].Value) { [void]$bad.Add($m.Groups[1].Value) }
    }
    Write-Info "partitions written: $($done.Count)"
    if ($bad.Count -gt 0) { Write-Err2 "truncated (target != written): $($bad -join ', ')" }
    else { Write-Ok 'all partitions fully written (target == written)' }

    if ($log -match 'Write Part Done:\s*super') { Write-Ok 'super written (system image complete)' }
    else { Write-Warn2 'no super write record - if Mode=full the system is incomplete' }

    Write-Host ""
    if ($script:Failures -gt 0) { exit 1 }
    Write-Host "  flash complete. device resets; first boot is slow." -ForegroundColor Green
}

function Cmd-FlashInitBoot {
    Write-Head 'write init_boot_a'
    if (-not $Image) { Write-Err2 'need -Image <patched img>'; exit 1 }
    if (-not (Test-Path $Image)) { Write-Err2 "not found: $Image"; exit 1 }

    $fi = Get-Item $Image
    if ($fi.Length -ne 8388608) {
        Write-Warn2 "size $($fi.Length) != 8388608 (init_boot is 8 MB), continuing but verify"
    }

    $s = Resolve-SpdDir -RomPath $Rom
    $d = Get-BromDevice
    if (-not $d) {
        Write-Warn2 'no BROM device yet, waiting ...'
        $d = Wait-BromDevice -Seconds $Timeout
        if (-not $d) { Write-Err2 'no BROM device'; exit 1 }
    }
    Write-Ok "BROM: $($d.FriendlyName)"

    $log = Invoke-Spd -SpdExe $s.Exe -Fdl1 $s.Fdl1 -Fdl2 $s.Fdl2 -Wait $Timeout `
                      -Tail @('path', (Join-Path $WorkDir 'tmp'), 'w', 'init_boot_a', (Resolve-Path $Image).Path, 'reset') -Echo

    if ($log -match 'Write Part Done:\s*init_boot_a') { Write-Ok 'init_boot_a written' }
    elseif ($log -match 'device removed') { Write-Err2 'device disconnected - pull battery and retry'; exit 1 }
    else { Write-Err2 'no success record'; exit 1 }
}

function Cmd-MagiskPrepare {
    Write-Head 'push stock init_boot for Magisk patching'
    if (-not $Image) { Write-Err2 'need -Image <stock init_boot_a.bin>'; exit 1 }
    if (-not (Test-Path $Image)) { Write-Err2 "not found: $Image"; exit 1 }

    $dev = Get-AdbDevice
    if (-not $dev) { Write-Err2 'no adb device - boot Android and enable USB debugging'; exit 1 }
    Write-Ok "device: $dev"

    Invoke-Adb -AdbArgs @('push', (Resolve-Path $Image).Path, '/sdcard/Download/init_boot.img') | Out-Null
    Write-Ok 'pushed to /sdcard/Download/init_boot.img'

    Write-Host @'

  Now on the phone:
    Magisk -> Install -> Select and Patch a File
    -> Download/init_boot.img -> LET'S GO
    wait for "All done!", it writes magisk_patched-*.img

  Then run:  ./e5.ps1 magisk-fetch
'@ -ForegroundColor White
}

function Cmd-MagiskFetch {
    Write-Head 'fetch Magisk patched image'
    $dev = Get-AdbDevice
    if (-not $dev) { Write-Err2 'no adb device'; exit 1 }

    $list = Invoke-Adb -AdbArgs @('shell', 'ls -1 /sdcard/Download/ | grep -i "^magisk_patched"')
    $name = ($list -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
    if (-not $name) { Write-Err2 'no magisk_patched-*.img on device - patch first in Magisk app'; exit 1 }
    $name = $name.Trim()
    Write-Ok "found: $name"

    if (-not $Dest) { $Dest = $WorkDir }
    if (-not (Test-Path $Dest)) { New-Item -ItemType Directory -Force -Path $Dest | Out-Null }

    Push-Location $Dest
    try { Invoke-Adb -AdbArgs @('pull', "/sdcard/Download/$name") | Out-Null }
    finally { Pop-Location }

    $local = Join-Path $Dest $name
    if (-not (Test-Path $local)) { Write-Err2 'pull failed'; exit 1 }

    $fi = Get-Item $local
    Write-Info "size: $($fi.Length) (expect 8388608)"
    if ($fi.Length -eq 8388608) { Write-Ok 'size ok' } else { Write-Err2 'size mismatch' }

    $fs = [IO.File]::OpenRead($local)
    try { $hdr = New-Object byte[] 8; $fs.Read($hdr, 0, 8) | Out-Null } finally { $fs.Close() }
    $magic = ($hdr | ForEach-Object { [string]::Format('{0:X2}', $_) }) -join ''
    Write-Info "magic: $magic"
    if ($magic -eq '414E44524F494421') { Write-Ok 'ANDROID! magic ok (Magisk injected)' }
    else { Write-Err2 'magic is not ANDROID! - image likely corrupt' }

    Write-Host ""
    Write-Host "  next: ./e5.ps1 flash-initboot -Image `"$local`"" -ForegroundColor Green
}

function Cmd-MagiskInstall {
    Write-Head 'install Magisk module'
    if (-not $Module) { Write-Err2 'need -Module <zip>'; exit 1 }
    if (-not (Test-Path $Module)) { Write-Err2 "not found: $Module"; exit 1 }

    $dev = Get-AdbDevice
    if (-not $dev) { Write-Err2 'no adb device'; exit 1 }

    $fi = Get-Item $Module
    $ascii = 'e5mod_' + [Guid]::NewGuid().ToString('N').Substring(0,8) + '.zip'
    $stage = Join-Path $WorkDir $ascii
    Copy-Item $fi.FullName $stage -Force
    $remote = "/sdcard/Download/$ascii"

    Write-Info "pushing as ASCII name: $ascii"
    Invoke-Adb -AdbArgs @('push', $stage, $remote) | Out-Null

    Write-Step 'magisk --install-module'
    $output = Invoke-Adb -AdbArgs @('shell', "su -c 'magisk --install-module $remote'") -AllowFail
    Write-Host $output

    if ($output -match 'Done' -or $output -match 'installed') {
        Write-Ok 'module installed'
        Write-Warn2 'reboot required: ./e5.ps1 reboot'
    } else {
        Write-Err2 'no success marker, check output above'
    }
}

function Cmd-OpenWrtTf {
    Write-Head 'install OpenWrt to TF card'
    if (-not $Package) { Write-Err2 'need -Package <openwrt pkg dir>'; exit 1 }
    if (-not (Test-Path $Package)) { Write-Err2 "not found: $Package"; exit 1 }

    $backend = Join-Path $Package 'tools\backend\openwrt-backend.exe'
    if (-not (Test-Path $backend)) { Write-Err2 "installer backend missing: $backend"; exit 1 }

    $dev = Get-AdbDevice
    if (-not $dev) { Write-Err2 'no adb device - installer needs Android with root'; exit 1 }
    Write-Ok "device: $dev"

    Write-Step 'preflight: root + unlocked + slot_a'
    $id    = (Invoke-Adb -AdbArgs @('shell', "su -c id") -AllowFail).Trim()
    $vbs   = (Invoke-Adb -AdbArgs @('shell', 'getprop ro.boot.verifiedbootstate') -AllowFail).Trim()
    $slot  = (Invoke-Adb -AdbArgs @('shell', 'getprop ro.boot.slot_suffix') -AllowFail).Trim()
    $model = (Invoke-Adb -AdbArgs @('shell', 'getprop ro.product.model') -AllowFail).Trim()
    Write-Info "id    : $id"
    Write-Info "vbs   : $vbs"
    Write-Info "slot  : $slot"
    Write-Info "model : $model"
    if ($id -notmatch 'uid=0') { Write-Err2 'no root - finish the Magisk stage first' }
    if ($vbs -ne 'orange')    { Write-Err2 'verifiedbootstate != orange - bootloader not unlocked' }
    if ($slot -ne '_a')       { Write-Err2 'slot != _a - installer requires Android on slot a' }
    if ($script:Failures -gt 0) { exit 1 }
    Write-Ok 'preflight passed'

    Push-Location $Package
    try {
        if ($CheckOnly) {
            Write-Step 'check only (writes nothing)'
            & $backend --cli --package-root $Package --no-pause --check 2>&1 | Out-String | Write-Host
        } else {
            Write-Step 'installing (erases the TF card target)'
            Write-Warn2 "SSID: $Ssid"
            if (-not $Yes) {
                $ans = Read-Host '  confirm (type yes)'
                if ($ans -ne 'yes') { Write-Info 'cancelled'; exit 0 }
            }
            & $backend --cli --package-root $Package --no-pause --tf --ssid $Ssid -y 2>&1 | Out-String | Write-Host
        }
    } finally { Pop-Location }

    if ($CheckOnly) { Write-Ok 'check complete, nothing written' }
    else {
        Write-Ok 'install complete - reboot manually'
        Write-Warn2 'first reboot may fall back to Android (trial boot); reboot once more'
        Write-Info 'after boot: http://192.168.9.1   root / root'
    }
}

function Cmd-WipeTf {
    Write-Head 'wipe TF card partition table'
    $dev = Get-AdbDevice
    if (-not $dev) { Write-Err2 'no adb device'; exit 1 }

    $info = Invoke-Adb -AdbArgs @('shell', 'ls /dev/block/ | grep "^mmcblk1$"') -AllowFail
    if ($info -notmatch 'mmcblk1') { Write-Err2 'TF card (mmcblk1) not found'; exit 1 }

    $sz = (Invoke-Adb -AdbArgs @('shell', "su -c 'blockdev --getsize64 /dev/block/mmcblk1'")).Trim()
    Write-Warn2 "TF card: mmcblk1 ($sz bytes)"
    Write-Warn2 'this erases the partition table and card data (first 16 MB + last 32 sectors)'
    if (-not $Yes) {
        $ans = Read-Host '  confirm (type yes)'
        if ($ans -ne 'yes') { Write-Info 'cancelled'; exit 0 }
    }

    $lines = @(
        'for v in $(sm list-volumes all | awk ''$2=="mounted"{print $1}''); do sm unmount "$v"; done',
        'sleep 2',
        'dd if=/dev/zero of=/dev/block/mmcblk1 bs=1M count=16 2>&1 | tail -1',
        'sync',
        'SECTORS=$(( $(blockdev --getsize64 /dev/block/mmcblk1) / 512 ))',
        'dd if=/dev/zero of=/dev/block/mmcblk1 bs=512 seek=$((SECTORS-32)) count=32 2>&1 | tail -1',
        'sync',
        'blockdev --flushbufs /dev/block/mmcblk1',
        'blockdev --rereadpt /dev/block/mmcblk1',
        'sleep 1',
        'echo "--- partitions after ---"',
        'cat /proc/partitions | grep mmcblk1'
    )
    $scriptText = ($lines -join "`n") + "`n"
    $p = Join-Path $WorkDir 'wipe_tf.sh'
    [IO.File]::WriteAllText($p, $scriptText, (New-Object Text.UTF8Encoding $false))
    Invoke-Adb -AdbArgs @('push', $p, '/data/local/tmp/wipe_tf.sh') | Out-Null
    $output = Invoke-Adb -AdbArgs @('shell', "su -c 'sh /data/local/tmp/wipe_tf.sh'") -AllowFail
    Write-Host $output

    if ($output -match 'mmcblk1p1') { Write-Warn2 'sub-partitions still listed - check output above' }
    else { Write-Ok 'partition table cleared, installer will now see the whole card' }
}

function Cmd-Probe {
    Write-Head 'device capability probe'
    $dev = Get-AdbDevice
    if (-not $dev) { Write-Err2 'no adb device'; exit 1 }
    Write-Ok "device: $dev"

    $lines = @(
        'echo "=== memory ==="',
        'grep -E ''MemTotal|MemAvailable'' /proc/meminfo',
        'echo "=== cpu ==="',
        'echo "cores: $(nproc)"',
        'echo "=== wifi ifaces ==="',
        'ls /sys/class/net/ | grep -E ''^wlan'' || echo "no wlan"',
        'echo "=== STA+AP concurrency ==="',
        'dumpsys wifi 2>/dev/null | grep -oE ''num_concurrent_connection: [0-9]+'' | head -1',
        'echo "=== hotspot capability ==="',
        'dumpsys wifi 2>/dev/null | grep -oE ''MaximumSupportedClientNumber=[0-9]+'' | head -1',
        'echo "=== net tools ==="',
        'for t in iptables ip6tables nft dnsmasq tcpdump iperf3 curl socat ping wget; do',
        '  command -v $t >/dev/null 2>&1 && echo "OK   $t" || echo "MISS $t"',
        'done',
        'echo "=== storage ==="',
        'df -h /data | tail -1'
    )
    $scriptText = ($lines -join "`n") + "`n"
    $p = Join-Path $WorkDir 'probe.sh'
    [IO.File]::WriteAllText($p, $scriptText, (New-Object Text.UTF8Encoding $false))
    Invoke-Adb -AdbArgs @('push', $p, '/data/local/tmp/probe.sh') | Out-Null
    $output = Invoke-Adb -AdbArgs @('shell', "su -c 'sh /data/local/tmp/probe.sh'") -AllowFail
    Write-Host $output
}

function Cmd-Verify {
    Write-Head 'status verification'
    $dev = Get-AdbDevice
    if (-not $dev) {
        Write-Err2 'no adb device (off / in BROM / running OpenWrt)'
        Write-Info 'if running OpenWrt: http://192.168.9.1'
        exit 1
    }
    Write-Ok "device: $dev"

    $vbs   = (Invoke-Adb -AdbArgs @('shell', 'getprop ro.boot.verifiedbootstate') -AllowFail).Trim()
    $model = (Invoke-Adb -AdbArgs @('shell', 'getprop ro.product.model') -AllowFail).Trim()
    $slot  = (Invoke-Adb -AdbArgs @('shell', 'getprop ro.boot.slot_suffix') -AllowFail).Trim()
    $id    = (Invoke-Adb -AdbArgs @('shell', 'su -c id') -AllowFail).Trim()
    $mv    = (Invoke-Adb -AdbArgs @('shell', 'magisk -v') -AllowFail).Trim()

    Write-Step 'basics'
    if ($vbs -eq 'orange') { Write-Ok 'verifiedbootstate = orange (unlocked + AVB disabled)' }
    else { Write-Err2 "verifiedbootstate = $vbs (expect orange)" }
    if ($model -eq 'E5') { Write-Ok 'model = E5' } else { Write-Warn2 "model = $model" }
    if ($slot -eq '_a')  { Write-Ok 'slot = _a' } else { Write-Warn2 "slot = $slot" }

    Write-Step 'root'
    if ($id -match 'uid=0') { Write-Ok "su: $id" }
    else { Write-Err2 "su unavailable: $id (grant Shell in Magisk app)" }
    if ($mv -match ':MAGISK:R') { Write-Ok "magisk: $mv (R = root loaded)" }
    elseif ($mv) { Write-Warn2 "magisk: $mv" }
    else { Write-Err2 'magisk unavailable' }

    if (-not $Full) { Write-Host ""; return }

    Write-Step 'modules and props'
    $mods = (Invoke-Adb -AdbArgs @('shell', "su -c 'ls /data/adb/modules/'") -AllowFail).Trim()
    Write-Info ("modules: " + ($mods -replace "`r?`n", ', '))
    $pairs = @(
        @('ro.debuggable', '1'),
        @('ro.adb.secure', '0'),
        @('service.adb.tcp.port', '5555')
    )
    foreach ($kv in $pairs) {
        $v = (Invoke-Adb -AdbArgs @('shell', "getprop $($kv[0])") -AllowFail).Trim()
        if ($v -eq $kv[1]) { Write-Ok "$($kv[0]) = $v" }
        else { Write-Warn2 "$($kv[0]) = $v (expect $($kv[1]))" }
    }
    $enf = (Invoke-Adb -AdbArgs @('shell', 'getenforce') -AllowFail).Trim()
    if ($enf -eq 'Permissive') { Write-Ok 'SELinux = Permissive' } else { Write-Warn2 "SELinux = $enf" }

    Write-Step 'listening ports'
    $net = Invoke-Adb -AdbArgs @('shell', "su -c netstat -tlnp") -AllowFail
    foreach ($p in @(2333, 5555, 1146)) {
        if ($net -match ":$p\s") { Write-Ok ":$p LISTEN" } else { Write-Info ":$p not listening" }
    }

    Write-Step 'hotspot / tethering'
    $ap = Invoke-Adb -AdbArgs @('shell', "su -c 'mount | grep -i tethering'") -AllowFail
    if ($ap -match 'mmcblk0p70') { Write-Ok 'TetheringGoogle.apk replaced (apex bind mount active)' }
    else { Write-Info 'no tethering bind mount (module missing or not rebooted)' }

    Write-Host ""
    if ($script:Failures -gt 0) {
        Write-Host "  $($script:Failures) issue(s)" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  all checks passed" -ForegroundColor Green
}

function Cmd-Reboot {
    Write-Head 'reboot device'
    $dev = Get-AdbDevice
    if (-not $dev) { Write-Err2 'no adb device'; exit 1 }
    Invoke-Adb -AdbArgs @('reboot') -AllowFail | Out-Null
    Write-Ok 'reboot command sent'

    Write-Info 'waiting for boot_completed (max 240s) ...'
    Start-Sleep -Seconds 8
    $deadline = (Get-Date).AddSeconds(240)
    while ((Get-Date) -lt $deadline) {
        $d = Get-AdbDevice
        if ($d) {
            $b = (Invoke-Adb -AdbArgs @('shell', 'getprop sys.boot_completed') -AllowFail).Trim()
            if ($b -eq '1') { Write-Ok "boot complete: $d"; return }
        }
        Start-Sleep -Seconds 3
    }
    Write-Warn2 'no boot_completed=1 within 240s'
    Write-Info 'if it is OpenWrt now: http://192.168.9.1'
}

function Cmd-Help {
    Write-Host @'
RongYue E5 flashing toolkit

  detect                                    env / driver / device / disk
  wait-brom  [-Timeout 600]                 wait for BROM device
  backup     [-Out <dir>]                   full backup + validation
  flash      -Rom <dir> -Mode full|keepdata|raw [-Yes]
  flash-initboot -Image <img>               write init_boot_a
  magisk-prepare -Image <img>               push stock init_boot
  magisk-fetch [-Dest <dir>]                fetch patched image + verify
  magisk-install -Module <zip>              install Magisk module
  openwrt-tf -Package <dir> [-CheckOnly] [-Ssid <name>] [-Yes]
  wipe-tf    [-Yes]                         wipe TF partition table
  probe                                     device capability probe
  verify     [-Full]                        status verification
  reboot                                    reboot and wait for boot

common options:
  -SpdDir <dir>       dir with spd_dump.exe + fdl1-dl.bin + fdl2-dl.bin
  -BackupRoot <dir>   backup root (default E:\e5flash\backup)
  -WorkDir <dir>      temp work dir
  -Rom <dir>          mod ROM root or backup dir
  -Yes                skip confirmation

env vars:
  ADB_EXE             path to adb.exe
  E5_SPD_DIR          spd_dump dir
'@ -ForegroundColor Gray
}

# ---------------------------------------------------------------- dispatch

Initialize-Env

switch ($Command) {
    'detect'         { Cmd-Detect }
    'wait-brom'      { Cmd-WaitBrom }
    'backup'         { Cmd-Backup }
    'flash'          { Cmd-Flash }
    'flash-initboot' { Cmd-FlashInitBoot }
    'magisk-prepare' { Cmd-MagiskPrepare }
    'magisk-fetch'   { Cmd-MagiskFetch }
    'magisk-install' { Cmd-MagiskInstall }
    'openwrt-tf'     { Cmd-OpenWrtTf }
    'wipe-tf'        { Cmd-WipeTf }
    'probe'          { Cmd-Probe }
    'verify'         { Cmd-Verify }
    'reboot'         { Cmd-Reboot }
    'help'           { Cmd-Help }
}

exit $script:Failures
