---
name: rongyue-e5-flash
description: Flash, root, and dual-boot a RongYue E5 (荣悦 E5 / Unisoc T158 keyboard 5G phone). Covers BROM-mode full-partition backup, official mod ROM flashing, Magisk root via patched init_boot, UFI-TOOLS and hotspot modules, and installing OpenWrt to a TF card with Android/OpenWrt switching. Use when the user asks to flash, back up, root, unlock, install Magisk modules, or install OpenWrt on a RongYue E5 or any Unisoc T158 keyboard phone.
---

# 荣悦 E5 一键刷机

面向 agent 的可执行手册。所有命令都封装在 `scripts/e5.ps1` 里，用子命令调用。
本 skill 假设目标是**荣悦 E5（Unisoc T158）**；同方案公模（如 POMP ED351 5G）可参考，但分区表与 FDL 需重新核对。

## 什么时候用

- 用户要求刷机 / 备份 / 解锁 / root / 装模块 / 装 OpenWrt，且机型是荣悦 E5 或 T158 键盘机
- 用户已有官改包、e5-tools、OpenWrt 整包等物料，需要有人把流程跑通
- 用户设备变砖，需要用备份还原

## 什么时候不要用

- 机型不是 T158 平台（中兴 F50 是 T760，**固件与工具完全不通用**）
- 用户没有备份、也不同意先做备份 —— 备份是硬门槛，不接受跳过
- 用户目标是「WiFi 中继」—— 见「硬件真相」，这台机器做不到

## 硬性前置

开工前逐条确认，缺一条就停下来问用户，不要自行绕过：

| 项 | 检查方式 | 不满足怎么办 |
| --- | --- | --- |
| Windows x64 宿主机 | `$env:OS` | macOS/Linux 可跑但坑多，优先 Windows |
| **管理员权限**（装驱动） | `([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrator')` | 让用户手动提权执行 `pnputil` |
| SPRD 驱动已装 | `pnputil /enum-drivers` 里有 `sprdvcom.inf` | 见「阶段 1」 |
| 磁盘空间 ≥ 16 GB 空闲 | 备份 7 GB + 镜像 6 GB | 换盘，**不要**在剩几百 MB 的盘上开工 |
| 数据线能传数据 | 换线测试 | 纯充电线插上不会有任何 USB 枚举 |
| 官改包 / OpenWrt 包 / 模块包 | 见 `references/materials.md` | 让用户提供 |
| 手机电量 ≥ 50% | 用户确认 | 刷机中途断电 = 半刷状态 |

## 核心认知：BROM 三阶段（最容易翻车的地方）

```
bootrom (BROM)  →  FDL1  →  FDL2
  ↑ 芯片固化         ↑ 内存中     ↑ 内存中，能读写分区
```

**这是本 skill 最重要的一条**：

- `BROM` 只有**彻底断电**才退出
- `FDL1` / `FDL2` 是**加载到手机内存里的程序**，拔线、松手**都不会**清掉
- 所以任何中途失败后，必须**取出电池断电 10 秒**，否则下次连接会从 FDL1 残留继续，
  报 `exec_addr is 0x0` / `unexpected response (0x0089)`

### 进 BROM 的唯一正确时序

```
关机 → 取电池 → 等 3 秒 → 装回 → 按住返回键不放 → 插 USB → 继续按住 10 秒
```

**按住时长按目标分区的写入耗时决定**：

| 目标 | 大小 | 需按住 |
| --- | --- | --- |
| `init_boot_a` | 8 MB | ≥ 5 秒 |
| 全分区备份 | 6.7 GB | 全程（约 5 分钟） |
| `super`（完整刷机） | 5.6 GB | 全程（约 3 分钟） |

松手太早的典型症状：`EXEC FDL1` 之后立刻 `[send] device removed, exiting...`

## 工作流

每个阶段都有**验证闸门**，不通过就不要进下一阶段。

### 阶段 0：清点物料

```powershell
./scripts/e5.ps1 detect
```

输出宿主机环境、驱动状态、设备状态（BROM / ADB / 无）、磁盘余量。
把结果念给用户确认，特别是「设备状态」。

### 阶段 1：装 SPRD 驱动

需要管理员。让用户执行，或 agent 在已提权的会话里执行：

