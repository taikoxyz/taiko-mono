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

// AddressManagerMetaData contains all meta data concerning the AddressManager contract.
var AddressManagerMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"addressManager\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getAddress\",\"inputs\":[{\"name\":\"_chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"impl\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inNonReentrant\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"init2\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"lastUnpausedAt\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolve\",\"inputs\":[{\"name\":\"_chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_allowZeroAddress\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"resolve\",\"inputs\":[{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_allowZeroAddress\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"setAddress\",\"inputs\":[{\"name\":\"_chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_newAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"event\",\"name\":\"AddressSet\",\"inputs\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"indexed\":true,\"internalType\":\"uint64\"},{\"name\":\"name\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"newAddress\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"oldAddress\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"AM_ADDRESS_ALREADY_SET\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FUNC_NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_INVALID_MANAGER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_UNEXPECTED_CHAINID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_ZERO_ADDR\",\"inputs\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_VALUE\",\"inputs\":[]}]",
}

// AddressManagerABI is the input ABI used to generate the binding from.
// Deprecated: Use AddressManagerMetaData.ABI instead.
var AddressManagerABI = AddressManagerMetaData.ABI

// AddressManager is an auto generated Go binding around an Ethereum contract.
type AddressManager struct {
	AddressManagerCaller     // Read-only binding to the contract
	AddressManagerTransactor // Write-only binding to the contract
	AddressManagerFilterer   // Log filterer for contract events
}

// AddressManagerCaller is an auto generated read-only Go binding around an Ethereum contract.
type AddressManagerCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AddressManagerTransactor is an auto generated write-only Go binding around an Ethereum contract.
type AddressManagerTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AddressManagerFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type AddressManagerFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AddressManagerSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type AddressManagerSession struct {
	Contract     *AddressManager   // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// AddressManagerCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type AddressManagerCallerSession struct {
	Contract *AddressManagerCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts         // Call options to use throughout this session
}

// AddressManagerTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type AddressManagerTransactorSession struct {
	Contract     *AddressManagerTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts         // Transaction auth options to use throughout this session
}

// AddressManagerRaw is an auto generated low-level Go binding around an Ethereum contract.
type AddressManagerRaw struct {
	Contract *AddressManager // Generic contract binding to access the raw methods on
}

// AddressManagerCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type AddressManagerCallerRaw struct {
	Contract *AddressManagerCaller // Generic read-only contract binding to access the raw methods on
}

// AddressManagerTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type AddressManagerTransactorRaw struct {
	Contract *AddressManagerTransactor // Generic write-only contract binding to access the raw methods on
}

