package manifest

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	consensus "github.com/ethereum/go-ethereum/consensus/taiko"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto/kzg4844"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/rlp"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	shastaIndexer "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/state_indexer"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

const (
	defaultTimeout = 1 * time.Minute
)

// ShastaBlockPayload represents a Shasta block payload with additional metadata.
type ShastaBlockPayload struct {
	manifest.BlockManifest
	BondInstructionsHash common.Hash
	BondInstructions     []shastaBindings.LibBondsBondInstruction
}

// ShastaProposalPayload wraps Shasta blocks alongside proposal metadata.
type ShastaProposalPayload struct {
	ProverAuthBytes   []byte
	BlockPayloads     []*ShastaBlockPayload
	Default           bool
	ParentBlock       *types.Block
	IsLowBondProposal bool
}

// ShastaManifestFetcher is responsible for fetching the txList blob from the L1 block sidecar.
type ShastaManifestFetcher struct {
	cli        *rpc.Client
	dataSource *rpc.BlobDataSource
}

// NewManifestFetcher creates a new ShastaManifestFetcher instance based on the given rpc client.
func NewManifestFetcher(cli *rpc.Client, dataSource *rpc.BlobDataSource) *ShastaManifestFetcher {
	return &ShastaManifestFetcher{
		cli:        cli,
		dataSource: dataSource,
	}
}

// NewShastaManifestFetcher creates a new ShastaManifestFetcher instance based on the given rpc client.
func (f *ShastaManifestFetcher) Fetch(
	ctx context.Context,
	meta metadata.TaikoProposalMetaDataShasta,
	derivationIdx int,
) (*ShastaProposalPayload, error) {
	// If there is no blob hash, or its length exceeds PROPOSAL_MAX_BLOBS, or its offest is invalid,
	// return the default manifest.
	if len(meta.GetBlobHashes(derivationIdx)) == 0 ||
		meta.GetDerivation().Sources[derivationIdx].BlobSlice.Offset.Uint64() >
			uint64(manifest.BlobBytes*len(meta.GetBlobHashes(derivationIdx))-64) {
		return &ShastaProposalPayload{Default: true}, nil
	}

	blobBytes, err := f.fetchBlobs(ctx, meta, derivationIdx)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch blobs: %w", err)
	}

	return f.manifestFromBlobBytes(blobBytes, int(meta.GetDerivation().Sources[derivationIdx].BlobSlice.Offset.Uint64()))
}

// manifestFromBlobBytes constructs the manifest from the given blob bytes.
func (f *ShastaManifestFetcher) manifestFromBlobBytes(
	b []byte,
	offset int,
) (*ShastaProposalPayload, error) {
	var (
		defaultPayload   = &ShastaProposalPayload{Default: true}
		protocolProposal = new(manifest.DerivationSourceManifest)
	)
	version, size, err := ExtractVersionAndSize(b, offset)
	if err != nil {
		log.Warn("Failed to extracts version or size in blob bytes, use default payload instead", "err", err)
		return defaultPayload, nil
	}

	if version != manifest.ShastaPayloadVersion {
		log.Warn("Unsupported manifest version, use default payload instead", "version", version)
		return defaultPayload, nil
	}

	log.Info("Extracted manifest version and size from Shasta blobs", "version", version, "size", size)

	encoded, err := utils.Decompress(b[offset+64 : offset+64+int(size)])
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
	if err = rlp.DecodeBytes(encoded, protocolProposal); err != nil {
		log.Warn("Failed to decode manifest bytes, use default payload instead", "error", err)
		return defaultPayload, err
	}

	// If there are too many blocks in the manifest, return the default manifest.
	if len(protocolProposal.Blocks) > manifest.ProposalMaxBlocks {
		log.Warn(
			"Too many blocks in the manifest, use default payload instead",
			"blocks", len(protocolProposal.Blocks),
			"max", manifest.ProposalMaxBlocks,
		)
		return defaultPayload, nil
	}

	// Convert ProtocolProposalManifest to ShastaProposalPayload.
	proposal := &ShastaProposalPayload{
		BlockPayloads: make([]*ShastaBlockPayload, len(protocolProposal.Blocks)),
	}
	for i, block := range protocolProposal.Blocks {
		proposal.BlockPayloads[i] = &ShastaBlockPayload{BlockManifest: *block}
	}

	return proposal, nil
}

