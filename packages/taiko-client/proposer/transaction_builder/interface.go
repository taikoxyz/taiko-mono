package builder

import (
	"context"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-client/bindings/encoding"
)

// ProposeBlockTransactionBuilder is an interface for building a TaikoL1.proposeBlock transaction.
type ProposeBlockTransactionBuilder interface {
	Build(
		ctx context.Context,
		tierFees []encoding.TierFee,
		opts *bind.TransactOpts,
		includeParentMetaHash bool,
		txListBytes []byte,
	) (*types.Transaction, error)
}
