# ccvm

Single-command provisioning for Ubuntu 22.04/24.04 LTS (Server or Desktop) with Claude Code, gstack, and all supporting tooling.

## Quick start

```bash
git clone https://github.com/citruscosmos/ccvm.git
cd ccvm
./setup.sh
```

`source ~/.bashrc` when done.

## What it installs

| Tool | Purpose |
|------|---------|
| Claude Code | AI coding assistant (native installer) |
| gstack | Claude Code skill suite |
| Node.js (LTS) | Runtime (via nvm) |
| Bun | JavaScript runtime (gstack dependency) |
| Chromium | Headless browser (gstack `/browse`, `/qa`) |
| tmux | Terminal multiplexer (persistent sessions) |
| ripgrep, jq, htop, tree | CLI utilities |

## Options

```bash
./setup.sh --help                 # Show usage
./setup.sh --skip chromium        # Skip Chromium
./setup.sh --skip tmux            # Skip tmux config
SKIP_CHROMIUM=1 ./setup.sh        # Equivalent via env var
```

## Model backends

```bash
claude                  # Anthropic (default)
claude-model deepseek   # DeepSeek v4 (session-only)
```

`claude-model` prompts for your DeepSeek API key on first run (stored at `~/.claude/deepseek-key`).

## System locale

The script generates both `en_US.UTF-8` and `ja_JP.UTF-8` and prompts you to pick a default.
