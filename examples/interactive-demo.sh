#!/bin/bash

# Commit-AI Interactive Features Demo
# This script demonstrates the new interactive features of commit-ai

set -e

echo "🤖 Commit-AI Interactive Features Demo"
echo "======================================"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}➤ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check if commit-ai binary exists
if [ ! -f "./commit-ai" ]; then
    print_error "commit-ai binary not found. Please build it first with: go build -o commit-ai ./cmd"
    exit 1
fi

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    print_error "Not in a git repository. Please run this from the commit-ai project root."
    exit 1
fi

echo "This demo will show you the interactive features of commit-ai:"
echo "1. 📋 Show last commit message"
echo "2. ✏️  Interactive editing mode"
echo "3. 🚀 Auto-staging and committing"
echo "4. 🔄 Full interactive workflow"
echo

# Demo 1: Show last commit
print_step "Demo 1: Show last commit message"
echo "Command: ./commit-ai --show"
echo "Output:"
./commit-ai --show
echo

# Create a test file for demonstrations
TEST_FILE="demo-file.txt"
print_step "Creating test file for demos: $TEST_FILE"
echo "# Demo file for commit-ai interactive features
This file demonstrates the new interactive capabilities.

Features demonstrated:
- Show last commit message
- Interactive editing
- Auto-staging
- Auto-committing
" > $TEST_FILE

print_success "Test file created"
echo

# Demo 2: Basic message generation (without AI to avoid errors)
print_step "Demo 2: Show basic usage (generate message for staged changes)"
git add $TEST_FILE 2>/dev/null || true
echo "Command: ./commit-ai (note: will show error if AI provider not available, which is expected)"
echo "This would normally generate an AI commit message for the staged changes."
echo "Example output: 'docs: add demo file for interactive features'"
echo

# Demo 3: Show command line options
print_step "Demo 3: Available command line options"
echo "Command: ./commit-ai --help"
./commit-ai --help | grep -A 10 "Flags:"
echo

# Demo 4: Configuration example
print_step "Demo 4: Configuration setup"
echo "Commit-AI uses configuration from ~/.config/commit-ai/config.toml"
echo "Example configuration for different providers:"
echo
echo "For Ollama (local AI):"
cat << 'EOF'
CAI_API_URL = "http://localhost:11434"
CAI_MODEL = "llama2"
CAI_PROVIDER = "ollama"
CAI_LANGUAGE = "english"
EOF
echo
echo "For OpenAI:"
cat << 'EOF'
CAI_API_URL = "https://api.openai.com"
CAI_MODEL = "gpt-3.5-turbo"
CAI_PROVIDER = "openai"
CAI_API_TOKEN = "your-api-key-here"
CAI_LANGUAGE = "english"
EOF
echo

# Demo 5: Workflow examples
print_step "Demo 5: Typical workflow examples"
echo

echo "🔹 Quick commit with AI message (requires AI provider):"
echo "   git add ."
echo "   git commit -m \"\$(commit-ai)\""
echo

echo "🔹 Interactive workflow:"
echo "   commit-ai --add --edit --commit"
echo "   (stages changes, generates message, allows editing, commits)"
echo

echo "🔹 Just show what the AI suggests:"
echo "   commit-ai --edit"
echo "   (generates message and lets you edit before using elsewhere)"
echo

echo "🔹 Review last commit:"
echo "   commit-ai --show"
echo "   (displays the last commit message nicely formatted)"
echo

# Demo 6: Integration examples
print_step "Demo 6: Integration examples"
echo

echo "🔧 Git alias for quick AI commits:"
echo "   git config --global alias.aic '!git add . && git commit -m \"\$(commit-ai)\"'"
echo

echo "🔧 Shell function for interactive commits:"
cat << 'EOF'
function gai() {
    local msg=$(commit-ai)
    echo "AI suggests: $msg"
    read -p "Use this message? (y/n): " -n 1 -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git commit -m "$msg"
    else
        git commit
    fi
}
EOF
echo

# Cleanup
print_step "Cleaning up demo files"
git reset HEAD $TEST_FILE 2>/dev/null || true
rm -f $TEST_FILE
print_success "Demo completed!"

echo
echo "🎉 That concludes the interactive features demo!"
echo
echo "To get started:"
echo "1. Set up an AI provider (Ollama locally or OpenAI with API key)"
echo "2. Configure commit-ai in ~/.config/commit-ai/config.toml"
echo "3. Try: commit-ai --show (works without AI)"
echo "4. Try: commit-ai --edit (requires AI provider)"
echo "5. Try: commit-ai --add --commit (full workflow)"
echo
echo "For more information, see the README.md or run: commit-ai --help"
