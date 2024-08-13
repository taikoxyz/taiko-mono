package builder

import (
	"context"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
)

// ProposeBlockTransactionBuilder is an interface for building a TaikoL1.proposeBlock transaction.
type ProposeBlockTransactionBuilder interface {
	Build(
		ctx context.Context,
		txListBytes []byte,
		l1StateBlockNumber uint32,
		timestamp uint64,
		parentMetaHash [32]byte,
	) (*txmgr.TxCandidate, error)
}
