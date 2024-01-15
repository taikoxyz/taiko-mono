package repo

import (
	"context"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
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

func TestIntegration_RawBlock_Save(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	blockRepo, err := NewBlockRepository(db)
	assert.Equal(t, nil, err)

	header := &types.Header{
		ParentHash:  common.HexToHash("0x3a537c89809712367218bb171b3b1c46aa95df3dee7200ae9dc78f4052024068"),
		UncleHash:   common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		Coinbase:    common.HexToAddress("0x0000000000000000000000000000000000000000"),
		Root:        common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		TxHash:      common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		ReceiptHash: common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		Bloom:       types.Bloom{},
		Difficulty:  new(big.Int).SetInt64(2),
		Number:      new(big.Int).SetInt64(1),
		GasLimit:    100000,
		GasUsed:     2000,
		Time:        1234,
		Extra:       []byte{0x7f},
		MixDigest:   common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		Nonce:       types.BlockNonce{0x13},
		BaseFee:     big.NewInt(10),
	}
	b := types.NewBlockWithHeader(header)

	genesisHeader := &types.Header{
		Time: 0,
	}

	b2 := types.NewBlockWithHeader(genesisHeader)

	tests := []struct {
		name    string
		block   *types.Block
		chainID *big.Int
		wantErr error
	}{
		{
			"success",
			b,
			big.NewInt(0),
			nil,
		},
		{
			"genesis",
			b2,
			big.NewInt(0),
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := blockRepo.Save(context.Background(), tt.block, tt.chainID)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}
