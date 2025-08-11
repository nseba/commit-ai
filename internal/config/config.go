package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/BurntSushi/toml"
)

const (
	providerOllama = "ollama"
	providerOpenAI = "openai"
)

// Config holds the application configuration
type Config struct {
	APIURL         string `toml:"CAI_API_URL"`
	Model          string `toml:"CAI_MODEL"`
	Provider       string `toml:"CAI_PROVIDER"`
	APIToken       string `toml:"CAI_API_TOKEN"`
	Language       string `toml:"CAI_LANGUAGE"`
	PromptTemplate string `toml:"CAI_PROMPT_TEMPLATE"`
	TimeoutSeconds int    `toml:"CAI_TIMEOUT_SECONDS"`
}

// DefaultConfig returns the default configuration
func DefaultConfig() *Config {
	return &Config{
		APIURL:         "http://localhost:11434",
		Model:          "llama2",
		Provider:       providerOllama,
		APIToken:       "",
		Language:       "english",
		PromptTemplate: "default.txt",
		TimeoutSeconds: 300, // 5 minutes default
	}
}

// Load loads the configuration from the specified file and applies project-local overrides
// from .commitai files found in the current directory.
func Load(configFile string) (*Config, error) {
	return LoadWithProjectPath(configFile, ".")
}

// LoadWithProjectPath loads the configuration with cascading project-local overrides.
// Configuration is loaded in the following priority order (highest to lowest):
//  1. Environment variables (CAI_*)
//  2. Project-local .commitai files (more specific directories override less specific ones)
//  3. Global configuration file
//  4. Default values
//
// Project-local configurations are discovered by:
//   - Finding the git repository root (if in a git repository)
//   - Looking for .commitai files from the git root to the project path
//   - Applying configurations in hierarchical order
//
// Parameters:
//   - configFile: Path to the global configuration file
//   - projectPath: Path to the project directory (used to find project-local configs)
//
// Returns the merged configuration with all overrides applied.
func LoadWithProjectPath(configFile, projectPath string) (*Config, error) {
	cfg := DefaultConfig()

	// Load global configuration
	if _, err := os.Stat(configFile); os.IsNotExist(err) {
		// If config file doesn't exist, create it with default values
		if err := cfg.Save(configFile); err != nil {
			return nil, fmt.Errorf("failed to create default config file: %w", err)
		}
	} else {
		// Load configuration from file
		if _, err := toml.DecodeFile(configFile, cfg); err != nil {
			return nil, fmt.Errorf("failed to decode config file %s: %w", configFile, err)
		}
	}

	// Apply project-local configuration overrides
	if err := cfg.applyProjectConfig(projectPath); err != nil {
		return nil, fmt.Errorf("failed to apply project configuration: %w", err)
	}

	// Override with environment variables if present (highest priority)
	cfg.loadFromEnv()

	return cfg, nil
}

// Save saves the configuration to the specified file
func (c *Config) Save(configFile string) error {
	// Create directory if it doesn't exist
	dir := filepath.Dir(configFile)
	if err := os.MkdirAll(dir, 0o750); err != nil {
		return fmt.Errorf("failed to create config directory: %w", err)
	}

	// #nosec G304 -- configFile path is controlled by application
	file, err := os.OpenFile(configFile, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o600)
	if err != nil {
		return fmt.Errorf("failed to create config file: %w", err)
	}
	defer file.Close()

	encoder := toml.NewEncoder(file)
	if err := encoder.Encode(c); err != nil {
		return fmt.Errorf("failed to encode config: %w", err)
	}

	return nil
}

// applyProjectConfig applies project-local configuration from .commitai files.
// It finds the git repository root and looks for .commitai files from the root
// to the project path, applying them in hierarchical order.
func (c *Config) applyProjectConfig(projectPath string) error {
	// Find the git repository root
	gitRoot, err := findGitRoot(projectPath)
	if err != nil {
		// If not in a git repository, just use the project path
		gitRoot = projectPath
	}

	// Look for .commitai files from git root up to current directory
	configFiles := findProjectConfigs(gitRoot, projectPath)

	// Apply configurations in order (git root first, then more specific)
	for _, configFile := range configFiles {
		if err := c.loadProjectConfig(configFile); err != nil {
			return fmt.Errorf("failed to load project config %s: %w", configFile, err)
		}
	}

	return nil
}

