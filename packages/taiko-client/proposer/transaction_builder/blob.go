package builder

import (
	"context"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
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
	gasLimit                uint64
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
	gasLimit uint64,
	extraData string,
) *BlobTransactionBuilder {
	return &BlobTransactionBuilder{
		rpc,
		proverSelector,
		l1BlockBuilderTip,
		taikoL1Address,
		l2SuggestedFeeRecipient,
		assignmentHookAddress,
		gasLimit,
		extraData,
	}
}

// Build implements the ProposeBlockTransactionBuilder interface.
func (b *BlobTransactionBuilder) Build(
	ctx context.Context,
	tierFees []encoding.TierFee,
	includeParentMetaHash bool,
	txListBytes []byte,
) (*txmgr.TxCandidate, error) {
	// Make a sidecar then calculate the blob hash.
	sideCar, err := rpc.MakeSidecar(txListBytes)
	if err != nil {
		return nil, err
	}

	var blob = &eth.Blob{}
	if err := blob.FromData(txListBytes); err != nil {
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
	data, err := encoding.TaikoL1ABI.Pack("proposeBlock", encodedParams, []byte{})
	if err != nil {
		return nil, encoding.TryParsingCustomError(err)
	}

	return &txmgr.TxCandidate{
		TxData:   data,
		Blobs:    []*eth.Blob{blob},
		To:       &b.taikoL1Address,
		GasLimit: b.gasLimit,
		Value:    maxFee,
	}, nil
}
