package softblocks

import (
	"errors"
	"math/big"
	"net/http"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/labstack/echo/v4"
)

// TransactionBatchMarker represents the status of a soft block transactions group.
type TransactionBatchMarker string

// BatchMarker valid values.
const (
	BatchMarkerEmpty TransactionBatchMarker = ""
	BatchMarkerEOB   TransactionBatchMarker = "endOfBlock"
	BatchMarkerEOP   TransactionBatchMarker = "endOfPreconf"
)

// SoftBlockParams represents the parameters for building a soft block.
type SoftBlockParams struct {
	// @param timestamp uint64 Timestamp of the soft block
	Timestamp uint64 `json:"timestamp"`
	// @param coinbase string Coinbase of the soft block
	Coinbase common.Address `json:"coinbase"`

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
	Signature string `json:"signature" rlp:"-"`
	// @param blockParams SoftBlockParams Block parameters of the soft block
	BlockParams *SoftBlockParams `json:"blockParams"`
}

// ValidateSignature validates the signature of the transaction batch.
func (b *TransactionBatch) ValidateSignature() (bool, error) {
	payload, err := rlp.EncodeToBytes(b)
	if err != nil {
		return false, err
	}

	pubKey, err := crypto.SigToPub(crypto.Keccak256(payload), common.FromHex(b.Signature))
	if err != nil {
		return false, err
	}

	return crypto.PubkeyToAddress(*pubKey).Hex() == b.BlockParams.Coinbase.Hex(), nil
}

// BuildSoftBlockRequestBody represents a request body when handling
// soft blocks creation requests.
type BuildSoftBlockRequestBody struct {
	// @param transactionBatch TransactionBatch Transaction batch to be inserted into the soft block
	TransactionBatch *TransactionBatch `json:"transactionBatch"`
}

// CreateOrUpdateBlocksFromBatchResponseBody represents a response body when handling soft
// blocks creation requests.
type BuildSoftBlockResponseBody struct {
	// @param blockHeader types.Header of the soft block
	BlockHeader *types.Header `json:"blockHeader"`
}

