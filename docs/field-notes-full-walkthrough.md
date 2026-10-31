# 荣悦 E5 实刷全程记录：从原厂到 Magisk + UFI-TOOLS + OpenWrt 双系统

> 一台原厂荣悦 E5（紫光展锐 T158），在 Windows 上用 `spd_dump` 走 BROM 深刷官改 V4，装 Magisk 拿 root，
> 装 UFI-TOOLS 与热点优化模块，最后把 OpenWrt 装进 TF 卡实现 Android / OpenWrt 双系统。
>
> 本文是**按实际执行顺序记录的完整过程**，含每一步的真实命令、预期输出、踩过的坑和判断依据。
> 全程只用公开工具，所有分区镜像先备份后写入。

## 目录

- [0. 结论速览](#0-结论速览)
- [1. 环境与物料](#1-环境与物料)
- [2. 关键前置认知](#2-关键前置认知)
- [3. 步骤一：装 SPRD 驱动，进 BROM](#3-步骤一装-sprd-驱动进-brom)
- [4. 步骤二：全分区备份（只读，必做）](#4-步骤二全分区备份只读必做)
- [5. 步骤三：刷官改 V4（解锁 BL + 去 AVB）](#5-步骤三刷官改-v4解锁-bl--去-avb)
- [6. 步骤四：Magisk 打补丁拿 root](#6-步骤四magisk-打补丁拿-root)
- [7. 步骤五：UFI-TOOLS + 热点优化模块](#7-步骤五ufi-tools--热点优化模块)
- [8. 步骤六：OpenWrt 装进 TF 卡（双系统）](#8-步骤六openwrt-装进-tf-卡双系统)
- [9. 双系统切换机制](#9-双系统切换机制)
- [10. 硬件能力的实测结论](#10-硬件能力的实测结论)
- [11. 坑位合集](#11-坑位合集)
- [12. 救砖与回滚](#12-救砖与回滚)
- [13. 附：完整命令清单](#13-附完整命令清单)

---

## 0. 结论速览

| 目标 | 可行性 | 关键前提 |
| --- | --- | --- |
| 刷官改 ROM | ✅ 顺利 | Windows + SPRD 驱动 + 定制 `spd_dump` |
| 解锁 Bootloader / 去 AVB | ✅ 官改包自带 | `verifiedbootstate` 变 `orange` |
| Magisk root | ✅ 顺利 | `init_boot_a` 打补丁后 BROM 写回 |
| UFI-TOOLS | ✅ 可用 | Magisk 模块 + 重启 |
| 热点解除限制 / 锁信道 / 固定 IP | ✅ 可用 | 专用模块，apex bind mount |
| OpenWrt 双系统 | ✅ 可用 | TF 卡 ≥ 2 GB，装完可切 |
| WiFi 中继（STA+AP 同时） | ❌ **硬件不支持** | 单 `wlan0`，`num_concurrent_connection: 0` |

**一句话**：这台机器刷机路径非常成熟，但**单 WiFi 射频**决定了它只能当「5G → WiFi 热点」，
不能当「WiFi 中继」。刷 OpenWrt 也改变不了这一点。

---

## 1. 环境与物料

### 宿主机

- Windows 10/11 x64（本例 10.0.26300）
- 管理员权限（装驱动必须）
- USB-A 数据线（能传数据的，不是纯充电线）
- 磁盘空间：官改包解压约 6 GB，备份约 7 GB

### 固件与工具

| 物料 | 大小 | 说明 |
| --- | --- | --- |
| 荣悦E5官改系统V4（去除data加密/ADB默认打开） | 1.69 GB 压缩 / 5.97 GB 解压 | 含 `bin/`（定制 spd_dump + fdl）、`data/`（31 个分区镜像）、`刷机驱动_SPD_Driver_R4.20.4201/` |
| e5-tools 工具包 | 294 MB | `scrcpy` + `adb` + `spd_dump`（SPRD/LibUSB 两版）+ `Magisk-v30.7.apk` |
| OpenWrt 整包（e5-linux） | 245 MB | `e5-openwrt-25.12.5` + 图形安装器 + `boot.img` + `openwrt.ext4.gz` |
| UFI-TOOLS 通用模块 | 17.8 MB | `UFI-TOOLS_for_Unisoc_devices.zip` |
| 热点优化模块 v4 | 2.49 MB | `荣悦E5解除热点数量限制+锁5GWIFI信道+固定热点IP模块v4.zip` |

> **注意**：官改包解压后文件名是 GBK 编码，7-Zip 在 UTF-8 控制台会显示乱码，但文件本身正常。

### 官改包目录结构

```
rom/
├─ bin/
│  ├─ spd_dump.exe          # 定制版 ver:228（支持 exec_addr2）
│  ├─ fdl1-dl.bin           # 62024 B
│  ├─ fdl2-dl.bin           # 1035432 B
│  └─ custom_exec_no_verify_65017f08.bin
├─ data/                    # 31 个分区镜像，5.91 GB
│  ├─ splloader.bin  uboot_a.bin  trustos_a.bin  sml_a.bin  teecfg_a.bin
│  ├─ boot_a.bin  init_boot_a.bin  vendor_boot_a.bin
│  ├─ vbmeta_a.bin  vbmeta_{odm,product,system,system_ext,vendor}_a.bin
│  ├─ super.bin（5600 MB）  metadata.bin  misc.bin  logo.bin  fbootlogo.bin
│  ├─ dtb_a.bin  dtbo_a.bin  hypervsior_a.bin
│  ├─ ch_sys_a.bin  common_rs1_a.bin  common_rs2_a.bin  l_agdsp_a.bin  pm_sys_a.bin
│  ├─ nr_runtimenv1.bin  nr_runtimenv2.bin  persist.bin  avbmeta_rs_a.bin
├─ 刷机驱动_SPD_Driver_R4.20.4201/{Win7,Win8,Win10&win11}/
├─ [直接插电]一键备份.bat
├─ [短接模式]一键备份.bat
├─ [短接模式]一键刷机_会清空用户数据.bat
├─ [短接模式](之前装过我的官改的）一键更新_不清空数据.bat
└─ [面具用我]Magisk_28103_原版.apk
```

---

## 2. 关键前置认知

### 2.1 BROM 模式的三个「阶段」

`spd_dump` 连接设备时会依次经过：

```
bootrom (BROM)  →  FDL1  →  FDL2
   ↑ 硬件只读      ↑ 内存中   ↑ 内存中，能读写分区
```

**这是最重要的认知**：

- `BROM` 是芯片固化的，**彻底断电才会退出**
- `FDL1` / `FDL2` 是**加载到手机内存里的程序**，拔线、松手都**不会**清掉
- 所以中途失败后，必须**取电池断电 10 秒**，否则下次连接会从 FDL1 残留状态继续，报
  `exec_addr is 0x0` / `unexpected response (0x0089)`

### 2.2 按键时序决定成败

进入 BROM 的唯一方式是**按住返回键**，靠按键维持连接：

```
关机 → 取电池 → 等 3 秒 → 装回 → 按住返回键不放 → 插 USB → 继续按住 10 秒
```

**踩坑记录**：

| 现象 | 原因 |
| --- | --- |
| `EXEC FDL1` 后立刻 `device removed` | 插上线就松手了 |
| `exec_addr is 0x0` + `unexpected response 0x0089` | 上次 FDL1 残留，没断电 |
| `find port failed` | 设备出现后几百毫秒就退出，`spd_dump` 还没连上 |
| `usb_send failed (0 / 1)` | 半连接状态，需拔插复位 |

**经验**：`init_boot` 这种 8 MB 的分区，40 MB/s 下不到 1 秒就写完，
**多按住 5 秒足够覆盖**；刷 `super`（5.6 GB）则要按住 2~3 分钟。

### 2.3 设备识别

| 阶段 | VID:PID | 设备名 |
| --- | --- | --- |
| BROM（正常） | `VID_1782&PID_4D00` | `SPRD U2S Diag (COM3)` |
| 驱动缺失 | 同上，但 `Status=Error` / `CM_PROB_FAILED_INSTALL` | 无 |
| Android 正常 | — | `adb devices` 显示序列号 |

判断设备是否真的在 BROM：

```powershell
Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match "VID_1782" } |
  Select-Object Status, Class, FriendlyName, Problem
# 期望：Status=OK, Class=Ports, FriendlyName=SPRD U2S Diag (COM3), Problem=CM_PROB_NONE
```

---

## 3. 步骤一：装 SPRD 驱动，进 BROM

### 3.1 装驱动（必须管理员）

```cmd
pnputil /add-driver "E:\e5flash\rom\刷机驱动_SPD_Driver_R4.20.4201\Win10&win11\Drivers\sprdvcom.inf" /install
```

或直接跑包里的 `DriverSetup.exe`。

验证：

```powershell
pnputil /enum-drivers | Select-String -Pattern "sprdvcom" -Context 0,3
# 期望：Published Name: oem78.inf / Provider Name: UNISOC Communications Inc. / Class Name: Ports
```

驱动 INF 里 `PID_4D00` 对应 `%USBCOMM_DL%`，正是 BROM 下载口：

```ini
%USBCOMM_DL%  = Serial_Inst, USB\VID_1782&PID_4D00
%SPRD.DIAG%   = Serial_Inst, USB\VID_1782&PID_4D01&MI_01
```

### 3.2 进 BROM

1. 手机关机
2. **取出电池**（E5 可拆），等 3 秒，装回
3. **按住「返回键」不放**
4. 插入 USB
5. **继续按住，数 10 秒**再松手

设备管理器出现 `SPRD U2S Diag (COM3)` 即成功。

---

## 4. 步骤二：全分区备份（只读，必做）

**这一步不写入任何字节**，但决定了后面能不能救砖。

### 4.1 命令

```bat
cd /d E:\e5flash\rom
bin\spd_dump.exe --wait 300 --kickto 2 exec_addr2 0x65017f08 ^
  fdl bin\fdl1-dl.bin 0x65000800 ^
  fdl bin\fdl2-dl.bin 0xbefffe00 ^
  exec path "E:\e5flash\backup\20261031_074608" r all reset
```

**参数解释**：

| 参数 | 含义 |
| --- | --- |
| `--wait 300` | 等设备 300 秒 |
| `--kickto 2` | 走 `boot_diag → dl_diag` 路径（比直接连 COM 更稳） |
| `exec_addr2 0x65017f08` | 发送 `custom_exec_no_verify_65017f08.bin` 到该地址，绕过 BROM 对 `splloader/fdl1` 的签名校验（CVE-2022-38694 思路） |
| `fdl fdl1-dl.bin 0x65000800` | 把 FDL1 送到 0x65000800 |
| `fdl fdl2-dl.bin 0xbefffe00` | 把 FDL2 送到 0xbefffe00 |
| `exec` | 执行 |
| `path <dir>` | 备份输出目录 |
| `r all` | 全分区读取（跳过 blackbox / cache / userdata） |
| `reset` | 完成后重启 |

> **`exec_addr2` 是定制版的私有命令**，开源 `spreadtrum_flash` 的 stable 版没有。
> 若用官方 stable 版，需改成 `exec_addr 0x65017f08` 且文件名必须是 `custom_exec_no_verify_0x65017f08.bin`。

### 4.2 预期输出（关键行）

```
Waiting for boot_diag/cali_diag/dl_diag connection (300s)
Successfully connected to port: 3
CHECK_BAUD bootrom
BSL_REP_VER: "SPRD3\0"
CMD_CONNECT bootrom
current exec_addr is 0x65017f08
SEND ...\fdl1-dl.bin to 0x65000800
SEND custom_exec_no_verify_65017f08.bin to 0x65017f08
EXEC FDL1
BSL_REP_VER: "Spreadtrum Boot Block version 1.1\0"
CMD_CONNECT FDL1
CHANGE_BAUD FDL1 to 921600
SEND ...\fdl2-dl.bin to 0xbefffe00
FDL2: incompatible partition
EXEC FDL2
DISABLE_TRANSCODE
Reading Partition List
standard gpt table dumped successfully
Total number of partitions: 70
Storage is emmc
Device is using slot a
```

> `FDL2: incompatible partition` 是**正常提示**（PC 与设备的 GPT 缓存不一致），不影响后续操作。

### 4.3 实测分区表（70 个）

```
 0 splloader 256KB      1 prodnv 64MB          2 miscdata 1MB       3 misc 1MB
 4 trustos_a 6MB        5 trustos_b 6MB        6 sml_a 1MB          7 sml_b 1MB
 8 uboot_a 3MB          9 uboot_b 3MB         10 uboot_log 16MB    11 logo 8MB
12 fbootlogo 8MB       13 nr_fixnv1_a 50MB    14 nr_fixnv1_b 50MB  15 nr_fixnv2_a 50MB
16 nr_fixnv2_b 50MB    17 nr_runtimenv1 55MB  18 nr_runtimenv2 55MB 19 persist 2MB
20 nr_modem_a 50MB     21 nr_modem_b 50MB     22 nr_deltanv_a 1MB  23 nr_deltanv_b 1MB
24 nr_phy_a 50MB       25 nr_phy_b 50MB       26 l_agdsp_a 6MB     27 l_agdsp_b 6MB
28 pm_sys_a 1MB        29 pm_sys_b 1MB        30 ch_sys_a 16MB     31 ch_sys_b 16MB
32 teecfg_a 1MB        33 teecfg_b 1MB        34 hypervsior_a 10MB 35 hypervsior_b 10MB
36 boot_a 64MB         37 boot_b 64MB         38 vendor_boot_a 100MB 39 vendor_boot_b 100MB
40 init_boot_a 8MB     41 init_boot_b 8MB     42 dtb_a 8MB         43 dtb_b 8MB
44 dtbo_a 8MB          45 dtbo_b 8MB          46 super 5600MB      47 cache 64MB
48 blackbox 500MB      49 vbmeta_a 1MB        50 vbmeta_b 1MB      51 metadata 64MB
52 sysdumpdb 60MB      53 vbmeta_system_a 1MB 54 vbmeta_system_b 1MB 55 vbmeta_vendor_a 1MB
56 vbmeta_vendor_b 1MB 57 vbmeta_system_ext_a 1MB 58 vbmeta_system_ext_b 1MB
59 vbmeta_product_a 1MB 60 vbmeta_product_b 1MB 61 vbmeta_odm_a 1MB 62 vbmeta_odm_b 1MB
63 avbmeta_rs_a 1MB    64 avbmeta_rs_b 1MB    65 common_rs1_a 8MB   66 common_rs1_b 8MB
67 common_rs2_a 16MB   68 common_rs2_b 16MB   69 calinv 15MB        70 userdata 22380MB
```

### 4.4 备份校验

```powershell
$bk = "E:\e5flash\backup\20261031_074608"
$f = Get-ChildItem $bk -File
"文件数: $($f.Count)  合计: $([math]::Round(($f|Measure-Object Length -Sum).Sum/1GB,2)) GB"
"零字节文件: $(($f | Where-Object { $_.Length -eq 0 }).Count)"
```

实测结果：**68 个文件，6.7 GB，零 0 字节文件**。

关键分区必须存在且非零：
`splloader` / `uboot_a` / `trustos_a` / `sml_a` / `boot_a` / `vbmeta_a` / `misc` / **`prodnv`** / `persist` / `nr_fixnv1_a`

> ⚠️ **`prodnv`（64 MB）是基带/IMEI/射频校准**，ROM 包里没有这个镜像，所以刷机不会覆盖它。
> 但备份里必须有——丢了机器就没信号。

---

## 5. 步骤三：刷官改 V4（解锁 BL + 去 AVB）

### 5.1 刷前核对

**镜像名必须与真实分区名一一对应**，否则 `write_parts` 会写错位置：

```powershell
# 实测：31 个镜像全部匹配
```

**核对全零镜像是否正常**（这点很容易误判）：

| 文件 | ROM 密度 | 真机密度 | 判定 |
| --- | --- | --- | --- |
| `dtb_a.bin` | 全零 | **全零** | ✅ 一致，设备本来就这样 |
| `hypervsior_a.bin` | 全零 | **全零** | ✅ 一致 |
| `common_rs2_a.bin` | 全零 | **全零** | ✅ 一致 |
| `avbmeta_rs_a.bin` | 全零 | **全零** | ✅ 一致 |
| `super.bin` | 41.4% | 41.5% | ✅ 一致（稀疏） |

**结论**：ROM 包里那几个全零文件是**正确的**，因为真机对应分区本来就是空的。
只有先做备份，才能确认这一点——这是「先备份」的另一个理由。

### 5.2 刷机命令

```bat
cd /d E:\e5flash\rom
bin\spd_dump.exe --wait 300 exec_addr2 0x65017f08 ^
  fdl bin\fdl1-dl.bin 0x65000800 ^
  fdl bin\fdl2-dl.bin 0xbefffe00 ^
  exec path "E:\e5flash\temp" ^
  write_parts "E:\e5flash\rom\data\" ^
  e userdata verity 0 reset
```

| 参数 | 含义 |
| --- | --- |
| `write_parts <dir>` | 把目录里所有 `.bin` 按文件名写入同名分区 |
| `e userdata` | 擦除 userdata（完整刷机才需要） |
| `verity 0` | 关闭 dm-verity |
| `reset` | 刷完重启 |

> **增量更新（保留数据）** 用另一条命令，只写 5 个分区：
> ```
> ... exec path temp w init_boot_a data\init_boot_a.bin w boot_a data\boot_a.bin ^
>     w uboot_a data\uboot_a.bin w trustos_a data\trustos_a.bin w super data\super.bin verity 0 reset
> ```
> 仅适用于**之前已装过同一作者官改**的机器。

### 5.3 写入顺序（实测）

`write_parts` 按字母序写入，实测顺序：

```
splloader → uboot_a → vbmeta_a → vbmeta_odm_a → vbmeta_product_a →
vbmeta_system_a → vbmeta_system_ext_a → vbmeta_vendor_a → avbmeta_rs_a →
boot_a → ch_sys_a → common_rs1_a → common_rs2_a → dtbo_a → dtb_a →
fbootlogo → hypervsior_a → init_boot_a → logo → l_agdsp_a → misc →
[erase nr_runtimenv1/nr_runtimenv2] → persist → pm_sys_a → sml_a →
teecfg_a → trustos_a → vendor_boot_a → super（5.6 GB）→ metadata →
[misc 回写 + VAB 偏移写入] → [erase persist] → [vbmeta_a 回写 + verity]
```

### 5.4 刷机中断怎么办

**实测踩坑**：刷到 `hypervsior_a` 80% 时设备掉线：

```
[send] device removed, exiting...
```

**后果**：引导链改了但 `super` 没写 → **必然开不了机**，这是正常的。

**处理**：取电池断电 → 重新进 BROM → **从头完整重刷一遍**。
`write_parts` 是幂等的，重复写相同数据无害。

**经验**：刷 `super` 那 2~3 分钟**必须按住返回键**。

### 5.5 成功标志

```
Write Part Done: super, target: 0x15e000000, written: 0x15e000000
w_mem_to_part_offset: wrote to 1 part(s) for VAB device
```

`target == written` 表示完整写入无截断。

### 5.6 刷后验证

开机后：

```powershell
adb shell "getprop ro.boot.verifiedbootstate"   # 期望 orange
adb shell "getprop ro.product.model"            # 期望 E5
adb shell "getprop ro.boot.slot_suffix"         # 期望 _a
adb shell "getprop ro.build.version.release"    # 13
```

`orange` = Bootloader 已解锁 + AVB 已解除。

---

## 6. 步骤四：Magisk 打补丁拿 root

### 6.1 为什么必须打补丁而不能直接装

设备此时**没有 root**，`adb` 读不了块设备；而 Magisk 必须由 App 注入 `magiskinit`。
所以流程是：**取原始 `init_boot` → App 打补丁 → BROM 写回**。

> **关键细节**：要用**当前设备上正在运行的那份** `init_boot`，不是原厂的。
> 本例中官改 ROM 的 `init_boot_a.bin`（`c18561…`）与原厂备份（`3499fa…`）**不同**，
> 因为官改改了内核。用 ROM 里那份即可（刚刷进去的就是它）。

### 6.2 操作

```powershell
# 1) 推送原始镜像
adb push E:\e5flash\rom\data\init_boot_a.bin /sdcard/Download/init_boot.img

# 2) 手机上打开 Magisk → 安装 → 选择并修补一个文件 → 选 init_boot.img → 开始
#    产出 /sdcard/Download/magisk_patched-28103_XXXXX.img

# 3) 拉回（注意：Windows 下 adb pull 对某些盘符路径会报 No such file，
#    先 cd 到工作目录再 pull 更稳）
cd C:\...\stage
adb pull /sdcard/Download/magisk_patched-28103_WbWCS.img
```

### 6.3 校验补丁

```powershell
# 大小必须与原镜像一致：8388608
# magic 必须是 ANDROID! = 414e44524f494421
```

实测：

```
原始 init_boot : c18561d49bba1b991d188f76be9f46abb63828f492fb5faefa7a7710261dd96e
Magisk 补丁后  : 28217a1e726260d2ce37d68b27918f0e904d219ef1e7d4b2bd54bd1ab69b906b
补丁镜像 magic : 414e44524f494421  (ANDROID!)
```

### 6.4 写回

```bat
bin\spd_dump.exe --wait 600 exec_addr2 0x65017f08 ^
  fdl bin\fdl1-dl.bin 0x65000800 fdl bin\fdl2-dl.bin 0xbefffe00 ^
  exec path "E:\e5flash\temp" ^
  w init_boot_a "E:\e5flash\magisk\magisk_patched_init_boot.img" reset
```

成功：

```
Write Part Done: init_boot_a, target: 0x800000, written: 0x800000
```

### 6.5 授权与验证

开机后在 Magisk App 里给 `Shell` 授予超级用户权限，然后：

```powershell
adb shell "su -c id"
# 期望：uid=0(root) gid=0(root) groups=0(root) context=u:r:magisk:s0
```

其他验证点：

```powershell
adb shell "magisk -v"        # 1e3edb88:MAGISK:R  ← 末尾 R 表示 root 已加载
adb shell "ps -A | grep magisk"   # 应有 magiskd
adb shell "ls -la /debug_ramdisk/su"  # -> ./magisk
```

> `id -u` 在 `adb shell` 下返回 `2000`（shell 用户）是正常的，必须用 `su -c`。

---

## 7. 步骤五：UFI-TOOLS + 热点优化模块

### 7.1 UFI-TOOLS 主模块

```powershell
adb push UFI-TOOLS_for_Unisoc_devices.zip /sdcard/Download/
adb shell "su -c 'magisk --install-module /sdcard/Download/UFI-TOOLS_for_Unisoc_devices.zip'"
```

模块做的事（读 `customize.sh`）：

1. 安装 `ufi_tools.apk`（包名 `com.minikano.f50_sms`）
2. 写 `sepolicy.rule`：`permissive <pkg domain>;`
3. `system.prop` 注入：
   ```
   ro.adb.secure=0
   ro.debuggable=1
   persist.sys.usb.allow_debug=1
   service.adb.tcp.port=5555
   ```

重启后验证：

```powershell
adb shell "getprop ro.debuggable"          # 1
adb shell "getprop service.adb.tcp.port"   # 5555
adb shell "getenforce"                     # Permissive
adb shell "su -c netstat -tlnp"            # 应有 :2333 (com.minikano.f50_sms)
```

### 7.2 UFI-TOOLS 端口

| 端口 | 进程 | 用途 |
| --- | --- | --- |
| **2333** | `com.minikano.f50_sms` | Web 管理后台 |
| 1146 | `ttyd` | 网页终端 |
| 5555 | `adbd` | 无线 ADB |
| 5201 | `iperf3` | 测速 |

登录 token 在 `/data/data/com.minikano.f50_sms/shared_prefs/kano_ZTE_store.xml`：

```xml
<string name="login_token">8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918</string>
<string name="device_uuid">0091e1e90e4a8894</string>
<string name="gateway_ip">0.0.0.0:8080</string>
```

### 7.3 热点优化模块

```powershell
adb push hotspot_v4.zip /sdcard/Download/    # 中文名会失败，改 ASCII 名
adb shell "su -c 'magisk --install-module /sdcard/Download/hotspot_v4.zip'"
```

模块做的事：

| 组件 | 作用 |
| --- | --- |
| `apx/com.android.tethering/priv-app/TetheringGoogle@…/TetheringGoogle.apk` | 解除热点客户端数量限制 |
| `apx/com.android.wifi/javalib/service-wifi.jar` | 锁 5G WiFi 信道 |
| `system/priv-app/NetworkStackGoogle/NetworkStackGoogle.apk` | 固定热点网关 |
| `post-fs-data.sh` | 把 `apx/<apex模块>/<相对路径>` bind mount 到 `/apex/<模块>/<相对路径>` 和 `/apex/<模块>@*/<相对路径>` |
| `service.sh` | 检测 `com.google.android.networkstack.tethering` 是否在用更新包，是则 `cmd package uninstall-system-updates` |

**默认值**：信道 36（可改 149），热点网关 `192.168.43.1`，USB 共享网关 `192.168.42.1`。

**可选配置**（在 `/data/` 下创建）：

```sh
echo 149 > /data/kano_ap_channel.cfg      # 信道，建议 36 或 149
echo 600 > /data/kano_softap_timeout      # 无连接自动关闭（秒），默认不关
echo 1   > /data/kano_is_hidden_ssid      # 隐藏 SSID
```

**验证 bind mount 生效**：

```powershell
adb shell "su -c 'mount | grep tethering'"
# 期望看到 /dev/block/mmcblk0p70（= userdata）挂在
# /apex/com.android.tethering/priv-app/TetheringGoogle@…/TetheringGoogle.apk
```

### 7.4 实测：热点能力

```powershell
adb shell "su -c 'dumpsys wifi | grep MaximumSupportedClientNumber'"
# MaximumSupportedClientNumber=10
```

支持的信道（来自驱动）：

```
2.4G: 1 2 3 4 5 6 7 8 9 10 11 12 13
5G  : 36 40 44 48 149 153 157 161 165
```

---

## 8. 步骤六：OpenWrt 装进 TF 卡（双系统）

### 8.1 前置：必须满足的条件

OpenWrt 安装器的 `preflight` 硬性要求（见 `magisk-tf-install.sh`）：

```sh
[ "$(id -u)" = 0 ] || fail 'root required'
[ "$(getprop ro.product.model)" = "E5" ] || fail 'wrong device model'
[ "$(getprop ro.boot.slot_suffix)" = _a ] || fail 'Android A / OpenWrt B only'
[ "$(getprop ro.boot.verifiedbootstate)" = orange ] || fail 'bootloader must be unlocked'
```

→ **必须先完成第 5、6 步**（解锁 + root）。

### 8.2 TF 卡的坑（重点）

安装器**优先使用卡的第一个分区**；没有分区才用整卡。

**实测踩坑**：一张带树莓派系统的 14.8 GB 卡，有 `p1`（46 MB vfat boot）+ `p2`（15.1 GB ext4 rootfs），
安装器报：

```
错误 / error: SD capacity is insufficient: /dev/block/mmcblk1 has 43.9 MiB;
the image requires 2048.0 MiB (minimum supported card: 2048 MiB). Nothing was written.
```

**原因**：它把 `p1` 的 46 MB 当成了目标。

**解决**：清空分区表，让安装器看到整卡 14.8 GB。

```sh
#!/system/bin/sh
# 卸载所有 TF 挂载
for v in $(sm list-volumes all | awk '$2=="mounted"{print $1}'); do sm unmount "$v"; done
sleep 2
# 擦除前 16 MB（含 MBR/GPT 主表）
dd if=/dev/zero of=/dev/block/mmcblk1 bs=1M count=16
sync
# 擦除尾部 32 扇区（GPT 备份表）
SECTORS=$(( $(blockdev --getsize64 /dev/block/mmcblk1) / 512 ))
dd if=/dev/zero of=/dev/block/mmcblk1 bs=512 seek=$((SECTORS-32)) count=32
sync
blockdev --flushbufs /dev/block/mmcblk1
blockdev --rereadpt /dev/block/mmcblk1
```

清完 `cat /proc/partitions | grep mmcblk1` 应该只剩 `mmcblk1` 一行。

### 8.3 安装

安装器有图形界面和 CLI 两种。CLI 方式（`tools/backend/openwrt-backend.exe`）：

```powershell
# 1) 只校验包，不碰设备
.\tools\backend\openwrt-backend.exe --cli --package-root . --no-pause --verify-package

# 2) 只检查设备，不写分区
.\tools\backend\openwrt-backend.exe --cli --package-root . --no-pause --check

# 3) 正式安装到 TF 卡
.\tools\backend\openwrt-backend.exe --cli --package-root . --no-pause --tf --ssid "E5-OpenWrt" -y
```

`--check` 的预期输出：

```
[1/3] 连接设备 / looking for Android (USB debugging on)
   ok (E5, root via su)
BOOTCHAIN-PLAN a b
[2/3] 从这台设备提取固件和基带文件
   ... 14 个 vendor 文件（60.6 MB）
[3/3] 检查完成，未修改分区
```

### 8.4 安装流程（9 个阶段）

```
[1/9] 连接设备 + 启动链检查
[2/9] 准备 SD 卡（14.84 GiB；不预留 OTA 空间）
[3/9] 从设备提取固件和基带（14 个文件）+ 解压 openwrt.ext4.gz（163 MiB）
[4/9] 写入 OpenWrt 到卡（约 181 秒）+ 回读校验（29 秒）+ 扩容到全卡
[5/9] 写入本机设置和设备文件（60.6 MB）
[6/9] 写入 boot.img 到 boot_b 并校验 + 备份 misc 32 字节控制块
[7/9] 完成，提示手动重启
```

实测总耗时 **274 秒**。

### 8.5 安装结果

```
热点 / hotspot:  E5-OpenWrt   密码 / key:  j9b3p6rg2z
管理 / admin:    http://192.168.9.1  (LuCI, root / root)
回 Android:      屏幕 高级 -> 系统 -> 下次启动 Android, or: e5-next-boot android; reboot
```

卡上的 `/etc/e5/install.conf`：

```sh
E5_APN=''
E5_WIFI_SSID='E5-OpenWrt'
E5_WIFI_KEY='j9b3p6rg2z'
E5_WIFI_CHANNEL='149'
E5_DEFAULT_BOOT='linux'
```

`/etc/e5/sd-root` 标记：`e5-openwrt-sd 2026-10-31 4830ff6b8ae5`

### 8.6 启动

**第一次启动约 2 分钟**，屏幕会亮起 OpenWrt 信息屏。

实测：第一次重启后**回到了 Android**（试启动失败回退），**再重启一次**才成功进入 OpenWrt。
所以如果第一次没进去，**别慌，再重启一次**。

成功后验证：

```powershell
# LuCI 首页
Invoke-WebRequest http://192.168.9.1/ -UseBasicParsing   # 200，重定向到 cgi-bin/luci/

# 端口
# :22 SSH  :80 HTTP  :443 HTTPS  :53 DNS
```

LuCI 登录（表单）：

```
POST http://192.168.9.1/cgi-bin/luci/
luci_username=root&luci_password=root
→ 302，标题「状态看板 - E5」
```

系统信息：`OpenWrt 25.12.5 r33051-f5dae5ece4` / 内核 `6.18.54-e5-mobile4` / 板型 `Unisoc UMS9621-base Board`

---

## 9. 双系统切换机制

### 9.1 底层原理

切换**完全靠 `misc` 分区偏移 2048 处的 32 字节 AOSP 启动控制块**：

```
偏移 2048，32 字节，结构（来自 android-bootchain.sh 的 check_misc）：
  字节 0-3  : 槽位标识（_a / _b）
  字节 4-7  : 魔数 'BCAB' (66 67 65 66)
  字节 8    : 版本 = 1
  字节 9    : 槽位状态（低 3 位 = 2 表示 A 成功启动）
  字节 12   : slot_a 尝试计数（bit7=128 表示有效，低 4 位>0）
  字节 13   : slot_a 成功标志（bit0 必须 0）
  字节 14   : slot_b 尝试计数
  字节 15   : slot_b 成功标志（bit0 必须 0）
  字节 28-31: CRC32（多项式 0xEDB88320，初值/终值 0xFFFFFFFF）
```

`e5-bootctl` 二进制支持的动作：`android` / `linux` / `sd` / `arm` / `trial`

### 9.2 三种切换方式

| 方向 | 方式 | 命令 / 位置 |
| --- | --- | --- |
| OpenWrt → Android | 屏幕菜单 | 屏幕 → 高级 → 系统 → 下次启动 Android |
| OpenWrt → Android | SSH | `e5-next-boot android && reboot` |
| Android → OpenWrt | 切换器 App | `com.minikano.e5switch`（`extras/android/op-system-switcher.apk`） |
| 任意 → 指定 | 底层工具 | `e5-bootctl arm <backup>` |

### 9.3 安全性

- 只改 `misc` 的 32 字节，**不碰分区表、不碰 Android 数据**
- 切换只影响「下次启动」，不改默认策略
- 永久默认启动要在 OpenWrt 里设置
- **启动失败两次后自动回退 Android**
- 拔掉 TF 卡 = 自动回 Android

### 9.4 关于 recovery

**没有 recovery 入口**，原因：

1. 不是 AOSP 标准 AB 设备，用私有 BCAB 格式，没有 `bootctl` 标准接口
2. 70 个分区里**没有 `recovery` 分区**
3. 官改 ROM 已移除 recovery 依赖

---

## 10. 硬件能力的实测结论

### 10.1 内存（关键限制）

```
MemTotal:  1472556 kB  (约 1.4 GB)
MemFree:      14296 kB
MemAvailable: 414408 kB  (约 405 MB)
```

→ **Docker 基本跑不动**，重度服务不现实。

### 10.2 WiFi 是单射频（最重要的发现）

```powershell
adb shell "ls /sys/class/net/ | grep wlan"     # 只有 wlan0
adb shell "dumpsys wifi | grep num_concurrent_connection"   # 0
```

尝试「连着 WiFi 再开热点」时：

```
cmd wifi start-softap E5-TEST open
→ onStateChanged with state: 11 failure reason: 0
→ SAP is disabled
```

**结论**：**不支持 STA+AP 并发**。

- ❌ 不能当 WiFi 中继（连上游 WiFi 再转发）
- ✅ 可以当「SIM 卡 5G → WiFi 热点」
- ⚠️ **刷 OpenWrt 也改变不了**——这是射频硬件限制，不是软件问题

### 10.3 网络工具

| 工具 | Android 自带 | UFI-TOOLS 补充 |
| --- | --- | --- |
| iptables / ip6tables | ✅ | — |
| dnsmasq | ✅ | — |
| tcpdump | ✅ | — |
| ping | ✅ | — |
| nft | ❌ | — |
| curl / socat / iperf3 / jq / ttyd | ❌ | ✅（`/data/data/com.minikano.f50_sms/files/`） |

### 10.4 存储

| 分区 | 大小 |
| --- | --- |
| `userdata` | 22380 MB |
| `super` | 5600 MB |
| 实测 `/data` 可用 | 22 GB（已用 1.5 GB） |

---

## 11. 坑位合集

### 11.1 BROM 相关

| 问题 | 原因 | 解决 |
| --- | --- | --- |
| `adb.exe: Cannot mkdir 'C:\Users\<user>\.android': Permission denied` | 家目录不可写 | 重定向 `TMP`/`TEMP`/`HOME` 到可写目录 |
| `adb.log: Permission denied` | 同上 | 同上 |
| 驱动 `CM_PROB_FAILED_INSTALL` | 没装 SPRD 驱动 | `pnputil /add-driver ... /install`（需管理员） |
| 设备插上但系统看不到 | 纯充电线 / 虚拟机未直通 | 换数据线 / 配 USB 直通 |
| `EXEC FDL1` 后 `device removed` | 按键松手太早 | 按住 10 秒 |
| `exec_addr is 0x0` + `unexpected response (0x0089)` | FDL1 残留 | **取电池断电 10 秒** |
| `find port failed` | 设备出现即消失 | 让 `spd_dump` 自己 `--wait 600` 轮询，别用外部探测 |
| `usb_send failed (0 / 1)` | 半连接状态 | 拔插 USB 复位 |

### 11.2 刷机相关

| 问题 | 说明 |
| --- | --- |
| `FDL2: incompatible partition` | 正常提示，不影响 |
| 刷到一半 `device removed` | 取电池断电后**从头完整重刷**，`write_parts` 幂等 |
| 全零镜像被误判为损坏 | 先备份对比，真机对应分区本来可能就是空的 |
| `spd.bin` 1 GB 全零 | 下载失败的占位文件，不能用 |

### 11.3 Magisk 相关

| 问题 | 说明 |
| --- | --- |
| 用了原厂 `init_boot` 打补丁 | **错**，要用当前系统的那份（本例官改已改内核） |
| `su` 返回 `Permission denied` | root 已生效，只是 Shell 未授权，去 Magisk App 点允许 |
| `id -u` 返回 2000 | 正常，`adb shell` 是 shell 用户，要用 `su -c` |
| `adb pull` 报 `No such file or directory` | Windows 下某些盘符路径有问题，先 `cd` 到工作目录 |

### 11.4 模块相关

| 问题 | 说明 |
| --- | --- |
| `adb push` 中文文件名失败（`remote couldn't create file: Is a directory`） | 改成 ASCII 文件名再推 |
| `magisk --sqlite` 报 `Root is required` | 需要 `su -c` 包裹 |
| 模块装了但属性没变 | 必须**重启** |

### 11.5 OpenWrt 相关

| 问题 | 说明 |
| --- | --- |
| `SD capacity is insufficient: … has 43.9 MiB` | 卡有 46 MB 的 `p1`，安装器把它当整卡 → 清空分区表 |
| 第一次重启回到 Android | 试启动失败自动回退，**再重启一次** |
| LuCI `/cgi-bin/luci` 返回 403 | 正常，需登录；POST `luci_username=root&luci_password=root` |
| LuCI 页面显示「需要 JavaScript」 | Aurora 主题是 SPA，必须浏览器开 JS |
| ubus `file.exec` 返回空 | ACL 白名单限制，只能执行列表内命令 |

### 11.6 磁盘空间

**实测**：C 盘只剩 0.5 GB，装不下 6 GB 镜像。
→ 把工作区整体搬到空间充足的盘（本例 E 盘 127 GB 空闲），并修正脚本里的路径。

---

## 12. 救砖与回滚

### 12.1 从备份完整还原

进 BROM 后：

```bat
cd /d E:\e5flash\rom
bin\spd_dump.exe --wait 300 exec_addr2 0x65017f08 ^
  fdl bin\fdl1-dl.bin 0x65000800 fdl bin\fdl2-dl.bin 0xbefffe00 ^
  exec path "E:\e5flash\temp" ^
  write_parts "E:\e5flash\backup\20261031_074608\" reset
```

> 备份目录里的文件名就是分区名（`boot_a.bin` 等），可以直接被 `write_parts` 使用。
> 注意备份里**包含** `prodnv`、`nr_fixnv1_a`、`nr_modem_a` 等基带分区，还原时会一并写回。

### 12.2 只还原 boot

```bat
... exec path temp w init_boot_a "E:\e5flash\magisk\init_boot_a_stock_rom.img" reset
```

### 12.3 撤掉 OpenWrt（保留 Android）

```sh
# 在 Android 里
echo android > /data/e5linux/boot-os
# 或删掉该文件
rm /data/e5linux/boot-os
# 重启即回 Android；TF 卡可自行格式化
```

`boot_b` 里的 OpenWrt 内核留着不影响 Android（Android 从 slot a 启动）。

### 12.4 关键备份位置

| 内容 | 位置 |
| --- | --- |
| 原厂全分区 | `E:\e5flash\backup\20261031_074608`（68 文件 / 6.7 GB） |
| 官改 ROM | `E:\e5flash\rom`（5.97 GB） |
| Magisk 补丁镜像 | `E:\e5flash\magisk\magisk_patched_init_boot.img` |
| 官改原版 init_boot | `E:\e5flash\magisk\init_boot_a_stock_rom.img` |
| 原厂 init_boot | `E:\e5flash\magisk\init_boot_a_orig.bin` |
| 启动控制块备份 | 设备内 `/data/adb/e5-boot-control/before.*` |
| 启动链备份 | 设备内 `/data/adb/e5-bootchain/` |
| OpenWrt 安装包 | `e5-work\openwrt-pkg` |

---

## 13. 附：完整命令清单

### 13.1 备份

```bat
bin\spd_dump.exe --wait 300 --kickto 2 exec_addr2 0x65017f08 fdl bin\fdl1-dl.bin 0x65000800 fdl bin\fdl2-dl.bin 0xbefffe00 exec path "<BACKUP_DIR>" r all reset
```

### 13.2 完整刷机

```bat
bin\spd_dump.exe --wait 300 exec_addr2 0x65017f08 fdl bin\fdl1-dl.bin 0x65000800 fdl bin\fdl2-dl.bin 0xbefffe00 exec path temp write_parts "data\" e userdata verity 0 reset
```

### 13.3 增量更新（保数据）

```bat
bin\spd_dump.exe --wait 300 exec_addr2 0x65017f08 fdl bin\fdl1-dl.bin 0x65000800 fdl bin\fdl2-dl.bin 0xbefffe00 exec path temp w init_boot_a data\init_boot_a.bin w boot_a data\boot_a.bin w uboot_a data\uboot_a.bin w trustos_a data\trustos_a.bin w super data\super.bin verity 0 reset
```

### 13.4 刷 Magisk 补丁

```bat
bin\spd_dump.exe --wait 600 exec_addr2 0x65017f08 fdl bin\fdl1-dl.bin 0x65000800 fdl bin\fdl2-dl.bin 0xbefffe00 exec path temp w init_boot_a "<PATCHED_IMG>" reset
```

### 13.5 装模块

```powershell
adb push <MODULE>.zip /sdcard/Download/
adb shell "su -c 'magisk --install-module /sdcard/Download/<MODULE>.zip'"
adb reboot
```

### 13.6 OpenWrt 安装

```powershell
.\tools\backend\openwrt-backend.exe --cli --package-root . --no-pause --verify-package
.\tools\backend\openwrt-backend.exe --cli --package-root . --no-pause --check
.\tools\backend\openwrt-backend.exe --cli --package-root . --no-pause --tf --ssid "E5-OpenWrt" -y
```

### 13.7 状态检查

```powershell
# Android 侧
adb shell "getprop ro.boot.verifiedbootstate"   # orange
adb shell "su -c id"                            # uid=0(root)
adb shell "getprop service.adb.tcp.port"        # 5555
adb shell "su -c netstat -tlnp" | Select-String "2333"

# OpenWrt 侧
Invoke-WebRequest http://192.168.9.1/ -UseBasicParsing   # 200
```

### 13.8 切换

```sh
# OpenWrt → Android
e5-next-boot android && reboot

# 屏幕菜单
高级 → 系统 → 下次启动 Android

# Android → OpenWrt
打开「系统切换器」App → 选 OpenWrt → 重启
```

---

## 参考

- [awesome-e5](https://github.com/r4ym0n/awesome-e5) — 资源索引
- [TomKing062/spreadtrum_flash](https://github.com/TomKing062/spreadtrum_flash) — `spd_dump` 开源实现
- [TomKing062/CVE-2022-38694_unlock_bootloader](https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader) — BL 解锁研究
- [kanoqwq/UFI-TOOLS](https://github.com/kanoqwq/UFI-TOOLS) — UFI 管理后台
- [Hovatek T158 线程](https://www.hovatek.com/forum/thread-49605.html) — 进阶移植

---

**License**: 本文档采用 [CC0-1.0](../LICENSE)，与仓库一致。
