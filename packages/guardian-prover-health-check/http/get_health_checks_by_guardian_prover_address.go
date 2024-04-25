package http

import (
	"errors"
	"net/http"
	"strconv"

	echo "github.com/labstack/echo/v4"
)

// GetHealthChecksByGuardianProverID
//
//	 returns the health checks.
//
//			@Summary		Get health checks by guardian prover ID
//			@ID			   	get-health-checks-by-guardian-prover-id
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} paginate.Page
//			@Router			/healthchecks [get]
//		    @Param			id	string		true	"guardian prover ID with which to query"

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
