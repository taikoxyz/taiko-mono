package flags

import (
	"os"
	"testing"

	"github.com/stretchr/testify/require"
	"github.com/urfave/cli/v2"
)

func TestProverFlagsAllowZkOnlyModeWithoutRaikoHost(t *testing.T) {
	oldRaikoHost, hadRaikoHost := os.LookupEnv("RAIKO_HOST")
	require.NoError(t, os.Unsetenv("RAIKO_HOST"))
	t.Cleanup(func() {
		if hadRaikoHost {
			require.NoError(t, os.Setenv("RAIKO_HOST", oldRaikoHost))
		}
	})

	app := cli.NewApp()
	app.Flags = ProverFlags
	actionCalled := false
	app.Action = func(*cli.Context) error {
		actionCalled = true
		return nil
	}

	err := app.Run([]string{
		"prover",
		"--" + InboxAddress.Name, "0x0000000000000000000000000000000000000001",
		"--" + TaikoAnchorAddress.Name, "0x0000000000000000000000000000000000000002",
		"--" + L2AuthEndpoint.Name, "http://localhost:8551",
		"--" + JWTSecret.Name, "jwt-secret.txt",
		"--" + L1ProverPrivKey.Name, "0x01",
		"--" + ZkOnlyProofs.Name,
		"--" + RaikoZKVMHostEndpoint.Name, "http://raiko.zkvm",
	})

	require.NoError(t, err)
	require.True(t, actionCalled)
}
