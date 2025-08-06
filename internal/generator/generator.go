package generator

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"text/template"
	"time"

	"github.com/nseba/commit-ai/internal/config"
)

const (
	providerOllama = "ollama"
	providerOpenAI = "openai"
)

// Generator handles commit message generation using AI providers
type Generator struct {
	config   *config.Config
	client   *http.Client
	template *template.Template
}

// New creates a new Generator instance
func New(cfg *config.Config, configFile string) (*Generator, error) {
	if err := cfg.Validate(); err != nil {
		return nil, fmt.Errorf("invalid configuration: %w", err)
	}

	// Load prompt template
	templatePath := cfg.GetPromptTemplatePath(configFile)
	tmpl, err := loadTemplate(templatePath)
	if err != nil {
		return nil, fmt.Errorf("failed to load template: %w", err)
	}

	return &Generator{
		config:   cfg,
		client:   &http.Client{Timeout: 180 * time.Second},
		template: tmpl,
	}, nil
}

// Generate creates a commit message from the given diff
func (g *Generator) Generate(diff string) (string, error) {
	// Prepare prompt with diff
	prompt, err := g.preparePrompt(diff)
	if err != nil {
		return "", fmt.Errorf("failed to prepare prompt: %w", err)
	}

	// Generate using appropriate provider
	switch g.config.Provider {
	case providerOllama:
		return g.generateWithOllama(prompt)
	case providerOpenAI:
		return g.generateWithOpenAI(prompt)
	default:
		return "", fmt.Errorf("unsupported provider: %s", g.config.Provider)
	}
}

// preparePrompt combines the template with the diff and language settings
func (g *Generator) preparePrompt(diff string) (string, error) {
	data := struct {
		Diff     string
		Language string
	}{
		Diff:     diff,
		Language: g.config.Language,
	}

	var buf bytes.Buffer
	if err := g.template.Execute(&buf, data); err != nil {
		return "", fmt.Errorf("failed to execute template: %w", err)
	}

	return buf.String(), nil
}

// generateWithOllama generates commit message using Ollama API
func (g *Generator) generateWithOllama(prompt string) (string, error) {
	reqBody := map[string]interface{}{
		"model":  g.config.Model,
		"prompt": prompt,
		"stream": false,
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("failed to marshal request: %w", err)
	}

	url := strings.TrimRight(g.config.APIURL, "/") + "/api/generate"
	resp, err := g.client.Post(url, "application/json", bytes.NewBuffer(jsonData))
	if err != nil {
		return "", fmt.Errorf("failed to make request to Ollama: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("ollama API error (status %d): %s", resp.StatusCode, string(body))
	}

	var ollamaResp struct {
		Response string `json:"response"`
		Done     bool   `json:"done"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&ollamaResp); err != nil {
		return "", fmt.Errorf("failed to decode Ollama response: %w", err)
	}

	return strings.TrimSpace(ollamaResp.Response), nil
}

// generateWithOpenAI generates commit message using OpenAI API
func (g *Generator) generateWithOpenAI(prompt string) (string, error) {
	reqBody := map[string]interface{}{
		"model": g.config.Model,
		"messages": []map[string]string{
			{
				"role":    "user",
				"content": prompt,
			},
		},
		"max_tokens":  150,
		"temperature": 0.7,
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("failed to marshal request: %w", err)
	}

	url := strings.TrimRight(g.config.APIURL, "/") + "/v1/chat/completions"
	if g.config.APIURL == "http://localhost:11434" {
		// Default OpenAI API URL
		url = "https://api.openai.com/v1/chat/completions"
	}

	ctx := context.Background()
	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+g.config.APIToken)

	resp, err := g.client.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to make request to OpenAI: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("OpenAI API error (status %d): %s", resp.StatusCode, string(body))
	}

	var openaiResp struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&openaiResp); err != nil {
		return "", fmt.Errorf("failed to decode OpenAI response: %w", err)
	}

	if len(openaiResp.Choices) == 0 {
		return "", fmt.Errorf("no response from OpenAI")
	}

	return strings.TrimSpace(openaiResp.Choices[0].Message.Content), nil
}

// loadTemplate loads and parses the prompt template file
func loadTemplate(templatePath string) (*template.Template, error) {
	// Validate template path to prevent path traversal
	if err := validateTemplatePath(templatePath); err != nil {
		return nil, fmt.Errorf("invalid template path: %w", err)
	}

	// Check if template file exists
	content, err := os.ReadFile(templatePath)
	if err != nil {
		// If template doesn't exist, create it with default content
		defaultContent := getDefaultTemplate()
		if err := createDefaultTemplate(templatePath, defaultContent); err != nil {
			return nil, fmt.Errorf("failed to create default template: %w", err)
		}
		content = []byte(defaultContent)
	}

	tmpl, err := template.New("prompt").Parse(string(content))
	if err != nil {
		return nil, fmt.Errorf("failed to parse template: %w", err)
	}

	return tmpl, nil
}

// getDefaultTemplate returns the default prompt template content
func getDefaultTemplate() string {
	return `You are an expert developer reviewing a git diff to generate a concise, meaningful commit message.

Language: Generate the commit message in {{.Language}}.

Git Diff:
{{.Diff}}

Based on the above git diff, generate a single line commit message that:
1. Is concise and descriptive (50 characters or less preferred)
2. Uses conventional commit format if applicable (feat:, fix:, docs:, etc.)
3. Describes WHAT changed, not HOW it was implemented
4. Uses imperative mood (e.g., "Add feature" not "Added feature")

Commit Message:`
}

// createDefaultTemplate creates a default template file
func createDefaultTemplate(templatePath, content string) error {
	// Validate template path before creating
	if err := validateTemplatePath(templatePath); err != nil {
		return fmt.Errorf("invalid template path: %w", err)
	}

	// Ensure parent directory exists
	dir := filepath.Dir(templatePath)
	if err := os.MkdirAll(dir, 0o750); err != nil {
		return fmt.Errorf("failed to create template directory: %w", err)
	}

	if err := os.WriteFile(templatePath, []byte(content), 0o600); err != nil {
		return fmt.Errorf("failed to write template file: %w", err)
	}
	return nil
}

// validateTemplatePath validates that a template path is safe
func validateTemplatePath(templatePath string) error {
	// Clean the path to resolve any .. or . components
	cleanPath := filepath.Clean(templatePath)

	// Check for path traversal attempts
	if strings.Contains(cleanPath, "..") {
		return fmt.Errorf("path traversal detected in template path: %s", templatePath)
	}

	// For security, only allow templates in user's home directory or absolute paths to known safe locations
	if !filepath.IsAbs(cleanPath) {
		return fmt.Errorf("template path must be absolute: %s", templatePath)
	}

	return nil
}
