package builder

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"math/big"
	"sync/atomic"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	consensus "github.com/ethereum/go-ethereum/consensus/taiko"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// BlobTransactionBuilder is responsible for building a TaikoInbox.proposeBatch transaction with txList
// bytes saved in blob.
type BlobTransactionBuilder struct {
	rpc                     *rpc.Client
	proposerPrivateKey      *ecdsa.PrivateKey
	pacayaInboxAddress      common.Address
	shastaInboxAddress      common.Address
	taikoWrapperAddress     common.Address
	proverSetAddress        common.Address
	l2SuggestedFeeRecipient common.Address
	gasLimit                uint64
	chainConfig             *config.ChainConfig
	revertProtectionEnabled bool
	manifestBuilderCounter  uint32
}

// NewBlobTransactionBuilder creates a new BlobTransactionBuilder instance based on giving configurations.
func NewBlobTransactionBuilder(
	rpc *rpc.Client,
	proposerPrivateKey *ecdsa.PrivateKey,
	pacayaInboxAddress common.Address,
	shastaInboxAddress common.Address,
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
		pacayaInboxAddress,
		shastaInboxAddress,
		taikoWrapperAddress,
		proverSetAddress,
		l2SuggestedFeeRecipient,
		gasLimit,
		chainConfig,
		revertProtectionEnabled,
		0,
	}
}

