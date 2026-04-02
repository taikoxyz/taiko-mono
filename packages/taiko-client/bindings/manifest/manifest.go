package manifest

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/params"
)

const (
	// Version number for Shasta payloads.
	ShastaPayloadVersion = 0x1
	// BlobBytes The maximum number of bytes in a blob.
	BlobBytes = params.BlobTxBytesPerFieldElement * params.BlobTxFieldElementsPerBlob
	// ProposalMaxBlocks The maximum number of blocks allowed in a proposal.
	ProposalMaxBlocks = 192
	// AnchorMaxOffset The maximum anchor block number offset from the proposal origin block number on Hoodi.
	AnchorMaxOffset = uint64(128)
	// MainnetAnchorMaxOffset The maximum anchor block number offset from the proposal origin block number on mainnet.
	MainnetAnchorMaxOffset = uint64(512)
	// TimestampMaxOffset The maximum timestamp offset from the proposal origin timestamp on Hoodi.
	TimestampMaxOffset = uint64(12) * AnchorMaxOffset
	// MainnetTimestampMaxOffset The maximum timestamp offset from the proposal origin timestamp on mainnet.
	MainnetTimestampMaxOffset = uint64(12) * MainnetAnchorMaxOffset
	// MaxBlockGasLimitMaxChange The maximum block gas limit change per block,
	// expressed in millionths (1/1,000,000).
	MaxBlockGasLimitMaxChange = 200 // 0.02%
	// GasLimitChangeDenominator Denominator used when clamping gas limits (parts per million).
	GasLimitChangeDenominator = 1_000_000
	// MinBlockGasLimit The minimum block gas limit.
	MinBlockGasLimit = 10_000_000
	// MaxBlockGasLimit The maximum block gas limit.
	MaxBlockGasLimit = 45_000_000
	// MainnetAnchorCheckSkipProposalOffset is the proposal offset after which anchor checks can be skipped on mainnet.
	MainnetAnchorCheckSkipProposalOffset = uint64(7)
)

// BlockManifest represents the blocks inside a derivation source.
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
type DerivationSourceManifest struct {
	Blocks []*BlockManifest `json:"blocks"`
}

// AnchorMaxOffsetByChainID returns the maximum anchor offset based on chainID.
func AnchorMaxOffsetByChainID(chainID *big.Int) uint64 {
	if chainID != nil && chainID.Cmp(params.TaikoMainnetNetworkID) == 0 {
		return MainnetAnchorMaxOffset
	}

	return AnchorMaxOffset
}

// TimestampMaxOffsetByChainID returns the maximum timestamp offset based on chainID.
func TimestampMaxOffsetByChainID(chainID *big.Int) uint64 {
	if chainID != nil && chainID.Cmp(params.TaikoMainnetNetworkID) == 0 {
		return MainnetTimestampMaxOffset
	}

	return TimestampMaxOffset
}
