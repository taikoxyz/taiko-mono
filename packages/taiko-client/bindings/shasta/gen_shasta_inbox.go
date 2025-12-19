// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package shasta

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
	ProvingWindow                     *big.Int
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
	Proposer         common.Address
	DesignatedProver common.Address
	Timestamp        *big.Int
	BlockHash        [32]byte
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

// LibBondsBondInstruction is an auto generated low-level Go binding around an user-defined struct.
type LibBondsBondInstruction struct {
	ProposalId *big.Int
	BondType   uint8
	Payer      common.Address
	Payee      common.Address
}

// ShastaInboxClientMetaData contains all meta data concerning the ShastaInboxClient contract.
var ShastaInboxClientMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"_proofVerifier\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_proposerChecker\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_proverWhitelist\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"activate\",\"inputs\":[{\"name\":\"_lastPacayaBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"activationTimestamp\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint48\",\"internalType\":\"uint48\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"decodeProposeInput\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"input_\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProposeInput\",\"components\":[{\"name\":\"deadline\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blobReference\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobReference\",\"components\":[{\"name\":\"blobStartIndex\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"numBlobs\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"}]},{\"name\":\"numForcedInclusions\",\"type\":\"uint8\",\"internalType\":\"uint8\"}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"decodeProveInput\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"input_\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProveInput\",\"components\":[{\"name\":\"commitment\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Commitment\",\"components\":[{\"name\":\"firstProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"firstProposalParentBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"lastProposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"endBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endStateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"transitions\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Transition[]\",\"components\":[{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]},{\"name\":\"forceCheckpointSync\",\"type\":\"bool\",\"internalType\":\"bool\"}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"encodeProposeInput\",\"inputs\":[{\"name\":\"_input\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProposeInput\",\"components\":[{\"name\":\"deadline\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blobReference\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobReference\",\"components\":[{\"name\":\"blobStartIndex\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"numBlobs\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"}]},{\"name\":\"numForcedInclusions\",\"type\":\"uint8\",\"internalType\":\"uint8\"}]}],\"outputs\":[{\"name\":\"encoded_\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"encodeProveInput\",\"inputs\":[{\"name\":\"_input\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProveInput\",\"components\":[{\"name\":\"commitment\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Commitment\",\"components\":[{\"name\":\"firstProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"firstProposalParentBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"lastProposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"endBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endStateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"transitions\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Transition[]\",\"components\":[{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]},{\"name\":\"forceCheckpointSync\",\"type\":\"bool\",\"internalType\":\"bool\"}]}],\"outputs\":[{\"name\":\"encoded_\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getConfig\",\"inputs\":[],\"outputs\":[{\"name\":\"config_\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Config\",\"components\":[{\"name\":\"proofVerifier\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"proposerChecker\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"proverWhitelist\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"signalService\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"provingWindow\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"maxProofSubmissionDelay\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"ringBufferSize\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"minForcedInclusionCount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"forcedInclusionDelay\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"forcedInclusionFeeInGwei\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"forcedInclusionFeeDoubleThreshold\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"minCheckpointDelay\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"permissionlessInclusionMultiplier\",\"type\":\"uint8\",\"internalType\":\"uint8\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getCoreState\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structIInbox.CoreState\",\"components\":[{\"name\":\"nextProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastProposalBlockId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastCheckpointTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getCurrentForcedInclusionFee\",\"inputs\":[],\"outputs\":[{\"name\":\"feeInGwei_\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getForcedInclusionState\",\"inputs\":[],\"outputs\":[{\"name\":\"head_\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"tail_\",\"type\":\"uint48\",\"internalType\":\"uint48\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getForcedInclusions\",\"inputs\":[{\"name\":\"_start\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"_maxCount\",\"type\":\"uint48\",\"internalType\":\"uint48\"}],\"outputs\":[{\"name\":\"inclusions_\",\"type\":\"tuple[]\",\"internalType\":\"structIForcedInclusionStore.ForcedInclusion[]\",\"components\":[{\"name\":\"feeInGwei\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getProposalHash\",\"inputs\":[{\"name\":\"_proposalId\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"hashBondInstruction\",\"inputs\":[{\"name\":\"_bondInstruction\",\"type\":\"tuple\",\"internalType\":\"structLibBonds.BondInstruction\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"bondType\",\"type\":\"uint8\",\"internalType\":\"enumLibBonds.BondType\"},{\"name\":\"payer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"payee\",\"type\":\"address\",\"internalType\":\"address\"}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashCommitment\",\"inputs\":[{\"name\":\"_commitment\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Commitment\",\"components\":[{\"name\":\"firstProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"firstProposalParentBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"lastProposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"endBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endStateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"transitions\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Transition[]\",\"components\":[{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashProposal\",\"inputs\":[{\"name\":\"_proposal\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Proposal\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"parentProposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"originBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"originBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sources\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.DerivationSource[]\",\"components\":[{\"name\":\"isForcedInclusion\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"impl\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inNonReentrant\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"propose\",\"inputs\":[{\"name\":\"_lookahead\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"prove\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"_proof\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolver\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"saveForcedInclusion\",\"inputs\":[{\"name\":\"_blobReference\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobReference\",\"components\":[{\"name\":\"blobStartIndex\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"numBlobs\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"}]}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondInstructionCreated\",\"inputs\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"indexed\":true,\"internalType\":\"uint48\"},{\"name\":\"bondInstruction\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structLibBonds.BondInstruction\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"bondType\",\"type\":\"uint8\",\"internalType\":\"enumLibBonds.BondType\"},{\"name\":\"payer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"payee\",\"type\":\"address\",\"internalType\":\"address\"}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ForcedInclusionSaved\",\"inputs\":[{\"name\":\"forcedInclusion\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structIForcedInclusionStore.ForcedInclusion\",\"components\":[{\"name\":\"feeInGwei\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"InboxActivated\",\"inputs\":[{\"name\":\"lastPacayaBlockHash\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Proposed\",\"inputs\":[{\"name\":\"id\",\"type\":\"uint48\",\"indexed\":true,\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"parentProposalHash\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"indexed\":false,\"internalType\":\"uint48\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"},{\"name\":\"sources\",\"type\":\"tuple[]\",\"indexed\":false,\"internalType\":\"structIInbox.DerivationSource[]\",\"components\":[{\"name\":\"isForcedInclusion\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Proved\",\"inputs\":[{\"name\":\"firstProposalId\",\"type\":\"uint48\",\"indexed\":false,\"internalType\":\"uint48\"},{\"name\":\"firstNewProposalId\",\"type\":\"uint48\",\"indexed\":false,\"internalType\":\"uint48\"},{\"name\":\"lastProposalId\",\"type\":\"uint48\",\"indexed\":false,\"internalType\":\"uint48\"},{\"name\":\"actualProver\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"checkpointSynced\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCESS_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ActivationRequired\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"BlobNotFound\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CannotProposeInCurrentBlock\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CheckpointDelayHasPassed\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"DeadlineExceeded\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ETH_TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EmptyBatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FUNC_NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FirstProposalIdTooLarge\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"IncorrectProposalCount\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"LastProposalAlreadyFinalized\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"LastProposalHashMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"LastProposalIdTooLarge\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"LengthExceedsUint16\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NoBlobs\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotEnoughCapacity\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ParentBlockHashMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ProverNotWhitelisted\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UnprocessedForcedInclusionIsDue\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_VALUE\",\"inputs\":[]}]",
}

// ShastaInboxClientABI is the input ABI used to generate the binding from.
// Deprecated: Use ShastaInboxClientMetaData.ABI instead.
var ShastaInboxClientABI = ShastaInboxClientMetaData.ABI

// ShastaInboxClient is an auto generated Go binding around an Ethereum contract.
type ShastaInboxClient struct {
	ShastaInboxClientCaller     // Read-only binding to the contract
	ShastaInboxClientTransactor // Write-only binding to the contract
	ShastaInboxClientFilterer   // Log filterer for contract events
}

