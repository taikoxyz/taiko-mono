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

// ICheckpointManagerCheckpoint is an auto generated low-level Go binding around an user-defined struct.
type ICheckpointManagerCheckpoint struct {
	BlockNumber *big.Int
	BlockHash   [32]byte
	StateRoot   [32]byte
}

// IForcedInclusionStoreForcedInclusion is an auto generated low-level Go binding around an user-defined struct.
type IForcedInclusionStoreForcedInclusion struct {
	FeeInGwei uint64
	BlobSlice LibBlobsBlobSlice
}

// IInboxConfig is an auto generated low-level Go binding around an user-defined struct.
type IInboxConfig struct {
	BondToken                common.Address
	CheckpointManager        common.Address
	ProofVerifier            common.Address
	ProposerChecker          common.Address
	ProvingWindow            *big.Int
	ExtendedProvingWindow    *big.Int
	MaxFinalizationCount     *big.Int
	FinalizationGracePeriod  *big.Int
	RingBufferSize           *big.Int
	BasefeeSharingPctg       uint8
	MinForcedInclusionCount  *big.Int
	ForcedInclusionDelay     uint64
	ForcedInclusionFeeInGwei uint64
}

// IInboxCoreState is an auto generated low-level Go binding around an user-defined struct.
type IInboxCoreState struct {
	NextProposalId              *big.Int
	LastFinalizedProposalId     *big.Int
	LastFinalizedTransitionHash [32]byte
	BondInstructionsHash        [32]byte
}

// IInboxDerivation is an auto generated low-level Go binding around an user-defined struct.
type IInboxDerivation struct {
	OriginBlockNumber  *big.Int
	OriginBlockHash    [32]byte
	IsForcedInclusion  bool
	BasefeeSharingPctg uint8
	BlobSlice          LibBlobsBlobSlice
}

// IInboxProposal is an auto generated low-level Go binding around an user-defined struct.
type IInboxProposal struct {
	Id                             *big.Int
	Timestamp                      *big.Int
	EndOfSubmissionWindowTimestamp *big.Int
	Proposer                       common.Address
	CoreStateHash                  [32]byte
	DerivationHash                 [32]byte
}

// IInboxProposeInput is an auto generated low-level Go binding around an user-defined struct.
type IInboxProposeInput struct {
	Deadline            *big.Int
	CoreState           IInboxCoreState
	ParentProposals     []IInboxProposal
	BlobReference       LibBlobsBlobReference
	TransitionRecords   []IInboxTransitionRecord
	Checkpoint          ICheckpointManagerCheckpoint
	NumForcedInclusions uint8
}

// IInboxProposedEventPayload is an auto generated low-level Go binding around an user-defined struct.
type IInboxProposedEventPayload struct {
	Proposal   IInboxProposal
	Derivation IInboxDerivation
	CoreState  IInboxCoreState
}

// IInboxProveInput is an auto generated low-level Go binding around an user-defined struct.
type IInboxProveInput struct {
	Proposals   []IInboxProposal
	Transitions []IInboxTransition
	Metadata    []IInboxTransitionMetadata
}

// IInboxProvedEventPayload is an auto generated low-level Go binding around an user-defined struct.
type IInboxProvedEventPayload struct {
	ProposalId       *big.Int
	Transition       IInboxTransition
	TransitionRecord IInboxTransitionRecord
	Metadata         IInboxTransitionMetadata
}

// IInboxTransition is an auto generated low-level Go binding around an user-defined struct.
type IInboxTransition struct {
	ProposalHash         [32]byte
	ParentTransitionHash [32]byte
	Checkpoint           ICheckpointManagerCheckpoint
}

// IInboxTransitionMetadata is an auto generated low-level Go binding around an user-defined struct.
type IInboxTransitionMetadata struct {
	DesignatedProver common.Address
	ActualProver     common.Address
}

// IInboxTransitionRecord is an auto generated low-level Go binding around an user-defined struct.
type IInboxTransitionRecord struct {
	Span             uint8
	BondInstructions []LibBondsBondInstruction
	TransitionHash   [32]byte
	CheckpointHash   [32]byte
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
	Receiver   common.Address
}

