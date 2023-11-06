package http

import (
	"net/http"

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

func (srv *Server) GetHealthChecks(c echo.Context) error {
	page, err := srv.healthCheckRepo.Get(c.Request().Context(), c.Request())
	if err != nil {
		return c.JSON(http.StatusBadRequest, err)
	}

	return c.JSON(http.StatusOK, page)
}
