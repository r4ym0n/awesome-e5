# 故障手册

按症状查。每条都是实刷过程中真实遇到的。

## A. 环境与工具链

### A1 `adb.exe: Cannot mkdir 'C:\Users\<user>\.android': Permission denied`

**原因**：家目录不可写（受限账户 / 沙箱 / 家目录 ACL 异常）。

**处理**：重定向临时目录。`scripts/e5.ps1` 已内置（`Initialize-Env`）。

手动版：

```powershell
$w = "C:\temp\e5"
New-Item -ItemType Directory -Force -Path "$w\tmp","$w\home" | Out-Null
$env:TMP = "$w\tmp"; $env:TEMP = $env:TMP
$env:HOME = "$w\home"; $env:ANDROID_USER_HOME = $env:HOME
adb devices
```

### A2 `adb.log: Permission denied` / `cannot open C:\...\Temp\adb.log`

同 A1，临时目录不可写。

### A3 执行脚本报 `AuthorizationManager 检查失败` / `UnauthorizedAccess`

**原因**：PowerShell 执行策略。

**处理**：

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
```

或 `powershell -ExecutionPolicy Bypass -File .\e5.ps1 help`。

### A4 找不到 `spd_dump.exe` / `fdl1-dl.bin`

**处理**：显式指定

```powershell
./e5.ps1 detect -SpdDir "E:\e5flash\rom\bin"
```

或设环境变量 `E5_SPD_DIR`。

### A5 `spd_dump` 里 `exec_addr2` 不认

**原因**：用了 `LibUSB_Release` 的 stable 版（只有 `exec_addr`），或用了开源版。

**处理**：必须用官改包 `bin/` 里的 **定制版 ver:228**（82432 字节，SPRD 驱动版）。

```powershell
(Get-Item .\spd_dump.exe).Length   # 期望 82432
.\spd_dump.exe --help 2>&1 | Select-String "ver:"
# 期望 ver:228
```

### A6 `custom_exec_no_verify` 地址对不上

**坑**：e5-tools 里的那份叫 `custom_exec_no_verify_65012f48.bin`（地址 `0x65012f48`），
官改包里的是 `custom_exec_no_verify_65017f08.bin`（地址 `0x65017f08`）。

**不能混用**。用哪个 FDL 就必须配对应地址的 `custom_exec`。

## B. 驱动与设备识别

### B1 设备管理器显示 `CM_PROB_FAILED_INSTALL`，FriendlyName 为空

**原因**：SPRD 驱动没装。

**处理**（需管理员）：

```cmd
pnputil /add-driver "<ROM>\刷机驱动_SPD_Driver_R4.20.4201\Win10&win11\Drivers\sprdvcom.inf" /install
```

或跑 `DriverSetup.exe`。

验证：

```powershell
pnputil /enum-drivers | Select-String "sprdvcom" -Context 0,3
# 期望 Provider Name: UNISOC Communications Inc. / Class Name: Ports
```

### B2 插上手机系统完全看不到任何新设备

按概率排查：

1. **纯充电线** —— 换一根确定能传数据的
2. **虚拟机未直通** —— 检查 USB 直通设置（PVE/VMware/Hyper-V）
3. **没进 BROM** —— 按键时序不对（见 C1）
4. **手机没电** —— 充电 10 分钟再试

用 PnP 快速确认：

```powershell
Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match "VID_1782" } |
  Select-Object Status, Class, FriendlyName, Problem
