package http

import (
	"net/http"
	"time"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

// GetStats returns the current computed stats for the deployed network.
//
//	@Summary		Get stats
//	@ID			   	get-stats
//	@Accept			json
//	@Produce		json
//	@Success		200	{object} eventindexer.Stat
//	@Router			/stats [get]
func (srv *Server) GetStats(c echo.Context) error {
	cached, found := srv.cache.Get(CacheKeyStats)

	var stats *eventindexer.Stat

	var err error

	if found {
		stats = cached.(*eventindexer.Stat)
	} else {
		stats, err = srv.statRepo.Find(
			c.Request().Context(),
		)
		if err != nil {
			return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
		}

		srv.cache.Set(CacheKeyStats, stats, 1*time.Minute)
	}

	return c.JSON(http.StatusOK, stats)
}
