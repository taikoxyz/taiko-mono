package proof

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

type blocker interface {
	BlockByHash(ctx context.Context, hash common.Hash) (*types.Block, error)
	BlockByNumber(ctx context.Context, number *big.Int) (*types.Block, error)
}
type Prover struct {
	blocker blocker
}

func New(blocker blocker) (*Prover, error) {
	if blocker == nil {
		return nil, relayer.ErrNoEthClient
	}

	return &Prover{
		blocker: blocker,
	}, nil
}
