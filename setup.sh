#!/usr/bin/env bash
# =============================================================================
# setup_claude_vm.sh
# Ubuntu Server VM Setup Script
# Target: Claude Code + gstack + related tools
# Tested on: Ubuntu 22.04 LTS / 24.04 LTS
#
# Usage:
#   chmod +x setup_claude_vm.sh
#   ./setup_claude_vm.sh
#   ./setup_claude_vm.sh --skip chromium --skip tmux
#   SKIP_APIKEY=1 ./setup_claude_vm.sh
# =============================================================================

set -euo pipefail

# ─────────────────────────────────────────────
# CLI flag parsing
# ─────────────────────────────────────────────
# Internal variables for --skip (CLI takes priority over env vars)
_CLI_SKIP_SSH=0
_CLI_SKIP_CHROMIUM=0
_CLI_SKIP_APIKEY=0
_CLI_SKIP_TMUX=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      echo "Usage: ./setup.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --help              Show this message"
      echo "  --skip <step>       Skip an optional step (can repeat)."
      echo "                      Skippable: ssh, chromium, apikey, tmux"
      echo "                      Core steps cannot be skipped."
      exit 0
      ;;
    --skip)
      case "${2:-}" in
        ssh)      _CLI_SKIP_SSH=1 ;;
        chromium) _CLI_SKIP_CHROMIUM=1 ;;
        apikey)   _CLI_SKIP_APIKEY=1 ;;
        tmux)     _CLI_SKIP_TMUX=1 ;;
        *)
          echo "Invalid --skip step: '${2:-}'. Valid steps: ssh, chromium, apikey, tmux"
          exit 1
          ;;
      esac
      shift 2
      ;;
    *)
      echo "Unknown option: $1. Use --help for usage."
      exit 1
      ;;
  esac
done

# Merge CLI flags and env vars: --skip takes precedence over env vars.
# Capture env vars before overwriting them with CLI values.
_ENV_SKIP_SSH="${SKIP_SSH:-0}"
_ENV_SKIP_CHROMIUM="${SKIP_CHROMIUM:-0}"
_ENV_SKIP_APIKEY="${SKIP_APIKEY:-0}"
_ENV_SKIP_TMUX="${SKIP_TMUX:-0}"

SKIP_SSH=$_CLI_SKIP_SSH
SKIP_CHROMIUM=$_CLI_SKIP_CHROMIUM
SKIP_APIKEY=$_CLI_SKIP_APIKEY
SKIP_TMUX=$_CLI_SKIP_TMUX

# For steps where --skip was NOT passed, check env var
if [[ "$_CLI_SKIP_SSH" -eq 0 ]]      && [[ "$_ENV_SKIP_SSH"      == "1" ]]; then SKIP_SSH=1; fi
if [[ "$_CLI_SKIP_CHROMIUM" -eq 0 ]] && [[ "$_ENV_SKIP_CHROMIUM" == "1" ]]; then SKIP_CHROMIUM=1; fi
if [[ "$_CLI_SKIP_APIKEY" -eq 0 ]]   && [[ "$_ENV_SKIP_APIKEY"   == "1" ]]; then SKIP_APIKEY=1; fi
if [[ "$_CLI_SKIP_TMUX" -eq 0 ]]     && [[ "$_ENV_SKIP_TMUX"     == "1" ]]; then SKIP_TMUX=1; fi

# ─────────────────────────────────────────────
# Color output helpers
# ─────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CURRENT_STEP=0
TOTAL_STEPS=12
STEP_START_TIME=0
TOTAL_START_TIME=$(date +%s)

_step_header() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  STEP_START_TIME=$(date +%s)
}

info()    { echo -e "${BLUE}[INFO]${NC}  [$CURRENT_STEP/$TOTAL_STEPS] $*"; }
success() {
  local elapsed
  elapsed=$(($(date +%s) - STEP_START_TIME))
  echo -e "${GREEN}[OK]${NC}    [$CURRENT_STEP/$TOTAL_STEPS] $* (took ${elapsed}s)"
}
warn()    { echo -e "${YELLOW}[WARN]${NC}  [$CURRENT_STEP/$TOTAL_STEPS] $*"; }
error()   { echo -e "${RED}[ERROR]${NC} [$CURRENT_STEP/$TOTAL_STEPS] $*" >&2; exit 1; }