// ShastaInboxClientCaller is an auto generated read-only Go binding around an Ethereum contract.
type ShastaInboxClientCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ShastaInboxClientTransactor is an auto generated write-only Go binding around an Ethereum contract.
type ShastaInboxClientTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ShastaInboxClientFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type ShastaInboxClientFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ShastaInboxClientSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type ShastaInboxClientSession struct {
	Contract     *ShastaInboxClient // Generic contract binding to set the session for
	CallOpts     bind.CallOpts      // Call options to use throughout this session
	TransactOpts bind.TransactOpts  // Transaction auth options to use throughout this session
}

// ShastaInboxClientCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type ShastaInboxClientCallerSession struct {
	Contract *ShastaInboxClientCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts            // Call options to use throughout this session
}

// ShastaInboxClientTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type ShastaInboxClientTransactorSession struct {
	Contract     *ShastaInboxClientTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts            // Transaction auth options to use throughout this session
}

// ShastaInboxClientRaw is an auto generated low-level Go binding around an Ethereum contract.
type ShastaInboxClientRaw struct {
	Contract *ShastaInboxClient // Generic contract binding to access the raw methods on
}

// ShastaInboxClientCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type ShastaInboxClientCallerRaw struct {
	Contract *ShastaInboxClientCaller // Generic read-only contract binding to access the raw methods on
}

// ShastaInboxClientTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type ShastaInboxClientTransactorRaw struct {
	Contract *ShastaInboxClientTransactor // Generic write-only contract binding to access the raw methods on
}

// NewShastaInboxClient creates a new instance of ShastaInboxClient, bound to a specific deployed contract.
func NewShastaInboxClient(address common.Address, backend bind.ContractBackend) (*ShastaInboxClient, error) {
	contract, err := bindShastaInboxClient(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &ShastaInboxClient{ShastaInboxClientCaller: ShastaInboxClientCaller{contract: contract}, ShastaInboxClientTransactor: ShastaInboxClientTransactor{contract: contract}, ShastaInboxClientFilterer: ShastaInboxClientFilterer{contract: contract}}, nil
}

// NewShastaInboxClientCaller creates a new read-only instance of ShastaInboxClient, bound to a specific deployed contract.
func NewShastaInboxClientCaller(address common.Address, caller bind.ContractCaller) (*ShastaInboxClientCaller, error) {
	contract, err := bindShastaInboxClient(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &ShastaInboxClientCaller{contract: contract}, nil
}

// NewShastaInboxClientTransactor creates a new write-only instance of ShastaInboxClient, bound to a specific deployed contract.
func NewShastaInboxClientTransactor(address common.Address, transactor bind.ContractTransactor) (*ShastaInboxClientTransactor, error) {
	contract, err := bindShastaInboxClient(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &ShastaInboxClientTransactor{contract: contract}, nil
}

// NewShastaInboxClientFilterer creates a new log filterer instance of ShastaInboxClient, bound to a specific deployed contract.
func NewShastaInboxClientFilterer(address common.Address, filterer bind.ContractFilterer) (*ShastaInboxClientFilterer, error) {
	contract, err := bindShastaInboxClient(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &ShastaInboxClientFilterer{contract: contract}, nil
}

// bindShastaInboxClient binds a generic wrapper to an already deployed contract.
func bindShastaInboxClient(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := ShastaInboxClientMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ShastaInboxClient *ShastaInboxClientRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ShastaInboxClient.Contract.ShastaInboxClientCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ShastaInboxClient *ShastaInboxClientRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.ShastaInboxClientTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ShastaInboxClient *ShastaInboxClientRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.ShastaInboxClientTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ShastaInboxClient *ShastaInboxClientCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ShastaInboxClient.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ShastaInboxClient *ShastaInboxClientTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ShastaInboxClient *ShastaInboxClientTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.contract.Transact(opts, method, params...)
}

// ActivationTimestamp is a free data retrieval call binding the contract method 0x0423c7de.
//
// Solidity: function activationTimestamp() view returns(uint48)
func (_ShastaInboxClient *ShastaInboxClientCaller) ActivationTimestamp(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "activationTimestamp")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// ActivationTimestamp is a free data retrieval call binding the contract method 0x0423c7de.
//
// Solidity: function activationTimestamp() view returns(uint48)
func (_ShastaInboxClient *ShastaInboxClientSession) ActivationTimestamp() (*big.Int, error) {
	return _ShastaInboxClient.Contract.ActivationTimestamp(&_ShastaInboxClient.CallOpts)
}

// ActivationTimestamp is a free data retrieval call binding the contract method 0x0423c7de.
//
// Solidity: function activationTimestamp() view returns(uint48)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) ActivationTimestamp() (*big.Int, error) {
	return _ShastaInboxClient.Contract.ActivationTimestamp(&_ShastaInboxClient.CallOpts)
}

// DecodeProposeInput is a free data retrieval call binding the contract method 0xafb63ad4.
//
// Solidity: function decodeProposeInput(bytes _data) pure returns((uint48,(uint16,uint16,uint24),uint8) input_)
func (_ShastaInboxClient *ShastaInboxClientCaller) DecodeProposeInput(opts *bind.CallOpts, _data []byte) (IInboxProposeInput, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "decodeProposeInput", _data)

	if err != nil {
		return *new(IInboxProposeInput), err
	}

	out0 := *abi.ConvertType(out[0], new(IInboxProposeInput)).(*IInboxProposeInput)

	return out0, err

}

// DecodeProposeInput is a free data retrieval call binding the contract method 0xafb63ad4.
//
// Solidity: function decodeProposeInput(bytes _data) pure returns((uint48,(uint16,uint16,uint24),uint8) input_)
func (_ShastaInboxClient *ShastaInboxClientSession) DecodeProposeInput(_data []byte) (IInboxProposeInput, error) {
	return _ShastaInboxClient.Contract.DecodeProposeInput(&_ShastaInboxClient.CallOpts, _data)
}

// DecodeProposeInput is a free data retrieval call binding the contract method 0xafb63ad4.
//
// Solidity: function decodeProposeInput(bytes _data) pure returns((uint48,(uint16,uint16,uint24),uint8) input_)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) DecodeProposeInput(_data []byte) (IInboxProposeInput, error) {
	return _ShastaInboxClient.Contract.DecodeProposeInput(&_ShastaInboxClient.CallOpts, _data)
}

// DecodeProveInput is a free data retrieval call binding the contract method 0xedbacd44.
//
// Solidity: function decodeProveInput(bytes _data) pure returns(((uint48,bytes32,bytes32,address,uint48,bytes32,(address,address,uint48,bytes32)[]),bool) input_)
func (_ShastaInboxClient *ShastaInboxClientCaller) DecodeProveInput(opts *bind.CallOpts, _data []byte) (IInboxProveInput, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "decodeProveInput", _data)

	if err != nil {
		return *new(IInboxProveInput), err
	}

	out0 := *abi.ConvertType(out[0], new(IInboxProveInput)).(*IInboxProveInput)

	return out0, err

}

// DecodeProveInput is a free data retrieval call binding the contract method 0xedbacd44.
//
// Solidity: function decodeProveInput(bytes _data) pure returns(((uint48,bytes32,bytes32,address,uint48,bytes32,(address,address,uint48,bytes32)[]),bool) input_)
func (_ShastaInboxClient *ShastaInboxClientSession) DecodeProveInput(_data []byte) (IInboxProveInput, error) {
	return _ShastaInboxClient.Contract.DecodeProveInput(&_ShastaInboxClient.CallOpts, _data)
}

// DecodeProveInput is a free data retrieval call binding the contract method 0xedbacd44.
//
// Solidity: function decodeProveInput(bytes _data) pure returns(((uint48,bytes32,bytes32,address,uint48,bytes32,(address,address,uint48,bytes32)[]),bool) input_)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) DecodeProveInput(_data []byte) (IInboxProveInput, error) {
	return _ShastaInboxClient.Contract.DecodeProveInput(&_ShastaInboxClient.CallOpts, _data)
}

