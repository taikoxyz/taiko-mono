// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package taikoinbox

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

// ITaikoInboxBatch is an auto generated low-level Go binding around an user-defined struct.
type ITaikoInboxBatch struct {
	MetaHash             [32]byte
	LastBlockId          uint64
	Reserved3            *big.Int
	LivenessBond         *big.Int
	BatchId              uint64
	LastBlockTimestamp   uint64
	AnchorBlockId        uint64
	NextTransitionId     *big.Int
	Reserved4            uint8
	VerifiedTransitionId *big.Int
}

// ITaikoInboxBatchInfo is an auto generated low-level Go binding around an user-defined struct.
type ITaikoInboxBatchInfo struct {
	TxsHash            [32]byte
	Blocks             []ITaikoInboxBlockParams
	BlobHashes         [][32]byte
	ExtraData          [32]byte
	Coinbase           common.Address
	ProposedIn         uint64
	BlobByteOffset     uint32
	BlobByteSize       uint32
	GasLimit           uint32
	LastBlockId        uint64
	LastBlockTimestamp uint64
	AnchorBlockId      uint64
	AnchorBlockHash    [32]byte
	BaseFeeConfig      LibSharedDataBaseFeeConfig
}

// ITaikoInboxBatchMetadata is an auto generated low-level Go binding around an user-defined struct.
type ITaikoInboxBatchMetadata struct {
	InfoHash   [32]byte
	Proposer   common.Address
	BatchId    uint64
	ProposedAt uint64
}

// ITaikoInboxBlockParams is an auto generated low-level Go binding around an user-defined struct.
type ITaikoInboxBlockParams struct {
	NumTransactions uint16
	TimeShift       uint8
	SignalSlots     [][32]byte
}

// ITaikoInboxConfig is an auto generated low-level Go binding around an user-defined struct.
type ITaikoInboxConfig struct {
	ChainId               uint64
	MaxUnverifiedBatches  uint64
	BatchRingBufferSize   uint64
	MaxBatchesToVerify    uint64
	BlockMaxGasLimit      uint32
	LivenessBondBase      *big.Int
	LivenessBondPerBlock  *big.Int
	StateRootSyncInternal uint8
	MaxAnchorHeightOffset uint64
	BaseFeeConfig         LibSharedDataBaseFeeConfig
	ProvingWindow         uint16
	CooldownWindow        *big.Int
	MaxSignalsToReceive   uint8
	MaxBlocksPerBatch     uint16
	ForkHeights           ITaikoInboxForkHeights
}

// ITaikoInboxForkHeights is an auto generated low-level Go binding around an user-defined struct.
type ITaikoInboxForkHeights struct {
	Ontake uint64
	Pacaya uint64
}

// ITaikoInboxStats1 is an auto generated low-level Go binding around an user-defined struct.
type ITaikoInboxStats1 struct {
	GenesisHeight     uint64
	Reserved2         uint64
	LastSyncedBatchId uint64
	LastSyncedAt      uint64
}

// ITaikoInboxStats2 is an auto generated low-level Go binding around an user-defined struct.
type ITaikoInboxStats2 struct {
	NumBatches          uint64
	LastVerifiedBatchId uint64
	Paused              bool
	LastProposedIn      *big.Int
	LastUnpausedAt      uint64
}

// ITaikoInboxTransition is an auto generated low-level Go binding around an user-defined struct.
type ITaikoInboxTransition struct {
	ParentHash [32]byte
	BlockHash  [32]byte
	StateRoot  [32]byte
}

// ITaikoInboxTransitionState is an auto generated low-level Go binding around an user-defined struct.
type ITaikoInboxTransitionState struct {
	ParentHash      [32]byte
	BlockHash       [32]byte
	StateRoot       [32]byte
	Prover          common.Address
	InProvingWindow bool
	CreatedAt       *big.Int
}

// LibSharedDataBaseFeeConfig is an auto generated low-level Go binding around an user-defined struct.
type LibSharedDataBaseFeeConfig struct {
	AdjustmentQuotient     uint8
	SharingPctg            uint8
	GasIssuancePerSecond   uint32
	MinGasExcess           uint64
	MaxGasIssuancePerBlock uint32
}

// TaikoInboxMetaData contains all meta data concerning the TaikoInbox contract.
var TaikoInboxMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"bondBalanceOf\",\"inputs\":[{\"name\":\"_user\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"bondToken\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"depositBond\",\"inputs\":[{\"name\":\"_amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"getBatch\",\"inputs\":[{\"name\":\"_batchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"outputs\":[{\"name\":\"batch_\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.Batch\",\"components\":[{\"name\":\"metaHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"lastBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"reserved3\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"livenessBond\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"batchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastBlockTimestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"anchorBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"nextTransitionId\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"reserved4\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"verifiedTransitionId\",\"type\":\"uint24\",\"internalType\":\"uint24\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getBatchVerifyingTransition\",\"inputs\":[{\"name\":\"_batchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"outputs\":[{\"name\":\"ts_\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.TransitionState\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"prover\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"inProvingWindow\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"createdAt\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getLastSyncedTransition\",\"inputs\":[],\"outputs\":[{\"name\":\"batchId_\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blockId_\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"ts_\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.TransitionState\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"prover\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"inProvingWindow\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"createdAt\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getLastVerifiedTransition\",\"inputs\":[],\"outputs\":[{\"name\":\"batchId_\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blockId_\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"ts_\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.TransitionState\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"prover\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"inProvingWindow\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"createdAt\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getStats1\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.Stats1\",\"components\":[{\"name\":\"genesisHeight\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"__reserved2\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastSyncedBatchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastSyncedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getStats2\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.Stats2\",\"components\":[{\"name\":\"numBatches\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastVerifiedBatchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"paused\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"lastProposedIn\",\"type\":\"uint56\",\"internalType\":\"uint56\"},{\"name\":\"lastUnpausedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTransitionById\",\"inputs\":[{\"name\":\"_batchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_tid\",\"type\":\"uint24\",\"internalType\":\"uint24\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.TransitionState\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"prover\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"inProvingWindow\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"createdAt\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTransitionByParentHash\",\"inputs\":[{\"name\":\"_batchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.TransitionState\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"prover\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"inProvingWindow\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"createdAt\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"impl\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inNonReentrant\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_genesisBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isOnL1\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pacayaConfig\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.Config\",\"components\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxUnverifiedBatches\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"batchRingBufferSize\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxBatchesToVerify\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blockMaxGasLimit\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"livenessBondBase\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"livenessBondPerBlock\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"stateRootSyncInternal\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"maxAnchorHeightOffset\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"baseFeeConfig\",\"type\":\"tuple\",\"internalType\":\"structLibSharedData.BaseFeeConfig\",\"components\":[{\"name\":\"adjustmentQuotient\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"gasIssuancePerSecond\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"minGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxGasIssuancePerBlock\",\"type\":\"uint32\",\"internalType\":\"uint32\"}]},{\"name\":\"provingWindow\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"cooldownWindow\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"maxSignalsToReceive\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"maxBlocksPerBatch\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"forkHeights\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.ForkHeights\",\"components\":[{\"name\":\"ontake\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"pacaya\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proposeBatch\",\"inputs\":[{\"name\":\"_params\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"_txList\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"info_\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.BatchInfo\",\"components\":[{\"name\":\"txsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blocks\",\"type\":\"tuple[]\",\"internalType\":\"structITaikoInbox.BlockParams[]\",\"components\":[{\"name\":\"numTransactions\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"timeShift\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"signalSlots\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}]},{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"extraData\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"coinbase\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"proposedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobByteOffset\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobByteSize\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"gasLimit\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"lastBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastBlockTimestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"anchorBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"anchorBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"baseFeeConfig\",\"type\":\"tuple\",\"internalType\":\"structLibSharedData.BaseFeeConfig\",\"components\":[{\"name\":\"adjustmentQuotient\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"gasIssuancePerSecond\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"minGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxGasIssuancePerBlock\",\"type\":\"uint32\",\"internalType\":\"uint32\"}]}]},{\"name\":\"meta_\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.BatchMetadata\",\"components\":[{\"name\":\"infoHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"batchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"proposedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proveBatches\",\"inputs\":[{\"name\":\"_params\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"_proof\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolver\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"state\",\"inputs\":[],\"outputs\":[{\"name\":\"__reserve1\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stats1\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.Stats1\",\"components\":[{\"name\":\"genesisHeight\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"__reserved2\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastSyncedBatchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastSyncedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]},{\"name\":\"stats2\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.Stats2\",\"components\":[{\"name\":\"numBatches\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastVerifiedBatchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"paused\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"lastProposedIn\",\"type\":\"uint56\",\"internalType\":\"uint56\"},{\"name\":\"lastUnpausedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"verifyBatches\",\"inputs\":[{\"name\":\"_length\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"withdrawBond\",\"inputs\":[{\"name\":\"_amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"writeTransition\",\"inputs\":[{\"name\":\"_batchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_prover\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_inProvingWindow\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BatchProposed\",\"inputs\":[{\"name\":\"info\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structITaikoInbox.BatchInfo\",\"components\":[{\"name\":\"txsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blocks\",\"type\":\"tuple[]\",\"internalType\":\"structITaikoInbox.BlockParams[]\",\"components\":[{\"name\":\"numTransactions\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"timeShift\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"signalSlots\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}]},{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"extraData\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"coinbase\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"proposedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobByteOffset\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobByteSize\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"gasLimit\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"lastBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastBlockTimestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"anchorBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"anchorBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"baseFeeConfig\",\"type\":\"tuple\",\"internalType\":\"structLibSharedData.BaseFeeConfig\",\"components\":[{\"name\":\"adjustmentQuotient\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"gasIssuancePerSecond\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"minGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxGasIssuancePerBlock\",\"type\":\"uint32\",\"internalType\":\"uint32\"}]}]},{\"name\":\"meta\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structITaikoInbox.BatchMetadata\",\"components\":[{\"name\":\"infoHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"batchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"proposedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]},{\"name\":\"txList\",\"type\":\"bytes\",\"indexed\":false,\"internalType\":\"bytes\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BatchesProved\",\"inputs\":[{\"name\":\"verifier\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"batchIds\",\"type\":\"uint64[]\",\"indexed\":false,\"internalType\":\"uint64[]\"},{\"name\":\"transitions\",\"type\":\"tuple[]\",\"indexed\":false,\"internalType\":\"structITaikoInbox.Transition[]\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BatchesVerified\",\"inputs\":[{\"name\":\"batchId\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondCredited\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondDebited\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondDeposited\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondWithdrawn\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ConflictingProof\",\"inputs\":[{\"name\":\"batchId\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"},{\"name\":\"oldTran\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structITaikoInbox.TransitionState\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"prover\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"inProvingWindow\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"createdAt\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]},{\"name\":\"newTran\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structITaikoInbox.Transition\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Stats1Updated\",\"inputs\":[{\"name\":\"stats1\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structITaikoInbox.Stats1\",\"components\":[{\"name\":\"genesisHeight\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"__reserved2\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastSyncedBatchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastSyncedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Stats2Updated\",\"inputs\":[{\"name\":\"stats2\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structITaikoInbox.Stats2\",\"components\":[{\"name\":\"numBatches\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastVerifiedBatchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"paused\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"lastProposedIn\",\"type\":\"uint56\",\"internalType\":\"uint56\"},{\"name\":\"lastUnpausedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransitionWritten\",\"inputs\":[{\"name\":\"batchId\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"},{\"name\":\"tid\",\"type\":\"uint24\",\"indexed\":false,\"internalType\":\"uint24\"},{\"name\":\"ts\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structITaikoInbox.TransitionState\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"prover\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"inProvingWindow\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"createdAt\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCESS_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AnchorBlockIdSmallerThanParent\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AnchorBlockIdTooLarge\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AnchorBlockIdTooSmall\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ArraySizesMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"BatchNotFound\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"BatchVerified\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"BlobNotFound\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"BlobNotSpecified\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"BlockNotFound\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ContractPaused\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CustomProposerMissing\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CustomProposerNotAllowed\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ETH_TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EtherNotPaidAsBond\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FUNC_NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ForkNotActivated\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InsufficientBond\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidBlobParams\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidGenesisBlockHash\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidParams\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidTransitionBlockHash\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidTransitionParentHash\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidTransitionStateRoot\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MetaHashMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MsgValueNotZero\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NoBlocksToProve\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotFirstProposal\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotInboxWrapper\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ParentMetaHashMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SameTransition\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SignalNotSent\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"TimestampSmallerThanParent\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"TimestampTooLarge\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"TimestampTooSmall\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"TooManyBatches\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"TooManyBlocks\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"TooManySignals\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"TransitionNotFound\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_VALUE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZeroAnchorBlockHash\",\"inputs\":[]}]",
}

