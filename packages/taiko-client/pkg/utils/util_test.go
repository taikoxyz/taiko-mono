package utils_test

import (
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

func TestEncodeDecodeBytes(t *testing.T) {
	b := testutils.RandomBytes(1024)

	compressed, err := utils.Compress(b)
	require.Nil(t, err)
	require.NotEmpty(t, compressed)

	decompressed, err := utils.Decompress(compressed)
	require.Nil(t, err)

	require.Equal(t, b, decompressed)
}

func TestGWeiToWei(t *testing.T) {
	wei, err := utils.GWeiToWei(1.0)
	require.Nil(t, err)

	require.Equal(t, big.NewInt(params.GWei), wei)
}

func TestEtherToWei(t *testing.T) {
	wei, err := utils.EtherToWei(1.0)
	require.Nil(t, err)

	require.Equal(t, big.NewInt(params.Ether), wei)
}

func TestWeiToEther(t *testing.T) {
	eth := utils.WeiToEther(big.NewInt(params.Ether))
	require.Equal(t, new(big.Float).SetUint64(1), eth)
}

func TestWeiToGWei(t *testing.T) {
	gwei := utils.WeiToGWei(big.NewInt(params.GWei))
	require.Equal(t, new(big.Float).SetUint64(1), gwei)
}
