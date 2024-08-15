package metadata

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
)

// Ensure TaikoDataBlockMetadataOntake implements TaikoBlockMetaData.
var _ TaikoBlockMetaData = (*TaikoDataBlockMetadataOntake)(nil)

// TaikoDataBlockMetadataOntake is the metadata of an ontake Taiko block.
type TaikoDataBlockMetadataOntake struct {
	bindings.TaikoDataBlockMetadataV2
	types.Log
}

// NewTaikoDataBlockMetadataOntake creates a new instance of TaikoDataBlockMetadataOntake
// from the TaikoL1.BlockProposedV2 event.
func NewTaikoDataBlockMetadataOntake(e *bindings.LibProposingBlockProposedV2) *TaikoDataBlockMetadataOntake {
	return &TaikoDataBlockMetadataOntake{
		TaikoDataBlockMetadataV2: e.Meta,
		Log:                      e.Raw,
	}
}

// GetAnchorBlockHash returns the anchor block hash.
func (m *TaikoDataBlockMetadataOntake) GetAnchorBlockHash() common.Hash {
	return m.AnchorBlockHash
}

// GetDifficulty returns the difficulty.
func (m *TaikoDataBlockMetadataOntake) GetDifficulty() common.Hash {
	return m.Difficulty
}

// GetBlobHash returns the blob hash.
func (m *TaikoDataBlockMetadataOntake) GetBlobHash() common.Hash {
	return m.BlobHash
}

// GetExtraData returns the extra data.
func (m *TaikoDataBlockMetadataOntake) GetExtraData() []byte {
	return m.ExtraData[:]
}

// GetCoinbase returns the coinbase.
func (m *TaikoDataBlockMetadataOntake) GetCoinbase() common.Address {
	return m.Coinbase
}

// GetBlockID returns the L2 block ID.
func (m *TaikoDataBlockMetadataOntake) GetBlockID() *big.Int {
	return new(big.Int).SetUint64(m.Id)
}

// GetGasLimit returns the gas limit.
func (m *TaikoDataBlockMetadataOntake) GetGasLimit() uint32 {
	return m.GasLimit
}

// GetTimestamp returns the timestamp.
func (m *TaikoDataBlockMetadataOntake) GetTimestamp() uint64 {
	return m.Timestamp
}

// GetAnchorBlockID returns the L1 block number which should be used in anchor transaction.
func (m *TaikoDataBlockMetadataOntake) GetAnchorBlockID() uint64 {
	return m.AnchorBlockId
}

// GetMinTier returns the minimum tier.
func (m *TaikoDataBlockMetadataOntake) GetMinTier() uint16 {
	return m.MinTier
}

// GetBlobUsed returns whether the blob is used.
func (m *TaikoDataBlockMetadataOntake) GetBlobUsed() bool {
	return m.BlobUsed
}

// GetParentMetaHash returns the parent meta hash.
func (m *TaikoDataBlockMetadataOntake) GetParentMetaHash() common.Hash {
	return m.ParentMetaHash
}

// GetProposer returns the proposer address.
func (m *TaikoDataBlockMetadataOntake) GetProposer() common.Address {
	return m.Proposer
}

// GetAssignedProver returns the assigned prover address, right now
// this address should be equal to the proposer address.
func (m *TaikoDataBlockMetadataOntake) GetAssignedProver() common.Address {
	return m.Proposer
}

// GetLivenessBond returns the liveness bond.
func (m *TaikoDataBlockMetadataOntake) GetLivenessBond() *big.Int {
	return m.LivenessBond
}

// GetProposedAt returns the proposedAt timestamp.
func (m *TaikoDataBlockMetadataOntake) GetProposedAt() uint64 {
	return m.ProposedAt
}

// GetProposedIn returns the proposedIn block number.
func (m *TaikoDataBlockMetadataOntake) GetProposedIn() uint64 {
	return m.ProposedIn
}

// GetBlobTxListOffset returns the blob tx list offset.
func (m *TaikoDataBlockMetadataOntake) GetBlobTxListOffset() uint32 {
	return m.BlobTxListOffset
}

// GetBlobTxListLength returns the blob tx list length.
func (m *TaikoDataBlockMetadataOntake) GetBlobTxListLength() uint32 {
	return m.BlobTxListLength
}

// GetBlobIndex returns the blob index.
func (m *TaikoDataBlockMetadataOntake) GetBlobIndex() uint8 {
	return m.BlobIndex
}

// GetBaseFeeConfig returns the L2 block basefee configs.
func (m *TaikoDataBlockMetadataOntake) GetBaseFeeConfig() *bindings.TaikoDataBaseFeeConfig {
	return &m.BaseFeeConfig
}

// GetRawBlockHeight returns the raw L1 block height.
func (m *TaikoDataBlockMetadataOntake) GetRawBlockHeight() *big.Int {
	return new(big.Int).SetUint64(m.BlockNumber)
}

// GetRawBlockHash returns the raw L1 block hash.
func (m *TaikoDataBlockMetadataOntake) GetRawBlockHash() common.Hash {
	return m.BlockHash
}

// GetTxIndex returns the transaction index.
func (m *TaikoDataBlockMetadataOntake) GetTxIndex() uint {
	return m.Log.TxIndex
}

// GetTxHash returns the transaction hash.
func (m *TaikoDataBlockMetadataOntake) GetTxHash() common.Hash {
	return m.Log.TxHash
}

// IsOntakeBlock returns whether the block is an ontake block.
func (m *TaikoDataBlockMetadataOntake) IsOntakeBlock() bool {
	return true
}

// InnerMetadata returns the inner metadata.
func (m *TaikoDataBlockMetadataOntake) InnerMetadata() *bindings.TaikoDataBlockMetadataV2 {
	return &m.TaikoDataBlockMetadataV2
}
