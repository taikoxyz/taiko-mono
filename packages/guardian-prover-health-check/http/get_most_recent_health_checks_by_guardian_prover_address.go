package http

import (
	"errors"
	"net/http"
	"strconv"

	echo "github.com/labstack/echo/v4"
)

// GetMostRecentHealthCheckByGuardianProverID
//
//	 returns the health checks.
//
//			@Summary		GetMostRecentHealthCheckByGuardianProverID
//			@ID			   	get-most-recent-health-checks-by-guardian-prover-id
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} paginate.Page
//			@Router			/liveness [get]

func (srv *Server) GetMostRecentHealthCheckByGuardianProverID(
	c echo.Context,
) error {
	idParam := c.Param("id")
	if idParam == "" {
		return c.JSON(http.StatusBadRequest, errors.New("no id provided"))
	}

	id, err := strconv.Atoi(idParam)
	if err != nil {
		return c.JSON(http.StatusBadRequest, err)
	}

	healthCheck, err := srv.healthCheckRepo.GetMostRecentByGuardianProverID(c.Request().Context(), c.Request(), id)
	if err != nil {
		return c.JSON(http.StatusBadRequest, err)
	}

	return c.JSON(http.StatusOK, healthCheck)
}
