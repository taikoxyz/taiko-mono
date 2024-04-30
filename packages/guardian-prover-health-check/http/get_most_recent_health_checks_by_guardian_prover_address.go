package http

import (
	"errors"
	"net/http"

	echo "github.com/labstack/echo/v4"
)

// GetMostRecentHealthCheckByGuardianProverAddress
//
//	 returns the health checks.
//
//			@Summary		GetMostRecentHealthCheckByGuardianProverAddress
//			@ID			   	get-most-recent-health-checks-by-guardian-prover-address
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} paginate.Page
//			@Router			/liveness [get]

func (srv *Server) GetMostRecentHealthCheckByGuardianProverAddress(
	c echo.Context,
) error {
	address := c.Param("address")
	if address == "" {
		return c.JSON(http.StatusBadRequest, errors.New("no address provided"))
	}

	healthCheck, err := srv.healthCheckRepo.GetMostRecentByGuardianProverAddress(
		c.Request().Context(), c.Request(), address,
	)
	if err != nil {
		return c.JSON(http.StatusBadRequest, err)
	}

	return c.JSON(http.StatusOK, healthCheck)
}
