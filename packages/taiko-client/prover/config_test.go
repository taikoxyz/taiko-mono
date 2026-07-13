package prover

import (
	"os"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/require"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
)

func (s *ProverTestSuite) TestProverConfigShastaOnlySurface() {
	l1Endpoint := "http://localhost:8545"
	l1BeaconEndpoint := "http://localhost:5052"
	l2Endpoint := "http://localhost:9545"
	inbox := common.HexToAddress("0x00000000000000000000000000000000000000aa")
	taikoAnchor := common.HexToAddress("0x00000000000000000000000000000000000000bb")

	app := cli.NewApp()
	app.Flags = []cli.Flag{
		&cli.StringFlag{Name: flags.L1WSEndpoint.Name},
		&cli.StringFlag{Name: flags.L1BeaconEndpoint.Name},
		&cli.StringFlag{Name: flags.L2WSEndpoint.Name},
		&cli.StringFlag{Name: flags.InboxAddress.Name},
		&cli.StringFlag{Name: flags.TaikoAnchorAddress.Name},
		&cli.StringFlag{Name: flags.L1ProverPrivKey.Name},
		&cli.StringFlag{Name: flags.JWTSecret.Name},
		&cli.StringFlag{Name: flags.RaikoHostEndpoint.Name},
		&cli.StringFlag{Name: flags.RaikoZKVMHostEndpoint.Name},
		&cli.StringFlag{Name: flags.RaikoApiKeyPath.Name},
		&cli.DurationFlag{Name: flags.RaikoRequestTimeout.Name},
	}

	app.Action = func(ctx *cli.Context) error {
		c, err := NewConfigFromCliContext(ctx)
		s.Nil(err)
		s.Equal(l1Endpoint, c.L1WsEndpoint)
		s.Equal(l1BeaconEndpoint, c.L1BeaconEndpoint)
		s.Equal(l2Endpoint, c.L2WsEndpoint)
		s.Equal(inbox.String(), c.InboxAddress.String())
		s.Equal(taikoAnchor.String(), c.TaikoAnchorAddress.String())
		s.Equal("http://raiko.host", c.RaikoHostEndpoint)
		s.Equal("http://raiko.zkvm", c.RaikoZKVMHostEndpoint)
		s.Equal("secret-key", c.RaikoApiKey)
		s.Equal(7*time.Second, c.RaikoRequestTimeout)

		return nil
	}

	tempAPIKey := s.T().TempDir() + "/api-key.txt"
	s.Nil(os.WriteFile(tempAPIKey, []byte("  secret-key  \n"), 0o600))

	s.Nil(app.Run([]string{
		"TestProverConfigShastaOnlySurface",
		"--" + flags.L1WSEndpoint.Name, l1Endpoint,
		"--" + flags.L1BeaconEndpoint.Name, l1BeaconEndpoint,
		"--" + flags.L2WSEndpoint.Name, l2Endpoint,
		"--" + flags.InboxAddress.Name, inbox.Hex(),
		"--" + flags.TaikoAnchorAddress.Name, taikoAnchor.Hex(),
		"--" + flags.L1ProverPrivKey.Name, encoding.GoldenTouchPrivKey,
		"--" + flags.JWTSecret.Name, os.Getenv("JWT_SECRET"),
		"--" + flags.RaikoHostEndpoint.Name, "http://raiko.host",
		"--" + flags.RaikoZKVMHostEndpoint.Name, "http://raiko.zkvm",
		"--" + flags.RaikoApiKeyPath.Name, tempAPIKey,
		"--" + flags.RaikoRequestTimeout.Name, "7s",
	}))
}

func TestNewConfigFromCliContextMaxRisc0ProofProposalDistance(t *testing.T) {
	t.Run("uses default value", func(t *testing.T) {
		cfg := newTestConfigFromCLI(t)

		require.Equal(t, uint64(30), cfg.MaxRisc0ProofProposalDistance)
	})

	t.Run("uses flag value", func(t *testing.T) {
		cfg := newTestConfigFromCLI(t, "--"+flags.MaxRisc0ProofProposalDistance.Name, "12")

		require.Equal(t, uint64(12), cfg.MaxRisc0ProofProposalDistance)
	})

	t.Run("rejects removed legacy flag", func(t *testing.T) {
		err := runTestConfigFromCLI(t, "--prover.maxZKProofProposalDistance", "13")

		require.ErrorContains(t, err, "flag provided but not defined")
	})
}

func TestNewConfigFromCliContextForceSP1Proof(t *testing.T) {
	t.Run("uses default value", func(t *testing.T) {
		cfg := newTestConfigFromCLI(t)

		require.False(t, cfg.ForceSP1Proof)
	})

	t.Run("uses flag value", func(t *testing.T) {
		cfg := newTestConfigFromCLI(t, "--"+flags.ForceSP1Proof.Name)

		require.True(t, cfg.ForceSP1Proof)
	})
}

