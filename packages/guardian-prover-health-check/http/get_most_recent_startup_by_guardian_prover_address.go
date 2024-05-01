package http

import (
	"errors"
	"net/http"

	echo "github.com/labstack/echo/v4"
)

// GetMostRecentStartupByGuardianProverAddress
//
//	 returns the startup
//
//			@Summary		GetMostRecentStartupByGuardianProverAddress
//			@ID			   	get-most-recent-startup-by-guardian-prover-address
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} guardianproverhealthcheck.Startup
//			@Router			/mostRecentStartup/:address [get]

func (srv *Server) GetMostRecentStartupByGuardianProverAddress(
	c echo.Context,
) error {
	address := c.Param("address")
	if address == "" {
		return c.JSON(http.StatusBadRequest, errors.New("no address provided"))
	}

	startup, err := srv.startupRepo.GetMostRecentByGuardianProverAddress(
		c.Request().Context(), address,
	)
	if err != nil {
		return c.JSON(http.StatusBadRequest, err)
	}

	return c.JSON(http.StatusOK, startup)
}
