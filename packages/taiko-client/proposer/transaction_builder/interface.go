package builder

import (
	"context"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding/params"
)

// BatchProposalTransactionBuilder is an interface for building a TaikoInbox.proposeBatch /
// TaikoInbox.v4ProposeBatch transaction.
type BatchProposalTransactionBuilder interface {
	BuildPacaya(
		ctx context.Context,
		txBatch []types.Transactions,
		forcedInclusion params.IForcedInclusionStoreForcedInclusion,
		minTxsPerForcedInclusion *big.Int,
		parentMetahash common.Hash,
	) (*txmgr.TxCandidate, error)
	BuildShasta(
		ctx context.Context,
		txBatch []types.Transactions,
		forcedInclusion params.IForcedInclusionStoreForcedInclusion,
		minTxsPerForcedInclusion *big.Int,
		parentMetahash common.Hash,
	) (*txmgr.TxCandidate, error)
}
