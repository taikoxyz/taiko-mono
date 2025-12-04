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

// ICheckpointStoreCheckpoint is an auto generated low-level Go binding around an user-defined struct.
type ICheckpointStoreCheckpoint struct {
	BlockNumber *big.Int
	BlockHash   [32]byte
	StateRoot   [32]byte
}

// IInboxDerivation is an auto generated low-level Go binding around an user-defined struct.
type IInboxDerivation struct {
	OriginBlockNumber  *big.Int
	OriginBlockHash    [32]byte
	BasefeeSharingPctg uint8
	Sources            []IInboxDerivationSource
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
	DerivationHash                 [32]byte
}

// IInboxProposeInput is an auto generated low-level Go binding around an user-defined struct.
type IInboxProposeInput struct {
	Deadline            *big.Int
	BlobReference       LibBlobsBlobReference
	NumForcedInclusions uint8
}

// IInboxProposedEventPayload is an auto generated low-level Go binding around an user-defined struct.
type IInboxProposedEventPayload struct {
	Proposal   IInboxProposal
	Derivation IInboxDerivation
}

// IInboxProveInput is an auto generated low-level Go binding around an user-defined struct.
type IInboxProveInput struct {
	Proposals   []IInboxProposal
	Transitions []IInboxTransition
	Checkpoint  ICheckpointStoreCheckpoint
}

// IInboxProvedEventPayload is an auto generated low-level Go binding around an user-defined struct.
type IInboxProvedEventPayload struct {
	ProposalId      *big.Int
	Transition      IInboxTransition
	BondInstruction LibBondsBondInstruction
	BondSignal      [32]byte
}

// IInboxTransition is an auto generated low-level Go binding around an user-defined struct.
type IInboxTransition struct {
	ProposalHash         [32]byte
	ParentTransitionHash [32]byte
	Checkpoint           ICheckpointStoreCheckpoint
	DesignatedProver     common.Address
	ActualProver         common.Address
}

// LibBondsBondInstruction is an auto generated low-level Go binding around an user-defined struct.
type LibBondsBondInstruction struct {
	ProposalId *big.Int
	BondType   uint8
	Payer      common.Address
	Payee      common.Address
}

// CodecOptimizedClientMetaData contains all meta data concerning the CodecOptimizedClient contract.
var CodecOptimizedClientMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"decodeProposeInput\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"input_\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProposeInput\",\"components\":[{\"name\":\"deadline\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blobReference\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobReference\",\"components\":[{\"name\":\"blobStartIndex\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"numBlobs\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"}]},{\"name\":\"numForcedInclusions\",\"type\":\"uint8\",\"internalType\":\"uint8\"}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"decodeProposedEvent\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"payload_\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProposedEventPayload\",\"components\":[{\"name\":\"proposal\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Proposal\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"derivation\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Derivation\",\"components\":[{\"name\":\"originBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"originBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sources\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.DerivationSource[]\",\"components\":[{\"name\":\"isForcedInclusion\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]}]}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"decodeProveInput\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"input_\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProveInput\",\"components\":[{\"name\":\"proposals\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Proposal[]\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"transitions\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Transition[]\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"decodeProvedEvent\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"payload_\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProvedEventPayload\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"transition\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Transition\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"bondInstruction\",\"type\":\"tuple\",\"internalType\":\"structLibBonds.BondInstruction\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"bondType\",\"type\":\"uint8\",\"internalType\":\"enumLibBonds.BondType\"},{\"name\":\"payer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"payee\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"bondSignal\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"encodeProposeInput\",\"inputs\":[{\"name\":\"_input\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProposeInput\",\"components\":[{\"name\":\"deadline\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blobReference\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobReference\",\"components\":[{\"name\":\"blobStartIndex\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"numBlobs\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"}]},{\"name\":\"numForcedInclusions\",\"type\":\"uint8\",\"internalType\":\"uint8\"}]}],\"outputs\":[{\"name\":\"encoded_\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"encodeProposedEvent\",\"inputs\":[{\"name\":\"_payload\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProposedEventPayload\",\"components\":[{\"name\":\"proposal\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Proposal\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"derivation\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Derivation\",\"components\":[{\"name\":\"originBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"originBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sources\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.DerivationSource[]\",\"components\":[{\"name\":\"isForcedInclusion\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]}]}]}],\"outputs\":[{\"name\":\"encoded_\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"encodeProveInput\",\"inputs\":[{\"name\":\"_input\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProveInput\",\"components\":[{\"name\":\"proposals\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Proposal[]\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"transitions\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Transition[]\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]}],\"outputs\":[{\"name\":\"encoded_\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"encodeProvedEvent\",\"inputs\":[{\"name\":\"_payload\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProvedEventPayload\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"transition\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Transition\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"bondInstruction\",\"type\":\"tuple\",\"internalType\":\"structLibBonds.BondInstruction\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"bondType\",\"type\":\"uint8\",\"internalType\":\"enumLibBonds.BondType\"},{\"name\":\"payer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"payee\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"bondSignal\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"outputs\":[{\"name\":\"encoded_\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashCheckpoint\",\"inputs\":[{\"name\":\"_checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashCoreState\",\"inputs\":[{\"name\":\"_coreState\",\"type\":\"tuple\",\"internalType\":\"structIInbox.CoreState\",\"components\":[{\"name\":\"nextProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastProposalBlockId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastCheckpointTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"lastFinalizedTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashDerivation\",\"inputs\":[{\"name\":\"_derivation\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Derivation\",\"components\":[{\"name\":\"originBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"originBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sources\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.DerivationSource[]\",\"components\":[{\"name\":\"isForcedInclusion\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashProposal\",\"inputs\":[{\"name\":\"_proposal\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Proposal\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"derivationHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashTransition\",\"inputs\":[{\"name\":\"_transition\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Transition\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashTransitions\",\"inputs\":[{\"name\":\"_transitions\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Transition[]\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentTransitionHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"error\",\"name\":\"InvalidBondType\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"LengthExceedsUint16\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ProposalTransitionLengthMismatch\",\"inputs\":[]}]",
}

