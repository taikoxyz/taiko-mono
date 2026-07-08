package testutils

import (
	"fmt"
	"os"
	"strings"

	"github.com/ethereum/go-ethereum/log"
	"github.com/joho/godotenv"
)

// LoadEnv loads all the test environment variables.
func LoadEnv() {
	currentPath, err := os.Getwd()
	if err != nil {
		log.Debug("Failed to get current path", "error", err)
	}
	path := strings.Split(currentPath, "/taiko-client")
	if len(path) == 0 {
		log.Debug("Not a taiko-client repo")
	}
	if loadErr := godotenv.Load(fmt.Sprintf("%s/taiko-client/integration_test/.env", path[0])); loadErr != nil {
		log.Debug("Failed to load test env", "current path", currentPath, "error", loadErr)
	}
}
