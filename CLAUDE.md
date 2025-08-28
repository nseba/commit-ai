# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **Commit-AI**, a Go CLI tool that generates AI-powered commit messages from git diffs. It supports multiple AI providers (Ollama, OpenAI) and features hierarchical configuration with project-local overrides.

## Essential Commands

### Development Commands
```bash
# Run all tests
make test

# Run tests with coverage
make test-coverage

# Run linting
make lint

# Format code
make fmt

# Run go vet
make vet

# Run all development checks (fmt + vet + lint + test)
make dev-test

# Run security scans
make security-all
```

### Build Commands
```bash
# Build for current platform
make build

# Build for all platforms
make build-all

# Install locally
make install
```

### Release Commands
```bash
# Run pre-release checks
make release-check

# Create semantic release
make semantic-release

# Create patch release
make release-patch

# Create minor release
make release-minor
```

### Project Initialization
```bash
# Initialize project with local config files
commit-ai init

# This creates:
# - .commitai: Project-specific configuration
# - .caiignore: File patterns to ignore
# - custom-prompt.txt: Custom prompt template
```

### Testing the Application
```bash
# Set up development environment with example configs
make dev-setup

# Run with example configuration
make run-example

# Test manually (requires staged git changes)
./dist/commit-ai
```

## Architecture

### Core Packages
- **`internal/cli/`** - Cobra-based command-line interface with interactive features
- **`internal/config/`** - Hierarchical configuration system with project-local overrides
- **`internal/generator/`** - AI provider abstraction for generating commit messages
- **`internal/git/`** - Git repository operations and diff handling

### Key Design Patterns

1. **Hierarchical Configuration**: Configuration loads in priority order:
   - Environment variables (`CAI_*`)
   - Project-local `.commitai` files (cascading from git root to current directory)
   - Global config (`~/.config/commit-ai/config.toml`)
   - Default values

2. **Provider Pattern**: The generator package abstracts different AI providers (Ollama/OpenAI) behind a common interface.

3. **Template System**: Uses Go templates for customizable prompt generation with security validation.

4. **Security-First Design**: All file paths are validated to prevent path traversal attacks (`internal/config/config.go:validateProjectConfigPath`, `internal/generator/generator.go:validateTemplatePath`).

### Interactive Features
The CLI supports:
- `--show` / `-s`: Display last commit message
- `--edit` / `-e`: Interactive editing of generated messages
- `--commit` / `-c`: Auto-commit with generated message
- `--add` / `-a`: Stage all changes before processing

### Configuration Discovery
- Automatically finds git repository root
- Applies cascading configuration from git root to current directory
- More specific directory configs override less specific ones
- Supports partial configuration overrides (only specify values you want to change)
- **Project-local templates**: Looks for templates in current directory first, then falls back to global config directory

## Testing Strategy

- Unit tests for all major components (`*_test.go` files)
- Configuration validation tests
- Security validation for path traversal protection
- Coverage reports generated in `coverage.out` and `coverage.html`

## Security Considerations

- All file paths are validated to prevent path traversal attacks
- Template files must be absolute paths in safe locations
- Project config files must have `.commitai` extension
- Git path validation prevents malicious `.git` file reading

## Common Development Tasks

### Setting up a new project
```bash
# In your project directory
commit-ai init

# Customize the generated files:
# - Edit .commitai to set provider/model preferences
# - Edit .caiignore to exclude files from analysis
# - Edit custom-prompt.txt to customize AI prompts
```

When adding new AI providers:
1. Add provider constant to `internal/generator/generator.go`
2. Implement provider-specific generation method
3. Update the switch statement in `Generate()` method
4. Add provider validation to `internal/config/config.go`

When modifying configuration:
1. Update the `Config` struct in `internal/config/config.go`
2. Add environment variable loading in `loadFromEnv()`
3. Add validation in `Validate()` method
4. Update project config merging in `loadProjectConfig()`

### Template System
- Templates support project-local customization via `commit-ai init`
- Template resolution: current directory → global config directory → create default
- All template paths are validated for security (`validateTemplatePath` function)

## Git Workflow

This project uses conventional commits and semantic versioning. The `make validate-commit` command checks commit message format, and git hooks can be installed with `make install-hooks`.