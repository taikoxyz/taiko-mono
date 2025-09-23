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

// IInboxCoreState is an auto generated low-level Go binding around an user-defined struct.
type IInboxCoreState struct {
	NextProposalId              *big.Int
	NextProposalBlockId         *big.Int
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
	Checkpoint          ICheckpointStoreCheckpoint
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
	Checkpoint           ICheckpointStoreCheckpoint
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

// InboxHelperClientMetaData contains all meta data concerning the InboxHelperClient contract.
var InboxHelperClientMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"decodeProposeInput\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"input_\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProposeInput\",\"components\":[{\"name\":\"deadline\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"coreState\",\"type\":\"tuple\",\"internalType\":\"structIInbox.CoreState\",\"components\":[{\"name\":\"nextProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"nextProposalBlockId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"bondInstructionsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"parentProposals\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Proposal[]\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"coreStateHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"blobReference\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobReference\",\"components\":[{\"name\":\"blobStartIndex\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"numBlobs\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"}]},{\"name\":\"transitionRecords\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.TransitionRecord[]\",\"components\":[{\"name\":\"span\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"bondInstructions\",\"type\":\"tuple[]\",\"internalType\":\"structLibBonds.BondInstruction[]\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"bondType\",\"type\":\"uint8\",\"internalType\":\"enumLibBonds.BondType\"},{\"name\":\"payer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"receiver\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"transitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpointHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"numForcedInclusions\",\"type\":\"uint8\",\"internalType\":\"uint8\"}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"decodeProposeInputOptimized\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"input_\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProposeInput\",\"components\":[{\"name\":\"deadline\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"coreState\",\"type\":\"tuple\",\"internalType\":\"structIInbox.CoreState\",\"components\":[{\"name\":\"nextProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"nextProposalBlockId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"bondInstructionsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"parentProposals\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Proposal[]\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"coreStateHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"blobReference\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobReference\",\"components\":[{\"name\":\"blobStartIndex\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"numBlobs\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"}]},{\"name\":\"transitionRecords\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.TransitionRecord[]\",\"components\":[{\"name\":\"span\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"bondInstructions\",\"type\":\"tuple[]\",\"internalType\":\"structLibBonds.BondInstruction[]\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"bondType\",\"type\":\"uint8\",\"internalType\":\"enumLibBonds.BondType\"},{\"name\":\"payer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"receiver\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"transitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpointHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"numForcedInclusions\",\"type\":\"uint8\",\"internalType\":\"uint8\"}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"decodeProposedEvent\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"payload_\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProposedEventPayload\",\"components\":[{\"name\":\"proposal\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Proposal\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"coreStateHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"derivation\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Derivation\",\"components\":[{\"name\":\"originBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"originBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"isForcedInclusion\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]},{\"name\":\"coreState\",\"type\":\"tuple\",\"internalType\":\"structIInbox.CoreState\",\"components\":[{\"name\":\"nextProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"nextProposalBlockId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"bondInstructionsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"decodeProposedEventOptimized\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"payload_\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProposedEventPayload\",\"components\":[{\"name\":\"proposal\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Proposal\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"coreStateHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"derivation\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Derivation\",\"components\":[{\"name\":\"originBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"originBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"isForcedInclusion\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]},{\"name\":\"coreState\",\"type\":\"tuple\",\"internalType\":\"structIInbox.CoreState\",\"components\":[{\"name\":\"nextProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"nextProposalBlockId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"bondInstructionsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"decodeProveInput\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"input_\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProveInput\",\"components\":[{\"name\":\"proposals\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Proposal[]\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"coreStateHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"transitions\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Transition[]\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]},{\"name\":\"metadata\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.TransitionMetadata[]\",\"components\":[{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"}]}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"decodeProveInputOptimized\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"input_\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProveInput\",\"components\":[{\"name\":\"proposals\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Proposal[]\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"coreStateHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"transitions\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Transition[]\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]},{\"name\":\"metadata\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.TransitionMetadata[]\",\"components\":[{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"}]}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"decodeProvedEvent\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"payload_\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProvedEventPayload\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"transition\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Transition\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]},{\"name\":\"transitionRecord\",\"type\":\"tuple\",\"internalType\":\"structIInbox.TransitionRecord\",\"components\":[{\"name\":\"span\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"bondInstructions\",\"type\":\"tuple[]\",\"internalType\":\"structLibBonds.BondInstruction[]\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"bondType\",\"type\":\"uint8\",\"internalType\":\"enumLibBonds.BondType\"},{\"name\":\"payer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"receiver\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"transitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpointHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"metadata\",\"type\":\"tuple\",\"internalType\":\"structIInbox.TransitionMetadata\",\"components\":[{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"}]}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"decodeProvedEventOptimized\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"payload_\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProvedEventPayload\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"transition\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Transition\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]},{\"name\":\"transitionRecord\",\"type\":\"tuple\",\"internalType\":\"structIInbox.TransitionRecord\",\"components\":[{\"name\":\"span\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"bondInstructions\",\"type\":\"tuple[]\",\"internalType\":\"structLibBonds.BondInstruction[]\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"bondType\",\"type\":\"uint8\",\"internalType\":\"enumLibBonds.BondType\"},{\"name\":\"payer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"receiver\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"transitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpointHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"metadata\",\"type\":\"tuple\",\"internalType\":\"structIInbox.TransitionMetadata\",\"components\":[{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"}]}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"encodeProposeInput\",\"inputs\":[{\"name\":\"_input\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProposeInput\",\"components\":[{\"name\":\"deadline\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"coreState\",\"type\":\"tuple\",\"internalType\":\"structIInbox.CoreState\",\"components\":[{\"name\":\"nextProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"nextProposalBlockId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"bondInstructionsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"parentProposals\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Proposal[]\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"coreStateHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"blobReference\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobReference\",\"components\":[{\"name\":\"blobStartIndex\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"numBlobs\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"}]},{\"name\":\"transitionRecords\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.TransitionRecord[]\",\"components\":[{\"name\":\"span\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"bondInstructions\",\"type\":\"tuple[]\",\"internalType\":\"structLibBonds.BondInstruction[]\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"bondType\",\"type\":\"uint8\",\"internalType\":\"enumLibBonds.BondType\"},{\"name\":\"payer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"receiver\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"transitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpointHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"numForcedInclusions\",\"type\":\"uint8\",\"internalType\":\"uint8\"}]}],\"outputs\":[{\"name\":\"encoded_\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"encodeProposeInputOptimized\",\"inputs\":[{\"name\":\"_input\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProposeInput\",\"components\":[{\"name\":\"deadline\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"coreState\",\"type\":\"tuple\",\"internalType\":\"structIInbox.CoreState\",\"components\":[{\"name\":\"nextProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"nextProposalBlockId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"bondInstructionsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"parentProposals\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Proposal[]\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"coreStateHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"blobReference\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobReference\",\"components\":[{\"name\":\"blobStartIndex\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"numBlobs\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"}]},{\"name\":\"transitionRecords\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.TransitionRecord[]\",\"components\":[{\"name\":\"span\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"bondInstructions\",\"type\":\"tuple[]\",\"internalType\":\"structLibBonds.BondInstruction[]\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"bondType\",\"type\":\"uint8\",\"internalType\":\"enumLibBonds.BondType\"},{\"name\":\"payer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"receiver\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"transitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpointHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"numForcedInclusions\",\"type\":\"uint8\",\"internalType\":\"uint8\"}]}],\"outputs\":[{\"name\":\"encoded_\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"encodeProposedEvent\",\"inputs\":[{\"name\":\"_payload\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProposedEventPayload\",\"components\":[{\"name\":\"proposal\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Proposal\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"coreStateHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"derivation\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Derivation\",\"components\":[{\"name\":\"originBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"originBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"isForcedInclusion\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]},{\"name\":\"coreState\",\"type\":\"tuple\",\"internalType\":\"structIInbox.CoreState\",\"components\":[{\"name\":\"nextProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"nextProposalBlockId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"bondInstructionsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]}],\"outputs\":[{\"name\":\"encoded_\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"encodeProposedEventOptimized\",\"inputs\":[{\"name\":\"_payload\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProposedEventPayload\",\"components\":[{\"name\":\"proposal\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Proposal\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"coreStateHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"derivation\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Derivation\",\"components\":[{\"name\":\"originBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"originBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"isForcedInclusion\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]},{\"name\":\"coreState\",\"type\":\"tuple\",\"internalType\":\"structIInbox.CoreState\",\"components\":[{\"name\":\"nextProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"nextProposalBlockId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"bondInstructionsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]}],\"outputs\":[{\"name\":\"encoded_\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"encodeProveInput\",\"inputs\":[{\"name\":\"_input\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProveInput\",\"components\":[{\"name\":\"proposals\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Proposal[]\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"coreStateHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"transitions\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Transition[]\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]},{\"name\":\"metadata\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.TransitionMetadata[]\",\"components\":[{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"}]}]}],\"outputs\":[{\"name\":\"encoded_\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"encodeProveInputOptimized\",\"inputs\":[{\"name\":\"_input\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProveInput\",\"components\":[{\"name\":\"proposals\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Proposal[]\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"coreStateHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"transitions\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Transition[]\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]},{\"name\":\"metadata\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.TransitionMetadata[]\",\"components\":[{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"}]}]}],\"outputs\":[{\"name\":\"encoded_\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"encodeProvedEvent\",\"inputs\":[{\"name\":\"_payload\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProvedEventPayload\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"transition\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Transition\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]},{\"name\":\"transitionRecord\",\"type\":\"tuple\",\"internalType\":\"structIInbox.TransitionRecord\",\"components\":[{\"name\":\"span\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"bondInstructions\",\"type\":\"tuple[]\",\"internalType\":\"structLibBonds.BondInstruction[]\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"bondType\",\"type\":\"uint8\",\"internalType\":\"enumLibBonds.BondType\"},{\"name\":\"payer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"receiver\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"transitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpointHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"metadata\",\"type\":\"tuple\",\"internalType\":\"structIInbox.TransitionMetadata\",\"components\":[{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"}]}]}],\"outputs\":[{\"name\":\"encoded_\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"encodeProvedEventOptimized\",\"inputs\":[{\"name\":\"_payload\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProvedEventPayload\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"transition\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Transition\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]},{\"name\":\"transitionRecord\",\"type\":\"tuple\",\"internalType\":\"structIInbox.TransitionRecord\",\"components\":[{\"name\":\"span\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"bondInstructions\",\"type\":\"tuple[]\",\"internalType\":\"structLibBonds.BondInstruction[]\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"bondType\",\"type\":\"uint8\",\"internalType\":\"enumLibBonds.BondType\"},{\"name\":\"payer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"receiver\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"transitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpointHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"metadata\",\"type\":\"tuple\",\"internalType\":\"structIInbox.TransitionMetadata\",\"components\":[{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"}]}]}],\"outputs\":[{\"name\":\"encoded_\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashCheckpoint\",\"inputs\":[{\"name\":\"_checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashCheckpointOptimized\",\"inputs\":[{\"name\":\"_checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashCoreState\",\"inputs\":[{\"name\":\"_coreState\",\"type\":\"tuple\",\"internalType\":\"structIInbox.CoreState\",\"components\":[{\"name\":\"nextProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"nextProposalBlockId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"bondInstructionsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashCoreStateOptimized\",\"inputs\":[{\"name\":\"_coreState\",\"type\":\"tuple\",\"internalType\":\"structIInbox.CoreState\",\"components\":[{\"name\":\"nextProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"nextProposalBlockId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"bondInstructionsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashDerivation\",\"inputs\":[{\"name\":\"_derivation\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Derivation\",\"components\":[{\"name\":\"originBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"originBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"isForcedInclusion\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashDerivationOptimized\",\"inputs\":[{\"name\":\"_derivation\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Derivation\",\"components\":[{\"name\":\"originBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"originBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"isForcedInclusion\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashProposal\",\"inputs\":[{\"name\":\"_proposal\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Proposal\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"coreStateHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashProposalOptimized\",\"inputs\":[{\"name\":\"_proposal\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Proposal\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"coreStateHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashTransition\",\"inputs\":[{\"name\":\"_transition\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Transition\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashTransitionOptimized\",\"inputs\":[{\"name\":\"_transition\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Transition\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashTransitionRecord\",\"inputs\":[{\"name\":\"_transitionRecord\",\"type\":\"tuple\",\"internalType\":\"structIInbox.TransitionRecord\",\"components\":[{\"name\":\"span\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"bondInstructions\",\"type\":\"tuple[]\",\"internalType\":\"structLibBonds.BondInstruction[]\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"bondType\",\"type\":\"uint8\",\"internalType\":\"enumLibBonds.BondType\"},{\"name\":\"payer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"receiver\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"transitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpointHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes26\",\"internalType\":\"bytes26\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashTransitionRecordOptimized\",\"inputs\":[{\"name\":\"_transitionRecord\",\"type\":\"tuple\",\"internalType\":\"structIInbox.TransitionRecord\",\"components\":[{\"name\":\"span\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"bondInstructions\",\"type\":\"tuple[]\",\"internalType\":\"structLibBonds.BondInstruction[]\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"bondType\",\"type\":\"uint8\",\"internalType\":\"enumLibBonds.BondType\"},{\"name\":\"payer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"receiver\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"transitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpointHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes26\",\"internalType\":\"bytes26\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashTransitionsArray\",\"inputs\":[{\"name\":\"_transitions\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Transition[]\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashTransitionsArrayOptimized\",\"inputs\":[{\"name\":\"_transitions\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Transition[]\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"error\",\"name\":\"BondInstructionsLengthExceeded\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"LengthExceedsUint24\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ProposalTransitionLengthMismatch\",\"inputs\":[]}]",
}

