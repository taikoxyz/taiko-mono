package http

import (
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

type NFTBalanceWithMetadata struct {
	Balance  eventindexer.NFTBalance   `json:"balance"`
	Metadata *eventindexer.NFTMetadata `json:"metadata"`
}

type NFTBalancesResponse struct {
	Balances []NFTBalanceWithMetadata `json:"balances"`
}

// GetNFTBalancesByAddressAndChainID
//
//	 returns nft balances by address and chain ID
//
//			@Summary		Get nft balances by address and chain ID
//			@ID			   	get-nft-balances-by-address-and-chain-id
//		    @Param			address	query		string		true	"address to query"
//		    @Param			chainID	query		string		true	"chainID to query"
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} paginate.Page
//			@Router			/nftsByAddress [get]
func (srv *Server) GetNFTBalancesByAddressAndChainID(c echo.Context) error {
	page, err := srv.nftBalanceRepo.FindByAddress(
		c.Request().Context(),
		c.Request(),
		c.QueryParam("address"),
		c.QueryParam("chainID"),
	)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	balances, ok := page.Items.(*[]eventindexer.NFTBalance)
	if !ok {
		return webutils.LogAndRenderErrors(c, http.StatusInternalServerError, echo.NewHTTPError(http.StatusInternalServerError, "Failed to cast paginated items"))
	}

	var balancesWithMetadata []NFTBalanceWithMetadata
	for _, balance := range *balances {
		metadata, err := srv.nftMetadataRepo.GetNFTMetadata(
			c.Request().Context(),
			balance.ContractAddress,
			balance.TokenID,
		)
		if err != nil {
			return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
		}

		balancesWithMetadata = append(balancesWithMetadata, NFTBalanceWithMetadata{
			Balance:  balance,
			Metadata: metadata,
		})
	}

	response := NFTBalancesResponse{
		Balances: balancesWithMetadata,
	}

	return c.JSON(http.StatusOK, response)
}