// NewAddressManager creates a new instance of AddressManager, bound to a specific deployed contract.
func NewAddressManager(address common.Address, backend bind.ContractBackend) (*AddressManager, error) {
	contract, err := bindAddressManager(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &AddressManager{AddressManagerCaller: AddressManagerCaller{contract: contract}, AddressManagerTransactor: AddressManagerTransactor{contract: contract}, AddressManagerFilterer: AddressManagerFilterer{contract: contract}}, nil
}

// NewAddressManagerCaller creates a new read-only instance of AddressManager, bound to a specific deployed contract.
func NewAddressManagerCaller(address common.Address, caller bind.ContractCaller) (*AddressManagerCaller, error) {
	contract, err := bindAddressManager(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &AddressManagerCaller{contract: contract}, nil
}

// NewAddressManagerTransactor creates a new write-only instance of AddressManager, bound to a specific deployed contract.
func NewAddressManagerTransactor(address common.Address, transactor bind.ContractTransactor) (*AddressManagerTransactor, error) {
	contract, err := bindAddressManager(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &AddressManagerTransactor{contract: contract}, nil
}

// NewAddressManagerFilterer creates a new log filterer instance of AddressManager, bound to a specific deployed contract.
func NewAddressManagerFilterer(address common.Address, filterer bind.ContractFilterer) (*AddressManagerFilterer, error) {
	contract, err := bindAddressManager(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &AddressManagerFilterer{contract: contract}, nil
}

// bindAddressManager binds a generic wrapper to an already deployed contract.
func bindAddressManager(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := AddressManagerMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_AddressManager *AddressManagerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _AddressManager.Contract.AddressManagerCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_AddressManager *AddressManagerRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AddressManager.Contract.AddressManagerTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_AddressManager *AddressManagerRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _AddressManager.Contract.AddressManagerTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_AddressManager *AddressManagerCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _AddressManager.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_AddressManager *AddressManagerTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AddressManager.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_AddressManager *AddressManagerTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _AddressManager.Contract.contract.Transact(opts, method, params...)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_AddressManager *AddressManagerCaller) AddressManager(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AddressManager.contract.Call(opts, &out, "addressManager")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_AddressManager *AddressManagerSession) AddressManager() (common.Address, error) {
	return _AddressManager.Contract.AddressManager(&_AddressManager.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_AddressManager *AddressManagerCallerSession) AddressManager() (common.Address, error) {
	return _AddressManager.Contract.AddressManager(&_AddressManager.CallOpts)
}

// GetAddress is a free data retrieval call binding the contract method 0x28f713cc.
//
// Solidity: function getAddress(uint64 _chainId, bytes32 _name) view returns(address)
func (_AddressManager *AddressManagerCaller) GetAddress(opts *bind.CallOpts, _chainId uint64, _name [32]byte) (common.Address, error) {
	var out []interface{}
	err := _AddressManager.contract.Call(opts, &out, "getAddress", _chainId, _name)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetAddress is a free data retrieval call binding the contract method 0x28f713cc.
//
// Solidity: function getAddress(uint64 _chainId, bytes32 _name) view returns(address)
func (_AddressManager *AddressManagerSession) GetAddress(_chainId uint64, _name [32]byte) (common.Address, error) {
	return _AddressManager.Contract.GetAddress(&_AddressManager.CallOpts, _chainId, _name)
}

// GetAddress is a free data retrieval call binding the contract method 0x28f713cc.
//
// Solidity: function getAddress(uint64 _chainId, bytes32 _name) view returns(address)
func (_AddressManager *AddressManagerCallerSession) GetAddress(_chainId uint64, _name [32]byte) (common.Address, error) {
	return _AddressManager.Contract.GetAddress(&_AddressManager.CallOpts, _chainId, _name)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_AddressManager *AddressManagerCaller) Impl(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AddressManager.contract.Call(opts, &out, "impl")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_AddressManager *AddressManagerSession) Impl() (common.Address, error) {
	return _AddressManager.Contract.Impl(&_AddressManager.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_AddressManager *AddressManagerCallerSession) Impl() (common.Address, error) {
	return _AddressManager.Contract.Impl(&_AddressManager.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_AddressManager *AddressManagerCaller) InNonReentrant(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _AddressManager.contract.Call(opts, &out, "inNonReentrant")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_AddressManager *AddressManagerSession) InNonReentrant() (bool, error) {
	return _AddressManager.Contract.InNonReentrant(&_AddressManager.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_AddressManager *AddressManagerCallerSession) InNonReentrant() (bool, error) {
	return _AddressManager.Contract.InNonReentrant(&_AddressManager.CallOpts)
}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_AddressManager *AddressManagerCaller) LastUnpausedAt(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _AddressManager.contract.Call(opts, &out, "lastUnpausedAt")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_AddressManager *AddressManagerSession) LastUnpausedAt() (uint64, error) {
	return _AddressManager.Contract.LastUnpausedAt(&_AddressManager.CallOpts)
}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_AddressManager *AddressManagerCallerSession) LastUnpausedAt() (uint64, error) {
	return _AddressManager.Contract.LastUnpausedAt(&_AddressManager.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_AddressManager *AddressManagerCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AddressManager.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_AddressManager *AddressManagerSession) Owner() (common.Address, error) {
	return _AddressManager.Contract.Owner(&_AddressManager.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_AddressManager *AddressManagerCallerSession) Owner() (common.Address, error) {
	return _AddressManager.Contract.Owner(&_AddressManager.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_AddressManager *AddressManagerCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _AddressManager.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_AddressManager *AddressManagerSession) Paused() (bool, error) {
	return _AddressManager.Contract.Paused(&_AddressManager.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_AddressManager *AddressManagerCallerSession) Paused() (bool, error) {
	return _AddressManager.Contract.Paused(&_AddressManager.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_AddressManager *AddressManagerCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AddressManager.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_AddressManager *AddressManagerSession) PendingOwner() (common.Address, error) {
	return _AddressManager.Contract.PendingOwner(&_AddressManager.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_AddressManager *AddressManagerCallerSession) PendingOwner() (common.Address, error) {
	return _AddressManager.Contract.PendingOwner(&_AddressManager.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_AddressManager *AddressManagerCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _AddressManager.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_AddressManager *AddressManagerSession) ProxiableUUID() ([32]byte, error) {
	return _AddressManager.Contract.ProxiableUUID(&_AddressManager.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_AddressManager *AddressManagerCallerSession) ProxiableUUID() ([32]byte, error) {
	return _AddressManager.Contract.ProxiableUUID(&_AddressManager.CallOpts)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_AddressManager *AddressManagerCaller) Resolve(opts *bind.CallOpts, _chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _AddressManager.contract.Call(opts, &out, "resolve", _chainId, _name, _allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_AddressManager *AddressManagerSession) Resolve(_chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _AddressManager.Contract.Resolve(&_AddressManager.CallOpts, _chainId, _name, _allowZeroAddress)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_AddressManager *AddressManagerCallerSession) Resolve(_chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _AddressManager.Contract.Resolve(&_AddressManager.CallOpts, _chainId, _name, _allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_AddressManager *AddressManagerCaller) Resolve0(opts *bind.CallOpts, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _AddressManager.contract.Call(opts, &out, "resolve0", _name, _allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_AddressManager *AddressManagerSession) Resolve0(_name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _AddressManager.Contract.Resolve0(&_AddressManager.CallOpts, _name, _allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_AddressManager *AddressManagerCallerSession) Resolve0(_name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _AddressManager.Contract.Resolve0(&_AddressManager.CallOpts, _name, _allowZeroAddress)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_AddressManager *AddressManagerTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AddressManager.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_AddressManager *AddressManagerSession) AcceptOwnership() (*types.Transaction, error) {
	return _AddressManager.Contract.AcceptOwnership(&_AddressManager.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_AddressManager *AddressManagerTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _AddressManager.Contract.AcceptOwnership(&_AddressManager.TransactOpts)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_AddressManager *AddressManagerTransactor) Init(opts *bind.TransactOpts, _owner common.Address) (*types.Transaction, error) {
	return _AddressManager.contract.Transact(opts, "init", _owner)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_AddressManager *AddressManagerSession) Init(_owner common.Address) (*types.Transaction, error) {
	return _AddressManager.Contract.Init(&_AddressManager.TransactOpts, _owner)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_AddressManager *AddressManagerTransactorSession) Init(_owner common.Address) (*types.Transaction, error) {
	return _AddressManager.Contract.Init(&_AddressManager.TransactOpts, _owner)
}

// Init2 is a paid mutator transaction binding the contract method 0x069489a2.
//
// Solidity: function init2() returns()
func (_AddressManager *AddressManagerTransactor) Init2(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AddressManager.contract.Transact(opts, "init2")
}

// Init2 is a paid mutator transaction binding the contract method 0x069489a2.
//
// Solidity: function init2() returns()
func (_AddressManager *AddressManagerSession) Init2() (*types.Transaction, error) {
	return _AddressManager.Contract.Init2(&_AddressManager.TransactOpts)
}

// Init2 is a paid mutator transaction binding the contract method 0x069489a2.
//
// Solidity: function init2() returns()
func (_AddressManager *AddressManagerTransactorSession) Init2() (*types.Transaction, error) {
	return _AddressManager.Contract.Init2(&_AddressManager.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_AddressManager *AddressManagerTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AddressManager.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_AddressManager *AddressManagerSession) Pause() (*types.Transaction, error) {
	return _AddressManager.Contract.Pause(&_AddressManager.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_AddressManager *AddressManagerTransactorSession) Pause() (*types.Transaction, error) {
	return _AddressManager.Contract.Pause(&_AddressManager.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_AddressManager *AddressManagerTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AddressManager.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_AddressManager *AddressManagerSession) RenounceOwnership() (*types.Transaction, error) {
	return _AddressManager.Contract.RenounceOwnership(&_AddressManager.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_AddressManager *AddressManagerTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _AddressManager.Contract.RenounceOwnership(&_AddressManager.TransactOpts)
}

// SetAddress is a paid mutator transaction binding the contract method 0xd8f4648f.
//
// Solidity: function setAddress(uint64 _chainId, bytes32 _name, address _newAddress) returns()
func (_AddressManager *AddressManagerTransactor) SetAddress(opts *bind.TransactOpts, _chainId uint64, _name [32]byte, _newAddress common.Address) (*types.Transaction, error) {
	return _AddressManager.contract.Transact(opts, "setAddress", _chainId, _name, _newAddress)
}

// SetAddress is a paid mutator transaction binding the contract method 0xd8f4648f.
//
// Solidity: function setAddress(uint64 _chainId, bytes32 _name, address _newAddress) returns()
func (_AddressManager *AddressManagerSession) SetAddress(_chainId uint64, _name [32]byte, _newAddress common.Address) (*types.Transaction, error) {
	return _AddressManager.Contract.SetAddress(&_AddressManager.TransactOpts, _chainId, _name, _newAddress)
}

// SetAddress is a paid mutator transaction binding the contract method 0xd8f4648f.
//
// Solidity: function setAddress(uint64 _chainId, bytes32 _name, address _newAddress) returns()
func (_AddressManager *AddressManagerTransactorSession) SetAddress(_chainId uint64, _name [32]byte, _newAddress common.Address) (*types.Transaction, error) {
	return _AddressManager.Contract.SetAddress(&_AddressManager.TransactOpts, _chainId, _name, _newAddress)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_AddressManager *AddressManagerTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _AddressManager.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_AddressManager *AddressManagerSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _AddressManager.Contract.TransferOwnership(&_AddressManager.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_AddressManager *AddressManagerTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _AddressManager.Contract.TransferOwnership(&_AddressManager.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_AddressManager *AddressManagerTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AddressManager.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_AddressManager *AddressManagerSession) Unpause() (*types.Transaction, error) {
	return _AddressManager.Contract.Unpause(&_AddressManager.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_AddressManager *AddressManagerTransactorSession) Unpause() (*types.Transaction, error) {
	return _AddressManager.Contract.Unpause(&_AddressManager.TransactOpts)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_AddressManager *AddressManagerTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _AddressManager.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_AddressManager *AddressManagerSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _AddressManager.Contract.UpgradeTo(&_AddressManager.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_AddressManager *AddressManagerTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _AddressManager.Contract.UpgradeTo(&_AddressManager.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_AddressManager *AddressManagerTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _AddressManager.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_AddressManager *AddressManagerSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _AddressManager.Contract.UpgradeToAndCall(&_AddressManager.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_AddressManager *AddressManagerTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _AddressManager.Contract.UpgradeToAndCall(&_AddressManager.TransactOpts, newImplementation, data)
}

// AddressManagerAddressSetIterator is returned from FilterAddressSet and is used to iterate over the raw logs and unpacked data for AddressSet events raised by the AddressManager contract.
type AddressManagerAddressSetIterator struct {
	Event *AddressManagerAddressSet // Event containing the contract specifics and raw log

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
func (it *AddressManagerAddressSetIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AddressManagerAddressSet)
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
		it.Event = new(AddressManagerAddressSet)
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
func (it *AddressManagerAddressSetIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AddressManagerAddressSetIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AddressManagerAddressSet represents a AddressSet event raised by the AddressManager contract.
type AddressManagerAddressSet struct {
	ChainId    uint64
	Name       [32]byte
	NewAddress common.Address
	OldAddress common.Address
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterAddressSet is a free log retrieval operation binding the contract event 0x500dcd607a98daece9bccc2511bf6032471252929de73caf507aae0e082f8453.
//
// Solidity: event AddressSet(uint64 indexed chainId, bytes32 indexed name, address newAddress, address oldAddress)
func (_AddressManager *AddressManagerFilterer) FilterAddressSet(opts *bind.FilterOpts, chainId []uint64, name [][32]byte) (*AddressManagerAddressSetIterator, error) {

	var chainIdRule []interface{}
	for _, chainIdItem := range chainId {
		chainIdRule = append(chainIdRule, chainIdItem)
	}
	var nameRule []interface{}
	for _, nameItem := range name {
		nameRule = append(nameRule, nameItem)
	}

	logs, sub, err := _AddressManager.contract.FilterLogs(opts, "AddressSet", chainIdRule, nameRule)
	if err != nil {
		return nil, err
	}
	return &AddressManagerAddressSetIterator{contract: _AddressManager.contract, event: "AddressSet", logs: logs, sub: sub}, nil
}

// WatchAddressSet is a free log subscription operation binding the contract event 0x500dcd607a98daece9bccc2511bf6032471252929de73caf507aae0e082f8453.
//
// Solidity: event AddressSet(uint64 indexed chainId, bytes32 indexed name, address newAddress, address oldAddress)
func (_AddressManager *AddressManagerFilterer) WatchAddressSet(opts *bind.WatchOpts, sink chan<- *AddressManagerAddressSet, chainId []uint64, name [][32]byte) (event.Subscription, error) {

	var chainIdRule []interface{}
	for _, chainIdItem := range chainId {
		chainIdRule = append(chainIdRule, chainIdItem)
	}
	var nameRule []interface{}
	for _, nameItem := range name {
		nameRule = append(nameRule, nameItem)
	}

	logs, sub, err := _AddressManager.contract.WatchLogs(opts, "AddressSet", chainIdRule, nameRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AddressManagerAddressSet)
				if err := _AddressManager.contract.UnpackLog(event, "AddressSet", log); err != nil {
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

// ParseAddressSet is a log parse operation binding the contract event 0x500dcd607a98daece9bccc2511bf6032471252929de73caf507aae0e082f8453.
//
// Solidity: event AddressSet(uint64 indexed chainId, bytes32 indexed name, address newAddress, address oldAddress)
func (_AddressManager *AddressManagerFilterer) ParseAddressSet(log types.Log) (*AddressManagerAddressSet, error) {
	event := new(AddressManagerAddressSet)
	if err := _AddressManager.contract.UnpackLog(event, "AddressSet", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AddressManagerAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the AddressManager contract.
type AddressManagerAdminChangedIterator struct {
	Event *AddressManagerAdminChanged // Event containing the contract specifics and raw log

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
func (it *AddressManagerAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AddressManagerAdminChanged)
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
		it.Event = new(AddressManagerAdminChanged)
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
func (it *AddressManagerAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AddressManagerAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AddressManagerAdminChanged represents a AdminChanged event raised by the AddressManager contract.
type AddressManagerAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_AddressManager *AddressManagerFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*AddressManagerAdminChangedIterator, error) {

	logs, sub, err := _AddressManager.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &AddressManagerAdminChangedIterator{contract: _AddressManager.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_AddressManager *AddressManagerFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *AddressManagerAdminChanged) (event.Subscription, error) {

	logs, sub, err := _AddressManager.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AddressManagerAdminChanged)
				if err := _AddressManager.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_AddressManager *AddressManagerFilterer) ParseAdminChanged(log types.Log) (*AddressManagerAdminChanged, error) {
	event := new(AddressManagerAdminChanged)
	if err := _AddressManager.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AddressManagerBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the AddressManager contract.
type AddressManagerBeaconUpgradedIterator struct {
	Event *AddressManagerBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *AddressManagerBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AddressManagerBeaconUpgraded)
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
		it.Event = new(AddressManagerBeaconUpgraded)
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
func (it *AddressManagerBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AddressManagerBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AddressManagerBeaconUpgraded represents a BeaconUpgraded event raised by the AddressManager contract.
type AddressManagerBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_AddressManager *AddressManagerFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*AddressManagerBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _AddressManager.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &AddressManagerBeaconUpgradedIterator{contract: _AddressManager.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_AddressManager *AddressManagerFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *AddressManagerBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _AddressManager.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AddressManagerBeaconUpgraded)
				if err := _AddressManager.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_AddressManager *AddressManagerFilterer) ParseBeaconUpgraded(log types.Log) (*AddressManagerBeaconUpgraded, error) {
	event := new(AddressManagerBeaconUpgraded)
	if err := _AddressManager.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AddressManagerInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the AddressManager contract.
type AddressManagerInitializedIterator struct {
	Event *AddressManagerInitialized // Event containing the contract specifics and raw log

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
func (it *AddressManagerInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AddressManagerInitialized)
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
		it.Event = new(AddressManagerInitialized)
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
func (it *AddressManagerInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AddressManagerInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AddressManagerInitialized represents a Initialized event raised by the AddressManager contract.
type AddressManagerInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_AddressManager *AddressManagerFilterer) FilterInitialized(opts *bind.FilterOpts) (*AddressManagerInitializedIterator, error) {

	logs, sub, err := _AddressManager.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &AddressManagerInitializedIterator{contract: _AddressManager.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_AddressManager *AddressManagerFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *AddressManagerInitialized) (event.Subscription, error) {

	logs, sub, err := _AddressManager.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AddressManagerInitialized)
				if err := _AddressManager.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_AddressManager *AddressManagerFilterer) ParseInitialized(log types.Log) (*AddressManagerInitialized, error) {
	event := new(AddressManagerInitialized)
	if err := _AddressManager.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AddressManagerOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the AddressManager contract.
type AddressManagerOwnershipTransferStartedIterator struct {
	Event *AddressManagerOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *AddressManagerOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AddressManagerOwnershipTransferStarted)
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
		it.Event = new(AddressManagerOwnershipTransferStarted)
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
func (it *AddressManagerOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AddressManagerOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AddressManagerOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the AddressManager contract.
type AddressManagerOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_AddressManager *AddressManagerFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*AddressManagerOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _AddressManager.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &AddressManagerOwnershipTransferStartedIterator{contract: _AddressManager.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_AddressManager *AddressManagerFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *AddressManagerOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _AddressManager.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AddressManagerOwnershipTransferStarted)
				if err := _AddressManager.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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
func (_AddressManager *AddressManagerFilterer) ParseOwnershipTransferStarted(log types.Log) (*AddressManagerOwnershipTransferStarted, error) {
	event := new(AddressManagerOwnershipTransferStarted)
	if err := _AddressManager.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AddressManagerOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the AddressManager contract.
type AddressManagerOwnershipTransferredIterator struct {
	Event *AddressManagerOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *AddressManagerOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AddressManagerOwnershipTransferred)
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
		it.Event = new(AddressManagerOwnershipTransferred)
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
func (it *AddressManagerOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AddressManagerOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AddressManagerOwnershipTransferred represents a OwnershipTransferred event raised by the AddressManager contract.
type AddressManagerOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_AddressManager *AddressManagerFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*AddressManagerOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _AddressManager.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &AddressManagerOwnershipTransferredIterator{contract: _AddressManager.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_AddressManager *AddressManagerFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *AddressManagerOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _AddressManager.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AddressManagerOwnershipTransferred)
				if err := _AddressManager.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_AddressManager *AddressManagerFilterer) ParseOwnershipTransferred(log types.Log) (*AddressManagerOwnershipTransferred, error) {
	event := new(AddressManagerOwnershipTransferred)
	if err := _AddressManager.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AddressManagerPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the AddressManager contract.
type AddressManagerPausedIterator struct {
	Event *AddressManagerPaused // Event containing the contract specifics and raw log

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
func (it *AddressManagerPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AddressManagerPaused)
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
		it.Event = new(AddressManagerPaused)
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
func (it *AddressManagerPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AddressManagerPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AddressManagerPaused represents a Paused event raised by the AddressManager contract.
type AddressManagerPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_AddressManager *AddressManagerFilterer) FilterPaused(opts *bind.FilterOpts) (*AddressManagerPausedIterator, error) {

	logs, sub, err := _AddressManager.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &AddressManagerPausedIterator{contract: _AddressManager.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_AddressManager *AddressManagerFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *AddressManagerPaused) (event.Subscription, error) {

	logs, sub, err := _AddressManager.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AddressManagerPaused)
				if err := _AddressManager.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_AddressManager *AddressManagerFilterer) ParsePaused(log types.Log) (*AddressManagerPaused, error) {
	event := new(AddressManagerPaused)
	if err := _AddressManager.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AddressManagerUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the AddressManager contract.
type AddressManagerUnpausedIterator struct {
	Event *AddressManagerUnpaused // Event containing the contract specifics and raw log

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
func (it *AddressManagerUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AddressManagerUnpaused)
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
		it.Event = new(AddressManagerUnpaused)
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
func (it *AddressManagerUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AddressManagerUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AddressManagerUnpaused represents a Unpaused event raised by the AddressManager contract.
type AddressManagerUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_AddressManager *AddressManagerFilterer) FilterUnpaused(opts *bind.FilterOpts) (*AddressManagerUnpausedIterator, error) {

	logs, sub, err := _AddressManager.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &AddressManagerUnpausedIterator{contract: _AddressManager.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_AddressManager *AddressManagerFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *AddressManagerUnpaused) (event.Subscription, error) {

	logs, sub, err := _AddressManager.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AddressManagerUnpaused)
				if err := _AddressManager.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_AddressManager *AddressManagerFilterer) ParseUnpaused(log types.Log) (*AddressManagerUnpaused, error) {
	event := new(AddressManagerUnpaused)
	if err := _AddressManager.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AddressManagerUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the AddressManager contract.
type AddressManagerUpgradedIterator struct {
	Event *AddressManagerUpgraded // Event containing the contract specifics and raw log

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
func (it *AddressManagerUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AddressManagerUpgraded)
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
		it.Event = new(AddressManagerUpgraded)
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
func (it *AddressManagerUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AddressManagerUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AddressManagerUpgraded represents a Upgraded event raised by the AddressManager contract.
type AddressManagerUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_AddressManager *AddressManagerFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*AddressManagerUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _AddressManager.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &AddressManagerUpgradedIterator{contract: _AddressManager.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_AddressManager *AddressManagerFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *AddressManagerUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _AddressManager.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AddressManagerUpgraded)
				if err := _AddressManager.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_AddressManager *AddressManagerFilterer) ParseUpgraded(log types.Log) (*AddressManagerUpgraded, error) {
	event := new(AddressManagerUpgraded)
	if err := _AddressManager.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