// InboxHelperClientABI is the input ABI used to generate the binding from.
// Deprecated: Use InboxHelperClientMetaData.ABI instead.
var InboxHelperClientABI = InboxHelperClientMetaData.ABI

// InboxHelperClient is an auto generated Go binding around an Ethereum contract.
type InboxHelperClient struct {
	InboxHelperClientCaller     // Read-only binding to the contract
	InboxHelperClientTransactor // Write-only binding to the contract
	InboxHelperClientFilterer   // Log filterer for contract events
}

// InboxHelperClientCaller is an auto generated read-only Go binding around an Ethereum contract.
type InboxHelperClientCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// InboxHelperClientTransactor is an auto generated write-only Go binding around an Ethereum contract.
type InboxHelperClientTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// InboxHelperClientFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type InboxHelperClientFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// InboxHelperClientSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type InboxHelperClientSession struct {
	Contract     *InboxHelperClient // Generic contract binding to set the session for
	CallOpts     bind.CallOpts      // Call options to use throughout this session
	TransactOpts bind.TransactOpts  // Transaction auth options to use throughout this session
}

// InboxHelperClientCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type InboxHelperClientCallerSession struct {
	Contract *InboxHelperClientCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts            // Call options to use throughout this session
}

// InboxHelperClientTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type InboxHelperClientTransactorSession struct {
	Contract     *InboxHelperClientTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts            // Transaction auth options to use throughout this session
}

// InboxHelperClientRaw is an auto generated low-level Go binding around an Ethereum contract.
type InboxHelperClientRaw struct {
	Contract *InboxHelperClient // Generic contract binding to access the raw methods on
}

// InboxHelperClientCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type InboxHelperClientCallerRaw struct {
	Contract *InboxHelperClientCaller // Generic read-only contract binding to access the raw methods on
}

// InboxHelperClientTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type InboxHelperClientTransactorRaw struct {
	Contract *InboxHelperClientTransactor // Generic write-only contract binding to access the raw methods on
}

