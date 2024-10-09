// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package bindings

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

// IPreconfTaskManagerLookaheadBufferEntry is an auto generated low-level Go binding around an user-defined struct.
type IPreconfTaskManagerLookaheadBufferEntry struct {
	IsFallback    bool
	Timestamp     *big.Int
	PrevTimestamp *big.Int
	Preconfer     common.Address
}

// IPreconfTaskManagerLookaheadSetParam is an auto generated low-level Go binding around an user-defined struct.
type IPreconfTaskManagerLookaheadSetParam struct {
	Timestamp *big.Int
	Preconfer common.Address
}

// PreconfTaskManagerMetaData contains all meta data concerning the PreconfTaskManager contract.
var PreconfTaskManagerMetaData = &bind.MetaData{
	ABI: "[{\"inputs\":[],\"name\":\"getLookaheadBuffer\",\"outputs\":[{\"components\":[{\"internalType\":\"bool\",\"name\":\"isFallback\",\"type\":\"bool\"},{\"internalType\":\"uint40\",\"name\":\"timestamp\",\"type\":\"uint40\"},{\"internalType\":\"uint40\",\"name\":\"prevTimestamp\",\"type\":\"uint40\"},{\"internalType\":\"address\",\"name\":\"preconfer\",\"type\":\"address\"}],\"internalType\":\"structIPreconfTaskManager.LookaheadBufferEntry[64]\",\"name\":\"\",\"type\":\"tuple[64]\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes[]\",\"name\":\"blockParams\",\"type\":\"bytes[]\"},{\"internalType\":\"bytes[]\",\"name\":\"txLists\",\"type\":\"bytes[]\"},{\"internalType\":\"uint256\",\"name\":\"lookaheadPointer\",\"type\":\"uint256\"},{\"components\":[{\"internalType\":\"uint256\",\"name\":\"timestamp\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"preconfer\",\"type\":\"address\"}],\"internalType\":\"structIPreconfTaskManager.LookaheadSetParam[]\",\"name\":\"lookaheadSetParams\",\"type\":\"tuple[]\"}],\"name\":\"newBlockProposal\",\"outputs\":[],\"stateMutability\":\"payable\",\"type\":\"function\"}]",
}

// PreconfTaskManagerABI is the input ABI used to generate the binding from.
// Deprecated: Use PreconfTaskManagerMetaData.ABI instead.
var PreconfTaskManagerABI = PreconfTaskManagerMetaData.ABI

// PreconfTaskManager is an auto generated Go binding around an Ethereum contract.
type PreconfTaskManager struct {
	PreconfTaskManagerCaller     // Read-only binding to the contract
	PreconfTaskManagerTransactor // Write-only binding to the contract
	PreconfTaskManagerFilterer   // Log filterer for contract events
}

// PreconfTaskManagerCaller is an auto generated read-only Go binding around an Ethereum contract.
type PreconfTaskManagerCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// PreconfTaskManagerTransactor is an auto generated write-only Go binding around an Ethereum contract.
type PreconfTaskManagerTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// PreconfTaskManagerFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type PreconfTaskManagerFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// PreconfTaskManagerSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type PreconfTaskManagerSession struct {
	Contract     *PreconfTaskManager // Generic contract binding to set the session for
	CallOpts     bind.CallOpts       // Call options to use throughout this session
	TransactOpts bind.TransactOpts   // Transaction auth options to use throughout this session
}

// PreconfTaskManagerCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type PreconfTaskManagerCallerSession struct {
	Contract *PreconfTaskManagerCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts             // Call options to use throughout this session
}

// PreconfTaskManagerTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type PreconfTaskManagerTransactorSession struct {
	Contract     *PreconfTaskManagerTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts             // Transaction auth options to use throughout this session
}

// PreconfTaskManagerRaw is an auto generated low-level Go binding around an Ethereum contract.
type PreconfTaskManagerRaw struct {
	Contract *PreconfTaskManager // Generic contract binding to access the raw methods on
}

// PreconfTaskManagerCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type PreconfTaskManagerCallerRaw struct {
	Contract *PreconfTaskManagerCaller // Generic read-only contract binding to access the raw methods on
}

// PreconfTaskManagerTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type PreconfTaskManagerTransactorRaw struct {
	Contract *PreconfTaskManagerTransactor // Generic write-only contract binding to access the raw methods on
}

