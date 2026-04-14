package derivation

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

// BlockPayload represents a L2 block payload with additional metadata.
type BlockPayload struct {
	manifest.BlockManifest
}

// DerivationSourcePayload wraps L2 blocks alongside proposal metadata.
type DerivationSourcePayload struct {
	BlockPayloads []*BlockPayload
	Default       bool
	ParentBlock   *types.Block
}

// DerivationSourceFetcher is responsible for fetching the blob source from the L1 block sidecar.
type DerivationSourceFetcher struct {
	cli        *rpc.Client
	dataSource *rpc.BlobDataSource
}

// NewDerivationSourceFetcher creates a new derivation source fetcher based on the given RPC client.
func NewDerivationSourceFetcher(cli *rpc.Client, dataSource *rpc.BlobDataSource) *DerivationSourceFetcher {
	return &DerivationSourceFetcher{
		cli:        cli,
		dataSource: dataSource,
	}
}

// Fetch builds a derivation source payload for the given proposal source index.
func (f *DerivationSourceFetcher) Fetch(
	ctx context.Context,
	meta metadata.TaikoProposalMetaDataShasta,
	derivationIdx int,
) (*DerivationSourcePayload, error) {
	// If there is no blob hash, or its offset is invalid, return the default payload.
	if len(meta.GetBlobHashes(derivationIdx)) == 0 ||
		meta.GetEventData().Sources[derivationIdx].BlobSlice.Offset.Uint64() >
			uint64(manifest.BlobBytes-64) {
		return &DerivationSourcePayload{Default: true}, nil
	}

	blobBytes, err := f.fetchBlobs(ctx, meta, derivationIdx)
	if err != nil {
		if errors.Is(err, rpc.ErrInvalidBlobBytes) {
			return &DerivationSourcePayload{Default: true}, nil
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
func (f *DerivationSourceFetcher) manifestFromBlobBytes(
	b []byte,
	meta metadata.TaikoProposalMetaDataShasta,
	derivationIdx int,
) (*DerivationSourcePayload, error) {
	var (
		offset                   = int(meta.GetEventData().Sources[derivationIdx].BlobSlice.Offset.Uint64())
		defaultPayload           = &DerivationSourcePayload{Default: true}
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

	log.Info("Extracted manifest version and size from blobs", "version", version, "size", size)

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

	// Convert protocol derivation manifest to DerivationSourcePayload.
	payload := &DerivationSourcePayload{
		BlockPayloads: make([]*BlockPayload, len(derivationSourceManifest.Blocks)),
	}
	for i, block := range derivationSourceManifest.Blocks {
		payload.BlockPayloads[i] = &BlockPayload{BlockManifest: *block}
	}

	return payload, nil
}

// fetchBlobs fetches the blob source from the L1 block sidecar.
func (f *DerivationSourceFetcher) fetchBlobs(
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
	if version.BitLen() > 32 {
		return 0, fmt.Errorf("version number %s too large", version.String())
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

	if !size.IsUint64() {
		return 0, fmt.Errorf("size %s too large", size.String())
	}

	return size.Uint64(), nil
}

// ValidateMetadata validates block-level metadata according to protocol rules, return true if validation passes.
func ValidateMetadata(
	rpc *rpc.Client,
	sourcePayload *DerivationSourcePayload,
	event *shastaBindings.ShastaInboxClientProposed,
	proposalTimestamp uint64,
	originBlockNumber uint64,
	parentAnchorBlockNumber uint64,
	isForcedInclusion bool,
) bool {
	if sourcePayload.Default {
		return false
	}

	if !validateMetadataTimestamp(
		sourcePayload,
		event,
		proposalTimestamp,
		rpc.L2.ChainID,
	) {
		return false
	}

	if !validateAnchorBlockNumber(
		sourcePayload,
		originBlockNumber,
		parentAnchorBlockNumber,
		event,
		isForcedInclusion,
		rpc.L2.ChainID,
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
	sourcePayload *DerivationSourcePayload,
	event *shastaBindings.ShastaInboxClientProposed,
	proposalTimestamp uint64,
	chainID *big.Int,
) bool {
	var (
		parentTimestamp = sourcePayload.ParentBlock.Time()
	)

	for i := range sourcePayload.BlockPayloads {
		lowerBound := ComputeTimestampLowerBound(parentTimestamp, proposalTimestamp, chainID)
		if lowerBound > proposalTimestamp {
			log.Info(
				"Invalid timestamp bounds",
				"blockIndex", i,
				"proposalTimestamp", proposalTimestamp,
				"lowerBound", lowerBound,
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
// Returns the maximum of all three values to ensure all constraints are satisfied.
func ComputeTimestampLowerBound(parentTimestamp, proposalTimestamp uint64, chainID *big.Int) uint64 {
	timestampMaxOffset := manifest.TimestampMaxOffsetByChainID(chainID)

	lowerBound := parentTimestamp + 1
	if proposalTimestamp > timestampMaxOffset {
		lowerBound = max(lowerBound, proposalTimestamp-timestampMaxOffset)
	}

	return lowerBound
}

// validateAnchorBlockNumber checks if each block's anchor block number is valid.
func validateAnchorBlockNumber(
	sourcePayload *DerivationSourcePayload,
	originBlockNumber uint64,
	parentAnchorBlockNumber uint64,
	event *shastaBindings.ShastaInboxClientProposed,
	isForcedInclusion bool,
	chainID *big.Int,
) bool {
	var (
		originalParentAnchorNumber = parentAnchorBlockNumber
		highestAnchorNumber        = parentAnchorBlockNumber
		anchorMaxOffset            = manifest.AnchorMaxOffsetByChainID(chainID)
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

		if originBlockNumber > anchorMaxOffset &&
			anchorBlockNumber < originBlockNumber-anchorMaxOffset {
			log.Info(
				"Invalid anchor block number: excessive lag",
				"proposal", event.Id,
				"blockIndex", i,
				"anchorBlockNumber", anchorBlockNumber,
				"minRequired", originBlockNumber-anchorMaxOffset,
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
	sourcePayload *DerivationSourcePayload,
	parentBlockNumber *big.Int,
	parentGasLimit uint64,
) bool {
	// NOTE: When the parent block is not the genesis block, its gas limit always contains the
	// legacy or post-Shasta anchor transaction gas limit, which always equals consensus.AnchorV3V4GasLimit.
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
	sourcePayload *DerivationSourcePayload,
	event *shastaBindings.ShastaInboxClientProposed,
	timestamp uint64,
	anchorBlockNumber uint64,
	chainID *big.Int,
) {
	var (
		parentTimestamp = sourcePayload.ParentBlock.Time()
		parentGasLimit  = sourcePayload.ParentBlock.GasLimit()
	)
	if sourcePayload.ParentBlock.Number().Cmp(common.Big0) != 0 {
		parentGasLimit -= consensus.AnchorV3V4GasLimit
	}

	for i := range sourcePayload.BlockPayloads {
		lowerBound := ComputeTimestampLowerBound(parentTimestamp, timestamp, chainID)

		sourcePayload.BlockPayloads[i].Timestamp = lowerBound
		sourcePayload.BlockPayloads[i].Coinbase = event.Proposer
		sourcePayload.BlockPayloads[i].AnchorBlockNumber = anchorBlockNumber
		sourcePayload.BlockPayloads[i].GasLimit = parentGasLimit

		parentTimestamp = lowerBound
	}
}
