#!/bin/bash
# full-setup.sh - Complete VM setup for Claude Code development
#
# Usage (for non-Lima VMs like UTM):
#   1. Create Ubuntu 24.04 VM
#   2. Copy this script to the VM
#   3. Run: chmod +x full-setup.sh && ./full-setup.sh
#
# This is the standalone equivalent of cloud-init + setup-languages.sh.
# Idempotent: safe to re-run on failure or after reboot.

set -euo pipefail

# Get the actual username (works whether run with sudo or not)
if [ -n "${SUDO_USER:-}" ]; then
    ACTUAL_USER="$SUDO_USER"
    ACTUAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    ACTUAL_USER="$(whoami)"
    ACTUAL_HOME="$HOME"
fi

echo "=============================================="
echo "  Claude Code Development VM Setup"
echo "=============================================="
echo "User: $ACTUAL_USER"
echo "Home: $ACTUAL_HOME"
echo ""

# Check if running as root for the base tools section
if [ "$(id -u)" -ne 0 ]; then
    echo "This script needs sudo for system packages."
    echo "Re-running with sudo..."
    exec sudo -E bash "$0" "$@"
fi

# =============================================================================
# PART 1: Base Tools (runs as root)
# =============================================================================
SYSTEM_SENTINEL="/var/lib/vmclaude-system-provisioned"

if [ -f "$SYSTEM_SENTINEL" ]; then
    echo "=== [1/4] System packages already installed, skipping ==="
else
    echo ""
    echo "=== [1/4] Installing Base Developer Tools ==="

    export DEBIAN_FRONTEND=noninteractive
    apt-get update

    apt-get install -y \
        build-essential \
        gcc \
        g++ \
        make \
        cmake \
        autoconf \
        automake \
        libtool \
        pkg-config \
        git \
        curl \
        wget \
        jq \
        ripgrep \
        fd-find \
        tree \
        htop \
        tmux \
        vim \
        unzip \
        zip \
        ca-certificates \
        gnupg \
        lsb-release \
        software-properties-common \
        apt-transport-https

    # Create symlink for fd
    ln -sf /usr/bin/fdfind /usr/local/bin/fd

    echo ""
    echo "=== [2/4] Installing Docker ==="

    # Add Docker's official GPG key (--batch --yes prevents re-run failures)
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Add user to docker group
    usermod -aG docker "$ACTUAL_USER"

    systemctl enable docker
    systemctl start docker

    echo ""
    echo "=== Installing Podman ==="

    apt-get install -y podman podman-compose

    # Configure Podman registries
    mkdir -p /etc/containers
    cat > /etc/containers/registries.conf << 'EOF'
[registries.search]
registries = ['docker.io', 'quay.io', 'ghcr.io']
EOF

    echo "=== Installing Python ==="

    apt-get install -y python3-pip python3-venv python-is-python3 pipx

    echo "=== Installing Language Build Dependencies ==="

    apt-get install -y \
        libssl-dev \
        zlib1g-dev \
        libbz2-dev \
        libreadline-dev \
        libsqlite3-dev \
        libncursesw5-dev \
        xz-utils \
        tk-dev \
        libxml2-dev \
        libxmlsec1-dev \
        libffi-dev \
        liblzma-dev \
        libyaml-dev \
        libncurses5-dev \
        libgdbm-dev

    echo "=== Installing Go ==="

    GO_VERSION="1.22.0"
    ARCH=$(dpkg --print-architecture)
    wget -q "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" -O /tmp/go.tar.gz
    rm -rf /usr/local/go
    tar -C /usr/local -xzf /tmp/go.tar.gz
    rm /tmp/go.tar.gz

    touch "$SYSTEM_SENTINEL"
fi

# =============================================================================
# PART 2: Shell Configuration (idempotent with marker)
# =============================================================================
echo ""
echo "=== Configuring shell environment ==="

sudo -u "$ACTUAL_USER" bash << SHELLCONFIG
MARKER="# --- vmclaude-env-begin ---"
if ! grep -qF "\$MARKER" "$ACTUAL_HOME/.bashrc" 2>/dev/null; then
    cat >> "$ACTUAL_HOME/.bashrc" << 'EOF'

# --- vmclaude-env-begin ---
# Claude Code Development Environment (managed by vmclaude)

