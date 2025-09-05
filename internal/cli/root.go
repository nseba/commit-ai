package cli

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/spf13/cobra"

	"github.com/nseba/commit-ai/internal/config"
	"github.com/nseba/commit-ai/internal/generator"
	"github.com/nseba/commit-ai/internal/git"
)

var (
	cfgFile       string
	path          string
	version       = "dev" // Set by build flags
	showCommit    bool
	editCommit    bool
	commitChanges bool
	stageAll      bool
)

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "commit-ai [path]",
	Short: "Generate AI-powered commit messages from git diffs",
	Long: `commit-ai is a CLI tool that scans git diff files and generates
meaningful commit messages using AI. It supports multiple AI providers
and allows customization through configuration files and prompt templates.`,
	Args: cobra.MaximumNArgs(1),
	RunE: func(cmd *cobra.Command, args []string) error {
		// Set path from argument or default to current directory
		targetPath := "."
		if len(args) > 0 {
			targetPath = args[0]
		}
		if path != "" {
			targetPath = path
		}

		// Load configuration with project-local overrides
		cfg, err := config.LoadWithProjectPath(cfgFile, targetPath)
		if err != nil {
			return fmt.Errorf("failed to load configuration: %w", err)
		}

		// Validate configuration
		if err := cfg.Validate(); err != nil {
			return fmt.Errorf("invalid configuration: %w", err)
		}

		// Get git repository
		gitRepo, err := git.NewRepository(targetPath)
		if err != nil {
			return fmt.Errorf("failed to initialize git repository: %w", err)
		}

		// Handle show commit flag
		if showCommit {
			return handleShowCommit(gitRepo)
		}

		// Stage all changes if requested
		if stageAll {
			if err := gitRepo.StageAll(); err != nil {
				return fmt.Errorf("failed to stage changes: %w", err)
			}
			fmt.Println("Staged all changes")
		}

		// Get git diff
		diff, err := gitRepo.GetDiff()
		if err != nil {
			return fmt.Errorf("failed to get git diff: %w", err)
		}

		if diff == "" {
			fmt.Println("No changes to commit")
			return nil
		}

		// Apply ignore patterns
		filteredDiff, err := gitRepo.ApplyIgnorePatterns(diff, targetPath)
		if err != nil {
			return fmt.Errorf("failed to apply ignore patterns: %w", err)
		}

		if filteredDiff == "" {
			fmt.Println("chore: No changes after applying ignore patterns")
			return nil
		}

		// Generate commit message
		gen, err := generator.New(cfg, cfgFile)
		if err != nil {
			return fmt.Errorf("failed to create generator: %w", err)
		}

		commitMessage, err := gen.Generate(filteredDiff)
		if err != nil {
			return fmt.Errorf("failed to generate commit message: %w", err)
		}

		// Handle interactive editing or commit
		if editCommit || commitChanges {
			return handleInteractiveMode(commitMessage, gitRepo)
		}

		// Output the commit message
		fmt.Print(commitMessage)
		return nil
	},
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() error {
	return rootCmd.Execute()
}

// versionCmd represents the version command
var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Print the version number of commit-ai",
	Long:  `Print the version number of commit-ai and exit.`,
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("commit-ai version %s\n", version)
	},
}

// initCmd represents the init command
var initCmd = &cobra.Command{
	Use:   "init",
	Short: "Initialize project configuration",
	Long: `Initialize commit-ai configuration for the current project.

This will create:
- .commitai: Project-specific configuration file
- .caiignore: File patterns to ignore when generating commit messages
- custom-prompt.txt: Custom prompt template for this project`,
	RunE: func(cmd *cobra.Command, args []string) error {
		return initProject()
	},
}

// handleShowCommit shows the last commit message
func handleShowCommit(gitRepo *git.Repository) error {
	lastCommit, err := gitRepo.GetLastCommitMessage()
	if err != nil {
		return fmt.Errorf("failed to get last commit message: %w", err)
	}

	editor := NewInteractiveEditor()
	editor.DisplayMessage("Last Commit Message", lastCommit)
	return nil
}

