package builder

import (
	"context"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
)

// ProposeBlockTransactionBuilder is an interface for building a TaikoL1.proposeBlock transaction.
type ProposeBlockTransactionBuilder interface {
	BuildOntake(ctx context.Context, txListBytesArray [][]byte) (*txmgr.TxCandidate, error)
}
