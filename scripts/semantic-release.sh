#!/bin/bash

# Semantic Release Script for commit-ai
# Automatically determines the next version based on conventional commits
# and generates changelog entries

# Remove set -e to handle errors gracefully
# set -e

# Configuration
REPO_OWNER="nseba"
REPO_NAME="commit-ai"
DEFAULT_VERSION="1.0.0"

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

print_version() {
    echo -e "${CYAN}${1}${NC}"
}

# Get current version from git tags
get_current_version() {
    local current_tag
    current_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

    if [ -z "$current_tag" ]; then
        echo "v0.0.0"
        return
    fi

    # Validate version format
    if echo "$current_tag" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+'; then
        echo "$current_tag"
    else
        echo "v0.0.0"
    fi
}

# Parse semantic version
parse_version() {
    local version="$1"
    # Remove 'v' prefix if present
    version=${version#v}

    local major minor patch
    major=$(echo "$version" | cut -d. -f1)
    minor=$(echo "$version" | cut -d. -f2)
    patch=$(echo "$version" | cut -d. -f3 | cut -d- -f1)  # Remove pre-release suffix

    echo "$major $minor $patch"
}

# Increment version based on type
increment_version() {
    local current_version="$1"
    local bump_type="$2"

    read -r major minor patch <<< "$(parse_version "$current_version")"

    case "$bump_type" in
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            ;;
        "patch")
            patch=$((patch + 1))
            ;;
        *)
            print_error "Invalid bump type: $bump_type"
            exit 1
            ;;
    esac

    echo "v$major.$minor.$patch"
}

# Analyze commits for conventional commit patterns
analyze_commits() {
    local from_ref="$1"
    local to_ref="${2:-HEAD}"

    print_info "Analyzing commits from $from_ref to $to_ref..."

    # Get commit messages with safe handling of special characters
    local commits_file=$(mktemp)
    if [ "$from_ref" = "v0.0.0" ]; then
        git log --pretty=format:"%s" "$to_ref" > "$commits_file" 2>/dev/null || echo "" > "$commits_file"
    else
        git log --pretty=format:"%s" "$from_ref..$to_ref" > "$commits_file" 2>/dev/null || echo "" > "$commits_file"
    fi

    if [ ! -s "$commits_file" ]; then
        print_warning "No commits found in range $from_ref..$to_ref"
        rm -f "$commits_file"
        echo "none"
        return 0
    fi

    # Display commits safely
    while IFS= read -r commit_msg || [ -n "$commit_msg" ]; do
        if [ -n "$commit_msg" ]; then
            echo "  📝 $commit_msg"
        fi
    done < "$commits_file"
    echo ""

    # Initialize flags
    local has_breaking=false
    local has_feature=false
    local has_fix=false

    # Check for breaking changes
    if grep -qE "^[^:]*!:|BREAKING CHANGE|^[a-z]+\([^)]*\)!:" "$commits_file"; then
        has_breaking=true
        print_info "🚨 Breaking changes detected"
    fi

    # Check for features
    if grep -qE "^feat(\([^)]*\))?:" "$commits_file"; then
        has_feature=true
        print_info "✨ New features detected"
    fi

    # Check for fixes
    if grep -qE "^fix(\([^)]*\))?:|^security(\([^)]*\))?:" "$commits_file"; then
        has_fix=true
        print_info "🐛 Bug fixes detected"
    fi

    # Cleanup
    rm -f "$commits_file"

    # Determine bump type
    if [ "$has_breaking" = true ]; then
        echo "major"
    elif [ "$has_feature" = true ]; then
        echo "minor"
    elif [ "$has_fix" = true ]; then
        echo "patch"
    else
        echo "none"
    fi
}

