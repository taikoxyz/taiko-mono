package metadata

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"
)

type TaikoBlockMetaData interface {
	GetAnchorBlockHash() common.Hash
	GetDifficulty() common.Hash
	GetBlobHash() common.Hash
	GetExtraData() common.Hash
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
	GetBasefeeSharingPctg() uint8
	GetRawBlockHeight() *big.Int
	GetRawBlockHash() common.Hash
}