// ShastaInboxClientMetaData contains all meta data concerning the ShastaInboxClient contract.
var ShastaInboxClientMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"_checkpointManager\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_proofVerifier\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_proposerChecker\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"bondBalance\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"bond\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"decodeProposeInput\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProposeInput\",\"components\":[{\"name\":\"deadline\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"coreState\",\"type\":\"tuple\",\"internalType\":\"structIInbox.CoreState\",\"components\":[{\"name\":\"nextProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"bondInstructionsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"parentProposals\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Proposal[]\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"coreStateHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"blobReference\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobReference\",\"components\":[{\"name\":\"blobStartIndex\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"numBlobs\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"}]},{\"name\":\"transitionRecords\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.TransitionRecord[]\",\"components\":[{\"name\":\"span\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"bondInstructions\",\"type\":\"tuple[]\",\"internalType\":\"structLibBonds.BondInstruction[]\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"bondType\",\"type\":\"uint8\",\"internalType\":\"enumLibBonds.BondType\"},{\"name\":\"payer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"receiver\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"transitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpointHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointManager.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"numForcedInclusions\",\"type\":\"uint8\",\"internalType\":\"uint8\"}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"decodeProposedEventData\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProposedEventPayload\",\"components\":[{\"name\":\"proposal\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Proposal\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"coreStateHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"derivation\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Derivation\",\"components\":[{\"name\":\"originBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"originBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"isForcedInclusion\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]},{\"name\":\"coreState\",\"type\":\"tuple\",\"internalType\":\"structIInbox.CoreState\",\"components\":[{\"name\":\"nextProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"bondInstructionsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"decodeProveInput\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProveInput\",\"components\":[{\"name\":\"proposals\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Proposal[]\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"coreStateHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"transitions\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Transition[]\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointManager.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]},{\"name\":\"metadata\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.TransitionMetadata[]\",\"components\":[{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"}]}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"decodeProvedEventData\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProvedEventPayload\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"transition\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Transition\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointManager.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]},{\"name\":\"transitionRecord\",\"type\":\"tuple\",\"internalType\":\"structIInbox.TransitionRecord\",\"components\":[{\"name\":\"span\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"bondInstructions\",\"type\":\"tuple[]\",\"internalType\":\"structLibBonds.BondInstruction[]\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"bondType\",\"type\":\"uint8\",\"internalType\":\"enumLibBonds.BondType\"},{\"name\":\"payer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"receiver\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"transitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpointHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"metadata\",\"type\":\"tuple\",\"internalType\":\"structIInbox.TransitionMetadata\",\"components\":[{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"}]}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"encodeProposeInput\",\"inputs\":[{\"name\":\"_input\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProposeInput\",\"components\":[{\"name\":\"deadline\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"coreState\",\"type\":\"tuple\",\"internalType\":\"structIInbox.CoreState\",\"components\":[{\"name\":\"nextProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"bondInstructionsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"parentProposals\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Proposal[]\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"coreStateHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"blobReference\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobReference\",\"components\":[{\"name\":\"blobStartIndex\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"numBlobs\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"}]},{\"name\":\"transitionRecords\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.TransitionRecord[]\",\"components\":[{\"name\":\"span\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"bondInstructions\",\"type\":\"tuple[]\",\"internalType\":\"structLibBonds.BondInstruction[]\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"bondType\",\"type\":\"uint8\",\"internalType\":\"enumLibBonds.BondType\"},{\"name\":\"payer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"receiver\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"transitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpointHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointManager.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"numForcedInclusions\",\"type\":\"uint8\",\"internalType\":\"uint8\"}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"encodeProposedEventData\",\"inputs\":[{\"name\":\"_payload\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProposedEventPayload\",\"components\":[{\"name\":\"proposal\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Proposal\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"coreStateHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"derivation\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Derivation\",\"components\":[{\"name\":\"originBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"originBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"isForcedInclusion\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]},{\"name\":\"coreState\",\"type\":\"tuple\",\"internalType\":\"structIInbox.CoreState\",\"components\":[{\"name\":\"nextProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"bondInstructionsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"encodeProposedEventPayload\",\"inputs\":[{\"name\":\"_payload\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProposedEventPayload\",\"components\":[{\"name\":\"proposal\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Proposal\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"coreStateHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"derivation\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Derivation\",\"components\":[{\"name\":\"originBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"originBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"isForcedInclusion\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]},{\"name\":\"coreState\",\"type\":\"tuple\",\"internalType\":\"structIInbox.CoreState\",\"components\":[{\"name\":\"nextProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"bondInstructionsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"encodeProveInput\",\"inputs\":[{\"name\":\"_input\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProveInput\",\"components\":[{\"name\":\"proposals\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Proposal[]\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"coreStateHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"transitions\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Transition[]\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointManager.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]},{\"name\":\"metadata\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.TransitionMetadata[]\",\"components\":[{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"}]}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"encodeProvedEventData\",\"inputs\":[{\"name\":\"_payload\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProvedEventPayload\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"transition\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Transition\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointManager.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]},{\"name\":\"transitionRecord\",\"type\":\"tuple\",\"internalType\":\"structIInbox.TransitionRecord\",\"components\":[{\"name\":\"span\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"bondInstructions\",\"type\":\"tuple[]\",\"internalType\":\"structLibBonds.BondInstruction[]\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"bondType\",\"type\":\"uint8\",\"internalType\":\"enumLibBonds.BondType\"},{\"name\":\"payer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"receiver\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"transitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpointHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"metadata\",\"type\":\"tuple\",\"internalType\":\"structIInbox.TransitionMetadata\",\"components\":[{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"}]}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"encodeProvedEventPayload\",\"inputs\":[{\"name\":\"_payload\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProvedEventPayload\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"transition\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Transition\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointManager.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]},{\"name\":\"transitionRecord\",\"type\":\"tuple\",\"internalType\":\"structIInbox.TransitionRecord\",\"components\":[{\"name\":\"span\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"bondInstructions\",\"type\":\"tuple[]\",\"internalType\":\"structLibBonds.BondInstruction[]\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"bondType\",\"type\":\"uint8\",\"internalType\":\"enumLibBonds.BondType\"},{\"name\":\"payer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"receiver\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"transitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpointHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"metadata\",\"type\":\"tuple\",\"internalType\":\"structIInbox.TransitionMetadata\",\"components\":[{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"}]}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getConfig\",\"inputs\":[],\"outputs\":[{\"name\":\"config_\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Config\",\"components\":[{\"name\":\"bondToken\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"checkpointManager\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"proofVerifier\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"proposerChecker\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"provingWindow\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"extendedProvingWindow\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"maxFinalizationCount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"finalizationGracePeriod\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"ringBufferSize\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"minForcedInclusionCount\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"forcedInclusionDelay\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"forcedInclusionFeeInGwei\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getProposalHash\",\"inputs\":[{\"name\":\"_proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"}],\"outputs\":[{\"name\":\"proposalHash_\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTransitionRecordHash\",\"inputs\":[{\"name\":\"_proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"_parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"finalizationDeadline_\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"recordHash_\",\"type\":\"bytes26\",\"internalType\":\"bytes26\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"hashCheckpoint\",\"inputs\":[{\"name\":\"_checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointManager.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashCoreState\",\"inputs\":[{\"name\":\"_coreState\",\"type\":\"tuple\",\"internalType\":\"structIInbox.CoreState\",\"components\":[{\"name\":\"nextProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"bondInstructionsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashDerivation\",\"inputs\":[{\"name\":\"_derivation\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Derivation\",\"components\":[{\"name\":\"originBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"originBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"isForcedInclusion\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashProposal\",\"inputs\":[{\"name\":\"_proposal\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Proposal\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"coreStateHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashTransition\",\"inputs\":[{\"name\":\"_transition\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Transition\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointManager.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashTransitionsArray\",\"inputs\":[{\"name\":\"_transitions\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Transition[]\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointManager.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"impl\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inNonReentrant\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"initV3\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_genesisBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isOldestForcedInclusionDue\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"propose\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"prove\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"_proof\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolver\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"storeForcedInclusion\",\"inputs\":[{\"name\":\"_blobReference\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobReference\",\"components\":[{\"name\":\"blobStartIndex\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"numBlobs\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"}]}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"withdrawBond\",\"inputs\":[{\"name\":\"_address\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondInstructed\",\"inputs\":[{\"name\":\"instructions\",\"type\":\"tuple[]\",\"indexed\":false,\"internalType\":\"structLibBonds.BondInstruction[]\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"bondType\",\"type\":\"uint8\",\"internalType\":\"enumLibBonds.BondType\"},{\"name\":\"payer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"receiver\",\"type\":\"address\",\"internalType\":\"address\"}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondWithdrawn\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ForcedInclusionStored\",\"inputs\":[{\"name\":\"forcedInclusion\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structIForcedInclusionStore.ForcedInclusion\",\"components\":[{\"name\":\"feeInGwei\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Proposed\",\"inputs\":[{\"name\":\"data\",\"type\":\"bytes\",\"indexed\":false,\"internalType\":\"bytes\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Proved\",\"inputs\":[{\"name\":\"data\",\"type\":\"bytes\",\"indexed\":false,\"internalType\":\"bytes\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCESS_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"BlobNotFound\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"BondInstructionsLengthExceeded\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CheckpointMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"DeadlineExceeded\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ETH_TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EmptyProposals\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ExceedsUnfinalizedProposalCapacity\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FUNC_NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InconsistentParams\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"IncorrectProposalCount\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidBondType\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidCoreState\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidLastProposalProof\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidSpan\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidState\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"LengthExceedsUint24\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MetadataLengthMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NextProposalHashMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NoBlobs\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NoBondToWithdraw\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ProposalHashMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ProposalHashMismatchWithTransition\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ProposalTransitionLengthMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SpanOutOfBounds\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"TransitionRecordHashMismatchWithStorage\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"TransitionRecordNotProvided\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UnprocessedForcedInclusionIsDue\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_VALUE\",\"inputs\":[]}]",
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

// BondBalance is a free data retrieval call binding the contract method 0x245e272f.
//
// Solidity: function bondBalance(address account) view returns(uint256 bond)
func (_ShastaInboxClient *ShastaInboxClientCaller) BondBalance(opts *bind.CallOpts, account common.Address) (*big.Int, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "bondBalance", account)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// BondBalance is a free data retrieval call binding the contract method 0x245e272f.
//
// Solidity: function bondBalance(address account) view returns(uint256 bond)
func (_ShastaInboxClient *ShastaInboxClientSession) BondBalance(account common.Address) (*big.Int, error) {
	return _ShastaInboxClient.Contract.BondBalance(&_ShastaInboxClient.CallOpts, account)
}

