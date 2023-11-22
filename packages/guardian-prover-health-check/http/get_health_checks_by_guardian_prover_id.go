package http

import (
	"errors"
	"net/http"
	"strconv"

	echo "github.com/labstack/echo/v4"
)

// GetHealthChecks
//
//	 returns the health checks.
//
//			@Summary		Get health checks
//			@ID			   	get-health-checks
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} paginate.Page
//			@Router			/healthchecks [get]

func (srv *Server) GetHealthChecksByGuardianProverID(c echo.Context) error {
	idParam := c.Param("id")
	if idParam == "" {
		return c.JSON(http.StatusBadRequest, errors.New("no id provided"))
	}

	id, err := strconv.Atoi(idParam)
	if err != nil {
		return c.JSON(http.StatusBadRequest, err)
	}

	page, err := srv.healthCheckRepo.GetByGuardianProverID(c.Request().Context(), c.Request(), id)
	if err != nil {
		return c.JSON(http.StatusBadRequest, err)
	}

	return c.JSON(http.StatusOK, page)
}
