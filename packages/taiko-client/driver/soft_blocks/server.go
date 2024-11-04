package softblocks

import (
	"context"
	"fmt"
	"os"

	"github.com/ethereum/go-ethereum/core/types"
	echojwt "github.com/labstack/echo-jwt/v4"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"

	txListDecompressor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/txlist_decompressor"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// softBlockChainSyncer is an interface for soft block chain syncer.
type softBlockChainSyncer interface {
	InsertSoftBlockFromTransactionsBatch(
		ctx context.Context,
		blockID uint64,
		batchID uint64,
		txListBytes []byte,
		batchMarker TransactionBatchMarker,
		softBlockParams *SoftBlockParams,
	) (*types.Header, error)
	RemoveSoftBlocks(ctx context.Context, newLastBlockId uint64) error
}

// @title Taiko Soft Block Server API
// @version 1.0
// @termsOfService http://swagger.io/terms/

// @contact.name API Support
// @contact.url https://community.taiko.xyz/
// @contact.email info@taiko.xyz

// @license.name MIT
// @license.url https://github.com/taikoxyz/taiko-mono/blob/main/LICENSE.md
// SoftBlockAPIServer represents a soft blcok server instance.
type SoftBlockAPIServer struct {
	echo               *echo.Echo
	chainSyncer        softBlockChainSyncer
	rpc                *rpc.Client
	txListDecompressor *txListDecompressor.TxListDecompressor
	checkSig           bool
}

// New creates a new soft blcok server instance, and starts the server.
func New(
	cors string,
	jwtSecret []byte,
	chainSyncer softBlockChainSyncer,
	cli *rpc.Client,
	checkSig bool,
) (*SoftBlockAPIServer, error) {
	protocolConfigs, err := rpc.GetProtocolConfigs(cli.TaikoL1, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch protocol configs: %w", err)
	}

	server := &SoftBlockAPIServer{
		echo:        echo.New(),
		chainSyncer: chainSyncer,
		txListDecompressor: txListDecompressor.NewTxListDecompressor(
			uint64(protocolConfigs.BlockMaxGasLimit),
			rpc.BlockMaxTxListBytes,
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
func (s *SoftBlockAPIServer) configureMiddleware(corsOrigins []string) {
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
func (s *SoftBlockAPIServer) Start(port uint64) error {
	return s.echo.Start(fmt.Sprintf(":%v", port))
}

// Shutdown shuts down the HTTP server.
func (s *SoftBlockAPIServer) Shutdown(ctx context.Context) error {
	return s.echo.Shutdown(ctx)
}

// configureRoutes contains all routes which will be used by prover server.
func (s *SoftBlockAPIServer) configureRoutes() {
	s.echo.GET("/", s.HealthCheck)
	s.echo.GET("/healthz", s.HealthCheck)
	s.echo.POST("/softBlocks", s.BuildSoftBlock)
	s.echo.DELETE("/softBlocks", s.RemoveSoftBlocks)
}
