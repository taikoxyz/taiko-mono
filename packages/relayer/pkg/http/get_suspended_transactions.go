package http

import (
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
)

// GetSuspendedTransactions
//
//	 returns suspended transactions
//
//			@Summary		Get suspended transactions
//			@ID			   	get-suspended-transactions
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} paginate.Page
//			@Router			/suspendedTransactions [get]
func (srv *Server) GetSuspendedTransactions(c echo.Context) error {
	page, err := srv.suspendedTxRepo.Find(
		c.Request().Context(),
		c.Request(),
	)

	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	return c.JSON(http.StatusOK, page)
}
