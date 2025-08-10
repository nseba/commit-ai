package generator

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/nseba/commit-ai/internal/config"
)

func TestNew(t *testing.T) {
	cfg := config.DefaultConfig()
	tempDir := t.TempDir()
	configFile := filepath.Join(tempDir, "config.toml")

	gen, err := New(cfg, configFile)
	require.NoError(t, err)
	assert.NotNil(t, gen)
	assert.Equal(t, cfg, gen.config)
	assert.NotNil(t, gen.client)
	assert.NotNil(t, gen.template)
}

func TestNew_InvalidConfig(t *testing.T) {
	cfg := &config.Config{
		APIURL:         "",
		Model:          "test-model",
		Provider:       "ollama",
		Language:       "english",
		PromptTemplate: "default.txt",
	}
	tempDir := t.TempDir()
	configFile := filepath.Join(tempDir, "config.toml")

	_, err := New(cfg, configFile)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "invalid configuration")
}

func TestPreparePrompt(t *testing.T) {
	cfg := config.DefaultConfig()
	tempDir := t.TempDir()
	configFile := filepath.Join(tempDir, "config.toml")
	gen, err := New(cfg, configFile)
	require.NoError(t, err)

	diff := "diff --git a/test.txt b/test.txt\n+Hello, World!"

	prompt, err := gen.preparePrompt(diff)
	require.NoError(t, err)

	assert.Contains(t, prompt, diff)
	assert.Contains(t, prompt, "english")
	assert.Contains(t, prompt, "expert developer")
}

func TestGenerateWithOllama(t *testing.T) {
	// Mock Ollama server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, "/api/generate", r.URL.Path)
		assert.Equal(t, "POST", r.Method)
		assert.Equal(t, "application/json", r.Header.Get("Content-Type"))

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"response": "feat: add hello world greeting", "done": true}`))
	}))
	defer server.Close()

	cfg := config.DefaultConfig()
	cfg.APIURL = server.URL
	cfg.Provider = "ollama"
	tempDir := t.TempDir()
	configFile := filepath.Join(tempDir, "config.toml")

	gen, err := New(cfg, configFile)
	require.NoError(t, err)

	prompt := "Generate commit message for diff"
	result, err := gen.generateWithOllama(prompt)
	require.NoError(t, err)

	assert.Equal(t, "feat: add hello world greeting", result)
}

func TestGenerateWithOllama_ServerError(t *testing.T) {
	// Mock server that returns error
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(`{"error": "Internal server error"}`))
	}))
	defer server.Close()

	cfg := config.DefaultConfig()
	cfg.APIURL = server.URL
	cfg.Provider = "ollama"
	tempDir := t.TempDir()
	configFile := filepath.Join(tempDir, "config.toml")

	gen, err := New(cfg, configFile)
	require.NoError(t, err)

	prompt := "Generate commit message"
	_, err = gen.generateWithOllama(prompt)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "ollama API error")
}

func TestGenerateWithOpenAI(t *testing.T) {
	// Mock OpenAI server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		assert.Equal(t, "/v1/chat/completions", r.URL.Path)
		assert.Equal(t, "POST", r.Method)
		assert.Equal(t, "application/json", r.Header.Get("Content-Type"))
		assert.Equal(t, "Bearer test-token", r.Header.Get("Authorization"))

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{
			"choices": [
				{
					"message": {
						"content": "feat: implement user authentication"
					}
				}
			]
		}`))
	}))
	defer server.Close()

	cfg := &config.Config{
		APIURL:         server.URL,
		Model:          "gpt-3.5-turbo",
		Provider:       "openai",
		APIToken:       "test-token",
		Language:       "english",
		PromptTemplate: "default.txt",
	}
	tempDir := t.TempDir()
	configFile := filepath.Join(tempDir, "config.toml")

	gen, err := New(cfg, configFile)
	require.NoError(t, err)

	prompt := "Generate commit message for auth changes"
	result, err := gen.generateWithOpenAI(prompt)
	require.NoError(t, err)

	assert.Equal(t, "feat: implement user authentication", result)
}

func TestGenerateWithOpenAI_NoChoices(t *testing.T) {
	// Mock server with no choices
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"choices": []}`))
	}))
	defer server.Close()

	cfg := &config.Config{
		APIURL:         server.URL,
		Model:          "gpt-3.5-turbo",
		Provider:       "openai",
		APIToken:       "test-token",
		Language:       "english",
		PromptTemplate: "default.txt",
	}
	tempDir := t.TempDir()
	configFile := filepath.Join(tempDir, "config.toml")

	gen, err := New(cfg, configFile)
	require.NoError(t, err)

	prompt := "Generate commit message"
	_, err = gen.generateWithOpenAI(prompt)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "no response from OpenAI")
}

func TestGenerate(t *testing.T) {
	// Mock Ollama server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"response": "feat: add new feature", "done": true}`))
	}))
	defer server.Close()

	cfg := config.DefaultConfig()
	cfg.APIURL = server.URL
	tempDir := t.TempDir()
	configFile := filepath.Join(tempDir, "config.toml")

	gen, err := New(cfg, configFile)
	require.NoError(t, err)

	diff := "diff --git a/test.txt b/test.txt\n+New feature code"

	result, err := gen.Generate(diff)
	require.NoError(t, err)

	assert.Equal(t, "feat: add new feature", result)
}

