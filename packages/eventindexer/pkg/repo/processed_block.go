package repo

import (
	"math/big"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"gorm.io/gorm"
)

type ProcessedBlockRepository struct {
	db eventindexer.DB
}

func NewProcessedBlockRepository(db eventindexer.DB) (*ProcessedBlockRepository, error) {
	if db == nil {
		return nil, eventindexer.ErrNoDB
	}

	return &ProcessedBlockRepository{
		db: db,
	}, nil
}

func (r *ProcessedBlockRepository) startQuery() *gorm.DB {
	return r.db.GormDB().Table("processed_blocks")
}

func (r *ProcessedBlockRepository) Save(opts eventindexer.SaveProcessedBlockOpts) error {
	exists := &eventindexer.ProcessedBlock{}
	_ = r.startQuery().Where("block_height = ?", opts.Height).Where("chain_id = ?", opts.ChainID.Int64()).First(exists)
	// block processed already
	if exists.Height == opts.Height {
		return nil
	}

	b := &eventindexer.ProcessedBlock{
		Height:  opts.Height,
		Hash:    opts.Hash.String(),
		ChainID: opts.ChainID.Int64(),
	}
	if err := r.startQuery().Create(b).Error; err != nil {
		return err
	}

	return nil
}

func (r *ProcessedBlockRepository) GetLatestBlockProcessed(chainID *big.Int) (*eventindexer.ProcessedBlock, error) {
	b := &eventindexer.ProcessedBlock{}
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
