# 能否使用 macOS 作为刷机环境？

**结论：可用，但不建议。**

荣悦 E5（展锐 T158）的深刷、备份与刷入 e5-linux / OpenWrt 整包，在技术上可以在 macOS 上完成，但国内社区教程与一键整合包几乎都以 **Windows + 官方展锐驱动 + `.bat` 脚本** 为准。首次刷机或刷 e5-linux 时，更稳妥的做法仍是 **Windows 实体机或虚拟机**；macOS 更适合已有经验后的备份、维护，或仅做 Android 侧（ADB、UFI-TOOLS 安装）操作。

---

## macOS 上能做什么

| 环节 | macOS |
| --- | --- |
| BROM 模式下备份 / 写分区（`spd_dump`） | 可以（需 **LibUSB**，不依赖 Windows 专用 SPRD 驱动） |
| `adb`、投屏、USB 调试 | 可以 |
| UFI-TOOLS 装到手机（官改 Android 路线） | 可以（[macOS 一键安装器](https://pan.kanokano.cn/d/UFI-TOOLS-UPDATE/plugins/UFI-TOOLS%E5%85%A8%E8%87%AA%E5%8A%A8%E5%AE%89%E8%A3%85%E5%99%A8_macos.zip)） |
| e5-linux / OpenWrt 教程里的 `.bat` 一键刷机 | 不能直接运行，需改用手动命令或跨平台工具 |
| 官方 `DPInst` 展锐 USB 驱动 | 不支持（仅 Windows） |

BROM 下设备常见 USB ID：**`1782:4d00`**（展锐），LibUSB 工具可识别。

---

## 为什么不建议作为主刷机系统

1. **教程不可复制**：B 站、网盘包多为「装驱动 → 双击 `01备份.bat` / `02刷机.bat`」，Mac 需自行安装工具并把 bat 里的 `spd_dump` 参数翻译成 shell。
2. **工具链分裂**：QuTick102 定制 `spd_dump`、e5-linux 整合包多为 **Windows 预编译**；Mac 需从包内提取 FDL、镜像、`gpt.xml`，再用下方 Mac 向工具复现流程，踩坑成本高。
3. **驱动模型不同**：Windows 用官方 Spreadtrum 驱动；Mac 用 LibUSB（与 TomKing062 发布页中的 LibUSB 版 `spd_dump` 思路一致），命令细节（如 `exec_addr2`、`disable_transcode`）需对照文档。
4. **风险不变**：FDL、加载地址、分区表必须 **T158 / 荣悦 E5 专用**；刷前仍应 **全盘备份**。误操作在 Mac 与 Windows 上一样可能变砖。

若只求省事跟教程走一遍，**Parallels / UTM 安装 Windows** 往往比第一次在 Mac 上手搓命令更稳。

---

## 若坚持使用 macOS：工具与依赖

### 依赖

```bash
brew install libusb
```

部分项目还需 `pkg-config`、`cmake` 等，以各仓库 README 为准。

### 推荐关注的 Mac / 跨平台工具

| 工具 | 链接 | 说明 |
| --- | --- | --- |
| **spd_dump-macos** | https://github.com/xun404/spd_dump-macos | 标明在 **UMS9621（T158）**、Android 13 / GKI 上验证；含 `exec_addr2`、分区规则与刷写脚本示例 |
| **sfd_tool** | https://github.com/C-Hidery/sfd_tool | 跨平台 GUI/CLI，提供 macOS 构建；`--no-gui` 适合脚本 |
| **spreadtrum_flash** | https://github.com/TomKing062/spreadtrum_flash | 可自行在 Mac 编译；是否满足 T158 的 `exec_addr2` 以实测为准 |
| **TomKing062 预编译发布** | https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader/releases | 主要为 Windows；LibUSB 版思路与 Mac 一致，可参考命令形态 |

### 与 e5-linux / OpenWrt 整包

- 固件、FDL、`gpt.xml` 仍从 **[B站 e5-linux 教程](https://www.bilibili.com/video/BV1htpJ6NECu/)** 及作者提供的 GitHub / 网盘获取。
- **不要**使用中兴 F50（T760）的 OpenWrt 包或 FDL。
- 官方 [OpenWrt Firmware Selector](https://firmware-selector.openwrt.org/) **未收录** T158，E5 路线为社区 **e5-linux 整包替换**，非 `sysupgrade.bin` 直刷。

### BROM 进入方式（荣悦 E5，常见）

关机 → **按住 Back（返回键）** → 连接 USB（部分包写法略有不同，**以固件包内说明为准**）。

Hovatek 等资料指出：E5 在出厂 Android 上 **无** 物理按键组合进入 Fastboot/Recovery，需通过 `adb reboot bootloader` 等（刷 Linux 整包前若仍在 Android，可先做好备份与调试授权）。

---

## 建议分工

| 场景 | 建议环境 |
| --- | --- |
| 第一次刷机、e5-linux 整包、跟 QuTick102 一键包 | **Windows**（或 Mac 上的 Windows 虚拟机） |
| 日常 `adb`、UFI-TOOLS 安装、已熟悉命令后的备份 | **macOS 可以** |
| 长期 OpenWrt 插件、社区问答密度 | 设备是 T158，生态弱于 T760（F50）；见 [OpenWrt 选型讨论](https://post.smzdm.com/p/agg58n3m/) |

---

## 相关链接

- [老人机刷上 openwrt 改造随身 WiFi — 荣悦 E5（B站）](https://www.bilibili.com/video/BV1htpJ6NECu/)
- [荣悦 E5 刷机 + UFI-TOOLS（B站）](https://www.bilibili.com/video/BV1e65y69E3L/)
- [Hovatek — Unisoc T158 / RongYue E5](https://www.hovatek.com/forum/thread-49605.html)
- [主 README — 刷机工具与其它资源](../README.md)

如发现 Mac 向工具或命令有更新，欢迎向本仓库提交 Pull Request。
