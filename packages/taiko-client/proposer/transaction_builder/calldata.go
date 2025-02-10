package builder

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/rlp"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
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
	chainConfig             *config.ChainConfig
	revertProtectionEnabled bool
}

// NewCalldataTransactionBuilder creates a new CalldataTransactionBuilder instance based on giving configurations.
func NewCalldataTransactionBuilder(
	rpc *rpc.Client,
	proposerPrivateKey *ecdsa.PrivateKey,
	l2SuggestedFeeRecipient common.Address,
	taikoL1Address common.Address,
	proverSetAddress common.Address,
	gasLimit uint64,
	chainConfig *config.ChainConfig,
	revertProtectionEnabled bool,
) *CalldataTransactionBuilder {
	return &CalldataTransactionBuilder{
		rpc,
		proposerPrivateKey,
		l2SuggestedFeeRecipient,
		taikoL1Address,
		proverSetAddress,
		gasLimit,
		chainConfig,
		revertProtectionEnabled,
	}
}

// BuildOntake implements the ProposeBlockTransactionBuilder interface.
func (b *CalldataTransactionBuilder) BuildOntake(
	ctx context.Context,
	txListBytesArray [][]byte,
) (*txmgr.TxCandidate, error) {
	// Check if the current L2 chain is after ontake fork.
	l2Head, err := b.rpc.L2.BlockNumber(ctx)
	if err != nil {
		return nil, err
	}

	if !b.chainConfig.IsOntake(new(big.Int).SetUint64(l2Head)) {
		return nil, fmt.Errorf("ontake transaction builder is not supported before ontake fork")
	}

	// ABI encode the TaikoL1.proposeBlocksV2 / ProverSet.proposeBlocksV2 parameters.
	var (
		to                 = &b.taikoL1Address
		data               []byte
		encodedParamsArray [][]byte
	)

	for range txListBytesArray {
		encodedParams, err := encoding.EncodeBlockParamsOntake(&encoding.BlockParamsV2{
			Coinbase:       b.l2SuggestedFeeRecipient,
			ParentMetaHash: [32]byte{},
			AnchorBlockId:  0,
			Timestamp:      0,
		})
		if err != nil {
			return nil, err
		}
		encodedParamsArray = append(encodedParamsArray, encodedParams)
	}

	if b.proverSetAddress != rpc.ZeroAddress {
		to = &b.proverSetAddress
		if b.revertProtectionEnabled {
			data, err = encoding.ProverSetABI.Pack("proposeBlocksV2Conditionally", encodedParamsArray, txListBytesArray)
		} else {
			data, err = encoding.ProverSetABI.Pack("proposeBlocksV2", encodedParamsArray, txListBytesArray)
		}
		if err != nil {
			return nil, err
		}
	} else {
		data, err = encoding.TaikoL1ABI.Pack("proposeBlocksV2", encodedParamsArray, txListBytesArray)
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

// BuildPacaya implements the ProposeBlocksTransactionBuilder interface.
func (b *CalldataTransactionBuilder) BuildPacaya(
	ctx context.Context,
	txBatch []types.Transactions,
) (*txmgr.TxCandidate, error) {
	// ABI encode the TaikoInbox.proposeBatch / ProverSet.proposeBatch parameters.
	var (
		to            = &b.taikoL1Address
		data          []byte
		encodedParams []byte
		blockParams   []pacayaBindings.ITaikoInboxBlockParams
		allTxs        types.Transactions
	)

	for _, txs := range txBatch {
		allTxs = append(allTxs, txs...)
		blockParams = append(blockParams, pacayaBindings.ITaikoInboxBlockParams{
			NumTransactions: uint16(len(txs)),
			TimeShift:       0,
			SignalSlots:     make([][32]byte, 0),
		})
	}

	rlpEncoded, err := rlp.EncodeToBytes(allTxs)
	if err != nil {
		return nil, fmt.Errorf("failed to encode transactions: %w", err)
	}
	txListsBytes, err := utils.Compress(rlpEncoded)
	if err != nil {
		return nil, fmt.Errorf("failed to compress transactions: %w", err)
	}

	if encodedParams, err = encoding.EncodeBatchParams(&encoding.BatchParams{
		Coinbase:                 b.l2SuggestedFeeRecipient,
		RevertIfNotFirstProposal: b.revertProtectionEnabled,
		BlobParams: encoding.BlobParams{
			ByteOffset: 0,
			ByteSize:   uint32(len(txListsBytes)),
		},
		Blocks: blockParams,
	}); err != nil {
		return nil, err
	}

	if b.proverSetAddress != rpc.ZeroAddress {
		to = &b.proverSetAddress

		if data, err = encoding.ProverSetPacayaABI.Pack("proposeBatch", encodedParams, txListsBytes); err != nil {
			return nil, err
		}
	} else {
		if data, err = encoding.TaikoInboxABI.Pack("proposeBatch", encodedParams, txListsBytes); err != nil {
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
