package builder

import (
	"context"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

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
	BuildUnsigned(
		ctx context.Context,
		txListBytes []byte,
		l1StateBlockNumber uint32,
		timestamp uint64,
		coinbase common.Address,
		extraData [32]byte,
	) (*types.Transaction, error)
}
