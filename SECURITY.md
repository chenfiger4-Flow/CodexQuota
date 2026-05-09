# Security

CodexQuota reads quota data by starting the local `codex app-server` process and calling the `account/rateLimits/read` JSON-RPC method.

The app does not require you to paste a ChatGPT password, access token, refresh token, or session cookie. Authentication is handled by your existing local Codex CLI installation.

## Do Not Commit

Never commit these files or directories:

- `~/.codex/`
- `~/.codex/auth.json`
- `~/.codex-menubar/`
- `~/.codex-menubar/config.json`
- `~/.codex-menubar/rpc.log`
- `.build/`
- screenshots or local reference images that show your account email

## Logs

The app writes a small local diagnostic log to `~/.codex-menubar/rpc.log`. It records request lifecycle events, but intentionally does not store raw stderr output from the Codex CLI child process.

When opening issues, do not paste logs unless you have reviewed them first.

## API Stability

This project uses the Codex CLI app-server RPC surface, which may be private or unstable. Future Codex CLI releases may change method names, response shapes, or authentication behavior.
