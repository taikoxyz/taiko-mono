package http

import (
	"errors"
	"net/http"
	"strconv"

	echo "github.com/labstack/echo/v4"
)

// GetMostRecentStartupByGuardianProverID
//
//	 returns the startup
//
//			@Summary		GetMostRecentStartupByGuardianProverID
//			@ID			   	get-most-recent-startup-by-guardian-prover-id
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} guardianproverhealthcheck.Startup
//			@Router			/mostRecentStartup/:id [get]

func (srv *Server) GetMostRecentStartupByGuardianProverID(
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

	startup, err := srv.startupRepo.GetMostRecentByGuardianProverID(c.Request().Context(), id)
	if err != nil {
		return c.JSON(http.StatusBadRequest, err)
	}

	return c.JSON(http.StatusOK, startup)
}
