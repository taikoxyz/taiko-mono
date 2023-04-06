package repo

import (
	"math/big"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"gorm.io/gorm"
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

func (r *BlockRepository) startQuery() *gorm.DB {
	return r.db.GormDB().Table("processed_blocks")
}

func (r *BlockRepository) Save(opts eventindexer.SaveBlockOpts) error {
	exists := &eventindexer.Block{}
	_ = r.startQuery().Where("block_height = ?", opts.Height).Where("chain_id = ?", opts.ChainID.Int64()).First(exists)
	// block processed already
	if exists.Height == opts.Height {
		return nil
	}

	b := &eventindexer.Block{
		Height:  opts.Height,
		Hash:    opts.Hash.String(),
		ChainID: opts.ChainID.Int64(),
	}
	if err := r.startQuery().Create(b).Error; err != nil {
		return err
	}

	return nil
}

func (r *BlockRepository) GetLatestBlockProcessed(chainID *big.Int) (*eventindexer.Block, error) {
	b := &eventindexer.Block{}
	if err := r.
		startQuery().
		Raw(`SELECT id, block_height, hash, chain_id 
		FROM processed_blocks 
		WHERE block_height = 
		( SELECT MAX(block_height) from processed_blocks 
		WHERE chain_id = ? )`, chainID.Int64()).
		FirstOrInit(b).Error; err != nil {
		return nil, err
	}

	return b, nil
}
