package mock

import (
	"errors"
	"math/big"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

var (
	LatestBlock = &relayer.Block{
		Height:  100,
		Hash:    "0x",
		ChainID: MockChainID.Int64(),
	}
)

type BlockRepository struct {
}

func (r *BlockRepository) Save(opts relayer.SaveBlockOpts) error {
	return nil
}

func (r *BlockRepository) GetLatestBlockProcessedForEvent(eventName string, chainID *big.Int) (*relayer.Block, error) {
	if chainID.Int64() != MockChainID.Int64() {
		return nil, errors.New("error getting latest block processed for event")
	}

	return LatestBlock, nil
}
