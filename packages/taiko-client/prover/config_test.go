package prover

import (
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
)

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
		&cli.StringFlag{Name: flags.L1HTTPEndpoint.Name},
		&cli.StringFlag{Name: flags.L1WSEndpoint.Name},
		&cli.StringFlag{Name: flags.L2WSEndpoint.Name},
		&cli.StringFlag{Name: flags.L2HTTPEndpoint.Name},
		&cli.StringFlag{Name: flags.PacayaInboxAddress.Name},
		&cli.StringFlag{Name: flags.ShastaInboxAddress.Name},
		&cli.StringFlag{Name: flags.TaikoAnchorAddress.Name},
		&cli.StringFlag{Name: flags.L1ProverPrivKey.Name},
		&cli.Uint64Flag{Name: flags.StartingBatchID.Name},
		&cli.BoolFlag{Name: flags.Dummy.Name},
		&cli.BoolFlag{Name: flags.ProveUnassignedBlocks.Name},
		&cli.DurationFlag{Name: flags.RPCTimeout.Name},
		&cli.StringFlag{Name: flags.Allowance.Name},
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