# Base tools
export PATH="\$HOME/.local/bin:\$PATH"
alias fd='fdfind'
alias ll='ls -alF'
alias dc='docker compose'
alias pc='podman-compose'

# nvm (guarded)
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh"
[ -s "\$NVM_DIR/bash_completion" ] && . "\$NVM_DIR/bash_completion"

# Rust (guarded)
[ -f "\$HOME/.cargo/env" ] && . "\$HOME/.cargo/env"

# Go
export PATH=\$PATH:/usr/local/go/bin
export GOPATH=\$HOME/go
export PATH=\$PATH:\$GOPATH/bin

# rbenv (guarded)
[[ -d \$HOME/.rbenv/bin ]] && export PATH="\$HOME/.rbenv/bin:\$PATH"
command -v rbenv >/dev/null && eval "\$(rbenv init -)"

# Claude Code
alias claude-unsafe='claude --dangerously-skip-permissions'
claude-dev() { claude --dangerously-skip-permissions "\$@"; }
# --- vmclaude-env-end ---
EOF
    echo "  .bashrc configured"
else
    echo "  .bashrc already configured, skipping"
fi
SHELLCONFIG

# Create directories
sudo -u "$ACTUAL_USER" mkdir -p "$ACTUAL_HOME/projects"
sudo -u "$ACTUAL_USER" mkdir -p "$ACTUAL_HOME/go"/{bin,src,pkg}
sudo -u "$ACTUAL_USER" mkdir -p "$ACTUAL_HOME/.vmclaude"

# =============================================================================
# PART 3: Language Environments (runs as user, with sentinel files)
# =============================================================================
echo ""
echo "=== [3/4] Installing Language Environments ==="

sudo -u "$ACTUAL_USER" bash << USERSCRIPT
set -euo pipefail
cd "$ACTUAL_HOME"

SENTINEL_DIR="$ACTUAL_HOME/.vmclaude"
CACHE_DIR="\$HOME/.vmclaude-cache"
cache_available() { [ -d "\$CACHE_DIR/runtimes" ]; }

step_done() { [ -f "\$SENTINEL_DIR/\$1.done" ]; }
mark_done() { touch "\$SENTINEL_DIR/\$1.done"; }

# --- Python (system) + Poetry ---
if step_done python; then
    echo "  Python + Poetry: already installed"
else
    echo "Installing Poetry (using system Python)..."
    pipx install poetry
    pipx ensurepath
    mark_done python
fi

# --- nvm ---
if step_done nvm; then
    echo "  nvm: already installed"
else
    echo "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    mark_done nvm
fi

