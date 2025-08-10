# Interactive Features - New in Commit-AI

This document describes the new interactive features added to commit-ai, allowing for better commit message workflow management.

## 🎯 Overview

Commit-AI now includes interactive features that enhance the commit workflow by allowing users to:
- View the last commit message in a formatted display
- Edit generated commit messages before using them
- Automatically stage changes and commit in one workflow
- Combine all features for a complete interactive experience

## 🚀 New Command Line Flags

| Flag | Short | Description |
|------|-------|-------------|
| `--show` | `-s` | Show the last commit message in a formatted display |
| `--edit` | `-e` | Allow editing of the generated commit message |
| `--commit` | `-c` | Commit the changes with the generated/edited message |
| `--add` | `-a` | Stage all changes before generating commit message |

## 📋 Feature Details

### 1. Show Last Commit Message (`--show`, `-s`)
Displays the last commit message in a nicely formatted way:

```bash
commit-ai --show
```

Output:
```
Last Commit Message:
─────────────────────────────────────────────────────────────
feat: add new interactive editing capabilities

This commit introduces interactive features for better
commit workflow management.
─────────────────────────────────────────────────────────────
```

**Benefits:**
- Quick review of recent commit messages
- Works without AI provider (no network needed)
- Formatted display for better readability
- Useful for understanding recent changes

### 2. Interactive Editing (`--edit`, `-e`)
Allows editing of generated commit messages before use:

```bash
commit-ai --edit
```

**Workflow:**
1. Generates AI commit message
2. Displays the generated message
3. Prompts user for editing preference:
   - Keep as is
   - Edit inline (terminal input)
   - Edit with external editor (`$EDITOR`)

**Benefits:**
- Review and improve AI suggestions
- Customize messages for specific requirements
- Use familiar editors (vim, nano, VS Code, etc.)
- Fallback to inline editing if no editor configured

### 3. Auto-Commit (`--commit`, `-c`)
Commits changes using the generated/edited message:

```bash
commit-ai --commit
```

**Workflow:**
1. Generates commit message
2. Shows final message
3. Asks for confirmation
4. Creates the commit if confirmed

**Safety Features:**
- Requires staged changes (prevents accidental empty commits)
- Shows confirmation prompt
- Displays final message before committing
- Can be cancelled at confirmation step

### 4. Auto-Stage (`--add`, `-a`)
Automatically stages all changes before processing:

```bash
commit-ai --add
```

**Benefits:**
- Streamlines workflow (no need for separate `git add`)
- Works with all other flags
- Equivalent to running `git add .` first

## 🔄 Combined Workflows

### Basic Interactive Workflow
```bash
commit-ai --edit
```
- Generate → Edit → Display (no commit)

### Auto-Stage and Commit
```bash
commit-ai --add --commit
```
- Stage → Generate → Confirm → Commit

### Full Interactive Experience
```bash
commit-ai --add --edit --commit
```
- Stage → Generate → Edit → Confirm → Commit

## 🛠️ Technical Implementation

### New Components Added

1. **Interactive Editor Module** (`internal/cli/interactive.go`)
   - Handles user input and interaction
   - Manages different editing modes
   - Provides formatted output display
   - Supports external editor integration

2. **Enhanced Git Operations** (`internal/git/repository.go`)
   - `GetLastCommitMessage()` - Retrieves last commit message
   - `Commit()` - Creates commits with proper git config
   - `StageAll()` - Stages all changes in working directory
   - Git config integration for author information

3. **Enhanced CLI Interface** (`internal/cli/root.go`)
   - New command-line flags
   - Interactive workflow management
   - Error handling for different scenarios
   - Integration with existing AI generation

### Key Features

- **Editor Detection**: Automatically detects and uses `$EDITOR` or `$VISUAL`
- **Fallback Support**: Falls back to common editors (nano, vim, vi, emacs)
- **Safety Checks**: Validates staged changes before committing
- **User Confirmation**: Always asks before making commits
- **Formatted Display**: Consistent, readable output formatting

## 🎯 Use Cases

### Development Workflows

1. **Quick Review**: `commit-ai --show`
   - Check what was committed last
   - Understand recent changes quickly

2. **Careful Commits**: `commit-ai --edit`
   - Generate AI suggestion
   - Review and improve message
   - Use elsewhere (copy-paste, scripts)

3. **Streamlined Commits**: `commit-ai --add --commit`
   - Stage everything and commit in one step
   - Perfect for small, focused changes

4. **Full Control**: `commit-ai --add --edit --commit`
   - Complete interactive workflow
   - Maximum control and safety

### Integration Examples

**Git Aliases:**
```bash
git config --global alias.ai '!commit-ai -a -e -c'
git config --global alias.last '!commit-ai --show'
```

**Shell Functions:**
```bash
function gai() {
    commit-ai --edit
}

function gaiq() {
    commit-ai --add --commit
}
```

## 🔧 Configuration

All existing configuration options work with new features:
- AI provider settings (Ollama, OpenAI)
- Language preferences
- Custom prompt templates
- Timeout configurations
- Ignore patterns (`.caiignore`)

## 🚨 Safety Features

1. **Staged Changes Validation**: Won't commit without staged changes
2. **User Confirmation**: Always prompts before committing
3. **Message Display**: Shows final message before commit
4. **Cancellation Support**: Can cancel at any confirmation prompt
5. **Error Handling**: Graceful handling of missing editors, git errors, etc.

## 📊 Backward Compatibility

- All existing functionality remains unchanged
- New flags are additive (don't affect existing usage)
- Default behavior (no flags) works exactly as before
- Existing configurations and templates work with new features

## 🧪 Testing

Run the interactive demo:
```bash
./examples/interactive-demo.sh
```

Test individual features:
```bash
commit-ai --show                    # View last commit
commit-ai --edit                    # Generate and edit
commit-ai --add --commit           # Stage and commit
commit-ai --add --edit --commit    # Full workflow
```

## 📚 Additional Resources

- See `examples/USAGE_EXAMPLES.md` for detailed usage examples
- Run `examples/interactive-demo.sh` for a guided demonstration
- Check `README.md` for updated documentation
- Use `commit-ai --help` to see all available options

## 🎉 Summary

These interactive features transform commit-ai from a simple message generator into a complete commit workflow tool, providing:

- ✅ Better user control and safety
- ✅ Streamlined development workflows  
- ✅ Enhanced message quality through editing
- ✅ Flexible integration options
- ✅ Backward compatibility
- ✅ Comprehensive error handling

The new features maintain the simplicity of the original tool while adding powerful interactive capabilities for users who want more control over their commit process.