func TestNewConfigFromCliContextZkOnlyProofs(t *testing.T) {
	t.Run("uses default value", func(t *testing.T) {
		cfg := newTestConfigFromCLI(t)

		require.False(t, cfg.ZkOnlyProofs)
	})

	t.Run("requires the ZKVM raiko host", func(t *testing.T) {
		err := runTestConfigFromCLI(t, "--"+flags.ZkOnlyProofs.Name)

		require.ErrorContains(t, err, "--"+flags.RaikoZKVMHostEndpoint.Name)
	})

	t.Run("uses flag value with the ZKVM raiko host", func(t *testing.T) {
		cfg := newTestConfigFromCLI(
			t,
			"--"+flags.RaikoHostEndpoint.Name, "",
			"--"+flags.ZkOnlyProofs.Name,
			"--"+flags.RaikoZKVMHostEndpoint.Name, "http://raiko.zkvm",
		)

		require.True(t, cfg.ZkOnlyProofs)
		require.Empty(t, cfg.RaikoHostEndpoint)
	})
}

func TestNewConfigFromCliContextRequiresRaikoHostOutsideZkOnlyMode(t *testing.T) {
	err := runTestConfigFromCLI(t, "--"+flags.RaikoHostEndpoint.Name, "")

	require.ErrorContains(t, err, "--"+flags.RaikoHostEndpoint.Name)
}

func (s *ProverTestSuite) TestNewConfigFromCliContextProverKeyError() {
	app := s.SetupApp()

	s.ErrorContains(app.Run([]string{
		"TestNewConfigFromCliContext",
		"--" + flags.L1ProverPrivKey.Name, "0x",
	}), "invalid L1 prover private key")
}

func (s *ProverTestSuite) SetupApp() *cli.App {
	app := cli.NewApp()
	app.Flags = []cli.Flag{
		&cli.StringFlag{Name: flags.L1WSEndpoint.Name},
		&cli.StringFlag{Name: flags.L2WSEndpoint.Name},
		&cli.StringFlag{Name: flags.InboxAddress.Name},
		&cli.StringFlag{Name: flags.TaikoAnchorAddress.Name},
		&cli.StringFlag{Name: flags.L1ProverPrivKey.Name},
		&cli.Uint64Flag{Name: flags.StartingProposalID.Name},
		&cli.BoolFlag{Name: flags.Dummy.Name},
		&cli.BoolFlag{Name: flags.ProveUnassignedProposals.Name},
		&cli.DurationFlag{Name: flags.RPCTimeout.Name},
		&cli.StringFlag{Name: flags.RaikoHostEndpoint.Name},
	}
	app.Flags = append(app.Flags, flags.TxmgrFlags...)
	app.Action = func(ctx *cli.Context) error {
		_, err := NewConfigFromCliContext(ctx)
		s.NotNil(err)
		return err
	}
	return app
}

func newTestConfigFromCLI(t *testing.T, extraArgs ...string) *Config {
	t.Helper()

	var cfg *Config
	require.NoError(t, runTestConfigFromCLIWithConfig(t, &cfg, extraArgs...))
	return cfg
}

func runTestConfigFromCLI(t *testing.T, extraArgs ...string) error {
	t.Helper()

	var cfg *Config
	return runTestConfigFromCLIWithConfig(t, &cfg, extraArgs...)
}

func runTestConfigFromCLIWithConfig(t *testing.T, cfg **Config, extraArgs ...string) error {
	t.Helper()

	jwtSecret := t.TempDir() + "/jwt-secret.txt"
	require.NoError(
		t,
		os.WriteFile(
			jwtSecret,
			[]byte("0x1000000000000000000000000000000000000000000000000000000000000000"),
			0o600,
		),
	)

	app := cli.NewApp()
	app.Flags = []cli.Flag{
		&cli.StringFlag{Name: flags.L1WSEndpoint.Name},
		&cli.StringFlag{Name: flags.L2WSEndpoint.Name},
		&cli.StringFlag{Name: flags.InboxAddress.Name},
		&cli.StringFlag{Name: flags.TaikoAnchorAddress.Name},
		&cli.StringFlag{Name: flags.L1ProverPrivKey.Name},
		&cli.StringFlag{Name: flags.JWTSecret.Name},
		&cli.Uint64Flag{
			Name:    flags.MaxRisc0ProofProposalDistance.Name,
			Aliases: flags.MaxRisc0ProofProposalDistance.Aliases,
			Value:   flags.MaxRisc0ProofProposalDistance.Value,
		},
		&cli.BoolFlag{Name: flags.ForceSP1Proof.Name},
		&cli.BoolFlag{Name: flags.ZkOnlyProofs.Name},
		&cli.StringFlag{Name: flags.RaikoHostEndpoint.Name},
		&cli.StringFlag{Name: flags.RaikoZKVMHostEndpoint.Name},
	}

	app.Action = func(ctx *cli.Context) error {
		var err error
		*cfg, err = NewConfigFromCliContext(ctx)
		return err
	}

	args := []string{
		"TestNewConfigFromCliContextMaxRisc0ProofProposalDistance",
		"--" + flags.L1WSEndpoint.Name, "http://localhost:8545",
		"--" + flags.L2WSEndpoint.Name, "http://localhost:9545",
		"--" + flags.InboxAddress.Name, common.HexToAddress("0x00000000000000000000000000000000000000aa").Hex(),
		"--" + flags.TaikoAnchorAddress.Name, common.HexToAddress("0x00000000000000000000000000000000000000bb").Hex(),
		"--" + flags.L1ProverPrivKey.Name, encoding.GoldenTouchPrivKey,
		"--" + flags.JWTSecret.Name, jwtSecret,
		"--" + flags.RaikoHostEndpoint.Name, "http://raiko.host",
	}
	args = append(args, extraArgs...)

	return app.Run(args)
}
