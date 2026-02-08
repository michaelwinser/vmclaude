# Development Environment Rules

This VM is configured for Claude Code development in dangerous mode. Follow these rules to maintain a clean, reproducible environment.

## Isolation Requirements (MANDATORY)

### Python
- **Always use poetry** for dependency management and virtual environments.
- Initialize with: `poetry init` or `poetry new <project-name>`
- Add dependencies with: `poetry add <package>`
- Never `pip install` directly — use `poetry add` instead.
- Use `pyproject.toml` for project configuration (poetry manages this).

### Node.js
- Use project-local `node_modules`. Never install project dependencies globally.
- Global installs (`npm install -g` or `pnpm add -g`) are only for CLI tools like `typescript`, `eslint`, etc.
- Prefer `pnpm` over `npm` for faster, more efficient package management.
- Use `package.json` for all project dependencies.

### Go
- Use Go modules. Ensure `go.mod` exists before adding dependencies.
- Initialize with: `go mod init <module-name>`
- Dependencies are managed automatically in `go.sum`.

### Rust
- Use Cargo. Project must have `Cargo.toml`.
- Initialize with: `cargo init` or `cargo new <project-name>`
- Use `cargo add` to add dependencies.

### Ruby
- Use Bundler. Create `Gemfile` before adding gems.
- Initialize with: `bundle init`
- Install dependencies with: `bundle install`
- Run commands with: `bundle exec <command>`

## Container-First Development

### When to Use Containers
- For any project with a `Dockerfile`, prefer building and running inside containers.
- For projects requiring specific system dependencies or services.
- For consistent CI/CD parity.

### Docker Compose
- Use `docker-compose.yml` or `compose.yml` for multi-service setups.
- Build artifacts should be created inside containers for reproducibility.
- Example workflow:
  ```bash
  docker compose build
  docker compose up -d
  docker compose exec app <command>
  ```

### Podman (Rootless Alternative)
- Podman is available for rootless container operations.
- Commands are mostly compatible: `podman build`, `podman run`, etc.
- Use `podman-compose` for compose files.

## Devcontainer Usage

### When to Use Devcontainers
- For complex projects with many dependencies.
- When working with a team to ensure identical environments.
- For projects that will be developed in VS Code.

### Setup
```bash
# Initialize with a template
init-project python my-project
# Or manually create .devcontainer/devcontainer.json
```

### Available Templates
- `python` - Python with pyproject.toml, poetry
- `node` - Node/TypeScript with pnpm
- `go` - Go modules setup
- `rust` - Cargo-based project
- `ruby` - Bundler-based project
- `base` - Multi-language with all tools available

## What NOT To Do

### Never Do These
- `pip install <package>` directly — use `poetry add` instead
- `npm install <package>` globally for project dependencies
- Install language runtimes globally (use version managers: pyenv, nvm, rbenv)
- Hardcode paths to system binaries
- Modify system Python or Node installations
- Run `sudo pip install`, `sudo npm install`, or any sudo package installs

### Instead Do These
- `poetry add <package>` (poetry manages the venv automatically)
- `npm install <package>` (local to project)
- `pyenv install 3.12` / `nvm install 20` for version management
- Use `$(which python)` or rely on PATH for binary locations

## Project Initialization Checklist

### New Python Project
```bash
mkdir my-project && cd my-project
poetry init
poetry add <dependencies>
poetry shell   # or: poetry run <command>
```

### New Node Project
```bash
mkdir my-project && cd my-project
pnpm init
# or: npm init -y
```

### New Go Project
```bash
mkdir my-project && cd my-project
go mod init github.com/username/my-project
```

### New Rust Project
```bash
cargo new my-project
# or in existing directory:
cargo init
```

### New Ruby Project
```bash
mkdir my-project && cd my-project
bundle init
# Edit Gemfile, then:
bundle install
```

## Claude Code Dangerous Mode

This VM is configured for dangerous mode operation. Claude can:
- Execute any bash command without prompts
- Read, write, and edit any file
- Search the web and fetch URLs
- Create and manage files

### Starting Claude
```bash
claude-dev           # Dangerous mode (no prompts)
claude               # Normal mode (with prompts)
```

### Authentication
Run `claude auth` to authenticate with your Anthropic account.
