package softblocks

import (
	"net/http"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/labstack/echo/v4"
)

// TransactionBatchMarker represents the status of a soft block transactions group.
type TransactionBatchMarker string

// BatchMarker values.
const (
	BatchMarkerEOB TransactionBatchMarker = "end_of_block"
	BatchMarkerEOP TransactionBatchMarker = "end_of_preconf"
)

// SoftBlockParams represents the parameters for building a soft block.
type SoftBlockParams struct {
	// @param timestamp uint64 Timestamp of the soft block
	Timestamp uint64 `json:"timestamp"`
	// @param coinbase uint64 Coinbase of the soft block
	Coinbase string `json:"coinbase"`

	// @param anchorBlockID uint64 `_anchorBlockId` parameter of the `anchorV2` transaction in soft block
	AnchorBlockID uint64 `json:"anchorBlockID"`
	// @param anchorStateRoot string `_anchorStateRoot` parameter of the `anchorV2` transaction in soft block
	AnchorStateRoot common.Hash `json:"anchorStateRoot"`
}

// TransactionBatch represents a soft block group.
type TransactionBatch struct {
	// @param blockId uint64 Block ID of the soft block
	BlockID uint64 `json:"blockId"`
	// @param batchId uint64 ID of this transaction batch
	ID uint64 `json:"batchId"`
	// @param transactions string zlib compressed RLP encoded bytes of a transactions list
	TransactionsList []byte `json:"transactions"`
	// @param batchType TransactionBatchMarker Marker of the transaction batch,
	// @param either `end_of_block`, `end_of_preconf` or empty
	BatchMarker TransactionBatchMarker `json:"batchType"`
	// @param signature string Signature of this transaction batch
	Signature string `json:"signature"`
	// @param blockParams SoftBlockParams Block parameters of the soft block
	BlockParams *SoftBlockParams `json:"blockParams"`
}

// BuildSoftBlockRequestBody represents a request body when handling
// soft blocks creation requests.
type BuildSoftBlockRequestBody struct {
	// @param transactionBatch TransactionBatch Transaction batch to be inserted into the soft block
	TransactionBatch TransactionBatch `json:"transactionBatch"`
}

// CreateOrUpdateBlocksFromBatchResponseBody represents a response body when handling soft
// blocks creation requests.
type BuildSoftBlockResponseBody struct {
	// @param blockHeader types.Header Header of the soft block
	BlockHeader types.Header `json:"blockHeader"`
}

// BuildSoftBlock handles a soft block creation request,
// if the soft block group in request are valid, it will insert the correspoinding new soft
// block to the backend L2 execution engine and return a success response.
//
//		@Description	Insert a group of transactions into a soft block for preconfirmation. If the group is the
//		@Description	first for a block, a new soft block will be created. Otherwise, the transactions will
//		@Description	be appended to the existing soft block. The API will fail if:
//		@Description	1) the block is not soft
//	  @Description	2) block-level parameters are invalid or do not match the current soft block’s parameters
//	  @Description	3) the group ID is not exactly 1 greater than the previous one
//	  @Description	4) the last group of the block indicates no further transactions are allowed
//		@Param  body body BuildSoftBlockRequestBody true "soft block creation request body"
//		@Accept	  json
//		@Produce	json
//		@Success	200		{object} BuildSoftBlockResponseBody
//		@Router		/softBlocks [post]
func (s *SoftBlockAPIServer) BuildSoftBlock(c echo.Context) error {
	// Check if the L2 execution engine is syncing from L1.
	progress, err := s.rpc.L2ExecutionEngineSyncProgress(c.Request().Context())
	if err != nil {
		return err
	}
	if progress.IsSyncing() {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "L2 execution engine is syncing"})
	}

	// Insert the soft block.
	header, err := s.chainSyncer.BlobSyncer().InsertSoftBlock(c.Request().Context())
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	}

	return c.JSON(http.StatusOK, BuildSoftBlockResponseBody{BlockHeader: *header})
}

// RemoveSoftBlocksRequestBody represents a request body when resetting the backend
// L2 execution engine soft head.
type RemoveSoftBlocksRequestBody struct {
	// @param newLastBlockID uint64 New last block ID of the blockchain, it should
	// @param not smaller than the canonical chain's highest block ID.
	NewLastBlockID uint64 `json:"newLastBlockId"`
}

// RemoveSoftBlocksResponseBody represents a response body when resetting the backend
// L2 execution engine soft head.
type RemoveSoftBlocksResponseBody struct {
	// @param lastBlockID uint64 Current highest block ID of the blockchain (including soft blocks)
	LastBlockID uint64 `json:"lastBlockId"`
	// @param lastProposedBlockID uint64 Highest block ID of the cnonical chain
	LastProposedBlockID uint64 `json:"lastProposedBlockID"`
	// @param headsRemoved uint64 Number of soft heads removed
	HeadsRemoved uint64 `json:"headsRemoved"`
}

// RemoveSoftBlocks removes the backend L2 execution engine soft head.
//
//		@Description	 Remove all soft blocks from the blockchain beyond the specified block height,
//	  @Description	 ensuring the latest block ID does not exceed the given height. This method will fail if
//	  @Description	 the block with an ID one greater than the specified height is not a soft block. If the
//	  @Description	 specified block height is greater than the latest soft block ID, the method will succeed
//	  @Description	 without modifying the blockchain.
//		@Param      body body RemoveSoftBlocksRequestBody true "soft blocks removing request body"
//		@Accept			json
//		@Produce		json
//		@Success		200	{object} RemoveSoftBlocksResponseBody
//		@Router			/softBlocks [delete]
func (s *SoftBlockAPIServer) RemoveSoftBlocks(c echo.Context) error {
	return c.NoContent(http.StatusOK)
}

// HealthCheck is the endpoints for probes.
//
//	@Summary		Get current server health status
//	@ID			   	health-check
//	@Accept			json
//	@Produce		json
//	@Success		200	{object} string
//	@Router			/healthz [get]
func (s *SoftBlockAPIServer) HealthCheck(c echo.Context) error {
	return c.NoContent(http.StatusOK)
}
