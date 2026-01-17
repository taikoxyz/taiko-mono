// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package inbox

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

// IBondManagerBond is an auto generated low-level Go binding around an user-defined struct.
type IBondManagerBond struct {
	Balance               uint64
	WithdrawalRequestedAt *big.Int
}

// IForcedInclusionStoreForcedInclusion is an auto generated low-level Go binding around an user-defined struct.
type IForcedInclusionStoreForcedInclusion struct {
	FeeInGwei uint64
	BlobSlice LibBlobsBlobSlice
}

// IInboxCommitment is an auto generated low-level Go binding around an user-defined struct.
type IInboxCommitment struct {
	FirstProposalId              *big.Int
	FirstProposalParentBlockHash [32]byte
	LastProposalHash             [32]byte
	ActualProver                 common.Address
	EndBlockNumber               *big.Int
	EndStateRoot                 [32]byte
	Transitions                  []IInboxTransition
}

// IInboxConfig is an auto generated low-level Go binding around an user-defined struct.
type IInboxConfig struct {
	ProofVerifier                     common.Address
	ProposerChecker                   common.Address
	ProverWhitelist                   common.Address
	SignalService                     common.Address
	BondToken                         common.Address
	MinBond                           uint64
	LivenessBond                      uint64
	WithdrawalDelay                   *big.Int
	ProvingWindow                     *big.Int
	PermissionlessProvingDelay        *big.Int
	MaxProofSubmissionDelay           *big.Int
	RingBufferSize                    *big.Int
	BasefeeSharingPctg                uint8
	MinForcedInclusionCount           *big.Int
	ForcedInclusionDelay              uint16
	ForcedInclusionFeeInGwei          uint64
	ForcedInclusionFeeDoubleThreshold uint64
	MinCheckpointDelay                uint16
	PermissionlessInclusionMultiplier uint8
}

// IInboxCoreState is an auto generated low-level Go binding around an user-defined struct.
type IInboxCoreState struct {
	NextProposalId          *big.Int
	LastProposalBlockId     *big.Int
	LastFinalizedProposalId *big.Int
	LastFinalizedTimestamp  *big.Int
	LastCheckpointTimestamp *big.Int
	LastFinalizedBlockHash  [32]byte
}

// IInboxDerivationSource is an auto generated low-level Go binding around an user-defined struct.
type IInboxDerivationSource struct {
	IsForcedInclusion bool
	BlobSlice         LibBlobsBlobSlice
}

// IInboxProposal is an auto generated low-level Go binding around an user-defined struct.
type IInboxProposal struct {
	Id                             *big.Int
	Timestamp                      *big.Int
	EndOfSubmissionWindowTimestamp *big.Int
	Proposer                       common.Address
	ParentProposalHash             [32]byte
	OriginBlockNumber              *big.Int
	OriginBlockHash                [32]byte
	BasefeeSharingPctg             uint8
	Sources                        []IInboxDerivationSource
}

// IInboxProposeInput is an auto generated low-level Go binding around an user-defined struct.
type IInboxProposeInput struct {
	Deadline            *big.Int
	BlobReference       LibBlobsBlobReference
	NumForcedInclusions uint8
}

// IInboxProveInput is an auto generated low-level Go binding around an user-defined struct.
type IInboxProveInput struct {
	Commitment          IInboxCommitment
	ForceCheckpointSync bool
}

// IInboxTransition is an auto generated low-level Go binding around an user-defined struct.
type IInboxTransition struct {
	Proposer  common.Address
	Timestamp *big.Int
	BlockHash [32]byte
}

// LibBlobsBlobReference is an auto generated low-level Go binding around an user-defined struct.
type LibBlobsBlobReference struct {
	BlobStartIndex uint16
	NumBlobs       uint16
	Offset         *big.Int
}

// LibBlobsBlobSlice is an auto generated low-level Go binding around an user-defined struct.
type LibBlobsBlobSlice struct {
	BlobHashes [][32]byte
	Offset     *big.Int
	Timestamp  *big.Int
}

// InboxMetaData contains all meta data concerning the Inbox contract.
var InboxMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"_config\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Config\",\"components\":[{\"name\":\"proofVerifier\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"proposerChecker\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"proverWhitelist\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"signalService\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"bondToken\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"minBond\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"livenessBond\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"withdrawalDelay\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"provingWindow\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"permissionlessProvingDelay\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"maxProofSubmissionDelay\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"ringBufferSize\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"minForcedInclusionCount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"forcedInclusionDelay\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"forcedInclusionFeeInGwei\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"forcedInclusionFeeDoubleThreshold\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"minCheckpointDelay\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"permissionlessInclusionMultiplier\",\"type\":\"uint8\",\"internalType\":\"uint8\"}]}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"activate\",\"inputs\":[{\"name\":\"_lastPacayaBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"activationTimestamp\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint48\",\"internalType\":\"uint48\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"cancelWithdrawal\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"decodeProposeInput\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"input_\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProposeInput\",\"components\":[{\"name\":\"deadline\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blobReference\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobReference\",\"components\":[{\"name\":\"blobStartIndex\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"numBlobs\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"}]},{\"name\":\"numForcedInclusions\",\"type\":\"uint8\",\"internalType\":\"uint8\"}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"decodeProveInput\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"input_\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProveInput\",\"components\":[{\"name\":\"commitment\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Commitment\",\"components\":[{\"name\":\"firstProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"firstProposalParentBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"lastProposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"endBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endStateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"transitions\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Transition[]\",\"components\":[{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]},{\"name\":\"forceCheckpointSync\",\"type\":\"bool\",\"internalType\":\"bool\"}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"deposit\",\"inputs\":[{\"name\":\"_amount\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"depositTo\",\"inputs\":[{\"name\":\"_recipient\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_amount\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"encodeProposeInput\",\"inputs\":[{\"name\":\"_input\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProposeInput\",\"components\":[{\"name\":\"deadline\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blobReference\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobReference\",\"components\":[{\"name\":\"blobStartIndex\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"numBlobs\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"}]},{\"name\":\"numForcedInclusions\",\"type\":\"uint8\",\"internalType\":\"uint8\"}]}],\"outputs\":[{\"name\":\"encoded_\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"encodeProveInput\",\"inputs\":[{\"name\":\"_input\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProveInput\",\"components\":[{\"name\":\"commitment\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Commitment\",\"components\":[{\"name\":\"firstProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"firstProposalParentBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"lastProposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"endBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endStateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"transitions\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Transition[]\",\"components\":[{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]},{\"name\":\"forceCheckpointSync\",\"type\":\"bool\",\"internalType\":\"bool\"}]}],\"outputs\":[{\"name\":\"encoded_\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getBond\",\"inputs\":[{\"name\":\"_address\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"bond_\",\"type\":\"tuple\",\"internalType\":\"structIBondManager.Bond\",\"components\":[{\"name\":\"balance\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"withdrawalRequestedAt\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getConfig\",\"inputs\":[],\"outputs\":[{\"name\":\"config_\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Config\",\"components\":[{\"name\":\"proofVerifier\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"proposerChecker\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"proverWhitelist\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"signalService\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"bondToken\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"minBond\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"livenessBond\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"withdrawalDelay\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"provingWindow\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"permissionlessProvingDelay\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"maxProofSubmissionDelay\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"ringBufferSize\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"minForcedInclusionCount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"forcedInclusionDelay\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"forcedInclusionFeeInGwei\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"forcedInclusionFeeDoubleThreshold\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"minCheckpointDelay\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"permissionlessInclusionMultiplier\",\"type\":\"uint8\",\"internalType\":\"uint8\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getCoreState\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structIInbox.CoreState\",\"components\":[{\"name\":\"nextProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastProposalBlockId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastCheckpointTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getCurrentForcedInclusionFee\",\"inputs\":[],\"outputs\":[{\"name\":\"feeInGwei_\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getForcedInclusionState\",\"inputs\":[],\"outputs\":[{\"name\":\"head_\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"tail_\",\"type\":\"uint48\",\"internalType\":\"uint48\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getForcedInclusions\",\"inputs\":[{\"name\":\"_start\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"_maxCount\",\"type\":\"uint48\",\"internalType\":\"uint48\"}],\"outputs\":[{\"name\":\"inclusions_\",\"type\":\"tuple[]\",\"internalType\":\"structIForcedInclusionStore.ForcedInclusion[]\",\"components\":[{\"name\":\"feeInGwei\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getProposalHash\",\"inputs\":[{\"name\":\"_proposalId\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"hashCommitment\",\"inputs\":[{\"name\":\"_commitment\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Commitment\",\"components\":[{\"name\":\"firstProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"firstProposalParentBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"lastProposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"endBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endStateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"transitions\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Transition[]\",\"components\":[{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashProposal\",\"inputs\":[{\"name\":\"_proposal\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Proposal\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"parentProposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"originBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"originBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sources\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.DerivationSource[]\",\"components\":[{\"name\":\"isForcedInclusion\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"impl\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inNonReentrant\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"propose\",\"inputs\":[{\"name\":\"_lookahead\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"prove\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"_proof\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"requestWithdrawal\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolver\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"saveForcedInclusion\",\"inputs\":[{\"name\":\"_blobReference\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobReference\",\"components\":[{\"name\":\"blobStartIndex\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"numBlobs\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"}]}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"withdraw\",\"inputs\":[{\"name\":\"_to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_amount\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondDeposited\",\"inputs\":[{\"name\":\"depositor\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"recipient\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondWithdrawn\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ForcedInclusionSaved\",\"inputs\":[{\"name\":\"forcedInclusion\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structIForcedInclusionStore.ForcedInclusion\",\"components\":[{\"name\":\"feeInGwei\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"InboxActivated\",\"inputs\":[{\"name\":\"lastPacayaBlockHash\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"LivenessBondSettled\",\"inputs\":[{\"name\":\"payer\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"payee\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"livenessBond\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"},{\"name\":\"credited\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"},{\"name\":\"slashed\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Proposed\",\"inputs\":[{\"name\":\"id\",\"type\":\"uint48\",\"indexed\":true,\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"parentProposalHash\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"indexed\":false,\"internalType\":\"uint48\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"},{\"name\":\"sources\",\"type\":\"tuple[]\",\"indexed\":false,\"internalType\":\"structIInbox.DerivationSource[]\",\"components\":[{\"name\":\"isForcedInclusion\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Proved\",\"inputs\":[{\"name\":\"firstProposalId\",\"type\":\"uint48\",\"indexed\":false,\"internalType\":\"uint48\"},{\"name\":\"firstNewProposalId\",\"type\":\"uint48\",\"indexed\":false,\"internalType\":\"uint48\"},{\"name\":\"lastProposalId\",\"type\":\"uint48\",\"indexed\":false,\"internalType\":\"uint48\"},{\"name\":\"actualProver\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"checkpointSynced\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"WithdrawalCancelled\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"WithdrawalRequested\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"withdrawableAt\",\"type\":\"uint48\",\"indexed\":false,\"internalType\":\"uint48\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCESS_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ActivationRequired\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"BlobNotFound\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CannotProposeInCurrentBlock\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CheckpointDelayHasPassed\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"DeadlineExceeded\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ETH_TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EmptyBatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FUNC_NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FirstProposalIdTooLarge\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"IncorrectProposalCount\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InsufficientBond\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidAddress\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"LastProposalAlreadyFinalized\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"LastProposalHashMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"LastProposalIdTooLarge\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"LengthExceedsUint16\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MustMaintainMinBond\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NoBlobs\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NoBondToWithdraw\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NoWithdrawalRequested\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotEnoughCapacity\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ParentBlockHashMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ProverNotWhitelisted\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UnprocessedForcedInclusionIsDue\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"WithdrawalAlreadyRequested\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_VALUE\",\"inputs\":[]}]",
}

