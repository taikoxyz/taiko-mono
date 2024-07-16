package builder

import (
	"context"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
)

type TxBuilder interface {
	BuildBlockUnsigned(
		ctx context.Context,
		txListBytes []byte,
		l1StateBlockNumber uint32,
		timestamp uint64,
		coinbase common.Address,
		extraData [32]byte,
	) (*types.Transaction, error)
	BuildBlocksUnsigned(
		ctx context.Context,
		txListBytes []byte,
		l1StateBlockNumber uint32,
		timestamp uint64,
		coinbase common.Address,
		extraData [32]byte,
	) (*types.Transaction, error)
}
