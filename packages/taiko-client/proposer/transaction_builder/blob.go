package builder

import (
	"context"
	"fmt"
	"math"
	"math/big"
	"sync/atomic"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	consensus "github.com/ethereum/go-ethereum/consensus/taiko"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// BlobTransactionBuilder is responsible for building an inbox propose transaction with txList bytes saved in blobs.
type BlobTransactionBuilder struct {
	rpc                     *rpc.Client
	inboxAddress            common.Address
	l2SuggestedFeeRecipient common.Address
	gasLimit                uint64
	manifestBuilderCounter  uint32
}

type shastaManifestTestCase struct {
	name          string
	buildManifest func(*manifest.DerivationSourceManifest, []types.Transactions, *types.Header, uint64)
	mutatePayload func([]byte) []byte
}

// NewBlobTransactionBuilder creates a new BlobTransactionBuilder instance based on giving configurations.
func NewBlobTransactionBuilder(
	rpc *rpc.Client,
	inboxAddress common.Address,
	l2SuggestedFeeRecipient common.Address,
	gasLimit uint64,
) *BlobTransactionBuilder {
	return &BlobTransactionBuilder{
		rpc:                     rpc,
		inboxAddress:            inboxAddress,
		l2SuggestedFeeRecipient: l2SuggestedFeeRecipient,
		gasLimit:                gasLimit,
		manifestBuilderCounter:  0,
	}
}

// Build implements the ProposeBatchTransactionBuilder interface.
func (b *BlobTransactionBuilder) Build(
	ctx context.Context,
	txBatch []types.Transactions,
) (*txmgr.TxCandidate, error) {
	var (
		to                       = &b.inboxAddress
		derivationSourceManifest = &manifest.DerivationSourceManifest{}
		blobs                    []*eth.Blob
		data                     []byte
	)

	l1Head, err := b.rpc.L1.HeaderByNumber(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get L1 head: %w", err)
	}

	// For Shasta proposals submission in current implementation, we always use the parent block's gas limit.
	l2Head, err := b.rpc.L2.HeaderByNumber(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get L2 head: %w", err)
	}
	gasLimit := l2Head.GasLimit
	if l2Head.Number.Uint64() > 0 {
		gasLimit -= consensus.AnchorV3V4GasLimit
	}

	// Populate the derivation source manifest with one boundary test case at a time (round-robin).
	testCases := b.shastaManifestTestCases()
	idx := atomic.AddUint32(&b.manifestBuilderCounter, 1) - 1
	testCase := testCases[idx%uint32(len(testCases))]
	testCase.buildManifest(derivationSourceManifest, txBatch, l1Head, gasLimit)

	// Encode the derivation source manifest.
	sourceManifestBytes, err := EncodeSourceManifest(derivationSourceManifest)
	if err != nil {
		return nil, fmt.Errorf("failed to encode derivation source manifest: %w", err)
	}

	if testCase.mutatePayload != nil {
		sourceManifestBytes = testCase.mutatePayload(sourceManifestBytes)
	}

	// Split the derivation source manifest bytes into multiple blobs.
	if blobs, err = SplitToBlobs(sourceManifestBytes); err != nil {
		return nil, err
	}

	// ABI encode the inbox propose parameters.
	inputData, err := b.rpc.EncodeProposeInput(
		&bind.CallOpts{Context: ctx},
		&shastaBindings.IInboxProposeInput{
			Deadline: common.Big0,
			BlobReference: shastaBindings.LibBlobsBlobReference{
				BlobStartIndex: 0,
				NumBlobs:       uint16(len(blobs)),
				Offset:         common.Big0,
			},
			// We try to include all the forced inclusions in the source manifest.
			NumForcedInclusions: math.MaxUint16,
		},
	)
	if err != nil {
		return nil, fmt.Errorf("failed to encode inbox.propose input: %w", err)
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

		blob := &eth.Blob{}
		if err := blob.FromData(txListBytes[start:end]); err != nil {
			return nil, err
		}

		blobs = append(blobs, blob)
	}

	return blobs, nil
}

// EncodeSourceManifest encodes the given derivation source manifest to a byte slice
// that can be used as input to the inbox propose function.
func EncodeSourceManifest(sourceManifest *manifest.DerivationSourceManifest) ([]byte, error) {
	sourceManifestBytes, err := utils.EncodeAndCompressSourceManifest(sourceManifest)
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

func (b *BlobTransactionBuilder) shastaManifestTestCases() []shastaManifestTestCase {
	return []shastaManifestTestCase{
		{name: "low timestamp", buildManifest: b.lowTimestamp},
		{name: "high timestamp", buildManifest: b.highTimestamp},
		{name: "low gas limit", buildManifest: b.lowGasLimit},
		{name: "high gas limit", buildManifest: b.highGasLimit},
		{name: "low anchor block number offset", buildManifest: b.lowAnchorBlockNumberOffset},
		{name: "high anchor block number offset", buildManifest: b.highAnchorBlockNumberOffset},
		{name: "invalid blob", buildManifest: b.validManifest, mutatePayload: invalidBlobPayload},
		{name: "invalid tx", buildManifest: b.invalidTx},
	}
}

func invalidBlobPayload(payload []byte) []byte {
	corrupted := append([]byte(nil), payload...)
	corrupted[31] = byte(manifest.ShastaPayloadVersion + 1)
	return corrupted
}

func (b *BlobTransactionBuilder) validManifest(
	sourceManifest *manifest.DerivationSourceManifest,
	txBatch []types.Transactions,
	l1Head *types.Header,
	gasLimit uint64,
) {
	for i, txs := range txBatch {
		log.Info(
			"Constructing valid derivation source manifest.",
			"index", i,
			"numTxs", len(txs),
			"timestamp", l1Head.Time+uint64(i),
			"anchorBlockNumber", l1Head.Number.Uint64(),
			"coinbase", b.l2SuggestedFeeRecipient,
			"gasLimit", gasLimit,
		)
		sourceManifest.Blocks = append(sourceManifest.Blocks, &manifest.BlockManifest{
			Timestamp:         l1Head.Time + uint64(i),
			Coinbase:          b.l2SuggestedFeeRecipient,
			AnchorBlockNumber: l1Head.Number.Uint64(),
			GasLimit:          gasLimit,
			Transactions:      txs,
		})
	}
}

func (b *BlobTransactionBuilder) invalidTx(
	sourceManifest *manifest.DerivationSourceManifest,
	txBatch []types.Transactions,
	l1Head *types.Header,
	gasLimit uint64,
) {
	b.validManifest(sourceManifest, txBatch, l1Head, gasLimit)
	if len(sourceManifest.Blocks) == 0 {
		return
	}

	to := common.Address{}
	sourceManifest.Blocks[0].Transactions = append(
		sourceManifest.Blocks[0].Transactions,
		types.NewTx(&types.DynamicFeeTx{
			ChainID:   common.Big1,
			Nonce:     0,
			GasTipCap: big.NewInt(2),
			GasFeeCap: common.Big1,
			Gas:       21_000,
			To:        &to,
			Value:     common.Big0,
		}),
	)
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
