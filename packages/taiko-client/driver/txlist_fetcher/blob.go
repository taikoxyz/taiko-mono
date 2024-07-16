package txlistdecoder

import (
	"context"
	"crypto/sha256"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto/kzg4844"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// BlobFetcher is responsible for fetching the txList blob from the L1 block sidecar.
type BlobFetcher struct {
	l1Beacon *rpc.BeaconClient
	ds       *rpc.BlobDataSource
}

// NewBlobTxListFetcher creates a new BlobFetcher instance based on the given rpc client.
func NewBlobTxListFetcher(l1Beacon *rpc.BeaconClient, ds *rpc.BlobDataSource) *BlobFetcher {
	return &BlobFetcher{l1Beacon, ds}
}

// Fetch implements the TxListFetcher interface.
func (d *BlobFetcher) Fetch(
	ctx context.Context,
	_ *types.Transaction,
	meta *bindings.TaikoDataBlockMetadata,
	emittedInBlockID uint64,
	blockProposedEventEmittedInTimestamp uint64,
) ([]byte, error) {
	if !meta.BlobUsed {
		return nil, pkg.ErrBlobUsed
	}

	// Fetch the L1 block sidecars.
	sidecars, err := d.ds.GetBlobs(ctx, meta, blockProposedEventEmittedInTimestamp)
	if err != nil {
		return nil, err
	}

	log.Info("Fetch sidecars", "blockNumber", emittedInBlockID, "sidecars", len(sidecars))

	// Compare the blob hash with the sidecar's kzg commitment.
	for i, sidecar := range sidecars {
		log.Info(
			"Block sidecar",
			"index", i,
			"KzgCommitment", sidecar.KzgCommitment,
			"blobHash", common.Bytes2Hex(meta.BlobHash[:]),
		)

		commitment := kzg4844.Commitment(common.FromHex(sidecar.KzgCommitment))
		if kzg4844.CalcBlobHashV1(
			sha256.New(),
			&commitment,
		) == common.BytesToHash(meta.BlobHash[:]) {
			blob := eth.Blob(common.FromHex(sidecar.Blob))
			return blob.ToData()
		}
	}

	return nil, pkg.ErrSidecarNotFound
}
