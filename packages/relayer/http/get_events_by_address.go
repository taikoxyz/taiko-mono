package http

import (
	"errors"
	"html"
	"math/big"
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/ethereum/go-ethereum/common"
	"github.com/labstack/echo/v4"
)

func (srv *Server) GetEventsByAddress(c echo.Context) error {
	chainID, ok := new(big.Int).SetString(c.QueryParam("chainID"), 10)
	if !ok {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, errors.New("invalid chain id"))
	}

	address := html.EscapeString(c.QueryParam("address"))

	events, err := srv.eventRepo.FindAllByAddress(c.Request().Context(), chainID, common.HexToAddress(address))
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	return c.JSON(http.StatusOK, events)
}
