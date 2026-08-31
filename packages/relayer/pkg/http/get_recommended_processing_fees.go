package http

import (
	"context"
	"math"
	"math/big"
	"net/http"
	"strconv"

	"github.com/cyberhorsey/webutils"
	"github.com/ethereum/go-ethereum/consensus/misc/eip1559"
	"github.com/ethereum/go-ethereum/params"
	"github.com/labstack/echo/v4"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
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
	Eth                FeeType = FeeType(messageMinGasLimit(0) + 1)
	ERC20NotDeployed   FeeType = FeeType(messageMinGasLimit(516) + 750_000)
	ERC20Deployed      FeeType = FeeType(messageMinGasLimit(516) + 500_000)
	ERC721NotDeployed  FeeType = FeeType(messageMinGasLimit(548) + 2_400_000)
	ERC721Deployed     FeeType = FeeType(messageMinGasLimit(548) + 1_100_000)
	ERC1155NotDeployed FeeType = FeeType(messageMinGasLimit(772) + 2_600_000)
	ERC1155Deployed    FeeType = FeeType(messageMinGasLimit(772) + 1_100_000)
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

// GetRecommendedProcessingFees
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

	srcChainID := srv.srcChainID
	destChainID := srv.destChainID

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
		paddedGasLimit := relayer.PaddedMessageGasLimit(uint64(f), true)

		fees = append(fees, fee{
			Type:        f.String(),
			Amount:      srv.getCost(paddedGasLimit, destGasTipCap, destBaseFee, Layer2).String(),
			DestChainID: destChainID.Uint64(),
			GasLimit:    strconv.Itoa(int(f)),
		})

		fees = append(fees, fee{
			Type:        f.String(),
			Amount:      srv.getCost(paddedGasLimit, srcGasTipCap, srcBaseFee, Layer1).String(),
			DestChainID: srcChainID.Uint64(),
			GasLimit:    strconv.Itoa(int(f)),
		})
	}

	resp := getRecommendedProcessingFeesResponse{
		Fees: fees,
	}

	return c.JSON(http.StatusOK, resp)
}

func (srv *Server) getCost(
	gasLimit uint64,
	gasTipCap *big.Int,
	baseFee *big.Int,
	destLayer layer,
) *big.Int {
	cost := new(big.Int).Mul(
		new(big.Int).SetUint64(gasLimit),
		new(big.Int).Add(gasTipCap, new(big.Int).Mul(baseFee, big.NewInt(2))))

	if destLayer == Layer2 {
		return cost
	}

	return mulRatCeil(cost, srv.processingFeeMultiplier)
}

func (srv *Server) getDestChainBaseFee(ctx context.Context, destLayer layer, chainID *big.Int) (*big.Int, error) {
	if destLayer == Layer2 {
		latestL2Block, err := srv.destEthClient.BlockByNumber(ctx, nil)
		if err != nil {
			return nil, err
		}

		if latestL2Block.BaseFee() != nil {
			return latestL2Block.BaseFee(), nil
		}

		return nil, relayer.ErrMissingDestBaseFee
	}

	blk, err := srv.srcEthClient.BlockByNumber(ctx, nil)
	if err != nil {
		return nil, err
	}

	cfg := params.NetworkIDToChainConfigOrDefault(chainID)

	return eip1559.CalcBaseFee(cfg, blk.Header()), nil
}

func messageMinGasLimit(dataLength uint64) uint64 {
	return (((dataLength+31)/32)*32+416)*16 + 800_000
}

func mulRatCeil(value *big.Int, multiplier float64) *big.Int {
	valueRat := new(big.Rat).SetInt(value)
	multiplierRat := parseMultiplier(multiplier)
	valueRat.Mul(valueRat, multiplierRat)

	quotient, remainder := new(big.Int).QuoRem(valueRat.Num(), valueRat.Denom(), new(big.Int))
	if remainder.Sign() > 0 {
		quotient.Add(quotient, big.NewInt(1))
	}

	return quotient
}

func parseMultiplier(multiplier float64) *big.Rat {
	if multiplier < 1 || math.IsNaN(multiplier) || math.IsInf(multiplier, 0) {
		return big.NewRat(1, 1)
	}

	if rat, ok := new(big.Rat).SetString(strconv.FormatFloat(multiplier, 'f', -1, 64)); ok {
		return rat
	}

	return big.NewRat(1, 1)
}
