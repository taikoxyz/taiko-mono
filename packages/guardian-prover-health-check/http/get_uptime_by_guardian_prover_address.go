package http

import (
	"errors"
	"net/http"

	echo "github.com/labstack/echo/v4"
)

type uptimeResponse struct {
	Uptime                     float64 `json:"uptime"`
	NumHealthChecksLast24Hours int     `json:"numHealthChecksLast24Hours"`
}

// GetUptimeByGuardianProverAddress
//
//	 returns the stats
//
//			@Summary		Get updatime by guardian prover address
//			@ID			   	get-updatime-by-guardian-prover-address
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} uptimeResponse
//			@Router			/stats/:id [get]

func (srv *Server) GetUptimeByGuardianProverAddress(c echo.Context) error {
	address := c.Param("address")
	if address == "" {
		return c.JSON(http.StatusBadRequest, errors.New("no address provided"))
	}

	uptime, numHealthChecks, err := srv.healthCheckRepo.GetUptimeByGuardianProverAddress(
		c.Request().Context(), address,
	)
	if err != nil {
		return c.JSON(http.StatusBadRequest, err)
	}

	resp := uptimeResponse{
		Uptime:                     uptime,
		NumHealthChecksLast24Hours: numHealthChecks,
	}

	return c.JSON(http.StatusOK, resp)
}
