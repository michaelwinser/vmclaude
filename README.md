# VM Template for Claude Code Development

A reproducible VM template using Lima for development with Claude Code in dangerous mode (no permission prompts).

## Architecture

```
Host (macOS)
└── Lima VM (Ubuntu 24.04 LTS)
    ├── Claude Code (dangerous mode)
    ├── Docker & Podman
    ├── pyenv, nvm, rustup, Go, rbenv
    ├── ~/CLAUDE.md (development rules)
    └── ~/projects ← shared with host
```

## Prerequisites

- macOS (Apple Silicon or Intel)
- [Homebrew](https://brew.sh/)

## Quick Start

### 1. Install Lima

```bash
brew install lima
```

### 2. Start the VM

```bash
cd /path/to/vmclaude
limactl start claude-dev.yaml
```

This downloads Ubuntu 24.04, provisions all tools, and configures Claude Code. First run takes 10-15 minutes.

### 3. Enter the VM

```bash
limactl shell claude-dev
```

Or use the shortcut (after first start):
```bash
lima claude-dev
```

### 4. Authenticate Claude

```bash
claude auth
```

### 5. Start developing

```bash
claude-dev  # Starts Claude in dangerous mode
```

## Installed Tools

| Category | Tools |
|----------|-------|
| Containers | Docker, Docker Compose, Podman, podman-compose |
| Python | pyenv, Python 3.12, pipx |
| Node.js | nvm, Node LTS, pnpm |
| Rust | rustup, stable toolchain, rustfmt, clippy |
| Go | Go 1.22 |
| Ruby | rbenv, Ruby 3.3, Bundler |
| Utilities | ripgrep, fd, jq, htop, tmux, vim |

## File Sharing

Lima automatically shares directories between host and VM:

| Host Path | VM Path | Writable |
|-----------|---------|----------|
| `~` | `~` | No |
| `~/projects` | `~/projects` | Yes |
| `/tmp/lima` | `/tmp/lima` | Yes |

Work in `~/projects` for full read-write access.

## Port Forwarding

Common development ports are automatically forwarded:

- 3000-3010 (React, Next.js)
- 4000-4010 (Phoenix, custom)
- 5000-5010 (Flask, custom)
- 8000-8010 (Django, FastAPI)
- 8080-8090 (General web)

Services running in the VM are accessible at `localhost:<port>` on your Mac.

## VM Management

```bash
# Start the VM
limactl start claude-dev.yaml

# Enter the VM shell
limactl shell claude-dev

# Stop the VM
limactl stop claude-dev

# Restart the VM
limactl stop claude-dev && limactl start claude-dev

# Delete the VM completely
limactl delete claude-dev

# List all VMs
limactl list

# Check VM status
limactl info claude-dev
```

## Using Claude Code

```bash
# Normal mode (with prompts)
claude

# Dangerous mode (no prompts) - use these in the VM
claude-dev
claude-unsafe
claude --dangerously-skip-permissions
```

## Development Guidelines

See `~/CLAUDE.md` inside the VM. Key rules:

1. **Python**: Always use venv before pip install
2. **Node.js**: Use project-local node_modules
3. **Go**: Use Go modules (`go mod init`)
4. **Rust**: Use Cargo
5. **Ruby**: Use Bundler

## Customization

### Adjust Resources

Edit `claude-dev.yaml`:

```yaml
cpus: 8
memory: "16GiB"
disk: "128GiB"
```

Then recreate the VM:
```bash
limactl delete claude-dev
limactl start claude-dev.yaml
```

### Add Port Forwarding

Edit `claude-dev.yaml`:

```yaml
portForwards:
  - guestPort: 5432
    hostPort: 5432
  - guestPortRange: [9000, 9010]
    hostPortRange: [9000, 9010]
```

### Add Mounts

Edit `claude-dev.yaml`:

```yaml
mounts:
  - location: "~/my-other-folder"
    writable: true
```

## Troubleshooting

### VM won't start
```bash
# Check Lima status
limactl list

# View logs
limactl logs claude-dev

# Try with QEMU explicitly (if VZ issues)
# Edit claude-dev.yaml: vmType: "qemu"
```

### Provisioning failed
```bash
# Delete and recreate
limactl delete claude-dev
limactl start claude-dev.yaml
```

### Docker permission denied
```bash
# Inside VM, re-add to docker group
sudo usermod -aG docker $USER
# Then exit and re-enter
exit
limactl shell claude-dev
```

### Slow file access
Lima uses different mount backends. For better performance on large codebases:
```yaml
mounts:
  - location: "~/projects"
    writable: true
    9p:
      cache: "mmap"
```

## File Structure

```
vmclaude/
├── claude-dev.yaml          # Lima VM configuration
├── README.md
├── scripts/                  # Standalone scripts (optional)
│   └── full-setup.sh        # For manual VM setup
├── templates/
│   ├── CLAUDE.md            # Development rules
│   └── devcontainers/       # VS Code devcontainer templates
│       ├── python/
│       ├── node/
│       ├── go/
│       ├── rust/
│       ├── ruby/
│       └── base/
└── config/
    └── claude-settings.json  # Claude permissions
```

## Security Notes

This VM runs Claude Code in **dangerous mode**:
- No permission prompts for any operations
- Full filesystem access within the VM
- Unrestricted command execution

**Recommendations:**
- Keep sensitive data outside `~/projects`
- Use separate VMs for different security contexts
- Periodically delete and recreate the VM
