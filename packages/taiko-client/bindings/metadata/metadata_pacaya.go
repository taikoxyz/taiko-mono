package metadata

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
)

// Ensure TaikoDataBlockMetadataPacaya implements TaikoBlockMetaData.
var _ TaikoProposalMetaData = (*TaikoDataBlockMetadataPacaya)(nil)

// TaikoDataBlockMetadataPacaya is the metadata of an Pacaya Taiko blocks batch.
type TaikoDataBlockMetadataPacaya struct {
	pacayaBindings.ITaikoInboxBatchInfo
	pacayaBindings.ITaikoInboxBatchMetadata
	types.Log
}

// NewTaikoDataBlockMetadataPacaya creates a new instance of TaikoDataBlockMetadataPacaya
// from the TaikoInbox.BatchProposed event.
func NewTaikoDataBlockMetadataPacaya(e *pacayaBindings.TaikoInboxClientBatchProposed) *TaikoDataBlockMetadataPacaya {
	return &TaikoDataBlockMetadataPacaya{
		ITaikoInboxBatchInfo:     e.Info,
		ITaikoInboxBatchMetadata: e.Meta,
		Log:                      e.Raw,
	}
}

// Pacaya implements TaikoProposalMetaData interface.
func (m *TaikoDataBlockMetadataPacaya) Pacaya() TaikoBatchMetaDataPacaya {
	return m
}

// IsPacaya implements TaikoProposalMetaData interface.
func (m *TaikoDataBlockMetadataPacaya) IsPacaya() bool {
	return true
}

// Shasta implements TaikoProposalMetaData interface.
func (m *TaikoDataBlockMetadataPacaya) Shasta() TaikoProposalMetaDataShasta {
	return nil
}

// IsShasta implements TaikoProposalMetaData interface.
func (m *TaikoDataBlockMetadataPacaya) IsShasta() bool {
	return false
}

// GetTxListHash returns the hash of calldata txlist.
func (m *TaikoDataBlockMetadataPacaya) GetTxListHash() common.Hash {
	return m.TxsHash
}

// GetExtraData returns block extradata.
func (m *TaikoDataBlockMetadataPacaya) GetExtraData() []byte {
	return m.ExtraData[:]
}

// GetCoinbase returns block coinbase.
func (m *TaikoDataBlockMetadataPacaya) GetCoinbase() common.Address {
	return m.Coinbase
}

// GetBatchID returns batch ID.
func (m *TaikoDataBlockMetadataPacaya) GetBatchID() *big.Int {
	return new(big.Int).SetUint64(m.BatchId)
}

// GetProposalID returns batch ID.
func (m *TaikoDataBlockMetadataPacaya) GetProposalID() *big.Int {
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

// GetBlobHashes returns blob hashes in this batch.
func (m *TaikoDataBlockMetadataPacaya) GetBlobHashes() []common.Hash {
	var blobHashes []common.Hash
	for _, hash := range m.BlobHashes {
		blobHashes = append(blobHashes, hash)
	}
	return blobHashes
}

// GetLastBlockID returns last block's ID in this batch.
func (m *TaikoDataBlockMetadataPacaya) GetLastBlockID() uint64 {
	return m.LastBlockId
}

// GetProposer returns the proposer of this batch.
func (m *TaikoDataBlockMetadataPacaya) GetProposer() common.Address {
	return m.Proposer
}

// GetProposedAt returns the proposing timestamp of this batch.
func (m *TaikoDataBlockMetadataPacaya) GetProposedAt() uint64 {
	return m.ProposedAt
}

// GetProposedIn returns the proposing L1 block number of this batch.
func (m *TaikoDataBlockMetadataPacaya) GetProposedIn() uint64 {
	return m.ProposedIn
}

// GetBlobCreatedIn returns the L1 block number when the blob created.
func (m *TaikoDataBlockMetadataPacaya) GetBlobCreatedIn() *big.Int {
	return new(big.Int).SetUint64(m.BlobCreatedIn)
}

// GetTxListOffset returns calldata tx list offset.
func (m *TaikoDataBlockMetadataPacaya) GetTxListOffset() uint32 {
	return m.BlobByteOffset
}

// GetTxListSize returns calldata tx list size.
func (m *TaikoDataBlockMetadataPacaya) GetTxListSize() uint32 {
	return m.BlobByteSize
}

// GetAnchorBlockID returns the anchor block ID.
func (m *TaikoDataBlockMetadataPacaya) GetAnchorBlockID() uint64 {
	return m.AnchorBlockId
}

// GetAnchorBlockHash returns the anchor block hash.
func (m *TaikoDataBlockMetadataPacaya) GetAnchorBlockHash() common.Hash {
	return m.AnchorBlockHash
}

// GetBlocks returns block params of this batch.
func (m *TaikoDataBlockMetadataPacaya) GetBlocks() []pacayaBindings.ITaikoInboxBlockParams {
	return m.Blocks
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
func (m *TaikoDataBlockMetadataPacaya) InnerMetadata() *pacayaBindings.ITaikoInboxBatchMetadata {
	return &m.ITaikoInboxBatchMetadata
}
