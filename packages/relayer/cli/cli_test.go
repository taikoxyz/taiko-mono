package cli

import (
	"os"
	"strings"
	"testing"

	"gopkg.in/go-playground/assert.v1"
)

func Test_loadAndValidateEnvVars(t *testing.T) {
	for _, envVar := range envVars {
		os.Setenv(envVar, "valid")
	}
	assert.Equal(t, loadAndValidateEnv(), nil)
}

func Test_loadAndValidateEnvVars_missing(t *testing.T) {
	for _, envVar := range envVars {
		os.Setenv(envVar, "valid")
	}

	for _, envVar := range envVars {
		os.Setenv(envVar, "")
		err := loadAndValidateEnv()
		assert.NotEqual(t, err, nil)
		assert.Equal(t, true, strings.Contains(err.Error(), envVar))
		os.Setenv(envVar, "valid")
	}
}
