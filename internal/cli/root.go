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
	cfgFile string
	path    string
	version = "dev" // Set by build flags
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

		// Get git diff
		gitRepo, err := git.NewRepository(targetPath)
		if err != nil {
			return fmt.Errorf("failed to initialize git repository: %w", err)
		}

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

func init() {
	cobra.OnInitialize(initConfig)

	// Add version command
	rootCmd.AddCommand(versionCmd)

	// Global flags
	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.config/commit-ai/config.toml)")
	rootCmd.PersistentFlags().StringVarP(&path, "path", "p", "", "path to git repository (default is current directory)")
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
