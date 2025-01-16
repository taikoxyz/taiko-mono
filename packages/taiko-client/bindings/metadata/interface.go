package metadata

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"

	ontakeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/ontake"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
)

// TaikoProposalMetaData defines all the metadata of a Taiko block.
type TaikoProposalMetaData interface {
	TaikoBlockMetaDataOntake() TaikoBlockMetaDataOntake
	TaikoBatchMetaDataPacaya() TaikoBatchMetaDataPacaya
	IsPacaya() bool
	GetRawBlockHeight() *big.Int
	GetRawBlockHash() common.Hash
	GetTxIndex() uint
	GetTxHash() common.Hash
	GetProposer() common.Address
}

type TaikoBlockMetaDataOntake interface {
	GetAnchorBlockHash() common.Hash
	GetDifficulty() common.Hash
	GetBlobHash() common.Hash
	GetExtraData() []byte
	GetCoinbase() common.Address
	GetBlockID() *big.Int
	GetGasLimit() uint32
	GetTimestamp() uint64
	GetAnchorBlockID() uint64
	GetMinTier() uint16
	GetBlobUsed() bool
	GetParentMetaHash() common.Hash
	GetProposer() common.Address
	GetAssignedProver() common.Address
	GetLivenessBond() *big.Int
	GetProposedAt() uint64
	GetProposedIn() uint64
	GetBlobTxListOffset() uint32
	GetBlobTxListLength() uint32
	GetBlobIndex() uint8
	GetBaseFeeConfig() *ontakeBindings.LibSharedDataBaseFeeConfig
	GetRawBlockHeight() *big.Int
	GetRawBlockHash() common.Hash
	GetTxIndex() uint
	GetTxHash() common.Hash
}

type TaikoBatchMetaDataPacaya interface {
	GetTxListHash() common.Hash
	GetExtraData() []byte
	GetCoinbase() common.Address
	GetBatchID() *big.Int
	GetGasLimit() uint32
	GetLastBlockTimestamp() uint64
	GetParentMetaHash() common.Hash
	GetProposer() common.Address
	GetLivenessBond() *big.Int
	GetProposedAt() uint64
	GetProposedIn() uint64
	GetTxListOffset() uint32
	GetTxListSize() uint32
	GetNumBlobs() uint8
	GetAnchorBlockID() uint64
	GetAnchorBlockHash() common.Hash
	GetSignalSlots() [][32]byte
	GetBlocks() []pacayaBindings.ITaikoInboxBlockParams
	GetAnchorInput() [32]byte
	GetBaseFeeConfig() *pacayaBindings.LibSharedDataBaseFeeConfig
	GetRawBlockHeight() *big.Int
	GetRawBlockHash() common.Hash
	GetTxIndex() uint
	GetTxHash() common.Hash
}
