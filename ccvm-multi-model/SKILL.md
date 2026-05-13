---
name: ccvm-multi-model
version: 0.1.0
description: |
  Patches CLAUDE.md with model-aware commit guidance and WebSearch fallback
  for non-Anthropic models (DeepSeek, etc.). Ensures Co-Authored-By reflects
  the actual model in use and provides a DuckDuckGo HTML fallback when
  WebSearch is unavailable. Idempotent — safe to run multiple times.
triggers:
  - patch CLAUDE.md for multi-model
  - add model fallback to CLAUDE.md
  - setup multi-model support
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Grep
---

# /ccvm-multi-model — Multi-Model CLAUDE.md Patcher

Patches the repo's CLAUDE.md with guidance for using non-Anthropic models (DeepSeek, etc.).

## What it adds

1. **Model-aware `## git commit`** — replaces the one-line `## git commit` section with a step-by-step procedure to detect the active model (via `$ANTHROPIC_MODEL`) and write the correct `Co-Authored-By:` line. Never assumes "Claude Opus 4.7".

2. **`## Web Search Fallback`** — adds a DuckDuckGo HTML fallback procedure for when `WebSearch` fails with non-Anthropic models (400 error).

Both additions are idempotent — the skill detects existing sections and skips already-patched content.

## Preamble (run first)

```bash
# Verify we're in a git repo with a CLAUDE.md
if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "ERROR: Not in a git repository."
  exit 1
fi

REPO_TOP=$(git rev-parse --show-toplevel)
CLAUDE_MD="$REPO_TOP/CLAUDE.md"

if [[ ! -f "$CLAUDE_MD" ]]; then
  echo "ERROR: No CLAUDE.md found at $CLAUDE_MD"
  exit 1
fi

echo "REPO_TOP: $REPO_TOP"
echo "CLAUDE_MD: $CLAUDE_MD"
```

## Step 1: Check current state

Read `CLAUDE.md` and check what already exists:

```bash
echo "=== Checking current state ==="

# Check if the model-aware git commit section already exists
if grep -q "Detecting the active model" "$CLAUDE_MD"; then
  echo "GIT_COMMIT_PATCHED: true"
else
  echo "GIT_COMMIT_PATCHED: false"
fi

# Check if Web Search Fallback section already exists
if grep -q "^## Web Search Fallback" "$CLAUDE_MD"; then
  echo "WEB_SEARCH_PATCHED: true"
else
  echo "WEB_SEARCH_PATCHED: false"
fi
```

## Step 2: Apply patches

### 2a. Model-aware git commit

If `GIT_COMMIT_PATCHED` is `false`, replace the existing `## git commit` section.

The `old_string` to match is the short form:

```
## git commit
Please check the model which currently using and describe in "Co-Authored-By:".
```

Replace it with:

```
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
```

If the `## git commit` section does not exist at all, append the new section before the next `##` heading.

If `GIT_COMMIT_PATCHED` is already `true`, skip this step.

### 2b. Web Search Fallback

If `WEB_SEARCH_PATCHED` is `false`, append a new `## Web Search Fallback` section at the end of CLAUDE.md:

```
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
```

If `WEB_SEARCH_PATCHED` is already `true`, skip this step.

## Step 3: Verify

```bash
echo "=== Verification ==="

if grep -q "Detecting the active model" "$CLAUDE_MD"; then
  echo "PASS: git commit model detection"
else
  echo "FAIL: git commit model detection"
fi

if grep -q "^## Web Search Fallback" "$CLAUDE_MD"; then
  echo "PASS: Web Search Fallback"
else
  echo "FAIL: Web Search Fallback"
fi
```
