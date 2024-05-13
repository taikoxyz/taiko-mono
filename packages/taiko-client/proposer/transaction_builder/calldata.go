package builder

import (
	"context"
	"crypto/ecdsa"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	selector "github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer/prover_selector"
)

// CalldataTransactionBuilder is responsible for building a TaikoL1.proposeBlock transaction with txList
// bytes saved in calldata.
type CalldataTransactionBuilder struct {
	rpc                     *rpc.Client
	proposerPrivateKey      *ecdsa.PrivateKey
	proverSelector          selector.ProverSelector
	l1BlockBuilderTip       *big.Int
	l2SuggestedFeeRecipient common.Address
	taikoL1Address          common.Address
	assignmentHookAddress   common.Address
	gasLimit                uint64
	extraData               string
}

// NewCalldataTransactionBuilder creates a new CalldataTransactionBuilder instance based on giving configurations.
func NewCalldataTransactionBuilder(
	rpc *rpc.Client,
	proposerPrivateKey *ecdsa.PrivateKey,
	proverSelector selector.ProverSelector,
	l1BlockBuilderTip *big.Int,
	l2SuggestedFeeRecipient common.Address,
	taikoL1Address common.Address,
	assignmentHookAddress common.Address,
	gasLimit uint64,
	extraData string,
) *CalldataTransactionBuilder {
	return &CalldataTransactionBuilder{
		rpc,
		proposerPrivateKey,
		proverSelector,
		l1BlockBuilderTip,
		l2SuggestedFeeRecipient,
		taikoL1Address,
		assignmentHookAddress,
		gasLimit,
		extraData,
	}
}

// Build implements the ProposeBlockTransactionBuilder interface.
func (b *CalldataTransactionBuilder) Build(
	ctx context.Context,
	tierFees []encoding.TierFee,
	includeParentMetaHash bool,
	txListBytes []byte,
) (*txmgr.TxCandidate, error) {
	// Try to assign a prover.
	assignment, assignedProver, maxFee, err := b.proverSelector.AssignProver(
		ctx,
		tierFees,
		crypto.Keccak256Hash(txListBytes),
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

	signature, err := crypto.Sign(crypto.Keccak256(txListBytes), b.proposerPrivateKey)
	if err != nil {
		return nil, err
	}
	signature[64] = uint8(uint(signature[64])) + 27

	// ABI encode the TaikoL1.proposeBlock parameters.
	encodedParams, err := encoding.EncodeBlockParams(&encoding.BlockParams{
		AssignedProver: assignedProver,
		Coinbase:       b.l2SuggestedFeeRecipient,
		ExtraData:      rpc.StringToBytes32(b.extraData),
		ParentMetaHash: parentMetaHash,
		HookCalls:      []encoding.HookCall{{Hook: b.assignmentHookAddress, Data: hookInputData}},
		Signature:      signature,
	})
	if err != nil {
		return nil, err
	}

	// Send the transaction to the L1 node.
	data, err := encoding.TaikoL1ABI.Pack("proposeBlock", encodedParams, txListBytes)
	if err != nil {
		return nil, err
	}

	return &txmgr.TxCandidate{
		TxData:   data,
		Blobs:    nil,
		To:       &b.taikoL1Address,
		GasLimit: b.gasLimit,
		Value:    maxFee,
	}, nil
}
