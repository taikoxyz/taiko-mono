package api

import (
	"context"
	"fmt"

	nethttp "net/http"

	"github.com/labstack/echo/v4"
	"github.com/taikoxyz/taiko-mono/packages/blobstorage/pkg/http"
	"github.com/taikoxyz/taiko-mono/packages/blobstorage/pkg/repo"
	"github.com/urfave/cli/v2"
	"golang.org/x/exp/slog"
)

type API struct {
	srv  *http.Server
	port int
}

func (a *API) InitFromCli(ctx context.Context, c *cli.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return InitFromConfig(ctx, a, cfg)
}

// InitFromConfig inits a new Server from a provided Config struct
func InitFromConfig(ctx context.Context, a *API, cfg *Config) (err error) {
	db, err := cfg.OpenDBFunc()
	if err != nil {
		return err
	}

	blobHashRepo, err := repo.NewBlobHashRepository(db)
	if err != nil {
		return err
	}

	srv, err := http.NewServer(http.NewServerOpts{
		BlobHashRepo: blobHashRepo,
		Echo:         echo.New(),
	})
	if err != nil {
		return err
	}

	a.srv = srv

	a.port = int(cfg.Port)

	return nil
}

func (a *API) Start() error {
	go func() {
		if err := a.srv.Start(fmt.Sprintf(":%v", a.port)); err != nil && err != nethttp.ErrServerClosed {
			slog.Error("error starting server", "error", err)
		}
	}()

	return nil
}

func (a *API) Close(ctx context.Context) {
}

func (a *API) Name() string {
	return "server"
}
