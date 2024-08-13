package builder

import (
	"context"
	"crypto/ecdsa"
	"crypto/sha256"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/crypto/kzg4844"

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
	afterOntake             bool
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
		false,
	}
}

// Build implements the ProposeBlockTransactionBuilder interface.
func (b *BlobTransactionBuilder) Build(
	ctx context.Context,
	txListBytes []byte,
	l1StateBlockNumber uint32,
	timestamp uint64,
	parentMetaHash [32]byte,
) (*txmgr.TxCandidate, error) {
	var blob = &eth.Blob{}
	if err := blob.FromData(txListBytes); err != nil {
		return nil, err
	}

	commitment, err := blob.ComputeKZGCommitment()
	if err != nil {
		return nil, err
	}
	blobHash := kzg4844.CalcBlobHashV1(sha256.New(), &commitment)

	signature, err := crypto.Sign(blobHash[:], b.proposerPrivateKey)
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

		// ABI encode the TaikoL1.proposeBlock / ProverSet.proposeBlock parameters.
		encodedParams, err = encoding.EncodeBlockParams(&encoding.BlockParams{
			ExtraData:      rpc.StringToBytes32(b.extraData),
			Coinbase:       b.l2SuggestedFeeRecipient,
			ParentMetaHash: parentMetaHash,
			Signature:      signature,
		})
		if err != nil {
			return nil, err
		}
	} else {
		// ABI encode the TaikoL1.proposeBlockV2 / ProverSet.proposeBlockV2 parameters.
		method = "proposeBlockV2"

		if encodedParams, err = encoding.EncodeBlockParamsOntake(&encoding.BlockParamsV2{
			Coinbase:         b.l2SuggestedFeeRecipient,
			ParentMetaHash:   parentMetaHash,
			AnchorBlockId:    uint64(l1StateBlockNumber),
			Timestamp:        timestamp,
			BlobTxListOffset: 0,
			BlobTxListLength: uint32(len(txListBytes)),
			BlobIndex:        0,
		}); err != nil {
			return nil, err
		}
	}

	if b.proverSetAddress != rpc.ZeroAddress {
		data, err = encoding.ProverSetABI.Pack(method, encodedParams, []byte{})
		if err != nil {
			return nil, err
		}
	} else {
		data, err = encoding.TaikoL1ABI.Pack(method, encodedParams, []byte{})
		if err != nil {
			return nil, err
		}
	}

	return &txmgr.TxCandidate{
		TxData:   data,
		Blobs:    []*eth.Blob{blob},
		To:       to,
		GasLimit: b.gasLimit,
	}, nil
}
