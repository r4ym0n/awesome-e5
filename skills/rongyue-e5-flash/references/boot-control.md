# 启动控制块（misc 偏移 2048，32 字节）

## 位置

```
分区：/dev/block/by-name/misc   (1 MB)
偏移：2048 字节
长度：32 字节
格式：展锐私有 BCAB（不是 AOSP 标准 bootloader_control）
```

读取：

```sh
dd if=/dev/block/by-name/misc bs=1 skip=2048 count=32 2>/dev/null | od -An -tu1 -v
```

实测输出（16 进制）：

```
00000000: 5f62 0000 4243 4142 0102 0000 9e00 2f00
00000010: 0000 0000 0000 0000 0000 0000 9bf8 546d
```

对应 ASCII：`_b..BCAB......./.................Tm`

## 字段布局

依据 `android-bootchain.sh` 的 `check_misc()` 反推：

| 偏移 | 长度 | 含义 | 实测值 | 校验规则 |
| --- | --- | --- | --- | --- |
| 0 | 4 | 槽位标识 | `_b\0\0` | 文本 `_a` 或 `_b` |
| 4 | 4 | 魔数 | `BCAB` | 必须等于 `66 67 65 66`（ASCII "BCAB"） |
| 8 | 1 | 版本 | `01` | 必须 = 1 |
| 9 | 1 | 槽位状态 | `02` | 低 3 位必须 = 2 |
| 10 | 1 | 保留 | `00` | |
| 11 | 1 | 保留 | `00` | |
| 12 | 1 | slot_a 计数 | `9e` | bit7 = 128 表示有效；低 4 位 > 0 |
| 13 | 1 | slot_a 成功标志 | `00` | bit0 必须 = 0 |
| 14 | 1 | slot_b 计数 | `2f` | |
| 15 | 1 | slot_b 成功标志 | `00` | bit0 必须 = 0 |
| 16–27 | 12 | 保留 | 全 0 | |
| 28 | 4 | CRC32（小端） | `9b f8 54 6d` | 见下 |

## CRC32 算法

`android-bootchain.sh` 里的实现（对前 28 字节）：

```sh
crc=4294967295            # 0xFFFFFFFF
i=0
for byte in $bytes; do    # 只取前 28 字节
    if [ "$i" -lt 28 ]; then
        crc=$((crc ^ byte))
        bit=0
        while [ "$bit" -lt 8 ]; do
            if [ $((crc & 1)) = 1 ]; then
                crc=$(((crc >> 1) ^ 3988292384))   # 0xEDB88320 反射多项式
            else
                crc=$((crc >> 1))
            fi
            bit=$((bit + 1))
        done
    else
        # 后 4 字节是存储的 CRC（小端拼接）
        stored=$((stored | (byte << ((i - 28) * 8))))
    fi
    i=$((i + 1))
done
# 最终比较
[ $(((crc ^ 4294967295) & 4294967295)) = "$stored" ]
```

即标准 **CRC-32/ISO-HDLC**（多项式 `0xEDB88320`，初值 `0xFFFFFFFF`，结果取反），
存储在偏移 28–31，**小端序**。

Python 等价：

```python
import zlib, struct
blk = bytes.fromhex('5f620000424341420102000 09e002f00'.replace(' ',''))
body = blk[:28]
stored = struct.unpack('<I', blk[28:32])[0]
calc = zlib.crc32(body) & 0xFFFFFFFF
assert calc == stored
```

## 状态含义

`check_misc()` 的完整校验条件（任一不满足即判定「无效控制块」）：

1. 长度 = 32 字节
2. 偏移 4–7 = `BCAB`
3. 偏移 8 = 1（版本）
4. 偏移 9 低 3 位 = 2（槽位状态）
5. 偏移 12 bit7 = 1（slot_a 有效）**且** 低 4 位 > 0（slot_a 有尝试计数）
6. 偏移 13 bit0 = 0（slot_a 无未决错误）
7. 偏移 15 bit0 = 0（slot_b 无未决错误）
8. CRC32 匹配
9. `slot_b 计数 <= slot_a 计数` —— 防止 B 槽是「未完成的 Android OTA」

第 9 条的含义：如果 B 槽计数比 A 高，说明可能是 OTA 写到一半，此时**不要消耗 B 槽的回退链**。

## 试启动（trial boot）机制

安装器写的是「试启动」标记，流程：

```
写入 boot_b + 设置 misc 指向 b + 标记为 trial
        ↓
    重启，走 slot b
        ↓
  ┌─────────────┴─────────────┐
启动成功                     启动失败
  ↓                            ↓
标记 b 为成功              b 的尝试计数 +1
（计数清零）                    ↓
                          计数达上限（2 次）
                                ↓
                          自动回退 slot a（Android）
```

**实测**：第一次重启回到了 Android，第二次重启才进入 OpenWrt。
所以「第一次没进去」是预期行为，不是故障。

## e5-bootctl

`/data/.../files/e5-bootctl`（546864 B，ARM64 静态二进制）。

从二进制字符串提取到的动作关键字：

```
android   linux   sd   arm   trial
```

用法（安装器内部调用）：

```sh
e5-bootctl check                    # 校验当前控制块
e5-bootctl arm <backup-file>        # 武装下次启动（备份当前控制块到文件）
```

## e5-next-boot

`/usr/bin/e5-next-boot`（6208 B，OpenWrt 侧脚本/二进制）。

```sh
e5-next-boot android    # 下次启动 Android
e5-next-boot linux      # 下次启动 OpenWrt
```

配合重启：

```sh
e5-next-boot android && reboot
```

## 相关启动选择文件（Android 侧）

| 路径 | 内容 | 作用 |
| --- | --- | --- |
| `/data/e5linux/boot-os` | `sd` / `android` / `linux` | 启动目标 |
| `/data/e5linux/boot-os-next` | 同上 | 下次启动目标（一次性） |
| `/data/e5linux/openwrt-default-boot` | `linux` | 默认启动策略 |

实测安装后：`boot-os` = `sd`，`openwrt-default-boot` 为空，`boot-os-next` 不存在。

> 这三个文件是 **OpenWrt / 安装器** 的约定，不是 bootloader 直接读的。
> 真正决定启动的是 `misc` 的 32 字节控制块。

## 备份与恢复控制块

安装器会自动备份：

```
/data/adb/e5-boot-control/before.<random>     # 32 字节原始控制块
```

手动备份/恢复：

```sh
# 备份
dd if=/dev/block/by-name/misc bs=1 skip=2048 count=32 of=/sdcard/misc-bcb.bin

# 恢复
dd if=/sdcard/misc-bcb.bin of=/dev/block/by-name/misc bs=1 seek=2048 conv=fsync
sync
```

> **恢复前务必确认 CRC 有效**，否则 bootloader 会认为控制块损坏。

## 为什么没有 recovery

1. 70 个分区里**没有 `recovery`** 分区
2. 展锐用私有 `BCAB` 而非 AOSP 标准 `bootloader_control`
3. 因此也没有标准 `bootctl` 接口（`/system/bin/bootctl` 不存在）
4. 官改 ROM 已移除 recovery 依赖

→ **不要向用户承诺「在 recovery 里选系统」**。可用的切换入口只有：
屏幕菜单、`e5-next-boot` 命令、Android 侧的切换器 App。
