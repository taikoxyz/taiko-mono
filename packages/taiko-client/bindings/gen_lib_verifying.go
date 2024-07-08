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

// LibVerifyingMetaData contains all meta data concerning the LibVerifying contract.
var LibVerifyingMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"error\",\"name\":\"L1_BLOCK_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_INVALID_CONFIG\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_TOO_LATE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_TRANSITION_ID_ZERO\",\"inputs\":[]}]",
}

// LibVerifyingABI is the input ABI used to generate the binding from.
// Deprecated: Use LibVerifyingMetaData.ABI instead.
var LibVerifyingABI = LibVerifyingMetaData.ABI

// LibVerifying is an auto generated Go binding around an Ethereum contract.
type LibVerifying struct {
	LibVerifyingCaller     // Read-only binding to the contract
	LibVerifyingTransactor // Write-only binding to the contract
	LibVerifyingFilterer   // Log filterer for contract events
}

// LibVerifyingCaller is an auto generated read-only Go binding around an Ethereum contract.
type LibVerifyingCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// LibVerifyingTransactor is an auto generated write-only Go binding around an Ethereum contract.
type LibVerifyingTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// LibVerifyingFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type LibVerifyingFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// LibVerifyingSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type LibVerifyingSession struct {
	Contract     *LibVerifying     // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// LibVerifyingCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type LibVerifyingCallerSession struct {
	Contract *LibVerifyingCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts       // Call options to use throughout this session
}

// LibVerifyingTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type LibVerifyingTransactorSession struct {
	Contract     *LibVerifyingTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts       // Transaction auth options to use throughout this session
}

// LibVerifyingRaw is an auto generated low-level Go binding around an Ethereum contract.
type LibVerifyingRaw struct {
	Contract *LibVerifying // Generic contract binding to access the raw methods on
}

// LibVerifyingCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type LibVerifyingCallerRaw struct {
	Contract *LibVerifyingCaller // Generic read-only contract binding to access the raw methods on
}

// LibVerifyingTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type LibVerifyingTransactorRaw struct {
	Contract *LibVerifyingTransactor // Generic write-only contract binding to access the raw methods on
}

// NewLibVerifying creates a new instance of LibVerifying, bound to a specific deployed contract.
func NewLibVerifying(address common.Address, backend bind.ContractBackend) (*LibVerifying, error) {
	contract, err := bindLibVerifying(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &LibVerifying{LibVerifyingCaller: LibVerifyingCaller{contract: contract}, LibVerifyingTransactor: LibVerifyingTransactor{contract: contract}, LibVerifyingFilterer: LibVerifyingFilterer{contract: contract}}, nil
}

// NewLibVerifyingCaller creates a new read-only instance of LibVerifying, bound to a specific deployed contract.
func NewLibVerifyingCaller(address common.Address, caller bind.ContractCaller) (*LibVerifyingCaller, error) {
	contract, err := bindLibVerifying(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &LibVerifyingCaller{contract: contract}, nil
}

// NewLibVerifyingTransactor creates a new write-only instance of LibVerifying, bound to a specific deployed contract.
func NewLibVerifyingTransactor(address common.Address, transactor bind.ContractTransactor) (*LibVerifyingTransactor, error) {
	contract, err := bindLibVerifying(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &LibVerifyingTransactor{contract: contract}, nil
}

// NewLibVerifyingFilterer creates a new log filterer instance of LibVerifying, bound to a specific deployed contract.
func NewLibVerifyingFilterer(address common.Address, filterer bind.ContractFilterer) (*LibVerifyingFilterer, error) {
	contract, err := bindLibVerifying(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &LibVerifyingFilterer{contract: contract}, nil
}

// bindLibVerifying binds a generic wrapper to an already deployed contract.
func bindLibVerifying(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := LibVerifyingMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_LibVerifying *LibVerifyingRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _LibVerifying.Contract.LibVerifyingCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_LibVerifying *LibVerifyingRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _LibVerifying.Contract.LibVerifyingTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_LibVerifying *LibVerifyingRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _LibVerifying.Contract.LibVerifyingTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_LibVerifying *LibVerifyingCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _LibVerifying.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_LibVerifying *LibVerifyingTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _LibVerifying.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_LibVerifying *LibVerifyingTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _LibVerifying.Contract.contract.Transact(opts, method, params...)
}
