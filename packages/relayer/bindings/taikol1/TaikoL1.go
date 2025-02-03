// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package taikol1

import (
	"errors"
	"math/big"
	"strings"

	ethereum "github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
)

// Reference imports to suppress errors if they are not otherwise used.
var (
	_ = errors.New
	_ = big.NewInt
	_ = strings.NewReader
	_ = ethereum.NotFound
	_ = bind.Bind
	_ = common.Big1
	_ = types.BloomLookup
	_ = event.NewSubscription
	_ = abi.ConvertType
)

// LibSharedDataBaseFeeConfig is an auto generated low-level Go binding around an user-defined struct.
type LibSharedDataBaseFeeConfig struct {
	AdjustmentQuotient     uint8
	SharingPctg            uint8
	GasIssuancePerSecond   uint32
	MinGasExcess           uint64
	MaxGasIssuancePerBlock uint32
}

// TaikoDataBlock is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataBlock struct {
	MetaHash             [32]byte
	AssignedProver       common.Address
	LivenessBond         *big.Int
	BlockId              uint64
	ProposedAt           uint64
	ProposedIn           uint64
	NextTransitionId     uint32
	VerifiedTransitionId uint32
}

// TaikoDataBlockMetadata is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataBlockMetadata struct {
	L1Hash         [32]byte
	Difficulty     [32]byte
	BlobHash       [32]byte
	ExtraData      [32]byte
	DepositsHash   [32]byte
	Coinbase       common.Address
	Id             uint64
	GasLimit       uint32
	Timestamp      uint64
	L1Height       uint64
	MinTier        uint16
	BlobUsed       bool
	ParentMetaHash [32]byte
	Sender         common.Address
}

// TaikoDataBlockMetadataV2 is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataBlockMetadataV2 struct {
	AnchorBlockHash  [32]byte
	Difficulty       [32]byte
	BlobHash         [32]byte
	ExtraData        [32]byte
	Coinbase         common.Address
	Id               uint64
	GasLimit         uint32
	Timestamp        uint64
	AnchorBlockId    uint64
	MinTier          uint16
	BlobUsed         bool
	ParentMetaHash   [32]byte
	Proposer         common.Address
	LivenessBond     *big.Int
	ProposedAt       uint64
	ProposedIn       uint64
	BlobTxListOffset uint32
	BlobTxListLength uint32
	BlobIndex        uint8
	BaseFeeConfig    LibSharedDataBaseFeeConfig
}

// TaikoDataBlockV2 is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataBlockV2 struct {
	MetaHash             [32]byte
	AssignedProver       common.Address
	LivenessBond         *big.Int
	BlockId              uint64
	ProposedAt           uint64
	ProposedIn           uint64
	NextTransitionId     *big.Int
	LivenessBondReturned bool
	VerifiedTransitionId *big.Int
}

// TaikoDataConfig is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataConfig struct {
	ChainId               uint64
	BlockMaxProposals     uint64
	BlockRingBufferSize   uint64
	MaxBlocksToVerify     uint64
	BlockMaxGasLimit      uint32
	LivenessBond          *big.Int
	StateRootSyncInternal uint8
	MaxAnchorHeightOffset uint64
	BaseFeeConfig         LibSharedDataBaseFeeConfig
	OntakeForkHeight      uint64
}

// TaikoDataEthDeposit is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataEthDeposit struct {
	Recipient common.Address
	Amount    *big.Int
	Id        uint64
}

// TaikoDataSlotA is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataSlotA struct {
	GenesisHeight     uint64
	GenesisTimestamp  uint64
	LastSyncedBlockId uint64
	LastSynecdAt      uint64
}

// TaikoDataSlotB is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataSlotB struct {
	NumBlocks           uint64
	LastVerifiedBlockId uint64
	ProvingPaused       bool
	LastProposedIn      *big.Int
	LastUnpausedAt      uint64
}

// TaikoDataTransition is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataTransition struct {
	ParentHash [32]byte
	BlockHash  [32]byte
	StateRoot  [32]byte
	Graffiti   [32]byte
}

// TaikoDataTransitionState is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataTransitionState struct {
	Key          [32]byte
	BlockHash    [32]byte
	StateRoot    [32]byte
	Prover       common.Address
	ValidityBond *big.Int
	Contester    common.Address
	ContestBond  *big.Int
	Timestamp    uint64
	Tier         uint16
	Reserved1    uint8
}

// TaikoL1MetaData contains all meta data concerning the TaikoL1 contract.
var TaikoL1MetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"addressManager\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"bondBalanceOf\",\"inputs\":[{\"name\":\"_user\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"depositBond\",\"inputs\":[{\"name\":\"_amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"getBlock\",\"inputs\":[{\"name\":\"_blockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"outputs\":[{\"name\":\"blk_\",\"type\":\"tuple\",\"internalType\":\"structTaikoData.Block\",\"components\":[{\"name\":\"metaHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"assignedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"livenessBond\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"blockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"proposedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"proposedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"nextTransitionId\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"verifiedTransitionId\",\"type\":\"uint32\",\"internalType\":\"uint32\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getBlockV2\",\"inputs\":[{\"name\":\"_blockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"outputs\":[{\"name\":\"blk_\",\"type\":\"tuple\",\"internalType\":\"structTaikoData.BlockV2\",\"components\":[{\"name\":\"metaHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"assignedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"livenessBond\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"blockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"proposedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"proposedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"nextTransitionId\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"livenessBondReturned\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"verifiedTransitionId\",\"type\":\"uint24\",\"internalType\":\"uint24\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getConfig\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structTaikoData.Config\",\"components\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blockMaxProposals\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blockRingBufferSize\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxBlocksToVerify\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blockMaxGasLimit\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"livenessBond\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"stateRootSyncInternal\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"maxAnchorHeightOffset\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"baseFeeConfig\",\"type\":\"tuple\",\"internalType\":\"structLibSharedData.BaseFeeConfig\",\"components\":[{\"name\":\"adjustmentQuotient\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"gasIssuancePerSecond\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"minGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxGasIssuancePerBlock\",\"type\":\"uint32\",\"internalType\":\"uint32\"}]},{\"name\":\"ontakeForkHeight\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getLastSyncedBlock\",\"inputs\":[],\"outputs\":[{\"name\":\"blockId_\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blockHash_\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot_\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"verifiedAt_\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getLastVerifiedBlock\",\"inputs\":[],\"outputs\":[{\"name\":\"blockId_\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blockHash_\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot_\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"verifiedAt_\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getStateVariables\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structTaikoData.SlotA\",\"components\":[{\"name\":\"genesisHeight\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"genesisTimestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastSyncedBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastSynecdAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]},{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structTaikoData.SlotB\",\"components\":[{\"name\":\"numBlocks\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastVerifiedBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"provingPaused\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"lastProposedIn\",\"type\":\"uint56\",\"internalType\":\"uint56\"},{\"name\":\"lastUnpausedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTransition\",\"inputs\":[{\"name\":\"_blockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_tid\",\"type\":\"uint32\",\"internalType\":\"uint32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structTaikoData.TransitionState\",\"components\":[{\"name\":\"key\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"prover\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"validityBond\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"contester\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"contestBond\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"timestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"tier\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"__reserved1\",\"type\":\"uint8\",\"internalType\":\"uint8\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTransition\",\"inputs\":[{\"name\":\"_blockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structTaikoData.TransitionState\",\"components\":[{\"name\":\"key\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"prover\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"validityBond\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"contester\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"contestBond\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"timestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"tier\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"__reserved1\",\"type\":\"uint8\",\"internalType\":\"uint8\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTransitions\",\"inputs\":[{\"name\":\"_blockIds\",\"type\":\"uint64[]\",\"internalType\":\"uint64[]\"},{\"name\":\"_parentHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple[]\",\"internalType\":\"structTaikoData.TransitionState[]\",\"components\":[{\"name\":\"key\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"prover\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"validityBond\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"contester\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"contestBond\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"timestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"tier\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"__reserved1\",\"type\":\"uint8\",\"internalType\":\"uint8\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getVerifiedBlockProver\",\"inputs\":[{\"name\":\"_blockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"outputs\":[{\"name\":\"prover_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"impl\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inNonReentrant\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_rollupAddressManager\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_genesisBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_toPause\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"init2\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"init3\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"lastProposedIn\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint56\",\"internalType\":\"uint56\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"lastUnpausedAt\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"pauseProving\",\"inputs\":[{\"name\":\"_pause\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proposeBlockV2\",\"inputs\":[{\"name\":\"_params\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"_txList\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"meta_\",\"type\":\"tuple\",\"internalType\":\"structTaikoData.BlockMetadataV2\",\"components\":[{\"name\":\"anchorBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"difficulty\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blobHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"extraData\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"coinbase\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"id\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"gasLimit\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"timestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"anchorBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"minTier\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"blobUsed\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"parentMetaHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"livenessBond\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"proposedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"proposedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobTxListOffset\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobTxListLength\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobIndex\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"baseFeeConfig\",\"type\":\"tuple\",\"internalType\":\"structLibSharedData.BaseFeeConfig\",\"components\":[{\"name\":\"adjustmentQuotient\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"gasIssuancePerSecond\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"minGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxGasIssuancePerBlock\",\"type\":\"uint32\",\"internalType\":\"uint32\"}]}]}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proposeBlocksV2\",\"inputs\":[{\"name\":\"_paramsArr\",\"type\":\"bytes[]\",\"internalType\":\"bytes[]\"},{\"name\":\"_txListArr\",\"type\":\"bytes[]\",\"internalType\":\"bytes[]\"}],\"outputs\":[{\"name\":\"metaArr_\",\"type\":\"tuple[]\",\"internalType\":\"structTaikoData.BlockMetadataV2[]\",\"components\":[{\"name\":\"anchorBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"difficulty\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blobHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"extraData\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"coinbase\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"id\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"gasLimit\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"timestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"anchorBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"minTier\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"blobUsed\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"parentMetaHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"livenessBond\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"proposedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"proposedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobTxListOffset\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobTxListLength\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobIndex\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"baseFeeConfig\",\"type\":\"tuple\",\"internalType\":\"structLibSharedData.BaseFeeConfig\",\"components\":[{\"name\":\"adjustmentQuotient\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"gasIssuancePerSecond\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"minGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxGasIssuancePerBlock\",\"type\":\"uint32\",\"internalType\":\"uint32\"}]}]}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proveBlock\",\"inputs\":[{\"name\":\"_blockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_input\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proveBlocks\",\"inputs\":[{\"name\":\"_blockIds\",\"type\":\"uint64[]\",\"internalType\":\"uint64[]\"},{\"name\":\"_inputs\",\"type\":\"bytes[]\",\"internalType\":\"bytes[]\"},{\"name\":\"_batchProof\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolve\",\"inputs\":[{\"name\":\"_chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_allowZeroAddress\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"resolve\",\"inputs\":[{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_allowZeroAddress\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"state\",\"inputs\":[],\"outputs\":[{\"name\":\"__reserve1\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"slotA\",\"type\":\"tuple\",\"internalType\":\"structTaikoData.SlotA\",\"components\":[{\"name\":\"genesisHeight\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"genesisTimestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastSyncedBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastSynecdAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]},{\"name\":\"slotB\",\"type\":\"tuple\",\"internalType\":\"structTaikoData.SlotB\",\"components\":[{\"name\":\"numBlocks\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastVerifiedBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"provingPaused\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"lastProposedIn\",\"type\":\"uint56\",\"internalType\":\"uint56\"},{\"name\":\"lastUnpausedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"verifyBlocks\",\"inputs\":[{\"name\":\"_maxBlocksToVerify\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"withdrawBond\",\"inputs\":[{\"name\":\"_amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BlockProposed\",\"inputs\":[{\"name\":\"blockId\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"assignedProver\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"livenessBond\",\"type\":\"uint96\",\"indexed\":false,\"internalType\":\"uint96\"},{\"name\":\"meta\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structTaikoData.BlockMetadata\",\"components\":[{\"name\":\"l1Hash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"difficulty\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blobHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"extraData\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"depositsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"coinbase\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"id\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"gasLimit\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"timestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"l1Height\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"minTier\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"blobUsed\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"parentMetaHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"sender\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"depositsProcessed\",\"type\":\"tuple[]\",\"indexed\":false,\"internalType\":\"structTaikoData.EthDeposit[]\",\"components\":[{\"name\":\"recipient\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"id\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BlockProposedV2\",\"inputs\":[{\"name\":\"blockId\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"meta\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structTaikoData.BlockMetadataV2\",\"components\":[{\"name\":\"anchorBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"difficulty\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blobHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"extraData\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"coinbase\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"id\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"gasLimit\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"timestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"anchorBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"minTier\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"blobUsed\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"parentMetaHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"livenessBond\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"proposedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"proposedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobTxListOffset\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobTxListLength\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobIndex\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"baseFeeConfig\",\"type\":\"tuple\",\"internalType\":\"structLibSharedData.BaseFeeConfig\",\"components\":[{\"name\":\"adjustmentQuotient\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"gasIssuancePerSecond\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"minGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxGasIssuancePerBlock\",\"type\":\"uint32\",\"internalType\":\"uint32\"}]}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BlockProposedV2\",\"inputs\":[{\"name\":\"blockId\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"meta\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structTaikoData.BlockMetadataV2\",\"components\":[{\"name\":\"anchorBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"difficulty\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blobHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"extraData\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"coinbase\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"id\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"gasLimit\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"timestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"anchorBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"minTier\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"blobUsed\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"parentMetaHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"livenessBond\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"proposedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"proposedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobTxListOffset\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobTxListLength\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobIndex\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"baseFeeConfig\",\"type\":\"tuple\",\"internalType\":\"structLibSharedData.BaseFeeConfig\",\"components\":[{\"name\":\"adjustmentQuotient\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"gasIssuancePerSecond\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"minGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxGasIssuancePerBlock\",\"type\":\"uint32\",\"internalType\":\"uint32\"}]}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BlockVerified\",\"inputs\":[{\"name\":\"blockId\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"prover\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"tier\",\"type\":\"uint16\",\"indexed\":false,\"internalType\":\"uint16\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BlockVerifiedV2\",\"inputs\":[{\"name\":\"blockId\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"prover\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"tier\",\"type\":\"uint16\",\"indexed\":false,\"internalType\":\"uint16\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BlockVerifiedV2\",\"inputs\":[{\"name\":\"blockId\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"prover\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"tier\",\"type\":\"uint16\",\"indexed\":false,\"internalType\":\"uint16\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondCredited\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"blockId\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondCredited\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"blockId\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondDebited\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"blockId\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondDebited\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"blockId\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondDeposited\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondDeposited\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondWithdrawn\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"CalldataTxList\",\"inputs\":[{\"name\":\"blockId\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"txList\",\"type\":\"bytes\",\"indexed\":false,\"internalType\":\"bytes\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"CalldataTxList\",\"inputs\":[{\"name\":\"blockId\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"txList\",\"type\":\"bytes\",\"indexed\":false,\"internalType\":\"bytes\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ProvingPaused\",\"inputs\":[{\"name\":\"paused\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"StateVariablesUpdated\",\"inputs\":[{\"name\":\"slotB\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structTaikoData.SlotB\",\"components\":[{\"name\":\"numBlocks\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastVerifiedBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"provingPaused\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"lastProposedIn\",\"type\":\"uint56\",\"internalType\":\"uint56\"},{\"name\":\"lastUnpausedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransitionContested\",\"inputs\":[{\"name\":\"blockId\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"tran\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structTaikoData.Transition\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"graffiti\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"contester\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"contestBond\",\"type\":\"uint96\",\"indexed\":false,\"internalType\":\"uint96\"},{\"name\":\"tier\",\"type\":\"uint16\",\"indexed\":false,\"internalType\":\"uint16\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransitionContestedV2\",\"inputs\":[{\"name\":\"blockId\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"tran\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structTaikoData.Transition\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"graffiti\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"contester\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"contestBond\",\"type\":\"uint96\",\"indexed\":false,\"internalType\":\"uint96\"},{\"name\":\"tier\",\"type\":\"uint16\",\"indexed\":false,\"internalType\":\"uint16\"},{\"name\":\"proposedIn\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransitionProved\",\"inputs\":[{\"name\":\"blockId\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"tran\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structTaikoData.Transition\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"graffiti\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"prover\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"validityBond\",\"type\":\"uint96\",\"indexed\":false,\"internalType\":\"uint96\"},{\"name\":\"tier\",\"type\":\"uint16\",\"indexed\":false,\"internalType\":\"uint16\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransitionProvedV2\",\"inputs\":[{\"name\":\"blockId\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"tran\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structTaikoData.Transition\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"graffiti\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"prover\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"validityBond\",\"type\":\"uint96\",\"indexed\":false,\"internalType\":\"uint96\"},{\"name\":\"tier\",\"type\":\"uint16\",\"indexed\":false,\"internalType\":\"uint16\"},{\"name\":\"proposedIn\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"FUNC_NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_BLOB_NOT_AVAILABLE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_BLOB_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_BLOCK_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_ETH_NOT_PAID_AS_BOND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_FORK_HEIGHT_ERROR\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_FORK_HEIGHT_ERROR\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_INVALID_ANCHOR_BLOCK\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_INVALID_BLOCK_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_INVALID_CUSTOM_PROPOSER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_INVALID_MSG_VALUE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_INVALID_PARAMS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_INVALID_PROPOSER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_INVALID_TIMESTAMP\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_PROVING_PAUSED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_TOO_MANY_BLOCKS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_TRANSITION_ID_ZERO\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_TRANSITION_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_UNEXPECTED_PARENT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_UNEXPECTED_TRANSITION_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_INVALID_MANAGER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_UNEXPECTED_CHAINID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_ZERO_ADDR\",\"inputs\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_VALUE\",\"inputs\":[]}]",
}

