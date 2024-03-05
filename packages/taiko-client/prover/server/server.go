package server

import (
	"context"
	"crypto/ecdsa"
	"math/big"
	"net/http"
	"os"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethdb"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"

	"github.com/taikoxyz/taiko-client/bindings"
	"github.com/taikoxyz/taiko-client/pkg/rpc"
)

// @title Taiko Prover Server API
// @version 1.0
// @termsOfService http://swagger.io/terms/

// @contact.name API Support
// @contact.url https://community.taiko.xyz/
// @contact.email info@taiko.xyz

// @license.name MIT
// @license.url https://github.com/taikoxyz/taiko-client/blob/main/LICENSE.md

// ProverServer represents a prover server instance.
type ProverServer struct {
	echo                    *echo.Echo
	proverPrivateKey        *ecdsa.PrivateKey
	proverAddress           common.Address
	minOptimisticTierFee    *big.Int
	minSgxTierFee           *big.Int
	maxExpiry               time.Duration
	maxSlippage             uint64
	maxProposedIn           uint64
	proposeConcurrencyGuard chan struct{}
	taikoL1Address          common.Address
	assignmentHookAddress   common.Address
	rpc                     *rpc.Client
	protocolConfigs         *bindings.TaikoDataConfig
	livenessBond            *big.Int
	isGuardian              bool
	db                      ethdb.KeyValueStore
}

// NewProverServerOpts contains all configurations for creating a prover server instance.
type NewProverServerOpts struct {
	ProverPrivateKey        *ecdsa.PrivateKey
	MinOptimisticTierFee    *big.Int
	MinSgxTierFee           *big.Int
	MaxExpiry               time.Duration
	MaxBlockSlippage        uint64
	MaxProposedIn           uint64
	ProposeConcurrencyGuard chan struct{}
	TaikoL1Address          common.Address
	AssignmentHookAddress   common.Address
	RPC                     *rpc.Client
	ProtocolConfigs         *bindings.TaikoDataConfig
	LivenessBond            *big.Int
	IsGuardian              bool
	DB                      ethdb.KeyValueStore
}

// New creates a new prover server instance.
func New(opts *NewProverServerOpts) (*ProverServer, error) {
	srv := &ProverServer{
		proverPrivateKey:        opts.ProverPrivateKey,
		proverAddress:           crypto.PubkeyToAddress(opts.ProverPrivateKey.PublicKey),
		echo:                    echo.New(),
		minOptimisticTierFee:    opts.MinOptimisticTierFee,
		minSgxTierFee:           opts.MinSgxTierFee,
		maxExpiry:               opts.MaxExpiry,
		maxProposedIn:           opts.MaxProposedIn,
		maxSlippage:             opts.MaxBlockSlippage,
		proposeConcurrencyGuard: opts.ProposeConcurrencyGuard,
		taikoL1Address:          opts.TaikoL1Address,
		assignmentHookAddress:   opts.AssignmentHookAddress,
		rpc:                     opts.RPC,
		protocolConfigs:         opts.ProtocolConfigs,
		livenessBond:            opts.LivenessBond,
		isGuardian:              opts.IsGuardian,
		db:                      opts.DB,
	}

	srv.echo.HideBanner = true
	srv.configureMiddleware()
	srv.configureRoutes()

	return srv, nil
}

// Start starts the HTTP server.
func (srv *ProverServer) Start(address string) error {
	return srv.echo.Start(address)
}

// Shutdown shuts down the HTTP server.
func (srv *ProverServer) Shutdown(ctx context.Context) error {
	return srv.echo.Shutdown(ctx)
}

// Health endpoints for probes.
func (srv *ProverServer) Health(c echo.Context) error {
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
func (srv *ProverServer) configureMiddleware() {
	srv.echo.Use(middleware.RequestID())

	srv.echo.Use(middleware.LoggerWithConfig(middleware.LoggerConfig{
		Skipper: LogSkipper,
		Format: `{"time":"${time_rfc3339_nano}","level":"INFO","message":{"id":"${id}","remote_ip":"${remote_ip}",` +
			`"host":"${host}","method":"${method}","uri":"${uri}","user_agent":"${user_agent}",` +
			`"response_status":${status},"error":"${error}","latency":${latency},"latency_human":"${latency_human}",` +
			`"bytes_in":${bytes_in},"bytes_out":${bytes_out}}}` + "\n",
		Output: os.Stdout,
	}))
}

// configureRoutes contains all routes which will be used by prover server.
func (srv *ProverServer) configureRoutes() {
	srv.echo.GET("/", srv.Health)
	srv.echo.GET("/healthz", srv.Health)
	srv.echo.GET("/status", srv.GetStatus)
	srv.echo.POST("/assignment", srv.CreateAssignment)
}
