package http

import (
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
)

type GetCountByAddressAndEventNameResp struct {
	Count int `json:"count"`
}

func (srv *Server) GetCountByAddressAndEventName(c echo.Context) error {
	count, err := srv.eventRepo.GetCountByAddressAndEventName(
		c.Request().Context(),
		c.QueryParam("address"),
		c.QueryParam("event"),
	)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	return c.JSON(http.StatusOK, &GetCountByAddressAndEventNameResp{
		Count: count,
	})
}
