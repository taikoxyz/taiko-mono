package driver

import (
	"context"
	"os"
	"time"

	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
)

var (
	l1Endpoint       = os.Getenv("L1_WS")
	l1BeaconEndpoint = os.Getenv("L1_HTTP")
	l2Endpoint       = os.Getenv("L2_WS")
	l2CheckPoint     = os.Getenv("L2_HTTP")
	l2EngineEndpoint = os.Getenv("L2_AUTH")
	taikoL1          = os.Getenv("TAIKO_L1")
	taikoL2          = os.Getenv("TAIKO_L2")
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
		s.Equal(taikoL1, c.TaikoL1Address.String())
		s.Equal(taikoL2, c.TaikoL2Address.String())
		s.Equal(120*time.Second, c.P2PSyncTimeout)
		s.NotEmpty(c.JwtSecret)
		s.True(c.P2PSync)
		s.Equal(l2CheckPoint, c.L2CheckPoint)
		s.Nil(new(Driver).InitFromCli(context.Background(), ctx))

		return err
	}

	s.Nil(app.Run([]string{
		"TestNewConfigFromCliContext",
		"--" + flags.L1WSEndpoint.Name, l1Endpoint,
		"--" + flags.L1BeaconEndpoint.Name, l1BeaconEndpoint,
		"--" + flags.L2WSEndpoint.Name, l2Endpoint,
		"--" + flags.L2AuthEndpoint.Name, l2EngineEndpoint,
		"--" + flags.TaikoL1Address.Name, taikoL1,
		"--" + flags.TaikoL2Address.Name, taikoL2,
		"--" + flags.JWTSecret.Name, os.Getenv("JWT_SECRET"),
		"--" + flags.P2PSyncTimeout.Name, "120s",
		"--" + flags.RPCTimeout.Name, "5s",
		"--" + flags.P2PSync.Name,
		"--" + flags.CheckPointSyncURL.Name, l2CheckPoint,
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
	app.Flags = []cli.Flag{
		&cli.StringFlag{Name: flags.L1WSEndpoint.Name},
		&cli.StringFlag{Name: flags.L1BeaconEndpoint.Name},
		&cli.StringFlag{Name: flags.L2WSEndpoint.Name},
		&cli.StringFlag{Name: flags.L2AuthEndpoint.Name},
		&cli.StringFlag{Name: flags.TaikoL1Address.Name},
		&cli.StringFlag{Name: flags.TaikoL2Address.Name},
		&cli.StringFlag{Name: flags.JWTSecret.Name},
		&cli.BoolFlag{Name: flags.P2PSync.Name},
		&cli.DurationFlag{Name: flags.P2PSyncTimeout.Name},
		&cli.DurationFlag{Name: flags.RPCTimeout.Name},
		&cli.StringFlag{Name: flags.CheckPointSyncURL.Name},
	}
	app.Action = func(ctx *cli.Context) error {
		_, err := NewConfigFromCliContext(ctx)
		return err
	}
	return app
}
