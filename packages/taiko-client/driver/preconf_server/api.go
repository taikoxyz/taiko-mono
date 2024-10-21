package preconf_server

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
}

// CreateOrUpdateBlocksFromBatchResponseBodyRequestBody represents a request body when handling
// preconfirmation blocks creation requests.
type CreateOrUpdateBlocksFromBatchResponseBodyRequestBody struct {
	TransactionsGroups []PreconfTransactionsGroup `json:"transactionsGroups"`
}

// CreateOrUpdateBlocksFromBatchResponseBody represents a response body when handling preconfirmation
// blocks creation requests.
type CreateOrUpdateBlocksFromBatchResponseBody struct {
	PreconfHeaders []types.Header `json:"preconfHeaders"`
}

// CreateOrUpdateBlocksFromBatch handles a preconfirmation blocks creation request,
// if the preconfirmation block groups in request are valid, it will insert the correspoinding new preconfirmation
// blocks to the backend L2 execution engine and return a success response.
//
//	@Summary	Insert preconfirmation blocks by the given groups to the backend L2 execution engine, please note that
//	            the AVS service should sort the groups and make sure all the groups are valid at first.
//	@Param    body body CreateOrUpdateBlocksFromBatchResponseBodyRequestBody true "preconf blocks creation request body"
//	@Accept	  json
//	@Produce	json
//	@Success	200		{object} CreateOrUpdateBlocksFromBatchResponseBody
//	@Router		/perconfBlocks [post]
func (s *PreconfAPIServer) CreateOrUpdateBlocksFromBatch(c echo.Context) error {
	return c.NoContent(http.StatusOK)
}

// ResetPreconfHeadRequestBody represents a request body when resetting the backend
// L2 execution engine preconfirmation head.
type ResetPreconfHeadRequestBody struct {
	NewHead uint64 `json:"newHead"`
}

// ResetPreconfHeadResponseBody represents a response body when resetting the backend
// L2 execution engine preconfirmation head.
type ResetPreconfHeadResponseBody struct {
	CurrentHead types.Header `json:"currentHead"`
}

// ResetPreconfHead resets the backend L2 execution engine preconfirmation head.
//
//	@Summary	  Resets the backend L2 execution engine preconfirmation head, please note that
//	            the AVS service should make sure the new head height is from a valid preconfirmation head.
//	@Param      body body ResetPreconfHeadRequestBody true "preconf blocks creation request body"
//	@Accept			json
//	@Produce		json
//	@Success		200	{object} ResetPreconfHeadResponseBody
//	@Router			/preconfHead [put]
func (s *PreconfAPIServer) ResetPreconfHead(c echo.Context) error {
	return c.NoContent(http.StatusOK)
}

// HealthCheck is the endpoints for probes.
//
//	@Summary		Get current server health status
//	@ID			   	health-check
//	@Accept			json
//	@Produce		json
//	@Success		200	{object} Status
//	@Router			/healthz [get]
func (s *PreconfAPIServer) HealthCheck(c echo.Context) error {
	return c.NoContent(http.StatusOK)
}