```powershell
pnputil /add-driver "<ROM>\刷机驱动_SPD_Driver_R4.20.4201\Win10&win11\Drivers\sprdvcom.inf" /install
```

验证：

```powershell
pnputil /enum-drivers | Select-String -Pattern "sprdvcom" -Context 0,3
```

期望 `Provider Name: UNISOC Communications Inc.` / `Class Name: Ports`。

驱动 INF 里 `USB\VID_1782&PID_4D00` 对应 `%USBCOMM_DL%`，就是 BROM 下载口。

### 阶段 2：全分区备份（**不可跳过**）

```powershell
./scripts/e5.ps1 wait-brom -Timeout 600     # 提示用户按上面时序插线
./scripts/e5.ps1 backup -Out "E:\e5flash\backup\$(Get-Date -f yyyyMMdd_HHmmss)"
```

闸门（脚本内置，也会打印）：

- 文件数 ≥ 60，总大小 ≈ 6.7 GB
- **零字节文件数 = 0**
- 关键分区存在且非零：`splloader` `uboot_a` `trustos_a` `sml_a` `boot_a` `vbmeta_a` `misc` **`prodnv`** `persist` `nr_fixnv1_a`

> **`prodnv`（64 MB）是基带 / IMEI / 射频校准。** 官改 ROM 里没有这个镜像，所以刷机不会覆盖它，
> 但备份里必须有 —— 丢了机器没信号。

备份完成后设备会 `reset` 重启回 Android，属正常。

### 阶段 3：刷官改 ROM

先判断用户机器状态：

- **原厂 / 不确定** → `-Mode full`（清空 userdata）
- **之前装过同一作者官改** → `-Mode keepdata`（只写 5 个分区）

```powershell
./scripts/e5.ps1 flash -Rom "E:\e5flash\rom" -Mode full
```

闸门（脚本内置）：

1. `data\` 里每个 `.bin` 的文件名都能在真实分区表里找到
2. 打印「全零镜像清单」并**对照备份**确认这些分区在真机上本来就是空的

> **全零镜像不是损坏。** 实测 `dtb_a` / `hypervsior_a` / `common_rs2_a` / `avbmeta_rs_a`
> 在 ROM 里是全零，**真机对应分区也是全零**。只有先做备份才能确认这一点。

成功标志：

```
Write Part Done: super, target: 0x15e000000, written: 0x15e000000
```

`target == written` 才是完整写入。若中途 `device removed`：

- 取电池断电 → 重进 BROM → **从头完整重刷**
- `write_parts` 幂等，重复写相同数据无害
- 此时开不了机是**正常的**（引导链改了但 `super` 没写）

刷完验证：

```powershell
./scripts/e5.ps1 verify
```

期望 `verifiedbootstate=orange`（已解锁 + 去 AVB）。

### 阶段 4：Magisk 拿 root

**关键细节**：要用**当前设备上正在运行的那份** `init_boot`，不是原厂的。
官改改了内核，两者哈希不同（实测原厂 `3499fa…` vs 官改 `c18561…`）。

流程是「取镜像 → App 打补丁 → BROM 写回」，因为此时没 root，`adb` 读不了块设备：

```powershell
# 1) 推送原始 init_boot（用 ROM 里的，等于设备当前那份）
./scripts/e5.ps1 magisk-prepare -Image "<ROM>\data\init_boot_a.bin"
```

然后在**手机上**操作（agent 无法代做）：

```
Magisk → 安装 → 选择并修补一个文件 → Download/init_boot.img → 开始
```

```powershell
# 2) 拉回补丁镜像并校验（magic 必须是 ANDROID! = 414e44524f494421，大小 8388608）
./scripts/e5.ps1 magisk-fetch

# 3) BROM 写回
./scripts/e5.ps1 wait-brom -Timeout 600
./scripts/e5.ps1 flash-initboot -Image "E:\e5flash\magisk\magisk_patched_init_boot.img"
```

开机后让用户在 Magisk App 里给 `Shell` 授予超级用户权限，然后：

```powershell
./scripts/e5.ps1 verify
```

期望：

```
uid=0(root) gid=0(root) groups=0(root) context=u:r:magisk:s0
magisk -v → 1e3edb88:MAGISK:R     ← 末尾 R 表示 root 已加载
```

> `adb shell` 下 `id -u` 返回 `2000` 是正常的，必须用 `su -c`。

### 阶段 5：UFI-TOOLS 与热点模块（可选）

```powershell
./scripts/e5.ps1 magisk-install -Module "E:\e5flash\ufi\UFI-TOOLS_for_Unisoc_devices.zip"
./scripts/e5.ps1 magisk-install -Module "E:\e5flash\ufi\hotspot_v4.zip"
./scripts/e5.ps1 reboot
```

> **模块包必须用 ASCII 文件名推送。** 中文名会失败：
> `adb: error: failed to copy '…中文.zip' to '/sdcard/Download/.': remote couldn't create file: Is a directory`

