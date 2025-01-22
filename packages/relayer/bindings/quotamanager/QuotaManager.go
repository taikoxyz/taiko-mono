// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package quotamanager

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

// QuotaManagerMetaData contains all meta data concerning the QuotaManager contract.
var QuotaManagerMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"addressManager\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"availableQuota\",\"inputs\":[{\"name\":\"_token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_leap\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"consumeQuota\",\"inputs\":[{\"name\":\"_token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"impl\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inNonReentrant\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_addressManager\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_quotaPeriod\",\"type\":\"uint24\",\"internalType\":\"uint24\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"lastUnpausedAt\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"quotaPeriod\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint24\",\"internalType\":\"uint24\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolve\",\"inputs\":[{\"name\":\"_chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_allowZeroAddress\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"addresspayable\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"resolve\",\"inputs\":[{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_allowZeroAddress\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"addresspayable\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"setQuotaPeriod\",\"inputs\":[{\"name\":\"_quotaPeriod\",\"type\":\"uint24\",\"internalType\":\"uint24\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"tokenQuota\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"updatedAt\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"quota\",\"type\":\"uint104\",\"internalType\":\"uint104\"},{\"name\":\"available\",\"type\":\"uint104\",\"internalType\":\"uint104\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"updateQuota\",\"inputs\":[{\"name\":\"_token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_quota\",\"type\":\"uint104\",\"internalType\":\"uint104\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"QuotaPeriodUpdated\",\"inputs\":[{\"name\":\"quotaPeriod\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"QuotaUpdated\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"oldQuota\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"newQuota\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"FUNC_NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"QM_INVALID_PARAM\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"QM_OUT_OF_QUOTA\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_INVALID_MANAGER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_UNEXPECTED_CHAINID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_ZERO_ADDR\",\"inputs\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_VALUE\",\"inputs\":[]}]",
}

// QuotaManagerABI is the input ABI used to generate the binding from.
// Deprecated: Use QuotaManagerMetaData.ABI instead.
var QuotaManagerABI = QuotaManagerMetaData.ABI

// QuotaManager is an auto generated Go binding around an Ethereum contract.
type QuotaManager struct {
	QuotaManagerCaller     // Read-only binding to the contract
	QuotaManagerTransactor // Write-only binding to the contract
	QuotaManagerFilterer   // Log filterer for contract events
}

// QuotaManagerCaller is an auto generated read-only Go binding around an Ethereum contract.
type QuotaManagerCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// QuotaManagerTransactor is an auto generated write-only Go binding around an Ethereum contract.
type QuotaManagerTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// QuotaManagerFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type QuotaManagerFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// QuotaManagerSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type QuotaManagerSession struct {
	Contract     *QuotaManager     // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// QuotaManagerCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type QuotaManagerCallerSession struct {
	Contract *QuotaManagerCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts       // Call options to use throughout this session
}

// QuotaManagerTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type QuotaManagerTransactorSession struct {
	Contract     *QuotaManagerTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts       // Transaction auth options to use throughout this session
}

// QuotaManagerRaw is an auto generated low-level Go binding around an Ethereum contract.
type QuotaManagerRaw struct {
	Contract *QuotaManager // Generic contract binding to access the raw methods on
}

// QuotaManagerCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type QuotaManagerCallerRaw struct {
	Contract *QuotaManagerCaller // Generic read-only contract binding to access the raw methods on
}

// QuotaManagerTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type QuotaManagerTransactorRaw struct {
	Contract *QuotaManagerTransactor // Generic write-only contract binding to access the raw methods on
}

