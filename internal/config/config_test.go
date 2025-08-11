package config

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestDefaultConfig(t *testing.T) {
	cfg := DefaultConfig()

	assert.Equal(t, "http://localhost:11434", cfg.APIURL)
	assert.Equal(t, "llama2", cfg.Model)
	assert.Equal(t, "ollama", cfg.Provider)
	assert.Equal(t, "", cfg.APIToken)
	assert.Equal(t, "english", cfg.Language)
	assert.Equal(t, "default.txt", cfg.PromptTemplate)
}

func TestConfig_Save(t *testing.T) {
	// Create temporary directory
	tempDir := t.TempDir()
	configFile := filepath.Join(tempDir, "config.toml")

	cfg := DefaultConfig()
	cfg.Model = "test-model"

	err := cfg.Save(configFile)
	require.NoError(t, err)

	// Verify file was created
	_, err = os.Stat(configFile)
	require.NoError(t, err)

	// Load and verify content
	loadedCfg, err := Load(configFile)
	require.NoError(t, err)
	assert.Equal(t, "test-model", loadedCfg.Model)
}

func TestConfig_LoadFromEnv(t *testing.T) {
	// Set environment variables
	os.Setenv("CAI_API_URL", "http://test.com")
	os.Setenv("CAI_MODEL", "test-model")
	os.Setenv("CAI_PROVIDER", "openai")
	os.Setenv("CAI_API_TOKEN", "test-token")
	os.Setenv("CAI_LANGUAGE", "spanish")
	os.Setenv("CAI_PROMPT_TEMPLATE", "test.txt")

	defer func() {
		os.Unsetenv("CAI_API_URL")
		os.Unsetenv("CAI_MODEL")
		os.Unsetenv("CAI_PROVIDER")
		os.Unsetenv("CAI_API_TOKEN")
		os.Unsetenv("CAI_LANGUAGE")
		os.Unsetenv("CAI_PROMPT_TEMPLATE")
	}()

	cfg := DefaultConfig()
	cfg.loadFromEnv()

	assert.Equal(t, "http://test.com", cfg.APIURL)
	assert.Equal(t, "test-model", cfg.Model)
	assert.Equal(t, "openai", cfg.Provider)
	assert.Equal(t, "test-token", cfg.APIToken)
	assert.Equal(t, "spanish", cfg.Language)
	assert.Equal(t, "test.txt", cfg.PromptTemplate)
}

func TestConfig_Validate(t *testing.T) {
	tests := []struct {
		cfg     *Config
		name    string
		errMsg  string
		wantErr bool
	}{
		{
			name:    "valid ollama config",
			cfg:     DefaultConfig(),
			wantErr: false,
		},
		{
			name: "valid openai config",
			cfg: &Config{
				APIURL:         "https://api.openai.com",
				Model:          "gpt-3.5-turbo",
				Provider:       "openai",
				APIToken:       "test-token",
				Language:       "english",
				PromptTemplate: "default.txt",
			},
			wantErr: false,
		},
		{
			name: "empty API URL",
			cfg: &Config{
				APIURL:         "",
				Model:          "test-model",
				Provider:       "ollama",
				Language:       "english",
				PromptTemplate: "default.txt",
			},
			wantErr: true,
			errMsg:  "CAI_API_URL cannot be empty",
		},
		{
			name: "empty model",
			cfg: &Config{
				APIURL:         "http://localhost:11434",
				Model:          "",
				Provider:       "ollama",
				Language:       "english",
				PromptTemplate: "default.txt",
			},
			wantErr: true,
			errMsg:  "CAI_MODEL cannot be empty",
		},
		{
			name: "invalid provider",
			cfg: &Config{
				APIURL:         "http://localhost:11434",
				Model:          "test-model",
				Provider:       "invalid",
				Language:       "english",
				PromptTemplate: "default.txt",
			},
			wantErr: true,
			errMsg:  "invalid provider",
		},
		{
			name: "openai without token",
			cfg: &Config{
				APIURL:         "https://api.openai.com",
				Model:          "gpt-3.5-turbo",
				Provider:       "openai",
				APIToken:       "",
				Language:       "english",
				PromptTemplate: "default.txt",
			},
			wantErr: true,
			errMsg:  "CAI_API_TOKEN is required when using OpenAI provider",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.cfg.Validate()
			if tt.wantErr {
				require.Error(t, err)
				assert.Contains(t, err.Error(), tt.errMsg)
			} else {
				require.NoError(t, err)
			}
		})
	}
}

