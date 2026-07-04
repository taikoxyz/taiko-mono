package http

import (
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"

	_ "github.com/morkid/paginate"
)

// GetAssignedBlocksByProverAddress
//
//	 returns the assigned blocks for a given prover address.
//
//			@Summary		Get assigned blocks by prover address
//			@ID			   	get-assigned-blocks-by-prover-address
//		    @Param			address	query		string		true	"address to query"
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} paginate.Page
//			@Router			/assignedBlocks [get]
func (srv *Server) GetAssignedBlocksByProverAddress(c echo.Context) error {
	page, err := srv.eventRepo.GetAssignedBlocksByProverAddress(
		c.Request().Context(),
		c.Request(),
		c.QueryParam("address"),
	)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	return c.JSON(http.StatusOK, page)
}
