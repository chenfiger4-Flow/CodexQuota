# CodexQuota

A tiny macOS menu bar app that shows your remaining Codex quota and reset timers.

It reads quota data from the local Codex CLI app-server via JSON-RPC, so it uses the same logged-in Codex account as your local `codex` command. You do not paste tokens, cookies, or passwords into this app.

## Features

- Native macOS menu bar item
- Shows 5-hour and weekly Codex quota windows
- Displays remaining percentage, reset countdown, and weekly reset date
- Reuses a long-running Codex CLI RPC child process
- Stores only a small local config file under `~/.codex-menubar/`

## Requirements

- macOS 14 or later
- Swift toolchain / Xcode Command Line Tools
- Codex CLI installed and already logged in

Check that Codex CLI works before launching the app:

```bash
codex --version
```

## 中文使用说明

CodexQuota 是一个 macOS 状态栏小工具，用来显示当前 Codex 账号的额度剩余比例和重置时间。它不会要求你输入 ChatGPT 密码、token 或 cookie，而是读取你本机已经登录的 Codex CLI。

### 使用前准备

1. 确认已经安装并登录 Codex CLI。

```bash
codex --version
```

2. 如果 `codex --version` 可以正常输出版本号，就可以启动本工具。

### 运行方式

从仓库根目录直接运行：

```bash
swift run
```

也可以打包成 `.app`：

```bash
bash scripts/build-app.sh
open .build/CodexQuota.app
```

安装到“应用程序”：

```bash
cp -R .build/CodexQuota.app /Applications/CodexQuota.app
open /Applications/CodexQuota.app
```

### 状态栏显示含义

- 第一行显示 5 小时窗口的剩余额度百分比和完整重置时刻。
- 第二行显示每周窗口的剩余额度百分比和重置日期。
- 背景为蓝色表示额度充足，橙色表示额度偏低，红色表示额度很低。
- 点击状态栏小组件可以查看更完整的额度、重置时间、计划类型和 credits 信息。

注意：Codex 设置页可能会显示“下一次额度恢复”的倒计时；当前 Codex CLI RPC 只提供完整窗口重置时间，所以状态栏显示本地重置时刻而不是恢复倒计时。

### 配置文件

配置文件位置：

```text
~/.codex-menubar/config.json
```

当前支持的配置项：

```json
{
  "source": "codexRPC",
  "refreshIntervalSeconds": 30
}
```

`refreshIntervalSeconds` 表示刷新 Codex 额度的间隔秒数。配置文件不存在时，应用会自动创建默认配置。
`proxyURL` 是可选项。如果你使用 Clash、Surge、Loon 等本地代理，而状态栏 App 显示读取失败，可以把它设置为你的代理地址：

```json
{
  "source": "codexRPC",
  "refreshIntervalSeconds": 30,
  "proxyURL": "http://127.0.0.1:7890"
}
```

### 常见问题

- 如果显示“读取中”或“读取失败”，先确认终端里 `codex --version` 可以正常运行。
- 如果显示“启动失败”，通常是应用找不到 `codex` 命令，建议确认 Codex CLI 安装路径在系统 `PATH` 中。
- 如果日志里出现 `failed to fetch codex rate limits` 或 `chatgpt.com/backend-api/wham/usage`，通常是菜单栏 App 没有继承终端代理环境，请在配置文件里设置 `proxyURL`。
- 如果显示“超时”，可能是 Codex CLI 本身响应较慢，稍等后可以从菜单里手动刷新配置。
- 不要把 `~/.codex/`、`~/.codex/auth.json` 或 `~/.codex-menubar/rpc.log` 上传到公开仓库。

## Build

Run from the repository root:

```bash
swift run
```

Build a `.app` bundle:

```bash
bash scripts/build-app.sh
open .build/CodexQuota.app
```

To install locally:

```bash
cp -R .build/CodexQuota.app /Applications/CodexQuota.app
open /Applications/CodexQuota.app
```

## Configuration

Optional config path:

```text
~/.codex-menubar/config.json
```

Example:

```json
{
  "source": "codexRPC",
  "refreshIntervalSeconds": 30
}
```

`proxyURL` is optional. Set it when the macOS menu bar app cannot reach ChatGPT through the network environment inherited by GUI apps:

```json
{
  "source": "codexRPC",
  "refreshIntervalSeconds": 30,
  "proxyURL": "http://127.0.0.1:7890"
}
```

If the config file does not exist, the app creates a default one.

## Privacy

CodexQuota does not store ChatGPT credentials. It starts your local `codex app-server` process and asks it for `account/rateLimits/read`.

Do not commit or share:

- `~/.codex/`
- `~/.codex/auth.json`
- `~/.codex-menubar/`
- `~/.codex-menubar/rpc.log`
- screenshots that show your account email

The Codex CLI RPC surface may change, so this app should be treated as a small personal utility rather than a guaranteed stable integration.