func TestConfig_GetPromptTemplatePath(t *testing.T) {
	cfg := DefaultConfig()
	configFile := "/home/user/.config/commit-ai/config.toml"

	expected := "/home/user/.config/commit-ai/default.txt"
	actual := cfg.GetPromptTemplatePath(configFile)

	assert.Equal(t, expected, actual)
}

func TestLoad_NonExistentFile(t *testing.T) {
	tempDir := t.TempDir()
	configFile := filepath.Join(tempDir, "nonexistent.toml")

	cfg, err := Load(configFile)
	require.NoError(t, err)

	// Should return default config and create the file
	assert.Equal(t, DefaultConfig().APIURL, cfg.APIURL)

	// Verify file was created
	_, err = os.Stat(configFile)
	require.NoError(t, err)
}

func TestLoad_ExistingFile(t *testing.T) {
	tempDir := t.TempDir()
	configFile := filepath.Join(tempDir, "config.toml")

	// Create config file with custom values
	content := `CAI_API_URL = "http://custom.com"
CAI_MODEL = "custom-model"
CAI_PROVIDER = "openai"
CAI_API_TOKEN = "custom-token"
CAI_LANGUAGE = "french"
CAI_PROMPT_TEMPLATE = "custom.txt"`

	err := os.WriteFile(configFile, []byte(content), 0o644)
	require.NoError(t, err)

	cfg, err := Load(configFile)
	require.NoError(t, err)

	assert.Equal(t, "http://custom.com", cfg.APIURL)
	assert.Equal(t, "custom-model", cfg.Model)
	assert.Equal(t, "openai", cfg.Provider)
	assert.Equal(t, "custom-token", cfg.APIToken)
	assert.Equal(t, "french", cfg.Language)
	assert.Equal(t, "custom.txt", cfg.PromptTemplate)
}

func TestLoadWithProjectPath_NoGitRepo(t *testing.T) {
	tempDir := t.TempDir()
	configFile := filepath.Join(tempDir, "config.toml")

	// Create global config
	globalCfg := DefaultConfig()
	globalCfg.Model = "global-model"
	err := globalCfg.Save(configFile)
	require.NoError(t, err)

	// Create project config in temp dir (not a git repo)
	projectConfigFile := filepath.Join(tempDir, ".commitai")
	projectContent := `CAI_MODEL = "project-model"
CAI_LANGUAGE = "spanish"`
	err = os.WriteFile(projectConfigFile, []byte(projectContent), 0o644)
	require.NoError(t, err)

	cfg, err := LoadWithProjectPath(configFile, tempDir)
	require.NoError(t, err)

	// Should use project overrides
	assert.Equal(t, "project-model", cfg.Model)
	assert.Equal(t, "spanish", cfg.Language)
	// Other values should remain from global config
	assert.Equal(t, DefaultConfig().APIURL, cfg.APIURL)
}

