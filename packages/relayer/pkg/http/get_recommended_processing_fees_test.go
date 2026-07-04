package http

import (
	"context"
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
