#!/bin/bash

# Manual Release Script for commit-ai
# This script creates a GitHub release manually when the automated pipeline fails

set -e

# Configuration
REPO_OWNER="nseba"
REPO_NAME="commit-ai"
BINARY_NAME="commit-ai"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}✓ ${1}${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${1}${NC}"
}

print_error() {
    echo -e "${RED}✗ ${1}${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."

    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        print_error "Not in a git repository"
        exit 1
    fi

    # Check if gh CLI is installed
    if ! command_exists gh; then
        print_error "GitHub CLI (gh) is not installed"
        print_info "Install it from: https://cli.github.com/"
        print_info "Or use: brew install gh (macOS), apt install gh (Ubuntu)"
        exit 1
    fi

    # Check if logged into gh
    if ! gh auth status >/dev/null 2>&1; then
        print_error "Not logged into GitHub CLI"
        print_info "Run: gh auth login"
        exit 1
    fi

    # Check if Go is installed
    if ! command_exists go; then
        print_error "Go is not installed"
        exit 1
    fi

    print_success "Prerequisites check passed"
}

# Get version from command line or prompt
get_version() {
    if [ -n "$1" ]; then
        VERSION="$1"
    else
        echo "Enter version (e.g., v1.0.0):"
        read -r VERSION
    fi

    # Validate version format
    if ! echo "$VERSION" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$'; then
        print_error "Invalid version format. Use semantic versioning (e.g., v1.0.0)"
        exit 1
    fi

    print_info "Version: $VERSION"
}

# Check if version already exists
check_version_exists() {
    if git tag -l | grep -q "^$VERSION$"; then
        print_error "Version $VERSION already exists locally"
        print_info "Delete it with: git tag -d $VERSION"
        exit 1
    fi

    if gh release view "$VERSION" >/dev/null 2>&1; then
        print_error "Release $VERSION already exists on GitHub"
        exit 1
    fi

    print_success "Version $VERSION is available"
}

# Run pre-release checks
run_checks() {
    print_info "Running pre-release checks..."

    # Check working directory is clean
    if ! git diff-index --quiet HEAD --; then
        print_error "Working directory is not clean. Commit or stash changes first."
        exit 1
    fi

    # Ensure we're on main branch
    CURRENT_BRANCH=$(git branch --show-current)
    if [ "$CURRENT_BRANCH" != "main" ]; then
        print_warning "Not on main branch (currently on: $CURRENT_BRANCH)"
        echo "Continue anyway? (y/N)"
        read -r CONTINUE
        if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
            exit 1
        fi
    fi

    # Run tests
    print_info "Running tests..."
    if ! go test ./...; then
        print_error "Tests failed"
        exit 1
    fi

    # Run security check
    print_info "Running security checks..."
    if command_exists govulncheck; then
        if ! govulncheck ./...; then
            print_error "Security vulnerabilities found"
            exit 1
        fi
    else
        print_warning "govulncheck not found, skipping vulnerability check"
    fi

    # Test build
    print_info "Testing build..."
    if ! go build -o "/tmp/${BINARY_NAME}-test" ./cmd; then
        print_error "Build failed"
        exit 1
    fi
    rm -f "/tmp/${BINARY_NAME}-test"

    print_success "Pre-release checks passed"
}

# Build multi-platform binaries
build_binaries() {
    print_info "Building multi-platform binaries..."

    BUILD_DIR="./release-build"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"

    # Define platforms
    declare -a platforms=(
        "linux/amd64"
        "linux/arm64"
        "darwin/amd64"
        "darwin/arm64"
        "windows/amd64"
    )

    # Build for each platform
    for platform in "${platforms[@]}"; do
        IFS='/' read -r GOOS GOARCH <<< "$platform"

        output_name="${BINARY_NAME}-${GOOS}-${GOARCH}"
        if [ "$GOOS" = "windows" ]; then
            output_name="${output_name}.exe"
        fi

        print_info "Building for $GOOS/$GOARCH..."

        env GOOS="$GOOS" GOARCH="$GOARCH" go build \
            -ldflags="-s -w -X main.version=${VERSION#v}" \
            -o "${BUILD_DIR}/${output_name}" \
            ./cmd

        if [ $? -ne 0 ]; then
            print_error "Failed to build for $GOOS/$GOARCH"
            exit 1
        fi
    done

    print_success "Built binaries for all platforms"
    ls -la "$BUILD_DIR"
}

