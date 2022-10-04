// Package pprint provides colored "pretty print" output helper methods
package pprint

import (
	"fmt"
	"os"
)

const (
	errorString   = "\033[1m\033[31mERROR:\033[0m %s\n"
	warningString = "\033[35mWARNING:\033[0m %s\n"
	infoString    = "\033[32mINFO:\033[0m %s\n"
	clearLine     = "\033[A\033[K"
)

// Error prints an error message in bazel style colors
func Error(errorMsg string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, errorString, fmt.Sprintf(errorMsg, args...))
}

// Warning prints a warning message in bazel style colors
func Warning(warningMsg string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, warningString, fmt.Sprintf(warningMsg, args...))
}

// Info prints an info message in bazel style colors
func Info(infoMsg string, args ...interface{}) {
	fmt.Fprintf(os.Stderr, infoString, fmt.Sprintf(infoMsg, args...))
}

// ClearLine deletes the line above the cursor's current position.
func ClearLine() {
	fmt.Printf(clearLine)
}
