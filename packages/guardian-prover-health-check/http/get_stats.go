package http

import (
	"net/http"

	echo "github.com/labstack/echo/v4"
)

// GetStats
//
//	 returns the stats
//
//			@Summary		Getstats
//			@ID			   	get-stats
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} paginate.Page
//			@Router			/stats [get]

func (srv *Server) GetStats(c echo.Context) error {
	page, err := srv.statRepo.Get(c.Request().Context(), c.Request())
	if err != nil {
		return c.JSON(http.StatusBadRequest, err)
	}

	return c.JSON(http.StatusOK, page)
}
