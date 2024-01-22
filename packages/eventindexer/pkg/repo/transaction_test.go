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
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
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
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

func TestIntegration_Transaction_Save(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	txRepo, err := NewTransactionRepository(db)
	assert.Equal(t, nil, err)

	to := common.HexToAddress("0x3a537c89809712367218bb171b3b1c46aa95df3dee7200ae9dc78f4052024068")
	accessList := make(types.AccessList, 0)
	tx := types.NewTx(&types.AccessListTx{
		Nonce:      10,
		GasPrice:   big.NewInt(10),
		Gas:        100,
		To:         &to,
		Value:      common.Big0,
		Data:       []byte{},
		V:          big.NewInt(1),
		R:          big.NewInt(1),
		S:          big.NewInt(1),
		ChainID:    big.NewInt(1),
		AccessList: accessList,
	})

	tests := []struct {
		name            string
		tx              *types.Transaction
		sender          common.Address
		blockID         *big.Int
		transactedAt    time.Time
		contractAddress common.Address
		wantErr         error
	}{
		{
			"success",
			tx,
			common.HexToAddress("0x3a537c89809712367218bb171b3b1c46aa95df3dee7200ae9dc78f4052024068"),
			big.NewInt(1),
			time.Now(),
			common.HexToAddress("0x3a537c89809712367218bb171b3b1c46aa95df3dee7200ae9dc78f4052024068"),
			nil,
		},
	}

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
