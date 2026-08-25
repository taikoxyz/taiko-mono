package preconfblocks

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"time"

	"github.com/ethereum-optimism/optimism/op-node/p2p"
	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/consensus/taiko"
	"github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/holiman/uint256"
	"github.com/labstack/echo/v4"
	"github.com/modern-go/reflect2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/preconf"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// ExecutableData is the data necessary to execute an EL payload.
type ExecutableData struct {
	ParentHash   common.Hash    `json:"parentHash"`
	FeeRecipient common.Address `json:"feeRecipient"`
	Number       uint64         `json:"blockNumber"`
	GasLimit     uint64         `json:"gasLimit"`
	Timestamp    uint64         `json:"timestamp"`
	// Transactions list with RLP encoded at first, then zlib compressed.
	Transactions  hexutil.Bytes `json:"transactions"`
	ExtraData     hexutil.Bytes `json:"extraData"`
	BaseFeePerGas uint64        `json:"baseFeePerGas"`
}

// BuildPreconfBlockRequestBody represents a request body when handling
// preconfirmation blocks creation requests.
type BuildPreconfBlockRequestBody struct {
	// @param ExecutableData engine.ExecutableData the data necessary to execute an EL payload.
	ExecutableData    *ExecutableData `json:"executableData"`
	EndOfSequencing   *bool           `json:"endOfSequencing"`
	IsForcedInclusion *bool           `json:"isForcedInclusion"`
}

// BuildPreconfBlockResponseBody represents a response body when handling preconfirmation
// blocks creation requests.
type BuildPreconfBlockResponseBody struct {
	// @param blockHeader types.Header of the preconfirmation block
	BlockHeader *types.Header `json:"blockHeader"`
}

