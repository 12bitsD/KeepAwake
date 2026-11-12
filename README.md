<div align="center">

<picture>
  <source media="(max-width: 600px) and (prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/12bitsD/KeepAwake/main/docs/assets/logo-compact-dark.svg">
  <source media="(max-width: 600px) and (prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/12bitsD/KeepAwake/main/docs/assets/logo-compact-light.svg">
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/12bitsD/KeepAwake/main/docs/assets/logo-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/12bitsD/KeepAwake/main/docs/assets/logo-light.svg">
  <img alt="KeepAwake — native macOS menu bar utility" src="https://raw.githubusercontent.com/12bitsD/KeepAwake/main/docs/assets/logo-light.svg" width="800" height="200" fetchpriority="high">
</picture>

<p>
  <a href="https://github.com/12bitsD/KeepAwake/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/12bitsD/KeepAwake?style=flat-square&amp;color=black&amp;label=release"></a>
  <a href="https://github.com/12bitsD/KeepAwake/releases/latest"><img alt="macOS 12 or later, Apple Silicon" src="https://img.shields.io/badge/macOS_12%2B-arm64-black?style=flat-square"></a>
  <a href="Sources/main.swift"><img alt="Swift and AppKit" src="https://img.shields.io/badge/Swift-AppKit-black?style=flat-square"></a>
  <a href="LICENSE"><img alt="MIT license" src="https://img.shields.io/badge/license-MIT-black?style=flat-square"></a>
</p>

<p>
  <a href="#安装">安装</a> ·
  <a href="#功能">功能</a> ·
  <a href="#使用">使用</a> ·
  <a href="#工作原理">工作原理</a> ·
  <a href="#从源码构建">源码构建</a>
</p>

</div>

一个轻量、原生的 macOS 菜单栏防熄屏工具。一个开关、一组计时器，让 Mac 只在需要时保持清醒。

**Swift / AppKit · 无第三方依赖 · 不联网 · 不修改系统电源设置**

## 安装

<table role="presentation">
  <tr>
    <td width="50%" valign="top">
      <strong>01 / 下载</strong><br><br>
      <a href="https://github.com/12bitsD/KeepAwake/releases/download/v1.2.0/KeepAwake-1.2.0-macos-arm64.dmg"><strong>下载 KeepAwake v1.2.0 DMG</strong></a><br><br>
      Apple Silicon Mac（arm64）<br>
      macOS 12.0 或更高版本
    </td>
    <td width="50%" valign="top">
      <strong>02 / 拖入应用程序</strong><br><br>
      打开 DMG，将 <code>KeepAwake.app</code> 拖入 <code>Applications</code>。<br><br>
      从“应用程序”启动，然后推出 DMG 镜像。
    </td>
  </tr>
</table>

> 当前附件使用 ad-hoc 签名，未提供 Apple Developer ID 签名或公证。如 macOS 阻止打开，请在“系统设置 → 隐私与安全性”中查看并确认是否允许运行。

## 功能

<table role="presentation">
  <tr>
    <td width="50%" valign="top">
      <strong>01 / 一键防熄屏</strong><br>
      同时阻止显示器睡眠和系统闲置睡眠，菜单一键切换。
    </td>
    <td width="50%" valign="top">
      <strong>02 / 精确计时</strong><br>
      预设 1 分钟至 1 小时，也可自定义 1–10080 分钟或无限期。
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <strong>03 / 到期处理</strong><br>
      显示倒计时，到期自动恢复；可选立即关闭显示器。
    </td>
    <td width="50%" valign="top">
      <strong>04 / 合盖运行</strong><br>
      接通电源时阻止合盖系统睡眠，内置显示屏正常关闭。
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <strong>05 / 无感驻留</strong><br>
      只驻留菜单栏，不占用 Dock；记住时长和功能选项。
    </td>
    <td width="50%" valign="top">
      <strong>06 / 干净退出</strong><br>
      手动关闭或退出应用时，自动清理对应防休眠进程。
    </td>
  </tr>
</table>

## 使用

<p align="center">
  <strong>01 / 点击杯子</strong> →
  <strong>02 / 选择时长</strong> →
  <strong>03 / 开启防熄屏</strong>
</p>

应用启动后默认不开启防熄屏。选择预设或自定义整数分钟数（默认“无限期”），再点击“开启防熄屏”；实心杯子表示正在保持唤醒。

“到时自动息屏”和“合盖保持唤醒”默认开启，可在菜单中分别调整。只有有限时长自然到期时才可能自动息屏；无限期、手动关闭或退出应用都不会触发息屏。

## 工作原理

KeepAwake 调用 macOS 自带的 `caffeinate`，不安装后台服务。计时由应用自身管理，子进程跟随应用生命周期退出。

**合盖保持唤醒 / 开启**

```bash
/usr/bin/caffeinate -dis -w <PID>
```

接通电源时额外阻止合盖系统睡眠。

**合盖保持唤醒 / 关闭**

```bash
/usr/bin/caffeinate -di -w <PID>
```

仅阻止显示器和系统闲置睡眠。

<details>
  <summary><strong>参数与到期行为</strong></summary>
  <br>
  <ul>
    <li><code>-d</code>：阻止显示器闲置睡眠。</li>
    <li><code>-i</code>：阻止系统闲置睡眠。</li>
    <li><code>-s</code>：阻止系统睡眠，包括接通电源时的合盖睡眠。</li>
    <li><code>-w</code>：跟随 KeepAwake 的进程生命周期。</li>
  </ul>
  <p>有限时长自然到期且开启“到时自动息屏”时，应用运行 <code>/usr/bin/pmset displaysleepnow</code>。该命令只请求显示器睡眠，不执行锁屏命令。</p>
  <p>保持唤醒期间切换合盖模式会重启 <code>caffeinate</code>，并保留原倒计时。</p>
</details>

## 从源码构建

**01 / 编译**

需要 Swift 编译器，可由 Xcode Command Line Tools 提供。构建产物位于 `build/KeepAwake.app`。

```bash
git clone https://github.com/12bitsD/KeepAwake.git
cd KeepAwake
./build.sh
open build/KeepAwake.app
```

**02 / 安装到当前用户**

构建脚本为当前机器架构生成原生可执行文件。

```bash
INSTALL_DIR="$HOME/Applications" ./build.sh
open "$HOME/Applications/KeepAwake.app"
```

## 边界

- 合盖保持唤醒需要连接电源适配器；它让系统继续运行，不让内置显示屏在合盖后保持亮起。
- 不阻止屏幕锁定，不绕过系统安全设置，也不覆盖管理员或其他系统策略强制的电源设置。
- 自动息屏后是否锁定仍由 macOS 的密码策略决定，KeepAwake 不会修改该策略。

<br>

<div align="center">
  <sub>SMALL TOOL. NO NOISE.</sub><br><br>
  <a href="LICENSE">MIT License</a> ·
  <a href="https://github.com/12bitsD/KeepAwake/releases">Releases</a> ·
  <a href="https://github.com/12bitsD/KeepAwake">GitHub</a>
</div>
