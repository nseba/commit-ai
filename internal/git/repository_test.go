package git

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/go-git/go-git/v5"
	"github.com/go-git/go-git/v5/plumbing/object"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func createTestRepo(t *testing.T) (string, *git.Repository) {
	tempDir := t.TempDir()

	repo, err := git.PlainInit(tempDir, false)
	require.NoError(t, err)

	return tempDir, repo
}

func createTestFile(t *testing.T, repoPath, filename, content string) {
	filePath := filepath.Join(repoPath, filename)
	err := os.MkdirAll(filepath.Dir(filePath), 0o755)
	require.NoError(t, err)
	err = os.WriteFile(filePath, []byte(content), 0o644)
	require.NoError(t, err)
}

func commitFile(t *testing.T, repo *git.Repository, repoPath, filename, content string) {
	createTestFile(t, repoPath, filename, content)

	worktree, err := repo.Worktree()
	require.NoError(t, err)

	_, err = worktree.Add(filename)
	require.NoError(t, err)

	_, err = worktree.Commit("Initial commit", &git.CommitOptions{
		Author: &object.Signature{
			Name:  "Test User",
			Email: "test@example.com",
		},
	})
	require.NoError(t, err)
}

func TestNewRepository(t *testing.T) {
	tempDir, _ := createTestRepo(t)

	repo, err := NewRepository(tempDir)
	require.NoError(t, err)
	assert.NotNil(t, repo)
	assert.Equal(t, tempDir, repo.path)
}

func TestNewRepository_NonGitDirectory(t *testing.T) {
	tempDir := t.TempDir()

	_, err := NewRepository(tempDir)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "failed to open git repository")
}

func TestGetDiff_EmptyRepository(t *testing.T) {
	tempDir, gitRepo := createTestRepo(t)

	// Add a file but don't commit
	createTestFile(t, tempDir, "test.txt", "Hello, World!")

	// Stage the file to get it in the diff
	worktree, err := gitRepo.Worktree()
	require.NoError(t, err)

	_, err = worktree.Add("test.txt")
	require.NoError(t, err)

	repo, err := NewRepository(tempDir)
	require.NoError(t, err)

	diff, err := repo.GetDiff()
	require.NoError(t, err)

	assert.Contains(t, diff, "test.txt")
	assert.Contains(t, diff, "+Hello, World!")
}

func TestGetDiff_WithCommits(t *testing.T) {
	tempDir, gitRepo := createTestRepo(t)

	// Create initial commit
	commitFile(t, gitRepo, tempDir, "test.txt", "Hello, World!")

	// Modify the file
	createTestFile(t, tempDir, "test.txt", "Hello, Universe!")

	repo, err := NewRepository(tempDir)
	require.NoError(t, err)

	diff, err := repo.GetDiff()
	require.NoError(t, err)

	assert.Contains(t, diff, "test.txt")
	assert.Contains(t, diff, "-Hello, World!")
	assert.Contains(t, diff, "+Hello, Universe!")
}

func TestGetDiff_StagedChanges(t *testing.T) {
	tempDir, gitRepo := createTestRepo(t)

	// Create initial commit
	commitFile(t, gitRepo, tempDir, "test.txt", "Hello, World!")

	// Modify and stage the file
	createTestFile(t, tempDir, "test.txt", "Hello, Universe!")

	worktree, err := gitRepo.Worktree()
	require.NoError(t, err)

	_, err = worktree.Add("test.txt")
	require.NoError(t, err)

	repo, err := NewRepository(tempDir)
	require.NoError(t, err)

	diff, err := repo.GetDiff()
	require.NoError(t, err)

	assert.Contains(t, diff, "test.txt")
	assert.Contains(t, diff, "-Hello, World!")
	assert.Contains(t, diff, "+Hello, Universe!")
}

func TestGetDiff_NoChanges(t *testing.T) {
	tempDir, gitRepo := createTestRepo(t)

	// Create initial commit
	commitFile(t, gitRepo, tempDir, "test.txt", "Hello, World!")

	repo, err := NewRepository(tempDir)
	require.NoError(t, err)

	diff, err := repo.GetDiff()
	require.NoError(t, err)

	assert.Empty(t, diff)
}