// CodecOptimizedClientABI is the input ABI used to generate the binding from.
// Deprecated: Use CodecOptimizedClientMetaData.ABI instead.
var CodecOptimizedClientABI = CodecOptimizedClientMetaData.ABI

// CodecOptimizedClient is an auto generated Go binding around an Ethereum contract.
type CodecOptimizedClient struct {
	CodecOptimizedClientCaller     // Read-only binding to the contract
	CodecOptimizedClientTransactor // Write-only binding to the contract
	CodecOptimizedClientFilterer   // Log filterer for contract events
}

// CodecOptimizedClientCaller is an auto generated read-only Go binding around an Ethereum contract.
type CodecOptimizedClientCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// CodecOptimizedClientTransactor is an auto generated write-only Go binding around an Ethereum contract.
type CodecOptimizedClientTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// CodecOptimizedClientFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type CodecOptimizedClientFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// CodecOptimizedClientSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type CodecOptimizedClientSession struct {
	Contract     *CodecOptimizedClient // Generic contract binding to set the session for
	CallOpts     bind.CallOpts         // Call options to use throughout this session
	TransactOpts bind.TransactOpts     // Transaction auth options to use throughout this session
}

// CodecOptimizedClientCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type CodecOptimizedClientCallerSession struct {
	Contract *CodecOptimizedClientCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts               // Call options to use throughout this session
}

// CodecOptimizedClientTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type CodecOptimizedClientTransactorSession struct {
	Contract     *CodecOptimizedClientTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts               // Transaction auth options to use throughout this session
}

// CodecOptimizedClientRaw is an auto generated low-level Go binding around an Ethereum contract.
type CodecOptimizedClientRaw struct {
	Contract *CodecOptimizedClient // Generic contract binding to access the raw methods on
}

// CodecOptimizedClientCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type CodecOptimizedClientCallerRaw struct {
	Contract *CodecOptimizedClientCaller // Generic read-only contract binding to access the raw methods on
}

// CodecOptimizedClientTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type CodecOptimizedClientTransactorRaw struct {
	Contract *CodecOptimizedClientTransactor // Generic write-only contract binding to access the raw methods on
}

