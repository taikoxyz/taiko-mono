package builder

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/taikoxyz/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-client/pkg/rpc"
	selector "github.com/taikoxyz/taiko-client/proposer/prover_selector"
)

// BlobTransactionBuilder is responsible for building a TaikoL1.proposeBlock transaction with txList
// bytes saved in blob.
type BlobTransactionBuilder struct {
	rpc                     *rpc.Client
	proverSelector          selector.ProverSelector
	l1BlockBuilderTip       *big.Int
	taikoL1Address          common.Address
	l2SuggestedFeeRecipient common.Address
	assignmentHookAddress   common.Address
	extraData               string
}

// NewBlobTransactionBuilder creates a new BlobTransactionBuilder instance based on giving configurations.
func NewBlobTransactionBuilder(
	rpc *rpc.Client,
	proverSelector selector.ProverSelector,
	l1BlockBuilderTip *big.Int,
	taikoL1Address common.Address,
	l2SuggestedFeeRecipient common.Address,
	assignmentHookAddress common.Address,
	extraData string,
) *BlobTransactionBuilder {
	return &BlobTransactionBuilder{
		rpc,
		proverSelector,
		l1BlockBuilderTip,
		taikoL1Address,
		l2SuggestedFeeRecipient,
		assignmentHookAddress,
		extraData,
	}
}

// Build implements the ProposeBlockTransactionBuilder interface.
func (b *BlobTransactionBuilder) Build(
	ctx context.Context,
	tierFees []encoding.TierFee,
	opts *bind.TransactOpts,
	includeParentMetaHash bool,
	txListBytes []byte,
) (*types.Transaction, error) {
	// Make a sidecar then calculate the blob hash.
	sideCar, err := rpc.MakeSidecar(txListBytes)
	if err != nil {
		return nil, err
	}

	// Try to assign a prover.
	assignment, assignedProver, maxFee, err := b.proverSelector.AssignProver(
		ctx,
		tierFees,
		sideCar.BlobHashes()[0],
	)
	if err != nil {
		return nil, err
	}

	// Set the ETHs that the current proposer needs to pay to the prover.
	opts.Value = maxFee

	// If the current proposer wants to include the parent meta hash, then fetch it from the protocol.
	var parentMetaHash = [32]byte{}
	if includeParentMetaHash {
		if parentMetaHash, err = getParentMetaHash(ctx, b.rpc); err != nil {
			return nil, err
		}
	}

	// Initially just use the AssignmentHook default.
	hookInputData, err := encoding.EncodeAssignmentHookInput(&encoding.AssignmentHookInput{
		Assignment: assignment,
		Tip:        b.l1BlockBuilderTip,
	})
	if err != nil {
		return nil, err
	}

	// ABI encode the TaikoL1.proposeBlock parameters.
	encodedParams, err := encoding.EncodeBlockParams(&encoding.BlockParams{
		AssignedProver: assignedProver,
		ExtraData:      rpc.StringToBytes32(b.extraData),
		Coinbase:       b.l2SuggestedFeeRecipient,
		ParentMetaHash: parentMetaHash,
		HookCalls:      []encoding.HookCall{{Hook: b.assignmentHookAddress, Data: hookInputData}},
	})
	if err != nil {
		return nil, err
	}

	// Send the transaction to the L1 node.
	rawTx, err := b.rpc.TaikoL1.ProposeBlock(
		opts,
		encodedParams,
		nil,
	)
	if err != nil {
		return nil, encoding.TryParsingCustomError(err)
	}

	tx, err := b.rpc.L1.TransactBlobTx(opts, b.taikoL1Address, rawTx.Data(), sideCar)
	if err != nil {
		log.Debug("Failed to transact blob tx", "value", maxFee, "blobGasFeeCap", tx.BlobGasFeeCap(), "err", err)
		return nil, err
	}

	return tx, nil
}
