# Docker Hub Description Automation

This document explains the automated Docker Hub description update system for the commit-ai project.

## Overview

The project includes several methods to automatically keep your Docker Hub repository description in sync with your GitHub README.md file:

1. **GitHub Actions (Automatic)** - Updates on every push to main and when README changes
2. **Manual Script** - For local updates when needed
3. **Makefile Target** - Convenient wrapper for the manual script

## Automated Methods

### 1. GitHub Actions Integration

#### Main CI/CD Pipeline
The main CI/CD pipeline (`.github/workflows/ci.yml`) includes a step that updates the Docker Hub description whenever Docker images are built and pushed.

**Triggers:**
- Push to `main` branch
- New version tags (e.g., `v1.0.0`)

#### Dedicated Description Workflow
A separate workflow (`.github/workflows/docker-description.yml`) updates the description whenever the README changes.

**Triggers:**
- README.md changes on `main` branch
- Manual dispatch (can be triggered manually from GitHub UI)
- Changes to the workflow file itself

### 2. Required GitHub Secrets

To enable automated updates, you need to set these secrets in your GitHub repository:

1. Go to your GitHub repository
2. Navigate to Settings → Secrets and variables → Actions
3. Add these repository secrets:

```
DOCKER_USERNAME = nseba
DOCKER_PASSWORD = your-docker-hub-token-or-password
```

**Security Note:** It's highly recommended to use a Docker Hub Access Token instead of your password:

1. Go to [Docker Hub Account Settings](https://hub.docker.com/settings/security)
2. Create a new Access Token with Read & Write permissions
3. Use this token as your `DOCKER_PASSWORD` secret

## Manual Methods

### 1. Using the Script Directly

```bash
# Set environment variables
export DOCKER_USERNAME=nseba
export DOCKER_PASSWORD=your-docker-hub-token

# Run the script
./scripts/update-docker-description.sh
```

### 2. Using Makefile

```bash
# Set environment variables
export DOCKER_USERNAME=nseba
export DOCKER_PASSWORD=your-docker-hub-token

# Update description
make docker-update-description
```

## Configuration

### Repository Settings
The automation is configured for:
- **Docker Repository:** `nseba/commit-ai`
- **Short Description:** "AI-powered commit message generator for Git repositories using multiple LLM providers"
- **Full Description:** Content from README.md

### Customization
To customize for different repositories, update these files:

1. **GitHub Workflows:**
   ```yaml
   # In .github/workflows/ci.yml and .github/workflows/docker-description.yml
   repository: your-username/your-repo-name
   short-description: "Your custom description"
   ```

2. **Manual Script:**
   ```bash
   # In scripts/update-docker-description.sh
   DOCKER_REPO="your-username/your-repo-name"
   SHORT_DESCRIPTION="Your custom description"
   ```

3. **Makefile:**
   ```makefile
   # In Makefile
   DOCKER_USERNAME ?= your-username
   ```

## Features

### GitHub Actions Features
- ✅ Automatic updates on README changes
- ✅ Integrates with Docker image builds
- ✅ Handles both short and full descriptions
- ✅ URL completion for relative links
- ✅ Secure token handling via GitHub Secrets

### Manual Script Features
- ✅ Colored output for better UX
- ✅ Comprehensive error checking
- ✅ Authentication validation
- ✅ JSON response formatting (with jq)
- ✅ Repository information display
- ✅ Secure token handling

## Troubleshooting

### Common Issues

#### 1. Authentication Failures
```
Error: Failed to authenticate with Docker Hub
```

**Solutions:**
- Verify `DOCKER_USERNAME` and `DOCKER_PASSWORD` are set correctly
- Use a Docker Hub Access Token instead of password
- Check that the username matches exactly (case-sensitive)

#### 2. Repository Not Found
```
Error: Failed to update Docker Hub description
Response: {"detail": "Object not found"}
```

**Solutions:**
- Verify the repository name is correct in the configuration
- Ensure you have write permissions to the repository
- Check that the repository exists on Docker Hub

#### 3. README Content Issues
```
Error: Invalid JSON payload
```

**Solutions:**
- Check for special characters in README that might break JSON encoding
- Ensure README.md file exists and is readable
- Test with a simplified README first

### Debug Mode

For the manual script, you can enable debug output:

```bash
# Add debug flag to see detailed curl responses
export DEBUG=1
./scripts/update-docker-description.sh
```

### Checking Current Status

Use the Docker status checker:

```bash
make docker-status
```

This will show:
- Docker version and status
- Docker Hub login status
- Current user

## Workflow Examples

### Typical Development Workflow

1. **Make changes to README.md**
2. **Commit and push to main branch**
   ```bash
   git add README.md
   git commit -m "docs: update README"
   git push origin main
   ```
3. **GitHub Actions automatically updates Docker Hub** (within ~1-2 minutes)

### Manual Update Workflow

1. **Set environment variables** (one-time setup)
   ```bash
   export DOCKER_USERNAME=nseba
   export DOCKER_PASSWORD=your-token
   ```
2. **Update description**
   ```bash
   make docker-update-description
   ```

### Release Workflow

1. **Create and push a version tag**
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
2. **GitHub Actions will:**
   - Build and test the code
   - Create a GitHub release
   - Build and push Docker images
   - Update Docker Hub description

## Monitoring

### GitHub Actions
Monitor automation status at: `https://github.com/nseba/commit-ai/actions`

### Docker Hub
Check results at: `https://hub.docker.com/r/nseba/commit-ai`

### Notifications
GitHub Actions will send notifications on workflow failures if configured in your GitHub notification settings.

## Best Practices

1. **Use Access Tokens:** Always use Docker Hub Access Tokens instead of passwords
2. **README Structure:** Structure your README with Docker users in mind
3. **Test Locally:** Test manual updates before relying on automation
4. **Monitor Workflows:** Regularly check GitHub Actions for any failures
5. **Keep Secrets Updated:** Rotate access tokens periodically for security

## Advanced Configuration

### Custom Short Description
You can customize the short description by modifying the workflows and script:

```yaml
# In GitHub workflows
short-description: "Your custom description (max 100 characters)"
```

### Conditional Updates
You can modify workflows to only update on specific conditions:

```yaml
# Only update on version tags
if: startsWith(github.ref, 'refs/tags/v')
```

### Multiple Repositories
For managing multiple Docker repositories, duplicate and modify the workflows with different repository names.