package http

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
	"gorm.io/gorm"
)

// GetProposalProposedBy
//
//	 returns events by address and name of the event
//
//			@Summary		Get proposal proposed
//			@ID			   	get-proposal-proposed-by
//		    @Param			proposalID	query		string		true	"proposalID to query"
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} eventindexer.Event
//			@Router			/proposalProposedBy [get]
func (srv *Server) GetProposalProposedBy(c echo.Context) error {
	proposalID, err := strconv.Atoi(c.QueryParam("proposalID"))
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	proposed, err := srv.eventRepo.GetProposalProposedBy(c.Request().Context(),
		proposalID,
	)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return c.NoContent(http.StatusNotFound)
		}

		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	return c.JSON(http.StatusOK, proposed)
}
