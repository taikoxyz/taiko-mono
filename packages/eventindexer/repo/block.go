package repo

import (
	"context"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

type BlockRepository struct {
	db eventindexer.DB
}

func NewBlockRepository(db eventindexer.DB) (*BlockRepository, error) {
	if db == nil {
		return nil, eventindexer.ErrNoDB
	}

	return &BlockRepository{
		db: db,
	}, nil
}

func (r *BlockRepository) Save(
	ctx context.Context,
	block *types.Block,
	chainID *big.Int,
) error {
	b := &eventindexer.Block{
		ChainID:      chainID.Int64(),
		BlockID:      block.Number().Int64(),
		TransactedAt: time.Unix(int64(block.Time()), 0),
	}

	if err := r.db.GormDB().Create(b).Error; err != nil {
		return errors.Wrap(err, "r.db.Create")
	}

	return nil
}
