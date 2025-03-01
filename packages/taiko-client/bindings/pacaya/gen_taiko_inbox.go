// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package pacaya

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
	BlobCreatedIn      uint64
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
	Shasta uint64
	Unzen  uint64
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

// TaikoInboxClientMetaData contains all meta data concerning the TaikoInboxClient contract.
var TaikoInboxClientMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"bondBalanceOf\",\"inputs\":[{\"name\":\"_user\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"bondToken\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"depositBond\",\"inputs\":[{\"name\":\"_amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"getBatch\",\"inputs\":[{\"name\":\"_batchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"outputs\":[{\"name\":\"batch_\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.Batch\",\"components\":[{\"name\":\"metaHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"lastBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"reserved3\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"livenessBond\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"batchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastBlockTimestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"anchorBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"nextTransitionId\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"reserved4\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"verifiedTransitionId\",\"type\":\"uint24\",\"internalType\":\"uint24\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getBatchVerifyingTransition\",\"inputs\":[{\"name\":\"_batchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"outputs\":[{\"name\":\"ts_\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.TransitionState\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"prover\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"inProvingWindow\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"createdAt\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getLastSyncedTransition\",\"inputs\":[],\"outputs\":[{\"name\":\"batchId_\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blockId_\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"ts_\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.TransitionState\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"prover\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"inProvingWindow\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"createdAt\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getLastVerifiedTransition\",\"inputs\":[],\"outputs\":[{\"name\":\"batchId_\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blockId_\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"ts_\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.TransitionState\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"prover\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"inProvingWindow\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"createdAt\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getStats1\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.Stats1\",\"components\":[{\"name\":\"genesisHeight\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"__reserved2\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastSyncedBatchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastSyncedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getStats2\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.Stats2\",\"components\":[{\"name\":\"numBatches\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastVerifiedBatchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"paused\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"lastProposedIn\",\"type\":\"uint56\",\"internalType\":\"uint56\"},{\"name\":\"lastUnpausedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTransitionById\",\"inputs\":[{\"name\":\"_batchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_tid\",\"type\":\"uint24\",\"internalType\":\"uint24\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.TransitionState\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"prover\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"inProvingWindow\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"createdAt\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTransitionByParentHash\",\"inputs\":[{\"name\":\"_batchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.TransitionState\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"prover\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"inProvingWindow\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"createdAt\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"impl\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inNonReentrant\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inboxWrapper\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_genesisBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isOnL1\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pacayaConfig\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.Config\",\"components\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxUnverifiedBatches\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"batchRingBufferSize\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxBatchesToVerify\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blockMaxGasLimit\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"livenessBondBase\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"livenessBondPerBlock\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"stateRootSyncInternal\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"maxAnchorHeightOffset\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"baseFeeConfig\",\"type\":\"tuple\",\"internalType\":\"structLibSharedData.BaseFeeConfig\",\"components\":[{\"name\":\"adjustmentQuotient\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"gasIssuancePerSecond\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"minGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxGasIssuancePerBlock\",\"type\":\"uint32\",\"internalType\":\"uint32\"}]},{\"name\":\"provingWindow\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"cooldownWindow\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"maxSignalsToReceive\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"maxBlocksPerBatch\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"forkHeights\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.ForkHeights\",\"components\":[{\"name\":\"ontake\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"pacaya\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"shasta\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"unzen\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proposeBatch\",\"inputs\":[{\"name\":\"_params\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"_txList\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"info_\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.BatchInfo\",\"components\":[{\"name\":\"txsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blocks\",\"type\":\"tuple[]\",\"internalType\":\"structITaikoInbox.BlockParams[]\",\"components\":[{\"name\":\"numTransactions\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"timeShift\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"signalSlots\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}]},{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"extraData\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"coinbase\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"proposedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobCreatedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobByteOffset\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobByteSize\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"gasLimit\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"lastBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastBlockTimestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"anchorBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"anchorBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"baseFeeConfig\",\"type\":\"tuple\",\"internalType\":\"structLibSharedData.BaseFeeConfig\",\"components\":[{\"name\":\"adjustmentQuotient\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"gasIssuancePerSecond\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"minGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxGasIssuancePerBlock\",\"type\":\"uint32\",\"internalType\":\"uint32\"}]}]},{\"name\":\"meta_\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.BatchMetadata\",\"components\":[{\"name\":\"infoHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"batchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"proposedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proveBatches\",\"inputs\":[{\"name\":\"_params\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"_proof\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolver\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"signalService\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISignalService\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"state\",\"inputs\":[],\"outputs\":[{\"name\":\"__reserve1\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stats1\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.Stats1\",\"components\":[{\"name\":\"genesisHeight\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"__reserved2\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastSyncedBatchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastSyncedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]},{\"name\":\"stats2\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.Stats2\",\"components\":[{\"name\":\"numBatches\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastVerifiedBatchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"paused\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"lastProposedIn\",\"type\":\"uint56\",\"internalType\":\"uint56\"},{\"name\":\"lastUnpausedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"verifier\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"verifyBatches\",\"inputs\":[{\"name\":\"_length\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"withdrawBond\",\"inputs\":[{\"name\":\"_amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"writeTransition\",\"inputs\":[{\"name\":\"_batchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_prover\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_inProvingWindow\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BatchProposed\",\"inputs\":[{\"name\":\"info\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structITaikoInbox.BatchInfo\",\"components\":[{\"name\":\"txsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blocks\",\"type\":\"tuple[]\",\"internalType\":\"structITaikoInbox.BlockParams[]\",\"components\":[{\"name\":\"numTransactions\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"timeShift\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"signalSlots\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}]},{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"extraData\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"coinbase\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"proposedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobCreatedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobByteOffset\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobByteSize\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"gasLimit\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"lastBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastBlockTimestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"anchorBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"anchorBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"baseFeeConfig\",\"type\":\"tuple\",\"internalType\":\"structLibSharedData.BaseFeeConfig\",\"components\":[{\"name\":\"adjustmentQuotient\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"gasIssuancePerSecond\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"minGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxGasIssuancePerBlock\",\"type\":\"uint32\",\"internalType\":\"uint32\"}]}]},{\"name\":\"meta\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structITaikoInbox.BatchMetadata\",\"components\":[{\"name\":\"infoHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"batchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"proposedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]},{\"name\":\"txList\",\"type\":\"bytes\",\"indexed\":false,\"internalType\":\"bytes\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BatchesProved\",\"inputs\":[{\"name\":\"verifier\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"batchIds\",\"type\":\"uint64[]\",\"indexed\":false,\"internalType\":\"uint64[]\"},{\"name\":\"transitions\",\"type\":\"tuple[]\",\"indexed\":false,\"internalType\":\"structITaikoInbox.Transition[]\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BatchesVerified\",\"inputs\":[{\"name\":\"batchId\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondCredited\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondDebited\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondDeposited\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondWithdrawn\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ConflictingProof\",\"inputs\":[{\"name\":\"batchId\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"},{\"name\":\"oldTran\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structITaikoInbox.TransitionState\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"prover\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"inProvingWindow\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"createdAt\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]},{\"name\":\"newTran\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structITaikoInbox.Transition\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Stats1Updated\",\"inputs\":[{\"name\":\"stats1\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structITaikoInbox.Stats1\",\"components\":[{\"name\":\"genesisHeight\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"__reserved2\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastSyncedBatchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastSyncedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Stats2Updated\",\"inputs\":[{\"name\":\"stats2\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structITaikoInbox.Stats2\",\"components\":[{\"name\":\"numBatches\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastVerifiedBatchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"paused\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"lastProposedIn\",\"type\":\"uint56\",\"internalType\":\"uint56\"},{\"name\":\"lastUnpausedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransitionWritten\",\"inputs\":[{\"name\":\"batchId\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"},{\"name\":\"tid\",\"type\":\"uint24\",\"indexed\":false,\"internalType\":\"uint24\"},{\"name\":\"ts\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structITaikoInbox.TransitionState\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"prover\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"inProvingWindow\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"createdAt\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCESS_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AnchorBlockIdSmallerThanParent\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AnchorBlockIdTooLarge\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AnchorBlockIdTooSmall\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ArraySizesMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"BatchNotFound\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"BatchVerified\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"BlobNotFound\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"BlobNotSpecified\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"BlockNotFound\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ContractPaused\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CustomProposerMissing\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CustomProposerNotAllowed\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ETH_TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EtherNotPaidAsBond\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FUNC_NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ForkNotActivated\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InsufficientBond\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidBlobCreatedIn\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidBlobParams\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidGenesisBlockHash\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidParams\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidTransitionBlockHash\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidTransitionParentHash\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidTransitionStateRoot\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MetaHashMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MsgValueNotZero\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NoBlocksToProve\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotFirstProposal\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotInboxWrapper\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ParentMetaHashMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SameTransition\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SignalNotSent\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"TimestampSmallerThanParent\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"TimestampTooLarge\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"TimestampTooSmall\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"TooManyBatches\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"TooManyBlocks\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"TooManySignals\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"TransitionNotFound\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_VALUE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZeroAnchorBlockHash\",\"inputs\":[]}]",
}

// TaikoInboxClientABI is the input ABI used to generate the binding from.
// Deprecated: Use TaikoInboxClientMetaData.ABI instead.
var TaikoInboxClientABI = TaikoInboxClientMetaData.ABI

// TaikoInboxClient is an auto generated Go binding around an Ethereum contract.
type TaikoInboxClient struct {
	TaikoInboxClientCaller     // Read-only binding to the contract
	TaikoInboxClientTransactor // Write-only binding to the contract
	TaikoInboxClientFilterer   // Log filterer for contract events
}

// TaikoInboxClientCaller is an auto generated read-only Go binding around an Ethereum contract.
type TaikoInboxClientCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoInboxClientTransactor is an auto generated write-only Go binding around an Ethereum contract.
type TaikoInboxClientTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoInboxClientFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type TaikoInboxClientFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoInboxClientSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type TaikoInboxClientSession struct {
	Contract     *TaikoInboxClient // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// TaikoInboxClientCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type TaikoInboxClientCallerSession struct {
	Contract *TaikoInboxClientCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts           // Call options to use throughout this session
}

// TaikoInboxClientTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type TaikoInboxClientTransactorSession struct {
	Contract     *TaikoInboxClientTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts           // Transaction auth options to use throughout this session
}

// TaikoInboxClientRaw is an auto generated low-level Go binding around an Ethereum contract.
type TaikoInboxClientRaw struct {
	Contract *TaikoInboxClient // Generic contract binding to access the raw methods on
}

// TaikoInboxClientCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type TaikoInboxClientCallerRaw struct {
	Contract *TaikoInboxClientCaller // Generic read-only contract binding to access the raw methods on
}

// TaikoInboxClientTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type TaikoInboxClientTransactorRaw struct {
	Contract *TaikoInboxClientTransactor // Generic write-only contract binding to access the raw methods on
}

