package http

import (
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
)

// GetByAddressAndEventName
//
//	 returns events by address and name of the event
//
//			@Summary		Get events by address and event name
//			@ID			   	get-events-by-address-and-event-name
//		    @Param			address	query		string		true	"address to query"
//		    @Param			event	query		string		true	"event name to query"
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} paginate.Page
//			@Router			/events [get]
func (srv *Server) GetByAddressAndEventName(c echo.Context) error {
	page, err := srv.eventRepo.GetByAddressAndEventName(
		c.Request().Context(),
		c.Request(),
		c.QueryParam("address"),
		c.QueryParam("event"),
	)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	return c.JSON(http.StatusOK, page)
}
