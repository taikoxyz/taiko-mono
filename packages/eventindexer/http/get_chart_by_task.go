package http

import (
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
	"github.com/patrickmn/go-cache"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

func (srv *Server) GetChartByTask(c echo.Context) error {
	cached, found := srv.cache.Get(c.QueryParam("task"))

	var chart *eventindexer.ChartResponse

	var err error

	if found {
		chart = cached.(*eventindexer.ChartResponse)
	} else {
		chart, err = srv.chartRepo.Find(
			c.Request().Context(),
			c.QueryParam("task"),
			c.QueryParam("start"),
			c.QueryParam("end"),
		)
		if err != nil {
			return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
		}

		srv.cache.Set(c.QueryParam("task"), chart, cache.DefaultExpiration)
	}

	return c.JSON(http.StatusOK, chart)
}
