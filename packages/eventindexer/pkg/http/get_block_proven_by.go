package http

import (
	"net/http"
	"strconv"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
)

// GetBlockProvenBy
//
//	 returns events by address and name of the event
//
//			@Summary		Get block proven by
//			@ID			   	get-block-proven-by
//		    @Param			blockID	query		string		true	"blockID to query"
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} []*eventindexer.Event
//			@Router			/blockProvenBy [get]
func (srv *Server) GetBlockProvenBy(c echo.Context) error {
	blockID, err := strconv.Atoi(c.QueryParam("blockID"))
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	events, err := srv.eventRepo.GetBlockProvenBy(
		c.Request().Context(),
		blockID,
	)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	return c.JSON(http.StatusOK, events)
}
