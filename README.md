# 不熄屏 KeepAwake

一个轻量、原生的 macOS 菜单栏防熄屏应用。使用 Swift 和 AppKit 编写，无第三方依赖，不联网，不修改系统电源设置。

## 功能

- 菜单一键开启或关闭防熄屏
- 同时阻止显示器睡眠和系统闲置睡眠
- 支持 1 分钟、15 分钟、30 分钟、1 小时和无限期
- 显示倒计时，到期自动恢复
- 记住上次选择的时长
- 退出应用时自动清理防休眠进程
- 仅驻留菜单栏，不占用 Dock

## 系统要求

- macOS 12.0 或更高版本
- 构建时需要 Swift 编译器（可通过 Xcode Command Line Tools 提供）

## 构建

```bash
git clone https://github.com/12bitsD/KeepAwake.git
cd KeepAwake
./build.sh
open build/KeepAwake.app
```

构建产物位于 `build/KeepAwake.app`。脚本会为当前机器架构编译原生可执行文件。

安装到当前用户的应用目录：

```bash
INSTALL_DIR="$HOME/Applications" ./build.sh
open "$HOME/Applications/KeepAwake.app"
```

## 使用

1. 点击菜单栏中的杯子图标。
2. 在“保持时长”中选择需要的时间，默认是“无限期”。
3. 点击“开启防熄屏”。图标变为实心杯子时表示正在保持唤醒。
4. 点击“关闭防熄屏”可立即恢复；选择“退出不熄屏”也会停止防休眠。

应用启动后不会自动开启防熄屏，需要手动启用。

## 工作原理

开启时，应用启动 macOS 自带的工具：

```bash
/usr/bin/caffeinate -di -w <KeepAwake 进程 PID>
```

- `-d`：阻止显示器闲置睡眠。
- `-i`：阻止系统闲置睡眠。
- `-w`：跟随 KeepAwake 的进程生命周期，应用退出时自动结束。

定时由应用自身管理。手动关闭、倒计时结束和正常退出都会终止对应的 `caffeinate` 子进程。

## 限制

- 不阻止屏幕锁定，也不绕过系统安全设置。
- 不支持 MacBook 合盖后继续运行。
- 不覆盖管理员或其他系统策略强制的电源设置。
- 当前为本地构建的未签名应用，未提供经过 Apple 公证的安装包。

## 开源许可

[MIT License](LICENSE)
