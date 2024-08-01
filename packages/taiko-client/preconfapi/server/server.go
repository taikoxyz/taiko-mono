package server

import (
	"context"
	"net/http"
	"os"

	badger "github.com/dgraph-io/badger/v4"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/preconfapi/builder"
)

// @title Taiko Proposer Server API
// @version 1.0
// @termsOfService http://swagger.io/terms/

// @contact.name API Support
// @contact.url https://community.taiko.xyz/
// @contact.email info@taiko.xyz

// @license.name MIT
// @license.url https://github.com/taikoxyz/taiko-mono/blob/main/LICENSE.md
// PreconfAPIServer represents a proposer server instance.
type PreconfAPIServer struct {
	db         *badger.DB
	echo       *echo.Echo
	txBuilders map[string]builder.TxBuilder // calldata or blob map to txbuilder type
}

// NewPreconfAPIServerOpts contains all configurations for creating a prover server instance.
type NewPreconfAPIServerOpts struct {
	TxBuilders  map[string]builder.TxBuilder
	DB          *badger.DB
	CORSOrigins []string
}

// New creates a new prover server instance.
func New(opts *NewPreconfAPIServerOpts) (*PreconfAPIServer, error) {
	srv := &PreconfAPIServer{
		echo:       echo.New(),
		txBuilders: opts.TxBuilders,
		db:         opts.DB,
	}

	srv.echo.HideBanner = true
	srv.configureMiddleware(opts.CORSOrigins)
	srv.configureRoutes()

	return srv, nil
}

// Start starts the HTTP server.
func (s *PreconfAPIServer) Start(address string) error {
	return s.echo.Start(address)
}

// Shutdown shuts down the HTTP server.
func (s *PreconfAPIServer) Shutdown(ctx context.Context) error {
	return s.echo.Shutdown(ctx)
}

// Health endpoints for probes.
func (s *PreconfAPIServer) Health(c echo.Context) error {
	return c.NoContent(http.StatusOK)
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
func (s *PreconfAPIServer) configureMiddleware(corsOrigins []string) {
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
		AllowMethods:     []string{echo.GET, echo.HEAD, echo.PUT, echo.PATCH, echo.POST, echo.DELETE},
		AllowHeaders:     []string{echo.HeaderOrigin, echo.HeaderContentType, echo.HeaderAccept},
	}))
}

// configureRoutes contains all routes which will be used by prover server.
func (s *PreconfAPIServer) configureRoutes() {
	s.echo.GET("/", s.Health)
	s.echo.GET("/healthz", s.Health)
	s.echo.POST("/blocks/build", s.BuildBlocks)
	s.echo.POST("/block/build", s.BuildBlock)
	s.echo.GET("/tx/:hash", s.GetTransactionByHash)
}
