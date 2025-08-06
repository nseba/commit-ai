#!/bin/bash

# Script to update Docker Hub description from README.md
# Usage: ./scripts/update-docker-description.sh

set -e

# Configuration
DOCKER_REPO="nseba/commit-ai"
README_FILE="README.md"
SHORT_DESCRIPTION="AI-powered commit message generator for Git repositories using multiple LLM providers"

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

# Check if README.md exists
if [[ ! -f "$README_FILE" ]]; then
    print_error "README.md not found in current directory"
    exit 1
fi

print_info "Updating Docker Hub description for $DOCKER_REPO"

# Check if required environment variables are set
if [[ -z "$DOCKER_USERNAME" ]]; then
    print_error "DOCKER_USERNAME environment variable is not set"
    print_info "Please set it with: export DOCKER_USERNAME=your-username"
    exit 1
fi

if [[ -z "$DOCKER_PASSWORD" ]]; then
    print_error "DOCKER_PASSWORD environment variable is not set"
    print_info "Please set it with: export DOCKER_PASSWORD=your-password-or-token"
    print_info "For security, consider using a Docker Hub access token instead of your password"
    exit 1
fi

# Check if curl is available
if ! command -v curl &> /dev/null; then
    print_error "curl is required but not installed"
    exit 1
fi

# Check if jq is available (optional but helpful)
if ! command -v jq &> /dev/null; then
    print_warning "jq not found - JSON responses won't be formatted"
    JQ_AVAILABLE=false
else
    JQ_AVAILABLE=true
fi

print_info "Authenticating with Docker Hub..."

# Get authentication token
TOKEN_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$DOCKER_USERNAME\",\"password\":\"$DOCKER_PASSWORD\"}" \
    "https://hub.docker.com/v2/users/login/")

if [[ $JQ_AVAILABLE == true ]]; then
    TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.token // empty')
else
    # Extract token without jq (basic approach)
    TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
fi

if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
    print_error "Failed to authenticate with Docker Hub"
    if [[ $JQ_AVAILABLE == true ]]; then
        echo "Response: $(echo "$TOKEN_RESPONSE" | jq .)"
    else
        echo "Response: $TOKEN_RESPONSE"
    fi
    exit 1
fi

print_success "Authentication successful"

# Read README.md content and prepare for JSON
README_CONTENT=$(cat "$README_FILE")

# Escape content for JSON
README_ESCAPED=$(echo "$README_CONTENT" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

# Prepare JSON payload
JSON_PAYLOAD=$(cat <<EOF
{
    "full_description": "$README_ESCAPED",
    "description": "$SHORT_DESCRIPTION"
}
EOF
)

print_info "Updating repository description..."

# Update Docker Hub repository
UPDATE_RESPONSE=$(curl -s -X PATCH \
    -H "Authorization: JWT $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$JSON_PAYLOAD" \
    "https://hub.docker.com/v2/repositories/$DOCKER_REPO/")

# Check if update was successful
if echo "$UPDATE_RESPONSE" | grep -q '"name"'; then
    print_success "Docker Hub description updated successfully!"
    print_info "Repository: https://hub.docker.com/r/$DOCKER_REPO"
else
    print_error "Failed to update Docker Hub description"
    if [[ $JQ_AVAILABLE == true ]]; then
        echo "Response: $(echo "$UPDATE_RESPONSE" | jq .)"
    else
        echo "Response: $UPDATE_RESPONSE"
    fi
    exit 1
fi

# Optional: Show current repository info
print_info "Fetching updated repository information..."
REPO_INFO=$(curl -s "https://hub.docker.com/v2/repositories/$DOCKER_REPO/")

if [[ $JQ_AVAILABLE == true ]]; then
    echo ""
    echo "Repository Information:"
    echo "Name: $(echo "$REPO_INFO" | jq -r '.name')"
    echo "Short Description: $(echo "$REPO_INFO" | jq -r '.description')"
    echo "Stars: $(echo "$REPO_INFO" | jq -r '.star_count')"
    echo "Pulls: $(echo "$REPO_INFO" | jq -r '.pull_count')"
    echo "Last Updated: $(echo "$REPO_INFO" | jq -r '.last_updated')"
else
    print_info "Repository information updated (install 'jq' for formatted output)"
fi

print_success "Docker Hub description update completed!"
