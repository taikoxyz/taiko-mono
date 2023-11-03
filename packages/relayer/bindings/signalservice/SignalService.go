// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package signalservice

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

// SignalServiceMetaData contains all meta data concerning the SignalService contract.
var SignalServiceMetaData = &bind.MetaData{
	ABI: "[{\"inputs\":[],\"name\":\"ADDRESS_UNAUTHORIZED\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"INVALID_ADDRESS\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"INVALID_LABEL\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"INVALID_PAUSE_STATUS\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"REENTRANT_CALL\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"RESOLVER_DENIED\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"RESOLVER_INVALID_MANAGER\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"RESOLVER_UNEXPECTED_CHAINID\",\"type\":\"error\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"chainId\",\"type\":\"uint64\"},{\"internalType\":\"string\",\"name\":\"name\",\"type\":\"string\"}],\"name\":\"RESOLVER_ZERO_ADDR\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"SS_INVALID_APP\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"SS_INVALID_SIGNAL\",\"type\":\"error\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"addr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"oldLabel\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"newLabel\",\"type\":\"bytes32\"}],\"name\":\"Authorized\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint8\",\"name\":\"version\",\"type\":\"uint8\"}],\"name\":\"Initialized\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"previousOwner\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"OwnershipTransferStarted\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"previousOwner\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"OwnershipTransferred\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"account\",\"type\":\"address\"}],\"name\":\"Paused\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"account\",\"type\":\"address\"}],\"name\":\"Unpaused\",\"type\":\"event\"},{\"inputs\":[],\"name\":\"acceptOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"addressManager\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"addr\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"label\",\"type\":\"bytes32\"}],\"name\":\"authorize\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"name\":\"authorizedAddresses\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"label\",\"type\":\"bytes32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"chainId\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"app\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"signal\",\"type\":\"bytes32\"}],\"name\":\"getSignalSlot\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"pure\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"init\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"addr\",\"type\":\"address\"}],\"name\":\"isAuthorized\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"addr\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"label\",\"type\":\"bytes32\"}],\"name\":\"isAuthorizedAs\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"app\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"signal\",\"type\":\"bytes32\"}],\"name\":\"isSignalSent\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"owner\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"pause\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"paused\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"pendingOwner\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"srcChainId\",\"type\":\"uint64\"},{\"internalType\":\"address\",\"name\":\"app\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"signal\",\"type\":\"bytes32\"},{\"internalType\":\"bytes\",\"name\":\"proof\",\"type\":\"bytes\"}],\"name\":\"proveSignalReceived\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"renounceOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"chainId\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"name\",\"type\":\"bytes32\"},{\"internalType\":\"bool\",\"name\":\"allowZeroAddress\",\"type\":\"bool\"}],\"name\":\"resolve\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"addr\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"name\",\"type\":\"bytes32\"},{\"internalType\":\"bool\",\"name\":\"allowZeroAddress\",\"type\":\"bool\"}],\"name\":\"resolve\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"addr\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"signal\",\"type\":\"bytes32\"}],\"name\":\"sendSignal\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"slot\",\"type\":\"bytes32\"}],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"skipProofCheck\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"pure\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"transferOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"unpause\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"}]",
}

// SignalServiceABI is the input ABI used to generate the binding from.
// Deprecated: Use SignalServiceMetaData.ABI instead.
var SignalServiceABI = SignalServiceMetaData.ABI

// SignalService is an auto generated Go binding around an Ethereum contract.
type SignalService struct {
	SignalServiceCaller     // Read-only binding to the contract
	SignalServiceTransactor // Write-only binding to the contract
	SignalServiceFilterer   // Log filterer for contract events
}

// SignalServiceCaller is an auto generated read-only Go binding around an Ethereum contract.
type SignalServiceCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SignalServiceTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SignalServiceTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SignalServiceFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SignalServiceFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SignalServiceSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SignalServiceSession struct {
	Contract     *SignalService    // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// SignalServiceCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SignalServiceCallerSession struct {
	Contract *SignalServiceCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts        // Call options to use throughout this session
}

// SignalServiceTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SignalServiceTransactorSession struct {
	Contract     *SignalServiceTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts        // Transaction auth options to use throughout this session
}

// SignalServiceRaw is an auto generated low-level Go binding around an Ethereum contract.
type SignalServiceRaw struct {
	Contract *SignalService // Generic contract binding to access the raw methods on
}

// SignalServiceCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SignalServiceCallerRaw struct {
	Contract *SignalServiceCaller // Generic read-only contract binding to access the raw methods on
}

// SignalServiceTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SignalServiceTransactorRaw struct {
	Contract *SignalServiceTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSignalService creates a new instance of SignalService, bound to a specific deployed contract.
func NewSignalService(address common.Address, backend bind.ContractBackend) (*SignalService, error) {
	contract, err := bindSignalService(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SignalService{SignalServiceCaller: SignalServiceCaller{contract: contract}, SignalServiceTransactor: SignalServiceTransactor{contract: contract}, SignalServiceFilterer: SignalServiceFilterer{contract: contract}}, nil
}

// NewSignalServiceCaller creates a new read-only instance of SignalService, bound to a specific deployed contract.
func NewSignalServiceCaller(address common.Address, caller bind.ContractCaller) (*SignalServiceCaller, error) {
	contract, err := bindSignalService(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SignalServiceCaller{contract: contract}, nil
}

// NewSignalServiceTransactor creates a new write-only instance of SignalService, bound to a specific deployed contract.
func NewSignalServiceTransactor(address common.Address, transactor bind.ContractTransactor) (*SignalServiceTransactor, error) {
	contract, err := bindSignalService(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SignalServiceTransactor{contract: contract}, nil
}

// NewSignalServiceFilterer creates a new log filterer instance of SignalService, bound to a specific deployed contract.
func NewSignalServiceFilterer(address common.Address, filterer bind.ContractFilterer) (*SignalServiceFilterer, error) {
	contract, err := bindSignalService(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SignalServiceFilterer{contract: contract}, nil
}

// bindSignalService binds a generic wrapper to an already deployed contract.
func bindSignalService(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SignalServiceMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SignalService *SignalServiceRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SignalService.Contract.SignalServiceCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SignalService *SignalServiceRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SignalService.Contract.SignalServiceTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SignalService *SignalServiceRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SignalService.Contract.SignalServiceTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SignalService *SignalServiceCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SignalService.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SignalService *SignalServiceTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SignalService.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SignalService *SignalServiceTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SignalService.Contract.contract.Transact(opts, method, params...)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_SignalService *SignalServiceCaller) AddressManager(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SignalService.contract.Call(opts, &out, "addressManager")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_SignalService *SignalServiceSession) AddressManager() (common.Address, error) {
	return _SignalService.Contract.AddressManager(&_SignalService.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_SignalService *SignalServiceCallerSession) AddressManager() (common.Address, error) {
	return _SignalService.Contract.AddressManager(&_SignalService.CallOpts)
}

// AuthorizedAddresses is a free data retrieval call binding the contract method 0xf19e207e.
//
// Solidity: function authorizedAddresses(address ) view returns(bytes32 label)
func (_SignalService *SignalServiceCaller) AuthorizedAddresses(opts *bind.CallOpts, arg0 common.Address) ([32]byte, error) {
	var out []interface{}
	err := _SignalService.contract.Call(opts, &out, "authorizedAddresses", arg0)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// AuthorizedAddresses is a free data retrieval call binding the contract method 0xf19e207e.
//
// Solidity: function authorizedAddresses(address ) view returns(bytes32 label)
func (_SignalService *SignalServiceSession) AuthorizedAddresses(arg0 common.Address) ([32]byte, error) {
	return _SignalService.Contract.AuthorizedAddresses(&_SignalService.CallOpts, arg0)
}

// AuthorizedAddresses is a free data retrieval call binding the contract method 0xf19e207e.
//
// Solidity: function authorizedAddresses(address ) view returns(bytes32 label)
func (_SignalService *SignalServiceCallerSession) AuthorizedAddresses(arg0 common.Address) ([32]byte, error) {
	return _SignalService.Contract.AuthorizedAddresses(&_SignalService.CallOpts, arg0)
}

// GetSignalSlot is a free data retrieval call binding the contract method 0x91f3f74b.
//
// Solidity: function getSignalSlot(uint64 chainId, address app, bytes32 signal) pure returns(bytes32)
func (_SignalService *SignalServiceCaller) GetSignalSlot(opts *bind.CallOpts, chainId uint64, app common.Address, signal [32]byte) ([32]byte, error) {
	var out []interface{}
	err := _SignalService.contract.Call(opts, &out, "getSignalSlot", chainId, app, signal)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetSignalSlot is a free data retrieval call binding the contract method 0x91f3f74b.
//
// Solidity: function getSignalSlot(uint64 chainId, address app, bytes32 signal) pure returns(bytes32)
func (_SignalService *SignalServiceSession) GetSignalSlot(chainId uint64, app common.Address, signal [32]byte) ([32]byte, error) {
	return _SignalService.Contract.GetSignalSlot(&_SignalService.CallOpts, chainId, app, signal)
}

// GetSignalSlot is a free data retrieval call binding the contract method 0x91f3f74b.
//
// Solidity: function getSignalSlot(uint64 chainId, address app, bytes32 signal) pure returns(bytes32)
func (_SignalService *SignalServiceCallerSession) GetSignalSlot(chainId uint64, app common.Address, signal [32]byte) ([32]byte, error) {
	return _SignalService.Contract.GetSignalSlot(&_SignalService.CallOpts, chainId, app, signal)
}

// IsAuthorized is a free data retrieval call binding the contract method 0xfe9fbb80.
//
// Solidity: function isAuthorized(address addr) view returns(bool)
func (_SignalService *SignalServiceCaller) IsAuthorized(opts *bind.CallOpts, addr common.Address) (bool, error) {
	var out []interface{}
	err := _SignalService.contract.Call(opts, &out, "isAuthorized", addr)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsAuthorized is a free data retrieval call binding the contract method 0xfe9fbb80.
//
// Solidity: function isAuthorized(address addr) view returns(bool)
func (_SignalService *SignalServiceSession) IsAuthorized(addr common.Address) (bool, error) {
	return _SignalService.Contract.IsAuthorized(&_SignalService.CallOpts, addr)
}

// IsAuthorized is a free data retrieval call binding the contract method 0xfe9fbb80.
//
// Solidity: function isAuthorized(address addr) view returns(bool)
func (_SignalService *SignalServiceCallerSession) IsAuthorized(addr common.Address) (bool, error) {
	return _SignalService.Contract.IsAuthorized(&_SignalService.CallOpts, addr)
}

// IsAuthorizedAs is a free data retrieval call binding the contract method 0xa354b9de.
//
// Solidity: function isAuthorizedAs(address addr, bytes32 label) view returns(bool)
func (_SignalService *SignalServiceCaller) IsAuthorizedAs(opts *bind.CallOpts, addr common.Address, label [32]byte) (bool, error) {
	var out []interface{}
	err := _SignalService.contract.Call(opts, &out, "isAuthorizedAs", addr, label)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsAuthorizedAs is a free data retrieval call binding the contract method 0xa354b9de.
//
// Solidity: function isAuthorizedAs(address addr, bytes32 label) view returns(bool)
func (_SignalService *SignalServiceSession) IsAuthorizedAs(addr common.Address, label [32]byte) (bool, error) {
	return _SignalService.Contract.IsAuthorizedAs(&_SignalService.CallOpts, addr, label)
}

// IsAuthorizedAs is a free data retrieval call binding the contract method 0xa354b9de.
//
// Solidity: function isAuthorizedAs(address addr, bytes32 label) view returns(bool)
func (_SignalService *SignalServiceCallerSession) IsAuthorizedAs(addr common.Address, label [32]byte) (bool, error) {
	return _SignalService.Contract.IsAuthorizedAs(&_SignalService.CallOpts, addr, label)
}

// IsSignalSent is a free data retrieval call binding the contract method 0x32676bc6.
//
// Solidity: function isSignalSent(address app, bytes32 signal) view returns(bool)
func (_SignalService *SignalServiceCaller) IsSignalSent(opts *bind.CallOpts, app common.Address, signal [32]byte) (bool, error) {
	var out []interface{}
	err := _SignalService.contract.Call(opts, &out, "isSignalSent", app, signal)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsSignalSent is a free data retrieval call binding the contract method 0x32676bc6.
//
// Solidity: function isSignalSent(address app, bytes32 signal) view returns(bool)
func (_SignalService *SignalServiceSession) IsSignalSent(app common.Address, signal [32]byte) (bool, error) {
	return _SignalService.Contract.IsSignalSent(&_SignalService.CallOpts, app, signal)
}

// IsSignalSent is a free data retrieval call binding the contract method 0x32676bc6.
//
// Solidity: function isSignalSent(address app, bytes32 signal) view returns(bool)
func (_SignalService *SignalServiceCallerSession) IsSignalSent(app common.Address, signal [32]byte) (bool, error) {
	return _SignalService.Contract.IsSignalSent(&_SignalService.CallOpts, app, signal)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_SignalService *SignalServiceCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SignalService.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_SignalService *SignalServiceSession) Owner() (common.Address, error) {
	return _SignalService.Contract.Owner(&_SignalService.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_SignalService *SignalServiceCallerSession) Owner() (common.Address, error) {
	return _SignalService.Contract.Owner(&_SignalService.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_SignalService *SignalServiceCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _SignalService.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_SignalService *SignalServiceSession) Paused() (bool, error) {
	return _SignalService.Contract.Paused(&_SignalService.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_SignalService *SignalServiceCallerSession) Paused() (bool, error) {
	return _SignalService.Contract.Paused(&_SignalService.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_SignalService *SignalServiceCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SignalService.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_SignalService *SignalServiceSession) PendingOwner() (common.Address, error) {
	return _SignalService.Contract.PendingOwner(&_SignalService.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_SignalService *SignalServiceCallerSession) PendingOwner() (common.Address, error) {
	return _SignalService.Contract.PendingOwner(&_SignalService.CallOpts)
}

// ProveSignalReceived is a free data retrieval call binding the contract method 0x910af6ed.
//
// Solidity: function proveSignalReceived(uint64 srcChainId, address app, bytes32 signal, bytes proof) view returns(bool)
func (_SignalService *SignalServiceCaller) ProveSignalReceived(opts *bind.CallOpts, srcChainId uint64, app common.Address, signal [32]byte, proof []byte) (bool, error) {
	var out []interface{}
	err := _SignalService.contract.Call(opts, &out, "proveSignalReceived", srcChainId, app, signal, proof)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// ProveSignalReceived is a free data retrieval call binding the contract method 0x910af6ed.
//
// Solidity: function proveSignalReceived(uint64 srcChainId, address app, bytes32 signal, bytes proof) view returns(bool)
func (_SignalService *SignalServiceSession) ProveSignalReceived(srcChainId uint64, app common.Address, signal [32]byte, proof []byte) (bool, error) {
	return _SignalService.Contract.ProveSignalReceived(&_SignalService.CallOpts, srcChainId, app, signal, proof)
}

// ProveSignalReceived is a free data retrieval call binding the contract method 0x910af6ed.
//
// Solidity: function proveSignalReceived(uint64 srcChainId, address app, bytes32 signal, bytes proof) view returns(bool)
func (_SignalService *SignalServiceCallerSession) ProveSignalReceived(srcChainId uint64, app common.Address, signal [32]byte, proof []byte) (bool, error) {
	return _SignalService.Contract.ProveSignalReceived(&_SignalService.CallOpts, srcChainId, app, signal, proof)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 chainId, bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_SignalService *SignalServiceCaller) Resolve(opts *bind.CallOpts, chainId uint64, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _SignalService.contract.Call(opts, &out, "resolve", chainId, name, allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 chainId, bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_SignalService *SignalServiceSession) Resolve(chainId uint64, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _SignalService.Contract.Resolve(&_SignalService.CallOpts, chainId, name, allowZeroAddress)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 chainId, bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_SignalService *SignalServiceCallerSession) Resolve(chainId uint64, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _SignalService.Contract.Resolve(&_SignalService.CallOpts, chainId, name, allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_SignalService *SignalServiceCaller) Resolve0(opts *bind.CallOpts, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _SignalService.contract.Call(opts, &out, "resolve0", name, allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_SignalService *SignalServiceSession) Resolve0(name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _SignalService.Contract.Resolve0(&_SignalService.CallOpts, name, allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_SignalService *SignalServiceCallerSession) Resolve0(name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _SignalService.Contract.Resolve0(&_SignalService.CallOpts, name, allowZeroAddress)
}

// SkipProofCheck is a free data retrieval call binding the contract method 0xcbb3ddf3.
//
// Solidity: function skipProofCheck() pure returns(bool)
func (_SignalService *SignalServiceCaller) SkipProofCheck(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _SignalService.contract.Call(opts, &out, "skipProofCheck")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// SkipProofCheck is a free data retrieval call binding the contract method 0xcbb3ddf3.
//
// Solidity: function skipProofCheck() pure returns(bool)
func (_SignalService *SignalServiceSession) SkipProofCheck() (bool, error) {
	return _SignalService.Contract.SkipProofCheck(&_SignalService.CallOpts)
}

// SkipProofCheck is a free data retrieval call binding the contract method 0xcbb3ddf3.
//
// Solidity: function skipProofCheck() pure returns(bool)
func (_SignalService *SignalServiceCallerSession) SkipProofCheck() (bool, error) {
	return _SignalService.Contract.SkipProofCheck(&_SignalService.CallOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_SignalService *SignalServiceTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SignalService.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_SignalService *SignalServiceSession) AcceptOwnership() (*types.Transaction, error) {
	return _SignalService.Contract.AcceptOwnership(&_SignalService.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_SignalService *SignalServiceTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _SignalService.Contract.AcceptOwnership(&_SignalService.TransactOpts)
}

// Authorize is a paid mutator transaction binding the contract method 0x969e15a3.
//
// Solidity: function authorize(address addr, bytes32 label) returns()
func (_SignalService *SignalServiceTransactor) Authorize(opts *bind.TransactOpts, addr common.Address, label [32]byte) (*types.Transaction, error) {
	return _SignalService.contract.Transact(opts, "authorize", addr, label)
}

// Authorize is a paid mutator transaction binding the contract method 0x969e15a3.
//
// Solidity: function authorize(address addr, bytes32 label) returns()
func (_SignalService *SignalServiceSession) Authorize(addr common.Address, label [32]byte) (*types.Transaction, error) {
	return _SignalService.Contract.Authorize(&_SignalService.TransactOpts, addr, label)
}

// Authorize is a paid mutator transaction binding the contract method 0x969e15a3.
//
// Solidity: function authorize(address addr, bytes32 label) returns()
func (_SignalService *SignalServiceTransactorSession) Authorize(addr common.Address, label [32]byte) (*types.Transaction, error) {
	return _SignalService.Contract.Authorize(&_SignalService.TransactOpts, addr, label)
}

// Init is a paid mutator transaction binding the contract method 0xe1c7392a.
//
// Solidity: function init() returns()
func (_SignalService *SignalServiceTransactor) Init(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SignalService.contract.Transact(opts, "init")
}

// Init is a paid mutator transaction binding the contract method 0xe1c7392a.
//
// Solidity: function init() returns()
func (_SignalService *SignalServiceSession) Init() (*types.Transaction, error) {
	return _SignalService.Contract.Init(&_SignalService.TransactOpts)
}

// Init is a paid mutator transaction binding the contract method 0xe1c7392a.
//
// Solidity: function init() returns()
func (_SignalService *SignalServiceTransactorSession) Init() (*types.Transaction, error) {
	return _SignalService.Contract.Init(&_SignalService.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_SignalService *SignalServiceTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SignalService.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_SignalService *SignalServiceSession) Pause() (*types.Transaction, error) {
	return _SignalService.Contract.Pause(&_SignalService.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_SignalService *SignalServiceTransactorSession) Pause() (*types.Transaction, error) {
	return _SignalService.Contract.Pause(&_SignalService.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_SignalService *SignalServiceTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SignalService.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_SignalService *SignalServiceSession) RenounceOwnership() (*types.Transaction, error) {
	return _SignalService.Contract.RenounceOwnership(&_SignalService.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_SignalService *SignalServiceTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _SignalService.Contract.RenounceOwnership(&_SignalService.TransactOpts)
}

// SendSignal is a paid mutator transaction binding the contract method 0x66ca2bc0.
//
// Solidity: function sendSignal(bytes32 signal) returns(bytes32 slot)
func (_SignalService *SignalServiceTransactor) SendSignal(opts *bind.TransactOpts, signal [32]byte) (*types.Transaction, error) {
	return _SignalService.contract.Transact(opts, "sendSignal", signal)
}

// SendSignal is a paid mutator transaction binding the contract method 0x66ca2bc0.
//
// Solidity: function sendSignal(bytes32 signal) returns(bytes32 slot)
func (_SignalService *SignalServiceSession) SendSignal(signal [32]byte) (*types.Transaction, error) {
	return _SignalService.Contract.SendSignal(&_SignalService.TransactOpts, signal)
}

// SendSignal is a paid mutator transaction binding the contract method 0x66ca2bc0.
//
// Solidity: function sendSignal(bytes32 signal) returns(bytes32 slot)
func (_SignalService *SignalServiceTransactorSession) SendSignal(signal [32]byte) (*types.Transaction, error) {
	return _SignalService.Contract.SendSignal(&_SignalService.TransactOpts, signal)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_SignalService *SignalServiceTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _SignalService.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_SignalService *SignalServiceSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _SignalService.Contract.TransferOwnership(&_SignalService.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_SignalService *SignalServiceTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _SignalService.Contract.TransferOwnership(&_SignalService.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_SignalService *SignalServiceTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SignalService.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_SignalService *SignalServiceSession) Unpause() (*types.Transaction, error) {
	return _SignalService.Contract.Unpause(&_SignalService.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_SignalService *SignalServiceTransactorSession) Unpause() (*types.Transaction, error) {
	return _SignalService.Contract.Unpause(&_SignalService.TransactOpts)
}

// SignalServiceAuthorizedIterator is returned from FilterAuthorized and is used to iterate over the raw logs and unpacked data for Authorized events raised by the SignalService contract.
type SignalServiceAuthorizedIterator struct {
	Event *SignalServiceAuthorized // Event containing the contract specifics and raw log

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
func (it *SignalServiceAuthorizedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SignalServiceAuthorized)
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
		it.Event = new(SignalServiceAuthorized)
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
func (it *SignalServiceAuthorizedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SignalServiceAuthorizedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SignalServiceAuthorized represents a Authorized event raised by the SignalService contract.
type SignalServiceAuthorized struct {
	Addr     common.Address
	OldLabel [32]byte
	NewLabel [32]byte
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterAuthorized is a free log retrieval operation binding the contract event 0x7abb39ef31cf9e4e81ee30577a27909b031ee95c0459c22280fb8d3468c96fdf.
//
// Solidity: event Authorized(address indexed addr, bytes32 oldLabel, bytes32 newLabel)
func (_SignalService *SignalServiceFilterer) FilterAuthorized(opts *bind.FilterOpts, addr []common.Address) (*SignalServiceAuthorizedIterator, error) {

	var addrRule []interface{}
	for _, addrItem := range addr {
		addrRule = append(addrRule, addrItem)
	}

	logs, sub, err := _SignalService.contract.FilterLogs(opts, "Authorized", addrRule)
	if err != nil {
		return nil, err
	}
	return &SignalServiceAuthorizedIterator{contract: _SignalService.contract, event: "Authorized", logs: logs, sub: sub}, nil
}

// WatchAuthorized is a free log subscription operation binding the contract event 0x7abb39ef31cf9e4e81ee30577a27909b031ee95c0459c22280fb8d3468c96fdf.
//
// Solidity: event Authorized(address indexed addr, bytes32 oldLabel, bytes32 newLabel)
func (_SignalService *SignalServiceFilterer) WatchAuthorized(opts *bind.WatchOpts, sink chan<- *SignalServiceAuthorized, addr []common.Address) (event.Subscription, error) {

	var addrRule []interface{}
	for _, addrItem := range addr {
		addrRule = append(addrRule, addrItem)
	}

	logs, sub, err := _SignalService.contract.WatchLogs(opts, "Authorized", addrRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SignalServiceAuthorized)
				if err := _SignalService.contract.UnpackLog(event, "Authorized", log); err != nil {
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

// ParseAuthorized is a log parse operation binding the contract event 0x7abb39ef31cf9e4e81ee30577a27909b031ee95c0459c22280fb8d3468c96fdf.
//
// Solidity: event Authorized(address indexed addr, bytes32 oldLabel, bytes32 newLabel)
func (_SignalService *SignalServiceFilterer) ParseAuthorized(log types.Log) (*SignalServiceAuthorized, error) {
	event := new(SignalServiceAuthorized)
	if err := _SignalService.contract.UnpackLog(event, "Authorized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SignalServiceInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the SignalService contract.
type SignalServiceInitializedIterator struct {
	Event *SignalServiceInitialized // Event containing the contract specifics and raw log

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
func (it *SignalServiceInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SignalServiceInitialized)
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
		it.Event = new(SignalServiceInitialized)
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
func (it *SignalServiceInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SignalServiceInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SignalServiceInitialized represents a Initialized event raised by the SignalService contract.
type SignalServiceInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_SignalService *SignalServiceFilterer) FilterInitialized(opts *bind.FilterOpts) (*SignalServiceInitializedIterator, error) {

	logs, sub, err := _SignalService.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &SignalServiceInitializedIterator{contract: _SignalService.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_SignalService *SignalServiceFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *SignalServiceInitialized) (event.Subscription, error) {

	logs, sub, err := _SignalService.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SignalServiceInitialized)
				if err := _SignalService.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_SignalService *SignalServiceFilterer) ParseInitialized(log types.Log) (*SignalServiceInitialized, error) {
	event := new(SignalServiceInitialized)
	if err := _SignalService.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SignalServiceOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the SignalService contract.
type SignalServiceOwnershipTransferStartedIterator struct {
	Event *SignalServiceOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *SignalServiceOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SignalServiceOwnershipTransferStarted)
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
		it.Event = new(SignalServiceOwnershipTransferStarted)
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
func (it *SignalServiceOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SignalServiceOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SignalServiceOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the SignalService contract.
type SignalServiceOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_SignalService *SignalServiceFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*SignalServiceOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SignalService.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &SignalServiceOwnershipTransferStartedIterator{contract: _SignalService.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_SignalService *SignalServiceFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *SignalServiceOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SignalService.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SignalServiceOwnershipTransferStarted)
				if err := _SignalService.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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
func (_SignalService *SignalServiceFilterer) ParseOwnershipTransferStarted(log types.Log) (*SignalServiceOwnershipTransferStarted, error) {
	event := new(SignalServiceOwnershipTransferStarted)
	if err := _SignalService.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SignalServiceOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the SignalService contract.
type SignalServiceOwnershipTransferredIterator struct {
	Event *SignalServiceOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *SignalServiceOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SignalServiceOwnershipTransferred)
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
		it.Event = new(SignalServiceOwnershipTransferred)
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
func (it *SignalServiceOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SignalServiceOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SignalServiceOwnershipTransferred represents a OwnershipTransferred event raised by the SignalService contract.
type SignalServiceOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_SignalService *SignalServiceFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*SignalServiceOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SignalService.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &SignalServiceOwnershipTransferredIterator{contract: _SignalService.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_SignalService *SignalServiceFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *SignalServiceOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SignalService.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SignalServiceOwnershipTransferred)
				if err := _SignalService.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_SignalService *SignalServiceFilterer) ParseOwnershipTransferred(log types.Log) (*SignalServiceOwnershipTransferred, error) {
	event := new(SignalServiceOwnershipTransferred)
	if err := _SignalService.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SignalServicePausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the SignalService contract.
type SignalServicePausedIterator struct {
	Event *SignalServicePaused // Event containing the contract specifics and raw log

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
func (it *SignalServicePausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SignalServicePaused)
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
		it.Event = new(SignalServicePaused)
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
func (it *SignalServicePausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SignalServicePausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SignalServicePaused represents a Paused event raised by the SignalService contract.
type SignalServicePaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_SignalService *SignalServiceFilterer) FilterPaused(opts *bind.FilterOpts) (*SignalServicePausedIterator, error) {

	logs, sub, err := _SignalService.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &SignalServicePausedIterator{contract: _SignalService.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_SignalService *SignalServiceFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *SignalServicePaused) (event.Subscription, error) {

	logs, sub, err := _SignalService.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SignalServicePaused)
				if err := _SignalService.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_SignalService *SignalServiceFilterer) ParsePaused(log types.Log) (*SignalServicePaused, error) {
	event := new(SignalServicePaused)
	if err := _SignalService.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SignalServiceUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the SignalService contract.
type SignalServiceUnpausedIterator struct {
	Event *SignalServiceUnpaused // Event containing the contract specifics and raw log

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
func (it *SignalServiceUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SignalServiceUnpaused)
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
		it.Event = new(SignalServiceUnpaused)
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
func (it *SignalServiceUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SignalServiceUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SignalServiceUnpaused represents a Unpaused event raised by the SignalService contract.
type SignalServiceUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_SignalService *SignalServiceFilterer) FilterUnpaused(opts *bind.FilterOpts) (*SignalServiceUnpausedIterator, error) {

	logs, sub, err := _SignalService.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &SignalServiceUnpausedIterator{contract: _SignalService.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_SignalService *SignalServiceFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *SignalServiceUnpaused) (event.Subscription, error) {

	logs, sub, err := _SignalService.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SignalServiceUnpaused)
				if err := _SignalService.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_SignalService *SignalServiceFilterer) ParseUnpaused(log types.Log) (*SignalServiceUnpaused, error) {
	event := new(SignalServiceUnpaused)
	if err := _SignalService.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
