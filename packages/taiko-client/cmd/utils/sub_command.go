package utils

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/log"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/cmd/logger"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
)

// SubcommandApplication defines the lifecycle hooks shared by Taiko client
// subcommands such as the driver, proposer, and prover.
type SubcommandApplication interface {
	// InitFromCli initializes the application from CLI flags before startup.
	InitFromCli(context.Context, *cli.Context) error
	// Name returns the application name used in logs and lifecycle messages.
	Name() string
	// Start starts the application services and returns once startup succeeds or fails.
	Start() error
	// Close releases application resources during shutdown.
	Close(context.Context)
}

// SubcommandAction wraps a SubcommandApplication as a urfave/cli action with
// logger setup, devnet overrides, metrics serving, and signal-based shutdown.
func SubcommandAction(app SubcommandApplication) cli.ActionFunc {
	return func(c *cli.Context) error {
		logger.InitLogger(c)

		if err := applyDevnetForkTimeOverrides(c); err != nil {
			return err
		}

		ctx, ctxClose := context.WithCancel(context.Background())
		defer ctxClose()

		if err := app.InitFromCli(ctx, c); err != nil {
			return err
		}

		log.Info("Starting Taiko client application", "name", app.Name())

		if err := app.Start(); err != nil {
			log.Error("Starting application error", "name", app.Name(), "error", err)
			return err
		}

		if err := metrics.Serve(
			ctx,
			c.Bool(flags.MetricsEnabled.Name),
			c.String(flags.MetricsAddr.Name),
			c.Int(flags.MetricsPort.Name),
		); err != nil {
			log.Error("Starting metrics server error", "error", err)
			return err
		}

		defer func() {
			ctxClose()
			app.Close(ctx)
			log.Info("Application stopped", "name", app.Name())
		}()

		quitCh := make(chan os.Signal, 1)
		signal.Notify(quitCh, []os.Signal{
			os.Interrupt,
			os.Kill,
			syscall.SIGTERM,
			syscall.SIGQUIT,
		}...)
		<-quitCh

		return nil
	}
}

// applyDevnetForkTimeOverrides mutates the embedded taiko-geth's core.DevnetUnzenTime and
// core.DevnetEtnaTime package variables from the CLI flags, with the same semantics as taiko-geth's
// --taiko.devnet-unzen-time and --taiko.devnet-etna-time. It must run before any chain-config or
// genesis lookup so downstream consumers observe the overridden activation timestamps. Unzen is only
// overridden when its flag is set; Etna takes its own flag when set and otherwise follows an
// explicitly set Unzen time; Etna may never activate before Unzen.
func applyDevnetForkTimeOverrides(c *cli.Context) error {
	if c.IsSet(flags.TaikoDevnetUnzenTime.Name) {
		core.DevnetUnzenTime = c.Uint64(flags.TaikoDevnetUnzenTime.Name)
		log.Info("Overriding devnet Unzen activation time", "timestamp", core.DevnetUnzenTime)
	}

	switch {
	case c.IsSet(flags.TaikoDevnetEtnaTime.Name):
		core.DevnetEtnaTime = c.Uint64(flags.TaikoDevnetEtnaTime.Name)
		log.Info("Overriding devnet Etna activation time", "timestamp", core.DevnetEtnaTime)
	case c.IsSet(flags.TaikoDevnetUnzenTime.Name):
		core.DevnetEtnaTime = core.DevnetUnzenTime
		log.Info("Devnet Etna activation time follows Unzen", "timestamp", core.DevnetEtnaTime)
	}

	if core.DevnetEtnaTime < core.DevnetUnzenTime {
		return fmt.Errorf(
			"--%s (%d) must not be earlier than --%s (%d)",
			flags.TaikoDevnetEtnaTime.Name, core.DevnetEtnaTime,
			flags.TaikoDevnetUnzenTime.Name, core.DevnetUnzenTime,
		)
	}

	return nil
}
