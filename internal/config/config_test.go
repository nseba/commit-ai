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
		name    string
		cfg     *Config
		wantErr bool
		errMsg  string
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
