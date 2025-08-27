package metadata

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

// Ensure TaikoDataBlockMetadataShasta implements TaikoBlockMetaData.
var _ TaikoProposalMetaData = (*TaikoDataBlockMetadataShasta)(nil)

// TaikoDataBlockMetadataShasta is the metadata of an Shasta Taiko blocks batch.
type TaikoDataBlockMetadataShasta struct {
	shastaBindings.IInboxProposal
	shastaBindings.IInboxDerivation
	shastaBindings.IInboxCoreState
	types.Log
}

// Pacaya implements TaikoProposalMetaData interface.
func (m *TaikoDataBlockMetadataShasta) Pacaya() TaikoBatchMetaDataPacaya {
	return nil
}

// IsPacaya implements TaikoProposalMetaData interface.
func (m *TaikoDataBlockMetadataShasta) IsPacaya() bool {
	return false
}

// Shasta implements TaikoProposalMetaData interface.
func (m *TaikoDataBlockMetadataShasta) Shasta() TaikoBatchMetaDataShasta {
	return m
}

// IsShasta implements TaikoProposalMetaData interface.
func (m *TaikoDataBlockMetadataShasta) IsShasta() bool {
	return false
}

// GetRawBlockHeight returns the raw L1 block height.
func (m *TaikoDataBlockMetadataShasta) GetRawBlockHeight() *big.Int {
	return new(big.Int).SetUint64(m.BlockNumber)
}

// GetRawBlockHash returns the raw L1 block hash.
func (m *TaikoDataBlockMetadataShasta) GetRawBlockHash() common.Hash {
	return m.BlockHash
}

// GetTxIndex returns the transaction index.
func (m *TaikoDataBlockMetadataShasta) GetTxIndex() uint {
	return m.Log.TxIndex
}

// GetTxHash returns the transaction hash.
func (m *TaikoDataBlockMetadataShasta) GetTxHash() common.Hash {
	return m.Log.TxHash
}

// GetProposer returns the proposer of this batch.
func (m *TaikoDataBlockMetadataShasta) GetProposer() common.Address {
	return m.Proposer
}

// GetCoinbase returns block coinbase. Sets it to common.Address{}, because we need to fetch the value from blob.
func (m *TaikoDataBlockMetadataShasta) GetCoinbase() common.Address {
	return common.Address{}
}

// GetBlobCreatedIn returns the L1 block number when the blob created.
func (m *TaikoDataBlockMetadataShasta) GetBlobCreatedIn() *big.Int {
	return m.BlobSlice.Timestamp
}

// GetProposal returns the transaction hash.
func (m *TaikoDataBlockMetadataShasta) GetProposal() shastaBindings.IInboxProposal {
	return m.IInboxProposal
}

// GetDerivation returns the transaction hash.
func (m *TaikoDataBlockMetadataShasta) GetDerivation() shastaBindings.IInboxDerivation {
	return m.IInboxDerivation
}

// GetCoreState returns the transaction hash.
func (m *TaikoDataBlockMetadataShasta) GetCoreState() shastaBindings.IInboxCoreState {
	return m.IInboxCoreState
}
