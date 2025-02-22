package metadata

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"

	ontakeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/ontake"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
)

// TaikoProposalMetaData defines all the metadata of a Taiko block.
type TaikoProposalMetaData interface {
	Ontake() TaikoBlockMetaDataOntake
	Pacaya() TaikoBatchMetaDataPacaya
	IsPacaya() bool
	GetRawBlockHeight() *big.Int
	GetRawBlockHash() common.Hash
	GetTxIndex() uint
	GetTxHash() common.Hash
	GetProposer() common.Address
	GetCoinbase() common.Address
	GetBlobCreatedIn() *big.Int
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
	GetBlobCreatedIn() *big.Int
	GetBlobTxListOffset() uint32
	GetBlobTxListLength() uint32
	GetBlobIndex() uint8
	GetBaseFeeConfig() *ontakeBindings.LibSharedDataBaseFeeConfig
	GetRawBlockHeight() *big.Int
	GetRawBlockHash() common.Hash
	GetTxIndex() uint
	GetTxHash() common.Hash
	InnerMetadata() *ontakeBindings.TaikoDataBlockMetadataV2
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
