package manifest

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"math/big"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/common"
	consensus "github.com/ethereum/go-ethereum/consensus/taiko"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto/kzg4844"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/rlp"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	shastaIndexer "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/state_indexer"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

// ShastaBlockPayload represents a Shasta block payload with additional metadata.
type ShastaBlockPayload struct {
	manifest.BlockManifest
	BondInstructionsHash common.Hash
	BondInstructions     []shastaBindings.LibBondsBondInstruction
}

// ShastaDerivationSourcePayload wraps Shasta blocks alongside proposal metadata.
type ShastaDerivationSourcePayload struct {
	ProverAuthBytes   []byte
	BlockPayloads     []*ShastaBlockPayload
	Default           bool
	ParentBlock       *types.Block
	IsLowBondProposal bool
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

// Fetch fetches and checks the payload from event and blobs.
func (f *ShastaDerivationSourceFetcher) Fetch(
	ctx context.Context,
	meta metadata.TaikoProposalMetaDataShasta,
	derivationIdx int,
) (*ShastaDerivationSourcePayload, error) {
	// If there is no blob hash, or its length exceeds PROPOSAL_MAX_BLOBS, or its offset is invalid,
	// return the default payload.
	if len(meta.GetBlobHashes(derivationIdx)) == 0 ||
		meta.GetDerivation().Sources[derivationIdx].BlobSlice.Offset.Uint64() >
			uint64(manifest.BlobBytes*len(meta.GetBlobHashes(derivationIdx))-64) {
		return &ShastaDerivationSourcePayload{Default: true}, nil
	}

	// For forced-inclusion sources, we only allow 1 blob.
	if derivationIdx != len(meta.GetDerivation().Sources)-1 &&
		len(meta.GetBlobHashes(derivationIdx)) > 1 {
		return &ShastaDerivationSourcePayload{Default: true}, nil
	}

	blobBytes, err := f.fetchBlobs(ctx, meta, derivationIdx)
	if err != nil {
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
		proverAuth               []byte
		offset                   = int(meta.GetDerivation().Sources[derivationIdx].BlobSlice.Offset.Uint64())
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
	// For forced-inclusion sources, we only allow 1 block.
	if derivationIdx != len(meta.GetDerivation().Sources)-1 &&
		len(derivationSourceManifest.Blocks) > 1 {
		return defaultPayload, nil
		//for _, block := range derivationSourceManifest.Blocks {
		//	// Reset the anchor block number and timestamp from a forced-inclusion source to zero.
		//	block.AnchorBlockNumber = 0
		//	block.Timestamp = 0
		//	block.Coinbase = common.Address{}
		//	block.GasLimit = 0
		//}
	} else {
		// Only use the prover auth from the last source (non-forced-inclusion source).
		proverAuth = derivationSourceManifest.ProverAuthBytes
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
		ProverAuthBytes: proverAuth,
		BlockPayloads:   make([]*ShastaBlockPayload, len(derivationSourceManifest.Blocks)),
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
	sidecars, err := f.dataSource.GetBlobs(ctx, meta.GetBlobTimestamp(derivationIdx), blobHashes)
	if err != nil {
		return nil, fmt.Errorf("failed to get blobs, errs: %w", err)
	}

	if len(sidecars) != len(blobHashes) {
		return nil, fmt.Errorf("blob sidecar count mismatch: expected %d, got %d", len(blobHashes), len(sidecars))
	}

	log.Info(
		"Fetch sidecars",
		"proposalID", meta.GetProposal().Id,
		"l1Height", meta.GetRawBlockHeight(),
		"sidecars", len(sidecars),
	)
	// Build a map of blobHash -> blobBytes for O(1) lookup.
	blobMap := make(map[common.Hash][]byte, len(sidecars))
	for j, sidecar := range sidecars {
		log.Debug(
			"Block sidecar",
			"index", j,
			"KzgCommitment", sidecar.KzgCommitment,
		)

		commitment := kzg4844.Commitment(common.FromHex(sidecar.KzgCommitment))
		hash := kzg4844.CalcBlobHashV1(sha256.New(), &commitment)

		blob := eth.Blob(common.FromHex(sidecar.Blob))
		bytes, err := blob.ToData()
		if err != nil {
			return nil, err
		}
		blobMap[hash] = bytes
	}

	// Append in the order of blobHashes to preserve semantics.
	var b []byte
	for _, h := range blobHashes {
		bytes, ok := blobMap[h]
		if !ok {
			// If any requested blob is missing, surface a clear error.
			return nil, fmt.Errorf("requested blob hash %s not found in sidecars", h.Hex())
		}
		b = append(b, bytes...)
	}

	if len(b) == 0 {
		return nil, pkg.ErrSidecarNotFound
	}

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

// ValidateMetadata validates and decide block-level metadata according to protocol rules.
func ValidateMetadata(
	ctx context.Context,
	rpc *rpc.Client,
	sourcePayload *ShastaDerivationSourcePayload,
	isForcedInclusion bool,
	proposal shastaBindings.IInboxProposal,
	originBlockNumber uint64,
	forkTimestamp uint64,
	parentAnchorBlockNumber uint64,
) error {
	if sourcePayload == nil {
		return errors.New("empty derivation source payload")
	}
	// If there is the default payload, we return directly
	if sourcePayload.Default {
		return nil
	}

	// 1. Validate each block's timestamp.
	if !validateMetadataTimestamp(sourcePayload, proposal, forkTimestamp) {
		sourcePayload.Default = true
		return nil
	}

	// 2. Validate each block's anchor block number.
	if !validateAnchorBlockNumber(
		sourcePayload,
		originBlockNumber,
		parentAnchorBlockNumber,
		proposal,
		isForcedInclusion,
	) {
		sourcePayload.Default = true
		return nil
	}

	// 3. Validate each block's gas limit is within valid bounds.
	if !validateGasLimit(
		sourcePayload,
		sourcePayload.ParentBlock.Number(),
		sourcePayload.ParentBlock.GasLimit(),
	) {
		sourcePayload.Default = true
		return nil
	}

	return nil
}

// validateMetadataTimestamp checks if each block's timestamp is within valid bounds.
func validateMetadataTimestamp(
	sourcePayload *ShastaDerivationSourcePayload,
	proposal shastaBindings.IInboxProposal,
	forkTimestamp uint64,
) bool {
	var parentTimestamp = sourcePayload.ParentBlock.Time()
	for i := range sourcePayload.BlockPayloads {
		if sourcePayload.BlockPayloads[i].Timestamp > proposal.Timestamp.Uint64() {
			log.Info(
				"Invalid block timestamp to upper bound",
				"blockIndex", i,
				"originalTimestamp", sourcePayload.BlockPayloads[i].Timestamp,
				"upperBound", proposal.Timestamp,
			)
			return false
		}

		// Calculate lower bound for timestamp.
		lowerBound := max(parentTimestamp+1, proposal.Timestamp.Uint64()-manifest.TimestampMaxOffset, forkTimestamp)
		if sourcePayload.BlockPayloads[i].Timestamp < lowerBound {
			log.Info(
				"Invalid block timestamp to lower bound",
				"blockIndex", i,
				"originalTimestamp", sourcePayload.BlockPayloads[i].Timestamp,
				"lowerBound", lowerBound,
			)
			return false
		}
		parentTimestamp = sourcePayload.BlockPayloads[i].Timestamp
	}
	return true
}

// validateAnchorBlockNumber checks if each block's anchor block number is valid.
func validateAnchorBlockNumber(
	sourcePayload *ShastaDerivationSourcePayload,
	originBlockNumber uint64,
	parentAnchorBlockNumber uint64,
	proposal shastaBindings.IInboxProposal,
	isForcedInclusion bool,
) bool {
	var (
		originalParentAnchorNumber = parentAnchorBlockNumber
		highestAnchorNumber        = parentAnchorBlockNumber
	)
	for i := range sourcePayload.BlockPayloads {
		// 1. Non-monotonic progression: manifest.blocks[i].anchorBlockNumber < parent.metadata.anchorBlockNumber
		if sourcePayload.BlockPayloads[i].AnchorBlockNumber < parentAnchorBlockNumber {
			log.Info(
				"Invalid anchor block number: non-monotonic progression",
				"proposal", proposal.Id,
				"blockIndex", i,
				"anchorBlockNumber", sourcePayload.BlockPayloads[i].AnchorBlockNumber,
				"parentAnchorBlockNumber", parentAnchorBlockNumber,
			)
			return false
		}

		// 2. Future reference: manifest.blocks[i].anchorBlockNumber >= proposal.originBlockNumber - MIN_ANCHOR_OFFSET
		if sourcePayload.BlockPayloads[i].AnchorBlockNumber >= originBlockNumber-manifest.AnchorMinOffset {
			log.Info(
				"Invalid anchor block number: future reference",
				"proposal", proposal.Id,
				"blockIndex", i,
				"anchorBlockNumber", sourcePayload.BlockPayloads[i].AnchorBlockNumber,
				"originBlockNumber", originBlockNumber,
			)
			return false
		}

		// 3. Excessive lag: manifest.blocks[i].anchorBlockNumber < proposal.originBlockNumber - MAX_ANCHOR_OFFSET
		if originBlockNumber > manifest.AnchorMaxOffset &&
			sourcePayload.BlockPayloads[i].AnchorBlockNumber < originBlockNumber-manifest.AnchorMaxOffset {
			log.Info(
				"Invalid anchor block number: excessive lag",
				"proposal", proposal.Id,
				"blockIndex", i,
				"anchorBlockNumber", sourcePayload.BlockPayloads[i].AnchorBlockNumber,
				"minRequired", originBlockNumber-manifest.AnchorMaxOffset,
			)
			return false
		}

		if sourcePayload.BlockPayloads[i].AnchorBlockNumber > highestAnchorNumber {
			highestAnchorNumber = sourcePayload.BlockPayloads[i].AnchorBlockNumber
		}

		parentAnchorBlockNumber = sourcePayload.BlockPayloads[i].AnchorBlockNumber
	}

	// Forced inclusion protection: For non-forced proposals, if no blocks have valid anchor numbers greater than its
	// parent's, the entire payload is replaced with the default payload, penalizing proposals that fail to provide
	// proper L1 anchoring.
	if !isForcedInclusion && highestAnchorNumber <= originalParentAnchorNumber {
		log.Info(
			"Invalid anchor block numbers: no valid anchor numbers greater than parent's",
			"proposal", proposal.Id,
			"highestAnchorBlockNumber", highestAnchorNumber,
			"parentAnchorBlockNumber", originalParentAnchorNumber,
			"isForcedInclusion", isForcedInclusion,
		)
		return false
	}

	return true
}

// validateGasLimit checks each block's gas limit is within valid bounds.
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
		lowerGasBound := max(
			parentGasLimit*(manifest.GasLimitChangeDenominator-manifest.MaxBlockGasLimitChangePermyriad)/
				manifest.GasLimitChangeDenominator,
			manifest.MinBlockGasLimit,
		)
		upperGasBound := min(
			parentGasLimit*(manifest.GasLimitChangeDenominator+manifest.MaxBlockGasLimitChangePermyriad)/
				manifest.GasLimitChangeDenominator,
			manifest.MaxBlockGasLimit,
		)

		if sourcePayload.BlockPayloads[i].GasLimit < lowerGasBound {
			log.Info(
				"Invalid gas limit to lower bound",
				"blockIndex", i,
				"originalGasLimit", sourcePayload.BlockPayloads[i].GasLimit,
				"lowerGasBound", lowerGasBound,
			)
			return false
		}
		if sourcePayload.BlockPayloads[i].GasLimit > upperGasBound {
			log.Info(
				"Invalid gas limit to upper bound",
				"blockIndex", i,
				"originalGasLimit", sourcePayload.BlockPayloads[i].GasLimit,
				"newGasLimit", upperGasBound,
			)
			return false
		}

		parentGasLimit = sourcePayload.BlockPayloads[i].GasLimit
	}
	return true
}

// AssembleBondInstructions fetches and assembles bond instructions into the derivation payload.
func AssembleBondInstructions(
	ctx context.Context,
	proposalID *big.Int,
	indexer *shastaIndexer.Indexer,
	sourcePayload *ShastaDerivationSourcePayload,
) error {
	// If the current proposal ID is less than or equal to the bond processing delay,
	// there are no bond instructions to process.
	if proposalID.Uint64() <= manifest.BondProcessingDelay {
		return nil
	}

	targetProposal, err := indexer.GetProposalByID(proposalID.Uint64() - manifest.BondProcessingDelay)
	if err != nil {
		return fmt.Errorf("failed to get target proposal: %w", err)
	}
	for i := range sourcePayload.BlockPayloads {
		sourcePayload.BlockPayloads[i].BondInstructionsHash = targetProposal.CoreState.BondInstructionsHash
		sourcePayload.BlockPayloads[i].BondInstructions = targetProposal.BondInstructions
	}

	return nil
}