// NewInboxHelperClient creates a new instance of InboxHelperClient, bound to a specific deployed contract.
func NewInboxHelperClient(address common.Address, backend bind.ContractBackend) (*InboxHelperClient, error) {
	contract, err := bindInboxHelperClient(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &InboxHelperClient{InboxHelperClientCaller: InboxHelperClientCaller{contract: contract}, InboxHelperClientTransactor: InboxHelperClientTransactor{contract: contract}, InboxHelperClientFilterer: InboxHelperClientFilterer{contract: contract}}, nil
}

// NewInboxHelperClientCaller creates a new read-only instance of InboxHelperClient, bound to a specific deployed contract.
func NewInboxHelperClientCaller(address common.Address, caller bind.ContractCaller) (*InboxHelperClientCaller, error) {
	contract, err := bindInboxHelperClient(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &InboxHelperClientCaller{contract: contract}, nil
}

// NewInboxHelperClientTransactor creates a new write-only instance of InboxHelperClient, bound to a specific deployed contract.
func NewInboxHelperClientTransactor(address common.Address, transactor bind.ContractTransactor) (*InboxHelperClientTransactor, error) {
	contract, err := bindInboxHelperClient(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &InboxHelperClientTransactor{contract: contract}, nil
}

// NewInboxHelperClientFilterer creates a new log filterer instance of InboxHelperClient, bound to a specific deployed contract.
func NewInboxHelperClientFilterer(address common.Address, filterer bind.ContractFilterer) (*InboxHelperClientFilterer, error) {
	contract, err := bindInboxHelperClient(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &InboxHelperClientFilterer{contract: contract}, nil
}

// bindInboxHelperClient binds a generic wrapper to an already deployed contract.
func bindInboxHelperClient(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := InboxHelperClientMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_InboxHelperClient *InboxHelperClientRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _InboxHelperClient.Contract.InboxHelperClientCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_InboxHelperClient *InboxHelperClientRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _InboxHelperClient.Contract.InboxHelperClientTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_InboxHelperClient *InboxHelperClientRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _InboxHelperClient.Contract.InboxHelperClientTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_InboxHelperClient *InboxHelperClientCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _InboxHelperClient.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_InboxHelperClient *InboxHelperClientTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _InboxHelperClient.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_InboxHelperClient *InboxHelperClientTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _InboxHelperClient.Contract.contract.Transact(opts, method, params...)
}

// DecodeProposeInput is a free data retrieval call binding the contract method 0xafb63ad4.
//
// Solidity: function decodeProposeInput(bytes _data) pure returns((uint48,(uint48,uint48,uint48,bytes32,bytes32),(uint48,uint48,uint48,address,bytes32,bytes32)[],(uint16,uint16,uint24),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32)[],(uint48,bytes32,bytes32),uint8) input_)
func (_InboxHelperClient *InboxHelperClientCaller) DecodeProposeInput(opts *bind.CallOpts, _data []byte) (IInboxProposeInput, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "decodeProposeInput", _data)

	if err != nil {
		return *new(IInboxProposeInput), err
	}

	out0 := *abi.ConvertType(out[0], new(IInboxProposeInput)).(*IInboxProposeInput)

	return out0, err

}

// DecodeProposeInput is a free data retrieval call binding the contract method 0xafb63ad4.
//
// Solidity: function decodeProposeInput(bytes _data) pure returns((uint48,(uint48,uint48,uint48,bytes32,bytes32),(uint48,uint48,uint48,address,bytes32,bytes32)[],(uint16,uint16,uint24),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32)[],(uint48,bytes32,bytes32),uint8) input_)
func (_InboxHelperClient *InboxHelperClientSession) DecodeProposeInput(_data []byte) (IInboxProposeInput, error) {
	return _InboxHelperClient.Contract.DecodeProposeInput(&_InboxHelperClient.CallOpts, _data)
}

// DecodeProposeInput is a free data retrieval call binding the contract method 0xafb63ad4.
//
// Solidity: function decodeProposeInput(bytes _data) pure returns((uint48,(uint48,uint48,uint48,bytes32,bytes32),(uint48,uint48,uint48,address,bytes32,bytes32)[],(uint16,uint16,uint24),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32)[],(uint48,bytes32,bytes32),uint8) input_)
func (_InboxHelperClient *InboxHelperClientCallerSession) DecodeProposeInput(_data []byte) (IInboxProposeInput, error) {
	return _InboxHelperClient.Contract.DecodeProposeInput(&_InboxHelperClient.CallOpts, _data)
}

// DecodeProposeInputOptimized is a free data retrieval call binding the contract method 0x907926f0.
//
// Solidity: function decodeProposeInputOptimized(bytes _data) pure returns((uint48,(uint48,uint48,uint48,bytes32,bytes32),(uint48,uint48,uint48,address,bytes32,bytes32)[],(uint16,uint16,uint24),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32)[],(uint48,bytes32,bytes32),uint8) input_)
func (_InboxHelperClient *InboxHelperClientCaller) DecodeProposeInputOptimized(opts *bind.CallOpts, _data []byte) (IInboxProposeInput, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "decodeProposeInputOptimized", _data)

	if err != nil {
		return *new(IInboxProposeInput), err
	}

	out0 := *abi.ConvertType(out[0], new(IInboxProposeInput)).(*IInboxProposeInput)

	return out0, err

}

// DecodeProposeInputOptimized is a free data retrieval call binding the contract method 0x907926f0.
//
// Solidity: function decodeProposeInputOptimized(bytes _data) pure returns((uint48,(uint48,uint48,uint48,bytes32,bytes32),(uint48,uint48,uint48,address,bytes32,bytes32)[],(uint16,uint16,uint24),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32)[],(uint48,bytes32,bytes32),uint8) input_)
func (_InboxHelperClient *InboxHelperClientSession) DecodeProposeInputOptimized(_data []byte) (IInboxProposeInput, error) {
	return _InboxHelperClient.Contract.DecodeProposeInputOptimized(&_InboxHelperClient.CallOpts, _data)
}

// DecodeProposeInputOptimized is a free data retrieval call binding the contract method 0x907926f0.
//
// Solidity: function decodeProposeInputOptimized(bytes _data) pure returns((uint48,(uint48,uint48,uint48,bytes32,bytes32),(uint48,uint48,uint48,address,bytes32,bytes32)[],(uint16,uint16,uint24),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32)[],(uint48,bytes32,bytes32),uint8) input_)
func (_InboxHelperClient *InboxHelperClientCallerSession) DecodeProposeInputOptimized(_data []byte) (IInboxProposeInput, error) {
	return _InboxHelperClient.Contract.DecodeProposeInputOptimized(&_InboxHelperClient.CallOpts, _data)
}

// DecodeProposedEvent is a free data retrieval call binding the contract method 0x5d27cc95.
//
// Solidity: function decodeProposedEvent(bytes _data) pure returns(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)),(uint48,uint48,uint48,bytes32,bytes32)) payload_)
func (_InboxHelperClient *InboxHelperClientCaller) DecodeProposedEvent(opts *bind.CallOpts, _data []byte) (IInboxProposedEventPayload, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "decodeProposedEvent", _data)

	if err != nil {
		return *new(IInboxProposedEventPayload), err
	}

	out0 := *abi.ConvertType(out[0], new(IInboxProposedEventPayload)).(*IInboxProposedEventPayload)

	return out0, err

}

// DecodeProposedEvent is a free data retrieval call binding the contract method 0x5d27cc95.
//
// Solidity: function decodeProposedEvent(bytes _data) pure returns(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)),(uint48,uint48,uint48,bytes32,bytes32)) payload_)
func (_InboxHelperClient *InboxHelperClientSession) DecodeProposedEvent(_data []byte) (IInboxProposedEventPayload, error) {
	return _InboxHelperClient.Contract.DecodeProposedEvent(&_InboxHelperClient.CallOpts, _data)
}

// DecodeProposedEvent is a free data retrieval call binding the contract method 0x5d27cc95.
//
// Solidity: function decodeProposedEvent(bytes _data) pure returns(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)),(uint48,uint48,uint48,bytes32,bytes32)) payload_)
func (_InboxHelperClient *InboxHelperClientCallerSession) DecodeProposedEvent(_data []byte) (IInboxProposedEventPayload, error) {
	return _InboxHelperClient.Contract.DecodeProposedEvent(&_InboxHelperClient.CallOpts, _data)
}

// DecodeProposedEventOptimized is a free data retrieval call binding the contract method 0xc5063c47.
//
// Solidity: function decodeProposedEventOptimized(bytes _data) pure returns(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)),(uint48,uint48,uint48,bytes32,bytes32)) payload_)
func (_InboxHelperClient *InboxHelperClientCaller) DecodeProposedEventOptimized(opts *bind.CallOpts, _data []byte) (IInboxProposedEventPayload, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "decodeProposedEventOptimized", _data)

	if err != nil {
		return *new(IInboxProposedEventPayload), err
	}

	out0 := *abi.ConvertType(out[0], new(IInboxProposedEventPayload)).(*IInboxProposedEventPayload)

	return out0, err

}

