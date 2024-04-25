package http

import (
	"net/http"
	"strconv"

	echo "github.com/labstack/echo/v4"
	"github.com/labstack/gommon/log"
)

// GetMostRecentSignedBlockByGuardianProverID
//
//	 returns signed block data by each guardian prover.
//
//			@Summary		Get most recent signed block by guardian prover ID
//			@ID			   	get-most-recent-signed-block-by-guardian-prover-ID
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} block
//			@Router			/signedBlocks/:id[get]

func (srv *Server) GetMostRecentSignedBlockByGuardianProverID(c echo.Context) error {
	id, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		log.Error("Failed to convert id to integer", "error", err)
		return echo.NewHTTPError(http.StatusInternalServerError, err)
	}

	signedBlock, err := srv.signedBlockRepo.GetMostRecentByGuardianProverID(
		id,
	)

	if err != nil {
		log.Error("Failed to most recent block by guardian prover ID", "error", err)
		return echo.NewHTTPError(http.StatusInternalServerError, err)
	}

	return c.JSON(http.StatusOK, signedBlock)
}
