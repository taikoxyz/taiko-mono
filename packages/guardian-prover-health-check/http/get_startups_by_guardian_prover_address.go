package http

import (
	"errors"
	"net/http"

	echo "github.com/labstack/echo/v4"
)

// GetStartupsByGuardianProverAddress
//
//	 returns a paginated list of startups by guardian prover address
//
//			@Summary		Get startups by guardian prover address
//			@ID			   	get-startups-by-guardian-prover-address
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} paginate.Page
//			@Router			/startups [get]
//		    @Param			address	string		true	"guardian prover address with which to query"

func (srv *Server) GetStartupsByGuardianProverAddress(c echo.Context) error {
	address := c.Param("address")
	if address == "" {
		return c.JSON(http.StatusBadRequest, errors.New("no address provided"))
	}

	page, err := srv.startupRepo.GetByGuardianProverAddress(c.Request().Context(), c.Request(), address)
	if err != nil {
		return c.JSON(http.StatusBadRequest, err)
	}

	return c.JSON(http.StatusOK, page)
}
