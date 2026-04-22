package utils

import (
	"context"
	"os"
	"os/signal"
	"syscall"

	"log/slog"

	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/metrics"
	"github.com/urfave/cli/v2"
)

type SubcommandApplication interface {
	InitFromCli(context.Context, *cli.Context) error
	Name() string
	Start() error
	Close(context.Context)
}

// interruptWaiter can be implemented by apps that run as one-shot commands
// and should return immediately after Start() succeeds.
type interruptWaiter interface {
	WaitForInterrupt() bool
}

func SubcommandAction(app SubcommandApplication) cli.ActionFunc {
	return func(c *cli.Context) error {
		ctx, ctxClose := context.WithCancel(context.Background())

		if err := app.InitFromCli(ctx, c); err != nil {
			ctxClose()
			return err
		}

		defer func() {
			ctxClose()
			app.Close(ctx)
			slog.Info("Application stopped", "name", app.Name())
		}()

		_, startMetrics := metrics.Serve(ctx, c)

		go func() {
			if err := startMetrics(); err != nil {
				slog.Error("Starting metrics server error", "error", err)
			}
		}()

		slog.Info("Starting Taiko relayer application", "name", app.Name())

		if err := app.Start(); err != nil {
			slog.Error("Starting application error", "name", app.Name(), "error", err)
			return err
		}

		if waiter, ok := app.(interruptWaiter); ok && !waiter.WaitForInterrupt() {
			return nil
		}

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