func TestGenerate_UnsupportedProvider(t *testing.T) {
	cfg := &config.Config{
		APIURL:         "http://localhost:11434",
		Model:          "test-model",
		Provider:       "unsupported",
		APIToken:       "",
		Language:       "english",
		PromptTemplate: "default.txt",
	}
	tempDir := t.TempDir()
	configFile := filepath.Join(tempDir, "config.toml")

	_, err := New(cfg, configFile)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "invalid provider")
}

func TestLoadTemplate_DefaultContent(t *testing.T) {
	// Test with non-existent file (should create default)
	tempDir := t.TempDir()
	templatePath := filepath.Join(tempDir, "nonexistent.txt")

	tmpl, err := loadTemplate(templatePath)
	require.NoError(t, err)
	assert.NotNil(t, tmpl)

	// Test template execution
	data := struct {
		Diff     string
		Language string
	}{
		Diff:     "test diff",
		Language: "english",
	}

	var buf strings.Builder
	err = tmpl.Execute(&buf, data)
	require.NoError(t, err)

	result := buf.String()
	assert.Contains(t, result, "test diff")
	assert.Contains(t, result, "english")
	assert.Contains(t, result, "expert developer")
}

func TestGetDefaultTemplate(t *testing.T) {
	content := getDefaultTemplate()

	assert.Contains(t, content, "{{.Diff}}")
	assert.Contains(t, content, "{{.Language}}")
	assert.Contains(t, content, "expert developer")
	assert.Contains(t, content, "conventional commit")
}

func TestCreateDefaultTemplate(t *testing.T) {
	tempDir := t.TempDir()
	templatePath := filepath.Join(tempDir, "test.txt")
	content := "test template content"

	err := createDefaultTemplate(templatePath, content)
	require.NoError(t, err)

	// Verify file was created with correct content
	data, err := os.ReadFile(templatePath)
	require.NoError(t, err)
	assert.Equal(t, content, string(data))
}

func TestGenerateWithOllama_ConnectionError(t *testing.T) {
	cfg := config.DefaultConfig()
	cfg.APIURL = "http://nonexistent:12345"
	tempDir := t.TempDir()
	configFile := filepath.Join(tempDir, "config.toml")

	gen, err := New(cfg, configFile)
	require.NoError(t, err)

	prompt := "test prompt"
	_, err = gen.generateWithOllama(prompt)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "failed to make request to Ollama")
}

func TestGenerateWithOpenAI_ConnectionError(t *testing.T) {
	cfg := &config.Config{
		APIURL:         "http://nonexistent:12345",
		Model:          "gpt-3.5-turbo",
		Provider:       "openai",
		APIToken:       "test-token",
		Language:       "english",
		PromptTemplate: "default.txt",
	}
	tempDir := t.TempDir()
	configFile := filepath.Join(tempDir, "config.toml")

	gen, err := New(cfg, configFile)
	require.NoError(t, err)

	prompt := "test prompt"
	_, err = gen.generateWithOpenAI(prompt)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "failed to make request to OpenAI")
}

func TestGenerateWithOpenAI_InvalidJSON(t *testing.T) {
	// Mock server with invalid JSON
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`invalid json`))
	}))
	defer server.Close()

	cfg := &config.Config{
		APIURL:         server.URL,
		Model:          "gpt-3.5-turbo",
		Provider:       "openai",
		APIToken:       "test-token",
		Language:       "english",
		PromptTemplate: "default.txt",
	}
	tempDir := t.TempDir()
	configFile := filepath.Join(tempDir, "config.toml")

	gen, err := New(cfg, configFile)
	require.NoError(t, err)

	prompt := "test prompt"
	_, err = gen.generateWithOpenAI(prompt)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "failed to decode OpenAI response")
}

func TestGenerateWithOllama_InvalidJSON(t *testing.T) {
	// Mock server with invalid JSON
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`invalid json`))
	}))
	defer server.Close()

	cfg := config.DefaultConfig()
	cfg.APIURL = server.URL
	tempDir := t.TempDir()
	configFile := filepath.Join(tempDir, "config.toml")

	gen, err := New(cfg, configFile)
	require.NoError(t, err)

	prompt := "test prompt"
	_, err = gen.generateWithOllama(prompt)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "failed to decode Ollama response")
}

func TestCleanResponse(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "removes bold commit message label",
			input:    "**Commit Message:** fix: update user authentication",
			expected: "fix: update user authentication",
		},
		{
			name:     "removes plain commit message label",
			input:    "Commit Message: feat: add new dashboard",
			expected: "feat: add new dashboard",
		},
		{
			name:     "removes lowercase commit message label",
			input:    "**Commit message:** docs: update README",
			expected: "docs: update README",
		},
		{
			name:     "removes plain lowercase commit message label",
			input:    "Commit message: style: format code",
			expected: "style: format code",
		},
		{
			name:     "removes uppercase commit message label",
			input:    "**COMMIT MESSAGE:** refactor: simplify API",
			expected: "refactor: simplify API",
		},
		{
			name:     "removes plain uppercase commit message label",
			input:    "COMMIT MESSAGE: test: add unit tests",
			expected: "test: add unit tests",
		},
		{
			name:     "handles message without label",
			input:    "fix: resolve bug in payment processing",
			expected: "fix: resolve bug in payment processing",
		},
		{
			name:     "handles empty string",
			input:    "",
			expected: "",
		},
		{
			name:     "handles label with extra whitespace",
			input:    "**Commit Message:**   feat: implement OAuth",
			expected: "feat: implement OAuth",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := cleanResponse(tt.input)
			assert.Equal(t, tt.expected, result)
		})
	}
}
