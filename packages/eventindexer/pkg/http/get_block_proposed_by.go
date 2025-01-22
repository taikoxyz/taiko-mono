package http

import (
	"net/http"
	"strconv"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
)

// GetBlockProposedBy
//
//	 returns events by address and name of the event
//
//			@Summary		Get block proposed by
//			@ID			   	get-block-proposed-by
//		    @Param			blockID	query		string		true	"blockID to query"
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} []eventindexer.Event
//			@Router			/blockProposedBy [get]
func (srv *Server) GetBlockProposedBy(c echo.Context) error {
	blockID, err := strconv.Atoi(c.QueryParam("blockID"))
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	proposed, err := srv.eventRepo.GetBlockProposedBy(c.Request().Context(),
		blockID,
	)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	return c.JSON(http.StatusOK, proposed)
}
