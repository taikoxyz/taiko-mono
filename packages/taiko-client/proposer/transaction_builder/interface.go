package builder

import (
	"context"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
)

// ProposeBlocksTransactionBuilder is an interface for building a TaikoL1.proposeBlock / TaikoInbox.proposeBatch
// transaction.
type ProposeBlocksTransactionBuilder interface {
	BuildOntake(ctx context.Context, txListBytesArray [][]byte) (*txmgr.TxCandidate, error)
	BuildPacaya(
		ctx context.Context,
		txBatch []types.Transactions,
		forcedInclusion *pacaya.IForcedInclusionStoreForcedInclusion,
	) (*txmgr.TxCandidate, error)
}
