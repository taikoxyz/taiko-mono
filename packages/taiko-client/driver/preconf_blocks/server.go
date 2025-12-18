package preconfblocks

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/ethereum-optimism/optimism/op-node/p2p"
	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/miner"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/gorilla/websocket"
	lru "github.com/hashicorp/golang-lru/v2"
	"github.com/holiman/uint256"
	echojwt "github.com/labstack/echo-jwt/v4"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"github.com/libp2p/go-libp2p/core/peer"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/preconf"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
	validator "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/anchor_tx_validator"
)

var (
	errInvalidCurrOperator = errors.New("invalid operator: expected current operator in handover window")
	errInvalidNextOperator = errors.New("invalid operator: expected next operator in handover window")
	wsUpgrader             = websocket.Upgrader{CheckOrigin: func(r *http.Request) bool { return true }}
)

const requestSyncMargin = uint64(128) // Margin for requesting sync, to avoid requesting very old blocks.
// monitorLatestProposalOnChainInterval defines how often we reconcile the cached proposal with Pacaya on-chain state.
const monitorLatestProposalOnChainInterval = 10 * time.Second

// preconfBlockChainSyncer is an interface for preconfirmation block chain syncer.
type preconfBlockChainSyncer interface {
	InsertPreconfBlocksFromEnvelopes(context.Context, []*preconf.Envelope, bool) ([]*types.Header, error)
}

// @title Taiko Preconfirmation Block Server API
// @version 1.0
// @termsOfService http://swagger.io/terms/

// @contact.name API Support
// @contact.url https://community.taiko.xyz/
// @contact.email info@taiko.xyz

// @license.name MIT
// @license.url https://github.com/taikoxyz/taiko-mono/blob/main/LICENSE
// PreconfBlockAPIServer represents a preconfirmation block server instance.
type PreconfBlockAPIServer struct {
	echo                          *echo.Echo
	rpc                           *rpc.Client
	pacayaChainSyncer             preconfBlockChainSyncer
	shastaChainSyncer             preconfBlockChainSyncer
	anchorValidator               *validator.AnchorTxValidator
	highestUnsafeL2PayloadBlockID uint64
	// P2P network for preconfirmation block propagation
	p2pNode   *p2p.NodeP2P
	p2pSigner p2p.Signer
	// WebSocket server for preconfirmation block notifications
	ws *webSocketSever
	// Lookahead information for the current and next operator
	lookahead      *Lookahead
	lookaheadMutex sync.Mutex
	// Cache
	envelopesCache               *envelopeQueue
	blockRequestsCache           *lru.Cache[common.Hash, struct{}]
	sequencingEndedForEpochCache *lru.Cache[uint64, common.Hash]
	responseSeenCache            *lru.Cache[common.Hash, time.Time]
	// ConfigureRoutes
	preconfOperatorAddress common.Address
	// Last seen proposal
	latestSeenProposalCh chan *encoding.LastSeenProposal
	latestSeenProposal   *encoding.LastSeenProposal

	// Mutex for P2P message handlers
	mutex sync.Mutex
}

// New creates a new preconfirmation block server instance, and starts the server.
func New(
	cors string,
	jwtSecret []byte,
	preconfOperatorAddress common.Address,
	taikoAnchorAddress common.Address,
	pacayaChainSyncer preconfBlockChainSyncer,
	shastaChainSyncer preconfBlockChainSyncer,
	cli *rpc.Client,
	latestSeenProposalCh chan *encoding.LastSeenProposal,
) (*PreconfBlockAPIServer, error) {
	anchorValidator, err := validator.New(
		taikoAnchorAddress,
		cli.L2.ChainID,
		cli,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize anchor validator: %w", err)
	}

	// Initialize caches.
	blockRequestsCache, err := lru.New[common.Hash, struct{}](maxTrackedPayloads)
	if err != nil {
		return nil, fmt.Errorf("failed to create block requests cache: %w", err)
	}
	endOfSequencingCache, err := lru.New[uint64, common.Hash](maxTrackedPayloads)
	if err != nil {
		return nil, fmt.Errorf("failed to create end of sequencing cache: %w", err)
	}
	responseSeenCache, err := lru.New[common.Hash, time.Time](maxTrackedPayloads)
	if err != nil {
		return nil, fmt.Errorf("failed to create response seen cache: %w", err)
	}

	head, err := cli.L2.BlockByNumber(context.Background(), nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get L2 head block: %w", err)
	}

	server := &PreconfBlockAPIServer{
		echo:                          echo.New(),
		anchorValidator:               anchorValidator,
		pacayaChainSyncer:             pacayaChainSyncer,
		shastaChainSyncer:             shastaChainSyncer,
		ws:                            &webSocketSever{rpc: cli, clients: make(map[*websocket.Conn]struct{})},
		rpc:                           cli,
		envelopesCache:                newEnvelopeQueue(),
		preconfOperatorAddress:        preconfOperatorAddress,
		lookahead:                     &Lookahead{},
		mutex:                         sync.Mutex{},
		blockRequestsCache:            blockRequestsCache,
		sequencingEndedForEpochCache:  endOfSequencingCache,
		latestSeenProposalCh:          latestSeenProposalCh,
		responseSeenCache:             responseSeenCache,
		highestUnsafeL2PayloadBlockID: head.NumberU64(),
	}

	server.echo.HideBanner = true
	server.configureMiddleware([]string{cors})
	server.configureRoutes()
	if jwtSecret != nil {
		server.echo.Use(echojwt.JWT(jwtSecret))
	}

	return server, nil
}

// SetP2PNode sets the P2P node for the preconfirmation block server.
func (s *PreconfBlockAPIServer) SetP2PNode(p2pNode *p2p.NodeP2P) {
	s.p2pNode = p2pNode
}

// SetP2PSigner sets the P2P signer for the preconfirmation block server.
func (s *PreconfBlockAPIServer) SetP2PSigner(p2pSigner p2p.Signer) {
	s.p2pSigner = p2pSigner
}

