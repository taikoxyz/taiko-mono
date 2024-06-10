package repo

import (
	"context"
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
)

func Test_NewERC20BalanceRepo(t *testing.T) {
	tests := []struct {
		name    string
		db      eventindexer.DB
		wantErr error
	}{
		{
			"success",
			&db.DB{},
			nil,
		},
		{
			"noDb",
			nil,
			eventindexer.ErrNoDB,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := NewERC20BalanceRepository(tt.db)
			if err != tt.wantErr {
				t.Errorf("NewERC20BalanceRepository() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
		})
	}
}

func TestIntegration_ERC20Balance_Increase_And_Decrease(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	ERC20BalanceRepo, err := NewERC20BalanceRepository(db)
	assert.Equal(t, nil, err)

	pk, _ := ERC20BalanceRepo.CreateMetadata(context.Background(), 1, "0x123", "SYMBOL", 18)

	bal1, _, err := ERC20BalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(),
		eventindexer.UpdateERC20BalanceOpts{
			ERC20MetadataID: int64(pk),
			ChainID:         1,
			Address:         "0x123",
			ContractAddress: "0x123",
			Amount:          "1",
		}, eventindexer.UpdateERC20BalanceOpts{})
	assert.Equal(t, nil, err)
	assert.NotNil(t, bal1)

	bal2, _, err := ERC20BalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(),
		eventindexer.UpdateERC20BalanceOpts{
			ERC20MetadataID: int64(pk),
			ChainID:         1,
			Address:         "0x123",
			ContractAddress: "0x123456",
			Amount:          "2",
		}, eventindexer.UpdateERC20BalanceOpts{})
	assert.Equal(t, nil, err)
	assert.NotNil(t, bal2)

	tests := []struct {
		name         string
		increaseOpts eventindexer.UpdateERC20BalanceOpts
		decreaseOpts eventindexer.UpdateERC20BalanceOpts
		wantErr      error
	}{
		{
			"success",
			eventindexer.UpdateERC20BalanceOpts{
				ERC20MetadataID: int64(pk),
				ChainID:         1,
				Address:         "0x123",
				ContractAddress: "0x123456789",
				Amount:          "1",
			},
			eventindexer.UpdateERC20BalanceOpts{
				ERC20MetadataID: int64(pk),
				ChainID:         1,
				Address:         "0x123",
				ContractAddress: "0x123",
				Amount:          "1",
			},
			nil,
		},
		{
			"one left",
			eventindexer.UpdateERC20BalanceOpts{
				ERC20MetadataID: int64(pk),
				ChainID:         1,
				Address:         "0x123",
				ContractAddress: "0x123456789",
				Amount:          "1",
			},
			eventindexer.UpdateERC20BalanceOpts{
				ERC20MetadataID: int64(pk),
				ChainID:         1,
				Address:         "0x123",
				ContractAddress: "0x123456",
				Amount:          "1",
			},
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, _, err := ERC20BalanceRepo.IncreaseAndDecreaseBalancesInTx(context.Background(), tt.increaseOpts, tt.decreaseOpts)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

// TODO: fix this test
func TestIntegration_ERC20Balance_FindByAddress(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	ERC20BalanceRepo, err := NewERC20BalanceRepository(db)
	assert.Equal(t, nil, err)

	tests := []struct {
		name    string
		address string
		chainID string
		wantErr error
	}{
		{
			"success",
			"0x123",
			"1",
			nil,
		},
	}

	get, err := http.NewRequest("GET", "", nil)
	assert.Equal(t, nil, err)

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := ERC20BalanceRepo.FindByAddress(
				context.Background(),
				get,
				tt.address,
				tt.chainID)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}
