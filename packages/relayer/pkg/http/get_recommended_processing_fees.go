package http

import (
	"context"
	"math/big"
	"net/http"
	"strconv"

	"github.com/cyberhorsey/webutils"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/consensus/misc/eip1559"
	"github.com/ethereum/go-ethereum/params"
	"github.com/labstack/echo/v4"
)

type getRecommendedProcessingFeesResponse struct {
	Fees []fee `json:"fees"`
}

type fee struct {
	Type        string `json:"type"`
	Amount      string `json:"amount"`
	DestChainID uint64 `json:"destChainID"`
	GasLimit    string `json:"gasLimit"`
}

type FeeType uint64

// gas limits
var (
	Eth                FeeType = 900000
	ERC20NotDeployed   FeeType = 1650000
	ERC20Deployed      FeeType = 1000000
	ERC721NotDeployed  FeeType = 2500000
	ERC721Deployed     FeeType = 1500000
	ERC1155NotDeployed FeeType = 2650000
	ERC1155Deployed    FeeType = 1850000
)

var (
	feeTypes = []FeeType{
		Eth,
		ERC20Deployed,
		ERC20NotDeployed,
		ERC721Deployed,
		ERC721NotDeployed,
		ERC1155Deployed,
		ERC1155NotDeployed}
)

func (f FeeType) String() string {
	switch f {
	case Eth:
		return "eth"
	case ERC20NotDeployed:
		return "erc20NotDeployed"
	case ERC20Deployed:
		return "erc20Deployed"
	case ERC721Deployed:
		return "erc721Deployed"
	case ERC721NotDeployed:
		return "erc721NotDeployed"
	case ERC1155NotDeployed:
		return "erc1155NotDeployed"
	case ERC1155Deployed:
		return "erc1155Deployed"
	default:
		return ""
	}
}

type layer int

const (
	Layer1 layer = iota
	Layer2 layer = iota
)

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
func (srv *Server) GetRecommendedProcessingFees(c echo.Context) error {
	fees := make([]fee, 0)

	srcChainID, err := srv.srcEthClient.ChainID(c.Request().Context())
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	destChainID, err := srv.destEthClient.ChainID(c.Request().Context())
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	srcGasTipCap, err := srv.srcEthClient.SuggestGasTipCap(c.Request().Context())
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	srcBaseFee, err := srv.getDestChainBaseFee(c.Request().Context(), Layer1, srcChainID)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	destBaseFee, err := srv.getDestChainBaseFee(c.Request().Context(), Layer2, destChainID)
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	destGasTipCap, err := srv.destEthClient.SuggestGasTipCap(c.Request().Context())
	if err != nil {
		return webutils.LogAndRenderErrors(c, http.StatusUnprocessableEntity, err)
	}

	for _, f := range feeTypes {
		fees = append(fees, fee{
			Type:        f.String(),
			Amount:      srv.getCost(c.Request().Context(), uint64(f), destGasTipCap, destBaseFee, Layer1).String(),
			DestChainID: srcChainID.Uint64(),
			GasLimit:    strconv.Itoa(int(f)),
		})

		fees = append(fees, fee{
			Type:        f.String(),
			Amount:      srv.getCost(c.Request().Context(), uint64(f), srcGasTipCap, srcBaseFee, Layer2).String(),
			DestChainID: destChainID.Uint64(),
			GasLimit:    strconv.Itoa(int(f)),
		})
	}

	resp := getRecommendedProcessingFeesResponse{
		Fees: fees,
	}

	return c.JSON(http.StatusOK, resp)
}

func (srv *Server) getCost(
	ctx context.Context,
	gasLimit uint64,
	gasTipCap *big.Int,
	baseFee *big.Int,
	destLayer layer,
) *big.Int {
	cost := new(big.Int).Mul(
		new(big.Int).SetUint64(gasLimit),
		new(big.Int).Add(gasTipCap, baseFee))

	if destLayer == Layer2 {
		return cost
	}

	costRat := new(big.Rat).SetInt(cost)

	multiplierRat := new(big.Rat).SetFloat64(srv.processingFeeMultiplier)

	costRat.Mul(costRat, multiplierRat)

	costAfterMultiplier := new(big.Int).Div(costRat.Num(), costRat.Denom())

	return costAfterMultiplier
}

func (srv *Server) getDestChainBaseFee(ctx context.Context, destLayer layer, chainID *big.Int) (*big.Int, error) {
	blk, err := srv.srcEthClient.BlockByNumber(ctx, nil)
	if err != nil {
		return nil, err
	}

	var baseFee *big.Int

	if destLayer == Layer2 {
		latestL2Block, err := srv.destEthClient.BlockByNumber(ctx, nil)
		if err != nil {
			return nil, err
		}

		bf, err := srv.taikoL2.GetBasefee(&bind.CallOpts{Context: ctx}, blk.NumberU64(), uint32(latestL2Block.GasUsed()))
		if err != nil {
			return nil, err
		}

		baseFee = bf.Basefee
	} else {
		cfg := params.NetworkIDToChainConfigOrDefault(chainID)
		baseFee = eip1559.CalcBaseFee(cfg, blk.Header())
	}

	return baseFee, nil
}