// LogSkipper implements the `middleware.Skipper` interface,
// skip all ECHO logs for the preconfirmation block server.
func LogSkipper(c echo.Context) bool {
	return true
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

// configureRoutes contains all routes which will be used by the HTTP / WS server.
func (s *PreconfBlockAPIServer) configureRoutes() {
	// HTTP routes
	s.echo.GET("/", s.HealthCheck)
	s.echo.GET("/healthz", s.HealthCheck)
	s.echo.GET("/status", s.GetStatus)
	s.echo.POST("/preconfBlocks", s.BuildPreconfBlock)

	// WebSocket routes
	s.echo.GET("/ws", s.ws.handleWebSocket)
}

// OnUnsafeL2Payload implements the p2p.GossipIn interface.
func (s *PreconfBlockAPIServer) OnUnsafeL2Payload(
	ctx context.Context,
	from peer.ID,
	msg *eth.ExecutionPayloadEnvelope,
) error {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	start := time.Now()
	defer func() {
		elapsedMs := time.Since(start).Milliseconds()
		metrics.DriverPreconfOnUnsafeL2PayloadDuration.Observe(float64(elapsedMs) / 1_000)
		log.Debug("OnUnsafeL2Payload completed", "elapsed", fmt.Sprintf("%dms", elapsedMs))
	}()

	// Ignore the message if it is from the current P2P node, when `from` is empty,
	// it means the message is for importing the pending blocks from the cache after
	// a new L2 EE chain has just finished a beacon-sync.
	if from != "" && s.p2pNode.Host().ID() == from {
		log.Debug("Ignore the message from the current P2P node", "peer", from)
		return nil
	}

	if msg == nil || msg.ExecutionPayload == nil {
		log.Warn("Empty preconfirmation block payload", "peer", from)
		metrics.DriverPreconfInvalidEnvelopeCounter.Inc()
		return nil
	}

	var signature [65]byte
	if msg.Signature != nil {
		signature = *msg.Signature
	}

	log.Info(
		"📢 New preconfirmation block payload from P2P network",
		"peer", from,
		"blockID", uint64(msg.ExecutionPayload.BlockNumber),
		"hash", msg.ExecutionPayload.BlockHash.Hex(),
		"parentHash", msg.ExecutionPayload.ParentHash.Hex(),
		"timestamp", uint64(msg.ExecutionPayload.Timestamp),
		"coinbase", msg.ExecutionPayload.FeeRecipient.Hex(),
		"gasUsed", uint64(msg.ExecutionPayload.GasUsed),
		"endOfSequencing", msg.EndOfSequencing != nil && *msg.EndOfSequencing,
		"isForcedInclusion", msg.IsForcedInclusion != nil && *msg.IsForcedInclusion,
		"signature", common.Bytes2Hex(signature[:]),
	)
	metrics.DriverPreconfEnvelopeCounter.Inc()

	// Check if the payload is valid.
	if err := s.ValidateExecutionPayload(msg.ExecutionPayload); err != nil {
		log.Warn(
			"Invalid preconfirmation block payload",
			"peer", from,
			"blockID", uint64(msg.ExecutionPayload.BlockNumber),
			"hash", msg.ExecutionPayload.BlockHash.Hex(),
			"parentHash", msg.ExecutionPayload.ParentHash.Hex(),
			"error", err,
		)
		metrics.DriverPreconfInvalidEnvelopeCounter.Inc()
		return nil
	}

	// Check if the L2 execution engine is syncing from L1.
	progress, err := s.rpc.L2ExecutionEngineSyncProgress(ctx)
	if err != nil {
		return fmt.Errorf("failed to get L2 execution engine sync progress: %w", err)
	}

	if progress.IsSyncing() {
		s.tryPutEnvelopeIntoCache(msg, from)
		return nil
	}

	// Ensure the preconfirmation block number is greater than the current head L1 origin block ID.
	headL1Origin, err := checkMessageBlockNumber(ctx, s.rpc, msg)
	if err != nil {
		return fmt.Errorf("failed to check message block number: %w", err)
	}

	// Try to import the payload into the L2 EE chain, if can't, cache it.
	quit, err := s.TryImportingPayload(ctx, headL1Origin, msg, from)
	if err != nil {
		return fmt.Errorf("failed to try importing payload: %w", err)
	}
	if quit {
		return nil
	}

	s.tryPutEnvelopeIntoCache(msg, from)

	// If the envelope is an end of sequencing message, we need to notify the clients.
	if msg.EndOfSequencing != nil && *msg.EndOfSequencing && s.rpc.L1Beacon != nil {
		s.sequencingEndedForEpochCache.Add(s.rpc.L1Beacon.CurrentEpoch(), msg.ExecutionPayload.BlockHash)
		s.ws.pushEndOfSequencingNotification(s.rpc.L1Beacon.CurrentEpoch())
	}

	return nil
}

// OnUnsafeL2Response implements the p2p.GossipIn interface.
func (s *PreconfBlockAPIServer) OnUnsafeL2Response(
	ctx context.Context,
	from peer.ID,
	msg *eth.ExecutionPayloadEnvelope,
) error {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	start := time.Now()
	defer func() {
		elapsedMs := time.Since(start).Milliseconds()
		metrics.DriverPreconfOnL2UnsafeResponseDuration.Observe(float64(elapsedMs) / 1_000)
		log.Debug("OnUnsafeL2Response completed", "elapsed", fmt.Sprintf("%dms", elapsedMs))
	}()

	// add responses seen to cache.
	s.responseSeenCache.Add(msg.ExecutionPayload.BlockHash, time.Now().UTC())

	// Ignore the message if it is from the current P2P node, when `from` is empty,
	// it means the message is for importing the pending blocks from the cache after
	// a new L2 EE chain has just finished a beacon-sync.
	if from != "" && s.p2pNode.Host().ID() == from {
		log.Debug("Ignore the message from the current P2P node", "peer", from)
		return nil
	}

	metrics.DriverPreconfOnL2UnsafeResponseCounter.Inc()

	// Ignore the message if it is in the cache already.
	if s.envelopesCache.hasExact(uint64(msg.ExecutionPayload.BlockNumber), msg.ExecutionPayload.BlockHash) {
		log.Debug(
			"Ignore already cached preconfirmation block response",
			"peer", from,
			"blockID", uint64(msg.ExecutionPayload.BlockNumber),
			"hash", msg.ExecutionPayload.BlockHash.Hex(),
		)
		return nil
	}

	// Check if the payload is valid.
	if err := s.ValidateExecutionPayload(msg.ExecutionPayload); err != nil {
		log.Warn(
			"Invalid preconfirmation block payload response",
			"peer", from,
			"blockID", uint64(msg.ExecutionPayload.BlockNumber),
			"hash", msg.ExecutionPayload.BlockHash.Hex(),
			"parentHash", msg.ExecutionPayload.ParentHash.Hex(),
			"error", err,
		)
		metrics.DriverPreconfInvalidEnvelopeCounter.Inc()
		return nil
	}

	// Ignore the message if it has been inserted already.
	head, err := s.rpc.L2.HeaderByHash(ctx, msg.ExecutionPayload.BlockHash)
	if err != nil && !errors.Is(err, ethereum.NotFound) {
		return fmt.Errorf("failed to fetch header by hash: %w", err)
	}
	if head != nil {
		log.Debug(
			"Ignore already inserted preconfirmation response block",
			"peer", from,
			"blockID", uint64(msg.ExecutionPayload.BlockNumber),
			"hash", msg.ExecutionPayload.BlockHash.Hex(),
		)
		s.tryPutEnvelopeIntoCache(msg, from)
		return nil
	}

	log.Info(
		"🔔 New preconfirmation block payload response from P2P network",
		"peer", from,
		"blockID", uint64(msg.ExecutionPayload.BlockNumber),
		"hash", msg.ExecutionPayload.BlockHash.Hex(),
		"parentHash", msg.ExecutionPayload.ParentHash.Hex(),
		"timestamp", uint64(msg.ExecutionPayload.Timestamp),
		"coinbase", msg.ExecutionPayload.FeeRecipient.Hex(),
		"gasUsed", uint64(msg.ExecutionPayload.GasUsed),
		"transactions", len(msg.ExecutionPayload.Transactions),
	)

	// Ensure the preconfirmation block number is greater than the current head L1 origin block ID.
	headL1Origin, err := checkMessageBlockNumber(ctx, s.rpc, msg)
	if err != nil {
		return fmt.Errorf("failed to check message block number: %w", err)
	}

	// Try to import the payload into the L2 EE chain, if can't, cache it.
	cached, err := s.TryImportingPayload(ctx, headL1Origin, msg, from)
	if err != nil {
		return fmt.Errorf("failed to try importing payload: %w", err)
	}

	if !cached {
		s.tryPutEnvelopeIntoCache(msg, from)
	}

	return nil
}

// OnUnsafeL2Request implements the p2p.GossipIn interface.
func (s *PreconfBlockAPIServer) OnUnsafeL2Request(
	ctx context.Context,
	from peer.ID,
	hash common.Hash,
) error {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	start := time.Now()
	defer func() {
		elapsedMs := time.Since(start).Milliseconds()
		metrics.DriverPreconfOnL2UnsafeRequestDuration.Observe(float64(elapsedMs) / 1_000)
		log.Debug("OnUnsafeL2Request completed", "elapsed", fmt.Sprintf("%dms", elapsedMs))
	}()

	// Ignore the message if it is from the current P2P node.
	if from != "" && s.p2pNode.Host().ID() == from {
		log.Debug("Ignore the message from the current P2P node", "peer", from)
		return nil
	}

	log.Info("🔊 New preconfirmation block request from P2P network", "peer", from, "hash", hash.Hex())

	metrics.DriverPreconfOnL2UnsafeRequestCounter.Inc()

	headL1Origin, err := s.rpc.L2.HeadL1Origin(ctx)
	if err != nil && err.Error() != ethereum.NotFound.Error() {
		return fmt.Errorf("failed to fetch head L1 origin: %w", err)
	}

	// Fetch the block from L2 EE and gossip it out.
	block, err := s.rpc.L2.BlockByHash(ctx, hash)
	if err != nil {
		log.Debug(
			"Failed to fetch preconfirmation request block by hash",
			"peer", from,
			"hash", hash.Hex(),
			"error", err,
		)
		return fmt.Errorf("failed to fetch preconfirmation request block by hash: %w", err)
	}

	if headL1Origin != nil && block.NumberU64() <= headL1Origin.BlockID.Uint64() {
		log.Debug(
			"Ignore the message for outdated block",
			"peer", from,
			"blockID", block.NumberU64(),
			"hash", block.Hash().Hex(),
			"parentHash", block.ParentHash().Hex(),
		)

		return nil
	}

	l1Origin, err := s.rpc.L2.L1OriginByID(ctx, block.Number())
	if err != nil {
		log.Warn(
			"Failed to fetch L1 origin for the block",
			"peer", from,
			"blockID", block.NumberU64(),
			"hash", block.Hash().Hex(),
			"error", err,
		)
		return fmt.Errorf("failed to fetch L1 origin for the block: %w", err)
	}

	log.Info(
		"Fetched L1 Origin",
		"blockID", l1Origin.BlockID.Uint64(),
		"l2BlockHash", l1Origin.L2BlockHash.Hex(),
		"l1BlockHash", l1Origin.L1BlockHash.Hex(),
		"l1OriginBlockID", l1Origin.BlockID.Uint64(),
		"l1OriginIsForcedInclusion", l1Origin.IsForcedInclusion,
		"l1OriginBlockHeight", l1Origin.L1BlockHeight.Uint64(),
		"l1OriginSignature", common.Bytes2Hex(l1Origin.Signature[:]),
	)

	sig := l1Origin.Signature
	if sig == [65]byte{} {
		log.Warn(
			"Empty L1 origin signature, unable to propagate block",
			"peer", from,
			"blockID", block.NumberU64(),
			"hash", block.Hash().Hex(),
			"parentHash", block.ParentHash().Hex(),
			"l1OriginBlockID", l1Origin.BlockID.Uint64(),
		)

		return err
	}

	// we have the block, now wait a deterministic jitter before responding.
	// this will reduce "response storms" when many nodes receive the request for the block.
	wait := deterministicJitter(s.p2pNode.Host().ID(), hash, 1*time.Second)
	timer := time.NewTimer(wait)
	defer timer.Stop()
	select {
	case <-timer.C:
		// If any response for this hash was seen recently, skip ours.
		if ts, ok := s.responseSeenCache.Get(hash); ok && time.Since(ts) < 10*time.Second {
			log.Debug(
				"Skip responding; recent response already seen",
				"peer", from,
				"hash", hash.Hex(),
			)
			return nil
		}
	case <-ctx.Done():
		return ctx.Err()
	}

	endOfSequencing := false
	for _, epoch := range s.sequencingEndedForEpochCache.Keys() {
		if hash, ok := s.sequencingEndedForEpochCache.Get(epoch); ok && hash == block.Hash() {
			endOfSequencing = true
			break
		}
	}

	envelope, err := blockToEnvelope(block, &endOfSequencing, &l1Origin.IsForcedInclusion, &sig)
	if err != nil {
		return fmt.Errorf("failed to convert block to envelope: %w", err)
	}

	log.Info(
		"Publish preconfirmation block response",
		"blockID", block.NumberU64(),
		"hash", hash.Hex(),
		"signature", common.Bytes2Hex(sig[:]),
	)

	if err := s.p2pNode.GossipOut().PublishL2RequestResponse(ctx, envelope, s.p2pSigner); err != nil {
		log.Warn(
			"Failed to publish preconfirmation block response",
			"hash", hash.Hex(),
			"blockID", uint64(envelope.ExecutionPayload.BlockNumber),
			"error", err,
		)
	}

	s.tryPutEnvelopeIntoCache(envelope, from)

	s.responseSeenCache.Add(hash, time.Now().UTC())

	return nil
}

// OnUnsafeL2EndOfSequencingRequest implements the p2p.GossipIn interface.
func (s *PreconfBlockAPIServer) OnUnsafeL2EndOfSequencingRequest(
	ctx context.Context,
	from peer.ID,
	epoch uint64,
) error {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	start := time.Now()
	defer func() {
		elapsedMs := time.Since(start).Milliseconds()
		metrics.DriverPreconfOnEndOfSequencingRequestDuration.Observe(float64(elapsedMs) / 1_000)
		log.Debug("OnUnsafeL2EndOfSequencingRequest completed", "elapsed", fmt.Sprintf("%dms", elapsedMs))
	}()

	// Ignore the message if it is from the current P2P node.
	if from != "" && s.p2pNode.Host().ID() == from {
		log.Debug("Ignore the message from the current P2P node", "peer", from)
		return nil
	}

	// Only respond if you are the current sequencer, *not* the active sequencer in the slot.
	if s.preconfOperatorAddress.Hex() != s.lookahead.CurrOperator.Hex() {
		log.Debug("Ignore the message from the current P2P node, not current operator", "peer", from)
		return nil
	}

	log.Info(
		"🔕 New end of sequencing preconfirmation block request from P2P network",
		"peer", from,
		"epoch", epoch,
	)

	metrics.DriverPreconfOnEndOfSequencingRequestCounter.Inc()

	hash, ok := s.sequencingEndedForEpochCache.Get(epoch)
	if !ok {
		return fmt.Errorf("failed to find the end of sequencing block for the given epoch: %d", epoch)
	}

	block, err := s.rpc.L2.BlockByHash(ctx, hash)
	if err != nil {
		log.Warn(
			"Failed to fetch the end of sequencing block by hash",
			"peer", from,
			"hash", hash.Hex(),
			"error", err,
		)
		return fmt.Errorf("failed to fetch the end of sequencing block by hash: %w", err)
	}

	l1Origin, err := s.rpc.L2.L1OriginByID(ctx, block.Number())
	if err != nil {
		log.Warn(
			"Failed to fetch L1 origin for the block",
			"peer", from,
			"blockID", block.NumberU64(),
			"hash", block.Hash().Hex(),
			"error", err,
		)
		return fmt.Errorf("failed to fetch L1 origin for the block: %w", err)
	}

	sig := l1Origin.Signature

	endOfSequencing := true
	envelope, err := blockToEnvelope(block, &endOfSequencing, &l1Origin.IsForcedInclusion, &sig)
	if err != nil {
		return fmt.Errorf("failed to convert the end of sequencing block to envelope: %w", err)
	}

	log.Info(
		"Publish end of sequencing preconfirmation block response",
		"peer", from,
		"epoch", epoch,
		"blockID", block.NumberU64(),
		"hash", hash.Hex(),
	)

	if err := s.p2pNode.GossipOut().PublishL2RequestResponse(ctx, envelope, s.p2pSigner); err != nil {
		log.Warn(
			"Failed to publish end of sequencing preconfirmation block response",
			"peer", from,
			"error", err,
			"epoch", epoch,
			"blockID", uint64(envelope.ExecutionPayload.BlockNumber),
			"hash", hash.Hex(),
		)
	}

	s.tryPutEnvelopeIntoCache(envelope, from)

	return nil
}

// ImportMissingAncientsFromCache tries to import cached envelopes from the cached payload queue, if we can't
// find all the missing ancients and import them, an error will be returned.
func (s *PreconfBlockAPIServer) ImportMissingAncientsFromCache(
	ctx context.Context,
	currentPayload *preconf.Envelope,
	headL1Origin *rawdb.L1Origin,
) error {
	var headL1OriginBlockId uint64
	if headL1Origin != nil {
		headL1OriginBlockId = headL1Origin.BlockID.Uint64()
	}

	log.Debug(
		"Importing missing ancients from the cache",
		"blockID", uint64(currentPayload.Payload.BlockNumber),
		"hash", currentPayload.Payload.BlockHash.Hex(),
		"headL1OriginBlockID", headL1OriginBlockId,
	)

	// Try searching the missing ancients in the cache.
	payloadsToImport := make([]*preconf.Envelope, 0)
	for {
		if headL1Origin != nil && currentPayload.Payload.ParentHash == headL1Origin.L2BlockHash {
			log.Debug(
				"Reached canonical chain head, skip searching for ancients in cache",
				"currentNumber", uint64(currentPayload.Payload.BlockNumber),
				"currentHash", currentPayload.Payload.ParentHash.Hex(),
			)
			break
		}

		parentNum := uint64(currentPayload.Payload.BlockNumber - 1)
		parentPayload := s.envelopesCache.get(parentNum, currentPayload.Payload.ParentHash)
		if parentPayload == nil {
			// If the parent payload is not found in the cache and chain is not syncing,
			// we publish a request to the P2P network.
			if !s.blockRequestsCache.Contains(currentPayload.Payload.ParentHash) {
				progress, err := s.rpc.L2ExecutionEngineSyncProgress(ctx)
				if err != nil {
					return fmt.Errorf("failed to get L2 execution engine sync progress: %w", err)
				}

				if progress.IsSyncing() {
					log.Debug("Parent payload not in the cache, but the node is syncing, skip publishing L2Request")
					return nil
				}

				publishRequest := func() {
					log.Info(
						"Publishing preconfirmation block request",
						"blockID", parentNum,
						"hash", currentPayload.Payload.ParentHash.Hex(),
					)

					if err := s.p2pNode.GossipOut().PublishL2Request(ctx, currentPayload.Payload.ParentHash); err != nil {
						log.Warn(
							"Failed to publish preconfirmation block request",
							"blockID", parentNum,
							"hash", currentPayload.Payload.BlockHash.Hex(),
							"error", err,
						)
					} else {
						s.blockRequestsCache.Add(currentPayload.Payload.ParentHash, struct{}{})
					}
				}

				tip := progress.HighestOriginBlockID.Uint64()

				if tip >= requestSyncMargin && parentNum <= tip-requestSyncMargin {
					log.Debug(
						"Skipping request for very old block",
						"tip", tip,
						"margin", requestSyncMargin,
					)
				} else {
					publishRequest()
				}
			}

			return fmt.Errorf(
				"failed to find parent payload in the cache, number %d, hash %s",
				currentPayload.Payload.BlockNumber-1,
				currentPayload.Payload.ParentHash.Hex(),
			)
		}

		payloadsToImport = append([]*preconf.Envelope{
			parentPayload,
		}, payloadsToImport...)
		s.blockRequestsCache.Remove(parentPayload.Payload.BlockHash)

		// Check if the found parent payload is in the canonical chain,
		// if it is not, continue to find the parent payload.
		parentHeader, err := s.rpc.L2.HeaderByNumber(ctx, new(big.Int).SetUint64(uint64(parentPayload.Payload.BlockNumber)))
		if err != nil && !errors.Is(err, ethereum.NotFound) {
			return fmt.Errorf("failed to fetch parent header: %w", err)
		}

		if parentHeader == nil || parentHeader.Hash() != parentPayload.Payload.BlockHash {
			log.Debug(
				"Parent block not in L2 canonical chain, continue to search cached envelopes",
				"blockID", uint64(parentPayload.Payload.BlockNumber),
				"hash", parentPayload.Payload.BlockHash.Hex(),
			)
			if headL1Origin != nil && uint64(parentPayload.Payload.BlockNumber) <= headL1Origin.BlockID.Uint64() {
				return fmt.Errorf(
					"missing parent block ID (%d) is less than or equal to the current head L1 origin block ID (%d)",
					parentPayload.Payload.BlockNumber,
					headL1Origin.BlockID,
				)
			}
			currentPayload = parentPayload
			continue
		}

		break
	}

	log.Info(
		"Found all missing ancient envelopes in the cache, start importing",
		"count", len(payloadsToImport),
		"startBlockID", uint64(payloadsToImport[0].Payload.BlockNumber),
		"startBlockHash", payloadsToImport[0].Payload.BlockHash.Hex(),
		"endBlockID", uint64(payloadsToImport[len(payloadsToImport)-1].Payload.BlockNumber),
		"endBlockHash", payloadsToImport[len(payloadsToImport)-1].Payload.BlockHash.Hex(),
	)

	// If all ancient envelopes are found, try to import them.
	if _, err := s.insertPreconfBlocksFromEnvelopes(ctx, payloadsToImport, true); err != nil {
		return fmt.Errorf("failed to insert ancient preconfirmation blocks from cache: %w", err)
	}

	metrics.DriverImportedPreconBlocksFromCacheCounter.Add(float64(len(payloadsToImport)))

	return nil
}

// ImportChildBlocksFromCache tries to import the longest cached child envelopes from the cached payload queue.
func (s *PreconfBlockAPIServer) ImportChildBlocksFromCache(
	ctx context.Context,
	currentPayload *preconf.Envelope,
) error {
	// Try searching if there is any available child block in the cache.
	childPayloads := s.envelopesCache.getChildren(
		uint64(currentPayload.Payload.BlockNumber),
		currentPayload.Payload.BlockHash,
	)
	if len(childPayloads) == 0 {
		return nil
	}

	endBlockID := uint64(childPayloads[len(childPayloads)-1].Payload.BlockNumber)
	log.Info(
		"Found available child envelopes in the cache, start importing",
		"count", len(childPayloads),
		"startBlockID", uint64(childPayloads[0].Payload.BlockNumber),
		"startBlockHash", childPayloads[0].Payload.BlockHash.Hex(),
		"endBlockID", endBlockID,
		"endBlockHash", childPayloads[len(childPayloads)-1].Payload.BlockHash.Hex(),
	)

	// Try to import all available child envelopes.
	if _, err := s.insertPreconfBlocksFromEnvelopes(ctx, childPayloads, true); err != nil {
		return fmt.Errorf("failed to insert child preconfirmation blocks from cache: %w", err)
	}

	s.updateHighestUnsafeL2Payload(endBlockID)

	metrics.DriverImportedPreconBlocksFromCacheCounter.Add(float64(len(childPayloads)))

	return nil
}

// ValidateExecutionPayload validates the execution payload.
func (s *PreconfBlockAPIServer) ValidateExecutionPayload(payload *eth.ExecutionPayload) error {
	if payload.BlockNumber < eth.Uint64Quantity(s.rpc.PacayaClients.ForkHeights.Pacaya) {
		return fmt.Errorf(
			"block number %d is less than the Pacaya fork height %d",
			payload.BlockNumber,
			s.rpc.PacayaClients.ForkHeights.Pacaya,
		)
	}
	if payload.Timestamp == 0 {
		return errors.New("non-zero timestamp is required")
	}
	if payload.FeeRecipient == (common.Address{}) {
		return errors.New("empty L2 fee recipient")
	}
	if payload.GasLimit == 0 {
		return errors.New("non-zero gas limit is required")
	}
	u256BaseFee := uint256.Int(payload.BaseFeePerGas)
	if u256BaseFee.ToBig().Cmp(common.Big0) == 0 {
		return errors.New("non-zero base fee per gas is required")
	}
	if len(payload.ExtraData) == 0 {
		return errors.New("empty extra data")
	}
	if len(payload.Transactions) != 1 {
		return fmt.Errorf("only one transaction list is allowed")
	}
	if len(payload.Transactions[0]) > (eth.MaxBlobDataSize * eth.MaxBlobsPerBlobTx) {
		return errors.New("compressed transactions size exceeds max blob data size")
	}

	var txs types.Transactions
	b, err := utils.Decompress(payload.Transactions[0])
	if err != nil {
		return fmt.Errorf("invalid zlib bytes for transactions: %w", err)
	}

	if err := rlp.DecodeBytes(b, &txs); err != nil {
		return fmt.Errorf("invalid RLP bytes for transactions: %w", err)
	}
	if len(txs) == 0 {
		return errors.New("empty transactions list, missing anchor transaction")
	}

	if err := s.anchorValidator.ValidateAnchorTx(txs[0]); err != nil {
		return fmt.Errorf("invalid anchor transaction: %w", err)
	}

	log.Debug(
		"Decoded transactions list for preconfirmation block",
		"transactions", len(txs),
		"blockID", uint64(payload.BlockNumber),
		"blockHash", payload.BlockHash.Hex(),
		"parentHash", payload.ParentHash.Hex(),
		"timestamp", uint64(payload.Timestamp),
		"coinbase", payload.FeeRecipient.Hex(),
	)

	return nil
}

// ImportPendingBlocksFromCache tries to insert pending blocks from the cache,
// if there is no payload in the cache, it will skip the operation.
func (s *PreconfBlockAPIServer) ImportPendingBlocksFromCache(ctx context.Context) error {
	latestPayload := s.envelopesCache.getLatestEnvelope()
	if latestPayload == nil {
		log.Info("No envelopes in cache, skip importing from cache")
		return nil
	}

	log.Info(
		"Found pending envelopes in the cache, try importing",
		"latestPayloadNumber", uint64(latestPayload.Payload.BlockNumber),
		"latestPayloadBlockHash", latestPayload.Payload.BlockHash.Hex(),
		"latestPayloadParentHash", latestPayload.Payload.ParentHash.Hex(),
	)

	return s.OnUnsafeL2Payload(ctx, "", &eth.ExecutionPayloadEnvelope{
		ExecutionPayload:  latestPayload.Payload,
		Signature:         latestPayload.Signature,
		IsForcedInclusion: &latestPayload.IsForcedInclusion,
	})
}

// P2PSequencerAddress implements the p2p.GossipRuntimeConfig interface.
func (s *PreconfBlockAPIServer) P2PSequencerAddress() common.Address {
	operatorAddress, err := s.rpc.GetPreconfWhiteListOperator(nil)
	if err != nil || operatorAddress == (common.Address{}) {
		log.Debug("Failed to get current preconfirmation whitelist operator address", "error", err)
		return common.Address{}
	}

	log.Debug("Current operator address for epoch as P2P sequencer", "address", operatorAddress.Hex())

	return operatorAddress
}

// P2PSequencerAddresses implements the p2p.PreconfGossipRuntimeConfig interface.
func (s *PreconfBlockAPIServer) P2PSequencerAddresses() []common.Address {
	s.lookaheadMutex.Lock()
	defer s.lookaheadMutex.Unlock()

	log.Debug(
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
func (s *PreconfBlockAPIServer) UpdateLookahead(lookahead *Lookahead) {
	s.lookaheadMutex.Lock()
	defer s.lookaheadMutex.Unlock()

	s.lookahead = lookahead
}

// GetLookahead updates the lookahead information.
func (s *PreconfBlockAPIServer) GetLookahead() *Lookahead {
	s.lookaheadMutex.Lock()
	defer s.lookaheadMutex.Unlock()

	return s.lookahead
}

// CheckLookaheadHandover returns nil if feeRecipient is allowed to build at slot globalSlot (absolute L1 slot).
// and checks the handover window to see if we need to request the end of sequencing
// block.
func (s *PreconfBlockAPIServer) CheckLookaheadHandover(feeRecipient common.Address, globalSlot uint64) error {
	s.lookaheadMutex.Lock()
	defer s.lookaheadMutex.Unlock()

	if s.lookahead == nil || s.rpc.L1Beacon == nil {
		log.Warn("Lookahead information not initialized, allowing by default")
		return nil
	}

	// Check if the fee recipient is the current operator.
	for _, r := range s.lookahead.CurrRanges {
		if globalSlot >= r.Start && globalSlot < r.End {
			return nil
		}
	}

	// Check if the fee recipient is the next operator.
	for _, r := range s.lookahead.NextRanges {
		if globalSlot >= r.Start && globalSlot < r.End {
			return nil
		}
	}

	// If not in any range, we returns an error.
	log.Debug(
		"Slot out of sequencing window",
		"slot", globalSlot,
		"currRanges", s.lookahead.CurrRanges,
		"nextRanges", s.lookahead.NextRanges,
	)

	if feeRecipient == s.lookahead.CurrOperator {
		return errInvalidCurrOperator
	}

	return errInvalidNextOperator
}

// PutPayloadsCache puts the given payload into the payload cache queue, should ONLY be used in testing.
func (s *PreconfBlockAPIServer) PutPayloadsCache(id uint64, payload *preconf.Envelope) {
	s.envelopesCache.put(id, payload)
}

// GetSequencingEndedForEpoch returns the last block's hash for the given epoch.
func (s *PreconfBlockAPIServer) GetSequencingEndedForEpoch(epoch uint64) (common.Hash, bool) {
	return s.sequencingEndedForEpochCache.Get(epoch)
}

// LatestSeenProposalEventLoop is a goroutine that listens for the latest seen proposal events
func (s *PreconfBlockAPIServer) LatestSeenProposalEventLoop(ctx context.Context) {
	ticker := time.NewTicker(monitorLatestProposalOnChainInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			log.Info("Stopping latest batch seen event loop")
			return
		case proposal := <-s.latestSeenProposalCh:
			if proposal.IsPacaya() {
				s.recordLatestSeenProposalPacaya(proposal)
			} else {
				s.recordLatestSeenProposalShasta(proposal)
			}
		case <-ticker.C:
			s.monitorLatestProposalOnChain(ctx)
		}
	}
}

// monitorLatestProposalOnChain refreshes the latest proposal from L1 if the cached proposal reorgs.
func (s *PreconfBlockAPIServer) monitorLatestProposalOnChain(ctx context.Context) {
	proposal := s.latestSeenProposal
	if proposal == nil {
		return
	}

	if proposal.IsPacaya() {
		s.monitorPacayaProposalOnChain(ctx, proposal)
	} else {
		s.monitorShastaProposalOnChain(ctx, proposal)
	}
}

// monitorPacayaProposalOnChain monitors Pacaya proposals for reorgs.
func (s *PreconfBlockAPIServer) monitorPacayaProposalOnChain(ctx context.Context, proposal *encoding.LastSeenProposal) {
	stateVars, err := s.rpc.GetProtocolStateVariablesPacaya(&bind.CallOpts{Context: ctx})
	if err != nil {
		log.Error("Failed to get states from Pacaya Inbox", "error", err)
		return
	}

	numBatches := stateVars.Stats2.NumBatches
	if numBatches == 0 {
		return
	}

	latestSeenBatchID := proposal.Pacaya().GetBatchID()
	latestOnChainBatchID := new(big.Int).SetUint64(numBatches - 1)
	if latestSeenBatchID.Cmp(latestOnChainBatchID) <= 0 {
		return
	}

	iterPacaya, err := s.rpc.PacayaClients.TaikoInbox.FilterBatchProposed(
		&bind.FilterOpts{Start: stateVars.Stats2.LastProposedIn.Uint64(), Context: ctx},
	)
	if err != nil {
		log.Error("Failed to filter batch proposed event", "err", err)
		return
	}
	defer iterPacaya.Close()

	for iterPacaya.Next() {
		if new(big.Int).SetUint64(iterPacaya.Event.Meta.BatchId).Cmp(s.latestSeenProposal.Pacaya().GetBatchID()) < 0 {
			s.recordLatestSeenProposalPacaya(&encoding.LastSeenProposal{
				TaikoProposalMetaData: metadata.NewTaikoDataBlockMetadataPacaya(iterPacaya.Event),
				PreconfChainReorged:   true,
				LastBlockID:           iterPacaya.Event.Info.LastBlockId,
			})
		}
	}

	if err := iterPacaya.Error(); err != nil {
		log.Error("Failed to iterate batch proposed events", "err", err)
	}
}

// monitorShastaProposalOnChain monitors Shasta proposals for reorgs.
func (s *PreconfBlockAPIServer) monitorShastaProposalOnChain(ctx context.Context, proposal *encoding.LastSeenProposal) {
	header, err := s.rpc.L1.HeaderByNumber(ctx, proposal.GetRawBlockHeight())
	if err != nil {
		log.Error("Failed to get L1 header for shasta proposal", "blockNumber", proposal.GetRawBlockHeight(), "err", err)
		return
	}
	// Check for reorg and handle it
	if header.Hash() != proposal.GetRawBlockHash() {
		s.handleShastaProposalReorg(ctx, proposal.GetProposalID())
	}
}

// handleShastaProposalReorg handles reorg detection for Shasta proposals.
func (s *PreconfBlockAPIServer) handleShastaProposalReorg(ctx context.Context, latestSeenProposalID *big.Int) {
	log.Warn("Shasta proposal reorg detected", "latestSeenProposalID", latestSeenProposalID)

	coreState, err := s.rpc.GetCoreStateShasta(&bind.CallOpts{Context: ctx})
	if err != nil {
		log.Error("Failed to get core state from Shasta Inbox", "err", err)
		return
	}

	recordedProposal, eventLog, err := s.rpc.GetProposalByIDShasta(
		ctx,
		new(big.Int).Sub(coreState.NextProposalId, common.Big1),
	)
	if err != nil {
		log.Error(
			"Proposal not found in cache",
			"proposalId", new(big.Int).Sub(coreState.NextProposalId, common.Big1),
			"err", err,
		)
		return
	}

	blockID, err := s.rpc.L2.LastBlockIDByBatchID(ctx, recordedProposal.Id)
	if err != nil {
		log.Error(
			"Failed to get last block in batch for shasta proposal",
			"proposalId", recordedProposal.Id,
			"err", err,
		)
		return
	}

	header, err := s.rpc.L1.HeaderByHash(ctx, eventLog.BlockHash)
	if err != nil {
		log.Error(
			"Failed to get L1 header for shasta proposal event",
			"proposalId", recordedProposal.Id,
			"blockHash", eventLog.BlockHash.Hex(),
			"err", err,
		)
		return
	}

	s.recordLatestSeenProposalShasta(&encoding.LastSeenProposal{
		TaikoProposalMetaData: metadata.NewTaikoProposalMetadataShasta(
			&shastaBindings.ShastaInboxClientProposed{
				Id:                             recordedProposal.Id,
				Proposer:                       recordedProposal.Proposer,
				EndOfSubmissionWindowTimestamp: recordedProposal.EndOfSubmissionWindowTimestamp,
				BasefeeSharingPctg:             recordedProposal.BasefeeSharingPctg,
				Sources:                        recordedProposal.Sources,
				Raw:                            recordedProposal.Raw,
			},
			header.Time,
		),
		PreconfChainReorged: true,
		LastBlockID:         blockID.Uint64(),
	})
}

// recordLatestSeenProposalPacaya records the latest seen proposal.
func (s *PreconfBlockAPIServer) recordLatestSeenProposalPacaya(proposal *encoding.LastSeenProposal) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	log.Info(
		"Received latest pacaya proposal seen in event",
		"batchID", proposal.Pacaya().GetBatchID(),
		"lastBlockID", proposal.LastBlockID,
	)

	s.latestSeenProposal = proposal
	metrics.DriverLastSeenBlockInProposalGauge.Set(float64(proposal.LastBlockID))

	// If the latest seen proposal is reorged, reset the highest unsafe L2 payload block ID.
	if s.latestSeenProposal.PreconfChainReorged {
		s.highestUnsafeL2PayloadBlockID = proposal.LastBlockID
		log.Info(
			"Latest block ID seen in event is reorged, reset the highest unsafe L2 payload block ID",
			"batchID", proposal.Pacaya().GetBatchID(),
			"lastBlockID", s.highestUnsafeL2PayloadBlockID,
			"highestUnsafeL2PayloadBlockID", s.highestUnsafeL2PayloadBlockID,
		)
		metrics.DriverReorgsByProposalCounter.Inc()
	}
}

// recordLatestSeenProposalShasta records the latest seen proposal.
func (s *PreconfBlockAPIServer) recordLatestSeenProposalShasta(proposal *encoding.LastSeenProposal) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	log.Info(
		"Received latest shasta proposal seen in event",
		"proposalId", proposal.Shasta().GetEventData().Id,
		"lastBlockId", proposal.LastBlockID,
	)

	s.latestSeenProposal = proposal

	if proposal.LastBlockID != 0 {
		metrics.DriverLastSeenBlockInProposalGauge.Set(float64(proposal.LastBlockID))
	}

	// If the latest seen proposal is reorged, reset the highest unsafe L2 payload block ID.
	if s.latestSeenProposal.PreconfChainReorged {
		s.highestUnsafeL2PayloadBlockID = proposal.LastBlockID
		log.Info(
			"Latest block ID seen in event is reorged, reset the highest unsafe L2 payload block ID",
			"proposalId", proposal.Shasta().GetEventData().Id,
			"highestUnsafeL2PayloadBlockID", s.highestUnsafeL2PayloadBlockID,
		)

		metrics.DriverReorgsByProposalCounter.Inc()
	}
}

