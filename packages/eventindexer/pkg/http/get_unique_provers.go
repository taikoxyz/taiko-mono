package http

import (
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
	"github.com/patrickmn/go-cache"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

type uniqueProversResp struct {
	Provers       []eventindexer.UniqueProversResponse `json:"provers"`
	UniqueProvers int                                  `json:"uniqueProvers"`
}

// GetUniqueProvers
//
//	 returns all unique provers
//
//			@Summary		Get unique provers
//			@ID			   	get-unique-provers
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} uniqueProversResp
//			@Router			/uniqueProvers [get]
func (srv *Server) GetUniqueProvers(c echo.Context) error {
	cached, found := srv.cache.Get(CacheKeyUniqueProvers)

	var provers []eventindexer.UniqueProversResponse

	var err error

	if found {
		provers = cached.([]eventindexer.UniqueProversResponse)
	} else {
		provers, err = srv.eventRepo.FindUniqueProvers(
			c.Request().Context(),
		)
		if err != nil {
			return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
		}

		srv.cache.Set(CacheKeyUniqueProvers, provers, cache.DefaultExpiration)
	}

	return c.JSON(http.StatusOK, &uniqueProversResp{
		Provers:       provers,
		UniqueProvers: len(provers),
	})
}
