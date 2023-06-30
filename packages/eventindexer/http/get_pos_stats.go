package http

import (
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
	"github.com/patrickmn/go-cache"
)

type posStatsResponse struct {
	TotalSlashedTokens string `json:"totalSlashedTokens"`
}

func (srv *Server) GetPOSStats(c echo.Context) error {
	cached, found := srv.cache.Get(CacheKeyPOSStats)

	var resp *posStatsResponse

	if found {
		resp = cached.(*posStatsResponse)
	} else {
		totalSlashedTokens, err := srv.eventRepo.GetTotalSlashedTokens(c.Request().Context())
		if err != nil {
			return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
		}

		resp = &posStatsResponse{
			TotalSlashedTokens: totalSlashedTokens.String(),
		}

		srv.cache.Set(CacheKeyPOSStats, resp, cache.DefaultExpiration)
	}

	return c.JSON(http.StatusOK, resp)
}
