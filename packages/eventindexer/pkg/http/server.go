package http

import (
	"context"
	"net/http"
	"os"
	"time"

	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/labstack/echo/v4/middleware"
	"github.com/patrickmn/go-cache"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"

	echo "github.com/labstack/echo/v4"
)

// @title Taiko Eventindexer API
// @version 1.0
// @termsOfService http://swagger.io/terms/

// @contact.name API Support
// @contact.url https://community.taiko.xyz/
// @contact.email info@taiko.xyz

// @license.name MIT

// @host eventindexer.katla.taiko.xyz
// Server represents an eventindexer http server instance.
type Server struct {
	echo           *echo.Echo
	eventRepo      eventindexer.EventRepository
	statRepo       eventindexer.StatRepository
	nftBalanceRepo eventindexer.NFTBalanceRepository
	chartRepo      eventindexer.ChartRepository
	cache          *cache.Cache
}

type NewServerOpts struct {
	Echo           *echo.Echo
	EventRepo      eventindexer.EventRepository
	StatRepo       eventindexer.StatRepository
	NFTBalanceRepo eventindexer.NFTBalanceRepository
	ChartRepo      eventindexer.ChartRepository
	EthClient      *ethclient.Client
	CorsOrigins    []string
}

func (opts NewServerOpts) Validate() error {
	if opts.Echo == nil {
		return ErrNoHTTPFramework
	}

	if opts.EventRepo == nil {
		return eventindexer.ErrNoEventRepository
	}

	if opts.StatRepo == nil {
		return eventindexer.ErrNoStatRepository
	}

	if opts.CorsOrigins == nil {
		return eventindexer.ErrNoCORSOrigins
	}

	if opts.NFTBalanceRepo == nil {
		return eventindexer.ErrNoNFTBalanceRepository
	}

	return nil
}

func NewServer(opts NewServerOpts) (*Server, error) {
	if err := opts.Validate(); err != nil {
		return nil, err
	}

	cache := cache.New(5*time.Minute, 10*time.Minute)

	srv := &Server{
		echo:           opts.Echo,
		eventRepo:      opts.EventRepo,
		statRepo:       opts.StatRepo,
		nftBalanceRepo: opts.NFTBalanceRepo,
		chartRepo:      opts.ChartRepo,
		cache:          cache,
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
		return false
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
