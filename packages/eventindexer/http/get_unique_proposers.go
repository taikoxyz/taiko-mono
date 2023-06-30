package http

import (
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
	"github.com/patrickmn/go-cache"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

type uniqueProposersResp struct {
	Proposers       []eventindexer.UniqueProposersResponse `json:"proposers"`
	UniqueProposers int                                    `json:"uniqueProposers"`
}

func (srv *Server) GetUniqueProposers(c echo.Context) error {
	cached, found := srv.cache.Get(CacheKeyUniqueProposers)

	var proposers []eventindexer.UniqueProposersResponse

	var err error

	if found {
		proposers = cached.([]eventindexer.UniqueProposersResponse)
	} else {
		proposers, err = srv.eventRepo.FindUniqueProposers(
			c.Request().Context(),
		)
		if err != nil {
			return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
		}

		srv.cache.Set(CacheKeyUniqueProposers, proposers, cache.DefaultExpiration)
	}

	return c.JSON(http.StatusOK, &uniqueProposersResp{
		Proposers:       proposers,
		UniqueProposers: len(proposers),
	})
}
