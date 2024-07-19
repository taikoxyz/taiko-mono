package http

import (
	"errors"
	"net/http"

	echo "github.com/labstack/echo/v4"
	"github.com/labstack/gommon/log"
)

// GetMostRecentSignedBlockByGuardianProverID
//
//	 returns signed block data by each guardian prover.
//
//			@Summary		Get most recent signed block by guardian prover address
//			@ID			   	get-most-recent-signed-block-by-guardian-prover-address
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} block
//			@Router			/signedBlocks/:address[get]

func (srv *Server) GetMostRecentSignedBlockByGuardianProverAddress(c echo.Context) error {
	address := c.Param("address")
	if address == "" {
		return c.JSON(http.StatusBadRequest, errors.New("no address provided"))
	}

	signedBlock, err := srv.signedBlockRepo.GetMostRecentByGuardianProverAddress(
		c.Request().Context(),
		address,
	)

	if err != nil {
		log.Error("Failed to most recent block by guardian prover address", "error", err)
		return echo.NewHTTPError(http.StatusInternalServerError, err)
	}

	return c.JSON(http.StatusOK, signedBlock)
}
