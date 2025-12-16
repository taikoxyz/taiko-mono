package metadata

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

// Ensure TaikoProposalMetadataShasta implements TaikoBlockMetaData.
var _ TaikoProposalMetaData = (*TaikoProposalMetadataShasta)(nil)

// TaikoProposalMetadataShasta is the metadata of a Shasta Taiko blocks batch.
type TaikoProposalMetadataShasta struct {
	shastaBindings.IInboxProposal
	types.Log
}

// NewTaikoProposalMetadataShasta creates a new instance of TaikoProposalMetadataShasta
// from the ShastaTaikoInbox.Proposed event.
func NewTaikoProposalMetadataShasta(e *shastaBindings.IInboxProposedEventPayload, log types.Log) *TaikoProposalMetadataShasta {
	return &TaikoProposalMetadataShasta{
		IInboxProposal: e.Proposal,
		Log:            log,
	}
}

// Pacaya implements TaikoProposalMetaData interface.
func (m *TaikoProposalMetadataShasta) Pacaya() TaikoBatchMetaDataPacaya {
	return nil
}

// IsPacaya implements TaikoProposalMetaData interface.
func (m *TaikoProposalMetadataShasta) IsPacaya() bool {
	return false
}

// Shasta implements TaikoProposalMetaData interface.
func (m *TaikoProposalMetadataShasta) Shasta() TaikoProposalMetaDataShasta {
	return m
}

// IsShasta implements TaikoProposalMetaData interface.
func (m *TaikoProposalMetadataShasta) IsShasta() bool {
	return true
}

// GetRawBlockHeight returns the raw L1 block height.
func (m *TaikoProposalMetadataShasta) GetRawBlockHeight() *big.Int {
	return new(big.Int).SetUint64(m.BlockNumber)
}

// GetRawBlockHash returns the raw L1 block hash.
func (m *TaikoProposalMetadataShasta) GetRawBlockHash() common.Hash {
	return m.BlockHash
}

// GetTxIndex returns the transaction index.
func (m *TaikoProposalMetadataShasta) GetTxIndex() uint {
	return m.Log.TxIndex
}

// GetTxHash returns the transaction hash.
func (m *TaikoProposalMetadataShasta) GetTxHash() common.Hash {
	return m.Log.TxHash
}

// GetProposer returns the proposer of this batch.
func (m *TaikoProposalMetadataShasta) GetProposer() common.Address {
	return m.Proposer
}

// GetCoinbase returns block coinbase. Sets it to common.Address{}, because we need to fetch the value from blob.
func (m *TaikoProposalMetadataShasta) GetCoinbase() common.Address {
	return common.Address{}
}

func (m *TaikoProposalMetadataShasta) GetLog() *types.Log {
	return &m.Log
}

// GetBlobHashes returns blob hashes in this proposal.
func (m *TaikoProposalMetadataShasta) GetBlobHashes(idx int) []common.Hash {
	var blobHashes []common.Hash
	if len(m.GetProposal().Sources) <= idx {
		return blobHashes
	}
	for _, hash := range m.GetProposal().Sources[idx].BlobSlice.BlobHashes {
		blobHashes = append(blobHashes, hash)
	}
	return blobHashes
}

// GetBlobTimestamp returns the timestamp of the blob slice in this proposal.
func (m *TaikoProposalMetadataShasta) GetBlobTimestamp(idx int) uint64 {
	if len(m.GetProposal().Sources) <= idx {
		return 0
	}
	return m.GetProposal().Sources[idx].BlobSlice.Timestamp.Uint64()
}

// GetProposal returns the transaction hash.
func (m *TaikoProposalMetadataShasta) GetProposal() shastaBindings.IInboxProposal {
	return m.IInboxProposal
}

// GetProposalID returns proposal ID.
func (m *TaikoProposalMetadataShasta) GetProposalID() *big.Int {
	return m.IInboxProposal.Id
}
