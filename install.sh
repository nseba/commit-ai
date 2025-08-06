#!/bin/bash
# Commit-AI Installation Script
# This script installs commit-ai and sets up the configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO="nseba/commit-ai"
INSTALL_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/commit-ai"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}$1${NC}"
}

# Function to detect OS and architecture
detect_platform() {
    local os=""
    local arch=""

    case "$(uname -s)" in
        Darwin*)    os="darwin" ;;
        Linux*)     os="linux" ;;
        CYGWIN*|MINGW*|MSYS*) os="windows" ;;
        *)          print_error "Unsupported operating system: $(uname -s)"; exit 1 ;;
    esac

    case "$(uname -m)" in
        x86_64|amd64)   arch="amd64" ;;
        arm64|aarch64)  arch="arm64" ;;
        armv7l)         arch="arm" ;;
        *)              print_error "Unsupported architecture: $(uname -m)"; exit 1 ;;
    esac

    echo "${os}-${arch}"
}

# Function to get the latest release version
get_latest_version() {
    if command -v curl >/dev/null 2>&1; then
        curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
    else
        print_error "Neither curl nor wget is available. Please install one of them."
        exit 1
    fi
}

# Function to download and install binary
install_binary() {
    local version="$1"
    local platform="$2"
    local binary_name="commit-ai-$platform"

    if [[ "$platform" == *"windows"* ]]; then
        binary_name="${binary_name}.exe"
    fi

    local download_url="https://github.com/$REPO/releases/download/$version/$binary_name"
    local temp_file="/tmp/$binary_name"

    print_status "Downloading commit-ai $version for $platform..."

    if command -v curl >/dev/null 2>&1; then
        curl -L -o "$temp_file" "$download_url"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$temp_file" "$download_url"
    else
        print_error "Neither curl nor wget is available"
        exit 1
    fi

    if [ ! -f "$temp_file" ]; then
        print_error "Failed to download binary"
        exit 1
    fi

    # Create install directory if it doesn't exist
    mkdir -p "$INSTALL_DIR"

    # Install binary
    local install_path="$INSTALL_DIR/commit-ai"
    if [[ "$platform" == *"windows"* ]]; then
        install_path="${install_path}.exe"
    fi

    mv "$temp_file" "$install_path"
    chmod +x "$install_path"

    print_status "Binary installed to $install_path"
}

# Function to setup configuration
setup_config() {
    print_status "Setting up configuration..."

    # Create config directory
    mkdir -p "$CONFIG_DIR"

    # Create default config file if it doesn't exist
    local config_file="$CONFIG_DIR/config.toml"
    if [ ! -f "$config_file" ]; then
        cat > "$config_file" << 'EOF'
# Commit-AI Configuration File
# For more information, visit: https://github.com/nseba/commit-ai

# API URL for the AI provider
# For Ollama (default): http://localhost:11434
# For OpenAI: https://api.openai.com
CAI_API_URL = "http://localhost:11434"

# Model name to use for generating commit messages
# For Ollama: llama2, codellama, mistral, etc.
# For OpenAI: gpt-3.5-turbo, gpt-4, etc.
CAI_MODEL = "llama2"

# AI provider to use
# Supported values: ollama, openai
CAI_PROVIDER = "ollama"

# API token for external providers (required for OpenAI)
# Leave empty for local providers like Ollama
CAI_API_TOKEN = ""

# Language for the generated commit messages
# Examples: english, spanish, french, german, etc.
CAI_LANGUAGE = "english"

# Name of the prompt template file (relative to config directory)
# The template file should be placed in ~/.config/commit-ai/
CAI_PROMPT_TEMPLATE = "default.txt"
EOF
        print_status "Created default configuration file: $config_file"
    else
        print_warning "Configuration file already exists: $config_file"
    fi

    # Create default template file if it doesn't exist
    local template_file="$CONFIG_DIR/default.txt"
    if [ ! -f "$template_file" ]; then
        cat > "$template_file" << 'EOF'
You are an expert developer reviewing a git diff to generate a concise, meaningful commit message.

Language: Generate the commit message in {{.Language}}.

Git Diff:
{{.Diff}}

Based on the above git diff, generate a single line commit message that:
1. Is concise and descriptive (50 characters or less preferred)
2. Uses conventional commit format if applicable (feat:, fix:, docs:, etc.)
3. Describes WHAT changed, not HOW it was implemented
4. Uses imperative mood (e.g., "Add feature" not "Added feature")

Commit Message:
EOF
        print_status "Created default template file: $template_file"
    else
        print_warning "Template file already exists: $template_file"
    fi
}