# ─────────────────────────────────────────────
# Root check
# ─────────────────────────────────────────────
if [[ "$EUID" -eq 0 ]]; then
  echo -e "${RED}[ERROR]${NC} Do not run this script as root. Please run as a regular user." >&2
  exit 1
fi

# ─────────────────────────────────────────────
# Disk space check
# ─────────────────────────────────────────────
check_disk() {
  local mount="$1"
  local label="$2"
  local avail
  avail=$(df --output=avail "$mount" 2>/dev/null | tail -1 | tr -d ' ')
  if [[ -z "$avail" ]]; then
    warn "Could not check disk space on $label ($mount)"
    return
  fi
  # avail is in 1K blocks
  local avail_gb=$((avail / 1024 / 1024))
  if [[ "$avail_gb" -lt 2 ]]; then
    echo -e "${RED}[ERROR]${NC} Less than 2GB free on $label ($mount). Cannot proceed." >&2
    exit 1
  elif [[ "$avail_gb" -lt 5 ]]; then
    echo -e "${YELLOW}[WARN]${NC}  Only ${avail_gb}GB free on $label ($mount). Install may fail."
  fi
}

echo ""
echo "============================================================"
echo "  Claude Code + gstack VM Setup"
echo "============================================================"
echo ""

check_disk "/"    "root"
check_disk "/tmp" "/tmp"

# ─────────────────────────────────────────────
# STEP 1: System update and base packages
# ─────────────────────────────────────────────
_step_header
info "Updating system packages..."
info "Running: sudo apt-get update -q"
sudo apt-get update -q
info "Running: sudo apt-get upgrade -y -q"
sudo apt-get upgrade -y -q

info "Installing base tools..."
info "Running: sudo apt-get install -y -q curl wget git unzip build-essential ..."
sudo apt-get install -y -q \
  curl \
  wget \
  git \
  unzip \
  build-essential \
  ca-certificates \
  gnupg \
  lsb-release \
  ripgrep \
  jq \
  htop \
  tree \
  vim \
  tmux \
  python3 \
  python3-pip \
  python3-venv \
  locales

success "Base packages installed"

# ─────────────────────────────────────────────
# STEP 2: Locale configuration
# ─────────────────────────────────────────────
_step_header
info "Configuring locale (en_US.UTF-8)..."
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

success "Locale configured"

# ─────────────────────────────────────────────
# STEP 3: Git global configuration
# ─────────────────────────────────────────────
_step_header
info "Configuring Git globals..."

if [[ -z "$(git config --global user.name 2>/dev/null)" ]]; then
  read -rp "  Enter your Git username: " GIT_USERNAME
  git config --global user.name "$GIT_USERNAME"
fi

if [[ -z "$(git config --global user.email 2>/dev/null)" ]]; then
  read -rp "  Enter your Git email address: " GIT_EMAIL
  git config --global user.email "$GIT_EMAIL"
fi

git config --global core.editor vim
git config --global init.defaultBranch main
git config --global pull.rebase false

success "Git configured"

# ─────────────────────────────────────────────
# STEP 4: SSH key generation (for GitHub)
# ─────────────────────────────────────────────
_step_header
if [[ "$SKIP_SSH" -eq 1 ]]; then
  warn "SSH key setup skipped (--skip ssh or SKIP_SSH=1)"
else
  info "Setting up SSH key..."

  SSH_KEY="$HOME/.ssh/id_ed25519"
  if [[ -f "$SSH_KEY" ]]; then
    warn "SSH key already exists, skipping: $SSH_KEY"
  else
    GIT_EMAIL_FOR_SSH=$(git config --global user.email 2>/dev/null || echo "user@example.com")
    ssh-keygen -t ed25519 -C "$GIT_EMAIL_FOR_SSH" -f "$SSH_KEY" -N ""
    success "SSH key generated: $SSH_KEY"
    echo ""
    echo "  ── Public key to register on GitHub ───────────────────"
    cat "${SSH_KEY}.pub"
    echo "  ────────────────────────────────────────────────────────"
    echo "  Add the above key at: GitHub > Settings > SSH keys"
    echo ""
  fi

  # Add SSH agent auto-start to .bashrc (only if not already present)
  BASHRC="$HOME/.bashrc"
  if [[ -f "$BASHRC" ]] && grep -q "ssh-agent" "$BASHRC" 2>/dev/null; then
    info "SSH agent already configured in .bashrc"
  else
    cat >> "$BASHRC" << 'EOF'

