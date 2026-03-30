package metadata

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	realtimeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/realtime"
)

// Ensure TaikoProposalMetadataRealTime implements TaikoProposalMetaData.
var _ TaikoProposalMetaData = (*TaikoProposalMetadataRealTime)(nil)

// TaikoProposalMetadataRealTime is the metadata of a RealTime proposal.
type TaikoProposalMetadataRealTime struct {
	*realtimeBindings.RealTimeInboxClientProposedAndProved
	timestamp uint64
}

// NewTaikoProposalMetadataRealTime creates a new instance.
func NewTaikoProposalMetadataRealTime(
	e *realtimeBindings.RealTimeInboxClientProposedAndProved,
	timestamp uint64,
) *TaikoProposalMetadataRealTime {
	return &TaikoProposalMetadataRealTime{
		RealTimeInboxClientProposedAndProved: e,
		timestamp: timestamp,
	}
}

// Pacaya implements TaikoProposalMetaData interface.
func (m *TaikoProposalMetadataRealTime) Pacaya() TaikoBatchMetaDataPacaya { return nil }

// IsPacaya implements TaikoProposalMetaData interface.
func (m *TaikoProposalMetadataRealTime) IsPacaya() bool { return false }

// Shasta implements TaikoProposalMetaData interface.
func (m *TaikoProposalMetadataRealTime) Shasta() TaikoProposalMetaDataShasta { return nil }

// IsShasta implements TaikoProposalMetaData interface.
func (m *TaikoProposalMetadataRealTime) IsShasta() bool { return false }

// RealTime implements TaikoProposalMetaData interface.
func (m *TaikoProposalMetadataRealTime) RealTime() TaikoProposalMetaDataRealTime { return m }

// IsRealTime implements TaikoProposalMetaData interface.
func (m *TaikoProposalMetadataRealTime) IsRealTime() bool { return true }

// GetRawBlockHeight returns the raw L1 block height.
func (m *TaikoProposalMetadataRealTime) GetRawBlockHeight() *big.Int {
	return new(big.Int).SetUint64(m.Raw.BlockNumber)
}

// GetRawBlockHash returns the raw L1 block hash.
func (m *TaikoProposalMetadataRealTime) GetRawBlockHash() common.Hash {
	return m.Raw.BlockHash
}

// GetTxIndex returns the transaction index.
func (m *TaikoProposalMetadataRealTime) GetTxIndex() uint {
	return m.Raw.TxIndex
}

// GetTxHash returns the transaction hash.
func (m *TaikoProposalMetadataRealTime) GetTxHash() common.Hash {
	return m.Raw.TxHash
}

// GetProposer returns the proposer - not tracked in RealTimeInbox, returns zero address.
func (m *TaikoProposalMetadataRealTime) GetProposer() common.Address {
	return common.Address{}
}

// GetCoinbase returns the coinbase - fetched from blob manifest.
func (m *TaikoProposalMetadataRealTime) GetCoinbase() common.Address {
	return common.Address{}
}

// GetProposalID returns nil - RealTimeInbox uses hashes not sequential IDs.
func (m *TaikoProposalMetadataRealTime) GetProposalID() *big.Int {
	return nil
}

// --- TaikoProposalMetaDataRealTime interface methods ---

// GetEventData returns the underlying event data.
func (m *TaikoProposalMetadataRealTime) GetEventData() *realtimeBindings.RealTimeInboxClientProposedAndProved {
	return m.RealTimeInboxClientProposedAndProved
}

// GetBlobHashes returns blob hashes from the specified source.
func (m *TaikoProposalMetadataRealTime) GetBlobHashes(idx int) []common.Hash {
	if idx >= len(m.Sources) {
		return nil
	}
	var blobHashes []common.Hash
	for _, hash := range m.Sources[idx].BlobSlice.BlobHashes {
		blobHashes = append(blobHashes, hash)
	}
	return blobHashes
}

// GetBlobTimestamp returns the timestamp of the blob slice.
func (m *TaikoProposalMetadataRealTime) GetBlobTimestamp(idx int) uint64 {
	if idx >= len(m.Sources) {
		return 0
	}
	return m.Sources[idx].BlobSlice.Timestamp.Uint64()
}

// GetTimestamp returns the L1 block timestamp.
func (m *TaikoProposalMetadataRealTime) GetTimestamp() uint64 {
	return m.timestamp
}

// GetMaxAnchorBlockNumber returns the max anchor block number.
func (m *TaikoProposalMetadataRealTime) GetMaxAnchorBlockNumber() uint64 {
	return m.MaxAnchorBlockNumber.Uint64()
}

// GetSignalSlots returns the signal slots from the event.
func (m *TaikoProposalMetadataRealTime) GetSignalSlots() [][32]byte {
	return m.SignalSlots
}

// GetCheckpoint returns the checkpoint from the event.
func (m *TaikoProposalMetadataRealTime) GetCheckpoint() realtimeBindings.ICheckpointStoreCheckpoint {
	return m.Checkpoint
}

// GetLog returns the raw log.
func (m *TaikoProposalMetadataRealTime) GetLog() *types.Log {
	return &m.Raw
}