// TaikoInboxABI is the input ABI used to generate the binding from.
// Deprecated: Use TaikoInboxMetaData.ABI instead.
var TaikoInboxABI = TaikoInboxMetaData.ABI

// TaikoInbox is an auto generated Go binding around an Ethereum contract.
type TaikoInbox struct {
	TaikoInboxCaller     // Read-only binding to the contract
	TaikoInboxTransactor // Write-only binding to the contract
	TaikoInboxFilterer   // Log filterer for contract events
}

// TaikoInboxCaller is an auto generated read-only Go binding around an Ethereum contract.
type TaikoInboxCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoInboxTransactor is an auto generated write-only Go binding around an Ethereum contract.
type TaikoInboxTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoInboxFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type TaikoInboxFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoInboxSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type TaikoInboxSession struct {
	Contract     *TaikoInbox       // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// TaikoInboxCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type TaikoInboxCallerSession struct {
	Contract *TaikoInboxCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts     // Call options to use throughout this session
}

// TaikoInboxTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type TaikoInboxTransactorSession struct {
	Contract     *TaikoInboxTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts     // Transaction auth options to use throughout this session
}

// TaikoInboxRaw is an auto generated low-level Go binding around an Ethereum contract.
type TaikoInboxRaw struct {
	Contract *TaikoInbox // Generic contract binding to access the raw methods on
}

// TaikoInboxCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type TaikoInboxCallerRaw struct {
	Contract *TaikoInboxCaller // Generic read-only contract binding to access the raw methods on
}

// TaikoInboxTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type TaikoInboxTransactorRaw struct {
	Contract *TaikoInboxTransactor // Generic write-only contract binding to access the raw methods on
}

