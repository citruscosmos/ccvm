# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository hosts a single provisioning script that sets up Ubuntu 22.04/24.04 LTS (Server or Desktop) with Claude Code, gstack, and all supporting tooling. Works on both — headless cloud VMs and local workstations.

## Development commands

```bash
# Lint the scripts (shellcheck)
shellcheck setup claude-model

# Dry-run syntax check (does not execute commands)
bash -n setup

# Run the script on a target VM
./setup
```

## Architecture

`setup` runs 12 sequential steps, each idempotent (skips if already done):

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

`claude-model` is a standalone launcher that sets DeepSeek env vars and `exec`s `claude`. Session-only — no persistent state. Run `claude-model deepseek` for DeepSeek v4, plain `claude` for Anthropic (default).

Shell safety: `set -euo pipefail`. Root guard (exits if run as root). All destructive steps check for existing state before acting.

## Permissions

Project-level `.claude/settings.local.json` allows all `git *` commands without prompting. The file lives in `.claude/`, which is gitignored by default.

## gstack

Use the `/browse` skill from gstack for all web browsing. Never use `mcp__claude-in-chrome__*` tools.

Available skills:
`/office-hours`, `/plan-ceo-review`, `/plan-eng-review`, `/plan-design-review`, `/design-consultation`, `/design-shotgun`, `/design-html`, `/review`, `/ship`, `/land-and-deploy`, `/canary`, `/benchmark`, `/browse`, `/connect-chrome`, `/qa`, `/qa-only`, `/design-review`, `/setup-browser-cookies`, `/setup-deploy`, `/setup-gbrain`, `/retro`, `/investigate`, `/document-release`, `/codex`, `/cso`, `/autoplan`, `/plan-devex-review`, `/devex-review`, `/careful`, `/freeze`, `/guard`, `/unfreeze`, `/gstack-upgrade`, `/learn`

## git commit

When creating commits, the `Co-Authored-By:` line must reflect the model actually in use, not a hardcoded default.

### Detecting the active model

1. Check the `ANTHROPIC_MODEL` env var:
   ```bash
   echo "${ANTHROPIC_MODEL:-<not set>}"
   ```
2. If set (e.g. `deepseek-v4-pro`), derive the Co-Authored-By from it:
   - `deepseek-v4-pro` → `Co-Authored-By: DeepSeek V4 Pro <noreply@deepseek.com>`
   - `deepseek-v4-flash` → `Co-Authored-By: DeepSeek V4 Flash <noreply@deepseek.com>`
3. If `ANTHROPIC_MODEL` is not set, the default Anthropic model is in use. Check the system prompt or model metadata for the exact model name (Opus 4.7, Sonnet 4.6, Haiku 4.5, etc.) and use:
   - `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>`
   - `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`
   - `Co-Authored-By: Claude Haiku 4.5 <noreply@anthropic.com>`

Never assume "Claude Opus 4.7" — always check which model is actually running.

## Web Search Fallback

WebSearch may fail with non-Anthropic models (400 error, incompatible API). When WebSearch is unavailable, use the following DuckDuckGo HTML fallback.

### Fallback procedure

1. URL-encode the search keywords and fetch DuckDuckGo's HTML search:
   ```
   https://html.duckduckgo.com/html/?q=<URL-encoded-keywords>
   ```
   Use WebFetch to retrieve this URL.

2. Extract relevant result URLs from the returned HTML (look for `result__a` / `result__url` classes in the markup).

3. WebFetch the individual pages that are most relevant to the query.

4. Cite sources as DuckDuckGo result links, not as direct WebSearch citations.

### Encoding example

```bash
# Build the search URL
query="your search keywords"
encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$query'))")
url="https://html.duckduckgo.com/html/?q=$encoded"
```
