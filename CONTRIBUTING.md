# Contributing to Commit-AI

We love your input! We want to make contributing to Commit-AI as easy and transparent as possible, whether it's:

- Reporting a bug
- Discussing the current state of the code
- Submitting a fix
- Proposing new features
- Becoming a maintainer

## Development Process

We use GitHub to host code, to track issues and feature requests, as well as accept pull requests.

## Pull Requests

Pull requests are the best way to propose changes to the codebase. We actively welcome your pull requests:

1. Fork the repo and create your branch from `main`.
2. If you've added code that should be tested, add tests.
3. If you've changed APIs, update the documentation.
4. Ensure the test suite passes.
5. Make sure your code lints.
6. Issue that pull request!

## Development Setup

### Prerequisites

- Go 1.21 or later
- Git
- Make (optional, for using Makefile)
- golangci-lint (for linting)

### Setup Instructions

1. **Fork and clone the repository**
   ```bash
   git clone https://github.com/your-username/commit-ai.git
   cd commit-ai
   ```

2. **Set up development environment**
   ```bash
   make dev-setup
   ```
   
   Or manually:
   ```bash
   # Install dependencies
   go mod download
   
   # Set up example configuration
   mkdir -p ~/.config/commit-ai
   cp configs/config.toml.example ~/.config/commit-ai/config.toml
   cp templates/default.txt ~/.config/commit-ai/default.txt
   ```

3. **Run tests to verify setup**
   ```bash
   make test
   # or
   go test ./...
   ```

### Development Workflow

1. **Create a feature branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```

2. **Make your changes**
   - Write code
   - Add tests
   - Update documentation

3. **Run development checks**
   ```bash
   make dev-test
   ```
   
   This runs:
   - Code formatting (`go fmt`)
   - Linting (`golangci-lint`)
   - Vetting (`go vet`)
   - Tests (`go test`)

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: add amazing feature"
   ```

5. **Push to your fork**
   ```bash
   git push origin feature/amazing-feature
   ```

6. **Create a Pull Request**

## Code Style

### General Guidelines

- Follow standard Go conventions
- Use meaningful variable and function names
- Write clear, concise comments
- Keep functions small and focused
- Handle errors appropriately

### Specific Rules

1. **Formatting**: Use `gofmt` and `gofumpt`
   ```bash
   make fmt
   ```

2. **Linting**: Pass all `golangci-lint` checks
   ```bash
   make lint
   ```

3. **Testing**: Maintain test coverage
   ```bash
   make test-coverage
   ```

4. **Documentation**: Comment exported functions and types
   ```go
   // Generator handles commit message generation using AI providers
   type Generator struct {
       config *config.Config
   }
   ```

### Commit Message Convention

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Types:**
- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation only changes
- `style`: Changes that do not affect the meaning of the code
- `refactor`: A code change that neither fixes a bug nor adds a feature
- `perf`: A code change that improves performance
- `test`: Adding missing tests or correcting existing tests
- `chore`: Changes to the build process or auxiliary tools

**Examples:**
```
feat: add support for custom AI providers
fix: handle empty git repository gracefully
docs: update installation instructions
test: add unit tests for config validation
```

## Testing

### Running Tests

```bash
# Run all tests
make test

# Run tests with coverage
make test-coverage

# Run specific package tests
go test ./internal/config

# Run tests with verbose output
go test -v ./...
```

### Writing Tests

1. **Test files**: Name test files `*_test.go`
2. **Test functions**: Start with `Test` prefix
3. **Table-driven tests**: Use for multiple test cases
4. **Mocking**: Use interfaces and dependency injection
5. **Test helpers**: Create helper functions for common setup

**Example:**
```go
func TestConfig_Validate(t *testing.T) {
    tests := []struct {
        name    string
        cfg     *Config
        wantErr bool
        errMsg  string
    }{
        {
            name:    "valid config",
            cfg:     DefaultConfig(),
            wantErr: false,
        },
        {
            name: "invalid provider",
            cfg: &Config{
                Provider: "invalid",
            },
            wantErr: true,
            errMsg:  "invalid provider",
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := tt.cfg.Validate()
            if tt.wantErr {
                require.Error(t, err)
                assert.Contains(t, err.Error(), tt.errMsg)
            } else {
                require.NoError(t, err)
            }
        })
    }
}
```