验证：

```powershell
./scripts/e5.ps1 verify -Full
```

期望：`ro.debuggable=1`、`service.adb.tcp.port=5555`、`getenforce=Permissive`、`:2333` 在监听。

### 阶段 6：OpenWrt 装 TF 卡（可选）

前置：阶段 3、4 已完成（安装器 `preflight` 会硬性检查 root + `orange` + slot `_a`）。

```powershell
# 先只检查，不写分区
./scripts/e5.ps1 openwrt-tf -Package "E:\e5flash\openwrt-pkg" -CheckOnly

# 正式安装
./scripts/e5.ps1 openwrt-tf -Package "E:\e5flash\openwrt-pkg" -Ssid "E5-OpenWrt"
```

**TF 卡有分区会失败**（安装器优先用「第一分区」）。若卡上有小分区（如 46 MB 的树莓派 boot 分区）：

```
error: SD capacity is insufficient: /dev/block/mmcblk1 has 43.9 MiB;
the image requires 2048.0 MiB
```

先清空分区表：

```powershell
./scripts/e5.ps1 wipe-tf     # 会二次确认；只擦前 16 MB + 尾部 32 扇区
```

安装耗时约 **274 秒**。完成后**手动重启**。

> **第一次重启可能回到 Android** —— 安装器写的是「试启动」标记，失败会两次后回退。
> 实测第一次回到 Android，**再重启一次**才进 OpenWrt。第一次没进去不必紧张。

进入 OpenWrt 后：`http://192.168.9.1`，`root` / `root`。

### 阶段 7：双系统切换

切换靠 `misc` 分区偏移 2048 处的 **32 字节 AOSP 启动控制块**（展锐私有 `BCAB` 格式）。

| 方向 | 方式 |
| --- | --- |
| OpenWrt → Android | 屏幕 → 高级 → 系统 → 下次启动 Android |
| OpenWrt → Android | `e5-next-boot android && reboot` |
| Android → OpenWrt | App `com.minikano.e5switch` |

`e5-bootctl` 支持 `android` / `linux` / `sd` / `arm` / `trial`。

**没有 recovery 入口**：70 个分区里没有 `recovery`，用私有格式而非 AOSP 标准 AB，
所以也没有标准 `bootctl`。不要向用户承诺「recovery 里选系统」。

## 硬件真相（不要给用户错误预期）

| 项 | 实测值 | 影响 |
| --- | --- | --- |
| RAM | 1472556 kB ≈ **1.4 GB**（可用约 405 MB） | Docker / 重度服务不现实 |
| WiFi 接口 | **只有 `wlan0`** | — |
| STA+AP 并发 | **`num_concurrent_connection: 0`** | **不能当 WiFi 中继** |
| 开热点（连 WiFi 时） | `SAP is disabled` | 只能「SIM 5G → 热点」 |
| 热点最大客户端 | 10（装模块后解除原限制） | — |
| 支持信道 | 2.4G 1-13；5G 36/40/44/48/149/153/157/161/165 | — |

**关键结论**：单射频是**硬件限制**，刷 OpenWrt 也改变不了。
如果用户目标是「连家里 WiFi 再开热点转发」，直接告诉他做不到，不要让他白折腾。

## 故障处理

按症状查表。完整版见 `references/troubleshooting.md`。

