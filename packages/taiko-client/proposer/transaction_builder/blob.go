package builder

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// BlobTransactionBuilder is responsible for building a TaikoL1.proposeBlock transaction with txList
// bytes saved in blob.
type BlobTransactionBuilder struct {
	rpc                     *rpc.Client
	proposerPrivateKey      *ecdsa.PrivateKey
	taikoL1Address          common.Address
	proverSetAddress        common.Address
	l2SuggestedFeeRecipient common.Address
	gasLimit                uint64
	extraData               string
	chainConfig             *config.ChainConfig
	revertProtectionEnabled bool
}

// NewBlobTransactionBuilder creates a new BlobTransactionBuilder instance based on giving configurations.
func NewBlobTransactionBuilder(
	rpc *rpc.Client,
	proposerPrivateKey *ecdsa.PrivateKey,
	taikoL1Address common.Address,
	proverSetAddress common.Address,
	l2SuggestedFeeRecipient common.Address,
	gasLimit uint64,
	extraData string,
	chainConfig *config.ChainConfig,
	revertProtectionEnabled bool,
) *BlobTransactionBuilder {
	return &BlobTransactionBuilder{
		rpc,
		proposerPrivateKey,
		taikoL1Address,
		proverSetAddress,
		l2SuggestedFeeRecipient,
		gasLimit,
		extraData,
		chainConfig,
		revertProtectionEnabled,
	}
}

// BuildOntake implements the ProposeBlockTransactionBuilder interface.
func (b *BlobTransactionBuilder) BuildOntake(
	ctx context.Context,
	txListBytesArray [][]byte,
) (*txmgr.TxCandidate, error) {
	// Check if the current L2 chain is after ontake fork.
	state, err := rpc.GetProtocolStateVariables(b.rpc.TaikoL1, &bind.CallOpts{Context: ctx})
	if err != nil {
		return nil, err
	}

	if !b.chainConfig.IsOntake(new(big.Int).SetUint64(state.B.NumBlocks)) {
		return nil, fmt.Errorf("ontake transaction builder is not supported before ontake fork")
	}

	// ABI encode the TaikoL1.proposeBlocksV2 / ProverSet.proposeBlocksV2 parameters.
	var (
		to                 = &b.taikoL1Address
		data               []byte
		blobs              []*eth.Blob
		encodedParamsArray [][]byte
	)
	if b.proverSetAddress != rpc.ZeroAddress {
		to = &b.proverSetAddress
	}

	for i := range txListBytesArray {
		var blob = &eth.Blob{}
		if err := blob.FromData(txListBytesArray[i]); err != nil {
			return nil, err
		}

		blobs = append(blobs, blob)

		encodedParams, err := encoding.EncodeBlockParamsOntake(&encoding.BlockParamsV2{
			Coinbase:         b.l2SuggestedFeeRecipient,
			ParentMetaHash:   [32]byte{},
			AnchorBlockId:    0,
			Timestamp:        0,
			BlobTxListOffset: 0,
			BlobTxListLength: uint32(len(txListBytesArray[i])),
			BlobIndex:        uint8(i),
		})
		if err != nil {
			return nil, err
		}

		encodedParamsArray = append(encodedParamsArray, encodedParams)
	}
	txListArray := make([][]byte, len(encodedParamsArray))
	if b.proverSetAddress != rpc.ZeroAddress {
		if b.revertProtectionEnabled {
			data, err = encoding.ProverSetABI.Pack("proposeBlocksV2Conditionally", encodedParamsArray, txListArray)
		} else {
			data, err = encoding.ProverSetABI.Pack("proposeBlocksV2", encodedParamsArray, txListArray)
		}
		if err != nil {
			return nil, err
		}
	} else {
		data, err = encoding.TaikoL1ABI.Pack("proposeBlocksV2", encodedParamsArray, txListArray)
		if err != nil {
			return nil, err
		}
	}

	return &txmgr.TxCandidate{
		TxData:   data,
		Blobs:    blobs,
		To:       to,
		GasLimit: b.gasLimit,
	}, nil
}