// BuildPreconfBlock handles a preconfirmation block creation request,
// if the preconfirmation block creation body in request are valid, it will insert the corresponding
// preconfirmation block to the backend L2 execution engine and return a success response.
//
//		@Summary 	    Insert a preconfirmation block to the L2 execution engine.
//		@Description	Insert a preconfirmation block to the L2 execution engine, if the preconfirmation block creation
//		@Description	body in request are valid, it will insert the corresponding
//	 	@Description	preconfirmation block to the backend L2 execution engine and return a success response.
//		@Param  		request body BuildPreconfBlockRequestBody true "preconfirmation block creation request body"
//		@Accept	  	json
//		@Produce	json
//		@Success	200		{object} BuildPreconfBlockResponseBody
//		@Router		/preconfBlocks [post]
func (s *PreconfBlockAPIServer) BuildPreconfBlock(c echo.Context) error {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	start := time.Now()
	defer func() {
		elapsedMs := time.Since(start).Milliseconds()
		metrics.DriverPreconfBuildPreconfBlockDuration.Observe(float64(elapsedMs) / 1_000)
		log.Debug("BuildPreconfBlock completed", "elapsed", fmt.Sprintf("%dms", elapsedMs))
	}()

	// make a new context, we don't want to cancel the request if the caller times out.
	ctx := context.Background()

	// Check if the L2 execution engine is syncing from L1.
	progress, err := s.rpc.L2ExecutionEngineSyncProgress(ctx)
	if err != nil {
		return s.returnError(c, http.StatusBadRequest, err)
	}
	if progress.IsSyncing() {
		return s.returnError(c, http.StatusBadRequest, errors.New("l2 execution engine is syncing"))
	}
	if !s.syncReady {
		return s.returnError(
			c,
			http.StatusBadRequest,
			errors.New("preconfirmation block server is not ready to insert blocks"),
		)
	}

	// Parse the request body.
	reqBody := new(BuildPreconfBlockRequestBody)
	if err := c.Bind(reqBody); err != nil {
		return s.returnError(c, http.StatusUnprocessableEntity, err)
	}
	if reqBody.ExecutableData == nil {
		return s.returnError(c, http.StatusBadRequest, errors.New("executable data is required"))
	}

	parent, err := s.rpc.L2.BlockByHash(ctx, reqBody.ExecutableData.ParentHash)
	if err != nil {
		return s.returnError(c, http.StatusInternalServerError, err)
	}

	if s.latestSeenProposal != nil &&
		s.latestSeenProposal.IsShasta() &&
		bytes.HasPrefix(parent.Transactions()[0].Data(), taiko.AnchorV4Selector) {
		parentProposalID, err := core.DecodeShastaProposalID(parent.Extra())
		if err != nil {
			return s.returnError(c, http.StatusBadRequest, fmt.Errorf("failed to get parent block proposal ID: %w", err))
		}

		latestProposalID := s.latestSeenProposal.Shasta().GetEventData().Id
		if parentProposalID.Cmp(latestProposalID) < 0 {
			log.Warn(
				"The parent block proposal ID is smaller than the latest proposal ID seen in event",
				"parentProposalID", parentProposalID,
				"latestProposalIDSeenInEvent", latestProposalID,
			)

			return s.returnError(c, http.StatusBadRequest,
				fmt.Errorf(
					"latestProposalIDSeenInEvent: %v, parentProposalID: %v",
					latestProposalID,
					parentProposalID,
				),
			)
		}
	}

	var (
		endOfSequencing   = reqBody.EndOfSequencing != nil && *reqBody.EndOfSequencing
		isForcedInclusion = reqBody.IsForcedInclusion != nil && *reqBody.IsForcedInclusion
	)

	log.Info(
		"🏗️ New preconfirmation block building request",
		"blockID", reqBody.ExecutableData.Number,
		"coinbase", reqBody.ExecutableData.FeeRecipient.Hex(),
		"timestamp", reqBody.ExecutableData.Timestamp,
		"gasLimit", reqBody.ExecutableData.GasLimit,
		"baseFeePerGas", utils.WeiToEther(new(big.Int).SetUint64(reqBody.ExecutableData.BaseFeePerGas)),
		"extraData", common.Bytes2Hex(reqBody.ExecutableData.ExtraData),
		"parentHash", reqBody.ExecutableData.ParentHash.Hex(),
		"endOfSequencing", endOfSequencing,
		"isForcedInclusion", isForcedInclusion,
	)

	// Check that the current L1 slot falls inside this operator's sequencing window
	// (current or next, covering the handover window).
	if s.rpc.L1Beacon != nil {
		if err := s.CheckLookaheadHandover(s.rpc.L1Beacon.CurrentSlot()); err != nil {
			return s.returnError(c, http.StatusBadRequest, err)
		}
	}

	mixHash, err := encoding.CalculateShastaMixHash(
		parent.Difficulty(),
		new(big.Int).SetUint64(reqBody.ExecutableData.Number),
	)
	if err != nil {
		return s.returnError(c, http.StatusBadRequest, err)
	}

	baseFee, overflow := uint256.FromBig(new(big.Int).SetUint64(reqBody.ExecutableData.BaseFeePerGas))
	if overflow {
		return s.returnError(c, http.StatusBadRequest, errors.New("base fee per gas is too large"))
	}

	executablePayload := &eth.ExecutionPayload{
		ParentHash:    reqBody.ExecutableData.ParentHash,
		FeeRecipient:  reqBody.ExecutableData.FeeRecipient,
		PrevRandao:    eth.Bytes32(mixHash[:]),
		BlockNumber:   eth.Uint64Quantity(reqBody.ExecutableData.Number),
		GasLimit:      eth.Uint64Quantity(reqBody.ExecutableData.GasLimit),
		Timestamp:     eth.Uint64Quantity(reqBody.ExecutableData.Timestamp),
		ExtraData:     eth.BytesMax32(reqBody.ExecutableData.ExtraData),
		BaseFeePerGas: eth.Uint256Quantity(*baseFee),
		Transactions:  []eth.Data{reqBody.ExecutableData.Transactions},
	}

	if err := s.ValidateExecutionPayload(executablePayload); err != nil {
		return s.returnError(c, http.StatusBadRequest, err)
	}

	// Insert the preconfirmation block.
	var (
		headers   []*types.Header
		envelopes = []*preconf.Envelope{{Payload: executablePayload, Signature: nil, IsForcedInclusion: isForcedInclusion}}
	)

	if headers, err = s.insertPreconfBlocksFromEnvelopes(ctx, envelopes, false); err != nil {
		return s.returnError(c, http.StatusInternalServerError, err)
	}

	if len(headers) == 0 {
		return s.returnError(c, http.StatusInternalServerError, errors.New("no inserted header returned"))
	}

	header := headers[0]

	// always update the highest imported L2 payload block ID.
	// it's either higher than the existing one, or we reorged.
	s.updateHighestImportedL2Payload(header.Number.Uint64())

	// Propagate the preconfirmation block to the P2P network, if the current server
	// connects to the P2P network.
	if s.p2pNode != nil && !reflect2.IsNil(s.p2pSigner) {
		log.Info(
			"Gossiping unsafe L2 payload",
			"blockID", header.Number,
			"hash", header.Hash(),
			"coinbase", header.Coinbase,
			"timestamp", header.Time,
			"gasLimit", header.GasLimit,
			"baseFeePerGas", utils.WeiToEther(new(big.Int).SetUint64(header.BaseFee.Uint64())),
			"extraData", common.Bytes2Hex(header.Extra),
			"parentHash", header.ParentHash,
			"endOfSequencing", endOfSequencing,
			"isForcedInclusion", isForcedInclusion,
		)

		var u256 uint256.Int
		if overflow := u256.SetFromBig(header.BaseFee); overflow {
			log.Warn(
				"Failed to convert base fee to uint256, skip propagating the preconfirmation block",
				"baseFee", header.BaseFee,
			)
		} else {
			// sign the block hash, persist it to L1Origin as the signature
			sigBytes, err := s.p2pSigner.Sign(
				ctx,
				p2p.SigningDomainBlocksV1,
				s.rpc.L2.ChainID,
				header.Hash().Bytes(),
			)
			if err != nil {
				log.Warn(
					"Failed to sign the preconfirmation block payload",
					"blockHash", executablePayload.BlockHash.Hex(),
					"blockID", header.Number.Uint64(),
				)
				return s.returnError(c, http.StatusInternalServerError, fmt.Errorf("failed to sign payload: %w", err))
			}

			if _, err = s.rpc.L2Engine.SetL1OriginSignature(ctx, header.Number, *sigBytes); err != nil {
				return s.returnError(
					c,
					http.StatusInternalServerError,
					fmt.Errorf("failed to update L1 origin signature: %w", err),
				)
			}

			// Build envelope once, cache locally, then publish to P2P.
			env, err := headerToEnvelope(
				header,
				[]eth.Data{reqBody.ExecutableData.Transactions},
				reqBody.EndOfSequencing,
				&isForcedInclusion,
				sigBytes,
			)
			if err != nil {
				return s.returnError(c, http.StatusInternalServerError, err)
			}

			// Cache locally so this node can perform orphan handling without relying on receiving our own gossip.
			s.tryPutEnvelopeIntoCache(env, s.p2pNode.Host().ID())

			if err := s.p2pNode.GossipOut().PublishL2Payload(ctx, env, s.p2pSigner); err != nil {
				log.Warn("Failed to propagate the preconfirmation block to the P2P network", "error", err)
			}
		}
	} else {
		log.Info(
			"P2P network / signer is disabled, skip propagating the preconfirmation block",
			"blockID", header.Number,
			"hash", header.Hash(),
			"coinbase", header.Coinbase.Hex(),
			"timestamp", header.Time,
			"gasLimit", header.GasLimit,
			"gasUsed", header.GasUsed,
			"mixDigest", common.Bytes2Hex(header.MixDigest[:]),
			"extraData", common.Bytes2Hex(header.Extra),
			"baseFee", utils.WeiToEther(header.BaseFee),
		)
	}

	if endOfSequencing && s.rpc.L1Beacon != nil {
		currentEpoch := s.rpc.L1Beacon.CurrentEpoch()
		s.sequencingEndedForEpochCache.Add(currentEpoch, header.Hash())
		log.Info(
			"End of sequencing block marker created",
			"blockID", header.Number.Uint64(),
			"hash", header.Hash().Hex(),
			"currentEpoch", currentEpoch,
		)
	}

	metrics.DriverL2PreconfBlocksFromRPCGauge.Inc()

	return c.JSON(http.StatusOK, BuildPreconfBlockResponseBody{BlockHeader: header})
}

