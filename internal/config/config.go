package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"

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

// Load loads the configuration from the specified file
func Load(configFile string) (*Config, error) {
	cfg := DefaultConfig()

	// Check if config file exists
	if _, err := os.Stat(configFile); os.IsNotExist(err) {
		// If config file doesn't exist, create it with default values
		if err := cfg.Save(configFile); err != nil {
			return nil, fmt.Errorf("failed to create default config file: %w", err)
		}
		return cfg, nil
	}

	// Load configuration from file
	if _, err := toml.DecodeFile(configFile, cfg); err != nil {
		return nil, fmt.Errorf("failed to decode config file %s: %w", configFile, err)
	}

	// Override with environment variables if present
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
