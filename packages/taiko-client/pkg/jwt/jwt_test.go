package jwt

import (
	"os"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestParseSecretFromFile(t *testing.T) {
	_, err := ParseSecretFromFile(os.Getenv("JWT_SECRET"))
	require.Nil(t, err)

	secret, err := ParseSecretFromFile("")
	require.Nil(t, err)
	require.Nil(t, secret)

	// File not exists
	_, err = ParseSecretFromFile("TestParseSecretFromFile")
	require.NotNil(t, err)

	// Empty file
	file, err := os.CreateTemp("", "TestParseSecretFromFile")
	require.Nil(t, err)
	defer file.Close()
	defer os.Remove(file.Name())

	_, err = ParseSecretFromFile(file.Name())
	require.ErrorContains(t, err, "cannot be empty")

	file2, err := os.CreateTemp("", "test")
	require.Nil(t, err)
	defer file2.Close()
	defer os.Remove(file2.Name())

	_, err2 := file2.WriteString("0x10020FCb72e2765065")
	require.Nil(t, err2)

	_, err3 := ParseSecretFromFile(file2.Name())
	require.ErrorContains(t, err3, "at least 32 bytes")
}
