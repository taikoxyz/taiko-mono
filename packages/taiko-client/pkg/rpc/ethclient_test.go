package rpc

import (
	"context"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/require"
)

func TestBlockByHash(t *testing.T) {
	client := newTestClientWithTimeout(t)

	head, err := client.L1.HeaderByNumber(context.Background(), nil)
	require.Nil(t, err)

	block, err := client.L1.BlockByHash(context.Background(), head.Hash())

	require.Nil(t, err)
	require.Equal(t, head.Hash(), block.Hash())
}

func TestBlockNumber(t *testing.T) {
	client := newTestClientWithTimeout(t)

	head, err := client.L1.BlockNumber(context.Background())
	require.Nil(t, err)
	require.Greater(t, head, uint64(0))
}

func TestPeerCount(t *testing.T) {
	client := newTestClientWithTimeout(t)

	_, err := client.L1.PeerCount(context.Background())
	require.NotNil(t, err)
}

func TestTransactionByHash(t *testing.T) {
	client := newTestClientWithTimeout(t)

	_, _, err := client.L1.TransactionByHash(context.Background(), common.Hash{})
	require.NotNil(t, err)
}

func TestTransactionSender(t *testing.T) {
	client := newTestClientWithTimeout(t)

	block, err := client.L1.BlockByNumber(context.Background(), nil)
	require.Nil(t, err)
	require.NotZero(t, block.Transactions().Len())
}

func TestTransactionCount(t *testing.T) {
	client := newTestClientWithTimeout(t)

	block, err := client.L1.BlockByNumber(context.Background(), nil)
	require.Nil(t, err)
	require.NotZero(t, block.Transactions().Len())
}

func TestTransactionInBlock(t *testing.T) {
	client := newTestClientWithTimeout(t)

	block, err := client.L1.BlockByNumber(context.Background(), nil)
	require.Nil(t, err)
	require.NotZero(t, block.Transactions().Len())

	_, err = client.L1.TransactionInBlock(context.Background(), block.Hash(), 0)
	require.Nil(t, err)
}

func TestNetworkID(t *testing.T) {
	client := newTestClientWithTimeout(t)

	networkID, err := client.L1.NetworkID(context.Background())
	require.Nil(t, err)
	require.NotEqual(t, common.Big0.Uint64(), networkID.Uint64())
}

func TestStorageAt(t *testing.T) {
	client := newTestClientWithTimeout(t)

	_, err := client.L1.StorageAt(context.Background(), common.Address{}, common.Hash{}, nil)
	require.Nil(t, err)
}

func TestCodeAt(t *testing.T) {
	client := newTestClientWithTimeout(t)

	_, err := client.L1.CodeAt(context.Background(), common.Address{}, nil)
	require.Nil(t, err)
}

func TestNonceAt(t *testing.T) {
	client := newTestClientWithTimeout(t)

	_, err := client.L1.NonceAt(context.Background(), common.Address{}, nil)
	require.Nil(t, err)
}

func TestPendingBalanceAt(t *testing.T) {
	client := newTestClientWithTimeout(t)

	_, err := client.L1.PendingBalanceAt(context.Background(), common.Address{})
	require.Nil(t, err)
}

func TestPendingStorageAt(t *testing.T) {
	client := newTestClientWithTimeout(t)

	_, err := client.L1.PendingStorageAt(context.Background(), common.Address{}, common.Hash{})
	require.Nil(t, err)
}

func TestPendingCodeAt(t *testing.T) {
	client := newTestClientWithTimeout(t)

	_, err := client.L1.PendingCodeAt(context.Background(), common.Address{})
	require.Nil(t, err)
}

func TestPendingTransactionCount(t *testing.T) {
	client := newTestClientWithTimeout(t)

	_, err := client.L1.PendingTransactionCount(context.Background())
	require.Nil(t, err)
}

func TestCallContractAtHash(t *testing.T) {
	client := newTestClientWithTimeout(t)

	_, err := client.L1.CallContractAtHash(context.Background(), ethereum.CallMsg{}, common.Hash{})
	require.NotNil(t, err)
}

func TestPendingCallContract(t *testing.T) {
	client := newTestClientWithTimeout(t)

	_, err := client.L1.PendingCallContract(context.Background(), ethereum.CallMsg{})
	require.Nil(t, err)
}

func TestSuggestGasPrice(t *testing.T) {
	client := newTestClientWithTimeout(t)

	_, err := client.L1.SuggestGasPrice(context.Background())
	require.Nil(t, err)
}

func TestSuggestGasTipCap(t *testing.T) {
	client := newTestClientWithTimeout(t)

	_, err := client.L1.SuggestGasTipCap(context.Background())
	require.Nil(t, err)
}

func TestFeeHistory(t *testing.T) {
	client := newTestClientWithTimeout(t)

	_, err := client.L1.FeeHistory(context.Background(), 1, nil, []float64{})
	require.Nil(t, err)
}

func TestEstimateGas(t *testing.T) {
	client := newTestClientWithTimeout(t)

	_, err := client.L1.EstimateGas(context.Background(), ethereum.CallMsg{})
	require.Nil(t, err)
}

func TestBatchBlocksByNumbers(t *testing.T) {
	client := newTestClientWithTimeout(t)

	headers, err := client.L1.BatchHeadersByNumbers(context.Background(), []*big.Int{big.NewInt(0), big.NewInt(1)})
	require.Nil(t, err)
	require.Len(t, headers, 2)
}

func TestBatchBlocksByHashes(t *testing.T) {
	client := newTestClientWithTimeout(t)

	headers, err := client.L1.BatchHeadersByNumbers(context.Background(), []*big.Int{big.NewInt(0), big.NewInt(1)})
	require.Nil(t, err)
	require.Len(t, headers, 2)

	hashes := make([]common.Hash, len(headers))
	for i, header := range headers {
		hashes[i] = header.Hash()
	}

	blocks, err := client.L1.BatchBlocksByHashes(context.Background(), hashes)
	require.Nil(t, err)
	require.Len(t, blocks, 2)
}