// HealthCheck is the endpoints for probes.
//
//	@Summary		Get current server health status
//	@ID			   	health-check
//	@Accept			json
//	@Produce		json
//	@Success		200	{object} string
//	@Router			/healthz [get]
func (s *PreconfBlockAPIServer) HealthCheck(c echo.Context) error {
	return c.NoContent(http.StatusOK)
}

// Status represents the current status of the preconfirmation block server.
type Status struct {
	// @param lookahead the current lookahead information.
	Lookahead *Lookahead `json:"lookahead"`
	// @param totalCached uint64 the total number of cached envelopes after the start of the server.
	TotalCached uint64 `json:"totalCached"`
	// @param highestUnsafeL2PayloadBlockID uint64 the highest preconfirmation block ID that the server
	// @param has received from the P2P network, whether or not it could be imported, floored at the
	// @param current L2 execution engine head. A consumer that requires this to equal the execution
	// @param head before sequencing therefore sees a mismatch whenever this node is behind.
	HighestUnsafeL2PayloadBlockID uint64 `json:"highestUnsafeL2PayloadBlockID"`
	// @param highestImportedL2PayloadBlockID uint64 the highest preconfirmation block the server has
	// @param actually inserted into its L2 execution engine. The gap to highestUnsafeL2PayloadBlockID
	// @param is this node's preconfirmation backlog.
	HighestImportedL2PayloadBlockID uint64 `json:"highestImportedL2PayloadBlockID"`
	// @param whether the current epoch has received an end of sequencing block marker
	EndOfSequencingBlockHash string `json:"endOfSequencingBlockHash"`
	// CanShutdown is true when the server is safe to receive SIGTERM, i.e.,
	// not the active or imminent preconfer for the current L1 slot.
	CanShutdown bool `json:"canShutdown"`
}