// fetchBlobs fetches the blobs from the L1 block sidecar.
func (f *ShastaManifestFetcher) fetchBlobs(
	ctx context.Context,
	meta metadata.TaikoProposalMetaDataShasta,
	derivationIdx int,
) ([]byte, error) {
	// Fetch the L1 block sidecars.
	sidecars, err := f.dataSource.GetBlobs(ctx, meta.GetBlobTimestamp(derivationIdx), meta.GetBlobHashes(derivationIdx))
	if err != nil {
		return nil, fmt.Errorf("failed to get blobs, errs: %w", err)
	}

	log.Info(
		"Fetch sidecars",
		"proposalID", meta.GetProposal().Id,
		"l1Height", meta.GetRawBlockHeight(),
		"sidecars", len(sidecars),
	)

	var b []byte
	for _, blobHash := range meta.GetBlobHashes(derivationIdx) {
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

// ValidateMetadata validates and adjusts block-level metadata according to protocol rules.
func ValidateMetadata(
	ctx context.Context,
	rpc *rpc.Client,
	proposalPayload *ShastaProposalPayload,
	isForcedInclusion bool,
	proposal shastaBindings.IInboxProposal,
	originBlockNumber uint64,
	bondInstructionsHash common.Hash,
	parentAnchorBlockNumber uint64,
) error {
	if proposalPayload == nil {
		return errors.New("empty proposal payload")
	}
	// If there is the default payload, we return directly
	if proposalPayload.Default {
		return nil
	}

	// 1. Validate and adjust each block's timestamp.
	validateMetadataTimestamp(proposalPayload, proposal)

	// 2. Validate and adjust each block's anchor block number.
	if !validateAnchorBlockNumber(
		proposalPayload,
		originBlockNumber,
		parentAnchorBlockNumber,
		proposal,
		isForcedInclusion,
	) {
		proposalPayload.Default = true
		return nil
	}

	// 3. Ensure each block's coinbase is correctly assigned.
	validateCoinbase(proposalPayload, proposal, isForcedInclusion)

	// 4. Ensure each block's gas limit is within valid bounds.
	validateGasLimit(
		proposalPayload,
		proposalPayload.ParentBlock.Number(),
		proposalPayload.ParentBlock.GasLimit(),
	)

	return nil
}

// validateMetadataTimestamp ensures each block's timestamp is within valid bounds.
func validateMetadataTimestamp(proposalPayload *ShastaProposalPayload, proposal shastaBindings.IInboxProposal) {
	var parentTimestamp = proposalPayload.ParentBlock.Time()
	for i := range proposalPayload.BlockPayloads {
		if proposalPayload.BlockPayloads[i].Timestamp > proposal.Timestamp.Uint64() {
			log.Info(
				"Adjusting block timestamp to upper bound",
				"blockIndex", i,
				"originalTimestamp", proposalPayload.BlockPayloads[i].Timestamp,
				"newTimestamp", proposal.Timestamp,
			)
			proposalPayload.BlockPayloads[i].Timestamp = proposal.Timestamp.Uint64()
		}

		// Calculate lower bound for timestamp.
		lowerBound := max(parentTimestamp+1, proposal.Timestamp.Uint64()-manifest.TimestampMaxOffset)
		if proposalPayload.BlockPayloads[i].Timestamp < lowerBound {
			log.Info(
				"Adjusting block timestamp to lower bound",
				"blockIndex", i,
				"originalTimestamp", proposalPayload.BlockPayloads[i].Timestamp,
				"newTimestamp", lowerBound,
			)
			proposalPayload.BlockPayloads[i].Timestamp = lowerBound
		}
		parentTimestamp = proposalPayload.BlockPayloads[i].Timestamp
	}
}

// validateAnchorBlockNumber checks if each block's anchor block number is valid.
func validateAnchorBlockNumber(
	proposalPayload *ShastaProposalPayload,
	originBlockNumber uint64,
	parentAnchorBlockNumber uint64,
	proposal shastaBindings.IInboxProposal,
	isForcedInclusion bool,
) bool {
	var (
		originalParentAnchorNumber = parentAnchorBlockNumber
		highestAnchorNumber        = parentAnchorBlockNumber
	)
	for i := range proposalPayload.BlockPayloads {
		// 1. Non-monotonic progression: manifest.blocks[i].anchorBlockNumber < parent.metadata.anchorBlockNumber
		if proposalPayload.BlockPayloads[i].AnchorBlockNumber < parentAnchorBlockNumber {
			log.Info(
				"Invalid anchor block number: non-monotonic progression",
				"proposal", proposal.Id,
				"blockIndex", i,
				"anchorBlockNumber", proposalPayload.BlockPayloads[i].AnchorBlockNumber,
				"parentAnchorBlockNumber", parentAnchorBlockNumber,
			)
			proposalPayload.BlockPayloads[i].AnchorBlockNumber = parentAnchorBlockNumber
			continue
		}

		// 2. Future reference: manifest.blocks[i].anchorBlockNumber >= proposal.originBlockNumber - ANCHOR_MIN_OFFSET
		if proposalPayload.BlockPayloads[i].AnchorBlockNumber >= originBlockNumber-manifest.AnchorMinOffset {
			log.Info(
				"Invalid anchor block number: future reference",
				"proposal", proposal.Id,
				"blockIndex", i,
				"anchorBlockNumber", proposalPayload.BlockPayloads[i].AnchorBlockNumber,
				"originBlockNumber", originBlockNumber,
			)
			proposalPayload.BlockPayloads[i].AnchorBlockNumber = parentAnchorBlockNumber
			continue
		}

		// 3. Excessive lag: manifest.blocks[i].anchorBlockNumber < proposal.originBlockNumber - ANCHOR_MAX_OFFSET
		if originBlockNumber > manifest.AnchorMaxOffset &&
			proposalPayload.BlockPayloads[i].AnchorBlockNumber < originBlockNumber-manifest.AnchorMaxOffset {
			log.Info(
				"Invalid anchor block number: excessive lag",
				"proposal", proposal.Id,
				"blockIndex", i,
				"anchorBlockNumber", proposalPayload.BlockPayloads[i].AnchorBlockNumber,
				"minRequired", originBlockNumber-manifest.AnchorMaxOffset,
			)
			proposalPayload.BlockPayloads[i].AnchorBlockNumber = parentAnchorBlockNumber
			continue
		}

		if proposalPayload.BlockPayloads[i].AnchorBlockNumber > highestAnchorNumber {
			highestAnchorNumber = proposalPayload.BlockPayloads[i].AnchorBlockNumber
		}

		parentAnchorBlockNumber = proposalPayload.BlockPayloads[i].AnchorBlockNumber
	}

	// Forced inclusion protection: For non-forced proposals, if no blocks have valid anchor numbers greater than its
	// parent's, the entire manifest is replaced with the default manifest, penalizing proposals that fail to provide
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

// validateCoinbase ensures each block's coinbase is correctly assigned.
func validateCoinbase(
	proposalPayload *ShastaProposalPayload,
	proposal shastaBindings.IInboxProposal,
	isForcedInclusion bool,
) {
	for i := range proposalPayload.BlockPayloads {
		if isForcedInclusion {
			// Forced inclusions always use proposal.proposer
			proposalPayload.BlockPayloads[i].Coinbase = proposal.Proposer
		}

		if (proposalPayload.BlockPayloads[i].Coinbase == common.Address{}) {
			// Use proposal.proposer as fallback if manifest coinbase is zero
			proposalPayload.BlockPayloads[i].Coinbase = proposal.Proposer
		}
	}
}

// validateGasLimit ensures each block's gas limit is within valid bounds.
func validateGasLimit(
	proposalPayload *ShastaProposalPayload,
	parentBlockNumber *big.Int,
	parentGasLimit uint64,
) {
	// NOTE: When the parent block is not the genesis block, its gas limit always contains the Pacaya
	// or Shasta anchor transaction gas limit, which always equals to consensus.UpdateStateGasLimit.
	// Therefore, we need to subtract consensus.UpdateStateGasLimit from the parent gas limit to get
	// the real gas limit from parent block metadata.
	if parentBlockNumber.Cmp(common.Big0) != 0 {
		parentGasLimit = parentGasLimit - consensus.UpdateStateGasLimit
	}
	for i := range proposalPayload.BlockPayloads {
		lowerGasBound := max(
			parentGasLimit*(10000-manifest.MaxBlockGasLimitChangePermyriad)/10000,
			manifest.MinBlockGasLimit,
		)
		upperGasBound := parentGasLimit * (10000 + manifest.MaxBlockGasLimitChangePermyriad) / 10000

		if proposalPayload.BlockPayloads[i].GasLimit == 0 {
			// Inherit parent value.
			proposalPayload.BlockPayloads[i].GasLimit = parentGasLimit
			log.Info("Inheriting gas limit from parent", "blockIndex", i, "gasLimit", proposalPayload.BlockPayloads[i].GasLimit)
		}

		if proposalPayload.BlockPayloads[i].GasLimit < lowerGasBound {
			log.Info(
				"Clamping gas limit to lower bound",
				"blockIndex", i,
				"originalGasLimit", proposalPayload.BlockPayloads[i].GasLimit,
				"newGasLimit", lowerGasBound,
			)
			proposalPayload.BlockPayloads[i].GasLimit = lowerGasBound
		}
		if proposalPayload.BlockPayloads[i].GasLimit > upperGasBound {
			log.Info(
				"Clamping gas limit to upper bound",
				"blockIndex", i,
				"originalGasLimit", proposalPayload.BlockPayloads[i].GasLimit,
				"newGasLimit", upperGasBound,
			)
			proposalPayload.BlockPayloads[i].GasLimit = upperGasBound
		}

		parentGasLimit = proposalPayload.BlockPayloads[i].GasLimit
	}
}

// AssembleBondInstructions fetches and assembles bond instructions into the proposal manifest.
func AssembleBondInstructions(
	ctx context.Context,
	proposalID *big.Int,
	indexer *shastaIndexer.Indexer,
	proposalPayload *ShastaProposalPayload,
	parentBondInstructionsHash common.Hash,
	originBlockNumber uint64,
	derivationIdx int,
	rpc *rpc.Client,
) error {
	timeoutCtx, cancel := context.WithTimeout(ctx, defaultTimeout)
	defer cancel()

	// For an L2 block with a higher anchor block number than its parent, bond instructions must be processed within
	// its anchor transaction.
	for i := range proposalPayload.BlockPayloads {
		aggregatedHash := parentBondInstructionsHash
		if derivationIdx == 0 && i == 0 && proposalID.Uint64() > manifest.BondProcessingDelay {
			targetProposal, err := indexer.GetProposalByID(proposalID.Uint64() - manifest.BondProcessingDelay)
			if err != nil {
				return fmt.Errorf("failed to get target proposal: %w", err)
			}
			// Only checking bond instructions when there are new instructions.
			if parentBondInstructionsHash == targetProposal.CoreState.BondInstructionsHash {
				continue
			}
			start := targetProposal.RawBlockHeight.Uint64()
			proposedIter, err := rpc.ShastaClients.Inbox.FilterProposed(
				&bind.FilterOpts{Start: start, End: &start, Context: timeoutCtx},
			)
			if err != nil {
				return fmt.Errorf("failed to fetch Proposed events: %w", err)
			}
			// Aggregate bond instructions from the fetched events.
			for proposedIter.Next() {
				payload, err := rpc.DecodeProposedEventPayload(&bind.CallOpts{Context: timeoutCtx}, proposedIter.Event.Data)
				if err != nil {
					return fmt.Errorf("failed to decode Proposed event payload: %w", err)
				}
				// Skip unrelated proposals, should not happen, but just in case.
				if payload.Proposal.Id.Cmp(targetProposal.Proposal.Id) != 0 {
					log.Warn(
						"Skipping unrelated Proposed event",
						"eventHeight", start,
						"targetProposalID", targetProposal.Proposal.Id,
						"proposalID", payload.Proposal.Id,
					)
					continue
				}
				log.Info(
					"Processing Proposed event for bond instructions",
					"eventHeight", start,
					"parentBondInstructionsHash", parentBondInstructionsHash.Hex(),
					"currentBondInstructionsHash", common.Bytes2Hex(payload.CoreState.BondInstructionsHash[:]),
				)
				input, err := rpc.DecodeProposeInput(&bind.CallOpts{Context: timeoutCtx}, proposedIter.Event.Raw.Data)
				if err != nil {
					return fmt.Errorf("failed to decode Propose input: %w", err)
				}

			loop:
				for _, record := range input.TransitionRecords {
					for _, instruction := range record.BondInstructions {
						if aggregatedHash, err = encoding.CalculateBondInstructionHash(aggregatedHash, instruction); err != nil {
							return fmt.Errorf("failed to calculate bond instruction hash: %w", err)
						}
						log.Info(
							"New L2 bond instruction",
							"eventHeight", start,
							"proposalID", instruction.ProposalId,
							"type", instruction.BondType,
							"payee", instruction.Payee,
							"payer", instruction.Payer,
						)
						proposalPayload.BlockPayloads[i].BondInstructions = append(
							proposalPayload.BlockPayloads[i].BondInstructions,
							instruction,
						)
						if aggregatedHash == payload.CoreState.BondInstructionsHash {
							break loop
						}
					}
				}

				if aggregatedHash != payload.CoreState.BondInstructionsHash {
					return fmt.Errorf(
						"bond instructions hash mismatch: calculated %s, expected %s",
						aggregatedHash.Hex(),
						common.Bytes2Hex(payload.CoreState.BondInstructionsHash[:]),
					)
				}
			}
		}

		proposalPayload.BlockPayloads[i].BondInstructionsHash = aggregatedHash
		parentBondInstructionsHash = aggregatedHash
	}

	return nil
}
