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

// getBlockInfoResponse
//
//	 returns block info for the chains
//
//			@Summary		Get block info
//			@ID			   	get-block-info
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} getBlockInfoResponse
//			@Router			/blockInfo [get]
func (srv *Server) GetBlockInfo(c echo.Context) error {
	srcChainID, err := srv.srcEthClient.ChainID(c.Request().Context())
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	destChainID, err := srv.destEthClient.ChainID(c.Request().Context())
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	latestSrcBlock, err := srv.srcEthClient.BlockNumber(c.Request().Context())
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	latestDestBlock, err := srv.destEthClient.BlockNumber(c.Request().Context())
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	latestProcessedSrcBlock, err := srv.blockRepo.GetLatestBlockProcessedForEvent(relayer.EventNameMessageSent, srcChainID)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	latestProcessedDestBlock, err := srv.blockRepo.GetLatestBlockProcessedForEvent(
		relayer.EventNameMessageSent,
		destChainID,
	)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	resp := getBlockInfoResponse{
		Data: []blockInfo{
			{
				ChainID:              srcChainID.Int64(),
				LatestProcessedBlock: int64(latestProcessedSrcBlock.Height),
				LatestBlock:          int64(latestSrcBlock),
			},
			{
				ChainID:              destChainID.Int64(),
				LatestProcessedBlock: int64(latestProcessedDestBlock.Height),
				LatestBlock:          int64(latestDestBlock),
			},
		},
	}

	return c.JSON(http.StatusOK, resp)
}
