package repo

import (
	"context"
	"math/big"
	"testing"

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

	feeTokenAddress := "0x01"

	tests := []struct {
		name    string
		opts    eventindexer.SaveStatOpts
		wantErr error
	}{
		{
			"successProofReward",
			eventindexer.SaveStatOpts{
				ProofReward:     proofReward,
				StatType:        eventindexer.StatTypeProofReward,
				FeeTokenAddress: &feeTokenAddress,
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

	var proofTime = big.NewInt(7)

	feeTokenAddress := "0x01"

	_, err = statRepo.Save(context.Background(), eventindexer.SaveStatOpts{
		StatType:        eventindexer.StatTypeProofReward,
		ProofReward:     proofReward,
		FeeTokenAddress: &feeTokenAddress,
	})

	assert.Equal(t, nil, err)

	_, err = statRepo.Save(context.Background(), eventindexer.SaveStatOpts{
		StatType:  eventindexer.StatTypeProofTime,
		ProofTime: proofTime,
	})

	assert.Equal(t, nil, err)

	tests := []struct {
		name            string
		statType        string
		feeTokenAddress string
		wantResp        *eventindexer.Stat
		wantErr         error
	}{
		{
			"successStatTypeProofReward",
			eventindexer.StatTypeProofReward,
			"0x01",
			&eventindexer.Stat{
				ID:                 1,
				AverageProofReward: proofReward.String(),
			},
			nil,
		},
		{
			"successStatTypeProofTime",
			eventindexer.StatTypeProofTime,
			"",
			&eventindexer.Stat{
				ID:               1,
				AverageProofTime: proofTime.String(),
			},
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := tt.feeTokenAddress
			resp, err := statRepo.Find(context.Background(), tt.statType, &f)

			assert.Equal(t, tt.wantErr, err)
			assert.Equal(t, tt.wantResp.AverageProofReward, resp.AverageProofReward)
		})
	}
}
