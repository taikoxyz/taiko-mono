package utils

import (
	"context"
	"os"
	"os/signal"
	"syscall"

	"log/slog"

	"github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check/metrics"
	"github.com/urfave/cli/v2"
)

type SubcommandApplication interface {
	InitFromCli(context.Context, *cli.Context) error
	Name() string
	Start() error
	Close(context.Context)
}

func SubcommandAction(app SubcommandApplication) cli.ActionFunc {
	return func(c *cli.Context) error {
		ctx, ctxClose := context.WithCancel(context.Background())
		defer func() { ctxClose() }()

		if err := app.InitFromCli(ctx, c); err != nil {
			return err
		}

		_, startMetrics := metrics.Serve(ctx, c)

		go func() {
			if err := startMetrics(); err != nil {
				slog.Error("Starting metrics server error", "error", err)
			}
		}()

		slog.Info("Starting Taiko balance monitor application", "name", app.Name())

		if err := app.Start(); err != nil {
			slog.Error("Starting application error", "name", app.Name(), "error", err)
			return err
		}

		defer func() {
			ctxClose()
			app.Close(ctx)
			slog.Info("Application stopped", "name", app.Name())
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
