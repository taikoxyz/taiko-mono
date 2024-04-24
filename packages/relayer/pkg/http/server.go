package http

import (
	"context"
	"math/big"
	"net/http"
	"os"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/labstack/echo/v4/middleware"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/taikol2"

	echo "github.com/labstack/echo/v4"
)

type ethClient interface {
	BlockNumber(ctx context.Context) (uint64, error)
	ChainID(ctx context.Context) (*big.Int, error)
	SuggestGasTipCap(ctx context.Context) (*big.Int, error)
	BlockByNumber(ctx context.Context, number *big.Int) (*types.Block, error)
}

// @title Taiko Relayer API
// @version 1.0
// @termsOfService http://swagger.io/terms/

// @contact.name API Support
// @contact.url https://community.taiko.xyz/
// @contact.email info@taiko.xyz

// @license.name MIT

// @host relayer.katla.taiko.xyz
// Server represents an relayer http server instance.
type Server struct {
	echo                    *echo.Echo
	eventRepo               relayer.EventRepository
	srcEthClient            ethClient
	destEthClient           ethClient
	processingFeeMultiplier float64
	taikoL2                 *taikol2.TaikoL2
}

type NewServerOpts struct {
	Echo                    *echo.Echo
	EventRepo               relayer.EventRepository
	CorsOrigins             []string
	SrcEthClient            ethClient
	DestEthClient           ethClient
	ProcessingFeeMultiplier float64
	TaikoL2                 *taikol2.TaikoL2
}

func (opts NewServerOpts) Validate() error {
	if opts.Echo == nil {
		return ErrNoHTTPFramework
	}

	if opts.EventRepo == nil {
		return relayer.ErrNoEventRepository
	}

	if opts.CorsOrigins == nil {
		return relayer.ErrNoCORSOrigins
	}

	if opts.SrcEthClient == nil {
		return relayer.ErrNoEthClient
	}

	if opts.DestEthClient == nil {
		return relayer.ErrNoEthClient
	}

	return nil
}

func NewServer(opts NewServerOpts) (*Server, error) {
	if err := opts.Validate(); err != nil {
		return nil, err
	}

	srv := &Server{
		echo:                    opts.Echo,
		eventRepo:               opts.EventRepo,
		srcEthClient:            opts.SrcEthClient,
		destEthClient:           opts.DestEthClient,
		processingFeeMultiplier: opts.ProcessingFeeMultiplier,
		taikoL2:                 opts.TaikoL2,
	}

	corsOrigins := opts.CorsOrigins
	if corsOrigins == nil {
		corsOrigins = []string{"*"}
	}

	srv.configureMiddleware(corsOrigins)
	srv.configureRoutes()

	return srv, nil
}

// Start starts the HTTP server
func (srv *Server) Start(address string) error {
	return srv.echo.Start(address)
}

// Shutdown shuts down the HTTP server
func (srv *Server) Shutdown(ctx context.Context) error {
	return srv.echo.Shutdown(ctx)
}

// ServeHTTP implements the `http.Handler` interface which serves HTTP requests
func (srv *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	srv.echo.ServeHTTP(w, r)
}

// Health endpoints for probes
func (srv *Server) Health(c echo.Context) error {
	return c.NoContent(http.StatusOK)
}

func LogSkipper(c echo.Context) bool {
	switch c.Request().URL.Path {
	case "/healthz":
		return true
	case "/metrics":
		return true
	default:
		return true
	}
}

func (srv *Server) configureMiddleware(corsOrigins []string) {
	srv.echo.Use(middleware.RequestID())

	srv.echo.Use(middleware.LoggerWithConfig(middleware.LoggerConfig{
		Skipper: LogSkipper,
		Format: `{"time":"${time_rfc3339_nano}","level":"INFO","message":{"id":"${id}","remote_ip":"${remote_ip}",` + //nolint:lll
			`"host":"${host}","method":"${method}","uri":"${uri}","user_agent":"${user_agent}",` + //nolint:lll
			`"response_status":${status},"error":"${error}","latency":${latency},"latency_human":"${latency_human}",` +
			`"bytes_in":${bytes_in},"bytes_out":${bytes_out}}}` + "\n",
		Output: os.Stdout,
	}))

	srv.echo.Use(middleware.CORSWithConfig(middleware.CORSConfig{
		AllowOrigins: corsOrigins,
		AllowHeaders: []string{echo.HeaderOrigin, echo.HeaderContentType, echo.HeaderAccept},
		AllowMethods: []string{http.MethodGet, http.MethodHead},
	}))
}
