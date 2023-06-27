package http

import (
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
)

func (srv *Server) GetStats(c echo.Context) error {
	stats, err := srv.statRepo.Find(
		c.Request().Context(),
	)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	return c.JSON(http.StatusOK, stats)
}
