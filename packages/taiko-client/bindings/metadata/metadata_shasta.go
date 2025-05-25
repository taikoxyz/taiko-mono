package metadata

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/core/types"
	bindingTypes "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding/binding_types"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

// Ensure TaikoDataBlockMetadataShasta implements TaikoBlockMetaData.
var _ TaikoProposalMetaData = (*TaikoDataBlockMetadataShasta)(nil)

// TaikoDataBlockMetadataShasta is the metadata of an Shasta Taiko blocks batch.
type TaikoDataBlockMetadataShasta struct {
	shastaBindings.ITaikoInboxBatchInfo
	shastaBindings.ITaikoInboxBatchMetadata
	types.Log
}

// NewTaikoDataBlockMetadataShasta creates a new instance of TaikoDataBlockMetadataShasta
// from the TaikoInbox.BatchProposed event.
func NewTaikoDataBlockMetadataShasta(e *shastaBindings.TaikoInboxClientBatchProposed) *TaikoDataBlockMetadataShasta {
	return &TaikoDataBlockMetadataShasta{
		ITaikoInboxBatchInfo:     e.Info,
		ITaikoInboxBatchMetadata: e.Meta,
		Log:                      e.Raw,
	}
}

// Pacaya implements TaikoProposalMetaData interface.
func (m *TaikoDataBlockMetadataShasta) Pacaya() TaikoBatchMetaDataPacaya {
	return nil
}

// IsPacaya implements TaikoProposalMetaData interface.
func (m *TaikoDataBlockMetadataShasta) IsPacaya() bool {
	return false
}

// Pacaya implements TaikoProposalMetaData interface.
func (m *TaikoDataBlockMetadataShasta) Shasta() TaikoBatchMetaDataShasta {
	return m
}

// IsPacaya implements TaikoProposalMetaData interface.
func (m *TaikoDataBlockMetadataShasta) IsShasta() bool {
	return true
}

// GetTxListHash returns the hash of calldata txlist.
func (m *TaikoDataBlockMetadataShasta) GetTxListHash() common.Hash {
	return m.TxsHash
}

// GetBlocks returns the blocks parameters in this batch.
func (m *TaikoDataBlockMetadataShasta) GetBlocks() []bindingTypes.BlockParams {
	var params []bindingTypes.BlockParams
	for _, b := range m.Blocks {
		params = append(params, *bindingTypes.NewBlockParams(b.NumTransactions, b.TimeShift, b.SignalSlots))
	}
	return params
}

// GetBlobHashes returns blob hashes in this batch.
func (m *TaikoDataBlockMetadataShasta) GetBlobHashes() []common.Hash {
	var blobHashes []common.Hash
	for _, hash := range m.BlobHashes {
		blobHashes = append(blobHashes, hash)
	}
	return blobHashes
}

// GetExtraData returns block extradata.
func (m *TaikoDataBlockMetadataShasta) GetExtraData() []byte {
	return m.ExtraData[:]
}

// GetCoinbase returns block coinbase.
func (m *TaikoDataBlockMetadataShasta) GetCoinbase() common.Address {
	return m.Coinbase
}

// GetProposer returns the proposer of this batch.
func (m *TaikoDataBlockMetadataShasta) GetProposer() common.Address {
	return m.Proposer
}

// GetProposedIn returns the proposing L1 block number of this batch.
func (m *TaikoDataBlockMetadataShasta) GetProposedIn() uint64 {
	return m.ProposedIn
}

// GetBlobCreatedIn returns the L1 block number when the blob created.
func (m *TaikoDataBlockMetadataShasta) GetBlobCreatedIn() *big.Int {
	return new(big.Int).SetUint64(m.BlobCreatedIn)
}

// GetTxListOffset returns the offset of the blob in the batch.
func (m *TaikoDataBlockMetadataShasta) GetTxListOffset() uint32 {
	return m.BlobByteOffset
}

// GetTxListSize returns the size of the blob in the batch.
func (m *TaikoDataBlockMetadataShasta) GetTxListSize() uint32 {
	return m.BlobByteSize
}

// GetGasLimit returns gas limit of each L2 block.
func (m *TaikoDataBlockMetadataShasta) GetGasLimit() uint32 {
	return m.GasLimit
}

// GetLastBlockID returns last block's ID in this batch.
func (m *TaikoDataBlockMetadataShasta) GetLastBlockID() uint64 {
	return m.LastBlockId
}

// GetLastBlockTimestamp returns last block's timestamp in this batch.
func (m *TaikoDataBlockMetadataShasta) GetLastBlockTimestamp() uint64 {
	return m.LastBlockTimestamp
}

// GetAnchorBlockID returns the anchor block ID of this batch.
func (m *TaikoDataBlockMetadataShasta) GetAnchorBlockID() uint64 {
	return m.AnchorBlockId
}

// GetAnchorBlockHash returns the anchor block hash of this batch.
func (m *TaikoDataBlockMetadataShasta) GetAnchorBlockHash() common.Hash {
	return m.AnchorBlockHash
}

// GetBaseFeeConfig returns the base fee config of this batch.
func (m *TaikoDataBlockMetadataShasta) GetBaseFeeConfig() bindingTypes.LibSharedDataBaseFeeConfig {
	return bindingTypes.NewBaseFeeConfigShasta(&m.BaseFeeConfig, core.DecodeExtraData(m.ExtraData[:]))
}

// GetBatchID returns the batch ID of this batch.
func (m *TaikoDataBlockMetadataShasta) GetBatchID() *big.Int {
	return new(big.Int).SetUint64(m.BatchId)
}

// GetProposedAt returns the proposing timestamp of this batch.
func (m *TaikoDataBlockMetadataShasta) GetProposedAt() uint64 {
	return m.ProposedAt
}

// GetRawBlockHeight returns the raw block height of this batch.
func (m *TaikoDataBlockMetadataShasta) GetRawBlockHeight() *big.Int {
	return new(big.Int).SetUint64(m.BlockNumber)
}

// GetRawBlockHash returns the raw block hash of this batch.
func (m *TaikoDataBlockMetadataShasta) GetRawBlockHash() common.Hash {
	return m.BlockHash
}

// GetTxIndex returns the transaction index of this batch.
func (m *TaikoDataBlockMetadataShasta) GetTxIndex() uint {
	return m.TxIndex
}

// GetTxHash returns the transaction hash of this batch.
func (m *TaikoDataBlockMetadataShasta) GetTxHash() common.Hash {
	return m.TxHash
}

// InnerMetadata returns the inner metadata of this batch.
func (m *TaikoDataBlockMetadataShasta) InnerMetadata() *shastaBindings.ITaikoInboxBatchMetadata {
	return &m.ITaikoInboxBatchMetadata
}