// BondBalance is a free data retrieval call binding the contract method 0x245e272f.
//
// Solidity: function bondBalance(address account) view returns(uint256 bond)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) BondBalance(account common.Address) (*big.Int, error) {
	return _ShastaInboxClient.Contract.BondBalance(&_ShastaInboxClient.CallOpts, account)
}

// DecodeProposeInput is a free data retrieval call binding the contract method 0xafb63ad4.
//
// Solidity: function decodeProposeInput(bytes _data) pure returns((uint48,(uint48,uint48,bytes32,bytes32),(uint48,uint48,uint48,address,bytes32,bytes32)[],(uint16,uint16,uint24),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32)[],(uint48,bytes32,bytes32),uint8))
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
// Solidity: function decodeProposeInput(bytes _data) pure returns((uint48,(uint48,uint48,bytes32,bytes32),(uint48,uint48,uint48,address,bytes32,bytes32)[],(uint16,uint16,uint24),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32)[],(uint48,bytes32,bytes32),uint8))
func (_ShastaInboxClient *ShastaInboxClientSession) DecodeProposeInput(_data []byte) (IInboxProposeInput, error) {
	return _ShastaInboxClient.Contract.DecodeProposeInput(&_ShastaInboxClient.CallOpts, _data)
}

// DecodeProposeInput is a free data retrieval call binding the contract method 0xafb63ad4.
//
// Solidity: function decodeProposeInput(bytes _data) pure returns((uint48,(uint48,uint48,bytes32,bytes32),(uint48,uint48,uint48,address,bytes32,bytes32)[],(uint16,uint16,uint24),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32)[],(uint48,bytes32,bytes32),uint8))
func (_ShastaInboxClient *ShastaInboxClientCallerSession) DecodeProposeInput(_data []byte) (IInboxProposeInput, error) {
	return _ShastaInboxClient.Contract.DecodeProposeInput(&_ShastaInboxClient.CallOpts, _data)
}

// DecodeProposedEventData is a free data retrieval call binding the contract method 0xc52bb381.
//
// Solidity: function decodeProposedEventData(bytes _data) pure returns(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)),(uint48,uint48,bytes32,bytes32)))
func (_ShastaInboxClient *ShastaInboxClientCaller) DecodeProposedEventData(opts *bind.CallOpts, _data []byte) (IInboxProposedEventPayload, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "decodeProposedEventData", _data)

	if err != nil {
		return *new(IInboxProposedEventPayload), err
	}

	out0 := *abi.ConvertType(out[0], new(IInboxProposedEventPayload)).(*IInboxProposedEventPayload)

	return out0, err

}

// DecodeProposedEventData is a free data retrieval call binding the contract method 0xc52bb381.
//
// Solidity: function decodeProposedEventData(bytes _data) pure returns(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)),(uint48,uint48,bytes32,bytes32)))
func (_ShastaInboxClient *ShastaInboxClientSession) DecodeProposedEventData(_data []byte) (IInboxProposedEventPayload, error) {
	return _ShastaInboxClient.Contract.DecodeProposedEventData(&_ShastaInboxClient.CallOpts, _data)
}

// DecodeProposedEventData is a free data retrieval call binding the contract method 0xc52bb381.
//
// Solidity: function decodeProposedEventData(bytes _data) pure returns(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)),(uint48,uint48,bytes32,bytes32)))
func (_ShastaInboxClient *ShastaInboxClientCallerSession) DecodeProposedEventData(_data []byte) (IInboxProposedEventPayload, error) {
	return _ShastaInboxClient.Contract.DecodeProposedEventData(&_ShastaInboxClient.CallOpts, _data)
}

// DecodeProveInput is a free data retrieval call binding the contract method 0xedbacd44.
//
// Solidity: function decodeProveInput(bytes _data) pure returns(((uint48,uint48,uint48,address,bytes32,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32))[],(address,address)[]))
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
// Solidity: function decodeProveInput(bytes _data) pure returns(((uint48,uint48,uint48,address,bytes32,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32))[],(address,address)[]))
func (_ShastaInboxClient *ShastaInboxClientSession) DecodeProveInput(_data []byte) (IInboxProveInput, error) {
	return _ShastaInboxClient.Contract.DecodeProveInput(&_ShastaInboxClient.CallOpts, _data)
}

// DecodeProveInput is a free data retrieval call binding the contract method 0xedbacd44.
//
// Solidity: function decodeProveInput(bytes _data) pure returns(((uint48,uint48,uint48,address,bytes32,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32))[],(address,address)[]))
func (_ShastaInboxClient *ShastaInboxClientCallerSession) DecodeProveInput(_data []byte) (IInboxProveInput, error) {
	return _ShastaInboxClient.Contract.DecodeProveInput(&_ShastaInboxClient.CallOpts, _data)
}

// DecodeProvedEventData is a free data retrieval call binding the contract method 0xe160a68c.
//
// Solidity: function decodeProvedEventData(bytes _data) pure returns((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32)),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32),(address,address)))
func (_ShastaInboxClient *ShastaInboxClientCaller) DecodeProvedEventData(opts *bind.CallOpts, _data []byte) (IInboxProvedEventPayload, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "decodeProvedEventData", _data)

	if err != nil {
		return *new(IInboxProvedEventPayload), err
	}

	out0 := *abi.ConvertType(out[0], new(IInboxProvedEventPayload)).(*IInboxProvedEventPayload)

	return out0, err

}

// DecodeProvedEventData is a free data retrieval call binding the contract method 0xe160a68c.
//
// Solidity: function decodeProvedEventData(bytes _data) pure returns((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32)),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32),(address,address)))
func (_ShastaInboxClient *ShastaInboxClientSession) DecodeProvedEventData(_data []byte) (IInboxProvedEventPayload, error) {
	return _ShastaInboxClient.Contract.DecodeProvedEventData(&_ShastaInboxClient.CallOpts, _data)
}

// DecodeProvedEventData is a free data retrieval call binding the contract method 0xe160a68c.
//
// Solidity: function decodeProvedEventData(bytes _data) pure returns((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32)),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32),(address,address)))
func (_ShastaInboxClient *ShastaInboxClientCallerSession) DecodeProvedEventData(_data []byte) (IInboxProvedEventPayload, error) {
	return _ShastaInboxClient.Contract.DecodeProvedEventData(&_ShastaInboxClient.CallOpts, _data)
}

// EncodeProposeInput is a free data retrieval call binding the contract method 0x13fc9a59.
//
// Solidity: function encodeProposeInput((uint48,(uint48,uint48,bytes32,bytes32),(uint48,uint48,uint48,address,bytes32,bytes32)[],(uint16,uint16,uint24),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32)[],(uint48,bytes32,bytes32),uint8) _input) pure returns(bytes)
func (_ShastaInboxClient *ShastaInboxClientCaller) EncodeProposeInput(opts *bind.CallOpts, _input IInboxProposeInput) ([]byte, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "encodeProposeInput", _input)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProposeInput is a free data retrieval call binding the contract method 0x13fc9a59.
//
// Solidity: function encodeProposeInput((uint48,(uint48,uint48,bytes32,bytes32),(uint48,uint48,uint48,address,bytes32,bytes32)[],(uint16,uint16,uint24),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32)[],(uint48,bytes32,bytes32),uint8) _input) pure returns(bytes)
func (_ShastaInboxClient *ShastaInboxClientSession) EncodeProposeInput(_input IInboxProposeInput) ([]byte, error) {
	return _ShastaInboxClient.Contract.EncodeProposeInput(&_ShastaInboxClient.CallOpts, _input)
}

