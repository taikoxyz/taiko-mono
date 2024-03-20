package transaction

import (
	"errors"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-client/bindings"
	"github.com/taikoxyz/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-client/pkg/rpc"
)

var (
	ErrUnretryableSubmission = errors.New("unretryable submission error")
)

// TxBuilder will build a transaction with the given nonce.
type TxBuilder func(txOpts *bind.TransactOpts) (*types.Transaction, error)

// ProveBlockTxBuilder is responsible for building ProveBlock transactions.
type ProveBlockTxBuilder struct {
	rpc *rpc.Client
}

// NewProveBlockTxBuilder creates a new ProveBlockTxBuilder instance.
func NewProveBlockTxBuilder(
	rpc *rpc.Client,
) *ProveBlockTxBuilder {
	return &ProveBlockTxBuilder{rpc: rpc}
}

// Build creates a new TaikoL1.ProveBlock transaction with the given nonce.
func (a *ProveBlockTxBuilder) Build(
	blockID *big.Int,
	meta *bindings.TaikoDataBlockMetadata,
	transition *bindings.TaikoDataTransition,
	tierProof *bindings.TaikoDataTierProof,
	guardian bool,
) TxBuilder {
	return func(txOpts *bind.TransactOpts) (*types.Transaction, error) {
		var (
			tx  *types.Transaction
			err error
		)

		log.Info(
			"Build proof submission transaction",
			"blockID", blockID,
			"gasLimit", txOpts.GasLimit,
			"nonce", txOpts.Nonce,
			"gasTipCap", txOpts.GasTipCap,
			"gasFeeCap", txOpts.GasFeeCap,
			"guardian", guardian,
		)

		if !guardian {
			input, err := encoding.EncodeProveBlockInput(meta, transition, tierProof)
			if err != nil {
				return nil, err
			}
			if tx, err = a.rpc.TaikoL1.ProveBlock(txOpts, blockID.Uint64(), input); err != nil {
				if isSubmitProofTxErrorRetryable(err, blockID) {
					return nil, err
				}
				return nil, ErrUnretryableSubmission
			}
		} else {
			if tx, err = a.rpc.GuardianProver.Approve(txOpts, *meta, *transition, *tierProof); err != nil {
				if isSubmitProofTxErrorRetryable(err, blockID) {
					return nil, err
				}
				return nil, ErrUnretryableSubmission
			}
		}

		return tx, nil
	}
}
