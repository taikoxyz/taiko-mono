package manifest

import (
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/params"
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
	// AnchorMinOffset The minimum anchor block number offset from the proposal origin block number, refer to LibManifest.MIN_ANCHOR_OFFSET.
	AnchorMinOffset = 2
	// AnchorMaxOffset The maximum anchor block number offset from the proposal origin block number, refer to LibManifest.MAX_ANCHOR_OFFSET.
	AnchorMaxOffset = 128
	// MaxBlockGasLimitChangePermyriad The maximum block gas limit change per block, in millionths (1/1,000,000), refer to LibManifest.MAX_BLOCK_GAS_LIMIT_CHANGE_PERMYRIAD.
	MaxBlockGasLimitChangePermyriad = 10 // 0.1%
	// MinBlockGasLimit The minimum block gas limit, refer to LibManifest.MIN_BLOCK_GAS_LIMIT.
	MinBlockGasLimit = 10_000_000
	// MaxBlockGasLimit The maximum block gas limit, refer to LibManifest.MAX_BLOCK_GAS_LIMIT.
	MaxBlockGasLimit = 100_000_000
	// The delay in processing bond instructions relative to the current proposal. A value
	// of 1 signifies that the bond instructions of the immediate parent proposal will be
	// processed.
	BondProcessingDelay = 6
)

// BlockManifest represents the blocks inside a derivation source.
// Should be same with LibManifest.BlockManifest.
type BlockManifest struct {
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

// DerivationSourceManifest represents a derivation source manifest containing blocks for one source.
// Should be same with LibManifest.DerivationSourceManifest.
type DerivationSourceManifest struct {
	ProverAuthBytes []byte           `json:"proverAuthBytes"`
	Blocks          []*BlockManifest `json:"blocks"`
}
