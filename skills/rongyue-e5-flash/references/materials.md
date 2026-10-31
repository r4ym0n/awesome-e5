# 物料清单与目录结构

## 必须有的物料

| 物料 | 大小 | 用途 | 来源 |
| --- | --- | --- | --- |
| 官改 ROM（V4，去 data 加密 / ADB 默认开） | 1.69 GB 压缩 / 5.97 GB 解压 | 解锁 BL + 去 AVB + 系统 | 社区网盘（见 awesome-e5 README） |
| OpenWrt 整包（e5-linux） | 245 MB | 双系统 | 社区 / e5-linux 仓库 |
| UFI-TOOLS 通用模块 | 17.8 MB | 随身 WiFi 管理后台 | `pan.kanokano.cn/UFI-TOOLS-UPDATE/universal/` |
| 热点优化模块 v4（荣悦E5 专用） | 2.49 MB | 解热点限制 / 锁信道 / 固定 IP | `pan.kanokano.cn/UFI-TOOLS-UPDATE/Magisk模块/` |
| SPRD 驱动 | 含在官改包里 | Windows 识别 BROM | `rom/刷机驱动_SPD_Driver_R4.20.4201/` |
| adb + scrcpy | 含在 e5-tools 里 | Android 侧操作 | 官方 platform-tools 亦可 |

> **不要混用**：中兴 F50 是 **T760** 平台，固件/工具/FDL **完全不通用**。

## 官改包目录结构

```
rom/
├─ bin/
│  ├─ spd_dump.exe                        # 定制版 ver:228，支持 exec_addr2
│  ├─ fdl1-dl.bin                         # 62024 B
│  ├─ fdl2-dl.bin                         # 1035432 B
│  ├─ Channel.ini / Channel9.dll          # 串口驱动配置
│  ├─ custom_exec_no_verify_65017f08.bin  # 96 B，绕过 BROM 签名校验
│  └─ customexec_no_verify_65017f08.bin   # 同上（拼写不同，两份）
├─ data/                                  # 31 个分区镜像，5.91 GB
│  ├─ splloader.bin                        0.07 MB
│  ├─ uboot_a.bin                          1.21 MB
│  ├─ trustos_a.bin                        3.40 MB
│  ├─ sml_a.bin                            0.15 MB
│  ├─ teecfg_a.bin                         0.12 MB
│  ├─ boot_a.bin                          64.00 MB
│  ├─ init_boot_a.bin                      8.00 MB
│  ├─ vendor_boot_a.bin                  100.00 MB
│  ├─ vbmeta_a.bin                         1.00 MB
│  ├─ vbmeta_odm_a.bin                     1.00 MB
│  ├─ vbmeta_product_a.bin                 1.00 MB
│  ├─ vbmeta_system_a.bin                  1.00 MB
│  ├─ vbmeta_system_ext_a.bin              1.00 MB
│  ├─ vbmeta_vendor_a.bin                  1.00 MB
│  ├─ avbmeta_rs_a.bin                     1.00 MB   ← 全零（正常）
│  ├─ super.bin                         5600.00 MB
│  ├─ metadata.bin                        64.00 MB
│  ├─ misc.bin                             1.00 MB
│  ├─ logo.bin                             8.00 MB
│  ├─ fbootlogo.bin                        8.00 MB
│  ├─ dtb_a.bin                            8.00 MB   ← 全零（正常）
│  ├─ dtbo_a.bin                           8.00 MB
│  ├─ hypervsior_a.bin                    10.00 MB   ← 全零（正常）
│  ├─ ch_sys_a.bin                        16.00 MB
│  ├─ common_rs1_a.bin                     8.00 MB
│  ├─ common_rs2_a.bin                    16.00 MB   ← 全零（正常）
│  ├─ l_agdsp_a.bin                        6.00 MB
│  ├─ pm_sys_a.bin                         1.00 MB
│  ├─ nr_runtimenv1.bin                   55.00 MB
│  ├─ nr_runtimenv2.bin                   55.00 MB
│  └─ persist.bin                          2.00 MB
├─ 刷机驱动_SPD_Driver_R4.20.4201/
│  ├─ Win7/  Win8/  Win10&win11/
│  │  ├─ DPInst32.exe / DPInst64.exe
│  │  ├─ DriverSetup.exe
│  │  ├─ DriverUninstall32.exe / DriverUninstall64.exe
│  │  ├─ config.reg / dpinst.xml
│  │  └─ Drivers/
│  │     ├─ sprdvcom.inf/.cat  ← VCOM（BROM 下载口，必需）
│  │     ├─ sprdadb.inf/.cat
│  │     ├─ sprdvmdm.inf/.cat
│  │     ├─ rdavcom.inf/.cat
│  │     ├─ amd64/*.sys
│  │     └─ i386/*.sys
├─ [直接插电]一键备份.bat
├─ [短接模式]一键备份.bat
├─ [短接模式]一键备份 - 副本.bat
├─ [短接模式]一键刷机_会清空用户数据.bat
├─ [短接模式](之前装过我的官改的）一键更新_不清空数据.bat
├─ [面具用我]Magisk_28103_原版.apk      # 10.9 MB
├─ 菠萝手机开机第一屏logo_换成logo.bin放入data可以刷入.bin   # 8 MB
├─ 简介.txt                             # GBK 编码
├─ 关机状态下按住返回键插线即可进入短接模式        # 空文件，仅作提示
├─ 此ROM去除了DATA加密，DATA加密的手机请使用完整刷机脚本   # 空文件
└─ 请关闭杀毒软件和WindowsDefender              # 空文件
```

