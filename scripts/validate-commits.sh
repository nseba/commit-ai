#!/bin/bash

# Conventional Commit Validator for commit-ai
# Validates commit messages against conventional commit format
# and provides suggestions for improvement

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

print_header() {
    echo -e "${PURPLE}${1}${NC}"
}

print_suggestion() {
    echo -e "${CYAN}💡 ${1}${NC}"
}

# Conventional commit types
VALID_TYPES=(
    "feat"      # New feature
    "fix"       # Bug fix
    "docs"      # Documentation
    "style"     # Formatting, missing semi colons, etc; no code change
    "refactor"  # Refactoring production code
    "test"      # Adding tests, refactoring test; no production code change
    "chore"     # Updating build tasks, package manager configs, etc
    "build"     # Changes that affect the build system
    "ci"        # Changes to CI configuration files and scripts
    "perf"      # Performance improvements
    "revert"    # Revert previous commit
    "security"  # Security fixes
)

# Validate single commit message
validate_commit_message() {
    local commit_msg="$1"
    local is_valid=true
    local suggestions=()

    print_info "Validating: $commit_msg"
    echo ""

    # Check basic format: type(scope): description
    if ! echo "$commit_msg" | grep -qE "^[a-z]+(\([^)]*\))?!?: .+"; then
        print_error "Invalid format"
        suggestions+=("Use format: type(scope): description")
        suggestions+=("Example: feat(api): add user authentication")
        is_valid=false
    else
        print_success "Basic format is correct"
    fi

    # Extract type
    local type
    type=$(echo "$commit_msg" | sed -E 's/^([a-z]+)(\([^)]*\))?!?: .*/\1/')

    # Check if type is valid
    local type_valid=false
    for valid_type in "${VALID_TYPES[@]}"; do
        if [ "$type" = "$valid_type" ]; then
            type_valid=true
            break
        fi
    done

    if [ "$type_valid" = true ]; then
        print_success "Type '$type' is valid"
    else
        print_error "Invalid type '$type'"
        suggestions+=("Valid types: ${VALID_TYPES[*]}")
        is_valid=false
    fi

    # Check subject length (should be <= 72 characters)
    local subject_length=${#commit_msg}
    if [ $subject_length -gt 72 ]; then
        print_warning "Subject is too long ($subject_length chars, max 72)"
        suggestions+=("Keep subject line under 72 characters")
        is_valid=false
    else
        print_success "Subject length is good ($subject_length chars)"
    fi

    # Check if subject starts with lowercase
    local description
    description=$(echo "$commit_msg" | sed -E 's/^[a-z]+(\([^)]*\))?!?: (.*)$/\2/')
    if [[ $description =~ ^[A-Z] ]]; then
        print_warning "Description should start with lowercase"
        suggestions+=("Use lowercase for description: '${description,}'")
    else
        print_success "Description starts with lowercase"
    fi

    # Check if subject ends with period
    if [[ $description =~ \.$ ]]; then
        print_warning "Description should not end with period"
        suggestions+=("Remove trailing period from description")
    else
        print_success "Description doesn't end with period"
    fi

    # Check for breaking changes
    if echo "$commit_msg" | grep -qE "^[a-z]+(\([^)]*\))?!:|BREAKING CHANGE"; then
        print_info "🚨 Breaking change detected"
    fi

    # Provide suggestions
    if [ ${#suggestions[@]} -gt 0 ]; then
        echo ""
        print_header "💡 Suggestions:"
        for suggestion in "${suggestions[@]}"; do
            print_suggestion "$suggestion"
        done
    fi

    echo ""
    if [ "$is_valid" = true ]; then
        print_success "✨ Commit message is valid!"
        return 0
    else
        print_error "❌ Commit message needs improvement"
        return 1
    fi
}

# Validate commit range
validate_commit_range() {
    local from_ref="$1"
    local to_ref="${2:-HEAD}"
    local total_commits=0
    local valid_commits=0
    local invalid_commits=0

    print_header "🔍 Validating commits from $from_ref to $to_ref"
    echo ""

    # Get commits in range
    local commits
    if [ "$from_ref" = "HEAD" ] || [ "$from_ref" = "" ]; then
        # Just validate the last commit
        commits=$(git log -1 --pretty=format:"%s")
        total_commits=1
    elif [ "$from_ref" = "all" ]; then
        # Validate all commits
        commits=$(git log --pretty=format:"%s")
        total_commits=$(git log --oneline | wc -l)
    else
        # Validate commit range
        commits=$(git log --pretty=format:"%s" "$from_ref..$to_ref")
        total_commits=$(git log --oneline "$from_ref..$to_ref" | wc -l)
    fi

    if [ -z "$commits" ]; then
        print_warning "No commits found in range"
        return 0
    fi

    # Validate each commit
    while IFS= read -r commit_msg; do
        echo "----------------------------------------"
        if validate_commit_message "$commit_msg"; then
            ((valid_commits++))
        else
            ((invalid_commits++))
        fi
        echo ""
    done <<< "$commits"

    # Summary
    print_header "📊 Validation Summary"
    echo ""
    print_info "Total commits: $total_commits"
    print_success "Valid commits: $valid_commits"
    if [ $invalid_commits -gt 0 ]; then
        print_error "Invalid commits: $invalid_commits"
    else
        print_success "Invalid commits: $invalid_commits"
    fi

    # Calculate percentage
    local percentage=0
    if [ $total_commits -gt 0 ]; then
        percentage=$((valid_commits * 100 / total_commits))
    fi

    echo ""
    if [ $invalid_commits -eq 0 ]; then
        print_success "🎉 All commits follow conventional commit format! ($percentage%)"
        return 0
    else
        print_error "⚠️  Some commits need improvement ($percentage% valid)"
        return 1
    fi
}

# Generate commit message suggestions
suggest_commit_message() {
    local type="$1"
    local scope="$2"
    local description="$3"

    print_header "💡 Commit Message Suggestions"
    echo ""

    if [ -z "$type" ] || [ -z "$description" ]; then
        print_info "Usage: $0 suggest <type> [scope] <description>"
        echo ""
        print_info "Examples:"
        print_suggestion "$0 suggest feat user 'add login functionality'"
        print_suggestion "$0 suggest fix api 'resolve authentication bug'"
        print_suggestion "$0 suggest docs '' 'update installation guide'"
        echo ""
        print_info "Valid types: ${VALID_TYPES[*]}"
        return 1
    fi

    # Validate type
    local type_valid=false
    for valid_type in "${VALID_TYPES[@]}"; do
        if [ "$type" = "$valid_type" ]; then
            type_valid=true
            break
        fi
    done

    if [ "$type_valid" != true ]; then
        print_error "Invalid type '$type'"
        print_info "Valid types: ${VALID_TYPES[*]}"
        return 1
    fi

    # Generate suggestions
    local base_format="$type"
    if [ -n "$scope" ] && [ "$scope" != "''" ] && [ "$scope" != '""' ]; then
        base_format="$type($scope)"
    fi

    # Ensure description is lowercase and doesn't end with period
    description=$(echo "$description" | sed 's/^./\L&/' | sed 's/\.$//')

    echo "Suggested commit messages:"
    echo ""
    print_success "Standard: $base_format: $description"
    print_success "Breaking: $base_format!: $description"
    echo ""

    # Provide examples based on type
    case "$type" in
        "feat")
            print_info "Examples for 'feat':"
            print_suggestion "feat(auth): add OAuth2 authentication"
            print_suggestion "feat(api): implement user profile endpoints"
            print_suggestion "feat!: change API response format"
            ;;
        "fix")
            print_info "Examples for 'fix':"
            print_suggestion "fix(auth): resolve token expiration issue"
            print_suggestion "fix(ui): correct button alignment on mobile"
            print_suggestion "fix!: change default configuration format"
            ;;
        "docs")
            print_info "Examples for 'docs':"
            print_suggestion "docs: update installation instructions"
            print_suggestion "docs(api): add authentication examples"
            print_suggestion "docs(readme): fix typos and formatting"
            ;;
        *)
            print_info "Format: $type(scope): description"
            print_info "Use '!' for breaking changes: $type!: description"
            ;;
    esac
}

