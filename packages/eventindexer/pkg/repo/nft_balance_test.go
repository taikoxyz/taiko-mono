package repo

import (
	"context"
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
)

func Test_NewNFTBalanceRepo(t *testing.T) {
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
			_, err := NewNFTBalanceRepository(tt.db)
			if err != tt.wantErr {
				t.Errorf("NewNFTBalanceRepository() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
		})
	}
}

func TestIntegration_NFTBalance_Increase(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	nftBalanceRepo, err := NewNFTBalanceRepository(db)
	assert.Equal(t, nil, err)

	tests := []struct {
		name    string
		opts    eventindexer.UpdateNFTBalanceOpts
		wantErr error
	}{
		{
			"success",
			eventindexer.UpdateNFTBalanceOpts{
				ChainID:         1,
				Address:         "0x123",
				TokenID:         1,
				ContractAddress: "0x123",
				ContractType:    "ERC721",
				Amount:          1,
			},
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := nftBalanceRepo.IncreaseBalance(context.Background(), tt.opts)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

func TestIntegration_NFTBalance_Decrease(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	nftBalanceRepo, err := NewNFTBalanceRepository(db)
	assert.Equal(t, nil, err)

	bal1, err := nftBalanceRepo.IncreaseBalance(context.Background(),
		eventindexer.UpdateNFTBalanceOpts{
			ChainID:         1,
			Address:         "0x123",
			TokenID:         1,
			ContractAddress: "0x123",
			ContractType:    "ERC721",
			Amount:          1,
		})
	assert.Equal(t, nil, err)
	assert.NotNil(t, bal1)

	bal2, err := nftBalanceRepo.IncreaseBalance(context.Background(),
		eventindexer.UpdateNFTBalanceOpts{
			ChainID:         1,
			Address:         "0x123",
			TokenID:         1,
			ContractAddress: "0x123456",
			ContractType:    "ERC721",
			Amount:          2,
		})
	assert.Equal(t, nil, err)
	assert.NotNil(t, bal2)

	tests := []struct {
		name    string
		opts    eventindexer.UpdateNFTBalanceOpts
		wantErr error
	}{
		{
			"success",
			eventindexer.UpdateNFTBalanceOpts{
				ChainID:         1,
				Address:         "0x123",
				TokenID:         1,
				ContractAddress: "0x123",
				ContractType:    "ERC721",
				Amount:          1,
			},
			nil,
		},
		{
			"one left",
			eventindexer.UpdateNFTBalanceOpts{
				ChainID:         1,
				Address:         "0x123",
				TokenID:         1,
				ContractAddress: "0x123456",
				ContractType:    "ERC721",
				Amount:          1,
			},
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := nftBalanceRepo.SubtractBalance(context.Background(), tt.opts)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

// TODO: fix this test
func TestIntegration_NFTBalance_FindByAddress(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	nftBalanceRepo, err := NewNFTBalanceRepository(db)
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
			_, err := nftBalanceRepo.FindByAddress(
				context.Background(),
				get,
				tt.address,
				tt.chainID)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}