// DecodeProposedEventOptimized is a free data retrieval call binding the contract method 0xc5063c47.
//
// Solidity: function decodeProposedEventOptimized(bytes _data) pure returns(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)),(uint48,uint48,uint48,bytes32,bytes32)) payload_)
func (_InboxHelperClient *InboxHelperClientSession) DecodeProposedEventOptimized(_data []byte) (IInboxProposedEventPayload, error) {
	return _InboxHelperClient.Contract.DecodeProposedEventOptimized(&_InboxHelperClient.CallOpts, _data)
}

// DecodeProposedEventOptimized is a free data retrieval call binding the contract method 0xc5063c47.
//
// Solidity: function decodeProposedEventOptimized(bytes _data) pure returns(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)),(uint48,uint48,uint48,bytes32,bytes32)) payload_)
func (_InboxHelperClient *InboxHelperClientCallerSession) DecodeProposedEventOptimized(_data []byte) (IInboxProposedEventPayload, error) {
	return _InboxHelperClient.Contract.DecodeProposedEventOptimized(&_InboxHelperClient.CallOpts, _data)
}

// DecodeProveInput is a free data retrieval call binding the contract method 0xedbacd44.
//
// Solidity: function decodeProveInput(bytes _data) pure returns(((uint48,uint48,uint48,address,bytes32,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32))[],(address,address)[]) input_)
func (_InboxHelperClient *InboxHelperClientCaller) DecodeProveInput(opts *bind.CallOpts, _data []byte) (IInboxProveInput, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "decodeProveInput", _data)

	if err != nil {
		return *new(IInboxProveInput), err
	}

	out0 := *abi.ConvertType(out[0], new(IInboxProveInput)).(*IInboxProveInput)

	return out0, err

}

// DecodeProveInput is a free data retrieval call binding the contract method 0xedbacd44.
//
// Solidity: function decodeProveInput(bytes _data) pure returns(((uint48,uint48,uint48,address,bytes32,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32))[],(address,address)[]) input_)
func (_InboxHelperClient *InboxHelperClientSession) DecodeProveInput(_data []byte) (IInboxProveInput, error) {
	return _InboxHelperClient.Contract.DecodeProveInput(&_InboxHelperClient.CallOpts, _data)
}

// DecodeProveInput is a free data retrieval call binding the contract method 0xedbacd44.
//
// Solidity: function decodeProveInput(bytes _data) pure returns(((uint48,uint48,uint48,address,bytes32,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32))[],(address,address)[]) input_)
func (_InboxHelperClient *InboxHelperClientCallerSession) DecodeProveInput(_data []byte) (IInboxProveInput, error) {
	return _InboxHelperClient.Contract.DecodeProveInput(&_InboxHelperClient.CallOpts, _data)
}

// DecodeProveInputOptimized is a free data retrieval call binding the contract method 0x14ea7d0c.
//
// Solidity: function decodeProveInputOptimized(bytes _data) pure returns(((uint48,uint48,uint48,address,bytes32,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32))[],(address,address)[]) input_)
func (_InboxHelperClient *InboxHelperClientCaller) DecodeProveInputOptimized(opts *bind.CallOpts, _data []byte) (IInboxProveInput, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "decodeProveInputOptimized", _data)

	if err != nil {
		return *new(IInboxProveInput), err
	}

	out0 := *abi.ConvertType(out[0], new(IInboxProveInput)).(*IInboxProveInput)

	return out0, err

}

// DecodeProveInputOptimized is a free data retrieval call binding the contract method 0x14ea7d0c.
//
// Solidity: function decodeProveInputOptimized(bytes _data) pure returns(((uint48,uint48,uint48,address,bytes32,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32))[],(address,address)[]) input_)
func (_InboxHelperClient *InboxHelperClientSession) DecodeProveInputOptimized(_data []byte) (IInboxProveInput, error) {
	return _InboxHelperClient.Contract.DecodeProveInputOptimized(&_InboxHelperClient.CallOpts, _data)
}

// DecodeProveInputOptimized is a free data retrieval call binding the contract method 0x14ea7d0c.
//
// Solidity: function decodeProveInputOptimized(bytes _data) pure returns(((uint48,uint48,uint48,address,bytes32,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32))[],(address,address)[]) input_)
func (_InboxHelperClient *InboxHelperClientCallerSession) DecodeProveInputOptimized(_data []byte) (IInboxProveInput, error) {
	return _InboxHelperClient.Contract.DecodeProveInputOptimized(&_InboxHelperClient.CallOpts, _data)
}

// DecodeProvedEvent is a free data retrieval call binding the contract method 0x26303962.
//
// Solidity: function decodeProvedEvent(bytes _data) pure returns((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32)),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32),(address,address)) payload_)
func (_InboxHelperClient *InboxHelperClientCaller) DecodeProvedEvent(opts *bind.CallOpts, _data []byte) (IInboxProvedEventPayload, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "decodeProvedEvent", _data)

	if err != nil {
		return *new(IInboxProvedEventPayload), err
	}

	out0 := *abi.ConvertType(out[0], new(IInboxProvedEventPayload)).(*IInboxProvedEventPayload)

	return out0, err

}

// DecodeProvedEvent is a free data retrieval call binding the contract method 0x26303962.
//
// Solidity: function decodeProvedEvent(bytes _data) pure returns((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32)),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32),(address,address)) payload_)
func (_InboxHelperClient *InboxHelperClientSession) DecodeProvedEvent(_data []byte) (IInboxProvedEventPayload, error) {
	return _InboxHelperClient.Contract.DecodeProvedEvent(&_InboxHelperClient.CallOpts, _data)
}

// DecodeProvedEvent is a free data retrieval call binding the contract method 0x26303962.
//
// Solidity: function decodeProvedEvent(bytes _data) pure returns((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32)),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32),(address,address)) payload_)
func (_InboxHelperClient *InboxHelperClientCallerSession) DecodeProvedEvent(_data []byte) (IInboxProvedEventPayload, error) {
	return _InboxHelperClient.Contract.DecodeProvedEvent(&_InboxHelperClient.CallOpts, _data)
}

// DecodeProvedEventOptimized is a free data retrieval call binding the contract method 0x4ca66857.
//
// Solidity: function decodeProvedEventOptimized(bytes _data) pure returns((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32)),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32),(address,address)) payload_)
func (_InboxHelperClient *InboxHelperClientCaller) DecodeProvedEventOptimized(opts *bind.CallOpts, _data []byte) (IInboxProvedEventPayload, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "decodeProvedEventOptimized", _data)

	if err != nil {
		return *new(IInboxProvedEventPayload), err
	}

	out0 := *abi.ConvertType(out[0], new(IInboxProvedEventPayload)).(*IInboxProvedEventPayload)

	return out0, err

}

// DecodeProvedEventOptimized is a free data retrieval call binding the contract method 0x4ca66857.
//
// Solidity: function decodeProvedEventOptimized(bytes _data) pure returns((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32)),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32),(address,address)) payload_)
func (_InboxHelperClient *InboxHelperClientSession) DecodeProvedEventOptimized(_data []byte) (IInboxProvedEventPayload, error) {
	return _InboxHelperClient.Contract.DecodeProvedEventOptimized(&_InboxHelperClient.CallOpts, _data)
}

