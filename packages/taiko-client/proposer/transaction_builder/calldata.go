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
	proverSetAddress        common.Address
	gasLimit                uint64
	extraData               string
	enabledPreconfirmation  bool
}

// NewCalldataTransactionBuilder creates a new CalldataTransactionBuilder instance based on giving configurations.
func NewCalldataTransactionBuilder(
	rpc *rpc.Client,
	proposerPrivateKey *ecdsa.PrivateKey,
	proverSelector selector.ProverSelector,
	l1BlockBuilderTip *big.Int,
	l2SuggestedFeeRecipient common.Address,
	taikoL1Address common.Address,
	proverSetAddress common.Address,
	gasLimit uint64,
	extraData string,
	enabledPreconfirmation bool,
) *CalldataTransactionBuilder {
	return &CalldataTransactionBuilder{
		rpc,
		proposerPrivateKey,
		proverSelector,
		l1BlockBuilderTip,
		l2SuggestedFeeRecipient,
		taikoL1Address,
		proverSetAddress,
		gasLimit,
		extraData,
		enabledPreconfirmation,
	}
}

// Build implements the ProposeBlockTransactionBuilder interface.
func (b *CalldataTransactionBuilder) Build(
	ctx context.Context,
	tierFees []encoding.TierFee,
	txListBytes []byte,
	l1StateBlockNumber uint32,
	timestamp uint64,
	parentMetaHash [32]byte,
) (*txmgr.TxCandidate, error) {
	// Try to assign a prover.
	maxFee, err := b.proverSelector.AssignProver(
		ctx,
		tierFees,
	)
	if err != nil {
		return nil, err
	}

	signature, err := crypto.Sign(crypto.Keccak256(txListBytes), b.proposerPrivateKey)
	if err != nil {
		return nil, err
	}
	signature[64] = uint8(uint(signature[64])) + 27

	var (
		to   = &b.taikoL1Address
		data []byte
	)
	if b.proverSetAddress != rpc.ZeroAddress {
		to = &b.proverSetAddress
	}

	// ABI encode the TaikoL1.proposeBlock / ProverSet.proposeBlock parameters.
	encodedParams, err := encoding.EncodeBlockParams(&encoding.BlockParams{
		Coinbase:           b.l2SuggestedFeeRecipient,
		ExtraData:          rpc.StringToBytes32(b.extraData),
		ParentMetaHash:     parentMetaHash,
		Signature:          signature,
		L1StateBlockNumber: l1StateBlockNumber,
		Timestamp:          timestamp,
	})
	if err != nil {
		return nil, err
	}

	if b.proverSetAddress != rpc.ZeroAddress {
		data, err = encoding.ProverSetABI.Pack("proposeBlock", encodedParams, txListBytes)
		if err != nil {
			return nil, err
		}
	} else {
		data, err = encoding.TaikoL1ABI.Pack("proposeBlock", encodedParams, txListBytes)
		if err != nil {
			return nil, err
		}
	}

	return &txmgr.TxCandidate{
		TxData:   data,
		Blobs:    nil,
		To:       to,
		GasLimit: b.gasLimit,
		Value:    maxFee,
	}, nil
}
