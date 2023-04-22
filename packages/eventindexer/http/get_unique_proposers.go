package http

import (
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

type uniqueProposersResp struct {
	Proposers       []eventindexer.UniqueProposersResponse `json:"proposers"`
	UniqueProposers int                                    `json:"uniqueProposers"`
}

func (srv *Server) GetUniqueProposers(c echo.Context) error {
	proposers, err := srv.eventRepo.FindUniqueProposers(
		c.Request().Context(),
	)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	return c.JSON(http.StatusOK, &uniqueProposersResp{
		Proposers:       proposers,
		UniqueProposers: len(proposers),
	})
}
