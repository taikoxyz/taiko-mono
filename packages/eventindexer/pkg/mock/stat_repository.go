package mock

import (
	"context"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

type StatRepository struct {
	stats []*eventindexer.Stat
}

func NewStatRepository() *StatRepository {
	return &StatRepository{
		stats: make([]*eventindexer.Stat, 0),
	}
}
func (r *StatRepository) Save(ctx context.Context, opts eventindexer.SaveStatOpts) (*eventindexer.Stat, error) {
	proofReward := ""
	if opts.StatType == eventindexer.StatTypeProofReward && opts.ProofReward != nil {
		proofReward = opts.ProofReward.String()
	}

	proofTime := ""
	if opts.StatType == eventindexer.StatTypeProofTime && opts.ProofTime != nil {
		proofTime = opts.ProofTime.String()
	}

	stat := &eventindexer.Stat{
		ID:                 1,
		AverageProofTime:   proofTime,
		AverageProofReward: proofReward,
		NumProofs:          1,
		NumBlocksAssigned:  1,
		StatType:           opts.StatType,
	}

	if opts.FeeTokenAddress != nil {
		stat.FeeTokenAddress = *opts.FeeTokenAddress
	}

	r.stats = append(r.stats, stat)

	return stat, nil
}

// FindAll finds each type of unique stat and merges them together
func (r *StatRepository) FindAll(
	ctx context.Context,
) ([]*eventindexer.Stat, error) {
	return r.stats, nil
}

func (r *StatRepository) Find(
	ctx context.Context,
	statType string,
	feeTokenAddress *string,
) (*eventindexer.Stat, error) {
	for _, s := range r.stats {
		if s.StatType == statType {
			return s, nil
		}
	}

	return nil, nil
}
