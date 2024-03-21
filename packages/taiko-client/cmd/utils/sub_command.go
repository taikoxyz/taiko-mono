package utils

import (
	"context"
	"os"
	"os/signal"
	"syscall"

	"github.com/ethereum/go-ethereum/log"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-client/cmd/logger"
	"github.com/taikoxyz/taiko-client/internal/metrics"
)

type SubcommandApplication interface {
	InitFromCli(context.Context, *cli.Context) error
	Name() string
	Start() error
	Close(context.Context)
}

func SubcommandAction(app SubcommandApplication) cli.ActionFunc {
	return func(c *cli.Context) error {
		logger.InitLogger(c)

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

		if err := metrics.Serve(ctx, c); err != nil {
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
