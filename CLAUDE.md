# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository hosts a single provisioning script that sets up an Ubuntu Server VM (22.04/24.04 LTS) with Claude Code, gstack, and all supporting tooling. Target use case: headless cloud VMs where browser-based OAuth is unavailable.

## Development commands

```bash
# Lint the script (shellcheck)
shellcheck setup.sh

# Dry-run syntax check (does not execute commands)
bash -n setup.sh

# Run the script on a target VM
chmod +x setup.sh && ./setup.sh
```

## Architecture

`setup.sh` runs 12 sequential steps, each idempotent (skips if already done):

1. **System packages** — apt-get update + install base tools (curl, git, ripgrep, python3, tmux, etc.)
2. **Locale** — en_US.UTF-8
3. **Git globals** — prompts for user.name/email if unset; sets core.editor, defaultBranch
4. **SSH key** — generates ed25519 key for GitHub; adds ssh-agent auto-start to `.bashrc`
5. **Node.js via nvm** — LTS install with nvm (avoiding global npm permission issues)
6. **Bun** — required by gstack build tooling
7. **Claude Code** — native installer (no Node.js dependency for the CLI itself)
8. **gstack** — clones to `~/.claude/skills/gstack` from garrytan/gstack; runs `./setup`
9. **Chromium + headless deps** — for gstack `/browse` and `/qa` skills on headless servers
10. **Anthropic API key** — prompts for `ANTHROPIC_API_KEY` and persists to `~/.bashrc` (headless auth alternative)
11. **tmux** — opinionated config (prefix C-a, mouse support, 256-color)
12. **Verification** — checks every tool was installed; shows next steps

Shell safety: `set -euo pipefail`. Root guard (exits if run as root). All destructive steps check for existing state before acting.

## Permissions

Project-level `.claude/settings.local.json` allows all `git *` commands without prompting. The file lives in `.claude/`, which is gitignored by default.