# SSH agent auto-start
if [ -z "$SSH_AUTH_SOCK" ]; then
  eval "$(ssh-agent -s)" > /dev/null
  ssh-add ~/.ssh/id_ed25519 2>/dev/null || true
fi
EOF
    info "SSH agent auto-start added to .bashrc"
  fi

  success "SSH key setup complete"
fi

# ─────────────────────────────────────────────
# STEP 5: Node.js via nvm
# ─────────────────────────────────────────────
# Required by gstack build tools (Bun) and some scripts.
# Using nvm avoids permission issues with global npm installs.
_step_header
info "Installing nvm + Node.js LTS..."

NVM_DIR="$HOME/.nvm"
if [[ -d "$NVM_DIR" ]]; then
  warn "nvm already installed, skipping"
else
  info "Running: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash"
  if curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash; then
    success "nvm installed"
  else
    warn "nvm install failed (curl error). Node.js will not be available."
  fi
fi

# Activate nvm in the current session
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  source "$NVM_DIR/nvm.sh"
else
  warn "nvm.sh not found — nvm install may have failed. Skipping Node.js configuration."
fi

if ! node --version &>/dev/null; then
  if command -v nvm &>/dev/null || [[ -s "$NVM_DIR/nvm.sh" ]]; then
    nvm install --lts
    nvm use --lts
    nvm alias default node
    success "Node.js LTS installed: $(node --version)"
  fi
else
  info "Node.js already installed: $(node --version)"
fi

# ─────────────────────────────────────────────
# STEP 6: Bun (required for gstack build)
# ─────────────────────────────────────────────
_step_header
info "Installing Bun..."

if command -v bun &>/dev/null; then
  warn "Bun already installed: $(bun --version)"
else
  info "Running: curl -fsSL https://bun.sh/install | bash"
  curl -fsSL https://bun.sh/install | bash
  export PATH="$HOME/.bun/bin:$PATH"
  if command -v bun &>/dev/null; then
    success "Bun installed: $(bun --version)"
  else
    warn "Bun install completed but 'bun' not on PATH yet. Shell reload may be needed."
  fi
fi

if [[ -f "$BASHRC" ]]; then
  if ! grep -q ".bun/bin" "$BASHRC" 2>/dev/null; then
    echo 'export PATH="$HOME/.bun/bin:$PATH"' >> "$BASHRC"
  fi
fi

# ─────────────────────────────────────────────
# STEP 7: Claude Code (native installer)
# ─────────────────────────────────────────────
# The native installer is the recommended method — no Node.js dependency required.
_step_header
info "Installing Claude Code (native installer)..."

if command -v claude &>/dev/null; then
  warn "Claude Code already installed: $(claude --version 2>/dev/null || echo 'unknown')"
else
  info "Running: curl -fsSL https://claude.ai/install.sh | sh"
  curl -fsSL https://claude.ai/install.sh | sh
  export PATH="$HOME/.claude/bin:$PATH"
  if command -v claude &>/dev/null; then
    success "Claude Code installed: $(claude --version 2>/dev/null)"
  else
    warn "Claude Code install completed but 'claude' not on PATH. Shell reload may be needed."
  fi
fi

if [[ -f "$BASHRC" ]]; then
  if ! grep -q ".claude/bin" "$BASHRC" 2>/dev/null; then
    echo 'export PATH="$HOME/.claude/bin:$PATH"' >> "$BASHRC"
  fi
fi

# ─────────────────────────────────────────────
# STEP 8: gstack
# ─────────────────────────────────────────────
_step_header
info "Installing gstack..."

GSTACK_DIR="$HOME/.claude/skills/gstack"
if [[ -d "$GSTACK_DIR" ]]; then
  warn "gstack already installed. Updating to latest..."
  cd "$GSTACK_DIR"
  info "Running: git fetch origin && git reset --hard origin/main"
  git fetch origin
  git reset --hard origin/main
  bun run build 2>/dev/null || warn "bun run build skipped (normal on subsequent runs)"
