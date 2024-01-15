package repo

import (
	"context"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
)

func Test_NewAccountRepository(t *testing.T) {
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
			_, err := NewAccountRepository(tt.db)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

func TestIntegration_Account_Save(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	accountRepo, err := NewAccountRepository(db)
	assert.Equal(t, nil, err)

	t1 := time.Now()
	tests := []struct {
		name    string
		acct    eventindexer.Account
		wantErr error
	}{
		{
			"success",
			eventindexer.Account{
				ID:           0,
				Address:      "0x1234",
				TransactedAt: t1,
			},
			nil,
		},
		{
			"duplicate",
			eventindexer.Account{
				ID:           0,
				Address:      "0x1234",
				TransactedAt: t1,
			},
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err = accountRepo.Save(
				context.Background(),
				common.HexToAddress(tt.acct.Address),
				tt.acct.TransactedAt,
			)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}
