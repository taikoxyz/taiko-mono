package metadata

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	ontakeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/ontake"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
)

// Ensure TaikoDataBlockMetadataPacaya implements TaikoBlockMetaData.
var _ TaikoBlockMetaData = (*TaikoDataBlockMetadataPacaya)(nil)

// TaikoDataBlockMetadataPacaya is the metadata of an ontake Taiko block.
type TaikoDataBlockMetadataPacaya struct {
	pacayaBindings.ITaikoInboxBatchMetadata
	types.Log
}

// NewTaikoDataBlockMetadataPacaya creates a new instance of TaikoDataBlockMetadataPacaya
// from the TaikoL1.BlockProposedV2 event.
func NewTaikoDataBlockMetadataPacaya(e *pacayaBindings.TaikoInboxClientBatchProposed) *TaikoDataBlockMetadataPacaya {
	return &TaikoDataBlockMetadataPacaya{
		ITaikoInboxBatchMetadata: e.Meta,
		Log:                      e.Raw,
	}
}

// GetAnchorBlockHash returns the anchor block hash.
func (m *TaikoDataBlockMetadataPacaya) GetAnchorBlockHash() common.Hash {
	return m.AnchorBlockHash
}

// GetDifficulty returns the difficulty.
func (m *TaikoDataBlockMetadataPacaya) GetDifficulty() common.Hash {
	return common.Hash{} // TODO: implement the calculation of difficulty.
}

// GetBlobHash returns the blob hash.
func (m *TaikoDataBlockMetadataPacaya) GetBlobHash() common.Hash {
	return m.BlockHash
}

// GetExtraData returns the extra data.
func (m *TaikoDataBlockMetadataPacaya) GetExtraData() []byte {
	return m.ExtraData[:]
}

// GetCoinbase returns the coinbase.
func (m *TaikoDataBlockMetadataPacaya) GetCoinbase() common.Address {
	return m.Coinbase
}

// GetBlockID returns the L2 block ID.
func (m *TaikoDataBlockMetadataPacaya) GetBlockID() *big.Int {
	return new(big.Int).SetUint64(m.BatchId)
}

// GetGasLimit returns the gas limit.
func (m *TaikoDataBlockMetadataPacaya) GetGasLimit() uint32 {
	return m.GasLimit
}

// GetTimestamp returns the timestamp.
func (m *TaikoDataBlockMetadataPacaya) GetTimestamp() uint64 {
	return m.LastBlockTimestamp
}

// GetAnchorBlockID returns the L1 block number which should be used in anchor transaction.
func (m *TaikoDataBlockMetadataPacaya) GetAnchorBlockID() uint64 {
	return m.AnchorBlockId
}

// GetMinTier returns the minimum tier.
func (m *TaikoDataBlockMetadataPacaya) GetMinTier() uint16 {
	return 0
}

// GetBlobUsed returns whether the blob is used.
func (m *TaikoDataBlockMetadataPacaya) GetBlobUsed() bool {
	return m.NumBlobs != 0
}

// GetParentMetaHash returns the parent meta hash.
func (m *TaikoDataBlockMetadataPacaya) GetParentMetaHash() common.Hash {
	return m.ParentMetaHash
}

// GetProposer returns the proposer address.
func (m *TaikoDataBlockMetadataPacaya) GetProposer() common.Address {
	return m.Proposer
}

// GetAssignedProver returns the assigned prover address, right now
// this address should be equal to the proposer address.
func (m *TaikoDataBlockMetadataPacaya) GetAssignedProver() common.Address {
	return m.Proposer
}

// GetLivenessBond returns the liveness bond.
func (m *TaikoDataBlockMetadataPacaya) GetLivenessBond() *big.Int {
	return m.LivenessBond
}

// GetProposedAt returns the proposedAt timestamp.
func (m *TaikoDataBlockMetadataPacaya) GetProposedAt() uint64 {
	return m.ProposedAt
}

// GetProposedIn returns the proposedIn block number.
func (m *TaikoDataBlockMetadataPacaya) GetProposedIn() uint64 {
	return m.ProposedIn
}

// GetBlobTxListOffset returns the blob tx list offset.
func (m *TaikoDataBlockMetadataPacaya) GetBlobTxListOffset() uint32 {
	return 0
}

// GetBlobTxListLength returns the blob tx list length.
func (m *TaikoDataBlockMetadataPacaya) GetBlobTxListLength() uint32 {
	return 0
}

// GetBlobIndex returns the blob index.
func (m *TaikoDataBlockMetadataPacaya) GetBlobIndex() uint8 {
	return 0
}

// GetBaseFeeConfig returns the L2 block basefee configs.
func (m *TaikoDataBlockMetadataPacaya) GetBaseFeeConfig() *ontakeBindings.LibSharedDataBaseFeeConfig {
	return nil
}

// GetRawBlockHeight returns the raw L1 block height.
func (m *TaikoDataBlockMetadataPacaya) GetRawBlockHeight() *big.Int {
	return new(big.Int).SetUint64(m.BlockNumber)
}

// GetRawBlockHash returns the raw L1 block hash.
func (m *TaikoDataBlockMetadataPacaya) GetRawBlockHash() common.Hash {
	return m.BlockHash
}

// GetTxIndex returns the transaction index.
func (m *TaikoDataBlockMetadataPacaya) GetTxIndex() uint {
	return m.Log.TxIndex
}

// GetTxHash returns the transaction hash.
func (m *TaikoDataBlockMetadataPacaya) GetTxHash() common.Hash {
	return m.Log.TxHash
}

// IsOntakeBlock returns whether the block is an ontake block.
func (m *TaikoDataBlockMetadataPacaya) IsOntakeBlock() bool {
	return true
}

// InnerMetadata returns the inner metadata.
func (m *TaikoDataBlockMetadataPacaya) InnerMetadata() *ontakeBindings.TaikoDataBlockMetadataV2 {
	return nil
}
