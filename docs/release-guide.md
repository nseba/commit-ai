# Release Guide

This guide covers all the ways to create releases for the commit-ai project, from automated pipelines to manual processes.

## 🚀 Quick Start

### Create a Release (Recommended Method)
```bash
# Full release with pre-checks and automated versioning
make release VERSION=v1.0.1

# Or use automatic version incrementing
make release-patch    # v1.0.0 -> v1.0.1
make release-minor    # v1.0.0 -> v1.1.0
make release-major    # v1.0.0 -> v2.0.0
```

### Check What Version to Release Next
```bash
make release-next-patch    # Shows v1.0.0 -> v1.0.1
make release-next-minor    # Shows v1.0.0 -> v1.1.0
make release-next-major    # Shows v1.0.0 -> v2.0.0
```

### Check Current Release Status
```bash
make release-status        # Shows recent releases
```

## 📋 Release Methods

### Method 1: Automated Release (Recommended)

The `make release` command runs comprehensive checks and creates the release:

```bash
make release VERSION=v1.2.0
```

**What it does:**
1. ✅ Checks git working directory is clean
2. ✅ Verifies you're on the main branch
3. ✅ Runs all tests
4. ✅ Runs security scans
5. ✅ Tests the build
6. ✅ Creates and pushes git tag
7. 🚀 Triggers GitHub Actions release pipeline

### Method 2: Quick Tag Creation

If you just want to create and push a tag:

```bash
make release-tag VERSION=v1.2.0
```

### Method 3: Pre-Check Only

Run all the pre-release checks without creating a release:

```bash
make release-check
```

### Method 4: Manual Release Script

If the automated pipeline fails, use the manual script:

```bash
make release-manual VERSION=v1.2.0

# Or run directly:
./scripts/create-release.sh --version v1.2.0
```

## 🏷️ Version Management

### Semantic Versioning

