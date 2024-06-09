package http

import (
	"log/slog"
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
)

// GetNFTMetadataByContractAndTokenID
//
//	 returns nft metadata by contract address and token ID
//
//			@Summary		Get nft metadata by contract address and token ID
//			@ID			   	get-nft-metadata-by-contract-and-token-id
//		    @Param			contractAddress	query		string		true	"contract address to query"
//		    @Param			tokenID	query		string		true	"token ID to query"
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} eventindexer.NFTMetadata
//			@Router			/nftMetadataByContractAndTokenID [get]
func (srv *Server) GetNFTMetadataByContractAndTokenID(c echo.Context) error {
	contractAddress := c.QueryParam("contractAddress")
	tokenID := c.QueryParam("tokenID")

	slog.Info("GetNFTMetadata", "contractAddress", contractAddress, "tokenID", tokenID)

	metadata, err := srv.nftMetadataRepo.GetNFTMetadata(
		c.Request().Context(),
		contractAddress,
		tokenID,
	)

	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	if metadata == nil {
		return webutils.LogAndRenderErrors(c, http.StatusNotFound, echo.NewHTTPError(http.StatusNotFound, "NFT metadata not found"))
	}

	return c.JSON(http.StatusOK, metadata)
}
