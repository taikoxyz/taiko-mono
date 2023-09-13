package repo

import (
	"context"
	"math/big"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/db"
)

func Test_NewTransactionRepo(t *testing.T) {
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
			_, err := NewTransactionRepository(tt.db)
			if err != tt.wantErr {
				t.Errorf("NewTransactionRepository() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
		})
	}
}

func TestIntegration_Transaction_Save(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	txRepo, err := NewTransactionRepository(db)
	assert.Equal(t, nil, err)

	tests := []struct {
		name            string
		tx              *types.Transaction
		sender          common.Address
		blockID         *big.Int
		transactedAt    time.Time
		contractAddress common.Address
		wantErr         error
	}{}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := txRepo.Save(
				context.Background(),
				tt.tx,
				tt.sender,
				tt.blockID,
				tt.transactedAt,
				tt.contractAddress,
			)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}