// InboxABI is the input ABI used to generate the binding from.
// Deprecated: Use InboxMetaData.ABI instead.
var InboxABI = InboxMetaData.ABI

// Inbox is an auto generated Go binding around an Ethereum contract.
type Inbox struct {
	InboxCaller     // Read-only binding to the contract
	InboxTransactor // Write-only binding to the contract
	InboxFilterer   // Log filterer for contract events
}

// InboxCaller is an auto generated read-only Go binding around an Ethereum contract.
type InboxCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// InboxTransactor is an auto generated write-only Go binding around an Ethereum contract.
type InboxTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// InboxFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type InboxFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// InboxSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type InboxSession struct {
	Contract     *Inbox            // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// InboxCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type InboxCallerSession struct {
	Contract *InboxCaller  // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts // Call options to use throughout this session
}

// InboxTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type InboxTransactorSession struct {
	Contract     *InboxTransactor  // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// InboxRaw is an auto generated low-level Go binding around an Ethereum contract.
type InboxRaw struct {
	Contract *Inbox // Generic contract binding to access the raw methods on
}

// InboxCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type InboxCallerRaw struct {
	Contract *InboxCaller // Generic read-only contract binding to access the raw methods on
}

// InboxTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type InboxTransactorRaw struct {
	Contract *InboxTransactor // Generic write-only contract binding to access the raw methods on
}