// loadProjectConfig loads and merges a project-local configuration file.
// Only non-empty values from the project configuration are used to override
// existing configuration values, allowing for partial configuration overrides.
func (c *Config) loadProjectConfig(configFile string) error {
	// Validate the config file path for security (always validate, regardless of file existence)
	if err := validateProjectConfigPath(configFile); err != nil {
		return fmt.Errorf("invalid project config path %s: %w", configFile, err)
	}

	if _, err := os.Stat(configFile); os.IsNotExist(err) {
		return nil // File doesn't exist, skip
	}

	// Create a temporary config to load project settings
	projectCfg := &Config{}
	if _, err := toml.DecodeFile(configFile, projectCfg); err != nil {
		return fmt.Errorf("failed to decode project config file %s: %w", configFile, err)
	}

	// Merge non-empty values from project config into main config
	if projectCfg.APIURL != "" {
		c.APIURL = projectCfg.APIURL
	}
	if projectCfg.Model != "" {
		c.Model = projectCfg.Model
	}
	if projectCfg.Provider != "" {
		c.Provider = projectCfg.Provider
	}
	if projectCfg.APIToken != "" {
		c.APIToken = projectCfg.APIToken
	}
	if projectCfg.Language != "" {
		c.Language = projectCfg.Language
	}
	if projectCfg.PromptTemplate != "" {
		c.PromptTemplate = projectCfg.PromptTemplate
	}
	if projectCfg.TimeoutSeconds != 0 {
		c.TimeoutSeconds = projectCfg.TimeoutSeconds
	}

	return nil
}

// findGitRoot finds the git repository root by walking up the directory tree
// starting from the given path, looking for a .git directory or file.
// Returns an error if no git repository is found.
func findGitRoot(startPath string) (string, error) {
	absPath, err := filepath.Abs(startPath)
	if err != nil {
		return "", err
	}

	currentPath := absPath
	for {
		gitDir := filepath.Join(currentPath, ".git")
		if info, err := os.Stat(gitDir); err == nil {
			// Found .git directory or file
			if info.IsDir() {
				return currentPath, nil
			}
			// .git file (worktree or submodule)
			if err := validateGitPath(gitDir, currentPath); err == nil {
				content, err := os.ReadFile(gitDir)
				if err == nil && strings.HasPrefix(string(content), "gitdir:") {
					return currentPath, nil
				}
			}
		}

		parent := filepath.Dir(currentPath)
		if parent == currentPath {
			// Reached filesystem root
			break
		}
		currentPath = parent
	}

	return "", fmt.Errorf("not in a git repository")
}

// validateGitPath validates that the .git file path is safe to read
func validateGitPath(gitDir, basePath string) error {
	// Check for path traversal attempts first (before cleaning)
	if strings.Contains(gitDir, "..") {
		return fmt.Errorf("path traversal detected in git path: %s", gitDir)
	}

	// Ensure the gitDir is exactly basePath + "/.git"
	expectedPath := filepath.Join(basePath, ".git")
	cleanGitDir := filepath.Clean(gitDir)
	cleanExpected := filepath.Clean(expectedPath)

	if cleanGitDir != cleanExpected {
		return fmt.Errorf("invalid git path: expected %s, got %s", cleanExpected, cleanGitDir)
	}

	return nil
}

// validateProjectConfigPath validates that a project config file path is safe
func validateProjectConfigPath(configFile string) error {
	// Check for path traversal attempts first (before cleaning)
	if strings.Contains(configFile, "..") {
		return fmt.Errorf("path traversal detected in config path")
	}

	// Clean the path to resolve any . components
	cleanPath := filepath.Clean(configFile)

	// Ensure the file ends with .commitai
	if !strings.HasSuffix(cleanPath, ".commitai") {
		return fmt.Errorf("invalid config file extension, must be .commitai")
	}

	// Convert to absolute path for additional validation
	absPath, err := filepath.Abs(cleanPath)
	if err != nil {
		return fmt.Errorf("failed to resolve absolute path: %w", err)
	}

	// Basic sanity check - path should not be empty or in root directory
	if absPath == "/" || absPath == "" || cleanPath == "/" || cleanPath == "" {
		return fmt.Errorf("invalid config file path")
	}

	// Additional check: reject files directly in root directory
	if strings.HasPrefix(absPath, "/") && strings.Count(absPath, "/") == 1 {
		return fmt.Errorf("invalid config file path: cannot use root directory")
	}

	return nil
}

