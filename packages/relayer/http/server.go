package http

import (
	"context"
	"fmt"
	"net/http"
	"os"

	"github.com/labstack/echo/v4/middleware"
	"github.com/taikoxyz/taiko-mono/packages/relayer"

	echoprom "github.com/labstack/echo-contrib/prometheus"
	echo "github.com/labstack/echo/v4"
)

type Server struct {
	echo        *echo.Echo
	eventRepo   relayer.EventRepository
	blockRepo   relayer.BlockRepository
	l1EthClient relayer.EthClient
	l2EthClient relayer.EthClient
}

type NewServerOpts struct {
	Echo        *echo.Echo
	EventRepo   relayer.EventRepository
	BlockRepo   relayer.BlockRepository
	CorsOrigins []string
	L1EthClient relayer.EthClient
	L2EthClient relayer.EthClient
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

	if opts.L1EthClient == nil {
		return relayer.ErrNoEthClient
	}

	if opts.L2EthClient == nil {
		return relayer.ErrNoEthClient
	}

	if opts.BlockRepo == nil {
		return relayer.ErrNoBlockRepository
	}

	return nil
}

func NewServer(opts NewServerOpts) (*Server, error) {
	if err := opts.Validate(); err != nil {
		return nil, err
	}

	srv := &Server{
		blockRepo:   opts.BlockRepo,
		echo:        opts.Echo,
		eventRepo:   opts.EventRepo,
		l1EthClient: opts.L1EthClient,
		l2EthClient: opts.L2EthClient,
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

	srv.configureAndStartPrometheus()
}

func (srv *Server) configureAndStartPrometheus() {
	// Enable metrics middleware
	p := echoprom.NewPrometheus("echo", nil)
	p.Use(srv.echo)
	e := echo.New()
	p.SetMetricsPath(e)

	go func() {
		_ = e.Start(fmt.Sprintf(":%v", os.Getenv("PROMETHEUS_HTTP_PORT")))
	}()
}
