package builder

import (
	"context"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
)

// ProposeBlocksTransactionBuilder is an interface for building a TaikoL1.proposeBlock / TaikoInbox.proposeBatch
// transaction.
type ProposeBlocksTransactionBuilder interface {
	BuildOntake(ctx context.Context, txListBytesArray [][]byte) (*txmgr.TxCandidate, error)
	BuildPacaya(
		ctx context.Context,
		txBatch []types.Transactions,
		forcedInclusion *pacayaBindings.IForcedInclusionStoreForcedInclusion,
		minTxsPerForcedInclusion *big.Int,
	) (*txmgr.TxCandidate, error)
}

// buildParamsForForcedInclusion builds the blob params and the block params
// for the given forced inclusion.
func buildParamsForForcedInclusion(
	forcedInclusion *pacayaBindings.IForcedInclusionStoreForcedInclusion,
	minTxsPerForcedInclusion *big.Int,
) (*encoding.BlobParams, []pacayaBindings.ITaikoInboxBlockParams) {
	if forcedInclusion == nil {
		return nil, nil
	}
	return &encoding.BlobParams{
			BlobHashes: [][32]byte{forcedInclusion.BlobHash},
			NumBlobs:   0,
			ByteOffset: forcedInclusion.BlobByteOffset,
			ByteSize:   forcedInclusion.BlobByteSize,
			CreatedIn:  forcedInclusion.BlobCreatedIn,
		}, []pacayaBindings.ITaikoInboxBlockParams{
			{
				NumTransactions: uint16(minTxsPerForcedInclusion.Uint64()),
				TimeShift:       0,
				SignalSlots:     make([][32]byte, 0),
			},
		}
}