else
  info "Running: git clone https://github.com/garrytan/gstack.git $GSTACK_DIR"
  git clone https://github.com/garrytan/gstack.git "$GSTACK_DIR"
  cd "$GSTACK_DIR"
  ./setup
fi

success "gstack installed"
cd "$HOME"

# ─────────────────────────────────────────────
# STEP 9: Chromium + headless dependencies
# ─────────────────────────────────────────────
# Required for gstack /browse and /qa skills on a headless server.
_step_header
if [[ "$SKIP_CHROMIUM" -eq 1 ]]; then
  warn "Chromium setup skipped (--skip chromium or SKIP_CHROMIUM=1)"
else
  info "Installing Chromium (for gstack /browse and /qa skills)..."

  if command -v chromium-browser &>/dev/null || command -v chromium &>/dev/null; then
    warn "Chromium already installed"
  else
    sudo apt-get install -y -q chromium-browser 2>/dev/null || \
    sudo apt-get install -y -q chromium 2>/dev/null || \
    warn "Chromium installation failed. Please install manually if needed."
  fi

  # System libraries required to run Chromium in a headless environment
  info "Installing headless Chromium dependencies..."
  HEADLESS_LIBS_COUNT=0
  HEADLESS_LIBS_TOTAL=10

  install_lib() {
    if sudo apt-get install -y -q "$1" 2>/dev/null; then
      HEADLESS_LIBS_COUNT=$((HEADLESS_LIBS_COUNT + 1))
    fi
  }

  install_lib libnss3
  install_lib libatk-bridge2.0-0
  install_lib libdrm2
  install_lib libxcomposite1
  install_lib libxdamage1
  install_lib libxfixes3
  install_lib libxrandr2
  install_lib libgbm1
  install_lib libxkbcommon0
  install_lib libasound2

  if [[ "$HEADLESS_LIBS_COUNT" -eq "$HEADLESS_LIBS_TOTAL" ]]; then
    info "Headless libs: $HEADLESS_LIBS_COUNT/$HEADLESS_LIBS_TOTAL installed"
  else
    warn "Headless libs: $HEADLESS_LIBS_COUNT/$HEADLESS_LIBS_TOTAL installed — some libraries may be missing"
  fi

  success "Chromium and headless dependencies installed"
fi

# ─────────────────────────────────────────────
# STEP 10: Anthropic API key configuration
# ─────────────────────────────────────────────
# On a headless server, browser-based OAuth login is unavailable.
# Setting ANTHROPIC_API_KEY enables automatic authentication.
# Note: storing the key in .bashrc is a pragmatic tradeoff for headless VMs.
_step_header
if [[ "$SKIP_APIKEY" -eq 1 ]]; then
  warn "API key configuration skipped (--skip apikey or SKIP_APIKEY=1)"
else
  info "Configuring Anthropic API key..."

  if [[ -f "$BASHRC" ]] && grep -q "ANTHROPIC_API_KEY" "$BASHRC" 2>/dev/null; then
    warn "ANTHROPIC_API_KEY is already configured in .bashrc"
  else
    echo ""
    echo "  Enter your Anthropic API key (input will not be displayed)."
    echo "  Get your key at: https://console.anthropic.com"
    echo "  Press Enter to skip and configure later."
    read -rsp "  ANTHROPIC_API_KEY: " ANTHROPIC_API_KEY_INPUT
    echo ""

    if [[ -n "$ANTHROPIC_API_KEY_INPUT" ]]; then
      echo "export ANTHROPIC_API_KEY=\"$ANTHROPIC_API_KEY_INPUT\"" >> "$BASHRC"
      export ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY_INPUT"
      success "ANTHROPIC_API_KEY saved to .bashrc"
    else
      warn "Skipped API key configuration."
      warn "Add the following line to ~/.bashrc when ready:"
      warn '  export ANTHROPIC_API_KEY="sk-ant-..."'
    fi
  fi
fi

