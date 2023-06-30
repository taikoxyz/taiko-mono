package http

import (
	"context"
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
	"github.com/patrickmn/go-cache"
)

type Prover struct {
	CurrentCapacity uint16 `json:"currentCapacity"`
	Address         string `json:"address"`
	AmountStaked    uint64 `json:"amountStaked"`
}

type currentProversResponse struct {
	Provers []Prover `json:"provers"`
}

func (srv *Server) GetCurrentProvers(c echo.Context) error {
	cached, found := srv.cache.Get(CacheKeyCurrentProvers)

	var resp *currentProversResponse

	var err error

	if found {
		resp = cached.(*currentProversResponse)
	} else {
		resp, err = srv.getCurrentProvers(c.Request().Context())
		if err != nil {
			return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
		}

		srv.cache.Set(CacheKeyCurrentProvers, resp, cache.DefaultExpiration)
	}

	return c.JSON(http.StatusOK, resp)
}

func (srv *Server) getCurrentProvers(ctx context.Context) (*currentProversResponse, error) {
	provers, err := srv.proverPool.GetProvers(nil)
	if err != nil {
		return nil, err
	}

	resp := &currentProversResponse{}

	for i, prover := range provers.Provers {
		resp.Provers = append(resp.Provers, Prover{
			CurrentCapacity: prover.CurrentCapacity,
			AmountStaked:    prover.StakedAmount,
			Address:         provers.Stakers[i].Hex(),
		})
	}

	return resp, nil
}