// EncodeProposeInput is a free data retrieval call binding the contract method 0x13fc9a59.
//
// Solidity: function encodeProposeInput((uint48,(uint48,uint48,bytes32,bytes32),(uint48,uint48,uint48,address,bytes32,bytes32)[],(uint16,uint16,uint24),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32)[],(uint48,bytes32,bytes32),uint8) _input) pure returns(bytes)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) EncodeProposeInput(_input IInboxProposeInput) ([]byte, error) {
	return _ShastaInboxClient.Contract.EncodeProposeInput(&_ShastaInboxClient.CallOpts, _input)
}

// EncodeProposedEventData is a free data retrieval call binding the contract method 0xb38c7c08.
//
// Solidity: function encodeProposedEventData(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)),(uint48,uint48,bytes32,bytes32)) _payload) pure returns(bytes)
func (_ShastaInboxClient *ShastaInboxClientCaller) EncodeProposedEventData(opts *bind.CallOpts, _payload IInboxProposedEventPayload) ([]byte, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "encodeProposedEventData", _payload)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProposedEventData is a free data retrieval call binding the contract method 0xb38c7c08.
//
// Solidity: function encodeProposedEventData(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)),(uint48,uint48,bytes32,bytes32)) _payload) pure returns(bytes)
func (_ShastaInboxClient *ShastaInboxClientSession) EncodeProposedEventData(_payload IInboxProposedEventPayload) ([]byte, error) {
	return _ShastaInboxClient.Contract.EncodeProposedEventData(&_ShastaInboxClient.CallOpts, _payload)
}

// EncodeProposedEventData is a free data retrieval call binding the contract method 0xb38c7c08.
//
// Solidity: function encodeProposedEventData(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)),(uint48,uint48,bytes32,bytes32)) _payload) pure returns(bytes)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) EncodeProposedEventData(_payload IInboxProposedEventPayload) ([]byte, error) {
	return _ShastaInboxClient.Contract.EncodeProposedEventData(&_ShastaInboxClient.CallOpts, _payload)
}

// EncodeProposedEventPayload is a free data retrieval call binding the contract method 0x76534f87.
//
// Solidity: function encodeProposedEventPayload(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)),(uint48,uint48,bytes32,bytes32)) _payload) pure returns(bytes)
func (_ShastaInboxClient *ShastaInboxClientCaller) EncodeProposedEventPayload(opts *bind.CallOpts, _payload IInboxProposedEventPayload) ([]byte, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "encodeProposedEventPayload", _payload)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProposedEventPayload is a free data retrieval call binding the contract method 0x76534f87.
//
// Solidity: function encodeProposedEventPayload(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)),(uint48,uint48,bytes32,bytes32)) _payload) pure returns(bytes)
func (_ShastaInboxClient *ShastaInboxClientSession) EncodeProposedEventPayload(_payload IInboxProposedEventPayload) ([]byte, error) {
	return _ShastaInboxClient.Contract.EncodeProposedEventPayload(&_ShastaInboxClient.CallOpts, _payload)
}

// EncodeProposedEventPayload is a free data retrieval call binding the contract method 0x76534f87.
//
// Solidity: function encodeProposedEventPayload(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)),(uint48,uint48,bytes32,bytes32)) _payload) pure returns(bytes)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) EncodeProposedEventPayload(_payload IInboxProposedEventPayload) ([]byte, error) {
	return _ShastaInboxClient.Contract.EncodeProposedEventPayload(&_ShastaInboxClient.CallOpts, _payload)
}

// EncodeProveInput is a free data retrieval call binding the contract method 0xdc5a8bf8.
//
// Solidity: function encodeProveInput(((uint48,uint48,uint48,address,bytes32,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32))[],(address,address)[]) _input) pure returns(bytes)
func (_ShastaInboxClient *ShastaInboxClientCaller) EncodeProveInput(opts *bind.CallOpts, _input IInboxProveInput) ([]byte, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "encodeProveInput", _input)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProveInput is a free data retrieval call binding the contract method 0xdc5a8bf8.
//
// Solidity: function encodeProveInput(((uint48,uint48,uint48,address,bytes32,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32))[],(address,address)[]) _input) pure returns(bytes)
func (_ShastaInboxClient *ShastaInboxClientSession) EncodeProveInput(_input IInboxProveInput) ([]byte, error) {
	return _ShastaInboxClient.Contract.EncodeProveInput(&_ShastaInboxClient.CallOpts, _input)
}

// EncodeProveInput is a free data retrieval call binding the contract method 0xdc5a8bf8.
//
// Solidity: function encodeProveInput(((uint48,uint48,uint48,address,bytes32,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32))[],(address,address)[]) _input) pure returns(bytes)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) EncodeProveInput(_input IInboxProveInput) ([]byte, error) {
	return _ShastaInboxClient.Contract.EncodeProveInput(&_ShastaInboxClient.CallOpts, _input)
}

// EncodeProvedEventData is a free data retrieval call binding the contract method 0xea373dd8.
//
// Solidity: function encodeProvedEventData((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32)),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32),(address,address)) _payload) pure returns(bytes)
func (_ShastaInboxClient *ShastaInboxClientCaller) EncodeProvedEventData(opts *bind.CallOpts, _payload IInboxProvedEventPayload) ([]byte, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "encodeProvedEventData", _payload)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProvedEventData is a free data retrieval call binding the contract method 0xea373dd8.
//
// Solidity: function encodeProvedEventData((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32)),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32),(address,address)) _payload) pure returns(bytes)
func (_ShastaInboxClient *ShastaInboxClientSession) EncodeProvedEventData(_payload IInboxProvedEventPayload) ([]byte, error) {
	return _ShastaInboxClient.Contract.EncodeProvedEventData(&_ShastaInboxClient.CallOpts, _payload)
}

// EncodeProvedEventData is a free data retrieval call binding the contract method 0xea373dd8.
//
// Solidity: function encodeProvedEventData((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32)),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32),(address,address)) _payload) pure returns(bytes)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) EncodeProvedEventData(_payload IInboxProvedEventPayload) ([]byte, error) {
	return _ShastaInboxClient.Contract.EncodeProvedEventData(&_ShastaInboxClient.CallOpts, _payload)
}

// EncodeProvedEventPayload is a free data retrieval call binding the contract method 0x36f3574a.
//
// Solidity: function encodeProvedEventPayload((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32)),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32),(address,address)) _payload) pure returns(bytes)
func (_ShastaInboxClient *ShastaInboxClientCaller) EncodeProvedEventPayload(opts *bind.CallOpts, _payload IInboxProvedEventPayload) ([]byte, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "encodeProvedEventPayload", _payload)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProvedEventPayload is a free data retrieval call binding the contract method 0x36f3574a.
//
// Solidity: function encodeProvedEventPayload((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32)),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32),(address,address)) _payload) pure returns(bytes)
func (_ShastaInboxClient *ShastaInboxClientSession) EncodeProvedEventPayload(_payload IInboxProvedEventPayload) ([]byte, error) {
	return _ShastaInboxClient.Contract.EncodeProvedEventPayload(&_ShastaInboxClient.CallOpts, _payload)
}

