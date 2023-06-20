package http

import (
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

type GetByAddressAndEventNameResp struct {
	Events []*eventindexer.Event `json:"events"`
}

func (srv *Server) GetByAddressAndEventName(c echo.Context) error {
	events, err := srv.eventRepo.GetByAddressAndEventName(
		c.Request().Context(),
		c.QueryParam("address"),
		c.QueryParam("event"),
	)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	return c.JSON(http.StatusOK, &GetByAddressAndEventNameResp{
		Events: events,
	})
}
