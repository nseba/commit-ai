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

release: ## Create GitHub release (requires gh CLI)
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
		go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest; \
	fi
	gosec ./...

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