> 包内 `简介.txt` 是 **GBK** 编码。PowerShell 读会乱码，用
> `[System.IO.File]::ReadAllText($p, [System.Text.Encoding]::GetEncoding('GBK'))`。

## 官方一键脚本（参考，含正确地址）

### 备份（短接模式）

```bat
.\bin\spd_dump.exe --wait 300 exec_addr2 0x65017f08 ^
  fdl .\bin\fdl1-dl.bin 0x65000800 ^
  fdl .\bin\fdl2-dl.bin 0xbefffe00 ^
  exec path "%backup_dir%" r all reset
```

### 备份（直接插电，走 kickto）

```bat
.\bin\spd_dump.exe --wait 300 --kickto 2 exec ^
  path "%backup_dir%" r all reset
```

### 完整刷机

```bat
.\bin\spd_dump.exe --wait 300 exec_addr2 0x65017f08 ^
  fdl .\bin\fdl1-dl.bin 0x65000800 ^
  fdl .\bin\fdl2-dl.bin 0xbefffe00 ^
  exec path .\temp write_parts .\data\ e userdata verity 0 reset
```

### 增量更新（保数据）

```bat
.\bin\spd_dump.exe --wait 300 exec_addr2 0x65017f08 ^
  fdl .\bin\fdl1-dl.bin 0x65000800 ^
  fdl .\bin\fdl2-dl.bin 0xbefffe00 ^
  exec path .\temp ^
  w init_boot_a .\data\init_boot_a.bin ^
  w boot_a .\data\boot_a.bin ^
  w uboot_a .\data\uboot_a.bin ^
  w trustos_a .\data\trustos_a.bin ^
  w super .\data\super.bin ^
  verity 0 reset
```

## 地址常量（T158 专用）

| 名称 | 值 | 含义 |
| --- | --- | --- |
| `exec_addr2` | `0x65017f08` | `custom_exec_no_verify_65017f08.bin` 的落点，绕过 BROM 对 `splloader/fdl1` 的签名校验 |
| FDL1 | `0x65000800` | `fdl1-dl.bin` 落点 |
| FDL2 | `0xbefffe00` | `fdl2-dl.bin` 落点 |

> **不要随意改这些地址。** 它们与 FDL 二进制内的链接地址绑定。
> 开源 `spreadtrum_flash` 的 stable 版没有 `exec_addr2`，只有 `exec_addr`，
> 且要求文件名形如 `custom_exec_no_verify_0x65017f08.bin`。

## e5-tools 工具包