// DecodeProvedEventOptimized is a free data retrieval call binding the contract method 0x4ca66857.
//
// Solidity: function decodeProvedEventOptimized(bytes _data) pure returns((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32)),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32),(address,address)) payload_)
func (_InboxHelperClient *InboxHelperClientCallerSession) DecodeProvedEventOptimized(_data []byte) (IInboxProvedEventPayload, error) {
	return _InboxHelperClient.Contract.DecodeProvedEventOptimized(&_InboxHelperClient.CallOpts, _data)
}

// EncodeProposeInput is a free data retrieval call binding the contract method 0x2b41c9ca.
//
// Solidity: function encodeProposeInput((uint48,(uint48,uint48,uint48,bytes32,bytes32),(uint48,uint48,uint48,address,bytes32,bytes32)[],(uint16,uint16,uint24),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32)[],(uint48,bytes32,bytes32),uint8) _input) pure returns(bytes encoded_)
func (_InboxHelperClient *InboxHelperClientCaller) EncodeProposeInput(opts *bind.CallOpts, _input IInboxProposeInput) ([]byte, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "encodeProposeInput", _input)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProposeInput is a free data retrieval call binding the contract method 0x2b41c9ca.
//
// Solidity: function encodeProposeInput((uint48,(uint48,uint48,uint48,bytes32,bytes32),(uint48,uint48,uint48,address,bytes32,bytes32)[],(uint16,uint16,uint24),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32)[],(uint48,bytes32,bytes32),uint8) _input) pure returns(bytes encoded_)
func (_InboxHelperClient *InboxHelperClientSession) EncodeProposeInput(_input IInboxProposeInput) ([]byte, error) {
	return _InboxHelperClient.Contract.EncodeProposeInput(&_InboxHelperClient.CallOpts, _input)
}

// EncodeProposeInput is a free data retrieval call binding the contract method 0x2b41c9ca.
//
// Solidity: function encodeProposeInput((uint48,(uint48,uint48,uint48,bytes32,bytes32),(uint48,uint48,uint48,address,bytes32,bytes32)[],(uint16,uint16,uint24),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32)[],(uint48,bytes32,bytes32),uint8) _input) pure returns(bytes encoded_)
func (_InboxHelperClient *InboxHelperClientCallerSession) EncodeProposeInput(_input IInboxProposeInput) ([]byte, error) {
	return _InboxHelperClient.Contract.EncodeProposeInput(&_InboxHelperClient.CallOpts, _input)
}

// EncodeProposeInputOptimized is a free data retrieval call binding the contract method 0x9f9aee29.
//
// Solidity: function encodeProposeInputOptimized((uint48,(uint48,uint48,uint48,bytes32,bytes32),(uint48,uint48,uint48,address,bytes32,bytes32)[],(uint16,uint16,uint24),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32)[],(uint48,bytes32,bytes32),uint8) _input) pure returns(bytes encoded_)
func (_InboxHelperClient *InboxHelperClientCaller) EncodeProposeInputOptimized(opts *bind.CallOpts, _input IInboxProposeInput) ([]byte, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "encodeProposeInputOptimized", _input)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProposeInputOptimized is a free data retrieval call binding the contract method 0x9f9aee29.
//
// Solidity: function encodeProposeInputOptimized((uint48,(uint48,uint48,uint48,bytes32,bytes32),(uint48,uint48,uint48,address,bytes32,bytes32)[],(uint16,uint16,uint24),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32)[],(uint48,bytes32,bytes32),uint8) _input) pure returns(bytes encoded_)
func (_InboxHelperClient *InboxHelperClientSession) EncodeProposeInputOptimized(_input IInboxProposeInput) ([]byte, error) {
	return _InboxHelperClient.Contract.EncodeProposeInputOptimized(&_InboxHelperClient.CallOpts, _input)
}

// EncodeProposeInputOptimized is a free data retrieval call binding the contract method 0x9f9aee29.
//
// Solidity: function encodeProposeInputOptimized((uint48,(uint48,uint48,uint48,bytes32,bytes32),(uint48,uint48,uint48,address,bytes32,bytes32)[],(uint16,uint16,uint24),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32)[],(uint48,bytes32,bytes32),uint8) _input) pure returns(bytes encoded_)
func (_InboxHelperClient *InboxHelperClientCallerSession) EncodeProposeInputOptimized(_input IInboxProposeInput) ([]byte, error) {
	return _InboxHelperClient.Contract.EncodeProposeInputOptimized(&_InboxHelperClient.CallOpts, _input)
}

// EncodeProposedEvent is a free data retrieval call binding the contract method 0x559814cf.
//
// Solidity: function encodeProposedEvent(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)),(uint48,uint48,uint48,bytes32,bytes32)) _payload) pure returns(bytes encoded_)
func (_InboxHelperClient *InboxHelperClientCaller) EncodeProposedEvent(opts *bind.CallOpts, _payload IInboxProposedEventPayload) ([]byte, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "encodeProposedEvent", _payload)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProposedEvent is a free data retrieval call binding the contract method 0x559814cf.
//
// Solidity: function encodeProposedEvent(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)),(uint48,uint48,uint48,bytes32,bytes32)) _payload) pure returns(bytes encoded_)
func (_InboxHelperClient *InboxHelperClientSession) EncodeProposedEvent(_payload IInboxProposedEventPayload) ([]byte, error) {
	return _InboxHelperClient.Contract.EncodeProposedEvent(&_InboxHelperClient.CallOpts, _payload)
}

// EncodeProposedEvent is a free data retrieval call binding the contract method 0x559814cf.
//
// Solidity: function encodeProposedEvent(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)),(uint48,uint48,uint48,bytes32,bytes32)) _payload) pure returns(bytes encoded_)
func (_InboxHelperClient *InboxHelperClientCallerSession) EncodeProposedEvent(_payload IInboxProposedEventPayload) ([]byte, error) {
	return _InboxHelperClient.Contract.EncodeProposedEvent(&_InboxHelperClient.CallOpts, _payload)
}

// EncodeProposedEventOptimized is a free data retrieval call binding the contract method 0x1c8ce4be.
//
// Solidity: function encodeProposedEventOptimized(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)),(uint48,uint48,uint48,bytes32,bytes32)) _payload) pure returns(bytes encoded_)
func (_InboxHelperClient *InboxHelperClientCaller) EncodeProposedEventOptimized(opts *bind.CallOpts, _payload IInboxProposedEventPayload) ([]byte, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "encodeProposedEventOptimized", _payload)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProposedEventOptimized is a free data retrieval call binding the contract method 0x1c8ce4be.
//
// Solidity: function encodeProposedEventOptimized(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)),(uint48,uint48,uint48,bytes32,bytes32)) _payload) pure returns(bytes encoded_)
func (_InboxHelperClient *InboxHelperClientSession) EncodeProposedEventOptimized(_payload IInboxProposedEventPayload) ([]byte, error) {
	return _InboxHelperClient.Contract.EncodeProposedEventOptimized(&_InboxHelperClient.CallOpts, _payload)
}

// EncodeProposedEventOptimized is a free data retrieval call binding the contract method 0x1c8ce4be.
//
// Solidity: function encodeProposedEventOptimized(((uint48,uint48,uint48,address,bytes32,bytes32),(uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)),(uint48,uint48,uint48,bytes32,bytes32)) _payload) pure returns(bytes encoded_)
func (_InboxHelperClient *InboxHelperClientCallerSession) EncodeProposedEventOptimized(_payload IInboxProposedEventPayload) ([]byte, error) {
	return _InboxHelperClient.Contract.EncodeProposedEventOptimized(&_InboxHelperClient.CallOpts, _payload)
}

