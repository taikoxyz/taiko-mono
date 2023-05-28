package mock

import (
	"context"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

type StatRepository struct {
	stats *eventindexer.Stat
}

func NewStatRepository() *StatRepository {
	return &StatRepository{}
}
func (r *StatRepository) Save(ctx context.Context, opts eventindexer.SaveStatOpts) (*eventindexer.Stat, error) {
	proofReward := ""
	if opts.ProofReward != nil {
		proofReward = opts.ProofReward.String()
	}

	proofTime := ""
	if opts.ProofTime != nil {
		proofTime = opts.ProofTime.String()
	}

	r.stats = &eventindexer.Stat{
		ID:                 1,
		AverageProofTime:   proofTime,
		AverageProofReward: proofReward,
		NumProofs:          1,
		NumVerifiedBlocks:  1,
	}

	return r.stats, nil
}

func (r *StatRepository) Find(
	ctx context.Context,
) (*eventindexer.Stat, error) {
	return r.stats, nil
}
