package transaction

import (
	"errors"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-client/bindings"
	"github.com/taikoxyz/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-client/pkg/rpc"
)

var (
	ErrUnretryableSubmission = errors.New("unretryable submission error")
)

// TxBuilder will build a transaction with the given nonce.
type TxBuilder func(txOpts *bind.TransactOpts) (*txmgr.TxCandidate, error)

// ProveBlockTxBuilder is responsible for building ProveBlock transactions.
type ProveBlockTxBuilder struct {
	rpc                   *rpc.Client
	taikoL1Address        common.Address
	guardianProverAddress common.Address
}

// NewProveBlockTxBuilder creates a new ProveBlockTxBuilder instance.
func NewProveBlockTxBuilder(
	rpc *rpc.Client,
	taikoL1Address common.Address,
	guardianProverAddress common.Address,
) *ProveBlockTxBuilder {
	return &ProveBlockTxBuilder{rpc, taikoL1Address, guardianProverAddress}
}

// Build creates a new TaikoL1.ProveBlock transaction with the given nonce.
func (a *ProveBlockTxBuilder) Build(
	blockID *big.Int,
	meta *bindings.TaikoDataBlockMetadata,
	transition *bindings.TaikoDataTransition,
	tierProof *bindings.TaikoDataTierProof,
	guardian bool,
) TxBuilder {
	return func(txOpts *bind.TransactOpts) (*txmgr.TxCandidate, error) {
		var (
			data []byte
			to   common.Address
			err  error
		)

		log.Info(
			"Build proof submission transaction",
			"blockID", blockID,
			"gasLimit", txOpts.GasLimit,
			"guardian", guardian,
		)

		if !guardian {
			to = a.taikoL1Address

			input, err := encoding.EncodeProveBlockInput(meta, transition, tierProof)
			if err != nil {
				return nil, err
			}
			if data, err = encoding.TaikoL1ABI.Pack("proveBlock", blockID.Uint64(), input); err != nil {
				if isSubmitProofTxErrorRetryable(err, blockID) {
					return nil, err
				}
				return nil, ErrUnretryableSubmission
			}
		} else {
			to = a.guardianProverAddress

			if data, err = encoding.GuardianProverABI.Pack("approve", *meta, *transition, *tierProof); err != nil {
				if isSubmitProofTxErrorRetryable(err, blockID) {
					return nil, err
				}
				return nil, ErrUnretryableSubmission
			}
		}

		return &txmgr.TxCandidate{
			TxData:   data,
			To:       &to,
			Blobs:    nil,
			GasLimit: txOpts.GasLimit,
			Value:    txOpts.Value,
		}, nil
	}
}
