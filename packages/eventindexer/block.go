package eventindexer

import (
	"context"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
)

// ProcessedBlock is a database model representing simple header types
// to keep track of our most recently processed block number and hash.
type ProcessedBlock struct {
	ID      int    `json:"id"`
	Height  uint64 `json:"blockHeight" gorm:"column:block_height"`
	Hash    string `json:"hash"`
	ChainID int64  `json:"chainID"`
}

// SaveProcessedBlockOpts is required to store a new block
type SaveProcessedBlockOpts struct {
	Height  uint64
	Hash    common.Hash
	ChainID *big.Int
}

// ProcessedBlockRepository defines methods necessary for interacting with
// the block store.
type ProcessedBlockRepository interface {
	Save(opts SaveProcessedBlockOpts) error
	GetLatestBlockProcessed(chainID *big.Int) (*ProcessedBlock, error)
}

type Block struct {
	ID           int       `json:"id"`
	ChainID      int64     `json:"chainID"`
	BlockID      int64     `json:"blockID"`
	TransactedAt time.Time `json:"transactedAt"`
}

type BlockRepository interface {
	Save(ctx context.Context, tx *types.Block, chainID *big.Int) error
}
