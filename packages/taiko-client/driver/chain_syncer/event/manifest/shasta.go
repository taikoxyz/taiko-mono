package manifest

import (
	"context"
	"errors"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	consensus "github.com/ethereum/go-ethereum/consensus/taiko"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/rlp"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// ShastaBlockPayload represents a Shasta block payload with additional metadata.
type ShastaBlockPayload struct {
	manifest.BlockManifest
}

// ShastaDerivationSourcePayload wraps Shasta blocks alongside proposal metadata.
type ShastaDerivationSourcePayload struct {
	BlockPayloads []*ShastaBlockPayload
	Default       bool
	ParentBlock   *types.Block
}

// ShastaDerivationSourceFetcher is responsible for fetching the blob source from the L1 block sidecar.
type ShastaDerivationSourceFetcher struct {
	cli        *rpc.Client
	dataSource *rpc.BlobDataSource
}

// NewDerivationSourceFetcher creates a new ShastaManifestFetcher instance based on the given rpc client.
func NewDerivationSourceFetcher(cli *rpc.Client, dataSource *rpc.BlobDataSource) *ShastaDerivationSourceFetcher {
	return &ShastaDerivationSourceFetcher{
		cli:        cli,
		dataSource: dataSource,
	}
}

// NewShastaManifestFetcher creates a new ShastaDerivationSourceFetcher instance based on the given rpc client.
func (f *ShastaDerivationSourceFetcher) Fetch(
	ctx context.Context,
	meta metadata.TaikoProposalMetaDataShasta,
	derivationIdx int,
) (*ShastaDerivationSourcePayload, error) {
	// If there is no blob hash, or its length exceeds PROPOSAL_MAX_BLOBS, or its offset is invalid,
	// return the default payload.
	if len(meta.GetBlobHashes(derivationIdx)) == 0 ||
		meta.GetEventData().Sources[derivationIdx].BlobSlice.Offset.Uint64() >
			uint64(manifest.BlobBytes*len(meta.GetBlobHashes(derivationIdx))-64) {
		return &ShastaDerivationSourcePayload{Default: true}, nil
	}

	blobBytes, err := f.fetchBlobs(ctx, meta, derivationIdx)
	if err != nil {
		if errors.Is(err, rpc.ErrInvalidBlobBytes) {
			return &ShastaDerivationSourcePayload{Default: true}, nil
		}
		return nil, fmt.Errorf("failed to fetch blobs: %w", err)
	}

	return f.manifestFromBlobBytes(
		blobBytes,
		meta,
		derivationIdx,
	)
}

// manifestFromBlobBytes constructs the derivation payload from the given blob bytes.
func (f *ShastaDerivationSourceFetcher) manifestFromBlobBytes(
	b []byte,
	meta metadata.TaikoProposalMetaDataShasta,
	derivationIdx int,
) (*ShastaDerivationSourcePayload, error) {
	var (
		offset                   = int(meta.GetEventData().Sources[derivationIdx].BlobSlice.Offset.Uint64())
		defaultPayload           = &ShastaDerivationSourcePayload{Default: true}
		derivationSourceManifest = new(manifest.DerivationSourceManifest)
	)
	version, size, err := ExtractVersionAndSize(b, offset)
	if err != nil {
		log.Warn("Failed to extract version or size in blob bytes, use default payload instead", "err", err)
		return defaultPayload, nil
	}

	if version != manifest.ShastaPayloadVersion {
		log.Warn("Unsupported manifest version, use default payload instead", "version", version)
		return defaultPayload, nil
	}

	log.Info("Extracted manifest version and size from Shasta blobs", "version", version, "size", size)

	// Ensure the blob slice [offset+64, offset+64+size) is within bounds before slicing.
	start := offset + 64
	if start > len(b) || uint64(len(b)-start) < size {
		log.Warn(
			"Invalid manifest bounds in blob bytes, use default payload instead",
			"version", version,
			"offset", offset,
			"size", size,
			"blobLen", len(b),
		)
		return defaultPayload, nil
	}
	encoded, err := utils.Decompress(b[start : start+int(size)])
	// Decompress the manifest bytes.
	if err != nil {
		log.Warn(
			"Failed to decompress manifest bytes, use default payload instead",
			"version", version,
			"offset", offset,
			"size", size,
			"error", err,
		)
		return defaultPayload, nil
	}

	// Try to RLP decode the manifest bytes.
	if err = rlp.DecodeBytes(encoded, derivationSourceManifest); err != nil {
		log.Warn("Failed to decode derivation source manifest bytes, use default payload instead", "error", err)
		return defaultPayload, nil
	}
	if derivationIdx != len(meta.GetEventData().Sources)-1 {
		// For forced-inclusion source, ensure it contains exactly one block.
		if len(derivationSourceManifest.Blocks) != 1 {
			log.Warn(
				"Invalid blocks count in forced-inclusion source manifest, use default payload instead",
				"blobs", len(meta.GetEventData().Sources[derivationIdx].BlobSlice.BlobHashes),
				"blocks", len(derivationSourceManifest.Blocks),
			)
			return defaultPayload, nil
		}
	}

	// If there are too many blocks in the manifest, return the default payload.
	if len(derivationSourceManifest.Blocks) > manifest.ProposalMaxBlocks {
		log.Warn(
			"Too many blocks in the manifest, use default payload instead",
			"blocks", len(derivationSourceManifest.Blocks),
			"max", manifest.ProposalMaxBlocks,
		)
		return defaultPayload, nil
	}

	// Convert protocol derivation manifest to ShastaDerivationSourcePayload.
	payload := &ShastaDerivationSourcePayload{
		BlockPayloads: make([]*ShastaBlockPayload, len(derivationSourceManifest.Blocks)),
	}
	for i, block := range derivationSourceManifest.Blocks {
		payload.BlockPayloads[i] = &ShastaBlockPayload{BlockManifest: *block}
	}

	return payload, nil
}

// fetchBlobs fetches the blob source from the L1 block sidecar.
func (f *ShastaDerivationSourceFetcher) fetchBlobs(
	ctx context.Context,
	meta metadata.TaikoProposalMetaDataShasta,
	derivationIdx int,
) ([]byte, error) {
	blobHashes := meta.GetBlobHashes(derivationIdx)
	// Fetch the L1 block sidecars.
	b, err := f.dataSource.GetBlobBytes(ctx, meta.GetBlobTimestamp(derivationIdx), blobHashes)
	if err != nil {
		return nil, fmt.Errorf("failed to get blobs, errs: %w", err)
	}
	log.Info(
		"Fetch sidecars",
		"proposalID", meta.GetEventData().Id,
		"l1Height", meta.GetRawBlockHeight(),
		"sidecars", len(blobHashes),
	)
	return b, nil
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

// ExtractVersion extracts the version number from bytes [offset, offset+32)
// Returns the version number and an error if extraction fails
func ExtractVersion(data []byte, offset int) (uint32, error) {
	if len(data) < offset+32 {
		return 0, fmt.Errorf("insufficient data: need at least %d bytes, got %d", offset+32, len(data))
	}

	// Extract 32 bytes for version
	version := new(big.Int).SetBytes(data[offset : offset+32])

	// Check if version fits in uint32
	if !version.IsUint64() {
		return 0, fmt.Errorf("version number %d too large", version)
	}

	return uint32(version.Uint64()), nil
}

// ExtractSize extracts the data size from bytes [offset+32, offset+64)
// Returns the size and an error if extraction fails
func ExtractSize(data []byte, offset int) (uint64, error) {
	if len(data) < offset+64 {
		return 0, fmt.Errorf("insufficient data: need at least %d bytes, got %d", offset+64, len(data))
	}

	// Extract 32 bytes for size
	size := new(big.Int).SetBytes(data[offset+32 : offset+64])

	return size.Uint64(), nil
}

// ValidateMetadata validates block-level metadata according to protocol rules, return true if validation passes.
func ValidateMetadata(
	rpc *rpc.Client,
	sourcePayload *ShastaDerivationSourcePayload,
	event *shastaBindings.ShastaInboxClientProposed,
	proposalTimestamp uint64,
	originBlockNumber uint64,
	parentAnchorBlockNumber uint64,
	isForcedInclusion bool,
) bool {
	if sourcePayload.Default {
		return false
	}

	if !validateMetadataTimestamp(sourcePayload, event, proposalTimestamp, rpc.ShastaClients.ForkTime) {
		return false
	}

	if !validateAnchorBlockNumber(
		sourcePayload,
		originBlockNumber,
		parentAnchorBlockNumber,
		event,
		isForcedInclusion,
	) {
		return false
	}

	if !validateGasLimit(
		sourcePayload,
		sourcePayload.ParentBlock.Number(),
		sourcePayload.ParentBlock.GasLimit(),
	) {
		return false
	}

	return true
}

// validateMetadataTimestamp ensures each block's timestamp is within valid bounds.
func validateMetadataTimestamp(
	sourcePayload *ShastaDerivationSourcePayload,
	event *shastaBindings.ShastaInboxClientProposed,
	proposalTimestamp uint64,
	forkTime uint64,
) bool {
	var (
		parentTimestamp = sourcePayload.ParentBlock.Time()
	)

	for i := range sourcePayload.BlockPayloads {
		lowerBound := ComputeTimestampLowerBound(parentTimestamp, proposalTimestamp, forkTime)
		if lowerBound > proposalTimestamp {
			log.Info(
				"Invalid timestamp bounds",
				"blockIndex", i,
				"proposalTimestamp", proposalTimestamp,
				"lowerBound", lowerBound,
				"forkTime", forkTime,
			)
			return false
		}

		blockTimestamp := sourcePayload.BlockPayloads[i].Timestamp
		if blockTimestamp < lowerBound || blockTimestamp > proposalTimestamp {
			log.Info(
				"Invalid block timestamp",
				"blockIndex", i,
				"timestamp", blockTimestamp,
				"lowerBound", lowerBound,
				"upperBound", proposalTimestamp,
			)
			return false
		}

		parentTimestamp = blockTimestamp
	}

	return true
}

// ComputeTimestampLowerBound calculates the minimum allowed timestamp for the next block.
//
// The lower bound is determined by taking the maximum of three constraints:
// 1. parent_timestamp + 1: Blocks must progress forward in time
// 2. proposal_timestamp - TIMESTAMP_MAX_OFFSET: Blocks cannot be too far in the past relative to the proposal
// 3. fork_timestamp: Blocks must be after the Shasta fork activation
//
// Returns the maximum of all three values to ensure all constraints are satisfied.
func ComputeTimestampLowerBound(parentTimestamp, proposalTimestamp, forkTime uint64) uint64 {
	lowerBound := max(parentTimestamp+1, forkTime)
	if proposalTimestamp > manifest.TimestampMaxOffset {
		lowerBound = max(lowerBound, proposalTimestamp-manifest.TimestampMaxOffset)
	}

	return lowerBound
}

// validateAnchorBlockNumber checks if each block's anchor block number is valid.
func validateAnchorBlockNumber(
	sourcePayload *ShastaDerivationSourcePayload,
	originBlockNumber uint64,
	parentAnchorBlockNumber uint64,
	event *shastaBindings.ShastaInboxClientProposed,
	isForcedInclusion bool,
) bool {
	var (
		originalParentAnchorNumber = parentAnchorBlockNumber
		highestAnchorNumber        = parentAnchorBlockNumber
	)
	for i := range sourcePayload.BlockPayloads {
		anchorBlockNumber := sourcePayload.BlockPayloads[i].AnchorBlockNumber

		if anchorBlockNumber < parentAnchorBlockNumber {
			log.Info(
				"Invalid anchor block number: non-monotonic progression",
				"proposal", event.Id,
				"blockIndex", i,
				"anchorBlockNumber", anchorBlockNumber,
				"parentAnchorBlockNumber", parentAnchorBlockNumber,
			)
			return false
		}

		if anchorBlockNumber > originBlockNumber {
			log.Info(
				"Invalid anchor block number: cannot be newer than origin block",
				"proposal", event.Id,
				"blockIndex", i,
				"anchorBlockNumber", anchorBlockNumber,
				"originBlockNumber", originBlockNumber,
			)
			return false
		}

		if originBlockNumber > manifest.AnchorMaxOffset &&
			anchorBlockNumber < originBlockNumber-manifest.AnchorMaxOffset {
			log.Info(
				"Invalid anchor block number: excessive lag",
				"proposal", event.Id,
				"blockIndex", i,
				"anchorBlockNumber", anchorBlockNumber,
				"minRequired", originBlockNumber-manifest.AnchorMaxOffset,
			)
			return false
		}

		if anchorBlockNumber > highestAnchorNumber {
			highestAnchorNumber = anchorBlockNumber
		}

		parentAnchorBlockNumber = anchorBlockNumber
	}

	// Forced inclusion protection: For non-forced proposals, if no blocks have valid anchor numbers greater than its
	// parent's, the entire payload is replaced with the default payload, penalizing proposals that fail to provide
	// proper L1 anchoring.
	if !isForcedInclusion && highestAnchorNumber <= originalParentAnchorNumber {
		log.Info(
			"Invalid anchor block numbers: no valid anchor numbers greater than parent's",
			"proposal", event.Id,
			"highestAnchorBlockNumber", highestAnchorNumber,
			"parentAnchorBlockNumber", originalParentAnchorNumber,
			"isForcedInclusion", isForcedInclusion,
		)
		return false
	}

	return true
}

// validateGasLimit ensures each block's gas limit is within valid bounds.
func validateGasLimit(
	sourcePayload *ShastaDerivationSourcePayload,
	parentBlockNumber *big.Int,
	parentGasLimit uint64,
) bool {
	// NOTE: When the parent block is not the genesis block, its gas limit always contains the Pacaya
	// or Shasta anchor transaction gas limit, which always equals to consensus.AnchorV3V4GasLimit.
	// Therefore, we need to subtract consensus.AnchorV3V4GasLimit from the parent gas limit to get
	// the real gas limit from parent block metadata.
	if parentBlockNumber.Cmp(common.Big0) != 0 {
		parentGasLimit = parentGasLimit - consensus.AnchorV3V4GasLimit
	}
	for i := range sourcePayload.BlockPayloads {
		upperGasBound := min(
			parentGasLimit*(manifest.GasLimitChangeDenominator+manifest.MaxBlockGasLimitMaxChange)/
				manifest.GasLimitChangeDenominator,
			manifest.MaxBlockGasLimit,
		)
		lowerGasBound := min(max(
			parentGasLimit*(manifest.GasLimitChangeDenominator-manifest.MaxBlockGasLimitMaxChange)/
				manifest.GasLimitChangeDenominator,
			manifest.MinBlockGasLimit,
		), upperGasBound)

		if sourcePayload.BlockPayloads[i].GasLimit < lowerGasBound ||
			sourcePayload.BlockPayloads[i].GasLimit > upperGasBound {
			log.Info(
				"Invalid gas limit",
				"blockIndex", i,
				"gasLimit", sourcePayload.BlockPayloads[i].GasLimit,
				"lowerBound", lowerGasBound,
				"upperBound", upperGasBound,
			)
			return false
		}

		parentGasLimit = sourcePayload.BlockPayloads[i].GasLimit
	}

	return true
}

// ApplyInheritedMetadata assigns proposer, anchor, gas limit, and timestamp values to each block by inheriting
// from the parent block metadata.
func ApplyInheritedMetadata(
	sourcePayload *ShastaDerivationSourcePayload,
	event *shastaBindings.ShastaInboxClientProposed,
	timestamp uint64,
	anchorBlockNumber uint64,
	forkTime uint64,
) {
	var (
		parentTimestamp = sourcePayload.ParentBlock.Time()
		parentGasLimit  = sourcePayload.ParentBlock.GasLimit()
	)
	if sourcePayload.ParentBlock.Number().Cmp(common.Big0) != 0 {
		parentGasLimit -= consensus.AnchorV3V4GasLimit
	}

	for i := range sourcePayload.BlockPayloads {
		lowerBound := ComputeTimestampLowerBound(parentTimestamp, timestamp, forkTime)

		sourcePayload.BlockPayloads[i].Timestamp = lowerBound
		sourcePayload.BlockPayloads[i].Coinbase = event.Proposer
		sourcePayload.BlockPayloads[i].AnchorBlockNumber = anchorBlockNumber
		sourcePayload.BlockPayloads[i].GasLimit = parentGasLimit

		parentTimestamp = lowerBound
	}
}
