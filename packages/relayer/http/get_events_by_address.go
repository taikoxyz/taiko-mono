package http

import (
	"html"
	"math/big"
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/ethereum/go-ethereum/common"
	"github.com/labstack/echo/v4"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

func (srv *Server) GetEventsByAddress(c echo.Context) error {
	chainID, ok := new(big.Int).SetString(c.QueryParam("chainID"), 10)

	address := html.EscapeString(c.QueryParam("address"))

	var events []*relayer.Event

	var err error

	if ok {
		events, err = srv.eventRepo.FindAllByAddressAndChainID(
			c.Request().Context(),
			chainID,
			common.HexToAddress(address),
		)
	} else {
		events, err = srv.eventRepo.FindAllByAddress(
			c.Request().Context(),
			common.HexToAddress(address),
		)
	}

	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	return c.JSON(http.StatusOK, events)
}