// anchorHighestSeenL2Payload bounds the seen counter to one envelope-cache span above the live
// execution head and writes the bound back, returning the value to report.
//
// Writing it back is the point. A payload further ahead than the cache can bridge needs L1
// derivation to clear either way, but leaving the raw height in the counter means the reported
// value tracks `head + span` upwards forever and can never return to equality: one
// signature-valid payload carrying a wrong or hostile block number would keep the preconfer
// client from ever starting. Pinning the counter at a concrete height lets the chain pass it.
//
// The live head is the only safe anchor. Every counter maintained inside this server can lag it
// -- L1 derivation advances the chain without touching them -- and bounding against a lagging
// anchor would pull the counter below the head, which reads as synced. Anchored here, the stored
// value is always `head + span`, strictly above the head, so a real backlog always reports as
// one.
func (s *PreconfBlockAPIServer) anchorHighestSeenL2Payload(head uint64) uint64 {
	seen := s.highestSeenL2PayloadBlockID.Load()

	ceiling := head + maxTrackedPayloads
	if seen <= ceiling {
		return seen
	}

	log.Warn(
		"Anchoring highest seen L2 payload block ID to the execution head",
		"highestSeenL2PayloadBlockID", seen,
		"ceiling", ceiling,
	)
	// A concurrent writer holding s.mutex may have advanced the counter since the load; leave its
	// value alone and let the next poll re-anchor.
	s.highestSeenL2PayloadBlockID.CompareAndSwap(seen, ceiling)

	return ceiling
}

