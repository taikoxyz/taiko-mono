package server

import (
	"context"
	"net/http"
	"os"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	builder "github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer/transaction_builder"
)

// @title Taiko Proposer Server API
// @version 1.0
// @termsOfService http://swagger.io/terms/

// @contact.name API Support
// @contact.url https://community.taiko.xyz/
// @contact.email info@taiko.xyz

// @license.name MIT
// @license.url https://github.com/taikoxyz/taiko-mono/blob/main/LICENSE.md
// ProposerServer represents a proposer server instance.
type ProposerServer struct {
	echo      *echo.Echo
	rpc       *rpc.Client
	txBuilder builder.ProposeBlockTransactionBuilder
}

// NewProposerServerOpts contains all configurations for creating a prover server instance.
type NewProposerServerOpts struct {
	RPC       *rpc.Client
	TxBuilder builder.ProposeBlockTransactionBuilder
}

// New creates a new prover server instance.
func New(opts *NewProposerServerOpts) (*ProposerServer, error) {
	srv := &ProposerServer{
		echo:      echo.New(),
		rpc:       opts.RPC,
		txBuilder: opts.TxBuilder,
	}

	srv.echo.HideBanner = true
	srv.configureMiddleware()
	srv.configureRoutes()

	return srv, nil
}

// Start starts the HTTP server.
func (s *ProposerServer) Start(address string) error {
	return s.echo.Start(address)
}

// Shutdown shuts down the HTTP server.
func (s *ProposerServer) Shutdown(ctx context.Context) error {
	return s.echo.Shutdown(ctx)
}

// Health endpoints for probes.
func (s *ProposerServer) Health(c echo.Context) error {
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
func (s *ProposerServer) configureMiddleware() {
	s.echo.Use(middleware.RequestID())

	s.echo.Use(middleware.LoggerWithConfig(middleware.LoggerConfig{
		Skipper: LogSkipper,
		Format: `{"time":"${time_rfc3339_nano}","level":"INFO","message":{"id":"${id}","remote_ip":"${remote_ip}",` +
			`"host":"${host}","method":"${method}","uri":"${uri}","user_agent":"${user_agent}",` +
			`"response_status":${status},"error":"${error}","latency":${latency},"latency_human":"${latency_human}",` +
			`"bytes_in":${bytes_in},"bytes_out":${bytes_out}}}` + "\n",
		Output: os.Stdout,
	}))
}

// configureRoutes contains all routes which will be used by prover server.
func (s *ProposerServer) configureRoutes() {
	s.echo.GET("/", s.Health)
	s.echo.GET("/healthz", s.Health)
	s.echo.GET("/status", s.GetStatus)
	s.echo.GET("/block/build", s.BuildBlock)
}
