package repo

import (
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/db"
	"gopkg.in/go-playground/assert.v1"
)

func Test_NewBlockRepo(t *testing.T) {
	tests := []struct {
		name    string
		db      relayer.DB
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
			relayer.ErrNoDB,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := NewBlockRepository(tt.db)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

func TestIntegration_Block_Save(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	blockRepo, err := NewBlockRepository(db)
	assert.Equal(t, nil, err)
	tests := []struct {
		name    string
		opts    relayer.SaveBlockOpts
		wantErr error
	}{
		{
			"success",
			relayer.SaveBlockOpts{
				ChainID:   big.NewInt(1),
				Height:    100,
				Hash:      common.HexToHash("0x1234"),
				EventName: relayer.EventNameMessageSent,
			},
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err = blockRepo.Save(tt.opts)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

func TestIntegration_Block_GetLatestBlockProcessedForEvent(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	blockRepo, err := NewBlockRepository(db)
	assert.Equal(t, nil, err)
	tests := []struct {
		name      string
		eventName string
		chainID   *big.Int
		wantErr   error
	}{
		{
			"success",
			relayer.EventNameMessageSent,
			big.NewInt(1),
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := blockRepo.GetLatestBlockProcessedForEvent(tt.eventName, tt.chainID)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}