We use [semantic versioning](https://semver.org/):

- **Major** (`v1.0.0` → `v2.0.0`): Breaking changes
- **Minor** (`v1.0.0` → `v1.1.0`): New features, backward compatible
- **Patch** (`v1.0.0` → `v1.0.1`): Bug fixes, backward compatible

### Automatic Version Helpers

```bash
# See what version would be next
make release-next-patch
make release-next-minor
make release-next-major

# Create release with auto-incremented version
make release-patch
make release-minor
make release-major
```

### Version Cleanup

```bash
# Delete a tag if you made a mistake
make release-delete-tag VERSION=v1.2.0
```

## 🔍 Pre-Release Checklist

Before creating a release, ensure:

```bash
# 1. Working directory is clean
git status

# 2. All changes are committed and pushed
git push origin main

# 3. Tests pass
make test

# 4. Security checks pass
make security-all

# 5. Build works
make build

# 6. No vulnerabilities
make security-deps
```

Or run all checks at once:
```bash
make release-check
```

## 🎯 Release Pipeline (GitHub Actions)

When you push a version tag (like `v1.2.0`), GitHub Actions automatically:

### 1. Build Multi-Platform Binaries
- `commit-ai-linux-amd64`
- `commit-ai-linux-arm64`
- `commit-ai-darwin-amd64`
- `commit-ai-darwin-arm64`
- `commit-ai-windows-amd64.exe`

### 2. Create Docker Images
- Multi-platform: `linux/amd64`, `linux/arm64`
- Tags: `nseba/commit-ai:v1.2.0`, `nseba/commit-ai:1.2`, `nseba/commit-ai:latest`

### 3. Generate GitHub Release
- Automatic changelog from git commits
- Attach all binary files
- Release notes with security information

### 4. Update External Services
- Docker Hub description update
- Homebrew formula update (if configured)

## 📊 Monitoring Releases

### Check Release Status
```bash
make release-status
```

### Monitor GitHub Actions
- **Actions Page**: `https://github.com/nseba/commit-ai/actions`
- **Releases Page**: `https://github.com/nseba/commit-ai/releases`
- **Docker Hub**: `https://hub.docker.com/r/nseba/commit-ai`

### Expected Timeline
- **Build Phase**: 5-10 minutes (multi-platform builds)
- **Docker Phase**: 3-5 minutes (multi-arch images)
- **Release Creation**: 1-2 minutes
- **Total**: 10-15 minutes

## 🛠️ Manual Release Process

If the automated pipeline fails, use the manual script:

### Prerequisites
```bash
# Install GitHub CLI
brew install gh                    # macOS
sudo apt install gh               # Ubuntu
# Or download from: https://cli.github.com/

# Login to GitHub
gh auth login
```

### Run Manual Release
```bash
# Full manual release
make release-manual VERSION=v1.2.0

# Or run script directly
./scripts/create-release.sh --version v1.2.0

# Skip pre-checks if needed
./scripts/create-release.sh --version v1.2.0 --skip-checks
```

## 🚨 Troubleshooting

### Common Issues

#### 1. GitHub Actions Permission Denied
**Error**: `Error: Resource not accessible by integration`

**Solution**: Update repository settings
1. Go to: `https://github.com/nseba/commit-ai/settings/actions`
2. Under "Workflow permissions":
   - Select: "Read and write permissions"
   - Check: "Allow GitHub Actions to create and approve pull requests"
3. Save settings

#### 2. Docker Build Fails
**Error**: `go: go.mod requires go >= 1.24.4`

**Solution**: Already fixed in our Dockerfiles
- `Dockerfile` and `Dockerfile.dev` use `golang:1.24-alpine`
- CI pipeline uses Go 1.24.4

#### 3. Tag Already Exists
**Error**: `tag v1.2.0 already exists`

**Solution**: Delete and recreate tag
```bash
make release-delete-tag VERSION=v1.2.0
make release-tag VERSION=v1.2.0
```

#### 4. Working Directory Not Clean
**Error**: `Working directory is not clean`

**Solution**: Commit or stash changes
```bash
git add .
git commit -m "prepare for release"
# Then try release again
```

#### 5. Not on Main Branch
**Warning**: `Not on main branch`

**Solution**: Switch to main or continue anyway
```bash
git checkout main
git pull origin main
# Then try release again
```

### Debug Failed Release

1. **Check GitHub Actions logs**:
   ```
   https://github.com/nseba/commit-ai/actions
   ```

2. **Check Docker Hub**:
   ```
   https://hub.docker.com/r/nseba/commit-ai
   ```

3. **Re-run failed workflows**:
   - Go to GitHub Actions
   - Click on failed workflow
   - Click "Re-run all jobs"

## 📝 Release Types

### Patch Release (Bug Fixes)
```bash
# For bug fixes, security patches
make release-patch
# or
make release VERSION=v1.0.1
```

### Minor Release (New Features)
```bash
# For new features, backwards compatible
make release-minor
# or
make release VERSION=v1.1.0
```

### Major Release (Breaking Changes)
```bash
# For breaking changes, major updates
make release-major
# or
make release VERSION=v2.0.0
```

### Pre-Release
```bash
# For alpha, beta, or release candidates
make release VERSION=v1.0.0-alpha.1
make release VERSION=v1.0.0-beta.1
make release VERSION=v1.0.0-rc.1
```

## 🎉 After Release

### Verify Release Success

1. **Check GitHub Release**: `https://github.com/nseba/commit-ai/releases`
   - ✅ Binaries attached
   - ✅ Release notes generated
   - ✅ Tagged correctly

2. **Check Docker Images**: `https://hub.docker.com/r/nseba/commit-ai`
   - ✅ New version tag present
   - ✅ Latest tag updated
   - ✅ Multi-platform support

3. **Test Installation**:
   ```bash
   # Test Go installation
   go install github.com/nseba/commit-ai/cmd@v1.2.0
   
   # Test Docker image
   docker pull nseba/commit-ai:v1.2.0
   docker run --rm nseba/commit-ai:v1.2.0 version
   ```

### Post-Release Tasks

1. **Update Documentation** (if needed)
2. **Announce Release** (social media, forums, etc.)
3. **Monitor for Issues** (GitHub issues, user feedback)
4. **Plan Next Release** (roadmap, features)

## 📚 Examples

### Standard Workflow
```bash
# Check current status
make release-status

# See what version is next
make release-next-patch

# Run pre-checks
make release-check

# Create release
make release-patch

# Monitor progress
make release-status
```

### Emergency Patch Release
```bash
# Quick security fix release
git add .
git commit -m "security: fix critical vulnerability"
git push origin main
make release-patch
```

### Major Feature Release
```bash
# After completing major features
git checkout main
git pull origin main
make release-check
make release-minor  # or release-major for breaking changes
```

### Manual Fallback
```bash
# If automation fails
make release-manual VERSION=v1.2.0
```

## 🔗 Related Documentation

- [Security Updates](../SECURITY_UPDATES.md) - Recent security fixes
- [Contributing](../CONTRIBUTING.md) - Development workflow
- [Docker Automation](docker-hub-automation.md) - Docker build process
- [GitHub Actions](.github/workflows/ci.yml) - CI/CD configuration

## 💡 Tips

1. **Always test locally** before creating a release
2. **Use semantic versioning** consistently
3. **Write good commit messages** (they become release notes)
4. **Monitor releases** for the first 24 hours
5. **Keep security updates** in patch releases when possible
6. **Use pre-releases** for testing major changes

## 🆘 Need Help?

- **Create an Issue**: `https://github.com/nseba/commit-ai/issues`
- **Check Actions**: `https://github.com/nseba/commit-ai/actions`
- **Review Docs**: This guide and related documentation
- **Manual Override**: Use `./scripts/create-release.sh` for full control