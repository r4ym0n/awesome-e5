# T158 分区表（70 个）

来源：`spd_dump r all` 实测 dump，eMMC，GPT。

| # | 分区名 | 大小 | 备注 |
| --- | --- | --- | --- |
| 0 | `splloader` | 256 KB | 二级引导，**BROM 签名校验对象** |
| 1 | `prodnv` | 64 MB | **基带 / IMEI / 射频校准 —— 丢了没信号** |
| 2 | `miscdata` | 1 MB | |
| 3 | `misc` | 1 MB | **偏移 2048 处 32 字节 = 启动控制块** |
| 4 | `trustos_a` | 6 MB | TEE OS（slot a） |
| 5 | `trustos_b` | 6 MB | TEE OS（slot b） |
| 6 | `sml_a` | 1 MB | Secure Monitor Loader（a） |
| 7 | `sml_b` | 1 MB | |
| 8 | `uboot_a` | 3 MB | U-Boot / LK（a） |
| 9 | `uboot_b` | 3 MB | |
| 10 | `uboot_log` | 16 MB | U-Boot 日志分区 |
| 11 | `logo` | 8 MB | 开机 logo |
| 12 | `fbootlogo` | 8 MB | 首屏 logo |
| 13 | `nr_fixnv1_a` | 50 MB | 固定 NV（a）——**基带** |
| 14 | `nr_fixnv1_b` | 50 MB | |
| 15 | `nr_fixnv2_a` | 50 MB | |
| 16 | `nr_fixnv2_b` | 50 MB | |
| 17 | `nr_runtimenv1` | 55 MB | 运行时 NV |
| 18 | `nr_runtimenv2` | 55 MB | |
| 19 | `persist` | 2 MB | **传感器校准 / WiFi MAC 等** |
| 20 | `nr_modem_a` | 50 MB | 调制解调器固件（a） |
| 21 | `nr_modem_b` | 50 MB | |
| 22 | `nr_deltanv_a` | 1 MB | |
| 23 | `nr_deltanv_b` | 1 MB | |
| 24 | `nr_phy_a` | 50 MB | 射频物理层（a） |
| 25 | `nr_phy_b` | 50 MB | |
| 26 | `l_agdsp_a` | 6 MB | AGDSP 固件（a） |
| 27 | `l_agdsp_b` | 6 MB | |
| 28 | `pm_sys_a` | 1 MB | |
| 29 | `pm_sys_b` | 1 MB | |
| 30 | `ch_sys_a` | 16 MB | |
| 31 | `ch_sys_b` | 16 MB | |
| 32 | `teecfg_a` | 1 MB | TEE 配置（a） |
| 33 | `teecfg_b` | 1 MB | |
| 34 | `hypervsior_a` | 10 MB | **实测全零** |
| 35 | `hypervsior_b` | 10 MB | |
| 36 | `boot_a` | 64 MB | Android 内核（a） |
| 37 | `boot_b` | 64 MB | **OpenWrt 内核写在这里** |
| 38 | `vendor_boot_a` | 100 MB | |
| 39 | `vendor_boot_b` | 100 MB | |
| 40 | `init_boot_a` | 8 MB | **Magisk 打补丁的目标** |
| 41 | `init_boot_b` | 8 MB | |
| 42 | `dtb_a` | 8 MB | **实测全零** |
| 43 | `dtb_b` | 8 MB | |
| 44 | `dtbo_a` | 8 MB | |
| 45 | `dtbo_b` | 8 MB | |
| 46 | `super` | 5600 MB | **动态分区（system/vendor/product/odm）** |
| 47 | `cache` | 64 MB | `r all` 会跳过 |
| 48 | `blackbox` | 500 MB | `r all` 会跳过 |
| 49 | `vbmeta_a` | 1 MB | **AVB 元数据（a）** |
| 50 | `vbmeta_b` | 1 MB | |
| 51 | `metadata` | 64 MB | |
| 52 | `sysdumpdb` | 60 MB | |
| 53 | `vbmeta_system_a` | 1 MB | |
| 54 | `vbmeta_system_b` | 1 MB | |
| 55 | `vbmeta_vendor_a` | 1 MB | |
| 56 | `vbmeta_vendor_b` | 1 MB | |
| 57 | `vbmeta_system_ext_a` | 1 MB | |
| 58 | `vbmeta_system_ext_b` | 1 MB | |
| 59 | `vbmeta_product_a` | 1 MB | |
| 60 | `vbmeta_product_b` | 1 MB | |
| 61 | `vbmeta_odm_a` | 1 MB | |
| 62 | `vbmeta_odm_b` | 1 MB | |
| 63 | `avbmeta_rs_a` | 1 MB | **实测全零** |
| 64 | `avbmeta_rs_b` | 1 MB | |
| 65 | `common_rs1_a` | 8 MB | |
| 66 | `common_rs1_b` | 8 MB | |
| 67 | `common_rs2_a` | 16 MB | **实测全零** |
| 68 | `common_rs2_b` | 16 MB | |
| 69 | `calinv` | 15 MB | 校准数据 |
| 70 | `userdata` | 22380 MB | **用户数据，`r all` 会跳过** |

