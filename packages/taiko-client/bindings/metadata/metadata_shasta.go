package metadata

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

// Ensure TaikoProposalMetadataShasta implements TaikoBlockMetaData.
var _ TaikoProposalMetaData = (*TaikoProposalMetadataShasta)(nil)

// TaikoProposalMetadataShasta is the metadata of an Shasta Taiko blocks batch.
type TaikoProposalMetadataShasta struct {
	shastaBindings.IInboxProposal
	shastaBindings.IInboxDerivation
	shastaBindings.IInboxCoreState
	types.Log
}

// NewTaikoProposalMetadataShasta creates a new instance of TaikoProposalMetadataShasta
// from the ShastaTaikoInbox.Proposed event.
func NewTaikoProposalMetadataShasta(e *shastaBindings.IInboxProposedEventPayload, log types.Log) *TaikoProposalMetadataShasta {
	return &TaikoProposalMetadataShasta{
		IInboxProposal:   e.Proposal,
		IInboxDerivation: e.Derivation,
		IInboxCoreState:  e.CoreState,
		Log:              log,
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
	return false
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

// GetBlobCreatedIn returns the L1 block number when the blob created.
func (m *TaikoProposalMetadataShasta) GetBlobCreatedIn() *big.Int {
	return new(big.Int).SetUint64(m.BlockNumber)
}

// GetBlobHashes returns blob hashes in this proposal.
func (m *TaikoProposalMetadataShasta) GetBlobHashes() []common.Hash {
	var blobHashes []common.Hash
	for _, hash := range m.GetDerivation().BlobSlice.BlobHashes {
		blobHashes = append(blobHashes, hash)
	}
	return blobHashes
}

func (m *TaikoProposalMetadataShasta) GetBlobTimestamp() uint64 {
	return m.GetDerivation().BlobSlice.Timestamp.Uint64()
}

// GetProposal returns the transaction hash.
func (m *TaikoProposalMetadataShasta) GetProposal() shastaBindings.IInboxProposal {
	return m.IInboxProposal
}

// GetDerivation returns the transaction hash.
func (m *TaikoProposalMetadataShasta) GetDerivation() shastaBindings.IInboxDerivation {
	return m.IInboxDerivation
}

// GetCoreState returns the transaction hash.
func (m *TaikoProposalMetadataShasta) GetCoreState() shastaBindings.IInboxCoreState {
	return m.IInboxCoreState
}