// NewCodecOptimizedClient creates a new instance of CodecOptimizedClient, bound to a specific deployed contract.
func NewCodecOptimizedClient(address common.Address, backend bind.ContractBackend) (*CodecOptimizedClient, error) {
	contract, err := bindCodecOptimizedClient(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &CodecOptimizedClient{CodecOptimizedClientCaller: CodecOptimizedClientCaller{contract: contract}, CodecOptimizedClientTransactor: CodecOptimizedClientTransactor{contract: contract}, CodecOptimizedClientFilterer: CodecOptimizedClientFilterer{contract: contract}}, nil
}

// NewCodecOptimizedClientCaller creates a new read-only instance of CodecOptimizedClient, bound to a specific deployed contract.
func NewCodecOptimizedClientCaller(address common.Address, caller bind.ContractCaller) (*CodecOptimizedClientCaller, error) {
	contract, err := bindCodecOptimizedClient(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &CodecOptimizedClientCaller{contract: contract}, nil
}

// NewCodecOptimizedClientTransactor creates a new write-only instance of CodecOptimizedClient, bound to a specific deployed contract.
func NewCodecOptimizedClientTransactor(address common.Address, transactor bind.ContractTransactor) (*CodecOptimizedClientTransactor, error) {
	contract, err := bindCodecOptimizedClient(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &CodecOptimizedClientTransactor{contract: contract}, nil
}

// NewCodecOptimizedClientFilterer creates a new log filterer instance of CodecOptimizedClient, bound to a specific deployed contract.
func NewCodecOptimizedClientFilterer(address common.Address, filterer bind.ContractFilterer) (*CodecOptimizedClientFilterer, error) {
	contract, err := bindCodecOptimizedClient(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &CodecOptimizedClientFilterer{contract: contract}, nil
}

// bindCodecOptimizedClient binds a generic wrapper to an already deployed contract.
func bindCodecOptimizedClient(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := CodecOptimizedClientMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_CodecOptimizedClient *CodecOptimizedClientRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _CodecOptimizedClient.Contract.CodecOptimizedClientCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_CodecOptimizedClient *CodecOptimizedClientRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _CodecOptimizedClient.Contract.CodecOptimizedClientTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_CodecOptimizedClient *CodecOptimizedClientRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _CodecOptimizedClient.Contract.CodecOptimizedClientTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_CodecOptimizedClient *CodecOptimizedClientCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _CodecOptimizedClient.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_CodecOptimizedClient *CodecOptimizedClientTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _CodecOptimizedClient.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_CodecOptimizedClient *CodecOptimizedClientTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _CodecOptimizedClient.Contract.contract.Transact(opts, method, params...)
}

// DecodeProposeInput is a free data retrieval call binding the contract method 0xafb63ad4.
//
// Solidity: function decodeProposeInput(bytes _data) pure returns((uint48,(uint16,uint16,uint24),uint8) input_)
func (_CodecOptimizedClient *CodecOptimizedClientCaller) DecodeProposeInput(opts *bind.CallOpts, _data []byte) (IInboxProposeInput, error) {
	var out []interface{}
	err := _CodecOptimizedClient.contract.Call(opts, &out, "decodeProposeInput", _data)

	if err != nil {
		return *new(IInboxProposeInput), err
	}

	out0 := *abi.ConvertType(out[0], new(IInboxProposeInput)).(*IInboxProposeInput)

	return out0, err

}

// DecodeProposeInput is a free data retrieval call binding the contract method 0xafb63ad4.
//
// Solidity: function decodeProposeInput(bytes _data) pure returns((uint48,(uint16,uint16,uint24),uint8) input_)
func (_CodecOptimizedClient *CodecOptimizedClientSession) DecodeProposeInput(_data []byte) (IInboxProposeInput, error) {
	return _CodecOptimizedClient.Contract.DecodeProposeInput(&_CodecOptimizedClient.CallOpts, _data)
}

// DecodeProposeInput is a free data retrieval call binding the contract method 0xafb63ad4.
//
// Solidity: function decodeProposeInput(bytes _data) pure returns((uint48,(uint16,uint16,uint24),uint8) input_)
func (_CodecOptimizedClient *CodecOptimizedClientCallerSession) DecodeProposeInput(_data []byte) (IInboxProposeInput, error) {
	return _CodecOptimizedClient.Contract.DecodeProposeInput(&_CodecOptimizedClient.CallOpts, _data)
}

// DecodeProposedEvent is a free data retrieval call binding the contract method 0x5d27cc95.
//
// Solidity: function decodeProposedEvent(bytes _data) pure returns(((uint48,uint48,uint48,address,bytes32),(uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[])) payload_)
func (_CodecOptimizedClient *CodecOptimizedClientCaller) DecodeProposedEvent(opts *bind.CallOpts, _data []byte) (IInboxProposedEventPayload, error) {
	var out []interface{}
	err := _CodecOptimizedClient.contract.Call(opts, &out, "decodeProposedEvent", _data)

	if err != nil {
		return *new(IInboxProposedEventPayload), err
	}

	out0 := *abi.ConvertType(out[0], new(IInboxProposedEventPayload)).(*IInboxProposedEventPayload)

	return out0, err

}

// DecodeProposedEvent is a free data retrieval call binding the contract method 0x5d27cc95.
//
// Solidity: function decodeProposedEvent(bytes _data) pure returns(((uint48,uint48,uint48,address,bytes32),(uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[])) payload_)
func (_CodecOptimizedClient *CodecOptimizedClientSession) DecodeProposedEvent(_data []byte) (IInboxProposedEventPayload, error) {
	return _CodecOptimizedClient.Contract.DecodeProposedEvent(&_CodecOptimizedClient.CallOpts, _data)
}

// DecodeProposedEvent is a free data retrieval call binding the contract method 0x5d27cc95.
//
// Solidity: function decodeProposedEvent(bytes _data) pure returns(((uint48,uint48,uint48,address,bytes32),(uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[])) payload_)
func (_CodecOptimizedClient *CodecOptimizedClientCallerSession) DecodeProposedEvent(_data []byte) (IInboxProposedEventPayload, error) {
	return _CodecOptimizedClient.Contract.DecodeProposedEvent(&_CodecOptimizedClient.CallOpts, _data)
}

// DecodeProveInput is a free data retrieval call binding the contract method 0xedbacd44.
//
// Solidity: function decodeProveInput(bytes _data) pure returns(((uint48,uint48,uint48,address,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32),address,address)[],(uint48,bytes32,bytes32)) input_)
func (_CodecOptimizedClient *CodecOptimizedClientCaller) DecodeProveInput(opts *bind.CallOpts, _data []byte) (IInboxProveInput, error) {
	var out []interface{}
	err := _CodecOptimizedClient.contract.Call(opts, &out, "decodeProveInput", _data)

	if err != nil {
		return *new(IInboxProveInput), err
	}

	out0 := *abi.ConvertType(out[0], new(IInboxProveInput)).(*IInboxProveInput)

	return out0, err

}

// DecodeProveInput is a free data retrieval call binding the contract method 0xedbacd44.
//
// Solidity: function decodeProveInput(bytes _data) pure returns(((uint48,uint48,uint48,address,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32),address,address)[],(uint48,bytes32,bytes32)) input_)
func (_CodecOptimizedClient *CodecOptimizedClientSession) DecodeProveInput(_data []byte) (IInboxProveInput, error) {
	return _CodecOptimizedClient.Contract.DecodeProveInput(&_CodecOptimizedClient.CallOpts, _data)
}

// DecodeProveInput is a free data retrieval call binding the contract method 0xedbacd44.
//
// Solidity: function decodeProveInput(bytes _data) pure returns(((uint48,uint48,uint48,address,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32),address,address)[],(uint48,bytes32,bytes32)) input_)
func (_CodecOptimizedClient *CodecOptimizedClientCallerSession) DecodeProveInput(_data []byte) (IInboxProveInput, error) {
	return _CodecOptimizedClient.Contract.DecodeProveInput(&_CodecOptimizedClient.CallOpts, _data)
}

// DecodeProvedEvent is a free data retrieval call binding the contract method 0x26303962.
//
// Solidity: function decodeProvedEvent(bytes _data) pure returns((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32),address,address),(uint48,uint8,address,address),bytes32) payload_)
func (_CodecOptimizedClient *CodecOptimizedClientCaller) DecodeProvedEvent(opts *bind.CallOpts, _data []byte) (IInboxProvedEventPayload, error) {
	var out []interface{}
	err := _CodecOptimizedClient.contract.Call(opts, &out, "decodeProvedEvent", _data)

	if err != nil {
		return *new(IInboxProvedEventPayload), err
	}

	out0 := *abi.ConvertType(out[0], new(IInboxProvedEventPayload)).(*IInboxProvedEventPayload)

	return out0, err

}

// DecodeProvedEvent is a free data retrieval call binding the contract method 0x26303962.
//
// Solidity: function decodeProvedEvent(bytes _data) pure returns((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32),address,address),(uint48,uint8,address,address),bytes32) payload_)
func (_CodecOptimizedClient *CodecOptimizedClientSession) DecodeProvedEvent(_data []byte) (IInboxProvedEventPayload, error) {
	return _CodecOptimizedClient.Contract.DecodeProvedEvent(&_CodecOptimizedClient.CallOpts, _data)
}

// DecodeProvedEvent is a free data retrieval call binding the contract method 0x26303962.
//
// Solidity: function decodeProvedEvent(bytes _data) pure returns((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32),address,address),(uint48,uint8,address,address),bytes32) payload_)
func (_CodecOptimizedClient *CodecOptimizedClientCallerSession) DecodeProvedEvent(_data []byte) (IInboxProvedEventPayload, error) {
	return _CodecOptimizedClient.Contract.DecodeProvedEvent(&_CodecOptimizedClient.CallOpts, _data)
}

// EncodeProposeInput is a free data retrieval call binding the contract method 0x2f1969b0.
//
// Solidity: function encodeProposeInput((uint48,(uint16,uint16,uint24),uint8) _input) pure returns(bytes encoded_)
func (_CodecOptimizedClient *CodecOptimizedClientCaller) EncodeProposeInput(opts *bind.CallOpts, _input IInboxProposeInput) ([]byte, error) {
	var out []interface{}
	err := _CodecOptimizedClient.contract.Call(opts, &out, "encodeProposeInput", _input)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProposeInput is a free data retrieval call binding the contract method 0x2f1969b0.
//
// Solidity: function encodeProposeInput((uint48,(uint16,uint16,uint24),uint8) _input) pure returns(bytes encoded_)
func (_CodecOptimizedClient *CodecOptimizedClientSession) EncodeProposeInput(_input IInboxProposeInput) ([]byte, error) {
	return _CodecOptimizedClient.Contract.EncodeProposeInput(&_CodecOptimizedClient.CallOpts, _input)
}

// EncodeProposeInput is a free data retrieval call binding the contract method 0x2f1969b0.
//
// Solidity: function encodeProposeInput((uint48,(uint16,uint16,uint24),uint8) _input) pure returns(bytes encoded_)
func (_CodecOptimizedClient *CodecOptimizedClientCallerSession) EncodeProposeInput(_input IInboxProposeInput) ([]byte, error) {
	return _CodecOptimizedClient.Contract.EncodeProposeInput(&_CodecOptimizedClient.CallOpts, _input)
}

// EncodeProposedEvent is a free data retrieval call binding the contract method 0x65763483.
//
// Solidity: function encodeProposedEvent(((uint48,uint48,uint48,address,bytes32),(uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[])) _payload) pure returns(bytes encoded_)
func (_CodecOptimizedClient *CodecOptimizedClientCaller) EncodeProposedEvent(opts *bind.CallOpts, _payload IInboxProposedEventPayload) ([]byte, error) {
	var out []interface{}
	err := _CodecOptimizedClient.contract.Call(opts, &out, "encodeProposedEvent", _payload)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProposedEvent is a free data retrieval call binding the contract method 0x65763483.
//
// Solidity: function encodeProposedEvent(((uint48,uint48,uint48,address,bytes32),(uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[])) _payload) pure returns(bytes encoded_)
func (_CodecOptimizedClient *CodecOptimizedClientSession) EncodeProposedEvent(_payload IInboxProposedEventPayload) ([]byte, error) {
	return _CodecOptimizedClient.Contract.EncodeProposedEvent(&_CodecOptimizedClient.CallOpts, _payload)
}

// EncodeProposedEvent is a free data retrieval call binding the contract method 0x65763483.
//
// Solidity: function encodeProposedEvent(((uint48,uint48,uint48,address,bytes32),(uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[])) _payload) pure returns(bytes encoded_)
func (_CodecOptimizedClient *CodecOptimizedClientCallerSession) EncodeProposedEvent(_payload IInboxProposedEventPayload) ([]byte, error) {
	return _CodecOptimizedClient.Contract.EncodeProposedEvent(&_CodecOptimizedClient.CallOpts, _payload)
}

// EncodeProveInput is a free data retrieval call binding the contract method 0x59b70442.
//
// Solidity: function encodeProveInput(((uint48,uint48,uint48,address,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32),address,address)[],(uint48,bytes32,bytes32)) _input) pure returns(bytes encoded_)
func (_CodecOptimizedClient *CodecOptimizedClientCaller) EncodeProveInput(opts *bind.CallOpts, _input IInboxProveInput) ([]byte, error) {
	var out []interface{}
	err := _CodecOptimizedClient.contract.Call(opts, &out, "encodeProveInput", _input)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProveInput is a free data retrieval call binding the contract method 0x59b70442.
//
// Solidity: function encodeProveInput(((uint48,uint48,uint48,address,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32),address,address)[],(uint48,bytes32,bytes32)) _input) pure returns(bytes encoded_)
func (_CodecOptimizedClient *CodecOptimizedClientSession) EncodeProveInput(_input IInboxProveInput) ([]byte, error) {
	return _CodecOptimizedClient.Contract.EncodeProveInput(&_CodecOptimizedClient.CallOpts, _input)
}

// EncodeProveInput is a free data retrieval call binding the contract method 0x59b70442.
//
// Solidity: function encodeProveInput(((uint48,uint48,uint48,address,bytes32)[],(bytes32,bytes32,(uint48,bytes32,bytes32),address,address)[],(uint48,bytes32,bytes32)) _input) pure returns(bytes encoded_)
func (_CodecOptimizedClient *CodecOptimizedClientCallerSession) EncodeProveInput(_input IInboxProveInput) ([]byte, error) {
	return _CodecOptimizedClient.Contract.EncodeProveInput(&_CodecOptimizedClient.CallOpts, _input)
}

// EncodeProvedEvent is a free data retrieval call binding the contract method 0xa3f5bb4b.
//
// Solidity: function encodeProvedEvent((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32),address,address),(uint48,uint8,address,address),bytes32) _payload) pure returns(bytes encoded_)
func (_CodecOptimizedClient *CodecOptimizedClientCaller) EncodeProvedEvent(opts *bind.CallOpts, _payload IInboxProvedEventPayload) ([]byte, error) {
	var out []interface{}
	err := _CodecOptimizedClient.contract.Call(opts, &out, "encodeProvedEvent", _payload)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProvedEvent is a free data retrieval call binding the contract method 0xa3f5bb4b.
//
// Solidity: function encodeProvedEvent((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32),address,address),(uint48,uint8,address,address),bytes32) _payload) pure returns(bytes encoded_)
func (_CodecOptimizedClient *CodecOptimizedClientSession) EncodeProvedEvent(_payload IInboxProvedEventPayload) ([]byte, error) {
	return _CodecOptimizedClient.Contract.EncodeProvedEvent(&_CodecOptimizedClient.CallOpts, _payload)
}

// EncodeProvedEvent is a free data retrieval call binding the contract method 0xa3f5bb4b.
//
// Solidity: function encodeProvedEvent((uint48,(bytes32,bytes32,(uint48,bytes32,bytes32),address,address),(uint48,uint8,address,address),bytes32) _payload) pure returns(bytes encoded_)
func (_CodecOptimizedClient *CodecOptimizedClientCallerSession) EncodeProvedEvent(_payload IInboxProvedEventPayload) ([]byte, error) {
	return _CodecOptimizedClient.Contract.EncodeProvedEvent(&_CodecOptimizedClient.CallOpts, _payload)
}

// HashCheckpoint is a free data retrieval call binding the contract method 0x7989aa10.
//
// Solidity: function hashCheckpoint((uint48,bytes32,bytes32) _checkpoint) pure returns(bytes32)
func (_CodecOptimizedClient *CodecOptimizedClientCaller) HashCheckpoint(opts *bind.CallOpts, _checkpoint ICheckpointStoreCheckpoint) ([32]byte, error) {
	var out []interface{}
	err := _CodecOptimizedClient.contract.Call(opts, &out, "hashCheckpoint", _checkpoint)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashCheckpoint is a free data retrieval call binding the contract method 0x7989aa10.
//
// Solidity: function hashCheckpoint((uint48,bytes32,bytes32) _checkpoint) pure returns(bytes32)
func (_CodecOptimizedClient *CodecOptimizedClientSession) HashCheckpoint(_checkpoint ICheckpointStoreCheckpoint) ([32]byte, error) {
	return _CodecOptimizedClient.Contract.HashCheckpoint(&_CodecOptimizedClient.CallOpts, _checkpoint)
}

// HashCheckpoint is a free data retrieval call binding the contract method 0x7989aa10.
//
// Solidity: function hashCheckpoint((uint48,bytes32,bytes32) _checkpoint) pure returns(bytes32)
func (_CodecOptimizedClient *CodecOptimizedClientCallerSession) HashCheckpoint(_checkpoint ICheckpointStoreCheckpoint) ([32]byte, error) {
	return _CodecOptimizedClient.Contract.HashCheckpoint(&_CodecOptimizedClient.CallOpts, _checkpoint)
}

// HashCoreState is a free data retrieval call binding the contract method 0x217b8da0.
//
// Solidity: function hashCoreState((uint48,uint48,uint48,uint48,uint48,bytes32) _coreState) pure returns(bytes32)
func (_CodecOptimizedClient *CodecOptimizedClientCaller) HashCoreState(opts *bind.CallOpts, _coreState IInboxCoreState) ([32]byte, error) {
	var out []interface{}
	err := _CodecOptimizedClient.contract.Call(opts, &out, "hashCoreState", _coreState)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashCoreState is a free data retrieval call binding the contract method 0x217b8da0.
//
// Solidity: function hashCoreState((uint48,uint48,uint48,uint48,uint48,bytes32) _coreState) pure returns(bytes32)
func (_CodecOptimizedClient *CodecOptimizedClientSession) HashCoreState(_coreState IInboxCoreState) ([32]byte, error) {
	return _CodecOptimizedClient.Contract.HashCoreState(&_CodecOptimizedClient.CallOpts, _coreState)
}

// HashCoreState is a free data retrieval call binding the contract method 0x217b8da0.
//
// Solidity: function hashCoreState((uint48,uint48,uint48,uint48,uint48,bytes32) _coreState) pure returns(bytes32)
func (_CodecOptimizedClient *CodecOptimizedClientCallerSession) HashCoreState(_coreState IInboxCoreState) ([32]byte, error) {
	return _CodecOptimizedClient.Contract.HashCoreState(&_CodecOptimizedClient.CallOpts, _coreState)
}

// HashDerivation is a free data retrieval call binding the contract method 0xb8b02e0e.
//
// Solidity: function hashDerivation((uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]) _derivation) pure returns(bytes32)
func (_CodecOptimizedClient *CodecOptimizedClientCaller) HashDerivation(opts *bind.CallOpts, _derivation IInboxDerivation) ([32]byte, error) {
	var out []interface{}
	err := _CodecOptimizedClient.contract.Call(opts, &out, "hashDerivation", _derivation)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashDerivation is a free data retrieval call binding the contract method 0xb8b02e0e.
//
// Solidity: function hashDerivation((uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]) _derivation) pure returns(bytes32)
func (_CodecOptimizedClient *CodecOptimizedClientSession) HashDerivation(_derivation IInboxDerivation) ([32]byte, error) {
	return _CodecOptimizedClient.Contract.HashDerivation(&_CodecOptimizedClient.CallOpts, _derivation)
}

// HashDerivation is a free data retrieval call binding the contract method 0xb8b02e0e.
//
// Solidity: function hashDerivation((uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]) _derivation) pure returns(bytes32)
func (_CodecOptimizedClient *CodecOptimizedClientCallerSession) HashDerivation(_derivation IInboxDerivation) ([32]byte, error) {
	return _CodecOptimizedClient.Contract.HashDerivation(&_CodecOptimizedClient.CallOpts, _derivation)
}

// HashProposal is a free data retrieval call binding the contract method 0x85b627a2.
//
// Solidity: function hashProposal((uint48,uint48,uint48,address,bytes32) _proposal) pure returns(bytes32)
func (_CodecOptimizedClient *CodecOptimizedClientCaller) HashProposal(opts *bind.CallOpts, _proposal IInboxProposal) ([32]byte, error) {
	var out []interface{}
	err := _CodecOptimizedClient.contract.Call(opts, &out, "hashProposal", _proposal)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashProposal is a free data retrieval call binding the contract method 0x85b627a2.
//
// Solidity: function hashProposal((uint48,uint48,uint48,address,bytes32) _proposal) pure returns(bytes32)
func (_CodecOptimizedClient *CodecOptimizedClientSession) HashProposal(_proposal IInboxProposal) ([32]byte, error) {
	return _CodecOptimizedClient.Contract.HashProposal(&_CodecOptimizedClient.CallOpts, _proposal)
}

// HashProposal is a free data retrieval call binding the contract method 0x85b627a2.
//
// Solidity: function hashProposal((uint48,uint48,uint48,address,bytes32) _proposal) pure returns(bytes32)
func (_CodecOptimizedClient *CodecOptimizedClientCallerSession) HashProposal(_proposal IInboxProposal) ([32]byte, error) {
	return _CodecOptimizedClient.Contract.HashProposal(&_CodecOptimizedClient.CallOpts, _proposal)
}

// HashTransition is a free data retrieval call binding the contract method 0x2833bf29.
//
// Solidity: function hashTransition((bytes32,bytes32,(uint48,bytes32,bytes32),address,address) _transition) pure returns(bytes32)
func (_CodecOptimizedClient *CodecOptimizedClientCaller) HashTransition(opts *bind.CallOpts, _transition IInboxTransition) ([32]byte, error) {
	var out []interface{}
	err := _CodecOptimizedClient.contract.Call(opts, &out, "hashTransition", _transition)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashTransition is a free data retrieval call binding the contract method 0x2833bf29.
//
// Solidity: function hashTransition((bytes32,bytes32,(uint48,bytes32,bytes32),address,address) _transition) pure returns(bytes32)
func (_CodecOptimizedClient *CodecOptimizedClientSession) HashTransition(_transition IInboxTransition) ([32]byte, error) {
	return _CodecOptimizedClient.Contract.HashTransition(&_CodecOptimizedClient.CallOpts, _transition)
}

// HashTransition is a free data retrieval call binding the contract method 0x2833bf29.
//
// Solidity: function hashTransition((bytes32,bytes32,(uint48,bytes32,bytes32),address,address) _transition) pure returns(bytes32)
func (_CodecOptimizedClient *CodecOptimizedClientCallerSession) HashTransition(_transition IInboxTransition) ([32]byte, error) {
	return _CodecOptimizedClient.Contract.HashTransition(&_CodecOptimizedClient.CallOpts, _transition)
}

// HashTransitions is a free data retrieval call binding the contract method 0x012b5fd7.
//
// Solidity: function hashTransitions((bytes32,bytes32,(uint48,bytes32,bytes32),address,address)[] _transitions) pure returns(bytes32)
func (_CodecOptimizedClient *CodecOptimizedClientCaller) HashTransitions(opts *bind.CallOpts, _transitions []IInboxTransition) ([32]byte, error) {
	var out []interface{}
	err := _CodecOptimizedClient.contract.Call(opts, &out, "hashTransitions", _transitions)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashTransitions is a free data retrieval call binding the contract method 0x012b5fd7.
//
// Solidity: function hashTransitions((bytes32,bytes32,(uint48,bytes32,bytes32),address,address)[] _transitions) pure returns(bytes32)
func (_CodecOptimizedClient *CodecOptimizedClientSession) HashTransitions(_transitions []IInboxTransition) ([32]byte, error) {
	return _CodecOptimizedClient.Contract.HashTransitions(&_CodecOptimizedClient.CallOpts, _transitions)
}

// HashTransitions is a free data retrieval call binding the contract method 0x012b5fd7.
//
// Solidity: function hashTransitions((bytes32,bytes32,(uint48,bytes32,bytes32),address,address)[] _transitions) pure returns(bytes32)
func (_CodecOptimizedClient *CodecOptimizedClientCallerSession) HashTransitions(_transitions []IInboxTransition) ([32]byte, error) {
	return _CodecOptimizedClient.Contract.HashTransitions(&_CodecOptimizedClient.CallOpts, _transitions)
}