// EncodeProveInput is a free data retrieval call binding the contract method 0xdc5a8bf8.
//
// Solidity: function encodeProveInput(((uint48,uint48,uint48,address,bytes32,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32))[],(address,address)[]) _input) pure returns(bytes encoded_)
func (_InboxHelperClient *InboxHelperClientCaller) EncodeProveInput(opts *bind.CallOpts, _input IInboxProveInput) ([]byte, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "encodeProveInput", _input)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProveInput is a free data retrieval call binding the contract method 0xdc5a8bf8.
//
// Solidity: function encodeProveInput(((uint48,uint48,uint48,address,bytes32,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32))[],(address,address)[]) _input) pure returns(bytes encoded_)
func (_InboxHelperClient *InboxHelperClientSession) EncodeProveInput(_input IInboxProveInput) ([]byte, error) {
	return _InboxHelperClient.Contract.EncodeProveInput(&_InboxHelperClient.CallOpts, _input)
}

// EncodeProveInput is a free data retrieval call binding the contract method 0xdc5a8bf8.
//
// Solidity: function encodeProveInput(((uint48,uint48,uint48,address,bytes32,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32))[],(address,address)[]) _input) pure returns(bytes encoded_)
func (_InboxHelperClient *InboxHelperClientCallerSession) EncodeProveInput(_input IInboxProveInput) ([]byte, error) {
	return _InboxHelperClient.Contract.EncodeProveInput(&_InboxHelperClient.CallOpts, _input)
}

// EncodeProveInputOptimized is a free data retrieval call binding the contract method 0x0cb2d1f6.
//
// Solidity: function encodeProveInputOptimized(((uint48,uint48,uint48,address,bytes32,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32))[],(address,address)[]) _input) pure returns(bytes encoded_)
func (_InboxHelperClient *InboxHelperClientCaller) EncodeProveInputOptimized(opts *bind.CallOpts, _input IInboxProveInput) ([]byte, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "encodeProveInputOptimized", _input)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProveInputOptimized is a free data retrieval call binding the contract method 0x0cb2d1f6.
//
// Solidity: function encodeProveInputOptimized(((uint48,uint48,uint48,address,bytes32,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32))[],(address,address)[]) _input) pure returns(bytes encoded_)
func (_InboxHelperClient *InboxHelperClientSession) EncodeProveInputOptimized(_input IInboxProveInput) ([]byte, error) {
	return _InboxHelperClient.Contract.EncodeProveInputOptimized(&_InboxHelperClient.CallOpts, _input)
}

// EncodeProveInputOptimized is a free data retrieval call binding the contract method 0x0cb2d1f6.
//
// Solidity: function encodeProveInputOptimized(((uint48,uint48,uint48,address,bytes32,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32))[],(address,address)[]) _input) pure returns(bytes encoded_)
func (_InboxHelperClient *InboxHelperClientCallerSession) EncodeProveInputOptimized(_input IInboxProveInput) ([]byte, error) {
	return _InboxHelperClient.Contract.EncodeProveInputOptimized(&_InboxHelperClient.CallOpts, _input)
}

// EncodeProvedEvent is a free data retrieval call binding the contract method 0x8f6d0e1a.
//
// Solidity: function encodeProvedEvent((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32)),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32),(address,address)) _payload) pure returns(bytes encoded_)
func (_InboxHelperClient *InboxHelperClientCaller) EncodeProvedEvent(opts *bind.CallOpts, _payload IInboxProvedEventPayload) ([]byte, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "encodeProvedEvent", _payload)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProvedEvent is a free data retrieval call binding the contract method 0x8f6d0e1a.
//
// Solidity: function encodeProvedEvent((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32)),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32),(address,address)) _payload) pure returns(bytes encoded_)
func (_InboxHelperClient *InboxHelperClientSession) EncodeProvedEvent(_payload IInboxProvedEventPayload) ([]byte, error) {
	return _InboxHelperClient.Contract.EncodeProvedEvent(&_InboxHelperClient.CallOpts, _payload)
}

// EncodeProvedEvent is a free data retrieval call binding the contract method 0x8f6d0e1a.
//
// Solidity: function encodeProvedEvent((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32)),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32),(address,address)) _payload) pure returns(bytes encoded_)
func (_InboxHelperClient *InboxHelperClientCallerSession) EncodeProvedEvent(_payload IInboxProvedEventPayload) ([]byte, error) {
	return _InboxHelperClient.Contract.EncodeProvedEvent(&_InboxHelperClient.CallOpts, _payload)
}

// EncodeProvedEventOptimized is a free data retrieval call binding the contract method 0x676de864.
//
// Solidity: function encodeProvedEventOptimized((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32)),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32),(address,address)) _payload) pure returns(bytes encoded_)
func (_InboxHelperClient *InboxHelperClientCaller) EncodeProvedEventOptimized(opts *bind.CallOpts, _payload IInboxProvedEventPayload) ([]byte, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "encodeProvedEventOptimized", _payload)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProvedEventOptimized is a free data retrieval call binding the contract method 0x676de864.
//
// Solidity: function encodeProvedEventOptimized((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32)),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32),(address,address)) _payload) pure returns(bytes encoded_)
func (_InboxHelperClient *InboxHelperClientSession) EncodeProvedEventOptimized(_payload IInboxProvedEventPayload) ([]byte, error) {
	return _InboxHelperClient.Contract.EncodeProvedEventOptimized(&_InboxHelperClient.CallOpts, _payload)
}

// EncodeProvedEventOptimized is a free data retrieval call binding the contract method 0x676de864.
//
// Solidity: function encodeProvedEventOptimized((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32)),(uint8,(uint48,uint8,address,address)[],bytes32,bytes32),(address,address)) _payload) pure returns(bytes encoded_)
func (_InboxHelperClient *InboxHelperClientCallerSession) EncodeProvedEventOptimized(_payload IInboxProvedEventPayload) ([]byte, error) {
	return _InboxHelperClient.Contract.EncodeProvedEventOptimized(&_InboxHelperClient.CallOpts, _payload)
}

// HashCheckpoint is a free data retrieval call binding the contract method 0x7989aa10.
//
// Solidity: function hashCheckpoint((uint48,bytes32,bytes32) _checkpoint) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientCaller) HashCheckpoint(opts *bind.CallOpts, _checkpoint ICheckpointStoreCheckpoint) ([32]byte, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "hashCheckpoint", _checkpoint)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashCheckpoint is a free data retrieval call binding the contract method 0x7989aa10.
//
// Solidity: function hashCheckpoint((uint48,bytes32,bytes32) _checkpoint) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientSession) HashCheckpoint(_checkpoint ICheckpointStoreCheckpoint) ([32]byte, error) {
	return _InboxHelperClient.Contract.HashCheckpoint(&_InboxHelperClient.CallOpts, _checkpoint)
}

// HashCheckpoint is a free data retrieval call binding the contract method 0x7989aa10.
//
// Solidity: function hashCheckpoint((uint48,bytes32,bytes32) _checkpoint) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientCallerSession) HashCheckpoint(_checkpoint ICheckpointStoreCheckpoint) ([32]byte, error) {
	return _InboxHelperClient.Contract.HashCheckpoint(&_InboxHelperClient.CallOpts, _checkpoint)
}

// HashCheckpointOptimized is a free data retrieval call binding the contract method 0xcd68669f.
//
// Solidity: function hashCheckpointOptimized((uint48,bytes32,bytes32) _checkpoint) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientCaller) HashCheckpointOptimized(opts *bind.CallOpts, _checkpoint ICheckpointStoreCheckpoint) ([32]byte, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "hashCheckpointOptimized", _checkpoint)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashCheckpointOptimized is a free data retrieval call binding the contract method 0xcd68669f.
//
// Solidity: function hashCheckpointOptimized((uint48,bytes32,bytes32) _checkpoint) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientSession) HashCheckpointOptimized(_checkpoint ICheckpointStoreCheckpoint) ([32]byte, error) {
	return _InboxHelperClient.Contract.HashCheckpointOptimized(&_InboxHelperClient.CallOpts, _checkpoint)
}