// TryImportingPayload tries to import the given payload into the L2 EE chain.
// If the parent block is not in the canonical chain, it will try to find all the missing ancients from the cache
// and import them. If it can't find all the missing ancients, it will cache the payload.
// If the block already exists in the canonical chain, it will ignore the message.
func (s *PreconfBlockAPIServer) TryImportingPayload(
	ctx context.Context,
	headL1Origin *rawdb.L1Origin,
	msg *eth.ExecutionPayloadEnvelope,
	from peer.ID,
) (bool, error) {
	// Check if the parent block is in the canonical chain, if not, we try to
	// find all the missing ancients from the cache and import them, if we can't, then we cache the message.
	parentInCanonical, err := s.rpc.L2.HeaderByNumber(
		ctx,
		new(big.Int).SetUint64(uint64(msg.ExecutionPayload.BlockNumber-1)),
	)
	if err != nil && !errors.Is(err, ethereum.NotFound) {
		return false, fmt.Errorf("failed to fetch parent header by number: %w", err)
	}
	cachedParent := s.envelopesCache.get(
		uint64(msg.ExecutionPayload.BlockNumber-1),
		msg.ExecutionPayload.ParentHash,
	)

	isOrphan := parentInCanonical != nil &&
		parentInCanonical.Hash() != msg.ExecutionPayload.ParentHash

	if isOrphan {
		log.Info(
			"Block is building on an orphaned block",
			"peer", from,
			"blockID", uint64(msg.ExecutionPayload.BlockNumber),
			"hash", msg.ExecutionPayload.BlockHash.Hex(),
			"parentHash", msg.ExecutionPayload.ParentHash.Hex(),
			"parentInCanonicalHash", parentInCanonical.Hash().Hex(),
		)

		// Update L1 Origin for the parent being reorged out using cached data.
		var (
			payloadID engine.PayloadID
			parentID  *big.Int
		)

		if cachedParent != nil {
			if len(cachedParent.Payload.Transactions) == 0 {
				return false, fmt.Errorf("cached parent envelope has empty transactions: %s", msg.ExecutionPayload.ParentHash.Hex())
			}
			decompressedTxs, err := utils.Decompress(cachedParent.Payload.Transactions[0])
			if err != nil {
				return false, fmt.Errorf("failed to decompress cached parent tx list: %w", err)
			}
			txListHash := crypto.Keccak256Hash(decompressedTxs)
			args := &miner.BuildPayloadArgs{
				Parent:       cachedParent.Payload.ParentHash,
				Timestamp:    uint64(cachedParent.Payload.Timestamp),
				FeeRecipient: cachedParent.Payload.FeeRecipient,
				Random:       common.Hash(cachedParent.Payload.PrevRandao),
				Withdrawals:  make([]*types.Withdrawal, 0),
				Version:      engine.PayloadV2,
				TxListHash:   &txListHash,
			}
			payloadID = args.Id()
			parentID = new(big.Int).SetUint64(uint64(cachedParent.Payload.BlockNumber))

			var sig [65]byte
			if cachedParent.Signature != nil {
				sig = *cachedParent.Signature
			}

			// Update L1 Origin for the parent block via cached data.
			if _, err := s.rpc.L2Engine.UpdateL1Origin(ctx, &rawdb.L1Origin{
				BuildPayloadArgsID: payloadID,
				BlockID:            parentID,
				L2BlockHash:        msg.ExecutionPayload.ParentHash,
				IsForcedInclusion:  cachedParent.IsForcedInclusion,
				Signature:          sig,
			}); err != nil {
				return false, fmt.Errorf("failed to update L1 origin: %w", err)
			}

			log.Info("Updated L1 Origin for orphan parent via cache",
				"peer", from,
				"parentID", parentID,
				"parentHash", msg.ExecutionPayload.ParentHash.Hex(),
				"signature", common.Bytes2Hex(sig[:]),
			)
		} else {
			log.Warn("Orphan parent detected but not found in cache; skipping L1Origin update",
				"peer", from,
				"blockID", uint64(msg.ExecutionPayload.BlockNumber),
				"parentHash", msg.ExecutionPayload.ParentHash.Hex(),
			)
		}
	}

	// If the parent is not in the canonical chain at N-1, try to import ancients from cache
	if parentInCanonical == nil || parentInCanonical.Hash() != msg.ExecutionPayload.ParentHash {
		log.Info(
			"Parent block not in L2 canonical / fork chain",
			"peer", from,
			"blockID", uint64(msg.ExecutionPayload.BlockNumber),
			"hash", msg.ExecutionPayload.BlockHash.Hex(),
			"parentHash", msg.ExecutionPayload.ParentHash,
		)

		// Try to find all the missing ancients from the cache and import them.
		if err := s.ImportMissingAncientsFromCache(ctx, &preconf.Envelope{
			Payload:           msg.ExecutionPayload,
			Signature:         msg.Signature,
			IsForcedInclusion: msg.IsForcedInclusion != nil && *msg.IsForcedInclusion,
		}, headL1Origin); err != nil {
			log.Info(
				"Unable to find all the missing ancients from the cache, cache the current payload",
				"peer", from,
				"blockID", uint64(msg.ExecutionPayload.BlockNumber),
				"hash", msg.ExecutionPayload.BlockHash.Hex(),
				"parentHash", msg.ExecutionPayload.ParentHash.Hex(),
				"reason", err,
			)

			s.tryPutEnvelopeIntoCache(msg, from)

			return true, nil
		}
	}

	// Check if the block already exists in the canonical chain, if it does, we ignore the message.
	header, err := s.rpc.L2.HeaderByNumber(ctx, new(big.Int).SetUint64(uint64(msg.ExecutionPayload.BlockNumber)))
	if err != nil && !errors.Is(err, ethereum.NotFound) {
		return false, fmt.Errorf("failed to fetch header by hash: %w", err)
	}

	if header != nil {
		if header.Hash() == msg.ExecutionPayload.BlockHash {
			log.Info(
				"Preconfirmation block already exists",
				"peer", from,
				"blockID", uint64(msg.ExecutionPayload.BlockNumber),
				"hash", msg.ExecutionPayload.BlockHash.Hex(),
				"parentHash", msg.ExecutionPayload.ParentHash.Hex(),
			)
			return true, nil
		} else {
			log.Info(
				"Preconfirmation block already exists with different hash",
				"peer", from,
				"blockID", uint64(msg.ExecutionPayload.BlockNumber),
				"hash", msg.ExecutionPayload.BlockHash.Hex(),
				"parentHash", msg.ExecutionPayload.ParentHash.Hex(),
				"headerHash", header.Hash().Hex(),
				"headerParentHash", header.ParentHash.Hex(),
			)
		}
	}

	// Insert the preconfirmation block into the L2 EE chain.
	if _, err := s.insertPreconfBlocksFromEnvelopes(
		ctx,
		[]*preconf.Envelope{
			{
				Payload:           msg.ExecutionPayload,
				Signature:         msg.Signature,
				IsForcedInclusion: msg.IsForcedInclusion != nil && *msg.IsForcedInclusion,
			},
		},
		false,
	); err != nil {
		return false, fmt.Errorf("failed to insert preconfirmation block from P2P network: %w", err)
	}

	// If the block number is greater than the highest unsafe L2 payload block ID,
	// update the highest unsafe L2 payload block ID.
	if uint64(msg.ExecutionPayload.BlockNumber) > s.highestUnsafeL2PayloadBlockID {
		s.updateHighestUnsafeL2Payload(uint64(msg.ExecutionPayload.BlockNumber))
	}

	// If the block number is less than or equal to the highest unsafe L2 payload block ID,
	// we also need to update the highest unsafe L2 payload block ID.
	if header != nil && uint64(msg.ExecutionPayload.BlockNumber) <= header.Number.Uint64() {
		log.Info(
			"Preconfirmation block is reorging",
			"blockID", uint64(msg.ExecutionPayload.BlockNumber),
			"hash", msg.ExecutionPayload.BlockHash.Hex(),
			"parentHash", msg.ExecutionPayload.ParentHash.Hex(),
			"headerHash", header.Hash().Hex(),
			"headerParentHash", header.ParentHash.Hex(),
		)
		s.updateHighestUnsafeL2Payload(uint64(msg.ExecutionPayload.BlockNumber))
	}

	// Try to import the child blocks from the cache, if any.
	if err := s.ImportChildBlocksFromCache(ctx, &preconf.Envelope{
		Payload:           msg.ExecutionPayload,
		Signature:         msg.Signature,
		IsForcedInclusion: msg.IsForcedInclusion != nil && *msg.IsForcedInclusion,
	}); err != nil {
		return false, fmt.Errorf("failed to try importing child blocks from cache: %w", err)
	}

	return false, nil
}

