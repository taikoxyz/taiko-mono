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

// LibUtilsMetaData contains all meta data concerning the LibUtils contract.
var LibUtilsMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"error\",\"name\":\"L1_BLOCK_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_INVALID_BLOCK_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_TRANSITION_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_UNEXPECTED_TRANSITION_ID\",\"inputs\":[]}]",
}

// LibUtilsABI is the input ABI used to generate the binding from.
// Deprecated: Use LibUtilsMetaData.ABI instead.
var LibUtilsABI = LibUtilsMetaData.ABI

// LibUtils is an auto generated Go binding around an Ethereum contract.
type LibUtils struct {
	LibUtilsCaller     // Read-only binding to the contract
	LibUtilsTransactor // Write-only binding to the contract
	LibUtilsFilterer   // Log filterer for contract events
}

// LibUtilsCaller is an auto generated read-only Go binding around an Ethereum contract.
type LibUtilsCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// LibUtilsTransactor is an auto generated write-only Go binding around an Ethereum contract.
type LibUtilsTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// LibUtilsFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type LibUtilsFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// LibUtilsSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type LibUtilsSession struct {
	Contract     *LibUtils         // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// LibUtilsCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type LibUtilsCallerSession struct {
	Contract *LibUtilsCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts   // Call options to use throughout this session
}

// LibUtilsTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type LibUtilsTransactorSession struct {
	Contract     *LibUtilsTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts   // Transaction auth options to use throughout this session
}

// LibUtilsRaw is an auto generated low-level Go binding around an Ethereum contract.
type LibUtilsRaw struct {
	Contract *LibUtils // Generic contract binding to access the raw methods on
}

// LibUtilsCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type LibUtilsCallerRaw struct {
	Contract *LibUtilsCaller // Generic read-only contract binding to access the raw methods on
}

// LibUtilsTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type LibUtilsTransactorRaw struct {
	Contract *LibUtilsTransactor // Generic write-only contract binding to access the raw methods on
}

// NewLibUtils creates a new instance of LibUtils, bound to a specific deployed contract.
func NewLibUtils(address common.Address, backend bind.ContractBackend) (*LibUtils, error) {
	contract, err := bindLibUtils(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &LibUtils{LibUtilsCaller: LibUtilsCaller{contract: contract}, LibUtilsTransactor: LibUtilsTransactor{contract: contract}, LibUtilsFilterer: LibUtilsFilterer{contract: contract}}, nil
}

// NewLibUtilsCaller creates a new read-only instance of LibUtils, bound to a specific deployed contract.
func NewLibUtilsCaller(address common.Address, caller bind.ContractCaller) (*LibUtilsCaller, error) {
	contract, err := bindLibUtils(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &LibUtilsCaller{contract: contract}, nil
}

// NewLibUtilsTransactor creates a new write-only instance of LibUtils, bound to a specific deployed contract.
func NewLibUtilsTransactor(address common.Address, transactor bind.ContractTransactor) (*LibUtilsTransactor, error) {
	contract, err := bindLibUtils(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &LibUtilsTransactor{contract: contract}, nil
}

// NewLibUtilsFilterer creates a new log filterer instance of LibUtils, bound to a specific deployed contract.
func NewLibUtilsFilterer(address common.Address, filterer bind.ContractFilterer) (*LibUtilsFilterer, error) {
	contract, err := bindLibUtils(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &LibUtilsFilterer{contract: contract}, nil
}

// bindLibUtils binds a generic wrapper to an already deployed contract.
func bindLibUtils(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := LibUtilsMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_LibUtils *LibUtilsRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _LibUtils.Contract.LibUtilsCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_LibUtils *LibUtilsRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _LibUtils.Contract.LibUtilsTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_LibUtils *LibUtilsRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _LibUtils.Contract.LibUtilsTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_LibUtils *LibUtilsCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _LibUtils.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_LibUtils *LibUtilsTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _LibUtils.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_LibUtils *LibUtilsTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _LibUtils.Contract.contract.Transact(opts, method, params...)
}
