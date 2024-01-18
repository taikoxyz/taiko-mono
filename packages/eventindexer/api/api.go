package api

import (
	"context"
	"fmt"
	"log/slog"

	nethttp "net/http"

	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/labstack/echo/v4"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/http"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/repo"
	"github.com/urfave/cli/v2"
)

type API struct {
	httpPort uint64
	srv      *http.Server

	ctx context.Context
}

func (api *API) Start() error {
	api.ctx = context.Background()
	go func() {
		if err := api.srv.Start(fmt.Sprintf(":%v", api.httpPort)); err != nethttp.ErrServerClosed {
			slog.Error("http srv start", "error", err.Error())
		}
	}()

	return nil
}

func (api *API) Name() string {
	return "api"
}

func (api *API) InitFromCli(ctx context.Context, c *cli.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return InitFromConfig(ctx, api, cfg)
}

// nolint: funlen
func InitFromConfig(ctx context.Context, api *API, cfg *Config) error {
	db, err := cfg.OpenDBFunc()
	if err != nil {
		return err
	}

	eventRepository, err := repo.NewEventRepository(db)
	if err != nil {
		return err
	}

	chartRepository, err := repo.NewChartRepository(db)
	if err != nil {
		return err
	}

	statRepository, err := repo.NewStatRepository(db)
	if err != nil {
		return err
	}

	nftBalanceRepository, err := repo.NewNFTBalanceRepository(db)
	if err != nil {
		return err
	}

	ethClient, err := ethclient.Dial(cfg.RPCUrl)
	if err != nil {
		return err
	}

	srv, err := http.NewServer(http.NewServerOpts{
		EventRepo:      eventRepository,
		StatRepo:       statRepository,
		NFTBalanceRepo: nftBalanceRepository,
		ChartRepo:      chartRepository,
		Echo:           echo.New(),
		CorsOrigins:    cfg.CORSOrigins,
		EthClient:      ethClient,
	})
	if err != nil {
		return err
	}

	api.srv = srv
	api.httpPort = cfg.HTTPPort

	return nil
}

func (api *API) Close(ctx context.Context) {
	if err := api.srv.Shutdown(ctx); err != nil {
		slog.Error("srv shutdown", "error", err)
	}
}
