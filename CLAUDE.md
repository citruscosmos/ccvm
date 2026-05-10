# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository hosts a single provisioning script that sets up Ubuntu 22.04/24.04 LTS (Server or Desktop) with Claude Code, gstack, and all supporting tooling. Works on both — headless cloud VMs and local workstations.

## Development commands

```bash
# Lint the scripts (shellcheck)
shellcheck setup.sh scripts/claude-model

# Dry-run syntax check (does not execute commands)
bash -n setup.sh

# Run the script on a target VM
./setup.sh
```

## Architecture

`setup.sh` runs 12 sequential steps, each idempotent (skips if already done):

1. **System packages** — apt-get update + install base tools, headless Chromium libs
2. **Locale** — generates en_US.UTF-8 and ja_JP.UTF-8; prompts for default language
3. **Git globals** — prompts for user.name/email if unset; sets core.editor, defaultBranch
4. **SSH key** — generates ed25519 key for GitHub; adds ssh-agent auto-start to `.bashrc`
5. **Node.js via nvm** — LTS install with nvm (avoiding global npm permission issues)
6. **Bun** — required by gstack build tooling
7. **Claude Code** — native installer (no Node.js dependency for the CLI itself)
8. **gstack** — clones to `~/.claude/skills/gstack` from garrytan/gstack; runs `./setup`
9. **Chromium** — system browser for gstack `/browse` and `/qa` skills
10. **tmux** — opinionated config (prefix C-a, mouse support, 256-color)
11. **claude-model** — installs session-only DeepSeek v4 launcher to `~/.local/bin/claude-model`
12. **Verification** — checks every tool was installed; shows next steps

`scripts/claude-model` is a standalone launcher that sets DeepSeek env vars and `exec`s `claude`. Session-only — no persistent state. Run `claude-model deepseek` for DeepSeek v4, plain `claude` for Anthropic (default).

Shell safety: `set -euo pipefail`. Root guard (exits if run as root). All destructive steps check for existing state before acting.

## Permissions

Project-level `.claude/settings.local.json` allows all `git *` commands without prompting. The file lives in `.claude/`, which is gitignored by default.
