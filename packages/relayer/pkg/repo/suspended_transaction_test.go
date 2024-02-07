package repo

import (
	"context"
	"net/http"
	"testing"

	"github.com/morkid/paginate"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/db"
	"gopkg.in/go-playground/assert.v1"
)

func Test_NewSuspendedTransactionRepo(t *testing.T) {
	tests := []struct {
		name    string
		db      DB
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
			ErrNoDB,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := NewSuspendedTransactionRepository(tt.db)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

func TestIntegration_SuspendedTransaction_Save(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	suspendedTxRepo, err := NewSuspendedTransactionRepository(db)
	assert.Equal(t, nil, err)

	tests := []struct {
		name    string
		opts    relayer.SuspendTransactionOpts
		wantErr error
	}{
		{
			"success",
			relayer.SuspendTransactionOpts{
				SrcChainID:   1,
				DestChainID:  2,
				Suspended:    true,
				MessageID:    5,
				MsgHash:      "0x1",
				MessageOwner: "0x1",
			},
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tx, err := suspendedTxRepo.Save(context.Background(), tt.opts)
			assert.Equal(t, tt.wantErr, err)

			assert.Equal(t, tt.opts.SrcChainID, tx.SrcChainID)
			assert.Equal(t, tt.opts.DestChainID, tx.DestChainID)
			assert.Equal(t, tt.opts.Suspended, tx.Suspended)
			assert.Equal(t, tt.opts.MessageID, tx.MessageID)
			assert.Equal(t, tt.opts.MessageOwner, tx.MessageOwner)
			assert.Equal(t, tt.opts.MsgHash, tx.MsgHash)
		})
	}
}

func TestIntegration_SuspendedTransaction_Find(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	suspendedTxRepo, err := NewSuspendedTransactionRepository(db)
	assert.Equal(t, nil, err)

	_, err = suspendedTxRepo.Save(context.Background(), relayer.SuspendTransactionOpts{
		MessageID:    1,
		SrcChainID:   2,
		DestChainID:  3,
		MessageOwner: "0x456",
		Suspended:    true,
		MsgHash:      "0x1",
	})
	assert.Equal(t, nil, err)

	tests := []struct {
		name     string
		wantResp paginate.Page
		wantErr  error
	}{
		{
			"successJustAddress",
			paginate.Page{
				Items:      testEvents,
				Page:       0,
				Size:       100,
				MaxPage:    1,
				TotalPages: 1,
				Total:      1,
				Last:       false,
				First:      true,
				Visible:    1,
			},
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req, err := http.NewRequest(http.MethodGet, "/events", nil)
			assert.Equal(t, nil, err)

			resp, err := suspendedTxRepo.Find(context.Background(), req)
			assert.Equal(t, tt.wantResp.Items, resp.Items)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}
