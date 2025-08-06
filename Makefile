# Commit-AI Makefile
.PHONY: help build test clean install uninstall lint fmt vet deps docker run-example release

# Variables
BINARY_NAME=commit-ai
MAIN_PATH=./cmd
BUILD_DIR=dist
GO_FILES=$(shell find . -name '*.go' -not -path './vendor/*')
VERSION=$(shell git describe --tags --always --dirty)
LDFLAGS=-ldflags "-s -w -X main.version=$(VERSION)"

# Docker configuration
DOCKER_USERNAME ?= nseba
DOCKER_IMAGE_NAME = commit-ai
DOCKER_TAG ?= latest
DOCKER_FULL_NAME = $(DOCKER_USERNAME)/$(DOCKER_IMAGE_NAME):$(DOCKER_TAG)

# Default target
help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Development targets
deps: ## Download dependencies
	go mod download
	go mod tidy

fmt: ## Format Go code
	go fmt ./...

vet: ## Run go vet
	go vet ./...

lint: ## Run golangci-lint
	golangci-lint run --timeout=5m

test: ## Run tests
	go test -v -race -coverprofile=coverage.out ./...

test-coverage: test ## Run tests and show coverage
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

# Build targets
build: ## Build the binary
	mkdir -p $(BUILD_DIR)
	go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME) $(MAIN_PATH)

build-all: ## Build for all platforms
	mkdir -p $(BUILD_DIR)
	# Linux
	GOOS=linux GOARCH=amd64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-linux-amd64 $(MAIN_PATH)
	GOOS=linux GOARCH=arm64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-linux-arm64 $(MAIN_PATH)
	# macOS
	GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-darwin-amd64 $(MAIN_PATH)
	GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-darwin-arm64 $(MAIN_PATH)
	# Windows
	GOOS=windows GOARCH=amd64 go build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-windows-amd64.exe $(MAIN_PATH)

install: build ## Install the binary to $GOPATH/bin
	cp $(BUILD_DIR)/$(BINARY_NAME) $(shell go env GOPATH)/bin/$(BINARY_NAME)

uninstall: ## Remove the binary from $GOPATH/bin
	rm -f $(shell go env GOPATH)/bin/$(BINARY_NAME)

# Docker targets
docker-build: ## Build Docker image
	docker build -t $(DOCKER_FULL_NAME) .

docker-run: ## Run Docker container
	docker run --rm -it \
		-v $(PWD):/workspace \
		-v ~/.config/commit-ai:/home/appuser/.config/commit-ai \
		$(DOCKER_FULL_NAME)

docker-push: docker-build ## Push Docker image to registry
	@echo "Checking Docker login status..."
	@docker info >/dev/null 2>&1 || (echo "Error: Docker is not running" && exit 1)
	@if ! docker info 2>/dev/null | grep -q "Username:"; then \
		echo "Error: Not logged into Docker Hub. Please run 'docker login' first."; \
		exit 1; \
	fi
	@echo "Pushing $(DOCKER_FULL_NAME) to Docker Hub..."
	docker push $(DOCKER_FULL_NAME)

docker-status: ## Check Docker login status
	@echo "Docker version: $(shell docker --version)"
	@if docker info >/dev/null 2>&1; then \
		echo "✓ Docker is running"; \
		if docker info 2>/dev/null | grep -q "Username:"; then \
			echo "✓ Logged into Docker Hub as: $$(docker info 2>/dev/null | grep 'Username:' | cut -d' ' -f2)"; \
		else \
			echo "✗ Not logged into Docker Hub. Run 'docker login' to authenticate."; \
		fi; \
	else \
		echo "✗ Docker is not running"; \
	fi

docker-update-description: ## Update Docker Hub repository description from README
	@echo "Updating Docker Hub description for $(DOCKER_USERNAME)/$(DOCKER_IMAGE_NAME)..."
	@if [ -z "$(DOCKER_USERNAME)" ] || [ -z "$(DOCKER_PASSWORD)" ]; then \
		echo "Error: DOCKER_USERNAME and DOCKER_PASSWORD environment variables must be set"; \
		echo "Set them with: export DOCKER_USERNAME=your-username DOCKER_PASSWORD=your-token"; \
		exit 1; \
	fi
	./scripts/update-docker-description.sh

# Example and demo targets
setup-example: ## Set up example configuration
	mkdir -p ~/.config/commit-ai
	cp configs/config.toml.example ~/.config/commit-ai/config.toml
	cp templates/default.txt ~/.config/commit-ai/default.txt
	@echo "Example configuration created in ~/.config/commit-ai/"

