package http

import (
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

type blockInfo struct {
	ChainID              int64 `json:"chainID"`
	LatestProcessedBlock int64 `json:"latestProcessedBlock"`
	LatestBlock          int64 `json:"latestBlock"`
}

type getBlockInfoResponse struct {
	Data []blockInfo `json:"data"`
}

func (srv *Server) GetBlockInfo(c echo.Context) error {
	l1ChainID, err := srv.l1EthClient.ChainID(c.Request().Context())
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	l2ChainID, err := srv.l2EthClient.ChainID(c.Request().Context())
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	latestL1Block, err := srv.l1EthClient.BlockNumber(c.Request().Context())
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	latestL2Block, err := srv.l2EthClient.BlockNumber(c.Request().Context())
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	latestProcessedL1Block, err := srv.blockRepo.GetLatestBlockProcessedForEvent(relayer.EventNameMessageSent, l1ChainID)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	latestProcessedL2Block, err := srv.blockRepo.GetLatestBlockProcessedForEvent(relayer.EventNameMessageSent, l2ChainID)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	resp := getBlockInfoResponse{
		Data: []blockInfo{
			{
				ChainID:              l1ChainID.Int64(),
				LatestProcessedBlock: int64(latestProcessedL1Block.Height),
				LatestBlock:          int64(latestL1Block),
			},
			{
				ChainID:              l2ChainID.Int64(),
				LatestProcessedBlock: int64(latestProcessedL2Block.Height),
				LatestBlock:          int64(latestL2Block),
			},
		},
	}

	return c.JSON(http.StatusOK, resp)
}