## 备份覆盖率

`r all` 实测产出 **68 个文件 / 6.7 GB**，跳过的是：

| 跳过的分区 | 原因 |
| --- | --- |
| `userdata` | 用户数据，太大且不需要 |
| `cache` | 缓存 |
| `blackbox` | 500 MB 日志 |

**注意**：`r all` **不跳过** `prodnv` / `nr_fixnv*` / `nr_modem*` / `nr_phy*` / `persist` / `calinv`
—— 这些基带相关分区**都在备份里**，这是好事。

## 关键分区分类

### 刷机会改的（官改 ROM 覆盖）

```
splloader  uboot_a  trustos_a  sml_a  teecfg_a  hypervsior_a
boot_a  init_boot_a  vendor_boot_a  dtb_a  dtbo_a
vbmeta_a  vbmeta_{odm,product,system,system_ext,vendor}_a  avbmeta_rs_a
super  metadata  misc  logo  fbootlogo
ch_sys_a  common_rs1_a  common_rs2_a  l_agdsp_a  pm_sys_a
nr_runtimenv1  nr_runtimenv2  persist
```

共 **31 个**（= `data/` 里的 31 个 `.bin`）。

### 刷机**不会**改的（ROM 里没有对应镜像）

```
prodnv  nr_fixnv1_a/b  nr_fixnv2_a/b  nr_modem_a/b  nr_deltanv_a/b
nr_phy_a/b  calinv  userdata  cache  blackbox  sysdumpdb  miscdata  uboot_log
```

→ **基带 / IMEI / 校准数据天然安全**，但仍必须备份（万一误操作）。

### OpenWrt 会写的

```
boot_b        # boot.img（OpenWrt 内核）
misc[2048:32] # 启动控制块（32 字节）
```

只这两个。Android 侧 slot a 完全不动。

## 全零分区（正常，不是损坏）

实测 ROM 与真机**都是全零**：

| 分区 | 大小 | ROM 密度 | 真机密度 |
| --- | --- | --- | --- |
| `dtb_a` | 8 MB | 0.0% | 0.0% |
| `hypervsior_a` | 10 MB | 0.0% | 0.0% |
| `common_rs2_a` | 16 MB | 0.0% | 0.0% |
| `avbmeta_rs_a` | 1 MB | 0.0% | 0.0% |

判断方法：**必须先有备份**，然后逐字节对比。只看 ROM 无法区分「正常的空分区」和「打包错误」。

`super.bin` 密度 41.4%（ROM）/ 41.5%（真机）—— 稀疏镜像，正常。

## 分区大小核对命令

```powershell
# 从备份文件大小反查分区大小（备份按分区实际大小写出）
Get-ChildItem <backup_dir> -Filter *.bin |
  Select-Object BaseName, @{n='MB';e={[math]::Round($_.Length/1MB,1)}} |
  Sort-Object BaseName | Format-Table -AutoSize
```

在设备上（Android + root）：

```sh
ls -l /dev/block/by-name/           # 符号链接到 /dev/block/mmcblk0pN
blockdev --getsize64 /dev/block/by-name/boot_a
```
