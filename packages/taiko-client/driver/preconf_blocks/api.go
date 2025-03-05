package preconfblocks

import (
	"errors"
	"fmt"
	"math/big"
	"net/http"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/holiman/uint256"
	"github.com/labstack/echo/v4"
	"github.com/modern-go/reflect2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
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
// preconf blocks creation requests.
type BuildPreconfBlockRequestBody struct {
	// @param ExecutableData engine.ExecutableData the data necessary to execute an EL payload.
	ExecutableData *ExecutableData `json:"executableData"`
}

// BuildPreconfBlockResponseBody represents a response body when handling preconf
// blocks creation requests.
type BuildPreconfBlockResponseBody struct {
	// @param blockHeader types.Header of the preconf block
	BlockHeader *types.Header `json:"blockHeader"`
}

// BuildPreconfBlock handles a preconfirmation block creation request,
// if the preconfirmation block creation body in request are valid, it will insert the correspoinding the
// preconfirmation block to the backend L2 execution engine and return a success response.
//
//		@Summary 	    Insert a preconfirmation block to the L2 execution engine.
//		@Description	Insert a preconfirmation block to the L2 execution engine, if the preconfirmation block creation
//		@Description	body in request are valid, it will insert the correspoinding the
//	 	@Description	preconfirmation block to the backend L2 execution engine and return a success response.
//		@Param  	body body BuildPreconfBlockRequestBody true "preconf block creation request body"
//		@Accept	  json
//		@Produce	json
//		@Success	200		{object} BuildPreconfBlockResponseBody
//		@Router		/preconfBlocks [post]
func (s *PreconfBlockAPIServer) BuildPreconfBlock(c echo.Context) error {
	// Parse the request body.
	reqBody := new(BuildPreconfBlockRequestBody)
	if err := c.Bind(reqBody); err != nil {
		return s.returnError(c, http.StatusUnprocessableEntity, err)
	}
	if reqBody.ExecutableData == nil {
		return s.returnError(c, http.StatusBadRequest, errors.New("executable data is required"))
	}

	log.Info(
		"New preconfirmation block building request",
		"blockID", reqBody.ExecutableData.Number,
		"coinbase", reqBody.ExecutableData.FeeRecipient.Hex(),
		"timestamp", reqBody.ExecutableData.Timestamp,
		"gasLimit", reqBody.ExecutableData.GasLimit,
		"baseFeePerGas", utils.WeiToEther(new(big.Int).SetUint64(reqBody.ExecutableData.BaseFeePerGas)),
		"extraData", common.Bytes2Hex(reqBody.ExecutableData.ExtraData),
	)

	if reqBody.ExecutableData.Timestamp == 0 {
		return s.returnError(c, http.StatusBadRequest, errors.New("non-zero timestamp is required"))
	}
	if reqBody.ExecutableData.FeeRecipient == (common.Address{}) {
		return s.returnError(c, http.StatusBadRequest, errors.New("empty L2 fee recipient"))
	}
	if reqBody.ExecutableData.GasLimit == 0 {
		return s.returnError(c, http.StatusBadRequest, errors.New("non-zero gas limit is required"))
	}
	if reqBody.ExecutableData.BaseFeePerGas == 0 {
		return s.returnError(c, http.StatusBadRequest, errors.New("non-zero base fee per gas is required"))
	}
	baseFee, overflow := uint256.FromBig(new(big.Int).SetUint64(reqBody.ExecutableData.BaseFeePerGas))
	if overflow {
		return s.returnError(c, http.StatusBadRequest, errors.New("base fee per gas is too large"))
	}
	if len(reqBody.ExecutableData.ExtraData) == 0 {
		return s.returnError(c, http.StatusBadRequest, errors.New("empty extra data"))
	}

	// Check if the L2 execution engine is syncing from L1.
	progress, err := s.rpc.L2ExecutionEngineSyncProgress(c.Request().Context())
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}
	if progress.IsSyncing() {
		return s.returnError(c, http.StatusBadRequest, errors.New("L2 execution engine is syncing"))
	}

	difficulty, err := encoding.CalculatePacayaDifficulty(new(big.Int).SetUint64(reqBody.ExecutableData.Number))
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}

	// Decompress the transactions list.
	decompressed, err := utils.Decompress(reqBody.ExecutableData.Transactions)
	if err != nil {
		return fmt.Errorf("failed to decompress transactions list bytes: %w", err)
	}

	// Insert the preconf block.
	header, err := s.chainSyncer.InsertPreconfBlockFromExecutionPayload(
		c.Request().Context(),
		&eth.ExecutionPayload{
			ParentHash:    reqBody.ExecutableData.ParentHash,
			FeeRecipient:  reqBody.ExecutableData.FeeRecipient,
			PrevRandao:    eth.Bytes32(difficulty[:]),
			BlockNumber:   eth.Uint64Quantity(reqBody.ExecutableData.Number),
			GasLimit:      eth.Uint64Quantity(reqBody.ExecutableData.GasLimit),
			Timestamp:     eth.Uint64Quantity(reqBody.ExecutableData.Timestamp),
			ExtraData:     eth.BytesMax32(reqBody.ExecutableData.ExtraData),
			BaseFeePerGas: eth.Uint256Quantity(*baseFee),
			Transactions:  []eth.Data{decompressed},
		},
	)
	if err != nil {
		return s.returnError(c, http.StatusInternalServerError, err)
	}

	log.Info(
		"⏰ New preconfirmation L2 block inserted",
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

	return c.JSON(http.StatusOK, BuildPreconfBlockResponseBody{BlockHeader: header})
}

