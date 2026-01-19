package http

import (
	"net/http"
	"strconv"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
)

// GetProposalProvedBy
//
//	 returns events by address and name of the event
//
//			@Summary		Get proposal proved
//			@ID			   	get-proposal-proved-by
//		    @Param			proposalID	query		string		true	"proposalID to query"
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} eventindexer.Event
//			@Router			/proposalProvedBy [get]
func (srv *Server) GetProposalProvedBy(c echo.Context) error {
	proposalID, err := strconv.Atoi(c.QueryParam("proposalID"))
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	proved, err := srv.eventRepo.GetProposalProvedBy(c.Request().Context(),
		proposalID,
	)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	return c.JSON(http.StatusOK, proved)
}
