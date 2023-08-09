package http

import (
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
)

func (srv *Server) GetNFTBalancesByAddessAndChainID(c echo.Context) error {
	page, err := srv.nftBalanceRepo.FindByAddress(
		c.Request().Context(),
		c.Request(),
		c.QueryParam("address"),
		c.QueryParam("chainID"),
	)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	return c.JSON(http.StatusOK, page)
}
