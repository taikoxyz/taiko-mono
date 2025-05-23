package preconfblocks

import (
	"errors"
	"fmt"
	"math/big"
	"net/http"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/holiman/uint256"
	"github.com/labstack/echo/v4"
	"github.com/modern-go/reflect2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
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
	ExecutableData  *ExecutableData `json:"executableData"`
	EndOfSequencing *bool           `json:"endOfSequencing"`
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
//		@Param  	body body BuildPreconfBlockRequestBody true "preconfirmation block creation request body"
//		@Accept	  json
//		@Produce	json
//		@Success	200		{object} BuildPreconfBlockResponseBody
//		@Router		/preconfBlocks [post]
func (s *PreconfBlockAPIServer) BuildPreconfBlock(c echo.Context) error {
	s.mutex.Lock()
	defer s.mutex.Unlock()

	taikoWrapper, err := s.rpc.PacayaClients.TaikoWrapper.PreconfRouter(
		&bind.CallOpts{
			Context: c.Request().Context(),
		},
	)
	if err != nil {
		return s.returnError(c, http.StatusInternalServerError, err)
	}

	if taikoWrapper == rpc.ZeroAddress {
		return s.returnError(c, http.StatusInternalServerError, errors.New("preconfs are disabled via taiko wrapper"))
	}

	// Parse the request body.
	reqBody := new(BuildPreconfBlockRequestBody)
	if err := c.Bind(reqBody); err != nil {
		return s.returnError(c, http.StatusUnprocessableEntity, err)
	}
	if reqBody.ExecutableData == nil {
		return s.returnError(c, http.StatusBadRequest, errors.New("executable data is required"))
	}

	parent, err := s.rpc.L2.HeaderByHash(c.Request().Context(), reqBody.ExecutableData.ParentHash)
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

	log.Info(
		"New preconfirmation block building request",
		"blockID", reqBody.ExecutableData.Number,
		"coinbase", reqBody.ExecutableData.FeeRecipient.Hex(),
		"timestamp", reqBody.ExecutableData.Timestamp,
		"gasLimit", reqBody.ExecutableData.GasLimit,
		"baseFeePerGas", utils.WeiToEther(new(big.Int).SetUint64(reqBody.ExecutableData.BaseFeePerGas)),
		"extraData", common.Bytes2Hex(reqBody.ExecutableData.ExtraData),
		"parentHash", reqBody.ExecutableData.ParentHash.Hex(),
		"endOfSequencing", endOfSequencing,
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

	// Check if the L2 execution engine is syncing from L1.
	progress, err := s.rpc.L2ExecutionEngineSyncProgress(c.Request().Context())
	if err != nil {
		return s.returnError(c, http.StatusBadRequest, err)
	}
	if progress.IsSyncing() {
		return s.returnError(c, http.StatusBadRequest, errors.New("L2 execution engine is syncing"))
	}

	// Insert the preconfirmation block.
	headers, err := s.chainSyncer.InsertPreconfBlocksFromExecutionPayloads(
		c.Request().Context(),
		[]*eth.ExecutionPayload{executablePayload},
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
	// its either higher than the existing one, or we reorged.
	s.updateHighestUnsafeL2Payload(header.Number.Uint64())

	// Propagate the preconfirmation block to the P2P network, if the current server
	// connects to the P2P network.
	if s.p2pNode != nil && !reflect2.IsNil(s.p2pSigner) {
		log.Info("Gossiping L2 Payload", "blockID", header.Number.Uint64(), "time", header.Time)

		var u256 uint256.Int
		if overflow := u256.SetFromBig(header.BaseFee); overflow {
			log.Warn(
				"Failed to convert base fee to uint256, skip propagating the preconfirmation block",
				"baseFee", header.BaseFee,
			)
		} else {
			if err := s.p2pNode.GossipOut().PublishL2Payload(
				c.Request().Context(),
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
					EndOfSequencing: reqBody.EndOfSequencing,
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

	return c.JSON(http.StatusOK, BuildPreconfBlockResponseBody{BlockHeader: header})
}

// RemovePreconfBlocksRequestBody represents a request body when resetting the backend
// L2 execution engine preconfirmation head.
type RemovePreconfBlocksRequestBody struct {
	// @param newLastBlockID uint64 New last block ID of the blockchain, it should
	// @param not smaller than the canonical chain's highest block ID.
	NewLastBlockID uint64 `json:"newLastBlockId"`
}

// RemovePreconfBlocksResponseBody represents a response body when resetting the backend
// L2 execution engine preconfirmation head.
type RemovePreconfBlocksResponseBody struct {
	// @param lastBlockID uint64 Current highest block ID of the blockchain (including preconfirmation blocks)
	LastBlockID uint64 `json:"lastBlockId"`
	// @param lastProposedBlockID uint64 Highest block ID of the cnonical chain
	LastProposedBlockID uint64 `json:"lastProposedBlockID"`
	// @param headsRemoved uint64 Number of preconfirmation heads removed
	HeadsRemoved uint64 `json:"headsRemoved"`
}

// RemovePreconfBlocks removes the backend L2 execution engine preconfirmation head.
//
//		@Description	Remove all preconfirmation blocks from the blockchain beyond the specified block height,
//	  @Description	ensuring the latest block ID does not exceed the given height. This method will fail if
//	  @Description	the block with an ID one greater than the specified height is not a preconfirmation block. If the
//	  @Description	specified block height is greater than the latest preconfirmation block ID, the method will succeed
//	  @Description	without modifying the blockchain.
//		@Param      body body RemovePreconfBlocksRequestBody true "preconfirmation blocks removing request body"
//		@Accept			json
//		@Produce		json
//		@Success		200	{object} RemovePreconfBlocksResponseBody
//		@Router			/preconfBlocks [delete]
func (s *PreconfBlockAPIServer) RemovePreconfBlocks(c echo.Context) error {
	// Parse the request body.
	reqBody := new(RemovePreconfBlocksRequestBody)
	if err := c.Bind(reqBody); err != nil {
		return s.returnError(c, http.StatusUnprocessableEntity, err)
	}

	// Request body validation.
	canonicalHeadL1Origin, err := s.rpc.L2.HeadL1Origin(c.Request().Context())
	if err != nil && err.Error() != ethereum.NotFound.Error() {
		return s.returnError(c, http.StatusInternalServerError, err)
	}

	currentHead, err := s.rpc.L2.HeaderByNumber(c.Request().Context(), nil)
	if err != nil {
		return s.returnError(c, http.StatusInternalServerError, err)
	}

	if canonicalHeadL1Origin != nil && reqBody.NewLastBlockID < canonicalHeadL1Origin.BlockID.Uint64() {
		return s.returnError(
			c,
			http.StatusBadRequest,
			errors.New("newLastBlockId must not be smaller than the canonical chain's highest block ID"),
		)
	}

	log.Info(
		"New preconfirmation block removing request",
		"newLastBlockId", reqBody.NewLastBlockID,
		"currentHead", currentHead.Number.Uint64(),
	)

	if err := s.chainSyncer.RemovePreconfBlocks(c.Request().Context(), reqBody.NewLastBlockID); err != nil {
		return s.returnError(c, http.StatusBadRequest, err)
	}

	newHead, err := s.rpc.L2.HeaderByNumber(c.Request().Context(), nil)
	if err != nil {
		return s.returnError(c, http.StatusInternalServerError, err)
	}

	var lastBlockID uint64
	if canonicalHeadL1Origin != nil {
		lastBlockID = canonicalHeadL1Origin.BlockID.Uint64()
	}

	// If current block number is less than the highest unsafe L2 payload block ID,
	// update the highest unsafe L2 payload block ID.
	if newHead.Number.Uint64() < s.highestUnsafeL2PayloadBlockID {
		s.updateHighestUnsafeL2Payload(newHead.Number.Uint64())
	}

	log.Debug(
		"Removed preconfirmation blocks",
		"newHead", newHead.Number.Uint64(),
		"lastBlockID", lastBlockID,
		"headsRemoved", currentHead.Number.Uint64()-newHead.Number.Uint64(),
	)

	return c.JSON(http.StatusOK, RemovePreconfBlocksResponseBody{
		LastBlockID:         newHead.Number.Uint64(),
		LastProposedBlockID: lastBlockID,
		HeadsRemoved:        currentHead.Number.Uint64() - newHead.Number.Uint64(),
	})
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
	// @param lookahead Lookahead the current lookahead information.
	Lookahead *Lookahead `json:"lookahead"`
	// @param totalCached uint64 the total number of cached payloads after the start of the server.
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
		"totalCached", s.payloadsCache.getTotalCached(),
		"highestUnsafeL2PayloadBlockID", s.highestUnsafeL2PayloadBlockID,
		"endOfSequencingBlockHash", endOfSequencingBlockHash.Hex(),
	)

	return c.JSON(http.StatusOK, Status{
		Lookahead:                     s.lookahead,
		TotalCached:                   s.payloadsCache.getTotalCached(),
		HighestUnsafeL2PayloadBlockID: s.highestUnsafeL2PayloadBlockID,
		EndOfSequencingBlockHash:      endOfSequencingBlockHash.Hex(),
	})
}

// returnError is a helper function to return an error response.
func (s *PreconfBlockAPIServer) returnError(c echo.Context, statusCode int, err error) error {
	log.Error("Preconfirmation block request error", "status", statusCode, "error", err.Error())

	return c.JSON(statusCode, map[string]string{"error": err.Error()})
}
