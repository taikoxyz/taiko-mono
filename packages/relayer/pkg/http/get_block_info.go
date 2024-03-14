package http

import (
	"errors"
	"math/big"
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
	var srcChainID *big.Int

	var destChainID *big.Int

	var err error

	srcChainParam := c.QueryParam("srcChainID")

	destChainParam := c.QueryParam("destChainID")

	if srcChainParam == "" {
		srcChainID, err = srv.srcEthClient.ChainID(c.Request().Context())
		if err != nil {
			return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
		}
	} else {
		srcChain, ok := new(big.Int).SetString(srcChainParam, 10)
		if !ok {
			return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, errors.New("invalid src chain param"))
		}

		srcChainID = srcChain
	}

	if destChainParam == "" {
		destChainID, err = srv.destEthClient.ChainID(c.Request().Context())
		if err != nil {
			return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
		}
	} else {
		destChain, ok := new(big.Int).SetString(destChainParam, 10)
		if !ok {
			return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, errors.New("invalid dest chain param"))
		}

		destChainID = destChain
	}

	latestSrcBlock, err := srv.srcEthClient.BlockNumber(c.Request().Context())
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	latestDestBlock, err := srv.destEthClient.BlockNumber(c.Request().Context())
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	latestProcessedSrcBlock, err := srv.eventRepo.FindLatestBlockID(
		relayer.EventNameMessageSent,
		srcChainID.Uint64(),
		destChainID.Uint64(),
	)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	latestProcessedDestBlock, err := srv.eventRepo.FindLatestBlockID(
		relayer.EventNameMessageSent,
		destChainID.Uint64(),
		srcChainID.Uint64(),
	)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	resp := getBlockInfoResponse{
		Data: []blockInfo{
			{
				ChainID:              srcChainID.Int64(),
				LatestProcessedBlock: int64(latestProcessedSrcBlock),
				LatestBlock:          int64(latestSrcBlock),
			},
			{
				ChainID:              destChainID.Int64(),
				LatestProcessedBlock: int64(latestProcessedDestBlock),
				LatestBlock:          int64(latestDestBlock),
			},
		},
	}

	return c.JSON(http.StatusOK, resp)
}