// EncodeProposeInput is a free data retrieval call binding the contract method 0x2f1969b0.
//
// Solidity: function encodeProposeInput((uint48,(uint16,uint16,uint24),uint8) _input) pure returns(bytes encoded_)
func (_ShastaInboxClient *ShastaInboxClientCaller) EncodeProposeInput(opts *bind.CallOpts, _input IInboxProposeInput) ([]byte, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "encodeProposeInput", _input)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProposeInput is a free data retrieval call binding the contract method 0x2f1969b0.
//
// Solidity: function encodeProposeInput((uint48,(uint16,uint16,uint24),uint8) _input) pure returns(bytes encoded_)
func (_ShastaInboxClient *ShastaInboxClientSession) EncodeProposeInput(_input IInboxProposeInput) ([]byte, error) {
	return _ShastaInboxClient.Contract.EncodeProposeInput(&_ShastaInboxClient.CallOpts, _input)
}

// EncodeProposeInput is a free data retrieval call binding the contract method 0x2f1969b0.
//
// Solidity: function encodeProposeInput((uint48,(uint16,uint16,uint24),uint8) _input) pure returns(bytes encoded_)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) EncodeProposeInput(_input IInboxProposeInput) ([]byte, error) {
	return _ShastaInboxClient.Contract.EncodeProposeInput(&_ShastaInboxClient.CallOpts, _input)
}

// EncodeProveInput is a free data retrieval call binding the contract method 0xc3d3e2f4.
//
// Solidity: function encodeProveInput(((uint48,bytes32,bytes32,address,uint48,bytes32,(address,address,uint48,bytes32)[]),bool) _input) pure returns(bytes encoded_)
func (_ShastaInboxClient *ShastaInboxClientCaller) EncodeProveInput(opts *bind.CallOpts, _input IInboxProveInput) ([]byte, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "encodeProveInput", _input)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProveInput is a free data retrieval call binding the contract method 0xc3d3e2f4.
//
// Solidity: function encodeProveInput(((uint48,bytes32,bytes32,address,uint48,bytes32,(address,address,uint48,bytes32)[]),bool) _input) pure returns(bytes encoded_)
func (_ShastaInboxClient *ShastaInboxClientSession) EncodeProveInput(_input IInboxProveInput) ([]byte, error) {
	return _ShastaInboxClient.Contract.EncodeProveInput(&_ShastaInboxClient.CallOpts, _input)
}

// EncodeProveInput is a free data retrieval call binding the contract method 0xc3d3e2f4.
//
// Solidity: function encodeProveInput(((uint48,bytes32,bytes32,address,uint48,bytes32,(address,address,uint48,bytes32)[]),bool) _input) pure returns(bytes encoded_)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) EncodeProveInput(_input IInboxProveInput) ([]byte, error) {
	return _ShastaInboxClient.Contract.EncodeProveInput(&_ShastaInboxClient.CallOpts, _input)
}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() view returns((address,address,address,address,uint48,uint48,uint256,uint8,uint256,uint16,uint64,uint64,uint16,uint8) config_)
func (_ShastaInboxClient *ShastaInboxClientCaller) GetConfig(opts *bind.CallOpts) (IInboxConfig, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "getConfig")

	if err != nil {
		return *new(IInboxConfig), err
	}

	out0 := *abi.ConvertType(out[0], new(IInboxConfig)).(*IInboxConfig)

	return out0, err

}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() view returns((address,address,address,address,uint48,uint48,uint256,uint8,uint256,uint16,uint64,uint64,uint16,uint8) config_)
func (_ShastaInboxClient *ShastaInboxClientSession) GetConfig() (IInboxConfig, error) {
	return _ShastaInboxClient.Contract.GetConfig(&_ShastaInboxClient.CallOpts)
}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() view returns((address,address,address,address,uint48,uint48,uint256,uint8,uint256,uint16,uint64,uint64,uint16,uint8) config_)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) GetConfig() (IInboxConfig, error) {
	return _ShastaInboxClient.Contract.GetConfig(&_ShastaInboxClient.CallOpts)
}

// GetCoreState is a free data retrieval call binding the contract method 0x6aa6a01a.
//
// Solidity: function getCoreState() view returns((uint48,uint48,uint48,uint48,uint48,bytes32))
func (_ShastaInboxClient *ShastaInboxClientCaller) GetCoreState(opts *bind.CallOpts) (IInboxCoreState, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "getCoreState")

	if err != nil {
		return *new(IInboxCoreState), err
	}

	out0 := *abi.ConvertType(out[0], new(IInboxCoreState)).(*IInboxCoreState)

	return out0, err

}

// GetCoreState is a free data retrieval call binding the contract method 0x6aa6a01a.
//
// Solidity: function getCoreState() view returns((uint48,uint48,uint48,uint48,uint48,bytes32))
func (_ShastaInboxClient *ShastaInboxClientSession) GetCoreState() (IInboxCoreState, error) {
	return _ShastaInboxClient.Contract.GetCoreState(&_ShastaInboxClient.CallOpts)
}

// GetCoreState is a free data retrieval call binding the contract method 0x6aa6a01a.
//
// Solidity: function getCoreState() view returns((uint48,uint48,uint48,uint48,uint48,bytes32))
func (_ShastaInboxClient *ShastaInboxClientCallerSession) GetCoreState() (IInboxCoreState, error) {
	return _ShastaInboxClient.Contract.GetCoreState(&_ShastaInboxClient.CallOpts)
}

// GetCurrentForcedInclusionFee is a free data retrieval call binding the contract method 0xe3053335.
//
// Solidity: function getCurrentForcedInclusionFee() view returns(uint64 feeInGwei_)
func (_ShastaInboxClient *ShastaInboxClientCaller) GetCurrentForcedInclusionFee(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "getCurrentForcedInclusionFee")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// GetCurrentForcedInclusionFee is a free data retrieval call binding the contract method 0xe3053335.
//
// Solidity: function getCurrentForcedInclusionFee() view returns(uint64 feeInGwei_)
func (_ShastaInboxClient *ShastaInboxClientSession) GetCurrentForcedInclusionFee() (uint64, error) {
	return _ShastaInboxClient.Contract.GetCurrentForcedInclusionFee(&_ShastaInboxClient.CallOpts)
}

// GetCurrentForcedInclusionFee is a free data retrieval call binding the contract method 0xe3053335.
//
// Solidity: function getCurrentForcedInclusionFee() view returns(uint64 feeInGwei_)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) GetCurrentForcedInclusionFee() (uint64, error) {
	return _ShastaInboxClient.Contract.GetCurrentForcedInclusionFee(&_ShastaInboxClient.CallOpts)
}

// GetForcedInclusionState is a free data retrieval call binding the contract method 0x5ccc1718.
//
// Solidity: function getForcedInclusionState() view returns(uint48 head_, uint48 tail_)
func (_ShastaInboxClient *ShastaInboxClientCaller) GetForcedInclusionState(opts *bind.CallOpts) (struct {
	Head *big.Int
	Tail *big.Int
}, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "getForcedInclusionState")

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
func (_ShastaInboxClient *ShastaInboxClientSession) GetForcedInclusionState() (struct {
	Head *big.Int
	Tail *big.Int
}, error) {
	return _ShastaInboxClient.Contract.GetForcedInclusionState(&_ShastaInboxClient.CallOpts)
}

// GetForcedInclusionState is a free data retrieval call binding the contract method 0x5ccc1718.
//
// Solidity: function getForcedInclusionState() view returns(uint48 head_, uint48 tail_)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) GetForcedInclusionState() (struct {
	Head *big.Int
	Tail *big.Int
}, error) {
	return _ShastaInboxClient.Contract.GetForcedInclusionState(&_ShastaInboxClient.CallOpts)
}

// GetForcedInclusions is a free data retrieval call binding the contract method 0x40df9866.
//
// Solidity: function getForcedInclusions(uint48 _start, uint48 _maxCount) view returns((uint64,(bytes32[],uint24,uint48))[] inclusions_)
func (_ShastaInboxClient *ShastaInboxClientCaller) GetForcedInclusions(opts *bind.CallOpts, _start *big.Int, _maxCount *big.Int) ([]IForcedInclusionStoreForcedInclusion, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "getForcedInclusions", _start, _maxCount)

	if err != nil {
		return *new([]IForcedInclusionStoreForcedInclusion), err
	}

	out0 := *abi.ConvertType(out[0], new([]IForcedInclusionStoreForcedInclusion)).(*[]IForcedInclusionStoreForcedInclusion)

	return out0, err

}