// findProjectConfigs finds all .commitai file paths from git root to project path.
// Returns a slice of file paths in hierarchical order (git root first, then more specific).
// The returned paths may not exist - existence is checked when loading.
func findProjectConfigs(gitRoot, projectPath string) []string {
	var configFiles []string

	// Start from git root
	absGitRoot, err := filepath.Abs(gitRoot)
	if err != nil {
		return configFiles
	}

	absProjectPath, err := filepath.Abs(projectPath)
	if err != nil {
		return configFiles
	}

	// Add .commitai file from git root if it exists
	gitRootConfig := filepath.Join(absGitRoot, ".commitai")
	configFiles = append(configFiles, gitRootConfig)

	// If project path is different from git root, walk up from project path
	if absProjectPath != absGitRoot {
		currentPath := absProjectPath
		for {
			configFile := filepath.Join(currentPath, ".commitai")

			// Don't duplicate the git root config
			if configFile != gitRootConfig {
				configFiles = append(configFiles, configFile)
			}

			// Stop when we reach git root
			if currentPath == absGitRoot {
				break
			}

			parent := filepath.Dir(currentPath)
			if parent == currentPath {
				// Reached filesystem root
				break
			}
			currentPath = parent
		}
	}

	return configFiles
}

// loadFromEnv loads configuration values from environment variables
func (c *Config) loadFromEnv() {
	if val := os.Getenv("CAI_API_URL"); val != "" {
		c.APIURL = val
	}
	if val := os.Getenv("CAI_MODEL"); val != "" {
		c.Model = val
	}
	if val := os.Getenv("CAI_PROVIDER"); val != "" {
		c.Provider = val
	}
	if val := os.Getenv("CAI_API_TOKEN"); val != "" {
		c.APIToken = val
	}
	if val := os.Getenv("CAI_LANGUAGE"); val != "" {
		c.Language = val
	}
	if val := os.Getenv("CAI_PROMPT_TEMPLATE"); val != "" {
		c.PromptTemplate = val
	}
	if val := os.Getenv("CAI_TIMEOUT_SECONDS"); val != "" {
		if timeout, err := strconv.Atoi(val); err == nil && timeout > 0 {
			c.TimeoutSeconds = timeout
		}
	}
}

// GetPromptTemplatePath returns the full path to the prompt template file
func (c *Config) GetPromptTemplatePath(configFile string) string {
	configDir := filepath.Dir(configFile)
	return filepath.Join(configDir, c.PromptTemplate)
}

// Validate validates the configuration
func (c *Config) Validate() error {
	if c.APIURL == "" {
		return fmt.Errorf("CAI_API_URL cannot be empty")
	}
	if c.Model == "" {
		return fmt.Errorf("CAI_MODEL cannot be empty")
	}
	if c.Provider == "" {
		return fmt.Errorf("CAI_PROVIDER cannot be empty")
	}
	if c.Language == "" {
		return fmt.Errorf("CAI_LANGUAGE cannot be empty")
	}
	if c.PromptTemplate == "" {
		return fmt.Errorf("CAI_PROMPT_TEMPLATE cannot be empty")
	}

	// Validate provider
	validProviders := map[string]bool{
		providerOllama: true,
		providerOpenAI: true,
	}
	if !validProviders[c.Provider] {
		return fmt.Errorf("invalid provider: %s. Supported providers: ollama, openai", c.Provider)
	}

	// If using OpenAI, API token is required
	if c.Provider == providerOpenAI && c.APIToken == "" {
		return fmt.Errorf("CAI_API_TOKEN is required when using OpenAI provider")
	}

	return nil
}
