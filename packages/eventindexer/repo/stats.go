package repo

import (
	"context"
	"math/big"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
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
	s := &eventindexer.Stat{
		AverageProofTime: 0,
		ChainID:          opts.ChainID,
		NumProofs:        0,
	}

	if err := r.db.
		GormDB().
		Where("chain_id = ?", opts.ChainID.Int64()).
		FirstOrCreate(s).
		Error; err != nil {
		return nil, errors.Wrap(err, "r.db.gormDB.FirstOrCreate")
	}

	if err := r.db.GormDB().Save(s).Error; err != nil {
		return nil, errors.Wrap(err, "r.db.Create")
	}

	return s, nil
}

func (r *StatRepository) FindByChainID(ctx context.Context, chainID *big.Int) (*eventindexer.Stat, error) {
	var s *eventindexer.Stat

	if err := r.db.
		GormDB().
		Where("chain_id = ?", chainID.Int64()).
		First(s).
		Error; err != nil {
		return nil, errors.Wrap(err, "r.db.gormDB.FirstOrCreate")
	}

	return s, nil
}
