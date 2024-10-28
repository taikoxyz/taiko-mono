package softblocks

import (
	"os"

	echojwt "github.com/labstack/echo-jwt/v4"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	chainSyncer "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer"
	txListDecompressor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/txlist_decompressor"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

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
	chainSyncer        *chainSyncer.L2ChainSyncer
	rpc                *rpc.Client
	txListDecompressor *txListDecompressor.TxListDecompressor
}

// New creates a new soft blcok server instance.
func New(chainSyncer *chainSyncer.L2ChainSyncer, cli *rpc.Client) (*SoftBlockAPIServer, error) {
	server := &SoftBlockAPIServer{
		echo:        echo.New(),
		chainSyncer: chainSyncer,
		txListDecompressor: txListDecompressor.NewTxListDecompressor(
			uint64(encoding.GetProtocolConfig(cli.L2.ChainID.Uint64()).BlockMaxGasLimit),
			rpc.BlockMaxTxListBytes,
			cli.L2.ChainID,
		),
	}

	server.echo.HideBanner = true
	server.configureMiddleware([]string{"*"}) // TODO: add flags
	server.configureRoutes()
	server.echo.Use(echojwt.JWT([]byte("secret"))) // TODO: add flags

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

// configureRoutes contains all routes which will be used by prover server.
func (s *SoftBlockAPIServer) configureRoutes() {
	s.echo.GET("/", s.HealthCheck)
	s.echo.GET("/healthz", s.HealthCheck)
	s.echo.POST("/softBlocks", s.BuildSoftBlock)
	s.echo.DELETE("/softBlocks", s.RemoveSoftBlocks)
}
