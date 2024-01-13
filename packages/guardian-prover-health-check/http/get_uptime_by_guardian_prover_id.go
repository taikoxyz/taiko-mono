package http

import (
	"errors"
	"net/http"
	"strconv"

	echo "github.com/labstack/echo/v4"
)

type uptimeResponse struct {
	Uptime                     float64 `json:"uptime"`
	NumHealthChecksLast24Hours int     `json:"numHealthChecksLast24Hours"`
}

// GetUptimeByGuardianProverID
//
//	 returns the stats
//
//			@Summary		Get updatime by guardian prover id
//			@ID			   	get-updatime-by-guardian-prover-id
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} uptimeResponse
//			@Router			/stats/:id [get]

func (srv *Server) GetUptimeByGuardianProverID(c echo.Context) error {
	idParam := c.Param("id")
	if idParam == "" {
		return c.JSON(http.StatusBadRequest, errors.New("no id provided"))
	}

	id, err := strconv.Atoi(idParam)
	if err != nil {
		return c.JSON(http.StatusBadRequest, err)
	}

	uptime, numHealthChecks, err := srv.healthCheckRepo.GetUptimeByGuardianProverID(c.Request().Context(), id)
	if err != nil {
		return c.JSON(http.StatusBadRequest, err)
	}

	resp := uptimeResponse{
		Uptime:                     uptime,
		NumHealthChecksLast24Hours: numHealthChecks,
	}

	return c.JSON(http.StatusOK, resp)
}