# Generate changelog
generate_changelog() {
    print_info "Generating changelog..."

    # Get previous tag
    PREV_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")

    if [ -n "$PREV_TAG" ]; then
        CHANGELOG_RANGE="${PREV_TAG}..HEAD"
        print_info "Generating changelog from $PREV_TAG to HEAD"
    else
        CHANGELOG_RANGE="HEAD"
        print_info "Generating changelog for all commits (no previous tag found)"
    fi

    # Generate changelog
    cat > RELEASE_NOTES.md << EOF
# Release $VERSION

## What's Changed

$(git log --pretty=format:"* %s (%h)" "$CHANGELOG_RANGE")

## Security

This release includes all the latest security fixes:
- Updated Go to 1.24.4 with standard library security fixes
- Updated go-git to v5.16.2 (fixes argument injection)
- Updated golang.org/x/crypto to v0.40.0 (fixes SSH vulnerabilities)
- Updated all dependencies to secure versions

## Installation

### Download Binary
Download the appropriate binary for your platform from the assets below.

### Using Go
\`\`\`bash
go install github.com/nseba/commit-ai/cmd@$VERSION
\`\`\`

### Using Docker
\`\`\`bash
docker pull nseba/commit-ai:$VERSION
\`\`\`

### Using Homebrew (if available)
\`\`\`bash
brew tap nseba/tools
brew install commit-ai
\`\`\`

## Full Changelog
**Full Changelog**: https://github.com/$REPO_OWNER/$REPO_NAME/compare/${PREV_TAG:-$(git rev-list --max-parents=0 HEAD)}...$VERSION
EOF

    print_success "Changelog generated"
}

# Create git tag
create_tag() {
    print_info "Creating git tag $VERSION..."

    git tag "$VERSION" -m "Release $VERSION

This release includes:
- Security fixes for multiple vulnerabilities
- Multi-platform binary builds
- Docker support with multi-architecture images
- Comprehensive testing and validation

See release notes for full details."

    print_success "Created git tag $VERSION"
}

# Create GitHub release
create_github_release() {
    print_info "Creating GitHub release..."

    # Push tag first
    print_info "Pushing tag to GitHub..."
    git push origin "$VERSION"

    # Create release with binaries
    print_info "Creating release with assets..."
    gh release create "$VERSION" \
        --title "Release $VERSION" \
        --notes-file RELEASE_NOTES.md \
        ./release-build/* \
        --verify-tag

    if [ $? -eq 0 ]; then
        print_success "GitHub release created successfully!"
        print_info "Release URL: https://github.com/$REPO_OWNER/$REPO_NAME/releases/tag/$VERSION"
    else
        print_error "Failed to create GitHub release"
        exit 1
    fi
}

# Cleanup
cleanup() {
    print_info "Cleaning up..."
    rm -rf ./release-build
    rm -f RELEASE_NOTES.md
    print_success "Cleanup completed"
}

# Main function
main() {
    echo "=================================================="
    echo "        Commit-AI Manual Release Script"
    echo "=================================================="
    echo

    # Parse command line arguments
    VERSION=""
    SKIP_CHECKS=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                VERSION="$2"
                shift 2
                ;;
            --skip-checks)
                SKIP_CHECKS=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--version VERSION] [--skip-checks] [--help]"
                echo ""
                echo "Options:"
                echo "  --version VERSION    Specify version (e.g., v1.0.0)"
                echo "  --skip-checks        Skip pre-release checks"
                echo "  --help, -h           Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0 --version v1.0.0"
                echo "  $0 --version v1.0.0 --skip-checks"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Run the release process
    check_prerequisites
    get_version "$VERSION"
    check_version_exists

    if [ "$SKIP_CHECKS" != "true" ]; then
        run_checks
    else
        print_warning "Skipping pre-release checks"
    fi

    build_binaries
    generate_changelog
    create_tag
    create_github_release
    cleanup

    echo
    print_success "Release $VERSION completed successfully! 🎉"
    echo
    print_info "Next steps:"
    print_info "1. Check the release: https://github.com/$REPO_OWNER/$REPO_NAME/releases/tag/$VERSION"
    print_info "2. Update any documentation or announcements"
    print_info "3. Test the release binaries"
    echo
}

# Run main function with all arguments
main "$@"