// updateHighestUnsafeL2Payload updates the highest unsafe L2 payload block ID.
func (s *PreconfBlockAPIServer) updateHighestUnsafeL2Payload(blockID uint64) {
	if blockID > s.highestUnsafeL2PayloadBlockID {
		log.Info(
			"Updating highest unsafe L2 payload block ID",
			"blockID", blockID,
			"currentHighestUnsafeL2PayloadBlockID", s.highestUnsafeL2PayloadBlockID,
		)
	} else {
		log.Info(
			"Reorging highest unsafe L2 payload blockID",
			"blockID", blockID,
			"currentHighestUnsafeL2PayloadBlockID", s.highestUnsafeL2PayloadBlockID,
		)
	}
	s.highestUnsafeL2PayloadBlockID = blockID
	metrics.DriverHighestPreconfUnsafePayloadGauge.Set(float64(blockID))
}

// tryPutEnvelopeIntoCache tries to put the given payload into the cache, if it is not already cached.
func (s *PreconfBlockAPIServer) tryPutEnvelopeIntoCache(msg *eth.ExecutionPayloadEnvelope, from peer.ID) {
	id := uint64(msg.ExecutionPayload.BlockNumber)
	h := msg.ExecutionPayload.BlockHash
	if s.envelopesCache.hasExact(id, h) {
		return
	}

	log.Info(
		"Envelope is cached",
		"peer", from,
		"blockID", id,
		"blockHash", h.Hex(),
		"parentHash", msg.ExecutionPayload.ParentHash.Hex(),
	)

	s.envelopesCache.put(id, &preconf.Envelope{
		Payload:           msg.ExecutionPayload,
		Signature:         msg.Signature,
		IsForcedInclusion: msg.IsForcedInclusion != nil && *msg.IsForcedInclusion,
	})
}