run-example: build setup-example ## Build and run with example configuration
	./$(BUILD_DIR)/$(BINARY_NAME) --help
	@echo ""
	@echo "To test commit message generation, make some changes in a git repository and run:"
	@echo "./$(BUILD_DIR)/$(BINARY_NAME) [path-to-repo]"

# Release targets
release-prep: clean lint test build-all ## Prepare for release
	@echo "Release preparation complete. Binaries are in $(BUILD_DIR)/"

release-gh: ## Create GitHub release using gh CLI (requires gh CLI)
	@if ! command -v gh >/dev/null 2>&1; then \
		echo "Error: GitHub CLI (gh) is required for releases"; \
		exit 1; \
	fi
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: No version tag found"; \
		exit 1; \
	fi
	gh release create $(VERSION) $(BUILD_DIR)/* \
		--title "Release $(VERSION)" \
		--generate-notes

# Cleanup targets
clean: ## Clean build artifacts
	rm -rf $(BUILD_DIR)
	rm -f coverage.out coverage.html

clean-all: clean ## Clean everything including dependencies
	go clean -modcache

# Development workflow
dev-setup: deps setup-example ## Set up development environment
	@echo "Development environment set up successfully!"
	@echo "You can now run 'make run-example' to test the application."

dev-test: fmt vet lint test ## Run all development checks

# CI targets
ci: deps dev-test build ## Run CI pipeline locally

# Security
security-scan: ## Run security scan with gosec
	@if ! command -v gosec >/dev/null 2>&1; then \
		echo "Installing gosec..."; \
		go install github.com/securego/gosec/v2/cmd/gosec@latest; \
	fi
	gosec ./...

security-deps: ## Check for vulnerable dependencies
	@echo "Checking for vulnerable dependencies..."
	@if ! command -v govulncheck >/dev/null 2>&1; then \
		echo "Installing govulncheck..."; \
		go install golang.org/x/vuln/cmd/govulncheck@latest; \
	fi
	govulncheck ./...

security-all: security-scan security-deps ## Run all security checks
	@echo "All security checks completed"

security-update: ## Update dependencies for security fixes
	@echo "Updating dependencies..."
	go get -u all
	go mod tidy
	@echo "Dependencies updated. Please test and commit changes."

# Release targets
release-tag: ## Create and push a version tag (usage: make release-tag VERSION=v1.0.0)
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION is required. Usage: make release-tag VERSION=v1.0.0"; \
		exit 1; \
	fi
	@if ! echo "$(VERSION)" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$$'; then \
		echo "Error: Invalid version format. Use semantic versioning (e.g., v1.0.0)"; \
		exit 1; \
	fi
	@if git tag -l | grep -q "^$(VERSION)$$"; then \
		echo "Error: Tag $(VERSION) already exists locally"; \
		exit 1; \
	fi
	@echo "Creating and pushing release tag $(VERSION)..."
	@git tag $(VERSION) -m "Release $(VERSION)"
	@git push origin $(VERSION)
	@echo "✅ Release tag $(VERSION) created and pushed successfully!"
	@echo "🚀 GitHub Actions will now build and create the release"
	@echo "📊 Monitor progress at: https://github.com/$(DOCKER_USERNAME)/$(DOCKER_IMAGE_NAME)/actions"

release-delete-tag: ## Delete a version tag locally and remotely (usage: make release-delete-tag VERSION=v1.0.0)
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION is required. Usage: make release-delete-tag VERSION=v1.0.0"; \
		exit 1; \
	fi
	@echo "Deleting tag $(VERSION) locally and remotely..."
	@git tag -d $(VERSION) 2>/dev/null || echo "Tag $(VERSION) not found locally"
	@git push origin :refs/tags/$(VERSION) 2>/dev/null || echo "Tag $(VERSION) not found on remote"
	@echo "✅ Tag $(VERSION) deleted successfully"

release-manual: ## Create release manually using script (usage: make release-manual VERSION=v1.0.0)
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION is required. Usage: make release-manual VERSION=v1.0.0"; \
		exit 1; \
	fi
	@if [ ! -f "./scripts/create-release.sh" ]; then \
		echo "Error: Manual release script not found at ./scripts/create-release.sh"; \
		exit 1; \
	fi
	@echo "Creating release manually..."
	@./scripts/create-release.sh --version $(VERSION)

release-status: ## Check latest release status
	@echo "Checking release status..."
	@if command -v gh >/dev/null 2>&1; then \
		gh release list --limit 5; \
	else \
		echo "Install GitHub CLI (gh) to see release status"; \
		echo "Latest tags:"; \
		git tag --sort=-version:refname | head -5; \
	fi

release-check: ## Run comprehensive pre-release checks
	@echo "🔍 Running pre-release checks..."
	@echo ""
	@echo "1. Checking git status..."
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "❌ Working directory is not clean. Please commit or stash changes."; \
		exit 1; \
	fi
	@echo "✅ Working directory is clean"
	@echo ""
	@echo "2. Checking current branch..."
	@CURRENT_BRANCH=$$(git branch --show-current); \
	if [ "$$CURRENT_BRANCH" != "main" ]; then \
		echo "⚠️  Not on main branch (currently on: $$CURRENT_BRANCH)"; \
		echo "Continue? (y/N):"; \
		read -r CONTINUE; \
		if [ "$$CONTINUE" != "y" ] && [ "$$CONTINUE" != "Y" ]; then \
			exit 1; \
		fi; \
	fi
	@echo "✅ Branch check passed"
	@echo ""
	@echo "3. Running tests..."
	@$(MAKE) test
	@echo "✅ Tests passed"
	@echo ""
	@echo "4. Running security checks..."
	@$(MAKE) security-all
	@echo "✅ Security checks passed"
	@echo ""
	@echo "5. Testing build..."
	@$(MAKE) build
	@echo "✅ Build test passed"
	@echo ""
	@echo "🎉 All pre-release checks passed! Ready for release."

release: ## Create a full release with pre-checks (usage: make release VERSION=v1.0.0)
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION is required. Usage: make release VERSION=v1.0.0"; \
		exit 1; \
	fi
	@echo "🚀 Starting release process for $(VERSION)..."
	@echo ""
	@$(MAKE) release-check
	@echo ""
	@echo "📝 Creating release tag..."
	@$(MAKE) release-tag VERSION=$(VERSION)
	@echo ""
	@echo "✅ Release $(VERSION) initiated successfully!"
	@echo "📊 Monitor GitHub Actions: https://github.com/$(DOCKER_USERNAME)/$(DOCKER_IMAGE_NAME)/actions"
	@echo "📦 Release will be available at: https://github.com/$(DOCKER_USERNAME)/$(DOCKER_IMAGE_NAME)/releases/tag/$(VERSION)"

release-next-patch: ## Suggest next patch version (e.g., v1.0.0 -> v1.0.1)
	@LATEST_TAG=$$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0"); \
	if echo "$$LATEST_TAG" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$$'; then \
		MAJOR=$$(echo $$LATEST_TAG | sed 's/v\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1/'); \
		MINOR=$$(echo $$LATEST_TAG | sed 's/v\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\2/'); \
		PATCH=$$(echo $$LATEST_TAG | sed 's/v\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\3/'); \
		NEXT_PATCH=$$((PATCH + 1)); \
		NEXT_VERSION="v$$MAJOR.$$MINOR.$$NEXT_PATCH"; \
		echo "Current version: $$LATEST_TAG"; \
		echo "Suggested next patch: $$NEXT_VERSION"; \
		echo ""; \
		echo "To create patch release: make release VERSION=$$NEXT_VERSION"; \
	else \
		echo "Current version: $$LATEST_TAG"; \
		echo "Suggested first release: v1.0.0"; \
		echo ""; \
		echo "To create first release: make release VERSION=v1.0.0"; \
	fi

release-next-minor: ## Suggest next minor version (e.g., v1.0.0 -> v1.1.0)
	@LATEST_TAG=$$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0"); \
	if echo "$$LATEST_TAG" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$$'; then \
		MAJOR=$$(echo $$LATEST_TAG | sed 's/v\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1/'); \
		MINOR=$$(echo $$LATEST_TAG | sed 's/v\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\2/'); \
		NEXT_MINOR=$$((MINOR + 1)); \
		NEXT_VERSION="v$$MAJOR.$$NEXT_MINOR.0"; \
		echo "Current version: $$LATEST_TAG"; \
		echo "Suggested next minor: $$NEXT_VERSION"; \
		echo ""; \
		echo "To create minor release: make release VERSION=$$NEXT_VERSION"; \
	else \
		echo "Current version: $$LATEST_TAG"; \
		echo "Suggested first release: v1.0.0"; \
		echo ""; \
		echo "To create first release: make release VERSION=v1.0.0"; \
	fi

release-next-major: ## Suggest next major version (e.g., v1.0.0 -> v2.0.0)
	@LATEST_TAG=$$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0"); \
	if echo "$$LATEST_TAG" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$$'; then \
		MAJOR=$$(echo $$LATEST_TAG | sed 's/v\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1/'); \
		NEXT_MAJOR=$$((MAJOR + 1)); \
		NEXT_VERSION="v$$NEXT_MAJOR.0.0"; \
		echo "Current version: $$LATEST_TAG"; \
		echo "Suggested next major: $$NEXT_VERSION"; \
		echo ""; \
		echo "To create major release: make release VERSION=$$NEXT_VERSION"; \
	else \
		echo "Current version: $$LATEST_TAG"; \
		echo "Suggested first release: v1.0.0"; \
		echo ""; \
		echo "To create first release: make release VERSION=v1.0.0"; \
	fi

# Quick release shortcuts
release-patch: ## Create patch release with auto-version (alias for release with next patch)
	@LATEST_TAG=$$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0"); \
	if echo "$$LATEST_TAG" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$$'; then \
		MAJOR=$$(echo $$LATEST_TAG | sed 's/v\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1/'); \
		MINOR=$$(echo $$LATEST_TAG | sed 's/v\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\2/'); \
		PATCH=$$(echo $$LATEST_TAG | sed 's/v\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\3/'); \
		NEXT_PATCH=$$((PATCH + 1)); \
		NEXT_VERSION="v$$MAJOR.$$MINOR.$$NEXT_PATCH"; \
		$(MAKE) release VERSION=$$NEXT_VERSION; \
	else \
		$(MAKE) release VERSION=v1.0.0; \
	fi

release-minor: ## Create minor release with auto-version (alias for release with next minor)
	@LATEST_TAG=$$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0"); \
	if echo "$$LATEST_TAG" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$$'; then \
		MAJOR=$$(echo $$LATEST_TAG | sed 's/v\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1/'); \
		MINOR=$$(echo $$LATEST_TAG | sed 's/v\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\2/'); \
		NEXT_MINOR=$$((MINOR + 1)); \
		NEXT_VERSION="v$$MAJOR.$$NEXT_MINOR.0"; \
		$(MAKE) release VERSION=$$NEXT_VERSION; \
	else \
		$(MAKE) release VERSION=v1.0.0; \
	fi

release-major: ## Create major release with auto-version (alias for release with next major)
	@LATEST_TAG=$$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0"); \
	if echo "$$LATEST_TAG" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$$'; then \
		MAJOR=$$(echo $$LATEST_TAG | sed 's/v\([0-9]*\)\.\([0-9]*\)\.\([0-9]*\)/\1/'); \
		NEXT_MAJOR=$$((MAJOR + 1)); \
		NEXT_VERSION="v$$NEXT_MAJOR.0.0"; \
		$(MAKE) release VERSION=$$NEXT_VERSION; \
	else \
		$(MAKE) release VERSION=v1.0.0; \
	fi

# Documentation
docs: ## Generate documentation
	@echo "Generating documentation..."
	go doc ./...
	@echo "For detailed documentation, visit: https://github.com/nseba/commit-ai"

# Git hooks
install-hooks: ## Install git pre-commit hooks
	@echo "#!/bin/sh" > .git/hooks/pre-commit
	@echo "make dev-test" >> .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "Pre-commit hook installed. It will run 'make dev-test' before each commit."

# Benchmarks
bench: ## Run benchmarks
	go test -bench=. -benchmem ./...

# Profiling
profile-cpu: ## Generate CPU profile
	go test -cpuprofile=cpu.prof -bench=. ./...
	@echo "CPU profile generated: cpu.prof"
	@echo "View with: go tool pprof cpu.prof"

profile-mem: ## Generate memory profile
	go test -memprofile=mem.prof -bench=. ./...
	@echo "Memory profile generated: mem.prof"
	@echo "View with: go tool pprof mem.prof"

# Version information
version: ## Show version information
	@echo "Version: $(VERSION)"
	@echo "Go version: $(shell go version)"
	@echo "Git commit: $(shell git rev-parse HEAD)"
	@echo "Build date: $(shell date -u '+%Y-%m-%d %H:%M:%S UTC')"
