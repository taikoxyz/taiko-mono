package mock

import (
	"errors"
	"math/big"

	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

var (
	LatestBlock = &eventindexer.ProcessedBlock{
		Height:  100,
		Hash:    "0x",
		ChainID: MockChainID.Int64(),
	}
)

type ProcessedBlockRepository struct {
}

func (r *ProcessedBlockRepository) Save(opts eventindexer.SaveProcessedBlockOpts) error {
	return nil
}

func (r *ProcessedBlockRepository) GetLatestBlockProcessedForEvent(
	chainID *big.Int,
) (*eventindexer.ProcessedBlock, error) {
	if chainID.Int64() != MockChainID.Int64() {
		return nil, errors.New("error getting latest block processed for event")
	}

	return LatestBlock, nil
}
