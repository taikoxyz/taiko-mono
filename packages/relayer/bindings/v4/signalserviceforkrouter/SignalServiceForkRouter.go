// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package signalserviceforkrouter

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

// SignalServiceForkRouterMetaData contains all meta data concerning the SignalServiceForkRouter contract.
var SignalServiceForkRouterMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"_oldFork\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_newFork\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_shastaForkTimestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"fallback\",\"stateMutability\":\"payable\"},{\"type\":\"receive\",\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"newFork\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"oldFork\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"shastaForkTimestamp\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"shouldRouteToOldFork\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"InvalidParams\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZeroForkAddress\",\"inputs\":[]}]",
}

// SignalServiceForkRouterABI is the input ABI used to generate the binding from.
// Deprecated: Use SignalServiceForkRouterMetaData.ABI instead.
var SignalServiceForkRouterABI = SignalServiceForkRouterMetaData.ABI

// SignalServiceForkRouter is an auto generated Go binding around an Ethereum contract.
type SignalServiceForkRouter struct {
	SignalServiceForkRouterCaller     // Read-only binding to the contract
	SignalServiceForkRouterTransactor // Write-only binding to the contract
	SignalServiceForkRouterFilterer   // Log filterer for contract events
}

// SignalServiceForkRouterCaller is an auto generated read-only Go binding around an Ethereum contract.
type SignalServiceForkRouterCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SignalServiceForkRouterTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SignalServiceForkRouterTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SignalServiceForkRouterFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SignalServiceForkRouterFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SignalServiceForkRouterSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SignalServiceForkRouterSession struct {
	Contract     *SignalServiceForkRouter // Generic contract binding to set the session for
	CallOpts     bind.CallOpts            // Call options to use throughout this session
	TransactOpts bind.TransactOpts        // Transaction auth options to use throughout this session
}

// SignalServiceForkRouterCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SignalServiceForkRouterCallerSession struct {
	Contract *SignalServiceForkRouterCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                  // Call options to use throughout this session
}

// SignalServiceForkRouterTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SignalServiceForkRouterTransactorSession struct {
	Contract     *SignalServiceForkRouterTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                  // Transaction auth options to use throughout this session
}

// SignalServiceForkRouterRaw is an auto generated low-level Go binding around an Ethereum contract.
type SignalServiceForkRouterRaw struct {
	Contract *SignalServiceForkRouter // Generic contract binding to access the raw methods on
}

// SignalServiceForkRouterCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SignalServiceForkRouterCallerRaw struct {
	Contract *SignalServiceForkRouterCaller // Generic read-only contract binding to access the raw methods on
}

// SignalServiceForkRouterTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SignalServiceForkRouterTransactorRaw struct {
	Contract *SignalServiceForkRouterTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSignalServiceForkRouter creates a new instance of SignalServiceForkRouter, bound to a specific deployed contract.
