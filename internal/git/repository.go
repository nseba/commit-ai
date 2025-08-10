package git

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"time"

	"github.com/go-git/go-git/v5"
	"github.com/go-git/go-git/v5/plumbing/object"
	gitignore "github.com/sabhiram/go-gitignore"
)

// Repository represents a git repository with additional functionality
type Repository struct {
	repo     *git.Repository
	workTree *git.Worktree
	path     string
}

// NewRepository creates a new Repository instance
func NewRepository(path string) (*Repository, error) {
	absPath, err := filepath.Abs(path)
	if err != nil {
		return nil, fmt.Errorf("failed to get absolute path: %w", err)
	}

	repo, err := git.PlainOpen(absPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open git repository at %s: %w", absPath, err)
	}

	workTree, err := repo.Worktree()
	if err != nil {
		return nil, fmt.Errorf("failed to get worktree: %w", err)
	}

	return &Repository{
		repo:     repo,
		workTree: workTree,
		path:     absPath,
	}, nil
}

// GetDiff returns the diff of staged changes, or unstaged changes if nothing is staged
func (r *Repository) GetDiff() (string, error) {
	// First, try to get staged changes
	stagedDiff, err := r.getStagedDiff()
	if err != nil {
		return "", fmt.Errorf("failed to get staged diff: %w", err)
	}

	if stagedDiff != "" {
		return stagedDiff, nil
	}

	// If no staged changes, get unstaged changes
	return r.getUnstagedDiff()
}

// getStagedDiff returns the diff of staged changes
func (r *Repository) getStagedDiff() (string, error) {
	head, err := r.repo.Head()
	if err != nil {
		// If there's no HEAD (empty repo), compare against empty tree
		return r.getInitialCommitDiff()
	}

	headCommit, err := r.repo.CommitObject(head.Hash())
	if err != nil {
		return "", fmt.Errorf("failed to get HEAD commit: %w", err)
	}

	headTree, err := headCommit.Tree()
	if err != nil {
		return "", fmt.Errorf("failed to get HEAD tree: %w", err)
	}

	// Get the index (staging area)
	status, err := r.workTree.Status()
	if err != nil {
		return "", fmt.Errorf("failed to get status: %w", err)
	}

	var diffLines []string
	for file, fileStatus := range status {
		// Only process staged files
		if fileStatus.Staging == git.Unmodified {
			continue
		}

		fileDiff, err := r.getFileDiff(file, headTree)
		if err != nil {
			return "", fmt.Errorf("failed to get diff for file %s: %w", file, err)
		}

		if fileDiff != "" {
			diffLines = append(diffLines, fileDiff)
		}
	}

	return strings.Join(diffLines, "\n"), nil
}

// getUnstagedDiff returns the diff of unstaged changes
func (r *Repository) getUnstagedDiff() (string, error) {
	status, err := r.workTree.Status()
	if err != nil {
		return "", fmt.Errorf("failed to get status: %w", err)
	}

	head, err := r.repo.Head()
	if err != nil {
		// If there's no HEAD (empty repo), compare against empty tree
		return r.getInitialCommitDiff()
	}

	headCommit, err := r.repo.CommitObject(head.Hash())
	if err != nil {
		return "", fmt.Errorf("failed to get HEAD commit: %w", err)
	}

	headTree, err := headCommit.Tree()
	if err != nil {
		return "", fmt.Errorf("failed to get HEAD tree: %w", err)
	}

	var diffLines []string
	for file, fileStatus := range status {
		// Only process modified files in working directory
		if fileStatus.Worktree == git.Unmodified {
			continue
		}

		fileDiff, err := r.getFileDiff(file, headTree)
		if err != nil {
			return "", fmt.Errorf("failed to get diff for file %s: %w", file, err)
		}

		if fileDiff != "" {
			diffLines = append(diffLines, fileDiff)
		}
	}

	return strings.Join(diffLines, "\n"), nil
}

