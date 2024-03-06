package txlistdecoder

import (
	"context"
	"crypto/sha256"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto/kzg4844"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

type BlobFetcher struct {
	rpc *rpc.Client
}

func NewBlobTxListFetcher(rpc *rpc.Client) *BlobFetcher {
	return &BlobFetcher{rpc}
}

func (d *BlobFetcher) Fetch(
	ctx context.Context,
	tx *types.Transaction,
	meta *bindings.TaikoDataBlockMetadata,
) ([]byte, error) {
	if !meta.BlobUsed {
		return nil, errBlobUnused
	}

	sidecars, err := d.rpc.GetBlobs(ctx, new(big.Int).SetUint64(meta.L1Height+1))
	if err != nil {
		return nil, err
	}

	log.Info("Fetch sidecars", "slot", meta.L1Height+1, "sidecars", len(sidecars))

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
			return rpc.DecodeBlob(common.FromHex(sidecar.Blob))
		}
	}

	return nil, errSidecarNotFound
}
