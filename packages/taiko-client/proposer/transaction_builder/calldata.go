package builder

import (
	"context"
	"crypto/ecdsa"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
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
	chainConfig             *config.ChainConfig
	afterOntake             bool
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
	chainConfig *config.ChainConfig,
) *CalldataTransactionBuilder {
	return &CalldataTransactionBuilder{
		rpc,
		proposerPrivateKey,
		l2SuggestedFeeRecipient,
		taikoL1Address,
		proverSetAddress,
		gasLimit,
		extraData,
		chainConfig,
		false,
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
		to            = &b.taikoL1Address
		data          []byte
		encodedParams []byte
		method        string
	)
	if b.proverSetAddress != rpc.ZeroAddress {
		to = &b.proverSetAddress
	}

	// Check if the current L2 chain is after ontake fork.
	if !b.afterOntake {
		blockNum, err := b.rpc.L2.BlockNumber(ctx)
		if err != nil {
			return nil, err
		}

		b.afterOntake = b.chainConfig.IsOntake(new(big.Int).SetUint64(blockNum + 1))
	}

	if !b.afterOntake {
		// ABI encode the TaikoL1.proposeBlock / ProverSet.proposeBlock parameters.
		method = "proposeBlock"

		if encodedParams, err = encoding.EncodeBlockParams(&encoding.BlockParams{
			Coinbase:       b.l2SuggestedFeeRecipient,
			ExtraData:      rpc.StringToBytes32(b.extraData),
			ParentMetaHash: parentMetaHash,
			Signature:      signature,
		}); err != nil {
			return nil, err
		}
	} else {
		l1Head, err := b.rpc.L1.HeaderByNumber(ctx, nil)
		if err != nil {
			return nil, err
		}
		// ABI encode the TaikoL1.proposeBlockV2 / ProverSet.proposeBlockV2 parameters.
		method = "proposeBlockV2"

		if encodedParams, err = encoding.EncodeBlockParamsOntake(&encoding.BlockParamsV2{
			Coinbase:       b.l2SuggestedFeeRecipient,
			ExtraData:      rpc.StringToBytes32(b.extraData),
			ParentMetaHash: parentMetaHash,
			AnchorBlockId:  0,
			Timestamp:      l1Head.Time,
		}); err != nil {
			return nil, err
		}
	}

	if b.proverSetAddress != rpc.ZeroAddress {
		data, err = encoding.ProverSetABI.Pack(method, encodedParams, txListBytes)
		if err != nil {
			return nil, err
		}
	} else {
		data, err = encoding.TaikoL1ABI.Pack(method, encodedParams, txListBytes)
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
