#!/bin/bash
# setup-languages.sh - Idempotent language runtime installer for vmclaude
#
# Designed to run interactively via: limactl shell claude-dev -- bash scripts/setup-languages.sh
# Each step uses a sentinel file in ~/.vmclaude/ so it can be re-run safely.
# Completed steps are skipped; failed steps are retried on next run.

set -euo pipefail

SENTINEL_DIR="$HOME/.vmclaude"
mkdir -p "$SENTINEL_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

step_done() {
    [ -f "$SENTINEL_DIR/$1.done" ]
}

mark_done() {
    touch "$SENTINEL_DIR/$1.done"
}

info()  { echo -e "${BLUE}==>${NC} $*"; }
ok()    { echo -e "${GREEN}  ✓${NC} $*"; }
skip()  { echo -e "${YELLOW}  ⏭${NC} $* (already installed)"; }
fail()  { echo -e "${RED}  ✗${NC} $*"; }

# ---------------------------------------------------------------------------
# Persistent cache helpers
# ---------------------------------------------------------------------------
CACHE_DIR="$HOME/.vmclaude-cache"
cache_available() { [ -d "$CACHE_DIR/runtimes" ]; }

# ---------------------------------------------------------------------------
# Python (system) + Poetry
# ---------------------------------------------------------------------------
install_python() {
    if step_done python; then skip "Python + Poetry"; return 0; fi
    info "Installing Poetry (using system Python)..."
    pipx install poetry
    pipx ensurepath
    mark_done python
    ok "Python $(python --version 2>&1), Poetry"
}

# ---------------------------------------------------------------------------
# nvm
# ---------------------------------------------------------------------------
install_nvm() {
    if step_done nvm; then skip "nvm"; return 0; fi
    info "Installing nvm..."
    if [ -d "$HOME/.nvm" ]; then
        # Already exists — pull latest install script to update
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    else
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    fi
    mark_done nvm
    ok "nvm"
}

# ---------------------------------------------------------------------------
# Node.js LTS
# ---------------------------------------------------------------------------
install_node() {
    if step_done node; then skip "Node.js LTS"; return 0; fi
    info "Installing Node.js LTS..."
    export NVM_DIR="$HOME/.nvm"
    # nvm uses uninitialized variables internally — disable nounset around it
    set +u
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm install --lts
    nvm alias default lts/*
    set -u
    mark_done node
    ok "Node $(node --version 2>&1)"
}

# ---------------------------------------------------------------------------
# pnpm
# ---------------------------------------------------------------------------
install_pnpm() {
    if step_done pnpm; then skip "pnpm"; return 0; fi
    info "Installing pnpm..."
    export NVM_DIR="$HOME/.nvm"
    set +u
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    set -u
    npm install -g pnpm
    mark_done pnpm
    ok "pnpm $(pnpm --version 2>&1)"
}

# ---------------------------------------------------------------------------
# Rust
# ---------------------------------------------------------------------------
install_rust() {
    if step_done rust; then skip "Rust"; return 0; fi
    info "Installing Rust..."
    if [ -f "$HOME/.cargo/env" ]; then
        # Already installed, just ensure stable + components
        # shellcheck source=/dev/null
        source "$HOME/.cargo/env"
    else
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        # shellcheck source=/dev/null
        source "$HOME/.cargo/env"
    fi
    rustup default stable
    rustup component add rustfmt clippy
    mark_done rust
    ok "Rust $(rustc --version 2>&1)"
}

# ---------------------------------------------------------------------------
# rbenv
# ---------------------------------------------------------------------------
install_rbenv() {
    if step_done rbenv; then skip "rbenv"; return 0; fi
    info "Installing rbenv..."
    if [ -d "$HOME/.rbenv" ]; then
        cd "$HOME/.rbenv" && git pull --ff-only && cd ~
    else
        git clone https://github.com/rbenv/rbenv.git "$HOME/.rbenv"
    fi
    if [ ! -d "$HOME/.rbenv/plugins/ruby-build" ]; then
        git clone https://github.com/rbenv/ruby-build.git "$HOME/.rbenv/plugins/ruby-build"
    else
        cd "$HOME/.rbenv/plugins/ruby-build" && git pull --ff-only && cd ~
    fi
    mark_done rbenv
    ok "rbenv"
}

# ---------------------------------------------------------------------------
# Ruby 3.3
# ---------------------------------------------------------------------------
install_ruby() {
    if step_done ruby; then skip "Ruby 3.3"; return 0; fi
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(rbenv init -)"

    local ruby_ver="3.3.0"
    local cache_tar="$CACHE_DIR/runtimes/ruby-${ruby_ver}-$(uname -m).tar.gz"

    if cache_available && [ -f "$cache_tar" ]; then
        info "Restoring Ruby $ruby_ver from cache..."
        mkdir -p "$HOME/.rbenv/versions"
        tar -xzf "$cache_tar" -C "$HOME/.rbenv/versions/"
        rbenv global "$ruby_ver"
    else
        info "Installing Ruby 3.3 (this takes a few minutes)..."
        rbenv install -s "$ruby_ver"
        rbenv global "$ruby_ver"

        # Cache the compiled version for next time
        if cache_available; then
            info "Caching compiled Ruby $ruby_ver..."
            tar -czf "$cache_tar" -C "$HOME/.rbenv/versions" "$ruby_ver"
        fi
    fi

    gem install bundler
    mark_done ruby
    ok "Ruby $(ruby --version 2>&1)"
}

# ---------------------------------------------------------------------------
# Claude Code
# ---------------------------------------------------------------------------
install_claude_code() {
    if step_done claude-code; then skip "Claude Code"; return 0; fi
    info "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
    mark_done claude-code
    ok "Claude Code"
}

# ===========================================================================
# Main
# ===========================================================================
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  vmclaude — Language Runtime Setup           ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""

install_python
install_nvm
install_node
install_pnpm
install_rust
install_rbenv
install_ruby
install_claude_code

# Final marker
touch "$SENTINEL_DIR/setup-complete"

echo ""
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo ""
echo "Installed runtimes:"

# Source everything to show versions
export NVM_DIR="$HOME/.nvm"
set +u
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
set -u

[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

export PATH="$HOME/.rbenv/bin:$PATH"
command -v rbenv >/dev/null && eval "$(rbenv init -)"

echo "  Python:     $(python --version 2>&1 || echo 'not found')"
echo "  Node.js:    $(node --version 2>&1 || echo 'not found')"
echo "  pnpm:       $(pnpm --version 2>&1 || echo 'not found')"
echo "  Rust:       $(rustc --version 2>&1 || echo 'not found')"
echo "  Go:         $(/usr/local/go/bin/go version 2>&1 || echo 'not found')"
echo "  Ruby:       $(ruby --version 2>&1 || echo 'not found')"
echo "  Claude:     $(claude --version 2>&1 || echo 'not found')"
echo ""
echo "Next steps:"
echo "  1. Run: claude auth"
echo "  2. Run: claude-dev   (dangerous mode)"
echo ""
