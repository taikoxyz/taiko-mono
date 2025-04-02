package preconfblocks

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"os"
	"sync"

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
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
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
	p2pNode        *p2p.NodeP2P
	p2pSigner      p2p.Signer
	payloadsCache  *payloadQueue
	lookahead      *Lookahead
	lookaheadMutex sync.Mutex
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
		rpc:           cli,
		payloadsCache: newPayloadQueue(),
		lookahead:     &Lookahead{},
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

	metrics.DriverPreconfP2PEnvelopeCounter.Inc()

	if len(msg.ExecutionPayload.Transactions) != 1 {
		return fmt.Errorf("only one transaction list is allowed")
	}

	// Check if the parent block is in the canonical chain, if not, we try to
	// find all the missing ancients from the cache and import them, if we can't, then we cache the message.
	parent, err := s.rpc.L2.HeaderByNumber(ctx, new(big.Int).SetUint64(uint64(msg.ExecutionPayload.BlockNumber-1)))
	if err != nil && !errors.Is(err, ethereum.NotFound) {
		return fmt.Errorf("failed to fetch parent header: %w", err)
	}
	if parent == nil || parent.Hash() != msg.ExecutionPayload.ParentHash {
		// Try to find all the missing ancients from the cache and import them.
		if err := s.ImportCachedPayloads(ctx, msg.ExecutionPayload); err != nil {
			log.Info(
				"Parent block not in L2 canonical chain, cache the message for later use",
				"peer", from,
				"blockID", uint64(msg.ExecutionPayload.BlockNumber),
				"hash", msg.ExecutionPayload.BlockHash.Hex(),
				"parentHash", msg.ExecutionPayload.ParentHash,
				"error", err,
			)
			if !s.payloadsCache.has(uint64(msg.ExecutionPayload.BlockNumber), msg.ExecutionPayload.BlockHash) {
				s.payloadsCache.put(uint64(msg.ExecutionPayload.BlockNumber), msg.ExecutionPayload)
			}
			return nil
		}
	}

	// Check if the block already exists in the canonical chain, if it does, we ignore the message.
	header, err := s.rpc.L2.HeaderByNumber(ctx, new(big.Int).SetUint64(uint64(msg.ExecutionPayload.BlockNumber)))
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

	// Decompress the transactions list.
	if msg.ExecutionPayload.Transactions[0], err = utils.DecompressPacaya(
		msg.ExecutionPayload.Transactions[0],
	); err != nil {
		return fmt.Errorf("failed to decompress transactions list bytes: %w", err)
	}

	// Insert the preconfirmation block into the L2 EE chain.
	if _, err := s.chainSyncer.InsertPreconfBlockFromExecutionPayload(ctx, msg.ExecutionPayload); err != nil {
		return fmt.Errorf("failed to insert preconfirmation block from P2P network: %w", err)
	}

	return nil
}

// ImportCachedPayloads tries to import cached payloads from the cached payload queue.
func (s *PreconfBlockAPIServer) ImportCachedPayloads(ctx context.Context, headPayload *eth.ExecutionPayload) error {
	// Try find the missing parent payload in the cache.
	payloadsToImport := make([]*eth.ExecutionPayload, 0)
	for {
		parentPayload := s.payloadsCache.get(uint64(headPayload.BlockNumber)-1, headPayload.ParentHash)
		if parentPayload == nil {
			return fmt.Errorf(
				"failed to find parent payload in the cache, number %d, hash %s",
				headPayload.BlockNumber-1,
				headPayload.ParentHash.Hex(),
			)
		}
		payloadsToImport = append([]*eth.ExecutionPayload{parentPayload}, payloadsToImport...)

		// Check if the found parent payload is in the canonical chain,
		// if it is not, continue to find the parent payload.
		parentHeader, err := s.rpc.L2.HeaderByNumber(ctx, new(big.Int).SetUint64(uint64(parentPayload.BlockNumber)))
		if err != nil && !errors.Is(err, ethereum.NotFound) {
			return fmt.Errorf("failed to fetch parent header: %w", err)
		}
		if parentHeader == nil || parentHeader.Hash() != parentPayload.BlockHash {
			log.Debug("Parent block not in L2 canonical chain, continue to import cached payloads")
			continue
		}

		break
	}

	// If all parent payloads are found, try to import them.
	for _, payload := range payloadsToImport {
		if _, err := s.chainSyncer.InsertPreconfBlockFromExecutionPayload(ctx, payload); err != nil {
			return fmt.Errorf("failed to insert preconfirmation block from P2P network: %w", err)
		}
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
	s.lookaheadMutex.Lock()
	defer s.lookaheadMutex.Unlock()
	log.Info(
		"Operator addresses as P2P sequencer",
		"current", s.lookahead.CurrOperator.Hex(),
		"next", s.lookahead.NextOperator.Hex(),
	)

	return []common.Address{
		s.lookahead.CurrOperator,
		s.lookahead.NextOperator,
	}
}

// UpdateLookahead updates the lookahead information.
func (s *PreconfBlockAPIServer) UpdateLookahead(l *Lookahead) {
	s.lookaheadMutex.Lock()
	defer s.lookaheadMutex.Unlock()
	s.lookahead = l
}
