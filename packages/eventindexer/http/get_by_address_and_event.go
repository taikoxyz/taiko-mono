package http

import (
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
)

func (srv *Server) GetByAddressAndEventName(c echo.Context) error {
	page, err := srv.eventRepo.GetByAddressAndEventName(
		c.Request().Context(),
		c.Request(),
		c.QueryParam("address"),
		c.QueryParam("event"),
	)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	return c.JSON(http.StatusOK, page)
}
