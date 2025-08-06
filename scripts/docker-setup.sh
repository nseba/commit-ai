#!/bin/bash
# Docker setup script for Commit-AI
# This script helps set up the development environment using Docker Compose

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
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

# Check if Docker and Docker Compose are installed
check_dependencies() {
    print_status "Checking dependencies..."

    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker is not installed. Please install Docker first."
        echo "Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi

    if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        echo "Visit: https://docs.docker.com/compose/install/"
        exit 1
    fi

    print_status "✓ Docker and Docker Compose are installed"
}

# Create necessary directories and files
setup_environment() {
    print_status "Setting up environment..."

    # Create .env file if it doesn't exist
    if [ ! -f .env ]; then
        cat > .env << 'EOF'
# Environment variables for Commit-AI Docker setup
# Copy this to .env and customize as needed

# OpenAI API Token (required only if using OpenAI profile)
# OPENAI_API_TOKEN=your-openai-api-token-here

# Custom Ollama models to pull
OLLAMA_MODELS=llama2,codellama,mistral

# Timezone
TZ=UTC

# Development settings
COMPOSE_PROJECT_NAME=commit-ai
EOF
        print_status "Created .env file with default settings"
    fi

    # Ensure Docker has permission to access the current directory
    if [ "$(uname)" = "Darwin" ]; then
        print_warning "On macOS, ensure Docker Desktop has permission to access this directory"
    fi

    print_status "✓ Environment setup complete"
}

# Start development environment
start_dev() {
    print_header "🚀 Starting Commit-AI Development Environment"

    print_status "Starting Ollama service..."
    docker-compose up -d ollama

    print_status "Waiting for Ollama to be ready..."
    until docker-compose exec -T ollama curl -f http://localhost:11434/api/version >/dev/null 2>&1; do
        echo -n "."
        sleep 2
    done
    echo ""
    print_status "✓ Ollama is ready"

    print_status "Starting development container..."
    docker-compose up -d commit-ai-dev

    print_status "✓ Development environment is ready!"
    echo ""
    print_status "To enter the development container:"
    echo "  docker-compose exec commit-ai-dev bash"
    echo ""
    print_status "To run tests:"
    echo "  docker-compose exec commit-ai-dev make test"
    echo ""
    print_status "To build the application:"
    echo "  docker-compose exec commit-ai-dev make build"
}

# Pull and setup AI models
setup_models() {
    print_header "📚 Setting up AI Models"

    print_status "Starting model setup..."
    docker-compose --profile setup up model-setup

    print_status "✓ Models setup complete"

    print_status "Available models:"
    docker-compose exec -T ollama ollama list
}

# Start production environment
start_prod() {
    print_header "🏭 Starting Commit-AI Production Environment"

    print_status "Starting services..."
    docker-compose --profile production up -d

    print_status "✓ Production environment is ready!"
    echo ""
    print_status "To generate a commit message:"
    echo "  docker-compose exec commit-ai commit-ai"
}

# Start with OpenAI
start_openai() {
    print_header "🤖 Starting Commit-AI with OpenAI"

    if [ -z "$OPENAI_API_TOKEN" ] && ! grep -q "OPENAI_API_TOKEN=" .env; then
        print_error "OpenAI API token is not set"
        print_status "Please set OPENAI_API_TOKEN in .env file or environment"
        exit 1
    fi

    print_status "Starting OpenAI environment..."
    docker-compose --profile openai up -d commit-ai-openai

    print_status "✓ OpenAI environment is ready!"
    echo ""
    print_status "To generate a commit message:"
    echo "  docker-compose exec commit-ai-openai commit-ai"
}

# Stop all services
stop_all() {
    print_status "Stopping all services..."
    docker-compose --profile "*" down
    print_status "✓ All services stopped"
}

# Clean up everything
cleanup() {
    print_header "🧹 Cleaning up Docker environment"

    print_status "Stopping and removing containers..."
    docker-compose --profile "*" down -v

    print_status "Removing images..."
    docker-compose --profile "*" down --rmi all

    print_warning "This will remove all Docker volumes (including Ollama models)"
    read -p "Are you sure? [y/N]: " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker volume rm $(docker volume ls -q | grep commit-ai) 2>/dev/null || true
        print_status "✓ Cleanup complete"
    else
        print_status "Cleanup cancelled"
    fi
}

# Show status of services
show_status() {
    print_header "📊 Service Status"
    docker-compose ps

    echo ""
    print_header "📁 Docker Volumes"
    docker volume ls | grep commit-ai || echo "No commit-ai volumes found"

    echo ""
    print_header "🌐 Networks"
    docker network ls | grep commit-ai || echo "No commit-ai networks found"
}

# Show logs
show_logs() {
    local service="$1"
    if [ -z "$service" ]; then
        print_status "Showing logs for all services..."
        docker-compose logs -f
    else
        print_status "Showing logs for $service..."
        docker-compose logs -f "$service"
    fi
}

# Interactive shell
shell() {
    local service="${1:-commit-ai-dev}"
    print_status "Opening shell in $service..."
    docker-compose exec "$service" bash
}

# Run tests
run_tests() {
    print_status "Running tests in development container..."
    docker-compose exec commit-ai-dev make test
}

# Build application
build_app() {
    print_status "Building application in development container..."
    docker-compose exec commit-ai-dev make build
}

# Show usage
show_usage() {
    echo "Commit-AI Docker Setup Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start-dev     Start development environment with Ollama"
    echo "  start-prod    Start production environment"
    echo "  start-openai  Start environment with OpenAI"
    echo "  setup-models  Pull and setup AI models"
    echo "  stop          Stop all services"
    echo "  cleanup       Clean up all containers, images, and volumes"
    echo "  status        Show status of services"
    echo "  logs [service] Show logs (optionally for specific service)"
    echo "  shell [service] Open shell in container (default: commit-ai-dev)"
    echo "  test          Run tests in development container"
    echo "  build         Build application in development container"
    echo "  help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start-dev     # Start development environment"
    echo "  $0 setup-models  # Pull AI models"
    echo "  $0 shell         # Open development shell"
    echo "  $0 logs ollama   # Show Ollama logs"
    echo "  $0 test          # Run tests"
    echo ""
    echo "Environment Files:"
    echo "  .env             Environment variables"
    echo "  docker-compose.yml Docker Compose configuration"
    echo ""
    echo "For more information, visit: https://github.com/nseba/commit-ai"
}

# Main script logic
main() {
    case "${1:-}" in
        "start-dev")
            check_dependencies
            setup_environment
            start_dev
            ;;
        "start-prod")
            check_dependencies
            setup_environment
            start_prod
            ;;
        "start-openai")
            check_dependencies
            setup_environment
            start_openai
            ;;
        "setup-models")
            check_dependencies
            setup_models
            ;;
        "stop")
            stop_all
            ;;
        "cleanup")
            cleanup
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs "$2"
            ;;
        "shell")
            shell "$2"
            ;;
        "test")
            run_tests
            ;;
        "build")
            build_app
            ;;
        "help"|"--help"|"-h")
            show_usage
            ;;
        "")
            show_usage
            ;;
        *)
            print_error "Unknown command: $1"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