func TestLoadWithProjectPath_WithGitRepo(t *testing.T) {
	tempDir := t.TempDir()
	configFile := filepath.Join(tempDir, "config.toml")

	// Create global config
	globalCfg := DefaultConfig()
	globalCfg.Model = "global-model"
	err := globalCfg.Save(configFile)
	require.NoError(t, err)

	// Create git repo structure
	gitDir := filepath.Join(tempDir, "repo")
	err = os.MkdirAll(filepath.Join(gitDir, ".git"), 0o755)
	require.NoError(t, err)

	subDir := filepath.Join(gitDir, "subdir")
	err = os.MkdirAll(subDir, 0o755)
	require.NoError(t, err)

	// Create project configs at different levels
	gitRootConfig := filepath.Join(gitDir, ".commitai")
	gitRootContent := `CAI_MODEL = "git-root-model"
CAI_PROVIDER = "openai"`
	err = os.WriteFile(gitRootConfig, []byte(gitRootContent), 0o644)
	require.NoError(t, err)

	subDirConfig := filepath.Join(subDir, ".commitai")
	subDirContent := `CAI_MODEL = "subdir-model"
CAI_LANGUAGE = "french"`
	err = os.WriteFile(subDirConfig, []byte(subDirContent), 0o644)
	require.NoError(t, err)

	cfg, err := LoadWithProjectPath(configFile, subDir)
	require.NoError(t, err)

	// Should prioritize more specific config (subdir overrides git root)
	assert.Equal(t, "subdir-model", cfg.Model)          // from subdir
	assert.Equal(t, "french", cfg.Language)             // from subdir
	assert.Equal(t, "openai", cfg.Provider)             // from git root
	assert.Equal(t, DefaultConfig().APIURL, cfg.APIURL) // from global default
}

func TestLoadWithProjectPath_EnvironmentOverrides(t *testing.T) {
	tempDir := t.TempDir()
	configFile := filepath.Join(tempDir, "config.toml")

	// Set environment variable
	os.Setenv("CAI_MODEL", "env-model")
	defer os.Unsetenv("CAI_MODEL")

	// Create global config
	globalCfg := DefaultConfig()
	globalCfg.Model = "global-model"
	err := globalCfg.Save(configFile)
	require.NoError(t, err)

	// Create project config
	projectConfigFile := filepath.Join(tempDir, ".commitai")
	projectContent := `CAI_MODEL = "project-model"`
	err = os.WriteFile(projectConfigFile, []byte(projectContent), 0o644)
	require.NoError(t, err)

	cfg, err := LoadWithProjectPath(configFile, tempDir)
	require.NoError(t, err)

	// Environment should override everything
	assert.Equal(t, "env-model", cfg.Model)
}

func TestLoadWithProjectPath_PartialOverrides(t *testing.T) {
	tempDir := t.TempDir()
	configFile := filepath.Join(tempDir, "config.toml")

	// Create global config with all values
	globalContent := `CAI_API_URL = "http://global.com"
CAI_MODEL = "global-model"
CAI_PROVIDER = "ollama"
CAI_API_TOKEN = "global-token"
CAI_LANGUAGE = "english"
CAI_PROMPT_TEMPLATE = "global.txt"
CAI_TIMEOUT_SECONDS = 300`
	err := os.WriteFile(configFile, []byte(globalContent), 0o644)
	require.NoError(t, err)

	// Create project config with only some overrides
	projectConfigFile := filepath.Join(tempDir, ".commitai")
	projectContent := `CAI_MODEL = "project-model"
CAI_LANGUAGE = "spanish"
CAI_TIMEOUT_SECONDS = 600`
	err = os.WriteFile(projectConfigFile, []byte(projectContent), 0o644)
	require.NoError(t, err)

	cfg, err := LoadWithProjectPath(configFile, tempDir)
	require.NoError(t, err)

	// Should have project overrides where specified
	assert.Equal(t, "project-model", cfg.Model)
	assert.Equal(t, "spanish", cfg.Language)
	assert.Equal(t, 600, cfg.TimeoutSeconds)

	// Should keep global values for non-overridden fields
	assert.Equal(t, "http://global.com", cfg.APIURL)
	assert.Equal(t, "ollama", cfg.Provider)
	assert.Equal(t, "global-token", cfg.APIToken)
	assert.Equal(t, "global.txt", cfg.PromptTemplate)
}

