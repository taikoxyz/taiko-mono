package utils

import (
	"context"
	"errors"
	"math/big"
	"testing"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// blobFeeBackend is a wrapped backend that answers the typed call, as *ethclient.Client does.
type blobFeeBackend struct {
	txmgr.ETHBackend
	fee *big.Int
	err error
}

func (b *blobFeeBackend) BlobBaseFee(_ context.Context) (*big.Int, error) {
	return b.fee, b.err
}

// rpcOnlyBackend is a wrapped backend that exposes only the raw client, the estimator's own
// fallback shape.
type rpcOnlyBackend struct {
	txmgr.ETHBackend
	client *rpc.Client
}

func (b *rpcOnlyBackend) Client() *rpc.Client { return b.client }

// blobFeeAPI serves eth_blobBaseFee in process, so the fallback is exercised over a real client
// rather than a stub of one.
type blobFeeAPI struct{ fee int64 }

func (a *blobFeeAPI) BlobBaseFee() (*hexutil.Big, error) {
	return (*hexutil.Big)(big.NewInt(a.fee)), nil
}

// estimatorBackend carries what DefaultGasPriceEstimatorFn reads before it reaches the blob fee.
type estimatorBackend struct {
	txmgr.ETHBackend
	fee *big.Int
}

func (b *estimatorBackend) SuggestGasTipCap(_ context.Context) (*big.Int, error) {
	return big.NewInt(2), nil
}

func (b *estimatorBackend) HeaderByNumber(_ context.Context, _ *big.Int) (*types.Header, error) {
	excess := uint64(131072)

	return &types.Header{BaseFee: big.NewInt(11), ExcessBlobGas: &excess}, nil
}

func (b *estimatorBackend) BlobBaseFee(_ context.Context) (*big.Int, error) {
	return b.fee, nil
}

func TestSendingBackend_AnswersTheEstimatorsBlobBaseFeeAssertion(t *testing.T) {
	b := NewSendingBackend(&estimatorBackend{fee: big.NewInt(13)}, []TxSender{&fakeSender{}}, nil)

	// The whole point: the wrapped backend is reached through the assertion the transaction
	// manager actually makes, on the code path that signs every claim.
	tip, baseFee, blobFee, err := txmgr.DefaultGasPriceEstimatorFn(context.Background(), b)

	require.NoError(t, err, "a wrapper that hides the blob base fee fails every send on L1")
	assert.Equal(t, big.NewInt(2), tip)
	assert.Equal(t, big.NewInt(11), baseFee)
	assert.Equal(t, big.NewInt(13), blobFee)
}

func TestSendingBackend_ForwardsTheBlobBaseFeeCall(t *testing.T) {
	wrapped := &blobFeeBackend{fee: big.NewInt(42)}
	b := NewSendingBackend(wrapped, nil, nil)

	fee, err := b.BlobBaseFee(context.Background())

	require.NoError(t, err)
	assert.Equal(t, big.NewInt(42), fee)
}

func TestSendingBackend_ForwardsTheBlobBaseFeeError(t *testing.T) {
	wrapped := &blobFeeBackend{err: errors.New("node is behind")}
	b := NewSendingBackend(wrapped, nil, nil)

	_, err := b.BlobBaseFee(context.Background())

	assert.ErrorContains(t, err, "node is behind")
}

func TestSendingBackend_FallsBackToTheRawClientForTheBlobBaseFee(t *testing.T) {
	server := rpc.NewServer()
	require.NoError(t, server.RegisterName("eth", &blobFeeAPI{fee: 7}))

	t.Cleanup(server.Stop)

	client := rpc.DialInProc(server)
	t.Cleanup(client.Close)

	b := NewSendingBackend(&rpcOnlyBackend{client: client}, nil, nil)

	fee, err := b.BlobBaseFee(context.Background())

	require.NoError(t, err)
	assert.Equal(t, big.NewInt(7), fee)
}

func TestSendingBackend_ReportsABackendThatCannotAnswerTheBlobBaseFee(t *testing.T) {
	b := NewSendingBackend(&fakeBackend{}, nil, nil)

	_, err := b.BlobBaseFee(context.Background())

	assert.ErrorContains(t, err, "does not support blob base fee")
}