// handleInteractiveMode handles interactive editing and committing
func handleInteractiveMode(generatedMessage string, gitRepo *git.Repository) error {
	editor := NewInteractiveEditor()
	finalMessage := generatedMessage

	// Show generated message
	editor.DisplayMessage("Generated Commit Message", generatedMessage)

	if editCommit {
		// Ask user how they want to edit
		editOptions := []string{
			"Keep as is",
			"Edit inline",
			"Edit with external editor",
		}

		choice, err := editor.PromptChoice("How would you like to proceed?", editOptions)
		if err != nil {
			return fmt.Errorf("failed to get user choice: %w", err)
		}

		var editMode EditMode
		switch choice {
		case 0:
			editMode = EditModeNone
		case 1:
			editMode = EditModeInline
		case 2:
			editMode = EditModeEditor
		}

		if editMode != EditModeNone {
			finalMessage, err = editor.EditMessage(generatedMessage, editMode)
			if err != nil {
				return fmt.Errorf("failed to edit message: %w", err)
			}
		}
	}

	if commitChanges {
		// Show final message
		if finalMessage != generatedMessage {
			editor.DisplayMessage("Final Commit Message", finalMessage)
		}

		// Confirm commit
		shouldCommit, err := editor.PromptYesNo("Do you want to commit with this message?", true)
		if err != nil {
			return fmt.Errorf("failed to get confirmation: %w", err)
		}

		if shouldCommit {
			if err := gitRepo.Commit(finalMessage); err != nil {
				return fmt.Errorf("failed to commit: %w", err)
			}
			fmt.Println("✓ Committed successfully!")
		} else {
			fmt.Println("Commit canceled.")
		}
	} else {
		// Just output the final message
		fmt.Printf("\nFinal message:\n%s\n", finalMessage)
	}

	return nil
}

// initProject initializes project configuration files in the current directory
func initProject() error {
	currentDir, err := os.Getwd()
	if err != nil {
		return fmt.Errorf("failed to get current directory: %w", err)
	}

	fmt.Printf("Initializing commit-ai configuration in: %s\n", currentDir)

	// Create .commitai configuration file
	if err := createProjectConfig(currentDir); err != nil {
		return fmt.Errorf("failed to create .commitai file: %w", err)
	}

	// Create .caiignore file
	if err := createIgnoreFile(currentDir); err != nil {
		return fmt.Errorf("failed to create .caiignore file: %w", err)
	}

	// Create custom prompt template
	if err := createCustomPromptTemplate(currentDir); err != nil {
		return fmt.Errorf("failed to create custom prompt template: %w", err)
	}

	fmt.Println("✓ Project initialized successfully!")
	fmt.Println("\nFiles created:")
	fmt.Println("  .commitai - Project configuration")
	fmt.Println("  .caiignore - Ignore patterns")
	fmt.Println("  custom-prompt.txt - Custom prompt template")
	fmt.Println("\nYou can now customize these files for your project.")

	return nil
}

// createProjectConfig creates a .commitai configuration file
func createProjectConfig(dir string) error {
	configPath := filepath.Join(dir, ".commitai")

	// Check if file already exists
	if _, err := os.Stat(configPath); err == nil {
		fmt.Printf("⚠️  .commitai already exists, skipping\n")
		return nil
	}

	content := `# Project-specific commit-ai configuration
# This file allows you to override global settings for this project
# Only specify the values you want to change

# AI Provider settings
# CAI_PROVIDER = "ollama"  # or "openai"
# CAI_MODEL = "llama2"     # or "gpt-3.5-turbo", "gpt-4", etc.
# CAI_API_URL = "http://localhost:11434"  # or "https://api.openai.com"
# CAI_API_TOKEN = ""       # Required for OpenAI

# Language and template settings
# CAI_LANGUAGE = "english"
# CAI_PROMPT_TEMPLATE = "custom-prompt.txt"  # Use the custom template created in this directory

# Timeout settings
# CAI_TIMEOUT_SECONDS = 300
`

	if err := os.WriteFile(configPath, []byte(content), 0o600); err != nil {
		return err
	}

	fmt.Println("✓ Created .commitai")
	return nil
}

