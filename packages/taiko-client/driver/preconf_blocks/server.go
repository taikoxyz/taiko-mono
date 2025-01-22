package preconfblocks

import (
	"context"
	"fmt"
	"os"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	echojwt "github.com/labstack/echo-jwt/v4"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"

	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	txListDecompressor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/txlist_decompressor"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// preconfBlockChainSyncer is an interface for preconf block chain syncer.
type preconfBlockChainSyncer interface {
	InsertPreconfBlockFromTransactionsBatch(
		ctx context.Context,
		executableData *engine.ExecutableData,
		anchorBlockID uint64,
		anchorStateRoot common.Hash,
		anchorInput [32]byte,
		signalSlots [][32]byte,
		baseFeeConfig *pacayaBindings.LibSharedDataBaseFeeConfig,
	) (*types.Header, error)
}

// @title Taiko Preconfirmation Block Server API
// @version 1.0
// @termsOfService http://swagger.io/terms/

// @contact.name API Support
// @contact.url https://community.taiko.xyz/
// @contact.email info@taiko.xyz

// @license.name MIT
// @license.url https://github.com/taikoxyz/taiko-mono/blob/main/LICENSE.md
// PreconfBlockAPIServer represents a preconfirmation block server instance.
type PreconfBlockAPIServer struct {
	echo               *echo.Echo
	chainSyncer        preconfBlockChainSyncer
	rpc                *rpc.Client
	txListDecompressor *txListDecompressor.TxListDecompressor
	checkSig           bool
}

// New creates a new preconf blcok server instance, and starts the server.
func New(
	cors string,
	jwtSecret []byte,
	chainSyncer preconfBlockChainSyncer,
	cli *rpc.Client,
	checkSig bool,
) (*PreconfBlockAPIServer, error) {
	protocolConfigs, err := cli.GetProtocolConfigs(nil)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch protocol configs: %w", err)
	}

	server := &PreconfBlockAPIServer{
		echo:        echo.New(),
		chainSyncer: chainSyncer,
		txListDecompressor: txListDecompressor.NewTxListDecompressor(
			uint64(protocolConfigs.BlockMaxGasLimit()),
			uint64(rpc.BlobBytes),
			cli.L2.ChainID,
		),
		rpc:      cli,
		checkSig: checkSig,
	}

	server.echo.HideBanner = true
	server.configureMiddleware([]string{cors})
	server.configureRoutes()
	if jwtSecret != nil {
		server.echo.Use(echojwt.JWT(jwtSecret))
	}

	return server, nil
}

// LogSkipper implements the `middleware.Skipper` interface.
func LogSkipper(c echo.Context) bool {
	switch c.Request().URL.Path {
	case "/healthz":
		return true
	default:
		return true
	}
}

// configureMiddleware configures the server middlewares.
func (s *PreconfBlockAPIServer) configureMiddleware(corsOrigins []string) {
	s.echo.Use(middleware.RequestID())

	s.echo.Use(middleware.LoggerWithConfig(middleware.LoggerConfig{
		Skipper: LogSkipper,
		Format: `{"time":"${time_rfc3339_nano}","level":"INFO","message":{"id":"${id}","remote_ip":"${remote_ip}",` +
			`"host":"${host}","method":"${method}","uri":"${uri}","user_agent":"${user_agent}",` +
			`"response_status":${status},"error":"${error}","latency":${latency},"latency_human":"${latency_human}",` +
			`"bytes_in":${bytes_in},"bytes_out":${bytes_out}}}` + "\n",
		Output: os.Stdout,
	}))

	// Add CORS middleware
	s.echo.Use(middleware.CORSWithConfig(middleware.CORSConfig{
		AllowOrigins:     corsOrigins,
		AllowCredentials: true,
	}))
}

// Start starts the HTTP server.
func (s *PreconfBlockAPIServer) Start(port uint64) error {
	return s.echo.Start(fmt.Sprintf(":%v", port))
}

// Shutdown shuts down the HTTP server.
func (s *PreconfBlockAPIServer) Shutdown(ctx context.Context) error {
	return s.echo.Shutdown(ctx)
}

// configureRoutes contains all routes which will be used by the HTTP server.
func (s *PreconfBlockAPIServer) configureRoutes() {
	s.echo.GET("/", s.HealthCheck)
	s.echo.GET("/healthz", s.HealthCheck)
	s.echo.POST("/preconfBlocks", s.BuildPreconfBlock)
}
