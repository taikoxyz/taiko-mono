package mock

import (
	"errors"
	"math/big"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

var (
	LatestBlock = &eventindexer.Block{
		Height:  100,
		Hash:    "0x",
		ChainID: MockChainID.Int64(),
	}
)

type BlockRepository struct {
}

func (r *BlockRepository) Save(opts eventindexer.SaveBlockOpts) error {
	return nil
}

func (r *BlockRepository) GetLatestBlockProcessedForEvent(chainID *big.Int) (*eventindexer.Block, error) {
	if chainID.Int64() != MockChainID.Int64() {
		return nil, errors.New("error getting latest block processed for event")
	}

	return LatestBlock, nil
}