| 症状 | 原因 | 处理 |
| --- | --- | --- |
| `adb.exe: Cannot mkdir 'C:\Users\<u>\.android': Permission denied` | 家目录不可写 | 重定向 `TMP`/`TEMP`/`HOME` 到可写目录（脚本已内置） |
| 驱动 `CM_PROB_FAILED_INSTALL` | 没装 SPRD 驱动 | 阶段 1 |
| 设备插上系统完全看不到 | 纯充电线 / 虚拟机未直通 | 换线 / 配 USB 直通 |
| `EXEC FDL1` 后 `device removed` | 按键松手太早 | 按住 10 秒 |
| `exec_addr is 0x0` + `unexpected response (0x0089)` | FDL1 残留 | **取电池断电 10 秒** |
| `find port failed` | 设备出现即消失，探测有延迟 | 让 `spd_dump` 自己 `--wait 600` 轮询 |
| `usb_send failed (0 / 1)` | 半连接状态 | 拔插 USB 复位 |
| `FDL2: incompatible partition` | PC 与设备 GPT 缓存不一致 | **正常提示，忽略** |
| 刷完开不了机 | 引导链改了但 `super` 没写 | 完整重刷 |
| `su` 返回 `Permission denied` | root 已生效，Shell 未授权 | Magisk App 点允许 |
| `adb pull` 报 `No such file or directory` | Windows 盘符路径问题 | 先 `cd` 到工作目录再 pull |
| `SD capacity is insufficient` | 卡有小的 `p1` | `wipe-tf` |
| OpenWrt 首次重启回 Android | 试启动回退 | 再重启一次 |

## 救砖

```powershell
# 用备份完整还原（备份目录里的文件名就是分区名，可直接给 write_parts）
./scripts/e5.ps1 flash -Rom "<BACKUP_DIR>" -Mode raw

# 只还原 init_boot
./scripts/e5.ps1 flash-initboot -Image "<原版 init_boot>"
```

撤掉 OpenWrt 保留 Android：

```sh
echo android > /data/e5linux/boot-os    # 或删掉该文件
```

`boot_b` 里的 OpenWrt 内核留着不影响 Android（Android 从 slot a 启动）。

## 脚本参考

单入口 `scripts/e5.ps1`，子命令：

| 子命令 | 作用 |
| --- | --- |
| `detect` | 环境 / 驱动 / 设备 / 磁盘 |
| `wait-brom -Timeout <s>` | 等 BROM 出现，200 ms 轮询 |
| `backup -Out <dir>` | 全分区备份 + 校验闸门 |
| `flash -Rom <dir> -Mode full\|keepdata\|raw` | 刷机 / 增量 / 还原 |
| `flash-initboot -Image <img>` | 写 `init_boot_a` |
| `magisk-prepare -Image <img>` | 推原始 `init_boot` 到设备 |
| `magisk-fetch [-Dest <dir>]` | 拉补丁镜像 + 校验 |
| `magisk-install -Module <zip>` | 推 + `magisk --install-module` |
| `openwrt-tf -Package <dir> [-CheckOnly] [-Ssid]` | OpenWrt 装 TF 卡 |
| `wipe-tf [-Yes]` | 清 TF 分区表 |
| `probe` | 设备能力探测（内存/WiFi/工具） |
| `verify [-Full]` | root / 解锁 / 属性 / 端口 |
| `reboot` | 重启设备 |

通用参数：`-SpdDir`（含 `spd_dump.exe` + fdl 的目录）、`-BackupRoot`、`-WorkDir`。
不传则按 `E:\e5flash\rom` / `E:\e5flash\backup` 猜，猜不到就报错要求显式传。

## 给 agent 的几条纪律

1. **备份没做完，不许写任何分区。** 这是唯一不可协商的规则。
2. **每次进 BROM 前，先确认设备不在 FDL1 残留状态**（`detect` 会看 `exec_addr`）。
3. **刷机中断不要慌，先断电重进，再完整重刷。** 不要试图「接着刷」。
4. **全零镜像先对照备份再下结论**，不要直接判定为损坏。
5. **中文路径 / 中文文件名**是高频坑：模块包用 ASCII 名推送；`adb pull` 先 `cd`。
6. **不要承诺 WiFi 中继**，这是硬件限制。
7. 阶段之间停下来跟用户确认，特别是「会清空数据」的操作。

## 参考

- `references/materials.md` — 物料清单与目录结构
- `references/partition-table.md` — 70 个分区完整表
- `references/boot-control.md` — `misc` BCAB 32 字节结构 + CRC32
- `references/troubleshooting.md` — 完整故障手册
- 完整实刷记录：<https://github.com/r4ym0n/awesome-e5/blob/main/docs/field-notes-full-walkthrough.md>
