package http

import (
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
)

type posStatsResponse struct {
	TotalSlashedTokens string `json:"totalSlashedTokens"`
}

func (srv *Server) GetPOSStats(c echo.Context) error {
	totalSlashedTokens, err := srv.eventRepo.GetTotalSlashedTokens(c.Request().Context())
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	return c.JSON(http.StatusOK, &posStatsResponse{
		TotalSlashedTokens: totalSlashedTokens.String(),
	})
}
