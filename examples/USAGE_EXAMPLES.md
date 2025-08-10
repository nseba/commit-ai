# Commit-AI Usage Examples

This file contains practical examples of using commit-ai's interactive features.

## Basic Usage

### Show Last Commit Message
```bash
# Display the last commit message in a formatted way
commit-ai --show
commit-ai -s
```

### Generate Commit Message (Default Behavior)
```bash
# Generate AI commit message for staged changes
git add .
commit-ai

# Use the generated message directly
git commit -m "$(commit-ai)"
```

## Interactive Features

### Interactive Editing
```bash
# Generate message and allow editing
commit-ai --edit
commit-ai -e
```

This will:
1. Generate an AI commit message
2. Display the generated message
3. Ask how you want to proceed:
   - Keep as is
   - Edit inline (type new message in terminal)
   - Edit with external editor (opens $EDITOR)

### Auto-Stage and Commit
```bash
# Stage all changes and commit in one command
commit-ai --add --commit
commit-ai -a -c
```

This will:
1. Stage all changes (`git add .`)
2. Generate commit message
3. Ask for confirmation
4. Create the commit

### Full Interactive Workflow
```bash
# Complete interactive workflow
commit-ai --add --edit --commit
commit-ai -a -e -c
```

This provides the full experience:
1. Stages all changes
2. Generates AI commit message
3. Allows editing the message
4. Commits after confirmation

## Workflow Examples

### Quick Development Workflow
```bash
# Make changes
echo "new feature" >> src/app.js

# Quick commit with AI message
commit-ai -a -c
```

### Careful Review Workflow
```bash
# Stage specific files
git add src/important.js

# Generate and review message
commit-ai --edit

# Edit if needed, then commit manually
git commit -m "reviewed message"
```

### Show and Compare
```bash
# Check what the last commit was about
commit-ai --show

# See what AI suggests for current changes
commit-ai
```

## Configuration Examples

### Using Different AI Providers

#### Ollama (Local AI)
```bash
# Set environment variables for this session
export CAI_PROVIDER=ollama
export CAI_MODEL=codellama
export CAI_API_URL=http://localhost:11434

commit-ai -e
```

#### OpenAI
```bash
# Use OpenAI for better quality (requires API key)
export CAI_PROVIDER=openai
export CAI_MODEL=gpt-4
export CAI_API_TOKEN=sk-your-api-key

commit-ai -e
```

### Language Settings
```bash
# Generate commit messages in Spanish
export CAI_LANGUAGE=spanish
commit-ai

# Generate in French
export CAI_LANGUAGE=french
commit-ai -e
```

## Git Integration

### Git Aliases
Add these to your `.gitconfig`:

```ini
[alias]
    # Quick AI commit
    aic = !git add . && git commit -m "$(commit-ai)"
    
    # Interactive AI commit
    ai = !commit-ai -a -e -c
    
    # Show last commit nicely
    last = !commit-ai --show
```

Usage:
```bash
git aic        # Quick AI commit
git ai         # Interactive AI commit
git last       # Show last commit
```

### Shell Functions
Add to your `.bashrc` or `.zshrc`:

```bash
# Interactive commit with preview
function gai() {
    if [ -n "$(git diff --staged)" ] || [ -n "$(git diff)" ]; then
        commit-ai --edit
    else
        echo "No changes to commit"
    fi
}

# Quick AI commit with confirmation
function gaiq() {
    local msg=$(commit-ai)
    echo "AI suggests: $msg"
    read -p "Use this message? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git add .
        git commit -m "$msg"
        echo "✓ Committed!"
    else
        echo "Cancelled"
    fi
}

# Show commit history with AI analysis
function gailog() {
    commit-ai --show
    echo
    git log --oneline -5
}
```

## Error Handling Examples

### No Staged Changes
```bash
$ commit-ai -c
Error: no staged changes to commit

# Solution: stage changes first
$ commit-ai -a -c  # or git add . && commit-ai -c
```

### AI Provider Not Available
```bash
$ commit-ai
Error: failed to make request to Ollama: connection refused

# Solutions:
# 1. Start Ollama: ollama serve
# 2. Use OpenAI: export CAI_PROVIDER=openai CAI_API_TOKEN=sk-...
# 3. Just show last commit: commit-ai --show
```

### No Changes After Ignore Patterns
```bash
$ commit-ai
No changes after applying ignore patterns

# Check .caiignore file - might be ignoring everything
$ cat .caiignore
```

## Advanced Examples

### Custom Prompt Template
Create `~/.config/commit-ai/detailed.txt`:
```text
Generate a detailed commit message for:
{{.Diff}}

Include:
- Summary (50 chars max)
- Detailed explanation
- Impact assessment

Language: {{.Language}}
```

Use it:
```bash
export CAI_PROMPT_TEMPLATE=detailed.txt
commit-ai -e
```

### Ignoring Files
Create `.caiignore`:
```gitignore
*.log
dist/
node_modules/
*.test.js
```

### Working with Different Repositories
```bash
# Work on specific repository
commit-ai --path /path/to/other/repo --show

# Use different config per project
commit-ai --config ./project-config.toml -e
```

### Batch Operations
```bash
# Process multiple repositories
for repo in ~/projects/*/; do
    echo "Processing $repo"
    commit-ai --path "$repo" --show
done
```

## Troubleshooting Examples

### Debug Mode
```bash
# Enable debug logging
DEBUG=1 commit-ai -e
```

### Test Configuration
```bash
# Test if config is valid
commit-ai --help  # Should show all flags

# Test AI connection
commit-ai --edit  # Will show connection errors if any
```

### Timeout Issues
```bash
# Increase timeout for large diffs
export CAI_TIMEOUT_SECONDS=600
commit-ai -e
```

## Integration with IDEs

### VS Code
Create a task in `.vscode/tasks.json`:
```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "AI Commit",
            "type": "shell",
            "command": "commit-ai",
            "args": ["-a", "-e", "-c"],
            "group": "build",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared"
            }
        }
    ]
}
```

### Vim/Neovim
Add to your config:
```vim
" Quick AI commit
nnoremap <leader>gc :!commit-ai -a -c<CR>

" Interactive AI commit
nnoremap <leader>gi :!commit-ai -a -e -c<CR>

" Show last commit
nnoremap <leader>gl :!commit-ai --show<CR>
```

## Tips and Best Practices

1. **Use `--show` to review**: Always check what you committed with `commit-ai --show`

2. **Stage selectively**: Instead of `--add`, stage specific files first:
   ```bash
   git add src/
   commit-ai -e -c
   ```

3. **Edit messages**: Use `--edit` to improve AI suggestions:
   ```bash
   commit-ai --edit  # Review and improve before committing
   ```

4. **Combine flags wisely**:
   - `-s`: Just show information
   - `-e`: Generate and edit (no commit)
   - `-c`: Generate and commit (careful!)
   - `-a -e -c`: Full interactive workflow (recommended)

5. **Use ignore patterns**: Create `.caiignore` to focus on important changes

6. **Test first**: Use `commit-ai` (without flags) to see what it would generate

These examples should help you integrate commit-ai's interactive features into your development workflow effectively.