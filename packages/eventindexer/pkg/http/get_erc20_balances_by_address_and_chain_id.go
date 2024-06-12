package http

import (
	"net/http"

	"github.com/cyberhorsey/webutils"
	"github.com/labstack/echo/v4"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

// GetERC20BalancesByAddressAndChainID
//
//	 returns erc20 balances by address and chain ID
//
//			@Summary		Get erc20 balances by address and chain ID
//			@ID			   	get-erc20-balances-by-address-and-chain-id
//		    @Param			address	query		string		true	"address to query"
//		    @Param			chainID	query		string		true	"chainID to query"
//			@Accept			json
//			@Produce		json
//			@Success		200	{object} paginate.Page
//			@Router			/erc20sByAddress [get]
func (srv *Server) GetERC20BalancesByAddressAndChainID(c echo.Context) error {
	page, err := srv.erc20BalanceRepo.FindByAddress(
		c.Request().Context(),
		c.Request(),
		c.QueryParam("address"),
		c.QueryParam("chainID"),
	)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	for i := range *page.Items.(*[]eventindexer.ERC20Balance) {
		v := &(*page.Items.(*[]eventindexer.ERC20Balance))[i]

		md, err := srv.erc20BalanceRepo.FindMetadata(c.Request().Context(), v.ChainID, v.ContractAddress)
		if err != nil {
			return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
		}

		v.Metadata = md
	}

	return c.JSON(http.StatusOK, page)
}
