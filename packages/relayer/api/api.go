package api

import (
	"context"
	"fmt"
	"log/slog"
	nethttp "net/http"
	"sync"
	"time"

	"github.com/cenkalti/backoff"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/labstack/echo/v4"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/taikol2"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/http"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/repo"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/utils"
	"github.com/urfave/cli/v2"
)

type API struct {
	srv          *http.Server
	httpPort     uint64
	ctx          context.Context
	cancel       context.CancelFunc // cancels background routines started by API
	wg           sync.WaitGroup
	srcEthClient *ethclient.Client
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

	ctxDial, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

	srcEthClient, err := ethclient.DialContext(ctxDial, cfg.SrcRPCUrl)
	if err != nil {
		return err
	}

	destEthClient, err := ethclient.DialContext(ctxDial, cfg.DestRPCUrl)
	if err != nil {
		return err
	}

	taikoL2, err := taikol2.NewTaikoL2(cfg.DestTaikoAddress, destEthClient)
	if err != nil {
		return err
	}

	srv, err := http.NewServer(http.NewServerOpts{
		EventRepo:               eventRepository,
		Echo:                    echo.New(),
		CorsOrigins:             cfg.CORSOrigins,
		SrcEthClient:            srcEthClient,
		DestEthClient:           destEthClient,
		TaikoL2:                 taikoL2,
		ProcessingFeeMultiplier: cfg.ProcessingFeeMultiplier,
	})
	if err != nil {
		return err
	}

	api.srv = srv
	api.httpPort = cfg.HTTPPort
	api.ctx, api.cancel = context.WithCancel(ctx) // create cancelable context for API background tasks
	api.srcEthClient = srcEthClient

	return nil
}

func (api *API) Name() string {
	return "api"
}

func (api *API) Close(ctx context.Context) {
	// Ensure background goroutines are signaled to stop
	if api.cancel != nil {
		api.cancel()
	}

	if err := api.srv.Shutdown(ctx); err != nil {
		slog.Error("srv shutdown", "error", err)
	}

	api.wg.Wait()
}

// nolint: funlen
func (api *API) Start() error {
	go func() {
		if err := api.srv.Start(fmt.Sprintf(":%v", api.httpPort)); err != nethttp.ErrServerClosed {
			slog.Error("http srv start", "error", err.Error())
		}
	}()

	go func() {
		// Stop retrying when api.ctx is canceled to avoid infinite retries on shutdown
		bo := backoff.WithContext(backoff.NewConstantBackOff(5*time.Second), api.ctx)
		if err := backoff.Retry(func() error {
			return utils.ScanBlocks(api.ctx, api.srcEthClient, &api.wg)
		}, bo); err != nil {
			slog.Error("scan blocks backoff retry", "error", err)
		}
	}()

	return nil
}
