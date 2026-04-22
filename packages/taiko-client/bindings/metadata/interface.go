package metadata

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

// TaikoProposalMetaData defines all the metadata of a Taiko block.
type TaikoProposalMetaData interface {
	Shasta() TaikoProposalMetaDataShasta
	IsShasta() bool
	GetRawBlockHeight() *big.Int
	GetRawBlockHash() common.Hash
	GetTxIndex() uint
	GetTxHash() common.Hash
	GetProposer() common.Address
	GetCoinbase() common.Address
	GetProposalID() *big.Int
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
