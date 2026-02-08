#!/bin/bash
# claude-setup.sh - Install and configure Claude Code CLI
# This script should be run as the vagrant user

set -euo pipefail

echo "=== Installing Claude Code CLI ==="

# Ensure we're running as vagrant user
if [ "$(whoami)" != "vagrant" ]; then
    echo "This script must be run as the vagrant user"
    exit 1
fi

cd "$HOME"

# Source nvm to get npm available
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Claude Code CLI globally via npm
npm install -g @anthropic-ai/claude-code

# Create Claude configuration directory
mkdir -p ~/.claude

# Copy dangerous mode settings if they exist in /vagrant/config
if [ -f /vagrant/config/claude-settings.json ]; then
    cp /vagrant/config/claude-settings.json ~/.claude/settings.json
    echo "Copied Claude settings from provisioner"
else
    # Create default dangerous mode settings
    cat > ~/.claude/settings.json << 'EOF'
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
      "NotebookEdit(*)"
    ],
    "deny": []
  }
}
EOF
    echo "Created default Claude settings"
fi

# Copy CLAUDE.md template to home directory if it exists
if [ -f /vagrant/templates/CLAUDE.md ]; then
    cp /vagrant/templates/CLAUDE.md ~/CLAUDE.md
    echo "Copied CLAUDE.md template to home directory"
fi

# Add Claude alias for dangerous mode
cat >> ~/.bashrc << 'EOF'

# Claude Code configuration
alias claude-unsafe='claude --dangerously-skip-permissions'

# Function to start Claude in dangerous mode
claude-dev() {
    claude --dangerously-skip-permissions "$@"
}
EOF

# Create a helper script to initialize new projects with devcontainer
mkdir -p ~/.local/bin
cat > ~/.local/bin/init-project << 'EOF'
#!/bin/bash
# Initialize a new project with devcontainer template

set -euo pipefail

TEMPLATE=${1:-base}
PROJECT_NAME=${2:-$(basename "$(pwd)")}

TEMPLATES_DIR="$HOME/.claude-templates/devcontainers"

if [ ! -d "$TEMPLATES_DIR/$TEMPLATE" ]; then
    echo "Available templates:"
    ls -1 "$TEMPLATES_DIR" 2>/dev/null || echo "  No templates found in $TEMPLATES_DIR"
    echo ""
    echo "Usage: init-project <template> [project-name]"
    echo "Templates: python, node, go, rust, ruby, base"
    exit 1
fi

echo "Initializing $PROJECT_NAME with $TEMPLATE template..."

# Create project directory if it doesn't exist
mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

# Copy devcontainer template
cp -r "$TEMPLATES_DIR/$TEMPLATE/.devcontainer" .

# Copy project CLAUDE.md if it exists
if [ -f "$TEMPLATES_DIR/$TEMPLATE/CLAUDE.md" ]; then
    cp "$TEMPLATES_DIR/$TEMPLATE/CLAUDE.md" .
fi

echo "Project initialized at $(pwd)"
echo "Next steps:"
echo "  1. cd $PROJECT_NAME"
echo "  2. Open in VS Code with devcontainer, or"
echo "  3. Run: devcontainer up --workspace-folder ."
EOF
chmod +x ~/.local/bin/init-project

# Copy devcontainer templates to user's home for easy access
if [ -d /vagrant/templates/devcontainers ]; then
    mkdir -p ~/.claude-templates
    cp -r /vagrant/templates/devcontainers ~/.claude-templates/
    echo "Copied devcontainer templates to ~/.claude-templates"
fi

echo "=== Claude Code Setup Complete ==="
echo ""
echo "Usage:"
echo "  claude                    - Start Claude Code (normal mode)"
echo "  claude-dev               - Start Claude Code (dangerous mode)"
echo "  claude-unsafe            - Alias for dangerous mode"
echo "  init-project <template>  - Initialize project with devcontainer"
echo ""
echo "To authenticate, run: claude auth"
