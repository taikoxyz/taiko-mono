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
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/holiman/uint256"
	echojwt "github.com/labstack/echo-jwt/v4"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"github.com/libp2p/go-libp2p/core/peer"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
	validator "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/anchor_tx_validator"
)

var (
	errInvalidCurrOperator = errors.New("invalid operator: expected current operator in handover window")
	errInvalidNextOperator = errors.New("invalid operator: expected next operator in handover window")
)

// preconfBlockChainSyncer is an interface for preconf block chain syncer.
type preconfBlockChainSyncer interface {
	InsertPreconfBlocksFromExecutionPayloads(context.Context, []*eth.ExecutionPayload, bool) ([]*types.Header, error)
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
	echo            *echo.Echo
	chainSyncer     preconfBlockChainSyncer
	rpc             *rpc.Client
	anchorValidator *validator.AnchorTxValidator
	// P2P network for preconf block propagation
	p2pNode                       *p2p.NodeP2P
	p2pSigner                     p2p.Signer
	payloadsCache                 *payloadQueue
	lookahead                     *Lookahead
	lookaheadMutex                sync.Mutex
	handoverSlots                 uint64
	highestUnsafeL2PayloadBlockID uint64
}

// New creates a new preconf block server instance, and starts the server.
func New(
	cors string,
	jwtSecret []byte,
	handoverSlots uint64,
	taikoAnchorAddress common.Address,
	chainSyncer preconfBlockChainSyncer,
	cli *rpc.Client,
) (*PreconfBlockAPIServer, error) {
	anchorValidator, err := validator.New(taikoAnchorAddress, cli.L2.ChainID, cli)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize anchor validator: %w", err)
	}

	server := &PreconfBlockAPIServer{
		echo:            echo.New(),
		anchorValidator: anchorValidator,
		chainSyncer:     chainSyncer,
		handoverSlots:   handoverSlots,
		rpc:             cli,
		payloadsCache:   newPayloadQueue(),
		lookahead:       &Lookahead{},
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
	s.echo.GET("/status", s.GetStatus)
	s.echo.POST("/preconfBlocks", s.BuildPreconfBlock)
	s.echo.DELETE("/preconfBlocks", s.RemovePreconfBlocks)
}

