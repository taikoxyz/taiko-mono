package repo

import (
	"math/big"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"gorm.io/gorm"
)

type BlockRepository struct {
	db relayer.DB
}

func NewBlockRepository(db relayer.DB) (*BlockRepository, error) {
	if db == nil {
		return nil, relayer.ErrNoDB
	}

	return &BlockRepository{
		db: db,
	}, nil
}

func (r *BlockRepository) startQuery() *gorm.DB {
	return r.db.GormDB().Table("processed_blocks")
}

func (r *BlockRepository) Save(opts relayer.SaveBlockOpts) error {
	exists := &relayer.Block{}
	_ = r.startQuery().Where("block_height = ?", opts.Height).Where("chain_id = ?", opts.ChainID.Int64()).First(exists)
	// block procesed already
	if exists.Height == opts.Height {
		return nil
	}

	b := &relayer.Block{
		Height:    opts.Height,
		Hash:      opts.Hash.String(),
		ChainID:   opts.ChainID.Int64(),
		EventName: opts.EventName,
	}
	if err := r.startQuery().Create(b).Error; err != nil {
		return err
	}

	return nil
}

func (r *BlockRepository) GetLatestBlockProcessedForEvent(eventName string, chainID *big.Int) (*relayer.Block, error) {
	b := &relayer.Block{}
	if err := r.
		startQuery().
		Raw(`SELECT id, block_height, hash, event_name, chain_id 
		FROM processed_blocks 
		WHERE block_height = 
		( SELECT MAX(block_height) from processed_blocks 
		WHERE chain_id = ? AND event_name = ? )`, chainID.Int64(), eventName).
		FirstOrInit(b).Error; err != nil {
		return nil, err
	}

	return b, nil
}