// createIgnoreFile creates a .caiignore file
func createIgnoreFile(dir string) error {
	ignorePath := filepath.Join(dir, ".caiignore")

	// Check if file already exists
	if _, err := os.Stat(ignorePath); err == nil {
		fmt.Printf("⚠️  .caiignore already exists, skipping\n")
		return nil
	}

	content := `# Ignore patterns for commit-ai (syntax like .gitignore)
# These files will be excluded from diff analysis when generating commit messages

# Ignore log files
*.log
logs/

# Ignore generated files
dist/
build/
*.generated.*

# Ignore documentation changes (uncomment if you want to focus on code changes)
# *.md
# docs/

# Ignore test files (uncomment if you want to focus on implementation changes)
# *_test.*
# test/
# tests/

# Ignore vendor/node_modules directories
vendor/
node_modules/

# Ignore temporary files
*.tmp
*.temp
.DS_Store
Thumbs.db
`

	if err := os.WriteFile(ignorePath, []byte(content), 0o600); err != nil {
		return err
	}

	fmt.Println("✓ Created .caiignore")
	return nil
}

// createCustomPromptTemplate creates a custom prompt template file
func createCustomPromptTemplate(dir string) error {
	templatePath := filepath.Join(dir, "custom-prompt.txt")

	// Check if file already exists
	if _, err := os.Stat(templatePath); err == nil {
		fmt.Printf("⚠️  custom-prompt.txt already exists, skipping\n")
		return nil
	}

	// Use the same default template as in generator package
	content := `You are an expert developer reviewing a git diff to generate a concise, meaningful commit message.

Language: Generate the commit message in {{.Language}}.

Git Diff:
{{.Diff}}

Based on the above git diff, generate a single line commit message that:
1. Is concise and descriptive (50 characters or less preferred)
2. Uses conventional commit format if applicable (feat:, fix:, docs:, etc.)
3. Describes WHAT changed, not HOW it was implemented
4. Uses imperative mood (e.g., "Add feature" not "Added feature")

Commit Message:`

	if err := os.WriteFile(templatePath, []byte(content), 0o600); err != nil;
		return err
	}

	fmt.Println("✓ Created custom-prompt.txt")
	return nil
}

func init() {
	cobra.OnInitialize(initConfig)

	// Add subcommands
	rootCmd.AddCommand(versionCmd)
	rootCmd.AddCommand(initCmd)

	// Global flags
	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.config/commit-ai/config.toml)")
	rootCmd.PersistentFlags().StringVarP(&path, "path", "p", "", "path to git repository (default is current directory)")

	// Feature flags
	rootCmd.Flags().BoolVarP(&showCommit, "show", "s", false, "show the last commit message")
	rootCmd.Flags().BoolVarP(&editCommit, "edit", "e", false, "allow editing of the generated commit message")
	rootCmd.Flags().BoolVarP(&commitChanges, "commit", "c", false, "commit the changes with the generated/edited message")
	rootCmd.Flags().BoolVarP(&stageAll, "add", "a", false, "stage all changes before generating commit message")
}

// initConfig reads in config file and ENV variables if set.
func initConfig() {
	if cfgFile == "" {
		// Find home directory.
		home, err := os.UserHomeDir()
		cobra.CheckErr(err)

		// Search config in ~/.config/commit-ai directory with name "config.toml"
		cfgFile = filepath.Join(home, ".config", "commit-ai", "config.toml")
	}
}
