package builder

import (
	"context"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
)

// ProposeBlocksTransactionBuilder is an interface for building a TaikoL1.proposeBlock / TaikoInbox.proposeBatch
// transaction.
type ProposeBlocksTransactionBuilder interface {
	BuildOntake(ctx context.Context, txListBytesArray [][]byte) (*txmgr.TxCandidate, error)
	BuildPacaya(ctx context.Context, txListBytes []byte) (*txmgr.TxCandidate, error)
}
