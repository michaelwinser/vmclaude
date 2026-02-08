#!/bin/bash
# base-tools.sh - Install core developer tools, Docker, and Podman
# This script should be run as root (via vagrant provisioner)

set -euo pipefail

echo "=== Installing Base Developer Tools ==="

# Update package lists
export DEBIAN_FRONTEND=noninteractive
apt-get update

# Install build essentials and core utilities
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

# Create symlink for fd (Ubuntu packages it as fdfind)
ln -sf /usr/bin/fdfind /usr/local/bin/fd

echo "=== Installing Docker ==="

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update

# Install Docker
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add vagrant user to docker group
usermod -aG docker vagrant

# Enable and start Docker
systemctl enable docker
systemctl start docker

echo "=== Installing Podman ==="

# Install Podman from Ubuntu repos (24.04 has a recent version)
apt-get install -y podman podman-compose

# Configure Podman for rootless operation
# Create registries.conf for pulling from Docker Hub by default
mkdir -p /etc/containers
cat > /etc/containers/registries.conf << 'EOF'
[registries.search]
registries = ['docker.io', 'quay.io', 'ghcr.io']

[registries.insecure]
registries = []

[registries.block]
registries = []
EOF

echo "=== Configuring User Environment ==="

# Create projects directory
sudo -u vagrant mkdir -p /home/vagrant/projects

# Set up bashrc additions for vagrant user
cat >> /home/vagrant/.bashrc << 'EOF'

# Base tools additions
export PATH="$HOME/.local/bin:$PATH"

# fd alias (in case symlink doesn't work)
alias fd='fdfind'

# Docker/Podman aliases
alias dc='docker compose'
alias pc='podman-compose'

# Useful aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
EOF

chown vagrant:vagrant /home/vagrant/.bashrc

echo "=== Base Tools Installation Complete ==="
echo "Docker version: $(docker --version)"
echo "Podman version: $(podman --version)"
echo "Git version: $(git --version)"
