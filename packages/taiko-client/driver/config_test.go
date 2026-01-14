package driver

import (
	"context"
	"net"
	"os"
	"time"

	"github.com/ethereum/go-ethereum/p2p/enode"
	"github.com/urfave/cli/v2"

	p2pFlags "github.com/ethereum-optimism/optimism/op-node/flags"
	"github.com/ethereum-optimism/optimism/op-node/p2p"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
)

var (
	l1Endpoint       = os.Getenv("L1_HTTP")
	l1BeaconEndpoint = os.Getenv("L1_BEACON")
	l2Endpoint       = os.Getenv("L2_WS")
	l2CheckPoint     = os.Getenv("L2_HTTP")
	l2EngineEndpoint = os.Getenv("L2_AUTH")
	pacayaInbox      = os.Getenv("PACAYA_INBOX")
	shastaInbox      = os.Getenv("SHASTA_INBOX")
	taikoAnchor      = os.Getenv("TAIKO_ANCHOR")
)

func (s *DriverTestSuite) TestNewConfigFromCliContext() {
	app := s.SetupApp()

	app.Action = func(ctx *cli.Context) error {
		c, err := NewConfigFromCliContext(ctx)
		s.Nil(err)
		s.Equal(l1Endpoint, c.L1Endpoint)
		s.Equal(l1BeaconEndpoint, c.L1BeaconEndpoint)
		s.Equal(l2Endpoint, c.L2Endpoint)
		s.Equal(l2EngineEndpoint, c.L2EngineEndpoint)
		s.Equal(pacayaInbox, c.PacayaInboxAddress.String())
		s.Equal(taikoAnchor, c.TaikoAnchorAddress.String())
		s.Equal(120*time.Second, c.P2PSyncTimeout)
		s.NotEmpty(c.JwtSecret)
		s.True(c.P2PSync)
		s.Equal(l2CheckPoint, c.L2CheckPoint)
		s.Nil(new(Driver).InitFromCli(context.Background(), ctx))

		return err
	}

	s.Nil(app.Run([]string{
		"TestNewConfigFromCliContext",
		"--" + flags.L1HTTPEndpoint.Name, l1Endpoint,
		"--" + flags.L1BeaconEndpoint.Name, l1BeaconEndpoint,
		"--" + flags.L2WSEndpoint.Name, l2Endpoint,
		"--" + flags.L2AuthEndpoint.Name, l2EngineEndpoint,
		"--" + flags.PacayaInboxAddress.Name, pacayaInbox,
		"--" + flags.ShastaInboxAddress.Name, shastaInbox,
		"--" + flags.TaikoAnchorAddress.Name, taikoAnchor,
		"--" + flags.JWTSecret.Name, os.Getenv("JWT_SECRET"),
		"--" + flags.P2PSyncTimeout.Name, "120s",
		"--" + flags.RPCTimeout.Name, "5s",
		"--" + flags.P2PSync.Name,
		"--" + flags.CheckPointSyncURL.Name, l2CheckPoint,
		"--" + p2pFlags.P2PPrivPathName, os.Getenv("JWT_SECRET"),
		"--" + p2pFlags.DiscoveryPathName, "memory",
		"--" + p2pFlags.PeerstorePathName, "memory",
		"--" + p2pFlags.SequencerP2PKeyName, os.Getenv("L1_PROPOSER_PRIVATE_KEY"),
	}))
}

func (s *DriverTestSuite) TestNewConfigFromCliContextJWTError() {
	app := s.SetupApp()
	s.ErrorContains(app.Run([]string{
		"TestNewConfigFromCliContext",
		"--" + flags.JWTSecret.Name, "wrongsecretfile.txt",
	}), "invalid JWT secret file")
}

func (s *DriverTestSuite) TestNewConfigFromCliContextEmptyL2CheckPoint() {
	app := s.SetupApp()
	s.ErrorContains(app.Run([]string{
		"TestNewConfigFromCliContext",
		"--" + flags.JWTSecret.Name, os.Getenv("JWT_SECRET"),
		"--" + flags.P2PSync.Name,
		"--" + flags.L2WSEndpoint.Name, "",
	}), "empty L2 check point URL")
}

