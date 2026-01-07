package http

import (
	"context"
	"encoding/json"
	"log/slog"
	"math/big"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/ethereum/go-ethereum/common"
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
	TransactionByHash(ctx context.Context, hash common.Hash) (*types.Transaction, bool, error)
	TransactionSender(ctx context.Context,
		tx *types.Transaction,
		blockHash common.Hash,
		txIndex uint,
	) (common.Address, error)
}

// @title Taiko Bridge Relayer API
// @version 1.0
// @termsOfService http://swagger.io/terms/

// @contact.name API Support
// @contact.url https://community.taiko.xyz/
// @contact.email info@taiko.xyz

// @license.name MIT
// @license.url https://github.com/taikoxyz/taiko-mono/blob/main/LICENSE

// @host relayer.hekla.taiko.xyz
// Server represents a relayer http server instance.
type Server struct {
	echo                    *echo.Echo
	eventRepo               relayer.EventRepository
	srcEthClient            ethClient
	srcChainID              *big.Int
	destEthClient           ethClient
	destChainID             *big.Int
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

	srcChainID, err := opts.SrcEthClient.ChainID(context.Background())
	if err != nil {
		return nil, err
	}

	destChainID, err := opts.DestEthClient.ChainID(context.Background())
	if err != nil {
		return nil, err
	}

	srv := &Server{
		echo:                    opts.Echo,
		eventRepo:               opts.EventRepo,
		srcEthClient:            opts.SrcEthClient,
		destEthClient:           opts.DestEthClient,
		processingFeeMultiplier: opts.ProcessingFeeMultiplier,
		taikoL2:                 opts.TaikoL2,
		srcChainID:              srcChainID,
		destChainID:             destChainID,
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
	// Close db connection.
	if err := srv.eventRepo.Close(); err != nil {
		slog.Error("Failed to close db connection", "err", err)
	}

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
		return true
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
