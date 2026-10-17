# Awesome 荣悦 E5 [![Awesome](https://awesome.re/badge.svg)](https://awesome.re)

荣悦 E5（RongYue E5）相关资源精选列表：刷机、Root、随身 WiFi / UFI-TOOLS、展锐（Unisoc）深刷与社区教程。

> **免责声明**：刷机、解锁 Bootloader、修改分区或基带等行为可能导致设备变砖、失去保修或违反当地法规与运营商条款。本仓库仅收录公开链接与资料索引，**不托管固件**；操作前请自行备份，并确认固件与硬件批次匹配。涉及「改串」等可能违法的功能请勿使用。

## 目录

- [机型概览](#机型概览)
- [硬件与批次说明](#硬件与批次说明)
- [入门：你想做什么？](#入门你想做什么)
- [视频教程（中文）](#视频教程中文)
- [图文与评测](#图文与评测)
- [固件与资源网盘](#固件与资源网盘)
- [刷机工具（展锐 / spd_dump）](#刷机工具展锐--spd_dump)
- [UFI-TOOLS 与随身 WiFi 玩法](#ufi-tools-与随身-wifi-玩法)
- [Root / Magisk / KernelSU](#root--magisk--kernelsu)
- [进阶 ROM 与移植（Flyme / KernelSU-Next）](#进阶-rom-与移植flyme--kernelsu-next)
- [OpenWrt 与其它路线](#openwrt-与其它路线)
- [频段与作为 MiFi 的参考](#频段与作为-mifi-的参考)
- [通用展锐教程（可借鉴）](#通用展锐教程可借鉴)
- [相关 GitHub 项目](#相关-github-项目)
- [社区讨论](#社区讨论)
- [贡献](#贡献)

## 机型概览

| 项目 | 说明 |
| --- | --- |
| 品牌 / 型号 | 荣悦 E5（市面亦见 RongYue E5、键盘 5G 老人机形态） |
| SoC | 紫光展锐 **T158**（Unisoc，八核 5G） |
| GPU | Mali-G57 |
| 系统 | 出厂多为 **Android 13** |
| 屏幕 | 3.5″ IPS，320×480 触控 |
| 内存 / 存储 | 常见 **2GB+32GB** 或 **3GB+32GB**（批次不一，购买前确认） |
| 电池 | 3000mAh **可拆卸** |
| 接口 | USB Type-C（部分资料标注 USB 2.0） |
| 网络 | 双卡双待 5G、VoLTE；Wi‑Fi 5（AC433 等实测描述） |
| 其它 | TF 卡槽、实体键盘、可开热点当廉价 MiFi |
| OEM 背景 | 公开报道多指向贵州财富之舟等供应链；同方案公模在渠道上亦见 **ED351(5G)** 等型号描述 |

外观与 TCL T508N 等键盘机相似，闲鱼等平台大量流通，因低价 + 可刷机 + 可拆电池，常被当作「百元 5G 热点机」折腾。

## 硬件与批次说明

- **RAM 容量**：媒体与卖家描述在 2G / 3G 间不一致，刷入第三方 ROM 前务必确认内存版本（部分高版本移植 ROM 仅面向改内存机型）。
- **芯片平台**：折腾时以 **T158** 为准，勿与中兴 F50 等 **T760** 平台的 OpenWrt / 工具包混用（[什么值得买社区讨论](https://post.smzdm.com/p/agg58n3m/)）。
- **公模参数参考**：[POMP Mobile ED351(5G) 规格页](https://cn.pompmobile.com/productinfo109.html)（3GB+32GB、T158、Android 13 等，供对照非荣悦贴牌批次）。

## 入门：你想做什么？

| 目标 | 建议路径 |
| --- | --- |
| 官改系统 + 解锁 BL + 装 UFI-TOOLS | [B站：荣悦E5刷机+UFI-TOOLS](https://www.bilibili.com/video/BV1e65y69E3L/) → [官改包网盘](#固件与资源网盘) → [UFI-TOOLS](#ufi-tools-与随身-wifi-玩法) |
| 仅 Root（展瑞老头乐通用思路） | [B站：紫光5G老头乐 Root](https://www.bilibili.com/video/BV1woo9BPEmg/) + Magisk 资源见视频简介网盘 |
| 深刷 / 备份全分区 | Windows + 展锐驱动 + `spd_dump`，**先全盘备份**再写入 |
| 重度移植（Flyme / KernelSU-Next） | [Hovatek T158 线程](https://www.hovatek.com/forum/thread-49605.html)（含荣悦 E5 关键词，资源在帖内） |

### 进入 BROM / 下载模式（常见说法）

社区多条教程一致描述：

1. 关机（可拆电池机型建议断电更稳妥）。
2. **按住「返回 / Back」键**，再连接 USB 至电脑（或先按住 Back 再开机，以你使用的 `spd_dump` 脚本说明为准）。
3. 设备管理器中出现展锐 / Spreadtrum 端口后，在 `spd_dump` 中执行备份或刷写。

> 不同 ROM 包附带的一键脚本按键可能略有差异，**以你下载的刷机包内 BAT / 说明为准**。

### 刷机前建议备份的分区（展锐通用）

参考社区展锐深刷文档，至少关注：`splloader`、`uboot`、`sml`、`trustos`、`vbmeta`、`boot`、`recovery`、`system` 等；条件允许时使用 `r all` 或包内一键备份脚本做全分区备份。详见 [KDXF-LEAKiNG Unisoc.md](https://github.com/ig25138/KDXF-LEAKiNG-Project/blob/main/Unisoc.md)。

## 视频教程（中文）

- [荣悦E5刷机+UFI-TOOLS使用教程](https://www.bilibili.com/video/BV1e65y69E3L/) — MiniKano：官改包、QuTick102 版 `spd_dump`、UFI-TOOLS 模块
- [【也许是展瑞通用】紫光5G老头乐Root教程](https://www.bilibili.com/video/BV1woo9BPEmg/) — Magisk、`spd_dump` 致谢 TomKing062 / YC
- [老人机也会梦到Google，荣悦E5](https://www.bilibili.com/video/BV1t7ji6sEJr/) — 玩法向整活 / 折腾
- [UFI-TOOLS 相关安装演示](https://kanokano.cn/archives/1435.html) 文中链到的 B 站合集（F50/U30 流程可对照 PE 版尝试）

## 图文与评测

- [大量廉价5G手机涌入闲鱼！荣悦 E5 介绍](https://www.sohu.com/a/1034128812_99959092)（闲搞机 / 搜狐）
- [百元随身 WiFi 刷 OpenWrt：分清 T158 与 T760](https://post.smzdm.com/p/agg58n3m/) — 购买与平台选型
- [荣悦-E5 — MIFIPK 设备页](https://mifipk.com/en/devices/32) — 作为 MiFi 的延迟、频段与 UFI-TOOLS 测试版本记录
- [Кнопочник Rongyue E5 详细评测（俄语）](https://www.youtube.com/watch?v=NdD04OxYvxQ) — T158 / Mali-G57 / 可拆盖等

## 固件与资源网盘

| 资源 | 链接 | 备注 |
| --- | --- | --- |
| 荣悦 E5 官改系统（教程引用） | https://1816129281.share.123pan.cn/123pan/7oa5Vv-4vx03 | 见 [BV1e65y69E3L](https://www.bilibili.com/video/BV1e65y69E3L/) 简介；含解锁 BL / 去 AVB 等说明的包 |
| UFI-TOOLS 更新与插件 | https://pan.kanokano.cn/UFI-TOOLS-UPDATE | 官方维护的网盘入口 |
| 一键刷分区工具（7z） | https://pan.kanokano.cn/d/UFI-TOOLS-UPDATE/%E6%9D%82%E9%A1%B9/%E4%B8%80%E9%94%AE%E5%88%B7%E5%88%86%E5%8C%BA%E5%B7%A5%E5%85%B7.7z | [Root 教程 BV1woo9BPEmg](https://www.bilibili.com/video/BV1woo9BPEmg/) 简介 |
| Magisk APK（教程网盘） | https://pan.kanokano.cn/d/UFI-TOOLS-UPDATE/plugins/Magisk_28103.apk | 版本以网盘为准 |
| scrcpy / ADB 工具包 | https://pan.kanokano.cn/d/UFI-TOOLS-UPDATE/UFI-TOOLS%E4%B8%80%E9%94%AE%E5%AE%89%E8%A3%85%E5%99%A8/scrcpy | 投屏与调试 |
| QuTick102 私人空间 | http://qutick102.ysepan.com/ | 需密码；教程提到的定制 `spd_dump` |

网盘链接可能随时间失效，欢迎在 Issue 中提交可用镜像。

## 刷机工具（展锐 / spd_dump）

| 工具 | 链接 | 说明 |
| --- | --- | --- |
| **spreadtrum_flash**（开源） | https://github.com/TomKing062/spreadtrum_flash | 主流开源 `spd_dump` 实现，支持 Termux |
| **预编译 spd_dump / 解锁相关** | https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader/releases | 含 Windows 构建；注意驱动（官方 SPRD vs LibUSB） |
| **action_spd_dump_it** | https://github.com/TomKing062/action_spd_dump_it | 闭源分支，支持 `pac` 等扩展命令 |
| **spreadtrum_flash**（ilyakurdyukov） | https://github.com/ilyakurdyukov/spreadtrum_flash/releases | 另一套维护与 `spd_dump64.zip` |
| **SPRDClient** | https://github.com/YC-nw | 展锐工具链作者（社区致谢） |
| **紫光 USB 驱动** | 各教程包内常带 `SPRD_Driver_R4.x`；亦见 [Unisoc.md 配套驱动说明](https://github.com/ig25138/KDXF-LEAKiNG-Project/blob/main/Unisoc.md) | Windows 刷机前安装 |

常用命令形态（仅作索引，**以工具 `--help` 为准**）：

```text
# 示例：等待设备并读取全分区（路径与 FDL 因机型而异）
spd_dump --wait 300 fdl <fdl1> <addr1> fdl <fdl2> <addr2> exec <...> r all reset
```

荣悦 E5 教程多使用 **QuTick102 定制的 spd_dump** 与包内 FDL，不建议随意混用其它机型的 FDL。

## UFI-TOOLS 与随身 WiFi 玩法

UFI-TOOLS 最初面向中兴 F50 / U30 Air（T760），但社区已在 T158 的荣悦 E5 上实践「刷官改 + 装模块」路线。

| 资源 | 链接 |
| --- | --- |
| 项目主页 | https://github.com/kanoqwq/UFI-TOOLS |
| 用户文档（http-server 分支） | https://github.com/kanoqwq/UFI-TOOLS/blob/http-server-version/User_Doc.md |
| 食用指南（安装、PE 版、完整版） | https://kanokano.cn/archives/1435.html |
| Web 版相关（F50-SMS 系） | https://github.com/kanoqwq/F50-SMS |

要点：

- 先按视频刷入**已解锁 BL 的官改系统**，再安装 UFI-TOOLS 模块 / APK。
- 非官方适配机型可能功能不全，属正常现象；可从 **PE 版**远程管理试起。
- 拔电前等待缓存写入完成（教程常建议等待数分钟）。

## Root / Magisk / KernelSU

- [紫光5G老头乐 Root 教程](https://www.bilibili.com/video/BV1woo9BPEmg/) — 展瑞平台通用思路，简介含 Magisk 与分区工具网盘。
- 官改包描述中常见：**默认已解锁 Bootloader 并解除 AVB**，便于直接刷入 Magisk / 修改 boot。

## 进阶 ROM 与移植（Flyme / KernelSU-Next）

- [Full Bootloader Unlock & KernelSU Guide for Unisoc T158 (RongYue E5 / Meizu Note 16)](https://www.hovatek.com/forum/thread-49605.html) — 英文长帖，含：
  - BROM 一键备份 / 刷入 Flyme 移植包脚本说明
  - 内置 **KernelSU-Next**、Zygisk-Next、LSPosed 等
  - 荣悦 E5 专用键位映射插件说明（Menu / Back / \* 等）
  - 下载链接在帖内（第三方网盘，自行甄别）

适合已有展锐刷机经验、且接受 Flyme 移植风险的用户；**内存改版（如 4GB）** 与标准 2G/3G 机是否适用请以帖内标注为准。

## OpenWrt 与其它路线

- 社区有在荣悦 E5 上探索 **OpenWrt / 软路由** 的讨论，但 T158 生态明显弱于 T760（中兴 F50）等平台；选型参考 [什么值得买：T158 vs T760](https://post.smzdm.com/p/agg58n3m/)。
- 若目标是「长期可维护的 5G 路由」，许多玩家最终会选择 F50 等成熟平台；E5 更适合低价尝鲜。

## 频段与作为 MiFi 的参考

[MIFIPK 荣悦-E5](https://mifipk.com/en/devices/32) 收录了在 UFI-TOOLS 等环境下的测速、延迟与 **5G/4G 频段列表**（测试版本 V3.5 等），购机前可对照本地运营商频段。

## 通用展锐教程（可借鉴）

- [ig25138 / KDXF-LEAKiNG-Project — Unisoc.md](https://github.com/ig25138/KDXF-LEAKiNG-Project/blob/main/Unisoc.md) — 驱动、`spd_dump`、备份与 `w system` 等命令详解（面向学习机/UD710 等，思路可迁移，**FDL 与分区表勿照搬**）。

## 相关 GitHub 项目

- [TomKing062/spreadtrum_flash](https://github.com/TomKing062/spreadtrum_flash) — 开源刷机工具
- [TomKing062/CVE-2022-38694_unlock_bootloader](https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader) — BL 解锁研究与发布
- [kanoqwq/UFI-TOOLS](https://github.com/kanoqwq/UFI-TOOLS) — UFI 管理后台与插件
- [kanoqwq/F50-SMS](https://github.com/kanoqwq/F50-SMS) — UFI-TOOLS Web 相关

## 社区讨论

- [Hovatek — Unisoc T158 / RongYue E5](https://www.hovatek.com/forum/thread-49605.html)
- B 站搜索关键词：`荣悦E5`、`荣悦 E5 刷机`、`T158 spd_dump`
- 酷安 / 贴吧等中文社区亦有零星玩机帖（链接易变，欢迎 PR 补充）

## 贡献

欢迎通过 Pull Request 补充链接。请遵循 [贡献指南](CONTRIBUTING.md)。

若你发现失效链接或错误信息，请开 Issue 说明机型批次与来源。

---

**License**: [CC0-1.0](LICENSE)（链接与文档索引；各外链资源版权归原作者所有。）
