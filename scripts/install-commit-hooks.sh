#!/bin/bash

# Install Git Commit Hooks for commit-ai
# Automatically validates commit messages against conventional commit format

set -e

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

# Check if we're in a git repository
check_git_repo() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        print_error "Not in a git repository"
        exit 1
    fi
    print_success "Git repository detected"
}

# Install commit-msg hook
install_commit_msg_hook() {
    local hook_file=".git/hooks/commit-msg"

    print_info "Installing commit-msg hook..."

    cat > "$hook_file" << 'EOF'
#!/bin/bash

# Conventional Commit Message Validator Hook
# Validates commit messages against conventional commit format

# Get the commit message
commit_msg_file="$1"
commit_msg=$(cat "$commit_msg_file")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_error() {
    echo -e "${RED}✗ ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}✓ ${1}${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ ${1}${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${1}${NC}"
}

# Skip validation for merge commits, revert commits, and fixup commits
if echo "$commit_msg" | grep -qE "^(Merge|Revert|fixup!|squash!)"; then
    print_info "Skipping validation for special commit type"
    exit 0
fi

# Skip validation for initial commit
if echo "$commit_msg" | grep -qE "^(Initial commit|initial commit)"; then
    print_info "Skipping validation for initial commit"
    exit 0
fi

# Valid conventional commit types
VALID_TYPES="feat|fix|docs|style|refactor|test|chore|build|ci|perf|revert|security"

# Basic format validation: type(scope): description
if ! echo "$commit_msg" | grep -qE "^($VALID_TYPES)(\([^)]*\))?!?: .+"; then
    print_error "Invalid commit message format!"
    echo ""
    print_info "Conventional commit format:"
    echo "  <type>[optional scope]: <description>"
    echo ""
    print_info "Examples:"
    echo "  feat: add user authentication"
    echo "  feat(auth): add OAuth2 support"
    echo "  fix(api): resolve login endpoint bug"
    echo "  docs: update installation guide"
    echo "  feat!: change API response format (breaking)"
    echo ""
    print_info "Valid types: feat, fix, docs, style, refactor, test, chore, build, ci, perf, revert, security"
    echo ""
    print_warning "For more details, run: make validate-commit-msg MSG='your message'"
    exit 1
fi

# Extract components
type=$(echo "$commit_msg" | sed -E "s/^($VALID_TYPES)(\([^)]*\))?!?: .*/\1/")
description=$(echo "$commit_msg" | sed -E "s/^($VALID_TYPES)(\([^)]*\))?!?: (.*)$/\3/")

# Check subject length (should be <= 72 characters)
subject_length=${#commit_msg}
if [ $subject_length -gt 72 ]; then
    print_warning "Subject line is long ($subject_length chars, recommended max 72)"
fi

# Check if description starts with uppercase (warning, not error)
if [[ $description =~ ^[A-Z] ]]; then
    print_warning "Consider starting description with lowercase letter"
fi

# Check if description ends with period (warning, not error)
if [[ $description =~ \.$ ]]; then
    print_warning "Consider removing trailing period from description"
fi

print_success "Commit message follows conventional commit format"

# Check for breaking changes
if echo "$commit_msg" | grep -qE "^($VALID_TYPES)(\([^)]*\))?!:|BREAKING CHANGE"; then
    print_info "🚨 Breaking change detected"
fi

exit 0
EOF

    chmod +x "$hook_file"
    print_success "Commit-msg hook installed"
}

# Install pre-commit hook
install_pre_commit_hook() {
    local hook_file=".git/hooks/pre-commit"

    print_info "Installing pre-commit hook..."

    cat > "$hook_file" << 'EOF'
#!/bin/bash

# Pre-commit Hook for commit-ai
# Runs basic checks before allowing commit

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_error() {
    echo -e "${RED}✗ ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}✓ ${1}${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ ${1}${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${1}${NC}"
}

# Check if we're in the commit-ai repository
if [ -f "Makefile" ] && grep -q "commit-ai" Makefile 2>/dev/null; then
    print_info "Running pre-commit checks for commit-ai..."

    # Run Go formatting
    if command -v go >/dev/null 2>&1; then
        print_info "Checking Go formatting..."
        if ! go fmt ./...; then
            print_error "Go formatting failed"
            exit 1
        fi
        print_success "Go formatting passed"
    fi

    # Run basic build test if Go is available
    if command -v go >/dev/null 2>&1; then
        print_info "Testing build..."
        if ! go build -o /tmp/commit-ai-test ./cmd >/dev/null 2>&1; then
            print_error "Build test failed"
            exit 1
        fi
        rm -f /tmp/commit-ai-test
        print_success "Build test passed"
    fi

    print_success "Pre-commit checks passed"
else
    print_info "Basic pre-commit hook (not in commit-ai repository)"
fi

exit 0
EOF

    chmod +x "$hook_file"
    print_success "Pre-commit hook installed"
}

# Install prepare-commit-msg hook
install_prepare_commit_msg_hook() {
    local hook_file=".git/hooks/prepare-commit-msg"

    print_info "Installing prepare-commit-msg hook..."

    cat > "$hook_file" << 'EOF'
#!/bin/bash

# Prepare Commit Message Hook for commit-ai
# Provides template and suggestions for conventional commits

commit_file="$1"
commit_source="$2"

# Only add template for regular commits (not merge, revert, etc.)
if [ "$commit_source" != "merge" ] && [ "$commit_source" != "squash" ] && [ "$commit_source" != "commit" ]; then
    # Check if commit message is empty or just has comments
    if ! grep -qvE '^#' "$commit_file" 2>/dev/null || [ ! -s "$commit_file" ]; then
        # Add conventional commit template
        cat > "$commit_file" << 'TEMPLATE'
# <type>[optional scope]: <description>
#
# [optional body]
#
# [optional footer(s)]
#
# Types:
#   feat:     A new feature
#   fix:      A bug fix
#   docs:     Documentation only changes
#   style:    Formatting, missing semi colons, etc
#   refactor: Code change that neither fixes a bug nor adds a feature
#   perf:     Code change that improves performance
#   test:     Adding missing tests or correcting existing tests
#   build:    Changes that affect the build system
#   ci:       Changes to CI configuration files and scripts
#   chore:    Other changes that don't modify src or test files
#   revert:   Reverts a previous commit
#   security: Security related fixes
#
# Breaking Changes:
#   feat!: description (with !)
#   or add "BREAKING CHANGE:" in footer
#
# Examples:
#   feat: add user authentication
#   feat(auth): add OAuth2 support
#   fix(api): resolve login endpoint bug
#   docs: update installation guide
#   feat!: change API response format
#
# Remember:
#   - Use lowercase for description
#   - Don't end with period
#   - Keep first line under 72 characters
#   - Separate body with blank line
TEMPLATE
    fi
fi
EOF

    chmod +x "$hook_file"
    print_success "Prepare-commit-msg hook installed"
}

# Install commit template
install_commit_template() {
    local template_file=".gitmessage"

    print_info "Installing git commit template..."

    cat > "$template_file" << 'EOF'
# <type>[optional scope]: <description>
#
# [optional body]
#
# [optional footer(s)]
#
# Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert, security
# Breaking changes: Add ! after type or BREAKING CHANGE: in footer
#
# Examples:
#   feat: add user authentication
#   fix(api): resolve login bug
#   docs: update README
#   feat!: change API format
EOF

    # Set git to use the template
    git config commit.template "$template_file"
    print_success "Git commit template configured"
}

# Uninstall hooks
uninstall_hooks() {
    print_info "Uninstalling git hooks..."

    local hooks=("commit-msg" "pre-commit" "prepare-commit-msg")

    for hook in "${hooks[@]}"; do
        local hook_file=".git/hooks/$hook"
        if [ -f "$hook_file" ]; then
            rm "$hook_file"
            print_success "Removed $hook hook"
        fi
    done

    # Remove commit template
    if [ -f ".gitmessage" ]; then
        rm ".gitmessage"
        git config --unset commit.template 2>/dev/null || true
        print_success "Removed commit template"
    fi

    print_success "All hooks uninstalled"
}

# Show current hook status
show_status() {
    print_info "Git hooks status:"
    echo ""

    local hooks=("commit-msg" "pre-commit" "prepare-commit-msg")

    for hook in "${hooks[@]}"; do
        local hook_file=".git/hooks/$hook"
        if [ -f "$hook_file" ] && [ -x "$hook_file" ]; then
            print_success "$hook hook: installed"
        else
            print_warning "$hook hook: not installed"
        fi
    done

    echo ""
    if [ -f ".gitmessage" ]; then
        print_success "Commit template: configured"
    else
        print_warning "Commit template: not configured"
    fi

    echo ""
    local template_config=$(git config --get commit.template 2>/dev/null || echo "")
    if [ -n "$template_config" ]; then
        print_info "Template file: $template_config"
    fi
}

# Show help
show_help() {
    cat << EOF
Git Commit Hooks Installer for commit-ai

USAGE:
    $0 <command>

COMMANDS:
    install     Install all git hooks and commit template
    uninstall   Remove all git hooks and commit template
    status      Show current installation status
    help        Show this help message

HOOKS INSTALLED:
    commit-msg           Validates commit message format
    pre-commit           Runs basic checks before commit
    prepare-commit-msg   Provides commit message template

FEATURES:
    ✓ Validates conventional commit format
    ✓ Provides helpful error messages
    ✓ Runs basic build checks
    ✓ Adds commit message template
    ✓ Skips validation for merge/revert commits

EXAMPLES:
    $0 install          # Install all hooks
    $0 status           # Check installation status
    $0 uninstall        # Remove all hooks

After installation, all commits will be validated automatically.
Use 'git commit --no-verify' to skip validation if needed.

EOF
}

# Main function
main() {
    case "${1:-help}" in
        "install")
            check_git_repo
            print_info "Installing git commit hooks for commit-ai..."
            echo ""
            install_commit_msg_hook
            install_pre_commit_hook
            install_prepare_commit_msg_hook
            install_commit_template
            echo ""
            print_success "🎉 All git hooks installed successfully!"
            echo ""
            print_info "Your commits will now be automatically validated."
            print_info "Use 'git commit --no-verify' to skip validation if needed."
            print_info "Run '$0 status' to check installation status."
            ;;
        "uninstall")
            check_git_repo
            uninstall_hooks
            ;;
        "status")
            check_git_repo
            show_status
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown command: ${1}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