func TestFindGitRoot(t *testing.T) {
	tempDir := t.TempDir()

	// Create git repo structure
	gitDir := filepath.Join(tempDir, "repo")
	err := os.MkdirAll(filepath.Join(gitDir, ".git"), 0o755)
	require.NoError(t, err)

	subDir := filepath.Join(gitDir, "subdir", "nested")
	err = os.MkdirAll(subDir, 0o755)
	require.NoError(t, err)

	// Should find git root from nested directory
	root, err := findGitRoot(subDir)
	require.NoError(t, err)
	assert.Equal(t, gitDir, root)

	// Should find git root from git root itself
	root, err = findGitRoot(gitDir)
	require.NoError(t, err)
	assert.Equal(t, gitDir, root)

	// Should fail when not in git repo
	nonGitDir := filepath.Join(tempDir, "nongit")
	err = os.MkdirAll(nonGitDir, 0o755)
	require.NoError(t, err)

	_, err = findGitRoot(nonGitDir)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "not in a git repository")
}

func TestFindGitRoot_WithGitFile(t *testing.T) {
	tempDir := t.TempDir()

	// Create worktree structure with .git file
	worktreeDir := filepath.Join(tempDir, "worktree")
	err := os.MkdirAll(worktreeDir, 0o755)
	require.NoError(t, err)

	// Create .git file pointing to real git dir
	gitFile := filepath.Join(worktreeDir, ".git")
	gitFileContent := "gitdir: /some/other/path/.git"
	err = os.WriteFile(gitFile, []byte(gitFileContent), 0o644)
	require.NoError(t, err)

	root, err := findGitRoot(worktreeDir)
	require.NoError(t, err)
	assert.Equal(t, worktreeDir, root)
}

func TestFindProjectConfigs(t *testing.T) {
	tempDir := t.TempDir()

	// Create directory structure
	gitRoot := filepath.Join(tempDir, "repo")
	subDir := filepath.Join(gitRoot, "subdir")
	nestedDir := filepath.Join(subDir, "nested")

	err := os.MkdirAll(nestedDir, 0o755)
	require.NoError(t, err)

	configs := findProjectConfigs(gitRoot, nestedDir)

	// Should return configs in order: git root first, then path-specific
	expected := []string{
		filepath.Join(gitRoot, ".commitai"),
		filepath.Join(nestedDir, ".commitai"),
		filepath.Join(subDir, ".commitai"),
	}

	assert.Equal(t, expected, configs)
}

func TestFindProjectConfigs_SameAsGitRoot(t *testing.T) {
	tempDir := t.TempDir()

	configs := findProjectConfigs(tempDir, tempDir)

	// Should return only one config when project path is same as git root
	expected := []string{
		filepath.Join(tempDir, ".commitai"),
	}

	assert.Equal(t, expected, configs)
}

func TestLoadProjectConfig_EmptyValues(t *testing.T) {
	tempDir := t.TempDir()

	cfg := DefaultConfig()
	originalModel := cfg.Model

	// Create project config with empty values (should not override)
	projectConfigFile := filepath.Join(tempDir, ".commitai")
	projectContent := `CAI_API_URL = ""
CAI_MODEL = ""
CAI_LANGUAGE = "spanish"`
	err := os.WriteFile(projectConfigFile, []byte(projectContent), 0o644)
	require.NoError(t, err)

	err = cfg.loadProjectConfig(projectConfigFile)
	require.NoError(t, err)

	// Empty values should not override existing values
	assert.Equal(t, DefaultConfig().APIURL, cfg.APIURL)
	assert.Equal(t, originalModel, cfg.Model)

	// Non-empty values should override
	assert.Equal(t, "spanish", cfg.Language)
}

func TestLoadProjectConfig_NonExistentFile(t *testing.T) {
	tempDir := t.TempDir()

	cfg := DefaultConfig()
	originalModel := cfg.Model

	nonExistentFile := filepath.Join(tempDir, "nonexistent.commitai")
	err := cfg.loadProjectConfig(nonExistentFile)
	require.NoError(t, err)

	// Should not change anything
	assert.Equal(t, originalModel, cfg.Model)
}

