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
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// BlobTransactionBuilder is responsible for building a TaikoL1.proposeBlock transaction with txList
// bytes saved in blob.
type BlobTransactionBuilder struct {
	rpc                     *rpc.Client
	proposerPrivateKey      *ecdsa.PrivateKey
	taikoL1Address          common.Address
	taikoWrapperAddress     common.Address
	proverSetAddress        common.Address
	l2SuggestedFeeRecipient common.Address
	gasLimit                uint64
	chainConfig             *config.ChainConfig
	revertProtectionEnabled bool
}

// NewBlobTransactionBuilder creates a new BlobTransactionBuilder instance based on giving configurations.
func NewBlobTransactionBuilder(
	rpc *rpc.Client,
	proposerPrivateKey *ecdsa.PrivateKey,
	taikoL1Address common.Address,
	taikoWrapperAddress common.Address,
	proverSetAddress common.Address,
	l2SuggestedFeeRecipient common.Address,
	gasLimit uint64,
	chainConfig *config.ChainConfig,
	revertProtectionEnabled bool,
) *BlobTransactionBuilder {
	return &BlobTransactionBuilder{
		rpc,
		proposerPrivateKey,
		taikoL1Address,
		taikoWrapperAddress,
		proverSetAddress,
		l2SuggestedFeeRecipient,
		gasLimit,
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
	_, slotB, err := b.rpc.GetProtocolStateVariablesOntake(&bind.CallOpts{Context: ctx})
	if err != nil {
		return nil, err
	}

	if !b.chainConfig.IsOntake(new(big.Int).SetUint64(slotB.NumBlocks)) {
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

		params := &encoding.BlockParamsV2{
			Coinbase:         b.l2SuggestedFeeRecipient,
			ParentMetaHash:   [32]byte{},
			AnchorBlockId:    0,
			Timestamp:        0,
			BlobTxListOffset: 0,
			BlobTxListLength: uint32(len(txListBytesArray[i])),
			BlobIndex:        uint8(i),
		}

		if i == 0 && b.revertProtectionEnabled {
			_, slotB, err := b.rpc.GetProtocolStateVariablesOntake(nil)
			if err != nil {
				return nil, err
			}

			blockInfo, err := b.rpc.GetL2BlockInfoV2(ctx, new(big.Int).SetUint64(slotB.NumBlocks-1))
			if err != nil {
				return nil, err
			}

			params.ParentMetaHash = blockInfo.MetaHash
		}

		encodedParams, err := encoding.EncodeBlockParamsOntake(params)
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

// BuildPacaya implements the ProposeBlocksTransactionBuilder interface.
func (b *BlobTransactionBuilder) BuildPacaya(
	ctx context.Context,
	txBatch []types.Transactions,
	forcedInclusion *pacayaBindings.IForcedInclusionStoreForcedInclusion,
	minTxsPerForcedInclusion *big.Int,
) (*txmgr.TxCandidate, error) {
	// ABI encode the TaikoWrapper.proposeBatch / ProverSet.proposeBatch parameters.
	var (
		to                    = &b.taikoWrapperAddress
		proposer              = crypto.PubkeyToAddress(b.proposerPrivateKey.PublicKey)
		data                  []byte
		blobs                 []*eth.Blob
		encodedParams         []byte
		blockParams           []pacayaBindings.ITaikoInboxBlockParams
		forcedInclusionParams *encoding.BatchParams
		allTxs                types.Transactions
	)

	if b.proverSetAddress != rpc.ZeroAddress {
		to = &b.proverSetAddress
		proposer = b.proverSetAddress
	}

	if forcedInclusion != nil {
		blobParams, blockParams := buildParamsForForcedInclusion(forcedInclusion, minTxsPerForcedInclusion)
		forcedInclusionParams = &encoding.BatchParams{
			Proposer:                 proposer,
			Coinbase:                 b.l2SuggestedFeeRecipient,
			RevertIfNotFirstProposal: b.revertProtectionEnabled,
			BlobParams:               *blobParams,
			Blocks:                   blockParams,
		}
	}

	for _, txs := range txBatch {
		allTxs = append(allTxs, txs...)
		blockParams = append(blockParams, pacayaBindings.ITaikoInboxBlockParams{
			NumTransactions: uint16(len(txs)),
			TimeShift:       0,
			SignalSlots:     make([][32]byte, 0),
		})
	}

	txListsBytes, err := utils.EncodeAndCompressTxList(allTxs)
	if err != nil {
		return nil, err
	}

	if blobs, err = b.splitToBlobs(txListsBytes); err != nil {
		return nil, err
	}

	if encodedParams, err = encoding.EncodeBatchParamsWithForcedInclusion(
		forcedInclusionParams,
		&encoding.BatchParams{
			Proposer:                 proposer,
			Coinbase:                 b.l2SuggestedFeeRecipient,
			RevertIfNotFirstProposal: b.revertProtectionEnabled,
			BlobParams: encoding.BlobParams{
				BlobHashes:     [][32]byte{},
				FirstBlobIndex: 0,
				NumBlobs:       uint8(len(blobs)),
				ByteOffset:     0,
				ByteSize:       uint32(len(txListsBytes)),
			},
			Blocks: blockParams,
		}); err != nil {
		return nil, err
	}

	if b.proverSetAddress != rpc.ZeroAddress {
		if data, err = encoding.ProverSetPacayaABI.Pack("proposeBatch", encodedParams, []byte{}); err != nil {
			return nil, err
		}
	} else {
		if data, err = encoding.TaikoWrapperABI.Pack("proposeBatch", encodedParams, []byte{}); err != nil {
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

// splitToBlobs splits the txListBytes into multiple blobs.
func (b *BlobTransactionBuilder) splitToBlobs(txListBytes []byte) ([]*eth.Blob, error) {
	var blobs []*eth.Blob
	for start := 0; start < len(txListBytes); start += rpc.BlobBytes {
		end := start + rpc.BlobBytes
		if end > len(txListBytes) {
			end = len(txListBytes)
		}

		var blob = &eth.Blob{}
		if err := blob.FromData(txListBytes[start:end]); err != nil {
			return nil, err
		}

		blobs = append(blobs, blob)
	}

	return blobs, nil
}
