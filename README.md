# vmclaude — Lima VM for Claude Code Development

A reproducible VM template using Lima for development with Claude Code in dangerous mode (no permission prompts).

## Architecture

```
Host (macOS)
├── ./vm              ← CLI wrapper (all lifecycle commands)
└── Lima VM (Ubuntu 24.04 LTS)
    ├── Phase 1: cloud-init (apt packages, Docker, Podman, Go, build deps)
    ├── Phase 2: setup-languages.sh (pyenv, nvm, rustup, rbenv, Claude Code)
    ├── ~/CLAUDE.md (development rules)
    └── ~/projects ← shared with host
```

## Prerequisites

- macOS (Apple Silicon or Intel)
- [Lima](https://lima-vm.io/): `brew install lima`

## Quick Start

```bash
cd /path/to/vmclaude

# Create VM + install everything (~15 min first time)
./vm create

# Open a shell
./vm shell

# Authenticate Claude
claude auth

# Start developing
claude-dev    # dangerous mode
```

## `vm` Commands

### Lifecycle

| Command | Description |
|---------|-------------|
| `./vm create` | Create VM and run language setup |
| `./vm destroy` | Delete VM (with confirmation) |
| `./vm start` | Start a stopped VM |
| `./vm stop` | Stop the VM |
| `./vm restart` | Stop + start |

### Development

| Command | Description |
|---------|-------------|
| `./vm shell` | Open a shell in the VM |
| `./vm exec <cmd>` | Run a command in the VM |
| `./vm setup` | Run/resume language runtime installation |

### Info

| Command | Description |
|---------|-------------|
| `./vm status` | Show VM status + setup progress |
| `./vm info` | Detailed VM info (disk, setup steps) |
| `./vm logs` | Tail cloud-init log from inside VM |

### Snapshots

| Command | Description |
|---------|-------------|
| `./vm snapshot create <tag>` | Save VM state |
| `./vm snapshot list` | List snapshots |
| `./vm snapshot apply <tag>` | Restore VM state |
| `./vm snapshot delete <tag>` | Remove a snapshot |

## Two-Phase Provisioning

### Phase 1: cloud-init (automatic, fast)

Runs during `./vm create` via Lima's cloud-init. Installs system packages as root:

- Build essentials (gcc, make, cmake, etc.)
- Docker + Docker Compose
- Podman + podman-compose
- Go 1.22 (binary download)
- Language build dependencies (libssl-dev, zlib1g-dev, etc.)
- User shell config (.bashrc with guarded runtime entries)
- Claude Code settings + CLAUDE.md

Uses a sentinel file (`/var/lib/vmclaude-system-provisioned`) so it **skips entirely on VM restart**.

### Phase 2: Language setup (interactive, resumable)

Runs via `./vm setup` (called automatically after create). Compiles/installs runtimes with full TTY output:

- pyenv + Python 3.12
- nvm + Node.js LTS + pnpm
- Rust (rustup + stable toolchain)
- rbenv + Ruby 3.3
- Claude Code CLI

Each step uses a sentinel file in `~/.vmclaude/`. If setup fails partway through, `./vm setup` picks up where it left off.

## Installed Tools

| Category | Tools |
|----------|-------|
| Containers | Docker, Docker Compose, Podman, podman-compose |
| Python | pyenv, Python 3.12, poetry |
| Node.js | nvm, Node LTS, pnpm |
| Rust | rustup, stable toolchain, rustfmt, clippy |
| Go | Go 1.22 |
| Ruby | rbenv, Ruby 3.3, Bundler |
| Utilities | ripgrep, fd, jq, htop, tmux, vim |

## File Sharing

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

## Using Claude Code

```bash
claude              # Normal mode (with prompts)
claude-dev          # Dangerous mode (no prompts)
claude-unsafe       # Alias for dangerous mode
```

## Development Guidelines

See `~/CLAUDE.md` inside the VM. Key rules:

1. **Python**: Always use poetry for dependency management
2. **Node.js**: Use project-local node_modules, prefer pnpm
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

Then recreate: `./vm destroy && ./vm create`

### Add Port Forwarding

Edit `claude-dev.yaml`:

```yaml
portForwards:
  - guestPort: 5432
    hostPort: 5432
```

## Troubleshooting

### Setup failed partway through
```bash
./vm setup    # Re-run — completed steps are skipped
```

### VM won't start
```bash
./vm status          # Check current state
./vm logs            # View cloud-init output
limactl logs claude-dev   # View Lima logs
```

### Docker permission denied
```bash
# Inside VM
sudo usermod -aG docker $USER
exit
./vm shell
```

### Full reset
```bash
./vm destroy
./vm create
```

## File Structure

```
vmclaude/
├── vm                           # CLI wrapper (start here)
├── claude-dev.yaml              # Lima VM configuration
├── README.md
├── scripts/
│   ├── setup-languages.sh       # Phase 2: idempotent language installer
│   ├── full-setup.sh            # Standalone setup (non-Lima VMs)
│   └── legacy/                  # Old split scripts (reference only)
│       ├── base-tools.sh
│       ├── language-envs.sh
│       └── claude-setup.sh
├── templates/
│   ├── CLAUDE.md
│   └── devcontainers/
└── config/
    └── claude-settings.json
```

## Security Notes

This VM runs Claude Code in **dangerous mode**:
- No permission prompts for any operations
- Full filesystem access within the VM
- Unrestricted command execution

**Recommendations:**
- Keep sensitive data outside `~/projects`
- Use separate VMs for different security contexts
- Periodically snapshot or recreate the VM