// TaikoL1ABI is the input ABI used to generate the binding from.
// Deprecated: Use TaikoL1MetaData.ABI instead.
var TaikoL1ABI = TaikoL1MetaData.ABI

// TaikoL1 is an auto generated Go binding around an Ethereum contract.
type TaikoL1 struct {
	TaikoL1Caller     // Read-only binding to the contract
	TaikoL1Transactor // Write-only binding to the contract
	TaikoL1Filterer   // Log filterer for contract events
}

// TaikoL1Caller is an auto generated read-only Go binding around an Ethereum contract.
type TaikoL1Caller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoL1Transactor is an auto generated write-only Go binding around an Ethereum contract.
type TaikoL1Transactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoL1Filterer is an auto generated log filtering Go binding around an Ethereum contract events.
type TaikoL1Filterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoL1Session is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type TaikoL1Session struct {
	Contract     *TaikoL1          // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// TaikoL1CallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type TaikoL1CallerSession struct {
	Contract *TaikoL1Caller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts  // Call options to use throughout this session
}

// TaikoL1TransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type TaikoL1TransactorSession struct {
	Contract     *TaikoL1Transactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts  // Transaction auth options to use throughout this session
}

// TaikoL1Raw is an auto generated low-level Go binding around an Ethereum contract.
type TaikoL1Raw struct {
	Contract *TaikoL1 // Generic contract binding to access the raw methods on
}

// TaikoL1CallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type TaikoL1CallerRaw struct {
	Contract *TaikoL1Caller // Generic read-only contract binding to access the raw methods on
}

// TaikoL1TransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type TaikoL1TransactorRaw struct {
	Contract *TaikoL1Transactor // Generic write-only contract binding to access the raw methods on
}

