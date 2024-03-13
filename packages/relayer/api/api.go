package api

import (
	"context"
	"database/sql"
	"fmt"
	"log/slog"
	nethttp "net/http"

	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/labstack/echo/v4"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/http"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/repo"
	"github.com/urfave/cli/v2"
	"gorm.io/gorm"
)

type DB interface {
	DB() (*sql.DB, error)
	GormDB() *gorm.DB
}

type API struct {
	srv      *http.Server
	httpPort uint64
}

func (api *API) InitFromCli(ctx context.Context, c *cli.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return InitFromConfig(ctx, api, cfg)
}

func InitFromConfig(ctx context.Context, api *API, cfg *Config) (err error) {
	db, err := cfg.OpenDBFunc()
	if err != nil {
		return err
	}

	eventRepository, err := repo.NewEventRepository(db)
	if err != nil {
		return err
	}

	srcEthClient, err := ethclient.Dial(cfg.SrcRPCUrl)
	if err != nil {
		return err
	}

	destEthClient, err := ethclient.Dial(cfg.DestRPCUrl)
	if err != nil {
		return err
	}

	srv, err := http.NewServer(http.NewServerOpts{
		EventRepo:     eventRepository,
		Echo:          echo.New(),
		CorsOrigins:   cfg.CORSOrigins,
		SrcEthClient:  srcEthClient,
		DestEthClient: destEthClient,
	})
	if err != nil {
		return err
	}

	api.srv = srv
	api.httpPort = cfg.HTTPPort

	return nil
}

func (api *API) Name() string {
	return "api"
}

func (api *API) Close(ctx context.Context) {
	if err := api.srv.Shutdown(ctx); err != nil {
		slog.Error("srv shutdown", "error", err)
	}
}

// nolint: funlen
func (api *API) Start() error {
	go func() {
		if err := api.srv.Start(fmt.Sprintf(":%v", api.httpPort)); err != nethttp.ErrServerClosed {
			slog.Error("http srv start", "error", err.Error())
		}
	}()

	return nil
}