# ─────────────────────────────────────────────
# STEP 11: tmux configuration
# ─────────────────────────────────────────────
# Recommended for long-running Claude Code sessions on a headless server.
_step_header
if [[ "$SKIP_TMUX" -eq 1 ]]; then
  warn "tmux configuration skipped (--skip tmux or SKIP_TMUX=1)"
else
  info "Configuring tmux..."

  TMUX_CONF="$HOME/.tmux.conf"
  if [[ -f "$TMUX_CONF" ]]; then
    # Back up with timestamp to avoid collisions on re-run
    TMUX_BAK="${TMUX_CONF}.bak.$(date +%s)"
    cp "$TMUX_CONF" "$TMUX_BAK"
    warn "Existing tmux config backed up to $(basename "$TMUX_BAK")"
  fi

  cat > "$TMUX_CONF" << 'EOF'
# Change prefix key to Ctrl+a
set -g prefix C-a
unbind C-b
bind C-a send-prefix

# Start window and pane numbering from 1
set -g base-index 1
setw -g pane-base-index 1

# Enable mouse support
set -g mouse on

# Status bar
set -g status-right '%Y-%m-%d %H:%M'
set -g status-interval 1

# Scrollback history limit
set -g history-limit 50000

# 256-color support
set -g default-terminal "screen-256color"
EOF
  success "tmux config created: $TMUX_CONF"
fi

# ─────────────────────────────────────────────
# STEP 12: Verify installation
# ─────────────────────────────────────────────
_step_header
echo ""
echo "============================================================"
info "Verifying installation..."
echo "============================================================"

# Refresh PATH before checking
export NVM_DIR="$HOME/.nvm"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  source "$NVM_DIR/nvm.sh"
fi
export PATH="$HOME/.bun/bin:$HOME/.claude/bin:$PATH"

VERIFY_FAILS=()

verify_tool() {
  local label="$1"
  shift
  if "$@" &>/dev/null; then
    local ver
    ver=$("$@" 2>/dev/null | head -1 || echo "version unavailable")
    success "$label: $ver"
  else
    warn "$label: verification failed"
    VERIFY_FAILS+=("$label")
  fi
}

verify_tool "git"       git --version
verify_tool "Node.js"   node -e "console.log('ok')"
verify_tool "npm"       npm --version
verify_tool "Bun"       bun -e "console.log('ok')"
verify_tool "Claude Code" claude --version
verify_tool "ripgrep"   rg --version
verify_tool "Python3"   python3 -c "print('ok')"
verify_tool "tmux"      tmux -V

if [[ -d "$HOME/.claude/skills/gstack" ]]; then
  success "gstack: installed ($HOME/.claude/skills/gstack)"
else
  warn "gstack: not found"
  VERIFY_FAILS+=("gstack")
fi

if [[ ${#VERIFY_FAILS[@]} -gt 0 ]]; then
  echo ""
  warn "The following tools failed verification: ${VERIFY_FAILS[*]}"
  warn "You may need to reload your shell (source ~/.bashrc) and re-run verification manually."
fi

# ─────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────
TOTAL_ELAPSED=$(($(date +%s) - TOTAL_START_TIME))
echo ""
echo "============================================================"
echo -e "${GREEN}  Setup complete!${NC}  (total time: ${TOTAL_ELAPSED}s)"
echo "============================================================"
echo ""
echo "  Next steps:"
echo ""
echo "  1. Reload your shell to apply all settings:"
echo "       source ~/.bashrc"
echo "       # or open a new terminal session"
echo ""
echo "  2. Authenticate Claude Code:"
echo "       claude"
echo "       # On a headless server, browser login is unavailable."
echo "       # If ANTHROPIC_API_KEY is set, authentication is automatic."
echo ""
echo "  3. Run gstack initial setup inside Claude Code:"
echo "       claude  # then run one of:"
echo "       /gstack-setup"
echo "       /gbrain-onboarding"
echo ""
echo "  4. Verify environment health:"
echo "       claude doctor"
echo "       claude --version"
echo ""
if [[ -f "${HOME}/.ssh/id_ed25519.pub" ]]; then
  echo "  !! Don't forget to register your SSH public key on GitHub:"
  echo "       cat ~/.ssh/id_ed25519.pub"
  echo "       -> https://github.com/settings/keys"
  echo ""
fi
echo "============================================================"