func (s *DriverTestSuite) SetupApp() *cli.App {
	app := cli.NewApp()
	app.Flags = flags.MergeFlags([]cli.Flag{
		&cli.StringFlag{Name: flags.L1HTTPEndpoint.Name},
		&cli.StringFlag{Name: flags.L1BeaconEndpoint.Name},
		&cli.StringFlag{Name: flags.L2WSEndpoint.Name},
		&cli.StringFlag{Name: flags.L2AuthEndpoint.Name},
		&cli.StringFlag{Name: flags.PacayaInboxAddress.Name},
		&cli.StringFlag{Name: flags.ShastaInboxAddress.Name},
		&cli.StringFlag{Name: flags.TaikoAnchorAddress.Name},
		&cli.StringFlag{Name: flags.JWTSecret.Name},
		&cli.BoolFlag{Name: flags.P2PSync.Name},
		&cli.DurationFlag{Name: flags.P2PSyncTimeout.Name},
		&cli.DurationFlag{Name: flags.RPCTimeout.Name},
		&cli.StringFlag{Name: flags.CheckPointSyncURL.Name},
	}, p2pFlags.P2PFlags("PRECONFIRMATION"))
	app.Action = func(ctx *cli.Context) error {
		_, err := NewConfigFromCliContext(ctx)
		return err
	}
	return app
}

func (s *DriverTestSuite) defaultCliP2PConfigs() (*p2p.Config, p2p.SignerSetup) {
	var (
		p2pConfigCh   = make(chan *p2p.Config)
		signerSetupCh = make(chan p2p.SignerSetup)
		app           = s.SetupApp()
	)

	app.Action = func(ctx *cli.Context) error {
		c, err := NewConfigFromCliContext(ctx)
		s.Nil(err)
		s.NotNil(c.P2PConfigs)
		s.NotNil(c.P2PSignerConfigs)
		c.P2PConfigs.NoDiscovery = true
		c.P2PConfigs.NAT = false
		c.P2PConfigs.Bootnodes = []*enode.Node{}
		c.P2PConfigs.ListenIP = net.IP{127, 0, 0, 1}

		go func() {
			p2pConfigCh <- c.P2PConfigs
			signerSetupCh <- c.P2PSignerConfigs
		}()

		return nil
	}

	s.Nil(app.Run([]string{
		"GetDefaultP2PConfig",
		"--" + flags.L1HTTPEndpoint.Name, l1Endpoint,
		"--" + flags.L1BeaconEndpoint.Name, l1BeaconEndpoint,
		"--" + flags.L2WSEndpoint.Name, l2Endpoint,
		"--" + flags.L2AuthEndpoint.Name, l2EngineEndpoint,
		"--" + flags.PacayaInboxAddress.Name, pacayaInbox,
		"--" + flags.ShastaInboxAddress.Name, shastaInbox,
		"--" + flags.TaikoAnchorAddress.Name, taikoAnchor,
		"--" + flags.JWTSecret.Name, os.Getenv("JWT_SECRET"),
		"--" + flags.P2PSyncTimeout.Name, "120s",
		"--" + flags.RPCTimeout.Name, "5s",
		"--" + flags.P2PSync.Name,
		"--" + flags.CheckPointSyncURL.Name, l2CheckPoint,
		"--" + p2pFlags.P2PPrivRawName, testutils.RandomHash().Hex(),
		"--" + p2pFlags.DiscoveryPathName, "memory",
		"--" + p2pFlags.PeerstorePathName, "memory",
		"--" + p2pFlags.SequencerP2PKeyName, os.Getenv("L1_PROPOSER_PRIVATE_KEY"),
		"--" + p2pFlags.ListenTCPPortName, "0",
		"--" + p2pFlags.ListenUDPPortName, "0",
		"--" + p2pFlags.NATName, "false",
		"--" + p2pFlags.NoDiscoveryName, "true",
	}))

	return <-p2pConfigCh, <-signerSetupCh
}
