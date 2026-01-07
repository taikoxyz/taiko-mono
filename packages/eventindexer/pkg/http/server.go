package http

import (
	"context"
	"encoding/json"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/labstack/echo/v4/middleware"
	"github.com/patrickmn/go-cache"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"

	echo "github.com/labstack/echo/v4"
)

// @title Taiko Event Indexer API
// @version 1.0
// @termsOfService http://swagger.io/terms/

// @contact.name API Support
// @contact.url https://community.taiko.xyz/
// @contact.email info@taiko.xyz

// @license.name MIT
// @license.url https://github.com/taikoxyz/taiko-mono/blob/main/LICENSE

// @host eventindexer.hekla.taiko.xyz
// Server represents an eventindexer http server instance.
type Server struct {
	echo             *echo.Echo
	eventRepo        eventindexer.EventRepository
	nftBalanceRepo   eventindexer.NFTBalanceRepository
	erc20BalanceRepo eventindexer.ERC20BalanceRepository
	chartRepo        eventindexer.ChartRepository
	cache            *cache.Cache
}

type NewServerOpts struct {
	Echo             *echo.Echo
	EventRepo        eventindexer.EventRepository
	NFTBalanceRepo   eventindexer.NFTBalanceRepository
	ERC20BalanceRepo eventindexer.ERC20BalanceRepository
	ChartRepo        eventindexer.ChartRepository
	EthClient        *ethclient.Client
	CorsOrigins      []string
}

func (opts NewServerOpts) Validate() error {
	if opts.Echo == nil {
		return ErrNoHTTPFramework
	}

	if opts.EventRepo == nil {
		return eventindexer.ErrNoEventRepository
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
		echo:             opts.Echo,
		eventRepo:        opts.EventRepo,
		nftBalanceRepo:   opts.NFTBalanceRepo,
		erc20BalanceRepo: opts.ERC20BalanceRepo,
		chartRepo:        opts.ChartRepo,
		cache:            cache,
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

type requestLogEntry struct {
	Time    string            `json:"time"`
	Level   string            `json:"level"`
	Message requestLogMessage `json:"message"`
}

type requestLogMessage struct {
	ID             string `json:"id"`
	RemoteIP       string `json:"remote_ip"`
	Host           string `json:"host"`
	Method         string `json:"method"`
	URI            string `json:"uri"`
	UserAgent      string `json:"user_agent"`
	ResponseStatus int    `json:"response_status"`
	Error          string `json:"error"`
	Latency        int64  `json:"latency"`
	LatencyHuman   string `json:"latency_human"`
	BytesIn        int64  `json:"bytes_in"`
	BytesOut       int64  `json:"bytes_out"`
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

	srv.echo.Use(middleware.RequestLoggerWithConfig(middleware.RequestLoggerConfig{
		Skipper:          LogSkipper,
		HandleError:      true,
		LogRequestID:     true,
		LogRemoteIP:      true,
		LogHost:          true,
		LogMethod:        true,
		LogURI:           true,
		LogUserAgent:     true,
		LogStatus:        true,
		LogError:         true,
		LogLatency:       true,
		LogContentLength: true,
		LogResponseSize:  true,
		LogValuesFunc: func(c echo.Context, v middleware.RequestLoggerValues) error {
			bytesIn := int64(0)
			if v.ContentLength != "" {
				parsed, err := strconv.ParseInt(v.ContentLength, 10, 64)
				if err == nil {
					bytesIn = parsed
				}
			}

			errMsg := ""
			if v.Error != nil {
				errMsg = v.Error.Error()
			}

			entry := requestLogEntry{
				Time:  time.Now().Format(time.RFC3339Nano),
				Level: "INFO",
				Message: requestLogMessage{
					ID:             v.RequestID,
					RemoteIP:       v.RemoteIP,
					Host:           v.Host,
					Method:         v.Method,
					URI:            v.URI,
					UserAgent:      v.UserAgent,
					ResponseStatus: v.Status,
					Error:          errMsg,
					Latency:        v.Latency.Nanoseconds(),
					LatencyHuman:   v.Latency.String(),
					BytesIn:        bytesIn,
					BytesOut:       v.ResponseSize,
				},
			}

			payload, err := json.Marshal(entry)
			if err != nil {
				return err
			}
			_, err = os.Stdout.Write(append(payload, '\n'))
			return err
		},
	}))

	srv.echo.Use(middleware.CORSWithConfig(middleware.CORSConfig{
		AllowOrigins: corsOrigins,
		AllowHeaders: []string{echo.HeaderOrigin, echo.HeaderContentType, echo.HeaderAccept},
		AllowMethods: []string{http.MethodGet, http.MethodHead},
	}))
}