// HashCheckpointOptimized is a free data retrieval call binding the contract method 0xcd68669f.
//
// Solidity: function hashCheckpointOptimized((uint48,bytes32,bytes32) _checkpoint) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientCallerSession) HashCheckpointOptimized(_checkpoint ICheckpointStoreCheckpoint) ([32]byte, error) {
	return _InboxHelperClient.Contract.HashCheckpointOptimized(&_InboxHelperClient.CallOpts, _checkpoint)
}

// HashCoreState is a free data retrieval call binding the contract method 0x6f8a5cff.
//
// Solidity: function hashCoreState((uint48,uint48,uint48,bytes32,bytes32) _coreState) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientCaller) HashCoreState(opts *bind.CallOpts, _coreState IInboxCoreState) ([32]byte, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "hashCoreState", _coreState)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashCoreState is a free data retrieval call binding the contract method 0x6f8a5cff.
//
// Solidity: function hashCoreState((uint48,uint48,uint48,bytes32,bytes32) _coreState) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientSession) HashCoreState(_coreState IInboxCoreState) ([32]byte, error) {
	return _InboxHelperClient.Contract.HashCoreState(&_InboxHelperClient.CallOpts, _coreState)
}

// HashCoreState is a free data retrieval call binding the contract method 0x6f8a5cff.
//
// Solidity: function hashCoreState((uint48,uint48,uint48,bytes32,bytes32) _coreState) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientCallerSession) HashCoreState(_coreState IInboxCoreState) ([32]byte, error) {
	return _InboxHelperClient.Contract.HashCoreState(&_InboxHelperClient.CallOpts, _coreState)
}

// HashCoreStateOptimized is a free data retrieval call binding the contract method 0xe4459422.
//
// Solidity: function hashCoreStateOptimized((uint48,uint48,uint48,bytes32,bytes32) _coreState) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientCaller) HashCoreStateOptimized(opts *bind.CallOpts, _coreState IInboxCoreState) ([32]byte, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "hashCoreStateOptimized", _coreState)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashCoreStateOptimized is a free data retrieval call binding the contract method 0xe4459422.
//
// Solidity: function hashCoreStateOptimized((uint48,uint48,uint48,bytes32,bytes32) _coreState) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientSession) HashCoreStateOptimized(_coreState IInboxCoreState) ([32]byte, error) {
	return _InboxHelperClient.Contract.HashCoreStateOptimized(&_InboxHelperClient.CallOpts, _coreState)
}

// HashCoreStateOptimized is a free data retrieval call binding the contract method 0xe4459422.
//
// Solidity: function hashCoreStateOptimized((uint48,uint48,uint48,bytes32,bytes32) _coreState) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientCallerSession) HashCoreStateOptimized(_coreState IInboxCoreState) ([32]byte, error) {
	return _InboxHelperClient.Contract.HashCoreStateOptimized(&_InboxHelperClient.CallOpts, _coreState)
}

// HashDerivation is a free data retrieval call binding the contract method 0x6696f76b.
//
// Solidity: function hashDerivation((uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)) _derivation) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientCaller) HashDerivation(opts *bind.CallOpts, _derivation IInboxDerivation) ([32]byte, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "hashDerivation", _derivation)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashDerivation is a free data retrieval call binding the contract method 0x6696f76b.
//
// Solidity: function hashDerivation((uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)) _derivation) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientSession) HashDerivation(_derivation IInboxDerivation) ([32]byte, error) {
	return _InboxHelperClient.Contract.HashDerivation(&_InboxHelperClient.CallOpts, _derivation)
}

// HashDerivation is a free data retrieval call binding the contract method 0x6696f76b.
//
// Solidity: function hashDerivation((uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)) _derivation) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientCallerSession) HashDerivation(_derivation IInboxDerivation) ([32]byte, error) {
	return _InboxHelperClient.Contract.HashDerivation(&_InboxHelperClient.CallOpts, _derivation)
}

// HashDerivationOptimized is a free data retrieval call binding the contract method 0xf2c05060.
//
// Solidity: function hashDerivationOptimized((uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)) _derivation) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientCaller) HashDerivationOptimized(opts *bind.CallOpts, _derivation IInboxDerivation) ([32]byte, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "hashDerivationOptimized", _derivation)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashDerivationOptimized is a free data retrieval call binding the contract method 0xf2c05060.
//
// Solidity: function hashDerivationOptimized((uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)) _derivation) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientSession) HashDerivationOptimized(_derivation IInboxDerivation) ([32]byte, error) {
	return _InboxHelperClient.Contract.HashDerivationOptimized(&_InboxHelperClient.CallOpts, _derivation)
}

// HashDerivationOptimized is a free data retrieval call binding the contract method 0xf2c05060.
//
// Solidity: function hashDerivationOptimized((uint48,bytes32,bool,uint8,(bytes32[],uint24,uint48)) _derivation) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientCallerSession) HashDerivationOptimized(_derivation IInboxDerivation) ([32]byte, error) {
	return _InboxHelperClient.Contract.HashDerivationOptimized(&_InboxHelperClient.CallOpts, _derivation)
}

// HashProposal is a free data retrieval call binding the contract method 0xa1ec9333.
//
// Solidity: function hashProposal((uint48,uint48,uint48,address,bytes32,bytes32) _proposal) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientCaller) HashProposal(opts *bind.CallOpts, _proposal IInboxProposal) ([32]byte, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "hashProposal", _proposal)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashProposal is a free data retrieval call binding the contract method 0xa1ec9333.
//
// Solidity: function hashProposal((uint48,uint48,uint48,address,bytes32,bytes32) _proposal) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientSession) HashProposal(_proposal IInboxProposal) ([32]byte, error) {
	return _InboxHelperClient.Contract.HashProposal(&_InboxHelperClient.CallOpts, _proposal)
}

// HashProposal is a free data retrieval call binding the contract method 0xa1ec9333.
//
// Solidity: function hashProposal((uint48,uint48,uint48,address,bytes32,bytes32) _proposal) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientCallerSession) HashProposal(_proposal IInboxProposal) ([32]byte, error) {
	return _InboxHelperClient.Contract.HashProposal(&_InboxHelperClient.CallOpts, _proposal)
}

// HashProposalOptimized is a free data retrieval call binding the contract method 0xefde5f33.
//
// Solidity: function hashProposalOptimized((uint48,uint48,uint48,address,bytes32,bytes32) _proposal) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientCaller) HashProposalOptimized(opts *bind.CallOpts, _proposal IInboxProposal) ([32]byte, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "hashProposalOptimized", _proposal)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashProposalOptimized is a free data retrieval call binding the contract method 0xefde5f33.
//
// Solidity: function hashProposalOptimized((uint48,uint48,uint48,address,bytes32,bytes32) _proposal) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientSession) HashProposalOptimized(_proposal IInboxProposal) ([32]byte, error) {
	return _InboxHelperClient.Contract.HashProposalOptimized(&_InboxHelperClient.CallOpts, _proposal)
}

// HashProposalOptimized is a free data retrieval call binding the contract method 0xefde5f33.
//
// Solidity: function hashProposalOptimized((uint48,uint48,uint48,address,bytes32,bytes32) _proposal) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientCallerSession) HashProposalOptimized(_proposal IInboxProposal) ([32]byte, error) {
	return _InboxHelperClient.Contract.HashProposalOptimized(&_InboxHelperClient.CallOpts, _proposal)
}

// HashTransition is a free data retrieval call binding the contract method 0x1f397067.
//
// Solidity: function hashTransition((bytes32,bytes32,(uint48,bytes32,bytes32)) _transition) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientCaller) HashTransition(opts *bind.CallOpts, _transition IInboxTransition) ([32]byte, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "hashTransition", _transition)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashTransition is a free data retrieval call binding the contract method 0x1f397067.
//
// Solidity: function hashTransition((bytes32,bytes32,(uint48,bytes32,bytes32)) _transition) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientSession) HashTransition(_transition IInboxTransition) ([32]byte, error) {
	return _InboxHelperClient.Contract.HashTransition(&_InboxHelperClient.CallOpts, _transition)
}