// getInitialCommitDiff handles the case when there's no HEAD (empty repository)
func (r *Repository) getInitialCommitDiff() (string, error) {
	status, err := r.workTree.Status()
	if err != nil {
		return "", fmt.Errorf("failed to get status: %w", err)
	}

	var diffLines []string
	for file, fileStatus := range status {
		if fileStatus.Staging == git.Untracked && fileStatus.Worktree == git.Untracked {
			continue
		}

		if err := r.validatePath(file); err != nil {
			continue // Skip invalid paths
		}
		filePath := filepath.Join(r.path, file)
		content, err := os.ReadFile(filePath) // #nosec G304 -- path validated by validatePath()
		if err != nil {
			continue // Skip files that can't be read
		}

		diff := fmt.Sprintf("diff --git a/%s b/%s\nnew file mode 100644\nindex 0000000..%s\n--- /dev/null\n+++ b/%s\n%s",
			file, file, "xxxxxxx", file, addPlusPrefix(string(content)))

		diffLines = append(diffLines, diff)
	}

	return strings.Join(diffLines, "\n"), nil
}

// getFileDiff gets the diff for a specific file
func (r *Repository) getFileDiff(filename string, headTree *object.Tree) (string, error) {
	if err := r.validatePath(filename); err != nil {
		return "", err
	}
	filePath := filepath.Join(r.path, filename)

	// Read current file content
	currentContent, err := os.ReadFile(filePath) // #nosec G304 -- path validated by validatePath()
	if os.IsNotExist(err) {
		// File was deleted
		return r.getDeletedFileDiff(filename, headTree)
	}
	if err != nil {
		return "", fmt.Errorf("failed to read file %s: %w", filename, err)
	}

	// Get file content from HEAD
	headContent, err := r.getFileContentFromTree(filename, headTree)
	if err != nil {
		// New file
		return r.getNewFileDiff(filename, string(currentContent)), nil
	}

	// Generate diff
	return r.generateDiff(filename, headContent, string(currentContent)), nil
}

// getFileContentFromTree retrieves file content from a tree
func (r *Repository) getFileContentFromTree(filename string, tree *object.Tree) (string, error) {
	file, err := tree.File(filename)
	if err != nil {
		return "", err
	}

	content, err := file.Contents()
	if err != nil {
		return "", fmt.Errorf("failed to get file contents: %w", err)
	}

	return content, nil
}

// getNewFileDiff generates diff for a new file
func (r *Repository) getNewFileDiff(filename, content string) string {
	return fmt.Sprintf("diff --git a/%s b/%s\nnew file mode 100644\nindex 0000000..%s\n--- /dev/null\n+++ b/%s\n%s",
		filename, filename, "xxxxxxx", filename, addPlusPrefix(content))
}

// getDeletedFileDiff generates diff for a deleted file
func (r *Repository) getDeletedFileDiff(filename string, headTree *object.Tree) (string, error) {
	headContent, err := r.getFileContentFromTree(filename, headTree)
	if err != nil {
		return "", err
	}

	return fmt.Sprintf("diff --git a/%s b/%s\ndeleted file mode 100644\nindex %s..0000000\n--- a/%s\n+++ /dev/null\n%s",
		filename, filename, "xxxxxxx", filename, addMinusPrefix(headContent)), nil
}

