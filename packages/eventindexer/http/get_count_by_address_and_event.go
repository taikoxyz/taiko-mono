package http

import (
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
)

// GetCountByAddressAndEventName
//
//	 returns count of events by user address and event name
//
//			@Summary		Get count of events by user address and event name
//			@ID			   	get-charts-by-task
//		    @Param			address	query		string		true	"address to query"
//		    @Param			event	query		string		true	"event name to query"
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} GetCountByAddressAndEventNameResp
//			@Router			/eventByAddress [get]
type GetCountByAddressAndEventNameResp struct {
	Count int `json:"count"`
}

func (srv *Server) GetCountByAddressAndEventName(c echo.Context) error {
	count, err := srv.eventRepo.GetCountByAddressAndEventName(
		c.Request().Context(),
		c.QueryParam("address"),
		c.QueryParam("event"),
	)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	return c.JSON(http.StatusOK, &GetCountByAddressAndEventNameResp{
		Count: count,
	})
}
