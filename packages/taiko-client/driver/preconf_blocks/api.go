package preconfblocks

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"time"

	"github.com/ethereum-optimism/optimism/op-node/p2p"
	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/holiman/uint256"
	"github.com/labstack/echo/v4"
	"github.com/modern-go/reflect2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/preconf"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
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

	if s.rpc.PacayaClients.TaikoWrapper != nil {
		// Check if the preconfirmation is enabled.
		preconfRouter, err := s.rpc.GetPreconfRouterPacaya(&bind.CallOpts{Context: ctx})
		if err != nil {
			return s.returnError(c, http.StatusInternalServerError, err)
		}
		if preconfRouter == rpc.ZeroAddress {
			log.Warn("Preconfirmation is disabled via taikoWrapper", "preconfRouter", preconfRouter.Hex())
			return s.returnError(
				c,
				http.StatusInternalServerError,
				errors.New("preconfirmation is disabled via taikoWrapper"),
			)
		}
	}

	// Check if the L2 execution engine is syncing from L1.
	progress, err := s.rpc.L2ExecutionEngineSyncProgress(ctx)
	if err != nil {
		return s.returnError(c, http.StatusBadRequest, err)
	}
	if progress.IsSyncing() {
		return s.returnError(c, http.StatusBadRequest, errors.New("l2 execution engine is syncing"))
	}

	// Parse the request body.
	reqBody := new(BuildPreconfBlockRequestBody)
	if err := c.Bind(reqBody); err != nil {
		return s.returnError(c, http.StatusUnprocessableEntity, err)
	}
	if reqBody.ExecutableData == nil {
		return s.returnError(c, http.StatusBadRequest, errors.New("executable data is required"))
	}

	parent, err := s.rpc.L2.HeaderByHash(ctx, reqBody.ExecutableData.ParentHash)
	if err != nil {
		return s.returnError(c, http.StatusInternalServerError, err)
	}

	if s.latestSeenProposal != nil && parent.Number.Uint64() < s.latestSeenProposal.Pacaya().GetLastBlockID() {
		log.Warn(
			"The parent block ID is smaller than the latest block ID seen in event",
			"parentBlockID", parent.Number.Uint64(),
			"latestBlockIDSeenInEvent", s.latestSeenProposal.Pacaya().GetLastBlockID(),
		)

		return s.returnError(c, http.StatusBadRequest,
			fmt.Errorf(
				"latestBatchProposalBlockID: %v, parentBlockID: %v",
				s.latestSeenProposal.Pacaya().GetLastBlockID(),
				parent.Number.Uint64(),
			),
		)
	}

	endOfSequencing := false
	if reqBody.EndOfSequencing != nil && *reqBody.EndOfSequencing {
		endOfSequencing = true
	}

	isForcedInclusion := false
	if reqBody.IsForcedInclusion != nil && *reqBody.IsForcedInclusion {
		isForcedInclusion = true
	}

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

	// Check if the fee recipient the current operator or the next operator if its in handover window.
	if s.rpc.L1Beacon != nil {
		if err := s.CheckLookaheadHandover(reqBody.ExecutableData.FeeRecipient, s.rpc.L1Beacon.CurrentSlot()); err != nil {
			return s.returnError(c, http.StatusBadRequest, err)
		}
	}

	difficulty, err := encoding.CalculatePacayaDifficulty(new(big.Int).SetUint64(reqBody.ExecutableData.Number))
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
		PrevRandao:    eth.Bytes32(difficulty[:]),
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
	headers, err := s.chainSyncer.InsertPreconfBlocksFromEnvelopes(
		ctx,
		[]*preconf.Envelope{
			{
				Payload:           executablePayload,
				Signature:         nil,
				IsForcedInclusion: isForcedInclusion,
			},
		},
		false,
	)
	if err != nil {
		return s.returnError(c, http.StatusInternalServerError, err)
	}
	if len(headers) == 0 {
		return s.returnError(c, http.StatusInternalServerError, errors.New("no inserted header returned"))
	}

	header := headers[0]

	// always update the highest unsafe L2 payload block ID.
	// it's either higher than the existing one, or we reorged.
	s.updateHighestUnsafeL2Payload(header.Number.Uint64())

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
			"isForcedInclusion", reqBody.IsForcedInclusion != nil && *reqBody.IsForcedInclusion,
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

			if err := s.p2pNode.GossipOut().PublishL2Payload(
				ctx,
				&eth.ExecutionPayloadEnvelope{
					ExecutionPayload: &eth.ExecutionPayload{
						BaseFeePerGas: eth.Uint256Quantity(u256),
						ParentHash:    header.ParentHash,
						FeeRecipient:  header.Coinbase,
						ExtraData:     header.Extra,
						PrevRandao:    eth.Bytes32(header.MixDigest),
						BlockNumber:   eth.Uint64Quantity(header.Number.Uint64()),
						GasLimit:      eth.Uint64Quantity(header.GasLimit),
						GasUsed:       eth.Uint64Quantity(header.GasUsed),
						Timestamp:     eth.Uint64Quantity(header.Time),
						BlockHash:     header.Hash(),
						Transactions:  []eth.Data{reqBody.ExecutableData.Transactions},
					},
					EndOfSequencing:   reqBody.EndOfSequencing,
					IsForcedInclusion: &isForcedInclusion,
					Signature:         sigBytes,
				},
				s.p2pSigner,
			); err != nil {
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

	if reqBody.EndOfSequencing != nil && *reqBody.EndOfSequencing && s.rpc.L1Beacon != nil {
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
	// @param has received from the P2P network, if its zero, it means the current server has not received
	// @param any preconfirmation block from the P2P network yet.
	HighestUnsafeL2PayloadBlockID uint64 `json:"highestUnsafeL2PayloadBlockID"`
	// @param whether the current epoch has received an end of sequencing block marker
	EndOfSequencingBlockHash string `json:"endOfSequencingBlockHash"`
}

// GetStatus returns the current status of the preconfirmation block server.
//
//	@Summary		Get current preconfirmation block server status
//	@Accept			json
//	@Produce		json
//	@Success		200	{object} Status
//	@Router			/status [get]
func (s *PreconfBlockAPIServer) GetStatus(c echo.Context) error {
	s.lookaheadMutex.Lock()
	defer s.lookaheadMutex.Unlock()

	endOfSequencingBlockHash := common.Hash{}

	if s.rpc.L1Beacon != nil {
		hash, ok := s.sequencingEndedForEpochCache.Get(s.rpc.L1Beacon.CurrentEpoch())
		if ok {
			endOfSequencingBlockHash = hash
		}
	}

	log.Debug(
		"Get preconfirmation block server status",
		"currOperator", s.lookahead.CurrOperator.Hex(),
		"nextOperator", s.lookahead.NextOperator.Hex(),
		"currRanges", s.lookahead.CurrRanges,
		"nextRanges", s.lookahead.NextRanges,
		"totalCached", s.envelopesCache.getTotalCached(),
		"highestUnsafeL2PayloadBlockID", s.highestUnsafeL2PayloadBlockID,
		"endOfSequencingBlockHash", endOfSequencingBlockHash.Hex(),
		"currEpoch", s.rpc.L1Beacon.CurrentEpoch(),
	)

	return c.JSON(http.StatusOK, Status{
		Lookahead:                     s.lookahead,
		TotalCached:                   s.envelopesCache.getTotalCached(),
		HighestUnsafeL2PayloadBlockID: s.highestUnsafeL2PayloadBlockID,
		EndOfSequencingBlockHash:      endOfSequencingBlockHash.Hex(),
	})
}

// returnError is a helper function to return an error response.
func (s *PreconfBlockAPIServer) returnError(c echo.Context, statusCode int, err error) error {
	log.Error("Preconfirmation block request error", "status", statusCode, "error", err.Error())

	return c.JSON(statusCode, map[string]string{"error": err.Error()})
}
