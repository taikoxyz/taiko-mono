package http

import (
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

func (srv *Server) UserProposedBlock(c echo.Context) error {
	event, err := srv.eventRepo.FirstByAddressAndEventName(
		c.Request().Context(),
		c.QueryParam("address"),
		eventindexer.EventNameBlockProposed,
	)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	var found bool = false

	if event != nil {
		found = true
	}

	return c.JSON(http.StatusOK, &galaxeAPIResponse{
		Data: galaxeData{
			IsOK: found,
		},
	})
}