// insertPreconfBlocksFromEnvelopes inserts the given preconfirmation block envelopes into the L2 EE chain,
// splitting them into Pacaya and Shasta batches based on the fork height.
func (s *PreconfBlockAPIServer) insertPreconfBlocksFromEnvelopes(
	ctx context.Context,
	envelopes []*preconf.Envelope,
	fromCache bool,
) ([]*types.Header, error) {
	if len(envelopes) == 0 {
		return []*types.Header{}, nil
	}

	var (
		pacayaBatch, shastaBatch = s.splitEnvelopesByFork(envelopes)
		pacayaHeaders            = make([]*types.Header, 0)
		shastaHeaders            = make([]*types.Header, 0)
		result                   []*types.Header
		err                      error
	)

	if len(pacayaBatch) != 0 {
		if pacayaHeaders, err = s.pacayaChainSyncer.InsertPreconfBlocksFromEnvelopes(
			ctx,
			pacayaBatch,
			fromCache,
		); err != nil {
			return nil, err
		}
	}

	if len(shastaBatch) != 0 {
		if shastaHeaders, err = s.shastaChainSyncer.InsertPreconfBlocksFromEnvelopes(
			ctx,
			shastaBatch,
			fromCache,
		); err != nil {
			return nil, err
		}
	}

	result = append(result, pacayaHeaders...)
	result = append(result, shastaHeaders...)
	return result, nil
}

