package repo

import (
	"context"
	"math/big"
	"testing"

	"github.com/davecgh/go-spew/spew"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"gotest.tools/assert"
)

func TestIntegration_Stat_Save(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	statRepo, err := NewStatRepository(db)
	assert.Equal(t, nil, err)

	var proofReward = big.NewInt(4)

	tests := []struct {
		name    string
		opts    eventindexer.SaveStatOpts
		wantErr error
	}{
		{
			"successProofReward",
			eventindexer.SaveStatOpts{
				ProofReward: proofReward,
			},
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err = statRepo.Save(context.Background(), tt.opts)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

func TestIntegration_Stat_Find(t *testing.T) {
	db, close, err := testMysql(t)
	assert.Equal(t, nil, err)

	defer close()

	statRepo, err := NewStatRepository(db)
	assert.Equal(t, nil, err)

	var proofReward = big.NewInt(4)

	_, err = statRepo.Save(context.Background(), eventindexer.SaveStatOpts{
		ProofReward: proofReward,
	})

	assert.Equal(t, nil, err)

	tests := []struct {
		name     string
		wantResp *eventindexer.Stat
		wantErr  error
	}{
		{
			"success",
			&eventindexer.Stat{
				ID:                 1,
				AverageProofReward: proofReward.String(),
				AverageProofTime:   "0",
				NumProofs:          0,
				NumVerifiedBlocks:  1,
			},
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resp, err := statRepo.Find(context.Background())
			spew.Dump(resp)
			assert.Equal(t, tt.wantErr, err)
			assert.Equal(t, *tt.wantResp, *resp)
		})
	}
}
