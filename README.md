# Awesome 荣悦 E5 [![Awesome](https://awesome.re/badge.svg)](https://awesome.re)

荣悦 E5(RongYue E5)相关资源精选列表:刷机、Root、随身 WiFi / UFI-TOOLS、展锐(Unisoc)深刷与社区教程。

荣悦 E5 是一台基于紫光展锐 T158 的低价 5G 键盘老人机,因便宜、可拆电池、可解锁刷机,在中文玩机社区常被改造成「百元 5G 热点机 / MiFi」。本列表汇总公开教程、工具、固件网盘入口与研究帖,方便快速入门与避坑。

## Contents

- [机型概览](#机型概览)
- [硬件与批次说明](#硬件与批次说明)
- [入门](#入门)
- [完整实刷记录（原厂 → Magisk → UFI-TOOLS → OpenWrt）](#完整实刷记录原厂--magisk--ufi-tools--openwrt)
- [Agent Skill：一键刷机](#agent-skill一键刷机)
- [视频教程(中文)](#视频教程中文)
- [图文与评测](#图文与评测)
- [固件与资源网盘](#固件与资源网盘)
- [刷机环境:macOS 是否可用](#刷机环境macos-是否可用)
- [刷机工具:spd_dump 与展锐驱动](#刷机工具spd_dump-与展锐驱动)
- [UFI-TOOLS 与随身 WiFi 玩法](#ufi-tools-与随身-wifi-玩法)
- [Root / Magisk / KernelSU](#root--magisk--kernelsu)
- [进阶 ROM 与移植](#进阶-rom-与移植)
- [OpenWrt 专项](#openwrt-专项)
- [OpenWrt 与其它路线(摘要)](#openwrt-与其它路线摘要)
- [频段与作为 MiFi 的参考](#频段与作为-mifi-的参考)
- [通用展锐教程(可借鉴)](#通用展锐教程可借鉴)
- [相关 GitHub 项目](#相关-github-项目)
- [社区讨论](#社区讨论)

## 机型概览

| 项目        | 说明                                                                               |
| ----------- | ---------------------------------------------------------------------------------- |
| 品牌 / 型号 | 荣悦 E5(市面亦见 RongYue E5、键盘 5G 老人机形态)                                   |
| SoC         | 紫光展锐 **T158**(Unisoc,八核 5G)                                                  |
| GPU         | Mali-G57                                                                           |
| 系统        | 出厂多为 **Android 13**                                                            |
| 屏幕        | 3.5″ IPS,320×480 触控                                                              |
| 内存/存储   | 常见 **2GB+32GB** 或 **3GB+32GB**(批次不一,购买前确认)                             |
| 电池        | 3000mAh **可拆卸**                                                                 |
| 接口        | USB Type-C(部分资料标注 USB 2.0)                                                   |
| 网络        | 双卡双待 5G、VoLTE;Wi-Fi 5(AC433 等实测描述)                                       |
| 其它        | TF 卡槽、实体键盘、可开热点当廉价 MiFi                                             |
| OEM 背景    | 公开报道多指向贵州财富之舟等供应链;同方案公模在渠道上亦见 **ED351(5G)** 等型号描述 |

外观与 TCL T508N 等键盘机相似,闲鱼等平台大量流通,因低价 + 可刷机 + 可拆电池,常被当作「百元 5G 热点机」折腾。

## 硬件与批次说明

- RAM 容量:媒体与卖家描述在 2G / 3G 间不一致,刷入第三方 ROM 前务必确认内存版本(部分高版本移植 ROM 仅面向改内存机型)。
- 芯片平台:折腾时以 **T158** 为准,勿与中兴 F50 等 **T760** 平台的 OpenWrt / 工具包混用(见 [什么值得买社区讨论](https://post.smzdm.com/p/agg58n3m/))。
- 公模参数参考:[POMP Mobile ED351(5G) 规格页](https://cn.pompmobile.com/productinfo109.html) - 3GB+32GB、T158、Android 13 等,供对照非荣悦贴牌批次。

## 入门

| 目标                              | 建议路径                                                                |
| --------------------------------- | ----------------------------------------------------------------------- |
| 官改系统 + 解锁 BL + 装 UFI-TOOLS | B 站「荣悦E5刷机+UFI-TOOLS」(BV1e65y69E3L)→ 官改包网盘 → UFI-TOOLS 模块 |
| 仅 Root(展瑞老头乐通用思路)       | B 站「紫光5G老头乐 Root」(BV1woo9BPEmg)+ Magisk 资源见视频简介网盘      |
| 深刷 / 备份全分区                 | Windows + 展锐驱动 + `spd_dump`,**先全盘备份**再写入                    |
| 重度移植(Flyme / KernelSU-Next)   | Hovatek T158 线程(见进阶 ROM 一节),资源在帖内                           |

### 进入 BROM / 下载模式(常见说法)

社区多条教程一致描述:

1. 关机(可拆电池机型建议断电更稳妥)。
2. 按住「返回 / Back」键,再连接 USB 至电脑(或先按住 Back 再开机,以你使用的 `spd_dump` 脚本说明为准)。
3. 设备管理器中出现展锐 / Spreadtrum 端口后,在 `spd_dump` 中执行备份或刷写。

不同 ROM 包附带的一键脚本按键可能略有差异,**以你下载的刷机包内 BAT / 说明为准**。

### 刷机前建议备份的分区(展锐通用)

参考社区展锐深刷文档,至少关注:`splloader`、`uboot`、`sml`、`trustos`、`vbmeta`、`boot`、`recovery`、`system` 等;条件允许时使用 `r all` 或包内一键备份脚本做全分区备份,详见 [KDXF-LEAKiNG Unisoc_ud710.md](https://github.com/iflytek-leaking/KDXF-LEAKiNG-Project/blob/main/Unisoc_ud710.md)。

## 完整实刷记录（原厂 → Magisk → UFI-TOOLS → OpenWrt）

**[docs/field-notes-full-walkthrough.md](https://github.com/r4ym0n/awesome-e5/blob/main/docs/field-notes-full-walkthrough.md)** — 一台原厂 E5 的全程实刷记录，按实际执行顺序编写，含真实命令、预期输出、判断依据与全部踩坑。

覆盖内容：

| 阶段                | 要点                                                                                         |
| ------------------- | -------------------------------------------------------------------------------------------- |
| 环境与物料          | 官改 V4 包结构（`bin/` + `data/` 31 个镜像）、e5-tools、OpenWrt 整包、两个模块               |
| **BROM 三阶段认知** | `bootrom → FDL1 → FDL2`；FDL1/FDL2 是内存程序，**只有取电池断电才清掉**                      |
| 装驱动              | `pnputil /add-driver …sprdvcom.inf /install`，`PID_4D00` = `USBCOMM_DL`                      |
| 全分区备份          | `--kickto 2 exec_addr2 0x65017f08 … r all reset`，实测 68 文件 / 6.7 GB / 70 个分区          |
| 刷官改 V4           | `write_parts data\ e userdata verity 0`，实测 274 秒；全零镜像的正确判断方法                 |
| Magisk root         | 用**当前系统**的 `init_boot` 打补丁，`ANDROID!` magic 校验，BROM 写回                        |
| UFI-TOOLS           | 模块自动装 APK + `system.prop`（`ro.debuggable=1`、`tcp.port=5555`）+ sepolicy permissive    |
| 热点优化            | `apx/` bind mount 替换 `TetheringGoogle.apk` / `service-wifi.jar` / `NetworkStackGoogle.apk` |
| OpenWrt 双系统      | TF 卡整卡写入、`boot_b` 写内核、`misc` 32 字节控制块                                         |
| **双系统切换**      | `misc` 偏移 2048 的 BCAB 结构逐字节解析、CRC32、三种切换方式                                 |

## Agent Skill：一键刷机

**[skills/rongyue-e5-flash/](https://github.com/r4ym0n/awesome-e5/tree/main/skills/rongyue-e5-flash)** — 把上面的完整流程封装成**可被 AI agent 直接调用**的 skill。

### 它能做什么

| 命令                              | 作用                                 |
| --------------------------------- | ------------------------------------ |
| `detect`                          | 环境 / 驱动 / 设备 / 磁盘检查        |
| `wait-brom`                       | 等 BROM 出现（200 ms 轮询）          |
| `backup`                          | 全分区备份 + 自动校验闸门            |
| `flash -Mode full\|keepdata\|raw` | 刷机 / 增量 / 从备份还原             |
| `flash-initboot`                  | 写 Magisk 补丁后的 `init_boot_a`     |
| `magisk-prepare` / `magisk-fetch` | 推原始镜像 / 拉补丁镜像并校验 magic  |
| `magisk-install`                  | 装 Magisk 模块（自动处理中文文件名） |
| `openwrt-tf [-CheckOnly]`         | OpenWrt 装 TF 卡                     |
| `wipe-tf`                         | 清 TF 分区表                         |
| `probe`                           | 设备能力探测（内存 / WiFi / 工具）   |
| `verify [-Full]`                  | root / 解锁 / 属性 / 端口验证        |
| `reboot`                          | 重启并等待开机完成                   |

### 快速开始

```powershell
# 引导式全流程（交互确认）
./scripts/quickstart.ps1 -Rom E:\e5flash\rom

# 或逐步执行
./scripts/e5.ps1 detect -Rom E:\e5flash\rom
./scripts/e5.ps1 backup -Out E:\e5flash\backup\20261031
./scripts/e5.ps1 flash  -Rom E:\e5flash\rom -Mode full
./scripts/e5.ps1 verify
```

### 内置的安全闸门

这个 skill 不是「一把梭」脚本，每个写操作前都会校验：

1. 备份未完成 → 拒绝刷机
2. 镜像名必须与真实分区名一一对应，否则拒绝
3. 全零镜像会列出来要求对照备份，不盲目写入
4. 设备必须在 BROM，否则等待或拒绝
5. 刷完检查 `target == written`，检测截断
6. 检测到 `device removed` 立即提示断电重刷，不让 agent 误以为成功

### 文件结构

```
skills/rongyue-e5-flash/
├─ SKILL.md                        # 主文档（agent 读这个）
├─ scripts/
│  ├─ e5.ps1                       # 单入口 CLI（13 个子命令）
│  └─ quickstart.ps1               # 引导式全流程
└─ references/
   ├─ materials.md                 # 物料清单与目录结构
   ├─ partition-table.md           # 70 个分区完整表
   ├─ boot-control.md              # misc BCAB 32 字节结构 + CRC32
   └─ troubleshooting.md           # 完整故障手册
```

### 给 agent 的纪律（写在 SKILL.md 里）

- 备份没做完，不许写任何分区
- 每次进 BROM 前先确认不在 FDL1 残留状态
- 刷机中断先断电重进，再完整重刷，不「接着刷」
- 全零镜像先对照备份再下结论
- 中文路径 / 文件名是高频坑
- 不要承诺 WiFi 中继(硬件限制)

### 几条最有价值的实测结论

1. 这台机器不支持 WiFi 中继(STA+AP 并发)

```
ls /sys/class/net/ | grep wlan     →  只有 wlan0
dumpsys wifi | grep num_concurrent →  num_concurrent_connection: 0
cmd wifi start-softap …            →  SAP is disabled
```

单射频硬件限制，**刷 OpenWrt 也改变不了**。它只能当「SIM 5G → WiFi 热点」，不能当「WiFi 中继」。

2. 内存只有 1.4 GB(可用约 405 MB)

Docker、重度服务基本不现实。

3. ROM 里的全零镜像不是损坏

`dtb_a` / `hypervsior_a` / `common_rs2_a` / `avbmeta_rs_a` 在 ROM 里是全零，
但**真机对应分区本来也是全零** —— 这只能通过先做备份对比才能确认。

4. 刷机中断是「半刷状态」

刷到 `super` 前掉线会必然开不了机（引导链已改但系统没写）。
处理：**取电池断电 → 重新进 BROM → 从头完整重刷**，`write_parts` 幂等。

5. OpenWrt 第一次重启可能回退

试启动失败会回退 Android，**再重启一次**即可进入。

6. TF 卡有分区会导致安装失败

安装器优先用「第一分区」；若 `p1` 只有几十 MB，会报
`SD capacity is insufficient`。解决：清空分区表让安装器看到整卡。

### 没有 recovery 入口

70 个分区里**没有 `recovery`**；这台机器用展锐私有 `BCAB` 格式而非 AOSP 标准 AB，
所以也没有标准 `bootctl`。切换靠 `misc` 控制块 + `e5-bootctl`（支持 `android`/`linux`/`sd`/`arm`/`trial`）。

### 进入 BROM / 下载模式（常见说法）

社区多条教程一致描述：

1. 关机（可拆电池机型建议断电更稳妥）。
2. 按住「返回 / Back」键，再连接 USB 至电脑（或先按住 Back 再开机，以你使用的 `spd_dump` 脚本说明为准）。
3. 设备管理器中出现展锐 / Spreadtrum 端口后，在 `spd_dump` 中执行备份或刷写。

> 不同 ROM 包附带的一键脚本按键可能略有差异，**以你下载的刷机包内 BAT / 说明为准**。

### 刷机前建议备份的分区（展锐通用）

参考社区展锐深刷文档，至少关注：`splloader`、`uboot`、`sml`、`trustos`、`vbmeta`、`boot`、`recovery`、`system` 等；条件允许时使用 `r all` 或包内一键备份脚本做全分区备份。详见 KDXF-LEAKiNG Unisoc_ud710.md(链接见上文入门一节)。

## 视频教程(中文)

- [荣悦E5刷机+UFI-TOOLS使用教程](https://www.bilibili.com/video/BV1e65y69E3L/) - MiniKano:官改包、QuTick102 版 `spd_dump`、UFI-TOOLS 模块.
- [【也许是展瑞通用】紫光5G老头乐Root教程](https://www.bilibili.com/video/BV1woo9BPEmg/) - Magisk、`spd_dump`,致谢 TomKing062 / YC.
- [老人机也会梦到Google,荣悦E5](https://www.bilibili.com/video/BV1t7ji6sEJr/) - Fun demo:玩法向整活 / 折腾.
- UFI-TOOLS 相关安装演示 - [kanokano.cn 食用指南](https://kanokano.cn/archives/1435.html) 文中链到的 B 站合集(F50/U30 流程可对照 PE 版尝试).

## 图文与评测

- [大量廉价5G手机涌入闲鱼!荣悦 E5 介绍](https://www.sohu.com/a/1034128812_99959092) - Sohu 专栏:闲搞机 / 搜狐.
- 百元随身 WiFi 刷 OpenWrt:分清 T158 与 T760(什么值得买,链接见上文硬件与批次一节) - Buying guide:购买与平台选型.
- [荣悦-E5 MIFIPK 设备页](https://mifipk.com/en/devices/32) - MiFi tests:作为 MiFi 的延迟、频段与 UFI-TOOLS 测试版本记录.
- [Кнопочник Rongyue E5 详细评测(俄语)](https://www.youtube.com/watch?v=NdD04OxYvxQ) - T158 / Mali-G57 / 可拆盖等.

## 固件与资源网盘

| 资源                 | 链接                                                                                                                                         | 备注                                               |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| 官改系统(教程引用)   | [123pan 网盘](https://1816129281.share.123pan.cn/123pan/7oa5Vv-4vx03)                                                                        | 见 BV1e65y69E3L 简介;含解锁 BL / 去 AVB 等说明的包 |
| UFI-TOOLS 更新与插件 | [kanokano.cn 网盘](https://pan.kanokano.cn/UFI-TOOLS-UPDATE)                                                                                 | 官方维护的网盘入口                                 |
| 一键刷分区工具(7z)   | [网盘直链](https://pan.kanokano.cn/d/UFI-TOOLS-UPDATE/%E6%9D%82%E9%A1%B9/%E4%B8%80%E9%94%AE%E5%88%B7%E5%88%86%E5%8C%BA%E5%B7%A5%E5%85%B7.7z) | Root 教程(BV1woo9BPEmg)简介                        |
| Magisk APK           | [网盘直链](https://pan.kanokano.cn/d/UFI-TOOLS-UPDATE/plugins/Magisk_28103.apk)                                                              | 版本以网盘为准                                     |
| scrcpy / ADB 工具包  | [scrcpy-win64-v2.0.7z](https://pan.kanokano.cn/d/UFI-TOOLS-UPDATE/UFI-TOOLS%E4%B8%80%E9%94%AE%E5%AE%89%E8%A3%85%E5%99%A8/scrcpy-win64-v2.0.7z) | 投屏与调试;同目录亦见一键安装器各平台版本          |
| UFI-TOOLS Web APK    | [V4.1.5 (2026-09-19)](https://pan.kanokano.cn/d/UFI-TOOLS-UPDATE/UFI-TOOLS_WEB_V4.1.5_20260919_2127.apk)                                      | 网盘根目录的当前 Web 端;版本以网盘为准             |
| UFI-TOOLS 用户手册   | [用户手册UFI-TOOLS.pdf](https://pan.kanokano.cn/d/UFI-TOOLS-UPDATE/%E7%94%A8%E6%88%B7%E6%89%8B%E5%86%8CUFI-TOOLS.pdf)                         | 官方 PDF 手册(约 6 MB),先读再动手                  |
| UFI 一键安装器       | [网盘目录](https://pan.kanokano.cn/UFI-TOOLS-UPDATE/UFI-TOOLS%E4%B8%80%E9%94%AE%E5%AE%89%E8%A3%85%E5%99%A8)                                   | 含 Win x32/x64 1.9.2 与 macOS 版                   |
| 热点优化模块(E5 专用) | [荣悦E5解除热点数量限制+锁5GWIFI信道+固定热点IP模块v4](https://pan.kanokano.cn/UFI-TOOLS-UPDATE/Magisk%E6%A8%A1%E5%9D%97)                      | **v4**(2026-08-18):解热点数量限制 + 锁 5G 信道 + 固定网关;详见下方说明 |
| 按键修复模块(E5 专用) | [网盘 · Magisk模块](https://pan.kanokano.cn/UFI-TOOLS-UPDATE/Magisk%E6%A8%A1%E5%9D%97)                                                        | `荣悦E5按键修复模块.zip`(约 8.4 MB);实体键映射异常时尝试 |
| QuTick102 私人空间   | [ysepan](http://qutick102.ysepan.com/)                                                                                                       | 需密码;教程提到的定制 `spd_dump`                   |

### 热点优化模块 v4 说明

`荣悦E5解除热点数量限制+锁5GWIFI信道+固定热点IP模块v4.zip`（2.49 MB）是专为 E5 定制的 Magisk 模块，
通过 **apex bind mount** 替换系统组件实现三个功能：

| 组件 | 路径 | 作用 |
| --- | --- | --- |
| `TetheringGoogle.apk` | `apx/com.android.tethering/priv-app/TetheringGoogle@…/` | 解除热点客户端数量限制（默认 → 10） |
| `service-wifi.jar` | `apx/com.android.wifi/javalib/` | 锁定 5G WiFi 信道（默认 36） |
| `NetworkStackGoogle.apk` | `system/priv-app/NetworkStackGoogle/` | 固定热点网关 `192.168.43.1`、USB 共享网关 `192.168.42.1` |

可选配置（在 `/data/` 下创建）：

```sh
echo 149 > /data/kano_ap_channel.cfg   # 信道,建议 36 或 149
echo 600 > /data/kano_softap_timeout   # 无连接自动关闭(秒),默认不关
echo 1   > /data/kano_is_hidden_ssid   # 隐藏 SSID
```

重启生效。验证替换是否成功：

```sh
su -c 'mount | grep tethering'
# 期望看到 /dev/block/mmcblk0p70(= userdata)挂在 TetheringGoogle.apk 上
```

> v4 相比 v3 增加了 `NetworkStackGoogle.apk`（固定网关）。旧版只解限制 + 锁信道。

网盘链接可能随时间失效,欢迎在 Issue 中提交可用镜像。

## 刷机环境:macOS 是否可用

结论:可用,但不建议。

深刷与 e5-linux / OpenWrt 整包在 macOS 上可通过 LibUSB 版 `spd_dump` 等工具完成,但社区教程与 QuTick102 一键包以 Windows 为主;首次刷机更推荐 Windows 或虚拟机。Android 侧 `adb`、UFI-TOOLS macOS 安装器相对友好。

详见 [docs/macos-flashing.md](https://github.com/r4ym0n/awesome-e5/blob/main/docs/macos-flashing.md)(能力对照、推荐工具、与 e5-linux 的配合方式)。

## 刷机工具:spd_dump 与展锐驱动

| 工具                            | 链接                                                                                                        | 说明                                          |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| spreadtrum_flash(开源)          | [TomKing062/spreadtrum_flash](https://github.com/TomKing062/spreadtrum_flash)                               | 主流开源 `spd_dump` 实现,支持 Termux          |
| 预编译 spd_dump / 解锁相关      | [CVE-2022-38694_unlock_bootloader](https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader/releases) | 含 Windows 构建;注意驱动(官方 SPRD vs LibUSB) |
| action_spd_dump_it              | [TomKing062/action_spd_dump_it](https://github.com/TomKing062/action_spd_dump_it)                           | 闭源分支,支持 `pac` 等扩展命令                |
| spreadtrum_flash(ilyakurdyukov) | [releases](https://github.com/ilyakurdyukov/spreadtrum_flash/releases)                                      | 另一套维护与 `spd_dump64.zip`                 |
| SPRDClient                      | [YC-nw](https://github.com/YC-nw)                                                                           | 展锐工具链作者(社区致谢)                      |
| 紫光 USB 驱动                   | 各教程包内常带 `SPRD_Driver_R4.x`(官改包的 `刷机驱动_SPD_Driver_R4.20.4201/`)                            | Windows 刷机前安装;**必须管理员**执行 `pnputil /add-driver` |
| spd_dump-macos                  | [xun404/spd_dump-macos](https://github.com/xun404/spd_dump-macos)                                           | T158 验证的 macOS 移植;见 macOS 刷机说明      |
| sfd_tool                        | [C-Hidery/sfd_tool](https://github.com/C-Hidery/sfd_tool)                                                   | 跨平台(含 macOS)展锐维护工具                  |

### ⚠️ 两版 `spd_dump` 不可混用

e5-tools 等工具包里通常同时提供两个构建,能力不同:

| | `spd_dump_SPRD_Release` | `spd_dump_LibUSB_Release` |
| --- | --- | --- |
| 版本标识 | `ver:228`(定制) | `branch:stable` |
| 文件大小 | 82432 B | 82944 B |
| 依赖驱动 | **需装 SPRD 驱动**(`sprdvcom.inf`) | 免驱动(WinUSB/libusb) |
| 私有命令 `exec_addr2` | ✅ 支持 | ❌ 只有 `exec_addr` |
| `--kickto` | ✅ | ✅ |

**这条会直接决定刷机能否成功**：

- 官改包的一键脚本用 `exec_addr2 0x65017f08`，**必须用 SPRD 版 + 装驱动**
- 用 LibUSB stable 版跑同一条命令会报「未知命令」或等待超时

### ⚠️ `custom_exec` 文件地址必须与 FDL 匹配

`custom_exec_no_verify_<地址>.bin` 的文件名里带地址，**不能张冠李戴**：

| 来源 | 文件名里的地址 | 对应参数 |
| --- | --- | --- |
| 官改包 `bin/` | `65017f08` | `exec_addr2 0x65017f08` |
| e5-tools `spd_dump_SPRD_Release/` | `65012f48` | 只适用于配对的 FDL |

用哪个 FDL 就必须配对应地址的 `custom_exec`。混用会导致 BROM 签名校验绕过失败。
常用命令形态(仅作索引,**以工具 `--help` 为准**):

```text
# 示例:等待设备并读取全分区(路径与 FDL 因机型而异)
spd_dump --wait 300 fdl <fdl1> <addr1> fdl <fdl2> <addr2> exec <...> r all reset
```

荣悦 E5 教程多使用 **QuTick102 定制的 spd_dump** 与包内 FDL,不建议随意混用其它机型的 FDL。

## UFI-TOOLS 与随身 WiFi 玩法

UFI-TOOLS 最初面向中兴 F50 / U30 Air(T760),但社区已在 T158 的荣悦 E5 上实践「刷官改 + 装模块」路线。

| 资源       | 链接                                                                                                       |
| ---------- | ---------------------------------------------------------------------------------------------------------- |
| 项目主页   | [kanoqwq/UFI-TOOLS](https://github.com/kanoqwq/UFI-TOOLS)                                                  |
| 用户文档   | [User_Doc.md(http-server 分支)](https://github.com/kanoqwq/UFI-TOOLS/blob/http-server-version/User_Doc.md) |
| 食用指南   | kanokano.cn/archives/1435(安装、PE 版、完整版;链接见上文视频教程一节)                                      |
| Web 版相关 | [kanoqwq/F50-SMS](https://github.com/kanoqwq/F50-SMS)                                                      |

要点:

- 先按视频刷入**已解锁 BL 的官改系统**,再安装 UFI-TOOLS 模块 / APK。
- 非官方适配机型可能功能不全,属正常现象;可从 **PE 版**远程管理试起。
- 拔电前等待缓存写入完成(教程常建议等待数分钟)。

## Root / Magisk / KernelSU

- Root 教程 - B 站「紫光5G老头乐 Root」(BV1woo9BPEmg,链接见上文视频教程一节);展瑞平台通用思路,简介含 Magisk 与分区工具网盘。
- 官改包描述中常见:**默认已解锁 Bootloader 并解除 AVB**,便于直接刷入 Magisk / 修改 boot。

## 进阶 ROM 与移植

- [Full Bootloader Unlock & KernelSU Guide for Unisoc T158 (RongYue E5 / Meizu Note 16)](https://www.hovatek.com/forum/thread-49605.html) - 英文长帖,含 BROM 一键备份 / 刷入 Flyme 移植包脚本、内置 **KernelSU-Next** / Zygisk-Next / LSPosed、荣悦 E5 专用键位映射插件(Menu / Back / \* 等);下载链接在帖内(第三方网盘,自行甄别).

适合已有展锐刷机经验、且接受 Flyme 移植风险的用户;**内存改版(如 4GB)** 与标准 2G/3G 机是否适用请以帖内标注为准。

## OpenWrt 专项

如何把荣悦 E5 刷成 OpenWrt 向系统(社区 **e5-linux** 整包,非 openwrt.org 官方镜像)的教程、工具与 Windows 操作逻辑,见 [docs/openwrt.md](https://github.com/r4ym0n/awesome-e5/blob/main/docs/openwrt.md)。

- 主视频:[BV1htpJ6NECu - 老人机刷 openwrt 改造随身 WiFi](https://www.bilibili.com/video/BV1htpJ6NECu/)。
- 刷机环境:建议 **Windows**;Mac 见 docs/macos-flashing.md。

## OpenWrt 与其它路线(摘要)

- 荣悦 E5 = **T158 + e5-linux 整包替换**;中兴 F50 = **T760 + 另一套 OpenWrt 生态**,固件与工具 **不可混用**。
- 选型:什么值得买 T158 vs T760(见上文硬件与批次一节) · [E5 / F50 三条线](https://post.smzdm.com/p/avgprw87/)。
- 勿与 **Reyee AX3200 E5 路由器**(MT7622,[上游 OpenWrt 已支持](https://github.com/openwrt/openwrt/pull/10951))混淆。
- 长期重度插件用户多数倾向 F50;E5 适合低价尝鲜,系统迭代快,需接受实验性。

## 频段与作为 MiFi 的参考

MIFIPK 荣悦-E5 收录了在 UFI-TOOLS 等环境下的测速、延迟与 **5G/4G 频段列表**(测试版本 V3.5 等),购机前可对照本地运营商频段。

## 通用展锐教程(可借鉴)

- [iflytek-leaking / KDXF-LEAKiNG-Project](https://github.com/iflytek-leaking/KDXF-LEAKiNG-Project) - Unisoc_ud710.md 等:驱动、`spd_dump`、备份与 `w system` 等命令详解(面向 UD710/ums9620 等,思路可迁移,**FDL 与分区表勿照搬**)。仓库已从 `ig25138` 迁移至此。

## 相关 GitHub 项目

- TomKing062/spreadtrum_flash - 开源刷机工具(详见刷机工具一节).
- [TomKing062/CVE-2022-38694_unlock_bootloader](https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader) - BL 解锁研究与发布.
- kanoqwq/UFI-TOOLS - UFI 管理后台与插件(详见 UFI-TOOLS 一节).
- kanoqwq/F50-SMS - UFI-TOOLS Web 相关.

## 社区讨论

- Hovatek - Unisoc T158 / RongYue E5 线程(链接见进阶 ROM 一节)。
- B 站搜索关键词:`荣悦E5`、`荣悦 E5 刷机`、`T158 spd_dump`。
- 酷安 / 贴吧等中文社区亦有零星玩机帖(链接易变,欢迎 PR 补充)。

## Contributing

欢迎通过 Pull Request 补充链接。请遵循 [贡献指南](https://github.com/r4ym0n/awesome-e5/blob/main/CONTRIBUTING.md)。

若你发现失效链接或错误信息,请开 Issue 说明机型批次与来源。

## Footnotes

**免责声明**:刷机、解锁 Bootloader、修改分区或基带等行为可能导致设备变砖、失去保修或违反当地法规与运营商条款。本仓库仅收录公开链接与资料索引,**不托管固件**;操作前请自行备份,并确认固件与硬件批次匹配。涉及「改串」等可能违法的功能请勿使用。