func TestApplyIgnorePatterns_NoIgnoreFile(t *testing.T) {
	tempDir, _ := createTestRepo(t)

	repo, err := NewRepository(tempDir)
	require.NoError(t, err)

	originalDiff := "diff --git a/test.txt b/test.txt\n+Hello, World!"

	filteredDiff, err := repo.ApplyIgnorePatterns(originalDiff, tempDir)
	require.NoError(t, err)

	assert.Equal(t, originalDiff, filteredDiff)
}

func TestApplyIgnorePatterns_WithIgnoreFile(t *testing.T) {
	tempDir, _ := createTestRepo(t)

	// Create .caiignore file
	ignoreContent := "*.log\ntemp/\n"
	createTestFile(t, tempDir, ".caiignore", ignoreContent)

	repo, err := NewRepository(tempDir)
	require.NoError(t, err)

	// Test diff with ignored file
	ignoredDiff := "diff --git a/debug.log b/debug.log\n+Debug info"
	filteredDiff, err := repo.ApplyIgnorePatterns(ignoredDiff, tempDir)
	require.NoError(t, err)

	assert.Empty(t, filteredDiff)

	// Test diff with non-ignored file
	normalDiff := "diff --git a/test.txt b/test.txt\n+Hello, World!"
	filteredDiff, err = repo.ApplyIgnorePatterns(normalDiff, tempDir)
	require.NoError(t, err)

	assert.Equal(t, normalDiff, filteredDiff)
}

func TestSplitDiffIntoSections(t *testing.T) {
	repo := &Repository{}

	diff := `diff --git a/file1.txt b/file1.txt
index 123..456 100644
--- a/file1.txt
+++ b/file1.txt
+line1
diff --git a/file2.txt b/file2.txt
index 789..abc 100644
--- a/file2.txt
+++ b/file2.txt
+line2`

	sections := repo.splitDiffIntoSections(diff)

	assert.Len(t, sections, 2)
	assert.Contains(t, sections[0], "file1.txt")
	assert.Contains(t, sections[0], "+line1")
	assert.Contains(t, sections[1], "file2.txt")
	assert.Contains(t, sections[1], "+line2")
}

func TestExtractFilenameFromDiff(t *testing.T) {
	repo := &Repository{}

	testCases := []struct {
		name     string
		diff     string
		expected string
	}{
		{
			name:     "normal file",
			diff:     "diff --git a/test.txt b/test.txt\nindex 123..456",
			expected: "test.txt",
		},
		{
			name:     "file in subdirectory",
			diff:     "diff --git a/src/main.go b/src/main.go\nindex 123..456",
			expected: "src/main.go",
		},
		{
			name:     "no diff header",
			diff:     "some random content",
			expected: "",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			result := repo.extractFilenameFromDiff(tc.diff)
			assert.Equal(t, tc.expected, result)
		})
	}
}

func TestAddPlusPrefix(t *testing.T) {
	content := "line1\nline2\nline3"
	expected := "+line1\n+line2\n+line3"

	result := addPlusPrefix(content)
	assert.Equal(t, expected, result)
}

func TestAddMinusPrefix(t *testing.T) {
	content := "line1\nline2\nline3"
	expected := "-line1\n-line2\n-line3"

	result := addMinusPrefix(content)
	assert.Equal(t, expected, result)
}

func TestGenerateDiff_IdenticalContent(t *testing.T) {
	repo := &Repository{}

	content := "same content"
	result := repo.generateDiff("test.txt", content, content)

	assert.Empty(t, result)
}

func TestGenerateDiff_DifferentContent(t *testing.T) {
	repo := &Repository{}

	oldContent := "old line"
	newContent := "new line"

	result := repo.generateDiff("test.txt", oldContent, newContent)

	assert.Contains(t, result, "diff --git a/test.txt b/test.txt")
	assert.Contains(t, result, "--- a/test.txt")
	assert.Contains(t, result, "+++ b/test.txt")
	assert.Contains(t, result, "-old line")
	assert.Contains(t, result, "+new line")
}

func TestGetNewFileDiff(t *testing.T) {
	repo := &Repository{}

	content := "new file content"
	result := repo.getNewFileDiff("new.txt", content)

	assert.Contains(t, result, "diff --git a/new.txt b/new.txt")
	assert.Contains(t, result, "new file mode 100644")
	assert.Contains(t, result, "--- /dev/null")
	assert.Contains(t, result, "+++ b/new.txt")
	assert.Contains(t, result, "+new file content")
}
