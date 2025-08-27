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

// LibManifestClientMetaData contains all meta data concerning the LibManifestClient contract.
var LibManifestClientMetaData = &bind.MetaData{
	ABI: "[]",
}

// LibManifestClientABI is the input ABI used to generate the binding from.
// Deprecated: Use LibManifestClientMetaData.ABI instead.
var LibManifestClientABI = LibManifestClientMetaData.ABI

// LibManifestClient is an auto generated Go binding around an Ethereum contract.
type LibManifestClient struct {
	LibManifestClientCaller     // Read-only binding to the contract
	LibManifestClientTransactor // Write-only binding to the contract
	LibManifestClientFilterer   // Log filterer for contract events
}

// LibManifestClientCaller is an auto generated read-only Go binding around an Ethereum contract.
type LibManifestClientCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// LibManifestClientTransactor is an auto generated write-only Go binding around an Ethereum contract.
type LibManifestClientTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// LibManifestClientFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type LibManifestClientFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// LibManifestClientSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type LibManifestClientSession struct {
	Contract     *LibManifestClient // Generic contract binding to set the session for
	CallOpts     bind.CallOpts      // Call options to use throughout this session
	TransactOpts bind.TransactOpts  // Transaction auth options to use throughout this session
}

// LibManifestClientCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type LibManifestClientCallerSession struct {
	Contract *LibManifestClientCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts            // Call options to use throughout this session
}

// LibManifestClientTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type LibManifestClientTransactorSession struct {
	Contract     *LibManifestClientTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts            // Transaction auth options to use throughout this session
}

// LibManifestClientRaw is an auto generated low-level Go binding around an Ethereum contract.
type LibManifestClientRaw struct {
	Contract *LibManifestClient // Generic contract binding to access the raw methods on
}

// LibManifestClientCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type LibManifestClientCallerRaw struct {
	Contract *LibManifestClientCaller // Generic read-only contract binding to access the raw methods on
}

// LibManifestClientTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type LibManifestClientTransactorRaw struct {
	Contract *LibManifestClientTransactor // Generic write-only contract binding to access the raw methods on
}

// NewLibManifestClient creates a new instance of LibManifestClient, bound to a specific deployed contract.
func NewLibManifestClient(address common.Address, backend bind.ContractBackend) (*LibManifestClient, error) {
	contract, err := bindLibManifestClient(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &LibManifestClient{LibManifestClientCaller: LibManifestClientCaller{contract: contract}, LibManifestClientTransactor: LibManifestClientTransactor{contract: contract}, LibManifestClientFilterer: LibManifestClientFilterer{contract: contract}}, nil
}

// NewLibManifestClientCaller creates a new read-only instance of LibManifestClient, bound to a specific deployed contract.
func NewLibManifestClientCaller(address common.Address, caller bind.ContractCaller) (*LibManifestClientCaller, error) {
	contract, err := bindLibManifestClient(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &LibManifestClientCaller{contract: contract}, nil
}

// NewLibManifestClientTransactor creates a new write-only instance of LibManifestClient, bound to a specific deployed contract.
func NewLibManifestClientTransactor(address common.Address, transactor bind.ContractTransactor) (*LibManifestClientTransactor, error) {
	contract, err := bindLibManifestClient(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &LibManifestClientTransactor{contract: contract}, nil
}

// NewLibManifestClientFilterer creates a new log filterer instance of LibManifestClient, bound to a specific deployed contract.
func NewLibManifestClientFilterer(address common.Address, filterer bind.ContractFilterer) (*LibManifestClientFilterer, error) {
	contract, err := bindLibManifestClient(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &LibManifestClientFilterer{contract: contract}, nil
}

// bindLibManifestClient binds a generic wrapper to an already deployed contract.
func bindLibManifestClient(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := LibManifestClientMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_LibManifestClient *LibManifestClientRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _LibManifestClient.Contract.LibManifestClientCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_LibManifestClient *LibManifestClientRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _LibManifestClient.Contract.LibManifestClientTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_LibManifestClient *LibManifestClientRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _LibManifestClient.Contract.LibManifestClientTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_LibManifestClient *LibManifestClientCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _LibManifestClient.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_LibManifestClient *LibManifestClientTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _LibManifestClient.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_LibManifestClient *LibManifestClientTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _LibManifestClient.Contract.contract.Transact(opts, method, params...)
}
