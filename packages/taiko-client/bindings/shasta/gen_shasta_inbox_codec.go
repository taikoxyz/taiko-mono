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

// CodecClientMetaData contains all meta data concerning the CodecClient contract.
var CodecClientMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"decodeProposeInput\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"input_\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProposeInput\",\"components\":[{\"name\":\"deadline\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blobReference\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobReference\",\"components\":[{\"name\":\"blobStartIndex\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"numBlobs\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"}]},{\"name\":\"numForcedInclusions\",\"type\":\"uint8\",\"internalType\":\"uint8\"}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"decodeProveInput\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"input_\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProveInput\",\"components\":[{\"name\":\"commitment\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Commitment\",\"components\":[{\"name\":\"firstProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"firstProposalParentBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"lastProposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"endBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endStateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"transitions\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Transition[]\",\"components\":[{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]},{\"name\":\"forceCheckpointSync\",\"type\":\"bool\",\"internalType\":\"bool\"}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"encodeProposeInput\",\"inputs\":[{\"name\":\"_input\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProposeInput\",\"components\":[{\"name\":\"deadline\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blobReference\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobReference\",\"components\":[{\"name\":\"blobStartIndex\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"numBlobs\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"}]},{\"name\":\"numForcedInclusions\",\"type\":\"uint8\",\"internalType\":\"uint8\"}]}],\"outputs\":[{\"name\":\"encoded_\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"encodeProveInput\",\"inputs\":[{\"name\":\"_input\",\"type\":\"tuple\",\"internalType\":\"structIInbox.ProveInput\",\"components\":[{\"name\":\"commitment\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Commitment\",\"components\":[{\"name\":\"firstProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"firstProposalParentBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"lastProposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"endBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endStateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"transitions\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Transition[]\",\"components\":[{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]},{\"name\":\"forceCheckpointSync\",\"type\":\"bool\",\"internalType\":\"bool\"}]}],\"outputs\":[{\"name\":\"encoded_\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashBondInstruction\",\"inputs\":[{\"name\":\"_bondInstruction\",\"type\":\"tuple\",\"internalType\":\"structLibBonds.BondInstruction\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"bondType\",\"type\":\"uint8\",\"internalType\":\"enumLibBonds.BondType\"},{\"name\":\"payer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"payee\",\"type\":\"address\",\"internalType\":\"address\"}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashCommitment\",\"inputs\":[{\"name\":\"_commitment\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Commitment\",\"components\":[{\"name\":\"firstProposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"firstProposalParentBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"lastProposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"actualProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"endBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endStateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"transitions\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.Transition[]\",\"components\":[{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashProposal\",\"inputs\":[{\"name\":\"_proposal\",\"type\":\"tuple\",\"internalType\":\"structIInbox.Proposal\",\"components\":[{\"name\":\"id\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"endOfSubmissionWindowTimestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"parentProposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"originBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"originBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sources\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.DerivationSource[]\",\"components\":[{\"name\":\"isForcedInclusion\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"error\",\"name\":\"LengthExceedsUint16\",\"inputs\":[]}]",
}

// CodecClientABI is the input ABI used to generate the binding from.
// Deprecated: Use CodecClientMetaData.ABI instead.
var CodecClientABI = CodecClientMetaData.ABI

// CodecClient is an auto generated Go binding around an Ethereum contract.
type CodecClient struct {
	CodecClientCaller     // Read-only binding to the contract
	CodecClientTransactor // Write-only binding to the contract
	CodecClientFilterer   // Log filterer for contract events
}

// CodecClientCaller is an auto generated read-only Go binding around an Ethereum contract.
type CodecClientCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// CodecClientTransactor is an auto generated write-only Go binding around an Ethereum contract.
type CodecClientTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// CodecClientFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type CodecClientFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// CodecClientSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type CodecClientSession struct {
	Contract     *CodecClient      // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// CodecClientCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type CodecClientCallerSession struct {
	Contract *CodecClientCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts      // Call options to use throughout this session
}

// CodecClientTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type CodecClientTransactorSession struct {
	Contract     *CodecClientTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts      // Transaction auth options to use throughout this session
}

// CodecClientRaw is an auto generated low-level Go binding around an Ethereum contract.
type CodecClientRaw struct {
	Contract *CodecClient // Generic contract binding to access the raw methods on
}

// CodecClientCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type CodecClientCallerRaw struct {
	Contract *CodecClientCaller // Generic read-only contract binding to access the raw methods on
}

// CodecClientTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type CodecClientTransactorRaw struct {
	Contract *CodecClientTransactor // Generic write-only contract binding to access the raw methods on
}

// NewCodecClient creates a new instance of CodecClient, bound to a specific deployed contract.
func NewCodecClient(address common.Address, backend bind.ContractBackend) (*CodecClient, error) {
	contract, err := bindCodecClient(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &CodecClient{CodecClientCaller: CodecClientCaller{contract: contract}, CodecClientTransactor: CodecClientTransactor{contract: contract}, CodecClientFilterer: CodecClientFilterer{contract: contract}}, nil
}

// NewCodecClientCaller creates a new read-only instance of CodecClient, bound to a specific deployed contract.
func NewCodecClientCaller(address common.Address, caller bind.ContractCaller) (*CodecClientCaller, error) {
	contract, err := bindCodecClient(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &CodecClientCaller{contract: contract}, nil
}

// NewCodecClientTransactor creates a new write-only instance of CodecClient, bound to a specific deployed contract.
func NewCodecClientTransactor(address common.Address, transactor bind.ContractTransactor) (*CodecClientTransactor, error) {
	contract, err := bindCodecClient(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &CodecClientTransactor{contract: contract}, nil
}

// NewCodecClientFilterer creates a new log filterer instance of CodecClient, bound to a specific deployed contract.
func NewCodecClientFilterer(address common.Address, filterer bind.ContractFilterer) (*CodecClientFilterer, error) {
	contract, err := bindCodecClient(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &CodecClientFilterer{contract: contract}, nil
}

// bindCodecClient binds a generic wrapper to an already deployed contract.
func bindCodecClient(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := CodecClientMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_CodecClient *CodecClientRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _CodecClient.Contract.CodecClientCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_CodecClient *CodecClientRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _CodecClient.Contract.CodecClientTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_CodecClient *CodecClientRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _CodecClient.Contract.CodecClientTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_CodecClient *CodecClientCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _CodecClient.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_CodecClient *CodecClientTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _CodecClient.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_CodecClient *CodecClientTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _CodecClient.Contract.contract.Transact(opts, method, params...)
}

// DecodeProposeInput is a free data retrieval call binding the contract method 0xafb63ad4.
//
// Solidity: function decodeProposeInput(bytes _data) pure returns((uint48,(uint16,uint16,uint24),uint8) input_)
func (_CodecClient *CodecClientCaller) DecodeProposeInput(opts *bind.CallOpts, _data []byte) (IInboxProposeInput, error) {
	var out []interface{}
	err := _CodecClient.contract.Call(opts, &out, "decodeProposeInput", _data)

	if err != nil {
		return *new(IInboxProposeInput), err
	}

	out0 := *abi.ConvertType(out[0], new(IInboxProposeInput)).(*IInboxProposeInput)

	return out0, err

}

// DecodeProposeInput is a free data retrieval call binding the contract method 0xafb63ad4.
//
// Solidity: function decodeProposeInput(bytes _data) pure returns((uint48,(uint16,uint16,uint24),uint8) input_)
func (_CodecClient *CodecClientSession) DecodeProposeInput(_data []byte) (IInboxProposeInput, error) {
	return _CodecClient.Contract.DecodeProposeInput(&_CodecClient.CallOpts, _data)
}

// DecodeProposeInput is a free data retrieval call binding the contract method 0xafb63ad4.
//
// Solidity: function decodeProposeInput(bytes _data) pure returns((uint48,(uint16,uint16,uint24),uint8) input_)
func (_CodecClient *CodecClientCallerSession) DecodeProposeInput(_data []byte) (IInboxProposeInput, error) {
	return _CodecClient.Contract.DecodeProposeInput(&_CodecClient.CallOpts, _data)
}

// DecodeProveInput is a free data retrieval call binding the contract method 0xedbacd44.
//
// Solidity: function decodeProveInput(bytes _data) pure returns(((uint48,bytes32,bytes32,address,uint48,bytes32,(address,address,uint48,bytes32)[]),bool) input_)
func (_CodecClient *CodecClientCaller) DecodeProveInput(opts *bind.CallOpts, _data []byte) (IInboxProveInput, error) {
	var out []interface{}
	err := _CodecClient.contract.Call(opts, &out, "decodeProveInput", _data)

	if err != nil {
		return *new(IInboxProveInput), err
	}

	out0 := *abi.ConvertType(out[0], new(IInboxProveInput)).(*IInboxProveInput)

	return out0, err

}

// DecodeProveInput is a free data retrieval call binding the contract method 0xedbacd44.
//
// Solidity: function decodeProveInput(bytes _data) pure returns(((uint48,bytes32,bytes32,address,uint48,bytes32,(address,address,uint48,bytes32)[]),bool) input_)
func (_CodecClient *CodecClientSession) DecodeProveInput(_data []byte) (IInboxProveInput, error) {
	return _CodecClient.Contract.DecodeProveInput(&_CodecClient.CallOpts, _data)
}

// DecodeProveInput is a free data retrieval call binding the contract method 0xedbacd44.
//
// Solidity: function decodeProveInput(bytes _data) pure returns(((uint48,bytes32,bytes32,address,uint48,bytes32,(address,address,uint48,bytes32)[]),bool) input_)
func (_CodecClient *CodecClientCallerSession) DecodeProveInput(_data []byte) (IInboxProveInput, error) {
	return _CodecClient.Contract.DecodeProveInput(&_CodecClient.CallOpts, _data)
}

// EncodeProposeInput is a free data retrieval call binding the contract method 0x2f1969b0.
//
// Solidity: function encodeProposeInput((uint48,(uint16,uint16,uint24),uint8) _input) pure returns(bytes encoded_)
func (_CodecClient *CodecClientCaller) EncodeProposeInput(opts *bind.CallOpts, _input IInboxProposeInput) ([]byte, error) {
	var out []interface{}
	err := _CodecClient.contract.Call(opts, &out, "encodeProposeInput", _input)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProposeInput is a free data retrieval call binding the contract method 0x2f1969b0.
//
// Solidity: function encodeProposeInput((uint48,(uint16,uint16,uint24),uint8) _input) pure returns(bytes encoded_)
func (_CodecClient *CodecClientSession) EncodeProposeInput(_input IInboxProposeInput) ([]byte, error) {
	return _CodecClient.Contract.EncodeProposeInput(&_CodecClient.CallOpts, _input)
}

// EncodeProposeInput is a free data retrieval call binding the contract method 0x2f1969b0.
//
// Solidity: function encodeProposeInput((uint48,(uint16,uint16,uint24),uint8) _input) pure returns(bytes encoded_)
func (_CodecClient *CodecClientCallerSession) EncodeProposeInput(_input IInboxProposeInput) ([]byte, error) {
	return _CodecClient.Contract.EncodeProposeInput(&_CodecClient.CallOpts, _input)
}

// EncodeProveInput is a free data retrieval call binding the contract method 0xc3d3e2f4.
//
// Solidity: function encodeProveInput(((uint48,bytes32,bytes32,address,uint48,bytes32,(address,address,uint48,bytes32)[]),bool) _input) pure returns(bytes encoded_)
func (_CodecClient *CodecClientCaller) EncodeProveInput(opts *bind.CallOpts, _input IInboxProveInput) ([]byte, error) {
	var out []interface{}
	err := _CodecClient.contract.Call(opts, &out, "encodeProveInput", _input)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProveInput is a free data retrieval call binding the contract method 0xc3d3e2f4.
//
// Solidity: function encodeProveInput(((uint48,bytes32,bytes32,address,uint48,bytes32,(address,address,uint48,bytes32)[]),bool) _input) pure returns(bytes encoded_)
func (_CodecClient *CodecClientSession) EncodeProveInput(_input IInboxProveInput) ([]byte, error) {
	return _CodecClient.Contract.EncodeProveInput(&_CodecClient.CallOpts, _input)
}

// EncodeProveInput is a free data retrieval call binding the contract method 0xc3d3e2f4.
//
// Solidity: function encodeProveInput(((uint48,bytes32,bytes32,address,uint48,bytes32,(address,address,uint48,bytes32)[]),bool) _input) pure returns(bytes encoded_)
func (_CodecClient *CodecClientCallerSession) EncodeProveInput(_input IInboxProveInput) ([]byte, error) {
	return _CodecClient.Contract.EncodeProveInput(&_CodecClient.CallOpts, _input)
}

// HashBondInstruction is a free data retrieval call binding the contract method 0x5a213615.
//
// Solidity: function hashBondInstruction((uint48,uint8,address,address) _bondInstruction) pure returns(bytes32)
func (_CodecClient *CodecClientCaller) HashBondInstruction(opts *bind.CallOpts, _bondInstruction LibBondsBondInstruction) ([32]byte, error) {
	var out []interface{}
	err := _CodecClient.contract.Call(opts, &out, "hashBondInstruction", _bondInstruction)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashBondInstruction is a free data retrieval call binding the contract method 0x5a213615.
//
// Solidity: function hashBondInstruction((uint48,uint8,address,address) _bondInstruction) pure returns(bytes32)
func (_CodecClient *CodecClientSession) HashBondInstruction(_bondInstruction LibBondsBondInstruction) ([32]byte, error) {
	return _CodecClient.Contract.HashBondInstruction(&_CodecClient.CallOpts, _bondInstruction)
}

// HashBondInstruction is a free data retrieval call binding the contract method 0x5a213615.
//
// Solidity: function hashBondInstruction((uint48,uint8,address,address) _bondInstruction) pure returns(bytes32)
func (_CodecClient *CodecClientCallerSession) HashBondInstruction(_bondInstruction LibBondsBondInstruction) ([32]byte, error) {
	return _CodecClient.Contract.HashBondInstruction(&_CodecClient.CallOpts, _bondInstruction)
}

// HashCommitment is a free data retrieval call binding the contract method 0xcbc148c3.
//
// Solidity: function hashCommitment((uint48,bytes32,bytes32,address,uint48,bytes32,(address,address,uint48,bytes32)[]) _commitment) pure returns(bytes32)
func (_CodecClient *CodecClientCaller) HashCommitment(opts *bind.CallOpts, _commitment IInboxCommitment) ([32]byte, error) {
	var out []interface{}
	err := _CodecClient.contract.Call(opts, &out, "hashCommitment", _commitment)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashCommitment is a free data retrieval call binding the contract method 0xcbc148c3.
//
// Solidity: function hashCommitment((uint48,bytes32,bytes32,address,uint48,bytes32,(address,address,uint48,bytes32)[]) _commitment) pure returns(bytes32)
func (_CodecClient *CodecClientSession) HashCommitment(_commitment IInboxCommitment) ([32]byte, error) {
	return _CodecClient.Contract.HashCommitment(&_CodecClient.CallOpts, _commitment)
}

// HashCommitment is a free data retrieval call binding the contract method 0xcbc148c3.
//
// Solidity: function hashCommitment((uint48,bytes32,bytes32,address,uint48,bytes32,(address,address,uint48,bytes32)[]) _commitment) pure returns(bytes32)
func (_CodecClient *CodecClientCallerSession) HashCommitment(_commitment IInboxCommitment) ([32]byte, error) {
	return _CodecClient.Contract.HashCommitment(&_CodecClient.CallOpts, _commitment)
}

// HashProposal is a free data retrieval call binding the contract method 0xb28e824e.
//
// Solidity: function hashProposal((uint48,uint48,uint48,address,bytes32,uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]) _proposal) pure returns(bytes32)
func (_CodecClient *CodecClientCaller) HashProposal(opts *bind.CallOpts, _proposal IInboxProposal) ([32]byte, error) {
	var out []interface{}
	err := _CodecClient.contract.Call(opts, &out, "hashProposal", _proposal)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashProposal is a free data retrieval call binding the contract method 0xb28e824e.
//
// Solidity: function hashProposal((uint48,uint48,uint48,address,bytes32,uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]) _proposal) pure returns(bytes32)
func (_CodecClient *CodecClientSession) HashProposal(_proposal IInboxProposal) ([32]byte, error) {
	return _CodecClient.Contract.HashProposal(&_CodecClient.CallOpts, _proposal)
}

// HashProposal is a free data retrieval call binding the contract method 0xb28e824e.
//
// Solidity: function hashProposal((uint48,uint48,uint48,address,bytes32,uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[]) _proposal) pure returns(bytes32)
func (_CodecClient *CodecClientCallerSession) HashProposal(_proposal IInboxProposal) ([32]byte, error) {
	return _CodecClient.Contract.HashProposal(&_CodecClient.CallOpts, _proposal)
}
