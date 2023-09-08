package repo

import (
	"context"
	"math/big"
	"strings"
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
	// genesis block will have 0 time and no relevant information
	if block.Time() == uint64(0) {
		return nil
	}

	t := time.Unix(int64(block.Time()), 0)

	b := &eventindexer.Block{
		ChainID:      chainID.Int64(),
		BlockID:      block.Number().Int64(),
		TransactedAt: t,
	}

	if err := r.db.GormDB().Create(b).Error; err != nil {
		if strings.Contains(err.Error(), "Duplicate") {
			return nil
		}

		return errors.Wrap(err, "r.db.Create")
	}

	return nil
}
