package builder

import (
	"context"
	"fmt"
	"math"
	"math/big"

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
}

// NewBlobTransactionBuilder creates a new BlobTransactionBuilder instance.
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

	anchorBlockNumber := l1Head.Number.Uint64()

	// For inbox proposal submission in the current implementation, we always use the parent block's gas limit.
	l2Head, err := b.rpc.L2.HeaderByNumber(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get L2 head: %w", err)
	}
	gasLimit := l2Head.GasLimit
	if l2Head.Number.Uint64() > 0 {
		gasLimit -= consensus.AnchorV3V4GasLimit
	}

	for i, txs := range txBatch {
		log.Info(
			"Setting up derivation source manifest block",
			"index", i,
			"numTxs", len(txs),
			"timestamp", l1Head.Time+uint64(i),
			"anchorBlockNumber", anchorBlockNumber,
			"coinbase", b.l2SuggestedFeeRecipient,
			"gasLimit", gasLimit,
		)
		derivationSourceManifest.Blocks = append(derivationSourceManifest.Blocks, &manifest.BlockManifest{
			Timestamp:         l1Head.Time + uint64(i),
			Coinbase:          b.l2SuggestedFeeRecipient,
			AnchorBlockNumber: anchorBlockNumber,
			GasLimit:          gasLimit,
			Transactions:      txs,
		})
	}

	// Encode the derivation source manifest.
	sourceManifestBytes, err := EncodeSourceManifest(derivationSourceManifest)
	if err != nil {
		return nil, fmt.Errorf("failed to encode derivation source manifest: %w", err)
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
