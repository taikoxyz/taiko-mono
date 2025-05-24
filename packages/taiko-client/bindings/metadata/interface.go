package metadata

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"

	bindingTypes "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding/binding_types"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

// TaikoProposalMetaData defines all the metadata of a Taiko block.
type TaikoProposalMetaData interface {
	Pacaya() TaikoBatchMetaDataPacaya
	IsPacaya() bool
	Shasta() TaikoBatchMetaDataShasta
	IsShasta() bool
	GetRawBlockHeight() *big.Int
	GetRawBlockHash() common.Hash
	GetTxIndex() uint
	GetTxHash() common.Hash
	GetProposer() common.Address
	GetCoinbase() common.Address
	GetBatchID() *big.Int
	GetLastBlockID() uint64
	GetLastBlockTimestamp() uint64
	GetBlobHashes() []common.Hash
	GetBlocks() []bindingTypes.BlockParams
	GetAnchorBlockID() uint64
	GetAnchorBlockHash() common.Hash
	GetBaseFeeConfig() bindingTypes.LibSharedDataBaseFeeConfig
	GetProposedIn() uint64
	GetTxListOffset() uint32
	GetTxListSize() uint32
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
	GetBlocks() []bindingTypes.BlockParams
	GetBaseFeeConfig() bindingTypes.LibSharedDataBaseFeeConfig
	GetRawBlockHeight() *big.Int
	GetRawBlockHash() common.Hash
	GetTxIndex() uint
	GetTxHash() common.Hash
	InnerMetadata() *pacayaBindings.ITaikoInboxBatchMetadata
}

type TaikoBatchMetaDataShasta interface {
	GetTxListHash() common.Hash
	GetBlocks() []bindingTypes.BlockParams
	GetBlobHashes() []common.Hash
	GetExtraData() []byte
	GetCoinbase() common.Address
	GetProposer() common.Address
	GetProposedIn() uint64
	GetBlobCreatedIn() *big.Int
	GetTxListOffset() uint32
	GetTxListSize() uint32
	GetGasLimit() uint32
	GetLastBlockID() uint64
	GetLastBlockTimestamp() uint64
	GetAnchorBlockID() uint64
	GetAnchorBlockHash() common.Hash
	GetBaseFeeConfig() bindingTypes.LibSharedDataBaseFeeConfig
	GetBatchID() *big.Int
	GetProposedAt() uint64
	GetRawBlockHeight() *big.Int
	GetRawBlockHash() common.Hash
	GetTxIndex() uint
	GetTxHash() common.Hash
	InnerMetadata() *shastaBindings.ITaikoInboxBatchMetadata
}