// GetForcedInclusions is a free data retrieval call binding the contract method 0x40df9866.
//
// Solidity: function getForcedInclusions(uint48 _start, uint48 _maxCount) view returns((uint64,(bytes32[],uint24,uint48))[] inclusions_)
func (_ShastaInboxClient *ShastaInboxClientSession) GetForcedInclusions(_start *big.Int, _maxCount *big.Int) ([]IForcedInclusionStoreForcedInclusion, error) {
	return _ShastaInboxClient.Contract.GetForcedInclusions(&_ShastaInboxClient.CallOpts, _start, _maxCount)
}

// GetForcedInclusions is a free data retrieval call binding the contract method 0x40df9866.
//
// Solidity: function getForcedInclusions(uint48 _start, uint48 _maxCount) view returns((uint64,(bytes32[],uint24,uint48))[] inclusions_)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) GetForcedInclusions(_start *big.Int, _maxCount *big.Int) ([]IForcedInclusionStoreForcedInclusion, error) {
	return _ShastaInboxClient.Contract.GetForcedInclusions(&_ShastaInboxClient.CallOpts, _start, _maxCount)
}

// GetProposalHash is a free data retrieval call binding the contract method 0xa834725a.
//
// Solidity: function getProposalHash(uint256 _proposalId) view returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientCaller) GetProposalHash(opts *bind.CallOpts, _proposalId *big.Int) ([32]byte, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "getProposalHash", _proposalId)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetProposalHash is a free data retrieval call binding the contract method 0xa834725a.
//
// Solidity: function getProposalHash(uint256 _proposalId) view returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientSession) GetProposalHash(_proposalId *big.Int) ([32]byte, error) {
	return _ShastaInboxClient.Contract.GetProposalHash(&_ShastaInboxClient.CallOpts, _proposalId)
}

// GetProposalHash is a free data retrieval call binding the contract method 0xa834725a.
//
// Solidity: function getProposalHash(uint256 _proposalId) view returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) GetProposalHash(_proposalId *big.Int) ([32]byte, error) {
	return _ShastaInboxClient.Contract.GetProposalHash(&_ShastaInboxClient.CallOpts, _proposalId)
}

// HashBondInstruction is a free data retrieval call binding the contract method 0x5a213615.
//
// Solidity: function hashBondInstruction((uint48,uint8,address,address) _bondInstruction) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientCaller) HashBondInstruction(opts *bind.CallOpts, _bondInstruction LibBondsBondInstruction) ([32]byte, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "hashBondInstruction", _bondInstruction)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashBondInstruction is a free data retrieval call binding the contract method 0x5a213615.
//
// Solidity: function hashBondInstruction((uint48,uint8,address,address) _bondInstruction) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientSession) HashBondInstruction(_bondInstruction LibBondsBondInstruction) ([32]byte, error) {
	return _ShastaInboxClient.Contract.HashBondInstruction(&_ShastaInboxClient.CallOpts, _bondInstruction)
}

// HashBondInstruction is a free data retrieval call binding the contract method 0x5a213615.
//
// Solidity: function hashBondInstruction((uint48,uint8,address,address) _bondInstruction) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) HashBondInstruction(_bondInstruction LibBondsBondInstruction) ([32]byte, error) {
	return _ShastaInboxClient.Contract.HashBondInstruction(&_ShastaInboxClient.CallOpts, _bondInstruction)
}

// HashCommitment is a free data retrieval call binding the contract method 0xcbc148c3.
//
// Solidity: function hashCommitment((uint48,bytes32,bytes32,address,uint48,bytes32,(address,address,uint48,bytes32)[]) _commitment) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientCaller) HashCommitment(opts *bind.CallOpts, _commitment IInboxCommitment) ([32]byte, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "hashCommitment", _commitment)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashCommitment is a free data retrieval call binding the contract method 0xcbc148c3.
//
// Solidity: function hashCommitment((uint48,bytes32,bytes32,address,uint48,bytes32,(address,address,uint48,bytes32)[]) _commitment) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientSession) HashCommitment(_commitment IInboxCommitment) ([32]byte, error) {
	return _ShastaInboxClient.Contract.HashCommitment(&_ShastaInboxClient.CallOpts, _commitment)
}

// HashCommitment is a free data retrieval call binding the contract method 0xcbc148c3.
//
// Solidity: function hashCommitment((uint48,bytes32,bytes32,address,uint48,bytes32,(address,address,uint48,bytes32)[]) _commitment) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) HashCommitment(_commitment IInboxCommitment) ([32]byte, error) {
	return _ShastaInboxClient.Contract.HashCommitment(&_ShastaInboxClient.CallOpts, _commitment)
}

// HashProposal is a free data retrieval call binding the contract method 0xb28e824e.
//
// Solidity: function hashProposal((uint48,uint48,uint48,address,bytes32,uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]) _proposal) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientCaller) HashProposal(opts *bind.CallOpts, _proposal IInboxProposal) ([32]byte, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "hashProposal", _proposal)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashProposal is a free data retrieval call binding the contract method 0xb28e824e.
//
// Solidity: function hashProposal((uint48,uint48,uint48,address,bytes32,uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]) _proposal) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientSession) HashProposal(_proposal IInboxProposal) ([32]byte, error) {
	return _ShastaInboxClient.Contract.HashProposal(&_ShastaInboxClient.CallOpts, _proposal)
}

