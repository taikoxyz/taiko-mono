package builder

import (
	"context"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
)

// ProposeBatchTransactionBuilder is an interface for building a TaikoInbox.proposeBatch
// transaction.
type ProposeBatchTransactionBuilder interface {
	BuildPacaya(
		ctx context.Context,
		txBatch []types.Transactions,
		forcedInclusion *pacayaBindings.IForcedInclusionStoreForcedInclusion,
		parentMetahash common.Hash,
	) (*txmgr.TxCandidate, error)
}