```
e5/
├─ scrcpy/scrcpy-win64-v5.0.1/
│  ├─ adb.exe / AdbWinApi.dll / AdbWinUsbApi.dll
│  ├─ scrcpy.exe / scrcpy-server
│  └─ SDL3.dll / av*.dll / swresample-7.dll
├─ spd_dump/
│  ├─ README.md / README_zh.md
│  ├─ spd_dump_SPRD_Release/     # 需装 SPRD 驱动
│  │  ├─ spd_dump.exe            # 82432 B（ver 228，支持 exec_addr2）
│  │  ├─ fdl1-dl.bin / fdl2-dl.bin
│  │  └─ custom_exec_no_verify_65012f48.bin   ← 注意：地址是 65012f48
│  └─ spd_dump_LibUSB_Release/   # 免驱动（WinUSB）
│     ├─ spd_dump.exe            # 82944 B（stable，只有 exec_addr）
│     └─ libusb-1.0.dll
├─ tools/
│  ├─ 7zr.exe / scrcpy.zip / spd_dump.zip
│  └─ vc_redist.x64.exe / vc_redist.x86.exe
├─ Magisk-v30.7.apk
└─ README.txt
```

> **两版 spd_dump 的差别很重要**：
> - `SPRD_Release`（定制，ver 228）：支持 `exec_addr2`，需装 SPRD 驱动
> - `LibUSB_Release`（stable）：只有 `exec_addr`，免驱动
>
> 本 skill 的脚本用 `exec_addr2`，因此**必须用 SPRD 版 + 装驱动**。
> 且注意 e5-tools 里那份的 `custom_exec` 地址是 `65012f48`，与官改包的 `65017f08` **不同**，
> 不能混用。

## OpenWrt 整包结构

```
e5-openwrt-<version>/
├─ OpenWrt-Installer.exe          # Windows 图形安装器（3.5 MB）
├─ OpenWrt-Installer.py           # 命令行入口
├─ OpenWrt-Installer.app/         # macOS 图形安装器
├─ START-HERE.md                  # 使用说明（中英）
├─ launchers/
│  ├─ start-installer.cmd/.sh
│  ├─ install-to-tf-card.cmd/.sh
│  ├─ install-to-internal-storage.cmd/.sh
│  ├─ install-to-userdata-image.cmd/.sh
│  ├─ reinstall-internal-system.cmd/.sh
│  ├─ resume-internal-install.cmd/.sh
│  ├─ switch-to-openwrt.cmd/.sh
│  └─ update-openwrt.cmd/.sh
├─ files/
│  ├─ openwrt.ext4.gz             # 163.4 MB → 解压 2 GiB
│  ├─ boot.img                    # 64 MB（含 e5.part_v=2 标记）
│  ├─ boot.json / device-profile.json / tf-install.env
│  ├─ e5-bootctl                  # 546864 B，启动控制块工具
│  ├─ e5-gpt                      # GPT 处理
│  ├─ magisk-tf-install.sh        # TF 卡原生 Magisk 安装脚本
│  ├─ android-bootchain.sh        # A→B 启动链同步
│  ├─ android-loop.sh / android-tf.sh
│  ├─ device-install-image.sh / device-install-part.sh
│  ├─ part-write.sh / userdata-image.sh
│  ├─ collect-device-files.sh
│  ├─ busybox / ext4-tools.tar
│  ├─ magisk-firmware.py
│  └─ SHA256SUMS
├─ extras/android/
│  └─ op-system-switcher.apk      # 系统切换器 com.minikano.e5switch
├─ tools/
│  ├─ backend/openwrt-backend.exe # CLI 后端（3.1 MB）
│  └─ macos/backend/...
└─ docs/
```

关键常量（`files/tf-install.env`）：

```sh
PROFILE=e5
ANDROID_MODEL=E5
DEFAULT_SSID=E5-OpenWrt
RAW_BYTES=2147483648
RAW_SHA256=d693be43f405faa1f319a78cb6ec79788773b526aa38b371fc89c3f1c90fb0c4
BOOT_BYTES=67108864
BOOT_SHA256=4830ff6b8ae57fdb9b6438f906f34fc0431e03813f1756e544f740ee89eb2640
```

## 磁盘空间规划

| 项目 | 占用 |
| --- | --- |
| 官改包压缩 | 1.69 GB |
| 官改包解压 | 5.97 GB |
| 全分区备份 | 6.7 GB |
| Magisk 补丁镜像 | 8 MB × 2 |
| OpenWrt 包解压 | 380 MB |
| **合计建议预留** | **≥ 16 GB** |
