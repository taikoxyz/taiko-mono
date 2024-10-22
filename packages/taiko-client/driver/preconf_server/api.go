package preconfserver

import (
	"net/http"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/labstack/echo/v4"
)

// PreconfTxsGroupStatus represents the status of a preconfirmation transactions group.
type PreconfTxsGroupStatus string

// PreconfBlockGroupStatus values.
const (
	StatusFinalBlockGroup   PreconfTxsGroupStatus = "finalBlockGroup"
	StatusFinalPreconfGroup PreconfTxsGroupStatus = "finalPreconfGroup"
)

// PreconfTransactionsGroup represents a preconfirmation block group.
type PreconfTransactionsGroup struct {
	BlockID          uint64                `json:"blockId"`
	ID               uint64                `json:"groupId"`
	TransactionsList types.Transactions    `json:"transactions"`
	GroupStatus      PreconfTxsGroupStatus `json:"groupStatus"`
	Signature        string                `json:"signature"`

	// Block parameters
	Timestamp             uint64         `json:"timestamp"`
	Random                common.Hash    `json:"prevRandao"`
	SuggestedFeeRecipient common.Address `json:"suggestedFeeRecipient"`
	BaseFeePerGas         uint64         `json:"baseFeePerGas"`

	// AnchorV2 parameters
	AnchorBlockID   uint64      `json:"anchorBlockID"`
	AnchorStateRoot common.Hash `json:"anchorStateRoot"`
	ParentGasUsed   uint32      `json:"parentGasUsed"`
}

// buildTentativeBlocksRequestBody represents a request body when handling
// preconfirmation blocks creation requests.
type BuildTentativeBlocksRequestBody struct {
	TransactionsGroups []PreconfTransactionsGroup `json:"transactionsGroups"`
}

// CreateOrUpdateBlocksFromBatchResponseBody represents a response body when handling preconfirmation
// blocks creation requests.
type BuildTentativeBlocksResponseBody struct {
	PreconfHeaders []types.Header `json:"tentativeHeaders"`
}

// BuildTentativeBlocks handles a preconfirmation blocks creation request,
// if the preconfirmation block groups in request are valid, it will insert the correspoinding new preconfirmation
// blocks to the backend L2 execution engine and return a success response.
//
//		@Description	Insert a group of transactions into a tentative block for preconfirmation. If the group is the
//		@Description	first for a block, a new tentative block will be created. Otherwise, the transactions will
//		@Description	be appended to the existing tentative block. The API will fail if:
//		@Description	1) the block is not tentative, 2) any transaction in the group is invalid or a duplicate, 3)
//	  @Description	block-level parameters are invalid or do not match the current tentative block’s parameters,
//	  @Description	4) the group ID is not exactly 1 greater than the previous one, or 5) the last group of
//	  @Description	the block indicates no further transactions are allowed.
//		@Param  body body BuildTentativeBlocksRequestBody true "preconf blocks creation request body"
//		@Accept	  json
//		@Produce	json
//		@Success	200		{object} BuildTentativeBlocksResponseBody
//		@Router		/tentativeBlocks [post]
func (s *PreconfAPIServer) BuildTentativeBlocks(c echo.Context) error {
	return c.NoContent(http.StatusOK)
}

// RemoveTentativeBlocksRequestBody represents a request body when resetting the backend
// L2 execution engine preconfirmation head.
type RemoveTentativeBlocksRequestBody struct {
	NewHead uint64 `json:"newHead"`
}

// RemoveTentativeBlocksResponseBody represents a response body when resetting the backend
// L2 execution engine preconfirmation head.
type RemoveTentativeBlocksResponseBody struct {
	CurrentHead types.Header `json:"currentHead"`
}

// RemoveTentativeBlocks removes the backend L2 execution engine preconfirmation head.
//
//		@Description	 Remove all tentative blocks from the blockchain beyond the specified block height,
//	  @Description	 ensuring the latest block ID does not exceed the given height. This method will fail if
//	  @Description	 the block with an ID one greater than the specified height is not a tentative block. If the
//	  @Description	 specified block height is greater than the latest tentative block ID, the method will succeed
//	  @Description	 without modifying the blockchain.
//		@Param      body body RemoveTentativeBlocksRequestBody true "preconf blocks creation request body"
//		@Accept			json
//		@Produce		json
//		@Success		200	{object} RemoveTentativeBlocksResponseBody
//		@Router			/tentativeBlocks [delete]
func (s *PreconfAPIServer) RemoveTentativeBlocks(c echo.Context) error {
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
func (s *PreconfAPIServer) HealthCheck(c echo.Context) error {
	return c.NoContent(http.StatusOK)
}
