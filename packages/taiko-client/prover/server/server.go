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
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"

	"github.com/taikoxyz/taiko-client/bindings"
	"github.com/taikoxyz/taiko-client/pkg/rpc"
	proofProducer "github.com/taikoxyz/taiko-client/prover/proof_producer"
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
	echo                  *echo.Echo
	proverPrivateKey      *ecdsa.PrivateKey
	proverAddress         common.Address
	minOptimisticTierFee  *big.Int
	minSgxTierFee         *big.Int
	minSgxAndZkVMTierFee  *big.Int
	minEthBalance         *big.Int
	minTaikoTokenBalance  *big.Int
	maxExpiry             time.Duration
	maxSlippage           uint64
	maxProposedIn         uint64
	taikoL1Address        common.Address
	assignmentHookAddress common.Address
	proofSubmissionCh     chan<- proofProducer.ProofRequestBody
	rpc                   *rpc.Client
	protocolConfigs       *bindings.TaikoDataConfig
	livenessBond          *big.Int
}

// NewProverServerOpts contains all configurations for creating a prover server instance.
type NewProverServerOpts struct {
	ProverPrivateKey      *ecdsa.PrivateKey
	MinOptimisticTierFee  *big.Int
	MinSgxTierFee         *big.Int
	MinSgxAndZkVMTierFee  *big.Int
	MinEthBalance         *big.Int
	MinTaikoTokenBalance  *big.Int
	MaxExpiry             time.Duration
	MaxBlockSlippage      uint64
	MaxProposedIn         uint64
	TaikoL1Address        common.Address
	AssignmentHookAddress common.Address
	ProofSubmissionCh     chan<- proofProducer.ProofRequestBody
	RPC                   *rpc.Client
	ProtocolConfigs       *bindings.TaikoDataConfig
	LivenessBond          *big.Int
}

// New creates a new prover server instance.
func New(opts *NewProverServerOpts) (*ProverServer, error) {
	srv := &ProverServer{
		proverPrivateKey:      opts.ProverPrivateKey,
		proverAddress:         crypto.PubkeyToAddress(opts.ProverPrivateKey.PublicKey),
		echo:                  echo.New(),
		minOptimisticTierFee:  opts.MinOptimisticTierFee,
		minSgxTierFee:         opts.MinSgxTierFee,
		minSgxAndZkVMTierFee:  opts.MinSgxAndZkVMTierFee,
		minEthBalance:         opts.MinEthBalance,
		minTaikoTokenBalance:  opts.MinTaikoTokenBalance,
		maxExpiry:             opts.MaxExpiry,
		maxProposedIn:         opts.MaxProposedIn,
		maxSlippage:           opts.MaxBlockSlippage,
		taikoL1Address:        opts.TaikoL1Address,
		assignmentHookAddress: opts.AssignmentHookAddress,
		proofSubmissionCh:     opts.ProofSubmissionCh,
		rpc:                   opts.RPC,
		protocolConfigs:       opts.ProtocolConfigs,
		livenessBond:          opts.LivenessBond,
	}

	srv.echo.HideBanner = true
	srv.configureMiddleware()
	srv.configureRoutes()

	return srv, nil
}

// Start starts the HTTP server.
func (s *ProverServer) Start(address string) error {
	return s.echo.Start(address)
}

// Shutdown shuts down the HTTP server.
func (s *ProverServer) Shutdown(ctx context.Context) error {
	return s.echo.Shutdown(ctx)
}

// Health endpoints for probes.
func (s *ProverServer) Health(c echo.Context) error {
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
func (s *ProverServer) configureMiddleware() {
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
func (s *ProverServer) configureRoutes() {
	s.echo.GET("/", s.Health)
	s.echo.GET("/healthz", s.Health)
	s.echo.GET("/status", s.GetStatus)
	s.echo.POST("/assignment", s.CreateAssignment)
}
