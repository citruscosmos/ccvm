# ccvm

Single-command provisioning for Ubuntu 22.04/24.04 LTS (Server or Desktop) with Claude Code, gstack, and all supporting tooling.

## Quick start

```bash
git clone https://github.com/citruscosmos/ccvm.git
cd ccvm
./setup
```

`source ~/.bashrc` when done.

## What it installs

| Tool | Purpose |
|------|---------|
| Claude Code | AI coding assistant (native installer) |
| claude-model | Multi-provider model launcher (Python) |
| gstack | Claude Code skill suite |
| Node.js (LTS) | Runtime (via nvm) |
| Bun | JavaScript runtime (gstack dependency) |
| PyYAML | YAML config parser (claude-model dependency) |
| Chromium | Headless browser (gstack `/browse`, `/qa`) |
| tmux | Terminal multiplexer (persistent sessions) |
| ripgrep, jq, htop, tree | CLI utilities |

## Options

```bash
./setup --help                 # Show usage
./setup --skip chromium        # Skip Chromium
./setup --skip tmux            # Skip tmux config
SKIP_CHROMIUM=1 ./setup        # Equivalent via env var
```

## Model backends

`claude-model` switches your entire AI stack with one command. It supports multiple providers, per-role model mixing, and named profiles — all driven by a YAML config file you can version-control.

```bash
claude-model                     # Uses "default" profile
claude-model deepseek            # DeepSeek V4
claude-model kimi                # Kimi K2.6 (Moonshot AI)
claude-model glm                 # GLM-5.1 (Zhipu AI)
claude-model mixed-via-openrouter # Cross-provider via OpenRouter
claude                            # Anthropic (plain Claude Code)
```

### Managing profiles and keys

```bash
claude-model --list              # List available profiles
claude-model --validate          # Check config without launching
claude-model --init              # Write default config template
claude-model --add-key kimi      # Save API key for a provider
CLAUDE_MODEL_PROFILE=glm claude-model  # Env var override
```

API keys are stored per-provider at `~/.ccvm/keys/<provider>` (mode 600). The config lives at `~/.ccvm/model-profiles.yaml`.

### Supported providers

| Provider | Model | Base URL |
|----------|-------|----------|
| DeepSeek | deepseek-v4-pro, deepseek-v4-flash | `api.deepseek.com/anthropic` |
| Kimi K2.6 | kimi-k2.6, kimi-k2.6-flash | `platform.moonshot.ai` |
| GLM-5.1 | glm-5.1, glm-5.1-flash | `open.bigmodel.cn/api/anthropic` |
| OpenRouter | Any (unified gateway) | `openrouter.ai/api` |
| Anthropic | claude-opus-4-7, claude-sonnet-4-6, claude-haiku-4-5 | `api.anthropic.com` |

### Per-role model mixing

Each profile can assign different models to each Claude Code role (Opus, Sonnet, Haiku, Subagent). Example from `model-profiles.yaml`:

```yaml
profiles:
  deepseek:
    provider: deepseek
    effort: max
```

Missing roles fall back automatically: sonnet→opus, haiku→sonnet, subagent→haiku.

## Running multiple Claude Code sessions with tmux

tmux lets you run and manage multiple Claude Code instances in parallel — useful on headless servers or when juggling several tasks at once.

### Quick reference

```bash
# Start a new session named "cc"
tmux new-session -s cc
# Inside the session, launch Claude Code:
claude

# Detach from the session (keep it running):
#   Prefix + d   (Prefix is Ctrl+a)

# List running sessions:
tmux ls

# Reattach to a session:
tmux attach -t cc

# Create a new window in the current session:
#   Prefix + c

# Switch between windows:
#   Prefix + 1   (window 1)
#   Prefix + 2   (window 2)
#   Prefix + n   (next window)
#   Prefix + p   (previous window)

# Split the current pane:
#   Prefix + %   (vertical split)
#   Prefix + "   (horizontal split)

# Navigate between panes:
#   Prefix + arrow keys

# Kill the current pane/window:
#   exit   (or Ctrl+d)
```

### Workflow example

```bash
# Session 1: work on the ccvm repo
tmux new-session -s ccvm -d 'cd ~/ccvm && claude'
# Session 2: another project (Kimi K2.6)
tmux new-session -s myapp -d 'cd ~/myapp && claude-model kimi'

# Jump between them:
tmux attach -t ccvm       # work on ccvm
# Prefix + d               # detach
tmux attach -t myapp      # switch to myapp
```

### Over SSH

```bash
ssh your-server
tmux attach -t ccvm    # rejoin the session you left running
# Prefix + d             # detach without stopping Claude Code
```

If the server reboots, your sessions are lost. For persistent tmux setups, consider [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect).

Prefix key is **Ctrl+a** (configured by `setup`). The default tmux prefix (Ctrl+b) is unbound.

## System locale

The script generates both `en_US.UTF-8` and `ja_JP.UTF-8` and prompts you to pick a default.