## Documentation

### Code Documentation

- Document all exported functions, types, and constants
- Use complete sentences
- Provide examples where helpful

### README Updates

When adding features:
- Update usage examples
- Add configuration options
- Update feature list
- Add troubleshooting entries if needed

### API Documentation

Generate and review documentation:
```bash
make docs
```

## Issue Reporting

### Bug Reports

Create a [bug report](https://github.com/nseba/commit-ai/issues/new?template=bug_report.md) with:

1. **Summary**: Brief description of the issue
2. **Environment**: OS, Go version, commit-ai version
3. **Steps to reproduce**: Exact steps to trigger the bug
4. **Expected behavior**: What should happen
5. **Actual behavior**: What actually happens
6. **Additional context**: Logs, screenshots, etc.

**Template:**
```markdown
## Bug Description
Brief description of the bug.

## Environment
- OS: [e.g., macOS 14.0, Ubuntu 22.04]
- Go version: [e.g., 1.21.0]
- commit-ai version: [e.g., v1.0.0]

## Steps to Reproduce
1. Step one
2. Step two
3. Step three

## Expected Behavior
Description of expected behavior.

## Actual Behavior
Description of actual behavior.

## Additional Context
Logs, configuration files, screenshots, etc.
```

### Feature Requests

Create a [feature request](https://github.com/nseba/commit-ai/issues/new?template=feature_request.md) with:

1. **Problem description**: What problem does this solve?
2. **Proposed solution**: How should it work?
3. **Alternatives considered**: Other approaches you've considered
4. **Additional context**: Examples, mockups, etc.

## Architecture Guidelines

### Project Structure

```
commit-ai/
├── cmd/                    # CLI entry point
├── internal/              # Private application code
│   ├── cli/              # CLI command handling
│   ├── config/           # Configuration management
│   ├── generator/        # AI message generation
│   └── git/              # Git operations
├── pkg/                   # Public packages (if any)
├── configs/              # Example configurations
├── templates/            # Example templates
└── docs/                 # Documentation
```

### Design Principles

1. **Single Responsibility**: Each package has one clear purpose
2. **Dependency Injection**: Use interfaces and inject dependencies
3. **Error Handling**: Handle errors gracefully with context
4. **Configuration**: Support both files and environment variables
5. **Testability**: Write testable code with clear interfaces

### Adding New Features

1. **Design First**: Open an issue to discuss the design
2. **Interface Design**: Define clear interfaces
3. **Implementation**: Implement with tests
4. **Documentation**: Update relevant documentation
5. **Examples**: Provide usage examples

## Release Process

Releases are automated via GitHub Actions:

1. **Version Tags**: Create semantic version tags (`v1.0.0`)
2. **Changelog**: Update `CHANGELOG.md`
3. **Release Notes**: Auto-generated from commits
4. **Binaries**: Built for multiple platforms
5. **Docker Images**: Published to Docker Hub

### Creating a Release

1. Update version information
2. Update `CHANGELOG.md`
3. Create and push a tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
4. GitHub Actions will handle the rest

## Community

### Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/). By participating, you agree to uphold this code.

### Getting Help

- 🐛 **Bugs**: [Create an issue](https://github.com/nseba/commit-ai/issues/new)
- 💡 **Feature Ideas**: [Start a discussion](https://github.com/nseba/commit-ai/discussions)
- ❓ **Questions**: [Ask in discussions](https://github.com/nseba/commit-ai/discussions)
- 💬 **Chat**: [Join our Discord](https://discord.gg/commit-ai) (if available)

### Recognition

Contributors will be recognized in:
- `CONTRIBUTORS.md` file
- Release notes for significant contributions
- GitHub contributors page

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Questions?

Don't hesitate to reach out! We're here to help and want to make contributing as easy as possible.

---

Thank you for contributing to Commit-AI! 🚀