package relayer

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/assert"
)

func Test_IsInSlice(t *testing.T) {
	if IsInSlice("fake", []string{}) {
		t.Fatal()
	}

	if !IsInSlice("real", []string{"real"}) {
		t.Fatal()
	}
}

type mockConfirmer struct {
}

var (
	notFoundTxHash = common.HexToHash("0x123")
	succeedTxHash  = common.HexToHash("0x456")
	failTxHash     = common.HexToHash("0x789")
	blockNum       = 10
)

func (m *mockConfirmer) TransactionReceipt(ctx context.Context, txHash common.Hash) (*types.Receipt, error) {
	if txHash == notFoundTxHash {
		return nil, ethereum.NotFound
	}

	if txHash == succeedTxHash {
		return &types.Receipt{
			Status:      types.ReceiptStatusSuccessful,
			BlockNumber: new(big.Int).Sub(big.NewInt(int64(blockNum)), big.NewInt(1)),
		}, nil
	}

	return &types.Receipt{
		Status:      types.ReceiptStatusFailed,
		BlockNumber: big.NewInt(1),
	}, nil
}

func (m *mockConfirmer) BlockNumber(ctx context.Context) (uint64, error) {
	return uint64(blockNum), nil
}

func Test_WaitReceipt(t *testing.T) {
	timeoutTicker, cancel := context.WithTimeout(context.Background(), time.Duration(2*time.Second))
	defer cancel()

	tests := []struct {
		name        string
		ctx         context.Context
		txHash      common.Hash
		wantErr     error
		wantReceipt *types.Receipt
	}{
		{
			"success",
			context.Background(),
			succeedTxHash,
			nil,
			&types.Receipt{
				Status:      types.ReceiptStatusSuccessful,
				BlockNumber: new(big.Int).Sub(big.NewInt(int64(blockNum)), big.NewInt(1)),
			},
		},
		{
			"receiptStatusUnsuccessful",
			context.Background(),
			failTxHash,
			fmt.Errorf("transaction reverted, hash: %s", failTxHash),
			nil,
		},
		{
			"ticker timeout",
			timeoutTicker,
			notFoundTxHash,
			errors.New("context deadline exceeded"),
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			receipt, err := WaitReceipt(tt.ctx, &mockConfirmer{}, tt.txHash)
			if tt.wantErr != nil {
				assert.EqualError(t, err, tt.wantErr.Error())
			} else {
				assert.Nil(t, err)
			}
			assert.Equal(t, tt.wantReceipt, receipt)
		})
	}
}

func Test_WaitConfirmations(t *testing.T) {
	timeoutTicker, cancel := context.WithTimeout(context.Background(), time.Duration(2*time.Second))
	defer cancel()

	tests := []struct {
		name    string
		ctx     context.Context
		confs   uint64
		txHash  common.Hash
		wantErr error
	}{
		{
			"success",
			context.Background(),
			1,
			succeedTxHash,
			nil,
		},
		{
			"ticker timeout",
			timeoutTicker,
			1,
			notFoundTxHash,
			errors.New("context deadline exceeded"),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := WaitConfirmations(tt.ctx, &mockConfirmer{}, tt.confs, tt.txHash)
			if tt.wantErr != nil {
				assert.EqualError(t, err, tt.wantErr.Error())
			} else {
				assert.Nil(t, err)
			}
		})
	}
}
