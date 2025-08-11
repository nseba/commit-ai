# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Project-local configuration support via `.commitai` files
- Hierarchical configuration system with cascading overrides
- Git-aware configuration discovery from repository root
- Partial configuration overrides (only specify values you want to change)
- Directory-specific configuration support for monorepos

### Security
- Added path validation for `.commitai` configuration files to prevent path traversal attacks
- Added validation for `.git` file reading to ensure safe git repository detection
- Configuration file paths are now validated before processing to prevent malicious file access
- Initial release of Commit-AI CLI tool
- Support for AI-powered commit message generation from git diffs
- Multiple AI provider support (Ollama, OpenAI)
- Configurable prompt templates with Go template syntax
- Support for `.caiignore` files to exclude files from analysis
- Multi-language commit message generation
- TOML-based configuration with environment variable overrides
- Docker container support for containerized deployments
- Comprehensive CLI with path argument support
- Automatic configuration file creation with sensible defaults
- Cross-platform binary builds (Linux, macOS, Windows)
- GitHub Actions CI/CD pipeline with automated releases
- Homebrew formula for easy macOS/Linux installation
- Comprehensive test suite with high code coverage
- Detailed documentation and usage examples

### Features
- **AI Providers**: Support for Ollama (local) and OpenAI providers
- **Configuration**: Flexible configuration via `~/.config/commit-ai/config.toml`
- **Templates**: Customizable prompt templates stored alongside config
- **Ignore Patterns**: `.caiignore` files with gitignore-compatible syntax
- **Multi-language**: Generate commit messages in any language
- **Git Integration**: Handles both staged and unstaged changes
- **Error Handling**: Graceful handling of empty repos and edge cases
- **Security**: Secure handling of API tokens and credentials

### Configuration Options
- `CAI_API_URL`: API endpoint for AI provider
- `CAI_MODEL`: Model name to use for generation
- `CAI_PROVIDER`: AI provider selection (ollama, openai)
- `CAI_API_TOKEN`: API authentication token
- `CAI_LANGUAGE`: Target language for commit messages
- `CAI_PROMPT_TEMPLATE`: Custom prompt template filename

### Developer Experience
- Comprehensive Makefile with common development tasks
- golangci-lint integration with strict linting rules
- Pre-commit hooks for code quality assurance
- Docker support for consistent development environments
- Extensive unit tests with table-driven test patterns
- Benchmark and profiling support
- Security scanning with gosec

### Documentation
- Detailed README with installation and usage instructions
- Contributing guide with development setup instructions
- Example configuration files and templates
- Troubleshooting section with common issues
- API documentation for all exported functions

## [1.0.0] - 2024-01-XX

### Added
- Initial stable release
- Core functionality for AI-powered commit message generation
- Support for Ollama and OpenAI providers
- Configuration management with TOML files
- Git diff analysis with ignore pattern support
- Multi-platform binary releases
- Docker container images
- Comprehensive documentation

---

## Release Notes Template

For future releases, use this template:

## [X.Y.Z] - YYYY-MM-DD

### Added
- New features

### Changed
- Changes in existing functionality

### Deprecated
- Soon-to-be removed features

### Removed
- Now removed features

### Fixed
- Any bug fixes

### Security
- Security improvements