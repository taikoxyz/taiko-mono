package manifest

import (
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/params"

	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

const (
	// Version number for Shasta payloads.
	ShastaPayloadVersion = 0x1
	// BlobBytes The maximum number of bytes in a blob.
	BlobBytes = params.BlobTxBytesPerFieldElement * params.BlobTxFieldElementsPerBlob
	// ProposalMaxBlocks The maximum number of blocks allowed in a proposal, refer to LibManifest.PROPOSAL_MAX_BLOCKS.
	ProposalMaxBlocks = 384
	// TimestampMaxOffset The maximum number timestamp offset from the proposal origin timestamp, refer to LibManifest.TIMESTAMP_MAX_OFFSET.
	TimestampMaxOffset = 12 * 32
	// AnchorMinOffset The minimum anchor block number offset from the proposal origin block number, refer to LibManifest.ANCHOR_MIN_OFFSET.
	AnchorMinOffset = 2
	// AnchorMaxOffset The maximum anchor block number offset from the proposal origin block number, refer to LibManifest.ANCHOR_MAX_OFFSET.
	AnchorMaxOffset = 128
	// MaxBlockGasLimitChangePermyriad The maximum block gas limit change per block, in millionths (1/1,000,000), refer to LibManifest.MAX_BLOCK_GAS_LIMIT_CHANGE_PERMYRIAD.
	MaxBlockGasLimitChangePermyriad = 10 // 0.1%
	// MinBlockGasLimit The minimum block gas limit, refer to LibManifest.MIN_BLOCK_GAS_LIMIT.
	MinBlockGasLimit = 15_000_000
)

// BlockManifest represents a block manifest
// Should be same with LibManifest.BlockManifest
type ProtocolBlockManifest struct {
	// The timestamp of the block
	Timestamp uint64 `json:"timestamp"`
	// The coinbase of the block
	Coinbase common.Address `json:"coinbase"`
	// The anchor block number. This field can be zero, if so, this block will use the
	// most recent anchor in a previous block
	AnchorBlockNumber uint64 `json:"anchorBlockNumber"`
	// The block's gas limit
	GasLimit uint64 `json:"gasLimit"`
	// The transactions for this block
	Transactions types.Transactions `json:"transactions"`
}

// BlockManifest represents a block manifest with extra information.
type BlockManifest struct {
	ProtocolBlockManifest
	// Extra information
	BondInstructionsHash common.Hash                              `json:"bondInstructionsHash"`
	BondInstructions     []shastaBindings.LibBondsBondInstruction `json:"bondInstructions"`
}

// ProtocolProposalManifest represents a proposal manifest
// Should be same with LibManifest.ProposalManifest
type ProtocolProposalManifest struct {
	ProverAuthBytes []byte                   `json:"proverAuthBytes"`
	Blocks          []*ProtocolBlockManifest `json:"blocks"`
}

// ProposalManifest represents a proposal manifest with extra information.
type ProposalManifest struct {
	ProverAuthBytes []byte           `json:"proverAuthBytes"`
	Blocks          []*BlockManifest `json:"blocks"`
	// Extra information
	Default           bool         `json:"default"`
	ParentBlock       *types.Block `json:"parentBlock"`
	IsLowBondProposal bool         `json:"isLowBondProposal"`
}
