#!/bin/bash
# language-envs.sh - Install language version managers and runtimes
# This script should be run as the vagrant user (via vagrant provisioner)

set -euo pipefail

echo "=== Installing Language Version Managers and Runtimes ==="

# Ensure we're running as vagrant user
if [ "$(whoami)" != "vagrant" ]; then
    echo "This script must be run as the vagrant user"
    exit 1
fi

cd "$HOME"

# =============================================================================
# pyenv + Python
# =============================================================================
echo "=== Installing pyenv and Python ==="

# Install pyenv dependencies
sudo apt-get install -y \
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
    liblzma-dev

# Install pyenv
curl https://pyenv.run | bash

# Add pyenv to bashrc
cat >> ~/.bashrc << 'EOF'

# pyenv configuration
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
EOF

# Source pyenv for current session
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# Install Python 3.12
pyenv install 3.12
pyenv global 3.12

# Install pipx for global CLI tools
pip install --upgrade pip
pip install pipx
pipx ensurepath

# =============================================================================
# nvm + Node.js
# =============================================================================
echo "=== Installing nvm and Node.js ==="

# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# Add nvm to bashrc (installer does this, but ensure it's there)
cat >> ~/.bashrc << 'EOF'

# nvm configuration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF

# Source nvm for current session
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node LTS
nvm install --lts
nvm use --lts
nvm alias default lts/*

# Install pnpm globally
npm install -g pnpm

# =============================================================================
# Rust via rustup
# =============================================================================
echo "=== Installing Rust via rustup ==="

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Add cargo to bashrc
cat >> ~/.bashrc << 'EOF'

# Rust configuration
. "$HOME/.cargo/env"
EOF

# Source cargo for current session
source "$HOME/.cargo/env"

# Install stable toolchain (should be default, but be explicit)
rustup default stable
rustup component add rustfmt clippy

# =============================================================================
# Go (latest stable)
# =============================================================================
echo "=== Installing Go ==="

GO_VERSION="1.22.0"
wget -q "https://go.dev/dl/go${GO_VERSION}.linux-$(dpkg --print-architecture).tar.gz" -O /tmp/go.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf /tmp/go.tar.gz
rm /tmp/go.tar.gz

# Add Go to bashrc
cat >> ~/.bashrc << 'EOF'

# Go configuration
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
EOF

# Create Go workspace
mkdir -p ~/go/{bin,src,pkg}

# =============================================================================
# rbenv + Ruby
# =============================================================================
echo "=== Installing rbenv and Ruby ==="

# Install rbenv dependencies
sudo apt-get install -y \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    libyaml-dev \
    libncurses5-dev \
    libgdbm-dev

# Install rbenv
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
cd ~/.rbenv && src/configure && make -C src
cd ~

# Install ruby-build as rbenv plugin
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build

# Add rbenv to bashrc
cat >> ~/.bashrc << 'EOF'

# rbenv configuration
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
EOF

# Source rbenv for current session
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# Install Ruby 3.3 (latest stable)
rbenv install 3.3.0
rbenv global 3.3.0

# Install bundler
gem install bundler

echo "=== Language Environments Installation Complete ==="
echo ""
echo "Installed versions:"
echo "  Python: $(python --version 2>&1)"
echo "  Node: $(node --version 2>&1)"
echo "  npm: $(npm --version 2>&1)"
echo "  pnpm: $(pnpm --version 2>&1)"
echo "  Rust: $(rustc --version 2>&1)"
echo "  Go: $(/usr/local/go/bin/go version 2>&1)"
echo "  Ruby: $(ruby --version 2>&1)"