// EncodeProvedEventPayload is a free data retrieval call binding the contract method 0x36f3574a.
//
// Solidity: function encodeProvedEventPayload((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32)),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32),(address,address)) _payload) pure returns(bytes)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) EncodeProvedEventPayload(_payload IInboxProvedEventPayload) ([]byte, error) {
	return _ShastaInboxClient.Contract.EncodeProvedEventPayload(&_ShastaInboxClient.CallOpts, _payload)
}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() view returns((address,address,address,address,uint48,uint48,uint256,uint48,uint256,uint8,uint256,uint64,uint64) config_)
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
// Solidity: function getConfig() view returns((address,address,address,address,uint48,uint48,uint256,uint48,uint256,uint8,uint256,uint64,uint64) config_)
func (_ShastaInboxClient *ShastaInboxClientSession) GetConfig() (IInboxConfig, error) {
	return _ShastaInboxClient.Contract.GetConfig(&_ShastaInboxClient.CallOpts)
}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() view returns((address,address,address,address,uint48,uint48,uint256,uint48,uint256,uint8,uint256,uint64,uint64) config_)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) GetConfig() (IInboxConfig, error) {
	return _ShastaInboxClient.Contract.GetConfig(&_ShastaInboxClient.CallOpts)
}

// GetProposalHash is a free data retrieval call binding the contract method 0x0bb54ffd.
//
// Solidity: function getProposalHash(uint48 _proposalId) view returns(bytes32 proposalHash_)
func (_ShastaInboxClient *ShastaInboxClientCaller) GetProposalHash(opts *bind.CallOpts, _proposalId *big.Int) ([32]byte, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "getProposalHash", _proposalId)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetProposalHash is a free data retrieval call binding the contract method 0x0bb54ffd.
//
// Solidity: function getProposalHash(uint48 _proposalId) view returns(bytes32 proposalHash_)
func (_ShastaInboxClient *ShastaInboxClientSession) GetProposalHash(_proposalId *big.Int) ([32]byte, error) {
	return _ShastaInboxClient.Contract.GetProposalHash(&_ShastaInboxClient.CallOpts, _proposalId)
}

// GetProposalHash is a free data retrieval call binding the contract method 0x0bb54ffd.
//
// Solidity: function getProposalHash(uint48 _proposalId) view returns(bytes32 proposalHash_)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) GetProposalHash(_proposalId *big.Int) ([32]byte, error) {
	return _ShastaInboxClient.Contract.GetProposalHash(&_ShastaInboxClient.CallOpts, _proposalId)
}

// GetTransitionRecordHash is a free data retrieval call binding the contract method 0xba2850bf.
//
// Solidity: function getTransitionRecordHash(uint48 _proposalId, bytes32 _parentTransitionHash) view returns(uint48 finalizationDeadline_, bytes26 recordHash_)
func (_ShastaInboxClient *ShastaInboxClientCaller) GetTransitionRecordHash(opts *bind.CallOpts, _proposalId *big.Int, _parentTransitionHash [32]byte) (struct {
	FinalizationDeadline *big.Int
	RecordHash           [26]byte
}, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "getTransitionRecordHash", _proposalId, _parentTransitionHash)

	outstruct := new(struct {
		FinalizationDeadline *big.Int
		RecordHash           [26]byte
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.FinalizationDeadline = *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	outstruct.RecordHash = *abi.ConvertType(out[1], new([26]byte)).(*[26]byte)

	return *outstruct, err

}

// GetTransitionRecordHash is a free data retrieval call binding the contract method 0xba2850bf.
//
// Solidity: function getTransitionRecordHash(uint48 _proposalId, bytes32 _parentTransitionHash) view returns(uint48 finalizationDeadline_, bytes26 recordHash_)
func (_ShastaInboxClient *ShastaInboxClientSession) GetTransitionRecordHash(_proposalId *big.Int, _parentTransitionHash [32]byte) (struct {
	FinalizationDeadline *big.Int
	RecordHash           [26]byte
}, error) {
	return _ShastaInboxClient.Contract.GetTransitionRecordHash(&_ShastaInboxClient.CallOpts, _proposalId, _parentTransitionHash)
}

// GetTransitionRecordHash is a free data retrieval call binding the contract method 0xba2850bf.
//
// Solidity: function getTransitionRecordHash(uint48 _proposalId, bytes32 _parentTransitionHash) view returns(uint48 finalizationDeadline_, bytes26 recordHash_)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) GetTransitionRecordHash(_proposalId *big.Int, _parentTransitionHash [32]byte) (struct {
	FinalizationDeadline *big.Int
	RecordHash           [26]byte
}, error) {
	return _ShastaInboxClient.Contract.GetTransitionRecordHash(&_ShastaInboxClient.CallOpts, _proposalId, _parentTransitionHash)
}

// HashCheckpoint is a free data retrieval call binding the contract method 0x7989aa10.
//
// Solidity: function hashCheckpoint((uint48,bytes32,bytes32) _checkpoint) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientCaller) HashCheckpoint(opts *bind.CallOpts, _checkpoint ICheckpointManagerCheckpoint) ([32]byte, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "hashCheckpoint", _checkpoint)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashCheckpoint is a free data retrieval call binding the contract method 0x7989aa10.
//
// Solidity: function hashCheckpoint((uint48,bytes32,bytes32) _checkpoint) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientSession) HashCheckpoint(_checkpoint ICheckpointManagerCheckpoint) ([32]byte, error) {
	return _ShastaInboxClient.Contract.HashCheckpoint(&_ShastaInboxClient.CallOpts, _checkpoint)
}

// HashCheckpoint is a free data retrieval call binding the contract method 0x7989aa10.
//
// Solidity: function hashCheckpoint((uint48,bytes32,bytes32) _checkpoint) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) HashCheckpoint(_checkpoint ICheckpointManagerCheckpoint) ([32]byte, error) {
	return _ShastaInboxClient.Contract.HashCheckpoint(&_ShastaInboxClient.CallOpts, _checkpoint)
}

// HashCoreState is a free data retrieval call binding the contract method 0x52e416ed.
//
// Solidity: function hashCoreState((uint48,uint48,bytes32,bytes32) _coreState) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientCaller) HashCoreState(opts *bind.CallOpts, _coreState IInboxCoreState) ([32]byte, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "hashCoreState", _coreState)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashCoreState is a free data retrieval call binding the contract method 0x52e416ed.
//
// Solidity: function hashCoreState((uint48,uint48,bytes32,bytes32) _coreState) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientSession) HashCoreState(_coreState IInboxCoreState) ([32]byte, error) {
	return _ShastaInboxClient.Contract.HashCoreState(&_ShastaInboxClient.CallOpts, _coreState)
}

// HashCoreState is a free data retrieval call binding the contract method 0x52e416ed.
//
// Solidity: function hashCoreState((uint48,uint48,bytes32,bytes32) _coreState) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) HashCoreState(_coreState IInboxCoreState) ([32]byte, error) {
	return _ShastaInboxClient.Contract.HashCoreState(&_ShastaInboxClient.CallOpts, _coreState)
}

