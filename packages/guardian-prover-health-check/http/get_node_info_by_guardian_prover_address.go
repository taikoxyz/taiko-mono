package http

import (
	"errors"
	"net/http"

	echo "github.com/labstack/echo/v4"
	guardianproverhealthcheck "github.com/taikoxyz/taiko-mono/packages/guardian-prover-health-check"
)

// GetNodeInfoByGuardianProverAddress
//
//	 returns the startup
//
//			@Summary		GetNodeInfoByGuardianProverAddress
//			@ID			   	get-node-info-by-guardian-prover-address
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} guardianproverhealthcheck.NodeInfo
//			@Router			/nodeInfo/:address [get]

func (srv *Server) GetNodeInfoByGuardianProverAddress(
	c echo.Context,
) error {
	address := c.Param("address")
	if address == "" {
		return c.JSON(http.StatusBadRequest, errors.New("no address provided"))
	}

	startup, err := srv.startupRepo.GetMostRecentByGuardianProverAddress(
		c.Request().Context(), address)
	if err != nil {
		return c.JSON(http.StatusBadRequest, err)
	}

	healthCheck, err := srv.healthCheckRepo.GetMostRecentByGuardianProverAddress(
		c.Request().Context(), c.Request(), address)
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
