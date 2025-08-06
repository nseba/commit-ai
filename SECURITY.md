# Security Policy

## Supported Versions

We actively support and provide security updates for the following versions of Commit-AI:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Recent Security Updates

For detailed information about recent security fixes and vulnerability resolutions, see [SECURITY_UPDATES.md](SECURITY_UPDATES.md).

## Reporting a Vulnerability

The Commit-AI team takes security seriously. We appreciate your efforts to responsibly disclose your findings and will make every effort to acknowledge your contributions.

### How to Report

**Please do NOT report security vulnerabilities through public GitHub issues.**

Instead, please report security vulnerabilities by emailing us at:
- **Email**: security@commit-ai.dev
- **Subject**: [SECURITY] Brief description of the issue

If you don't receive a response within 48 hours, please follow up via GitHub by creating an issue with minimal details (no exploit information) asking us to check our email.

### What to Include

Please include the following information in your security report:

1. **Description**: A clear description of the vulnerability
2. **Steps to Reproduce**: Detailed steps to reproduce the issue
3. **Impact**: Your assessment of the potential impact
4. **Affected Versions**: Which versions of Commit-AI are affected
5. **Environment**: OS, Go version, configuration details
6. **Proof of Concept**: If possible, include a minimal proof of concept
7. **Suggested Fix**: If you have ideas for how to fix the issue

### Example Report Format

```
Subject: [SECURITY] API Token Exposure in Configuration

Description:
Brief description of the vulnerability

Affected Versions:
- All versions prior to X.X.X

Steps to Reproduce:
1. Step one
2. Step two
3. Step three

Impact:
Description of potential impact

Environment:
- OS: Ubuntu 22.04
- commit-ai version: v1.0.0
- Configuration: [relevant config details]

Proof of Concept:
[Minimal reproduction case]

Suggested Fix:
[Your suggestions if any]
```

## Security Response Process

1. **Acknowledgment**: We will acknowledge receipt of your report within 48 hours
2. **Initial Assessment**: We will perform an initial assessment within 5 business days
3. **Investigation**: We will investigate and develop a fix
4. **Coordination**: We will work with you to understand the issue and coordinate disclosure
5. **Release**: We will release a security update and announce it publicly
6. **Credit**: We will credit you for the discovery (unless you prefer to remain anonymous)

## Security Considerations

### API Token Security

- **Storage**: API tokens should be stored securely in configuration files with appropriate file permissions (600)
- **Environment Variables**: Use environment variables for sensitive configuration in production
- **Logging**: API tokens are never logged or included in error messages
- **Transmission**: All API communications use HTTPS/TLS encryption

### Configuration File Security

- Configuration files may contain sensitive information (API tokens)
- Set appropriate file permissions: `chmod 600 ~/.config/commit-ai/config.toml`
- Avoid committing configuration files to version control
- Use environment variables for sensitive values in CI/CD environments

### Git Repository Security

- Commit-AI only reads git repository data, never writes
- No sensitive data from your repository is sent to AI providers
- Use `.caiignore` files to exclude sensitive files from analysis
- The tool respects existing `.gitignore` patterns

### AI Provider Communications

- All communications with AI providers use secure protocols (HTTPS)
- Only git diff data is sent to AI providers
- No personal information, credentials, or business logic is transmitted
- API tokens are transmitted securely using standard authentication headers

### Docker Security

- Docker images use non-root users
- Minimal base images to reduce attack surface
- Regular updates to base images and dependencies
- No sensitive data baked into images

## Best Practices for Users

### Secure Configuration

1. **File Permissions**: Ensure your config directory has proper permissions:
   ```bash
   chmod 700 ~/.config/commit-ai
   chmod 600 ~/.config/commit-ai/config.toml
   ```

2. **Environment Variables**: Use environment variables for sensitive data:
   ```bash
   export CAI_API_TOKEN="your-secret-token"
   ```

3. **API Token Management**:
   - Use API tokens with minimal required permissions
   - Rotate API tokens regularly
   - Never commit API tokens to version control

### Repository Security

1. **Use .caiignore**: Create `.caiignore` files to exclude sensitive files:
   ```
   *.key
   *.pem
   secrets/
   .env
   config/production.yml
   ```

2. **Review Diffs**: Always review what changes will be analyzed before running commit-ai
3. **Sensitive Data**: Ensure no passwords, keys, or sensitive data are in your diffs

### Network Security

1. **Firewall**: If using Ollama locally, ensure it's not exposed to external networks
2. **VPN**: Use VPN when working with sensitive repositories on public networks
3. **HTTPS**: Always use HTTPS endpoints for external AI providers

## Dependency Security

We regularly monitor and update our dependencies to address security vulnerabilities:

- **Automated Scanning**: GitHub Dependabot scans for vulnerable dependencies
- **Security Advisories**: We monitor security advisories for Go and our dependencies
- **Update Policy**: Security updates are prioritized and released quickly
- **Recent Fixes**: See [SECURITY_UPDATES.md](SECURITY_UPDATES.md) for recent vulnerability fixes

## Security Auditing

- **Static Analysis**: We use `gosec` for static security analysis
- **Dependency Scanning**: Regular dependency vulnerability scanning
- **Code Review**: All changes undergo security-focused code review

## Threat Model

### In Scope

- Configuration file security
- API token handling
- Network communications
- Input validation and sanitization
- Dependency vulnerabilities
- Docker container security

### Out of Scope

- Security of third-party AI providers (Ollama, OpenAI)
- Security of the underlying git repository
- Operating system or hardware security
- Network infrastructure security

## Incident Response

In case of a security incident:

1. **Immediate Response**: Assess and contain the issue
2. **User Notification**: Notify affected users via GitHub security advisories
3. **Fix Development**: Develop and test a security fix
4. **Release**: Create emergency release with security fix
5. **Post-Incident**: Conduct post-incident review and improve processes

## Contact Information

- **Security Email**: security@commit-ai.dev
- **General Issues**: https://github.com/nseba/commit-ai/issues
- **Discussions**: https://github.com/nseba/commit-ai/discussions

## Hall of Fame

We'd like to thank the following individuals for responsibly disclosing security vulnerabilities:

<!-- Security researchers who report vulnerabilities will be listed here -->

*No vulnerabilities reported yet.*

---

Last Updated: December 2024
