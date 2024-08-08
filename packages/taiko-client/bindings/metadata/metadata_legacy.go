package metadata

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
)

// Ensure TaikoDataBlockMetadataLegacy implements TaikoBlockMetaData.
var _ TaikoBlockMetaData = (*TaikoDataBlockMetadataLegacy)(nil)

// TaikoDataBlockMetadataLegacy is the metadata of a legacy Taiko block.
type TaikoDataBlockMetadataLegacy struct {
	bindings.TaikoDataBlockMetadata
	types.Log
	assignedProver common.Address
	livenessBond   *big.Int
}

// NewTaikoDataBlockMetadataLegacy creates a new instance of TaikoDataBlockMetadataLegacy
// from the TaikoL1.BlockProposed event.
func NewTaikoDataBlockMetadataLegacy(e *bindings.LibProposingBlockProposed) *TaikoDataBlockMetadataLegacy {
	return &TaikoDataBlockMetadataLegacy{
		TaikoDataBlockMetadata: e.Meta,
		Log:                    e.Raw,
		assignedProver:         e.AssignedProver,
		livenessBond:           e.LivenessBond,
	}
}

// GetAnchorBlockHash returns the anchor block hash.
func (m *TaikoDataBlockMetadataLegacy) GetAnchorBlockHash() common.Hash {
	return m.L1Hash
}

// GetDifficulty returns the difficulty.
func (m *TaikoDataBlockMetadataLegacy) GetDifficulty() common.Hash {
	return m.Difficulty
}

// GetBlobHash returns the blob hash.
func (m *TaikoDataBlockMetadataLegacy) GetBlobHash() common.Hash {
	return m.BlobHash
}

// GetExtraData returns the extra data.
func (m *TaikoDataBlockMetadataLegacy) GetExtraData() []byte {
	return m.ExtraData[:]
}

// GetCoinbase returns the coinbase.
func (m *TaikoDataBlockMetadataLegacy) GetCoinbase() common.Address {
	return m.Coinbase
}

// GetBlockID returns the L2 block ID.
func (m *TaikoDataBlockMetadataLegacy) GetBlockID() *big.Int {
	return new(big.Int).SetUint64(m.Id)
}

// GetGasLimit returns the gas limit.
func (m *TaikoDataBlockMetadataLegacy) GetGasLimit() uint32 {
	return m.GasLimit
}

// GetTimestamp returns the timestamp.
func (m *TaikoDataBlockMetadataLegacy) GetTimestamp() uint64 {
	return m.Timestamp
}

// GetAnchorBlockID returns the L1 block number which should be used in anchor transaction.
func (m *TaikoDataBlockMetadataLegacy) GetAnchorBlockID() uint64 {
	return m.L1Height
}

// GetMinTier returns the minimum tier.
func (m *TaikoDataBlockMetadataLegacy) GetMinTier() uint16 {
	return m.MinTier
}

// GetBlobUsed returns whether the blob is used.
func (m *TaikoDataBlockMetadataLegacy) GetBlobUsed() bool {
	return m.BlobUsed
}

// GetParentMetaHash returns the parent meta hash.
func (m *TaikoDataBlockMetadataLegacy) GetParentMetaHash() common.Hash {
	return m.ParentMetaHash
}

// GetProposer returns the proposer address.
func (m *TaikoDataBlockMetadataLegacy) GetProposer() common.Address {
	return m.Sender
}

// GetAssignedProver returns the assigned prover address, right now
// this address should be equal to the proposer address.
func (m *TaikoDataBlockMetadataLegacy) GetAssignedProver() common.Address {
	return m.assignedProver
}

// GetLivenessBond returns the liveness bond.
func (m *TaikoDataBlockMetadataLegacy) GetLivenessBond() *big.Int {
	return m.livenessBond
}

// GetProposedAt returns the proposedAt timestamp.
func (m *TaikoDataBlockMetadataLegacy) GetProposedAt() uint64 {
	return m.Timestamp
}

// GetProposedIn returns the proposedIn block number.
func (m *TaikoDataBlockMetadataLegacy) GetProposedIn() uint64 {
	return m.BlockNumber
}

// GetBlobTxListOffset returns the blob tx list offset.
func (m *TaikoDataBlockMetadataLegacy) GetBlobTxListOffset() uint32 {
	return 0
}

// GetBlobTxListLength returns the blob tx list length.
func (m *TaikoDataBlockMetadataLegacy) GetBlobTxListLength() uint32 {
	return 0
}

// GetBlobIndex returns the blob index.
func (m *TaikoDataBlockMetadataLegacy) GetBlobIndex() uint8 {
	return 0
}

// GetBasefeeAdjustmentQuotient returns the L2 block basefee adjustment quotient.
func (m *TaikoDataBlockMetadataLegacy) GetBasefeeAdjustmentQuotient() uint8 {
	return 0
}

// GetGasIssuancePerSecond returns the L2 block gas issuance per second.
func (m *TaikoDataBlockMetadataLegacy) GetGasIssuancePerSecond() uint32 {
	return 0
}

// GetRawBlockHeight returns the raw L1 block height.
func (m *TaikoDataBlockMetadataLegacy) GetRawBlockHeight() *big.Int {
	return new(big.Int).SetUint64(m.BlockNumber)
}

// GetRawBlockHash returns the raw L1 block hash.
func (m *TaikoDataBlockMetadataLegacy) GetRawBlockHash() common.Hash {
	return m.BlockHash
}

// GetTxIndex returns the transaction index.
func (m *TaikoDataBlockMetadataLegacy) GetTxIndex() uint {
	return m.Log.TxIndex
}

// GetTxHash returns the transaction hash.
func (m *TaikoDataBlockMetadataLegacy) GetTxHash() common.Hash {
	return m.Log.TxHash
}

// IsOntakeBlock returns whether the block is an Ontake block.
func (m *TaikoDataBlockMetadataLegacy) IsOntakeBlock() bool {
	return false
}

// InnerMetadata returns the inner metadata.
func (m *TaikoDataBlockMetadataLegacy) InnerMetadata() *bindings.TaikoDataBlockMetadata {
	return &m.TaikoDataBlockMetadata
}
