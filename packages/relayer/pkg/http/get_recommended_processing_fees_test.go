package http

import (
	"context"
	"math"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
)

func TestGetCost_LayerBehaviour(t *testing.T) {
	srv := &Server{processingFeeMultiplier: 1.1}

	gasLimit := uint64(1)
	gasTipCap := big.NewInt(0)
	baseFee := big.NewInt(1)

	// Calculate base cost used by both branches: gasLimit * (gasTipCap + baseFee*2).
	baseCost := new(big.Int).Mul(
		new(big.Int).SetUint64(gasLimit),
		new(big.Int).Add(gasTipCap, new(big.Int).Mul(baseFee, big.NewInt(2))),
	)

	gotLayer2 := srv.getCost(gasLimit, gasTipCap, baseFee, Layer2)
	gotLayer1 := srv.getCost(gasLimit, gasTipCap, baseFee, Layer1)

	// For Layer2 we expect raw base cost without processingFeeMultiplier.
	assert.Equal(t, baseCost, gotLayer2)

	// For Layer1 we expect base cost multiplied by processingFeeMultiplier, rounded up.
	assert.Equal(t, big.NewInt(3), gotLayer1)
}

func TestGetCost_CeilsMultiplier(t *testing.T) {
	srv := &Server{processingFeeMultiplier: 1.1}

	got := srv.getCost(1, big.NewInt(0), big.NewInt(1), Layer1)

	assert.Equal(t, big.NewInt(3), got)
}

func TestGetCost_UsesExactDecimalMultiplier(t *testing.T) {
	srv := &Server{processingFeeMultiplier: 1.1}

	got := srv.getCost(10, big.NewInt(0), big.NewInt(1), Layer1)

	assert.Equal(t, big.NewInt(22), got)
}

func TestGetCost_ClampsInvalidMultiplier(t *testing.T) {
	srv := &Server{processingFeeMultiplier: 0.5}

	got := srv.getCost(10, big.NewInt(0), big.NewInt(1), Layer1)

	assert.Equal(t, big.NewInt(20), got)
}

func TestFeeTypeGasLimits(t *testing.T) {
	assert.Equal(t, uint64(806657), uint64(Eth))
	assert.Equal(t, uint64(1315360), uint64(ERC20Deployed))
	assert.Equal(t, uint64(1565360), uint64(ERC20NotDeployed))
	assert.Equal(t, uint64(1915872), uint64(ERC721Deployed))
	assert.Equal(t, uint64(3215872), uint64(ERC721NotDeployed))
	assert.Equal(t, uint64(1919456), uint64(ERC1155Deployed))
	assert.Equal(t, uint64(3419456), uint64(ERC1155NotDeployed))
}

func TestGetDestChainBaseFee_Layer2UsesHeaderBaseFee(t *testing.T) {
	destClient := &blockByNumberClient{EthClient: &mock.EthClient{}, block: blockWithBaseFee(big.NewInt(123))}
	srcClient := &blockByNumberClient{EthClient: &mock.EthClient{}, block: blockWithBaseFee(big.NewInt(1))}
	srv := &Server{
		srcEthClient:  srcClient,
		destEthClient: destClient,
	}

	got, err := srv.getDestChainBaseFee(context.Background(), Layer2, mock.MockChainID)

	assert.NoError(t, err)
	assert.Equal(t, big.NewInt(123), got)
	assert.Equal(t, 1, destClient.blockByNumberCalls)
	assert.Equal(t, 0, srcClient.blockByNumberCalls)
}

func TestGetDestChainBaseFee_Layer2MissingBaseFeeFails(t *testing.T) {
	destClient := &blockByNumberClient{EthClient: &mock.EthClient{}, block: blockWithBaseFee(nil)}
	srcClient := &blockByNumberClient{EthClient: &mock.EthClient{}, block: blockWithBaseFee(big.NewInt(1))}
	srv := &Server{
		srcEthClient:  srcClient,
		destEthClient: destClient,
	}

	got, err := srv.getDestChainBaseFee(context.Background(), Layer2, mock.MockChainID)

	assert.Nil(t, got)
	assert.ErrorIs(t, err, relayer.ErrMissingDestBaseFee)
	assert.Equal(t, 1, destClient.blockByNumberCalls)
	assert.Equal(t, 0, srcClient.blockByNumberCalls)
}

type blockByNumberClient struct {
	*mock.EthClient
	block              *types.Block
	blockByNumberCalls int
}

func (c *blockByNumberClient) BlockByNumber(ctx context.Context, number *big.Int) (*types.Block, error) {
	c.blockByNumberCalls++

	return c.block, nil
}

func blockWithBaseFee(baseFee *big.Int) *types.Block {
	header := *mock.Header
	header.BaseFee = baseFee

	return types.NewBlockWithHeader(&header)
}

func Test_FeeTypeString(t *testing.T) {
	// The string is the "type" field of every fee in the API response, so a wrong or empty one
	// silently changes a published contract.
	tests := map[FeeType]string{
		Eth:                "eth",
		ERC20Deployed:      "erc20Deployed",
		ERC20NotDeployed:   "erc20NotDeployed",
		ERC721Deployed:     "erc721Deployed",
		ERC721NotDeployed:  "erc721NotDeployed",
		ERC1155Deployed:    "erc1155Deployed",
		ERC1155NotDeployed: "erc1155NotDeployed",
	}

	for feeType, want := range tests {
		assert.Equal(t, want, feeType.String())
	}

	// Every type the handler iterates has to name itself, or a fee would be published under "".
	for _, feeType := range feeTypes {
		assert.NotEmpty(t, feeType.String(), "fee type %d has no name", uint64(feeType))
	}

	assert.Equal(t, "", FeeType(0).String(), "an unknown gas limit has no name")
}

func Test_parseMultiplier(t *testing.T) {
	tests := []struct {
		name       string
		multiplier float64
		want       *big.Rat
	}{
		{name: "one is the identity", multiplier: 1, want: big.NewRat(1, 1)},
		{name: "a normal multiplier", multiplier: 1.5, want: big.NewRat(3, 2)},
		{name: "many decimal places survive", multiplier: 1.125, want: big.NewRat(9, 8)},
		{
			// Below one would quote a fee under cost, so it is floored rather than honoured.
			name:       "below one falls back to one",
			multiplier: 0.5,
			want:       big.NewRat(1, 1),
		},
		{name: "zero falls back to one", multiplier: 0, want: big.NewRat(1, 1)},
		{name: "negative falls back to one", multiplier: -2, want: big.NewRat(1, 1)},
		{name: "NaN falls back to one", multiplier: math.NaN(), want: big.NewRat(1, 1)},
		{name: "+Inf falls back to one", multiplier: math.Inf(1), want: big.NewRat(1, 1)},
		{name: "-Inf falls back to one", multiplier: math.Inf(-1), want: big.NewRat(1, 1)},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Zero(t, parseMultiplier(tt.multiplier).Cmp(tt.want),
				"got %s want %s", parseMultiplier(tt.multiplier), tt.want)
		})
	}
}
