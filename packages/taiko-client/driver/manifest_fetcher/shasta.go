package manifestFetcher

import (
	"context"
	"crypto/sha256"
	"fmt"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto/kzg4844"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// ShastaManifestFetcher is responsible for fetching the txList blob from the L1 block sidecar.
type ShastaManifestFetcher struct {
	cli        *rpc.Client
	dataSource *rpc.BlobDataSource
}

// NewShastaManifestFetcher creates a new ShastaManifestFetcher instance based on the given rpc client.
func NewShastaManifestFetcher(cli *rpc.Client, ds *rpc.BlobDataSource) *ShastaManifestFetcher {
	return &ShastaManifestFetcher{cli, ds}
}

func (d *ShastaManifestFetcher) FetchShasta(ctx context.Context, meta metadata.TaikoProposalMetaDataShasta) ([]byte, error) {
	blobHashesLength := len(meta.GetDerivation().BlobSlice.BlobHashes)
	if blobHashesLength == 0 ||
		blobHashesLength > manifest.ProposalMaxBlobs ||
		meta.GetDerivation().BlobSlice.Offset.Cmp(big.NewInt(int64(manifest.BlobBytes*blobHashesLength-32))) > 0 {
		return nil, pkg.ErrBlobValidationFailed
	}

	// Fetch the L1 block sidecars.
	sidecars, err := d.dataSource.GetBlobs(ctx, meta.GetBlobTimestamp(), meta.GetBlobHashes())
	if err != nil {
		return nil, fmt.Errorf("failed to get blobs, errs: %w", err)
	}

	log.Info("Fetch sidecars",
		"proposalID", meta.GetProposal().Id,
		"l1Height", meta.GetRawBlockHeight(),
		"sidecars", len(sidecars),
	)

	var b []byte
	for _, blobHash := range meta.GetBlobHashes() {
		// Compare the blob hash with the sidecar's kzg commitment.
		for j, sidecar := range sidecars {
			log.Debug(
				"Block sidecar",
				"index", j,
				"KzgCommitment", sidecar.KzgCommitment,
				"blobHash", blobHash,
			)

			commitment := kzg4844.Commitment(common.FromHex(sidecar.KzgCommitment))
			if kzg4844.CalcBlobHashV1(sha256.New(), &commitment) == blobHash {
				blob := eth.Blob(common.FromHex(sidecar.Blob))
				bytes, err := blob.ToData()
				if err != nil {
					return nil, err
				}

				b = append(b, bytes...)
				// Exit the loop as the matching sidecar has been found and processed.
				break
			}
		}
	}
	if len(b) == 0 {
		return nil, pkg.ErrSidecarNotFound
	}

	return b, nil
}
