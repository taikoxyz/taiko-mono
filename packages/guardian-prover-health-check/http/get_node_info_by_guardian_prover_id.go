package http

import (
	"errors"
	"net/http"
	"strconv"

	echo "github.com/labstack/echo/v4"
	guardianproverhealthcheck "github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check"
)

// GetNodeInfoByGuardianProverID
//
//	 returns the startup
//
//			@Summary		GetNodeInfoByGuardianProverID
//			@ID			   	get-node-info-by-guardian-prover-id
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} guardianproverhealthcheck.NodeInfo
//			@Router			/nodeInfo/:id [get]

func (srv *Server) GetNodeInfoByGuardianProverID(
	c echo.Context,
) error {
	idParam := c.Param("id")
	if idParam == "" {
		return c.JSON(http.StatusBadRequest, errors.New("no id provided"))
	}

	id, err := strconv.Atoi(idParam)
	if err != nil {
		return c.JSON(http.StatusBadRequest, err)
	}

	startup, err := srv.startupRepo.GetMostRecentByGuardianProverID(c.Request().Context(), id)
	if err != nil {
		return c.JSON(http.StatusBadRequest, err)
	}

	healthCheck, err := srv.healthCheckRepo.GetMostRecentByGuardianProverID(c.Request().Context(), c.Request(), id)
	if err != nil {
		return c.JSON(http.StatusBadRequest, err)
	}

	nodeInfo := guardianproverhealthcheck.NodeInfo{
		Startup:             *startup,
		LatestL1BlockNumber: healthCheck.LatestL1Block,
		LatestL2BlockNumber: healthCheck.LatestL2Block,
	}

	return c.JSON(http.StatusOK, nodeInfo)
}