// NewPreconfTaskManager creates a new instance of PreconfTaskManager, bound to a specific deployed contract.
func NewPreconfTaskManager(address common.Address, backend bind.ContractBackend) (*PreconfTaskManager, error) {
	contract, err := bindPreconfTaskManager(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &PreconfTaskManager{PreconfTaskManagerCaller: PreconfTaskManagerCaller{contract: contract}, PreconfTaskManagerTransactor: PreconfTaskManagerTransactor{contract: contract}, PreconfTaskManagerFilterer: PreconfTaskManagerFilterer{contract: contract}}, nil
}

// NewPreconfTaskManagerCaller creates a new read-only instance of PreconfTaskManager, bound to a specific deployed contract.
func NewPreconfTaskManagerCaller(address common.Address, caller bind.ContractCaller) (*PreconfTaskManagerCaller, error) {
	contract, err := bindPreconfTaskManager(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &PreconfTaskManagerCaller{contract: contract}, nil
}

// NewPreconfTaskManagerTransactor creates a new write-only instance of PreconfTaskManager, bound to a specific deployed contract.
func NewPreconfTaskManagerTransactor(address common.Address, transactor bind.ContractTransactor) (*PreconfTaskManagerTransactor, error) {
	contract, err := bindPreconfTaskManager(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &PreconfTaskManagerTransactor{contract: contract}, nil
}

// NewPreconfTaskManagerFilterer creates a new log filterer instance of PreconfTaskManager, bound to a specific deployed contract.
func NewPreconfTaskManagerFilterer(address common.Address, filterer bind.ContractFilterer) (*PreconfTaskManagerFilterer, error) {
	contract, err := bindPreconfTaskManager(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &PreconfTaskManagerFilterer{contract: contract}, nil
}

// bindPreconfTaskManager binds a generic wrapper to an already deployed contract.
func bindPreconfTaskManager(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := PreconfTaskManagerMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_PreconfTaskManager *PreconfTaskManagerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _PreconfTaskManager.Contract.PreconfTaskManagerCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_PreconfTaskManager *PreconfTaskManagerRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _PreconfTaskManager.Contract.PreconfTaskManagerTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_PreconfTaskManager *PreconfTaskManagerRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _PreconfTaskManager.Contract.PreconfTaskManagerTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_PreconfTaskManager *PreconfTaskManagerCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _PreconfTaskManager.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_PreconfTaskManager *PreconfTaskManagerTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _PreconfTaskManager.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_PreconfTaskManager *PreconfTaskManagerTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _PreconfTaskManager.Contract.contract.Transact(opts, method, params...)
}

// GetLookaheadBuffer is a free data retrieval call binding the contract method 0xd91f98f3.
//
// Solidity: function getLookaheadBuffer() view returns((bool,uint40,uint40,address)[64])
func (_PreconfTaskManager *PreconfTaskManagerCaller) GetLookaheadBuffer(opts *bind.CallOpts) ([64]IPreconfTaskManagerLookaheadBufferEntry, error) {
	var out []interface{}
	err := _PreconfTaskManager.contract.Call(opts, &out, "getLookaheadBuffer")

	if err != nil {
		return *new([64]IPreconfTaskManagerLookaheadBufferEntry), err
	}

	out0 := *abi.ConvertType(out[0], new([64]IPreconfTaskManagerLookaheadBufferEntry)).(*[64]IPreconfTaskManagerLookaheadBufferEntry)

	return out0, err

}

// GetLookaheadBuffer is a free data retrieval call binding the contract method 0xd91f98f3.
//
// Solidity: function getLookaheadBuffer() view returns((bool,uint40,uint40,address)[64])
func (_PreconfTaskManager *PreconfTaskManagerSession) GetLookaheadBuffer() ([64]IPreconfTaskManagerLookaheadBufferEntry, error) {
	return _PreconfTaskManager.Contract.GetLookaheadBuffer(&_PreconfTaskManager.CallOpts)
}

// GetLookaheadBuffer is a free data retrieval call binding the contract method 0xd91f98f3.
//
// Solidity: function getLookaheadBuffer() view returns((bool,uint40,uint40,address)[64])
func (_PreconfTaskManager *PreconfTaskManagerCallerSession) GetLookaheadBuffer() ([64]IPreconfTaskManagerLookaheadBufferEntry, error) {
	return _PreconfTaskManager.Contract.GetLookaheadBuffer(&_PreconfTaskManager.CallOpts)
}

// NewBlockProposal is a paid mutator transaction binding the contract method 0x230f1af9.
//
// Solidity: function newBlockProposal(bytes[] blockParams, bytes[] txLists, uint256 lookaheadPointer, (uint256,address)[] lookaheadSetParams) payable returns()
func (_PreconfTaskManager *PreconfTaskManagerTransactor) NewBlockProposal(opts *bind.TransactOpts, blockParams [][]byte, txLists [][]byte, lookaheadPointer *big.Int, lookaheadSetParams []IPreconfTaskManagerLookaheadSetParam) (*types.Transaction, error) {
	return _PreconfTaskManager.contract.Transact(opts, "newBlockProposal", blockParams, txLists, lookaheadPointer, lookaheadSetParams)
}

// NewBlockProposal is a paid mutator transaction binding the contract method 0x230f1af9.
//
// Solidity: function newBlockProposal(bytes[] blockParams, bytes[] txLists, uint256 lookaheadPointer, (uint256,address)[] lookaheadSetParams) payable returns()
func (_PreconfTaskManager *PreconfTaskManagerSession) NewBlockProposal(blockParams [][]byte, txLists [][]byte, lookaheadPointer *big.Int, lookaheadSetParams []IPreconfTaskManagerLookaheadSetParam) (*types.Transaction, error) {
	return _PreconfTaskManager.Contract.NewBlockProposal(&_PreconfTaskManager.TransactOpts, blockParams, txLists, lookaheadPointer, lookaheadSetParams)
}

// NewBlockProposal is a paid mutator transaction binding the contract method 0x230f1af9.
//
// Solidity: function newBlockProposal(bytes[] blockParams, bytes[] txLists, uint256 lookaheadPointer, (uint256,address)[] lookaheadSetParams) payable returns()
func (_PreconfTaskManager *PreconfTaskManagerTransactorSession) NewBlockProposal(blockParams [][]byte, txLists [][]byte, lookaheadPointer *big.Int, lookaheadSetParams []IPreconfTaskManagerLookaheadSetParam) (*types.Transaction, error) {
	return _PreconfTaskManager.Contract.NewBlockProposal(&_PreconfTaskManager.TransactOpts, blockParams, txLists, lookaheadPointer, lookaheadSetParams)
}