// NewTaikoInbox creates a new instance of TaikoInbox, bound to a specific deployed contract.
func NewTaikoInbox(address common.Address, backend bind.ContractBackend) (*TaikoInbox, error) {
	contract, err := bindTaikoInbox(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &TaikoInbox{TaikoInboxCaller: TaikoInboxCaller{contract: contract}, TaikoInboxTransactor: TaikoInboxTransactor{contract: contract}, TaikoInboxFilterer: TaikoInboxFilterer{contract: contract}}, nil
}

// NewTaikoInboxCaller creates a new read-only instance of TaikoInbox, bound to a specific deployed contract.
func NewTaikoInboxCaller(address common.Address, caller bind.ContractCaller) (*TaikoInboxCaller, error) {
	contract, err := bindTaikoInbox(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &TaikoInboxCaller{contract: contract}, nil
}

// NewTaikoInboxTransactor creates a new write-only instance of TaikoInbox, bound to a specific deployed contract.
func NewTaikoInboxTransactor(address common.Address, transactor bind.ContractTransactor) (*TaikoInboxTransactor, error) {
	contract, err := bindTaikoInbox(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &TaikoInboxTransactor{contract: contract}, nil
}

// NewTaikoInboxFilterer creates a new log filterer instance of TaikoInbox, bound to a specific deployed contract.
func NewTaikoInboxFilterer(address common.Address, filterer bind.ContractFilterer) (*TaikoInboxFilterer, error) {
	contract, err := bindTaikoInbox(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &TaikoInboxFilterer{contract: contract}, nil
}

// bindTaikoInbox binds a generic wrapper to an already deployed contract.
func bindTaikoInbox(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := TaikoInboxMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TaikoInbox *TaikoInboxRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TaikoInbox.Contract.TaikoInboxCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TaikoInbox *TaikoInboxRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoInbox.Contract.TaikoInboxTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TaikoInbox *TaikoInboxRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TaikoInbox.Contract.TaikoInboxTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TaikoInbox *TaikoInboxCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TaikoInbox.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TaikoInbox *TaikoInboxTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoInbox.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TaikoInbox *TaikoInboxTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TaikoInbox.Contract.contract.Transact(opts, method, params...)
}

// BondBalanceOf is a free data retrieval call binding the contract method 0xa9c2c835.
//
// Solidity: function bondBalanceOf(address _user) view returns(uint256)
func (_TaikoInbox *TaikoInboxCaller) BondBalanceOf(opts *bind.CallOpts, _user common.Address) (*big.Int, error) {
	var out []interface{}
	err := _TaikoInbox.contract.Call(opts, &out, "bondBalanceOf", _user)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// BondBalanceOf is a free data retrieval call binding the contract method 0xa9c2c835.
//
// Solidity: function bondBalanceOf(address _user) view returns(uint256)
func (_TaikoInbox *TaikoInboxSession) BondBalanceOf(_user common.Address) (*big.Int, error) {
	return _TaikoInbox.Contract.BondBalanceOf(&_TaikoInbox.CallOpts, _user)
}

// BondBalanceOf is a free data retrieval call binding the contract method 0xa9c2c835.
//
// Solidity: function bondBalanceOf(address _user) view returns(uint256)
func (_TaikoInbox *TaikoInboxCallerSession) BondBalanceOf(_user common.Address) (*big.Int, error) {
	return _TaikoInbox.Contract.BondBalanceOf(&_TaikoInbox.CallOpts, _user)
}

// BondToken is a free data retrieval call binding the contract method 0xc28f4392.
//
// Solidity: function bondToken() view returns(address)
func (_TaikoInbox *TaikoInboxCaller) BondToken(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoInbox.contract.Call(opts, &out, "bondToken")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// BondToken is a free data retrieval call binding the contract method 0xc28f4392.
//
// Solidity: function bondToken() view returns(address)
func (_TaikoInbox *TaikoInboxSession) BondToken() (common.Address, error) {
	return _TaikoInbox.Contract.BondToken(&_TaikoInbox.CallOpts)
}

// BondToken is a free data retrieval call binding the contract method 0xc28f4392.
//
// Solidity: function bondToken() view returns(address)
func (_TaikoInbox *TaikoInboxCallerSession) BondToken() (common.Address, error) {
	return _TaikoInbox.Contract.BondToken(&_TaikoInbox.CallOpts)
}

// GetBatch is a free data retrieval call binding the contract method 0x888775d9.
//
// Solidity: function getBatch(uint64 _batchId) view returns((bytes32,uint64,uint96,uint96,uint64,uint64,uint64,uint24,uint8,uint24) batch_)
func (_TaikoInbox *TaikoInboxCaller) GetBatch(opts *bind.CallOpts, _batchId uint64) (ITaikoInboxBatch, error) {
	var out []interface{}
	err := _TaikoInbox.contract.Call(opts, &out, "getBatch", _batchId)

	if err != nil {
		return *new(ITaikoInboxBatch), err
	}

	out0 := *abi.ConvertType(out[0], new(ITaikoInboxBatch)).(*ITaikoInboxBatch)

	return out0, err

}

// GetBatch is a free data retrieval call binding the contract method 0x888775d9.
//
// Solidity: function getBatch(uint64 _batchId) view returns((bytes32,uint64,uint96,uint96,uint64,uint64,uint64,uint24,uint8,uint24) batch_)
func (_TaikoInbox *TaikoInboxSession) GetBatch(_batchId uint64) (ITaikoInboxBatch, error) {
	return _TaikoInbox.Contract.GetBatch(&_TaikoInbox.CallOpts, _batchId)
}

// GetBatch is a free data retrieval call binding the contract method 0x888775d9.
//
// Solidity: function getBatch(uint64 _batchId) view returns((bytes32,uint64,uint96,uint96,uint64,uint64,uint64,uint24,uint8,uint24) batch_)
func (_TaikoInbox *TaikoInboxCallerSession) GetBatch(_batchId uint64) (ITaikoInboxBatch, error) {
	return _TaikoInbox.Contract.GetBatch(&_TaikoInbox.CallOpts, _batchId)
}

// GetBatchVerifyingTransition is a free data retrieval call binding the contract method 0x7e7501dc.
//
// Solidity: function getBatchVerifyingTransition(uint64 _batchId) view returns((bytes32,bytes32,bytes32,address,bool,uint48) ts_)
func (_TaikoInbox *TaikoInboxCaller) GetBatchVerifyingTransition(opts *bind.CallOpts, _batchId uint64) (ITaikoInboxTransitionState, error) {
	var out []interface{}
	err := _TaikoInbox.contract.Call(opts, &out, "getBatchVerifyingTransition", _batchId)

	if err != nil {
		return *new(ITaikoInboxTransitionState), err
	}

	out0 := *abi.ConvertType(out[0], new(ITaikoInboxTransitionState)).(*ITaikoInboxTransitionState)

	return out0, err

}

// GetBatchVerifyingTransition is a free data retrieval call binding the contract method 0x7e7501dc.
//
// Solidity: function getBatchVerifyingTransition(uint64 _batchId) view returns((bytes32,bytes32,bytes32,address,bool,uint48) ts_)
func (_TaikoInbox *TaikoInboxSession) GetBatchVerifyingTransition(_batchId uint64) (ITaikoInboxTransitionState, error) {
	return _TaikoInbox.Contract.GetBatchVerifyingTransition(&_TaikoInbox.CallOpts, _batchId)
}

// GetBatchVerifyingTransition is a free data retrieval call binding the contract method 0x7e7501dc.
//
// Solidity: function getBatchVerifyingTransition(uint64 _batchId) view returns((bytes32,bytes32,bytes32,address,bool,uint48) ts_)
func (_TaikoInbox *TaikoInboxCallerSession) GetBatchVerifyingTransition(_batchId uint64) (ITaikoInboxTransitionState, error) {
	return _TaikoInbox.Contract.GetBatchVerifyingTransition(&_TaikoInbox.CallOpts, _batchId)
}

// GetLastSyncedTransition is a free data retrieval call binding the contract method 0xcee1136c.
//
// Solidity: function getLastSyncedTransition() view returns(uint64 batchId_, uint64 blockId_, (bytes32,bytes32,bytes32,address,bool,uint48) ts_)
func (_TaikoInbox *TaikoInboxCaller) GetLastSyncedTransition(opts *bind.CallOpts) (struct {
	BatchId uint64
	BlockId uint64
	Ts      ITaikoInboxTransitionState
}, error) {
	var out []interface{}
	err := _TaikoInbox.contract.Call(opts, &out, "getLastSyncedTransition")

	outstruct := new(struct {
		BatchId uint64
		BlockId uint64
		Ts      ITaikoInboxTransitionState
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.BatchId = *abi.ConvertType(out[0], new(uint64)).(*uint64)
	outstruct.BlockId = *abi.ConvertType(out[1], new(uint64)).(*uint64)
	outstruct.Ts = *abi.ConvertType(out[2], new(ITaikoInboxTransitionState)).(*ITaikoInboxTransitionState)

	return *outstruct, err

}

// GetLastSyncedTransition is a free data retrieval call binding the contract method 0xcee1136c.
//
// Solidity: function getLastSyncedTransition() view returns(uint64 batchId_, uint64 blockId_, (bytes32,bytes32,bytes32,address,bool,uint48) ts_)
func (_TaikoInbox *TaikoInboxSession) GetLastSyncedTransition() (struct {
	BatchId uint64
	BlockId uint64
	Ts      ITaikoInboxTransitionState
}, error) {
	return _TaikoInbox.Contract.GetLastSyncedTransition(&_TaikoInbox.CallOpts)
}

// GetLastSyncedTransition is a free data retrieval call binding the contract method 0xcee1136c.
//
// Solidity: function getLastSyncedTransition() view returns(uint64 batchId_, uint64 blockId_, (bytes32,bytes32,bytes32,address,bool,uint48) ts_)
func (_TaikoInbox *TaikoInboxCallerSession) GetLastSyncedTransition() (struct {
	BatchId uint64
	BlockId uint64
	Ts      ITaikoInboxTransitionState
}, error) {
	return _TaikoInbox.Contract.GetLastSyncedTransition(&_TaikoInbox.CallOpts)
}

// GetLastVerifiedTransition is a free data retrieval call binding the contract method 0x9c436473.
//
// Solidity: function getLastVerifiedTransition() view returns(uint64 batchId_, uint64 blockId_, (bytes32,bytes32,bytes32,address,bool,uint48) ts_)
func (_TaikoInbox *TaikoInboxCaller) GetLastVerifiedTransition(opts *bind.CallOpts) (struct {
	BatchId uint64
	BlockId uint64
	Ts      ITaikoInboxTransitionState
}, error) {
	var out []interface{}
	err := _TaikoInbox.contract.Call(opts, &out, "getLastVerifiedTransition")

	outstruct := new(struct {
		BatchId uint64
		BlockId uint64
		Ts      ITaikoInboxTransitionState
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.BatchId = *abi.ConvertType(out[0], new(uint64)).(*uint64)
	outstruct.BlockId = *abi.ConvertType(out[1], new(uint64)).(*uint64)
	outstruct.Ts = *abi.ConvertType(out[2], new(ITaikoInboxTransitionState)).(*ITaikoInboxTransitionState)

	return *outstruct, err

}

// GetLastVerifiedTransition is a free data retrieval call binding the contract method 0x9c436473.
//
// Solidity: function getLastVerifiedTransition() view returns(uint64 batchId_, uint64 blockId_, (bytes32,bytes32,bytes32,address,bool,uint48) ts_)
func (_TaikoInbox *TaikoInboxSession) GetLastVerifiedTransition() (struct {
	BatchId uint64
	BlockId uint64
	Ts      ITaikoInboxTransitionState
}, error) {
	return _TaikoInbox.Contract.GetLastVerifiedTransition(&_TaikoInbox.CallOpts)
}

// GetLastVerifiedTransition is a free data retrieval call binding the contract method 0x9c436473.
//
// Solidity: function getLastVerifiedTransition() view returns(uint64 batchId_, uint64 blockId_, (bytes32,bytes32,bytes32,address,bool,uint48) ts_)
func (_TaikoInbox *TaikoInboxCallerSession) GetLastVerifiedTransition() (struct {
	BatchId uint64
	BlockId uint64
	Ts      ITaikoInboxTransitionState
}, error) {
	return _TaikoInbox.Contract.GetLastVerifiedTransition(&_TaikoInbox.CallOpts)
}

// GetStats1 is a free data retrieval call binding the contract method 0x12ad809c.
//
// Solidity: function getStats1() view returns((uint64,uint64,uint64,uint64))
func (_TaikoInbox *TaikoInboxCaller) GetStats1(opts *bind.CallOpts) (ITaikoInboxStats1, error) {
	var out []interface{}
	err := _TaikoInbox.contract.Call(opts, &out, "getStats1")

	if err != nil {
		return *new(ITaikoInboxStats1), err
	}

	out0 := *abi.ConvertType(out[0], new(ITaikoInboxStats1)).(*ITaikoInboxStats1)

	return out0, err

}

// GetStats1 is a free data retrieval call binding the contract method 0x12ad809c.
//
// Solidity: function getStats1() view returns((uint64,uint64,uint64,uint64))
func (_TaikoInbox *TaikoInboxSession) GetStats1() (ITaikoInboxStats1, error) {
	return _TaikoInbox.Contract.GetStats1(&_TaikoInbox.CallOpts)
}

// GetStats1 is a free data retrieval call binding the contract method 0x12ad809c.
//
// Solidity: function getStats1() view returns((uint64,uint64,uint64,uint64))
func (_TaikoInbox *TaikoInboxCallerSession) GetStats1() (ITaikoInboxStats1, error) {
	return _TaikoInbox.Contract.GetStats1(&_TaikoInbox.CallOpts)
}

// GetStats2 is a free data retrieval call binding the contract method 0x26baca1c.
//
// Solidity: function getStats2() view returns((uint64,uint64,bool,uint56,uint64))
func (_TaikoInbox *TaikoInboxCaller) GetStats2(opts *bind.CallOpts) (ITaikoInboxStats2, error) {
	var out []interface{}
	err := _TaikoInbox.contract.Call(opts, &out, "getStats2")

	if err != nil {
		return *new(ITaikoInboxStats2), err
	}

	out0 := *abi.ConvertType(out[0], new(ITaikoInboxStats2)).(*ITaikoInboxStats2)

	return out0, err

}

// GetStats2 is a free data retrieval call binding the contract method 0x26baca1c.
//
// Solidity: function getStats2() view returns((uint64,uint64,bool,uint56,uint64))
func (_TaikoInbox *TaikoInboxSession) GetStats2() (ITaikoInboxStats2, error) {
	return _TaikoInbox.Contract.GetStats2(&_TaikoInbox.CallOpts)
}

// GetStats2 is a free data retrieval call binding the contract method 0x26baca1c.
//
// Solidity: function getStats2() view returns((uint64,uint64,bool,uint56,uint64))
func (_TaikoInbox *TaikoInboxCallerSession) GetStats2() (ITaikoInboxStats2, error) {
	return _TaikoInbox.Contract.GetStats2(&_TaikoInbox.CallOpts)
}

// GetTransitionById is a free data retrieval call binding the contract method 0xff109f59.
//
// Solidity: function getTransitionById(uint64 _batchId, uint24 _tid) view returns((bytes32,bytes32,bytes32,address,bool,uint48))
func (_TaikoInbox *TaikoInboxCaller) GetTransitionById(opts *bind.CallOpts, _batchId uint64, _tid *big.Int) (ITaikoInboxTransitionState, error) {
	var out []interface{}
	err := _TaikoInbox.contract.Call(opts, &out, "getTransitionById", _batchId, _tid)

	if err != nil {
		return *new(ITaikoInboxTransitionState), err
	}

	out0 := *abi.ConvertType(out[0], new(ITaikoInboxTransitionState)).(*ITaikoInboxTransitionState)

	return out0, err

}

// GetTransitionById is a free data retrieval call binding the contract method 0xff109f59.
//
// Solidity: function getTransitionById(uint64 _batchId, uint24 _tid) view returns((bytes32,bytes32,bytes32,address,bool,uint48))
func (_TaikoInbox *TaikoInboxSession) GetTransitionById(_batchId uint64, _tid *big.Int) (ITaikoInboxTransitionState, error) {
	return _TaikoInbox.Contract.GetTransitionById(&_TaikoInbox.CallOpts, _batchId, _tid)
}

// GetTransitionById is a free data retrieval call binding the contract method 0xff109f59.
//
// Solidity: function getTransitionById(uint64 _batchId, uint24 _tid) view returns((bytes32,bytes32,bytes32,address,bool,uint48))
func (_TaikoInbox *TaikoInboxCallerSession) GetTransitionById(_batchId uint64, _tid *big.Int) (ITaikoInboxTransitionState, error) {
	return _TaikoInbox.Contract.GetTransitionById(&_TaikoInbox.CallOpts, _batchId, _tid)
}

// GetTransitionByParentHash is a free data retrieval call binding the contract method 0xe8353dc0.
//
// Solidity: function getTransitionByParentHash(uint64 _batchId, bytes32 _parentHash) view returns((bytes32,bytes32,bytes32,address,bool,uint48))
func (_TaikoInbox *TaikoInboxCaller) GetTransitionByParentHash(opts *bind.CallOpts, _batchId uint64, _parentHash [32]byte) (ITaikoInboxTransitionState, error) {
	var out []interface{}
	err := _TaikoInbox.contract.Call(opts, &out, "getTransitionByParentHash", _batchId, _parentHash)

	if err != nil {
		return *new(ITaikoInboxTransitionState), err
	}

	out0 := *abi.ConvertType(out[0], new(ITaikoInboxTransitionState)).(*ITaikoInboxTransitionState)

	return out0, err

}

// GetTransitionByParentHash is a free data retrieval call binding the contract method 0xe8353dc0.
//
// Solidity: function getTransitionByParentHash(uint64 _batchId, bytes32 _parentHash) view returns((bytes32,bytes32,bytes32,address,bool,uint48))
func (_TaikoInbox *TaikoInboxSession) GetTransitionByParentHash(_batchId uint64, _parentHash [32]byte) (ITaikoInboxTransitionState, error) {
	return _TaikoInbox.Contract.GetTransitionByParentHash(&_TaikoInbox.CallOpts, _batchId, _parentHash)
}

// GetTransitionByParentHash is a free data retrieval call binding the contract method 0xe8353dc0.
//
// Solidity: function getTransitionByParentHash(uint64 _batchId, bytes32 _parentHash) view returns((bytes32,bytes32,bytes32,address,bool,uint48))
func (_TaikoInbox *TaikoInboxCallerSession) GetTransitionByParentHash(_batchId uint64, _parentHash [32]byte) (ITaikoInboxTransitionState, error) {
	return _TaikoInbox.Contract.GetTransitionByParentHash(&_TaikoInbox.CallOpts, _batchId, _parentHash)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_TaikoInbox *TaikoInboxCaller) Impl(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoInbox.contract.Call(opts, &out, "impl")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_TaikoInbox *TaikoInboxSession) Impl() (common.Address, error) {
	return _TaikoInbox.Contract.Impl(&_TaikoInbox.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_TaikoInbox *TaikoInboxCallerSession) Impl() (common.Address, error) {
	return _TaikoInbox.Contract.Impl(&_TaikoInbox.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_TaikoInbox *TaikoInboxCaller) InNonReentrant(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _TaikoInbox.contract.Call(opts, &out, "inNonReentrant")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_TaikoInbox *TaikoInboxSession) InNonReentrant() (bool, error) {
	return _TaikoInbox.Contract.InNonReentrant(&_TaikoInbox.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_TaikoInbox *TaikoInboxCallerSession) InNonReentrant() (bool, error) {
	return _TaikoInbox.Contract.InNonReentrant(&_TaikoInbox.CallOpts)
}

// IsOnL1 is a free data retrieval call binding the contract method 0xa4b23554.
//
// Solidity: function isOnL1() pure returns(bool)
func (_TaikoInbox *TaikoInboxCaller) IsOnL1(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _TaikoInbox.contract.Call(opts, &out, "isOnL1")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsOnL1 is a free data retrieval call binding the contract method 0xa4b23554.
//
// Solidity: function isOnL1() pure returns(bool)
func (_TaikoInbox *TaikoInboxSession) IsOnL1() (bool, error) {
	return _TaikoInbox.Contract.IsOnL1(&_TaikoInbox.CallOpts)
}

// IsOnL1 is a free data retrieval call binding the contract method 0xa4b23554.
//
// Solidity: function isOnL1() pure returns(bool)
func (_TaikoInbox *TaikoInboxCallerSession) IsOnL1() (bool, error) {
	return _TaikoInbox.Contract.IsOnL1(&_TaikoInbox.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoInbox *TaikoInboxCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoInbox.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoInbox *TaikoInboxSession) Owner() (common.Address, error) {
	return _TaikoInbox.Contract.Owner(&_TaikoInbox.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoInbox *TaikoInboxCallerSession) Owner() (common.Address, error) {
	return _TaikoInbox.Contract.Owner(&_TaikoInbox.CallOpts)
}

// PacayaConfig is a free data retrieval call binding the contract method 0xb932bf2b.
//
// Solidity: function pacayaConfig() view returns((uint64,uint64,uint64,uint64,uint32,uint96,uint96,uint8,uint64,(uint8,uint8,uint32,uint64,uint32),uint16,uint24,uint8,uint16,(uint64,uint64)))
func (_TaikoInbox *TaikoInboxCaller) PacayaConfig(opts *bind.CallOpts) (ITaikoInboxConfig, error) {
	var out []interface{}
	err := _TaikoInbox.contract.Call(opts, &out, "pacayaConfig")

	if err != nil {
		return *new(ITaikoInboxConfig), err
	}

	out0 := *abi.ConvertType(out[0], new(ITaikoInboxConfig)).(*ITaikoInboxConfig)

	return out0, err

}

// PacayaConfig is a free data retrieval call binding the contract method 0xb932bf2b.
//
// Solidity: function pacayaConfig() view returns((uint64,uint64,uint64,uint64,uint32,uint96,uint96,uint8,uint64,(uint8,uint8,uint32,uint64,uint32),uint16,uint24,uint8,uint16,(uint64,uint64)))
func (_TaikoInbox *TaikoInboxSession) PacayaConfig() (ITaikoInboxConfig, error) {
	return _TaikoInbox.Contract.PacayaConfig(&_TaikoInbox.CallOpts)
}

// PacayaConfig is a free data retrieval call binding the contract method 0xb932bf2b.
//
// Solidity: function pacayaConfig() view returns((uint64,uint64,uint64,uint64,uint32,uint96,uint96,uint8,uint64,(uint8,uint8,uint32,uint64,uint32),uint16,uint24,uint8,uint16,(uint64,uint64)))
func (_TaikoInbox *TaikoInboxCallerSession) PacayaConfig() (ITaikoInboxConfig, error) {
	return _TaikoInbox.Contract.PacayaConfig(&_TaikoInbox.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_TaikoInbox *TaikoInboxCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _TaikoInbox.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_TaikoInbox *TaikoInboxSession) Paused() (bool, error) {
	return _TaikoInbox.Contract.Paused(&_TaikoInbox.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_TaikoInbox *TaikoInboxCallerSession) Paused() (bool, error) {
	return _TaikoInbox.Contract.Paused(&_TaikoInbox.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_TaikoInbox *TaikoInboxCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoInbox.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_TaikoInbox *TaikoInboxSession) PendingOwner() (common.Address, error) {
	return _TaikoInbox.Contract.PendingOwner(&_TaikoInbox.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_TaikoInbox *TaikoInboxCallerSession) PendingOwner() (common.Address, error) {
	return _TaikoInbox.Contract.PendingOwner(&_TaikoInbox.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_TaikoInbox *TaikoInboxCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _TaikoInbox.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_TaikoInbox *TaikoInboxSession) ProxiableUUID() ([32]byte, error) {
	return _TaikoInbox.Contract.ProxiableUUID(&_TaikoInbox.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_TaikoInbox *TaikoInboxCallerSession) ProxiableUUID() ([32]byte, error) {
	return _TaikoInbox.Contract.ProxiableUUID(&_TaikoInbox.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_TaikoInbox *TaikoInboxCaller) Resolver(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoInbox.contract.Call(opts, &out, "resolver")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_TaikoInbox *TaikoInboxSession) Resolver() (common.Address, error) {
	return _TaikoInbox.Contract.Resolver(&_TaikoInbox.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_TaikoInbox *TaikoInboxCallerSession) Resolver() (common.Address, error) {
	return _TaikoInbox.Contract.Resolver(&_TaikoInbox.CallOpts)
}

// State is a free data retrieval call binding the contract method 0xc19d93fb.
//
// Solidity: function state() view returns(bytes32 __reserve1, (uint64,uint64,uint64,uint64) stats1, (uint64,uint64,bool,uint56,uint64) stats2)
func (_TaikoInbox *TaikoInboxCaller) State(opts *bind.CallOpts) (struct {
	Reserve1 [32]byte
	Stats1   ITaikoInboxStats1
	Stats2   ITaikoInboxStats2
}, error) {
	var out []interface{}
	err := _TaikoInbox.contract.Call(opts, &out, "state")

	outstruct := new(struct {
		Reserve1 [32]byte
		Stats1   ITaikoInboxStats1
		Stats2   ITaikoInboxStats2
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Reserve1 = *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)
	outstruct.Stats1 = *abi.ConvertType(out[1], new(ITaikoInboxStats1)).(*ITaikoInboxStats1)
	outstruct.Stats2 = *abi.ConvertType(out[2], new(ITaikoInboxStats2)).(*ITaikoInboxStats2)

	return *outstruct, err

}

// State is a free data retrieval call binding the contract method 0xc19d93fb.
//
// Solidity: function state() view returns(bytes32 __reserve1, (uint64,uint64,uint64,uint64) stats1, (uint64,uint64,bool,uint56,uint64) stats2)
func (_TaikoInbox *TaikoInboxSession) State() (struct {
	Reserve1 [32]byte
	Stats1   ITaikoInboxStats1
	Stats2   ITaikoInboxStats2
}, error) {
	return _TaikoInbox.Contract.State(&_TaikoInbox.CallOpts)
}

// State is a free data retrieval call binding the contract method 0xc19d93fb.
//
// Solidity: function state() view returns(bytes32 __reserve1, (uint64,uint64,uint64,uint64) stats1, (uint64,uint64,bool,uint56,uint64) stats2)
func (_TaikoInbox *TaikoInboxCallerSession) State() (struct {
	Reserve1 [32]byte
	Stats1   ITaikoInboxStats1
	Stats2   ITaikoInboxStats2
}, error) {
	return _TaikoInbox.Contract.State(&_TaikoInbox.CallOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_TaikoInbox *TaikoInboxTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoInbox.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_TaikoInbox *TaikoInboxSession) AcceptOwnership() (*types.Transaction, error) {
	return _TaikoInbox.Contract.AcceptOwnership(&_TaikoInbox.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_TaikoInbox *TaikoInboxTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _TaikoInbox.Contract.AcceptOwnership(&_TaikoInbox.TransactOpts)
}

// DepositBond is a paid mutator transaction binding the contract method 0x4dcb05f9.
//
// Solidity: function depositBond(uint256 _amount) payable returns()
func (_TaikoInbox *TaikoInboxTransactor) DepositBond(opts *bind.TransactOpts, _amount *big.Int) (*types.Transaction, error) {
	return _TaikoInbox.contract.Transact(opts, "depositBond", _amount)
}

// DepositBond is a paid mutator transaction binding the contract method 0x4dcb05f9.
//
// Solidity: function depositBond(uint256 _amount) payable returns()
func (_TaikoInbox *TaikoInboxSession) DepositBond(_amount *big.Int) (*types.Transaction, error) {
	return _TaikoInbox.Contract.DepositBond(&_TaikoInbox.TransactOpts, _amount)
}

// DepositBond is a paid mutator transaction binding the contract method 0x4dcb05f9.
//
// Solidity: function depositBond(uint256 _amount) payable returns()
func (_TaikoInbox *TaikoInboxTransactorSession) DepositBond(_amount *big.Int) (*types.Transaction, error) {
	return _TaikoInbox.Contract.DepositBond(&_TaikoInbox.TransactOpts, _amount)
}

// Init is a paid mutator transaction binding the contract method 0x2cc0b254.
//
// Solidity: function init(address _owner, bytes32 _genesisBlockHash) returns()
func (_TaikoInbox *TaikoInboxTransactor) Init(opts *bind.TransactOpts, _owner common.Address, _genesisBlockHash [32]byte) (*types.Transaction, error) {
	return _TaikoInbox.contract.Transact(opts, "init", _owner, _genesisBlockHash)
}

// Init is a paid mutator transaction binding the contract method 0x2cc0b254.
//
// Solidity: function init(address _owner, bytes32 _genesisBlockHash) returns()
func (_TaikoInbox *TaikoInboxSession) Init(_owner common.Address, _genesisBlockHash [32]byte) (*types.Transaction, error) {
	return _TaikoInbox.Contract.Init(&_TaikoInbox.TransactOpts, _owner, _genesisBlockHash)
}

// Init is a paid mutator transaction binding the contract method 0x2cc0b254.
//
// Solidity: function init(address _owner, bytes32 _genesisBlockHash) returns()
func (_TaikoInbox *TaikoInboxTransactorSession) Init(_owner common.Address, _genesisBlockHash [32]byte) (*types.Transaction, error) {
	return _TaikoInbox.Contract.Init(&_TaikoInbox.TransactOpts, _owner, _genesisBlockHash)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_TaikoInbox *TaikoInboxTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoInbox.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_TaikoInbox *TaikoInboxSession) Pause() (*types.Transaction, error) {
	return _TaikoInbox.Contract.Pause(&_TaikoInbox.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_TaikoInbox *TaikoInboxTransactorSession) Pause() (*types.Transaction, error) {
	return _TaikoInbox.Contract.Pause(&_TaikoInbox.TransactOpts)
}

// ProposeBatch is a paid mutator transaction binding the contract method 0x47faad14.
//
// Solidity: function proposeBatch(bytes _params, bytes _txList) returns((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint32,uint32,uint32,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint32)) info_, (bytes32,address,uint64,uint64) meta_)
func (_TaikoInbox *TaikoInboxTransactor) ProposeBatch(opts *bind.TransactOpts, _params []byte, _txList []byte) (*types.Transaction, error) {
	return _TaikoInbox.contract.Transact(opts, "proposeBatch", _params, _txList)
}

// ProposeBatch is a paid mutator transaction binding the contract method 0x47faad14.
//
// Solidity: function proposeBatch(bytes _params, bytes _txList) returns((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint32,uint32,uint32,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint32)) info_, (bytes32,address,uint64,uint64) meta_)
func (_TaikoInbox *TaikoInboxSession) ProposeBatch(_params []byte, _txList []byte) (*types.Transaction, error) {
	return _TaikoInbox.Contract.ProposeBatch(&_TaikoInbox.TransactOpts, _params, _txList)
}

// ProposeBatch is a paid mutator transaction binding the contract method 0x47faad14.
//
// Solidity: function proposeBatch(bytes _params, bytes _txList) returns((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint32,uint32,uint32,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint32)) info_, (bytes32,address,uint64,uint64) meta_)
func (_TaikoInbox *TaikoInboxTransactorSession) ProposeBatch(_params []byte, _txList []byte) (*types.Transaction, error) {
	return _TaikoInbox.Contract.ProposeBatch(&_TaikoInbox.TransactOpts, _params, _txList)
}

// ProveBatches is a paid mutator transaction binding the contract method 0xc9cc2843.
//
// Solidity: function proveBatches(bytes _params, bytes _proof) returns()
func (_TaikoInbox *TaikoInboxTransactor) ProveBatches(opts *bind.TransactOpts, _params []byte, _proof []byte) (*types.Transaction, error) {
	return _TaikoInbox.contract.Transact(opts, "proveBatches", _params, _proof)
}

// ProveBatches is a paid mutator transaction binding the contract method 0xc9cc2843.
//
// Solidity: function proveBatches(bytes _params, bytes _proof) returns()
func (_TaikoInbox *TaikoInboxSession) ProveBatches(_params []byte, _proof []byte) (*types.Transaction, error) {
	return _TaikoInbox.Contract.ProveBatches(&_TaikoInbox.TransactOpts, _params, _proof)
}

// ProveBatches is a paid mutator transaction binding the contract method 0xc9cc2843.
//
// Solidity: function proveBatches(bytes _params, bytes _proof) returns()
func (_TaikoInbox *TaikoInboxTransactorSession) ProveBatches(_params []byte, _proof []byte) (*types.Transaction, error) {
	return _TaikoInbox.Contract.ProveBatches(&_TaikoInbox.TransactOpts, _params, _proof)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoInbox *TaikoInboxTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoInbox.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoInbox *TaikoInboxSession) RenounceOwnership() (*types.Transaction, error) {
	return _TaikoInbox.Contract.RenounceOwnership(&_TaikoInbox.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoInbox *TaikoInboxTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _TaikoInbox.Contract.RenounceOwnership(&_TaikoInbox.TransactOpts)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoInbox *TaikoInboxTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _TaikoInbox.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoInbox *TaikoInboxSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _TaikoInbox.Contract.TransferOwnership(&_TaikoInbox.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoInbox *TaikoInboxTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _TaikoInbox.Contract.TransferOwnership(&_TaikoInbox.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_TaikoInbox *TaikoInboxTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoInbox.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_TaikoInbox *TaikoInboxSession) Unpause() (*types.Transaction, error) {
	return _TaikoInbox.Contract.Unpause(&_TaikoInbox.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_TaikoInbox *TaikoInboxTransactorSession) Unpause() (*types.Transaction, error) {
	return _TaikoInbox.Contract.Unpause(&_TaikoInbox.TransactOpts)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_TaikoInbox *TaikoInboxTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _TaikoInbox.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_TaikoInbox *TaikoInboxSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _TaikoInbox.Contract.UpgradeTo(&_TaikoInbox.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_TaikoInbox *TaikoInboxTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _TaikoInbox.Contract.UpgradeTo(&_TaikoInbox.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_TaikoInbox *TaikoInboxTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _TaikoInbox.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_TaikoInbox *TaikoInboxSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _TaikoInbox.Contract.UpgradeToAndCall(&_TaikoInbox.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_TaikoInbox *TaikoInboxTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _TaikoInbox.Contract.UpgradeToAndCall(&_TaikoInbox.TransactOpts, newImplementation, data)
}

// VerifyBatches is a paid mutator transaction binding the contract method 0x0cc62b42.
//
// Solidity: function verifyBatches(uint64 _length) returns()
func (_TaikoInbox *TaikoInboxTransactor) VerifyBatches(opts *bind.TransactOpts, _length uint64) (*types.Transaction, error) {
	return _TaikoInbox.contract.Transact(opts, "verifyBatches", _length)
}

// VerifyBatches is a paid mutator transaction binding the contract method 0x0cc62b42.
//
// Solidity: function verifyBatches(uint64 _length) returns()
func (_TaikoInbox *TaikoInboxSession) VerifyBatches(_length uint64) (*types.Transaction, error) {
	return _TaikoInbox.Contract.VerifyBatches(&_TaikoInbox.TransactOpts, _length)
}

// VerifyBatches is a paid mutator transaction binding the contract method 0x0cc62b42.
//
// Solidity: function verifyBatches(uint64 _length) returns()
func (_TaikoInbox *TaikoInboxTransactorSession) VerifyBatches(_length uint64) (*types.Transaction, error) {
	return _TaikoInbox.Contract.VerifyBatches(&_TaikoInbox.TransactOpts, _length)
}

// WithdrawBond is a paid mutator transaction binding the contract method 0xc3daab96.
//
// Solidity: function withdrawBond(uint256 _amount) returns()
func (_TaikoInbox *TaikoInboxTransactor) WithdrawBond(opts *bind.TransactOpts, _amount *big.Int) (*types.Transaction, error) {
	return _TaikoInbox.contract.Transact(opts, "withdrawBond", _amount)
}

// WithdrawBond is a paid mutator transaction binding the contract method 0xc3daab96.
//
// Solidity: function withdrawBond(uint256 _amount) returns()
func (_TaikoInbox *TaikoInboxSession) WithdrawBond(_amount *big.Int) (*types.Transaction, error) {
	return _TaikoInbox.Contract.WithdrawBond(&_TaikoInbox.TransactOpts, _amount)
}

// WithdrawBond is a paid mutator transaction binding the contract method 0xc3daab96.
//
// Solidity: function withdrawBond(uint256 _amount) returns()
func (_TaikoInbox *TaikoInboxTransactorSession) WithdrawBond(_amount *big.Int) (*types.Transaction, error) {
	return _TaikoInbox.Contract.WithdrawBond(&_TaikoInbox.TransactOpts, _amount)
}

// WriteTransition is a paid mutator transaction binding the contract method 0xc152c9eb.
//
// Solidity: function writeTransition(uint64 _batchId, bytes32 _parentHash, bytes32 _blockHash, bytes32 _stateRoot, address _prover, bool _inProvingWindow) returns()
func (_TaikoInbox *TaikoInboxTransactor) WriteTransition(opts *bind.TransactOpts, _batchId uint64, _parentHash [32]byte, _blockHash [32]byte, _stateRoot [32]byte, _prover common.Address, _inProvingWindow bool) (*types.Transaction, error) {
	return _TaikoInbox.contract.Transact(opts, "writeTransition", _batchId, _parentHash, _blockHash, _stateRoot, _prover, _inProvingWindow)
}

// WriteTransition is a paid mutator transaction binding the contract method 0xc152c9eb.
//
// Solidity: function writeTransition(uint64 _batchId, bytes32 _parentHash, bytes32 _blockHash, bytes32 _stateRoot, address _prover, bool _inProvingWindow) returns()
func (_TaikoInbox *TaikoInboxSession) WriteTransition(_batchId uint64, _parentHash [32]byte, _blockHash [32]byte, _stateRoot [32]byte, _prover common.Address, _inProvingWindow bool) (*types.Transaction, error) {
	return _TaikoInbox.Contract.WriteTransition(&_TaikoInbox.TransactOpts, _batchId, _parentHash, _blockHash, _stateRoot, _prover, _inProvingWindow)
}

// WriteTransition is a paid mutator transaction binding the contract method 0xc152c9eb.
//
// Solidity: function writeTransition(uint64 _batchId, bytes32 _parentHash, bytes32 _blockHash, bytes32 _stateRoot, address _prover, bool _inProvingWindow) returns()
func (_TaikoInbox *TaikoInboxTransactorSession) WriteTransition(_batchId uint64, _parentHash [32]byte, _blockHash [32]byte, _stateRoot [32]byte, _prover common.Address, _inProvingWindow bool) (*types.Transaction, error) {
	return _TaikoInbox.Contract.WriteTransition(&_TaikoInbox.TransactOpts, _batchId, _parentHash, _blockHash, _stateRoot, _prover, _inProvingWindow)
}

// TaikoInboxAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the TaikoInbox contract.
type TaikoInboxAdminChangedIterator struct {
	Event *TaikoInboxAdminChanged // Event containing the contract specifics and raw log

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
func (it *TaikoInboxAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxAdminChanged)
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
		it.Event = new(TaikoInboxAdminChanged)
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
func (it *TaikoInboxAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxAdminChanged represents a AdminChanged event raised by the TaikoInbox contract.
type TaikoInboxAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_TaikoInbox *TaikoInboxFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*TaikoInboxAdminChangedIterator, error) {

	logs, sub, err := _TaikoInbox.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &TaikoInboxAdminChangedIterator{contract: _TaikoInbox.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_TaikoInbox *TaikoInboxFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *TaikoInboxAdminChanged) (event.Subscription, error) {

	logs, sub, err := _TaikoInbox.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxAdminChanged)
				if err := _TaikoInbox.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_TaikoInbox *TaikoInboxFilterer) ParseAdminChanged(log types.Log) (*TaikoInboxAdminChanged, error) {
	event := new(TaikoInboxAdminChanged)
	if err := _TaikoInbox.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxBatchProposedIterator is returned from FilterBatchProposed and is used to iterate over the raw logs and unpacked data for BatchProposed events raised by the TaikoInbox contract.
type TaikoInboxBatchProposedIterator struct {
	Event *TaikoInboxBatchProposed // Event containing the contract specifics and raw log

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
func (it *TaikoInboxBatchProposedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxBatchProposed)
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
		it.Event = new(TaikoInboxBatchProposed)
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
func (it *TaikoInboxBatchProposedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxBatchProposedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxBatchProposed represents a BatchProposed event raised by the TaikoInbox contract.
type TaikoInboxBatchProposed struct {
	Info   ITaikoInboxBatchInfo
	Meta   ITaikoInboxBatchMetadata
	TxList []byte
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBatchProposed is a free log retrieval operation binding the contract event 0xac22bc0d7def53f17e8b32d373d53c3d8d0aabf718674569b1d8e469d14ab69d.
//
// Solidity: event BatchProposed((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint32,uint32,uint32,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint32)) info, (bytes32,address,uint64,uint64) meta, bytes txList)
func (_TaikoInbox *TaikoInboxFilterer) FilterBatchProposed(opts *bind.FilterOpts) (*TaikoInboxBatchProposedIterator, error) {

	logs, sub, err := _TaikoInbox.contract.FilterLogs(opts, "BatchProposed")
	if err != nil {
		return nil, err
	}
	return &TaikoInboxBatchProposedIterator{contract: _TaikoInbox.contract, event: "BatchProposed", logs: logs, sub: sub}, nil
}

// WatchBatchProposed is a free log subscription operation binding the contract event 0xac22bc0d7def53f17e8b32d373d53c3d8d0aabf718674569b1d8e469d14ab69d.
//
// Solidity: event BatchProposed((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint32,uint32,uint32,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint32)) info, (bytes32,address,uint64,uint64) meta, bytes txList)
func (_TaikoInbox *TaikoInboxFilterer) WatchBatchProposed(opts *bind.WatchOpts, sink chan<- *TaikoInboxBatchProposed) (event.Subscription, error) {

	logs, sub, err := _TaikoInbox.contract.WatchLogs(opts, "BatchProposed")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxBatchProposed)
				if err := _TaikoInbox.contract.UnpackLog(event, "BatchProposed", log); err != nil {
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

// ParseBatchProposed is a log parse operation binding the contract event 0xac22bc0d7def53f17e8b32d373d53c3d8d0aabf718674569b1d8e469d14ab69d.
//
// Solidity: event BatchProposed((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint32,uint32,uint32,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint32)) info, (bytes32,address,uint64,uint64) meta, bytes txList)
func (_TaikoInbox *TaikoInboxFilterer) ParseBatchProposed(log types.Log) (*TaikoInboxBatchProposed, error) {
	event := new(TaikoInboxBatchProposed)
	if err := _TaikoInbox.contract.UnpackLog(event, "BatchProposed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxBatchesProvedIterator is returned from FilterBatchesProved and is used to iterate over the raw logs and unpacked data for BatchesProved events raised by the TaikoInbox contract.
type TaikoInboxBatchesProvedIterator struct {
	Event *TaikoInboxBatchesProved // Event containing the contract specifics and raw log

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
func (it *TaikoInboxBatchesProvedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxBatchesProved)
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
		it.Event = new(TaikoInboxBatchesProved)
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
func (it *TaikoInboxBatchesProvedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxBatchesProvedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxBatchesProved represents a BatchesProved event raised by the TaikoInbox contract.
type TaikoInboxBatchesProved struct {
	Verifier    common.Address
	BatchIds    []uint64
	Transitions []ITaikoInboxTransition
	Raw         types.Log // Blockchain specific contextual infos
}

// FilterBatchesProved is a free log retrieval operation binding the contract event 0xc99f03c7db71a9e8c78654b1d2f77378b413cc979a02fa22dc9d39702afa92bc.
//
// Solidity: event BatchesProved(address verifier, uint64[] batchIds, (bytes32,bytes32,bytes32)[] transitions)
func (_TaikoInbox *TaikoInboxFilterer) FilterBatchesProved(opts *bind.FilterOpts) (*TaikoInboxBatchesProvedIterator, error) {

	logs, sub, err := _TaikoInbox.contract.FilterLogs(opts, "BatchesProved")
	if err != nil {
		return nil, err
	}
	return &TaikoInboxBatchesProvedIterator{contract: _TaikoInbox.contract, event: "BatchesProved", logs: logs, sub: sub}, nil
}

// WatchBatchesProved is a free log subscription operation binding the contract event 0xc99f03c7db71a9e8c78654b1d2f77378b413cc979a02fa22dc9d39702afa92bc.
//
// Solidity: event BatchesProved(address verifier, uint64[] batchIds, (bytes32,bytes32,bytes32)[] transitions)
func (_TaikoInbox *TaikoInboxFilterer) WatchBatchesProved(opts *bind.WatchOpts, sink chan<- *TaikoInboxBatchesProved) (event.Subscription, error) {

	logs, sub, err := _TaikoInbox.contract.WatchLogs(opts, "BatchesProved")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxBatchesProved)
				if err := _TaikoInbox.contract.UnpackLog(event, "BatchesProved", log); err != nil {
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

// ParseBatchesProved is a log parse operation binding the contract event 0xc99f03c7db71a9e8c78654b1d2f77378b413cc979a02fa22dc9d39702afa92bc.
//
// Solidity: event BatchesProved(address verifier, uint64[] batchIds, (bytes32,bytes32,bytes32)[] transitions)
func (_TaikoInbox *TaikoInboxFilterer) ParseBatchesProved(log types.Log) (*TaikoInboxBatchesProved, error) {
	event := new(TaikoInboxBatchesProved)
	if err := _TaikoInbox.contract.UnpackLog(event, "BatchesProved", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxBatchesVerifiedIterator is returned from FilterBatchesVerified and is used to iterate over the raw logs and unpacked data for BatchesVerified events raised by the TaikoInbox contract.
type TaikoInboxBatchesVerifiedIterator struct {
	Event *TaikoInboxBatchesVerified // Event containing the contract specifics and raw log

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
func (it *TaikoInboxBatchesVerifiedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxBatchesVerified)
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
		it.Event = new(TaikoInboxBatchesVerified)
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
func (it *TaikoInboxBatchesVerifiedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxBatchesVerifiedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxBatchesVerified represents a BatchesVerified event raised by the TaikoInbox contract.
type TaikoInboxBatchesVerified struct {
	BatchId   uint64
	BlockHash [32]byte
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterBatchesVerified is a free log retrieval operation binding the contract event 0xd6b1adebb10d3d794bc13103c4e9a696e79b3ce83355d8bdd77237cb20b3a4a0.
//
// Solidity: event BatchesVerified(uint64 batchId, bytes32 blockHash)
func (_TaikoInbox *TaikoInboxFilterer) FilterBatchesVerified(opts *bind.FilterOpts) (*TaikoInboxBatchesVerifiedIterator, error) {

	logs, sub, err := _TaikoInbox.contract.FilterLogs(opts, "BatchesVerified")
	if err != nil {
		return nil, err
	}
	return &TaikoInboxBatchesVerifiedIterator{contract: _TaikoInbox.contract, event: "BatchesVerified", logs: logs, sub: sub}, nil
}

// WatchBatchesVerified is a free log subscription operation binding the contract event 0xd6b1adebb10d3d794bc13103c4e9a696e79b3ce83355d8bdd77237cb20b3a4a0.
//
// Solidity: event BatchesVerified(uint64 batchId, bytes32 blockHash)
func (_TaikoInbox *TaikoInboxFilterer) WatchBatchesVerified(opts *bind.WatchOpts, sink chan<- *TaikoInboxBatchesVerified) (event.Subscription, error) {

	logs, sub, err := _TaikoInbox.contract.WatchLogs(opts, "BatchesVerified")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxBatchesVerified)
				if err := _TaikoInbox.contract.UnpackLog(event, "BatchesVerified", log); err != nil {
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

// ParseBatchesVerified is a log parse operation binding the contract event 0xd6b1adebb10d3d794bc13103c4e9a696e79b3ce83355d8bdd77237cb20b3a4a0.
//
// Solidity: event BatchesVerified(uint64 batchId, bytes32 blockHash)
func (_TaikoInbox *TaikoInboxFilterer) ParseBatchesVerified(log types.Log) (*TaikoInboxBatchesVerified, error) {
	event := new(TaikoInboxBatchesVerified)
	if err := _TaikoInbox.contract.UnpackLog(event, "BatchesVerified", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the TaikoInbox contract.
type TaikoInboxBeaconUpgradedIterator struct {
	Event *TaikoInboxBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *TaikoInboxBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxBeaconUpgraded)
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
		it.Event = new(TaikoInboxBeaconUpgraded)
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
func (it *TaikoInboxBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxBeaconUpgraded represents a BeaconUpgraded event raised by the TaikoInbox contract.
type TaikoInboxBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_TaikoInbox *TaikoInboxFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*TaikoInboxBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _TaikoInbox.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &TaikoInboxBeaconUpgradedIterator{contract: _TaikoInbox.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_TaikoInbox *TaikoInboxFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *TaikoInboxBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _TaikoInbox.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxBeaconUpgraded)
				if err := _TaikoInbox.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_TaikoInbox *TaikoInboxFilterer) ParseBeaconUpgraded(log types.Log) (*TaikoInboxBeaconUpgraded, error) {
	event := new(TaikoInboxBeaconUpgraded)
	if err := _TaikoInbox.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxBondCreditedIterator is returned from FilterBondCredited and is used to iterate over the raw logs and unpacked data for BondCredited events raised by the TaikoInbox contract.
type TaikoInboxBondCreditedIterator struct {
	Event *TaikoInboxBondCredited // Event containing the contract specifics and raw log

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
func (it *TaikoInboxBondCreditedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxBondCredited)
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
		it.Event = new(TaikoInboxBondCredited)
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
func (it *TaikoInboxBondCreditedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxBondCreditedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxBondCredited represents a BondCredited event raised by the TaikoInbox contract.
type TaikoInboxBondCredited struct {
	User   common.Address
	Amount *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBondCredited is a free log retrieval operation binding the contract event 0x6de6fe586196fa05b73b973026c5fda3968a2933989bff3a0b6bd57644fab606.
//
// Solidity: event BondCredited(address indexed user, uint256 amount)
func (_TaikoInbox *TaikoInboxFilterer) FilterBondCredited(opts *bind.FilterOpts, user []common.Address) (*TaikoInboxBondCreditedIterator, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoInbox.contract.FilterLogs(opts, "BondCredited", userRule)
	if err != nil {
		return nil, err
	}
	return &TaikoInboxBondCreditedIterator{contract: _TaikoInbox.contract, event: "BondCredited", logs: logs, sub: sub}, nil
}

// WatchBondCredited is a free log subscription operation binding the contract event 0x6de6fe586196fa05b73b973026c5fda3968a2933989bff3a0b6bd57644fab606.
//
// Solidity: event BondCredited(address indexed user, uint256 amount)
func (_TaikoInbox *TaikoInboxFilterer) WatchBondCredited(opts *bind.WatchOpts, sink chan<- *TaikoInboxBondCredited, user []common.Address) (event.Subscription, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoInbox.contract.WatchLogs(opts, "BondCredited", userRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxBondCredited)
				if err := _TaikoInbox.contract.UnpackLog(event, "BondCredited", log); err != nil {
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

// ParseBondCredited is a log parse operation binding the contract event 0x6de6fe586196fa05b73b973026c5fda3968a2933989bff3a0b6bd57644fab606.
//
// Solidity: event BondCredited(address indexed user, uint256 amount)
func (_TaikoInbox *TaikoInboxFilterer) ParseBondCredited(log types.Log) (*TaikoInboxBondCredited, error) {
	event := new(TaikoInboxBondCredited)
	if err := _TaikoInbox.contract.UnpackLog(event, "BondCredited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxBondDebitedIterator is returned from FilterBondDebited and is used to iterate over the raw logs and unpacked data for BondDebited events raised by the TaikoInbox contract.
type TaikoInboxBondDebitedIterator struct {
	Event *TaikoInboxBondDebited // Event containing the contract specifics and raw log

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
func (it *TaikoInboxBondDebitedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxBondDebited)
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
		it.Event = new(TaikoInboxBondDebited)
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
func (it *TaikoInboxBondDebitedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxBondDebitedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxBondDebited represents a BondDebited event raised by the TaikoInbox contract.
type TaikoInboxBondDebited struct {
	User   common.Address
	Amount *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBondDebited is a free log retrieval operation binding the contract event 0x85f32beeaff2d0019a8d196f06790c9a652191759c46643311344fd38920423c.
//
// Solidity: event BondDebited(address indexed user, uint256 amount)
func (_TaikoInbox *TaikoInboxFilterer) FilterBondDebited(opts *bind.FilterOpts, user []common.Address) (*TaikoInboxBondDebitedIterator, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoInbox.contract.FilterLogs(opts, "BondDebited", userRule)
	if err != nil {
		return nil, err
	}
	return &TaikoInboxBondDebitedIterator{contract: _TaikoInbox.contract, event: "BondDebited", logs: logs, sub: sub}, nil
}

// WatchBondDebited is a free log subscription operation binding the contract event 0x85f32beeaff2d0019a8d196f06790c9a652191759c46643311344fd38920423c.
//
// Solidity: event BondDebited(address indexed user, uint256 amount)
func (_TaikoInbox *TaikoInboxFilterer) WatchBondDebited(opts *bind.WatchOpts, sink chan<- *TaikoInboxBondDebited, user []common.Address) (event.Subscription, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoInbox.contract.WatchLogs(opts, "BondDebited", userRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxBondDebited)
				if err := _TaikoInbox.contract.UnpackLog(event, "BondDebited", log); err != nil {
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

// ParseBondDebited is a log parse operation binding the contract event 0x85f32beeaff2d0019a8d196f06790c9a652191759c46643311344fd38920423c.
//
// Solidity: event BondDebited(address indexed user, uint256 amount)
func (_TaikoInbox *TaikoInboxFilterer) ParseBondDebited(log types.Log) (*TaikoInboxBondDebited, error) {
	event := new(TaikoInboxBondDebited)
	if err := _TaikoInbox.contract.UnpackLog(event, "BondDebited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxBondDepositedIterator is returned from FilterBondDeposited and is used to iterate over the raw logs and unpacked data for BondDeposited events raised by the TaikoInbox contract.
type TaikoInboxBondDepositedIterator struct {
	Event *TaikoInboxBondDeposited // Event containing the contract specifics and raw log

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
func (it *TaikoInboxBondDepositedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxBondDeposited)
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
		it.Event = new(TaikoInboxBondDeposited)
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
func (it *TaikoInboxBondDepositedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxBondDepositedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxBondDeposited represents a BondDeposited event raised by the TaikoInbox contract.
type TaikoInboxBondDeposited struct {
	User   common.Address
	Amount *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBondDeposited is a free log retrieval operation binding the contract event 0x8ed8c6869618197b68315ade66e75ed3906c97b111fa3ab81e5760046825c7db.
//
// Solidity: event BondDeposited(address indexed user, uint256 amount)
func (_TaikoInbox *TaikoInboxFilterer) FilterBondDeposited(opts *bind.FilterOpts, user []common.Address) (*TaikoInboxBondDepositedIterator, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoInbox.contract.FilterLogs(opts, "BondDeposited", userRule)
	if err != nil {
		return nil, err
	}
	return &TaikoInboxBondDepositedIterator{contract: _TaikoInbox.contract, event: "BondDeposited", logs: logs, sub: sub}, nil
}

// WatchBondDeposited is a free log subscription operation binding the contract event 0x8ed8c6869618197b68315ade66e75ed3906c97b111fa3ab81e5760046825c7db.
//
// Solidity: event BondDeposited(address indexed user, uint256 amount)
func (_TaikoInbox *TaikoInboxFilterer) WatchBondDeposited(opts *bind.WatchOpts, sink chan<- *TaikoInboxBondDeposited, user []common.Address) (event.Subscription, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoInbox.contract.WatchLogs(opts, "BondDeposited", userRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxBondDeposited)
				if err := _TaikoInbox.contract.UnpackLog(event, "BondDeposited", log); err != nil {
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
func (_TaikoInbox *TaikoInboxFilterer) ParseBondDeposited(log types.Log) (*TaikoInboxBondDeposited, error) {
	event := new(TaikoInboxBondDeposited)
	if err := _TaikoInbox.contract.UnpackLog(event, "BondDeposited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxBondWithdrawnIterator is returned from FilterBondWithdrawn and is used to iterate over the raw logs and unpacked data for BondWithdrawn events raised by the TaikoInbox contract.
type TaikoInboxBondWithdrawnIterator struct {
	Event *TaikoInboxBondWithdrawn // Event containing the contract specifics and raw log

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
func (it *TaikoInboxBondWithdrawnIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxBondWithdrawn)
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
		it.Event = new(TaikoInboxBondWithdrawn)
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
func (it *TaikoInboxBondWithdrawnIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxBondWithdrawnIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxBondWithdrawn represents a BondWithdrawn event raised by the TaikoInbox contract.
type TaikoInboxBondWithdrawn struct {
	User   common.Address
	Amount *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBondWithdrawn is a free log retrieval operation binding the contract event 0x0d41118e36df44efb77a471fc49fb9c0be0406d802ef95520e9fbf606e65b455.
//
// Solidity: event BondWithdrawn(address indexed user, uint256 amount)
func (_TaikoInbox *TaikoInboxFilterer) FilterBondWithdrawn(opts *bind.FilterOpts, user []common.Address) (*TaikoInboxBondWithdrawnIterator, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoInbox.contract.FilterLogs(opts, "BondWithdrawn", userRule)
	if err != nil {
		return nil, err
	}
	return &TaikoInboxBondWithdrawnIterator{contract: _TaikoInbox.contract, event: "BondWithdrawn", logs: logs, sub: sub}, nil
}

// WatchBondWithdrawn is a free log subscription operation binding the contract event 0x0d41118e36df44efb77a471fc49fb9c0be0406d802ef95520e9fbf606e65b455.
//
// Solidity: event BondWithdrawn(address indexed user, uint256 amount)
func (_TaikoInbox *TaikoInboxFilterer) WatchBondWithdrawn(opts *bind.WatchOpts, sink chan<- *TaikoInboxBondWithdrawn, user []common.Address) (event.Subscription, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoInbox.contract.WatchLogs(opts, "BondWithdrawn", userRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxBondWithdrawn)
				if err := _TaikoInbox.contract.UnpackLog(event, "BondWithdrawn", log); err != nil {
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
func (_TaikoInbox *TaikoInboxFilterer) ParseBondWithdrawn(log types.Log) (*TaikoInboxBondWithdrawn, error) {
	event := new(TaikoInboxBondWithdrawn)
	if err := _TaikoInbox.contract.UnpackLog(event, "BondWithdrawn", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxConflictingProofIterator is returned from FilterConflictingProof and is used to iterate over the raw logs and unpacked data for ConflictingProof events raised by the TaikoInbox contract.
type TaikoInboxConflictingProofIterator struct {
	Event *TaikoInboxConflictingProof // Event containing the contract specifics and raw log

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
func (it *TaikoInboxConflictingProofIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxConflictingProof)
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
		it.Event = new(TaikoInboxConflictingProof)
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
func (it *TaikoInboxConflictingProofIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxConflictingProofIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxConflictingProof represents a ConflictingProof event raised by the TaikoInbox contract.
type TaikoInboxConflictingProof struct {
	BatchId uint64
	OldTran ITaikoInboxTransitionState
	NewTran ITaikoInboxTransition
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterConflictingProof is a free log retrieval operation binding the contract event 0xa05e896ff20170d694345384140d3397c040699d982fd6bdd73028e3d311f444.
//
// Solidity: event ConflictingProof(uint64 batchId, (bytes32,bytes32,bytes32,address,bool,uint48) oldTran, (bytes32,bytes32,bytes32) newTran)
func (_TaikoInbox *TaikoInboxFilterer) FilterConflictingProof(opts *bind.FilterOpts) (*TaikoInboxConflictingProofIterator, error) {

	logs, sub, err := _TaikoInbox.contract.FilterLogs(opts, "ConflictingProof")
	if err != nil {
		return nil, err
	}
	return &TaikoInboxConflictingProofIterator{contract: _TaikoInbox.contract, event: "ConflictingProof", logs: logs, sub: sub}, nil
}

// WatchConflictingProof is a free log subscription operation binding the contract event 0xa05e896ff20170d694345384140d3397c040699d982fd6bdd73028e3d311f444.
//
// Solidity: event ConflictingProof(uint64 batchId, (bytes32,bytes32,bytes32,address,bool,uint48) oldTran, (bytes32,bytes32,bytes32) newTran)
func (_TaikoInbox *TaikoInboxFilterer) WatchConflictingProof(opts *bind.WatchOpts, sink chan<- *TaikoInboxConflictingProof) (event.Subscription, error) {

	logs, sub, err := _TaikoInbox.contract.WatchLogs(opts, "ConflictingProof")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxConflictingProof)
				if err := _TaikoInbox.contract.UnpackLog(event, "ConflictingProof", log); err != nil {
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

// ParseConflictingProof is a log parse operation binding the contract event 0xa05e896ff20170d694345384140d3397c040699d982fd6bdd73028e3d311f444.
//
// Solidity: event ConflictingProof(uint64 batchId, (bytes32,bytes32,bytes32,address,bool,uint48) oldTran, (bytes32,bytes32,bytes32) newTran)
func (_TaikoInbox *TaikoInboxFilterer) ParseConflictingProof(log types.Log) (*TaikoInboxConflictingProof, error) {
	event := new(TaikoInboxConflictingProof)
	if err := _TaikoInbox.contract.UnpackLog(event, "ConflictingProof", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the TaikoInbox contract.
type TaikoInboxInitializedIterator struct {
	Event *TaikoInboxInitialized // Event containing the contract specifics and raw log

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
func (it *TaikoInboxInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxInitialized)
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
		it.Event = new(TaikoInboxInitialized)
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
func (it *TaikoInboxInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxInitialized represents a Initialized event raised by the TaikoInbox contract.
type TaikoInboxInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_TaikoInbox *TaikoInboxFilterer) FilterInitialized(opts *bind.FilterOpts) (*TaikoInboxInitializedIterator, error) {

	logs, sub, err := _TaikoInbox.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &TaikoInboxInitializedIterator{contract: _TaikoInbox.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_TaikoInbox *TaikoInboxFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *TaikoInboxInitialized) (event.Subscription, error) {

	logs, sub, err := _TaikoInbox.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxInitialized)
				if err := _TaikoInbox.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_TaikoInbox *TaikoInboxFilterer) ParseInitialized(log types.Log) (*TaikoInboxInitialized, error) {
	event := new(TaikoInboxInitialized)
	if err := _TaikoInbox.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the TaikoInbox contract.
type TaikoInboxOwnershipTransferStartedIterator struct {
	Event *TaikoInboxOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *TaikoInboxOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxOwnershipTransferStarted)
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
		it.Event = new(TaikoInboxOwnershipTransferStarted)
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
func (it *TaikoInboxOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the TaikoInbox contract.
type TaikoInboxOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_TaikoInbox *TaikoInboxFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*TaikoInboxOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoInbox.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &TaikoInboxOwnershipTransferStartedIterator{contract: _TaikoInbox.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_TaikoInbox *TaikoInboxFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *TaikoInboxOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoInbox.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxOwnershipTransferStarted)
				if err := _TaikoInbox.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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
func (_TaikoInbox *TaikoInboxFilterer) ParseOwnershipTransferStarted(log types.Log) (*TaikoInboxOwnershipTransferStarted, error) {
	event := new(TaikoInboxOwnershipTransferStarted)
	if err := _TaikoInbox.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the TaikoInbox contract.
type TaikoInboxOwnershipTransferredIterator struct {
	Event *TaikoInboxOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *TaikoInboxOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxOwnershipTransferred)
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
		it.Event = new(TaikoInboxOwnershipTransferred)
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
func (it *TaikoInboxOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxOwnershipTransferred represents a OwnershipTransferred event raised by the TaikoInbox contract.
type TaikoInboxOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_TaikoInbox *TaikoInboxFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*TaikoInboxOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoInbox.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &TaikoInboxOwnershipTransferredIterator{contract: _TaikoInbox.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_TaikoInbox *TaikoInboxFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *TaikoInboxOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoInbox.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxOwnershipTransferred)
				if err := _TaikoInbox.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_TaikoInbox *TaikoInboxFilterer) ParseOwnershipTransferred(log types.Log) (*TaikoInboxOwnershipTransferred, error) {
	event := new(TaikoInboxOwnershipTransferred)
	if err := _TaikoInbox.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the TaikoInbox contract.
type TaikoInboxPausedIterator struct {
	Event *TaikoInboxPaused // Event containing the contract specifics and raw log

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
func (it *TaikoInboxPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxPaused)
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
		it.Event = new(TaikoInboxPaused)
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
func (it *TaikoInboxPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxPaused represents a Paused event raised by the TaikoInbox contract.
type TaikoInboxPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_TaikoInbox *TaikoInboxFilterer) FilterPaused(opts *bind.FilterOpts) (*TaikoInboxPausedIterator, error) {

	logs, sub, err := _TaikoInbox.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &TaikoInboxPausedIterator{contract: _TaikoInbox.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_TaikoInbox *TaikoInboxFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *TaikoInboxPaused) (event.Subscription, error) {

	logs, sub, err := _TaikoInbox.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxPaused)
				if err := _TaikoInbox.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_TaikoInbox *TaikoInboxFilterer) ParsePaused(log types.Log) (*TaikoInboxPaused, error) {
	event := new(TaikoInboxPaused)
	if err := _TaikoInbox.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxStats1UpdatedIterator is returned from FilterStats1Updated and is used to iterate over the raw logs and unpacked data for Stats1Updated events raised by the TaikoInbox contract.
type TaikoInboxStats1UpdatedIterator struct {
	Event *TaikoInboxStats1Updated // Event containing the contract specifics and raw log

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
func (it *TaikoInboxStats1UpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxStats1Updated)
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
		it.Event = new(TaikoInboxStats1Updated)
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
func (it *TaikoInboxStats1UpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxStats1UpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxStats1Updated represents a Stats1Updated event raised by the TaikoInbox contract.
type TaikoInboxStats1Updated struct {
	Stats1 ITaikoInboxStats1
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterStats1Updated is a free log retrieval operation binding the contract event 0xcfbcbd3a81b749a28e6289bc350363f1949bb0a58ba7120d8dd4ef4b3617dff8.
//
// Solidity: event Stats1Updated((uint64,uint64,uint64,uint64) stats1)
func (_TaikoInbox *TaikoInboxFilterer) FilterStats1Updated(opts *bind.FilterOpts) (*TaikoInboxStats1UpdatedIterator, error) {

	logs, sub, err := _TaikoInbox.contract.FilterLogs(opts, "Stats1Updated")
	if err != nil {
		return nil, err
	}
	return &TaikoInboxStats1UpdatedIterator{contract: _TaikoInbox.contract, event: "Stats1Updated", logs: logs, sub: sub}, nil
}

// WatchStats1Updated is a free log subscription operation binding the contract event 0xcfbcbd3a81b749a28e6289bc350363f1949bb0a58ba7120d8dd4ef4b3617dff8.
//
// Solidity: event Stats1Updated((uint64,uint64,uint64,uint64) stats1)
func (_TaikoInbox *TaikoInboxFilterer) WatchStats1Updated(opts *bind.WatchOpts, sink chan<- *TaikoInboxStats1Updated) (event.Subscription, error) {

	logs, sub, err := _TaikoInbox.contract.WatchLogs(opts, "Stats1Updated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxStats1Updated)
				if err := _TaikoInbox.contract.UnpackLog(event, "Stats1Updated", log); err != nil {
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

// ParseStats1Updated is a log parse operation binding the contract event 0xcfbcbd3a81b749a28e6289bc350363f1949bb0a58ba7120d8dd4ef4b3617dff8.
//
// Solidity: event Stats1Updated((uint64,uint64,uint64,uint64) stats1)
func (_TaikoInbox *TaikoInboxFilterer) ParseStats1Updated(log types.Log) (*TaikoInboxStats1Updated, error) {
	event := new(TaikoInboxStats1Updated)
	if err := _TaikoInbox.contract.UnpackLog(event, "Stats1Updated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxStats2UpdatedIterator is returned from FilterStats2Updated and is used to iterate over the raw logs and unpacked data for Stats2Updated events raised by the TaikoInbox contract.
type TaikoInboxStats2UpdatedIterator struct {
	Event *TaikoInboxStats2Updated // Event containing the contract specifics and raw log

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
func (it *TaikoInboxStats2UpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxStats2Updated)
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
		it.Event = new(TaikoInboxStats2Updated)
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
func (it *TaikoInboxStats2UpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxStats2UpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxStats2Updated represents a Stats2Updated event raised by the TaikoInbox contract.
type TaikoInboxStats2Updated struct {
	Stats2 ITaikoInboxStats2
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterStats2Updated is a free log retrieval operation binding the contract event 0x7156d026e6a3864d290a971910746f96477d3901e33c4b2375e4ee00dabe7d87.
//
// Solidity: event Stats2Updated((uint64,uint64,bool,uint56,uint64) stats2)
func (_TaikoInbox *TaikoInboxFilterer) FilterStats2Updated(opts *bind.FilterOpts) (*TaikoInboxStats2UpdatedIterator, error) {

	logs, sub, err := _TaikoInbox.contract.FilterLogs(opts, "Stats2Updated")
	if err != nil {
		return nil, err
	}
	return &TaikoInboxStats2UpdatedIterator{contract: _TaikoInbox.contract, event: "Stats2Updated", logs: logs, sub: sub}, nil
}

// WatchStats2Updated is a free log subscription operation binding the contract event 0x7156d026e6a3864d290a971910746f96477d3901e33c4b2375e4ee00dabe7d87.
//
// Solidity: event Stats2Updated((uint64,uint64,bool,uint56,uint64) stats2)
func (_TaikoInbox *TaikoInboxFilterer) WatchStats2Updated(opts *bind.WatchOpts, sink chan<- *TaikoInboxStats2Updated) (event.Subscription, error) {

	logs, sub, err := _TaikoInbox.contract.WatchLogs(opts, "Stats2Updated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxStats2Updated)
				if err := _TaikoInbox.contract.UnpackLog(event, "Stats2Updated", log); err != nil {
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

// ParseStats2Updated is a log parse operation binding the contract event 0x7156d026e6a3864d290a971910746f96477d3901e33c4b2375e4ee00dabe7d87.
//
// Solidity: event Stats2Updated((uint64,uint64,bool,uint56,uint64) stats2)
func (_TaikoInbox *TaikoInboxFilterer) ParseStats2Updated(log types.Log) (*TaikoInboxStats2Updated, error) {
	event := new(TaikoInboxStats2Updated)
	if err := _TaikoInbox.contract.UnpackLog(event, "Stats2Updated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxTransitionWrittenIterator is returned from FilterTransitionWritten and is used to iterate over the raw logs and unpacked data for TransitionWritten events raised by the TaikoInbox contract.
type TaikoInboxTransitionWrittenIterator struct {
	Event *TaikoInboxTransitionWritten // Event containing the contract specifics and raw log

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
func (it *TaikoInboxTransitionWrittenIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxTransitionWritten)
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
		it.Event = new(TaikoInboxTransitionWritten)
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
func (it *TaikoInboxTransitionWrittenIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxTransitionWrittenIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxTransitionWritten represents a TransitionWritten event raised by the TaikoInbox contract.
type TaikoInboxTransitionWritten struct {
	BatchId uint64
	Tid     *big.Int
	Ts      ITaikoInboxTransitionState
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterTransitionWritten is a free log retrieval operation binding the contract event 0xd859648d474435f113442503ab429a8dc1e53be35a151a45aeec3e67302a941c.
//
// Solidity: event TransitionWritten(uint64 batchId, uint24 tid, (bytes32,bytes32,bytes32,address,bool,uint48) ts)
func (_TaikoInbox *TaikoInboxFilterer) FilterTransitionWritten(opts *bind.FilterOpts) (*TaikoInboxTransitionWrittenIterator, error) {

	logs, sub, err := _TaikoInbox.contract.FilterLogs(opts, "TransitionWritten")
	if err != nil {
		return nil, err
	}
	return &TaikoInboxTransitionWrittenIterator{contract: _TaikoInbox.contract, event: "TransitionWritten", logs: logs, sub: sub}, nil
}

// WatchTransitionWritten is a free log subscription operation binding the contract event 0xd859648d474435f113442503ab429a8dc1e53be35a151a45aeec3e67302a941c.
//
// Solidity: event TransitionWritten(uint64 batchId, uint24 tid, (bytes32,bytes32,bytes32,address,bool,uint48) ts)
func (_TaikoInbox *TaikoInboxFilterer) WatchTransitionWritten(opts *bind.WatchOpts, sink chan<- *TaikoInboxTransitionWritten) (event.Subscription, error) {

	logs, sub, err := _TaikoInbox.contract.WatchLogs(opts, "TransitionWritten")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxTransitionWritten)
				if err := _TaikoInbox.contract.UnpackLog(event, "TransitionWritten", log); err != nil {
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

// ParseTransitionWritten is a log parse operation binding the contract event 0xd859648d474435f113442503ab429a8dc1e53be35a151a45aeec3e67302a941c.
//
// Solidity: event TransitionWritten(uint64 batchId, uint24 tid, (bytes32,bytes32,bytes32,address,bool,uint48) ts)
func (_TaikoInbox *TaikoInboxFilterer) ParseTransitionWritten(log types.Log) (*TaikoInboxTransitionWritten, error) {
	event := new(TaikoInboxTransitionWritten)
	if err := _TaikoInbox.contract.UnpackLog(event, "TransitionWritten", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the TaikoInbox contract.
type TaikoInboxUnpausedIterator struct {
	Event *TaikoInboxUnpaused // Event containing the contract specifics and raw log

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
func (it *TaikoInboxUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxUnpaused)
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
		it.Event = new(TaikoInboxUnpaused)
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
func (it *TaikoInboxUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxUnpaused represents a Unpaused event raised by the TaikoInbox contract.
type TaikoInboxUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_TaikoInbox *TaikoInboxFilterer) FilterUnpaused(opts *bind.FilterOpts) (*TaikoInboxUnpausedIterator, error) {

	logs, sub, err := _TaikoInbox.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &TaikoInboxUnpausedIterator{contract: _TaikoInbox.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_TaikoInbox *TaikoInboxFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *TaikoInboxUnpaused) (event.Subscription, error) {

	logs, sub, err := _TaikoInbox.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxUnpaused)
				if err := _TaikoInbox.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_TaikoInbox *TaikoInboxFilterer) ParseUnpaused(log types.Log) (*TaikoInboxUnpaused, error) {
	event := new(TaikoInboxUnpaused)
	if err := _TaikoInbox.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the TaikoInbox contract.
type TaikoInboxUpgradedIterator struct {
	Event *TaikoInboxUpgraded // Event containing the contract specifics and raw log

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
func (it *TaikoInboxUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxUpgraded)
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
		it.Event = new(TaikoInboxUpgraded)
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
func (it *TaikoInboxUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxUpgraded represents a Upgraded event raised by the TaikoInbox contract.
type TaikoInboxUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_TaikoInbox *TaikoInboxFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*TaikoInboxUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _TaikoInbox.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &TaikoInboxUpgradedIterator{contract: _TaikoInbox.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_TaikoInbox *TaikoInboxFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *TaikoInboxUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _TaikoInbox.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxUpgraded)
				if err := _TaikoInbox.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_TaikoInbox *TaikoInboxFilterer) ParseUpgraded(log types.Log) (*TaikoInboxUpgraded, error) {
	event := new(TaikoInboxUpgraded)
	if err := _TaikoInbox.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
