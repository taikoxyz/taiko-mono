package utils

import (
	"context"
	"os"
	"os/signal"
	"syscall"
	"time"

	"log/slog"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/metrics"
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
		defer ctxClose()

		if err := app.InitFromCli(ctx, c); err != nil {
			return err
		}

		slog.Info("Starting Taiko relayer application", "name", app.Name())

		if err := app.Start(); err != nil {
			slog.Error("Starting application error", "name", app.Name(), "error", err)
			return err
		}

		echoServer, startMetrics := metrics.Serve(ctx, c)

		metricsErrCh := make(chan error, 1)
		go func() {
			if err := startMetrics(); err != nil {
				slog.Error("Starting metrics server error", "error", err)
				metricsErrCh <- err
			} else {
				metricsErrCh <- nil
			}
		}()
		// Check for metrics server start error
		if err := <-metricsErrCh; err != nil {
			return err
		}

		// Set up signal handling
		quitCh := make(chan os.Signal, 1)
		signal.Notify(quitCh, os.Interrupt, syscall.SIGTERM, syscall.SIGQUIT)

		go func() {
			<-quitCh
			slog.Info("Interrupt signal received")
			ctxClose()

			// Create a new context with a timeout to use for shutdown
			shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()

			// Shut down the Echo server gracefully
			if err := echoServer.Shutdown(shutdownCtx); err != nil {
				slog.Error("Failed to shut down Echo server", "error", err)
			}
		}()

		// Block until context is done
		<-ctx.Done()
		slog.Info("Waiting for application to stop", "name", app.Name())
		app.Close(context.Background())
		slog.Info("Application stopped", "name", app.Name())
		return nil
	}
}
