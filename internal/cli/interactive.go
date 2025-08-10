package cli

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// EditMode represents the editing mode
type EditMode int

const (
	EditModeNone EditMode = iota
	EditModeInline
	EditModeEditor
)

// InteractiveEditor handles user interaction for editing commit messages
type InteractiveEditor struct {
	reader *bufio.Reader
}

// NewInteractiveEditor creates a new interactive editor
func NewInteractiveEditor() *InteractiveEditor {
	return &InteractiveEditor{
		reader: bufio.NewReader(os.Stdin),
	}
}

// PromptYesNo prompts the user for a yes/no answer
func (ie *InteractiveEditor) PromptYesNo(question string, defaultValue bool) (bool, error) {
	defaultStr := "y/N"
	if defaultValue {
		defaultStr = "Y/n"
	}

	fmt.Printf("%s [%s]: ", question, defaultStr)

	response, err := ie.reader.ReadString('\n')
	if err != nil {
		return false, fmt.Errorf("failed to read input: %w", err)
	}

	response = strings.TrimSpace(strings.ToLower(response))

	if response == "" {
		return defaultValue, nil
	}

	switch response {
	case "y", "yes":
		return true, nil
	case "n", "no":
		return false, nil
	default:
		return ie.PromptYesNo(question, defaultValue)
	}
}

// PromptChoice prompts the user to choose from a list of options
func (ie *InteractiveEditor) PromptChoice(question string, options []string) (int, error) {
	fmt.Println(question)
	for i, option := range options {
		fmt.Printf("  %d. %s\n", i+1, option)
	}
	fmt.Print("Choose an option [1]: ")

	response, err := ie.reader.ReadString('\n')
	if err != nil {
		return 0, fmt.Errorf("failed to read input: %w", err)
	}

	response = strings.TrimSpace(response)
	if response == "" {
		return 0, nil // Default to first option
	}

	// Try to parse as number
	if len(response) == 1 && response[0] >= '1' && response[0] <= '9' {
		choice := int(response[0] - '1')
		if choice >= 0 && choice < len(options) {
			return choice, nil
		}
	}

	fmt.Println("Invalid choice. Please try again.")
	return ie.PromptChoice(question, options)
}

// EditMessage allows the user to edit a commit message
func (ie *InteractiveEditor) EditMessage(message string, mode EditMode) (string, error) {
	switch mode {
	case EditModeInline:
		return ie.editInline(message)
	case EditModeEditor:
		return ie.editWithEditor(message)
	case EditModeNone:
		return message, nil
	default:
		return message, nil
	}
}

// editInline allows inline editing of the message
func (ie *InteractiveEditor) editInline(message string) (string, error) {
	fmt.Printf("Current message: %s\n", message)
	fmt.Print("Enter new message (or press Enter to keep current): ")

	response, err := ie.reader.ReadString('\n')
	if err != nil {
		return message, fmt.Errorf("failed to read input: %w", err)
	}

	response = strings.TrimSpace(response)
	if response == "" {
		return message, nil
	}

	return response, nil
}

// editWithEditor opens the user's preferred editor to edit the message
func (ie *InteractiveEditor) editWithEditor(message string) (string, error) {
	// Get the editor from environment variables
	editor := os.Getenv("EDITOR")
	if editor == "" {
		editor = os.Getenv("VISUAL")
	}
	if editor == "" {
		// Default editors to try
		editors := []string{"nano", "vim", "vi", "emacs"}
		for _, ed := range editors {
			if _, err := exec.LookPath(ed); err == nil {
				editor = ed
				break
			}
		}
		if editor == "" {
			return "", fmt.Errorf("no editor found. Please set EDITOR or VISUAL environment variable")
		}
	}

	// Validate editor command for security
	if strings.Contains(editor, "/") && !strings.HasPrefix(editor, "/usr/bin/") && !strings.HasPrefix(editor, "/bin/") {
		if _, err := exec.LookPath(editor); err != nil {
			return "", fmt.Errorf("editor not found in PATH: %s", editor)
		}
	}

	// Create temporary file
	tmpFile, err := os.CreateTemp("", "commit-ai-*.txt")
	if err != nil {
		return "", fmt.Errorf("failed to create temporary file: %w", err)
	}
	tmpFileName := tmpFile.Name()
	defer func() {
		if err := os.Remove(tmpFileName); err != nil {
			// Log error but don't fail the operation
			fmt.Fprintf(os.Stderr, "Warning: failed to remove temporary file %s: %v\n", tmpFileName, err)
		}
	}()

	// Write current message to file
	if _, err := tmpFile.WriteString(message); err != nil {
		if closeErr := tmpFile.Close(); closeErr != nil {
			fmt.Fprintf(os.Stderr, "Warning: failed to close temporary file: %v\n", closeErr)
		}
		return "", fmt.Errorf("failed to write to temporary file: %w", err)
	}
	if err := tmpFile.Close(); err != nil {
		return "", fmt.Errorf("failed to close temporary file: %w", err)
	}

	// Open editor with validated command
	cmd := exec.Command(editor, tmpFileName) // #nosec G204 -- editor is validated above
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("failed to run editor: %w", err)
	}

	// Read edited content
	content, err := os.ReadFile(tmpFileName) // #nosec G304 -- tmpFileName is from os.CreateTemp, safe path
	if err != nil {
		return "", fmt.Errorf("failed to read edited file: %w", err)
	}

	return strings.TrimSpace(string(content)), nil
}

// DisplayMessage displays a commit message with formatting
func (ie *InteractiveEditor) DisplayMessage(title, message string) {
	fmt.Printf("\n%s:\n", title)
	fmt.Printf("─────────────────────────────────────────────────────────────\n")
	fmt.Printf("%s\n", message)
	fmt.Printf("─────────────────────────────────────────────────────────────\n")
}

// PromptString prompts for a string input
func (ie *InteractiveEditor) PromptString(question string) (string, error) {
	fmt.Printf("%s: ", question)

	response, err := ie.reader.ReadString('\n')
	if err != nil {
		return "", fmt.Errorf("failed to read input: %w", err)
	}

	return strings.TrimSpace(response), nil
}