// generateDiff generates a unified diff between two content strings
func (r *Repository) generateDiff(filename, oldContent, newContent string) string {
	if oldContent == newContent {
		return ""
	}

	oldLines := strings.Split(oldContent, "\n")
	newLines := strings.Split(newContent, "\n")

	var diffLines []string
	diffLines = append(diffLines, fmt.Sprintf("diff --git a/%s b/%s", filename, filename))
	diffLines = append(diffLines, fmt.Sprintf("index %s..%s 100644", "xxxxxxx", "xxxxxxx"))
	diffLines = append(diffLines, fmt.Sprintf("--- a/%s", filename))
	diffLines = append(diffLines, fmt.Sprintf("+++ b/%s", filename))

	// Simple diff implementation - for production, consider using a proper diff library
	maxLines := len(oldLines)
	if len(newLines) > maxLines {
		maxLines = len(newLines)
	}

	for i := 0; i < maxLines; i++ {
		var oldLine, newLine string
		if i < len(oldLines) {
			oldLine = oldLines[i]
		}
		if i < len(newLines) {
			newLine = newLines[i]
		}

		if oldLine != newLine {
			if oldLine != "" {
				diffLines = append(diffLines, "-"+oldLine)
			}
			if newLine != "" {
				diffLines = append(diffLines, "+"+newLine)
			}
		}
	}

	return strings.Join(diffLines, "\n")
}

// ApplyIgnorePatterns filters the diff content based on .caiignore files
func (r *Repository) ApplyIgnorePatterns(diff, basePath string) (string, error) {
	ignorePatterns, err := r.loadIgnorePatterns(basePath)
	if err != nil {
		return "", fmt.Errorf("failed to load ignore patterns: %w", err)
	}

	if len(ignorePatterns) == 0 {
		return diff, nil
	}

	// Split diff into file sections
	sections := r.splitDiffIntoSections(diff)
	var filteredSections []string

	for _, section := range sections {
		filename := r.extractFilenameFromDiff(section)
		if filename != "" {
			ignored := false
			for _, pattern := range ignorePatterns {
				if pattern.MatchesPath(filename) {
					ignored = true
					break
				}
			}
			if !ignored {
				filteredSections = append(filteredSections, section)
			}
		}
	}

	return strings.Join(filteredSections, "\n"), nil
}

// loadIgnorePatterns loads ignore patterns from .caiignore files
func (r *Repository) loadIgnorePatterns(basePath string) ([]*gitignore.GitIgnore, error) {
	var patterns []*gitignore.GitIgnore

	// Walk up the directory tree looking for .caiignore files
	currentPath := basePath
	for {
		ignoreFile := filepath.Join(currentPath, ".caiignore")
		if _, err := os.Stat(ignoreFile); err == nil {
			pattern, err := gitignore.CompileIgnoreFile(ignoreFile)
			if err != nil {
				return nil, fmt.Errorf("failed to compile ignore file %s: %w", ignoreFile, err)
			}
			patterns = append(patterns, pattern)
		}

		parent := filepath.Dir(currentPath)
		if parent == currentPath {
			break
		}
		currentPath = parent
	}

	return patterns, nil
}

// splitDiffIntoSections splits a unified diff into individual file sections
func (r *Repository) splitDiffIntoSections(diff string) []string {
	lines := strings.Split(diff, "\n")
	var sections []string
	var currentSection []string

	for _, line := range lines {
		if strings.HasPrefix(line, "diff --git") && len(currentSection) > 0 {
			sections = append(sections, strings.Join(currentSection, "\n"))
			currentSection = []string{line}
		} else {
			currentSection = append(currentSection, line)
		}
	}

	if len(currentSection) > 0 {
		sections = append(sections, strings.Join(currentSection, "\n"))
	}

	return sections
}

// extractFilenameFromDiff extracts the filename from a diff section
func (r *Repository) extractFilenameFromDiff(diffSection string) string {
	lines := strings.Split(diffSection, "\n")
	for _, line := range lines {
		if strings.HasPrefix(line, "diff --git") {
			parts := strings.Fields(line)
			if len(parts) >= 4 {
				// Extract filename from "a/filename" format
				filename := strings.TrimPrefix(parts[2], "a/")
				return filename
			}
		}
	}
	return ""
}

// Helper functions

// addPlusPrefix adds '+' prefix to each line of content
func addPlusPrefix(content string) string {
	lines := strings.Split(content, "\n")
	for i, line := range lines {
		if i == len(lines)-1 && line == "" {
			continue // Don't add prefix to empty last line
		}
		lines[i] = "+" + line
	}
	return strings.Join(lines, "\n")
}

