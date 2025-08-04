package builder

import (
	"context"
	"crypto/ecdsa"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// CalldataTransactionBuilder is responsible for building a TaikoInbox.proposeBatch transaction with txList
// bytes saved in calldata.
type CalldataTransactionBuilder struct {
	rpc                         *rpc.Client
	proposerPrivateKey          *ecdsa.PrivateKey
	l2SuggestedFeeRecipient     common.Address
	taikoInboxAddress           common.Address
	taikoWrapperAddress         common.Address
	proverSetAddress            common.Address
	surgeProposerWrapperAddress common.Address
	gasLimit                    uint64
	chainConfig                 *config.ChainConfig
	revertProtectionEnabled     bool
}

// NewCalldataTransactionBuilder creates a new CalldataTransactionBuilder instance based on giving configurations.
func NewCalldataTransactionBuilder(
	rpc *rpc.Client,
	proposerPrivateKey *ecdsa.PrivateKey,
	l2SuggestedFeeRecipient common.Address,
	taikoInboxAddress common.Address,
	taikoWrapperAddress common.Address,
	proverSetAddress common.Address,
	surgeProposerWrapperAddress common.Address,
	gasLimit uint64,
	chainConfig *config.ChainConfig,
	revertProtectionEnabled bool,
) *CalldataTransactionBuilder {
	return &CalldataTransactionBuilder{
		rpc:                         rpc,
		proposerPrivateKey:          proposerPrivateKey,
		l2SuggestedFeeRecipient:     l2SuggestedFeeRecipient,
		taikoInboxAddress:           taikoInboxAddress,
		taikoWrapperAddress:         taikoWrapperAddress,
		proverSetAddress:            proverSetAddress,
		surgeProposerWrapperAddress: surgeProposerWrapperAddress,
		gasLimit:                    gasLimit,
		chainConfig:                 chainConfig,
		revertProtectionEnabled:     revertProtectionEnabled,
	}
}

// BuildPacaya implements the ProposeBatchTransactionBuilder interface.
func (b *CalldataTransactionBuilder) BuildPacaya(
	ctx context.Context,
	txBatch []types.Transactions,
	forcedInclusion *pacayaBindings.IForcedInclusionStoreForcedInclusion,
	minTxsPerForcedInclusion *big.Int,
	parentMetahash common.Hash,
	baseFee *big.Int,
) (*txmgr.TxCandidate, error) {
	// ABI encode the TaikoWrapper.proposeBatch / SurgeProposerWrapper.proposeBatch parameters.
	var (
		to                    = &b.taikoWrapperAddress
		proposer              = crypto.PubkeyToAddress(b.proposerPrivateKey.PublicKey)
		data                  []byte
		encodedParams         []byte
		blockParams           []pacayaBindings.ITaikoInboxBlockParams
		forcedInclusionParams *encoding.BatchParams
		allTxs                types.Transactions
	)

	if b.surgeProposerWrapperAddress != rpc.ZeroAddress {
		to = &b.surgeProposerWrapperAddress
		proposer = b.surgeProposerWrapperAddress
		log.Info("Using SurgeProposerWrapper for calldata transaction at proposeBatch",
			"surgeProposerWrapper", b.surgeProposerWrapperAddress.Hex(),
			"taikoWrapper", b.taikoWrapperAddress.Hex())
	}

	if forcedInclusion != nil {
		blobParams, blockParams := buildParamsForForcedInclusion(forcedInclusion, minTxsPerForcedInclusion)
		forcedInclusionParams = &encoding.BatchParams{
			Proposer:                 proposer,
			Coinbase:                 b.l2SuggestedFeeRecipient,
			RevertIfNotFirstProposal: b.revertProtectionEnabled,
			BlobParams:               *blobParams,
			Blocks:                   blockParams,
			BaseFee:                  baseFee,
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

	params := &encoding.BatchParams{
		Proposer:                 proposer,
		Coinbase:                 b.l2SuggestedFeeRecipient,
		RevertIfNotFirstProposal: b.revertProtectionEnabled,
		BlobParams: encoding.BlobParams{
			ByteOffset: 0,
			ByteSize:   uint32(len(txListsBytes)),
		},
		Blocks:  blockParams,
		BaseFee: baseFee,
	}

	if b.revertProtectionEnabled {
		if forcedInclusionParams != nil {
			forcedInclusionParams.ParentMetaHash = parentMetahash
		} else {
			params.ParentMetaHash = parentMetahash
		}
	}

	if encodedParams, err = encoding.EncodeBatchParamsWithForcedInclusion(forcedInclusionParams, params); err != nil {
		return nil, err
	}

	// Use SurgeProposerWrapper ABI (same interface as TaikoWrapper)
	if data, err = encoding.TaikoWrapperABI.Pack("proposeBatch", encodedParams, txListsBytes); err != nil {
		return nil, encoding.TryParsingCustomError(err)
	}

	return &txmgr.TxCandidate{
		TxData:   data,
		Blobs:    nil,
		To:       to,
		GasLimit: b.gasLimit,
	}, nil
}