```

### B3 设备出现但 `Status=Error`

驱动缺失。见 B1。

### B4 `find port failed`

**原因**：设备出现的窗口只有几百毫秒，外部探测来不及反应。

**处理**：不要用「外部轮询 + 再启动 spd_dump」的两段式，
让 `spd_dump` 自己 `--wait 600` 持续轮询。

```powershell
./e5.ps1 backup -Out <dir> -Timeout 600
```

### B5 `usb_send failed (0 / 1)`

**原因**：BROM 半连接状态（上一次进程被强杀 / 超时）。

**处理**：拔掉 USB，等 2 秒，按住返回键重新插入。

## C. BROM 进入与保持

### C1 `EXEC FDL1` 后立刻 `[send] device removed, exiting...`

**原因**：按键松手太早。BROM 靠「返回键被按住」维持。

**处理**：插线后继续按住，按时长表：

| 目标 | 需按住 |
| --- | --- |
| `init_boot_a`（8 MB） | ≥ 5 秒 |
| 全分区备份（6.7 GB） | 全程约 5 分钟 |
| `super`（5.6 GB） | 全程约 3 分钟 |

### C2 `exec_addr is 0x0` + `unexpected response (0x0089)`

**原因**：**FDL1 残留**。上次操作中断后，FDL1 还在手机内存里，
bootloader 不会重新走 BROM，而是从 FDL1 阶段继续。

**处理（唯一有效）**：

```
拔 USB → 取出电池 → 等 10 秒 → 装回 → 按住返回键 → 插 USB
```

> 只是「关机」不够，**必须断电**。FDL1/FDL2 是内存中的程序，只有断电才清。

### C3 一直进不了 BROM

逐条核对：

1. 是否**完全关机**（不是重启、不是锁屏）
2. 是否**取过电池**（清残留）
3. 是否**先按住键再插线**（顺序反了无效）
4. 是否按的是**返回键**（不是电源键、不是音量键）
5. 电池接触是否良好（E5 可拆，装回要按紧）

## D. 备份

### D1 备份文件数偏少 / 有零字节文件

**原因**：中途断开。

**处理**：断电重进 BROM，重新完整备份。**不要用不完整的备份**。

### D2 `prodnv` 缺失

**严重**。`prodnv` 是基带 / IMEI / 射频校准，ROM 包里没有这个镜像，
所以刷机不会覆盖它 —— 但如果备份里没有，一旦误擦就无法恢复（机器没信号）。

**处理**：重新完整备份，确认 `prodnv.bin` = 64 MB 且非零。

### D3 备份里某些分区是全零，是否正常？

**看情况，必须先对比**。实测 `dtb_a` / `hypervsior_a` / `common_rs2_a` / `avbmeta_rs_a`
在**真机上本来就是全零**。

判断方法：

```powershell
# 对比 ROM 与备份的密度
# 两者都接近 0% → 正常
# ROM 有数据但备份全零 → 备份有问题
```

## E. 刷机

### E1 `FDL2: incompatible partition`

**正常提示**，PC 与设备的 GPT 缓存不一致，不影响后续读写。忽略。

### E2 刷到一半 `device removed`

**后果**：半刷状态。引导链可能已改但 `super` 没写 → **必然开不了机**。

**处理**：

```
取电池断电 10 秒 → 重进 BROM → 从头完整重刷
```

`write_parts` 是幂等的，重复写相同数据无害。**不要试图「接着刷」**。

### E3 `target != written`（截断）

日志形如：

```
Write Part Done: super, target: 0x15e000000, written: 0x0
```

说明该分区没写完整。按 E2 处理，完整重刷。

### E4 刷完开不了机

**先判断是否预期**：

- 只刷了部分分区（如中断）→ 预期，完整重刷
- 完整刷机后仍不开 → 检查 `boot_a` / `init_boot_a` / `super` 是否都写了

救砖见「12. 救砖与回滚」。

### E5 全零镜像被误判为损坏

见 D3。**先备份对比再下结论**。

## F. Magisk / root

### F1 用了原厂 `init_boot` 打补丁

**错**。要用**当前设备上正在运行的那份**。

实测：原厂 `init_boot_a` 哈希 `3499fa8a…`，官改版 `c18561d4…`，**不同**。
官改改了内核，必须用 ROM 里那份（等于刚刷进去的）。

### F2 `su` 返回 `Permission denied`

**说明 root 已生效**，只是 Shell 未授权。

**处理**：打开 Magisk App → 超级用户 → 允许 `Shell`。

验证：

```powershell
adb shell "magisk -v"     # 期望 ...:MAGISK:R   ← 末尾 R = root 已加载
adb shell "ps -A | grep magisk"   # 应有 magiskd
```

### F3 `id -u` 返回 `2000`

**正常**。`adb shell` 默认是 shell 用户。要用 `su -c`：

```powershell
adb shell "su -c id"      # uid=0(root)
```

### F4 `magisk --sqlite` 报 `Root is required`

需要 `su -c` 包裹：

```powershell
adb shell "su -c 'magisk --sqlite \"select * from policies\"'"
```

### F5 补丁镜像 magic 不是 `ANDROID!`

```powershell
# 前 8 字节应为 414E44524F494421
```

不是的话说明补丁失败或拉取损坏。重新打补丁。

### F6 `adb pull` 报 `No such file or directory`

**原因**：Windows 下 adb 对某些绝对路径（尤其带盘符）处理有问题。

**处理**：先 `cd` 到目标目录再 pull：

```powershell
Push-Location $Dest
adb pull /sdcard/Download/magisk_patched-xxx.img
Pop-Location
```

## G. Magisk 模块

### G1 `adb push` 中文文件名失败

```
adb: error: failed to copy 'E:\...\荣悦E5热点模块v4.zip' to '/sdcard/Download/.':
remote couldn't create file: Is a directory
```

**处理**：改成 ASCII 文件名再推。`e5.ps1 magisk-install` 已自动处理。

### G2 模块装了但属性没变

**必须重启**。

```powershell
./e5.ps1 reboot
./e5.ps1 verify -Full
```

### G3 热点模块装了但限制还在

检查 apex bind mount：

```powershell
adb shell "su -c 'mount | grep tethering'"
```

期望看到：

```
/dev/block/mmcblk0p70 on /apex/com.android.tethering/priv-app/TetheringGoogle@.../TetheringGoogle.apk
```

`mmcblk0p70` = `userdata`，说明 bind mount 生效。

没看到 → 模块未启用（`/data/adb/modules/<id>/disable` 存在）或未重启。

### G4 UFI-TOOLS 后台打不开

1. 检查进程：`adb shell "ps -A | grep f50_sms"`
2. 检查端口：`adb shell "su -c netstat -tlnp"` → 应有 `:2333`
3. 检查网络：设备必须拿到 IP（`ip -4 addr` 有 `wlan0` 的 inet）
4. 浏览器访问 `http://<手机IP>:2333`