// splitEnvelopesByFork splits the given envelopes into two batches, one for Pacaya and one for Shasta,
// based on the fork height.
func (s *PreconfBlockAPIServer) splitEnvelopesByFork(
	envelopes []*preconf.Envelope,
) (pacaya []*preconf.Envelope, shasta []*preconf.Envelope) {
	pacaya = []*preconf.Envelope{}
	shasta = []*preconf.Envelope{}

	for _, envelope := range envelopes {
		if uint64(envelope.Payload.Timestamp) < s.rpc.ShastaClients.ForkTime {
			pacaya = append(pacaya, envelope)
			continue
		}

		shasta = append(shasta, envelope)
	}

	return pacaya, shasta
}

// webSocketSever is a WebSocket server that handles incoming connections,
// upgrades them to WebSocket connections, and pushes new sequencingEndedForEpoch notifications.
type webSocketSever struct {
	rpc     *rpc.Client
	clients map[*websocket.Conn]struct{}
	mutex   sync.Mutex
}

// handleWebSocket handles the WebSocket connection, upgrades the connection
// to a WebSocket connection, and starts pushing new sequencingEndedForEpoch notification.
func (s *webSocketSever) handleWebSocket(c echo.Context) error {
	// Upgrade the connection to a WebSocket connection, and
	// record the client connection for later publication.
	conn, err := wsUpgrader.Upgrade(c.Response(), c.Request(), nil)
	if err != nil {
		return fmt.Errorf("failed to upgrade WebSocket connection: %w", err)
	}
	s.recordClient(conn)

	defer func() {
		s.releaseClient(conn)
		conn.Close()
	}()

	// Keep reading until the client disconnects.
	for {
		if _, _, err := conn.ReadMessage(); err != nil {
			// ReadMessage will return an error when the client hangs up.
			break
		}
	}
	return nil
}

// recordClient records the given WebSocket client connection.
func (s *webSocketSever) recordClient(conn *websocket.Conn) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	s.clients[conn] = struct{}{}
}

// releaseClient releases the given WebSocket client connection.
func (s *webSocketSever) releaseClient(conn *websocket.Conn) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	delete(s.clients, conn)
}

// pushEndOfSequencingNotification pushes the end of sequencing notification to all recorded WebSocket clients.
func (s *webSocketSever) pushEndOfSequencingNotification(epoch uint64) {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	for conn := range s.clients {
		if err := conn.WriteJSON(
			map[string]interface{}{"currentEpoch": s.rpc.L1Beacon.CurrentEpoch(), "endOfSequencing": true},
		); err != nil {
			conn.Close()
			delete(s.clients, conn)
		}
	}
}