// HashDerivation is a free data retrieval call binding the contract method 0x6696f76b.
//
// Solidity: function hashDerivation((uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)) _derivation) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientCaller) HashDerivation(opts *bind.CallOpts, _derivation IInboxDerivation) ([32]byte, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "hashDerivation", _derivation)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashDerivation is a free data retrieval call binding the contract method 0x6696f76b.
//
// Solidity: function hashDerivation((uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)) _derivation) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientSession) HashDerivation(_derivation IInboxDerivation) ([32]byte, error) {
	return _ShastaInboxClient.Contract.HashDerivation(&_ShastaInboxClient.CallOpts, _derivation)
}

// HashDerivation is a free data retrieval call binding the contract method 0x6696f76b.
//
// Solidity: function hashDerivation((uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)) _derivation) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) HashDerivation(_derivation IInboxDerivation) ([32]byte, error) {
	return _ShastaInboxClient.Contract.HashDerivation(&_ShastaInboxClient.CallOpts, _derivation)
}

// HashProposal is a free data retrieval call binding the contract method 0xa1ec9333.
//
// Solidity: function hashProposal((uint48,uint48,uint48,address,bytes32,bytes32) _proposal) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientCaller) HashProposal(opts *bind.CallOpts, _proposal IInboxProposal) ([32]byte, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "hashProposal", _proposal)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashProposal is a free data retrieval call binding the contract method 0xa1ec9333.
//
// Solidity: function hashProposal((uint48,uint48,uint48,address,bytes32,bytes32) _proposal) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientSession) HashProposal(_proposal IInboxProposal) ([32]byte, error) {
	return _ShastaInboxClient.Contract.HashProposal(&_ShastaInboxClient.CallOpts, _proposal)
}

// HashProposal is a free data retrieval call binding the contract method 0xa1ec9333.
//
// Solidity: function hashProposal((uint48,uint48,uint48,address,bytes32,bytes32) _proposal) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) HashProposal(_proposal IInboxProposal) ([32]byte, error) {
	return _ShastaInboxClient.Contract.HashProposal(&_ShastaInboxClient.CallOpts, _proposal)
}

// HashTransition is a free data retrieval call binding the contract method 0x1f397067.
//
// Solidity: function hashTransition((bytes32,bytes32,(uint48,bytes32,bytes32)) _transition) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientCaller) HashTransition(opts *bind.CallOpts, _transition IInboxTransition) ([32]byte, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "hashTransition", _transition)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashTransition is a free data retrieval call binding the contract method 0x1f397067.
//
// Solidity: function hashTransition((bytes32,bytes32,(uint48,bytes32,bytes32)) _transition) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientSession) HashTransition(_transition IInboxTransition) ([32]byte, error) {
	return _ShastaInboxClient.Contract.HashTransition(&_ShastaInboxClient.CallOpts, _transition)
}

// HashTransition is a free data retrieval call binding the contract method 0x1f397067.
//
// Solidity: function hashTransition((bytes32,bytes32,(uint48,bytes32,bytes32)) _transition) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) HashTransition(_transition IInboxTransition) ([32]byte, error) {
	return _ShastaInboxClient.Contract.HashTransition(&_ShastaInboxClient.CallOpts, _transition)
}

// HashTransitionsArray is a free data retrieval call binding the contract method 0xad345a23.
//
// Solidity: function hashTransitionsArray((bytes32,bytes32,(uint48,bytes32,bytes32))[] _transitions) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientCaller) HashTransitionsArray(opts *bind.CallOpts, _transitions []IInboxTransition) ([32]byte, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "hashTransitionsArray", _transitions)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashTransitionsArray is a free data retrieval call binding the contract method 0xad345a23.
//
// Solidity: function hashTransitionsArray((bytes32,bytes32,(uint48,bytes32,bytes32))[] _transitions) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientSession) HashTransitionsArray(_transitions []IInboxTransition) ([32]byte, error) {
	return _ShastaInboxClient.Contract.HashTransitionsArray(&_ShastaInboxClient.CallOpts, _transitions)
}

// HashTransitionsArray is a free data retrieval call binding the contract method 0xad345a23.
//
// Solidity: function hashTransitionsArray((bytes32,bytes32,(uint48,bytes32,bytes32))[] _transitions) pure returns(bytes32)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) HashTransitionsArray(_transitions []IInboxTransition) ([32]byte, error) {
	return _ShastaInboxClient.Contract.HashTransitionsArray(&_ShastaInboxClient.CallOpts, _transitions)
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

// IsOldestForcedInclusionDue is a free data retrieval call binding the contract method 0x16db8952.
//
// Solidity: function isOldestForcedInclusionDue() view returns(bool)
func (_ShastaInboxClient *ShastaInboxClientCaller) IsOldestForcedInclusionDue(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _ShastaInboxClient.contract.Call(opts, &out, "isOldestForcedInclusionDue")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsOldestForcedInclusionDue is a free data retrieval call binding the contract method 0x16db8952.
//
// Solidity: function isOldestForcedInclusionDue() view returns(bool)
func (_ShastaInboxClient *ShastaInboxClientSession) IsOldestForcedInclusionDue() (bool, error) {
	return _ShastaInboxClient.Contract.IsOldestForcedInclusionDue(&_ShastaInboxClient.CallOpts)
}

// IsOldestForcedInclusionDue is a free data retrieval call binding the contract method 0x16db8952.
//
// Solidity: function isOldestForcedInclusionDue() view returns(bool)
func (_ShastaInboxClient *ShastaInboxClientCallerSession) IsOldestForcedInclusionDue() (bool, error) {
	return _ShastaInboxClient.Contract.IsOldestForcedInclusionDue(&_ShastaInboxClient.CallOpts)
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

// InitV3 is a paid mutator transaction binding the contract method 0x55d61cb2.
//
// Solidity: function initV3(address _owner, bytes32 _genesisBlockHash) returns()
func (_ShastaInboxClient *ShastaInboxClientTransactor) InitV3(opts *bind.TransactOpts, _owner common.Address, _genesisBlockHash [32]byte) (*types.Transaction, error) {
	return _ShastaInboxClient.contract.Transact(opts, "initV3", _owner, _genesisBlockHash)
}

// InitV3 is a paid mutator transaction binding the contract method 0x55d61cb2.
//
// Solidity: function initV3(address _owner, bytes32 _genesisBlockHash) returns()
func (_ShastaInboxClient *ShastaInboxClientSession) InitV3(_owner common.Address, _genesisBlockHash [32]byte) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.InitV3(&_ShastaInboxClient.TransactOpts, _owner, _genesisBlockHash)
}

// InitV3 is a paid mutator transaction binding the contract method 0x55d61cb2.
//
// Solidity: function initV3(address _owner, bytes32 _genesisBlockHash) returns()
func (_ShastaInboxClient *ShastaInboxClientTransactorSession) InitV3(_owner common.Address, _genesisBlockHash [32]byte) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.InitV3(&_ShastaInboxClient.TransactOpts, _owner, _genesisBlockHash)
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
// Solidity: function propose(bytes , bytes _data) returns()
func (_ShastaInboxClient *ShastaInboxClientTransactor) Propose(opts *bind.TransactOpts, arg0 []byte, _data []byte) (*types.Transaction, error) {
	return _ShastaInboxClient.contract.Transact(opts, "propose", arg0, _data)
}

// Propose is a paid mutator transaction binding the contract method 0x9791e644.
//
// Solidity: function propose(bytes , bytes _data) returns()
func (_ShastaInboxClient *ShastaInboxClientSession) Propose(arg0 []byte, _data []byte) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.Propose(&_ShastaInboxClient.TransactOpts, arg0, _data)
}