// HashProposal is a free data retrieval call binding the contract method 0xb28e824e.
//
// Solidity: function hashProposal((uint48,uint48,uint48,address,bytes32,uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]) _proposal) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) HashProposal(_proposal IInboxProposal) ([32]byte, error) {
	return _ShastaInboxClient.Contract.HashProposal(&_ShastaInboxClient.CallOpts, _proposal)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_ShastaInboxClient *ShastaInboxClientCaller) Impl(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "impl")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_ShastaInboxClient *ShastaInboxClientSession) Impl() (common.Address, error) {
	return _ShastaInboxClient.Contract.Impl(&_ShastaInboxClient.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) Impl() (common.Address, error) {
	return _ShastaInboxClient.Contract.Impl(&_ShastaInboxClient.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_ShastaInboxClient *ShastaInboxClientCaller) InNonReentrant(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "inNonReentrant")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_ShastaInboxClient *ShastaInboxClientSession) InNonReentrant() (bool, error) {
	return _ShastaInboxClient.Contract.InNonReentrant(&_ShastaInboxClient.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) InNonReentrant() (bool, error) {
	return _ShastaInboxClient.Contract.InNonReentrant(&_ShastaInboxClient.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ShastaInboxClient *ShastaInboxClientCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ShastaInboxClient *ShastaInboxClientSession) Owner() (common.Address, error) {
	return _ShastaInboxClient.Contract.Owner(&_ShastaInboxClient.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) Owner() (common.Address, error) {
	return _ShastaInboxClient.Contract.Owner(&_ShastaInboxClient.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_ShastaInboxClient *ShastaInboxClientCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_ShastaInboxClient *ShastaInboxClientSession) Paused() (bool, error) {
	return _ShastaInboxClient.Contract.Paused(&_ShastaInboxClient.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) Paused() (bool, error) {
	return _ShastaInboxClient.Contract.Paused(&_ShastaInboxClient.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_ShastaInboxClient *ShastaInboxClientCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_ShastaInboxClient *ShastaInboxClientSession) PendingOwner() (common.Address, error) {
	return _ShastaInboxClient.Contract.PendingOwner(&_ShastaInboxClient.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) PendingOwner() (common.Address, error) {
	return _ShastaInboxClient.Contract.PendingOwner(&_ShastaInboxClient.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientSession) ProxiableUUID() ([32]byte, error) {
	return _ShastaInboxClient.Contract.ProxiableUUID(&_ShastaInboxClient.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) ProxiableUUID() ([32]byte, error) {
	return _ShastaInboxClient.Contract.ProxiableUUID(&_ShastaInboxClient.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_ShastaInboxClient *ShastaInboxClientCaller) Resolver(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "resolver")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_ShastaInboxClient *ShastaInboxClientSession) Resolver() (common.Address, error) {
	return _ShastaInboxClient.Contract.Resolver(&_ShastaInboxClient.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) Resolver() (common.Address, error) {
	return _ShastaInboxClient.Contract.Resolver(&_ShastaInboxClient.CallOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_ShastaInboxClient *ShastaInboxClientTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ShastaInboxClient.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_ShastaInboxClient *ShastaInboxClientSession) AcceptOwnership() (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.AcceptOwnership(&_ShastaInboxClient.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_ShastaInboxClient *ShastaInboxClientTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.AcceptOwnership(&_ShastaInboxClient.TransactOpts)
}

// Activate is a paid mutator transaction binding the contract method 0x59db6e85.
//
// Solidity: function activate(bytes32 _lastPacayaBlockHash) returns()
func (_ShastaInboxClient *ShastaInboxClientTransactor) Activate(opts *bind.TransactOpts, _lastPacayaBlockHash [32]byte) (*types.Transaction, error) {
	return _ShastaInboxClient.contract.Transact(opts, "activate", _lastPacayaBlockHash)
}

// Activate is a paid mutator transaction binding the contract method 0x59db6e85.
//
// Solidity: function activate(bytes32 _lastPacayaBlockHash) returns()
func (_ShastaInboxClient *ShastaInboxClientSession) Activate(_lastPacayaBlockHash [32]byte) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.Activate(&_ShastaInboxClient.TransactOpts, _lastPacayaBlockHash)
}

// Activate is a paid mutator transaction binding the contract method 0x59db6e85.
//
// Solidity: function activate(bytes32 _lastPacayaBlockHash) returns()
func (_ShastaInboxClient *ShastaInboxClientTransactorSession) Activate(_lastPacayaBlockHash [32]byte) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.Activate(&_ShastaInboxClient.TransactOpts, _lastPacayaBlockHash)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_ShastaInboxClient *ShastaInboxClientTransactor) Init(opts *bind.TransactOpts, _owner common.Address) (*types.Transaction, error) {
	return _ShastaInboxClient.contract.Transact(opts, "init", _owner)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_ShastaInboxClient *ShastaInboxClientSession) Init(_owner common.Address) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.Init(&_ShastaInboxClient.TransactOpts, _owner)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_ShastaInboxClient *ShastaInboxClientTransactorSession) Init(_owner common.Address) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.Init(&_ShastaInboxClient.TransactOpts, _owner)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_ShastaInboxClient *ShastaInboxClientTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ShastaInboxClient.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_ShastaInboxClient *ShastaInboxClientSession) Pause() (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.Pause(&_ShastaInboxClient.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_ShastaInboxClient *ShastaInboxClientTransactorSession) Pause() (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.Pause(&_ShastaInboxClient.TransactOpts)
}

// Propose is a paid mutator transaction binding the contract method 0x9791e644.
//
// Solidity: function propose(bytes _lookahead, bytes _data) returns()
func (_ShastaInboxClient *ShastaInboxClientTransactor) Propose(opts *bind.TransactOpts, _lookahead []byte, _data []byte) (*types.Transaction, error) {
	return _ShastaInboxClient.contract.Transact(opts, "propose", _lookahead, _data)
}

// Propose is a paid mutator transaction binding the contract method 0x9791e644.
//
// Solidity: function propose(bytes _lookahead, bytes _data) returns()
func (_ShastaInboxClient *ShastaInboxClientSession) Propose(_lookahead []byte, _data []byte) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.Propose(&_ShastaInboxClient.TransactOpts, _lookahead, _data)
}

// Propose is a paid mutator transaction binding the contract method 0x9791e644.
//
// Solidity: function propose(bytes _lookahead, bytes _data) returns()
func (_ShastaInboxClient *ShastaInboxClientTransactorSession) Propose(_lookahead []byte, _data []byte) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.Propose(&_ShastaInboxClient.TransactOpts, _lookahead, _data)
}

// Prove is a paid mutator transaction binding the contract method 0xea191743.
//
// Solidity: function prove(bytes _data, bytes _proof) returns()
func (_ShastaInboxClient *ShastaInboxClientTransactor) Prove(opts *bind.TransactOpts, _data []byte, _proof []byte) (*types.Transaction, error) {
	return _ShastaInboxClient.contract.Transact(opts, "prove", _data, _proof)
}

// Prove is a paid mutator transaction binding the contract method 0xea191743.
//
// Solidity: function prove(bytes _data, bytes _proof) returns()
func (_ShastaInboxClient *ShastaInboxClientSession) Prove(_data []byte, _proof []byte) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.Prove(&_ShastaInboxClient.TransactOpts, _data, _proof)
}

// Prove is a paid mutator transaction binding the contract method 0xea191743.
//
// Solidity: function prove(bytes _data, bytes _proof) returns()
func (_ShastaInboxClient *ShastaInboxClientTransactorSession) Prove(_data []byte, _proof []byte) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.Prove(&_ShastaInboxClient.TransactOpts, _data, _proof)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ShastaInboxClient *ShastaInboxClientTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ShastaInboxClient.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ShastaInboxClient *ShastaInboxClientSession) RenounceOwnership() (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.RenounceOwnership(&_ShastaInboxClient.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ShastaInboxClient *ShastaInboxClientTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.RenounceOwnership(&_ShastaInboxClient.TransactOpts)
}

// SaveForcedInclusion is a paid mutator transaction binding the contract method 0xdf596d9e.
//
// Solidity: function saveForcedInclusion((uint16,uint16,uint24) _blobReference) payable returns()
func (_ShastaInboxClient *ShastaInboxClientTransactor) SaveForcedInclusion(opts *bind.TransactOpts, _blobReference LibBlobsBlobReference) (*types.Transaction, error) {
	return _ShastaInboxClient.contract.Transact(opts, "saveForcedInclusion", _blobReference)
}

// SaveForcedInclusion is a paid mutator transaction binding the contract method 0xdf596d9e.
//
// Solidity: function saveForcedInclusion((uint16,uint16,uint24) _blobReference) payable returns()
func (_ShastaInboxClient *ShastaInboxClientSession) SaveForcedInclusion(_blobReference LibBlobsBlobReference) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.SaveForcedInclusion(&_ShastaInboxClient.TransactOpts, _blobReference)
}

// SaveForcedInclusion is a paid mutator transaction binding the contract method 0xdf596d9e.
//
// Solidity: function saveForcedInclusion((uint16,uint16,uint24) _blobReference) payable returns()
func (_ShastaInboxClient *ShastaInboxClientTransactorSession) SaveForcedInclusion(_blobReference LibBlobsBlobReference) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.SaveForcedInclusion(&_ShastaInboxClient.TransactOpts, _blobReference)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ShastaInboxClient *ShastaInboxClientTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _ShastaInboxClient.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ShastaInboxClient *ShastaInboxClientSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.TransferOwnership(&_ShastaInboxClient.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ShastaInboxClient *ShastaInboxClientTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.TransferOwnership(&_ShastaInboxClient.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_ShastaInboxClient *ShastaInboxClientTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ShastaInboxClient.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_ShastaInboxClient *ShastaInboxClientSession) Unpause() (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.Unpause(&_ShastaInboxClient.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_ShastaInboxClient *ShastaInboxClientTransactorSession) Unpause() (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.Unpause(&_ShastaInboxClient.TransactOpts)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_ShastaInboxClient *ShastaInboxClientTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _ShastaInboxClient.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_ShastaInboxClient *ShastaInboxClientSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.UpgradeTo(&_ShastaInboxClient.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_ShastaInboxClient *ShastaInboxClientTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.UpgradeTo(&_ShastaInboxClient.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_ShastaInboxClient *ShastaInboxClientTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _ShastaInboxClient.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_ShastaInboxClient *ShastaInboxClientSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.UpgradeToAndCall(&_ShastaInboxClient.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_ShastaInboxClient *ShastaInboxClientTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.UpgradeToAndCall(&_ShastaInboxClient.TransactOpts, newImplementation, data)
}

// ShastaInboxClientAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the ShastaInboxClient contract.
type ShastaInboxClientAdminChangedIterator struct {
	Event *ShastaInboxClientAdminChanged // Event containing the contract specifics and raw log

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
func (it *ShastaInboxClientAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaInboxClientAdminChanged)
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
		it.Event = new(ShastaInboxClientAdminChanged)
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
func (it *ShastaInboxClientAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaInboxClientAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaInboxClientAdminChanged represents a AdminChanged event raised by the ShastaInboxClient contract.
type ShastaInboxClientAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_ShastaInboxClient *ShastaInboxClientFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*ShastaInboxClientAdminChangedIterator, error) {

	logs, sub, err := _ShastaInboxClient.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &ShastaInboxClientAdminChangedIterator{contract: _ShastaInboxClient.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_ShastaInboxClient *ShastaInboxClientFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *ShastaInboxClientAdminChanged) (event.Subscription, error) {

	logs, sub, err := _ShastaInboxClient.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaInboxClientAdminChanged)
				if err := _ShastaInboxClient.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_ShastaInboxClient *ShastaInboxClientFilterer) ParseAdminChanged(log types.Log) (*ShastaInboxClientAdminChanged, error) {
	event := new(ShastaInboxClientAdminChanged)
	if err := _ShastaInboxClient.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ShastaInboxClientBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the ShastaInboxClient contract.
type ShastaInboxClientBeaconUpgradedIterator struct {
	Event *ShastaInboxClientBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *ShastaInboxClientBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaInboxClientBeaconUpgraded)
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
		it.Event = new(ShastaInboxClientBeaconUpgraded)
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
func (it *ShastaInboxClientBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaInboxClientBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaInboxClientBeaconUpgraded represents a BeaconUpgraded event raised by the ShastaInboxClient contract.
type ShastaInboxClientBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_ShastaInboxClient *ShastaInboxClientFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*ShastaInboxClientBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _ShastaInboxClient.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &ShastaInboxClientBeaconUpgradedIterator{contract: _ShastaInboxClient.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_ShastaInboxClient *ShastaInboxClientFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *ShastaInboxClientBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _ShastaInboxClient.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaInboxClientBeaconUpgraded)
				if err := _ShastaInboxClient.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_ShastaInboxClient *ShastaInboxClientFilterer) ParseBeaconUpgraded(log types.Log) (*ShastaInboxClientBeaconUpgraded, error) {
	event := new(ShastaInboxClientBeaconUpgraded)
	if err := _ShastaInboxClient.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ShastaInboxClientBondInstructionCreatedIterator is returned from FilterBondInstructionCreated and is used to iterate over the raw logs and unpacked data for BondInstructionCreated events raised by the ShastaInboxClient contract.
type ShastaInboxClientBondInstructionCreatedIterator struct {
	Event *ShastaInboxClientBondInstructionCreated // Event containing the contract specifics and raw log

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
func (it *ShastaInboxClientBondInstructionCreatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaInboxClientBondInstructionCreated)
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
		it.Event = new(ShastaInboxClientBondInstructionCreated)
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
func (it *ShastaInboxClientBondInstructionCreatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaInboxClientBondInstructionCreatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaInboxClientBondInstructionCreated represents a BondInstructionCreated event raised by the ShastaInboxClient contract.
type ShastaInboxClientBondInstructionCreated struct {
	ProposalId      *big.Int
	BondInstruction LibBondsBondInstruction
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterBondInstructionCreated is a free log retrieval operation binding the contract event 0x8796b99bbf275a983988181e85b42502d9347327f4dde674320bec3879bcc5e1.
//
// Solidity: event BondInstructionCreated(uint48 indexed proposalId, (uint48,uint8,address,address) bondInstruction)
func (_ShastaInboxClient *ShastaInboxClientFilterer) FilterBondInstructionCreated(opts *bind.FilterOpts, proposalId []*big.Int) (*ShastaInboxClientBondInstructionCreatedIterator, error) {

	var proposalIdRule []interface{}
	for _, proposalIdItem := range proposalId {
		proposalIdRule = append(proposalIdRule, proposalIdItem)
	}

	logs, sub, err := _ShastaInboxClient.contract.FilterLogs(opts, "BondInstructionCreated", proposalIdRule)
	if err != nil {
		return nil, err
	}
	return &ShastaInboxClientBondInstructionCreatedIterator{contract: _ShastaInboxClient.contract, event: "BondInstructionCreated", logs: logs, sub: sub}, nil
}

// WatchBondInstructionCreated is a free log subscription operation binding the contract event 0x8796b99bbf275a983988181e85b42502d9347327f4dde674320bec3879bcc5e1.
//
// Solidity: event BondInstructionCreated(uint48 indexed proposalId, (uint48,uint8,address,address) bondInstruction)
func (_ShastaInboxClient *ShastaInboxClientFilterer) WatchBondInstructionCreated(opts *bind.WatchOpts, sink chan<- *ShastaInboxClientBondInstructionCreated, proposalId []*big.Int) (event.Subscription, error) {

	var proposalIdRule []interface{}
	for _, proposalIdItem := range proposalId {
		proposalIdRule = append(proposalIdRule, proposalIdItem)
	}

	logs, sub, err := _ShastaInboxClient.contract.WatchLogs(opts, "BondInstructionCreated", proposalIdRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaInboxClientBondInstructionCreated)
				if err := _ShastaInboxClient.contract.UnpackLog(event, "BondInstructionCreated", log); err != nil {
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

// ParseBondInstructionCreated is a log parse operation binding the contract event 0x8796b99bbf275a983988181e85b42502d9347327f4dde674320bec3879bcc5e1.
//
// Solidity: event BondInstructionCreated(uint48 indexed proposalId, (uint48,uint8,address,address) bondInstruction)
func (_ShastaInboxClient *ShastaInboxClientFilterer) ParseBondInstructionCreated(log types.Log) (*ShastaInboxClientBondInstructionCreated, error) {
	event := new(ShastaInboxClientBondInstructionCreated)
	if err := _ShastaInboxClient.contract.UnpackLog(event, "BondInstructionCreated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ShastaInboxClientForcedInclusionSavedIterator is returned from FilterForcedInclusionSaved and is used to iterate over the raw logs and unpacked data for ForcedInclusionSaved events raised by the ShastaInboxClient contract.
type ShastaInboxClientForcedInclusionSavedIterator struct {
	Event *ShastaInboxClientForcedInclusionSaved // Event containing the contract specifics and raw log

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
func (it *ShastaInboxClientForcedInclusionSavedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaInboxClientForcedInclusionSaved)
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
		it.Event = new(ShastaInboxClientForcedInclusionSaved)
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
func (it *ShastaInboxClientForcedInclusionSavedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaInboxClientForcedInclusionSavedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaInboxClientForcedInclusionSaved represents a ForcedInclusionSaved event raised by the ShastaInboxClient contract.
type ShastaInboxClientForcedInclusionSaved struct {
	ForcedInclusion IForcedInclusionStoreForcedInclusion
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterForcedInclusionSaved is a free log retrieval operation binding the contract event 0x18c4fc1e6ac628dbb537b0375bf0efabf1ff2528af1ec22faa74d2da95c29471.
//
// Solidity: event ForcedInclusionSaved((uint64,(bytes32[],uint24,uint48)) forcedInclusion)
func (_ShastaInboxClient *ShastaInboxClientFilterer) FilterForcedInclusionSaved(opts *bind.FilterOpts) (*ShastaInboxClientForcedInclusionSavedIterator, error) {

	logs, sub, err := _ShastaInboxClient.contract.FilterLogs(opts, "ForcedInclusionSaved")
	if err != nil {
		return nil, err
	}
	return &ShastaInboxClientForcedInclusionSavedIterator{contract: _ShastaInboxClient.contract, event: "ForcedInclusionSaved", logs: logs, sub: sub}, nil
}

// WatchForcedInclusionSaved is a free log subscription operation binding the contract event 0x18c4fc1e6ac628dbb537b0375bf0efabf1ff2528af1ec22faa74d2da95c29471.
//
// Solidity: event ForcedInclusionSaved((uint64,(bytes32[],uint24,uint48)) forcedInclusion)
func (_ShastaInboxClient *ShastaInboxClientFilterer) WatchForcedInclusionSaved(opts *bind.WatchOpts, sink chan<- *ShastaInboxClientForcedInclusionSaved) (event.Subscription, error) {

	logs, sub, err := _ShastaInboxClient.contract.WatchLogs(opts, "ForcedInclusionSaved")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaInboxClientForcedInclusionSaved)
				if err := _ShastaInboxClient.contract.UnpackLog(event, "ForcedInclusionSaved", log); err != nil {
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
func (_ShastaInboxClient *ShastaInboxClientFilterer) ParseForcedInclusionSaved(log types.Log) (*ShastaInboxClientForcedInclusionSaved, error) {
	event := new(ShastaInboxClientForcedInclusionSaved)
	if err := _ShastaInboxClient.contract.UnpackLog(event, "ForcedInclusionSaved", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ShastaInboxClientInboxActivatedIterator is returned from FilterInboxActivated and is used to iterate over the raw logs and unpacked data for InboxActivated events raised by the ShastaInboxClient contract.
type ShastaInboxClientInboxActivatedIterator struct {
	Event *ShastaInboxClientInboxActivated // Event containing the contract specifics and raw log

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
func (it *ShastaInboxClientInboxActivatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaInboxClientInboxActivated)
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
		it.Event = new(ShastaInboxClientInboxActivated)
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
func (it *ShastaInboxClientInboxActivatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaInboxClientInboxActivatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaInboxClientInboxActivated represents a InboxActivated event raised by the ShastaInboxClient contract.
type ShastaInboxClientInboxActivated struct {
	LastPacayaBlockHash [32]byte
	Raw                 types.Log // Blockchain specific contextual infos
}

// FilterInboxActivated is a free log retrieval operation binding the contract event 0xe4356761c97932c05c3ee0859fb1a5e4f91f7a1d7a3752c7d5a72d5cc6ecb2d2.
//
// Solidity: event InboxActivated(bytes32 lastPacayaBlockHash)
func (_ShastaInboxClient *ShastaInboxClientFilterer) FilterInboxActivated(opts *bind.FilterOpts) (*ShastaInboxClientInboxActivatedIterator, error) {

	logs, sub, err := _ShastaInboxClient.contract.FilterLogs(opts, "InboxActivated")
	if err != nil {
		return nil, err
	}
	return &ShastaInboxClientInboxActivatedIterator{contract: _ShastaInboxClient.contract, event: "InboxActivated", logs: logs, sub: sub}, nil
}

// WatchInboxActivated is a free log subscription operation binding the contract event 0xe4356761c97932c05c3ee0859fb1a5e4f91f7a1d7a3752c7d5a72d5cc6ecb2d2.
//
// Solidity: event InboxActivated(bytes32 lastPacayaBlockHash)
func (_ShastaInboxClient *ShastaInboxClientFilterer) WatchInboxActivated(opts *bind.WatchOpts, sink chan<- *ShastaInboxClientInboxActivated) (event.Subscription, error) {

	logs, sub, err := _ShastaInboxClient.contract.WatchLogs(opts, "InboxActivated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaInboxClientInboxActivated)
				if err := _ShastaInboxClient.contract.UnpackLog(event, "InboxActivated", log); err != nil {
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
func (_ShastaInboxClient *ShastaInboxClientFilterer) ParseInboxActivated(log types.Log) (*ShastaInboxClientInboxActivated, error) {
	event := new(ShastaInboxClientInboxActivated)
	if err := _ShastaInboxClient.contract.UnpackLog(event, "InboxActivated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ShastaInboxClientInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the ShastaInboxClient contract.
type ShastaInboxClientInitializedIterator struct {
	Event *ShastaInboxClientInitialized // Event containing the contract specifics and raw log

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
func (it *ShastaInboxClientInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaInboxClientInitialized)
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
		it.Event = new(ShastaInboxClientInitialized)
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
func (it *ShastaInboxClientInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaInboxClientInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaInboxClientInitialized represents a Initialized event raised by the ShastaInboxClient contract.
type ShastaInboxClientInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_ShastaInboxClient *ShastaInboxClientFilterer) FilterInitialized(opts *bind.FilterOpts) (*ShastaInboxClientInitializedIterator, error) {

	logs, sub, err := _ShastaInboxClient.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &ShastaInboxClientInitializedIterator{contract: _ShastaInboxClient.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_ShastaInboxClient *ShastaInboxClientFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *ShastaInboxClientInitialized) (event.Subscription, error) {

	logs, sub, err := _ShastaInboxClient.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaInboxClientInitialized)
				if err := _ShastaInboxClient.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_ShastaInboxClient *ShastaInboxClientFilterer) ParseInitialized(log types.Log) (*ShastaInboxClientInitialized, error) {
	event := new(ShastaInboxClientInitialized)
	if err := _ShastaInboxClient.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ShastaInboxClientOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the ShastaInboxClient contract.
type ShastaInboxClientOwnershipTransferStartedIterator struct {
	Event *ShastaInboxClientOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *ShastaInboxClientOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaInboxClientOwnershipTransferStarted)
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
		it.Event = new(ShastaInboxClientOwnershipTransferStarted)
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
func (it *ShastaInboxClientOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaInboxClientOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaInboxClientOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the ShastaInboxClient contract.
type ShastaInboxClientOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_ShastaInboxClient *ShastaInboxClientFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*ShastaInboxClientOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ShastaInboxClient.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &ShastaInboxClientOwnershipTransferStartedIterator{contract: _ShastaInboxClient.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_ShastaInboxClient *ShastaInboxClientFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *ShastaInboxClientOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ShastaInboxClient.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaInboxClientOwnershipTransferStarted)
				if err := _ShastaInboxClient.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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
func (_ShastaInboxClient *ShastaInboxClientFilterer) ParseOwnershipTransferStarted(log types.Log) (*ShastaInboxClientOwnershipTransferStarted, error) {
	event := new(ShastaInboxClientOwnershipTransferStarted)
	if err := _ShastaInboxClient.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ShastaInboxClientOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the ShastaInboxClient contract.
type ShastaInboxClientOwnershipTransferredIterator struct {
	Event *ShastaInboxClientOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *ShastaInboxClientOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaInboxClientOwnershipTransferred)
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
		it.Event = new(ShastaInboxClientOwnershipTransferred)
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
func (it *ShastaInboxClientOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaInboxClientOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaInboxClientOwnershipTransferred represents a OwnershipTransferred event raised by the ShastaInboxClient contract.
type ShastaInboxClientOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_ShastaInboxClient *ShastaInboxClientFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*ShastaInboxClientOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ShastaInboxClient.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &ShastaInboxClientOwnershipTransferredIterator{contract: _ShastaInboxClient.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_ShastaInboxClient *ShastaInboxClientFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *ShastaInboxClientOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ShastaInboxClient.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaInboxClientOwnershipTransferred)
				if err := _ShastaInboxClient.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_ShastaInboxClient *ShastaInboxClientFilterer) ParseOwnershipTransferred(log types.Log) (*ShastaInboxClientOwnershipTransferred, error) {
	event := new(ShastaInboxClientOwnershipTransferred)
	if err := _ShastaInboxClient.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ShastaInboxClientPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the ShastaInboxClient contract.
type ShastaInboxClientPausedIterator struct {
	Event *ShastaInboxClientPaused // Event containing the contract specifics and raw log

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
func (it *ShastaInboxClientPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaInboxClientPaused)
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
		it.Event = new(ShastaInboxClientPaused)
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
func (it *ShastaInboxClientPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaInboxClientPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaInboxClientPaused represents a Paused event raised by the ShastaInboxClient contract.
type ShastaInboxClientPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_ShastaInboxClient *ShastaInboxClientFilterer) FilterPaused(opts *bind.FilterOpts) (*ShastaInboxClientPausedIterator, error) {

	logs, sub, err := _ShastaInboxClient.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &ShastaInboxClientPausedIterator{contract: _ShastaInboxClient.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_ShastaInboxClient *ShastaInboxClientFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *ShastaInboxClientPaused) (event.Subscription, error) {

	logs, sub, err := _ShastaInboxClient.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaInboxClientPaused)
				if err := _ShastaInboxClient.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_ShastaInboxClient *ShastaInboxClientFilterer) ParsePaused(log types.Log) (*ShastaInboxClientPaused, error) {
	event := new(ShastaInboxClientPaused)
	if err := _ShastaInboxClient.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ShastaInboxClientProposedIterator is returned from FilterProposed and is used to iterate over the raw logs and unpacked data for Proposed events raised by the ShastaInboxClient contract.
type ShastaInboxClientProposedIterator struct {
	Event *ShastaInboxClientProposed // Event containing the contract specifics and raw log

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
func (it *ShastaInboxClientProposedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaInboxClientProposed)
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
		it.Event = new(ShastaInboxClientProposed)
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
func (it *ShastaInboxClientProposedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaInboxClientProposedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaInboxClientProposed represents a Proposed event raised by the ShastaInboxClient contract.
type ShastaInboxClientProposed struct {
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
func (_ShastaInboxClient *ShastaInboxClientFilterer) FilterProposed(opts *bind.FilterOpts, id []*big.Int, proposer []common.Address) (*ShastaInboxClientProposedIterator, error) {

	var idRule []interface{}
	for _, idItem := range id {
		idRule = append(idRule, idItem)
	}
	var proposerRule []interface{}
	for _, proposerItem := range proposer {
		proposerRule = append(proposerRule, proposerItem)
	}

	logs, sub, err := _ShastaInboxClient.contract.FilterLogs(opts, "Proposed", idRule, proposerRule)
	if err != nil {
		return nil, err
	}
	return &ShastaInboxClientProposedIterator{contract: _ShastaInboxClient.contract, event: "Proposed", logs: logs, sub: sub}, nil
}

// WatchProposed is a free log subscription operation binding the contract event 0x7c4c4523e17533e451df15762a093e0693a2cd8b279fe54c6cd3777ed5771213.
//
// Solidity: event Proposed(uint48 indexed id, address indexed proposer, bytes32 parentProposalHash, uint48 endOfSubmissionWindowTimestamp, uint8 basefeeSharingPctg, (bool,(bytes32[],uint24,uint48))[] sources)
func (_ShastaInboxClient *ShastaInboxClientFilterer) WatchProposed(opts *bind.WatchOpts, sink chan<- *ShastaInboxClientProposed, id []*big.Int, proposer []common.Address) (event.Subscription, error) {

	var idRule []interface{}
	for _, idItem := range id {
		idRule = append(idRule, idItem)
	}
	var proposerRule []interface{}
	for _, proposerItem := range proposer {
		proposerRule = append(proposerRule, proposerItem)
	}

	logs, sub, err := _ShastaInboxClient.contract.WatchLogs(opts, "Proposed", idRule, proposerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaInboxClientProposed)
				if err := _ShastaInboxClient.contract.UnpackLog(event, "Proposed", log); err != nil {
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
func (_ShastaInboxClient *ShastaInboxClientFilterer) ParseProposed(log types.Log) (*ShastaInboxClientProposed, error) {
	event := new(ShastaInboxClientProposed)
	if err := _ShastaInboxClient.contract.UnpackLog(event, "Proposed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ShastaInboxClientProvedIterator is returned from FilterProved and is used to iterate over the raw logs and unpacked data for Proved events raised by the ShastaInboxClient contract.
type ShastaInboxClientProvedIterator struct {
	Event *ShastaInboxClientProved // Event containing the contract specifics and raw log

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
func (it *ShastaInboxClientProvedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaInboxClientProved)
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
		it.Event = new(ShastaInboxClientProved)
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
func (it *ShastaInboxClientProvedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaInboxClientProvedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaInboxClientProved represents a Proved event raised by the ShastaInboxClient contract.
type ShastaInboxClientProved struct {
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
func (_ShastaInboxClient *ShastaInboxClientFilterer) FilterProved(opts *bind.FilterOpts, actualProver []common.Address) (*ShastaInboxClientProvedIterator, error) {

	var actualProverRule []interface{}
	for _, actualProverItem := range actualProver {
		actualProverRule = append(actualProverRule, actualProverItem)
	}

	logs, sub, err := _ShastaInboxClient.contract.FilterLogs(opts, "Proved", actualProverRule)
	if err != nil {
		return nil, err
	}
	return &ShastaInboxClientProvedIterator{contract: _ShastaInboxClient.contract, event: "Proved", logs: logs, sub: sub}, nil
}

// WatchProved is a free log subscription operation binding the contract event 0x7ca0f1e30099488c4ee24e86a6b2c6802e9add6d530919af7aa17db3bcc1cff1.
//
// Solidity: event Proved(uint48 firstProposalId, uint48 firstNewProposalId, uint48 lastProposalId, address indexed actualProver, bool checkpointSynced)
func (_ShastaInboxClient *ShastaInboxClientFilterer) WatchProved(opts *bind.WatchOpts, sink chan<- *ShastaInboxClientProved, actualProver []common.Address) (event.Subscription, error) {

	var actualProverRule []interface{}
	for _, actualProverItem := range actualProver {
		actualProverRule = append(actualProverRule, actualProverItem)
	}

	logs, sub, err := _ShastaInboxClient.contract.WatchLogs(opts, "Proved", actualProverRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaInboxClientProved)
				if err := _ShastaInboxClient.contract.UnpackLog(event, "Proved", log); err != nil {
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
func (_ShastaInboxClient *ShastaInboxClientFilterer) ParseProved(log types.Log) (*ShastaInboxClientProved, error) {
	event := new(ShastaInboxClientProved)
	if err := _ShastaInboxClient.contract.UnpackLog(event, "Proved", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ShastaInboxClientUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the ShastaInboxClient contract.
type ShastaInboxClientUnpausedIterator struct {
	Event *ShastaInboxClientUnpaused // Event containing the contract specifics and raw log

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
func (it *ShastaInboxClientUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaInboxClientUnpaused)
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
		it.Event = new(ShastaInboxClientUnpaused)
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
func (it *ShastaInboxClientUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaInboxClientUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaInboxClientUnpaused represents a Unpaused event raised by the ShastaInboxClient contract.
type ShastaInboxClientUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_ShastaInboxClient *ShastaInboxClientFilterer) FilterUnpaused(opts *bind.FilterOpts) (*ShastaInboxClientUnpausedIterator, error) {

	logs, sub, err := _ShastaInboxClient.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &ShastaInboxClientUnpausedIterator{contract: _ShastaInboxClient.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_ShastaInboxClient *ShastaInboxClientFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *ShastaInboxClientUnpaused) (event.Subscription, error) {

	logs, sub, err := _ShastaInboxClient.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaInboxClientUnpaused)
				if err := _ShastaInboxClient.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_ShastaInboxClient *ShastaInboxClientFilterer) ParseUnpaused(log types.Log) (*ShastaInboxClientUnpaused, error) {
	event := new(ShastaInboxClientUnpaused)
	if err := _ShastaInboxClient.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ShastaInboxClientUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the ShastaInboxClient contract.
type ShastaInboxClientUpgradedIterator struct {
	Event *ShastaInboxClientUpgraded // Event containing the contract specifics and raw log

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
func (it *ShastaInboxClientUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaInboxClientUpgraded)
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
		it.Event = new(ShastaInboxClientUpgraded)
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
func (it *ShastaInboxClientUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaInboxClientUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaInboxClientUpgraded represents a Upgraded event raised by the ShastaInboxClient contract.
type ShastaInboxClientUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_ShastaInboxClient *ShastaInboxClientFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*ShastaInboxClientUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _ShastaInboxClient.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &ShastaInboxClientUpgradedIterator{contract: _ShastaInboxClient.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_ShastaInboxClient *ShastaInboxClientFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *ShastaInboxClientUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _ShastaInboxClient.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaInboxClientUpgraded)
				if err := _ShastaInboxClient.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_ShastaInboxClient *ShastaInboxClientFilterer) ParseUpgraded(log types.Log) (*ShastaInboxClientUpgraded, error) {
	event := new(ShastaInboxClientUpgraded)
	if err := _ShastaInboxClient.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
