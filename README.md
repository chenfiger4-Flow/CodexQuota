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
