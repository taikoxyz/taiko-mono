package builder

import (
	"context"
	"crypto/ecdsa"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// CalldataTransactionBuilder is responsible for building a TaikoL1.proposeBlock transaction with txList
// bytes saved in calldata.
type CalldataTransactionBuilder struct {
	rpc                     *rpc.Client
	proposerPrivateKey      *ecdsa.PrivateKey
	l2SuggestedFeeRecipient common.Address
	taikoL1Address          common.Address
	proverSetAddress        common.Address
	gasLimit                uint64
	extraData               string
}

// NewCalldataTransactionBuilder creates a new CalldataTransactionBuilder instance based on giving configurations.
func NewCalldataTransactionBuilder(
	rpc *rpc.Client,
	proposerPrivateKey *ecdsa.PrivateKey,
	l2SuggestedFeeRecipient common.Address,
	taikoL1Address common.Address,
	proverSetAddress common.Address,
	gasLimit uint64,
	extraData string,
) *CalldataTransactionBuilder {
	return &CalldataTransactionBuilder{
		rpc,
		proposerPrivateKey,
		l2SuggestedFeeRecipient,
		taikoL1Address,
		proverSetAddress,
		gasLimit,
		extraData,
	}
}

// Build implements the ProposeBlockTransactionBuilder interface.
func (b *CalldataTransactionBuilder) Build(
	ctx context.Context,
	includeParentMetaHash bool,
	txListBytes []byte,
) (*txmgr.TxCandidate, error) {
	// If the current proposer wants to include the parent meta hash, then fetch it from the protocol.
	var (
		parentMetaHash = [32]byte{}
		err            error
	)
	if includeParentMetaHash {
		if parentMetaHash, err = getParentMetaHash(ctx, b.rpc); err != nil {
			return nil, err
		}
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
		Coinbase:       b.l2SuggestedFeeRecipient,
		ExtraData:      rpc.StringToBytes32(b.extraData),
		ParentMetaHash: parentMetaHash,
		Signature:      signature,
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
	}, nil
}