# Generate changelog section
generate_changelog() {
    local from_ref="$1"
    local to_ref="${2:-HEAD}"
    local version="$3"

    local changelog_file="SEMANTIC_CHANGELOG.md"
    local temp_file=$(mktemp)

    print_info "Generating changelog from $from_ref to $to_ref..."

    # Create header
    cat > "$temp_file" << EOF
# Release $version

**Release Date**: $(date -u +"%Y-%m-%d")

EOF

    # Get commits and categorize them
    local commits
    if [ "$from_ref" = "v0.0.0" ]; then
        commits=$(git log --pretty=format:"%s|%h|%an|%ad" --date=short "$to_ref" 2>/dev/null || echo "")
    else
        commits=$(git log --pretty=format:"%s|%h|%an|%ad" --date=short "$from_ref..$to_ref" 2>/dev/null || echo "")
    fi

    if [ -z "$commits" ]; then
        echo "No commits found for changelog generation" > "$temp_file"
        echo "$changelog_file"
        return 0
    fi

    # Categories
    local breaking_changes=""
    local features=""
    local bug_fixes=""
    local security_fixes=""
    local documentation=""
    local refactoring=""
    local tests=""
    local chores=""
    local other_changes=""

    # Parse commits
    while IFS='|' read -r subject hash author date; do
        local line="* $subject ([${hash}](https://github.com/$REPO_OWNER/$REPO_NAME/commit/$hash))"

        case "$subject" in
            *"BREAKING CHANGE"*|*"!"*)
                breaking_changes="${breaking_changes}${line}\n"
                ;;
            "feat"*|"feature"*)
                features="${features}${line}\n"
                ;;
            "fix"*)
                bug_fixes="${bug_fixes}${line}\n"
                ;;
            "security"*)
                security_fixes="${security_fixes}${line}\n"
                ;;
            "docs"*|"doc"*)
                documentation="${documentation}${line}\n"
                ;;
            "refactor"*)
                refactoring="${refactoring}${line}\n"
                ;;
            "test"*)
                tests="${tests}${line}\n"
                ;;
            "chore"*|"build"*|"ci"*)
                chores="${chores}${line}\n"
                ;;
            *)
                other_changes="${other_changes}${line}\n"
                ;;
        esac
    done <<< "$commits"

    # Add sections to changelog
    if [ -n "$breaking_changes" ]; then
        echo -e "\n## 🚨 BREAKING CHANGES\n" >> "$temp_file"
        echo -e "$breaking_changes" >> "$temp_file"
    fi

    if [ -n "$security_fixes" ]; then
        echo -e "\n## 🔒 Security Fixes\n" >> "$temp_file"
        echo -e "$security_fixes" >> "$temp_file"
    fi

    if [ -n "$features" ]; then
        echo -e "\n## ✨ Features\n" >> "$temp_file"
        echo -e "$features" >> "$temp_file"
    fi

    if [ -n "$bug_fixes" ]; then
        echo -e "\n## 🐛 Bug Fixes\n" >> "$temp_file"
        echo -e "$bug_fixes" >> "$temp_file"
    fi

    if [ -n "$refactoring" ]; then
        echo -e "\n## ♻️ Code Refactoring\n" >> "$temp_file"
        echo -e "$refactoring" >> "$temp_file"
    fi

    if [ -n "$documentation" ]; then
        echo -e "\n## 📚 Documentation\n" >> "$temp_file"
        echo -e "$documentation" >> "$temp_file"
    fi

    if [ -n "$tests" ]; then
        echo -e "\n## 🧪 Tests\n" >> "$temp_file"
        echo -e "$tests" >> "$temp_file"
    fi

    if [ -n "$chores" ]; then
        echo -e "\n## 🔧 Maintenance\n" >> "$temp_file"
        echo -e "$chores" >> "$temp_file"
    fi

    if [ -n "$other_changes" ]; then
        echo -e "\n## 📝 Other Changes\n" >> "$temp_file"
        echo -e "$other_changes" >> "$temp_file"
    fi

    # Add installation instructions
    cat >> "$temp_file" << EOF

## 📦 Installation