## H. OpenWrt

### H1 `SD capacity is insufficient: ... has 43.9 MiB`

**原因**：安装器优先用「卡的第一个分区」，而 `p1` 很小（如 46 MB 的树莓派 boot 分区）。

**处理**：清空分区表。

```powershell
./e5.ps1 wipe-tf
```

清完 `cat /proc/partitions | grep mmcblk1` 应只剩 `mmcblk1` 一行。

### H2 第一次重启回到 Android

**预期行为**。安装器写的是「试启动」标记，失败会两次后回退。

**处理**：**再重启一次**。

### H3 两次都进不去 OpenWrt

1. 检查 `boot_b` 是否真写了 OpenWrt 内核：
   ```powershell
   adb shell "su -c 'dd if=/dev/block/by-name/boot_b bs=1 count=8 2>/dev/null | base64'"
   # 期望 ANDROID! (base64: QU5EUk9JRCE=)
   ```
2. 检查 TF 卡是否可读：`adb shell "su -c 'dd if=/dev/block/mmcblk1 bs=512 count=1 | wc -c'"`
3. 检查 TF 卡上的根：
   ```powershell
   adb shell "su -c 'mkdir -p /data/local/tmp/o && mount -t ext4 -o ro,loop /dev/block/mmcblk1 /data/local/tmp/o && ls /data/local/tmp/o'"
   ```

### H4 LuCI 返回 403

**正常**，需登录。POST 表单：

```
POST http://192.168.9.1/cgi-bin/luci/
luci_username=root&luci_password=root
→ 302
```

### H5 LuCI 页面显示「需要 JavaScript」

Aurora 主题是 SPA，必须浏览器开 JS。命令行抓 HTML 只能看到骨架，属正常。

### H6 ubus `file.exec` 返回空 / `Invalid parameters`

LuCI 的 ACL 是**白名单**，只能执行列表里的命令。`/usr/bin/e5-next-boot` 不在列表里。

可用的写入通道：

| 通道 | 范围 |
| --- | --- |
| `file.read` | 大部分路径可读 |
| `file.write` | 仅 `/etc/rc.local`、`/etc/crontabs/root`、`/etc/firewall.user`、`/etc/sysupgrade.conf`、`/etc/luci-uploads/*`、`/www/luci-static/aurora/{fonts,images}/*` |
| `uci` | `aurora` `dhcp` `dropbear` `e5-bluetooth` `e5-infoscreen` `e5-notify` `firewall` `fstab` `luci` `network` `system` `ttyd` `uhttpd` `unisoc_modem` `wireless` |

> 想加自定义 LuCI 页面 → 受限于 ACL，需改用其他方式（屏幕菜单 / SSH / 切换器 App）。

### H7 SSH 连不上

1. 端口：`:22` 应 OPEN
2. 密码：默认 `root` / `root`
3. Windows 的 `ssh` 会等交互输入，脚本里用 `echo y | ssh ...` 或改用 paramiko

> 实测：安装包自带的 paramiko 依赖不全（`cryptography.hazmat.backends` 缺失），
> 系统 Python 也没装。要么 `pip install paramiko`（需网络），要么用 LuCI 的 ubus。

## I. 硬件能力误判

### I1 想当 WiFi 中继（连 WiFi 再开热点）

**做不到**。单射频硬件限制：

```
ls /sys/class/net/ | grep wlan    →  只有 wlan0
dumpsys wifi | grep num_concurrent →  num_concurrent_connection: 0
cmd wifi start-softap <SSID> open  →  SAP is disabled
```

刷 OpenWrt **也改变不了**。只能「SIM 5G → 热点」。

### I2 想跑 Docker

内存 1.4 GB（可用约 405 MB），不现实。

### I3 热点只能连 5 台

默认限制。装热点优化模块后 `MaximumSupportedClientNumber=10`。

## J. 磁盘空间

### J1 `No space left on device` / 解压失败

**实测**：C 盘只剩 0.5 GB，装不下 6 GB 镜像。

**处理**：把工作区整体搬到空间充足的盘，并修正脚本里的路径。

```powershell
robocopy "C:\...\rom" "E:\e5flash\rom" /E /MOVE
```

> 注意：搬完要更新脚本里的 `ROM` 路径变量，或统一用 `-Rom` / `-SpdDir` 参数传入。
