package prover

import (
	"os"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
)

func (s *ProverTestSuite) TestProverConfigShastaOnlySurface() {
	l1Endpoint := "http://localhost:8545"
	l1BeaconEndpoint := "http://localhost:5052"
	l2Endpoint := "http://localhost:9545"
	l2HttpEndpoint := "http://localhost:10545"
	inbox := common.HexToAddress("0x00000000000000000000000000000000000000aa")
	taikoAnchor := common.HexToAddress("0x00000000000000000000000000000000000000bb")

	app := cli.NewApp()
	app.Flags = []cli.Flag{
		&cli.StringFlag{Name: flags.L1WSEndpoint.Name},
		&cli.StringFlag{Name: flags.L1BeaconEndpoint.Name},
		&cli.StringFlag{Name: flags.L2WSEndpoint.Name},
		&cli.StringFlag{Name: flags.L2HTTPEndpoint.Name},
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
		s.Equal(l2HttpEndpoint, c.L2HttpEndpoint)
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
		"--" + flags.L2HTTPEndpoint.Name, l2HttpEndpoint,
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
		&cli.StringFlag{Name: flags.L2HTTPEndpoint.Name},
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
