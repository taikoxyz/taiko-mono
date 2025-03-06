package preconfblocks

import (
	"context"
	"errors"
	"fmt"
	"os"

	"github.com/ethereum-optimism/optimism/op-node/p2p"
	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	echojwt "github.com/labstack/echo-jwt/v4"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"github.com/libp2p/go-libp2p/core/peer"

	txListDecompressor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/txlist_decompressor"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// preconfBlockChainSyncer is an interface for preconf block chain syncer.
type preconfBlockChainSyncer interface {
	InsertPreconfBlockFromExecutionPayload(context.Context, *eth.ExecutionPayload) (*types.Header, error)
	RemovePreconfBlocks(ctx context.Context, newLastBlockID uint64) error
}

// @title Taiko Preconfirmation Block Server API
// @version 1.0
// @termsOfService http://swagger.io/terms/

// @contact.name API Support
// @contact.url https://community.taiko.xyz/
// @contact.email info@taiko.xyz

// @license.name MIT
// @license.url https://github.com/taikoxyz/taiko-mono/blob/main/LICENSE.md
// PreconfBlockAPIServer represents a preconfirmation block server instance.
type PreconfBlockAPIServer struct {
	echo               *echo.Echo
	chainSyncer        preconfBlockChainSyncer
	rpc                *rpc.Client
	txListDecompressor *txListDecompressor.TxListDecompressor
	// P2P network for preconf block propagation
	p2pNode   *p2p.NodeP2P
	p2pSigner p2p.Signer
}

// New creates a new preconf blcok server instance, and starts the server.
func New(
	cors string,
	jwtSecret []byte,
	chainSyncer preconfBlockChainSyncer,
	cli *rpc.Client,
) (*PreconfBlockAPIServer, error) {
	protocolConfigs, err := cli.GetProtocolConfigs(nil)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch protocol configs: %w", err)
	}

	server := &PreconfBlockAPIServer{
		echo:        echo.New(),
		chainSyncer: chainSyncer,
		txListDecompressor: txListDecompressor.NewTxListDecompressor(
			uint64(protocolConfigs.BlockMaxGasLimit()),
			uint64(rpc.BlobBytes),
			cli.L2.ChainID,
		),
		rpc: cli,
	}

	server.echo.HideBanner = true
	server.configureMiddleware([]string{cors})
	server.configureRoutes()
	if jwtSecret != nil {
		server.echo.Use(echojwt.JWT(jwtSecret))
	}

	return server, nil
}

func (s *PreconfBlockAPIServer) SetP2PNode(p2pNode *p2p.NodeP2P) {
	s.p2pNode = p2pNode
}

func (s *PreconfBlockAPIServer) SetP2PSigner(p2pSigner p2p.Signer) {
	s.p2pSigner = p2pSigner
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
func (s *PreconfBlockAPIServer) configureMiddleware(corsOrigins []string) {
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

// Start starts the HTTP server.
func (s *PreconfBlockAPIServer) Start(port uint64) error {
	return s.echo.Start(fmt.Sprintf(":%v", port))
}

// Shutdown shuts down the HTTP server.
func (s *PreconfBlockAPIServer) Shutdown(ctx context.Context) error {
	return s.echo.Shutdown(ctx)
}

// configureRoutes contains all routes which will be used by the HTTP server.
func (s *PreconfBlockAPIServer) configureRoutes() {
	s.echo.GET("/", s.HealthCheck)
	s.echo.GET("/healthz", s.HealthCheck)
	s.echo.POST("/preconfBlocks", s.BuildPreconfBlock)
	s.echo.DELETE("/preconfBlocks", s.RemovePreconfBlocks)
}

// OnUnsafeL2Payload implements the p2p.GossipIn interface.
func (s *PreconfBlockAPIServer) OnUnsafeL2Payload(
	ctx context.Context,
	from peer.ID,
	msg *eth.ExecutionPayloadEnvelope,
) error {
	// Ignore the message if it is from the current P2P node.
	if s.p2pNode.Host().ID() == from {
		log.Debug("Ignore the message from the current P2P node", "peer", from)
		return nil
	}

	log.Info(
		"📢 New preconfirmation block payload from P2P network",
		"peer", from,
		"blockID", uint64(msg.ExecutionPayload.BlockNumber),
		"hash", msg.ExecutionPayload.BlockHash.Hex(),
		"txs", len(msg.ExecutionPayload.Transactions),
	)

	// Ignore the message if it is from the current P2P node.
	if s.p2pNode.Host().ID() == from {
		log.Info("Ignore the message from the current P2P node", "peer", from)
		return nil
	}

	if len(msg.ExecutionPayload.Transactions) != 1 {
		return fmt.Errorf("only one transaction list is allowed")
	}

	header, err := s.rpc.L2.HeaderByHash(ctx, msg.ExecutionPayload.BlockHash)
	if err != nil && !errors.Is(err, ethereum.NotFound) {
		return fmt.Errorf("failed to fetch header by hash: %w", err)
	}

	if header != nil {
		log.Debug(
			"Preconfirmation block already exists",
			"peer", from,
			"blockID", uint64(msg.ExecutionPayload.BlockNumber),
			"hash", msg.ExecutionPayload.BlockHash.Hex(),
			"txs", len(msg.ExecutionPayload.Transactions),
		)
		return nil
	}

	if msg.ExecutionPayload.Transactions[0], err = utils.Decompress(msg.ExecutionPayload.Transactions[0]); err != nil {
		return fmt.Errorf("failed to decompress tx list bytes: %w", err)
	}

	if _, err := s.chainSyncer.InsertPreconfBlockFromExecutionPayload(ctx, msg.ExecutionPayload); err != nil {
		return fmt.Errorf("failed to insert preconfirmation block from P2P network: %w", err)
	}

	return nil
}

// P2PSequencerAddress implements the p2p.GossipRuntimeConfig interface.
func (s *PreconfBlockAPIServer) P2PSequencerAddress() common.Address {
	operatorAddress, err := s.rpc.GetPreconfWhiteListOperator(nil)
	if err != nil || operatorAddress == (common.Address{}) {
		log.Warn("Failed to get current preconf whitelist operator address", "error", err)
		return common.Address{}
	}

	log.Info("Current operator address for epoch as P2P sequencer", "address", operatorAddress.Hex())

	return operatorAddress
}

// P2PSequencerAddresses implements the p2p.PreconfGossipRuntimeConfig interface.
func (s *PreconfBlockAPIServer) P2PSequencerAddresses() []common.Address {
	var sequencerAddresses []common.Address
	currentOperatorAddress, err := s.rpc.GetPreconfWhiteListOperator(nil)
	if err != nil {
		// TODO: return an error instead of logging it after we have a real whitelist contract to test.
		log.Warn("Failed to get current preconf whitelist operator address", "error", err)
	} else {
		sequencerAddresses = append(sequencerAddresses, currentOperatorAddress)
	}

	nextOperatorAddress, err := s.rpc.GetNextPreconfWhiteListOperator(nil)
	if err != nil {
		// TODO: return an error instead of logging it after we have a real whitelist contract to test.
		log.Warn("Failed to get next preconf whitelist operator address", "error", err)
	} else {
		sequencerAddresses = append(sequencerAddresses, nextOperatorAddress)
	}

	log.Info(
		"Operator addresses as P2P sequencer",
		"current", currentOperatorAddress.Hex(),
		"next", nextOperatorAddress.Hex(),
	)

	return sequencerAddresses
}