// NewInbox creates a new instance of Inbox, bound to a specific deployed contract.
func NewInbox(address common.Address, backend bind.ContractBackend) (*Inbox, error) {
	contract, err := bindInbox(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &Inbox{InboxCaller: InboxCaller{contract: contract}, InboxTransactor: InboxTransactor{contract: contract}, InboxFilterer: InboxFilterer{contract: contract}}, nil
}

// NewInboxCaller creates a new read-only instance of Inbox, bound to a specific deployed contract.
func NewInboxCaller(address common.Address, caller bind.ContractCaller) (*InboxCaller, error) {
	contract, err := bindInbox(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &InboxCaller{contract: contract}, nil
}

// NewInboxTransactor creates a new write-only instance of Inbox, bound to a specific deployed contract.
func NewInboxTransactor(address common.Address, transactor bind.ContractTransactor) (*InboxTransactor, error) {
	contract, err := bindInbox(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &InboxTransactor{contract: contract}, nil
}

// NewInboxFilterer creates a new log filterer instance of Inbox, bound to a specific deployed contract.
func NewInboxFilterer(address common.Address, filterer bind.ContractFilterer) (*InboxFilterer, error) {
	contract, err := bindInbox(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &InboxFilterer{contract: contract}, nil
}

// bindInbox binds a generic wrapper to an already deployed contract.
func bindInbox(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := InboxMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_Inbox *InboxRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _Inbox.Contract.InboxCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_Inbox *InboxRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Inbox.Contract.InboxTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_Inbox *InboxRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _Inbox.Contract.InboxTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_Inbox *InboxCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _Inbox.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_Inbox *InboxTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Inbox.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_Inbox *InboxTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _Inbox.Contract.contract.Transact(opts, method, params...)
}

// ActivationTimestamp is a free data retrieval call binding the contract method 0x0423c7de.
//
// Solidity: function activationTimestamp() view returns(uint48)
func (_Inbox *InboxCaller) ActivationTimestamp(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _Inbox.contract.Call(opts, &out, "activationTimestamp")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// ActivationTimestamp is a free data retrieval call binding the contract method 0x0423c7de.
//
// Solidity: function activationTimestamp() view returns(uint48)
func (_Inbox *InboxSession) ActivationTimestamp() (*big.Int, error) {
	return _Inbox.Contract.ActivationTimestamp(&_Inbox.CallOpts)
}

// ActivationTimestamp is a free data retrieval call binding the contract method 0x0423c7de.
//
// Solidity: function activationTimestamp() view returns(uint48)
func (_Inbox *InboxCallerSession) ActivationTimestamp() (*big.Int, error) {
	return _Inbox.Contract.ActivationTimestamp(&_Inbox.CallOpts)
}

// DecodeProposeInput is a free data retrieval call binding the contract method 0xafb63ad4.
//
// Solidity: function decodeProposeInput(bytes _data) pure returns((uint48,(uint16,uint16,uint24),uint8) input_)
func (_Inbox *InboxCaller) DecodeProposeInput(opts *bind.CallOpts, _data []byte) (IInboxProposeInput, error) {
	var out []interface{}
	err := _Inbox.contract.Call(opts, &out, "decodeProposeInput", _data)

	if err != nil {
		return *new(IInboxProposeInput), err
	}

	out0 := *abi.ConvertType(out[0], new(IInboxProposeInput)).(*IInboxProposeInput)

	return out0, err

}

// DecodeProposeInput is a free data retrieval call binding the contract method 0xafb63ad4.
//
// Solidity: function decodeProposeInput(bytes _data) pure returns((uint48,(uint16,uint16,uint24),uint8) input_)
func (_Inbox *InboxSession) DecodeProposeInput(_data []byte) (IInboxProposeInput, error) {
	return _Inbox.Contract.DecodeProposeInput(&_Inbox.CallOpts, _data)
}

// DecodeProposeInput is a free data retrieval call binding the contract method 0xafb63ad4.
//
// Solidity: function decodeProposeInput(bytes _data) pure returns((uint48,(uint16,uint16,uint24),uint8) input_)
func (_Inbox *InboxCallerSession) DecodeProposeInput(_data []byte) (IInboxProposeInput, error) {
	return _Inbox.Contract.DecodeProposeInput(&_Inbox.CallOpts, _data)
}

// DecodeProveInput is a free data retrieval call binding the contract method 0xedbacd44.
//
// Solidity: function decodeProveInput(bytes _data) pure returns(((uint48,bytes32,bytes32,address,uint48,bytes32,(address,uint48,bytes32)[]),bool) input_)
func (_Inbox *InboxCaller) DecodeProveInput(opts *bind.CallOpts, _data []byte) (IInboxProveInput, error) {
	var out []interface{}
	err := _Inbox.contract.Call(opts, &out, "decodeProveInput", _data)

	if err != nil {
		return *new(IInboxProveInput), err
	}

	out0 := *abi.ConvertType(out[0], new(IInboxProveInput)).(*IInboxProveInput)

	return out0, err

}

// DecodeProveInput is a free data retrieval call binding the contract method 0xedbacd44.
//
// Solidity: function decodeProveInput(bytes _data) pure returns(((uint48,bytes32,bytes32,address,uint48,bytes32,(address,uint48,bytes32)[]),bool) input_)
func (_Inbox *InboxSession) DecodeProveInput(_data []byte) (IInboxProveInput, error) {
	return _Inbox.Contract.DecodeProveInput(&_Inbox.CallOpts, _data)
}

// DecodeProveInput is a free data retrieval call binding the contract method 0xedbacd44.
//
// Solidity: function decodeProveInput(bytes _data) pure returns(((uint48,bytes32,bytes32,address,uint48,bytes32,(address,uint48,bytes32)[]),bool) input_)
func (_Inbox *InboxCallerSession) DecodeProveInput(_data []byte) (IInboxProveInput, error) {
	return _Inbox.Contract.DecodeProveInput(&_Inbox.CallOpts, _data)
}

// EncodeProposeInput is a free data retrieval call binding the contract method 0x2f1969b0.
//
// Solidity: function encodeProposeInput((uint48,(uint16,uint16,uint24),uint8) _input) pure returns(bytes encoded_)
func (_Inbox *InboxCaller) EncodeProposeInput(opts *bind.CallOpts, _input IInboxProposeInput) ([]byte, error) {
	var out []interface{}
	err := _Inbox.contract.Call(opts, &out, "encodeProposeInput", _input)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProposeInput is a free data retrieval call binding the contract method 0x2f1969b0.
//
// Solidity: function encodeProposeInput((uint48,(uint16,uint16,uint24),uint8) _input) pure returns(bytes encoded_)
func (_Inbox *InboxSession) EncodeProposeInput(_input IInboxProposeInput) ([]byte, error) {
	return _Inbox.Contract.EncodeProposeInput(&_Inbox.CallOpts, _input)
}

// EncodeProposeInput is a free data retrieval call binding the contract method 0x2f1969b0.
//
// Solidity: function encodeProposeInput((uint48,(uint16,uint16,uint24),uint8) _input) pure returns(bytes encoded_)
func (_Inbox *InboxCallerSession) EncodeProposeInput(_input IInboxProposeInput) ([]byte, error) {
	return _Inbox.Contract.EncodeProposeInput(&_Inbox.CallOpts, _input)
}

// EncodeProveInput is a free data retrieval call binding the contract method 0x8301d56d.
//
// Solidity: function encodeProveInput(((uint48,bytes32,bytes32,address,uint48,bytes32,(address,uint48,bytes32)[]),bool) _input) pure returns(bytes encoded_)
func (_Inbox *InboxCaller) EncodeProveInput(opts *bind.CallOpts, _input IInboxProveInput) ([]byte, error) {
	var out []interface{}
	err := _Inbox.contract.Call(opts, &out, "encodeProveInput", _input)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProveInput is a free data retrieval call binding the contract method 0x8301d56d.
//
// Solidity: function encodeProveInput(((uint48,bytes32,bytes32,address,uint48,bytes32,(address,uint48,bytes32)[]),bool) _input) pure returns(bytes encoded_)
func (_Inbox *InboxSession) EncodeProveInput(_input IInboxProveInput) ([]byte, error) {
	return _Inbox.Contract.EncodeProveInput(&_Inbox.CallOpts, _input)
}

// EncodeProveInput is a free data retrieval call binding the contract method 0x8301d56d.
//
// Solidity: function encodeProveInput(((uint48,bytes32,bytes32,address,uint48,bytes32,(address,uint48,bytes32)[]),bool) _input) pure returns(bytes encoded_)
func (_Inbox *InboxCallerSession) EncodeProveInput(_input IInboxProveInput) ([]byte, error) {
	return _Inbox.Contract.EncodeProveInput(&_Inbox.CallOpts, _input)
}

// GetBond is a free data retrieval call binding the contract method 0x0d8912f3.
//
// Solidity: function getBond(address _address) view returns((uint64,uint48) bond_)
func (_Inbox *InboxCaller) GetBond(opts *bind.CallOpts, _address common.Address) (IBondManagerBond, error) {
	var out []interface{}
	err := _Inbox.contract.Call(opts, &out, "getBond", _address)

	if err != nil {
		return *new(IBondManagerBond), err
	}

	out0 := *abi.ConvertType(out[0], new(IBondManagerBond)).(*IBondManagerBond)

	return out0, err

}

// GetBond is a free data retrieval call binding the contract method 0x0d8912f3.
//
// Solidity: function getBond(address _address) view returns((uint64,uint48) bond_)
func (_Inbox *InboxSession) GetBond(_address common.Address) (IBondManagerBond, error) {
	return _Inbox.Contract.GetBond(&_Inbox.CallOpts, _address)
}

// GetBond is a free data retrieval call binding the contract method 0x0d8912f3.
//
// Solidity: function getBond(address _address) view returns((uint64,uint48) bond_)
func (_Inbox *InboxCallerSession) GetBond(_address common.Address) (IBondManagerBond, error) {
	return _Inbox.Contract.GetBond(&_Inbox.CallOpts, _address)
}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() view returns((address,address,address,address,address,uint64,uint64,uint48,uint48,uint48,uint48,uint48,uint8,uint256,uint16,uint64,uint64,uint16,uint8) config_)
func (_Inbox *InboxCaller) GetConfig(opts *bind.CallOpts) (IInboxConfig, error) {
	var out []interface{}
	err := _Inbox.contract.Call(opts, &out, "getConfig")

	if err != nil {
		return *new(IInboxConfig), err
	}

	out0 := *abi.ConvertType(out[0], new(IInboxConfig)).(*IInboxConfig)

	return out0, err

}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() view returns((address,address,address,address,address,uint64,uint64,uint48,uint48,uint48,uint48,uint48,uint8,uint256,uint16,uint64,uint64,uint16,uint8) config_)
func (_Inbox *InboxSession) GetConfig() (IInboxConfig, error) {
	return _Inbox.Contract.GetConfig(&_Inbox.CallOpts)
}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() view returns((address,address,address,address,address,uint64,uint64,uint48,uint48,uint48,uint48,uint48,uint8,uint256,uint16,uint64,uint64,uint16,uint8) config_)
func (_Inbox *InboxCallerSession) GetConfig() (IInboxConfig, error) {
	return _Inbox.Contract.GetConfig(&_Inbox.CallOpts)
}

// GetCoreState is a free data retrieval call binding the contract method 0x6aa6a01a.
//
// Solidity: function getCoreState() view returns((uint48,uint48,uint48,uint48,uint48,bytes32))
func (_Inbox *InboxCaller) GetCoreState(opts *bind.CallOpts) (IInboxCoreState, error) {
	var out []interface{}
	err := _Inbox.contract.Call(opts, &out, "getCoreState")

	if err != nil {
		return *new(IInboxCoreState), err
	}

	out0 := *abi.ConvertType(out[0], new(IInboxCoreState)).(*IInboxCoreState)

	return out0, err

}

// GetCoreState is a free data retrieval call binding the contract method 0x6aa6a01a.
//
// Solidity: function getCoreState() view returns((uint48,uint48,uint48,uint48,uint48,bytes32))
func (_Inbox *InboxSession) GetCoreState() (IInboxCoreState, error) {
	return _Inbox.Contract.GetCoreState(&_Inbox.CallOpts)
}

// GetCoreState is a free data retrieval call binding the contract method 0x6aa6a01a.
//
// Solidity: function getCoreState() view returns((uint48,uint48,uint48,uint48,uint48,bytes32))
func (_Inbox *InboxCallerSession) GetCoreState() (IInboxCoreState, error) {
	return _Inbox.Contract.GetCoreState(&_Inbox.CallOpts)
}

// GetCurrentForcedInclusionFee is a free data retrieval call binding the contract method 0xe3053335.
//
// Solidity: function getCurrentForcedInclusionFee() view returns(uint64 feeInGwei_)
func (_Inbox *InboxCaller) GetCurrentForcedInclusionFee(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _Inbox.contract.Call(opts, &out, "getCurrentForcedInclusionFee")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// GetCurrentForcedInclusionFee is a free data retrieval call binding the contract method 0xe3053335.
//
// Solidity: function getCurrentForcedInclusionFee() view returns(uint64 feeInGwei_)
func (_Inbox *InboxSession) GetCurrentForcedInclusionFee() (uint64, error) {
	return _Inbox.Contract.GetCurrentForcedInclusionFee(&_Inbox.CallOpts)
}

// GetCurrentForcedInclusionFee is a free data retrieval call binding the contract method 0xe3053335.
//
// Solidity: function getCurrentForcedInclusionFee() view returns(uint64 feeInGwei_)
func (_Inbox *InboxCallerSession) GetCurrentForcedInclusionFee() (uint64, error) {
	return _Inbox.Contract.GetCurrentForcedInclusionFee(&_Inbox.CallOpts)
}

// GetForcedInclusionState is a free data retrieval call binding the contract method 0x5ccc1718.
//
// Solidity: function getForcedInclusionState() view returns(uint48 head_, uint48 tail_)
func (_Inbox *InboxCaller) GetForcedInclusionState(opts *bind.CallOpts) (struct {
	Head *big.Int
	Tail *big.Int
}, error) {
	var out []interface{}
	err := _Inbox.contract.Call(opts, &out, "getForcedInclusionState")

	outstruct := new(struct {
		Head *big.Int
		Tail *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Head = *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	outstruct.Tail = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// GetForcedInclusionState is a free data retrieval call binding the contract method 0x5ccc1718.
//
// Solidity: function getForcedInclusionState() view returns(uint48 head_, uint48 tail_)
func (_Inbox *InboxSession) GetForcedInclusionState() (struct {
	Head *big.Int
	Tail *big.Int
}, error) {
	return _Inbox.Contract.GetForcedInclusionState(&_Inbox.CallOpts)
}

// GetForcedInclusionState is a free data retrieval call binding the contract method 0x5ccc1718.
//
// Solidity: function getForcedInclusionState() view returns(uint48 head_, uint48 tail_)
func (_Inbox *InboxCallerSession) GetForcedInclusionState() (struct {
	Head *big.Int
	Tail *big.Int
}, error) {
	return _Inbox.Contract.GetForcedInclusionState(&_Inbox.CallOpts)
}

// GetForcedInclusions is a free data retrieval call binding the contract method 0x40df9866.
//
// Solidity: function getForcedInclusions(uint48 _start, uint48 _maxCount) view returns((uint64,(bytes32[],uint24,uint48))[] inclusions_)
func (_Inbox *InboxCaller) GetForcedInclusions(opts *bind.CallOpts, _start *big.Int, _maxCount *big.Int) ([]IForcedInclusionStoreForcedInclusion, error) {
	var out []interface{}
	err := _Inbox.contract.Call(opts, &out, "getForcedInclusions", _start, _maxCount)

	if err != nil {
		return *new([]IForcedInclusionStoreForcedInclusion), err
	}

	out0 := *abi.ConvertType(out[0], new([]IForcedInclusionStoreForcedInclusion)).(*[]IForcedInclusionStoreForcedInclusion)

	return out0, err

}

// GetForcedInclusions is a free data retrieval call binding the contract method 0x40df9866.
//
// Solidity: function getForcedInclusions(uint48 _start, uint48 _maxCount) view returns((uint64,(bytes32[],uint24,uint48))[] inclusions_)
func (_Inbox *InboxSession) GetForcedInclusions(_start *big.Int, _maxCount *big.Int) ([]IForcedInclusionStoreForcedInclusion, error) {
	return _Inbox.Contract.GetForcedInclusions(&_Inbox.CallOpts, _start, _maxCount)
}

// GetForcedInclusions is a free data retrieval call binding the contract method 0x40df9866.
//
// Solidity: function getForcedInclusions(uint48 _start, uint48 _maxCount) view returns((uint64,(bytes32[],uint24,uint48))[] inclusions_)
func (_Inbox *InboxCallerSession) GetForcedInclusions(_start *big.Int, _maxCount *big.Int) ([]IForcedInclusionStoreForcedInclusion, error) {
	return _Inbox.Contract.GetForcedInclusions(&_Inbox.CallOpts, _start, _maxCount)
}

// GetProposalHash is a free data retrieval call binding the contract method 0xa834725a.
//
// Solidity: function getProposalHash(uint256 _proposalId) view returns(bytes32)
func (_Inbox *InboxCaller) GetProposalHash(opts *bind.CallOpts, _proposalId *big.Int) ([32]byte, error) {
	var out []interface{}
	err := _Inbox.contract.Call(opts, &out, "getProposalHash", _proposalId)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetProposalHash is a free data retrieval call binding the contract method 0xa834725a.
//
// Solidity: function getProposalHash(uint256 _proposalId) view returns(bytes32)
func (_Inbox *InboxSession) GetProposalHash(_proposalId *big.Int) ([32]byte, error) {
	return _Inbox.Contract.GetProposalHash(&_Inbox.CallOpts, _proposalId)
}

// GetProposalHash is a free data retrieval call binding the contract method 0xa834725a.
//
// Solidity: function getProposalHash(uint256 _proposalId) view returns(bytes32)
func (_Inbox *InboxCallerSession) GetProposalHash(_proposalId *big.Int) ([32]byte, error) {
	return _Inbox.Contract.GetProposalHash(&_Inbox.CallOpts, _proposalId)
}

// HashCommitment is a free data retrieval call binding the contract method 0xf954ab92.
//
// Solidity: function hashCommitment((uint48,bytes32,bytes32,address,uint48,bytes32,(address,uint48,bytes32)[]) _commitment) pure returns(bytes32)
func (_Inbox *InboxCaller) HashCommitment(opts *bind.CallOpts, _commitment IInboxCommitment) ([32]byte, error) {
	var out []interface{}
	err := _Inbox.contract.Call(opts, &out, "hashCommitment", _commitment)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashCommitment is a free data retrieval call binding the contract method 0xf954ab92.
//
// Solidity: function hashCommitment((uint48,bytes32,bytes32,address,uint48,bytes32,(address,uint48,bytes32)[]) _commitment) pure returns(bytes32)
func (_Inbox *InboxSession) HashCommitment(_commitment IInboxCommitment) ([32]byte, error) {
	return _Inbox.Contract.HashCommitment(&_Inbox.CallOpts, _commitment)
}

// HashCommitment is a free data retrieval call binding the contract method 0xf954ab92.
//
// Solidity: function hashCommitment((uint48,bytes32,bytes32,address,uint48,bytes32,(address,uint48,bytes32)[]) _commitment) pure returns(bytes32)
func (_Inbox *InboxCallerSession) HashCommitment(_commitment IInboxCommitment) ([32]byte, error) {
	return _Inbox.Contract.HashCommitment(&_Inbox.CallOpts, _commitment)
}

// HashProposal is a free data retrieval call binding the contract method 0xb28e824e.
//
// Solidity: function hashProposal((uint48,uint48,uint48,address,bytes32,uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]) _proposal) pure returns(bytes32)
func (_Inbox *InboxCaller) HashProposal(opts *bind.CallOpts, _proposal IInboxProposal) ([32]byte, error) {
	var out []interface{}
	err := _Inbox.contract.Call(opts, &out, "hashProposal", _proposal)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashProposal is a free data retrieval call binding the contract method 0xb28e824e.
//
// Solidity: function hashProposal((uint48,uint48,uint48,address,bytes32,uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]) _proposal) pure returns(bytes32)
func (_Inbox *InboxSession) HashProposal(_proposal IInboxProposal) ([32]byte, error) {
	return _Inbox.Contract.HashProposal(&_Inbox.CallOpts, _proposal)
}

// HashProposal is a free data retrieval call binding the contract method 0xb28e824e.
//
// Solidity: function hashProposal((uint48,uint48,uint48,address,bytes32,uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]) _proposal) pure returns(bytes32)
func (_Inbox *InboxCallerSession) HashProposal(_proposal IInboxProposal) ([32]byte, error) {
	return _Inbox.Contract.HashProposal(&_Inbox.CallOpts, _proposal)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_Inbox *InboxCaller) Impl(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _Inbox.contract.Call(opts, &out, "impl")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_Inbox *InboxSession) Impl() (common.Address, error) {
	return _Inbox.Contract.Impl(&_Inbox.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_Inbox *InboxCallerSession) Impl() (common.Address, error) {
	return _Inbox.Contract.Impl(&_Inbox.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_Inbox *InboxCaller) InNonReentrant(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _Inbox.contract.Call(opts, &out, "inNonReentrant")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_Inbox *InboxSession) InNonReentrant() (bool, error) {
	return _Inbox.Contract.InNonReentrant(&_Inbox.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_Inbox *InboxCallerSession) InNonReentrant() (bool, error) {
	return _Inbox.Contract.InNonReentrant(&_Inbox.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_Inbox *InboxCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _Inbox.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_Inbox *InboxSession) Owner() (common.Address, error) {
	return _Inbox.Contract.Owner(&_Inbox.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_Inbox *InboxCallerSession) Owner() (common.Address, error) {
	return _Inbox.Contract.Owner(&_Inbox.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_Inbox *InboxCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _Inbox.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_Inbox *InboxSession) Paused() (bool, error) {
	return _Inbox.Contract.Paused(&_Inbox.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_Inbox *InboxCallerSession) Paused() (bool, error) {
	return _Inbox.Contract.Paused(&_Inbox.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_Inbox *InboxCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _Inbox.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_Inbox *InboxSession) PendingOwner() (common.Address, error) {
	return _Inbox.Contract.PendingOwner(&_Inbox.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_Inbox *InboxCallerSession) PendingOwner() (common.Address, error) {
	return _Inbox.Contract.PendingOwner(&_Inbox.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_Inbox *InboxCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _Inbox.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_Inbox *InboxSession) ProxiableUUID() ([32]byte, error) {
	return _Inbox.Contract.ProxiableUUID(&_Inbox.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_Inbox *InboxCallerSession) ProxiableUUID() ([32]byte, error) {
	return _Inbox.Contract.ProxiableUUID(&_Inbox.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_Inbox *InboxCaller) Resolver(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _Inbox.contract.Call(opts, &out, "resolver")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_Inbox *InboxSession) Resolver() (common.Address, error) {
	return _Inbox.Contract.Resolver(&_Inbox.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_Inbox *InboxCallerSession) Resolver() (common.Address, error) {
	return _Inbox.Contract.Resolver(&_Inbox.CallOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_Inbox *InboxTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Inbox.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_Inbox *InboxSession) AcceptOwnership() (*types.Transaction, error) {
	return _Inbox.Contract.AcceptOwnership(&_Inbox.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_Inbox *InboxTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _Inbox.Contract.AcceptOwnership(&_Inbox.TransactOpts)
}

// Activate is a paid mutator transaction binding the contract method 0x59db6e85.
//
// Solidity: function activate(bytes32 _lastPacayaBlockHash) returns()
func (_Inbox *InboxTransactor) Activate(opts *bind.TransactOpts, _lastPacayaBlockHash [32]byte) (*types.Transaction, error) {
	return _Inbox.contract.Transact(opts, "activate", _lastPacayaBlockHash)
}

// Activate is a paid mutator transaction binding the contract method 0x59db6e85.
//
// Solidity: function activate(bytes32 _lastPacayaBlockHash) returns()
func (_Inbox *InboxSession) Activate(_lastPacayaBlockHash [32]byte) (*types.Transaction, error) {
	return _Inbox.Contract.Activate(&_Inbox.TransactOpts, _lastPacayaBlockHash)
}

// Activate is a paid mutator transaction binding the contract method 0x59db6e85.
//
// Solidity: function activate(bytes32 _lastPacayaBlockHash) returns()
func (_Inbox *InboxTransactorSession) Activate(_lastPacayaBlockHash [32]byte) (*types.Transaction, error) {
	return _Inbox.Contract.Activate(&_Inbox.TransactOpts, _lastPacayaBlockHash)
}

// CancelWithdrawal is a paid mutator transaction binding the contract method 0x22611280.
//
// Solidity: function cancelWithdrawal() returns()
func (_Inbox *InboxTransactor) CancelWithdrawal(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Inbox.contract.Transact(opts, "cancelWithdrawal")
}

// CancelWithdrawal is a paid mutator transaction binding the contract method 0x22611280.
//
// Solidity: function cancelWithdrawal() returns()
func (_Inbox *InboxSession) CancelWithdrawal() (*types.Transaction, error) {
	return _Inbox.Contract.CancelWithdrawal(&_Inbox.TransactOpts)
}

// CancelWithdrawal is a paid mutator transaction binding the contract method 0x22611280.
//
// Solidity: function cancelWithdrawal() returns()
func (_Inbox *InboxTransactorSession) CancelWithdrawal() (*types.Transaction, error) {
	return _Inbox.Contract.CancelWithdrawal(&_Inbox.TransactOpts)
}

// Deposit is a paid mutator transaction binding the contract method 0x13765838.
//
// Solidity: function deposit(uint64 _amount) returns()
func (_Inbox *InboxTransactor) Deposit(opts *bind.TransactOpts, _amount uint64) (*types.Transaction, error) {
	return _Inbox.contract.Transact(opts, "deposit", _amount)
}

// Deposit is a paid mutator transaction binding the contract method 0x13765838.
//
// Solidity: function deposit(uint64 _amount) returns()
func (_Inbox *InboxSession) Deposit(_amount uint64) (*types.Transaction, error) {
	return _Inbox.Contract.Deposit(&_Inbox.TransactOpts, _amount)
}

// Deposit is a paid mutator transaction binding the contract method 0x13765838.
//
// Solidity: function deposit(uint64 _amount) returns()
func (_Inbox *InboxTransactorSession) Deposit(_amount uint64) (*types.Transaction, error) {
	return _Inbox.Contract.Deposit(&_Inbox.TransactOpts, _amount)
}

// DepositTo is a paid mutator transaction binding the contract method 0xefba83c9.
//
// Solidity: function depositTo(address _recipient, uint64 _amount) returns()
func (_Inbox *InboxTransactor) DepositTo(opts *bind.TransactOpts, _recipient common.Address, _amount uint64) (*types.Transaction, error) {
	return _Inbox.contract.Transact(opts, "depositTo", _recipient, _amount)
}

// DepositTo is a paid mutator transaction binding the contract method 0xefba83c9.
//
// Solidity: function depositTo(address _recipient, uint64 _amount) returns()
func (_Inbox *InboxSession) DepositTo(_recipient common.Address, _amount uint64) (*types.Transaction, error) {
	return _Inbox.Contract.DepositTo(&_Inbox.TransactOpts, _recipient, _amount)
}

// DepositTo is a paid mutator transaction binding the contract method 0xefba83c9.
//
// Solidity: function depositTo(address _recipient, uint64 _amount) returns()
func (_Inbox *InboxTransactorSession) DepositTo(_recipient common.Address, _amount uint64) (*types.Transaction, error) {
	return _Inbox.Contract.DepositTo(&_Inbox.TransactOpts, _recipient, _amount)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_Inbox *InboxTransactor) Init(opts *bind.TransactOpts, _owner common.Address) (*types.Transaction, error) {
	return _Inbox.contract.Transact(opts, "init", _owner)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_Inbox *InboxSession) Init(_owner common.Address) (*types.Transaction, error) {
	return _Inbox.Contract.Init(&_Inbox.TransactOpts, _owner)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_Inbox *InboxTransactorSession) Init(_owner common.Address) (*types.Transaction, error) {
	return _Inbox.Contract.Init(&_Inbox.TransactOpts, _owner)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_Inbox *InboxTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Inbox.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_Inbox *InboxSession) Pause() (*types.Transaction, error) {
	return _Inbox.Contract.Pause(&_Inbox.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_Inbox *InboxTransactorSession) Pause() (*types.Transaction, error) {
	return _Inbox.Contract.Pause(&_Inbox.TransactOpts)
}

// Propose is a paid mutator transaction binding the contract method 0x9791e644.
//
// Solidity: function propose(bytes _lookahead, bytes _data) returns()
func (_Inbox *InboxTransactor) Propose(opts *bind.TransactOpts, _lookahead []byte, _data []byte) (*types.Transaction, error) {
	return _Inbox.contract.Transact(opts, "propose", _lookahead, _data)
}

// Propose is a paid mutator transaction binding the contract method 0x9791e644.
//
// Solidity: function propose(bytes _lookahead, bytes _data) returns()
func (_Inbox *InboxSession) Propose(_lookahead []byte, _data []byte) (*types.Transaction, error) {
	return _Inbox.Contract.Propose(&_Inbox.TransactOpts, _lookahead, _data)
}

// Propose is a paid mutator transaction binding the contract method 0x9791e644.
//
// Solidity: function propose(bytes _lookahead, bytes _data) returns()
func (_Inbox *InboxTransactorSession) Propose(_lookahead []byte, _data []byte) (*types.Transaction, error) {
	return _Inbox.Contract.Propose(&_Inbox.TransactOpts, _lookahead, _data)
}

// Prove is a paid mutator transaction binding the contract method 0xea191743.
//
// Solidity: function prove(bytes _data, bytes _proof) returns()
func (_Inbox *InboxTransactor) Prove(opts *bind.TransactOpts, _data []byte, _proof []byte) (*types.Transaction, error) {
	return _Inbox.contract.Transact(opts, "prove", _data, _proof)
}

// Prove is a paid mutator transaction binding the contract method 0xea191743.
//
// Solidity: function prove(bytes _data, bytes _proof) returns()
func (_Inbox *InboxSession) Prove(_data []byte, _proof []byte) (*types.Transaction, error) {
	return _Inbox.Contract.Prove(&_Inbox.TransactOpts, _data, _proof)
}

// Prove is a paid mutator transaction binding the contract method 0xea191743.
//
// Solidity: function prove(bytes _data, bytes _proof) returns()
func (_Inbox *InboxTransactorSession) Prove(_data []byte, _proof []byte) (*types.Transaction, error) {
	return _Inbox.Contract.Prove(&_Inbox.TransactOpts, _data, _proof)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_Inbox *InboxTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Inbox.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_Inbox *InboxSession) RenounceOwnership() (*types.Transaction, error) {
	return _Inbox.Contract.RenounceOwnership(&_Inbox.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_Inbox *InboxTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _Inbox.Contract.RenounceOwnership(&_Inbox.TransactOpts)
}

// RequestWithdrawal is a paid mutator transaction binding the contract method 0xdbaf2145.
//
// Solidity: function requestWithdrawal() returns()
func (_Inbox *InboxTransactor) RequestWithdrawal(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Inbox.contract.Transact(opts, "requestWithdrawal")
}

// RequestWithdrawal is a paid mutator transaction binding the contract method 0xdbaf2145.
//
// Solidity: function requestWithdrawal() returns()
func (_Inbox *InboxSession) RequestWithdrawal() (*types.Transaction, error) {
	return _Inbox.Contract.RequestWithdrawal(&_Inbox.TransactOpts)
}

// RequestWithdrawal is a paid mutator transaction binding the contract method 0xdbaf2145.
//
// Solidity: function requestWithdrawal() returns()
func (_Inbox *InboxTransactorSession) RequestWithdrawal() (*types.Transaction, error) {
	return _Inbox.Contract.RequestWithdrawal(&_Inbox.TransactOpts)
}

// SaveForcedInclusion is a paid mutator transaction binding the contract method 0xdf596d9e.
//
// Solidity: function saveForcedInclusion((uint16,uint16,uint24) _blobReference) payable returns()
func (_Inbox *InboxTransactor) SaveForcedInclusion(opts *bind.TransactOpts, _blobReference LibBlobsBlobReference) (*types.Transaction, error) {
	return _Inbox.contract.Transact(opts, "saveForcedInclusion", _blobReference)
}

// SaveForcedInclusion is a paid mutator transaction binding the contract method 0xdf596d9e.
//
// Solidity: function saveForcedInclusion((uint16,uint16,uint24) _blobReference) payable returns()
func (_Inbox *InboxSession) SaveForcedInclusion(_blobReference LibBlobsBlobReference) (*types.Transaction, error) {
	return _Inbox.Contract.SaveForcedInclusion(&_Inbox.TransactOpts, _blobReference)
}

// SaveForcedInclusion is a paid mutator transaction binding the contract method 0xdf596d9e.
//
// Solidity: function saveForcedInclusion((uint16,uint16,uint24) _blobReference) payable returns()
func (_Inbox *InboxTransactorSession) SaveForcedInclusion(_blobReference LibBlobsBlobReference) (*types.Transaction, error) {
	return _Inbox.Contract.SaveForcedInclusion(&_Inbox.TransactOpts, _blobReference)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_Inbox *InboxTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _Inbox.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_Inbox *InboxSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _Inbox.Contract.TransferOwnership(&_Inbox.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_Inbox *InboxTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _Inbox.Contract.TransferOwnership(&_Inbox.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_Inbox *InboxTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Inbox.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_Inbox *InboxSession) Unpause() (*types.Transaction, error) {
	return _Inbox.Contract.Unpause(&_Inbox.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_Inbox *InboxTransactorSession) Unpause() (*types.Transaction, error) {
	return _Inbox.Contract.Unpause(&_Inbox.TransactOpts)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_Inbox *InboxTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _Inbox.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_Inbox *InboxSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _Inbox.Contract.UpgradeTo(&_Inbox.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_Inbox *InboxTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _Inbox.Contract.UpgradeTo(&_Inbox.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_Inbox *InboxTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _Inbox.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_Inbox *InboxSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _Inbox.Contract.UpgradeToAndCall(&_Inbox.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_Inbox *InboxTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _Inbox.Contract.UpgradeToAndCall(&_Inbox.TransactOpts, newImplementation, data)
}

// Withdraw is a paid mutator transaction binding the contract method 0xd6dad060.
//
// Solidity: function withdraw(address _to, uint64 _amount) returns()
func (_Inbox *InboxTransactor) Withdraw(opts *bind.TransactOpts, _to common.Address, _amount uint64) (*types.Transaction, error) {
	return _Inbox.contract.Transact(opts, "withdraw", _to, _amount)
}

// Withdraw is a paid mutator transaction binding the contract method 0xd6dad060.
//
// Solidity: function withdraw(address _to, uint64 _amount) returns()
func (_Inbox *InboxSession) Withdraw(_to common.Address, _amount uint64) (*types.Transaction, error) {
	return _Inbox.Contract.Withdraw(&_Inbox.TransactOpts, _to, _amount)
}

// Withdraw is a paid mutator transaction binding the contract method 0xd6dad060.
//
// Solidity: function withdraw(address _to, uint64 _amount) returns()
func (_Inbox *InboxTransactorSession) Withdraw(_to common.Address, _amount uint64) (*types.Transaction, error) {
	return _Inbox.Contract.Withdraw(&_Inbox.TransactOpts, _to, _amount)
}

// InboxAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the Inbox contract.
type InboxAdminChangedIterator struct {
	Event *InboxAdminChanged // Event containing the contract specifics and raw log

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
func (it *InboxAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(InboxAdminChanged)
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
		it.Event = new(InboxAdminChanged)
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
func (it *InboxAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *InboxAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// InboxAdminChanged represents a AdminChanged event raised by the Inbox contract.
type InboxAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_Inbox *InboxFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*InboxAdminChangedIterator, error) {

	logs, sub, err := _Inbox.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &InboxAdminChangedIterator{contract: _Inbox.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_Inbox *InboxFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *InboxAdminChanged) (event.Subscription, error) {

	logs, sub, err := _Inbox.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(InboxAdminChanged)
				if err := _Inbox.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_Inbox *InboxFilterer) ParseAdminChanged(log types.Log) (*InboxAdminChanged, error) {
	event := new(InboxAdminChanged)
	if err := _Inbox.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// InboxBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the Inbox contract.
type InboxBeaconUpgradedIterator struct {
	Event *InboxBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *InboxBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(InboxBeaconUpgraded)
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
		it.Event = new(InboxBeaconUpgraded)
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
func (it *InboxBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *InboxBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// InboxBeaconUpgraded represents a BeaconUpgraded event raised by the Inbox contract.
type InboxBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_Inbox *InboxFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*InboxBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _Inbox.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &InboxBeaconUpgradedIterator{contract: _Inbox.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_Inbox *InboxFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *InboxBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _Inbox.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(InboxBeaconUpgraded)
				if err := _Inbox.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_Inbox *InboxFilterer) ParseBeaconUpgraded(log types.Log) (*InboxBeaconUpgraded, error) {
	event := new(InboxBeaconUpgraded)
	if err := _Inbox.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// InboxBondDepositedIterator is returned from FilterBondDeposited and is used to iterate over the raw logs and unpacked data for BondDeposited events raised by the Inbox contract.
type InboxBondDepositedIterator struct {
	Event *InboxBondDeposited // Event containing the contract specifics and raw log

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
func (it *InboxBondDepositedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(InboxBondDeposited)
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
		it.Event = new(InboxBondDeposited)
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
func (it *InboxBondDepositedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *InboxBondDepositedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// InboxBondDeposited represents a BondDeposited event raised by the Inbox contract.
type InboxBondDeposited struct {
	Depositor common.Address
	Recipient common.Address
	Amount    uint64
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterBondDeposited is a free log retrieval operation binding the contract event 0xe5e95641fa87bdfef3ce0d39f0c9a37c200f3bf59f53623b3de21e03ed33e3d2.
//
// Solidity: event BondDeposited(address indexed depositor, address indexed recipient, uint64 amount)
func (_Inbox *InboxFilterer) FilterBondDeposited(opts *bind.FilterOpts, depositor []common.Address, recipient []common.Address) (*InboxBondDepositedIterator, error) {

	var depositorRule []interface{}
	for _, depositorItem := range depositor {
		depositorRule = append(depositorRule, depositorItem)
	}
	var recipientRule []interface{}
	for _, recipientItem := range recipient {
		recipientRule = append(recipientRule, recipientItem)
	}

	logs, sub, err := _Inbox.contract.FilterLogs(opts, "BondDeposited", depositorRule, recipientRule)
	if err != nil {
		return nil, err
	}
	return &InboxBondDepositedIterator{contract: _Inbox.contract, event: "BondDeposited", logs: logs, sub: sub}, nil
}

// WatchBondDeposited is a free log subscription operation binding the contract event 0xe5e95641fa87bdfef3ce0d39f0c9a37c200f3bf59f53623b3de21e03ed33e3d2.
//
// Solidity: event BondDeposited(address indexed depositor, address indexed recipient, uint64 amount)
func (_Inbox *InboxFilterer) WatchBondDeposited(opts *bind.WatchOpts, sink chan<- *InboxBondDeposited, depositor []common.Address, recipient []common.Address) (event.Subscription, error) {

	var depositorRule []interface{}
	for _, depositorItem := range depositor {
		depositorRule = append(depositorRule, depositorItem)
	}
	var recipientRule []interface{}
	for _, recipientItem := range recipient {
		recipientRule = append(recipientRule, recipientItem)
	}

	logs, sub, err := _Inbox.contract.WatchLogs(opts, "BondDeposited", depositorRule, recipientRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(InboxBondDeposited)
				if err := _Inbox.contract.UnpackLog(event, "BondDeposited", log); err != nil {
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

// ParseBondDeposited is a log parse operation binding the contract event 0xe5e95641fa87bdfef3ce0d39f0c9a37c200f3bf59f53623b3de21e03ed33e3d2.
//
// Solidity: event BondDeposited(address indexed depositor, address indexed recipient, uint64 amount)
func (_Inbox *InboxFilterer) ParseBondDeposited(log types.Log) (*InboxBondDeposited, error) {
	event := new(InboxBondDeposited)
	if err := _Inbox.contract.UnpackLog(event, "BondDeposited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// InboxBondWithdrawnIterator is returned from FilterBondWithdrawn and is used to iterate over the raw logs and unpacked data for BondWithdrawn events raised by the Inbox contract.
type InboxBondWithdrawnIterator struct {
	Event *InboxBondWithdrawn // Event containing the contract specifics and raw log

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
func (it *InboxBondWithdrawnIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(InboxBondWithdrawn)
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
		it.Event = new(InboxBondWithdrawn)
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
func (it *InboxBondWithdrawnIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *InboxBondWithdrawnIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// InboxBondWithdrawn represents a BondWithdrawn event raised by the Inbox contract.
type InboxBondWithdrawn struct {
	Account common.Address
	Amount  uint64
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterBondWithdrawn is a free log retrieval operation binding the contract event 0x3362c96009316515fccd3dd29c7036c305ad9e892d83dd5681845ac9edb0c9a8.
//
// Solidity: event BondWithdrawn(address indexed account, uint64 amount)
func (_Inbox *InboxFilterer) FilterBondWithdrawn(opts *bind.FilterOpts, account []common.Address) (*InboxBondWithdrawnIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _Inbox.contract.FilterLogs(opts, "BondWithdrawn", accountRule)
	if err != nil {
		return nil, err
	}
	return &InboxBondWithdrawnIterator{contract: _Inbox.contract, event: "BondWithdrawn", logs: logs, sub: sub}, nil
}

// WatchBondWithdrawn is a free log subscription operation binding the contract event 0x3362c96009316515fccd3dd29c7036c305ad9e892d83dd5681845ac9edb0c9a8.
//
// Solidity: event BondWithdrawn(address indexed account, uint64 amount)
func (_Inbox *InboxFilterer) WatchBondWithdrawn(opts *bind.WatchOpts, sink chan<- *InboxBondWithdrawn, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _Inbox.contract.WatchLogs(opts, "BondWithdrawn", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(InboxBondWithdrawn)
				if err := _Inbox.contract.UnpackLog(event, "BondWithdrawn", log); err != nil {
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

// ParseBondWithdrawn is a log parse operation binding the contract event 0x3362c96009316515fccd3dd29c7036c305ad9e892d83dd5681845ac9edb0c9a8.
//
// Solidity: event BondWithdrawn(address indexed account, uint64 amount)
func (_Inbox *InboxFilterer) ParseBondWithdrawn(log types.Log) (*InboxBondWithdrawn, error) {
	event := new(InboxBondWithdrawn)
	if err := _Inbox.contract.UnpackLog(event, "BondWithdrawn", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// InboxForcedInclusionSavedIterator is returned from FilterForcedInclusionSaved and is used to iterate over the raw logs and unpacked data for ForcedInclusionSaved events raised by the Inbox contract.
type InboxForcedInclusionSavedIterator struct {
	Event *InboxForcedInclusionSaved // Event containing the contract specifics and raw log

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
func (it *InboxForcedInclusionSavedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(InboxForcedInclusionSaved)
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
		it.Event = new(InboxForcedInclusionSaved)
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
func (it *InboxForcedInclusionSavedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *InboxForcedInclusionSavedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// InboxForcedInclusionSaved represents a ForcedInclusionSaved event raised by the Inbox contract.
type InboxForcedInclusionSaved struct {
	ForcedInclusion IForcedInclusionStoreForcedInclusion
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterForcedInclusionSaved is a free log retrieval operation binding the contract event 0x18c4fc1e6ac628dbb537b0375bf0efabf1ff2528af1ec22faa74d2da95c29471.
//
// Solidity: event ForcedInclusionSaved((uint64,(bytes32[],uint24,uint48)) forcedInclusion)
func (_Inbox *InboxFilterer) FilterForcedInclusionSaved(opts *bind.FilterOpts) (*InboxForcedInclusionSavedIterator, error) {

	logs, sub, err := _Inbox.contract.FilterLogs(opts, "ForcedInclusionSaved")
	if err != nil {
		return nil, err
	}
	return &InboxForcedInclusionSavedIterator{contract: _Inbox.contract, event: "ForcedInclusionSaved", logs: logs, sub: sub}, nil
}

// WatchForcedInclusionSaved is a free log subscription operation binding the contract event 0x18c4fc1e6ac628dbb537b0375bf0efabf1ff2528af1ec22faa74d2da95c29471.
//
// Solidity: event ForcedInclusionSaved((uint64,(bytes32[],uint24,uint48)) forcedInclusion)
func (_Inbox *InboxFilterer) WatchForcedInclusionSaved(opts *bind.WatchOpts, sink chan<- *InboxForcedInclusionSaved) (event.Subscription, error) {

	logs, sub, err := _Inbox.contract.WatchLogs(opts, "ForcedInclusionSaved")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(InboxForcedInclusionSaved)
				if err := _Inbox.contract.UnpackLog(event, "ForcedInclusionSaved", log); err != nil {
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

// ParseForcedInclusionSaved is a log parse operation binding the contract event 0x18c4fc1e6ac628dbb537b0375bf0efabf1ff2528af1ec22faa74d2da95c29471.
//
// Solidity: event ForcedInclusionSaved((uint64,(bytes32[],uint24,uint48)) forcedInclusion)
func (_Inbox *InboxFilterer) ParseForcedInclusionSaved(log types.Log) (*InboxForcedInclusionSaved, error) {
	event := new(InboxForcedInclusionSaved)
	if err := _Inbox.contract.UnpackLog(event, "ForcedInclusionSaved", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// InboxInboxActivatedIterator is returned from FilterInboxActivated and is used to iterate over the raw logs and unpacked data for InboxActivated events raised by the Inbox contract.
type InboxInboxActivatedIterator struct {
	Event *InboxInboxActivated // Event containing the contract specifics and raw log

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
func (it *InboxInboxActivatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(InboxInboxActivated)
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
		it.Event = new(InboxInboxActivated)
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
func (it *InboxInboxActivatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *InboxInboxActivatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// InboxInboxActivated represents a InboxActivated event raised by the Inbox contract.
type InboxInboxActivated struct {
	LastPacayaBlockHash [32]byte
	Raw                 types.Log // Blockchain specific contextual infos
}

// FilterInboxActivated is a free log retrieval operation binding the contract event 0xe4356761c97932c05c3ee0859fb1a5e4f91f7a1d7a3752c7d5a72d5cc6ecb2d2.
//
// Solidity: event InboxActivated(bytes32 lastPacayaBlockHash)
func (_Inbox *InboxFilterer) FilterInboxActivated(opts *bind.FilterOpts) (*InboxInboxActivatedIterator, error) {

	logs, sub, err := _Inbox.contract.FilterLogs(opts, "InboxActivated")
	if err != nil {
		return nil, err
	}
	return &InboxInboxActivatedIterator{contract: _Inbox.contract, event: "InboxActivated", logs: logs, sub: sub}, nil
}

// WatchInboxActivated is a free log subscription operation binding the contract event 0xe4356761c97932c05c3ee0859fb1a5e4f91f7a1d7a3752c7d5a72d5cc6ecb2d2.
//
// Solidity: event InboxActivated(bytes32 lastPacayaBlockHash)
func (_Inbox *InboxFilterer) WatchInboxActivated(opts *bind.WatchOpts, sink chan<- *InboxInboxActivated) (event.Subscription, error) {

	logs, sub, err := _Inbox.contract.WatchLogs(opts, "InboxActivated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(InboxInboxActivated)
				if err := _Inbox.contract.UnpackLog(event, "InboxActivated", log); err != nil {
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

// ParseInboxActivated is a log parse operation binding the contract event 0xe4356761c97932c05c3ee0859fb1a5e4f91f7a1d7a3752c7d5a72d5cc6ecb2d2.
//
// Solidity: event InboxActivated(bytes32 lastPacayaBlockHash)
func (_Inbox *InboxFilterer) ParseInboxActivated(log types.Log) (*InboxInboxActivated, error) {
	event := new(InboxInboxActivated)
	if err := _Inbox.contract.UnpackLog(event, "InboxActivated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// InboxInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the Inbox contract.
type InboxInitializedIterator struct {
	Event *InboxInitialized // Event containing the contract specifics and raw log

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
func (it *InboxInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(InboxInitialized)
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
		it.Event = new(InboxInitialized)
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
func (it *InboxInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *InboxInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// InboxInitialized represents a Initialized event raised by the Inbox contract.
type InboxInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_Inbox *InboxFilterer) FilterInitialized(opts *bind.FilterOpts) (*InboxInitializedIterator, error) {

	logs, sub, err := _Inbox.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &InboxInitializedIterator{contract: _Inbox.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_Inbox *InboxFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *InboxInitialized) (event.Subscription, error) {

	logs, sub, err := _Inbox.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(InboxInitialized)
				if err := _Inbox.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_Inbox *InboxFilterer) ParseInitialized(log types.Log) (*InboxInitialized, error) {
	event := new(InboxInitialized)
	if err := _Inbox.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// InboxLivenessBondSettledIterator is returned from FilterLivenessBondSettled and is used to iterate over the raw logs and unpacked data for LivenessBondSettled events raised by the Inbox contract.
type InboxLivenessBondSettledIterator struct {
	Event *InboxLivenessBondSettled // Event containing the contract specifics and raw log

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
func (it *InboxLivenessBondSettledIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(InboxLivenessBondSettled)
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
		it.Event = new(InboxLivenessBondSettled)
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
func (it *InboxLivenessBondSettledIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *InboxLivenessBondSettledIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// InboxLivenessBondSettled represents a LivenessBondSettled event raised by the Inbox contract.
type InboxLivenessBondSettled struct {
	Payer        common.Address
	Payee        common.Address
	LivenessBond uint64
	Credited     uint64
	Slashed      uint64
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterLivenessBondSettled is a free log retrieval operation binding the contract event 0xaa22f5157944b5fa6846460e159d57ea9c3878e71fda274af372fa2ccf285aa0.
//
// Solidity: event LivenessBondSettled(address indexed payer, address indexed payee, uint64 livenessBond, uint64 credited, uint64 slashed)
func (_Inbox *InboxFilterer) FilterLivenessBondSettled(opts *bind.FilterOpts, payer []common.Address, payee []common.Address) (*InboxLivenessBondSettledIterator, error) {

	var payerRule []interface{}
	for _, payerItem := range payer {
		payerRule = append(payerRule, payerItem)
	}
	var payeeRule []interface{}
	for _, payeeItem := range payee {
		payeeRule = append(payeeRule, payeeItem)
	}

	logs, sub, err := _Inbox.contract.FilterLogs(opts, "LivenessBondSettled", payerRule, payeeRule)
	if err != nil {
		return nil, err
	}
	return &InboxLivenessBondSettledIterator{contract: _Inbox.contract, event: "LivenessBondSettled", logs: logs, sub: sub}, nil
}

// WatchLivenessBondSettled is a free log subscription operation binding the contract event 0xaa22f5157944b5fa6846460e159d57ea9c3878e71fda274af372fa2ccf285aa0.
//
// Solidity: event LivenessBondSettled(address indexed payer, address indexed payee, uint64 livenessBond, uint64 credited, uint64 slashed)
func (_Inbox *InboxFilterer) WatchLivenessBondSettled(opts *bind.WatchOpts, sink chan<- *InboxLivenessBondSettled, payer []common.Address, payee []common.Address) (event.Subscription, error) {

	var payerRule []interface{}
	for _, payerItem := range payer {
		payerRule = append(payerRule, payerItem)
	}
	var payeeRule []interface{}
	for _, payeeItem := range payee {
		payeeRule = append(payeeRule, payeeItem)
	}

	logs, sub, err := _Inbox.contract.WatchLogs(opts, "LivenessBondSettled", payerRule, payeeRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(InboxLivenessBondSettled)
				if err := _Inbox.contract.UnpackLog(event, "LivenessBondSettled", log); err != nil {
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

// ParseLivenessBondSettled is a log parse operation binding the contract event 0xaa22f5157944b5fa6846460e159d57ea9c3878e71fda274af372fa2ccf285aa0.
//
// Solidity: event LivenessBondSettled(address indexed payer, address indexed payee, uint64 livenessBond, uint64 credited, uint64 slashed)
func (_Inbox *InboxFilterer) ParseLivenessBondSettled(log types.Log) (*InboxLivenessBondSettled, error) {
	event := new(InboxLivenessBondSettled)
	if err := _Inbox.contract.UnpackLog(event, "LivenessBondSettled", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// InboxOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the Inbox contract.
type InboxOwnershipTransferStartedIterator struct {
	Event *InboxOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *InboxOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(InboxOwnershipTransferStarted)
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
		it.Event = new(InboxOwnershipTransferStarted)
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
func (it *InboxOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *InboxOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// InboxOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the Inbox contract.
type InboxOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_Inbox *InboxFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*InboxOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _Inbox.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &InboxOwnershipTransferStartedIterator{contract: _Inbox.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_Inbox *InboxFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *InboxOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _Inbox.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(InboxOwnershipTransferStarted)
				if err := _Inbox.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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
func (_Inbox *InboxFilterer) ParseOwnershipTransferStarted(log types.Log) (*InboxOwnershipTransferStarted, error) {
	event := new(InboxOwnershipTransferStarted)
	if err := _Inbox.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// InboxOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the Inbox contract.
type InboxOwnershipTransferredIterator struct {
	Event *InboxOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *InboxOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(InboxOwnershipTransferred)
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
		it.Event = new(InboxOwnershipTransferred)
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
func (it *InboxOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *InboxOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// InboxOwnershipTransferred represents a OwnershipTransferred event raised by the Inbox contract.
type InboxOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_Inbox *InboxFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*InboxOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _Inbox.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &InboxOwnershipTransferredIterator{contract: _Inbox.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_Inbox *InboxFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *InboxOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _Inbox.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(InboxOwnershipTransferred)
				if err := _Inbox.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_Inbox *InboxFilterer) ParseOwnershipTransferred(log types.Log) (*InboxOwnershipTransferred, error) {
	event := new(InboxOwnershipTransferred)
	if err := _Inbox.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// InboxPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the Inbox contract.
type InboxPausedIterator struct {
	Event *InboxPaused // Event containing the contract specifics and raw log

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
func (it *InboxPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(InboxPaused)
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
		it.Event = new(InboxPaused)
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
func (it *InboxPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *InboxPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// InboxPaused represents a Paused event raised by the Inbox contract.
type InboxPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_Inbox *InboxFilterer) FilterPaused(opts *bind.FilterOpts) (*InboxPausedIterator, error) {

	logs, sub, err := _Inbox.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &InboxPausedIterator{contract: _Inbox.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_Inbox *InboxFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *InboxPaused) (event.Subscription, error) {

	logs, sub, err := _Inbox.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(InboxPaused)
				if err := _Inbox.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_Inbox *InboxFilterer) ParsePaused(log types.Log) (*InboxPaused, error) {
	event := new(InboxPaused)
	if err := _Inbox.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// InboxProposedIterator is returned from FilterProposed and is used to iterate over the raw logs and unpacked data for Proposed events raised by the Inbox contract.
type InboxProposedIterator struct {
	Event *InboxProposed // Event containing the contract specifics and raw log

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
func (it *InboxProposedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(InboxProposed)
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
		it.Event = new(InboxProposed)
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
func (it *InboxProposedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *InboxProposedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// InboxProposed represents a Proposed event raised by the Inbox contract.
type InboxProposed struct {
	Id                             *big.Int
	Proposer                       common.Address
	ParentProposalHash             [32]byte
	EndOfSubmissionWindowTimestamp *big.Int
	BasefeeSharingPctg             uint8
	Sources                        []IInboxDerivationSource
	Raw                            types.Log // Blockchain specific contextual infos
}

// FilterProposed is a free log retrieval operation binding the contract event 0x7c4c4523e17533e451df15762a093e0693a2cd8b279fe54c6cd3777ed5771213.
//
// Solidity: event Proposed(uint48 indexed id, address indexed proposer, bytes32 parentProposalHash, uint48 endOfSubmissionWindowTimestamp, uint8 basefeeSharingPctg, (bool,(bytes32[],uint24,uint48))[] sources)
func (_Inbox *InboxFilterer) FilterProposed(opts *bind.FilterOpts, id []*big.Int, proposer []common.Address) (*InboxProposedIterator, error) {

	var idRule []interface{}
	for _, idItem := range id {
		idRule = append(idRule, idItem)
	}
	var proposerRule []interface{}
	for _, proposerItem := range proposer {
		proposerRule = append(proposerRule, proposerItem)
	}

	logs, sub, err := _Inbox.contract.FilterLogs(opts, "Proposed", idRule, proposerRule)
	if err != nil {
		return nil, err
	}
	return &InboxProposedIterator{contract: _Inbox.contract, event: "Proposed", logs: logs, sub: sub}, nil
}

// WatchProposed is a free log subscription operation binding the contract event 0x7c4c4523e17533e451df15762a093e0693a2cd8b279fe54c6cd3777ed5771213.
//
// Solidity: event Proposed(uint48 indexed id, address indexed proposer, bytes32 parentProposalHash, uint48 endOfSubmissionWindowTimestamp, uint8 basefeeSharingPctg, (bool,(bytes32[],uint24,uint48))[] sources)
func (_Inbox *InboxFilterer) WatchProposed(opts *bind.WatchOpts, sink chan<- *InboxProposed, id []*big.Int, proposer []common.Address) (event.Subscription, error) {

	var idRule []interface{}
	for _, idItem := range id {
		idRule = append(idRule, idItem)
	}
	var proposerRule []interface{}
	for _, proposerItem := range proposer {
		proposerRule = append(proposerRule, proposerItem)
	}

	logs, sub, err := _Inbox.contract.WatchLogs(opts, "Proposed", idRule, proposerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(InboxProposed)
				if err := _Inbox.contract.UnpackLog(event, "Proposed", log); err != nil {
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

// ParseProposed is a log parse operation binding the contract event 0x7c4c4523e17533e451df15762a093e0693a2cd8b279fe54c6cd3777ed5771213.
//
// Solidity: event Proposed(uint48 indexed id, address indexed proposer, bytes32 parentProposalHash, uint48 endOfSubmissionWindowTimestamp, uint8 basefeeSharingPctg, (bool,(bytes32[],uint24,uint48))[] sources)
func (_Inbox *InboxFilterer) ParseProposed(log types.Log) (*InboxProposed, error) {
	event := new(InboxProposed)
	if err := _Inbox.contract.UnpackLog(event, "Proposed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// InboxProvedIterator is returned from FilterProved and is used to iterate over the raw logs and unpacked data for Proved events raised by the Inbox contract.
type InboxProvedIterator struct {
	Event *InboxProved // Event containing the contract specifics and raw log

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
func (it *InboxProvedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(InboxProved)
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
		it.Event = new(InboxProved)
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
func (it *InboxProvedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *InboxProvedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// InboxProved represents a Proved event raised by the Inbox contract.
type InboxProved struct {
	FirstProposalId    *big.Int
	FirstNewProposalId *big.Int
	LastProposalId     *big.Int
	ActualProver       common.Address
	CheckpointSynced   bool
	Raw                types.Log // Blockchain specific contextual infos
}

// FilterProved is a free log retrieval operation binding the contract event 0x7ca0f1e30099488c4ee24e86a6b2c6802e9add6d530919af7aa17db3bcc1cff1.
//
// Solidity: event Proved(uint48 firstProposalId, uint48 firstNewProposalId, uint48 lastProposalId, address indexed actualProver, bool checkpointSynced)
func (_Inbox *InboxFilterer) FilterProved(opts *bind.FilterOpts, actualProver []common.Address) (*InboxProvedIterator, error) {

	var actualProverRule []interface{}
	for _, actualProverItem := range actualProver {
		actualProverRule = append(actualProverRule, actualProverItem)
	}

	logs, sub, err := _Inbox.contract.FilterLogs(opts, "Proved", actualProverRule)
	if err != nil {
		return nil, err
	}
	return &InboxProvedIterator{contract: _Inbox.contract, event: "Proved", logs: logs, sub: sub}, nil
}

// WatchProved is a free log subscription operation binding the contract event 0x7ca0f1e30099488c4ee24e86a6b2c6802e9add6d530919af7aa17db3bcc1cff1.
//
// Solidity: event Proved(uint48 firstProposalId, uint48 firstNewProposalId, uint48 lastProposalId, address indexed actualProver, bool checkpointSynced)
func (_Inbox *InboxFilterer) WatchProved(opts *bind.WatchOpts, sink chan<- *InboxProved, actualProver []common.Address) (event.Subscription, error) {

	var actualProverRule []interface{}
	for _, actualProverItem := range actualProver {
		actualProverRule = append(actualProverRule, actualProverItem)
	}

	logs, sub, err := _Inbox.contract.WatchLogs(opts, "Proved", actualProverRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(InboxProved)
				if err := _Inbox.contract.UnpackLog(event, "Proved", log); err != nil {
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

// ParseProved is a log parse operation binding the contract event 0x7ca0f1e30099488c4ee24e86a6b2c6802e9add6d530919af7aa17db3bcc1cff1.
//
// Solidity: event Proved(uint48 firstProposalId, uint48 firstNewProposalId, uint48 lastProposalId, address indexed actualProver, bool checkpointSynced)
func (_Inbox *InboxFilterer) ParseProved(log types.Log) (*InboxProved, error) {
	event := new(InboxProved)
	if err := _Inbox.contract.UnpackLog(event, "Proved", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// InboxUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the Inbox contract.
type InboxUnpausedIterator struct {
	Event *InboxUnpaused // Event containing the contract specifics and raw log

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
func (it *InboxUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(InboxUnpaused)
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
		it.Event = new(InboxUnpaused)
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
func (it *InboxUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *InboxUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// InboxUnpaused represents a Unpaused event raised by the Inbox contract.
type InboxUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_Inbox *InboxFilterer) FilterUnpaused(opts *bind.FilterOpts) (*InboxUnpausedIterator, error) {

	logs, sub, err := _Inbox.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &InboxUnpausedIterator{contract: _Inbox.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_Inbox *InboxFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *InboxUnpaused) (event.Subscription, error) {

	logs, sub, err := _Inbox.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(InboxUnpaused)
				if err := _Inbox.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_Inbox *InboxFilterer) ParseUnpaused(log types.Log) (*InboxUnpaused, error) {
	event := new(InboxUnpaused)
	if err := _Inbox.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// InboxUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the Inbox contract.
type InboxUpgradedIterator struct {
	Event *InboxUpgraded // Event containing the contract specifics and raw log

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
func (it *InboxUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(InboxUpgraded)
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
		it.Event = new(InboxUpgraded)
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
func (it *InboxUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *InboxUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// InboxUpgraded represents a Upgraded event raised by the Inbox contract.
type InboxUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_Inbox *InboxFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*InboxUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _Inbox.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &InboxUpgradedIterator{contract: _Inbox.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_Inbox *InboxFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *InboxUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _Inbox.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(InboxUpgraded)
				if err := _Inbox.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_Inbox *InboxFilterer) ParseUpgraded(log types.Log) (*InboxUpgraded, error) {
	event := new(InboxUpgraded)
	if err := _Inbox.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// InboxWithdrawalCancelledIterator is returned from FilterWithdrawalCancelled and is used to iterate over the raw logs and unpacked data for WithdrawalCancelled events raised by the Inbox contract.
type InboxWithdrawalCancelledIterator struct {
	Event *InboxWithdrawalCancelled // Event containing the contract specifics and raw log

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
func (it *InboxWithdrawalCancelledIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(InboxWithdrawalCancelled)
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
		it.Event = new(InboxWithdrawalCancelled)
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
func (it *InboxWithdrawalCancelledIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *InboxWithdrawalCancelledIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// InboxWithdrawalCancelled represents a WithdrawalCancelled event raised by the Inbox contract.
type InboxWithdrawalCancelled struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterWithdrawalCancelled is a free log retrieval operation binding the contract event 0xc51fdb96728de385ec7859819e3997bc618362ef0dbca0ad051d856866cda3db.
//
// Solidity: event WithdrawalCancelled(address indexed account)
func (_Inbox *InboxFilterer) FilterWithdrawalCancelled(opts *bind.FilterOpts, account []common.Address) (*InboxWithdrawalCancelledIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _Inbox.contract.FilterLogs(opts, "WithdrawalCancelled", accountRule)
	if err != nil {
		return nil, err
	}
	return &InboxWithdrawalCancelledIterator{contract: _Inbox.contract, event: "WithdrawalCancelled", logs: logs, sub: sub}, nil
}

// WatchWithdrawalCancelled is a free log subscription operation binding the contract event 0xc51fdb96728de385ec7859819e3997bc618362ef0dbca0ad051d856866cda3db.
//
// Solidity: event WithdrawalCancelled(address indexed account)
func (_Inbox *InboxFilterer) WatchWithdrawalCancelled(opts *bind.WatchOpts, sink chan<- *InboxWithdrawalCancelled, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _Inbox.contract.WatchLogs(opts, "WithdrawalCancelled", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(InboxWithdrawalCancelled)
				if err := _Inbox.contract.UnpackLog(event, "WithdrawalCancelled", log); err != nil {
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

// ParseWithdrawalCancelled is a log parse operation binding the contract event 0xc51fdb96728de385ec7859819e3997bc618362ef0dbca0ad051d856866cda3db.
//
// Solidity: event WithdrawalCancelled(address indexed account)
func (_Inbox *InboxFilterer) ParseWithdrawalCancelled(log types.Log) (*InboxWithdrawalCancelled, error) {
	event := new(InboxWithdrawalCancelled)
	if err := _Inbox.contract.UnpackLog(event, "WithdrawalCancelled", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// InboxWithdrawalRequestedIterator is returned from FilterWithdrawalRequested and is used to iterate over the raw logs and unpacked data for WithdrawalRequested events raised by the Inbox contract.
type InboxWithdrawalRequestedIterator struct {
	Event *InboxWithdrawalRequested // Event containing the contract specifics and raw log

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
func (it *InboxWithdrawalRequestedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(InboxWithdrawalRequested)
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
		it.Event = new(InboxWithdrawalRequested)
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
func (it *InboxWithdrawalRequestedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *InboxWithdrawalRequestedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// InboxWithdrawalRequested represents a WithdrawalRequested event raised by the Inbox contract.
type InboxWithdrawalRequested struct {
	Account        common.Address
	WithdrawableAt *big.Int
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterWithdrawalRequested is a free log retrieval operation binding the contract event 0x3bbe41cfdd142e0f9b2224dac18c6efd2a6966e35a9ec23ab57ce63a60b33604.
//
// Solidity: event WithdrawalRequested(address indexed account, uint48 withdrawableAt)
func (_Inbox *InboxFilterer) FilterWithdrawalRequested(opts *bind.FilterOpts, account []common.Address) (*InboxWithdrawalRequestedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _Inbox.contract.FilterLogs(opts, "WithdrawalRequested", accountRule)
	if err != nil {
		return nil, err
	}
	return &InboxWithdrawalRequestedIterator{contract: _Inbox.contract, event: "WithdrawalRequested", logs: logs, sub: sub}, nil
}

// WatchWithdrawalRequested is a free log subscription operation binding the contract event 0x3bbe41cfdd142e0f9b2224dac18c6efd2a6966e35a9ec23ab57ce63a60b33604.
//
// Solidity: event WithdrawalRequested(address indexed account, uint48 withdrawableAt)
func (_Inbox *InboxFilterer) WatchWithdrawalRequested(opts *bind.WatchOpts, sink chan<- *InboxWithdrawalRequested, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _Inbox.contract.WatchLogs(opts, "WithdrawalRequested", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(InboxWithdrawalRequested)
				if err := _Inbox.contract.UnpackLog(event, "WithdrawalRequested", log); err != nil {
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

// ParseWithdrawalRequested is a log parse operation binding the contract event 0x3bbe41cfdd142e0f9b2224dac18c6efd2a6966e35a9ec23ab57ce63a60b33604.
//
// Solidity: event WithdrawalRequested(address indexed account, uint48 withdrawableAt)
func (_Inbox *InboxFilterer) ParseWithdrawalRequested(log types.Log) (*InboxWithdrawalRequested, error) {
	event := new(InboxWithdrawalRequested)
	if err := _Inbox.contract.UnpackLog(event, "WithdrawalRequested", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