// RemovePreconfBlocksRequestBody represents a request body when resetting the backend
// L2 execution engine preconf head.
type RemovePreconfBlocksRequestBody struct {
	// @param newLastBlockID uint64 New last block ID of the blockchain, it should
	// @param not smaller than the canonical chain's highest block ID.
	NewLastBlockID uint64 `json:"newLastBlockId"`
}

// RemovePreconfBlocksResponseBody represents a response body when resetting the backend
// L2 execution engine preconf head.
type RemovePreconfBlocksResponseBody struct {
	// @param lastBlockID uint64 Current highest block ID of the blockchain (including preconf blocks)
	LastBlockID uint64 `json:"lastBlockId"`
	// @param lastProposedBlockID uint64 Highest block ID of the cnonical chain
	LastProposedBlockID uint64 `json:"lastProposedBlockID"`
	// @param headsRemoved uint64 Number of preconf heads removed
	HeadsRemoved uint64 `json:"headsRemoved"`
}

// RemovePreconfBlocks removes the backend L2 execution engine preconf head.
//
//		@Description	Remove all preconf blocks from the blockchain beyond the specified block height,
//	  @Description	ensuring the latest block ID does not exceed the given height. This method will fail if
//	  @Description	the block with an ID one greater than the specified height is not a preconf block. If the
//	  @Description	specified block height is greater than the latest preconf block ID, the method will succeed
//	  @Description	without modifying the blockchain.
//		@Param      body body RemovePreconfBlocksRequestBody true "preconf blocks removing request body"
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
	if err != nil {
		return s.returnError(c, http.StatusInternalServerError, err)
	}

	currentHead, err := s.rpc.L2.HeaderByNumber(c.Request().Context(), nil)
	if err != nil {
		return s.returnError(c, http.StatusInternalServerError, err)
	}

	log.Info(
		"New preconfirmation block removing request",
		"newLastBlockId", reqBody.NewLastBlockID,
		"canonicalHead", canonicalHeadL1Origin.BlockID.Uint64(),
		"currentHead", currentHead.Number.Uint64(),
	)

	if reqBody.NewLastBlockID < canonicalHeadL1Origin.BlockID.Uint64() {
		return s.returnError(
			c,
			http.StatusBadRequest,
			errors.New("newLastBlockId must not be smaller than the canonical chain's highest block ID"),
		)
	}

	if err := s.chainSyncer.RemovePreconfBlocks(c.Request().Context(), reqBody.NewLastBlockID); err != nil {
		return s.returnError(c, http.StatusBadRequest, err)
	}

	newHead, err := s.rpc.L2.HeaderByNumber(c.Request().Context(), nil)
	if err != nil {
		return s.returnError(c, http.StatusInternalServerError, err)
	}

	return c.JSON(http.StatusOK, RemovePreconfBlocksResponseBody{
		LastBlockID:         newHead.Number.Uint64(),
		LastProposedBlockID: canonicalHeadL1Origin.BlockID.Uint64(),
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

// returnError is a helper function to return an error response.
func (s *PreconfBlockAPIServer) returnError(c echo.Context, statusCode int, err error) error {
	return c.JSON(statusCode, map[string]string{"error": err.Error()})
}