# Show help
show_help() {
    cat << EOF
Conventional Commit Validator - Validate and suggest commit messages

USAGE:
    $0 <command> [options]

COMMANDS:
    validate [commit-msg]       Validate a specific commit message
    range [from] [to]          Validate commits in a range
    last                       Validate the last commit
    all                        Validate all commits in repository
    suggest <type> [scope] <desc>  Generate commit message suggestions
    help                       Show this help message

OPTIONS:
    commit-msg                 Commit message to validate (in quotes)
    from                       Starting reference (tag, commit, branch)
    to                         Ending reference (default: HEAD)
    type                       Commit type (feat, fix, docs, etc.)
    scope                      Commit scope (optional)
    desc                       Commit description

EXAMPLES:
    # Validate specific message
    $0 validate "feat(auth): add user login"

    # Validate last commit
    $0 last

    # Validate commits since last tag
    $0 range \$(git describe --tags --abbrev=0)

    # Validate all commits
    $0 all

    # Generate suggestions
    $0 suggest feat api "add user authentication"

CONVENTIONAL COMMIT FORMAT:
    <type>[optional scope]: <description>

    [optional body]

    [optional footer(s)]

TYPES:
$(printf "    %-10s %s\n" \
    "feat:" "A new feature" \
    "fix:" "A bug fix" \
    "docs:" "Documentation only changes" \
    "style:" "Formatting, missing semi colons, etc" \
    "refactor:" "Code change that neither fixes a bug nor adds a feature" \
    "perf:" "Code change that improves performance" \
    "test:" "Adding missing tests or correcting existing tests" \
    "build:" "Changes that affect the build system" \
    "ci:" "Changes to CI configuration files and scripts" \
    "chore:" "Other changes that don't modify src or test files" \
    "revert:" "Reverts a previous commit" \
    "security:" "Security related fixes")

BREAKING CHANGES:
    Use '!' after type/scope: feat!: remove deprecated API
    Or add 'BREAKING CHANGE:' in footer

EOF
}

# Main function
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 1
    fi

    case "$1" in
        "validate")
            if [ -z "$2" ]; then
                print_error "Please provide a commit message to validate"
                print_info "Usage: $0 validate 'commit message'"
                exit 1
            fi
            validate_commit_message "$2"
            ;;
        "range")
            local from="${2:-$(git describe --tags --abbrev=0 2>/dev/null || echo 'HEAD~10')}"
            local to="${3:-HEAD}"
            validate_commit_range "$from" "$to"
            ;;
        "last")
            validate_commit_range "HEAD~1" "HEAD"
            ;;
        "all")
            validate_commit_range "all"
            ;;
        "suggest")
            suggest_commit_message "$2" "$3" "$4"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
