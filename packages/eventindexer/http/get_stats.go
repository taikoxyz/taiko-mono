package http

import (
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
	"github.com/patrickmn/go-cache"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

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

		srv.cache.Set(CacheKeyStats, stats, cache.DefaultExpiration)
	}

	return c.JSON(http.StatusOK, stats)
}
