package metadata

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	ontakeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/ontake"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
)

// Ensure TaikoDataBlockMetadataPacaya implements TaikoBlockMetaData.
var _ TaikoProposalMetaData = (*TaikoDataBlockMetadataPacaya)(nil)

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

// TaikoBlockMetaDataOntake implemnts TaikoProposalMetaData interface.
func (m *TaikoDataBlockMetadataPacaya) TaikoBlockMetaDataOntake() TaikoBlockMetaDataOntake {
	return nil
}

// TaikoBatchMetaDataPacaya implemnts TaikoProposalMetaData interface.
func (m *TaikoDataBlockMetadataPacaya) TaikoBatchMetaDataPacaya() TaikoBatchMetaDataPacaya {
	return m
}

// IsPacaya implemnts TaikoProposalMetaData interface.
func (m *TaikoDataBlockMetadataPacaya) IsPacaya() bool {
	return true
}

// GetTxListHash returns the hash of calldata txlist.
func (m *TaikoDataBlockMetadataPacaya) GetTxListHash() common.Hash {
	return m.TxListHash
}

// GetTxListHash returns block extradata.
func (m *TaikoDataBlockMetadataPacaya) GetExtraData() []byte {
	return m.ExtraData[:]
}

// GetCoinbase returns block coinbase.
func (m *TaikoDataBlockMetadataPacaya) GetCoinbase() common.Address {
	return m.Coinbase
}

// GetTxListHash returns batch ID.
func (m *TaikoDataBlockMetadataPacaya) GetBatchID() *big.Int {
	return new(big.Int).SetUint64(m.BatchId)
}

// GetGasLimit returns gas limit of each L2 block.
func (m *TaikoDataBlockMetadataPacaya) GetGasLimit() uint32 {
	return m.GasLimit
}

// GetLastBlockTimestamp returns last block's timestamp in this batch.
func (m *TaikoDataBlockMetadataPacaya) GetLastBlockTimestamp() uint64 {
	return m.LastBlockTimestamp
}

// GetLastBlockTimestamp returns last block's timestamp in this batch.
func (m *TaikoDataBlockMetadataPacaya) GetParentMetaHash() common.Hash {
	return m.ParentMetaHash
}

// GetProposer returns the proposer of this batch.
func (m *TaikoDataBlockMetadataPacaya) GetProposer() common.Address {
	return m.Proposer
}

// GetLivenessBond returns the livenessBond of this batch.
func (m *TaikoDataBlockMetadataPacaya) GetLivenessBond() *big.Int {
	return m.LivenessBond
}

// GetProposedAt returns the proposing timestamp of this batch.
func (m *TaikoDataBlockMetadataPacaya) GetProposedAt() uint64 {
	return m.ProposedAt
}

// ProposedIn returns the proposing L1 block number of this batch.
func (m *TaikoDataBlockMetadataPacaya) GetProposedIn() uint64 {
	return m.ProposedIn
}

// GetTxListOffset returns calldata tx list offset.
func (m *TaikoDataBlockMetadataPacaya) GetTxListOffset() uint32 {
	return m.TxListOffset
}

// GetTxListSize returns calldata tx list size.
func (m *TaikoDataBlockMetadataPacaya) GetTxListSize() uint32 {
	return m.TxListSize
}

// GetFirstBlobIndex returns the index of the first blob of this batch.
func (m *TaikoDataBlockMetadataPacaya) GetFirstBlobIndex() uint8 {
	return m.FirstBlobIndex
}

// GetNumBlobs returns the number of the used blobs.
func (m *TaikoDataBlockMetadataPacaya) GetNumBlobs() uint8 {
	return m.NumBlobs
}

// GetAnchorBlockID returns the anchor block ID.
func (m *TaikoDataBlockMetadataPacaya) GetAnchorBlockID() uint64 {
	return m.AnchorBlockId
}

// GetAnchorBlockHash returns the anchor block hash.
func (m *TaikoDataBlockMetadataPacaya) GetAnchorBlockHash() common.Hash {
	return m.AnchorBlockHash
}

// GetSignalSlots returns the signal slots.
func (m *TaikoDataBlockMetadataPacaya) GetSignalSlots() [][32]byte {
	return m.SignalSlots
}

// GetBlocks returns block params of this batch.
func (m *TaikoDataBlockMetadataPacaya) GetBlocks() []pacayaBindings.ITaikoInboxBlockParams {
	return m.Blocks
}

// GetAnchorInput returns the input of the anchor transaction.
func (m *TaikoDataBlockMetadataPacaya) GetAnchorInput() [32]byte {
	return m.AnchorInput
}

// GetBaseFeeConfig returns the L2 block basefee configs.
func (m *TaikoDataBlockMetadataPacaya) GetBaseFeeConfig() *pacayaBindings.LibSharedDataBaseFeeConfig {
	return &m.BaseFeeConfig
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