// HashTransition is a free data retrieval call binding the contract method 0x1f397067.
//
// Solidity: function hashTransition((bytes32,bytes32,(uint48,bytes32,bytes32)) _transition) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientCallerSession) HashTransition(_transition IInboxTransition) ([32]byte, error) {
	return _InboxHelperClient.Contract.HashTransition(&_InboxHelperClient.CallOpts, _transition)
}

// HashTransitionOptimized is a free data retrieval call binding the contract method 0x71354cb5.
//
// Solidity: function hashTransitionOptimized((bytes32,bytes32,(uint48,bytes32,bytes32)) _transition) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientCaller) HashTransitionOptimized(opts *bind.CallOpts, _transition IInboxTransition) ([32]byte, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "hashTransitionOptimized", _transition)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashTransitionOptimized is a free data retrieval call binding the contract method 0x71354cb5.
//
// Solidity: function hashTransitionOptimized((bytes32,bytes32,(uint48,bytes32,bytes32)) _transition) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientSession) HashTransitionOptimized(_transition IInboxTransition) ([32]byte, error) {
	return _InboxHelperClient.Contract.HashTransitionOptimized(&_InboxHelperClient.CallOpts, _transition)
}

// HashTransitionOptimized is a free data retrieval call binding the contract method 0x71354cb5.
//
// Solidity: function hashTransitionOptimized((bytes32,bytes32,(uint48,bytes32,bytes32)) _transition) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientCallerSession) HashTransitionOptimized(_transition IInboxTransition) ([32]byte, error) {
	return _InboxHelperClient.Contract.HashTransitionOptimized(&_InboxHelperClient.CallOpts, _transition)
}

// HashTransitionRecord is a free data retrieval call binding the contract method 0xeedec102.
//
// Solidity: function hashTransitionRecord((uint8,(uint48,uint8,address,address)[],bytes32,bytes32) _transitionRecord) pure returns(bytes26)
func (_InboxHelperClient *InboxHelperClientCaller) HashTransitionRecord(opts *bind.CallOpts, _transitionRecord IInboxTransitionRecord) ([26]byte, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "hashTransitionRecord", _transitionRecord)

	if err != nil {
		return *new([26]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([26]byte)).(*[26]byte)

	return out0, err

}

// HashTransitionRecord is a free data retrieval call binding the contract method 0xeedec102.
//
// Solidity: function hashTransitionRecord((uint8,(uint48,uint8,address,address)[],bytes32,bytes32) _transitionRecord) pure returns(bytes26)
func (_InboxHelperClient *InboxHelperClientSession) HashTransitionRecord(_transitionRecord IInboxTransitionRecord) ([26]byte, error) {
	return _InboxHelperClient.Contract.HashTransitionRecord(&_InboxHelperClient.CallOpts, _transitionRecord)
}

// HashTransitionRecord is a free data retrieval call binding the contract method 0xeedec102.
//
// Solidity: function hashTransitionRecord((uint8,(uint48,uint8,address,address)[],bytes32,bytes32) _transitionRecord) pure returns(bytes26)
func (_InboxHelperClient *InboxHelperClientCallerSession) HashTransitionRecord(_transitionRecord IInboxTransitionRecord) ([26]byte, error) {
	return _InboxHelperClient.Contract.HashTransitionRecord(&_InboxHelperClient.CallOpts, _transitionRecord)
}

// HashTransitionRecordOptimized is a free data retrieval call binding the contract method 0x7a230268.
//
// Solidity: function hashTransitionRecordOptimized((uint8,(uint48,uint8,address,address)[],bytes32,bytes32) _transitionRecord) pure returns(bytes26)
func (_InboxHelperClient *InboxHelperClientCaller) HashTransitionRecordOptimized(opts *bind.CallOpts, _transitionRecord IInboxTransitionRecord) ([26]byte, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "hashTransitionRecordOptimized", _transitionRecord)

	if err != nil {
		return *new([26]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([26]byte)).(*[26]byte)

	return out0, err

}

// HashTransitionRecordOptimized is a free data retrieval call binding the contract method 0x7a230268.
//
// Solidity: function hashTransitionRecordOptimized((uint8,(uint48,uint8,address,address)[],bytes32,bytes32) _transitionRecord) pure returns(bytes26)
func (_InboxHelperClient *InboxHelperClientSession) HashTransitionRecordOptimized(_transitionRecord IInboxTransitionRecord) ([26]byte, error) {
	return _InboxHelperClient.Contract.HashTransitionRecordOptimized(&_InboxHelperClient.CallOpts, _transitionRecord)
}

// HashTransitionRecordOptimized is a free data retrieval call binding the contract method 0x7a230268.
//
// Solidity: function hashTransitionRecordOptimized((uint8,(uint48,uint8,address,address)[],bytes32,bytes32) _transitionRecord) pure returns(bytes26)
func (_InboxHelperClient *InboxHelperClientCallerSession) HashTransitionRecordOptimized(_transitionRecord IInboxTransitionRecord) ([26]byte, error) {
	return _InboxHelperClient.Contract.HashTransitionRecordOptimized(&_InboxHelperClient.CallOpts, _transitionRecord)
}

// HashTransitionsArray is a free data retrieval call binding the contract method 0xad345a23.
//
// Solidity: function hashTransitionsArray((bytes32,bytes32,(uint48,bytes32,bytes32))[] _transitions) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientCaller) HashTransitionsArray(opts *bind.CallOpts, _transitions []IInboxTransition) ([32]byte, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "hashTransitionsArray", _transitions)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashTransitionsArray is a free data retrieval call binding the contract method 0xad345a23.
//
// Solidity: function hashTransitionsArray((bytes32,bytes32,(uint48,bytes32,bytes32))[] _transitions) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientSession) HashTransitionsArray(_transitions []IInboxTransition) ([32]byte, error) {
	return _InboxHelperClient.Contract.HashTransitionsArray(&_InboxHelperClient.CallOpts, _transitions)
}

// HashTransitionsArray is a free data retrieval call binding the contract method 0xad345a23.
//
// Solidity: function hashTransitionsArray((bytes32,bytes32,(uint48,bytes32,bytes32))[] _transitions) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientCallerSession) HashTransitionsArray(_transitions []IInboxTransition) ([32]byte, error) {
	return _InboxHelperClient.Contract.HashTransitionsArray(&_InboxHelperClient.CallOpts, _transitions)
}

// HashTransitionsArrayOptimized is a free data retrieval call binding the contract method 0xa06dbcfa.
//
// Solidity: function hashTransitionsArrayOptimized((bytes32,bytes32,(uint48,bytes32,bytes32))[] _transitions) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientCaller) HashTransitionsArrayOptimized(opts *bind.CallOpts, _transitions []IInboxTransition) ([32]byte, error) {
	var out []interface{}
	err := _InboxHelperClient.contract.Call(opts, &out, "hashTransitionsArrayOptimized", _transitions)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashTransitionsArrayOptimized is a free data retrieval call binding the contract method 0xa06dbcfa.
//
// Solidity: function hashTransitionsArrayOptimized((bytes32,bytes32,(uint48,bytes32,bytes32))[] _transitions) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientSession) HashTransitionsArrayOptimized(_transitions []IInboxTransition) ([32]byte, error) {
	return _InboxHelperClient.Contract.HashTransitionsArrayOptimized(&_InboxHelperClient.CallOpts, _transitions)
}

// HashTransitionsArrayOptimized is a free data retrieval call binding the contract method 0xa06dbcfa.
//
// Solidity: function hashTransitionsArrayOptimized((bytes32,bytes32,(uint48,bytes32,bytes32))[] _transitions) pure returns(bytes32)
func (_InboxHelperClient *InboxHelperClientCallerSession) HashTransitionsArrayOptimized(_transitions []IInboxTransition) ([32]byte, error) {
	return _InboxHelperClient.Contract.HashTransitionsArrayOptimized(&_InboxHelperClient.CallOpts, _transitions)
}
