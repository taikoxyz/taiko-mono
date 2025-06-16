package builder

import (
	"context"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	bindingTypes "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding/binding_types"
)

// BatchProposalTransactionBuilder is an interface for building a TaikoInbox.proposeBatch /
// TaikoInbox.v4ProposeBatch transaction.
type BatchProposalTransactionBuilder interface {
	BuildPacaya(
		ctx context.Context,
		txBatch []types.Transactions,
		forcedInclusion bindingTypes.IForcedInclusionStoreForcedInclusion,
		parentMetahash common.Hash,
	) (*txmgr.TxCandidate, error)
	BuildShasta(
		ctx context.Context,
		txBatch []types.Transactions,
		forcedInclusion bindingTypes.IForcedInclusionStoreForcedInclusion,
		parentMetahash common.Hash,
	) (*txmgr.TxCandidate, error)
}