// OnUnsafeL2Payload implements the p2p.GossipIn interface.
func (s *PreconfBlockAPIServer) OnUnsafeL2Payload(
	ctx context.Context,
	from peer.ID,
	msg *eth.ExecutionPayloadEnvelope,
) error {
	// Ignore the message if it is from the current P2P node, when `from` is empty,
	// it means the message is for importing the pending blocks from the cache after
	// a new L2 EE chain has just finished a beacon-sync.
	if from != "" && s.p2pNode.Host().ID() == from {
		log.Debug("Ignore the message from the current P2P node", "peer", from)
		return nil
	}

	if msg == nil || msg.ExecutionPayload == nil {
		log.Warn("Empty preconfirmation block payload", "peer", from)
		return nil
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
	)

	metrics.DriverPreconfP2PEnvelopeCounter.Inc()

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
		metrics.DriverPreconfP2PInvalidEnvelopeCounter.Inc()
		return nil
	}

	// Ensure the preconfirmation block number is greater than the current head L1 origin block ID.
	headL1Origin, err := s.rpc.L2.HeadL1Origin(ctx)
	if err != nil && err.Error() != ethereum.NotFound.Error() {
		return fmt.Errorf("failed to fetch head L1 origin: %w", err)
	}
	if headL1Origin != nil && uint64(msg.ExecutionPayload.BlockNumber) <= headL1Origin.BlockID.Uint64() {
		metrics.DriverPreconfP2POutdatedEnvelopeCounter.Inc()
		return fmt.Errorf(
			"preconfirmation block ID (%d) is less than or equal to the current head L1 origin block ID (%d)",
			msg.ExecutionPayload.BlockNumber,
			headL1Origin.BlockID,
		)
	}

	// If the block number is greater than the highest unsafe L2 payload block ID,
	// update the highest unsafe L2 payload block ID.
	if uint64(msg.ExecutionPayload.BlockNumber) > s.highestUnsafeL2PayloadBlockID {
		s.highestUnsafeL2PayloadBlockID = uint64(msg.ExecutionPayload.BlockNumber)
	}

	// Check if the parent block is in the canonical chain, if not, we try to
	// find all the missing ancients from the cache and import them, if we can't, then we cache the message.
	parentInCanonical, err := s.rpc.L2.HeaderByNumber(
		ctx,
		new(big.Int).SetUint64(uint64(msg.ExecutionPayload.BlockNumber-1)),
	)
	if err != nil && !errors.Is(err, ethereum.NotFound) {
		return fmt.Errorf("failed to fetch parent header by number: %w", err)
	}
	parentInFork, err := s.rpc.L2.HeaderByHash(ctx, msg.ExecutionPayload.ParentHash)
	if err != nil && !errors.Is(err, ethereum.NotFound) {
		return fmt.Errorf("failed to fetch parent header by hash: %w", err)
	}
	if parentInFork == nil && (parentInCanonical == nil || parentInCanonical.Hash() != msg.ExecutionPayload.ParentHash) {
		log.Info(
			"Parent block not in L2 canonical / fork chain",
			"peer", from,
			"blockID", uint64(msg.ExecutionPayload.BlockNumber),
			"hash", msg.ExecutionPayload.BlockHash.Hex(),
			"parentHash", msg.ExecutionPayload.ParentHash,
		)
		// Try to find all the missing ancients from the cache and import them.
		if err := s.ImportMissingAncientsFromCache(ctx, msg.ExecutionPayload, headL1Origin); err != nil {
			log.Info(
				"Unable to find all the missing ancients from the cache, cache the current payload",
				"peer", from,
				"blockID", uint64(msg.ExecutionPayload.BlockNumber),
				"hash", msg.ExecutionPayload.BlockHash.Hex(),
				"parentHash", msg.ExecutionPayload.ParentHash.Hex(),
				"reason", err,
			)
			if !s.payloadsCache.has(uint64(msg.ExecutionPayload.BlockNumber), msg.ExecutionPayload.BlockHash) {
				log.Info(
					"Payload is cached",
					"peer", from,
					"blockID", uint64(msg.ExecutionPayload.BlockNumber),
					"blockHash", msg.ExecutionPayload.BlockHash.Hex(),
					"parentHash", msg.ExecutionPayload.ParentHash.Hex(),
				)

				s.payloadsCache.put(uint64(msg.ExecutionPayload.BlockNumber), msg.ExecutionPayload)
				metrics.DriverPreconfP2PEnvelopeCachedCounter.Inc()
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
		if header.Hash() == msg.ExecutionPayload.BlockHash {
			log.Info(
				"Preconfirmation block already exists",
				"peer", from,
				"blockID", uint64(msg.ExecutionPayload.BlockNumber),
				"hash", msg.ExecutionPayload.BlockHash.Hex(),
				"parentHash", msg.ExecutionPayload.ParentHash.Hex(),
			)
			return nil
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
	if _, err := s.chainSyncer.InsertPreconfBlocksFromExecutionPayloads(
		ctx,
		[]*eth.ExecutionPayload{msg.ExecutionPayload},
		false,
	); err != nil {
		return fmt.Errorf("failed to insert preconfirmation block from P2P network: %w", err)
	}

	// Try to import the child blocks from the cache, if any.
	if err := s.ImportChildBlocksFromCache(ctx, msg.ExecutionPayload); err != nil {
		return fmt.Errorf("failed to try importing child blocks from cache: %w", err)
	}

	return nil
}

// ImportMissingAncientsFromCache tries to import cached payloads from the cached payload queue, if we can't
// find all the missing ancients and import them, an error will be returned.
func (s *PreconfBlockAPIServer) ImportMissingAncientsFromCache(
	ctx context.Context,
	currentPayload *eth.ExecutionPayload,
	headL1Origin *rawdb.L1Origin,
) error {
	// Try searching the missing ancients in the cache.
	payloadsToImport := make([]*eth.ExecutionPayload, 0)
	for {
		if headL1Origin != nil && currentPayload.ParentHash == headL1Origin.L2BlockHash {
			log.Debug(
				"Reached canonical chain head, skip searching for ancients in cache",
				"currentNumber", uint64(currentPayload.BlockNumber),
				"currentHash", currentPayload.ParentHash.Hex(),
			)
			break
		}

		parentPayload := s.payloadsCache.get(uint64(currentPayload.BlockNumber)-1, currentPayload.ParentHash)
		if parentPayload == nil {
			return fmt.Errorf(
				"failed to find parent payload in the cache, number %d, hash %s",
				currentPayload.BlockNumber-1,
				currentPayload.ParentHash.Hex(),
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
			log.Debug(
				"Parent block not in L2 canonical chain, continue to search cached payloads",
				"blockID", uint64(parentPayload.BlockNumber),
				"hash", parentPayload.BlockHash.Hex(),
			)
			if headL1Origin != nil && uint64(parentPayload.BlockNumber) <= headL1Origin.BlockID.Uint64() {
				return fmt.Errorf(
					"missing parent block ID (%d) is less than or equal to the current head L1 origin block ID (%d)",
					parentPayload.BlockNumber,
					headL1Origin.BlockID,
				)
			}
			currentPayload = parentPayload
			continue
		}

		break
	}

	log.Info(
		"Found all missing ancient payloads in the cache, start importing",
		"count", len(payloadsToImport),
	)

	// If all ancient payloads are found, try to import them.
	if _, err := s.chainSyncer.InsertPreconfBlocksFromExecutionPayloads(ctx, payloadsToImport, true); err != nil {
		return fmt.Errorf("failed to insert ancient preconfirmation blocks from cache: %w", err)
	}

	return nil
}

// ImportChildBlocksFromCache tries to import the longest cached child payloads from the cached payload queue.
func (s *PreconfBlockAPIServer) ImportChildBlocksFromCache(
	ctx context.Context,
	currentPayload *eth.ExecutionPayload,
) error {
	// Try searching if there is any available child block in the cache.
	childPayloads := s.payloadsCache.getChildren(uint64(currentPayload.BlockNumber), currentPayload.BlockHash)
	if len(childPayloads) == 0 {
		return nil
	}

	log.Info(
		"Found available child payloads in the cache, start importing",
		"count", len(childPayloads),
	)

	// Try to import all available child payloads.
	if _, err := s.chainSyncer.InsertPreconfBlocksFromExecutionPayloads(ctx, childPayloads, true); err != nil {
		return fmt.Errorf("failed to insert child preconfirmation blocks from cache: %w", err)
	}

	return nil
}

// ValidateExecutionPayload validates the execution payload.
func (s *PreconfBlockAPIServer) ValidateExecutionPayload(payload *eth.ExecutionPayload) error {
	if payload.BlockNumber < eth.Uint64Quantity(s.rpc.PacayaClients.ForkHeight) {
		return fmt.Errorf(
			"block number %d is less than the Pacaya fork height %d",
			payload.BlockNumber,
			s.rpc.PacayaClients.ForkHeight,
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
	var u256BaseFee = uint256.Int(payload.BaseFeePerGas)
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
	b, err := utils.DecompressPacaya(payload.Transactions[0])
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

	return nil
}

// ImportPendingBlocksFromCache tries to insert pending blocks from the cache,
// if there is no payload in the cache, it will skip the operation.
func (s *PreconfBlockAPIServer) ImportPendingBlocksFromCache(ctx context.Context) error {
	latestPayload := s.payloadsCache.getLatestPayload()
	if latestPayload == nil {
		log.Info("No payloads in cache, skip importing from cache")
		return nil
	}

	log.Info(
		"Found pending payloads in the cache, try importing",
		"latestPayloadNumber", uint64(latestPayload.BlockNumber),
		"latestPayloadBlockHash", latestPayload.BlockHash.Hex(),
		"latestPayloadParentHash", latestPayload.ParentHash.Hex(),
	)

	return s.OnUnsafeL2Payload(ctx, "", &eth.ExecutionPayloadEnvelope{ExecutionPayload: latestPayload})
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

// checkLookaheadHandover returns nil if feeRecipient is allowed to build at slot globalSlot (absolute L1 slot).
func (s *PreconfBlockAPIServer) checkLookaheadHandover(feeRecipient common.Address, globalSlot uint64) error {
	s.lookaheadMutex.Lock()
	la := s.lookahead
	s.lookaheadMutex.Unlock()

	if la == nil || s.rpc.L1Beacon == nil {
		log.Warn("Lookahead information not initialized, allowing by default")
		return nil
	}

	// Check Current ranges first
	for _, r := range la.CurrRanges {
		if globalSlot >= r.Start && globalSlot < r.End {
			return nil
		}
	}

	for _, r := range la.NextRanges {
		if globalSlot >= r.Start && globalSlot < r.End {
			return nil
		}
	}

	// If not in any range
	log.Warn(
		"Slot out of sequencing window",
		"slot", globalSlot,
		"currRanges", la.CurrRanges,
		"nextRanges", la.NextRanges,
	)

	if feeRecipient == la.CurrOperator {
		return errInvalidCurrOperator
	}

	return errInvalidNextOperator
}

// PutPayloadsCache puts the given payload into the payload cache queue, should ONLY be used in testing.
func (s *PreconfBlockAPIServer) PutPayloadsCache(id uint64, payload *eth.ExecutionPayload) {
	s.payloadsCache.put(id, payload)
}
