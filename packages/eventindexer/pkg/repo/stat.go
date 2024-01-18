package repo

import (
	"context"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"golang.org/x/exp/slog"
)

type StatRepository struct {
	db eventindexer.DB
}

func NewStatRepository(db eventindexer.DB) (*StatRepository, error) {
	if db == nil {
		return nil, eventindexer.ErrNoDB
	}

	return &StatRepository{
		db: db,
	}, nil
}

func (r *StatRepository) Save(ctx context.Context, opts eventindexer.SaveStatOpts) (*eventindexer.Stat, error) {
	slog.Info("saving stat", "stat", opts.StatType)

	s := &eventindexer.Stat{}

	q := r.db.
		GormDB().Table("stats").Where("stat_type = ?", opts.StatType)

	if opts.FeeTokenAddress != nil {
		q.Where("fee_token_address = ?", *opts.FeeTokenAddress)
	}

	if err := q.
		FirstOrCreate(s).
		Error; err != nil {
		return nil, errors.Wrap(err, "r.db.gormDB.FirstOrCreate")
	}

	if opts.StatType == eventindexer.StatTypeProofReward && opts.ProofReward != nil {
		s.NumBlocksAssigned++
		s.FeeTokenAddress = *opts.FeeTokenAddress
		s.StatType = opts.StatType
		s.AverageProofReward = opts.ProofReward.String()
	}

	if opts.StatType == eventindexer.StatTypeProofTime && opts.ProofTime != nil {
		s.NumProofs++
		s.StatType = opts.StatType
		s.AverageProofTime = opts.ProofTime.String()
	}

	if err := r.db.GormDB().Save(s).Error; err != nil {
		return nil, errors.Wrap(err, "r.db.Save")
	}

	return s, nil
}

// FindAll finds each type of unique stat and merges them together
func (r *StatRepository) FindAll(
	ctx context.Context,
) ([]*eventindexer.Stat, error) {
	// first find all unique proof reward stats by fee token address
	var proofRewardStats []*eventindexer.Stat

	err := r.db.
		GormDB().Table("stats").Where("stat_type = ?", eventindexer.StatTypeProofReward).
		Scan(&proofRewardStats).
		Error
	if err != nil {
		return nil, err
	}

	// then find the average proof time stats
	var proofTimeStat *eventindexer.Stat

	err = r.db.
		GormDB().Table("stats").Where("stat_type = ?", eventindexer.StatTypeProofTime).
		Scan(&proofTimeStat).
		Error
	if err != nil {
		return nil, err
	}

	return append(proofRewardStats, proofTimeStat), nil
}

func (r *StatRepository) Find(
	ctx context.Context,
	statType string,
	feeTokenAddress *string,
) (*eventindexer.Stat, error) {
	s := &eventindexer.Stat{}

	q := r.db.
		GormDB().Table("stats").Where("stat_type = ?", statType)

	if feeTokenAddress != nil {
		q.Where("fee_token_address = ?", *feeTokenAddress)
	}

	if err := q.
		FirstOrCreate(s).
		Error; err != nil {
		return nil, errors.Wrap(err, "r.db.gormDB.FirstOrCreate")
	}

	if statType == eventindexer.StatTypeProofReward && s.AverageProofReward == "" {
		s.AverageProofReward = "0"
	}

	if statType == eventindexer.StatTypeProofTime && s.AverageProofTime == "" {
		s.AverageProofTime = "0"
	}

	return s, nil
}