func TestLoadProjectConfig_InvalidTOML(t *testing.T) {
	tempDir := t.TempDir()

	cfg := DefaultConfig()

	// Create invalid TOML file
	projectConfigFile := filepath.Join(tempDir, ".commitai")
	invalidContent := `CAI_MODEL = "unclosed string`
	err := os.WriteFile(projectConfigFile, []byte(invalidContent), 0o644)
	require.NoError(t, err)

	err = cfg.loadProjectConfig(projectConfigFile)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "failed to decode project config file")
}

func TestValidateGitPath(t *testing.T) {
	tempDir := t.TempDir()

	tests := []struct {
		name     string
		gitDir   string
		basePath string
		wantErr  bool
		errMsg   string
	}{
		{
			name:     "valid git path",
			gitDir:   filepath.Join(tempDir, ".git"),
			basePath: tempDir,
			wantErr:  false,
		},
		{
			name:     "path traversal in gitDir",
			gitDir:   tempDir + "/../malicious/.git",
			basePath: tempDir,
			wantErr:  true,
			errMsg:   "path traversal detected",
		},
		{
			name:     "invalid git path structure",
			gitDir:   filepath.Join(tempDir, "notgit"),
			basePath: tempDir,
			wantErr:  true,
			errMsg:   "invalid git path",
		},
		{
			name:     "path with double dots",
			gitDir:   tempDir + "/../test/.git",
			basePath: tempDir,
			wantErr:  true,
			errMsg:   "path traversal detected",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateGitPath(tt.gitDir, tt.basePath)
			if tt.wantErr {
				require.Error(t, err)
				assert.Contains(t, err.Error(), tt.errMsg)
			} else {
				require.NoError(t, err)
			}
		})
	}
}

func TestValidateProjectConfigPath(t *testing.T) {
	tempDir := t.TempDir()

	tests := []struct {
		name       string
		configFile string
		wantErr    bool
		errMsg     string
	}{
		{
			name:       "valid config path",
			configFile: filepath.Join(tempDir, ".commitai"),
			wantErr:    false,
		},
		{
			name:       "path traversal attempt",
			configFile: "../../../etc/passwd",
			wantErr:    true,
			errMsg:     "path traversal detected",
		},
		{
			name:       "invalid file extension",
			configFile: filepath.Join(tempDir, "config.toml"),
			wantErr:    true,
			errMsg:     "invalid config file extension",
		},
		{
			name:       "path with traversal components",
			configFile: tempDir + "/../malicious/.commitai",
			wantErr:    true,
			errMsg:     "path traversal detected",
		},
		{
			name:       "root path",
			configFile: "/.commitai",
			wantErr:    true,
			errMsg:     "cannot use root directory",
		},
		{
			name:       "empty path with extension",
			configFile: ".commitai",
			wantErr:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateProjectConfigPath(tt.configFile)
			if tt.wantErr {
				require.Error(t, err)
				assert.Contains(t, err.Error(), tt.errMsg)
			} else {
				require.NoError(t, err)
			}
		})
	}
}

func TestLoadProjectConfig_SecurityValidation(t *testing.T) {
	tempDir := t.TempDir()
	cfg := DefaultConfig()

	// Try to load a file with invalid extension - should fail
	invalidFile := filepath.Join(tempDir, "malicious.toml")
	err := cfg.loadProjectConfig(invalidFile)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "invalid config file extension")

	// Try to load a file with path traversal - should fail
	traversalFile := "../../../malicious.commitai"
	err = cfg.loadProjectConfig(traversalFile)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "path traversal detected")

	// Try root directory file - should fail
	rootFile := "/.commitai"
	err = cfg.loadProjectConfig(rootFile)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "cannot use root directory")

	// Valid file should work
	validFile := filepath.Join(tempDir, ".commitai")
	validContent := `CAI_MODEL = "valid"`
	err = os.WriteFile(validFile, []byte(validContent), 0o644)
	require.NoError(t, err)

	err = cfg.loadProjectConfig(validFile)
	require.NoError(t, err)
	assert.Equal(t, "valid", cfg.Model)
}
