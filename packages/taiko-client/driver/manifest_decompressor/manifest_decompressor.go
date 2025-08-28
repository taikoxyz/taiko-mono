package manifest_decompressor

import (
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/rlp"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

type ManifestDecompressor struct {
}

func (v *ManifestDecompressor) TryDecompressProposalManifest(blobBytes []byte, offset int) manifest.ProposalManifest {
	return v.tryDecompressProposalManifest(blobBytes, offset)
}

// tryDecompressProposalManifest is the inner implementation of TryDecompressProposalManifest.
func (v *ManifestDecompressor) tryDecompressProposalManifest(
	blobBytes []byte,
	offset int,
) manifest.ProposalManifest {
	_, size, err := ExtractVersionAndSize(blobBytes, offset)
	if err != nil {
		log.Error("Failed to extracts both version or size, use default manifest instead", "err", err)
		return manifest.ProposalManifest{}
	}

	manifestBytes, err := utils.Decompress(blobBytes[offset+64 : offset+64+int(size)])
	// Decompress the manifest bytes.
	if err != nil {
		log.Error("Failed to decompress manifest bytes, use default manifest instead", "error", err)
		return manifest.ProposalManifest{}
	}

	var proposal manifest.ProposalManifest
	// Try to RLP decode the transaction list bytes.
	if err = rlp.DecodeBytes(manifestBytes, &proposal); err != nil {
		log.Error("Failed to decode  decompress manifest bytes, use default manifest instead", "error", err)
		return manifest.ProposalManifest{}
	}

	if len(proposal.Blocks) > manifest.ProposalMaxBlocks {
		log.Error("There are too many blocks in the manifest, use default manifest instead",
			"blocks", len(proposal.Blocks),
			"max", manifest.ProposalMaxBlocks)
		return manifest.ProposalManifest{}
	}

	for _, block := range proposal.Blocks {
		if len(block.Transactions) > manifest.BlockMaxRawTransactions {
			log.Error("Block has too many transactions, use default manifest instead",
				"transactions", len(block.Transactions),
				"max", manifest.BlockMaxRawTransactions)
			return manifest.ProposalManifest{}
		}
	}

	return proposal
}

// ExtractVersion extracts the version number from bytes [offset, offset+32)
// Returns the version number and an error if extraction fails
func ExtractVersion(data []byte, offset int) (uint32, error) {
	if len(data) < offset+32 {
		return 0, fmt.Errorf("insufficient data: need at least %d bytes, got %d", offset+32, len(data))
	}

	// Extract 32 bytes for version
	versionBytes := data[offset : offset+32]

	// Convert bytes to big.Int
	version := new(big.Int).SetBytes(versionBytes)

	// Check if version fits in uint32
	if !version.IsUint64() {
		return 0, fmt.Errorf("version number too large")
	}

	versionUint := uint32(version.Uint64())

	// Validate version for Shasta
	if versionUint != manifest.ValidShastaVersion {
		return 0, fmt.Errorf("invalid version: expected 0x%x, got 0x%x", manifest.ValidShastaVersion, versionUint)
	}

	return versionUint, nil
}

// ExtractSize extracts the data size from bytes [offset+32, offset+64)
// Returns the size and an error if extraction fails
func ExtractSize(data []byte, offset int) (uint64, error) {
	if len(data) < offset+64 {
		return 0, fmt.Errorf("insufficient data: need at least %d bytes, got %d", offset+64, len(data))
	}

	// Extract 32 bytes for size
	sizeBytes := data[offset+32 : offset+64]

	// Convert bytes to big.Int
	size := new(big.Int).SetBytes(sizeBytes)

	// Check if size fits in uint64
	if !size.IsUint64() {
		return 0, fmt.Errorf("data size too large for uint64")
	}

	// Validate size
	if size.Cmp(big.NewInt(manifest.ProposalMaxBytes)) > 0 {
		return 0, fmt.Errorf("invalid size: size(%d) exceeds PROPOSAL_MAX_BYTES", size)
	}

	return size.Uint64(), nil
}

// ExtractVersionAndSize extracts both version and size from the data
// Returns version, size, and an error if extraction fails
func ExtractVersionAndSize(data []byte, offset int) (uint32, uint64, error) {
	version, err := ExtractVersion(data, offset)
	if err != nil {
		return 0, 0, fmt.Errorf("failed to extract version: %w", err)
	}

	size, err := ExtractSize(data, offset)
	if err != nil {
		return 0, 0, fmt.Errorf("failed to extract size: %w", err)
	}

	return version, size, nil
}
