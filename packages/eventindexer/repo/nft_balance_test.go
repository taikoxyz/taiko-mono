package repo

import (
	"context"
	"net/http"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/db"
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
	}{}

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

	tests := []struct {
		name    string
		opts    eventindexer.UpdateNFTBalanceOpts
		wantErr error
	}{}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := nftBalanceRepo.SubtractBalance(context.Background(), tt.opts)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

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
		{},
	}

	get, err := http.NewRequest("GET", "", nil)

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
