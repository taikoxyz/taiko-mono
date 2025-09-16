package metadata

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"

	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
)

// TaikoProposalMetaData defines all the metadata of a Taiko block.
type TaikoProposalMetaData interface {
	Pacaya() TaikoBatchMetaDataPacaya
	IsPacaya() bool
	GetRawBlockHeight() *big.Int
	GetRawBlockHash() common.Hash
	GetTxIndex() uint
	GetTxHash() common.Hash
	GetLogIndex() uint
	GetProposer() common.Address
	GetCoinbase() common.Address
	GetBlobCreatedIn() *big.Int
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
	GetLogIndex() uint
	InnerMetadata() *pacayaBindings.ITaikoInboxBatchMetadata
	GetBaseFee() *big.Int
}
