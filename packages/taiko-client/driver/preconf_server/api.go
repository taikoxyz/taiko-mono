package preconf_server

import (
	"net/http"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/labstack/echo/v4"
)

// PreconfBlockGroup represents a preconfirmation block group.
type PreconfBlockGroup struct {
	BlockID          uint64             `json:"blockId"`
	ID               uint64             `json:"groupId"`
	TransactionsList types.Transactions `json:"transactions"`
	IsFinalGroup     bool               `json:"isFinalGroup"`
	Signature        string             `json:"signature"`
}

// CreateBlocksByGroupsRequestBody represents a request body when handling preconfirmation blocks creation requests.
type CreateBlocksByGroupsRequestBody struct {
	Groups []PreconfBlockGroup `json:"block_groups"`
}

// CreateBlocksByGroups handles a preconfirmation blocks creation request,
// if the preconfirmation block groups in request are valid, it will insert the correspoinding new preconfirmation
// blocks to the backend L2 execution engine and return a success response
//
//	@Summary		Insert preconfirmation blocks by the given groups to the backend L2 execution engine.
//	@Param      body body preconf_server.CreateBlocksByGroupsRequestBody true "preconf blocks creation request body"
//	@Accept			json
//	@Produce		json
//	@Success		200		{object} ProposeBlockResponse
//	@Router			/perconfBlocks [post]
func (s *PreconfAPIServer) CreateBlocksByGroups(c echo.Context) error {
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
