#!/bin/bash
# Setup verification script for Commit-AI
# This script verifies that the project is properly set up and working

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_header() {
    echo -e "${BLUE}$1${NC}"
}

print_info() {
    echo -e "${BLUE}[ℹ]${NC} $1"
}

# Check if we're in the correct directory
check_project_structure() {
    print_header "📁 Checking Project Structure"

    local required_files=(
        "go.mod"
        "cmd/main.go"
        "internal/cli/root.go"
        "internal/config/config.go"
        "internal/generator/generator.go"
        "internal/git/repository.go"
        "Makefile"
        "README.md"
    )

    local missing_files=()

    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            print_status "Found $file"
        else
            print_error "Missing $file"
            missing_files+=("$file")
        fi
    done

    if [ ${#missing_files[@]} -eq 0 ]; then
        print_status "All required files are present"
    else
        print_error "Missing ${#missing_files[@]} required files"
        return 1
    fi
}

# Check Go version and dependencies
check_go_environment() {
    print_header "🔧 Checking Go Environment"

    if ! command -v go >/dev/null 2>&1; then
        print_error "Go is not installed"
        return 1
    fi

    local go_version=$(go version | cut -d' ' -f3)
    print_status "Go version: $go_version"

    # Check if go.mod is valid
    if go mod verify >/dev/null 2>&1; then
        print_status "Go module verification passed"
    else
        print_error "Go module verification failed"
        return 1
    fi

    # Check dependencies
    print_info "Downloading dependencies..."
    if go mod download >/dev/null 2>&1; then
        print_status "Dependencies downloaded successfully"
    else
        print_error "Failed to download dependencies"
        return 1
    fi
}

# Run tests
run_tests() {
    print_header "🧪 Running Tests"

    print_info "Running unit tests..."
    if go test ./... >/dev/null 2>&1; then
        print_status "All tests passed"
    else
        print_error "Some tests failed"
        print_info "Running tests with verbose output:"
        go test -v ./...
        return 1
    fi

    # Generate coverage report
    print_info "Generating coverage report..."
    if go test -coverprofile=coverage.out ./... >/dev/null 2>&1; then
        local coverage=$(go tool cover -func=coverage.out | grep total | awk '{print $3}')
        print_status "Test coverage: $coverage"

        local coverage_num=$(echo "${coverage%\%}" | cut -d'.' -f1)
        if [[ "$coverage_num" -gt "80" ]]; then
            print_status "Coverage is above 80%"
        else
            print_warning "Coverage is below 80%"
        fi
    else
        print_warning "Could not generate coverage report"
    fi
}

# Build the application
build_application() {
    print_header "🏗️ Building Application"

    print_info "Building commit-ai binary..."
    if go build -o commit-ai ./cmd >/dev/null 2>&1; then
        print_status "Build successful"
    else
        print_error "Build failed"
        return 1
    fi

    # Verify binary works
    if [ -f "./commit-ai" ]; then
        print_info "Testing binary..."
        if ./commit-ai --help >/dev/null 2>&1; then
            print_status "Binary is functional"
        else
            print_error "Binary is not working correctly"
            return 1
        fi

        # Test version command
        local version_output=$(./commit-ai version 2>/dev/null)
        if [[ $? -eq 0 ]]; then
            print_status "Version command works: $version_output"
        else
            print_error "Version command failed"
            return 1
        fi
    else
        print_error "Binary was not created"
        return 1
    fi
}

# Check linting (if golangci-lint is available)
check_linting() {
    print_header "🔍 Checking Code Quality"

    if command -v golangci-lint >/dev/null 2>&1; then
        print_info "Running golangci-lint..."
        if golangci-lint run --timeout=5m >/dev/null 2>&1; then
            print_status "Linting passed"
        else
            print_warning "Linting issues found (run 'make lint' for details)"
        fi
    else
        print_warning "golangci-lint not installed, skipping linting check"
        print_info "Install with: go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest"
    fi

    # Check formatting
    print_info "Checking code formatting..."
    local unformatted=$(go fmt ./... 2>&1)
    if [ -z "$unformatted" ]; then
        print_status "Code is properly formatted"
    else
        print_warning "Some files need formatting"
        echo "$unformatted"
    fi
}

# Check Docker setup (if Docker is available)
check_docker_setup() {
    print_header "🐳 Checking Docker Setup"

    if command -v docker >/dev/null 2>&1; then
        print_status "Docker is installed"

        # Check if Dockerfile exists and can be built
        if [ -f "Dockerfile" ]; then
            print_info "Testing Docker build..."
            if docker build -t commit-ai-test . >/dev/null 2>&1; then
                print_status "Docker build successful"

                # Clean up test image
                docker rmi commit-ai-test >/dev/null 2>&1 || true
            else
                print_warning "Docker build failed"
            fi
        else
            print_warning "Dockerfile not found"
        fi

        # Check docker-compose setup
        if [ -f "docker-compose.yml" ]; then
            print_status "Docker Compose file found"

            if command -v docker-compose >/dev/null 2>&1; then
                print_status "Docker Compose is installed"
            else
                print_warning "Docker Compose not installed"
            fi
        else
            print_warning "docker-compose.yml not found"
        fi
    else
        print_warning "Docker not installed, skipping Docker checks"
    fi
}

# Check documentation
check_documentation() {
    print_header "📚 Checking Documentation"

    local doc_files=(
        "README.md"
        "CONTRIBUTING.md"
        "SECURITY.md"
        "CHANGELOG.md"
        "LICENSE"
    )

    for doc in "${doc_files[@]}"; do
        if [ -f "$doc" ]; then
            local word_count=$(wc -w < "$doc" 2>/dev/null || echo "0")
            if [ "$word_count" -gt "100" ]; then
                print_status "$doc exists and is comprehensive ($word_count words)"
            else
                print_warning "$doc exists but may be incomplete ($word_count words)"
            fi
        else
            print_warning "$doc is missing"
        fi
    done

    # Check for example files
    local example_files=(
        "configs/config.toml.example"
        "templates/default.txt"
        ".caiignore.example"
    )

    for example in "${example_files[@]}"; do
        if [ -f "$example" ]; then
            print_status "Example file found: $example"
        else
            print_warning "Example file missing: $example"
        fi
    done
}

# Check CI/CD setup
check_cicd_setup() {
    print_header "🚀 Checking CI/CD Setup"

    if [ -f ".github/workflows/ci.yml" ]; then
        print_status "GitHub Actions CI workflow found"
    else
        print_warning "GitHub Actions CI workflow not found"
    fi

    if [ -f ".github/pull_request_template.md" ]; then
        print_status "Pull request template found"
    else
        print_warning "Pull request template not found"
    fi

    local issue_templates_dir=".github/ISSUE_TEMPLATE"
    if [ -d "$issue_templates_dir" ]; then
        local template_count=$(find "$issue_templates_dir" -name "*.md" -o -name "*.yml" | wc -l)
        print_status "Issue templates found: $template_count"
    else
        print_warning "Issue templates directory not found"
    fi
}

# Verify installation scripts
check_installation_scripts() {
    print_header "📦 Checking Installation Scripts"

    if [ -f "install.sh" ]; then
        if [ -x "install.sh" ]; then
            print_status "Installation script exists and is executable"
        else
            print_warning "Installation script exists but is not executable"
        fi
    else
        print_warning "Installation script not found"
    fi

    if [ -f "scripts/docker-setup.sh" ]; then
        if [ -x "scripts/docker-setup.sh" ]; then
            print_status "Docker setup script exists and is executable"
        else
            print_warning "Docker setup script exists but is not executable"
        fi
    else
        print_warning "Docker setup script not found"
    fi

    if [ -f "Makefile" ]; then
        print_status "Makefile found"

        # Check for common make targets
        local targets=("build" "test" "lint" "clean")
        for target in "${targets[@]}"; do
            if grep -q "^$target:" Makefile; then
                print_status "Make target '$target' available"
            else
                print_warning "Make target '$target' not found"
            fi
        done
    else
        print_warning "Makefile not found"
    fi
}

# Generate summary report
generate_summary() {
    print_header "📊 Setup Verification Summary"

    local total_checks=0
    local passed_checks=0
    local failed_checks=0
    local warning_checks=0

    # This is a simple way to count checks - in a real implementation,
    # you'd want to track the results more precisely
    echo ""
    print_info "Verification completed!"
    echo ""
    print_info "Next steps:"
    echo "  1. Fix any errors or warnings shown above"
    echo "  2. Run 'make ci' to verify everything works"
    echo "  3. Test the application with 'make run-example'"
    echo "  4. Read the README.md for usage instructions"
    echo ""
    print_info "For development:"
    echo "  - Use 'make dev-setup' to set up development environment"
    echo "  - Use 'make test' to run tests"
    echo "  - Use 'make lint' to check code quality"
    echo "  - Use 'scripts/docker-setup.sh start-dev' for Docker development"
    echo ""
    print_status "Setup verification completed!"
}

# Main execution
main() {
    print_header "🔍 Commit-AI Setup Verification"
    print_header "================================"
    echo ""

    local failed=0

    # Run all checks
    check_project_structure || ((failed++))
    echo ""

    check_go_environment || ((failed++))
    echo ""

    run_tests || ((failed++))
    echo ""

    build_application || ((failed++))
    echo ""

    check_linting
    echo ""

    check_docker_setup
    echo ""

    check_documentation
    echo ""

    check_cicd_setup
    echo ""

    check_installation_scripts
    echo ""

    generate_summary

    if [ $failed -eq 0 ]; then
        print_status "All critical checks passed! 🎉"
        exit 0
    else
        print_error "$failed critical checks failed"
        exit 1
    fi
}

# Handle command line arguments
case "${1:-}" in
    "help"|"--help"|"-h")
        echo "Commit-AI Setup Verification Script"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  help        Show this help message"
        echo "  quick       Run only critical checks"
        echo "  full        Run all checks (default)"
        echo ""
        echo "This script verifies that the Commit-AI project is properly set up"
        echo "and all components are working correctly."
        exit 0
        ;;
    "quick")
        print_header "🚀 Quick Verification"
        check_project_structure
        check_go_environment
        run_tests
        build_application
        print_status "Quick verification completed!"
        exit 0
        ;;
    "full"|"")
        main
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
