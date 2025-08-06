# Commit-AI

[![CI/CD Pipeline](https://github.com/nseba/commit-ai/workflows/CI/CD%20Pipeline/badge.svg)](https://github.com/nseba/commit-ai/actions)
[![Go Report Card](https://goreportcard.com/badge/github.com/nseba/commit-ai)](https://goreportcard.com/report/github.com/nseba/commit-ai)
[![codecov](https://codecov.io/gh/nseba/commit-ai/branch/main/graph/badge.svg)](https://codecov.io/gh/nseba/commit-ai)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Release](https://img.shields.io/github/release/nseba/commit-ai.svg)](https://github.com/nseba/commit-ai/releases/latest)

A CLI tool that uses AI to generate meaningful commit messages from git diffs. Supports multiple AI providers including Ollama and OpenAI, with customizable prompt templates and ignore patterns.

## Features

- 🤖 **AI-Powered**: Generate commit messages using various AI providers
- 🔧 **Multi-Provider Support**: Ollama (local), OpenAI, and more
- 🌐 **Multi-Language**: Generate commit messages in any language
- 📝 **Custom Templates**: Use your own prompt templates
- 🚫 **Ignore Patterns**: Support for `.caiignore` files (like `.gitignore`)
- ⚙️ **Configurable**: Flexible configuration via TOML files and environment variables
- 🐳 **Docker Support**: Run in containers
- 📦 **Easy Installation**: Multiple installation methods

## Quick Start

### Installation

#### Using Go (recommended)
```bash
go install github.com/nseba/commit-ai/cmd@latest
```

#### Using Homebrew (macOS/Linux)
```bash
brew tap nseba/tools
brew install commit-ai
```

#### Using Docker
```bash
docker pull nseba/commit-ai:latest
```

#### Download Binary
Download the latest binary from the [releases page](https://github.com/nseba/commit-ai/releases).

### Basic Usage

1. **Set up Ollama** (for local AI):
   ```bash
   # Install Ollama
   curl -fsSL https://ollama.ai/install.sh | sh
   
   # Pull a model
   ollama pull llama2
   ```

2. **Generate a commit message**:
   ```bash
   # In your git repository with staged changes
   commit-ai
   
   # Or specify a path
   commit-ai /path/to/your/repo
   
   # Use the generated message
   git commit -m "$(commit-ai)"
   ```

## Configuration

Commit-AI looks for configuration in `~/.config/commit-ai/config.toml`. If it doesn't exist, it will be created with default values.

### Configuration Options

| Option | Environment Variable | Description | Default |
|--------|---------------------|-------------|---------|
| `CAI_API_URL` | `CAI_API_URL` | API URL for the AI provider | `http://localhost:11434` |
| `CAI_MODEL` | `CAI_MODEL` | Model name to use | `llama2` |
| `CAI_PROVIDER` | `CAI_PROVIDER` | AI provider (`ollama`, `openai`) | `ollama` |
| `CAI_API_TOKEN` | `CAI_API_TOKEN` | API token (required for OpenAI) | `""` |
| `CAI_LANGUAGE` | `CAI_LANGUAGE` | Language for commit messages | `english` |
| `CAI_PROMPT_TEMPLATE` | `CAI_PROMPT_TEMPLATE` | Prompt template file name | `default.txt` |

### Example Configuration

```toml
# ~/.config/commit-ai/config.toml

CAI_API_URL = "http://localhost:11434"
CAI_MODEL = "llama2"
CAI_PROVIDER = "ollama"
CAI_API_TOKEN = ""
CAI_LANGUAGE = "english"
CAI_PROMPT_TEMPLATE = "default.txt"
```

### OpenAI Configuration

```toml
# ~/.config/commit-ai/config.toml

CAI_API_URL = "https://api.openai.com"
CAI_MODEL = "gpt-3.5-turbo"
CAI_PROVIDER = "openai"
CAI_API_TOKEN = "your-openai-api-key"
CAI_LANGUAGE = "english"
CAI_PROMPT_TEMPLATE = "default.txt"
```

## Prompt Templates

Commit-AI uses Go templates to customize the AI prompts. Templates are stored in `~/.config/commit-ai/`.

### Default Template

```text
You are an expert developer reviewing a git diff to generate a concise, meaningful commit message.

Language: Generate the commit message in {{.Language}}.

Git Diff:
{{.Diff}}

Based on the above git diff, generate a single line commit message that:
1. Is concise and descriptive (50 characters or less preferred)
2. Uses conventional commit format if applicable (feat:, fix:, docs:, etc.)
3. Describes WHAT changed, not HOW it was implemented
4. Uses imperative mood (e.g., "Add feature" not "Added feature")

Commit Message:
```

### Custom Template Example

Create `~/.config/commit-ai/detailed.txt`:

```text
You are reviewing a git diff to create a detailed commit message.

Language: {{.Language}}

Changes:
{{.Diff}}

Generate a commit message with:
- Summary line (50 chars max)
- Blank line
- Detailed explanation if needed

Format as conventional commit (feat/fix/docs/refactor/etc).

Response:
```

Then update your config:
```toml
CAI_PROMPT_TEMPLATE = "detailed.txt"
```

## Ignore Patterns

Use `.caiignore` files to exclude certain files from diff analysis. The syntax is identical to `.gitignore`.

### Example `.caiignore`

```gitignore
# Ignore log files
*.log
logs/

# Ignore generated files
dist/
build/
*.generated.go

# Ignore documentation changes for commit message generation
*.md
docs/

# Ignore test files
*_test.go
test/
```

Place `.caiignore` files at any level in your repository. Commit-AI will search up the directory tree and apply all applicable ignore patterns.

## Advanced Usage

### Environment Variables

All configuration options can be overridden with environment variables:

```bash
export CAI_PROVIDER=openai
export CAI_MODEL=gpt-4
export CAI_API_TOKEN=your-token

commit-ai
```

### Using with Different Providers

#### Ollama (Local)
```bash
# Start Ollama
ollama serve

# Pull a coding-focused model
ollama pull codellama

# Update config or set environment variable
export CAI_MODEL=codellama

commit-ai
```

#### OpenAI
```bash
export CAI_PROVIDER=openai
export CAI_MODEL=gpt-3.5-turbo
export CAI_API_TOKEN=sk-your-token-here

commit-ai
```

### Docker Usage

#### Basic Usage
```bash
docker run --rm -it \
  -v $(pwd):/workspace \
  -v ~/.config/commit-ai:/home/appuser/.config/commit-ai \
  nseba/commit-ai:latest
```

#### With Environment Variables
```bash
docker run --rm -it \
  -v $(pwd):/workspace \
  -e CAI_PROVIDER=openai \
  -e CAI_API_TOKEN=your-token \
  nseba/commit-ai:latest
```

### Integration with Git Hooks

Create a pre-commit hook to automatically generate commit messages:

```bash
#!/bin/sh
# .git/hooks/prepare-commit-msg

if [ -z "$2" ]; then
    commit-ai > "$1"
fi
```

### Shell Integration

Add to your `.bashrc` or `.zshrc`:

```bash
# Quick commit with AI-generated message
alias gaic='git add . && git commit -m "$(commit-ai)"'

# Interactive commit with AI suggestion
function gai() {
    local msg=$(commit-ai "$1")
    echo "Suggested commit message: $msg"
    read -p "Use this message? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git commit -m "$msg"
    else
        git commit
    fi
}
```

## Development

### Prerequisites

- Go 1.21 or later
- Git
- Make (optional, for using Makefile)

### Building from Source

```bash
git clone https://github.com/nseba/commit-ai.git
cd commit-ai

# Install dependencies
go mod download

# Build
go build -o commit-ai ./cmd

# Run tests
go test ./...
```

### Using Makefile

```bash
# Set up development environment
make dev-setup

# Run tests
make test

# Build for all platforms
make build-all

# Run linting
make lint

# View all available targets
make help
```

### Project Structure

```
commit-ai/
├── cmd/                    # CLI entry point
├── internal/              # Private application code
│   ├── cli/              # CLI command handling
│   ├── config/           # Configuration management
│   ├── generator/        # AI message generation
│   └── git/              # Git operations and diff handling
├── pkg/                   # Public packages (if any)
├── configs/              # Example configuration files
├── templates/            # Example prompt templates
├── .github/workflows/    # CI/CD pipelines
├── Dockerfile            # Container definition
├── Makefile             # Build automation
└── README.md            # This file
```

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Quick Contribution Steps

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Run tests: `make test`
5. Run linting: `make lint`
6. Commit your changes: `git commit -m "feat: add my feature"`
7. Push to your fork: `git push origin feature/my-feature`
8. Create a Pull Request

## Examples

### Basic Workflow

```bash
# Make some changes to your code
echo "console.log('Hello, World!');" >> app.js
git add app.js

# Generate commit message
commit-ai
# Output: "feat: add hello world logging to app"

# Commit with the generated message
git commit -m "$(commit-ai)"
```

### Different Languages

```bash
# Spanish commit messages
export CAI_LANGUAGE=spanish
commit-ai
# Output: "feat: agregar logging de hello world a la app"

# French commit messages
export CAI_LANGUAGE=french
commit-ai
# Output: "feat: ajouter la journalisation hello world à l'app"
```

### Working with Ignore Patterns

```bash
# Create .caiignore
echo "*.log" > .caiignore
echo "dist/" >> .caiignore

# Make changes to ignored and non-ignored files
echo "debug info" > debug.log
echo "new feature" >> src/app.js

git add .

# Only src/app.js changes will be analyzed
commit-ai
# Output: "feat: add new feature to app"
```

## Troubleshooting

### Common Issues

#### "No changes to commit"
- Ensure you have staged changes: `git add .`
- Check if all changes are being ignored by `.caiignore` patterns

#### "Failed to connect to AI provider"
- For Ollama: Ensure Ollama is running (`ollama serve`)
- For OpenAI: Check your API token and internet connection
- Verify the API URL in your configuration

#### "Template not found"
- Check if the template file exists in `~/.config/commit-ai/`
- Verify the `CAI_PROMPT_TEMPLATE` setting in your config

#### "Permission denied"
- Ensure the binary has execute permissions: `chmod +x commit-ai`
- Check file permissions in `~/.config/commit-ai/`

### Debug Mode

Set `DEBUG=1` to enable verbose logging:

```bash
DEBUG=1 commit-ai
```

### Getting Help

- Create an [issue](https://github.com/nseba/commit-ai/issues) for bugs
- Start a [discussion](https://github.com/nseba/commit-ai/discussions) for questions
- Check existing issues before creating new ones

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Ollama](https://ollama.ai/) for providing local AI capabilities
- [OpenAI](https://openai.com/) for their API
- [Cobra](https://cobra.dev/) for the CLI framework
- [go-git](https://github.com/go-git/go-git) for Git operations
- All contributors and users of this project

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed list of changes and releases.

---

Made with ❤️ by [nseba](https://github.com/nseba)