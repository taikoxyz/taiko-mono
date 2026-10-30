package utils

import (
	"context"
	"errors"
	"flag"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	"github.com/urfave/cli/v2"
)

type fatalApplication struct {
	ctx    context.Context
	fatal  chan error
	closed chan error
}

func (a *fatalApplication) InitFromCli(ctx context.Context, _ *cli.Context) error {
	a.ctx = ctx
	return nil
}
func (a *fatalApplication) Name() string              { return "fatal-test" }
func (a *fatalApplication) Start() error              { return nil }
func (a *fatalApplication) Close(ctx context.Context) { a.closed <- ctx.Err() }
func (a *fatalApplication) FatalErrors() <-chan error { return a.fatal }

func TestSubcommandActionReturnsFatalError(t *testing.T) {
	want := errors.New("writer ownership lost")
	app := &fatalApplication{fatal: make(chan error, 1), closed: make(chan error, 1)}
	app.fatal <- want

	cliCtx := cli.NewContext(cli.NewApp(), flag.NewFlagSet("test", flag.ContinueOnError), nil)
	result := make(chan error, 1)

	go func() { result <- SubcommandAction(app)(cliCtx) }()

	select {
	case err := <-result:
		require.ErrorIs(t, err, want)
	case <-time.After(2 * time.Second):
		t.Fatal("action did not exit after fatal application error")
	}

	select {
	case err := <-app.closed:
		require.ErrorIs(t, err, context.Canceled)
	default:
		t.Fatal("action did not close the application")
	}
	require.ErrorIs(t, app.ctx.Err(), context.Canceled)
}