// addMinusPrefix adds '-' prefix to each line of content
func addMinusPrefix(content string) string {
	lines := strings.Split(content, "\n")
	for i, line := range lines {
		if i == len(lines)-1 && line == "" {
			continue // Don't add prefix to empty last line
		}
		lines[i] = "-" + line
	}
	return strings.Join(lines, "\n")
}

// GetLastCommitMessage returns the message of the last commit
func (r *Repository) GetLastCommitMessage() (string, error) {
	head, err := r.repo.Head()
	if err != nil {
		return "", fmt.Errorf("failed to get HEAD: %w", err)
	}

	commit, err := r.repo.CommitObject(head.Hash())
	if err != nil {
		return "", fmt.Errorf("failed to get commit object: %w", err)
	}

	return commit.Message, nil
}

// Commit creates a new commit with the given message
func (r *Repository) Commit(message string) error {
	// First check if there are staged changes
	status, err := r.workTree.Status()
	if err != nil {
		return fmt.Errorf("failed to get status: %w", err)
	}

	hasStagedChanges := false
	for _, fileStatus := range status {
		if fileStatus.Staging != git.Unmodified {
			hasStagedChanges = true
			break
		}
	}

	if !hasStagedChanges {
		return fmt.Errorf("no staged changes to commit")
	}

	// Create the commit
	_, err = r.workTree.Commit(message, &git.CommitOptions{
		Author: &object.Signature{
			Name:  getGitConfigValue("user.name"),
			Email: getGitConfigValue("user.email"),
			When:  time.Now(),
		},
	})
	if err != nil {
		return fmt.Errorf("failed to create commit: %w", err)
	}

	return nil
}

// StageAll stages all changes in the working directory
func (r *Repository) StageAll() error {
	status, err := r.workTree.Status()
	if err != nil {
		return fmt.Errorf("failed to get status: %w", err)
	}

	for file := range status {
		_, err = r.workTree.Add(file)
		if err != nil {
			return fmt.Errorf("failed to stage file %s: %w", file, err)
		}
	}

	return nil
}

// getGitConfigValue gets a git config value
func getGitConfigValue(key string) string {
	// In a real implementation, you might want to read from git config
	// For now, return default values or empty strings
	switch key {
	case "user.name":
		if name := os.Getenv("GIT_AUTHOR_NAME"); name != "" {
			return name
		}
		return "commit-ai"
	case "user.email":
		if email := os.Getenv("GIT_AUTHOR_EMAIL"); email != "" {
			return email
		}
		return "commit-ai@localhost"
	}
	return ""
}

// validatePath validates that a file path is safe and doesn't contain path traversal attempts
func (r *Repository) validatePath(filename string) error {
	// Clean the path to resolve any .. or . components
	cleanPath := filepath.Clean(filename)

	// Check for path traversal attempts
	if strings.Contains(cleanPath, "..") {
		return fmt.Errorf("path traversal detected in filename: %s", filename)
	}

	// Ensure the path doesn't start with / (absolute path)
	if filepath.IsAbs(cleanPath) {
		return fmt.Errorf("absolute path not allowed: %s", filename)
	}

	// Additional check: ensure the resolved path is within the repository
	fullPath := filepath.Join(r.path, cleanPath)
	resolvedPath, err := filepath.Abs(fullPath)
	if err != nil {
		return fmt.Errorf("failed to resolve path: %w", err)
	}

	repoPath, err := filepath.Abs(r.path)
	if err != nil {
		return fmt.Errorf("failed to resolve repository path: %w", err)
	}

	// Check if the resolved path is within the repository
	relPath, err := filepath.Rel(repoPath, resolvedPath)
	if err != nil || strings.HasPrefix(relPath, "..") {
		return fmt.Errorf("path outside repository: %s", filename)
	}

	return nil
}