### Download Binary
Download the appropriate binary for your platform from the [release assets](https://github.com/$REPO_OWNER/$REPO_NAME/releases/tag/$version).

### Using Go
\`\`\`bash
go install github.com/$REPO_OWNER/$REPO_NAME/cmd@$version
\`\`\`

### Using Docker
\`\`\`bash
docker pull $REPO_OWNER/$REPO_NAME:$version
\`\`\`

### Using Homebrew (if available)
\`\`\`bash
brew tap $REPO_OWNER/tools
brew install $REPO_NAME
\`\`\`

## 🔗 Links

* **Full Changelog**: https://github.com/$REPO_OWNER/$REPO_NAME/compare/${from_ref}...$version
* **Docker Image**: https://hub.docker.com/r/$REPO_OWNER/$REPO_NAME
* **Documentation**: https://github.com/$REPO_OWNER/$REPO_NAME#readme

EOF

    # Save changelog
    cp "$temp_file" "$changelog_file"
    rm "$temp_file"

    print_success "Changelog saved to $changelog_file"
    echo "$changelog_file"
}

# Main semantic release function
semantic_release() {
    local dry_run=false
    local force_version=""
    local skip_checks=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --version)
                force_version="$2"
                shift 2
                ;;
            --skip-checks)
                skip_checks=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    print_header "🤖 Semantic Release Analysis"
    echo ""

    # Get current version
    local current_version
    current_version=$(get_current_version)
    print_info "Current version: $current_version"

    # Analyze commits since last release
    local bump_type
    bump_type=$(analyze_commits "$current_version")

    if [ "$bump_type" = "none" ]; then
        print_warning "No significant changes detected. No release needed."
        if [ "$dry_run" = true ]; then
            print_info "This was a dry run. No changes made."
        fi
        exit 0
    fi

    # Calculate next version
    local next_version
    if [ -n "$force_version" ]; then
        next_version="$force_version"
        print_info "Using forced version: $next_version"
    else
        next_version=$(increment_version "$current_version" "$bump_type")
        print_success "Recommended version bump: $bump_type"
    fi

    print_version "Next version: $next_version"
    echo ""

    # Generate changelog
    local changelog_file
    changelog_file=$(generate_changelog "$current_version" "HEAD" "$next_version")

    if [ "$dry_run" = true ]; then
        print_header "🔍 Dry Run Complete"
        echo ""
        print_info "Would create version: $next_version"
        print_info "Bump type: $bump_type"
        print_info "Changelog: $changelog_file"
        print_info "No changes made (dry run mode)"
        exit 0
    fi

    # Confirm release
    echo ""
    print_header "🚀 Ready to Release"
    echo ""
    print_info "Version: $current_version → $next_version"
    print_info "Type: $bump_type release"
    print_info "Changelog: $changelog_file"
    echo ""

    if [ "$skip_checks" != true ]; then
        echo "Proceed with release? (y/N): "
        read -r confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            print_warning "Release cancelled"
            exit 0
        fi
    fi

    # Create release
    print_info "Creating semantic release..."

    # Create git tag with changelog as message
    local tag_message
    tag_message=$(cat "$changelog_file")

    git tag "$next_version" -m "$tag_message"
    git push origin "$next_version"

    print_success "✨ Semantic release $next_version created successfully!"
    echo ""
    print_info "🔗 Monitor release: https://github.com/$REPO_OWNER/$REPO_NAME/actions"
    print_info "📦 Release page: https://github.com/$REPO_OWNER/$REPO_NAME/releases/tag/$next_version"

    # Cleanup
    rm -f "$changelog_file"
}

# Show help
show_help() {
    cat << EOF
Semantic Release - Automated versioning based on conventional commits

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --dry-run           Show what would be released without making changes
    --version VERSION   Force a specific version (e.g., v1.2.0)
    --skip-checks       Skip confirmation prompts
    --help, -h          Show this help message

EXAMPLES:
    $0                          # Analyze and create release
    $0 --dry-run                # Show what would be released
    $0 --version v2.0.0         # Force specific version
    $0 --skip-checks            # Auto-confirm release

CONVENTIONAL COMMITS:
    feat:       New feature (minor version bump)
    fix:        Bug fix (patch version bump)
    security:   Security fix (patch version bump)

    Breaking changes (major version bump):
    feat!:      Breaking feature
    fix!:       Breaking fix
    BREAKING CHANGE: in commit body

    Other types:
    docs:       Documentation
    refactor:   Code refactoring
    test:       Tests
    chore:      Maintenance
    build:      Build system
    ci:         CI/CD changes

VERSIONING:
    Follows semantic versioning (semver.org):
    - MAJOR: Breaking changes
    - MINOR: New features (backwards compatible)
    - PATCH: Bug fixes (backwards compatible)

EOF
}

# Main execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    semantic_release "$@"
fi
