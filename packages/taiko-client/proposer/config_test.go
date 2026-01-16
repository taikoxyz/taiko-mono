package proposer

import (
	"context"
	"os"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
)

var (
	l1Endpoint      = os.Getenv("L1_HTTP")
	l2Endpoint      = os.Getenv("L2_WS")
	pacayaInbox     = os.Getenv("PACAYA_INBOX")
	shastaInbox     = os.Getenv("SHASTA_INBOX")
	taikoAnchor     = os.Getenv("TAIKO_ANCHOR")
	taikoToken      = os.Getenv("TAIKO_TOKEN")
	proposeInterval = "10s"
	rpcTimeout      = "5s"
)

func (s *ProposerTestSuite) TestNewConfigFromCliContext() {
	goldenTouchAddress, err := s.RPCClient.PacayaClients.TaikoAnchor.GOLDENTOUCHADDRESS(nil)
	s.Nil(err)

	app := s.SetupApp()

	app.Action = func(cliCtx *cli.Context) error {
		c, err := NewConfigFromCliContext(cliCtx)
		s.Nil(err)
		s.Equal(l1Endpoint, c.L1Endpoint)
		s.Equal(l2Endpoint, c.L2Endpoint)
		s.Equal(pacayaInbox, c.PacayaInboxAddress.String())
		s.Equal(shastaInbox, c.ShastaInboxAddress.String())
		s.Equal(taikoAnchor, c.TaikoAnchorAddress.String())
		s.Equal(taikoToken, c.TaikoTokenAddress.String())
		s.Equal(goldenTouchAddress, crypto.PubkeyToAddress(c.L1ProposerPrivKey.PublicKey))
		s.Equal(goldenTouchAddress, c.L2SuggestedFeeRecipient)
		s.Equal(float64(10), c.ProposeInterval.Seconds())
		s.Equal(5*time.Second, c.Timeout)

		s.Nil(new(Proposer).InitFromCli(context.Background(), cliCtx))
		return nil
	}

	s.Nil(app.Run([]string{
		"TestNewConfigFromCliContext",
		"--" + flags.L1HTTPEndpoint.Name, l1Endpoint,
		"--" + flags.L2WSEndpoint.Name, l2Endpoint,
		"--" + flags.PacayaInboxAddress.Name, pacayaInbox,
		"--" + flags.ShastaInboxAddress.Name, shastaInbox,
		"--" + flags.TaikoAnchorAddress.Name, taikoAnchor,
		"--" + flags.TaikoTokenAddress.Name, taikoToken,
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
		&cli.StringFlag{Name: flags.L1HTTPEndpoint.Name},
		&cli.StringFlag{Name: flags.L1WSEndpoint.Name},
		&cli.StringFlag{Name: flags.L2WSEndpoint.Name},
		&cli.StringFlag{Name: flags.PacayaInboxAddress.Name},
		&cli.StringFlag{Name: flags.ShastaInboxAddress.Name},
		&cli.StringFlag{Name: flags.TaikoAnchorAddress.Name},
		&cli.StringFlag{Name: flags.TaikoTokenAddress.Name},
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