export NVM_DIR="\$HOME/.nvm"
# nvm uses uninitialized variables internally — disable nounset around it
set +u
[ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh"

# --- Node ---
if step_done node; then
    echo "  Node.js LTS: already installed"
else
    echo "Installing Node.js LTS..."
    nvm install --lts
    nvm alias default lts/*
    mark_done node
fi
set -u

# --- pnpm ---
if step_done pnpm; then
    echo "  pnpm: already installed"
else
    echo "Installing pnpm..."
    npm install -g pnpm
    mark_done pnpm
fi

# --- Rust ---
if step_done rust; then
    echo "  Rust: already installed"
else
    echo "Installing Rust..."
    if [ -f "\$HOME/.cargo/env" ]; then
        source "\$HOME/.cargo/env"
    else
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "\$HOME/.cargo/env"
    fi
    rustup default stable
    rustup component add rustfmt clippy
    mark_done rust
fi

# --- rbenv ---
if step_done rbenv; then
    echo "  rbenv: already installed"
else
    echo "Installing rbenv..."
    if [ -d "\$HOME/.rbenv" ]; then
        cd "\$HOME/.rbenv" && git pull --ff-only && cd ~
    else
        git clone https://github.com/rbenv/rbenv.git "\$HOME/.rbenv"
    fi
    if [ ! -d "\$HOME/.rbenv/plugins/ruby-build" ]; then
        git clone https://github.com/rbenv/ruby-build.git "\$HOME/.rbenv/plugins/ruby-build"
    fi
    mark_done rbenv
fi

export PATH="\$HOME/.rbenv/bin:\$PATH"
eval "\$(rbenv init -)"

# --- Ruby ---
if step_done ruby; then
    echo "  Ruby 3.3: already installed"
else
    ruby_ver="3.3.0"
    cache_tar="\$CACHE_DIR/runtimes/ruby-\${ruby_ver}-\$(uname -m).tar.gz"

    if cache_available && [ -f "\$cache_tar" ]; then
        echo "Restoring Ruby \$ruby_ver from cache..."
        mkdir -p "\$HOME/.rbenv/versions"
        tar -xzf "\$cache_tar" -C "\$HOME/.rbenv/versions/"
        rbenv global "\$ruby_ver"
    else
        echo "Installing Ruby 3.3..."
        rbenv install -s "\$ruby_ver"
        rbenv global "\$ruby_ver"
        if cache_available; then
            echo "Caching compiled Ruby \$ruby_ver..."
            tar -czf "\$cache_tar" -C "\$HOME/.rbenv/versions" "\$ruby_ver"
        fi
    fi
    gem install bundler
    mark_done ruby
fi

USERSCRIPT

# =============================================================================
# PART 4: Claude Code Setup
# =============================================================================
echo ""
echo "=== [4/4] Installing Claude Code ==="

sudo -u "$ACTUAL_USER" bash << CLAUDESCRIPT
set -euo pipefail

SENTINEL_DIR="$ACTUAL_HOME/.vmclaude"

# Source nvm to get npm (nvm needs nounset disabled)
export NVM_DIR="\$HOME/.nvm"
set +u
[ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh"
set -u

if [ -f "\$SENTINEL_DIR/claude-code.done" ]; then
    echo "  Claude Code: already installed"
else
    echo "Installing Claude Code CLI..."
    npm install -g @anthropic-ai/claude-code
    touch "\$SENTINEL_DIR/claude-code.done"
fi

echo "Configuring Claude permissions..."
mkdir -p "\$HOME/.claude"
cat > "\$HOME/.claude/settings.json" << 'EOF'
{
  "permissions": {
    "allow": [
      "Bash(*)",
      "Read(*)",
      "Write(*)",
      "Edit(*)",
      "Glob(*)",
      "Grep(*)",
      "WebFetch(*)",
      "WebSearch(*)",
      "NotebookEdit(*)",
      "Task(*)"
    ],
    "deny": []
  }
}
EOF

echo "Creating CLAUDE.md..."
cat > "\$HOME/CLAUDE.md" << 'CLAUDEMD'
# Development Environment Rules

## Isolation Requirements (MANDATORY)

### Python
- **Always use poetry**: \`poetry init\` then \`poetry add <package>\`
- Never \`pip install\` directly — use \`poetry add\` instead

### Node.js
- Use project-local \`node_modules\`
- Prefer \`pnpm\` over \`npm\`

### Go
- Use Go modules: \`go mod init <module-name>\`

### Rust
- Use Cargo: \`cargo init\` or \`cargo new\`

### Ruby
- Use Bundler: \`bundle init\`

## Container-First Development
- Use \`docker compose\` or \`podman-compose\` for multi-service setups
- Build artifacts inside containers for reproducibility

## What NOT To Do
- Never \`pip install\` directly — use \`poetry add\`
- Never \`npm install -g\` for project dependencies
- Never install language runtimes globally (use version managers)
CLAUDEMD

touch "\$SENTINEL_DIR/setup-complete"
CLAUDESCRIPT

# =============================================================================
# Complete
# =============================================================================
echo ""
echo "=============================================="
echo "  Setup Complete!"
echo "=============================================="
echo ""
echo "Installed:"
echo "  - Docker & Podman"
echo "  - Python 3.12 (system) + Poetry"
echo "  - nvm + Node.js LTS + pnpm"
echo "  - rustup + Rust stable"
echo "  - Go 1.22"
echo "  - rbenv + Ruby 3.3"
echo "  - Claude Code CLI"
echo ""
echo "IMPORTANT: Log out and back in (or run 'newgrp docker')"
echo "to use Docker without sudo."
echo ""
echo "Next steps:"
echo "  1. Log out and back in (or: source ~/.bashrc)"
echo "  2. Run: claude auth"
echo "  3. Run: claude-dev (dangerous mode)"
echo ""
echo "See ~/CLAUDE.md for development guidelines."
echo "=============================================="
