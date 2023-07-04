package http

import (
	"context"
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
	"github.com/patrickmn/go-cache"
	log "github.com/sirupsen/logrus"
)

type posStatsResponse struct {
	TotalSlashedTokens      string `json:"totalSlashedTokens"`
	CurrentProtocolCapacity string `json:"currentProtocolCapacity"`
}

func (srv *Server) GetPOSStats(c echo.Context) error {
	cached, found := srv.cache.Get(CacheKeyPOSStats)

	var resp *posStatsResponse

	var err error

	if found {
		resp = cached.(*posStatsResponse)
	} else {
		resp, err = srv.getPosStats(c.Request().Context())

		if err != nil {
			return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
		}

		srv.cache.Set(CacheKeyPOSStats, resp, cache.DefaultExpiration)
	}

	return c.JSON(http.StatusOK, resp)
}

func (srv *Server) getPosStats(ctx context.Context) (*posStatsResponse, error) {
	totalSlashedTokens, err := srv.eventRepo.GetTotalSlashedTokens(ctx)
	if err != nil {
		return nil, err
	}

	capacity, err := srv.proverPool.GetCapacity(nil)
	if err != nil {
		return nil, err
	}

	log.Infof(
		"pos stats, slashedTokens: %v, capacity: %v",
		totalSlashedTokens.String(),
		capacity.String(),
	)

	resp := &posStatsResponse{
		TotalSlashedTokens:      totalSlashedTokens.String(),
		CurrentProtocolCapacity: capacity.String(),
	}

	return resp, nil
}
