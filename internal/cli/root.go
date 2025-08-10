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

		// Load configuration
		cfg, err := config.Load(cfgFile)
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
			fmt.Println("Commit cancelled.")
		}
	} else {
		// Just output the final message
		fmt.Printf("\nFinal message:\n%s\n", finalMessage)
	}

	return nil
}

func init() {
	cobra.OnInitialize(initConfig)

	// Add version command
	rootCmd.AddCommand(versionCmd)

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
