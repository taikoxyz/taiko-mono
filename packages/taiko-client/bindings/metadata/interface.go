package metadata

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	realtimeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/realtime"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

// TaikoProposalMetaData defines all the metadata of a Taiko block.
type TaikoProposalMetaData interface {
	Pacaya() TaikoBatchMetaDataPacaya
	IsPacaya() bool
	Shasta() TaikoProposalMetaDataShasta
	IsShasta() bool
	RealTime() TaikoProposalMetaDataRealTime
	IsRealTime() bool
	GetRawBlockHeight() *big.Int
	GetRawBlockHash() common.Hash
	GetTxIndex() uint
	GetTxHash() common.Hash
	GetProposer() common.Address
	GetCoinbase() common.Address
	GetProposalID() *big.Int
}

type TaikoBatchMetaDataPacaya interface {
	GetTxListHash() common.Hash
	GetExtraData() []byte
	GetCoinbase() common.Address
	GetBatchID() *big.Int
	GetGasLimit() uint32
	GetLastBlockTimestamp() uint64
	GetProposer() common.Address
	GetProposedAt() uint64
	GetProposedIn() uint64
	GetBlobCreatedIn() *big.Int
	GetTxListOffset() uint32
	GetTxListSize() uint32
	GetLastBlockID() uint64
	GetBlobHashes() []common.Hash
	GetAnchorBlockID() uint64
	GetAnchorBlockHash() common.Hash
	GetBlocks() []pacayaBindings.ITaikoInboxBlockParams
	GetBaseFeeConfig() *pacayaBindings.LibSharedDataBaseFeeConfig
	GetRawBlockHeight() *big.Int
	GetRawBlockHash() common.Hash
	GetTxIndex() uint
	GetTxHash() common.Hash
	InnerMetadata() *pacayaBindings.ITaikoInboxBatchMetadata
}

type TaikoProposalMetaDataShasta interface {
	GetEventData() *shastaBindings.ShastaInboxClientProposed
	GetBlobHashes(int) []common.Hash
	GetBlobTimestamp(int) uint64
	GetTimestamp() uint64
	GetRawBlockHeight() *big.Int
	GetRawBlockHash() common.Hash
	GetLog() *types.Log
}

type TaikoProposalMetaDataRealTime interface {
	GetEventData() *realtimeBindings.RealTimeInboxClientProposedAndProved
	GetBlobHashes(int) []common.Hash
	GetBlobTimestamp(int) uint64
	GetTimestamp() uint64
	GetMaxAnchorBlockNumber() uint64
	GetSignalSlots() [][32]byte
	GetCheckpoint() realtimeBindings.ICheckpointStoreCheckpoint
	GetRawBlockHeight() *big.Int
	GetRawBlockHash() common.Hash
	GetLog() *types.Log
}
