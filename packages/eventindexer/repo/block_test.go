package repo

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/db"
)

func Test_NewBlockRepo(t *testing.T) {
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
			_, err := NewBlockRepository(tt.db)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

// func TestIntegration_RawBlock_Save(t *testing.T) {
// 	db, close, err := testMysql(t)
// 	assert.Equal(t, nil, err)

// 	defer close()

// 	blockRepo, err := NewBlockRepository(db)
// 	assert.Equal(t, nil, err)
// 	tests := []struct {
// 		name    string
// 		block   types.Block
// 		chainID *big.Int
// 		wantErr error
// 	}{
// 		{
// 			"success",
// 			types.Block{
// 				&types.Header{},
// 				[]*types.Header{},
// 				[]*types.Transaction{},
// 				[]*types.Withdrawals{},
// 				atomic.Value{},
// 				atomic.Value{},
// 				time.Now(),
// 				nil,
// 			},
// 			big.NewInt(0),
// 			nil,
// 		},
// 	}

// 	for _, tt := range tests {
// 		t.Run(tt.name, func(t *testing.T) {
// 			err := blockRepo.Save(context.Background(), &tt.block, tt.chainID)
// 			assert.Equal(t, tt.wantErr, err)
// 		})
// 	}
// }