// Propose is a paid mutator transaction binding the contract method 0x9791e644.
//
// Solidity: function propose(bytes , bytes _data) returns()
func (_ShastaInboxClient *ShastaInboxClientTransactorSession) Propose(arg0 []byte, _data []byte) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.Propose(&_ShastaInboxClient.TransactOpts, arg0, _data)
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

// StoreForcedInclusion is a paid mutator transaction binding the contract method 0xe7e46b3d.
//
// Solidity: function storeForcedInclusion((uint16,uint16,uint24) _blobReference) payable returns()
func (_ShastaInboxClient *ShastaInboxClientTransactor) StoreForcedInclusion(opts *bind.TransactOpts, _blobReference LibBlobsBlobReference) (*types.Transaction, error) {
	return _ShastaInboxClient.contract.Transact(opts, "storeForcedInclusion", _blobReference)
}

// StoreForcedInclusion is a paid mutator transaction binding the contract method 0xe7e46b3d.
//
// Solidity: function storeForcedInclusion((uint16,uint16,uint24) _blobReference) payable returns()
func (_ShastaInboxClient *ShastaInboxClientSession) StoreForcedInclusion(_blobReference LibBlobsBlobReference) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.StoreForcedInclusion(&_ShastaInboxClient.TransactOpts, _blobReference)
}

// StoreForcedInclusion is a paid mutator transaction binding the contract method 0xe7e46b3d.
//
// Solidity: function storeForcedInclusion((uint16,uint16,uint24) _blobReference) payable returns()
func (_ShastaInboxClient *ShastaInboxClientTransactorSession) StoreForcedInclusion(_blobReference LibBlobsBlobReference) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.StoreForcedInclusion(&_ShastaInboxClient.TransactOpts, _blobReference)
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

// WithdrawBond is a paid mutator transaction binding the contract method 0x7529d9df.
//
// Solidity: function withdrawBond(address _address) returns()
func (_ShastaInboxClient *ShastaInboxClientTransactor) WithdrawBond(opts *bind.TransactOpts, _address common.Address) (*types.Transaction, error) {
	return _ShastaInboxClient.contract.Transact(opts, "withdrawBond", _address)
}

// WithdrawBond is a paid mutator transaction binding the contract method 0x7529d9df.
//
// Solidity: function withdrawBond(address _address) returns()
func (_ShastaInboxClient *ShastaInboxClientSession) WithdrawBond(_address common.Address) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.WithdrawBond(&_ShastaInboxClient.TransactOpts, _address)
}

