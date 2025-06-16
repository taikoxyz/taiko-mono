// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package pacaya

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

// IVerifierContext is an auto generated low-level Go binding around an user-defined struct.
type IVerifierContext struct {
	BatchId    uint64
	MetaHash   [32]byte
	Transition ITaikoInboxTransition
}

// ComposeVerifierMetaData contains all meta data concerning the ComposeVerifier contract.
var ComposeVerifierMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"impl\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inNonReentrant\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"opVerifier\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolver\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"risc0RethVerifier\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"sgxGethVerifier\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"sgxRethVerifier\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"sp1RethVerifier\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"taikoInbox\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"tdxGethVerifier\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"verifyProof\",\"inputs\":[{\"name\":\"_ctxs\",\"type\":\"tuple[]\",\"internalType\":\"structIVerifier.Context[]\",\"components\":[{\"name\":\"batchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"metaHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"transition\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.Transition\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]},{\"name\":\"_proof\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCESS_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CV_INVALID_SUB_VERIFIER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CV_INVALID_SUB_VERIFIER_ORDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CV_VERIFIERS_INSUFFICIENT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FUNCTION_DISABLED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FUNC_NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_VALUE\",\"inputs\":[]}]",
}

// ComposeVerifierABI is the input ABI used to generate the binding from.
// Deprecated: Use ComposeVerifierMetaData.ABI instead.
var ComposeVerifierABI = ComposeVerifierMetaData.ABI

// ComposeVerifier is an auto generated Go binding around an Ethereum contract.
type ComposeVerifier struct {
	ComposeVerifierCaller     // Read-only binding to the contract
	ComposeVerifierTransactor // Write-only binding to the contract
	ComposeVerifierFilterer   // Log filterer for contract events
}

// ComposeVerifierCaller is an auto generated read-only Go binding around an Ethereum contract.
type ComposeVerifierCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ComposeVerifierTransactor is an auto generated write-only Go binding around an Ethereum contract.
type ComposeVerifierTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ComposeVerifierFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type ComposeVerifierFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ComposeVerifierSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type ComposeVerifierSession struct {
	Contract     *ComposeVerifier  // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// ComposeVerifierCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type ComposeVerifierCallerSession struct {
	Contract *ComposeVerifierCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts          // Call options to use throughout this session
}

// ComposeVerifierTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type ComposeVerifierTransactorSession struct {
	Contract     *ComposeVerifierTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts          // Transaction auth options to use throughout this session
}

// ComposeVerifierRaw is an auto generated low-level Go binding around an Ethereum contract.
type ComposeVerifierRaw struct {
	Contract *ComposeVerifier // Generic contract binding to access the raw methods on
}

// ComposeVerifierCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type ComposeVerifierCallerRaw struct {
	Contract *ComposeVerifierCaller // Generic read-only contract binding to access the raw methods on
}

// ComposeVerifierTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type ComposeVerifierTransactorRaw struct {
	Contract *ComposeVerifierTransactor // Generic write-only contract binding to access the raw methods on
}

