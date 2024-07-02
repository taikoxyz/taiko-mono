package builder

import (
	"context"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
)

// ProposeBlockTransactionBuilder is an interface for building a TaikoL1.proposeBlock transaction.
type ProposeBlockTransactionBuilder interface {
	Build(
		ctx context.Context,
		tierFees []encoding.TierFee,
		txListBytes []byte,
		l1StateBlockNumber uint32,
		timestamp uint64,
		parentMetaHash [32]byte,
	) (*txmgr.TxCandidate, error)
}