// WithdrawBond is a paid mutator transaction binding the contract method 0x7529d9df.
//
// Solidity: function withdrawBond(address _address) returns()
func (_ShastaInboxClient *ShastaInboxClientTransactorSession) WithdrawBond(_address common.Address) (*types.Transaction, error) {
	return _ShastaInboxClient.Contract.WithdrawBond(&_ShastaInboxClient.TransactOpts, _address)
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

// ShastaInboxClientBondInstructedIterator is returned from FilterBondInstructed and is used to iterate over the raw logs and unpacked data for BondInstructed events raised by the ShastaInboxClient contract.
type ShastaInboxClientBondInstructedIterator struct {
	Event *ShastaInboxClientBondInstructed // Event containing the contract specifics and raw log

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
func (it *ShastaInboxClientBondInstructedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaInboxClientBondInstructed)
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
		it.Event = new(ShastaInboxClientBondInstructed)
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
func (it *ShastaInboxClientBondInstructedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaInboxClientBondInstructedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaInboxClientBondInstructed represents a BondInstructed event raised by the ShastaInboxClient contract.
type ShastaInboxClientBondInstructed struct {
	Instructions []LibBondsBondInstruction
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterBondInstructed is a free log retrieval operation binding the contract event 0xf2d537d03425ffbe0a312cc4b640d80e634171d856a2e5b961d4f3c6cf20e1a7.
//
// Solidity: event BondInstructed((uint48,uint8,address,address)[] instructions)
func (_ShastaInboxClient *ShastaInboxClientFilterer) FilterBondInstructed(opts *bind.FilterOpts) (*ShastaInboxClientBondInstructedIterator, error) {

	logs, sub, err := _ShastaInboxClient.contract.FilterLogs(opts, "BondInstructed")
	if err != nil {
		return nil, err
	}
	return &ShastaInboxClientBondInstructedIterator{contract: _ShastaInboxClient.contract, event: "BondInstructed", logs: logs, sub: sub}, nil
}

// WatchBondInstructed is a free log subscription operation binding the contract event 0xf2d537d03425ffbe0a312cc4b640d80e634171d856a2e5b961d4f3c6cf20e1a7.
//
// Solidity: event BondInstructed((uint48,uint8,address,address)[] instructions)
func (_ShastaInboxClient *ShastaInboxClientFilterer) WatchBondInstructed(opts *bind.WatchOpts, sink chan<- *ShastaInboxClientBondInstructed) (event.Subscription, error) {

	logs, sub, err := _ShastaInboxClient.contract.WatchLogs(opts, "BondInstructed")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaInboxClientBondInstructed)
				if err := _ShastaInboxClient.contract.UnpackLog(event, "BondInstructed", log); err != nil {
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

// ParseBondInstructed is a log parse operation binding the contract event 0xf2d537d03425ffbe0a312cc4b640d80e634171d856a2e5b961d4f3c6cf20e1a7.
//
// Solidity: event BondInstructed((uint48,uint8,address,address)[] instructions)
func (_ShastaInboxClient *ShastaInboxClientFilterer) ParseBondInstructed(log types.Log) (*ShastaInboxClientBondInstructed, error) {
	event := new(ShastaInboxClientBondInstructed)
	if err := _ShastaInboxClient.contract.UnpackLog(event, "BondInstructed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ShastaInboxClientBondWithdrawnIterator is returned from FilterBondWithdrawn and is used to iterate over the raw logs and unpacked data for BondWithdrawn events raised by the ShastaInboxClient contract.
type ShastaInboxClientBondWithdrawnIterator struct {
	Event *ShastaInboxClientBondWithdrawn // Event containing the contract specifics and raw log

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
func (it *ShastaInboxClientBondWithdrawnIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaInboxClientBondWithdrawn)
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
		it.Event = new(ShastaInboxClientBondWithdrawn)
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
func (it *ShastaInboxClientBondWithdrawnIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaInboxClientBondWithdrawnIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaInboxClientBondWithdrawn represents a BondWithdrawn event raised by the ShastaInboxClient contract.
type ShastaInboxClientBondWithdrawn struct {
	User   common.Address
	Amount *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBondWithdrawn is a free log retrieval operation binding the contract event 0x0d41118e36df44efb77a471fc49fb9c0be0406d802ef95520e9fbf606e65b455.
//
// Solidity: event BondWithdrawn(address indexed user, uint256 amount)
func (_ShastaInboxClient *ShastaInboxClientFilterer) FilterBondWithdrawn(opts *bind.FilterOpts, user []common.Address) (*ShastaInboxClientBondWithdrawnIterator, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _ShastaInboxClient.contract.FilterLogs(opts, "BondWithdrawn", userRule)
	if err != nil {
		return nil, err
	}
	return &ShastaInboxClientBondWithdrawnIterator{contract: _ShastaInboxClient.contract, event: "BondWithdrawn", logs: logs, sub: sub}, nil
}

// WatchBondWithdrawn is a free log subscription operation binding the contract event 0x0d41118e36df44efb77a471fc49fb9c0be0406d802ef95520e9fbf606e65b455.
//
// Solidity: event BondWithdrawn(address indexed user, uint256 amount)
func (_ShastaInboxClient *ShastaInboxClientFilterer) WatchBondWithdrawn(opts *bind.WatchOpts, sink chan<- *ShastaInboxClientBondWithdrawn, user []common.Address) (event.Subscription, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _ShastaInboxClient.contract.WatchLogs(opts, "BondWithdrawn", userRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaInboxClientBondWithdrawn)
				if err := _ShastaInboxClient.contract.UnpackLog(event, "BondWithdrawn", log); err != nil {
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
func (_ShastaInboxClient *ShastaInboxClientFilterer) ParseBondWithdrawn(log types.Log) (*ShastaInboxClientBondWithdrawn, error) {
	event := new(ShastaInboxClientBondWithdrawn)
	if err := _ShastaInboxClient.contract.UnpackLog(event, "BondWithdrawn", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ShastaInboxClientForcedInclusionStoredIterator is returned from FilterForcedInclusionStored and is used to iterate over the raw logs and unpacked data for ForcedInclusionStored events raised by the ShastaInboxClient contract.
type ShastaInboxClientForcedInclusionStoredIterator struct {
	Event *ShastaInboxClientForcedInclusionStored // Event containing the contract specifics and raw log

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
func (it *ShastaInboxClientForcedInclusionStoredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaInboxClientForcedInclusionStored)
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
		it.Event = new(ShastaInboxClientForcedInclusionStored)
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
func (it *ShastaInboxClientForcedInclusionStoredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaInboxClientForcedInclusionStoredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaInboxClientForcedInclusionStored represents a ForcedInclusionStored event raised by the ShastaInboxClient contract.
type ShastaInboxClientForcedInclusionStored struct {
	ForcedInclusion IForcedInclusionStoreForcedInclusion
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterForcedInclusionStored is a free log retrieval operation binding the contract event 0x2f33e0807c74cca345279e8e8eb5083d2da943d7013bd2111794b5938ac437d8.
//
// Solidity: event ForcedInclusionStored((uint64,(bytes32[],uint24,uint48)) forcedInclusion)
func (_ShastaInboxClient *ShastaInboxClientFilterer) FilterForcedInclusionStored(opts *bind.FilterOpts) (*ShastaInboxClientForcedInclusionStoredIterator, error) {

	logs, sub, err := _ShastaInboxClient.contract.FilterLogs(opts, "ForcedInclusionStored")
	if err != nil {
		return nil, err
	}
	return &ShastaInboxClientForcedInclusionStoredIterator{contract: _ShastaInboxClient.contract, event: "ForcedInclusionStored", logs: logs, sub: sub}, nil
}

// WatchForcedInclusionStored is a free log subscription operation binding the contract event 0x2f33e0807c74cca345279e8e8eb5083d2da943d7013bd2111794b5938ac437d8.
//
// Solidity: event ForcedInclusionStored((uint64,(bytes32[],uint24,uint48)) forcedInclusion)
func (_ShastaInboxClient *ShastaInboxClientFilterer) WatchForcedInclusionStored(opts *bind.WatchOpts, sink chan<- *ShastaInboxClientForcedInclusionStored) (event.Subscription, error) {

	logs, sub, err := _ShastaInboxClient.contract.WatchLogs(opts, "ForcedInclusionStored")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaInboxClientForcedInclusionStored)
				if err := _ShastaInboxClient.contract.UnpackLog(event, "ForcedInclusionStored", log); err != nil {
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

// ParseForcedInclusionStored is a log parse operation binding the contract event 0x2f33e0807c74cca345279e8e8eb5083d2da943d7013bd2111794b5938ac437d8.
//
// Solidity: event ForcedInclusionStored((uint64,(bytes32[],uint24,uint48)) forcedInclusion)
func (_ShastaInboxClient *ShastaInboxClientFilterer) ParseForcedInclusionStored(log types.Log) (*ShastaInboxClientForcedInclusionStored, error) {
	event := new(ShastaInboxClientForcedInclusionStored)
	if err := _ShastaInboxClient.contract.UnpackLog(event, "ForcedInclusionStored", log); err != nil {
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
	Data []byte
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterProposed is a free log retrieval operation binding the contract event 0x10b2060c55406ea48522476f67fd813d4984b12078555d3e2a377e35839d7d01.
//
// Solidity: event Proposed(bytes data)
func (_ShastaInboxClient *ShastaInboxClientFilterer) FilterProposed(opts *bind.FilterOpts) (*ShastaInboxClientProposedIterator, error) {

	logs, sub, err := _ShastaInboxClient.contract.FilterLogs(opts, "Proposed")
	if err != nil {
		return nil, err
	}
	return &ShastaInboxClientProposedIterator{contract: _ShastaInboxClient.contract, event: "Proposed", logs: logs, sub: sub}, nil
}

// WatchProposed is a free log subscription operation binding the contract event 0x10b2060c55406ea48522476f67fd813d4984b12078555d3e2a377e35839d7d01.
//
// Solidity: event Proposed(bytes data)
func (_ShastaInboxClient *ShastaInboxClientFilterer) WatchProposed(opts *bind.WatchOpts, sink chan<- *ShastaInboxClientProposed) (event.Subscription, error) {

	logs, sub, err := _ShastaInboxClient.contract.WatchLogs(opts, "Proposed")
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

// ParseProposed is a log parse operation binding the contract event 0x10b2060c55406ea48522476f67fd813d4984b12078555d3e2a377e35839d7d01.
//
// Solidity: event Proposed(bytes data)
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
	Data []byte
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterProved is a free log retrieval operation binding the contract event 0xb2d5049ba96efb9e1fee66a51e4e6cbdfa2949627891ee29c6e4281abb8da03c.
//
// Solidity: event Proved(bytes data)
func (_ShastaInboxClient *ShastaInboxClientFilterer) FilterProved(opts *bind.FilterOpts) (*ShastaInboxClientProvedIterator, error) {

	logs, sub, err := _ShastaInboxClient.contract.FilterLogs(opts, "Proved")
	if err != nil {
		return nil, err
	}
	return &ShastaInboxClientProvedIterator{contract: _ShastaInboxClient.contract, event: "Proved", logs: logs, sub: sub}, nil
}

// WatchProved is a free log subscription operation binding the contract event 0xb2d5049ba96efb9e1fee66a51e4e6cbdfa2949627891ee29c6e4281abb8da03c.
//
// Solidity: event Proved(bytes data)
func (_ShastaInboxClient *ShastaInboxClientFilterer) WatchProved(opts *bind.WatchOpts, sink chan<- *ShastaInboxClientProved) (event.Subscription, error) {

	logs, sub, err := _ShastaInboxClient.contract.WatchLogs(opts, "Proved")
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

// ParseProved is a log parse operation binding the contract event 0xb2d5049ba96efb9e1fee66a51e4e6cbdfa2949627891ee29c6e4281abb8da03c.
//
// Solidity: event Proved(bytes data)
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