// BuildSoftBlock handles a soft block creation request,
// if the soft block transactions batch in request are valid, it will insert or reorg the correspoinding the soft
// block to the backend L2 execution engine and return a success response.
//
//		@Description	Insert a batch of transactions into a soft block for preconfirmation. If the batch is the
//		@Description	first for a block, a new soft block will be created. Otherwise, the transactions will
//		@Description	be appended to the existing soft block. The API will fail if:
//		@Description	1) the block is not soft
//	  	@Description	2) block-level parameters are invalid or do not match the current soft block’s parameters
//	  	@Description	3) the batch ID is not exactly 1 greater than the previous one
//	  	@Description	4) the last batch of the block indicates no further transactions are allowed
//		@Param  	body BuildSoftBlockRequestBody true "soft block creation request body"
//		@Accept	  	json
//		@Produce	json
//		@Success	200		{object} BuildSoftBlockResponseBody
//		@Router		/softBlocks [post]
func (s *SoftBlockAPIServer) BuildSoftBlock(c echo.Context) error {
	// Parse the request body.
	reqBody := new(BuildSoftBlockRequestBody)
	if err := c.Bind(reqBody); err != nil {
		return s.returnError(c, http.StatusUnprocessableEntity, err)
	}
	if reqBody.TransactionBatch == nil {
		return s.returnError(c, http.StatusBadRequest, errors.New("transactionBatch is required"))
	}

	log.Info(
		"New soft block building request",
		"blockID", reqBody.TransactionBatch.BlockID,
		"batchID", reqBody.TransactionBatch.ID,
		"batchMarker", reqBody.TransactionBatch.BatchMarker,
		"transactionsListBytes", len(reqBody.TransactionBatch.TransactionsList),
		"signature", reqBody.TransactionBatch.Signature,
		"timestamp", reqBody.TransactionBatch.BlockParams.Timestamp,
		"coinbase", reqBody.TransactionBatch.BlockParams.Coinbase,
		"anchorBlockID", reqBody.TransactionBatch.BlockParams.AnchorBlockID,
		"anchorStateRoot", reqBody.TransactionBatch.BlockParams.AnchorStateRoot,
	)

	// Request body validation.
	if reqBody.TransactionBatch.BlockParams == nil {
		return s.returnError(c, http.StatusBadRequest, errors.New("blockParams is required"))
	}
	if reqBody.TransactionBatch.BlockParams.AnchorBlockID == 0 {
		return s.returnError(c, http.StatusBadRequest, errors.New("non-zero anchorBlockID is required"))
	}
	if reqBody.TransactionBatch.BlockParams.AnchorStateRoot == (common.Hash{}) {
		return s.returnError(c, http.StatusBadRequest, errors.New("empty anchorStateRoot"))
	}
	if reqBody.TransactionBatch.BlockParams.Timestamp == 0 {
		return s.returnError(c, http.StatusBadRequest, errors.New("non-zero timestamp is required"))
	}
	if reqBody.TransactionBatch.BlockParams.Coinbase == (common.Address{}) {
		return s.returnError(c, http.StatusBadRequest, errors.New("empty coinbase"))
	}

	// If the `--softBlock.signatureCheck` flag is enabled, validate the signature.
	if s.checkSig {
		ok, err := reqBody.TransactionBatch.ValidateSignature()
		if err != nil {
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
		}
		if !ok {
			log.Warn(
				"Invalid signature",
				"signature", reqBody.TransactionBatch.Signature,
				"coinbase", reqBody.TransactionBatch.BlockParams.Coinbase.Hex(),
			)
			return s.returnError(c, http.StatusBadRequest, errors.New("invalid signature"))
		}
	}

	// Check if the L2 execution engine is syncing from L1.
	progress, err := s.rpc.L2ExecutionEngineSyncProgress(c.Request().Context())
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}
	if progress.IsSyncing() {
		return s.returnError(c, http.StatusBadRequest, errors.New("L2 execution engine is syncing"))
	}

	// Check if the softblock batch or the current preconf process is ended.
	l1Origin, err := s.rpc.L2.L1OriginByID(
		c.Request().Context(),
		new(big.Int).SetUint64(reqBody.TransactionBatch.BlockID),
	)
	if err != nil && err.Error() != ethereum.NotFound.Error() {
		return s.returnError(c, http.StatusInternalServerError, err)
	}
	if l1Origin != nil {
		if l1Origin.EndOfBlock {
			return s.returnError(c, http.StatusBadRequest, errors.New("soft block has already been marked as ended"))
		}
		if l1Origin.EndOfPreconf {
			return s.returnError(
				c,
				http.StatusBadRequest,
				errors.New("preconfirmation has already been marked as ended"),
			)
		}
	}

	// Insert the soft block.
	header, err := s.chainSyncer.InsertSoftBlockFromTransactionsBatch(
		c.Request().Context(),
		reqBody.TransactionBatch.BlockID,
		reqBody.TransactionBatch.ID,
		s.txListDecompressor.TryDecompress(
			s.rpc.L2.ChainID,
			new(big.Int).SetUint64(reqBody.TransactionBatch.BlockID),
			reqBody.TransactionBatch.TransactionsList,
			true,
		),
		reqBody.TransactionBatch.BatchMarker,
		reqBody.TransactionBatch.BlockParams,
	)
	if err != nil {
		return s.returnError(c, http.StatusInternalServerError, err)
	}

	return c.JSON(http.StatusOK, BuildSoftBlockResponseBody{BlockHeader: header})
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
//		@Description	Remove all soft blocks from the blockchain beyond the specified block height,
//	  	@Description	ensuring the latest block ID does not exceed the given height. This method will fail if
//	  	@Description	the block with an ID one greater than the specified height is not a soft block. If the
//	  	@Description	specified block height is greater than the latest soft block ID, the method will succeed
//	  	@Description	without modifying the blockchain.
//		@Param      	body RemoveSoftBlocksRequestBody true "soft blocks removing request body"
//		@Accept			json
//		@Produce		json
//		@Success		200	{object} RemoveSoftBlocksResponseBody
//		@Router			/softBlocks [delete]
func (s *SoftBlockAPIServer) RemoveSoftBlocks(c echo.Context) error {
	// Parse the request body.
	reqBody := new(RemoveSoftBlocksRequestBody)
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
		"New soft block removing request",
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

	if err := s.chainSyncer.RemoveSoftBlocks(c.Request().Context(), reqBody.NewLastBlockID); err != nil {
		return s.returnError(c, http.StatusBadRequest, err)
	}

	newHead, err := s.rpc.L2.HeaderByNumber(c.Request().Context(), nil)
	if err != nil {
		return s.returnError(c, http.StatusInternalServerError, err)
	}

	return c.JSON(http.StatusOK, RemoveSoftBlocksResponseBody{
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
func (s *SoftBlockAPIServer) HealthCheck(c echo.Context) error {
	return c.NoContent(http.StatusOK)
}

// returnError is a helper function to return an error response.
func (s *SoftBlockAPIServer) returnError(c echo.Context, statusCode int, err error) error {
	return c.JSON(statusCode, map[string]string{"error": err.Error()})
}
