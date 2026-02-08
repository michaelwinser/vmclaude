#!/bin/bash
# full-setup.sh - Complete VM setup for Claude Code development
#
# Usage:
#   1. Create Ubuntu 24.04 VM in UTM (or any hypervisor)
#   2. Copy this script to the VM
#   3. Run: chmod +x full-setup.sh && ./full-setup.sh
#
# This script combines base-tools, language-envs, and claude-setup into one.

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

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
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

# =============================================================================
# PART 2: Language Environments (runs as user)
# =============================================================================
echo ""
echo "=== [3/4] Installing Language Environments ==="

# Install language build dependencies
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

# Create projects directory
sudo -u "$ACTUAL_USER" mkdir -p "$ACTUAL_HOME/projects"

# Run language installations as the actual user
sudo -u "$ACTUAL_USER" bash << USERSCRIPT
set -euo pipefail
cd "$ACTUAL_HOME"

echo "Installing pyenv..."
curl -fsSL https://pyenv.run | bash

# Set up pyenv for this script
export PYENV_ROOT="\$HOME/.pyenv"
export PATH="\$PYENV_ROOT/bin:\$PATH"
eval "\$(pyenv init -)"

echo "Installing Python 3.12..."
pyenv install 3.12
pyenv global 3.12

echo "Installing pipx..."
pip install --upgrade pip
pip install pipx
"\$HOME/.local/bin/pipx" ensurepath

echo "Installing nvm..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh"

echo "Installing Node.js LTS..."
nvm install --lts
nvm use --lts
nvm alias default lts/*

echo "Installing pnpm..."
npm install -g pnpm

echo "Installing Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "\$HOME/.cargo/env"
rustup default stable
rustup component add rustfmt clippy

echo "Installing Go..."
GO_VERSION="1.22.0"
wget -q "https://go.dev/dl/go\${GO_VERSION}.linux-\$(dpkg --print-architecture).tar.gz" -O /tmp/go.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf /tmp/go.tar.gz
rm /tmp/go.tar.gz
mkdir -p "\$HOME/go"/{bin,src,pkg}

echo "Installing rbenv..."
git clone https://github.com/rbenv/rbenv.git "\$HOME/.rbenv"
cd "\$HOME/.rbenv" && src/configure && make -C src
cd "\$HOME"
git clone https://github.com/rbenv/ruby-build.git "\$HOME/.rbenv/plugins/ruby-build"

export PATH="\$HOME/.rbenv/bin:\$PATH"
eval "\$(rbenv init -)"

echo "Installing Ruby 3.3..."
rbenv install 3.3.0
rbenv global 3.3.0
gem install bundler

USERSCRIPT

# =============================================================================
# PART 3: Shell Configuration
# =============================================================================
echo ""
echo "=== Configuring shell environment ==="

sudo -u "$ACTUAL_USER" bash << SHELLCONFIG
cat >> "$ACTUAL_HOME/.bashrc" << 'EOF'

# ============================================
# Claude Code Development Environment
# ============================================

# Base tools
export PATH="\$HOME/.local/bin:\$PATH"
alias fd='fdfind'
alias ll='ls -alF'
alias dc='docker compose'
alias pc='podman-compose'

# pyenv
export PYENV_ROOT="\$HOME/.pyenv"
[[ -d \$PYENV_ROOT/bin ]] && export PATH="\$PYENV_ROOT/bin:\$PATH"
eval "\$(pyenv init -)"
eval "\$(pyenv virtualenv-init -)"

# nvm
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh"
[ -s "\$NVM_DIR/bash_completion" ] && . "\$NVM_DIR/bash_completion"

# Rust
[ -f "\$HOME/.cargo/env" ] && . "\$HOME/.cargo/env"

# Go
export PATH=\$PATH:/usr/local/go/bin
export GOPATH=\$HOME/go
export PATH=\$PATH:\$GOPATH/bin

# rbenv
export PATH="\$HOME/.rbenv/bin:\$PATH"
eval "\$(rbenv init -)"

# Claude Code
alias claude-unsafe='claude --dangerously-skip-permissions'
claude-dev() {
    claude --dangerously-skip-permissions "\$@"
}
EOF
SHELLCONFIG

# =============================================================================
# PART 4: Claude Code Setup
# =============================================================================
echo ""
echo "=== [4/4] Installing Claude Code ==="

sudo -u "$ACTUAL_USER" bash << CLAUDESCRIPT
# Source nvm to get npm
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh"

echo "Installing Claude Code CLI..."
npm install -g @anthropic-ai/claude-code

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
- **Always use venv**: \`python -m venv .venv && source .venv/bin/activate\`
- Never \`pip install\` without an active venv

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
- Never \`pip install\` without a venv
- Never \`npm install -g\` for project dependencies
- Never install language runtimes globally (use version managers)
CLAUDEMD

echo "Creating init-project helper..."
mkdir -p "\$HOME/.local/bin"
cat > "\$HOME/.local/bin/init-project" << 'INITSCRIPT'
#!/bin/bash
echo "Usage: init-project <type> <name>"
echo "Types: python, node, go, rust, ruby"
echo ""
echo "Example:"
echo "  init-project python my-app"
echo "  cd my-app"
echo "  source .venv/bin/activate"
INITSCRIPT
chmod +x "\$HOME/.local/bin/init-project"

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
echo "  - pyenv + Python 3.12"
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
