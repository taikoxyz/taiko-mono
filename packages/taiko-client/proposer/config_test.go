package proposer

import (
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
)

var (
	l1Endpoint      = "http://localhost:8545"
	l2Endpoint      = "http://localhost:9545"
	inbox           = common.HexToAddress("0x00000000000000000000000000000000000000aa")
	taikoAnchor     = common.HexToAddress("0x00000000000000000000000000000000000000bb")
	proposeInterval = "10s"
	rpcTimeout      = "5s"
)

func (s *ProposerTestSuite) TestProposerConfigShastaOnlySurface() {
	goldenTouchKey, err := crypto.ToECDSA(common.FromHex(encoding.GoldenTouchPrivKey))
	s.Nil(err)
	goldenTouchAddress := crypto.PubkeyToAddress(goldenTouchKey.PublicKey)

	app := cli.NewApp()
	app.Flags = []cli.Flag{
		&cli.StringFlag{Name: flags.L1WSEndpoint.Name},
		&cli.StringFlag{Name: flags.L2WSEndpoint.Name},
		&cli.StringFlag{Name: flags.InboxAddress.Name},
		&cli.StringFlag{Name: flags.TaikoAnchorAddress.Name},
		&cli.StringFlag{Name: flags.L1ProposerPrivKey.Name},
		&cli.StringFlag{Name: flags.L2SuggestedFeeRecipient.Name},
		&cli.DurationFlag{Name: flags.MinProposingInternal.Name},
		&cli.DurationFlag{Name: flags.ProposeInterval.Name},
		&cli.DurationFlag{Name: flags.RPCTimeout.Name},
	}
	app.Flags = append(app.Flags, flags.TxmgrFlags...)

	app.Action = func(cliCtx *cli.Context) error {
		c, err := NewConfigFromCliContext(cliCtx)
		s.Nil(err)
		s.Equal(l1Endpoint, c.L1Endpoint)
		s.Equal(l2Endpoint, c.L2Endpoint)
		s.Equal(inbox.String(), c.InboxAddress.String())
		s.Equal(taikoAnchor.String(), c.TaikoAnchorAddress.String())
		s.Equal(goldenTouchAddress, crypto.PubkeyToAddress(c.L1ProposerPrivKey.PublicKey))
		s.Equal(goldenTouchAddress, c.L2SuggestedFeeRecipient)
		s.Equal(float64(10), c.ProposeInterval.Seconds())
		s.Equal(5*time.Second, c.Timeout)
		return nil
	}

	s.Nil(app.Run([]string{
		"TestProposerConfigShastaOnlySurface",
		"--" + flags.L1WSEndpoint.Name, l1Endpoint,
		"--" + flags.L2WSEndpoint.Name, l2Endpoint,
		"--" + flags.InboxAddress.Name, inbox.Hex(),
		"--" + flags.TaikoAnchorAddress.Name, taikoAnchor.Hex(),
		"--" + flags.L1ProposerPrivKey.Name, encoding.GoldenTouchPrivKey,
		"--" + flags.L2SuggestedFeeRecipient.Name, goldenTouchAddress.Hex(),
		"--" + flags.ProposeInterval.Name, proposeInterval,
		"--" + flags.RPCTimeout.Name, rpcTimeout,
		"--" + flags.TxGasLimit.Name, "100000",
	}))
}

func (s *ProposerTestSuite) TestNewConfigFromCliContextPrivKeyErr() {
	app := s.SetupApp()

	s.ErrorContains(app.Run([]string{
		"TestNewConfigFromCliContextPrivKeyErr",
		"--" + flags.L1ProposerPrivKey.Name, string(common.FromHex("0x")),
	}), "invalid L1 proposer private key")
}

func (s *ProposerTestSuite) TestNewConfigFromCliContextL2RecipErr() {
	app := s.SetupApp()

	s.ErrorContains(app.Run([]string{
		"TestNewConfigFromCliContextL2RecipErr",
		"--" + flags.L1ProposerPrivKey.Name, encoding.GoldenTouchPrivKey,
		"--" + flags.ProposeInterval.Name, proposeInterval,
		"--" + flags.MinProposingInternal.Name, proposeInterval,
		"--" + flags.L2SuggestedFeeRecipient.Name, "notAnAddress",
	}), "invalid L2 suggested fee recipient address")
}

func (s *ProposerTestSuite) SetupApp() *cli.App {
	app := cli.NewApp()
	app.Flags = []cli.Flag{
		&cli.StringFlag{Name: flags.L1WSEndpoint.Name},
		&cli.StringFlag{Name: flags.L2WSEndpoint.Name},
		&cli.StringFlag{Name: flags.InboxAddress.Name},
		&cli.StringFlag{Name: flags.TaikoAnchorAddress.Name},
		&cli.StringFlag{Name: flags.L1ProposerPrivKey.Name},
		&cli.StringFlag{Name: flags.L2SuggestedFeeRecipient.Name},
		&cli.DurationFlag{Name: flags.MinProposingInternal.Name},
		&cli.DurationFlag{Name: flags.ProposeInterval.Name},
		&cli.DurationFlag{Name: flags.RPCTimeout.Name},
	}
	app.Flags = append(app.Flags, flags.TxmgrFlags...)
	app.Action = func(ctx *cli.Context) error {
		_, err := NewConfigFromCliContext(ctx)
		return err
	}
	return app
}