// NewTaikoInboxClient creates a new instance of TaikoInboxClient, bound to a specific deployed contract.
func NewTaikoInboxClient(address common.Address, backend bind.ContractBackend) (*TaikoInboxClient, error) {
	contract, err := bindTaikoInboxClient(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &TaikoInboxClient{TaikoInboxClientCaller: TaikoInboxClientCaller{contract: contract}, TaikoInboxClientTransactor: TaikoInboxClientTransactor{contract: contract}, TaikoInboxClientFilterer: TaikoInboxClientFilterer{contract: contract}}, nil
}

// NewTaikoInboxClientCaller creates a new read-only instance of TaikoInboxClient, bound to a specific deployed contract.
func NewTaikoInboxClientCaller(address common.Address, caller bind.ContractCaller) (*TaikoInboxClientCaller, error) {
	contract, err := bindTaikoInboxClient(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &TaikoInboxClientCaller{contract: contract}, nil
}

// NewTaikoInboxClientTransactor creates a new write-only instance of TaikoInboxClient, bound to a specific deployed contract.
func NewTaikoInboxClientTransactor(address common.Address, transactor bind.ContractTransactor) (*TaikoInboxClientTransactor, error) {
	contract, err := bindTaikoInboxClient(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &TaikoInboxClientTransactor{contract: contract}, nil
}

// NewTaikoInboxClientFilterer creates a new log filterer instance of TaikoInboxClient, bound to a specific deployed contract.
func NewTaikoInboxClientFilterer(address common.Address, filterer bind.ContractFilterer) (*TaikoInboxClientFilterer, error) {
	contract, err := bindTaikoInboxClient(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &TaikoInboxClientFilterer{contract: contract}, nil
}

// bindTaikoInboxClient binds a generic wrapper to an already deployed contract.
func bindTaikoInboxClient(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := TaikoInboxClientMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TaikoInboxClient *TaikoInboxClientRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TaikoInboxClient.Contract.TaikoInboxClientCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TaikoInboxClient *TaikoInboxClientRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.TaikoInboxClientTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TaikoInboxClient *TaikoInboxClientRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.TaikoInboxClientTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TaikoInboxClient *TaikoInboxClientCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TaikoInboxClient.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TaikoInboxClient *TaikoInboxClientTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TaikoInboxClient *TaikoInboxClientTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.contract.Transact(opts, method, params...)
}

// BondBalanceOf is a free data retrieval call binding the contract method 0xa9c2c835.
//
// Solidity: function bondBalanceOf(address _user) view returns(uint256)
func (_TaikoInboxClient *TaikoInboxClientCaller) BondBalanceOf(opts *bind.CallOpts, _user common.Address) (*big.Int, error) {
	var out []interface{}
	err := _TaikoInboxClient.contract.Call(opts, &out, "bondBalanceOf", _user)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// BondBalanceOf is a free data retrieval call binding the contract method 0xa9c2c835.
//
// Solidity: function bondBalanceOf(address _user) view returns(uint256)
func (_TaikoInboxClient *TaikoInboxClientSession) BondBalanceOf(_user common.Address) (*big.Int, error) {
	return _TaikoInboxClient.Contract.BondBalanceOf(&_TaikoInboxClient.CallOpts, _user)
}

// BondBalanceOf is a free data retrieval call binding the contract method 0xa9c2c835.
//
// Solidity: function bondBalanceOf(address _user) view returns(uint256)
func (_TaikoInboxClient *TaikoInboxClientCallerSession) BondBalanceOf(_user common.Address) (*big.Int, error) {
	return _TaikoInboxClient.Contract.BondBalanceOf(&_TaikoInboxClient.CallOpts, _user)
}

// BondToken is a free data retrieval call binding the contract method 0xc28f4392.
//
// Solidity: function bondToken() view returns(address)
func (_TaikoInboxClient *TaikoInboxClientCaller) BondToken(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoInboxClient.contract.Call(opts, &out, "bondToken")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// BondToken is a free data retrieval call binding the contract method 0xc28f4392.
//
// Solidity: function bondToken() view returns(address)
func (_TaikoInboxClient *TaikoInboxClientSession) BondToken() (common.Address, error) {
	return _TaikoInboxClient.Contract.BondToken(&_TaikoInboxClient.CallOpts)
}

// BondToken is a free data retrieval call binding the contract method 0xc28f4392.
//
// Solidity: function bondToken() view returns(address)
func (_TaikoInboxClient *TaikoInboxClientCallerSession) BondToken() (common.Address, error) {
	return _TaikoInboxClient.Contract.BondToken(&_TaikoInboxClient.CallOpts)
}

// GetBatch is a free data retrieval call binding the contract method 0x888775d9.
//
// Solidity: function getBatch(uint64 _batchId) view returns((bytes32,uint64,uint96,uint96,uint64,uint64,uint64,uint24,uint8,uint24) batch_)
func (_TaikoInboxClient *TaikoInboxClientCaller) GetBatch(opts *bind.CallOpts, _batchId uint64) (ITaikoInboxBatch, error) {
	var out []interface{}
	err := _TaikoInboxClient.contract.Call(opts, &out, "getBatch", _batchId)

	if err != nil {
		return *new(ITaikoInboxBatch), err
	}

	out0 := *abi.ConvertType(out[0], new(ITaikoInboxBatch)).(*ITaikoInboxBatch)

	return out0, err

}

// GetBatch is a free data retrieval call binding the contract method 0x888775d9.
//
// Solidity: function getBatch(uint64 _batchId) view returns((bytes32,uint64,uint96,uint96,uint64,uint64,uint64,uint24,uint8,uint24) batch_)
func (_TaikoInboxClient *TaikoInboxClientSession) GetBatch(_batchId uint64) (ITaikoInboxBatch, error) {
	return _TaikoInboxClient.Contract.GetBatch(&_TaikoInboxClient.CallOpts, _batchId)
}

// GetBatch is a free data retrieval call binding the contract method 0x888775d9.
//
// Solidity: function getBatch(uint64 _batchId) view returns((bytes32,uint64,uint96,uint96,uint64,uint64,uint64,uint24,uint8,uint24) batch_)
func (_TaikoInboxClient *TaikoInboxClientCallerSession) GetBatch(_batchId uint64) (ITaikoInboxBatch, error) {
	return _TaikoInboxClient.Contract.GetBatch(&_TaikoInboxClient.CallOpts, _batchId)
}

// GetBatchVerifyingTransition is a free data retrieval call binding the contract method 0x7e7501dc.
//
// Solidity: function getBatchVerifyingTransition(uint64 _batchId) view returns((bytes32,bytes32,bytes32,address,bool,uint48) ts_)
func (_TaikoInboxClient *TaikoInboxClientCaller) GetBatchVerifyingTransition(opts *bind.CallOpts, _batchId uint64) (ITaikoInboxTransitionState, error) {
	var out []interface{}
	err := _TaikoInboxClient.contract.Call(opts, &out, "getBatchVerifyingTransition", _batchId)

	if err != nil {
		return *new(ITaikoInboxTransitionState), err
	}

	out0 := *abi.ConvertType(out[0], new(ITaikoInboxTransitionState)).(*ITaikoInboxTransitionState)

	return out0, err

}

// GetBatchVerifyingTransition is a free data retrieval call binding the contract method 0x7e7501dc.
//
// Solidity: function getBatchVerifyingTransition(uint64 _batchId) view returns((bytes32,bytes32,bytes32,address,bool,uint48) ts_)
func (_TaikoInboxClient *TaikoInboxClientSession) GetBatchVerifyingTransition(_batchId uint64) (ITaikoInboxTransitionState, error) {
	return _TaikoInboxClient.Contract.GetBatchVerifyingTransition(&_TaikoInboxClient.CallOpts, _batchId)
}

// GetBatchVerifyingTransition is a free data retrieval call binding the contract method 0x7e7501dc.
//
// Solidity: function getBatchVerifyingTransition(uint64 _batchId) view returns((bytes32,bytes32,bytes32,address,bool,uint48) ts_)
func (_TaikoInboxClient *TaikoInboxClientCallerSession) GetBatchVerifyingTransition(_batchId uint64) (ITaikoInboxTransitionState, error) {
	return _TaikoInboxClient.Contract.GetBatchVerifyingTransition(&_TaikoInboxClient.CallOpts, _batchId)
}

// GetLastSyncedTransition is a free data retrieval call binding the contract method 0xcee1136c.
//
// Solidity: function getLastSyncedTransition() view returns(uint64 batchId_, uint64 blockId_, (bytes32,bytes32,bytes32,address,bool,uint48) ts_)
func (_TaikoInboxClient *TaikoInboxClientCaller) GetLastSyncedTransition(opts *bind.CallOpts) (struct {
	BatchId uint64
	BlockId uint64
	Ts      ITaikoInboxTransitionState
}, error) {
	var out []interface{}
	err := _TaikoInboxClient.contract.Call(opts, &out, "getLastSyncedTransition")

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
func (_TaikoInboxClient *TaikoInboxClientSession) GetLastSyncedTransition() (struct {
	BatchId uint64
	BlockId uint64
	Ts      ITaikoInboxTransitionState
}, error) {
	return _TaikoInboxClient.Contract.GetLastSyncedTransition(&_TaikoInboxClient.CallOpts)
}

// GetLastSyncedTransition is a free data retrieval call binding the contract method 0xcee1136c.
//
// Solidity: function getLastSyncedTransition() view returns(uint64 batchId_, uint64 blockId_, (bytes32,bytes32,bytes32,address,bool,uint48) ts_)
func (_TaikoInboxClient *TaikoInboxClientCallerSession) GetLastSyncedTransition() (struct {
	BatchId uint64
	BlockId uint64
	Ts      ITaikoInboxTransitionState
}, error) {
	return _TaikoInboxClient.Contract.GetLastSyncedTransition(&_TaikoInboxClient.CallOpts)
}

// GetLastVerifiedTransition is a free data retrieval call binding the contract method 0x9c436473.
//
// Solidity: function getLastVerifiedTransition() view returns(uint64 batchId_, uint64 blockId_, (bytes32,bytes32,bytes32,address,bool,uint48) ts_)
func (_TaikoInboxClient *TaikoInboxClientCaller) GetLastVerifiedTransition(opts *bind.CallOpts) (struct {
	BatchId uint64
	BlockId uint64
	Ts      ITaikoInboxTransitionState
}, error) {
	var out []interface{}
	err := _TaikoInboxClient.contract.Call(opts, &out, "getLastVerifiedTransition")

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
func (_TaikoInboxClient *TaikoInboxClientSession) GetLastVerifiedTransition() (struct {
	BatchId uint64
	BlockId uint64
	Ts      ITaikoInboxTransitionState
}, error) {
	return _TaikoInboxClient.Contract.GetLastVerifiedTransition(&_TaikoInboxClient.CallOpts)
}

// GetLastVerifiedTransition is a free data retrieval call binding the contract method 0x9c436473.
//
// Solidity: function getLastVerifiedTransition() view returns(uint64 batchId_, uint64 blockId_, (bytes32,bytes32,bytes32,address,bool,uint48) ts_)
func (_TaikoInboxClient *TaikoInboxClientCallerSession) GetLastVerifiedTransition() (struct {
	BatchId uint64
	BlockId uint64
	Ts      ITaikoInboxTransitionState
}, error) {
	return _TaikoInboxClient.Contract.GetLastVerifiedTransition(&_TaikoInboxClient.CallOpts)
}

// GetStats1 is a free data retrieval call binding the contract method 0x12ad809c.
//
// Solidity: function getStats1() view returns((uint64,uint64,uint64,uint64))
func (_TaikoInboxClient *TaikoInboxClientCaller) GetStats1(opts *bind.CallOpts) (ITaikoInboxStats1, error) {
	var out []interface{}
	err := _TaikoInboxClient.contract.Call(opts, &out, "getStats1")

	if err != nil {
		return *new(ITaikoInboxStats1), err
	}

	out0 := *abi.ConvertType(out[0], new(ITaikoInboxStats1)).(*ITaikoInboxStats1)

	return out0, err

}

// GetStats1 is a free data retrieval call binding the contract method 0x12ad809c.
//
// Solidity: function getStats1() view returns((uint64,uint64,uint64,uint64))
func (_TaikoInboxClient *TaikoInboxClientSession) GetStats1() (ITaikoInboxStats1, error) {
	return _TaikoInboxClient.Contract.GetStats1(&_TaikoInboxClient.CallOpts)
}

// GetStats1 is a free data retrieval call binding the contract method 0x12ad809c.
//
// Solidity: function getStats1() view returns((uint64,uint64,uint64,uint64))
func (_TaikoInboxClient *TaikoInboxClientCallerSession) GetStats1() (ITaikoInboxStats1, error) {
	return _TaikoInboxClient.Contract.GetStats1(&_TaikoInboxClient.CallOpts)
}

// GetStats2 is a free data retrieval call binding the contract method 0x26baca1c.
//
// Solidity: function getStats2() view returns((uint64,uint64,bool,uint56,uint64))
func (_TaikoInboxClient *TaikoInboxClientCaller) GetStats2(opts *bind.CallOpts) (ITaikoInboxStats2, error) {
	var out []interface{}
	err := _TaikoInboxClient.contract.Call(opts, &out, "getStats2")

	if err != nil {
		return *new(ITaikoInboxStats2), err
	}

	out0 := *abi.ConvertType(out[0], new(ITaikoInboxStats2)).(*ITaikoInboxStats2)

	return out0, err

}

// GetStats2 is a free data retrieval call binding the contract method 0x26baca1c.
//
// Solidity: function getStats2() view returns((uint64,uint64,bool,uint56,uint64))
func (_TaikoInboxClient *TaikoInboxClientSession) GetStats2() (ITaikoInboxStats2, error) {
	return _TaikoInboxClient.Contract.GetStats2(&_TaikoInboxClient.CallOpts)
}

// GetStats2 is a free data retrieval call binding the contract method 0x26baca1c.
//
// Solidity: function getStats2() view returns((uint64,uint64,bool,uint56,uint64))
func (_TaikoInboxClient *TaikoInboxClientCallerSession) GetStats2() (ITaikoInboxStats2, error) {
	return _TaikoInboxClient.Contract.GetStats2(&_TaikoInboxClient.CallOpts)
}

// GetTransitionById is a free data retrieval call binding the contract method 0xff109f59.
//
// Solidity: function getTransitionById(uint64 _batchId, uint24 _tid) view returns((bytes32,bytes32,bytes32,address,bool,uint48))
func (_TaikoInboxClient *TaikoInboxClientCaller) GetTransitionById(opts *bind.CallOpts, _batchId uint64, _tid *big.Int) (ITaikoInboxTransitionState, error) {
	var out []interface{}
	err := _TaikoInboxClient.contract.Call(opts, &out, "getTransitionById", _batchId, _tid)

	if err != nil {
		return *new(ITaikoInboxTransitionState), err
	}

	out0 := *abi.ConvertType(out[0], new(ITaikoInboxTransitionState)).(*ITaikoInboxTransitionState)

	return out0, err

}

// GetTransitionById is a free data retrieval call binding the contract method 0xff109f59.
//
// Solidity: function getTransitionById(uint64 _batchId, uint24 _tid) view returns((bytes32,bytes32,bytes32,address,bool,uint48))
func (_TaikoInboxClient *TaikoInboxClientSession) GetTransitionById(_batchId uint64, _tid *big.Int) (ITaikoInboxTransitionState, error) {
	return _TaikoInboxClient.Contract.GetTransitionById(&_TaikoInboxClient.CallOpts, _batchId, _tid)
}

// GetTransitionById is a free data retrieval call binding the contract method 0xff109f59.
//
// Solidity: function getTransitionById(uint64 _batchId, uint24 _tid) view returns((bytes32,bytes32,bytes32,address,bool,uint48))
func (_TaikoInboxClient *TaikoInboxClientCallerSession) GetTransitionById(_batchId uint64, _tid *big.Int) (ITaikoInboxTransitionState, error) {
	return _TaikoInboxClient.Contract.GetTransitionById(&_TaikoInboxClient.CallOpts, _batchId, _tid)
}

// GetTransitionByParentHash is a free data retrieval call binding the contract method 0xe8353dc0.
//
// Solidity: function getTransitionByParentHash(uint64 _batchId, bytes32 _parentHash) view returns((bytes32,bytes32,bytes32,address,bool,uint48))
func (_TaikoInboxClient *TaikoInboxClientCaller) GetTransitionByParentHash(opts *bind.CallOpts, _batchId uint64, _parentHash [32]byte) (ITaikoInboxTransitionState, error) {
	var out []interface{}
	err := _TaikoInboxClient.contract.Call(opts, &out, "getTransitionByParentHash", _batchId, _parentHash)

	if err != nil {
		return *new(ITaikoInboxTransitionState), err
	}

	out0 := *abi.ConvertType(out[0], new(ITaikoInboxTransitionState)).(*ITaikoInboxTransitionState)

	return out0, err

}

// GetTransitionByParentHash is a free data retrieval call binding the contract method 0xe8353dc0.
//
// Solidity: function getTransitionByParentHash(uint64 _batchId, bytes32 _parentHash) view returns((bytes32,bytes32,bytes32,address,bool,uint48))
func (_TaikoInboxClient *TaikoInboxClientSession) GetTransitionByParentHash(_batchId uint64, _parentHash [32]byte) (ITaikoInboxTransitionState, error) {
	return _TaikoInboxClient.Contract.GetTransitionByParentHash(&_TaikoInboxClient.CallOpts, _batchId, _parentHash)
}

// GetTransitionByParentHash is a free data retrieval call binding the contract method 0xe8353dc0.
//
// Solidity: function getTransitionByParentHash(uint64 _batchId, bytes32 _parentHash) view returns((bytes32,bytes32,bytes32,address,bool,uint48))
func (_TaikoInboxClient *TaikoInboxClientCallerSession) GetTransitionByParentHash(_batchId uint64, _parentHash [32]byte) (ITaikoInboxTransitionState, error) {
	return _TaikoInboxClient.Contract.GetTransitionByParentHash(&_TaikoInboxClient.CallOpts, _batchId, _parentHash)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_TaikoInboxClient *TaikoInboxClientCaller) Impl(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoInboxClient.contract.Call(opts, &out, "impl")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_TaikoInboxClient *TaikoInboxClientSession) Impl() (common.Address, error) {
	return _TaikoInboxClient.Contract.Impl(&_TaikoInboxClient.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_TaikoInboxClient *TaikoInboxClientCallerSession) Impl() (common.Address, error) {
	return _TaikoInboxClient.Contract.Impl(&_TaikoInboxClient.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_TaikoInboxClient *TaikoInboxClientCaller) InNonReentrant(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _TaikoInboxClient.contract.Call(opts, &out, "inNonReentrant")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_TaikoInboxClient *TaikoInboxClientSession) InNonReentrant() (bool, error) {
	return _TaikoInboxClient.Contract.InNonReentrant(&_TaikoInboxClient.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_TaikoInboxClient *TaikoInboxClientCallerSession) InNonReentrant() (bool, error) {
	return _TaikoInboxClient.Contract.InNonReentrant(&_TaikoInboxClient.CallOpts)
}

// InboxWrapper is a free data retrieval call binding the contract method 0x59df1118.
//
// Solidity: function inboxWrapper() view returns(address)
func (_TaikoInboxClient *TaikoInboxClientCaller) InboxWrapper(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoInboxClient.contract.Call(opts, &out, "inboxWrapper")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// InboxWrapper is a free data retrieval call binding the contract method 0x59df1118.
//
// Solidity: function inboxWrapper() view returns(address)
func (_TaikoInboxClient *TaikoInboxClientSession) InboxWrapper() (common.Address, error) {
	return _TaikoInboxClient.Contract.InboxWrapper(&_TaikoInboxClient.CallOpts)
}

// InboxWrapper is a free data retrieval call binding the contract method 0x59df1118.
//
// Solidity: function inboxWrapper() view returns(address)
func (_TaikoInboxClient *TaikoInboxClientCallerSession) InboxWrapper() (common.Address, error) {
	return _TaikoInboxClient.Contract.InboxWrapper(&_TaikoInboxClient.CallOpts)
}

// IsOnL1 is a free data retrieval call binding the contract method 0xa4b23554.
//
// Solidity: function isOnL1() pure returns(bool)
func (_TaikoInboxClient *TaikoInboxClientCaller) IsOnL1(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _TaikoInboxClient.contract.Call(opts, &out, "isOnL1")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsOnL1 is a free data retrieval call binding the contract method 0xa4b23554.
//
// Solidity: function isOnL1() pure returns(bool)
func (_TaikoInboxClient *TaikoInboxClientSession) IsOnL1() (bool, error) {
	return _TaikoInboxClient.Contract.IsOnL1(&_TaikoInboxClient.CallOpts)
}

// IsOnL1 is a free data retrieval call binding the contract method 0xa4b23554.
//
// Solidity: function isOnL1() pure returns(bool)
func (_TaikoInboxClient *TaikoInboxClientCallerSession) IsOnL1() (bool, error) {
	return _TaikoInboxClient.Contract.IsOnL1(&_TaikoInboxClient.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoInboxClient *TaikoInboxClientCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoInboxClient.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoInboxClient *TaikoInboxClientSession) Owner() (common.Address, error) {
	return _TaikoInboxClient.Contract.Owner(&_TaikoInboxClient.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoInboxClient *TaikoInboxClientCallerSession) Owner() (common.Address, error) {
	return _TaikoInboxClient.Contract.Owner(&_TaikoInboxClient.CallOpts)
}

// PacayaConfig is a free data retrieval call binding the contract method 0xb932bf2b.
//
// Solidity: function pacayaConfig() view returns((uint64,uint64,uint64,uint64,uint32,uint96,uint96,uint8,uint64,(uint8,uint8,uint32,uint64,uint32),uint16,uint24,uint8,uint16,(uint64,uint64,uint64,uint64)))
func (_TaikoInboxClient *TaikoInboxClientCaller) PacayaConfig(opts *bind.CallOpts) (ITaikoInboxConfig, error) {
	var out []interface{}
	err := _TaikoInboxClient.contract.Call(opts, &out, "pacayaConfig")

	if err != nil {
		return *new(ITaikoInboxConfig), err
	}

	out0 := *abi.ConvertType(out[0], new(ITaikoInboxConfig)).(*ITaikoInboxConfig)

	return out0, err

}

// PacayaConfig is a free data retrieval call binding the contract method 0xb932bf2b.
//
// Solidity: function pacayaConfig() view returns((uint64,uint64,uint64,uint64,uint32,uint96,uint96,uint8,uint64,(uint8,uint8,uint32,uint64,uint32),uint16,uint24,uint8,uint16,(uint64,uint64,uint64,uint64)))
func (_TaikoInboxClient *TaikoInboxClientSession) PacayaConfig() (ITaikoInboxConfig, error) {
	return _TaikoInboxClient.Contract.PacayaConfig(&_TaikoInboxClient.CallOpts)
}

// PacayaConfig is a free data retrieval call binding the contract method 0xb932bf2b.
//
// Solidity: function pacayaConfig() view returns((uint64,uint64,uint64,uint64,uint32,uint96,uint96,uint8,uint64,(uint8,uint8,uint32,uint64,uint32),uint16,uint24,uint8,uint16,(uint64,uint64,uint64,uint64)))
func (_TaikoInboxClient *TaikoInboxClientCallerSession) PacayaConfig() (ITaikoInboxConfig, error) {
	return _TaikoInboxClient.Contract.PacayaConfig(&_TaikoInboxClient.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_TaikoInboxClient *TaikoInboxClientCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _TaikoInboxClient.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_TaikoInboxClient *TaikoInboxClientSession) Paused() (bool, error) {
	return _TaikoInboxClient.Contract.Paused(&_TaikoInboxClient.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_TaikoInboxClient *TaikoInboxClientCallerSession) Paused() (bool, error) {
	return _TaikoInboxClient.Contract.Paused(&_TaikoInboxClient.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_TaikoInboxClient *TaikoInboxClientCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoInboxClient.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_TaikoInboxClient *TaikoInboxClientSession) PendingOwner() (common.Address, error) {
	return _TaikoInboxClient.Contract.PendingOwner(&_TaikoInboxClient.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_TaikoInboxClient *TaikoInboxClientCallerSession) PendingOwner() (common.Address, error) {
	return _TaikoInboxClient.Contract.PendingOwner(&_TaikoInboxClient.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_TaikoInboxClient *TaikoInboxClientCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _TaikoInboxClient.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_TaikoInboxClient *TaikoInboxClientSession) ProxiableUUID() ([32]byte, error) {
	return _TaikoInboxClient.Contract.ProxiableUUID(&_TaikoInboxClient.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_TaikoInboxClient *TaikoInboxClientCallerSession) ProxiableUUID() ([32]byte, error) {
	return _TaikoInboxClient.Contract.ProxiableUUID(&_TaikoInboxClient.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_TaikoInboxClient *TaikoInboxClientCaller) Resolver(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoInboxClient.contract.Call(opts, &out, "resolver")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_TaikoInboxClient *TaikoInboxClientSession) Resolver() (common.Address, error) {
	return _TaikoInboxClient.Contract.Resolver(&_TaikoInboxClient.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_TaikoInboxClient *TaikoInboxClientCallerSession) Resolver() (common.Address, error) {
	return _TaikoInboxClient.Contract.Resolver(&_TaikoInboxClient.CallOpts)
}

// SignalService is a free data retrieval call binding the contract method 0x62d09453.
//
// Solidity: function signalService() view returns(address)
func (_TaikoInboxClient *TaikoInboxClientCaller) SignalService(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoInboxClient.contract.Call(opts, &out, "signalService")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SignalService is a free data retrieval call binding the contract method 0x62d09453.
//
// Solidity: function signalService() view returns(address)
func (_TaikoInboxClient *TaikoInboxClientSession) SignalService() (common.Address, error) {
	return _TaikoInboxClient.Contract.SignalService(&_TaikoInboxClient.CallOpts)
}

// SignalService is a free data retrieval call binding the contract method 0x62d09453.
//
// Solidity: function signalService() view returns(address)
func (_TaikoInboxClient *TaikoInboxClientCallerSession) SignalService() (common.Address, error) {
	return _TaikoInboxClient.Contract.SignalService(&_TaikoInboxClient.CallOpts)
}

// State is a free data retrieval call binding the contract method 0xc19d93fb.
//
// Solidity: function state() view returns(bytes32 __reserve1, (uint64,uint64,uint64,uint64) stats1, (uint64,uint64,bool,uint56,uint64) stats2)
func (_TaikoInboxClient *TaikoInboxClientCaller) State(opts *bind.CallOpts) (struct {
	Reserve1 [32]byte
	Stats1   ITaikoInboxStats1
	Stats2   ITaikoInboxStats2
}, error) {
	var out []interface{}
	err := _TaikoInboxClient.contract.Call(opts, &out, "state")

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
func (_TaikoInboxClient *TaikoInboxClientSession) State() (struct {
	Reserve1 [32]byte
	Stats1   ITaikoInboxStats1
	Stats2   ITaikoInboxStats2
}, error) {
	return _TaikoInboxClient.Contract.State(&_TaikoInboxClient.CallOpts)
}

// State is a free data retrieval call binding the contract method 0xc19d93fb.
//
// Solidity: function state() view returns(bytes32 __reserve1, (uint64,uint64,uint64,uint64) stats1, (uint64,uint64,bool,uint56,uint64) stats2)
func (_TaikoInboxClient *TaikoInboxClientCallerSession) State() (struct {
	Reserve1 [32]byte
	Stats1   ITaikoInboxStats1
	Stats2   ITaikoInboxStats2
}, error) {
	return _TaikoInboxClient.Contract.State(&_TaikoInboxClient.CallOpts)
}

// Verifier is a free data retrieval call binding the contract method 0x2b7ac3f3.
//
// Solidity: function verifier() view returns(address)
func (_TaikoInboxClient *TaikoInboxClientCaller) Verifier(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoInboxClient.contract.Call(opts, &out, "verifier")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Verifier is a free data retrieval call binding the contract method 0x2b7ac3f3.
//
// Solidity: function verifier() view returns(address)
func (_TaikoInboxClient *TaikoInboxClientSession) Verifier() (common.Address, error) {
	return _TaikoInboxClient.Contract.Verifier(&_TaikoInboxClient.CallOpts)
}

// Verifier is a free data retrieval call binding the contract method 0x2b7ac3f3.
//
// Solidity: function verifier() view returns(address)
func (_TaikoInboxClient *TaikoInboxClientCallerSession) Verifier() (common.Address, error) {
	return _TaikoInboxClient.Contract.Verifier(&_TaikoInboxClient.CallOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_TaikoInboxClient *TaikoInboxClientTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoInboxClient.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_TaikoInboxClient *TaikoInboxClientSession) AcceptOwnership() (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.AcceptOwnership(&_TaikoInboxClient.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_TaikoInboxClient *TaikoInboxClientTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.AcceptOwnership(&_TaikoInboxClient.TransactOpts)
}

// DepositBond is a paid mutator transaction binding the contract method 0x4dcb05f9.
//
// Solidity: function depositBond(uint256 _amount) payable returns()
func (_TaikoInboxClient *TaikoInboxClientTransactor) DepositBond(opts *bind.TransactOpts, _amount *big.Int) (*types.Transaction, error) {
	return _TaikoInboxClient.contract.Transact(opts, "depositBond", _amount)
}

// DepositBond is a paid mutator transaction binding the contract method 0x4dcb05f9.
//
// Solidity: function depositBond(uint256 _amount) payable returns()
func (_TaikoInboxClient *TaikoInboxClientSession) DepositBond(_amount *big.Int) (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.DepositBond(&_TaikoInboxClient.TransactOpts, _amount)
}

// DepositBond is a paid mutator transaction binding the contract method 0x4dcb05f9.
//
// Solidity: function depositBond(uint256 _amount) payable returns()
func (_TaikoInboxClient *TaikoInboxClientTransactorSession) DepositBond(_amount *big.Int) (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.DepositBond(&_TaikoInboxClient.TransactOpts, _amount)
}

// Init is a paid mutator transaction binding the contract method 0x2cc0b254.
//
// Solidity: function init(address _owner, bytes32 _genesisBlockHash) returns()
func (_TaikoInboxClient *TaikoInboxClientTransactor) Init(opts *bind.TransactOpts, _owner common.Address, _genesisBlockHash [32]byte) (*types.Transaction, error) {
	return _TaikoInboxClient.contract.Transact(opts, "init", _owner, _genesisBlockHash)
}

// Init is a paid mutator transaction binding the contract method 0x2cc0b254.
//
// Solidity: function init(address _owner, bytes32 _genesisBlockHash) returns()
func (_TaikoInboxClient *TaikoInboxClientSession) Init(_owner common.Address, _genesisBlockHash [32]byte) (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.Init(&_TaikoInboxClient.TransactOpts, _owner, _genesisBlockHash)
}

// Init is a paid mutator transaction binding the contract method 0x2cc0b254.
//
// Solidity: function init(address _owner, bytes32 _genesisBlockHash) returns()
func (_TaikoInboxClient *TaikoInboxClientTransactorSession) Init(_owner common.Address, _genesisBlockHash [32]byte) (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.Init(&_TaikoInboxClient.TransactOpts, _owner, _genesisBlockHash)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_TaikoInboxClient *TaikoInboxClientTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoInboxClient.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_TaikoInboxClient *TaikoInboxClientSession) Pause() (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.Pause(&_TaikoInboxClient.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_TaikoInboxClient *TaikoInboxClientTransactorSession) Pause() (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.Pause(&_TaikoInboxClient.TransactOpts)
}

// ProposeBatch is a paid mutator transaction binding the contract method 0x47faad14.
//
// Solidity: function proposeBatch(bytes _params, bytes _txList) returns((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint64,uint32,uint32,uint32,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint32)) info_, (bytes32,address,uint64,uint64) meta_)
func (_TaikoInboxClient *TaikoInboxClientTransactor) ProposeBatch(opts *bind.TransactOpts, _params []byte, _txList []byte) (*types.Transaction, error) {
	return _TaikoInboxClient.contract.Transact(opts, "proposeBatch", _params, _txList)
}

// ProposeBatch is a paid mutator transaction binding the contract method 0x47faad14.
//
// Solidity: function proposeBatch(bytes _params, bytes _txList) returns((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint64,uint32,uint32,uint32,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint32)) info_, (bytes32,address,uint64,uint64) meta_)
func (_TaikoInboxClient *TaikoInboxClientSession) ProposeBatch(_params []byte, _txList []byte) (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.ProposeBatch(&_TaikoInboxClient.TransactOpts, _params, _txList)
}

// ProposeBatch is a paid mutator transaction binding the contract method 0x47faad14.
//
// Solidity: function proposeBatch(bytes _params, bytes _txList) returns((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint64,uint32,uint32,uint32,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint32)) info_, (bytes32,address,uint64,uint64) meta_)
func (_TaikoInboxClient *TaikoInboxClientTransactorSession) ProposeBatch(_params []byte, _txList []byte) (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.ProposeBatch(&_TaikoInboxClient.TransactOpts, _params, _txList)
}

// ProveBatches is a paid mutator transaction binding the contract method 0xc9cc2843.
//
// Solidity: function proveBatches(bytes _params, bytes _proof) returns()
func (_TaikoInboxClient *TaikoInboxClientTransactor) ProveBatches(opts *bind.TransactOpts, _params []byte, _proof []byte) (*types.Transaction, error) {
	return _TaikoInboxClient.contract.Transact(opts, "proveBatches", _params, _proof)
}

// ProveBatches is a paid mutator transaction binding the contract method 0xc9cc2843.
//
// Solidity: function proveBatches(bytes _params, bytes _proof) returns()
func (_TaikoInboxClient *TaikoInboxClientSession) ProveBatches(_params []byte, _proof []byte) (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.ProveBatches(&_TaikoInboxClient.TransactOpts, _params, _proof)
}

// ProveBatches is a paid mutator transaction binding the contract method 0xc9cc2843.
//
// Solidity: function proveBatches(bytes _params, bytes _proof) returns()
func (_TaikoInboxClient *TaikoInboxClientTransactorSession) ProveBatches(_params []byte, _proof []byte) (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.ProveBatches(&_TaikoInboxClient.TransactOpts, _params, _proof)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoInboxClient *TaikoInboxClientTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoInboxClient.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoInboxClient *TaikoInboxClientSession) RenounceOwnership() (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.RenounceOwnership(&_TaikoInboxClient.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoInboxClient *TaikoInboxClientTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.RenounceOwnership(&_TaikoInboxClient.TransactOpts)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoInboxClient *TaikoInboxClientTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _TaikoInboxClient.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoInboxClient *TaikoInboxClientSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.TransferOwnership(&_TaikoInboxClient.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoInboxClient *TaikoInboxClientTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.TransferOwnership(&_TaikoInboxClient.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_TaikoInboxClient *TaikoInboxClientTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoInboxClient.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_TaikoInboxClient *TaikoInboxClientSession) Unpause() (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.Unpause(&_TaikoInboxClient.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_TaikoInboxClient *TaikoInboxClientTransactorSession) Unpause() (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.Unpause(&_TaikoInboxClient.TransactOpts)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_TaikoInboxClient *TaikoInboxClientTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _TaikoInboxClient.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_TaikoInboxClient *TaikoInboxClientSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.UpgradeTo(&_TaikoInboxClient.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_TaikoInboxClient *TaikoInboxClientTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.UpgradeTo(&_TaikoInboxClient.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_TaikoInboxClient *TaikoInboxClientTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _TaikoInboxClient.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_TaikoInboxClient *TaikoInboxClientSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.UpgradeToAndCall(&_TaikoInboxClient.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_TaikoInboxClient *TaikoInboxClientTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.UpgradeToAndCall(&_TaikoInboxClient.TransactOpts, newImplementation, data)
}

// VerifyBatches is a paid mutator transaction binding the contract method 0x0cc62b42.
//
// Solidity: function verifyBatches(uint64 _length) returns()
func (_TaikoInboxClient *TaikoInboxClientTransactor) VerifyBatches(opts *bind.TransactOpts, _length uint64) (*types.Transaction, error) {
	return _TaikoInboxClient.contract.Transact(opts, "verifyBatches", _length)
}

// VerifyBatches is a paid mutator transaction binding the contract method 0x0cc62b42.
//
// Solidity: function verifyBatches(uint64 _length) returns()
func (_TaikoInboxClient *TaikoInboxClientSession) VerifyBatches(_length uint64) (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.VerifyBatches(&_TaikoInboxClient.TransactOpts, _length)
}

// VerifyBatches is a paid mutator transaction binding the contract method 0x0cc62b42.
//
// Solidity: function verifyBatches(uint64 _length) returns()
func (_TaikoInboxClient *TaikoInboxClientTransactorSession) VerifyBatches(_length uint64) (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.VerifyBatches(&_TaikoInboxClient.TransactOpts, _length)
}

// WithdrawBond is a paid mutator transaction binding the contract method 0xc3daab96.
//
// Solidity: function withdrawBond(uint256 _amount) returns()
func (_TaikoInboxClient *TaikoInboxClientTransactor) WithdrawBond(opts *bind.TransactOpts, _amount *big.Int) (*types.Transaction, error) {
	return _TaikoInboxClient.contract.Transact(opts, "withdrawBond", _amount)
}

// WithdrawBond is a paid mutator transaction binding the contract method 0xc3daab96.
//
// Solidity: function withdrawBond(uint256 _amount) returns()
func (_TaikoInboxClient *TaikoInboxClientSession) WithdrawBond(_amount *big.Int) (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.WithdrawBond(&_TaikoInboxClient.TransactOpts, _amount)
}

// WithdrawBond is a paid mutator transaction binding the contract method 0xc3daab96.
//
// Solidity: function withdrawBond(uint256 _amount) returns()
func (_TaikoInboxClient *TaikoInboxClientTransactorSession) WithdrawBond(_amount *big.Int) (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.WithdrawBond(&_TaikoInboxClient.TransactOpts, _amount)
}

// WriteTransition is a paid mutator transaction binding the contract method 0xc152c9eb.
//
// Solidity: function writeTransition(uint64 _batchId, bytes32 _parentHash, bytes32 _blockHash, bytes32 _stateRoot, address _prover, bool _inProvingWindow) returns()
func (_TaikoInboxClient *TaikoInboxClientTransactor) WriteTransition(opts *bind.TransactOpts, _batchId uint64, _parentHash [32]byte, _blockHash [32]byte, _stateRoot [32]byte, _prover common.Address, _inProvingWindow bool) (*types.Transaction, error) {
	return _TaikoInboxClient.contract.Transact(opts, "writeTransition", _batchId, _parentHash, _blockHash, _stateRoot, _prover, _inProvingWindow)
}

// WriteTransition is a paid mutator transaction binding the contract method 0xc152c9eb.
//
// Solidity: function writeTransition(uint64 _batchId, bytes32 _parentHash, bytes32 _blockHash, bytes32 _stateRoot, address _prover, bool _inProvingWindow) returns()
func (_TaikoInboxClient *TaikoInboxClientSession) WriteTransition(_batchId uint64, _parentHash [32]byte, _blockHash [32]byte, _stateRoot [32]byte, _prover common.Address, _inProvingWindow bool) (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.WriteTransition(&_TaikoInboxClient.TransactOpts, _batchId, _parentHash, _blockHash, _stateRoot, _prover, _inProvingWindow)
}

// WriteTransition is a paid mutator transaction binding the contract method 0xc152c9eb.
//
// Solidity: function writeTransition(uint64 _batchId, bytes32 _parentHash, bytes32 _blockHash, bytes32 _stateRoot, address _prover, bool _inProvingWindow) returns()
func (_TaikoInboxClient *TaikoInboxClientTransactorSession) WriteTransition(_batchId uint64, _parentHash [32]byte, _blockHash [32]byte, _stateRoot [32]byte, _prover common.Address, _inProvingWindow bool) (*types.Transaction, error) {
	return _TaikoInboxClient.Contract.WriteTransition(&_TaikoInboxClient.TransactOpts, _batchId, _parentHash, _blockHash, _stateRoot, _prover, _inProvingWindow)
}

// TaikoInboxClientAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the TaikoInboxClient contract.
type TaikoInboxClientAdminChangedIterator struct {
	Event *TaikoInboxClientAdminChanged // Event containing the contract specifics and raw log

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
func (it *TaikoInboxClientAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxClientAdminChanged)
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
		it.Event = new(TaikoInboxClientAdminChanged)
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
func (it *TaikoInboxClientAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxClientAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxClientAdminChanged represents a AdminChanged event raised by the TaikoInboxClient contract.
type TaikoInboxClientAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_TaikoInboxClient *TaikoInboxClientFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*TaikoInboxClientAdminChangedIterator, error) {

	logs, sub, err := _TaikoInboxClient.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &TaikoInboxClientAdminChangedIterator{contract: _TaikoInboxClient.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_TaikoInboxClient *TaikoInboxClientFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *TaikoInboxClientAdminChanged) (event.Subscription, error) {

	logs, sub, err := _TaikoInboxClient.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxClientAdminChanged)
				if err := _TaikoInboxClient.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_TaikoInboxClient *TaikoInboxClientFilterer) ParseAdminChanged(log types.Log) (*TaikoInboxClientAdminChanged, error) {
	event := new(TaikoInboxClientAdminChanged)
	if err := _TaikoInboxClient.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxClientBatchProposedIterator is returned from FilterBatchProposed and is used to iterate over the raw logs and unpacked data for BatchProposed events raised by the TaikoInboxClient contract.
type TaikoInboxClientBatchProposedIterator struct {
	Event *TaikoInboxClientBatchProposed // Event containing the contract specifics and raw log

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
func (it *TaikoInboxClientBatchProposedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxClientBatchProposed)
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
		it.Event = new(TaikoInboxClientBatchProposed)
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
func (it *TaikoInboxClientBatchProposedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxClientBatchProposedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxClientBatchProposed represents a BatchProposed event raised by the TaikoInboxClient contract.
type TaikoInboxClientBatchProposed struct {
	Info   ITaikoInboxBatchInfo
	Meta   ITaikoInboxBatchMetadata
	TxList []byte
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBatchProposed is a free log retrieval operation binding the contract event 0x9eb7fc80523943f28950bbb71ed6d584effe3e1e02ca4ddc8c86e5ee1558c096.
//
// Solidity: event BatchProposed((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint64,uint32,uint32,uint32,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint32)) info, (bytes32,address,uint64,uint64) meta, bytes txList)
func (_TaikoInboxClient *TaikoInboxClientFilterer) FilterBatchProposed(opts *bind.FilterOpts) (*TaikoInboxClientBatchProposedIterator, error) {

	logs, sub, err := _TaikoInboxClient.contract.FilterLogs(opts, "BatchProposed")
	if err != nil {
		return nil, err
	}
	return &TaikoInboxClientBatchProposedIterator{contract: _TaikoInboxClient.contract, event: "BatchProposed", logs: logs, sub: sub}, nil
}

// WatchBatchProposed is a free log subscription operation binding the contract event 0x9eb7fc80523943f28950bbb71ed6d584effe3e1e02ca4ddc8c86e5ee1558c096.
//
// Solidity: event BatchProposed((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint64,uint32,uint32,uint32,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint32)) info, (bytes32,address,uint64,uint64) meta, bytes txList)
func (_TaikoInboxClient *TaikoInboxClientFilterer) WatchBatchProposed(opts *bind.WatchOpts, sink chan<- *TaikoInboxClientBatchProposed) (event.Subscription, error) {

	logs, sub, err := _TaikoInboxClient.contract.WatchLogs(opts, "BatchProposed")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxClientBatchProposed)
				if err := _TaikoInboxClient.contract.UnpackLog(event, "BatchProposed", log); err != nil {
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

// ParseBatchProposed is a log parse operation binding the contract event 0x9eb7fc80523943f28950bbb71ed6d584effe3e1e02ca4ddc8c86e5ee1558c096.
//
// Solidity: event BatchProposed((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint64,uint32,uint32,uint32,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint32)) info, (bytes32,address,uint64,uint64) meta, bytes txList)
func (_TaikoInboxClient *TaikoInboxClientFilterer) ParseBatchProposed(log types.Log) (*TaikoInboxClientBatchProposed, error) {
	event := new(TaikoInboxClientBatchProposed)
	if err := _TaikoInboxClient.contract.UnpackLog(event, "BatchProposed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxClientBatchesProvedIterator is returned from FilterBatchesProved and is used to iterate over the raw logs and unpacked data for BatchesProved events raised by the TaikoInboxClient contract.
type TaikoInboxClientBatchesProvedIterator struct {
	Event *TaikoInboxClientBatchesProved // Event containing the contract specifics and raw log

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
func (it *TaikoInboxClientBatchesProvedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxClientBatchesProved)
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
		it.Event = new(TaikoInboxClientBatchesProved)
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
func (it *TaikoInboxClientBatchesProvedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxClientBatchesProvedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxClientBatchesProved represents a BatchesProved event raised by the TaikoInboxClient contract.
type TaikoInboxClientBatchesProved struct {
	Verifier    common.Address
	BatchIds    []uint64
	Transitions []ITaikoInboxTransition
	Raw         types.Log // Blockchain specific contextual infos
}

// FilterBatchesProved is a free log retrieval operation binding the contract event 0xc99f03c7db71a9e8c78654b1d2f77378b413cc979a02fa22dc9d39702afa92bc.
//
// Solidity: event BatchesProved(address verifier, uint64[] batchIds, (bytes32,bytes32,bytes32)[] transitions)
func (_TaikoInboxClient *TaikoInboxClientFilterer) FilterBatchesProved(opts *bind.FilterOpts) (*TaikoInboxClientBatchesProvedIterator, error) {

	logs, sub, err := _TaikoInboxClient.contract.FilterLogs(opts, "BatchesProved")
	if err != nil {
		return nil, err
	}
	return &TaikoInboxClientBatchesProvedIterator{contract: _TaikoInboxClient.contract, event: "BatchesProved", logs: logs, sub: sub}, nil
}

// WatchBatchesProved is a free log subscription operation binding the contract event 0xc99f03c7db71a9e8c78654b1d2f77378b413cc979a02fa22dc9d39702afa92bc.
//
// Solidity: event BatchesProved(address verifier, uint64[] batchIds, (bytes32,bytes32,bytes32)[] transitions)
func (_TaikoInboxClient *TaikoInboxClientFilterer) WatchBatchesProved(opts *bind.WatchOpts, sink chan<- *TaikoInboxClientBatchesProved) (event.Subscription, error) {

	logs, sub, err := _TaikoInboxClient.contract.WatchLogs(opts, "BatchesProved")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxClientBatchesProved)
				if err := _TaikoInboxClient.contract.UnpackLog(event, "BatchesProved", log); err != nil {
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
func (_TaikoInboxClient *TaikoInboxClientFilterer) ParseBatchesProved(log types.Log) (*TaikoInboxClientBatchesProved, error) {
	event := new(TaikoInboxClientBatchesProved)
	if err := _TaikoInboxClient.contract.UnpackLog(event, "BatchesProved", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxClientBatchesVerifiedIterator is returned from FilterBatchesVerified and is used to iterate over the raw logs and unpacked data for BatchesVerified events raised by the TaikoInboxClient contract.
type TaikoInboxClientBatchesVerifiedIterator struct {
	Event *TaikoInboxClientBatchesVerified // Event containing the contract specifics and raw log

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
func (it *TaikoInboxClientBatchesVerifiedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxClientBatchesVerified)
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
		it.Event = new(TaikoInboxClientBatchesVerified)
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
func (it *TaikoInboxClientBatchesVerifiedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxClientBatchesVerifiedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxClientBatchesVerified represents a BatchesVerified event raised by the TaikoInboxClient contract.
type TaikoInboxClientBatchesVerified struct {
	BatchId   uint64
	BlockHash [32]byte
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterBatchesVerified is a free log retrieval operation binding the contract event 0xd6b1adebb10d3d794bc13103c4e9a696e79b3ce83355d8bdd77237cb20b3a4a0.
//
// Solidity: event BatchesVerified(uint64 batchId, bytes32 blockHash)
func (_TaikoInboxClient *TaikoInboxClientFilterer) FilterBatchesVerified(opts *bind.FilterOpts) (*TaikoInboxClientBatchesVerifiedIterator, error) {

	logs, sub, err := _TaikoInboxClient.contract.FilterLogs(opts, "BatchesVerified")
	if err != nil {
		return nil, err
	}
	return &TaikoInboxClientBatchesVerifiedIterator{contract: _TaikoInboxClient.contract, event: "BatchesVerified", logs: logs, sub: sub}, nil
}

// WatchBatchesVerified is a free log subscription operation binding the contract event 0xd6b1adebb10d3d794bc13103c4e9a696e79b3ce83355d8bdd77237cb20b3a4a0.
//
// Solidity: event BatchesVerified(uint64 batchId, bytes32 blockHash)
func (_TaikoInboxClient *TaikoInboxClientFilterer) WatchBatchesVerified(opts *bind.WatchOpts, sink chan<- *TaikoInboxClientBatchesVerified) (event.Subscription, error) {

	logs, sub, err := _TaikoInboxClient.contract.WatchLogs(opts, "BatchesVerified")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxClientBatchesVerified)
				if err := _TaikoInboxClient.contract.UnpackLog(event, "BatchesVerified", log); err != nil {
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
func (_TaikoInboxClient *TaikoInboxClientFilterer) ParseBatchesVerified(log types.Log) (*TaikoInboxClientBatchesVerified, error) {
	event := new(TaikoInboxClientBatchesVerified)
	if err := _TaikoInboxClient.contract.UnpackLog(event, "BatchesVerified", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxClientBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the TaikoInboxClient contract.
type TaikoInboxClientBeaconUpgradedIterator struct {
	Event *TaikoInboxClientBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *TaikoInboxClientBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxClientBeaconUpgraded)
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
		it.Event = new(TaikoInboxClientBeaconUpgraded)
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
func (it *TaikoInboxClientBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxClientBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxClientBeaconUpgraded represents a BeaconUpgraded event raised by the TaikoInboxClient contract.
type TaikoInboxClientBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_TaikoInboxClient *TaikoInboxClientFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*TaikoInboxClientBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _TaikoInboxClient.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &TaikoInboxClientBeaconUpgradedIterator{contract: _TaikoInboxClient.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_TaikoInboxClient *TaikoInboxClientFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *TaikoInboxClientBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _TaikoInboxClient.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxClientBeaconUpgraded)
				if err := _TaikoInboxClient.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_TaikoInboxClient *TaikoInboxClientFilterer) ParseBeaconUpgraded(log types.Log) (*TaikoInboxClientBeaconUpgraded, error) {
	event := new(TaikoInboxClientBeaconUpgraded)
	if err := _TaikoInboxClient.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxClientBondCreditedIterator is returned from FilterBondCredited and is used to iterate over the raw logs and unpacked data for BondCredited events raised by the TaikoInboxClient contract.
type TaikoInboxClientBondCreditedIterator struct {
	Event *TaikoInboxClientBondCredited // Event containing the contract specifics and raw log

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
func (it *TaikoInboxClientBondCreditedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxClientBondCredited)
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
		it.Event = new(TaikoInboxClientBondCredited)
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
func (it *TaikoInboxClientBondCreditedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxClientBondCreditedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxClientBondCredited represents a BondCredited event raised by the TaikoInboxClient contract.
type TaikoInboxClientBondCredited struct {
	User   common.Address
	Amount *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBondCredited is a free log retrieval operation binding the contract event 0x6de6fe586196fa05b73b973026c5fda3968a2933989bff3a0b6bd57644fab606.
//
// Solidity: event BondCredited(address indexed user, uint256 amount)
func (_TaikoInboxClient *TaikoInboxClientFilterer) FilterBondCredited(opts *bind.FilterOpts, user []common.Address) (*TaikoInboxClientBondCreditedIterator, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoInboxClient.contract.FilterLogs(opts, "BondCredited", userRule)
	if err != nil {
		return nil, err
	}
	return &TaikoInboxClientBondCreditedIterator{contract: _TaikoInboxClient.contract, event: "BondCredited", logs: logs, sub: sub}, nil
}

// WatchBondCredited is a free log subscription operation binding the contract event 0x6de6fe586196fa05b73b973026c5fda3968a2933989bff3a0b6bd57644fab606.
//
// Solidity: event BondCredited(address indexed user, uint256 amount)
func (_TaikoInboxClient *TaikoInboxClientFilterer) WatchBondCredited(opts *bind.WatchOpts, sink chan<- *TaikoInboxClientBondCredited, user []common.Address) (event.Subscription, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoInboxClient.contract.WatchLogs(opts, "BondCredited", userRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxClientBondCredited)
				if err := _TaikoInboxClient.contract.UnpackLog(event, "BondCredited", log); err != nil {
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
func (_TaikoInboxClient *TaikoInboxClientFilterer) ParseBondCredited(log types.Log) (*TaikoInboxClientBondCredited, error) {
	event := new(TaikoInboxClientBondCredited)
	if err := _TaikoInboxClient.contract.UnpackLog(event, "BondCredited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxClientBondDebitedIterator is returned from FilterBondDebited and is used to iterate over the raw logs and unpacked data for BondDebited events raised by the TaikoInboxClient contract.
type TaikoInboxClientBondDebitedIterator struct {
	Event *TaikoInboxClientBondDebited // Event containing the contract specifics and raw log

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
func (it *TaikoInboxClientBondDebitedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxClientBondDebited)
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
		it.Event = new(TaikoInboxClientBondDebited)
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
func (it *TaikoInboxClientBondDebitedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxClientBondDebitedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxClientBondDebited represents a BondDebited event raised by the TaikoInboxClient contract.
type TaikoInboxClientBondDebited struct {
	User   common.Address
	Amount *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBondDebited is a free log retrieval operation binding the contract event 0x85f32beeaff2d0019a8d196f06790c9a652191759c46643311344fd38920423c.
//
// Solidity: event BondDebited(address indexed user, uint256 amount)
func (_TaikoInboxClient *TaikoInboxClientFilterer) FilterBondDebited(opts *bind.FilterOpts, user []common.Address) (*TaikoInboxClientBondDebitedIterator, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoInboxClient.contract.FilterLogs(opts, "BondDebited", userRule)
	if err != nil {
		return nil, err
	}
	return &TaikoInboxClientBondDebitedIterator{contract: _TaikoInboxClient.contract, event: "BondDebited", logs: logs, sub: sub}, nil
}

// WatchBondDebited is a free log subscription operation binding the contract event 0x85f32beeaff2d0019a8d196f06790c9a652191759c46643311344fd38920423c.
//
// Solidity: event BondDebited(address indexed user, uint256 amount)
func (_TaikoInboxClient *TaikoInboxClientFilterer) WatchBondDebited(opts *bind.WatchOpts, sink chan<- *TaikoInboxClientBondDebited, user []common.Address) (event.Subscription, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoInboxClient.contract.WatchLogs(opts, "BondDebited", userRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxClientBondDebited)
				if err := _TaikoInboxClient.contract.UnpackLog(event, "BondDebited", log); err != nil {
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
func (_TaikoInboxClient *TaikoInboxClientFilterer) ParseBondDebited(log types.Log) (*TaikoInboxClientBondDebited, error) {
	event := new(TaikoInboxClientBondDebited)
	if err := _TaikoInboxClient.contract.UnpackLog(event, "BondDebited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxClientBondDepositedIterator is returned from FilterBondDeposited and is used to iterate over the raw logs and unpacked data for BondDeposited events raised by the TaikoInboxClient contract.
type TaikoInboxClientBondDepositedIterator struct {
	Event *TaikoInboxClientBondDeposited // Event containing the contract specifics and raw log

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
func (it *TaikoInboxClientBondDepositedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxClientBondDeposited)
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
		it.Event = new(TaikoInboxClientBondDeposited)
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
func (it *TaikoInboxClientBondDepositedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxClientBondDepositedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxClientBondDeposited represents a BondDeposited event raised by the TaikoInboxClient contract.
type TaikoInboxClientBondDeposited struct {
	User   common.Address
	Amount *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBondDeposited is a free log retrieval operation binding the contract event 0x8ed8c6869618197b68315ade66e75ed3906c97b111fa3ab81e5760046825c7db.
//
// Solidity: event BondDeposited(address indexed user, uint256 amount)
func (_TaikoInboxClient *TaikoInboxClientFilterer) FilterBondDeposited(opts *bind.FilterOpts, user []common.Address) (*TaikoInboxClientBondDepositedIterator, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoInboxClient.contract.FilterLogs(opts, "BondDeposited", userRule)
	if err != nil {
		return nil, err
	}
	return &TaikoInboxClientBondDepositedIterator{contract: _TaikoInboxClient.contract, event: "BondDeposited", logs: logs, sub: sub}, nil
}

// WatchBondDeposited is a free log subscription operation binding the contract event 0x8ed8c6869618197b68315ade66e75ed3906c97b111fa3ab81e5760046825c7db.
//
// Solidity: event BondDeposited(address indexed user, uint256 amount)
func (_TaikoInboxClient *TaikoInboxClientFilterer) WatchBondDeposited(opts *bind.WatchOpts, sink chan<- *TaikoInboxClientBondDeposited, user []common.Address) (event.Subscription, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoInboxClient.contract.WatchLogs(opts, "BondDeposited", userRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxClientBondDeposited)
				if err := _TaikoInboxClient.contract.UnpackLog(event, "BondDeposited", log); err != nil {
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
func (_TaikoInboxClient *TaikoInboxClientFilterer) ParseBondDeposited(log types.Log) (*TaikoInboxClientBondDeposited, error) {
	event := new(TaikoInboxClientBondDeposited)
	if err := _TaikoInboxClient.contract.UnpackLog(event, "BondDeposited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxClientBondWithdrawnIterator is returned from FilterBondWithdrawn and is used to iterate over the raw logs and unpacked data for BondWithdrawn events raised by the TaikoInboxClient contract.
type TaikoInboxClientBondWithdrawnIterator struct {
	Event *TaikoInboxClientBondWithdrawn // Event containing the contract specifics and raw log

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
func (it *TaikoInboxClientBondWithdrawnIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxClientBondWithdrawn)
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
		it.Event = new(TaikoInboxClientBondWithdrawn)
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
func (it *TaikoInboxClientBondWithdrawnIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxClientBondWithdrawnIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxClientBondWithdrawn represents a BondWithdrawn event raised by the TaikoInboxClient contract.
type TaikoInboxClientBondWithdrawn struct {
	User   common.Address
	Amount *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBondWithdrawn is a free log retrieval operation binding the contract event 0x0d41118e36df44efb77a471fc49fb9c0be0406d802ef95520e9fbf606e65b455.
//
// Solidity: event BondWithdrawn(address indexed user, uint256 amount)
func (_TaikoInboxClient *TaikoInboxClientFilterer) FilterBondWithdrawn(opts *bind.FilterOpts, user []common.Address) (*TaikoInboxClientBondWithdrawnIterator, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoInboxClient.contract.FilterLogs(opts, "BondWithdrawn", userRule)
	if err != nil {
		return nil, err
	}
	return &TaikoInboxClientBondWithdrawnIterator{contract: _TaikoInboxClient.contract, event: "BondWithdrawn", logs: logs, sub: sub}, nil
}

// WatchBondWithdrawn is a free log subscription operation binding the contract event 0x0d41118e36df44efb77a471fc49fb9c0be0406d802ef95520e9fbf606e65b455.
//
// Solidity: event BondWithdrawn(address indexed user, uint256 amount)
func (_TaikoInboxClient *TaikoInboxClientFilterer) WatchBondWithdrawn(opts *bind.WatchOpts, sink chan<- *TaikoInboxClientBondWithdrawn, user []common.Address) (event.Subscription, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _TaikoInboxClient.contract.WatchLogs(opts, "BondWithdrawn", userRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxClientBondWithdrawn)
				if err := _TaikoInboxClient.contract.UnpackLog(event, "BondWithdrawn", log); err != nil {
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
func (_TaikoInboxClient *TaikoInboxClientFilterer) ParseBondWithdrawn(log types.Log) (*TaikoInboxClientBondWithdrawn, error) {
	event := new(TaikoInboxClientBondWithdrawn)
	if err := _TaikoInboxClient.contract.UnpackLog(event, "BondWithdrawn", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxClientConflictingProofIterator is returned from FilterConflictingProof and is used to iterate over the raw logs and unpacked data for ConflictingProof events raised by the TaikoInboxClient contract.
type TaikoInboxClientConflictingProofIterator struct {
	Event *TaikoInboxClientConflictingProof // Event containing the contract specifics and raw log

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
func (it *TaikoInboxClientConflictingProofIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxClientConflictingProof)
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
		it.Event = new(TaikoInboxClientConflictingProof)
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
func (it *TaikoInboxClientConflictingProofIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxClientConflictingProofIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxClientConflictingProof represents a ConflictingProof event raised by the TaikoInboxClient contract.
type TaikoInboxClientConflictingProof struct {
	BatchId uint64
	OldTran ITaikoInboxTransitionState
	NewTran ITaikoInboxTransition
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterConflictingProof is a free log retrieval operation binding the contract event 0xa05e896ff20170d694345384140d3397c040699d982fd6bdd73028e3d311f444.
//
// Solidity: event ConflictingProof(uint64 batchId, (bytes32,bytes32,bytes32,address,bool,uint48) oldTran, (bytes32,bytes32,bytes32) newTran)
func (_TaikoInboxClient *TaikoInboxClientFilterer) FilterConflictingProof(opts *bind.FilterOpts) (*TaikoInboxClientConflictingProofIterator, error) {

	logs, sub, err := _TaikoInboxClient.contract.FilterLogs(opts, "ConflictingProof")
	if err != nil {
		return nil, err
	}
	return &TaikoInboxClientConflictingProofIterator{contract: _TaikoInboxClient.contract, event: "ConflictingProof", logs: logs, sub: sub}, nil
}

// WatchConflictingProof is a free log subscription operation binding the contract event 0xa05e896ff20170d694345384140d3397c040699d982fd6bdd73028e3d311f444.
//
// Solidity: event ConflictingProof(uint64 batchId, (bytes32,bytes32,bytes32,address,bool,uint48) oldTran, (bytes32,bytes32,bytes32) newTran)
func (_TaikoInboxClient *TaikoInboxClientFilterer) WatchConflictingProof(opts *bind.WatchOpts, sink chan<- *TaikoInboxClientConflictingProof) (event.Subscription, error) {

	logs, sub, err := _TaikoInboxClient.contract.WatchLogs(opts, "ConflictingProof")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxClientConflictingProof)
				if err := _TaikoInboxClient.contract.UnpackLog(event, "ConflictingProof", log); err != nil {
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
func (_TaikoInboxClient *TaikoInboxClientFilterer) ParseConflictingProof(log types.Log) (*TaikoInboxClientConflictingProof, error) {
	event := new(TaikoInboxClientConflictingProof)
	if err := _TaikoInboxClient.contract.UnpackLog(event, "ConflictingProof", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxClientInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the TaikoInboxClient contract.
type TaikoInboxClientInitializedIterator struct {
	Event *TaikoInboxClientInitialized // Event containing the contract specifics and raw log

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
func (it *TaikoInboxClientInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxClientInitialized)
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
		it.Event = new(TaikoInboxClientInitialized)
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
func (it *TaikoInboxClientInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxClientInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxClientInitialized represents a Initialized event raised by the TaikoInboxClient contract.
type TaikoInboxClientInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_TaikoInboxClient *TaikoInboxClientFilterer) FilterInitialized(opts *bind.FilterOpts) (*TaikoInboxClientInitializedIterator, error) {

	logs, sub, err := _TaikoInboxClient.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &TaikoInboxClientInitializedIterator{contract: _TaikoInboxClient.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_TaikoInboxClient *TaikoInboxClientFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *TaikoInboxClientInitialized) (event.Subscription, error) {

	logs, sub, err := _TaikoInboxClient.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxClientInitialized)
				if err := _TaikoInboxClient.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_TaikoInboxClient *TaikoInboxClientFilterer) ParseInitialized(log types.Log) (*TaikoInboxClientInitialized, error) {
	event := new(TaikoInboxClientInitialized)
	if err := _TaikoInboxClient.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxClientOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the TaikoInboxClient contract.
type TaikoInboxClientOwnershipTransferStartedIterator struct {
	Event *TaikoInboxClientOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *TaikoInboxClientOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxClientOwnershipTransferStarted)
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
		it.Event = new(TaikoInboxClientOwnershipTransferStarted)
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
func (it *TaikoInboxClientOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxClientOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxClientOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the TaikoInboxClient contract.
type TaikoInboxClientOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_TaikoInboxClient *TaikoInboxClientFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*TaikoInboxClientOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoInboxClient.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &TaikoInboxClientOwnershipTransferStartedIterator{contract: _TaikoInboxClient.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_TaikoInboxClient *TaikoInboxClientFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *TaikoInboxClientOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoInboxClient.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxClientOwnershipTransferStarted)
				if err := _TaikoInboxClient.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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
func (_TaikoInboxClient *TaikoInboxClientFilterer) ParseOwnershipTransferStarted(log types.Log) (*TaikoInboxClientOwnershipTransferStarted, error) {
	event := new(TaikoInboxClientOwnershipTransferStarted)
	if err := _TaikoInboxClient.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxClientOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the TaikoInboxClient contract.
type TaikoInboxClientOwnershipTransferredIterator struct {
	Event *TaikoInboxClientOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *TaikoInboxClientOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxClientOwnershipTransferred)
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
		it.Event = new(TaikoInboxClientOwnershipTransferred)
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
func (it *TaikoInboxClientOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxClientOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxClientOwnershipTransferred represents a OwnershipTransferred event raised by the TaikoInboxClient contract.
type TaikoInboxClientOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_TaikoInboxClient *TaikoInboxClientFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*TaikoInboxClientOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoInboxClient.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &TaikoInboxClientOwnershipTransferredIterator{contract: _TaikoInboxClient.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_TaikoInboxClient *TaikoInboxClientFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *TaikoInboxClientOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoInboxClient.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxClientOwnershipTransferred)
				if err := _TaikoInboxClient.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_TaikoInboxClient *TaikoInboxClientFilterer) ParseOwnershipTransferred(log types.Log) (*TaikoInboxClientOwnershipTransferred, error) {
	event := new(TaikoInboxClientOwnershipTransferred)
	if err := _TaikoInboxClient.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxClientPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the TaikoInboxClient contract.
type TaikoInboxClientPausedIterator struct {
	Event *TaikoInboxClientPaused // Event containing the contract specifics and raw log

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
func (it *TaikoInboxClientPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxClientPaused)
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
		it.Event = new(TaikoInboxClientPaused)
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
func (it *TaikoInboxClientPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxClientPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxClientPaused represents a Paused event raised by the TaikoInboxClient contract.
type TaikoInboxClientPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_TaikoInboxClient *TaikoInboxClientFilterer) FilterPaused(opts *bind.FilterOpts) (*TaikoInboxClientPausedIterator, error) {

	logs, sub, err := _TaikoInboxClient.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &TaikoInboxClientPausedIterator{contract: _TaikoInboxClient.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_TaikoInboxClient *TaikoInboxClientFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *TaikoInboxClientPaused) (event.Subscription, error) {

	logs, sub, err := _TaikoInboxClient.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxClientPaused)
				if err := _TaikoInboxClient.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_TaikoInboxClient *TaikoInboxClientFilterer) ParsePaused(log types.Log) (*TaikoInboxClientPaused, error) {
	event := new(TaikoInboxClientPaused)
	if err := _TaikoInboxClient.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxClientStats1UpdatedIterator is returned from FilterStats1Updated and is used to iterate over the raw logs and unpacked data for Stats1Updated events raised by the TaikoInboxClient contract.
type TaikoInboxClientStats1UpdatedIterator struct {
	Event *TaikoInboxClientStats1Updated // Event containing the contract specifics and raw log

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
func (it *TaikoInboxClientStats1UpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxClientStats1Updated)
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
		it.Event = new(TaikoInboxClientStats1Updated)
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
func (it *TaikoInboxClientStats1UpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxClientStats1UpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxClientStats1Updated represents a Stats1Updated event raised by the TaikoInboxClient contract.
type TaikoInboxClientStats1Updated struct {
	Stats1 ITaikoInboxStats1
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterStats1Updated is a free log retrieval operation binding the contract event 0xcfbcbd3a81b749a28e6289bc350363f1949bb0a58ba7120d8dd4ef4b3617dff8.
//
// Solidity: event Stats1Updated((uint64,uint64,uint64,uint64) stats1)
func (_TaikoInboxClient *TaikoInboxClientFilterer) FilterStats1Updated(opts *bind.FilterOpts) (*TaikoInboxClientStats1UpdatedIterator, error) {

	logs, sub, err := _TaikoInboxClient.contract.FilterLogs(opts, "Stats1Updated")
	if err != nil {
		return nil, err
	}
	return &TaikoInboxClientStats1UpdatedIterator{contract: _TaikoInboxClient.contract, event: "Stats1Updated", logs: logs, sub: sub}, nil
}

// WatchStats1Updated is a free log subscription operation binding the contract event 0xcfbcbd3a81b749a28e6289bc350363f1949bb0a58ba7120d8dd4ef4b3617dff8.
//
// Solidity: event Stats1Updated((uint64,uint64,uint64,uint64) stats1)
func (_TaikoInboxClient *TaikoInboxClientFilterer) WatchStats1Updated(opts *bind.WatchOpts, sink chan<- *TaikoInboxClientStats1Updated) (event.Subscription, error) {

	logs, sub, err := _TaikoInboxClient.contract.WatchLogs(opts, "Stats1Updated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxClientStats1Updated)
				if err := _TaikoInboxClient.contract.UnpackLog(event, "Stats1Updated", log); err != nil {
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
func (_TaikoInboxClient *TaikoInboxClientFilterer) ParseStats1Updated(log types.Log) (*TaikoInboxClientStats1Updated, error) {
	event := new(TaikoInboxClientStats1Updated)
	if err := _TaikoInboxClient.contract.UnpackLog(event, "Stats1Updated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxClientStats2UpdatedIterator is returned from FilterStats2Updated and is used to iterate over the raw logs and unpacked data for Stats2Updated events raised by the TaikoInboxClient contract.
type TaikoInboxClientStats2UpdatedIterator struct {
	Event *TaikoInboxClientStats2Updated // Event containing the contract specifics and raw log

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
func (it *TaikoInboxClientStats2UpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxClientStats2Updated)
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
		it.Event = new(TaikoInboxClientStats2Updated)
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
func (it *TaikoInboxClientStats2UpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxClientStats2UpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxClientStats2Updated represents a Stats2Updated event raised by the TaikoInboxClient contract.
type TaikoInboxClientStats2Updated struct {
	Stats2 ITaikoInboxStats2
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterStats2Updated is a free log retrieval operation binding the contract event 0x7156d026e6a3864d290a971910746f96477d3901e33c4b2375e4ee00dabe7d87.
//
// Solidity: event Stats2Updated((uint64,uint64,bool,uint56,uint64) stats2)
func (_TaikoInboxClient *TaikoInboxClientFilterer) FilterStats2Updated(opts *bind.FilterOpts) (*TaikoInboxClientStats2UpdatedIterator, error) {

	logs, sub, err := _TaikoInboxClient.contract.FilterLogs(opts, "Stats2Updated")
	if err != nil {
		return nil, err
	}
	return &TaikoInboxClientStats2UpdatedIterator{contract: _TaikoInboxClient.contract, event: "Stats2Updated", logs: logs, sub: sub}, nil
}

// WatchStats2Updated is a free log subscription operation binding the contract event 0x7156d026e6a3864d290a971910746f96477d3901e33c4b2375e4ee00dabe7d87.
//
// Solidity: event Stats2Updated((uint64,uint64,bool,uint56,uint64) stats2)
func (_TaikoInboxClient *TaikoInboxClientFilterer) WatchStats2Updated(opts *bind.WatchOpts, sink chan<- *TaikoInboxClientStats2Updated) (event.Subscription, error) {

	logs, sub, err := _TaikoInboxClient.contract.WatchLogs(opts, "Stats2Updated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxClientStats2Updated)
				if err := _TaikoInboxClient.contract.UnpackLog(event, "Stats2Updated", log); err != nil {
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
func (_TaikoInboxClient *TaikoInboxClientFilterer) ParseStats2Updated(log types.Log) (*TaikoInboxClientStats2Updated, error) {
	event := new(TaikoInboxClientStats2Updated)
	if err := _TaikoInboxClient.contract.UnpackLog(event, "Stats2Updated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxClientTransitionWrittenIterator is returned from FilterTransitionWritten and is used to iterate over the raw logs and unpacked data for TransitionWritten events raised by the TaikoInboxClient contract.
type TaikoInboxClientTransitionWrittenIterator struct {
	Event *TaikoInboxClientTransitionWritten // Event containing the contract specifics and raw log

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
func (it *TaikoInboxClientTransitionWrittenIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxClientTransitionWritten)
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
		it.Event = new(TaikoInboxClientTransitionWritten)
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
func (it *TaikoInboxClientTransitionWrittenIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxClientTransitionWrittenIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxClientTransitionWritten represents a TransitionWritten event raised by the TaikoInboxClient contract.
type TaikoInboxClientTransitionWritten struct {
	BatchId uint64
	Tid     *big.Int
	Ts      ITaikoInboxTransitionState
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterTransitionWritten is a free log retrieval operation binding the contract event 0xd859648d474435f113442503ab429a8dc1e53be35a151a45aeec3e67302a941c.
//
// Solidity: event TransitionWritten(uint64 batchId, uint24 tid, (bytes32,bytes32,bytes32,address,bool,uint48) ts)
func (_TaikoInboxClient *TaikoInboxClientFilterer) FilterTransitionWritten(opts *bind.FilterOpts) (*TaikoInboxClientTransitionWrittenIterator, error) {

	logs, sub, err := _TaikoInboxClient.contract.FilterLogs(opts, "TransitionWritten")
	if err != nil {
		return nil, err
	}
	return &TaikoInboxClientTransitionWrittenIterator{contract: _TaikoInboxClient.contract, event: "TransitionWritten", logs: logs, sub: sub}, nil
}

// WatchTransitionWritten is a free log subscription operation binding the contract event 0xd859648d474435f113442503ab429a8dc1e53be35a151a45aeec3e67302a941c.
//
// Solidity: event TransitionWritten(uint64 batchId, uint24 tid, (bytes32,bytes32,bytes32,address,bool,uint48) ts)
func (_TaikoInboxClient *TaikoInboxClientFilterer) WatchTransitionWritten(opts *bind.WatchOpts, sink chan<- *TaikoInboxClientTransitionWritten) (event.Subscription, error) {

	logs, sub, err := _TaikoInboxClient.contract.WatchLogs(opts, "TransitionWritten")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxClientTransitionWritten)
				if err := _TaikoInboxClient.contract.UnpackLog(event, "TransitionWritten", log); err != nil {
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
func (_TaikoInboxClient *TaikoInboxClientFilterer) ParseTransitionWritten(log types.Log) (*TaikoInboxClientTransitionWritten, error) {
	event := new(TaikoInboxClientTransitionWritten)
	if err := _TaikoInboxClient.contract.UnpackLog(event, "TransitionWritten", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxClientUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the TaikoInboxClient contract.
type TaikoInboxClientUnpausedIterator struct {
	Event *TaikoInboxClientUnpaused // Event containing the contract specifics and raw log

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
func (it *TaikoInboxClientUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxClientUnpaused)
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
		it.Event = new(TaikoInboxClientUnpaused)
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
func (it *TaikoInboxClientUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxClientUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxClientUnpaused represents a Unpaused event raised by the TaikoInboxClient contract.
type TaikoInboxClientUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_TaikoInboxClient *TaikoInboxClientFilterer) FilterUnpaused(opts *bind.FilterOpts) (*TaikoInboxClientUnpausedIterator, error) {

	logs, sub, err := _TaikoInboxClient.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &TaikoInboxClientUnpausedIterator{contract: _TaikoInboxClient.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_TaikoInboxClient *TaikoInboxClientFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *TaikoInboxClientUnpaused) (event.Subscription, error) {

	logs, sub, err := _TaikoInboxClient.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxClientUnpaused)
				if err := _TaikoInboxClient.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_TaikoInboxClient *TaikoInboxClientFilterer) ParseUnpaused(log types.Log) (*TaikoInboxClientUnpaused, error) {
	event := new(TaikoInboxClientUnpaused)
	if err := _TaikoInboxClient.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoInboxClientUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the TaikoInboxClient contract.
type TaikoInboxClientUpgradedIterator struct {
	Event *TaikoInboxClientUpgraded // Event containing the contract specifics and raw log

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
func (it *TaikoInboxClientUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoInboxClientUpgraded)
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
		it.Event = new(TaikoInboxClientUpgraded)
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
func (it *TaikoInboxClientUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoInboxClientUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoInboxClientUpgraded represents a Upgraded event raised by the TaikoInboxClient contract.
type TaikoInboxClientUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_TaikoInboxClient *TaikoInboxClientFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*TaikoInboxClientUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _TaikoInboxClient.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &TaikoInboxClientUpgradedIterator{contract: _TaikoInboxClient.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_TaikoInboxClient *TaikoInboxClientFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *TaikoInboxClientUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _TaikoInboxClient.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoInboxClientUpgraded)
				if err := _TaikoInboxClient.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_TaikoInboxClient *TaikoInboxClientFilterer) ParseUpgraded(log types.Log) (*TaikoInboxClientUpgraded, error) {
	event := new(TaikoInboxClientUpgraded)
	if err := _TaikoInboxClient.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