// BuildPacaya implements the ProposeBatchTransactionBuilder interface.
func (b *BlobTransactionBuilder) BuildPacaya(
	ctx context.Context,
	txBatch []types.Transactions,
	forcedInclusion *pacayaBindings.IForcedInclusionStoreForcedInclusion,
	minTxsPerForcedInclusion *big.Int,
	parentMetahash common.Hash,
	preconfRouterAddress common.Address,
) (*txmgr.TxCandidate, error) {
	to := &b.taikoWrapperAddress
	if preconfRouterAddress != rpc.ZeroAddress {
		to = &preconfRouterAddress
	}

	// ABI encode the TaikoWrapper.proposeBatch / ProverSet.proposeBatch parameters.
	var (
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

	if blobs, err = SplitToBlobs(txListsBytes); err != nil {
		return nil, err
	}

	params := &encoding.BatchParams{
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

// BuildShasta implements the ProposeBatchTransactionBuilder interface.
func (b *BlobTransactionBuilder) BuildShasta(
	ctx context.Context,
	txBatch []types.Transactions,
	minTxsPerForcedInclusion *big.Int,
	preconfRouterAddress common.Address,
) (*txmgr.TxCandidate, error) {
	var (
		to                       = &b.shastaInboxAddress
		derivationSourceManifest = &manifest.DerivationSourceManifest{}
		blobs                    []*eth.Blob
		data                     []byte
	)
	if preconfRouterAddress != rpc.ZeroAddress {
		to = &preconfRouterAddress
	}

	l1Head, err := b.rpc.L1.HeaderByNumber(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get L1 head: %w", err)
	}

	// For Shasta proposals submission in current implementation, we always use the parent block's gas limit.
	l2Head, err := b.rpc.L2.HeaderByNumber(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get L2 head: %w", err)
	}
	var gasLimit = l2Head.GasLimit - consensus.AnchorV3V4GasLimit
	if l2Head.Time < b.rpc.ShastaClients.ForkTime {
		gasLimit = manifest.MaxBlockGasLimit
	}

	// Populate the derivation source manifest with one boundary test case at a time (round-robin).
	builders := []func(*manifest.DerivationSourceManifest, []types.Transactions, *types.Header, uint64){
		b.lowTimestamp,
		b.highTimestamp,
		b.lowGasLimit,
		b.highGasLimit,
		b.lowAnchorBlockNumberOffset,
		b.highAnchorBlockNumberOffset,
	}
	idx := atomic.AddUint32(&b.manifestBuilderCounter, 1) - 1
	buildFn := builders[idx%uint32(len(builders))]
	buildFn(derivationSourceManifest, txBatch, l1Head, gasLimit)

	// Encode the derivation source manifest.
	sourceManifestBytes, err := EncodeSourceManifestShasta(derivationSourceManifest)
	if err != nil {
		return nil, fmt.Errorf("failed to encode derivation source manifest: %w", err)
	}

	// Split the derivation source manifest bytes into multiple blobs.
	if blobs, err = SplitToBlobs(sourceManifestBytes); err != nil {
		return nil, err
	}

	// ABI encode the ShastaInbox.propose parameters.
	inputData, err := b.rpc.EncodeProposeInput(
		&bind.CallOpts{Context: ctx},
		&shastaBindings.IInboxProposeInput{
			Deadline: common.Big0,
			BlobReference: shastaBindings.LibBlobsBlobReference{
				BlobStartIndex: 0,
				NumBlobs:       uint16(len(blobs)),
				Offset:         common.Big0,
			},
			NumForcedInclusions: uint8(minTxsPerForcedInclusion.Uint64()),
		},
	)
	if err != nil {
		return nil, fmt.Errorf("failed to encode shasta propose input: %w", err)
	}

	if data, err = encoding.ShastaInboxABI.Pack("propose", []byte{}, inputData); err != nil {
		return nil, err
	}

	return &txmgr.TxCandidate{
		TxData:   data,
		Blobs:    blobs,
		To:       to,
		GasLimit: b.gasLimit,
	}, nil
}

// SplitToBlobs splits the txListBytes into multiple blobs.
func SplitToBlobs(txListBytes []byte) ([]*eth.Blob, error) {
	var blobs []*eth.Blob
	for start := 0; start < len(txListBytes); start += eth.MaxBlobDataSize {
		end := min(start+eth.MaxBlobDataSize, len(txListBytes))

		var blob = &eth.Blob{}
		if err := blob.FromData(txListBytes[start:end]); err != nil {
			return nil, err
		}

		blobs = append(blobs, blob)
	}

	return blobs, nil
}

// EncodeSourceManifestShasta encodes the given derivation source manifest to a byte slice
// that can be used as input to the Shasta Inbox.propose function.
func EncodeSourceManifestShasta(sourceManifest *manifest.DerivationSourceManifest) ([]byte, error) {
	sourceManifestBytes, err := utils.EncodeAndCompressSourceManifestShasta(sourceManifest)
	if err != nil {
		return nil, err
	}

	// Prepend the version and length bytes to the manifest bytes, then split
	// the resulting bytes into multiple blobs.
	versionBytes := make([]byte, 32)
	versionBytes[31] = byte(manifest.ShastaPayloadVersion)

	lenBytes := make([]byte, 32)
	lenBig := new(big.Int).SetUint64(uint64(len(sourceManifestBytes)))
	lenBig.FillBytes(lenBytes)

	blobBytesPrefix := make([]byte, 0, 64)
	blobBytesPrefix = append(blobBytesPrefix, versionBytes...)
	blobBytesPrefix = append(blobBytesPrefix, lenBytes...)

	return append(blobBytesPrefix, sourceManifestBytes...), nil
}

func (b *BlobTransactionBuilder) lowTimestamp(
	sourceManifest *manifest.DerivationSourceManifest,
	txBatch []types.Transactions,
	l1Head *types.Header,
	gasLimit uint64,
) {
	for i, txs := range txBatch {
		log.Info(
			"Constructing test case for testing the lower bound of the timestamp.",
			"index", i,
			"numTxs", len(txs),
			"timestamp", 1,
			"anchorBlockNumber", l1Head.Number.Uint64(),
			"coinbase", b.l2SuggestedFeeRecipient,
			"gasLimit", gasLimit,
		)
		sourceManifest.Blocks = append(sourceManifest.Blocks, &manifest.BlockManifest{
			Timestamp:         1,
			Coinbase:          b.l2SuggestedFeeRecipient,
			AnchorBlockNumber: l1Head.Number.Uint64(),
			GasLimit:          gasLimit,
			Transactions:      txs,
		})
	}
}

func (b *BlobTransactionBuilder) highTimestamp(
	sourceManifest *manifest.DerivationSourceManifest,
	txBatch []types.Transactions,
	l1Head *types.Header,
	gasLimit uint64,
) {
	for i, txs := range txBatch {
		log.Info(
			"Constructing test case for testing the higher bound of the timestamp.",
			"index", i,
			"numTxs", len(txs),
			"timestamp", l1Head.Time+200,
			"anchorBlockNumber", l1Head.Number.Uint64(),
			"coinbase", b.l2SuggestedFeeRecipient,
			"gasLimit", gasLimit,
		)
		sourceManifest.Blocks = append(sourceManifest.Blocks, &manifest.BlockManifest{
			Timestamp:         l1Head.Time + 200,
			Coinbase:          b.l2SuggestedFeeRecipient,
			AnchorBlockNumber: l1Head.Number.Uint64(),
			GasLimit:          gasLimit,
			Transactions:      txs,
		})
	}
}

func (b *BlobTransactionBuilder) lowGasLimit(
	sourceManifest *manifest.DerivationSourceManifest,
	txBatch []types.Transactions,
	l1Head *types.Header,
	gasLimit uint64,
) {
	for i, txs := range txBatch {
		log.Info(
			"Constructing test case for testing the lower bound of the gas limit.",
			"index", i,
			"numTxs", len(txs),
			"timestamp", l1Head.Time+uint64(i),
			"anchorBlockNumber", l1Head.Number.Uint64(),
			"coinbase", b.l2SuggestedFeeRecipient,
			"gasLimit", gasLimit/2,
		)
		sourceManifest.Blocks = append(sourceManifest.Blocks, &manifest.BlockManifest{
			Timestamp:         l1Head.Time + uint64(i),
			Coinbase:          b.l2SuggestedFeeRecipient,
			AnchorBlockNumber: l1Head.Number.Uint64(),
			GasLimit:          gasLimit / 2,
			Transactions:      txs,
		})
	}
}

func (b *BlobTransactionBuilder) highGasLimit(
	sourceManifest *manifest.DerivationSourceManifest,
	txBatch []types.Transactions,
	l1Head *types.Header,
	gasLimit uint64,
) {
	for i, txs := range txBatch {
		log.Info(
			"Constructing test case for testing the higher bound of the gas limit.",
			"index", i,
			"numTxs", len(txs),
			"timestamp", l1Head.Time+uint64(i),
			"anchorBlockNumber", l1Head.Number.Uint64(),
			"coinbase", b.l2SuggestedFeeRecipient,
			"gasLimit", gasLimit*2,
		)
		sourceManifest.Blocks = append(sourceManifest.Blocks, &manifest.BlockManifest{
			Timestamp:         l1Head.Time + uint64(i),
			Coinbase:          b.l2SuggestedFeeRecipient,
			AnchorBlockNumber: l1Head.Number.Uint64(),
			GasLimit:          gasLimit * 2,
			Transactions:      txs,
		})
	}
}

func (b *BlobTransactionBuilder) lowAnchorBlockNumberOffset(
	sourceManifest *manifest.DerivationSourceManifest,
	txBatch []types.Transactions,
	l1Head *types.Header,
	gasLimit uint64,
) {
	for i, txs := range txBatch {
		log.Info(
			"Constructing test case for testing the lower bound of the anchor block number offset.",
			"index", i,
			"numTxs", len(txs),
			"timestamp", l1Head.Time+uint64(i),
			"anchorBlockNumber", l1Head.Number.Uint64()+10,
			"coinbase", b.l2SuggestedFeeRecipient,
			"gasLimit", gasLimit,
		)
		sourceManifest.Blocks = append(sourceManifest.Blocks, &manifest.BlockManifest{
			Timestamp:         l1Head.Time + uint64(i),
			Coinbase:          b.l2SuggestedFeeRecipient,
			AnchorBlockNumber: l1Head.Number.Uint64() + 10,
			GasLimit:          gasLimit,
			Transactions:      txs,
		})
	}
}

func (b *BlobTransactionBuilder) highAnchorBlockNumberOffset(
	sourceManifest *manifest.DerivationSourceManifest,
	txBatch []types.Transactions,
	l1Head *types.Header,
	gasLimit uint64,
) {
	for i, txs := range txBatch {
		log.Info(
			"Constructing test case for testing the higher bound of the anchor block number Offset.",
			"index", i,
			"numTxs", len(txs),
			"timestamp", l1Head.Time+uint64(i),
			"anchorBlockNumber", l1Head.Number.Uint64()-manifest.AnchorMaxOffset-1,
			"coinbase", b.l2SuggestedFeeRecipient,
			"gasLimit", gasLimit,
		)
		sourceManifest.Blocks = append(sourceManifest.Blocks, &manifest.BlockManifest{
			Timestamp:         l1Head.Time + uint64(i),
			Coinbase:          b.l2SuggestedFeeRecipient,
			AnchorBlockNumber: l1Head.Number.Uint64() - manifest.AnchorMaxOffset - 1,
			GasLimit:          gasLimit,
			Transactions:      txs,
		})
	}
}