// NewQuotaManager creates a new instance of QuotaManager, bound to a specific deployed contract.
func NewQuotaManager(address common.Address, backend bind.ContractBackend) (*QuotaManager, error) {
	contract, err := bindQuotaManager(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &QuotaManager{QuotaManagerCaller: QuotaManagerCaller{contract: contract}, QuotaManagerTransactor: QuotaManagerTransactor{contract: contract}, QuotaManagerFilterer: QuotaManagerFilterer{contract: contract}}, nil
}

// NewQuotaManagerCaller creates a new read-only instance of QuotaManager, bound to a specific deployed contract.
func NewQuotaManagerCaller(address common.Address, caller bind.ContractCaller) (*QuotaManagerCaller, error) {
	contract, err := bindQuotaManager(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &QuotaManagerCaller{contract: contract}, nil
}

// NewQuotaManagerTransactor creates a new write-only instance of QuotaManager, bound to a specific deployed contract.
func NewQuotaManagerTransactor(address common.Address, transactor bind.ContractTransactor) (*QuotaManagerTransactor, error) {
	contract, err := bindQuotaManager(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &QuotaManagerTransactor{contract: contract}, nil
}

// NewQuotaManagerFilterer creates a new log filterer instance of QuotaManager, bound to a specific deployed contract.
func NewQuotaManagerFilterer(address common.Address, filterer bind.ContractFilterer) (*QuotaManagerFilterer, error) {
	contract, err := bindQuotaManager(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &QuotaManagerFilterer{contract: contract}, nil
}

// bindQuotaManager binds a generic wrapper to an already deployed contract.
func bindQuotaManager(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := QuotaManagerMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_QuotaManager *QuotaManagerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _QuotaManager.Contract.QuotaManagerCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_QuotaManager *QuotaManagerRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _QuotaManager.Contract.QuotaManagerTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_QuotaManager *QuotaManagerRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _QuotaManager.Contract.QuotaManagerTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_QuotaManager *QuotaManagerCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _QuotaManager.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_QuotaManager *QuotaManagerTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _QuotaManager.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_QuotaManager *QuotaManagerTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _QuotaManager.Contract.contract.Transact(opts, method, params...)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_QuotaManager *QuotaManagerCaller) AddressManager(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _QuotaManager.contract.Call(opts, &out, "addressManager")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_QuotaManager *QuotaManagerSession) AddressManager() (common.Address, error) {
	return _QuotaManager.Contract.AddressManager(&_QuotaManager.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_QuotaManager *QuotaManagerCallerSession) AddressManager() (common.Address, error) {
	return _QuotaManager.Contract.AddressManager(&_QuotaManager.CallOpts)
}

// AvailableQuota is a free data retrieval call binding the contract method 0x105d9e6c.
//
// Solidity: function availableQuota(address _token, uint256 _leap) view returns(uint256)
func (_QuotaManager *QuotaManagerCaller) AvailableQuota(opts *bind.CallOpts, _token common.Address, _leap *big.Int) (*big.Int, error) {
	var out []interface{}
	err := _QuotaManager.contract.Call(opts, &out, "availableQuota", _token, _leap)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// AvailableQuota is a free data retrieval call binding the contract method 0x105d9e6c.
//
// Solidity: function availableQuota(address _token, uint256 _leap) view returns(uint256)
func (_QuotaManager *QuotaManagerSession) AvailableQuota(_token common.Address, _leap *big.Int) (*big.Int, error) {
	return _QuotaManager.Contract.AvailableQuota(&_QuotaManager.CallOpts, _token, _leap)
}

// AvailableQuota is a free data retrieval call binding the contract method 0x105d9e6c.
//
// Solidity: function availableQuota(address _token, uint256 _leap) view returns(uint256)
func (_QuotaManager *QuotaManagerCallerSession) AvailableQuota(_token common.Address, _leap *big.Int) (*big.Int, error) {
	return _QuotaManager.Contract.AvailableQuota(&_QuotaManager.CallOpts, _token, _leap)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_QuotaManager *QuotaManagerCaller) Impl(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _QuotaManager.contract.Call(opts, &out, "impl")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_QuotaManager *QuotaManagerSession) Impl() (common.Address, error) {
	return _QuotaManager.Contract.Impl(&_QuotaManager.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_QuotaManager *QuotaManagerCallerSession) Impl() (common.Address, error) {
	return _QuotaManager.Contract.Impl(&_QuotaManager.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_QuotaManager *QuotaManagerCaller) InNonReentrant(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _QuotaManager.contract.Call(opts, &out, "inNonReentrant")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_QuotaManager *QuotaManagerSession) InNonReentrant() (bool, error) {
	return _QuotaManager.Contract.InNonReentrant(&_QuotaManager.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_QuotaManager *QuotaManagerCallerSession) InNonReentrant() (bool, error) {
	return _QuotaManager.Contract.InNonReentrant(&_QuotaManager.CallOpts)
}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_QuotaManager *QuotaManagerCaller) LastUnpausedAt(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _QuotaManager.contract.Call(opts, &out, "lastUnpausedAt")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_QuotaManager *QuotaManagerSession) LastUnpausedAt() (uint64, error) {
	return _QuotaManager.Contract.LastUnpausedAt(&_QuotaManager.CallOpts)
}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_QuotaManager *QuotaManagerCallerSession) LastUnpausedAt() (uint64, error) {
	return _QuotaManager.Contract.LastUnpausedAt(&_QuotaManager.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_QuotaManager *QuotaManagerCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _QuotaManager.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_QuotaManager *QuotaManagerSession) Owner() (common.Address, error) {
	return _QuotaManager.Contract.Owner(&_QuotaManager.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_QuotaManager *QuotaManagerCallerSession) Owner() (common.Address, error) {
	return _QuotaManager.Contract.Owner(&_QuotaManager.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_QuotaManager *QuotaManagerCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _QuotaManager.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_QuotaManager *QuotaManagerSession) Paused() (bool, error) {
	return _QuotaManager.Contract.Paused(&_QuotaManager.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_QuotaManager *QuotaManagerCallerSession) Paused() (bool, error) {
	return _QuotaManager.Contract.Paused(&_QuotaManager.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_QuotaManager *QuotaManagerCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _QuotaManager.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_QuotaManager *QuotaManagerSession) PendingOwner() (common.Address, error) {
	return _QuotaManager.Contract.PendingOwner(&_QuotaManager.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_QuotaManager *QuotaManagerCallerSession) PendingOwner() (common.Address, error) {
	return _QuotaManager.Contract.PendingOwner(&_QuotaManager.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_QuotaManager *QuotaManagerCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _QuotaManager.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_QuotaManager *QuotaManagerSession) ProxiableUUID() ([32]byte, error) {
	return _QuotaManager.Contract.ProxiableUUID(&_QuotaManager.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_QuotaManager *QuotaManagerCallerSession) ProxiableUUID() ([32]byte, error) {
	return _QuotaManager.Contract.ProxiableUUID(&_QuotaManager.CallOpts)
}

// QuotaPeriod is a free data retrieval call binding the contract method 0xc3e3a590.
//
// Solidity: function quotaPeriod() view returns(uint24)
func (_QuotaManager *QuotaManagerCaller) QuotaPeriod(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _QuotaManager.contract.Call(opts, &out, "quotaPeriod")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// QuotaPeriod is a free data retrieval call binding the contract method 0xc3e3a590.
//
// Solidity: function quotaPeriod() view returns(uint24)
func (_QuotaManager *QuotaManagerSession) QuotaPeriod() (*big.Int, error) {
	return _QuotaManager.Contract.QuotaPeriod(&_QuotaManager.CallOpts)
}

// QuotaPeriod is a free data retrieval call binding the contract method 0xc3e3a590.
//
// Solidity: function quotaPeriod() view returns(uint24)
func (_QuotaManager *QuotaManagerCallerSession) QuotaPeriod() (*big.Int, error) {
	return _QuotaManager.Contract.QuotaPeriod(&_QuotaManager.CallOpts)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_QuotaManager *QuotaManagerCaller) Resolve(opts *bind.CallOpts, _chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _QuotaManager.contract.Call(opts, &out, "resolve", _chainId, _name, _allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_QuotaManager *QuotaManagerSession) Resolve(_chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _QuotaManager.Contract.Resolve(&_QuotaManager.CallOpts, _chainId, _name, _allowZeroAddress)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_QuotaManager *QuotaManagerCallerSession) Resolve(_chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _QuotaManager.Contract.Resolve(&_QuotaManager.CallOpts, _chainId, _name, _allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_QuotaManager *QuotaManagerCaller) Resolve0(opts *bind.CallOpts, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _QuotaManager.contract.Call(opts, &out, "resolve0", _name, _allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_QuotaManager *QuotaManagerSession) Resolve0(_name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _QuotaManager.Contract.Resolve0(&_QuotaManager.CallOpts, _name, _allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_QuotaManager *QuotaManagerCallerSession) Resolve0(_name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _QuotaManager.Contract.Resolve0(&_QuotaManager.CallOpts, _name, _allowZeroAddress)
}

// TokenQuota is a free data retrieval call binding the contract method 0x57839929.
//
// Solidity: function tokenQuota(address token) view returns(uint48 updatedAt, uint104 quota, uint104 available)
func (_QuotaManager *QuotaManagerCaller) TokenQuota(opts *bind.CallOpts, token common.Address) (struct {
	UpdatedAt *big.Int
	Quota     *big.Int
	Available *big.Int
}, error) {
	var out []interface{}
	err := _QuotaManager.contract.Call(opts, &out, "tokenQuota", token)

	outstruct := new(struct {
		UpdatedAt *big.Int
		Quota     *big.Int
		Available *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.UpdatedAt = *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	outstruct.Quota = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)
	outstruct.Available = *abi.ConvertType(out[2], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// TokenQuota is a free data retrieval call binding the contract method 0x57839929.
//
// Solidity: function tokenQuota(address token) view returns(uint48 updatedAt, uint104 quota, uint104 available)
func (_QuotaManager *QuotaManagerSession) TokenQuota(token common.Address) (struct {
	UpdatedAt *big.Int
	Quota     *big.Int
	Available *big.Int
}, error) {
	return _QuotaManager.Contract.TokenQuota(&_QuotaManager.CallOpts, token)
}

// TokenQuota is a free data retrieval call binding the contract method 0x57839929.
//
// Solidity: function tokenQuota(address token) view returns(uint48 updatedAt, uint104 quota, uint104 available)
func (_QuotaManager *QuotaManagerCallerSession) TokenQuota(token common.Address) (struct {
	UpdatedAt *big.Int
	Quota     *big.Int
	Available *big.Int
}, error) {
	return _QuotaManager.Contract.TokenQuota(&_QuotaManager.CallOpts, token)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_QuotaManager *QuotaManagerTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _QuotaManager.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_QuotaManager *QuotaManagerSession) AcceptOwnership() (*types.Transaction, error) {
	return _QuotaManager.Contract.AcceptOwnership(&_QuotaManager.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_QuotaManager *QuotaManagerTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _QuotaManager.Contract.AcceptOwnership(&_QuotaManager.TransactOpts)
}

// ConsumeQuota is a paid mutator transaction binding the contract method 0xae31c7d8.
//
// Solidity: function consumeQuota(address _token, uint256 _amount) returns()
func (_QuotaManager *QuotaManagerTransactor) ConsumeQuota(opts *bind.TransactOpts, _token common.Address, _amount *big.Int) (*types.Transaction, error) {
	return _QuotaManager.contract.Transact(opts, "consumeQuota", _token, _amount)
}

// ConsumeQuota is a paid mutator transaction binding the contract method 0xae31c7d8.
//
// Solidity: function consumeQuota(address _token, uint256 _amount) returns()
func (_QuotaManager *QuotaManagerSession) ConsumeQuota(_token common.Address, _amount *big.Int) (*types.Transaction, error) {
	return _QuotaManager.Contract.ConsumeQuota(&_QuotaManager.TransactOpts, _token, _amount)
}

// ConsumeQuota is a paid mutator transaction binding the contract method 0xae31c7d8.
//
// Solidity: function consumeQuota(address _token, uint256 _amount) returns()
func (_QuotaManager *QuotaManagerTransactorSession) ConsumeQuota(_token common.Address, _amount *big.Int) (*types.Transaction, error) {
	return _QuotaManager.Contract.ConsumeQuota(&_QuotaManager.TransactOpts, _token, _amount)
}

// Init is a paid mutator transaction binding the contract method 0x28b94164.
//
// Solidity: function init(address _owner, address _addressManager, uint24 _quotaPeriod) returns()
func (_QuotaManager *QuotaManagerTransactor) Init(opts *bind.TransactOpts, _owner common.Address, _addressManager common.Address, _quotaPeriod *big.Int) (*types.Transaction, error) {
	return _QuotaManager.contract.Transact(opts, "init", _owner, _addressManager, _quotaPeriod)
}

// Init is a paid mutator transaction binding the contract method 0x28b94164.
//
// Solidity: function init(address _owner, address _addressManager, uint24 _quotaPeriod) returns()
func (_QuotaManager *QuotaManagerSession) Init(_owner common.Address, _addressManager common.Address, _quotaPeriod *big.Int) (*types.Transaction, error) {
	return _QuotaManager.Contract.Init(&_QuotaManager.TransactOpts, _owner, _addressManager, _quotaPeriod)
}

// Init is a paid mutator transaction binding the contract method 0x28b94164.
//
// Solidity: function init(address _owner, address _addressManager, uint24 _quotaPeriod) returns()
func (_QuotaManager *QuotaManagerTransactorSession) Init(_owner common.Address, _addressManager common.Address, _quotaPeriod *big.Int) (*types.Transaction, error) {
	return _QuotaManager.Contract.Init(&_QuotaManager.TransactOpts, _owner, _addressManager, _quotaPeriod)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_QuotaManager *QuotaManagerTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _QuotaManager.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_QuotaManager *QuotaManagerSession) Pause() (*types.Transaction, error) {
	return _QuotaManager.Contract.Pause(&_QuotaManager.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_QuotaManager *QuotaManagerTransactorSession) Pause() (*types.Transaction, error) {
	return _QuotaManager.Contract.Pause(&_QuotaManager.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_QuotaManager *QuotaManagerTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _QuotaManager.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_QuotaManager *QuotaManagerSession) RenounceOwnership() (*types.Transaction, error) {
	return _QuotaManager.Contract.RenounceOwnership(&_QuotaManager.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_QuotaManager *QuotaManagerTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _QuotaManager.Contract.RenounceOwnership(&_QuotaManager.TransactOpts)
}

// SetQuotaPeriod is a paid mutator transaction binding the contract method 0xb91d1651.
//
// Solidity: function setQuotaPeriod(uint24 _quotaPeriod) returns()
func (_QuotaManager *QuotaManagerTransactor) SetQuotaPeriod(opts *bind.TransactOpts, _quotaPeriod *big.Int) (*types.Transaction, error) {
	return _QuotaManager.contract.Transact(opts, "setQuotaPeriod", _quotaPeriod)
}

// SetQuotaPeriod is a paid mutator transaction binding the contract method 0xb91d1651.
//
// Solidity: function setQuotaPeriod(uint24 _quotaPeriod) returns()
func (_QuotaManager *QuotaManagerSession) SetQuotaPeriod(_quotaPeriod *big.Int) (*types.Transaction, error) {
	return _QuotaManager.Contract.SetQuotaPeriod(&_QuotaManager.TransactOpts, _quotaPeriod)
}

// SetQuotaPeriod is a paid mutator transaction binding the contract method 0xb91d1651.
//
// Solidity: function setQuotaPeriod(uint24 _quotaPeriod) returns()
func (_QuotaManager *QuotaManagerTransactorSession) SetQuotaPeriod(_quotaPeriod *big.Int) (*types.Transaction, error) {
	return _QuotaManager.Contract.SetQuotaPeriod(&_QuotaManager.TransactOpts, _quotaPeriod)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_QuotaManager *QuotaManagerTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _QuotaManager.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_QuotaManager *QuotaManagerSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _QuotaManager.Contract.TransferOwnership(&_QuotaManager.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_QuotaManager *QuotaManagerTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _QuotaManager.Contract.TransferOwnership(&_QuotaManager.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_QuotaManager *QuotaManagerTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _QuotaManager.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_QuotaManager *QuotaManagerSession) Unpause() (*types.Transaction, error) {
	return _QuotaManager.Contract.Unpause(&_QuotaManager.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_QuotaManager *QuotaManagerTransactorSession) Unpause() (*types.Transaction, error) {
	return _QuotaManager.Contract.Unpause(&_QuotaManager.TransactOpts)
}

// UpdateQuota is a paid mutator transaction binding the contract method 0xeabbe47b.
//
// Solidity: function updateQuota(address _token, uint104 _quota) returns()
func (_QuotaManager *QuotaManagerTransactor) UpdateQuota(opts *bind.TransactOpts, _token common.Address, _quota *big.Int) (*types.Transaction, error) {
	return _QuotaManager.contract.Transact(opts, "updateQuota", _token, _quota)
}

// UpdateQuota is a paid mutator transaction binding the contract method 0xeabbe47b.
//
// Solidity: function updateQuota(address _token, uint104 _quota) returns()
func (_QuotaManager *QuotaManagerSession) UpdateQuota(_token common.Address, _quota *big.Int) (*types.Transaction, error) {
	return _QuotaManager.Contract.UpdateQuota(&_QuotaManager.TransactOpts, _token, _quota)
}

// UpdateQuota is a paid mutator transaction binding the contract method 0xeabbe47b.
//
// Solidity: function updateQuota(address _token, uint104 _quota) returns()
func (_QuotaManager *QuotaManagerTransactorSession) UpdateQuota(_token common.Address, _quota *big.Int) (*types.Transaction, error) {
	return _QuotaManager.Contract.UpdateQuota(&_QuotaManager.TransactOpts, _token, _quota)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_QuotaManager *QuotaManagerTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _QuotaManager.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_QuotaManager *QuotaManagerSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _QuotaManager.Contract.UpgradeTo(&_QuotaManager.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_QuotaManager *QuotaManagerTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _QuotaManager.Contract.UpgradeTo(&_QuotaManager.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_QuotaManager *QuotaManagerTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _QuotaManager.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_QuotaManager *QuotaManagerSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _QuotaManager.Contract.UpgradeToAndCall(&_QuotaManager.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_QuotaManager *QuotaManagerTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _QuotaManager.Contract.UpgradeToAndCall(&_QuotaManager.TransactOpts, newImplementation, data)
}

// QuotaManagerAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the QuotaManager contract.
type QuotaManagerAdminChangedIterator struct {
	Event *QuotaManagerAdminChanged // Event containing the contract specifics and raw log

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
func (it *QuotaManagerAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(QuotaManagerAdminChanged)
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
		it.Event = new(QuotaManagerAdminChanged)
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
func (it *QuotaManagerAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *QuotaManagerAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// QuotaManagerAdminChanged represents a AdminChanged event raised by the QuotaManager contract.
type QuotaManagerAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_QuotaManager *QuotaManagerFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*QuotaManagerAdminChangedIterator, error) {

	logs, sub, err := _QuotaManager.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &QuotaManagerAdminChangedIterator{contract: _QuotaManager.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_QuotaManager *QuotaManagerFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *QuotaManagerAdminChanged) (event.Subscription, error) {

	logs, sub, err := _QuotaManager.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(QuotaManagerAdminChanged)
				if err := _QuotaManager.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_QuotaManager *QuotaManagerFilterer) ParseAdminChanged(log types.Log) (*QuotaManagerAdminChanged, error) {
	event := new(QuotaManagerAdminChanged)
	if err := _QuotaManager.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// QuotaManagerBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the QuotaManager contract.
type QuotaManagerBeaconUpgradedIterator struct {
	Event *QuotaManagerBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *QuotaManagerBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(QuotaManagerBeaconUpgraded)
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
		it.Event = new(QuotaManagerBeaconUpgraded)
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
func (it *QuotaManagerBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *QuotaManagerBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// QuotaManagerBeaconUpgraded represents a BeaconUpgraded event raised by the QuotaManager contract.
type QuotaManagerBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_QuotaManager *QuotaManagerFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*QuotaManagerBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _QuotaManager.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &QuotaManagerBeaconUpgradedIterator{contract: _QuotaManager.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_QuotaManager *QuotaManagerFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *QuotaManagerBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _QuotaManager.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(QuotaManagerBeaconUpgraded)
				if err := _QuotaManager.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_QuotaManager *QuotaManagerFilterer) ParseBeaconUpgraded(log types.Log) (*QuotaManagerBeaconUpgraded, error) {
	event := new(QuotaManagerBeaconUpgraded)
	if err := _QuotaManager.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// QuotaManagerInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the QuotaManager contract.
type QuotaManagerInitializedIterator struct {
	Event *QuotaManagerInitialized // Event containing the contract specifics and raw log

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
func (it *QuotaManagerInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(QuotaManagerInitialized)
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
		it.Event = new(QuotaManagerInitialized)
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
func (it *QuotaManagerInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *QuotaManagerInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// QuotaManagerInitialized represents a Initialized event raised by the QuotaManager contract.
type QuotaManagerInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_QuotaManager *QuotaManagerFilterer) FilterInitialized(opts *bind.FilterOpts) (*QuotaManagerInitializedIterator, error) {

	logs, sub, err := _QuotaManager.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &QuotaManagerInitializedIterator{contract: _QuotaManager.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_QuotaManager *QuotaManagerFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *QuotaManagerInitialized) (event.Subscription, error) {

	logs, sub, err := _QuotaManager.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(QuotaManagerInitialized)
				if err := _QuotaManager.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_QuotaManager *QuotaManagerFilterer) ParseInitialized(log types.Log) (*QuotaManagerInitialized, error) {
	event := new(QuotaManagerInitialized)
	if err := _QuotaManager.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// QuotaManagerOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the QuotaManager contract.
type QuotaManagerOwnershipTransferStartedIterator struct {
	Event *QuotaManagerOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *QuotaManagerOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(QuotaManagerOwnershipTransferStarted)
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
		it.Event = new(QuotaManagerOwnershipTransferStarted)
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
func (it *QuotaManagerOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *QuotaManagerOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// QuotaManagerOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the QuotaManager contract.
type QuotaManagerOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_QuotaManager *QuotaManagerFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*QuotaManagerOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _QuotaManager.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &QuotaManagerOwnershipTransferStartedIterator{contract: _QuotaManager.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_QuotaManager *QuotaManagerFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *QuotaManagerOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _QuotaManager.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(QuotaManagerOwnershipTransferStarted)
				if err := _QuotaManager.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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
func (_QuotaManager *QuotaManagerFilterer) ParseOwnershipTransferStarted(log types.Log) (*QuotaManagerOwnershipTransferStarted, error) {
	event := new(QuotaManagerOwnershipTransferStarted)
	if err := _QuotaManager.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// QuotaManagerOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the QuotaManager contract.
type QuotaManagerOwnershipTransferredIterator struct {
	Event *QuotaManagerOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *QuotaManagerOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(QuotaManagerOwnershipTransferred)
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
		it.Event = new(QuotaManagerOwnershipTransferred)
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
func (it *QuotaManagerOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *QuotaManagerOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// QuotaManagerOwnershipTransferred represents a OwnershipTransferred event raised by the QuotaManager contract.
type QuotaManagerOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_QuotaManager *QuotaManagerFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*QuotaManagerOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _QuotaManager.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &QuotaManagerOwnershipTransferredIterator{contract: _QuotaManager.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_QuotaManager *QuotaManagerFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *QuotaManagerOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _QuotaManager.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(QuotaManagerOwnershipTransferred)
				if err := _QuotaManager.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_QuotaManager *QuotaManagerFilterer) ParseOwnershipTransferred(log types.Log) (*QuotaManagerOwnershipTransferred, error) {
	event := new(QuotaManagerOwnershipTransferred)
	if err := _QuotaManager.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// QuotaManagerPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the QuotaManager contract.
type QuotaManagerPausedIterator struct {
	Event *QuotaManagerPaused // Event containing the contract specifics and raw log

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
func (it *QuotaManagerPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(QuotaManagerPaused)
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
		it.Event = new(QuotaManagerPaused)
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
func (it *QuotaManagerPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *QuotaManagerPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// QuotaManagerPaused represents a Paused event raised by the QuotaManager contract.
type QuotaManagerPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_QuotaManager *QuotaManagerFilterer) FilterPaused(opts *bind.FilterOpts) (*QuotaManagerPausedIterator, error) {

	logs, sub, err := _QuotaManager.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &QuotaManagerPausedIterator{contract: _QuotaManager.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_QuotaManager *QuotaManagerFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *QuotaManagerPaused) (event.Subscription, error) {

	logs, sub, err := _QuotaManager.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(QuotaManagerPaused)
				if err := _QuotaManager.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_QuotaManager *QuotaManagerFilterer) ParsePaused(log types.Log) (*QuotaManagerPaused, error) {
	event := new(QuotaManagerPaused)
	if err := _QuotaManager.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// QuotaManagerQuotaPeriodUpdatedIterator is returned from FilterQuotaPeriodUpdated and is used to iterate over the raw logs and unpacked data for QuotaPeriodUpdated events raised by the QuotaManager contract.
type QuotaManagerQuotaPeriodUpdatedIterator struct {
	Event *QuotaManagerQuotaPeriodUpdated // Event containing the contract specifics and raw log

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
func (it *QuotaManagerQuotaPeriodUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(QuotaManagerQuotaPeriodUpdated)
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
		it.Event = new(QuotaManagerQuotaPeriodUpdated)
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
func (it *QuotaManagerQuotaPeriodUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *QuotaManagerQuotaPeriodUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// QuotaManagerQuotaPeriodUpdated represents a QuotaPeriodUpdated event raised by the QuotaManager contract.
type QuotaManagerQuotaPeriodUpdated struct {
	QuotaPeriod *big.Int
	Raw         types.Log // Blockchain specific contextual infos
}

// FilterQuotaPeriodUpdated is a free log retrieval operation binding the contract event 0x714cf57ffe172b008fcbb807b801535a5edc28672cff603865d82fc2708287ba.
//
// Solidity: event QuotaPeriodUpdated(uint256 quotaPeriod)
func (_QuotaManager *QuotaManagerFilterer) FilterQuotaPeriodUpdated(opts *bind.FilterOpts) (*QuotaManagerQuotaPeriodUpdatedIterator, error) {

	logs, sub, err := _QuotaManager.contract.FilterLogs(opts, "QuotaPeriodUpdated")
	if err != nil {
		return nil, err
	}
	return &QuotaManagerQuotaPeriodUpdatedIterator{contract: _QuotaManager.contract, event: "QuotaPeriodUpdated", logs: logs, sub: sub}, nil
}

// WatchQuotaPeriodUpdated is a free log subscription operation binding the contract event 0x714cf57ffe172b008fcbb807b801535a5edc28672cff603865d82fc2708287ba.
//
// Solidity: event QuotaPeriodUpdated(uint256 quotaPeriod)
func (_QuotaManager *QuotaManagerFilterer) WatchQuotaPeriodUpdated(opts *bind.WatchOpts, sink chan<- *QuotaManagerQuotaPeriodUpdated) (event.Subscription, error) {

	logs, sub, err := _QuotaManager.contract.WatchLogs(opts, "QuotaPeriodUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(QuotaManagerQuotaPeriodUpdated)
				if err := _QuotaManager.contract.UnpackLog(event, "QuotaPeriodUpdated", log); err != nil {
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

// ParseQuotaPeriodUpdated is a log parse operation binding the contract event 0x714cf57ffe172b008fcbb807b801535a5edc28672cff603865d82fc2708287ba.
//
// Solidity: event QuotaPeriodUpdated(uint256 quotaPeriod)
func (_QuotaManager *QuotaManagerFilterer) ParseQuotaPeriodUpdated(log types.Log) (*QuotaManagerQuotaPeriodUpdated, error) {
	event := new(QuotaManagerQuotaPeriodUpdated)
	if err := _QuotaManager.contract.UnpackLog(event, "QuotaPeriodUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// QuotaManagerQuotaUpdatedIterator is returned from FilterQuotaUpdated and is used to iterate over the raw logs and unpacked data for QuotaUpdated events raised by the QuotaManager contract.
type QuotaManagerQuotaUpdatedIterator struct {
	Event *QuotaManagerQuotaUpdated // Event containing the contract specifics and raw log

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
func (it *QuotaManagerQuotaUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(QuotaManagerQuotaUpdated)
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
		it.Event = new(QuotaManagerQuotaUpdated)
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
func (it *QuotaManagerQuotaUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *QuotaManagerQuotaUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// QuotaManagerQuotaUpdated represents a QuotaUpdated event raised by the QuotaManager contract.
type QuotaManagerQuotaUpdated struct {
	Token    common.Address
	OldQuota *big.Int
	NewQuota *big.Int
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterQuotaUpdated is a free log retrieval operation binding the contract event 0xc1879fe680552d3452890fc07618b28ab4a629c2abf665db5837c367c6dd5ede.
//
// Solidity: event QuotaUpdated(address indexed token, uint256 oldQuota, uint256 newQuota)
func (_QuotaManager *QuotaManagerFilterer) FilterQuotaUpdated(opts *bind.FilterOpts, token []common.Address) (*QuotaManagerQuotaUpdatedIterator, error) {

	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _QuotaManager.contract.FilterLogs(opts, "QuotaUpdated", tokenRule)
	if err != nil {
		return nil, err
	}
	return &QuotaManagerQuotaUpdatedIterator{contract: _QuotaManager.contract, event: "QuotaUpdated", logs: logs, sub: sub}, nil
}

// WatchQuotaUpdated is a free log subscription operation binding the contract event 0xc1879fe680552d3452890fc07618b28ab4a629c2abf665db5837c367c6dd5ede.
//
// Solidity: event QuotaUpdated(address indexed token, uint256 oldQuota, uint256 newQuota)
func (_QuotaManager *QuotaManagerFilterer) WatchQuotaUpdated(opts *bind.WatchOpts, sink chan<- *QuotaManagerQuotaUpdated, token []common.Address) (event.Subscription, error) {

	var tokenRule []interface{}
	for _, tokenItem := range token {
		tokenRule = append(tokenRule, tokenItem)
	}

	logs, sub, err := _QuotaManager.contract.WatchLogs(opts, "QuotaUpdated", tokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(QuotaManagerQuotaUpdated)
				if err := _QuotaManager.contract.UnpackLog(event, "QuotaUpdated", log); err != nil {
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

// ParseQuotaUpdated is a log parse operation binding the contract event 0xc1879fe680552d3452890fc07618b28ab4a629c2abf665db5837c367c6dd5ede.
//
// Solidity: event QuotaUpdated(address indexed token, uint256 oldQuota, uint256 newQuota)
func (_QuotaManager *QuotaManagerFilterer) ParseQuotaUpdated(log types.Log) (*QuotaManagerQuotaUpdated, error) {
	event := new(QuotaManagerQuotaUpdated)
	if err := _QuotaManager.contract.UnpackLog(event, "QuotaUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// QuotaManagerUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the QuotaManager contract.
type QuotaManagerUnpausedIterator struct {
	Event *QuotaManagerUnpaused // Event containing the contract specifics and raw log

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
func (it *QuotaManagerUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(QuotaManagerUnpaused)
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
		it.Event = new(QuotaManagerUnpaused)
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
func (it *QuotaManagerUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *QuotaManagerUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// QuotaManagerUnpaused represents a Unpaused event raised by the QuotaManager contract.
type QuotaManagerUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_QuotaManager *QuotaManagerFilterer) FilterUnpaused(opts *bind.FilterOpts) (*QuotaManagerUnpausedIterator, error) {

	logs, sub, err := _QuotaManager.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &QuotaManagerUnpausedIterator{contract: _QuotaManager.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_QuotaManager *QuotaManagerFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *QuotaManagerUnpaused) (event.Subscription, error) {

	logs, sub, err := _QuotaManager.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(QuotaManagerUnpaused)
				if err := _QuotaManager.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_QuotaManager *QuotaManagerFilterer) ParseUnpaused(log types.Log) (*QuotaManagerUnpaused, error) {
	event := new(QuotaManagerUnpaused)
	if err := _QuotaManager.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// QuotaManagerUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the QuotaManager contract.
type QuotaManagerUpgradedIterator struct {
	Event *QuotaManagerUpgraded // Event containing the contract specifics and raw log

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
func (it *QuotaManagerUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(QuotaManagerUpgraded)
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
		it.Event = new(QuotaManagerUpgraded)
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
func (it *QuotaManagerUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *QuotaManagerUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// QuotaManagerUpgraded represents a Upgraded event raised by the QuotaManager contract.
type QuotaManagerUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_QuotaManager *QuotaManagerFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*QuotaManagerUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _QuotaManager.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &QuotaManagerUpgradedIterator{contract: _QuotaManager.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_QuotaManager *QuotaManagerFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *QuotaManagerUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _QuotaManager.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(QuotaManagerUpgraded)
				if err := _QuotaManager.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_QuotaManager *QuotaManagerFilterer) ParseUpgraded(log types.Log) (*QuotaManagerUpgraded, error) {
	event := new(QuotaManagerUpgraded)
	if err := _QuotaManager.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
