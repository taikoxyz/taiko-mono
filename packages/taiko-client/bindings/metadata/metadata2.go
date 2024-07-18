package metadata

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
)

// TaikoDataBlockMetadata2 is the metadata of an ontake Taiko block.
type TaikoDataBlockMetadata2 struct {
	bindings.TaikoDataBlockMetadata2
	types.Log
}

// GetAnchorBlockHash returns the anchor block hash.
func (m *TaikoDataBlockMetadata2) GetAnchorBlockHash() common.Hash {
	return m.AnchorBlockHash
}

// GetDifficulty returns the difficulty.
func (m *TaikoDataBlockMetadata2) GetDifficulty() common.Hash {
	return m.Difficulty
}

// GetBlobHash returns the blob hash.
func (m *TaikoDataBlockMetadata2) GetBlobHash() common.Hash {
	return m.BlobHash
}

// GetExtraData returns the extra data.
func (m *TaikoDataBlockMetadata2) GetExtraData() common.Hash {
	return m.ExtraData
}

// GetCoinbase returns the coinbase.
func (m *TaikoDataBlockMetadata2) GetCoinbase() common.Address {
	return m.Coinbase
}

// GetBlockID returns the L2 block ID.
func (m *TaikoDataBlockMetadata2) GetBlockID() *big.Int {
	return new(big.Int).SetUint64(m.Id)
}

// GetGasLimit returns the gas limit.
func (m *TaikoDataBlockMetadata2) GetGasLimit() uint32 {
	return m.GasLimit
}

// GetTimestamp returns the timestamp.
func (m *TaikoDataBlockMetadata2) GetTimestamp() uint64 {
	return m.Timestamp
}

// GetAnchorBlockID returns the L1 block number which should be used in anchor transaction.
func (m *TaikoDataBlockMetadata2) GetAnchorBlockID() uint64 {
	return m.AnchorBlockId
}

// GetMinTier returns the minimum tier.
func (m *TaikoDataBlockMetadata2) GetMinTier() uint16 {
	return m.MinTier
}

// GetBlobUsed returns whether the blob is used.
func (m *TaikoDataBlockMetadata2) GetBlobUsed() bool {
	return m.BlobUsed
}

// GetParentMetaHash returns the parent meta hash.
func (m *TaikoDataBlockMetadata2) GetParentMetaHash() common.Hash {
	return m.ParentMetaHash
}

// GetProposer returns the proposer address.
func (m *TaikoDataBlockMetadata2) GetProposer() common.Address {
	return m.Proposer
}

// GetAssignedProver returns the assigned prover address, right now
// this address should be equal to the proposer address.
func (m *TaikoDataBlockMetadata2) GetAssignedProver() common.Address {
	return m.Proposer
}

// GetLivenessBond returns the liveness bond.
func (m *TaikoDataBlockMetadata2) GetLivenessBond() *big.Int {
	return m.LivenessBond
}

// GetProposedAt returns the proposedAt timestamp.
func (m *TaikoDataBlockMetadata2) GetProposedAt() uint64 {
	return m.ProposedAt
}

// GetProposedIn returns the proposedIn block number.
func (m *TaikoDataBlockMetadata2) GetProposedIn() uint64 {
	return m.ProposedIn
}

// GetBlobTxListOffset returns the blob tx list offset.
func (m *TaikoDataBlockMetadata2) GetBlobTxListOffset() uint32 {
	return m.BlobTxListOffset
}

// GetBlobTxListLength returns the blob tx list length.
func (m *TaikoDataBlockMetadata2) GetBlobTxListLength() uint32 {
	return m.BlobTxListLength
}

// GetBlobIndex returns the blob index.
func (m *TaikoDataBlockMetadata2) GetBlobIndex() uint8 {
	return m.BlobIndex
}

// GetBasefeeSharingPctg returns the basefee sharing percentage.
func (m *TaikoDataBlockMetadata2) GetBasefeeSharingPctg() uint8 {
	return m.BasefeeSharingPctg
}

// GetRawBlockHeight returns the raw L1 block height.
func (m *TaikoDataBlockMetadata2) GetRawBlockHeight() *big.Int {
	return new(big.Int).SetUint64(m.BlockNumber)
}

// GetRawBlockHash returns the raw L1 block hash.
func (m *TaikoDataBlockMetadata2) GetRawBlockHash() common.Hash {
	return m.BlockHash
}