// NewTaikoL1 creates a new instance of TaikoL1, bound to a specific deployed contract.
func NewTaikoL1(address common.Address, backend bind.ContractBackend) (*TaikoL1, error) {
	contract, err := bindTaikoL1(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &TaikoL1{TaikoL1Caller: TaikoL1Caller{contract: contract}, TaikoL1Transactor: TaikoL1Transactor{contract: contract}, TaikoL1Filterer: TaikoL1Filterer{contract: contract}}, nil
}

// NewTaikoL1Caller creates a new read-only instance of TaikoL1, bound to a specific deployed contract.
func NewTaikoL1Caller(address common.Address, caller bind.ContractCaller) (*TaikoL1Caller, error) {
	contract, err := bindTaikoL1(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &TaikoL1Caller{contract: contract}, nil
}

// NewTaikoL1Transactor creates a new write-only instance of TaikoL1, bound to a specific deployed contract.
func NewTaikoL1Transactor(address common.Address, transactor bind.ContractTransactor) (*TaikoL1Transactor, error) {
	contract, err := bindTaikoL1(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &TaikoL1Transactor{contract: contract}, nil
}

// NewTaikoL1Filterer creates a new log filterer instance of TaikoL1, bound to a specific deployed contract.
func NewTaikoL1Filterer(address common.Address, filterer bind.ContractFilterer) (*TaikoL1Filterer, error) {
	contract, err := bindTaikoL1(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &TaikoL1Filterer{contract: contract}, nil
}

// bindTaikoL1 binds a generic wrapper to an already deployed contract.
func bindTaikoL1(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := TaikoL1MetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TaikoL1 *TaikoL1Raw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TaikoL1.Contract.TaikoL1Caller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TaikoL1 *TaikoL1Raw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL1.Contract.TaikoL1Transactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TaikoL1 *TaikoL1Raw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TaikoL1.Contract.TaikoL1Transactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TaikoL1 *TaikoL1CallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TaikoL1.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TaikoL1 *TaikoL1TransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL1.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TaikoL1 *TaikoL1TransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TaikoL1.Contract.contract.Transact(opts, method, params...)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_TaikoL1 *TaikoL1Caller) AddressManager(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "addressManager")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_TaikoL1 *TaikoL1Session) AddressManager() (common.Address, error) {
	return _TaikoL1.Contract.AddressManager(&_TaikoL1.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_TaikoL1 *TaikoL1CallerSession) AddressManager() (common.Address, error) {
	return _TaikoL1.Contract.AddressManager(&_TaikoL1.CallOpts)
}

// BondBalanceOf is a free data retrieval call binding the contract method 0xa9c2c835.
//
// Solidity: function bondBalanceOf(address _user) view returns(uint256)
func (_TaikoL1 *TaikoL1Caller) BondBalanceOf(opts *bind.CallOpts, _user common.Address) (*big.Int, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "bondBalanceOf", _user)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// BondBalanceOf is a free data retrieval call binding the contract method 0xa9c2c835.
//
// Solidity: function bondBalanceOf(address _user) view returns(uint256)
func (_TaikoL1 *TaikoL1Session) BondBalanceOf(_user common.Address) (*big.Int, error) {
	return _TaikoL1.Contract.BondBalanceOf(&_TaikoL1.CallOpts, _user)
}

// BondBalanceOf is a free data retrieval call binding the contract method 0xa9c2c835.
//
// Solidity: function bondBalanceOf(address _user) view returns(uint256)
func (_TaikoL1 *TaikoL1CallerSession) BondBalanceOf(_user common.Address) (*big.Int, error) {
	return _TaikoL1.Contract.BondBalanceOf(&_TaikoL1.CallOpts, _user)
}

// GetBlock is a free data retrieval call binding the contract method 0x5fa15e79.
//
// Solidity: function getBlock(uint64 _blockId) view returns((bytes32,address,uint96,uint64,uint64,uint64,uint32,uint32) blk_)
func (_TaikoL1 *TaikoL1Caller) GetBlock(opts *bind.CallOpts, _blockId uint64) (TaikoDataBlock, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getBlock", _blockId)

	if err != nil {
		return *new(TaikoDataBlock), err
	}

	out0 := *abi.ConvertType(out[0], new(TaikoDataBlock)).(*TaikoDataBlock)

	return out0, err

}

// GetBlock is a free data retrieval call binding the contract method 0x5fa15e79.
//
// Solidity: function getBlock(uint64 _blockId) view returns((bytes32,address,uint96,uint64,uint64,uint64,uint32,uint32) blk_)
func (_TaikoL1 *TaikoL1Session) GetBlock(_blockId uint64) (TaikoDataBlock, error) {
	return _TaikoL1.Contract.GetBlock(&_TaikoL1.CallOpts, _blockId)
}

// GetBlock is a free data retrieval call binding the contract method 0x5fa15e79.
//
// Solidity: function getBlock(uint64 _blockId) view returns((bytes32,address,uint96,uint64,uint64,uint64,uint32,uint32) blk_)
func (_TaikoL1 *TaikoL1CallerSession) GetBlock(_blockId uint64) (TaikoDataBlock, error) {
	return _TaikoL1.Contract.GetBlock(&_TaikoL1.CallOpts, _blockId)
}

// GetBlockV2 is a free data retrieval call binding the contract method 0x3f0c544a.
//
// Solidity: function getBlockV2(uint64 _blockId) view returns((bytes32,address,uint96,uint64,uint64,uint64,uint24,bool,uint24) blk_)
func (_TaikoL1 *TaikoL1Caller) GetBlockV2(opts *bind.CallOpts, _blockId uint64) (TaikoDataBlockV2, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getBlockV2", _blockId)

	if err != nil {
		return *new(TaikoDataBlockV2), err
	}

	out0 := *abi.ConvertType(out[0], new(TaikoDataBlockV2)).(*TaikoDataBlockV2)

	return out0, err

}

// GetBlockV2 is a free data retrieval call binding the contract method 0x3f0c544a.
//
// Solidity: function getBlockV2(uint64 _blockId) view returns((bytes32,address,uint96,uint64,uint64,uint64,uint24,bool,uint24) blk_)
func (_TaikoL1 *TaikoL1Session) GetBlockV2(_blockId uint64) (TaikoDataBlockV2, error) {
	return _TaikoL1.Contract.GetBlockV2(&_TaikoL1.CallOpts, _blockId)
}

// GetBlockV2 is a free data retrieval call binding the contract method 0x3f0c544a.
//
// Solidity: function getBlockV2(uint64 _blockId) view returns((bytes32,address,uint96,uint64,uint64,uint64,uint24,bool,uint24) blk_)
func (_TaikoL1 *TaikoL1CallerSession) GetBlockV2(_blockId uint64) (TaikoDataBlockV2, error) {
	return _TaikoL1.Contract.GetBlockV2(&_TaikoL1.CallOpts, _blockId)
}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() pure returns((uint64,uint64,uint64,uint64,uint32,uint96,uint8,uint64,(uint8,uint8,uint32,uint64,uint32),uint64))
func (_TaikoL1 *TaikoL1Caller) GetConfig(opts *bind.CallOpts) (TaikoDataConfig, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getConfig")

	if err != nil {
		return *new(TaikoDataConfig), err
	}

	out0 := *abi.ConvertType(out[0], new(TaikoDataConfig)).(*TaikoDataConfig)

	return out0, err

}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() pure returns((uint64,uint64,uint64,uint64,uint32,uint96,uint8,uint64,(uint8,uint8,uint32,uint64,uint32),uint64))
func (_TaikoL1 *TaikoL1Session) GetConfig() (TaikoDataConfig, error) {
	return _TaikoL1.Contract.GetConfig(&_TaikoL1.CallOpts)
}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() pure returns((uint64,uint64,uint64,uint64,uint32,uint96,uint8,uint64,(uint8,uint8,uint32,uint64,uint32),uint64))
func (_TaikoL1 *TaikoL1CallerSession) GetConfig() (TaikoDataConfig, error) {
	return _TaikoL1.Contract.GetConfig(&_TaikoL1.CallOpts)
}

// GetLastSyncedBlock is a free data retrieval call binding the contract method 0x9413caa9.
//
// Solidity: function getLastSyncedBlock() view returns(uint64 blockId_, bytes32 blockHash_, bytes32 stateRoot_, uint64 verifiedAt_)
func (_TaikoL1 *TaikoL1Caller) GetLastSyncedBlock(opts *bind.CallOpts) (struct {
	BlockId    uint64
	BlockHash  [32]byte
	StateRoot  [32]byte
	VerifiedAt uint64
}, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getLastSyncedBlock")

	outstruct := new(struct {
		BlockId    uint64
		BlockHash  [32]byte
		StateRoot  [32]byte
		VerifiedAt uint64
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.BlockId = *abi.ConvertType(out[0], new(uint64)).(*uint64)
	outstruct.BlockHash = *abi.ConvertType(out[1], new([32]byte)).(*[32]byte)
	outstruct.StateRoot = *abi.ConvertType(out[2], new([32]byte)).(*[32]byte)
	outstruct.VerifiedAt = *abi.ConvertType(out[3], new(uint64)).(*uint64)

	return *outstruct, err

}

// GetLastSyncedBlock is a free data retrieval call binding the contract method 0x9413caa9.
//
// Solidity: function getLastSyncedBlock() view returns(uint64 blockId_, bytes32 blockHash_, bytes32 stateRoot_, uint64 verifiedAt_)
func (_TaikoL1 *TaikoL1Session) GetLastSyncedBlock() (struct {
	BlockId    uint64
	BlockHash  [32]byte
	StateRoot  [32]byte
	VerifiedAt uint64
}, error) {
	return _TaikoL1.Contract.GetLastSyncedBlock(&_TaikoL1.CallOpts)
}

// GetLastSyncedBlock is a free data retrieval call binding the contract method 0x9413caa9.
//
// Solidity: function getLastSyncedBlock() view returns(uint64 blockId_, bytes32 blockHash_, bytes32 stateRoot_, uint64 verifiedAt_)
func (_TaikoL1 *TaikoL1CallerSession) GetLastSyncedBlock() (struct {
	BlockId    uint64
	BlockHash  [32]byte
	StateRoot  [32]byte
	VerifiedAt uint64
}, error) {
	return _TaikoL1.Contract.GetLastSyncedBlock(&_TaikoL1.CallOpts)
}

// GetLastVerifiedBlock is a free data retrieval call binding the contract method 0x26af7986.
//
// Solidity: function getLastVerifiedBlock() view returns(uint64 blockId_, bytes32 blockHash_, bytes32 stateRoot_, uint64 verifiedAt_)
func (_TaikoL1 *TaikoL1Caller) GetLastVerifiedBlock(opts *bind.CallOpts) (struct {
	BlockId    uint64
	BlockHash  [32]byte
	StateRoot  [32]byte
	VerifiedAt uint64
}, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getLastVerifiedBlock")

	outstruct := new(struct {
		BlockId    uint64
		BlockHash  [32]byte
		StateRoot  [32]byte
		VerifiedAt uint64
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.BlockId = *abi.ConvertType(out[0], new(uint64)).(*uint64)
	outstruct.BlockHash = *abi.ConvertType(out[1], new([32]byte)).(*[32]byte)
	outstruct.StateRoot = *abi.ConvertType(out[2], new([32]byte)).(*[32]byte)
	outstruct.VerifiedAt = *abi.ConvertType(out[3], new(uint64)).(*uint64)

	return *outstruct, err

}

// GetLastVerifiedBlock is a free data retrieval call binding the contract method 0x26af7986.
//
// Solidity: function getLastVerifiedBlock() view returns(uint64 blockId_, bytes32 blockHash_, bytes32 stateRoot_, uint64 verifiedAt_)
func (_TaikoL1 *TaikoL1Session) GetLastVerifiedBlock() (struct {
	BlockId    uint64
	BlockHash  [32]byte
	StateRoot  [32]byte
	VerifiedAt uint64
}, error) {
	return _TaikoL1.Contract.GetLastVerifiedBlock(&_TaikoL1.CallOpts)
}

// GetLastVerifiedBlock is a free data retrieval call binding the contract method 0x26af7986.
//
// Solidity: function getLastVerifiedBlock() view returns(uint64 blockId_, bytes32 blockHash_, bytes32 stateRoot_, uint64 verifiedAt_)
func (_TaikoL1 *TaikoL1CallerSession) GetLastVerifiedBlock() (struct {
	BlockId    uint64
	BlockHash  [32]byte
	StateRoot  [32]byte
	VerifiedAt uint64
}, error) {
	return _TaikoL1.Contract.GetLastVerifiedBlock(&_TaikoL1.CallOpts)
}

// GetStateVariables is a free data retrieval call binding the contract method 0xdde89cf5.
//
// Solidity: function getStateVariables() view returns((uint64,uint64,uint64,uint64), (uint64,uint64,bool,uint56,uint64))
func (_TaikoL1 *TaikoL1Caller) GetStateVariables(opts *bind.CallOpts) (TaikoDataSlotA, TaikoDataSlotB, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getStateVariables")

	if err != nil {
		return *new(TaikoDataSlotA), *new(TaikoDataSlotB), err
	}

	out0 := *abi.ConvertType(out[0], new(TaikoDataSlotA)).(*TaikoDataSlotA)
	out1 := *abi.ConvertType(out[1], new(TaikoDataSlotB)).(*TaikoDataSlotB)

	return out0, out1, err

}

// GetStateVariables is a free data retrieval call binding the contract method 0xdde89cf5.
//
// Solidity: function getStateVariables() view returns((uint64,uint64,uint64,uint64), (uint64,uint64,bool,uint56,uint64))
func (_TaikoL1 *TaikoL1Session) GetStateVariables() (TaikoDataSlotA, TaikoDataSlotB, error) {
	return _TaikoL1.Contract.GetStateVariables(&_TaikoL1.CallOpts)
}

// GetStateVariables is a free data retrieval call binding the contract method 0xdde89cf5.
//
// Solidity: function getStateVariables() view returns((uint64,uint64,uint64,uint64), (uint64,uint64,bool,uint56,uint64))
func (_TaikoL1 *TaikoL1CallerSession) GetStateVariables() (TaikoDataSlotA, TaikoDataSlotB, error) {
	return _TaikoL1.Contract.GetStateVariables(&_TaikoL1.CallOpts)
}

// GetTransition is a free data retrieval call binding the contract method 0x563479a5.
//
// Solidity: function getTransition(uint64 _blockId, uint32 _tid) view returns((bytes32,bytes32,bytes32,address,uint96,address,uint96,uint64,uint16,uint8))
func (_TaikoL1 *TaikoL1Caller) GetTransition(opts *bind.CallOpts, _blockId uint64, _tid uint32) (TaikoDataTransitionState, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getTransition", _blockId, _tid)

	if err != nil {
		return *new(TaikoDataTransitionState), err
	}

	out0 := *abi.ConvertType(out[0], new(TaikoDataTransitionState)).(*TaikoDataTransitionState)

	return out0, err

}

// GetTransition is a free data retrieval call binding the contract method 0x563479a5.
//
// Solidity: function getTransition(uint64 _blockId, uint32 _tid) view returns((bytes32,bytes32,bytes32,address,uint96,address,uint96,uint64,uint16,uint8))
func (_TaikoL1 *TaikoL1Session) GetTransition(_blockId uint64, _tid uint32) (TaikoDataTransitionState, error) {
	return _TaikoL1.Contract.GetTransition(&_TaikoL1.CallOpts, _blockId, _tid)
}

// GetTransition is a free data retrieval call binding the contract method 0x563479a5.
//
// Solidity: function getTransition(uint64 _blockId, uint32 _tid) view returns((bytes32,bytes32,bytes32,address,uint96,address,uint96,uint64,uint16,uint8))
func (_TaikoL1 *TaikoL1CallerSession) GetTransition(_blockId uint64, _tid uint32) (TaikoDataTransitionState, error) {
	return _TaikoL1.Contract.GetTransition(&_TaikoL1.CallOpts, _blockId, _tid)
}

// GetTransition0 is a free data retrieval call binding the contract method 0xfd257e29.
//
// Solidity: function getTransition(uint64 _blockId, bytes32 _parentHash) view returns((bytes32,bytes32,bytes32,address,uint96,address,uint96,uint64,uint16,uint8))
func (_TaikoL1 *TaikoL1Caller) GetTransition0(opts *bind.CallOpts, _blockId uint64, _parentHash [32]byte) (TaikoDataTransitionState, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getTransition0", _blockId, _parentHash)

	if err != nil {
		return *new(TaikoDataTransitionState), err
	}

	out0 := *abi.ConvertType(out[0], new(TaikoDataTransitionState)).(*TaikoDataTransitionState)

	return out0, err

}

// GetTransition0 is a free data retrieval call binding the contract method 0xfd257e29.
//
// Solidity: function getTransition(uint64 _blockId, bytes32 _parentHash) view returns((bytes32,bytes32,bytes32,address,uint96,address,uint96,uint64,uint16,uint8))
func (_TaikoL1 *TaikoL1Session) GetTransition0(_blockId uint64, _parentHash [32]byte) (TaikoDataTransitionState, error) {
	return _TaikoL1.Contract.GetTransition0(&_TaikoL1.CallOpts, _blockId, _parentHash)
}

// GetTransition0 is a free data retrieval call binding the contract method 0xfd257e29.
//
// Solidity: function getTransition(uint64 _blockId, bytes32 _parentHash) view returns((bytes32,bytes32,bytes32,address,uint96,address,uint96,uint64,uint16,uint8))
func (_TaikoL1 *TaikoL1CallerSession) GetTransition0(_blockId uint64, _parentHash [32]byte) (TaikoDataTransitionState, error) {
	return _TaikoL1.Contract.GetTransition0(&_TaikoL1.CallOpts, _blockId, _parentHash)
}

// GetTransitions is a free data retrieval call binding the contract method 0xb89c61bc.
//
// Solidity: function getTransitions(uint64[] _blockIds, bytes32[] _parentHashes) view returns((bytes32,bytes32,bytes32,address,uint96,address,uint96,uint64,uint16,uint8)[])
func (_TaikoL1 *TaikoL1Caller) GetTransitions(opts *bind.CallOpts, _blockIds []uint64, _parentHashes [][32]byte) ([]TaikoDataTransitionState, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getTransitions", _blockIds, _parentHashes)

	if err != nil {
		return *new([]TaikoDataTransitionState), err
	}

	out0 := *abi.ConvertType(out[0], new([]TaikoDataTransitionState)).(*[]TaikoDataTransitionState)

	return out0, err

}

// GetTransitions is a free data retrieval call binding the contract method 0xb89c61bc.
//
// Solidity: function getTransitions(uint64[] _blockIds, bytes32[] _parentHashes) view returns((bytes32,bytes32,bytes32,address,uint96,address,uint96,uint64,uint16,uint8)[])
func (_TaikoL1 *TaikoL1Session) GetTransitions(_blockIds []uint64, _parentHashes [][32]byte) ([]TaikoDataTransitionState, error) {
	return _TaikoL1.Contract.GetTransitions(&_TaikoL1.CallOpts, _blockIds, _parentHashes)
}

// GetTransitions is a free data retrieval call binding the contract method 0xb89c61bc.
//
// Solidity: function getTransitions(uint64[] _blockIds, bytes32[] _parentHashes) view returns((bytes32,bytes32,bytes32,address,uint96,address,uint96,uint64,uint16,uint8)[])
func (_TaikoL1 *TaikoL1CallerSession) GetTransitions(_blockIds []uint64, _parentHashes [][32]byte) ([]TaikoDataTransitionState, error) {
	return _TaikoL1.Contract.GetTransitions(&_TaikoL1.CallOpts, _blockIds, _parentHashes)
}

// GetVerifiedBlockProver is a free data retrieval call binding the contract method 0x6074b8c1.
//
// Solidity: function getVerifiedBlockProver(uint64 _blockId) view returns(address prover_)
func (_TaikoL1 *TaikoL1Caller) GetVerifiedBlockProver(opts *bind.CallOpts, _blockId uint64) (common.Address, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getVerifiedBlockProver", _blockId)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetVerifiedBlockProver is a free data retrieval call binding the contract method 0x6074b8c1.
//
// Solidity: function getVerifiedBlockProver(uint64 _blockId) view returns(address prover_)
func (_TaikoL1 *TaikoL1Session) GetVerifiedBlockProver(_blockId uint64) (common.Address, error) {
	return _TaikoL1.Contract.GetVerifiedBlockProver(&_TaikoL1.CallOpts, _blockId)
}

// GetVerifiedBlockProver is a free data retrieval call binding the contract method 0x6074b8c1.
//
// Solidity: function getVerifiedBlockProver(uint64 _blockId) view returns(address prover_)
func (_TaikoL1 *TaikoL1CallerSession) GetVerifiedBlockProver(_blockId uint64) (common.Address, error) {
	return _TaikoL1.Contract.GetVerifiedBlockProver(&_TaikoL1.CallOpts, _blockId)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_TaikoL1 *TaikoL1Caller) Impl(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "impl")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_TaikoL1 *TaikoL1Session) Impl() (common.Address, error) {
	return _TaikoL1.Contract.Impl(&_TaikoL1.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_TaikoL1 *TaikoL1CallerSession) Impl() (common.Address, error) {
	return _TaikoL1.Contract.Impl(&_TaikoL1.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_TaikoL1 *TaikoL1Caller) InNonReentrant(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "inNonReentrant")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_TaikoL1 *TaikoL1Session) InNonReentrant() (bool, error) {
	return _TaikoL1.Contract.InNonReentrant(&_TaikoL1.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_TaikoL1 *TaikoL1CallerSession) InNonReentrant() (bool, error) {
	return _TaikoL1.Contract.InNonReentrant(&_TaikoL1.CallOpts)
}

// LastProposedIn is a free data retrieval call binding the contract method 0x5979f17c.
//
// Solidity: function lastProposedIn() view returns(uint56)
func (_TaikoL1 *TaikoL1Caller) LastProposedIn(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "lastProposedIn")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// LastProposedIn is a free data retrieval call binding the contract method 0x5979f17c.
//
// Solidity: function lastProposedIn() view returns(uint56)
func (_TaikoL1 *TaikoL1Session) LastProposedIn() (*big.Int, error) {
	return _TaikoL1.Contract.LastProposedIn(&_TaikoL1.CallOpts)
}

// LastProposedIn is a free data retrieval call binding the contract method 0x5979f17c.
//
// Solidity: function lastProposedIn() view returns(uint56)
func (_TaikoL1 *TaikoL1CallerSession) LastProposedIn() (*big.Int, error) {
	return _TaikoL1.Contract.LastProposedIn(&_TaikoL1.CallOpts)
}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_TaikoL1 *TaikoL1Caller) LastUnpausedAt(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "lastUnpausedAt")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_TaikoL1 *TaikoL1Session) LastUnpausedAt() (uint64, error) {
	return _TaikoL1.Contract.LastUnpausedAt(&_TaikoL1.CallOpts)
}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_TaikoL1 *TaikoL1CallerSession) LastUnpausedAt() (uint64, error) {
	return _TaikoL1.Contract.LastUnpausedAt(&_TaikoL1.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoL1 *TaikoL1Caller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoL1 *TaikoL1Session) Owner() (common.Address, error) {
	return _TaikoL1.Contract.Owner(&_TaikoL1.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoL1 *TaikoL1CallerSession) Owner() (common.Address, error) {
	return _TaikoL1.Contract.Owner(&_TaikoL1.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_TaikoL1 *TaikoL1Caller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_TaikoL1 *TaikoL1Session) Paused() (bool, error) {
	return _TaikoL1.Contract.Paused(&_TaikoL1.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_TaikoL1 *TaikoL1CallerSession) Paused() (bool, error) {
	return _TaikoL1.Contract.Paused(&_TaikoL1.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_TaikoL1 *TaikoL1Caller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_TaikoL1 *TaikoL1Session) PendingOwner() (common.Address, error) {
	return _TaikoL1.Contract.PendingOwner(&_TaikoL1.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_TaikoL1 *TaikoL1CallerSession) PendingOwner() (common.Address, error) {
	return _TaikoL1.Contract.PendingOwner(&_TaikoL1.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_TaikoL1 *TaikoL1Caller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_TaikoL1 *TaikoL1Session) ProxiableUUID() ([32]byte, error) {
	return _TaikoL1.Contract.ProxiableUUID(&_TaikoL1.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_TaikoL1 *TaikoL1CallerSession) ProxiableUUID() ([32]byte, error) {
	return _TaikoL1.Contract.ProxiableUUID(&_TaikoL1.CallOpts)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_TaikoL1 *TaikoL1Caller) Resolve(opts *bind.CallOpts, _chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "resolve", _chainId, _name, _allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_TaikoL1 *TaikoL1Session) Resolve(_chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _TaikoL1.Contract.Resolve(&_TaikoL1.CallOpts, _chainId, _name, _allowZeroAddress)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_TaikoL1 *TaikoL1CallerSession) Resolve(_chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _TaikoL1.Contract.Resolve(&_TaikoL1.CallOpts, _chainId, _name, _allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_TaikoL1 *TaikoL1Caller) Resolve0(opts *bind.CallOpts, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "resolve0", _name, _allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_TaikoL1 *TaikoL1Session) Resolve0(_name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _TaikoL1.Contract.Resolve0(&_TaikoL1.CallOpts, _name, _allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_TaikoL1 *TaikoL1CallerSession) Resolve0(_name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _TaikoL1.Contract.Resolve0(&_TaikoL1.CallOpts, _name, _allowZeroAddress)
}

// State is a free data retrieval call binding the contract method 0xc19d93fb.
//
// Solidity: function state() view returns(bytes32 __reserve1, (uint64,uint64,uint64,uint64) slotA, (uint64,uint64,bool,uint56,uint64) slotB)
func (_TaikoL1 *TaikoL1Caller) State(opts *bind.CallOpts) (struct {
	Reserve1 [32]byte
	SlotA    TaikoDataSlotA
	SlotB    TaikoDataSlotB
}, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "state")

	outstruct := new(struct {
		Reserve1 [32]byte
		SlotA    TaikoDataSlotA
		SlotB    TaikoDataSlotB
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Reserve1 = *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)
	outstruct.SlotA = *abi.ConvertType(out[1], new(TaikoDataSlotA)).(*TaikoDataSlotA)
	outstruct.SlotB = *abi.ConvertType(out[2], new(TaikoDataSlotB)).(*TaikoDataSlotB)

	return *outstruct, err

}

// State is a free data retrieval call binding the contract method 0xc19d93fb.
//
// Solidity: function state() view returns(bytes32 __reserve1, (uint64,uint64,uint64,uint64) slotA, (uint64,uint64,bool,uint56,uint64) slotB)
func (_TaikoL1 *TaikoL1Session) State() (struct {
	Reserve1 [32]byte
	SlotA    TaikoDataSlotA
	SlotB    TaikoDataSlotB
}, error) {
	return _TaikoL1.Contract.State(&_TaikoL1.CallOpts)
}

// State is a free data retrieval call binding the contract method 0xc19d93fb.
//
// Solidity: function state() view returns(bytes32 __reserve1, (uint64,uint64,uint64,uint64) slotA, (uint64,uint64,bool,uint56,uint64) slotB)
func (_TaikoL1 *TaikoL1CallerSession) State() (struct {
	Reserve1 [32]byte
	SlotA    TaikoDataSlotA
	SlotB    TaikoDataSlotB
}, error) {
	return _TaikoL1.Contract.State(&_TaikoL1.CallOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_TaikoL1 *TaikoL1Transactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_TaikoL1 *TaikoL1Session) AcceptOwnership() (*types.Transaction, error) {
	return _TaikoL1.Contract.AcceptOwnership(&_TaikoL1.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_TaikoL1 *TaikoL1TransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _TaikoL1.Contract.AcceptOwnership(&_TaikoL1.TransactOpts)
}

// DepositBond is a paid mutator transaction binding the contract method 0x4dcb05f9.
//
// Solidity: function depositBond(uint256 _amount) payable returns()
func (_TaikoL1 *TaikoL1Transactor) DepositBond(opts *bind.TransactOpts, _amount *big.Int) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "depositBond", _amount)
}

// DepositBond is a paid mutator transaction binding the contract method 0x4dcb05f9.
//
// Solidity: function depositBond(uint256 _amount) payable returns()
func (_TaikoL1 *TaikoL1Session) DepositBond(_amount *big.Int) (*types.Transaction, error) {
	return _TaikoL1.Contract.DepositBond(&_TaikoL1.TransactOpts, _amount)
}

// DepositBond is a paid mutator transaction binding the contract method 0x4dcb05f9.
//
// Solidity: function depositBond(uint256 _amount) payable returns()
func (_TaikoL1 *TaikoL1TransactorSession) DepositBond(_amount *big.Int) (*types.Transaction, error) {
	return _TaikoL1.Contract.DepositBond(&_TaikoL1.TransactOpts, _amount)
}

// Init is a paid mutator transaction binding the contract method 0x29d1b62f.
//
// Solidity: function init(address _owner, address _rollupAddressManager, bytes32 _genesisBlockHash, bool _toPause) returns()
func (_TaikoL1 *TaikoL1Transactor) Init(opts *bind.TransactOpts, _owner common.Address, _rollupAddressManager common.Address, _genesisBlockHash [32]byte, _toPause bool) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "init", _owner, _rollupAddressManager, _genesisBlockHash, _toPause)
}

// Init is a paid mutator transaction binding the contract method 0x29d1b62f.
//
// Solidity: function init(address _owner, address _rollupAddressManager, bytes32 _genesisBlockHash, bool _toPause) returns()
func (_TaikoL1 *TaikoL1Session) Init(_owner common.Address, _rollupAddressManager common.Address, _genesisBlockHash [32]byte, _toPause bool) (*types.Transaction, error) {
	return _TaikoL1.Contract.Init(&_TaikoL1.TransactOpts, _owner, _rollupAddressManager, _genesisBlockHash, _toPause)
}

// Init is a paid mutator transaction binding the contract method 0x29d1b62f.
//
// Solidity: function init(address _owner, address _rollupAddressManager, bytes32 _genesisBlockHash, bool _toPause) returns()
func (_TaikoL1 *TaikoL1TransactorSession) Init(_owner common.Address, _rollupAddressManager common.Address, _genesisBlockHash [32]byte, _toPause bool) (*types.Transaction, error) {
	return _TaikoL1.Contract.Init(&_TaikoL1.TransactOpts, _owner, _rollupAddressManager, _genesisBlockHash, _toPause)
}

// Init2 is a paid mutator transaction binding the contract method 0x069489a2.
//
// Solidity: function init2() returns()
func (_TaikoL1 *TaikoL1Transactor) Init2(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "init2")
}

// Init2 is a paid mutator transaction binding the contract method 0x069489a2.
//
// Solidity: function init2() returns()
func (_TaikoL1 *TaikoL1Session) Init2() (*types.Transaction, error) {
	return _TaikoL1.Contract.Init2(&_TaikoL1.TransactOpts)
}

// Init2 is a paid mutator transaction binding the contract method 0x069489a2.
//
// Solidity: function init2() returns()
func (_TaikoL1 *TaikoL1TransactorSession) Init2() (*types.Transaction, error) {
	return _TaikoL1.Contract.Init2(&_TaikoL1.TransactOpts)
}

// Init3 is a paid mutator transaction binding the contract method 0x486e3cd7.
//
// Solidity: function init3() returns()
func (_TaikoL1 *TaikoL1Transactor) Init3(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "init3")
}

// Init3 is a paid mutator transaction binding the contract method 0x486e3cd7.
//
// Solidity: function init3() returns()
func (_TaikoL1 *TaikoL1Session) Init3() (*types.Transaction, error) {
	return _TaikoL1.Contract.Init3(&_TaikoL1.TransactOpts)
}

// Init3 is a paid mutator transaction binding the contract method 0x486e3cd7.
//
// Solidity: function init3() returns()
func (_TaikoL1 *TaikoL1TransactorSession) Init3() (*types.Transaction, error) {
	return _TaikoL1.Contract.Init3(&_TaikoL1.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_TaikoL1 *TaikoL1Transactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_TaikoL1 *TaikoL1Session) Pause() (*types.Transaction, error) {
	return _TaikoL1.Contract.Pause(&_TaikoL1.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_TaikoL1 *TaikoL1TransactorSession) Pause() (*types.Transaction, error) {
	return _TaikoL1.Contract.Pause(&_TaikoL1.TransactOpts)
}

// PauseProving is a paid mutator transaction binding the contract method 0xff00c391.
//
// Solidity: function pauseProving(bool _pause) returns()
func (_TaikoL1 *TaikoL1Transactor) PauseProving(opts *bind.TransactOpts, _pause bool) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "pauseProving", _pause)
}

// PauseProving is a paid mutator transaction binding the contract method 0xff00c391.
//
// Solidity: function pauseProving(bool _pause) returns()
func (_TaikoL1 *TaikoL1Session) PauseProving(_pause bool) (*types.Transaction, error) {
	return _TaikoL1.Contract.PauseProving(&_TaikoL1.TransactOpts, _pause)
}

// PauseProving is a paid mutator transaction binding the contract method 0xff00c391.
//
// Solidity: function pauseProving(bool _pause) returns()
func (_TaikoL1 *TaikoL1TransactorSession) PauseProving(_pause bool) (*types.Transaction, error) {
	return _TaikoL1.Contract.PauseProving(&_TaikoL1.TransactOpts, _pause)
}

// ProposeBlockV2 is a paid mutator transaction binding the contract method 0x648885fb.
//
// Solidity: function proposeBlockV2(bytes _params, bytes _txList) returns((bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint16,bool,bytes32,address,uint96,uint64,uint64,uint32,uint32,uint8,(uint8,uint8,uint32,uint64,uint32)) meta_)
func (_TaikoL1 *TaikoL1Transactor) ProposeBlockV2(opts *bind.TransactOpts, _params []byte, _txList []byte) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "proposeBlockV2", _params, _txList)
}

// ProposeBlockV2 is a paid mutator transaction binding the contract method 0x648885fb.
//
// Solidity: function proposeBlockV2(bytes _params, bytes _txList) returns((bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint16,bool,bytes32,address,uint96,uint64,uint64,uint32,uint32,uint8,(uint8,uint8,uint32,uint64,uint32)) meta_)
func (_TaikoL1 *TaikoL1Session) ProposeBlockV2(_params []byte, _txList []byte) (*types.Transaction, error) {
	return _TaikoL1.Contract.ProposeBlockV2(&_TaikoL1.TransactOpts, _params, _txList)
}

// ProposeBlockV2 is a paid mutator transaction binding the contract method 0x648885fb.
//
// Solidity: function proposeBlockV2(bytes _params, bytes _txList) returns((bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint16,bool,bytes32,address,uint96,uint64,uint64,uint32,uint32,uint8,(uint8,uint8,uint32,uint64,uint32)) meta_)
func (_TaikoL1 *TaikoL1TransactorSession) ProposeBlockV2(_params []byte, _txList []byte) (*types.Transaction, error) {
	return _TaikoL1.Contract.ProposeBlockV2(&_TaikoL1.TransactOpts, _params, _txList)
}

// ProposeBlocksV2 is a paid mutator transaction binding the contract method 0x0c8f4a10.
//
// Solidity: function proposeBlocksV2(bytes[] _paramsArr, bytes[] _txListArr) returns((bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint16,bool,bytes32,address,uint96,uint64,uint64,uint32,uint32,uint8,(uint8,uint8,uint32,uint64,uint32))[] metaArr_)
func (_TaikoL1 *TaikoL1Transactor) ProposeBlocksV2(opts *bind.TransactOpts, _paramsArr [][]byte, _txListArr [][]byte) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "proposeBlocksV2", _paramsArr, _txListArr)
}

// ProposeBlocksV2 is a paid mutator transaction binding the contract method 0x0c8f4a10.
//
// Solidity: function proposeBlocksV2(bytes[] _paramsArr, bytes[] _txListArr) returns((bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint16,bool,bytes32,address,uint96,uint64,uint64,uint32,uint32,uint8,(uint8,uint8,uint32,uint64,uint32))[] metaArr_)
func (_TaikoL1 *TaikoL1Session) ProposeBlocksV2(_paramsArr [][]byte, _txListArr [][]byte) (*types.Transaction, error) {
	return _TaikoL1.Contract.ProposeBlocksV2(&_TaikoL1.TransactOpts, _paramsArr, _txListArr)
}

// ProposeBlocksV2 is a paid mutator transaction binding the contract method 0x0c8f4a10.
//
// Solidity: function proposeBlocksV2(bytes[] _paramsArr, bytes[] _txListArr) returns((bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint16,bool,bytes32,address,uint96,uint64,uint64,uint32,uint32,uint8,(uint8,uint8,uint32,uint64,uint32))[] metaArr_)
func (_TaikoL1 *TaikoL1TransactorSession) ProposeBlocksV2(_paramsArr [][]byte, _txListArr [][]byte) (*types.Transaction, error) {
	return _TaikoL1.Contract.ProposeBlocksV2(&_TaikoL1.TransactOpts, _paramsArr, _txListArr)
}

// ProveBlock is a paid mutator transaction binding the contract method 0x10d008bd.
//
// Solidity: function proveBlock(uint64 _blockId, bytes _input) returns()
func (_TaikoL1 *TaikoL1Transactor) ProveBlock(opts *bind.TransactOpts, _blockId uint64, _input []byte) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "proveBlock", _blockId, _input)
}

// ProveBlock is a paid mutator transaction binding the contract method 0x10d008bd.
//
// Solidity: function proveBlock(uint64 _blockId, bytes _input) returns()
func (_TaikoL1 *TaikoL1Session) ProveBlock(_blockId uint64, _input []byte) (*types.Transaction, error) {
	return _TaikoL1.Contract.ProveBlock(&_TaikoL1.TransactOpts, _blockId, _input)
}

// ProveBlock is a paid mutator transaction binding the contract method 0x10d008bd.
//
// Solidity: function proveBlock(uint64 _blockId, bytes _input) returns()
func (_TaikoL1 *TaikoL1TransactorSession) ProveBlock(_blockId uint64, _input []byte) (*types.Transaction, error) {
	return _TaikoL1.Contract.ProveBlock(&_TaikoL1.TransactOpts, _blockId, _input)
}

// ProveBlocks is a paid mutator transaction binding the contract method 0x440b6e18.
//
// Solidity: function proveBlocks(uint64[] _blockIds, bytes[] _inputs, bytes _batchProof) returns()
func (_TaikoL1 *TaikoL1Transactor) ProveBlocks(opts *bind.TransactOpts, _blockIds []uint64, _inputs [][]byte, _batchProof []byte) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "proveBlocks", _blockIds, _inputs, _batchProof)
}

// ProveBlocks is a paid mutator transaction binding the contract method 0x440b6e18.
//
// Solidity: function proveBlocks(uint64[] _blockIds, bytes[] _inputs, bytes _batchProof) returns()
func (_TaikoL1 *TaikoL1Session) ProveBlocks(_blockIds []uint64, _inputs [][]byte, _batchProof []byte) (*types.Transaction, error) {
	return _TaikoL1.Contract.ProveBlocks(&_TaikoL1.TransactOpts, _blockIds, _inputs, _batchProof)
}

// ProveBlocks is a paid mutator transaction binding the contract method 0x440b6e18.
//
// Solidity: function proveBlocks(uint64[] _blockIds, bytes[] _inputs, bytes _batchProof) returns()
func (_TaikoL1 *TaikoL1TransactorSession) ProveBlocks(_blockIds []uint64, _inputs [][]byte, _batchProof []byte) (*types.Transaction, error) {
	return _TaikoL1.Contract.ProveBlocks(&_TaikoL1.TransactOpts, _blockIds, _inputs, _batchProof)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoL1 *TaikoL1Transactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoL1 *TaikoL1Session) RenounceOwnership() (*types.Transaction, error) {
	return _TaikoL1.Contract.RenounceOwnership(&_TaikoL1.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoL1 *TaikoL1TransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _TaikoL1.Contract.RenounceOwnership(&_TaikoL1.TransactOpts)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoL1 *TaikoL1Transactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoL1 *TaikoL1Session) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _TaikoL1.Contract.TransferOwnership(&_TaikoL1.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoL1 *TaikoL1TransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _TaikoL1.Contract.TransferOwnership(&_TaikoL1.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_TaikoL1 *TaikoL1Transactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_TaikoL1 *TaikoL1Session) Unpause() (*types.Transaction, error) {
	return _TaikoL1.Contract.Unpause(&_TaikoL1.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_TaikoL1 *TaikoL1TransactorSession) Unpause() (*types.Transaction, error) {
	return _TaikoL1.Contract.Unpause(&_TaikoL1.TransactOpts)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_TaikoL1 *TaikoL1Transactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_TaikoL1 *TaikoL1Session) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _TaikoL1.Contract.UpgradeTo(&_TaikoL1.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_TaikoL1 *TaikoL1TransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _TaikoL1.Contract.UpgradeTo(&_TaikoL1.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_TaikoL1 *TaikoL1Transactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_TaikoL1 *TaikoL1Session) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _TaikoL1.Contract.UpgradeToAndCall(&_TaikoL1.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_TaikoL1 *TaikoL1TransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _TaikoL1.Contract.UpgradeToAndCall(&_TaikoL1.TransactOpts, newImplementation, data)
}

// VerifyBlocks is a paid mutator transaction binding the contract method 0x8778209d.
//
// Solidity: function verifyBlocks(uint64 _maxBlocksToVerify) returns()
func (_TaikoL1 *TaikoL1Transactor) VerifyBlocks(opts *bind.TransactOpts, _maxBlocksToVerify uint64) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "verifyBlocks", _maxBlocksToVerify)
}

// VerifyBlocks is a paid mutator transaction binding the contract method 0x8778209d.
//
// Solidity: function verifyBlocks(uint64 _maxBlocksToVerify) returns()
func (_TaikoL1 *TaikoL1Session) VerifyBlocks(_maxBlocksToVerify uint64) (*types.Transaction, error) {
	return _TaikoL1.Contract.VerifyBlocks(&_TaikoL1.TransactOpts, _maxBlocksToVerify)
}

// VerifyBlocks is a paid mutator transaction binding the contract method 0x8778209d.
//
// Solidity: function verifyBlocks(uint64 _maxBlocksToVerify) returns()
func (_TaikoL1 *TaikoL1TransactorSession) VerifyBlocks(_maxBlocksToVerify uint64) (*types.Transaction, error) {
	return _TaikoL1.Contract.VerifyBlocks(&_TaikoL1.TransactOpts, _maxBlocksToVerify)
}

// WithdrawBond is a paid mutator transaction binding the contract method 0xc3daab96.
//
// Solidity: function withdrawBond(uint256 _amount) returns()
func (_TaikoL1 *TaikoL1Transactor) WithdrawBond(opts *bind.TransactOpts, _amount *big.Int) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "withdrawBond", _amount)
}

// WithdrawBond is a paid mutator transaction binding the contract method 0xc3daab96.
//
// Solidity: function withdrawBond(uint256 _amount) returns()
func (_TaikoL1 *TaikoL1Session) WithdrawBond(_amount *big.Int) (*types.Transaction, error) {
	return _TaikoL1.Contract.WithdrawBond(&_TaikoL1.TransactOpts, _amount)
}

// WithdrawBond is a paid mutator transaction binding the contract method 0xc3daab96.
//
// Solidity: function withdrawBond(uint256 _amount) returns()
func (_TaikoL1 *TaikoL1TransactorSession) WithdrawBond(_amount *big.Int) (*types.Transaction, error) {
	return _TaikoL1.Contract.WithdrawBond(&_TaikoL1.TransactOpts, _amount)
}

// TaikoL1AdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the TaikoL1 contract.
type TaikoL1AdminChangedIterator struct {
	Event *TaikoL1AdminChanged // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1AdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1AdminChanged)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1AdminChanged)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1AdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1AdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1AdminChanged represents a AdminChanged event raised by the TaikoL1 contract.
type TaikoL1AdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_TaikoL1 *TaikoL1Filterer) FilterAdminChanged(opts *bind.FilterOpts) (*TaikoL1AdminChangedIterator, error) {

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &TaikoL1AdminChangedIterator{contract: _TaikoL1.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_TaikoL1 *TaikoL1Filterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *TaikoL1AdminChanged) (event.Subscription, error) {

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1AdminChanged)
				if err := _TaikoL1.contract.UnpackLog(event, "AdminChanged", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseAdminChanged is a log parse operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_TaikoL1 *TaikoL1Filterer) ParseAdminChanged(log types.Log) (*TaikoL1AdminChanged, error) {
	event := new(TaikoL1AdminChanged)
	if err := _TaikoL1.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the TaikoL1 contract.
type TaikoL1BeaconUpgradedIterator struct {
	Event *TaikoL1BeaconUpgraded // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1BeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BeaconUpgraded)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1BeaconUpgraded)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1BeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BeaconUpgraded represents a BeaconUpgraded event raised by the TaikoL1 contract.
type TaikoL1BeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_TaikoL1 *TaikoL1Filterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*TaikoL1BeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BeaconUpgradedIterator{contract: _TaikoL1.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_TaikoL1 *TaikoL1Filterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *TaikoL1BeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BeaconUpgraded)
				if err := _TaikoL1.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseBeaconUpgraded is a log parse operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_TaikoL1 *TaikoL1Filterer) ParseBeaconUpgraded(log types.Log) (*TaikoL1BeaconUpgraded, error) {
	event := new(TaikoL1BeaconUpgraded)
	if err := _TaikoL1.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BlockProposedIterator is returned from FilterBlockProposed and is used to iterate over the raw logs and unpacked data for BlockProposed events raised by the TaikoL1 contract.
type TaikoL1BlockProposedIterator struct {
	Event *TaikoL1BlockProposed // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1BlockProposedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BlockProposed)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1BlockProposed)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1BlockProposedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BlockProposedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BlockProposed represents a BlockProposed event raised by the TaikoL1 contract.
type TaikoL1BlockProposed struct {
	BlockId           *big.Int
	AssignedProver    common.Address
	LivenessBond      *big.Int
	Meta              TaikoDataBlockMetadata
	DepositsProcessed []TaikoDataEthDeposit
	Raw               types.Log // Blockchain specific contextual infos
}

// FilterBlockProposed is a free log retrieval operation binding the contract event 0xcda4e564245eb15494bc6da29f6a42e1941cf57f5314bf35bab8a1fca0a9c60a.
//
// Solidity: event BlockProposed(uint256 indexed blockId, address indexed assignedProver, uint96 livenessBond, (bytes32,bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint16,bool,bytes32,address) meta, (address,uint96,uint64)[] depositsProcessed)
func (_TaikoL1 *TaikoL1Filterer) FilterBlockProposed(opts *bind.FilterOpts, blockId []*big.Int, assignedProver []common.Address) (*TaikoL1BlockProposedIterator, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}
	var assignedProverRule []interface{}
	for _, assignedProverItem := range assignedProver {
		assignedProverRule = append(assignedProverRule, assignedProverItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BlockProposed", blockIdRule, assignedProverRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BlockProposedIterator{contract: _TaikoL1.contract, event: "BlockProposed", logs: logs, sub: sub}, nil
}

// WatchBlockProposed is a free log subscription operation binding the contract event 0xcda4e564245eb15494bc6da29f6a42e1941cf57f5314bf35bab8a1fca0a9c60a.
//
// Solidity: event BlockProposed(uint256 indexed blockId, address indexed assignedProver, uint96 livenessBond, (bytes32,bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint16,bool,bytes32,address) meta, (address,uint96,uint64)[] depositsProcessed)
func (_TaikoL1 *TaikoL1Filterer) WatchBlockProposed(opts *bind.WatchOpts, sink chan<- *TaikoL1BlockProposed, blockId []*big.Int, assignedProver []common.Address) (event.Subscription, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}
	var assignedProverRule []interface{}
	for _, assignedProverItem := range assignedProver {
		assignedProverRule = append(assignedProverRule, assignedProverItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BlockProposed", blockIdRule, assignedProverRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BlockProposed)
				if err := _TaikoL1.contract.UnpackLog(event, "BlockProposed", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseBlockProposed is a log parse operation binding the contract event 0xcda4e564245eb15494bc6da29f6a42e1941cf57f5314bf35bab8a1fca0a9c60a.
//
// Solidity: event BlockProposed(uint256 indexed blockId, address indexed assignedProver, uint96 livenessBond, (bytes32,bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint16,bool,bytes32,address) meta, (address,uint96,uint64)[] depositsProcessed)
func (_TaikoL1 *TaikoL1Filterer) ParseBlockProposed(log types.Log) (*TaikoL1BlockProposed, error) {
	event := new(TaikoL1BlockProposed)
	if err := _TaikoL1.contract.UnpackLog(event, "BlockProposed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BlockProposedV2Iterator is returned from FilterBlockProposedV2 and is used to iterate over the raw logs and unpacked data for BlockProposedV2 events raised by the TaikoL1 contract.
type TaikoL1BlockProposedV2Iterator struct {
	Event *TaikoL1BlockProposedV2 // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1BlockProposedV2Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BlockProposedV2)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1BlockProposedV2)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1BlockProposedV2Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BlockProposedV2Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BlockProposedV2 represents a BlockProposedV2 event raised by the TaikoL1 contract.
type TaikoL1BlockProposedV2 struct {
	BlockId *big.Int
	Meta    TaikoDataBlockMetadataV2
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterBlockProposedV2 is a free log retrieval operation binding the contract event 0xefe9c6c0b5cbd9c0eed2d1e9c00cfc1a010d6f1aff50f7facd665a639b622b26.
//
// Solidity: event BlockProposedV2(uint256 indexed blockId, (bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint16,bool,bytes32,address,uint96,uint64,uint64,uint32,uint32,uint8,(uint8,uint8,uint32,uint64,uint32)) meta)
func (_TaikoL1 *TaikoL1Filterer) FilterBlockProposedV2(opts *bind.FilterOpts, blockId []*big.Int) (*TaikoL1BlockProposedV2Iterator, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BlockProposedV2", blockIdRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BlockProposedV2Iterator{contract: _TaikoL1.contract, event: "BlockProposedV2", logs: logs, sub: sub}, nil
}

// WatchBlockProposedV2 is a free log subscription operation binding the contract event 0xefe9c6c0b5cbd9c0eed2d1e9c00cfc1a010d6f1aff50f7facd665a639b622b26.
//
// Solidity: event BlockProposedV2(uint256 indexed blockId, (bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint16,bool,bytes32,address,uint96,uint64,uint64,uint32,uint32,uint8,(uint8,uint8,uint32,uint64,uint32)) meta)
func (_TaikoL1 *TaikoL1Filterer) WatchBlockProposedV2(opts *bind.WatchOpts, sink chan<- *TaikoL1BlockProposedV2, blockId []*big.Int) (event.Subscription, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BlockProposedV2", blockIdRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BlockProposedV2)
				if err := _TaikoL1.contract.UnpackLog(event, "BlockProposedV2", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseBlockProposedV2 is a log parse operation binding the contract event 0xefe9c6c0b5cbd9c0eed2d1e9c00cfc1a010d6f1aff50f7facd665a639b622b26.
//
// Solidity: event BlockProposedV2(uint256 indexed blockId, (bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint16,bool,bytes32,address,uint96,uint64,uint64,uint32,uint32,uint8,(uint8,uint8,uint32,uint64,uint32)) meta)
func (_TaikoL1 *TaikoL1Filterer) ParseBlockProposedV2(log types.Log) (*TaikoL1BlockProposedV2, error) {
	event := new(TaikoL1BlockProposedV2)
	if err := _TaikoL1.contract.UnpackLog(event, "BlockProposedV2", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BlockProposedV20Iterator is returned from FilterBlockProposedV20 and is used to iterate over the raw logs and unpacked data for BlockProposedV20 events raised by the TaikoL1 contract.
type TaikoL1BlockProposedV20Iterator struct {
	Event *TaikoL1BlockProposedV20 // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1BlockProposedV20Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BlockProposedV20)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1BlockProposedV20)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1BlockProposedV20Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BlockProposedV20Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BlockProposedV20 represents a BlockProposedV20 event raised by the TaikoL1 contract.
type TaikoL1BlockProposedV20 struct {
	BlockId *big.Int
	Meta    TaikoDataBlockMetadataV2
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterBlockProposedV20 is a free log retrieval operation binding the contract event 0xefe9c6c0b5cbd9c0eed2d1e9c00cfc1a010d6f1aff50f7facd665a639b622b26.
//
// Solidity: event BlockProposedV2(uint256 indexed blockId, (bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint16,bool,bytes32,address,uint96,uint64,uint64,uint32,uint32,uint8,(uint8,uint8,uint32,uint64,uint32)) meta)
func (_TaikoL1 *TaikoL1Filterer) FilterBlockProposedV20(opts *bind.FilterOpts, blockId []*big.Int) (*TaikoL1BlockProposedV20Iterator, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BlockProposedV20", blockIdRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BlockProposedV20Iterator{contract: _TaikoL1.contract, event: "BlockProposedV20", logs: logs, sub: sub}, nil
}

// WatchBlockProposedV20 is a free log subscription operation binding the contract event 0xefe9c6c0b5cbd9c0eed2d1e9c00cfc1a010d6f1aff50f7facd665a639b622b26.
//
// Solidity: event BlockProposedV2(uint256 indexed blockId, (bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint16,bool,bytes32,address,uint96,uint64,uint64,uint32,uint32,uint8,(uint8,uint8,uint32,uint64,uint32)) meta)
func (_TaikoL1 *TaikoL1Filterer) WatchBlockProposedV20(opts *bind.WatchOpts, sink chan<- *TaikoL1BlockProposedV20, blockId []*big.Int) (event.Subscription, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BlockProposedV20", blockIdRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BlockProposedV20)
				if err := _TaikoL1.contract.UnpackLog(event, "BlockProposedV20", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseBlockProposedV20 is a log parse operation binding the contract event 0xefe9c6c0b5cbd9c0eed2d1e9c00cfc1a010d6f1aff50f7facd665a639b622b26.
//
// Solidity: event BlockProposedV2(uint256 indexed blockId, (bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint16,bool,bytes32,address,uint96,uint64,uint64,uint32,uint32,uint8,(uint8,uint8,uint32,uint64,uint32)) meta)
func (_TaikoL1 *TaikoL1Filterer) ParseBlockProposedV20(log types.Log) (*TaikoL1BlockProposedV20, error) {
	event := new(TaikoL1BlockProposedV20)
	if err := _TaikoL1.contract.UnpackLog(event, "BlockProposedV20", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BlockVerifiedIterator is returned from FilterBlockVerified and is used to iterate over the raw logs and unpacked data for BlockVerified events raised by the TaikoL1 contract.
type TaikoL1BlockVerifiedIterator struct {
	Event *TaikoL1BlockVerified // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1BlockVerifiedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BlockVerified)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1BlockVerified)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1BlockVerifiedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BlockVerifiedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BlockVerified represents a BlockVerified event raised by the TaikoL1 contract.
type TaikoL1BlockVerified struct {
	BlockId   *big.Int
	Prover    common.Address
	BlockHash [32]byte
	StateRoot [32]byte
	Tier      uint16
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterBlockVerified is a free log retrieval operation binding the contract event 0xdecbd2c61cbda254917d6fd4c980a470701e8f9f1b744f6ad163ca70ca5db289.
//
// Solidity: event BlockVerified(uint256 indexed blockId, address indexed prover, bytes32 blockHash, bytes32 stateRoot, uint16 tier)
func (_TaikoL1 *TaikoL1Filterer) FilterBlockVerified(opts *bind.FilterOpts, blockId []*big.Int, prover []common.Address) (*TaikoL1BlockVerifiedIterator, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}
	var proverRule []interface{}
	for _, proverItem := range prover {
		proverRule = append(proverRule, proverItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BlockVerified", blockIdRule, proverRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BlockVerifiedIterator{contract: _TaikoL1.contract, event: "BlockVerified", logs: logs, sub: sub}, nil
}

// WatchBlockVerified is a free log subscription operation binding the contract event 0xdecbd2c61cbda254917d6fd4c980a470701e8f9f1b744f6ad163ca70ca5db289.
//
// Solidity: event BlockVerified(uint256 indexed blockId, address indexed prover, bytes32 blockHash, bytes32 stateRoot, uint16 tier)
func (_TaikoL1 *TaikoL1Filterer) WatchBlockVerified(opts *bind.WatchOpts, sink chan<- *TaikoL1BlockVerified, blockId []*big.Int, prover []common.Address) (event.Subscription, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}
	var proverRule []interface{}
	for _, proverItem := range prover {
		proverRule = append(proverRule, proverItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BlockVerified", blockIdRule, proverRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BlockVerified)
				if err := _TaikoL1.contract.UnpackLog(event, "BlockVerified", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseBlockVerified is a log parse operation binding the contract event 0xdecbd2c61cbda254917d6fd4c980a470701e8f9f1b744f6ad163ca70ca5db289.
//
// Solidity: event BlockVerified(uint256 indexed blockId, address indexed prover, bytes32 blockHash, bytes32 stateRoot, uint16 tier)
func (_TaikoL1 *TaikoL1Filterer) ParseBlockVerified(log types.Log) (*TaikoL1BlockVerified, error) {
	event := new(TaikoL1BlockVerified)
	if err := _TaikoL1.contract.UnpackLog(event, "BlockVerified", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BlockVerifiedV2Iterator is returned from FilterBlockVerifiedV2 and is used to iterate over the raw logs and unpacked data for BlockVerifiedV2 events raised by the TaikoL1 contract.
type TaikoL1BlockVerifiedV2Iterator struct {
	Event *TaikoL1BlockVerifiedV2 // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1BlockVerifiedV2Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BlockVerifiedV2)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1BlockVerifiedV2)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1BlockVerifiedV2Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BlockVerifiedV2Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BlockVerifiedV2 represents a BlockVerifiedV2 event raised by the TaikoL1 contract.
type TaikoL1BlockVerifiedV2 struct {
	BlockId   *big.Int
	Prover    common.Address
	BlockHash [32]byte
	Tier      uint16
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterBlockVerifiedV2 is a free log retrieval operation binding the contract event 0xe5a390d9800811154279af0c1a80d3bdf558ea91f1301e7c6ec3c1ad83e80aef.
//
// Solidity: event BlockVerifiedV2(uint256 indexed blockId, address indexed prover, bytes32 blockHash, uint16 tier)
func (_TaikoL1 *TaikoL1Filterer) FilterBlockVerifiedV2(opts *bind.FilterOpts, blockId []*big.Int, prover []common.Address) (*TaikoL1BlockVerifiedV2Iterator, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}
	var proverRule []interface{}
	for _, proverItem := range prover {
		proverRule = append(proverRule, proverItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BlockVerifiedV2", blockIdRule, proverRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BlockVerifiedV2Iterator{contract: _TaikoL1.contract, event: "BlockVerifiedV2", logs: logs, sub: sub}, nil
}

// WatchBlockVerifiedV2 is a free log subscription operation binding the contract event 0xe5a390d9800811154279af0c1a80d3bdf558ea91f1301e7c6ec3c1ad83e80aef.
//
// Solidity: event BlockVerifiedV2(uint256 indexed blockId, address indexed prover, bytes32 blockHash, uint16 tier)
func (_TaikoL1 *TaikoL1Filterer) WatchBlockVerifiedV2(opts *bind.WatchOpts, sink chan<- *TaikoL1BlockVerifiedV2, blockId []*big.Int, prover []common.Address) (event.Subscription, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}
	var proverRule []interface{}
	for _, proverItem := range prover {
		proverRule = append(proverRule, proverItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BlockVerifiedV2", blockIdRule, proverRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BlockVerifiedV2)
				if err := _TaikoL1.contract.UnpackLog(event, "BlockVerifiedV2", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseBlockVerifiedV2 is a log parse operation binding the contract event 0xe5a390d9800811154279af0c1a80d3bdf558ea91f1301e7c6ec3c1ad83e80aef.
//
// Solidity: event BlockVerifiedV2(uint256 indexed blockId, address indexed prover, bytes32 blockHash, uint16 tier)
func (_TaikoL1 *TaikoL1Filterer) ParseBlockVerifiedV2(log types.Log) (*TaikoL1BlockVerifiedV2, error) {
	event := new(TaikoL1BlockVerifiedV2)
	if err := _TaikoL1.contract.UnpackLog(event, "BlockVerifiedV2", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BlockVerifiedV20Iterator is returned from FilterBlockVerifiedV20 and is used to iterate over the raw logs and unpacked data for BlockVerifiedV20 events raised by the TaikoL1 contract.
type TaikoL1BlockVerifiedV20Iterator struct {
	Event *TaikoL1BlockVerifiedV20 // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1BlockVerifiedV20Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BlockVerifiedV20)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1BlockVerifiedV20)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1BlockVerifiedV20Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BlockVerifiedV20Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BlockVerifiedV20 represents a BlockVerifiedV20 event raised by the TaikoL1 contract.
type TaikoL1BlockVerifiedV20 struct {
	BlockId   *big.Int
	Prover    common.Address
	BlockHash [32]byte
	Tier      uint16
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterBlockVerifiedV20 is a free log retrieval operation binding the contract event 0xe5a390d9800811154279af0c1a80d3bdf558ea91f1301e7c6ec3c1ad83e80aef.
//
// Solidity: event BlockVerifiedV2(uint256 indexed blockId, address indexed prover, bytes32 blockHash, uint16 tier)
func (_TaikoL1 *TaikoL1Filterer) FilterBlockVerifiedV20(opts *bind.FilterOpts, blockId []*big.Int, prover []common.Address) (*TaikoL1BlockVerifiedV20Iterator, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}
	var proverRule []interface{}
	for _, proverItem := range prover {
		proverRule = append(proverRule, proverItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BlockVerifiedV20", blockIdRule, proverRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BlockVerifiedV20Iterator{contract: _TaikoL1.contract, event: "BlockVerifiedV20", logs: logs, sub: sub}, nil
}

// WatchBlockVerifiedV20 is a free log subscription operation binding the contract event 0xe5a390d9800811154279af0c1a80d3bdf558ea91f1301e7c6ec3c1ad83e80aef.
//
// Solidity: event BlockVerifiedV2(uint256 indexed blockId, address indexed prover, bytes32 blockHash, uint16 tier)
func (_TaikoL1 *TaikoL1Filterer) WatchBlockVerifiedV20(opts *bind.WatchOpts, sink chan<- *TaikoL1BlockVerifiedV20, blockId []*big.Int, prover []common.Address) (event.Subscription, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}
	var proverRule []interface{}
	for _, proverItem := range prover {
		proverRule = append(proverRule, proverItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BlockVerifiedV20", blockIdRule, proverRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BlockVerifiedV20)
				if err := _TaikoL1.contract.UnpackLog(event, "BlockVerifiedV20", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseBlockVerifiedV20 is a log parse operation binding the contract event 0xe5a390d9800811154279af0c1a80d3bdf558ea91f1301e7c6ec3c1ad83e80aef.
//
// Solidity: event BlockVerifiedV2(uint256 indexed blockId, address indexed prover, bytes32 blockHash, uint16 tier)
func (_TaikoL1 *TaikoL1Filterer) ParseBlockVerifiedV20(log types.Log) (*TaikoL1BlockVerifiedV20, error) {
	event := new(TaikoL1BlockVerifiedV20)
	if err := _TaikoL1.contract.UnpackLog(event, "BlockVerifiedV20", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BondCreditedIterator is returned from FilterBondCredited and is used to iterate over the raw logs and unpacked data for BondCredited events raised by the TaikoL1 contract.
type TaikoL1BondCreditedIterator struct {
	Event *TaikoL1BondCredited // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1BondCreditedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BondCredited)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1BondCredited)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1BondCreditedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BondCreditedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BondCredited represents a BondCredited event raised by the TaikoL1 contract.
type TaikoL1BondCredited struct {
	User    common.Address
	BlockId *big.Int
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterBondCredited is a free log retrieval operation binding the contract event 0x767672484792852973001cc22546fd96c3d7466da3c383e42741793dce5e4169.
//
// Solidity: event BondCredited(address indexed user, uint256 blockId, uint256 amount)
func (_TaikoL1 *TaikoL1Filterer) FilterBondCredited(opts *bind.FilterOpts, user []common.Address) (*TaikoL1BondCreditedIterator, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BondCredited", userRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BondCreditedIterator{contract: _TaikoL1.contract, event: "BondCredited", logs: logs, sub: sub}, nil
}

// WatchBondCredited is a free log subscription operation binding the contract event 0x767672484792852973001cc22546fd96c3d7466da3c383e42741793dce5e4169.
//
// Solidity: event BondCredited(address indexed user, uint256 blockId, uint256 amount)
func (_TaikoL1 *TaikoL1Filterer) WatchBondCredited(opts *bind.WatchOpts, sink chan<- *TaikoL1BondCredited, user []common.Address) (event.Subscription, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BondCredited", userRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BondCredited)
				if err := _TaikoL1.contract.UnpackLog(event, "BondCredited", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseBondCredited is a log parse operation binding the contract event 0x767672484792852973001cc22546fd96c3d7466da3c383e42741793dce5e4169.
//
// Solidity: event BondCredited(address indexed user, uint256 blockId, uint256 amount)
func (_TaikoL1 *TaikoL1Filterer) ParseBondCredited(log types.Log) (*TaikoL1BondCredited, error) {
	event := new(TaikoL1BondCredited)
	if err := _TaikoL1.contract.UnpackLog(event, "BondCredited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BondCredited0Iterator is returned from FilterBondCredited0 and is used to iterate over the raw logs and unpacked data for BondCredited0 events raised by the TaikoL1 contract.
type TaikoL1BondCredited0Iterator struct {
	Event *TaikoL1BondCredited0 // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1BondCredited0Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BondCredited0)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1BondCredited0)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1BondCredited0Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BondCredited0Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BondCredited0 represents a BondCredited0 event raised by the TaikoL1 contract.
type TaikoL1BondCredited0 struct {
	User    common.Address
	BlockId *big.Int
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterBondCredited0 is a free log retrieval operation binding the contract event 0x767672484792852973001cc22546fd96c3d7466da3c383e42741793dce5e4169.
//
// Solidity: event BondCredited(address indexed user, uint256 blockId, uint256 amount)
func (_TaikoL1 *TaikoL1Filterer) FilterBondCredited0(opts *bind.FilterOpts, user []common.Address) (*TaikoL1BondCredited0Iterator, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BondCredited0", userRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BondCredited0Iterator{contract: _TaikoL1.contract, event: "BondCredited0", logs: logs, sub: sub}, nil
}

// WatchBondCredited0 is a free log subscription operation binding the contract event 0x767672484792852973001cc22546fd96c3d7466da3c383e42741793dce5e4169.
//
// Solidity: event BondCredited(address indexed user, uint256 blockId, uint256 amount)
func (_TaikoL1 *TaikoL1Filterer) WatchBondCredited0(opts *bind.WatchOpts, sink chan<- *TaikoL1BondCredited0, user []common.Address) (event.Subscription, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BondCredited0", userRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BondCredited0)
				if err := _TaikoL1.contract.UnpackLog(event, "BondCredited0", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseBondCredited0 is a log parse operation binding the contract event 0x767672484792852973001cc22546fd96c3d7466da3c383e42741793dce5e4169.
//
// Solidity: event BondCredited(address indexed user, uint256 blockId, uint256 amount)
func (_TaikoL1 *TaikoL1Filterer) ParseBondCredited0(log types.Log) (*TaikoL1BondCredited0, error) {
	event := new(TaikoL1BondCredited0)
	if err := _TaikoL1.contract.UnpackLog(event, "BondCredited0", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BondDebitedIterator is returned from FilterBondDebited and is used to iterate over the raw logs and unpacked data for BondDebited events raised by the TaikoL1 contract.
type TaikoL1BondDebitedIterator struct {
	Event *TaikoL1BondDebited // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1BondDebitedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BondDebited)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1BondDebited)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1BondDebitedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BondDebitedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BondDebited represents a BondDebited event raised by the TaikoL1 contract.
type TaikoL1BondDebited struct {
	User    common.Address
	BlockId *big.Int
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterBondDebited is a free log retrieval operation binding the contract event 0xf4636413c66bd7ef2a1d735c30d22543acb0fba1b0892503bef0734b237c3f37.
//
// Solidity: event BondDebited(address indexed user, uint256 blockId, uint256 amount)
func (_TaikoL1 *TaikoL1Filterer) FilterBondDebited(opts *bind.FilterOpts, user []common.Address) (*TaikoL1BondDebitedIterator, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BondDebited", userRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BondDebitedIterator{contract: _TaikoL1.contract, event: "BondDebited", logs: logs, sub: sub}, nil
}

// WatchBondDebited is a free log subscription operation binding the contract event 0xf4636413c66bd7ef2a1d735c30d22543acb0fba1b0892503bef0734b237c3f37.
//
// Solidity: event BondDebited(address indexed user, uint256 blockId, uint256 amount)
func (_TaikoL1 *TaikoL1Filterer) WatchBondDebited(opts *bind.WatchOpts, sink chan<- *TaikoL1BondDebited, user []common.Address) (event.Subscription, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BondDebited", userRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BondDebited)
				if err := _TaikoL1.contract.UnpackLog(event, "BondDebited", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseBondDebited is a log parse operation binding the contract event 0xf4636413c66bd7ef2a1d735c30d22543acb0fba1b0892503bef0734b237c3f37.
//
// Solidity: event BondDebited(address indexed user, uint256 blockId, uint256 amount)
func (_TaikoL1 *TaikoL1Filterer) ParseBondDebited(log types.Log) (*TaikoL1BondDebited, error) {
	event := new(TaikoL1BondDebited)
	if err := _TaikoL1.contract.UnpackLog(event, "BondDebited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BondDebited0Iterator is returned from FilterBondDebited0 and is used to iterate over the raw logs and unpacked data for BondDebited0 events raised by the TaikoL1 contract.
type TaikoL1BondDebited0Iterator struct {
	Event *TaikoL1BondDebited0 // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1BondDebited0Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BondDebited0)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1BondDebited0)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1BondDebited0Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BondDebited0Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BondDebited0 represents a BondDebited0 event raised by the TaikoL1 contract.
type TaikoL1BondDebited0 struct {
	User    common.Address
	BlockId *big.Int
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterBondDebited0 is a free log retrieval operation binding the contract event 0xf4636413c66bd7ef2a1d735c30d22543acb0fba1b0892503bef0734b237c3f37.
//
// Solidity: event BondDebited(address indexed user, uint256 blockId, uint256 amount)
func (_TaikoL1 *TaikoL1Filterer) FilterBondDebited0(opts *bind.FilterOpts, user []common.Address) (*TaikoL1BondDebited0Iterator, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BondDebited0", userRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BondDebited0Iterator{contract: _TaikoL1.contract, event: "BondDebited0", logs: logs, sub: sub}, nil
}

// WatchBondDebited0 is a free log subscription operation binding the contract event 0xf4636413c66bd7ef2a1d735c30d22543acb0fba1b0892503bef0734b237c3f37.
//
// Solidity: event BondDebited(address indexed user, uint256 blockId, uint256 amount)
func (_TaikoL1 *TaikoL1Filterer) WatchBondDebited0(opts *bind.WatchOpts, sink chan<- *TaikoL1BondDebited0, user []common.Address) (event.Subscription, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BondDebited0", userRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BondDebited0)
				if err := _TaikoL1.contract.UnpackLog(event, "BondDebited0", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseBondDebited0 is a log parse operation binding the contract event 0xf4636413c66bd7ef2a1d735c30d22543acb0fba1b0892503bef0734b237c3f37.
//
// Solidity: event BondDebited(address indexed user, uint256 blockId, uint256 amount)
func (_TaikoL1 *TaikoL1Filterer) ParseBondDebited0(log types.Log) (*TaikoL1BondDebited0, error) {
	event := new(TaikoL1BondDebited0)
	if err := _TaikoL1.contract.UnpackLog(event, "BondDebited0", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BondDepositedIterator is returned from FilterBondDeposited and is used to iterate over the raw logs and unpacked data for BondDeposited events raised by the TaikoL1 contract.
type TaikoL1BondDepositedIterator struct {
	Event *TaikoL1BondDeposited // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1BondDepositedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BondDeposited)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1BondDeposited)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1BondDepositedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BondDepositedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BondDeposited represents a BondDeposited event raised by the TaikoL1 contract.
type TaikoL1BondDeposited struct {
	User   common.Address
	Amount *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBondDeposited is a free log retrieval operation binding the contract event 0x8ed8c6869618197b68315ade66e75ed3906c97b111fa3ab81e5760046825c7db.
//
// Solidity: event BondDeposited(address indexed user, uint256 amount)
func (_TaikoL1 *TaikoL1Filterer) FilterBondDeposited(opts *bind.FilterOpts, user []common.Address) (*TaikoL1BondDepositedIterator, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BondDeposited", userRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BondDepositedIterator{contract: _TaikoL1.contract, event: "BondDeposited", logs: logs, sub: sub}, nil
}

// WatchBondDeposited is a free log subscription operation binding the contract event 0x8ed8c6869618197b68315ade66e75ed3906c97b111fa3ab81e5760046825c7db.
//
// Solidity: event BondDeposited(address indexed user, uint256 amount)
func (_TaikoL1 *TaikoL1Filterer) WatchBondDeposited(opts *bind.WatchOpts, sink chan<- *TaikoL1BondDeposited, user []common.Address) (event.Subscription, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BondDeposited", userRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BondDeposited)
				if err := _TaikoL1.contract.UnpackLog(event, "BondDeposited", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseBondDeposited is a log parse operation binding the contract event 0x8ed8c6869618197b68315ade66e75ed3906c97b111fa3ab81e5760046825c7db.
//
// Solidity: event BondDeposited(address indexed user, uint256 amount)
func (_TaikoL1 *TaikoL1Filterer) ParseBondDeposited(log types.Log) (*TaikoL1BondDeposited, error) {
	event := new(TaikoL1BondDeposited)
	if err := _TaikoL1.contract.UnpackLog(event, "BondDeposited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BondDeposited0Iterator is returned from FilterBondDeposited0 and is used to iterate over the raw logs and unpacked data for BondDeposited0 events raised by the TaikoL1 contract.
type TaikoL1BondDeposited0Iterator struct {
	Event *TaikoL1BondDeposited0 // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1BondDeposited0Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BondDeposited0)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1BondDeposited0)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1BondDeposited0Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BondDeposited0Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BondDeposited0 represents a BondDeposited0 event raised by the TaikoL1 contract.
type TaikoL1BondDeposited0 struct {
	User   common.Address
	Amount *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBondDeposited0 is a free log retrieval operation binding the contract event 0x8ed8c6869618197b68315ade66e75ed3906c97b111fa3ab81e5760046825c7db.
//
// Solidity: event BondDeposited(address indexed user, uint256 amount)
func (_TaikoL1 *TaikoL1Filterer) FilterBondDeposited0(opts *bind.FilterOpts, user []common.Address) (*TaikoL1BondDeposited0Iterator, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BondDeposited0", userRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BondDeposited0Iterator{contract: _TaikoL1.contract, event: "BondDeposited0", logs: logs, sub: sub}, nil
}

// WatchBondDeposited0 is a free log subscription operation binding the contract event 0x8ed8c6869618197b68315ade66e75ed3906c97b111fa3ab81e5760046825c7db.
//
// Solidity: event BondDeposited(address indexed user, uint256 amount)
func (_TaikoL1 *TaikoL1Filterer) WatchBondDeposited0(opts *bind.WatchOpts, sink chan<- *TaikoL1BondDeposited0, user []common.Address) (event.Subscription, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BondDeposited0", userRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BondDeposited0)
				if err := _TaikoL1.contract.UnpackLog(event, "BondDeposited0", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseBondDeposited0 is a log parse operation binding the contract event 0x8ed8c6869618197b68315ade66e75ed3906c97b111fa3ab81e5760046825c7db.
//
// Solidity: event BondDeposited(address indexed user, uint256 amount)
func (_TaikoL1 *TaikoL1Filterer) ParseBondDeposited0(log types.Log) (*TaikoL1BondDeposited0, error) {
	event := new(TaikoL1BondDeposited0)
	if err := _TaikoL1.contract.UnpackLog(event, "BondDeposited0", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BondWithdrawnIterator is returned from FilterBondWithdrawn and is used to iterate over the raw logs and unpacked data for BondWithdrawn events raised by the TaikoL1 contract.
type TaikoL1BondWithdrawnIterator struct {
	Event *TaikoL1BondWithdrawn // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1BondWithdrawnIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BondWithdrawn)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1BondWithdrawn)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1BondWithdrawnIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BondWithdrawnIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BondWithdrawn represents a BondWithdrawn event raised by the TaikoL1 contract.
type TaikoL1BondWithdrawn struct {
	User   common.Address
	Amount *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBondWithdrawn is a free log retrieval operation binding the contract event 0x0d41118e36df44efb77a471fc49fb9c0be0406d802ef95520e9fbf606e65b455.
//
// Solidity: event BondWithdrawn(address indexed user, uint256 amount)
func (_TaikoL1 *TaikoL1Filterer) FilterBondWithdrawn(opts *bind.FilterOpts, user []common.Address) (*TaikoL1BondWithdrawnIterator, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BondWithdrawn", userRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BondWithdrawnIterator{contract: _TaikoL1.contract, event: "BondWithdrawn", logs: logs, sub: sub}, nil
}

// WatchBondWithdrawn is a free log subscription operation binding the contract event 0x0d41118e36df44efb77a471fc49fb9c0be0406d802ef95520e9fbf606e65b455.
//
// Solidity: event BondWithdrawn(address indexed user, uint256 amount)
func (_TaikoL1 *TaikoL1Filterer) WatchBondWithdrawn(opts *bind.WatchOpts, sink chan<- *TaikoL1BondWithdrawn, user []common.Address) (event.Subscription, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BondWithdrawn", userRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BondWithdrawn)
				if err := _TaikoL1.contract.UnpackLog(event, "BondWithdrawn", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseBondWithdrawn is a log parse operation binding the contract event 0x0d41118e36df44efb77a471fc49fb9c0be0406d802ef95520e9fbf606e65b455.
//
// Solidity: event BondWithdrawn(address indexed user, uint256 amount)
func (_TaikoL1 *TaikoL1Filterer) ParseBondWithdrawn(log types.Log) (*TaikoL1BondWithdrawn, error) {
	event := new(TaikoL1BondWithdrawn)
	if err := _TaikoL1.contract.UnpackLog(event, "BondWithdrawn", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1CalldataTxListIterator is returned from FilterCalldataTxList and is used to iterate over the raw logs and unpacked data for CalldataTxList events raised by the TaikoL1 contract.
type TaikoL1CalldataTxListIterator struct {
	Event *TaikoL1CalldataTxList // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1CalldataTxListIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1CalldataTxList)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1CalldataTxList)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1CalldataTxListIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1CalldataTxListIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1CalldataTxList represents a CalldataTxList event raised by the TaikoL1 contract.
type TaikoL1CalldataTxList struct {
	BlockId *big.Int
	TxList  []byte
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterCalldataTxList is a free log retrieval operation binding the contract event 0xa07bc5e8f00f6065c8727821591c519efd2348e4ff0c26560a85592e85b6f418.
//
// Solidity: event CalldataTxList(uint256 indexed blockId, bytes txList)
func (_TaikoL1 *TaikoL1Filterer) FilterCalldataTxList(opts *bind.FilterOpts, blockId []*big.Int) (*TaikoL1CalldataTxListIterator, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "CalldataTxList", blockIdRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1CalldataTxListIterator{contract: _TaikoL1.contract, event: "CalldataTxList", logs: logs, sub: sub}, nil
}

// WatchCalldataTxList is a free log subscription operation binding the contract event 0xa07bc5e8f00f6065c8727821591c519efd2348e4ff0c26560a85592e85b6f418.
//
// Solidity: event CalldataTxList(uint256 indexed blockId, bytes txList)
func (_TaikoL1 *TaikoL1Filterer) WatchCalldataTxList(opts *bind.WatchOpts, sink chan<- *TaikoL1CalldataTxList, blockId []*big.Int) (event.Subscription, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "CalldataTxList", blockIdRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1CalldataTxList)
				if err := _TaikoL1.contract.UnpackLog(event, "CalldataTxList", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseCalldataTxList is a log parse operation binding the contract event 0xa07bc5e8f00f6065c8727821591c519efd2348e4ff0c26560a85592e85b6f418.
//
// Solidity: event CalldataTxList(uint256 indexed blockId, bytes txList)
func (_TaikoL1 *TaikoL1Filterer) ParseCalldataTxList(log types.Log) (*TaikoL1CalldataTxList, error) {
	event := new(TaikoL1CalldataTxList)
	if err := _TaikoL1.contract.UnpackLog(event, "CalldataTxList", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1CalldataTxList0Iterator is returned from FilterCalldataTxList0 and is used to iterate over the raw logs and unpacked data for CalldataTxList0 events raised by the TaikoL1 contract.
type TaikoL1CalldataTxList0Iterator struct {
	Event *TaikoL1CalldataTxList0 // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1CalldataTxList0Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1CalldataTxList0)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1CalldataTxList0)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1CalldataTxList0Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1CalldataTxList0Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1CalldataTxList0 represents a CalldataTxList0 event raised by the TaikoL1 contract.
type TaikoL1CalldataTxList0 struct {
	BlockId *big.Int
	TxList  []byte
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterCalldataTxList0 is a free log retrieval operation binding the contract event 0xa07bc5e8f00f6065c8727821591c519efd2348e4ff0c26560a85592e85b6f418.
//
// Solidity: event CalldataTxList(uint256 indexed blockId, bytes txList)
func (_TaikoL1 *TaikoL1Filterer) FilterCalldataTxList0(opts *bind.FilterOpts, blockId []*big.Int) (*TaikoL1CalldataTxList0Iterator, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "CalldataTxList0", blockIdRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1CalldataTxList0Iterator{contract: _TaikoL1.contract, event: "CalldataTxList0", logs: logs, sub: sub}, nil
}

// WatchCalldataTxList0 is a free log subscription operation binding the contract event 0xa07bc5e8f00f6065c8727821591c519efd2348e4ff0c26560a85592e85b6f418.
//
// Solidity: event CalldataTxList(uint256 indexed blockId, bytes txList)
func (_TaikoL1 *TaikoL1Filterer) WatchCalldataTxList0(opts *bind.WatchOpts, sink chan<- *TaikoL1CalldataTxList0, blockId []*big.Int) (event.Subscription, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "CalldataTxList0", blockIdRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1CalldataTxList0)
				if err := _TaikoL1.contract.UnpackLog(event, "CalldataTxList0", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseCalldataTxList0 is a log parse operation binding the contract event 0xa07bc5e8f00f6065c8727821591c519efd2348e4ff0c26560a85592e85b6f418.
//
// Solidity: event CalldataTxList(uint256 indexed blockId, bytes txList)
func (_TaikoL1 *TaikoL1Filterer) ParseCalldataTxList0(log types.Log) (*TaikoL1CalldataTxList0, error) {
	event := new(TaikoL1CalldataTxList0)
	if err := _TaikoL1.contract.UnpackLog(event, "CalldataTxList0", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1InitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the TaikoL1 contract.
type TaikoL1InitializedIterator struct {
	Event *TaikoL1Initialized // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1InitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1Initialized)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1Initialized)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1InitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1InitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1Initialized represents a Initialized event raised by the TaikoL1 contract.
type TaikoL1Initialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_TaikoL1 *TaikoL1Filterer) FilterInitialized(opts *bind.FilterOpts) (*TaikoL1InitializedIterator, error) {

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &TaikoL1InitializedIterator{contract: _TaikoL1.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_TaikoL1 *TaikoL1Filterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *TaikoL1Initialized) (event.Subscription, error) {

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1Initialized)
				if err := _TaikoL1.contract.UnpackLog(event, "Initialized", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseInitialized is a log parse operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_TaikoL1 *TaikoL1Filterer) ParseInitialized(log types.Log) (*TaikoL1Initialized, error) {
	event := new(TaikoL1Initialized)
	if err := _TaikoL1.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1OwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the TaikoL1 contract.
type TaikoL1OwnershipTransferStartedIterator struct {
	Event *TaikoL1OwnershipTransferStarted // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1OwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1OwnershipTransferStarted)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1OwnershipTransferStarted)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1OwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1OwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1OwnershipTransferStarted represents a OwnershipTransferStarted event raised by the TaikoL1 contract.
type TaikoL1OwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_TaikoL1 *TaikoL1Filterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*TaikoL1OwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1OwnershipTransferStartedIterator{contract: _TaikoL1.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_TaikoL1 *TaikoL1Filterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *TaikoL1OwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1OwnershipTransferStarted)
				if err := _TaikoL1.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseOwnershipTransferStarted is a log parse operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_TaikoL1 *TaikoL1Filterer) ParseOwnershipTransferStarted(log types.Log) (*TaikoL1OwnershipTransferStarted, error) {
	event := new(TaikoL1OwnershipTransferStarted)
	if err := _TaikoL1.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1OwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the TaikoL1 contract.
type TaikoL1OwnershipTransferredIterator struct {
	Event *TaikoL1OwnershipTransferred // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1OwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1OwnershipTransferred)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1OwnershipTransferred)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1OwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1OwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1OwnershipTransferred represents a OwnershipTransferred event raised by the TaikoL1 contract.
type TaikoL1OwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_TaikoL1 *TaikoL1Filterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*TaikoL1OwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1OwnershipTransferredIterator{contract: _TaikoL1.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_TaikoL1 *TaikoL1Filterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *TaikoL1OwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1OwnershipTransferred)
				if err := _TaikoL1.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseOwnershipTransferred is a log parse operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_TaikoL1 *TaikoL1Filterer) ParseOwnershipTransferred(log types.Log) (*TaikoL1OwnershipTransferred, error) {
	event := new(TaikoL1OwnershipTransferred)
	if err := _TaikoL1.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1PausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the TaikoL1 contract.
type TaikoL1PausedIterator struct {
	Event *TaikoL1Paused // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1PausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1Paused)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1Paused)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1PausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1PausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1Paused represents a Paused event raised by the TaikoL1 contract.
type TaikoL1Paused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_TaikoL1 *TaikoL1Filterer) FilterPaused(opts *bind.FilterOpts) (*TaikoL1PausedIterator, error) {

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &TaikoL1PausedIterator{contract: _TaikoL1.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_TaikoL1 *TaikoL1Filterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *TaikoL1Paused) (event.Subscription, error) {

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1Paused)
				if err := _TaikoL1.contract.UnpackLog(event, "Paused", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParsePaused is a log parse operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_TaikoL1 *TaikoL1Filterer) ParsePaused(log types.Log) (*TaikoL1Paused, error) {
	event := new(TaikoL1Paused)
	if err := _TaikoL1.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1ProvingPausedIterator is returned from FilterProvingPaused and is used to iterate over the raw logs and unpacked data for ProvingPaused events raised by the TaikoL1 contract.
type TaikoL1ProvingPausedIterator struct {
	Event *TaikoL1ProvingPaused // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1ProvingPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1ProvingPaused)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1ProvingPaused)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1ProvingPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1ProvingPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1ProvingPaused represents a ProvingPaused event raised by the TaikoL1 contract.
type TaikoL1ProvingPaused struct {
	Paused bool
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterProvingPaused is a free log retrieval operation binding the contract event 0xed64db85835d07c3c990b8ebdd55e32d64e5ed53143b6ef2179e7bfaf17ddc3b.
//
// Solidity: event ProvingPaused(bool paused)
func (_TaikoL1 *TaikoL1Filterer) FilterProvingPaused(opts *bind.FilterOpts) (*TaikoL1ProvingPausedIterator, error) {

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "ProvingPaused")
	if err != nil {
		return nil, err
	}
	return &TaikoL1ProvingPausedIterator{contract: _TaikoL1.contract, event: "ProvingPaused", logs: logs, sub: sub}, nil
}

// WatchProvingPaused is a free log subscription operation binding the contract event 0xed64db85835d07c3c990b8ebdd55e32d64e5ed53143b6ef2179e7bfaf17ddc3b.
//
// Solidity: event ProvingPaused(bool paused)
func (_TaikoL1 *TaikoL1Filterer) WatchProvingPaused(opts *bind.WatchOpts, sink chan<- *TaikoL1ProvingPaused) (event.Subscription, error) {

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "ProvingPaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1ProvingPaused)
				if err := _TaikoL1.contract.UnpackLog(event, "ProvingPaused", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseProvingPaused is a log parse operation binding the contract event 0xed64db85835d07c3c990b8ebdd55e32d64e5ed53143b6ef2179e7bfaf17ddc3b.
//
// Solidity: event ProvingPaused(bool paused)
func (_TaikoL1 *TaikoL1Filterer) ParseProvingPaused(log types.Log) (*TaikoL1ProvingPaused, error) {
	event := new(TaikoL1ProvingPaused)
	if err := _TaikoL1.contract.UnpackLog(event, "ProvingPaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1StateVariablesUpdatedIterator is returned from FilterStateVariablesUpdated and is used to iterate over the raw logs and unpacked data for StateVariablesUpdated events raised by the TaikoL1 contract.
type TaikoL1StateVariablesUpdatedIterator struct {
	Event *TaikoL1StateVariablesUpdated // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1StateVariablesUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1StateVariablesUpdated)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1StateVariablesUpdated)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1StateVariablesUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1StateVariablesUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1StateVariablesUpdated represents a StateVariablesUpdated event raised by the TaikoL1 contract.
type TaikoL1StateVariablesUpdated struct {
	SlotB TaikoDataSlotB
	Raw   types.Log // Blockchain specific contextual infos
}

// FilterStateVariablesUpdated is a free log retrieval operation binding the contract event 0xb4be1a16d35fdd62eeaf9f552e025df3639847ddf2d61f011c72565056785ad2.
//
// Solidity: event StateVariablesUpdated((uint64,uint64,bool,uint56,uint64) slotB)
func (_TaikoL1 *TaikoL1Filterer) FilterStateVariablesUpdated(opts *bind.FilterOpts) (*TaikoL1StateVariablesUpdatedIterator, error) {

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "StateVariablesUpdated")
	if err != nil {
		return nil, err
	}
	return &TaikoL1StateVariablesUpdatedIterator{contract: _TaikoL1.contract, event: "StateVariablesUpdated", logs: logs, sub: sub}, nil
}

// WatchStateVariablesUpdated is a free log subscription operation binding the contract event 0xb4be1a16d35fdd62eeaf9f552e025df3639847ddf2d61f011c72565056785ad2.
//
// Solidity: event StateVariablesUpdated((uint64,uint64,bool,uint56,uint64) slotB)
func (_TaikoL1 *TaikoL1Filterer) WatchStateVariablesUpdated(opts *bind.WatchOpts, sink chan<- *TaikoL1StateVariablesUpdated) (event.Subscription, error) {

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "StateVariablesUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1StateVariablesUpdated)
				if err := _TaikoL1.contract.UnpackLog(event, "StateVariablesUpdated", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseStateVariablesUpdated is a log parse operation binding the contract event 0xb4be1a16d35fdd62eeaf9f552e025df3639847ddf2d61f011c72565056785ad2.
//
// Solidity: event StateVariablesUpdated((uint64,uint64,bool,uint56,uint64) slotB)
func (_TaikoL1 *TaikoL1Filterer) ParseStateVariablesUpdated(log types.Log) (*TaikoL1StateVariablesUpdated, error) {
	event := new(TaikoL1StateVariablesUpdated)
	if err := _TaikoL1.contract.UnpackLog(event, "StateVariablesUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1TransitionContestedIterator is returned from FilterTransitionContested and is used to iterate over the raw logs and unpacked data for TransitionContested events raised by the TaikoL1 contract.
type TaikoL1TransitionContestedIterator struct {
	Event *TaikoL1TransitionContested // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1TransitionContestedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1TransitionContested)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1TransitionContested)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1TransitionContestedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1TransitionContestedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1TransitionContested represents a TransitionContested event raised by the TaikoL1 contract.
type TaikoL1TransitionContested struct {
	BlockId     *big.Int
	Tran        TaikoDataTransition
	Contester   common.Address
	ContestBond *big.Int
	Tier        uint16
	Raw         types.Log // Blockchain specific contextual infos
}

// FilterTransitionContested is a free log retrieval operation binding the contract event 0xb4c0a86c1ff239277697775b1e91d3375fd3a5ef6b345aa4e2f6001c890558f6.
//
// Solidity: event TransitionContested(uint256 indexed blockId, (bytes32,bytes32,bytes32,bytes32) tran, address contester, uint96 contestBond, uint16 tier)
func (_TaikoL1 *TaikoL1Filterer) FilterTransitionContested(opts *bind.FilterOpts, blockId []*big.Int) (*TaikoL1TransitionContestedIterator, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "TransitionContested", blockIdRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1TransitionContestedIterator{contract: _TaikoL1.contract, event: "TransitionContested", logs: logs, sub: sub}, nil
}

// WatchTransitionContested is a free log subscription operation binding the contract event 0xb4c0a86c1ff239277697775b1e91d3375fd3a5ef6b345aa4e2f6001c890558f6.
//
// Solidity: event TransitionContested(uint256 indexed blockId, (bytes32,bytes32,bytes32,bytes32) tran, address contester, uint96 contestBond, uint16 tier)
func (_TaikoL1 *TaikoL1Filterer) WatchTransitionContested(opts *bind.WatchOpts, sink chan<- *TaikoL1TransitionContested, blockId []*big.Int) (event.Subscription, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "TransitionContested", blockIdRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1TransitionContested)
				if err := _TaikoL1.contract.UnpackLog(event, "TransitionContested", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseTransitionContested is a log parse operation binding the contract event 0xb4c0a86c1ff239277697775b1e91d3375fd3a5ef6b345aa4e2f6001c890558f6.
//
// Solidity: event TransitionContested(uint256 indexed blockId, (bytes32,bytes32,bytes32,bytes32) tran, address contester, uint96 contestBond, uint16 tier)
func (_TaikoL1 *TaikoL1Filterer) ParseTransitionContested(log types.Log) (*TaikoL1TransitionContested, error) {
	event := new(TaikoL1TransitionContested)
	if err := _TaikoL1.contract.UnpackLog(event, "TransitionContested", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1TransitionContestedV2Iterator is returned from FilterTransitionContestedV2 and is used to iterate over the raw logs and unpacked data for TransitionContestedV2 events raised by the TaikoL1 contract.
type TaikoL1TransitionContestedV2Iterator struct {
	Event *TaikoL1TransitionContestedV2 // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1TransitionContestedV2Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1TransitionContestedV2)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1TransitionContestedV2)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1TransitionContestedV2Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1TransitionContestedV2Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1TransitionContestedV2 represents a TransitionContestedV2 event raised by the TaikoL1 contract.
type TaikoL1TransitionContestedV2 struct {
	BlockId     *big.Int
	Tran        TaikoDataTransition
	Contester   common.Address
	ContestBond *big.Int
	Tier        uint16
	ProposedIn  uint64
	Raw         types.Log // Blockchain specific contextual infos
}

// FilterTransitionContestedV2 is a free log retrieval operation binding the contract event 0x53b2379d5e9bcacdfe56b4a51c3fd92ebfff4b1e8e8638f7f7e85163260a6f99.
//
// Solidity: event TransitionContestedV2(uint256 indexed blockId, (bytes32,bytes32,bytes32,bytes32) tran, address contester, uint96 contestBond, uint16 tier, uint64 proposedIn)
func (_TaikoL1 *TaikoL1Filterer) FilterTransitionContestedV2(opts *bind.FilterOpts, blockId []*big.Int) (*TaikoL1TransitionContestedV2Iterator, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "TransitionContestedV2", blockIdRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1TransitionContestedV2Iterator{contract: _TaikoL1.contract, event: "TransitionContestedV2", logs: logs, sub: sub}, nil
}

// WatchTransitionContestedV2 is a free log subscription operation binding the contract event 0x53b2379d5e9bcacdfe56b4a51c3fd92ebfff4b1e8e8638f7f7e85163260a6f99.
//
// Solidity: event TransitionContestedV2(uint256 indexed blockId, (bytes32,bytes32,bytes32,bytes32) tran, address contester, uint96 contestBond, uint16 tier, uint64 proposedIn)
func (_TaikoL1 *TaikoL1Filterer) WatchTransitionContestedV2(opts *bind.WatchOpts, sink chan<- *TaikoL1TransitionContestedV2, blockId []*big.Int) (event.Subscription, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "TransitionContestedV2", blockIdRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1TransitionContestedV2)
				if err := _TaikoL1.contract.UnpackLog(event, "TransitionContestedV2", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseTransitionContestedV2 is a log parse operation binding the contract event 0x53b2379d5e9bcacdfe56b4a51c3fd92ebfff4b1e8e8638f7f7e85163260a6f99.
//
// Solidity: event TransitionContestedV2(uint256 indexed blockId, (bytes32,bytes32,bytes32,bytes32) tran, address contester, uint96 contestBond, uint16 tier, uint64 proposedIn)
func (_TaikoL1 *TaikoL1Filterer) ParseTransitionContestedV2(log types.Log) (*TaikoL1TransitionContestedV2, error) {
	event := new(TaikoL1TransitionContestedV2)
	if err := _TaikoL1.contract.UnpackLog(event, "TransitionContestedV2", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1TransitionProvedIterator is returned from FilterTransitionProved and is used to iterate over the raw logs and unpacked data for TransitionProved events raised by the TaikoL1 contract.
type TaikoL1TransitionProvedIterator struct {
	Event *TaikoL1TransitionProved // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1TransitionProvedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1TransitionProved)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1TransitionProved)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1TransitionProvedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1TransitionProvedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1TransitionProved represents a TransitionProved event raised by the TaikoL1 contract.
type TaikoL1TransitionProved struct {
	BlockId      *big.Int
	Tran         TaikoDataTransition
	Prover       common.Address
	ValidityBond *big.Int
	Tier         uint16
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterTransitionProved is a free log retrieval operation binding the contract event 0xc195e4be3b936845492b8be4b1cf604db687a4d79ad84d979499c136f8e6701f.
//
// Solidity: event TransitionProved(uint256 indexed blockId, (bytes32,bytes32,bytes32,bytes32) tran, address prover, uint96 validityBond, uint16 tier)
func (_TaikoL1 *TaikoL1Filterer) FilterTransitionProved(opts *bind.FilterOpts, blockId []*big.Int) (*TaikoL1TransitionProvedIterator, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "TransitionProved", blockIdRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1TransitionProvedIterator{contract: _TaikoL1.contract, event: "TransitionProved", logs: logs, sub: sub}, nil
}

// WatchTransitionProved is a free log subscription operation binding the contract event 0xc195e4be3b936845492b8be4b1cf604db687a4d79ad84d979499c136f8e6701f.
//
// Solidity: event TransitionProved(uint256 indexed blockId, (bytes32,bytes32,bytes32,bytes32) tran, address prover, uint96 validityBond, uint16 tier)
func (_TaikoL1 *TaikoL1Filterer) WatchTransitionProved(opts *bind.WatchOpts, sink chan<- *TaikoL1TransitionProved, blockId []*big.Int) (event.Subscription, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "TransitionProved", blockIdRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1TransitionProved)
				if err := _TaikoL1.contract.UnpackLog(event, "TransitionProved", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseTransitionProved is a log parse operation binding the contract event 0xc195e4be3b936845492b8be4b1cf604db687a4d79ad84d979499c136f8e6701f.
//
// Solidity: event TransitionProved(uint256 indexed blockId, (bytes32,bytes32,bytes32,bytes32) tran, address prover, uint96 validityBond, uint16 tier)
func (_TaikoL1 *TaikoL1Filterer) ParseTransitionProved(log types.Log) (*TaikoL1TransitionProved, error) {
	event := new(TaikoL1TransitionProved)
	if err := _TaikoL1.contract.UnpackLog(event, "TransitionProved", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1TransitionProvedV2Iterator is returned from FilterTransitionProvedV2 and is used to iterate over the raw logs and unpacked data for TransitionProvedV2 events raised by the TaikoL1 contract.
type TaikoL1TransitionProvedV2Iterator struct {
	Event *TaikoL1TransitionProvedV2 // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1TransitionProvedV2Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1TransitionProvedV2)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1TransitionProvedV2)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1TransitionProvedV2Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1TransitionProvedV2Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1TransitionProvedV2 represents a TransitionProvedV2 event raised by the TaikoL1 contract.
type TaikoL1TransitionProvedV2 struct {
	BlockId      *big.Int
	Tran         TaikoDataTransition
	Prover       common.Address
	ValidityBond *big.Int
	Tier         uint16
	ProposedIn   uint64
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterTransitionProvedV2 is a free log retrieval operation binding the contract event 0x11a9112e5724f21b226e2535a95a264a80c9626ed4c0923faaa9fa6556467488.
//
// Solidity: event TransitionProvedV2(uint256 indexed blockId, (bytes32,bytes32,bytes32,bytes32) tran, address prover, uint96 validityBond, uint16 tier, uint64 proposedIn)
func (_TaikoL1 *TaikoL1Filterer) FilterTransitionProvedV2(opts *bind.FilterOpts, blockId []*big.Int) (*TaikoL1TransitionProvedV2Iterator, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "TransitionProvedV2", blockIdRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1TransitionProvedV2Iterator{contract: _TaikoL1.contract, event: "TransitionProvedV2", logs: logs, sub: sub}, nil
}

// WatchTransitionProvedV2 is a free log subscription operation binding the contract event 0x11a9112e5724f21b226e2535a95a264a80c9626ed4c0923faaa9fa6556467488.
//
// Solidity: event TransitionProvedV2(uint256 indexed blockId, (bytes32,bytes32,bytes32,bytes32) tran, address prover, uint96 validityBond, uint16 tier, uint64 proposedIn)
func (_TaikoL1 *TaikoL1Filterer) WatchTransitionProvedV2(opts *bind.WatchOpts, sink chan<- *TaikoL1TransitionProvedV2, blockId []*big.Int) (event.Subscription, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "TransitionProvedV2", blockIdRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1TransitionProvedV2)
				if err := _TaikoL1.contract.UnpackLog(event, "TransitionProvedV2", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseTransitionProvedV2 is a log parse operation binding the contract event 0x11a9112e5724f21b226e2535a95a264a80c9626ed4c0923faaa9fa6556467488.
//
// Solidity: event TransitionProvedV2(uint256 indexed blockId, (bytes32,bytes32,bytes32,bytes32) tran, address prover, uint96 validityBond, uint16 tier, uint64 proposedIn)
func (_TaikoL1 *TaikoL1Filterer) ParseTransitionProvedV2(log types.Log) (*TaikoL1TransitionProvedV2, error) {
	event := new(TaikoL1TransitionProvedV2)
	if err := _TaikoL1.contract.UnpackLog(event, "TransitionProvedV2", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1UnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the TaikoL1 contract.
type TaikoL1UnpausedIterator struct {
	Event *TaikoL1Unpaused // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1UnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1Unpaused)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1Unpaused)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1UnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1UnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1Unpaused represents a Unpaused event raised by the TaikoL1 contract.
type TaikoL1Unpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_TaikoL1 *TaikoL1Filterer) FilterUnpaused(opts *bind.FilterOpts) (*TaikoL1UnpausedIterator, error) {

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &TaikoL1UnpausedIterator{contract: _TaikoL1.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_TaikoL1 *TaikoL1Filterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *TaikoL1Unpaused) (event.Subscription, error) {

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1Unpaused)
				if err := _TaikoL1.contract.UnpackLog(event, "Unpaused", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseUnpaused is a log parse operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_TaikoL1 *TaikoL1Filterer) ParseUnpaused(log types.Log) (*TaikoL1Unpaused, error) {
	event := new(TaikoL1Unpaused)
	if err := _TaikoL1.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1UpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the TaikoL1 contract.
type TaikoL1UpgradedIterator struct {
	Event *TaikoL1Upgraded // Event containing the contract specifics and raw log

	contract *bind.BoundContract // Generic contract to use for unpacking event data
	event    string              // Event name to use for unpacking event data

	logs chan types.Log        // Log channel receiving the found contract events
	sub  ethereum.Subscription // Subscription for errors, completion and termination
	done bool                  // Whether the subscription completed delivering logs
	fail error                 // Occurred error to stop iteration
}

// Next advances the iterator to the subsequent event, returning whether there
// are any more events found. In case of a retrieval or parsing error, false is
// returned and Error() can be queried for the exact failure.
func (it *TaikoL1UpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1Upgraded)
			if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
				it.fail = err
				return false
			}
			it.Event.Raw = log
			return true

		default:
			return false
		}
	}
	// Iterator still in progress, wait for either a data or an error event
	select {
	case log := <-it.logs:
		it.Event = new(TaikoL1Upgraded)
		if err := it.contract.UnpackLog(it.Event, it.event, log); err != nil {
			it.fail = err
			return false
		}
		it.Event.Raw = log
		return true

	case err := <-it.sub.Err():
		it.done = true
		it.fail = err
		return it.Next()
	}
}

// Error returns any retrieval or parsing error occurred during filtering.
func (it *TaikoL1UpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1UpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1Upgraded represents a Upgraded event raised by the TaikoL1 contract.
type TaikoL1Upgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_TaikoL1 *TaikoL1Filterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*TaikoL1UpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1UpgradedIterator{contract: _TaikoL1.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_TaikoL1 *TaikoL1Filterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *TaikoL1Upgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1Upgraded)
				if err := _TaikoL1.contract.UnpackLog(event, "Upgraded", log); err != nil {
					return err
				}
				event.Raw = log

				select {
				case sink <- event:
				case err := <-sub.Err():
					return err
				case <-quit:
					return nil
				}
			case err := <-sub.Err():
				return err
			case <-quit:
				return nil
			}
		}
	}), nil
}

// ParseUpgraded is a log parse operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_TaikoL1 *TaikoL1Filterer) ParseUpgraded(log types.Log) (*TaikoL1Upgraded, error) {
	event := new(TaikoL1Upgraded)
	if err := _TaikoL1.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
