package http

import (
	"errors"
	"net/http"
	"strconv"

	echo "github.com/labstack/echo/v4"
)

// GetStats
//
//	 returns the stats
//
//			@Summary		Get stats by guardian prover id
//			@ID			   	get-stats-by-guardian-prover-id
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} paginate.Page
//			@Router			/stats/:id [get]

func (srv *Server) GetStatsByGuardianProverID(c echo.Context) error {
	idParam := c.Param("id")
	if idParam == "" {
		return c.JSON(http.StatusBadRequest, errors.New("no id provided"))
	}

	id, err := strconv.Atoi(idParam)
	if err != nil {
		return c.JSON(http.StatusBadRequest, err)
	}

	page, err := srv.statRepo.GetByGuardianProverID(c.Request().Context(), c.Request(), id)
	if err != nil {
		return c.JSON(http.StatusBadRequest, err)
	}

	return c.JSON(http.StatusOK, page)
}