// NewComposeVerifier creates a new instance of ComposeVerifier, bound to a specific deployed contract.
func NewComposeVerifier(address common.Address, backend bind.ContractBackend) (*ComposeVerifier, error) {
	contract, err := bindComposeVerifier(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &ComposeVerifier{ComposeVerifierCaller: ComposeVerifierCaller{contract: contract}, ComposeVerifierTransactor: ComposeVerifierTransactor{contract: contract}, ComposeVerifierFilterer: ComposeVerifierFilterer{contract: contract}}, nil
}

// NewComposeVerifierCaller creates a new read-only instance of ComposeVerifier, bound to a specific deployed contract.
func NewComposeVerifierCaller(address common.Address, caller bind.ContractCaller) (*ComposeVerifierCaller, error) {
	contract, err := bindComposeVerifier(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &ComposeVerifierCaller{contract: contract}, nil
}

// NewComposeVerifierTransactor creates a new write-only instance of ComposeVerifier, bound to a specific deployed contract.
func NewComposeVerifierTransactor(address common.Address, transactor bind.ContractTransactor) (*ComposeVerifierTransactor, error) {
	contract, err := bindComposeVerifier(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &ComposeVerifierTransactor{contract: contract}, nil
}

// NewComposeVerifierFilterer creates a new log filterer instance of ComposeVerifier, bound to a specific deployed contract.
func NewComposeVerifierFilterer(address common.Address, filterer bind.ContractFilterer) (*ComposeVerifierFilterer, error) {
	contract, err := bindComposeVerifier(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &ComposeVerifierFilterer{contract: contract}, nil
}

// bindComposeVerifier binds a generic wrapper to an already deployed contract.
func bindComposeVerifier(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := ComposeVerifierMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ComposeVerifier *ComposeVerifierRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ComposeVerifier.Contract.ComposeVerifierCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ComposeVerifier *ComposeVerifierRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ComposeVerifier.Contract.ComposeVerifierTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ComposeVerifier *ComposeVerifierRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ComposeVerifier.Contract.ComposeVerifierTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ComposeVerifier *ComposeVerifierCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ComposeVerifier.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ComposeVerifier *ComposeVerifierTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ComposeVerifier.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ComposeVerifier *ComposeVerifierTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ComposeVerifier.Contract.contract.Transact(opts, method, params...)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_ComposeVerifier *ComposeVerifierCaller) Impl(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ComposeVerifier.contract.Call(opts, &out, "impl")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_ComposeVerifier *ComposeVerifierSession) Impl() (common.Address, error) {
	return _ComposeVerifier.Contract.Impl(&_ComposeVerifier.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_ComposeVerifier *ComposeVerifierCallerSession) Impl() (common.Address, error) {
	return _ComposeVerifier.Contract.Impl(&_ComposeVerifier.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_ComposeVerifier *ComposeVerifierCaller) InNonReentrant(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _ComposeVerifier.contract.Call(opts, &out, "inNonReentrant")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_ComposeVerifier *ComposeVerifierSession) InNonReentrant() (bool, error) {
	return _ComposeVerifier.Contract.InNonReentrant(&_ComposeVerifier.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_ComposeVerifier *ComposeVerifierCallerSession) InNonReentrant() (bool, error) {
	return _ComposeVerifier.Contract.InNonReentrant(&_ComposeVerifier.CallOpts)
}

// OpVerifier is a free data retrieval call binding the contract method 0xd09aed48.
//
// Solidity: function opVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierCaller) OpVerifier(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ComposeVerifier.contract.Call(opts, &out, "opVerifier")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// OpVerifier is a free data retrieval call binding the contract method 0xd09aed48.
//
// Solidity: function opVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierSession) OpVerifier() (common.Address, error) {
	return _ComposeVerifier.Contract.OpVerifier(&_ComposeVerifier.CallOpts)
}

// OpVerifier is a free data retrieval call binding the contract method 0xd09aed48.
//
// Solidity: function opVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierCallerSession) OpVerifier() (common.Address, error) {
	return _ComposeVerifier.Contract.OpVerifier(&_ComposeVerifier.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ComposeVerifier *ComposeVerifierCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ComposeVerifier.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ComposeVerifier *ComposeVerifierSession) Owner() (common.Address, error) {
	return _ComposeVerifier.Contract.Owner(&_ComposeVerifier.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ComposeVerifier *ComposeVerifierCallerSession) Owner() (common.Address, error) {
	return _ComposeVerifier.Contract.Owner(&_ComposeVerifier.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_ComposeVerifier *ComposeVerifierCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _ComposeVerifier.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_ComposeVerifier *ComposeVerifierSession) Paused() (bool, error) {
	return _ComposeVerifier.Contract.Paused(&_ComposeVerifier.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_ComposeVerifier *ComposeVerifierCallerSession) Paused() (bool, error) {
	return _ComposeVerifier.Contract.Paused(&_ComposeVerifier.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_ComposeVerifier *ComposeVerifierCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _ComposeVerifier.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_ComposeVerifier *ComposeVerifierSession) ProxiableUUID() ([32]byte, error) {
	return _ComposeVerifier.Contract.ProxiableUUID(&_ComposeVerifier.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_ComposeVerifier *ComposeVerifierCallerSession) ProxiableUUID() ([32]byte, error) {
	return _ComposeVerifier.Contract.ProxiableUUID(&_ComposeVerifier.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_ComposeVerifier *ComposeVerifierCaller) Resolver(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ComposeVerifier.contract.Call(opts, &out, "resolver")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_ComposeVerifier *ComposeVerifierSession) Resolver() (common.Address, error) {
	return _ComposeVerifier.Contract.Resolver(&_ComposeVerifier.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_ComposeVerifier *ComposeVerifierCallerSession) Resolver() (common.Address, error) {
	return _ComposeVerifier.Contract.Resolver(&_ComposeVerifier.CallOpts)
}

// Risc0RethVerifier is a free data retrieval call binding the contract method 0x97b56f57.
//
// Solidity: function risc0RethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierCaller) Risc0RethVerifier(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ComposeVerifier.contract.Call(opts, &out, "risc0RethVerifier")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Risc0RethVerifier is a free data retrieval call binding the contract method 0x97b56f57.
//
// Solidity: function risc0RethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierSession) Risc0RethVerifier() (common.Address, error) {
	return _ComposeVerifier.Contract.Risc0RethVerifier(&_ComposeVerifier.CallOpts)
}

// Risc0RethVerifier is a free data retrieval call binding the contract method 0x97b56f57.
//
// Solidity: function risc0RethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierCallerSession) Risc0RethVerifier() (common.Address, error) {
	return _ComposeVerifier.Contract.Risc0RethVerifier(&_ComposeVerifier.CallOpts)
}

// SgxGethVerifier is a free data retrieval call binding the contract method 0x680bca47.
//
// Solidity: function sgxGethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierCaller) SgxGethVerifier(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ComposeVerifier.contract.Call(opts, &out, "sgxGethVerifier")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SgxGethVerifier is a free data retrieval call binding the contract method 0x680bca47.
//
// Solidity: function sgxGethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierSession) SgxGethVerifier() (common.Address, error) {
	return _ComposeVerifier.Contract.SgxGethVerifier(&_ComposeVerifier.CallOpts)
}

// SgxGethVerifier is a free data retrieval call binding the contract method 0x680bca47.
//
// Solidity: function sgxGethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierCallerSession) SgxGethVerifier() (common.Address, error) {
	return _ComposeVerifier.Contract.SgxGethVerifier(&_ComposeVerifier.CallOpts)
}

// SgxRethVerifier is a free data retrieval call binding the contract method 0x4185d422.
//
// Solidity: function sgxRethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierCaller) SgxRethVerifier(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ComposeVerifier.contract.Call(opts, &out, "sgxRethVerifier")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SgxRethVerifier is a free data retrieval call binding the contract method 0x4185d422.
//
// Solidity: function sgxRethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierSession) SgxRethVerifier() (common.Address, error) {
	return _ComposeVerifier.Contract.SgxRethVerifier(&_ComposeVerifier.CallOpts)
}

// SgxRethVerifier is a free data retrieval call binding the contract method 0x4185d422.
//
// Solidity: function sgxRethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierCallerSession) SgxRethVerifier() (common.Address, error) {
	return _ComposeVerifier.Contract.SgxRethVerifier(&_ComposeVerifier.CallOpts)
}

// Sp1RethVerifier is a free data retrieval call binding the contract method 0x8d732463.
//
// Solidity: function sp1RethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierCaller) Sp1RethVerifier(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ComposeVerifier.contract.Call(opts, &out, "sp1RethVerifier")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Sp1RethVerifier is a free data retrieval call binding the contract method 0x8d732463.
//
// Solidity: function sp1RethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierSession) Sp1RethVerifier() (common.Address, error) {
	return _ComposeVerifier.Contract.Sp1RethVerifier(&_ComposeVerifier.CallOpts)
}

// Sp1RethVerifier is a free data retrieval call binding the contract method 0x8d732463.
//
// Solidity: function sp1RethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierCallerSession) Sp1RethVerifier() (common.Address, error) {
	return _ComposeVerifier.Contract.Sp1RethVerifier(&_ComposeVerifier.CallOpts)
}

// TaikoInbox is a free data retrieval call binding the contract method 0x5de92721.
//
// Solidity: function taikoInbox() view returns(address)
func (_ComposeVerifier *ComposeVerifierCaller) TaikoInbox(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ComposeVerifier.contract.Call(opts, &out, "taikoInbox")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// TaikoInbox is a free data retrieval call binding the contract method 0x5de92721.
//
// Solidity: function taikoInbox() view returns(address)
func (_ComposeVerifier *ComposeVerifierSession) TaikoInbox() (common.Address, error) {
	return _ComposeVerifier.Contract.TaikoInbox(&_ComposeVerifier.CallOpts)
}

// TaikoInbox is a free data retrieval call binding the contract method 0x5de92721.
//
// Solidity: function taikoInbox() view returns(address)
func (_ComposeVerifier *ComposeVerifierCallerSession) TaikoInbox() (common.Address, error) {
	return _ComposeVerifier.Contract.TaikoInbox(&_ComposeVerifier.CallOpts)
}

// TdxGethVerifier is a free data retrieval call binding the contract method 0xa936fa71.
//
// Solidity: function tdxGethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierCaller) TdxGethVerifier(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ComposeVerifier.contract.Call(opts, &out, "tdxGethVerifier")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// TdxGethVerifier is a free data retrieval call binding the contract method 0xa936fa71.
//
// Solidity: function tdxGethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierSession) TdxGethVerifier() (common.Address, error) {
	return _ComposeVerifier.Contract.TdxGethVerifier(&_ComposeVerifier.CallOpts)
}

// TdxGethVerifier is a free data retrieval call binding the contract method 0xa936fa71.
//
// Solidity: function tdxGethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierCallerSession) TdxGethVerifier() (common.Address, error) {
	return _ComposeVerifier.Contract.TdxGethVerifier(&_ComposeVerifier.CallOpts)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_ComposeVerifier *ComposeVerifierTransactor) Init(opts *bind.TransactOpts, _owner common.Address) (*types.Transaction, error) {
	return _ComposeVerifier.contract.Transact(opts, "init", _owner)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_ComposeVerifier *ComposeVerifierSession) Init(_owner common.Address) (*types.Transaction, error) {
	return _ComposeVerifier.Contract.Init(&_ComposeVerifier.TransactOpts, _owner)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_ComposeVerifier *ComposeVerifierTransactorSession) Init(_owner common.Address) (*types.Transaction, error) {
	return _ComposeVerifier.Contract.Init(&_ComposeVerifier.TransactOpts, _owner)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_ComposeVerifier *ComposeVerifierTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ComposeVerifier.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_ComposeVerifier *ComposeVerifierSession) Pause() (*types.Transaction, error) {
	return _ComposeVerifier.Contract.Pause(&_ComposeVerifier.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_ComposeVerifier *ComposeVerifierTransactorSession) Pause() (*types.Transaction, error) {
	return _ComposeVerifier.Contract.Pause(&_ComposeVerifier.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ComposeVerifier *ComposeVerifierTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ComposeVerifier.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ComposeVerifier *ComposeVerifierSession) RenounceOwnership() (*types.Transaction, error) {
	return _ComposeVerifier.Contract.RenounceOwnership(&_ComposeVerifier.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ComposeVerifier *ComposeVerifierTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _ComposeVerifier.Contract.RenounceOwnership(&_ComposeVerifier.TransactOpts)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ComposeVerifier *ComposeVerifierTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _ComposeVerifier.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ComposeVerifier *ComposeVerifierSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _ComposeVerifier.Contract.TransferOwnership(&_ComposeVerifier.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ComposeVerifier *ComposeVerifierTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _ComposeVerifier.Contract.TransferOwnership(&_ComposeVerifier.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_ComposeVerifier *ComposeVerifierTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ComposeVerifier.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_ComposeVerifier *ComposeVerifierSession) Unpause() (*types.Transaction, error) {
	return _ComposeVerifier.Contract.Unpause(&_ComposeVerifier.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_ComposeVerifier *ComposeVerifierTransactorSession) Unpause() (*types.Transaction, error) {
	return _ComposeVerifier.Contract.Unpause(&_ComposeVerifier.TransactOpts)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_ComposeVerifier *ComposeVerifierTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _ComposeVerifier.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_ComposeVerifier *ComposeVerifierSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _ComposeVerifier.Contract.UpgradeTo(&_ComposeVerifier.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_ComposeVerifier *ComposeVerifierTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _ComposeVerifier.Contract.UpgradeTo(&_ComposeVerifier.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_ComposeVerifier *ComposeVerifierTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _ComposeVerifier.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_ComposeVerifier *ComposeVerifierSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _ComposeVerifier.Contract.UpgradeToAndCall(&_ComposeVerifier.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_ComposeVerifier *ComposeVerifierTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _ComposeVerifier.Contract.UpgradeToAndCall(&_ComposeVerifier.TransactOpts, newImplementation, data)
}

// VerifyProof is a paid mutator transaction binding the contract method 0x9b26b724.
//
// Solidity: function verifyProof((uint64,bytes32,(bytes32,bytes32,bytes32))[] _ctxs, bytes _proof) returns()
func (_ComposeVerifier *ComposeVerifierTransactor) VerifyProof(opts *bind.TransactOpts, _ctxs []IVerifierContext, _proof []byte) (*types.Transaction, error) {
	return _ComposeVerifier.contract.Transact(opts, "verifyProof", _ctxs, _proof)
}

// VerifyProof is a paid mutator transaction binding the contract method 0x9b26b724.
//
// Solidity: function verifyProof((uint64,bytes32,(bytes32,bytes32,bytes32))[] _ctxs, bytes _proof) returns()
func (_ComposeVerifier *ComposeVerifierSession) VerifyProof(_ctxs []IVerifierContext, _proof []byte) (*types.Transaction, error) {
	return _ComposeVerifier.Contract.VerifyProof(&_ComposeVerifier.TransactOpts, _ctxs, _proof)
}

// VerifyProof is a paid mutator transaction binding the contract method 0x9b26b724.
//
// Solidity: function verifyProof((uint64,bytes32,(bytes32,bytes32,bytes32))[] _ctxs, bytes _proof) returns()
func (_ComposeVerifier *ComposeVerifierTransactorSession) VerifyProof(_ctxs []IVerifierContext, _proof []byte) (*types.Transaction, error) {
	return _ComposeVerifier.Contract.VerifyProof(&_ComposeVerifier.TransactOpts, _ctxs, _proof)
}

// ComposeVerifierAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the ComposeVerifier contract.
type ComposeVerifierAdminChangedIterator struct {
	Event *ComposeVerifierAdminChanged // Event containing the contract specifics and raw log

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
func (it *ComposeVerifierAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ComposeVerifierAdminChanged)
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
		it.Event = new(ComposeVerifierAdminChanged)
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
func (it *ComposeVerifierAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ComposeVerifierAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ComposeVerifierAdminChanged represents a AdminChanged event raised by the ComposeVerifier contract.
type ComposeVerifierAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_ComposeVerifier *ComposeVerifierFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*ComposeVerifierAdminChangedIterator, error) {

	logs, sub, err := _ComposeVerifier.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &ComposeVerifierAdminChangedIterator{contract: _ComposeVerifier.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_ComposeVerifier *ComposeVerifierFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *ComposeVerifierAdminChanged) (event.Subscription, error) {

	logs, sub, err := _ComposeVerifier.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ComposeVerifierAdminChanged)
				if err := _ComposeVerifier.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_ComposeVerifier *ComposeVerifierFilterer) ParseAdminChanged(log types.Log) (*ComposeVerifierAdminChanged, error) {
	event := new(ComposeVerifierAdminChanged)
	if err := _ComposeVerifier.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ComposeVerifierBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the ComposeVerifier contract.
type ComposeVerifierBeaconUpgradedIterator struct {
	Event *ComposeVerifierBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *ComposeVerifierBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ComposeVerifierBeaconUpgraded)
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
		it.Event = new(ComposeVerifierBeaconUpgraded)
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
func (it *ComposeVerifierBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ComposeVerifierBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ComposeVerifierBeaconUpgraded represents a BeaconUpgraded event raised by the ComposeVerifier contract.
type ComposeVerifierBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_ComposeVerifier *ComposeVerifierFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*ComposeVerifierBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _ComposeVerifier.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &ComposeVerifierBeaconUpgradedIterator{contract: _ComposeVerifier.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_ComposeVerifier *ComposeVerifierFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *ComposeVerifierBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _ComposeVerifier.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ComposeVerifierBeaconUpgraded)
				if err := _ComposeVerifier.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_ComposeVerifier *ComposeVerifierFilterer) ParseBeaconUpgraded(log types.Log) (*ComposeVerifierBeaconUpgraded, error) {
	event := new(ComposeVerifierBeaconUpgraded)
	if err := _ComposeVerifier.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ComposeVerifierInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the ComposeVerifier contract.
type ComposeVerifierInitializedIterator struct {
	Event *ComposeVerifierInitialized // Event containing the contract specifics and raw log

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
func (it *ComposeVerifierInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ComposeVerifierInitialized)
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
		it.Event = new(ComposeVerifierInitialized)
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
func (it *ComposeVerifierInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ComposeVerifierInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ComposeVerifierInitialized represents a Initialized event raised by the ComposeVerifier contract.
type ComposeVerifierInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_ComposeVerifier *ComposeVerifierFilterer) FilterInitialized(opts *bind.FilterOpts) (*ComposeVerifierInitializedIterator, error) {

	logs, sub, err := _ComposeVerifier.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &ComposeVerifierInitializedIterator{contract: _ComposeVerifier.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_ComposeVerifier *ComposeVerifierFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *ComposeVerifierInitialized) (event.Subscription, error) {

	logs, sub, err := _ComposeVerifier.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ComposeVerifierInitialized)
				if err := _ComposeVerifier.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_ComposeVerifier *ComposeVerifierFilterer) ParseInitialized(log types.Log) (*ComposeVerifierInitialized, error) {
	event := new(ComposeVerifierInitialized)
	if err := _ComposeVerifier.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ComposeVerifierOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the ComposeVerifier contract.
type ComposeVerifierOwnershipTransferredIterator struct {
	Event *ComposeVerifierOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *ComposeVerifierOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ComposeVerifierOwnershipTransferred)
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
		it.Event = new(ComposeVerifierOwnershipTransferred)
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
func (it *ComposeVerifierOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ComposeVerifierOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ComposeVerifierOwnershipTransferred represents a OwnershipTransferred event raised by the ComposeVerifier contract.
type ComposeVerifierOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_ComposeVerifier *ComposeVerifierFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*ComposeVerifierOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ComposeVerifier.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &ComposeVerifierOwnershipTransferredIterator{contract: _ComposeVerifier.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_ComposeVerifier *ComposeVerifierFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *ComposeVerifierOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ComposeVerifier.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ComposeVerifierOwnershipTransferred)
				if err := _ComposeVerifier.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_ComposeVerifier *ComposeVerifierFilterer) ParseOwnershipTransferred(log types.Log) (*ComposeVerifierOwnershipTransferred, error) {
	event := new(ComposeVerifierOwnershipTransferred)
	if err := _ComposeVerifier.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ComposeVerifierPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the ComposeVerifier contract.
type ComposeVerifierPausedIterator struct {
	Event *ComposeVerifierPaused // Event containing the contract specifics and raw log

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
func (it *ComposeVerifierPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ComposeVerifierPaused)
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
		it.Event = new(ComposeVerifierPaused)
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
func (it *ComposeVerifierPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ComposeVerifierPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ComposeVerifierPaused represents a Paused event raised by the ComposeVerifier contract.
type ComposeVerifierPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_ComposeVerifier *ComposeVerifierFilterer) FilterPaused(opts *bind.FilterOpts) (*ComposeVerifierPausedIterator, error) {

	logs, sub, err := _ComposeVerifier.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &ComposeVerifierPausedIterator{contract: _ComposeVerifier.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_ComposeVerifier *ComposeVerifierFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *ComposeVerifierPaused) (event.Subscription, error) {

	logs, sub, err := _ComposeVerifier.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ComposeVerifierPaused)
				if err := _ComposeVerifier.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_ComposeVerifier *ComposeVerifierFilterer) ParsePaused(log types.Log) (*ComposeVerifierPaused, error) {
	event := new(ComposeVerifierPaused)
	if err := _ComposeVerifier.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ComposeVerifierUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the ComposeVerifier contract.
type ComposeVerifierUnpausedIterator struct {
	Event *ComposeVerifierUnpaused // Event containing the contract specifics and raw log

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
func (it *ComposeVerifierUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ComposeVerifierUnpaused)
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
		it.Event = new(ComposeVerifierUnpaused)
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
func (it *ComposeVerifierUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ComposeVerifierUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ComposeVerifierUnpaused represents a Unpaused event raised by the ComposeVerifier contract.
type ComposeVerifierUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_ComposeVerifier *ComposeVerifierFilterer) FilterUnpaused(opts *bind.FilterOpts) (*ComposeVerifierUnpausedIterator, error) {

	logs, sub, err := _ComposeVerifier.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &ComposeVerifierUnpausedIterator{contract: _ComposeVerifier.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_ComposeVerifier *ComposeVerifierFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *ComposeVerifierUnpaused) (event.Subscription, error) {

	logs, sub, err := _ComposeVerifier.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ComposeVerifierUnpaused)
				if err := _ComposeVerifier.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_ComposeVerifier *ComposeVerifierFilterer) ParseUnpaused(log types.Log) (*ComposeVerifierUnpaused, error) {
	event := new(ComposeVerifierUnpaused)
	if err := _ComposeVerifier.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ComposeVerifierUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the ComposeVerifier contract.
type ComposeVerifierUpgradedIterator struct {
	Event *ComposeVerifierUpgraded // Event containing the contract specifics and raw log

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
func (it *ComposeVerifierUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ComposeVerifierUpgraded)
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
		it.Event = new(ComposeVerifierUpgraded)
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
func (it *ComposeVerifierUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ComposeVerifierUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ComposeVerifierUpgraded represents a Upgraded event raised by the ComposeVerifier contract.
type ComposeVerifierUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_ComposeVerifier *ComposeVerifierFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*ComposeVerifierUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _ComposeVerifier.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &ComposeVerifierUpgradedIterator{contract: _ComposeVerifier.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_ComposeVerifier *ComposeVerifierFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *ComposeVerifierUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _ComposeVerifier.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ComposeVerifierUpgraded)
				if err := _ComposeVerifier.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_ComposeVerifier *ComposeVerifierFilterer) ParseUpgraded(log types.Log) (*ComposeVerifierUpgraded, error) {
	event := new(ComposeVerifierUpgraded)
	if err := _ComposeVerifier.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