// reportedHighestUnsafeL2Payload is the value `/status` publishes as
// highestUnsafeL2PayloadBlockID: the highest payload this node has seen, floored at the
// execution head.
//
// The floor keeps a node whose execution head runs ahead of the gossip it has seen -- right
// after a beacon sync, before the next proposal event lands -- from reporting a backlog it does
// not have. That matters because the preconfer client exits the process after roughly half an
// L2 epoch of continuous mismatch.
//
// No cap is applied here. `updateHighestSeenL2Payload` already anchors the counter, and a cap at
// this end would track the head upwards and so could never return to equality.
func reportedHighestUnsafeL2Payload(highestSeen, head uint64) uint64 {
	if highestSeen < head {
		return head
	}
	return highestSeen
}

// GetStatus returns the current status of the preconfirmation block server.
//
//	@Summary		Get current preconfirmation block server status
//	@Accept			json
//	@Produce		json
//	@Success		200	{object} Status
//	@Router			/status [get]
func (s *PreconfBlockAPIServer) GetStatus(c echo.Context) error {
	// Read the execution head before taking any lock. A failed read reports the raw seen
	// counter, which errs toward reporting a mismatch.
	highestImported := s.highestImportedL2PayloadBlockID.Load()
	highestUnsafe := s.highestSeenL2PayloadBlockID.Load()
	if head, err := s.rpc.L2.BlockNumber(c.Request().Context()); err != nil {
		log.Warn("Failed to fetch L2 head for preconfirmation status, reporting highest seen", "error", err)
	} else {
		highestUnsafe = reportedHighestUnsafeL2Payload(s.anchorHighestSeenL2Payload(head), head)
	}

	s.lookaheadMutex.Lock()
	defer s.lookaheadMutex.Unlock()

	endOfSequencingBlockHash := common.Hash{}

	if s.rpc.L1Beacon != nil {
		hash, ok := s.sequencingEndedForEpochCache.Get(s.rpc.L1Beacon.CurrentEpoch())
		if ok {
			endOfSequencingBlockHash = hash
		}
	}

	currentSlot := uint64(0)
	if s.rpc.L1Beacon != nil {
		currentSlot = s.rpc.L1Beacon.CurrentSlot()
	}
	canShutdown := s.canShutdownLocked(currentSlot)

	if s.lookahead != nil && s.rpc.L1Beacon != nil {
		log.Debug(
			"Get preconfirmation block server status",
			"currOperator", s.lookahead.CurrOperator.Hex(),
			"nextOperator", s.lookahead.NextOperator.Hex(),
			"currRanges", s.lookahead.CurrRanges,
			"nextRanges", s.lookahead.NextRanges,
			"totalCached", s.envelopesCache.getTotalCached(),
			"highestUnsafeL2PayloadBlockID", highestUnsafe,
			"highestImportedL2PayloadBlockID", highestImported,
			"endOfSequencingBlockHash", endOfSequencingBlockHash.Hex(),
			"currEpoch", s.rpc.L1Beacon.CurrentEpoch(),
			"canShutdown", canShutdown,
		)
	}

	return c.JSON(http.StatusOK, Status{
		Lookahead:                       s.lookahead,
		TotalCached:                     s.envelopesCache.getTotalCached(),
		HighestUnsafeL2PayloadBlockID:   highestUnsafe,
		HighestImportedL2PayloadBlockID: highestImported,
		EndOfSequencingBlockHash:        endOfSequencingBlockHash.Hex(),
		CanShutdown:                     canShutdown,
	})
}

// returnError is a helper function to return an error response.
func (s *PreconfBlockAPIServer) returnError(c echo.Context, statusCode int, err error) error {
	log.Error("Preconfirmation block request error", "status", statusCode, "error", err.Error())

	return c.JSON(statusCode, map[string]string{"error": err.Error()})
}
