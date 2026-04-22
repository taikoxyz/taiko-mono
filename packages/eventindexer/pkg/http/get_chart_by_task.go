package http

import (
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
	"github.com/patrickmn/go-cache"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

// GetChartByTask
//
//	 returns time series data for displaying charts
//
//			@Summary		Get time series data for displaying charts
//			@ID			   	get-charts-by-task
//		    @Param			task	query		string		true	"task to query"
//		    @Param			start	query		string		true	"start date"
//		    @Param			end	query		string		true	"end date"
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} eventindexer.ChartResponse
//			@Router			/chart/chartByTask [get]
func (srv *Server) GetChartByTask(c echo.Context) error {
	cacheKey := c.QueryParam("task") +
		c.QueryParam("fee_token_address") +
		c.QueryParam("tier") +
		c.QueryParam("start") +
		c.QueryParam("end")
	cached, found := srv.cache.Get(cacheKey)

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
			c.QueryParam("fee_token_address"),
			c.QueryParam("tier"),
		)
		if err != nil {
			return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
		}

		srv.cache.Set(
			cacheKey,
			chart,
			cache.DefaultExpiration,
		)
	}

	return c.JSON(http.StatusOK, chart)
}