func NewSignalServiceForkRouter(address common.Address, backend bind.ContractBackend) (*SignalServiceForkRouter, error) {
	contract, err := bindSignalServiceForkRouter(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SignalServiceForkRouter{SignalServiceForkRouterCaller: SignalServiceForkRouterCaller{contract: contract}, SignalServiceForkRouterTransactor: SignalServiceForkRouterTransactor{contract: contract}, SignalServiceForkRouterFilterer: SignalServiceForkRouterFilterer{contract: contract}}, nil
}

// NewSignalServiceForkRouterCaller creates a new read-only instance of SignalServiceForkRouter, bound to a specific deployed contract.
func NewSignalServiceForkRouterCaller(address common.Address, caller bind.ContractCaller) (*SignalServiceForkRouterCaller, error) {
	contract, err := bindSignalServiceForkRouter(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SignalServiceForkRouterCaller{contract: contract}, nil
}

// NewSignalServiceForkRouterTransactor creates a new write-only instance of SignalServiceForkRouter, bound to a specific deployed contract.
func NewSignalServiceForkRouterTransactor(address common.Address, transactor bind.ContractTransactor) (*SignalServiceForkRouterTransactor, error) {
	contract, err := bindSignalServiceForkRouter(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SignalServiceForkRouterTransactor{contract: contract}, nil
}

// NewSignalServiceForkRouterFilterer creates a new log filterer instance of SignalServiceForkRouter, bound to a specific deployed contract.
func NewSignalServiceForkRouterFilterer(address common.Address, filterer bind.ContractFilterer) (*SignalServiceForkRouterFilterer, error) {
	contract, err := bindSignalServiceForkRouter(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SignalServiceForkRouterFilterer{contract: contract}, nil
}

// bindSignalServiceForkRouter binds a generic wrapper to an already deployed contract.
func bindSignalServiceForkRouter(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SignalServiceForkRouterMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SignalServiceForkRouter *SignalServiceForkRouterRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SignalServiceForkRouter.Contract.SignalServiceForkRouterCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SignalServiceForkRouter *SignalServiceForkRouterRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SignalServiceForkRouter.Contract.SignalServiceForkRouterTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SignalServiceForkRouter *SignalServiceForkRouterRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SignalServiceForkRouter.Contract.SignalServiceForkRouterTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SignalServiceForkRouter *SignalServiceForkRouterCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SignalServiceForkRouter.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SignalServiceForkRouter *SignalServiceForkRouterTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SignalServiceForkRouter.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SignalServiceForkRouter *SignalServiceForkRouterTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SignalServiceForkRouter.Contract.contract.Transact(opts, method, params...)
}

// NewFork is a free data retrieval call binding the contract method 0x863acc33.
//
// Solidity: function newFork() view returns(address)
func (_SignalServiceForkRouter *SignalServiceForkRouterCaller) NewFork(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SignalServiceForkRouter.contract.Call(opts, &out, "newFork")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// NewFork is a free data retrieval call binding the contract method 0x863acc33.
//
// Solidity: function newFork() view returns(address)
func (_SignalServiceForkRouter *SignalServiceForkRouterSession) NewFork() (common.Address, error) {
	return _SignalServiceForkRouter.Contract.NewFork(&_SignalServiceForkRouter.CallOpts)
}

// NewFork is a free data retrieval call binding the contract method 0x863acc33.
//
// Solidity: function newFork() view returns(address)
func (_SignalServiceForkRouter *SignalServiceForkRouterCallerSession) NewFork() (common.Address, error) {
	return _SignalServiceForkRouter.Contract.NewFork(&_SignalServiceForkRouter.CallOpts)
}

// OldFork is a free data retrieval call binding the contract method 0xdf6060fb.
//
// Solidity: function oldFork() view returns(address)
func (_SignalServiceForkRouter *SignalServiceForkRouterCaller) OldFork(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SignalServiceForkRouter.contract.Call(opts, &out, "oldFork")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// OldFork is a free data retrieval call binding the contract method 0xdf6060fb.
//
// Solidity: function oldFork() view returns(address)
func (_SignalServiceForkRouter *SignalServiceForkRouterSession) OldFork() (common.Address, error) {
	return _SignalServiceForkRouter.Contract.OldFork(&_SignalServiceForkRouter.CallOpts)
}

// OldFork is a free data retrieval call binding the contract method 0xdf6060fb.
//
// Solidity: function oldFork() view returns(address)
func (_SignalServiceForkRouter *SignalServiceForkRouterCallerSession) OldFork() (common.Address, error) {
	return _SignalServiceForkRouter.Contract.OldFork(&_SignalServiceForkRouter.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_SignalServiceForkRouter *SignalServiceForkRouterCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SignalServiceForkRouter.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_SignalServiceForkRouter *SignalServiceForkRouterSession) Owner() (common.Address, error) {
	return _SignalServiceForkRouter.Contract.Owner(&_SignalServiceForkRouter.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_SignalServiceForkRouter *SignalServiceForkRouterCallerSession) Owner() (common.Address, error) {
	return _SignalServiceForkRouter.Contract.Owner(&_SignalServiceForkRouter.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_SignalServiceForkRouter *SignalServiceForkRouterCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SignalServiceForkRouter.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_SignalServiceForkRouter *SignalServiceForkRouterSession) PendingOwner() (common.Address, error) {
	return _SignalServiceForkRouter.Contract.PendingOwner(&_SignalServiceForkRouter.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_SignalServiceForkRouter *SignalServiceForkRouterCallerSession) PendingOwner() (common.Address, error) {
	return _SignalServiceForkRouter.Contract.PendingOwner(&_SignalServiceForkRouter.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_SignalServiceForkRouter *SignalServiceForkRouterCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SignalServiceForkRouter.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_SignalServiceForkRouter *SignalServiceForkRouterSession) ProxiableUUID() ([32]byte, error) {
	return _SignalServiceForkRouter.Contract.ProxiableUUID(&_SignalServiceForkRouter.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_SignalServiceForkRouter *SignalServiceForkRouterCallerSession) ProxiableUUID() ([32]byte, error) {
	return _SignalServiceForkRouter.Contract.ProxiableUUID(&_SignalServiceForkRouter.CallOpts)
}

// ShastaForkTimestamp is a free data retrieval call binding the contract method 0x8a5eb178.
//
// Solidity: function shastaForkTimestamp() view returns(uint64)
func (_SignalServiceForkRouter *SignalServiceForkRouterCaller) ShastaForkTimestamp(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _SignalServiceForkRouter.contract.Call(opts, &out, "shastaForkTimestamp")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// ShastaForkTimestamp is a free data retrieval call binding the contract method 0x8a5eb178.
//
// Solidity: function shastaForkTimestamp() view returns(uint64)
func (_SignalServiceForkRouter *SignalServiceForkRouterSession) ShastaForkTimestamp() (uint64, error) {
	return _SignalServiceForkRouter.Contract.ShastaForkTimestamp(&_SignalServiceForkRouter.CallOpts)
}

// ShastaForkTimestamp is a free data retrieval call binding the contract method 0x8a5eb178.
//
// Solidity: function shastaForkTimestamp() view returns(uint64)
func (_SignalServiceForkRouter *SignalServiceForkRouterCallerSession) ShastaForkTimestamp() (uint64, error) {
	return _SignalServiceForkRouter.Contract.ShastaForkTimestamp(&_SignalServiceForkRouter.CallOpts)
}

// ShouldRouteToOldFork is a free data retrieval call binding the contract method 0x003f3080.
//
// Solidity: function shouldRouteToOldFork(bytes4 ) view returns(bool)
func (_SignalServiceForkRouter *SignalServiceForkRouterCaller) ShouldRouteToOldFork(opts *bind.CallOpts, arg0 [4]byte) (bool, error) {
	var out []interface{}
	err := _SignalServiceForkRouter.contract.Call(opts, &out, "shouldRouteToOldFork", arg0)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// ShouldRouteToOldFork is a free data retrieval call binding the contract method 0x003f3080.
//
// Solidity: function shouldRouteToOldFork(bytes4 ) view returns(bool)
func (_SignalServiceForkRouter *SignalServiceForkRouterSession) ShouldRouteToOldFork(arg0 [4]byte) (bool, error) {
	return _SignalServiceForkRouter.Contract.ShouldRouteToOldFork(&_SignalServiceForkRouter.CallOpts, arg0)
}

// ShouldRouteToOldFork is a free data retrieval call binding the contract method 0x003f3080.
//
// Solidity: function shouldRouteToOldFork(bytes4 ) view returns(bool)
func (_SignalServiceForkRouter *SignalServiceForkRouterCallerSession) ShouldRouteToOldFork(arg0 [4]byte) (bool, error) {
	return _SignalServiceForkRouter.Contract.ShouldRouteToOldFork(&_SignalServiceForkRouter.CallOpts, arg0)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_SignalServiceForkRouter *SignalServiceForkRouterTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SignalServiceForkRouter.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_SignalServiceForkRouter *SignalServiceForkRouterSession) AcceptOwnership() (*types.Transaction, error) {
	return _SignalServiceForkRouter.Contract.AcceptOwnership(&_SignalServiceForkRouter.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_SignalServiceForkRouter *SignalServiceForkRouterTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _SignalServiceForkRouter.Contract.AcceptOwnership(&_SignalServiceForkRouter.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_SignalServiceForkRouter *SignalServiceForkRouterTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SignalServiceForkRouter.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_SignalServiceForkRouter *SignalServiceForkRouterSession) RenounceOwnership() (*types.Transaction, error) {
	return _SignalServiceForkRouter.Contract.RenounceOwnership(&_SignalServiceForkRouter.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_SignalServiceForkRouter *SignalServiceForkRouterTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _SignalServiceForkRouter.Contract.RenounceOwnership(&_SignalServiceForkRouter.TransactOpts)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_SignalServiceForkRouter *SignalServiceForkRouterTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _SignalServiceForkRouter.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_SignalServiceForkRouter *SignalServiceForkRouterSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _SignalServiceForkRouter.Contract.TransferOwnership(&_SignalServiceForkRouter.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_SignalServiceForkRouter *SignalServiceForkRouterTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _SignalServiceForkRouter.Contract.TransferOwnership(&_SignalServiceForkRouter.TransactOpts, newOwner)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_SignalServiceForkRouter *SignalServiceForkRouterTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _SignalServiceForkRouter.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_SignalServiceForkRouter *SignalServiceForkRouterSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _SignalServiceForkRouter.Contract.UpgradeTo(&_SignalServiceForkRouter.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_SignalServiceForkRouter *SignalServiceForkRouterTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _SignalServiceForkRouter.Contract.UpgradeTo(&_SignalServiceForkRouter.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_SignalServiceForkRouter *SignalServiceForkRouterTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _SignalServiceForkRouter.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_SignalServiceForkRouter *SignalServiceForkRouterSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _SignalServiceForkRouter.Contract.UpgradeToAndCall(&_SignalServiceForkRouter.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_SignalServiceForkRouter *SignalServiceForkRouterTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _SignalServiceForkRouter.Contract.UpgradeToAndCall(&_SignalServiceForkRouter.TransactOpts, newImplementation, data)
}

// Fallback is a paid mutator transaction binding the contract fallback function.
//
// Solidity: fallback() payable returns()
func (_SignalServiceForkRouter *SignalServiceForkRouterTransactor) Fallback(opts *bind.TransactOpts, calldata []byte) (*types.Transaction, error) {
	return _SignalServiceForkRouter.contract.RawTransact(opts, calldata)
}

// Fallback is a paid mutator transaction binding the contract fallback function.
//
// Solidity: fallback() payable returns()
func (_SignalServiceForkRouter *SignalServiceForkRouterSession) Fallback(calldata []byte) (*types.Transaction, error) {
	return _SignalServiceForkRouter.Contract.Fallback(&_SignalServiceForkRouter.TransactOpts, calldata)
}

// Fallback is a paid mutator transaction binding the contract fallback function.
//
// Solidity: fallback() payable returns()
func (_SignalServiceForkRouter *SignalServiceForkRouterTransactorSession) Fallback(calldata []byte) (*types.Transaction, error) {
	return _SignalServiceForkRouter.Contract.Fallback(&_SignalServiceForkRouter.TransactOpts, calldata)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_SignalServiceForkRouter *SignalServiceForkRouterTransactor) Receive(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SignalServiceForkRouter.contract.RawTransact(opts, nil) // calldata is disallowed for receive function
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_SignalServiceForkRouter *SignalServiceForkRouterSession) Receive() (*types.Transaction, error) {
	return _SignalServiceForkRouter.Contract.Receive(&_SignalServiceForkRouter.TransactOpts)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_SignalServiceForkRouter *SignalServiceForkRouterTransactorSession) Receive() (*types.Transaction, error) {
	return _SignalServiceForkRouter.Contract.Receive(&_SignalServiceForkRouter.TransactOpts)
}

// SignalServiceForkRouterAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the SignalServiceForkRouter contract.
type SignalServiceForkRouterAdminChangedIterator struct {
	Event *SignalServiceForkRouterAdminChanged // Event containing the contract specifics and raw log

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
func (it *SignalServiceForkRouterAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SignalServiceForkRouterAdminChanged)
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
		it.Event = new(SignalServiceForkRouterAdminChanged)
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
func (it *SignalServiceForkRouterAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SignalServiceForkRouterAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SignalServiceForkRouterAdminChanged represents a AdminChanged event raised by the SignalServiceForkRouter contract.
type SignalServiceForkRouterAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_SignalServiceForkRouter *SignalServiceForkRouterFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*SignalServiceForkRouterAdminChangedIterator, error) {

	logs, sub, err := _SignalServiceForkRouter.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &SignalServiceForkRouterAdminChangedIterator{contract: _SignalServiceForkRouter.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_SignalServiceForkRouter *SignalServiceForkRouterFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *SignalServiceForkRouterAdminChanged) (event.Subscription, error) {

	logs, sub, err := _SignalServiceForkRouter.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SignalServiceForkRouterAdminChanged)
				if err := _SignalServiceForkRouter.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_SignalServiceForkRouter *SignalServiceForkRouterFilterer) ParseAdminChanged(log types.Log) (*SignalServiceForkRouterAdminChanged, error) {
	event := new(SignalServiceForkRouterAdminChanged)
	if err := _SignalServiceForkRouter.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SignalServiceForkRouterBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the SignalServiceForkRouter contract.
type SignalServiceForkRouterBeaconUpgradedIterator struct {
	Event *SignalServiceForkRouterBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *SignalServiceForkRouterBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SignalServiceForkRouterBeaconUpgraded)
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
		it.Event = new(SignalServiceForkRouterBeaconUpgraded)
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
func (it *SignalServiceForkRouterBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SignalServiceForkRouterBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SignalServiceForkRouterBeaconUpgraded represents a BeaconUpgraded event raised by the SignalServiceForkRouter contract.
type SignalServiceForkRouterBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_SignalServiceForkRouter *SignalServiceForkRouterFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*SignalServiceForkRouterBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _SignalServiceForkRouter.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &SignalServiceForkRouterBeaconUpgradedIterator{contract: _SignalServiceForkRouter.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_SignalServiceForkRouter *SignalServiceForkRouterFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *SignalServiceForkRouterBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _SignalServiceForkRouter.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SignalServiceForkRouterBeaconUpgraded)
				if err := _SignalServiceForkRouter.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_SignalServiceForkRouter *SignalServiceForkRouterFilterer) ParseBeaconUpgraded(log types.Log) (*SignalServiceForkRouterBeaconUpgraded, error) {
	event := new(SignalServiceForkRouterBeaconUpgraded)
	if err := _SignalServiceForkRouter.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SignalServiceForkRouterInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the SignalServiceForkRouter contract.
type SignalServiceForkRouterInitializedIterator struct {
	Event *SignalServiceForkRouterInitialized // Event containing the contract specifics and raw log

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
func (it *SignalServiceForkRouterInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SignalServiceForkRouterInitialized)
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
		it.Event = new(SignalServiceForkRouterInitialized)
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
func (it *SignalServiceForkRouterInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SignalServiceForkRouterInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SignalServiceForkRouterInitialized represents a Initialized event raised by the SignalServiceForkRouter contract.
type SignalServiceForkRouterInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_SignalServiceForkRouter *SignalServiceForkRouterFilterer) FilterInitialized(opts *bind.FilterOpts) (*SignalServiceForkRouterInitializedIterator, error) {

	logs, sub, err := _SignalServiceForkRouter.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &SignalServiceForkRouterInitializedIterator{contract: _SignalServiceForkRouter.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_SignalServiceForkRouter *SignalServiceForkRouterFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *SignalServiceForkRouterInitialized) (event.Subscription, error) {

	logs, sub, err := _SignalServiceForkRouter.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SignalServiceForkRouterInitialized)
				if err := _SignalServiceForkRouter.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_SignalServiceForkRouter *SignalServiceForkRouterFilterer) ParseInitialized(log types.Log) (*SignalServiceForkRouterInitialized, error) {
	event := new(SignalServiceForkRouterInitialized)
	if err := _SignalServiceForkRouter.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SignalServiceForkRouterOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the SignalServiceForkRouter contract.
type SignalServiceForkRouterOwnershipTransferStartedIterator struct {
	Event *SignalServiceForkRouterOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *SignalServiceForkRouterOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SignalServiceForkRouterOwnershipTransferStarted)
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
		it.Event = new(SignalServiceForkRouterOwnershipTransferStarted)
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
func (it *SignalServiceForkRouterOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SignalServiceForkRouterOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SignalServiceForkRouterOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the SignalServiceForkRouter contract.
type SignalServiceForkRouterOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_SignalServiceForkRouter *SignalServiceForkRouterFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*SignalServiceForkRouterOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SignalServiceForkRouter.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &SignalServiceForkRouterOwnershipTransferStartedIterator{contract: _SignalServiceForkRouter.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_SignalServiceForkRouter *SignalServiceForkRouterFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *SignalServiceForkRouterOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SignalServiceForkRouter.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SignalServiceForkRouterOwnershipTransferStarted)
				if err := _SignalServiceForkRouter.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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
func (_SignalServiceForkRouter *SignalServiceForkRouterFilterer) ParseOwnershipTransferStarted(log types.Log) (*SignalServiceForkRouterOwnershipTransferStarted, error) {
	event := new(SignalServiceForkRouterOwnershipTransferStarted)
	if err := _SignalServiceForkRouter.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SignalServiceForkRouterOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the SignalServiceForkRouter contract.
type SignalServiceForkRouterOwnershipTransferredIterator struct {
	Event *SignalServiceForkRouterOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *SignalServiceForkRouterOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SignalServiceForkRouterOwnershipTransferred)
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
		it.Event = new(SignalServiceForkRouterOwnershipTransferred)
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
func (it *SignalServiceForkRouterOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SignalServiceForkRouterOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SignalServiceForkRouterOwnershipTransferred represents a OwnershipTransferred event raised by the SignalServiceForkRouter contract.
type SignalServiceForkRouterOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_SignalServiceForkRouter *SignalServiceForkRouterFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*SignalServiceForkRouterOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SignalServiceForkRouter.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &SignalServiceForkRouterOwnershipTransferredIterator{contract: _SignalServiceForkRouter.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_SignalServiceForkRouter *SignalServiceForkRouterFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *SignalServiceForkRouterOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SignalServiceForkRouter.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SignalServiceForkRouterOwnershipTransferred)
				if err := _SignalServiceForkRouter.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_SignalServiceForkRouter *SignalServiceForkRouterFilterer) ParseOwnershipTransferred(log types.Log) (*SignalServiceForkRouterOwnershipTransferred, error) {
	event := new(SignalServiceForkRouterOwnershipTransferred)
	if err := _SignalServiceForkRouter.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SignalServiceForkRouterUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the SignalServiceForkRouter contract.
type SignalServiceForkRouterUpgradedIterator struct {
	Event *SignalServiceForkRouterUpgraded // Event containing the contract specifics and raw log

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
func (it *SignalServiceForkRouterUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SignalServiceForkRouterUpgraded)
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
		it.Event = new(SignalServiceForkRouterUpgraded)
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
func (it *SignalServiceForkRouterUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SignalServiceForkRouterUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SignalServiceForkRouterUpgraded represents a Upgraded event raised by the SignalServiceForkRouter contract.
type SignalServiceForkRouterUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_SignalServiceForkRouter *SignalServiceForkRouterFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*SignalServiceForkRouterUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _SignalServiceForkRouter.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &SignalServiceForkRouterUpgradedIterator{contract: _SignalServiceForkRouter.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_SignalServiceForkRouter *SignalServiceForkRouterFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *SignalServiceForkRouterUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _SignalServiceForkRouter.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SignalServiceForkRouterUpgraded)
				if err := _SignalServiceForkRouter.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_SignalServiceForkRouter *SignalServiceForkRouterFilterer) ParseUpgraded(log types.Log) (*SignalServiceForkRouterUpgraded, error) {
	event := new(SignalServiceForkRouterUpgraded)
	if err := _SignalServiceForkRouter.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