# Function to check PATH
check_path() {
    if [[ ":$PATH:" == *":$INSTALL_DIR:"* ]]; then
        print_status "✓ $INSTALL_DIR is already in your PATH"
    else
        print_warning "⚠ $INSTALL_DIR is not in your PATH"
        echo
        print_status "To use commit-ai from anywhere, add this line to your shell profile:"
        echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
        echo
        print_status "For bash: ~/.bashrc or ~/.bash_profile"
        print_status "For zsh: ~/.zshrc"
        print_status "For fish: ~/.config/fish/config.fish"
        echo
        print_status "Or run commit-ai directly: $INSTALL_DIR/commit-ai"
    fi
}

# Function to install Ollama (optional)
install_ollama() {
    echo
    read -p "Would you like to install Ollama for local AI processing? [y/N]: " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Installing Ollama..."
        if curl -fsSL https://ollama.ai/install.sh | sh; then
            print_status "✓ Ollama installed successfully"
            echo
            print_status "To get started with Ollama:"
            echo "  1. Pull a model: ollama pull llama2"
            echo "  2. Start the service: ollama serve"
            echo "  3. Test commit-ai: commit-ai"
        else
            print_error "Failed to install Ollama"
            print_status "You can install it manually from: https://ollama.ai"
        fi
    else
        print_status "Skipped Ollama installation"
        print_status "If you want to use OpenAI instead, update your config:"
        echo "  CAI_PROVIDER = \"openai\""
        echo "  CAI_MODEL = \"gpt-3.5-turbo\""
        echo "  CAI_API_TOKEN = \"your-api-token\""
    fi
}

# Function to run post-installation tests
test_installation() {
    local binary_path="$INSTALL_DIR/commit-ai"

    if [ -x "$binary_path" ]; then
        print_status "Testing installation..."
        if "$binary_path" --help >/dev/null 2>&1; then
            print_status "✓ commit-ai is working correctly"
        else
            print_error "✗ commit-ai test failed"
            return 1
        fi
    else
        print_error "✗ commit-ai binary not found or not executable"
        return 1
    fi
}

# Main installation function
main() {
    print_header "╭─────────────────────────────────────╮"
    print_header "│          Commit-AI Installer        │"
    print_header "│   AI-Powered Commit Message Tool    │"
    print_header "╰─────────────────────────────────────╯"
    echo

    # Check if running as root (not recommended)
    if [ "$EUID" -eq 0 ]; then
        print_warning "Running as root is not recommended"
        print_warning "This will install to system directories"
        INSTALL_DIR="/usr/local/bin"
    fi

    # Detect platform
    local platform
    platform=$(detect_platform)
    print_status "Detected platform: $platform"

    # Get latest version
    print_status "Fetching latest release information..."
    local version
    version=$(get_latest_version)

    if [ -z "$version" ]; then
        print_error "Failed to get latest version"
        print_status "You can download manually from: https://github.com/$REPO/releases"
        exit 1
    fi

    print_status "Latest version: $version"

    # Install binary
    install_binary "$version" "$platform"

    # Setup configuration
    setup_config

    # Test installation
    if test_installation; then
        echo
        print_header "🎉 Installation completed successfully!"
        echo
        print_status "Configuration directory: $CONFIG_DIR"
        print_status "Binary location: $INSTALL_DIR/commit-ai"
        echo

        # Check PATH
        check_path

        # Offer to install Ollama
        install_ollama

        echo
        print_header "📖 Quick Start:"
        echo "  1. Navigate to a git repository"
        echo "  2. Make some changes and stage them: git add ."
        echo "  3. Generate commit message: commit-ai"
        echo "  4. Commit with generated message: git commit -m \"\$(commit-ai)\""
        echo
        print_status "For more information, visit: https://github.com/$REPO"

    else
        print_error "Installation completed but tests failed"
        exit 1
    fi
}

# Function to show usage
show_usage() {
    echo "Commit-AI Installation Script"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -d, --dir DIR  Install directory (default: ~/.local/bin)"
    echo "  -v, --version  Show version and exit"
    echo
    echo "Environment Variables:"
    echo "  INSTALL_DIR    Override default installation directory"
    echo "  CONFIG_DIR     Override default configuration directory"
    echo
    echo "Examples:"
    echo "  $0                    # Install to ~/.local/bin"
    echo "  $0 -d /usr/local/bin  # Install to /usr/local/bin"
    echo "  INSTALL_DIR=~/bin $0  # Install to ~/bin"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -d|--dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        -v|--version)
            echo "commit-ai installer v1.0.0"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Override defaults with environment variables
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/commit-ai}"

# Run main installation
main
