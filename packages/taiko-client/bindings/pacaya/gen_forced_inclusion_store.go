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

// ForcedInclusionStoreMetaData contains all meta data concerning the ForcedInclusionStore contract.
var ForcedInclusionStoreMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"_inclusionDelay\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"_feeInGwei\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_inbox\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_inboxWrapper\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"consumeOldestForcedInclusion\",\"inputs\":[{\"name\":\"_feeRecipient\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"inclusion_\",\"type\":\"tuple\",\"internalType\":\"structIForcedInclusionStore.ForcedInclusion\",\"components\":[{\"name\":\"blobHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"feeInGwei\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"createdAtBatchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobByteOffset\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobByteSize\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobCreatedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"feeInGwei\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getForcedInclusion\",\"inputs\":[{\"name\":\"index\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structIForcedInclusionStore.ForcedInclusion\",\"components\":[{\"name\":\"blobHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"feeInGwei\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"createdAtBatchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobByteOffset\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobByteSize\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobCreatedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getOldestForcedInclusionDeadline\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"head\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"impl\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inNonReentrant\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inbox\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractITaikoInbox\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inboxWrapper\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inclusionDelay\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isOldestForcedInclusionDue\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"lastProcessedAtBatchId\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"queue\",\"inputs\":[{\"name\":\"id\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"blobHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"feeInGwei\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"createdAtBatchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobByteOffset\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobByteSize\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobCreatedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolver\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"storeForcedInclusion\",\"inputs\":[{\"name\":\"blobIndex\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"blobByteOffset\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobByteSize\",\"type\":\"uint32\",\"internalType\":\"uint32\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"tail\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ForcedInclusionConsumed\",\"inputs\":[{\"name\":\"forcedInclusion\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structIForcedInclusionStore.ForcedInclusion\",\"components\":[{\"name\":\"blobHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"feeInGwei\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"createdAtBatchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobByteOffset\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobByteSize\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobCreatedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ForcedInclusionStored\",\"inputs\":[{\"name\":\"forcedInclusion\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structIForcedInclusionStore.ForcedInclusion\",\"components\":[{\"name\":\"blobHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"feeInGwei\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"createdAtBatchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobByteOffset\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobByteSize\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobCreatedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCESS_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"BlobNotFound\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ETH_TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FUNC_NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"IncorrectFee\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidIndex\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidParams\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NoForcedInclusionFound\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_VALUE\",\"inputs\":[]}]",
}

// ForcedInclusionStoreABI is the input ABI used to generate the binding from.
// Deprecated: Use ForcedInclusionStoreMetaData.ABI instead.
var ForcedInclusionStoreABI = ForcedInclusionStoreMetaData.ABI

// ForcedInclusionStore is an auto generated Go binding around an Ethereum contract.
type ForcedInclusionStore struct {
	ForcedInclusionStoreCaller     // Read-only binding to the contract
	ForcedInclusionStoreTransactor // Write-only binding to the contract
	ForcedInclusionStoreFilterer   // Log filterer for contract events
}

// ForcedInclusionStoreCaller is an auto generated read-only Go binding around an Ethereum contract.
type ForcedInclusionStoreCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ForcedInclusionStoreTransactor is an auto generated write-only Go binding around an Ethereum contract.
type ForcedInclusionStoreTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ForcedInclusionStoreFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type ForcedInclusionStoreFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ForcedInclusionStoreSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type ForcedInclusionStoreSession struct {
	Contract     *ForcedInclusionStore // Generic contract binding to set the session for
	CallOpts     bind.CallOpts         // Call options to use throughout this session
	TransactOpts bind.TransactOpts     // Transaction auth options to use throughout this session
}

// ForcedInclusionStoreCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type ForcedInclusionStoreCallerSession struct {
	Contract *ForcedInclusionStoreCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts               // Call options to use throughout this session
}

// ForcedInclusionStoreTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type ForcedInclusionStoreTransactorSession struct {
	Contract     *ForcedInclusionStoreTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts               // Transaction auth options to use throughout this session
}

// ForcedInclusionStoreRaw is an auto generated low-level Go binding around an Ethereum contract.
type ForcedInclusionStoreRaw struct {
	Contract *ForcedInclusionStore // Generic contract binding to access the raw methods on
}

// ForcedInclusionStoreCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type ForcedInclusionStoreCallerRaw struct {
	Contract *ForcedInclusionStoreCaller // Generic read-only contract binding to access the raw methods on
}

// ForcedInclusionStoreTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type ForcedInclusionStoreTransactorRaw struct {
	Contract *ForcedInclusionStoreTransactor // Generic write-only contract binding to access the raw methods on
}

// NewForcedInclusionStore creates a new instance of ForcedInclusionStore, bound to a specific deployed contract.
func NewForcedInclusionStore(address common.Address, backend bind.ContractBackend) (*ForcedInclusionStore, error) {
	contract, err := bindForcedInclusionStore(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &ForcedInclusionStore{ForcedInclusionStoreCaller: ForcedInclusionStoreCaller{contract: contract}, ForcedInclusionStoreTransactor: ForcedInclusionStoreTransactor{contract: contract}, ForcedInclusionStoreFilterer: ForcedInclusionStoreFilterer{contract: contract}}, nil
}

// NewForcedInclusionStoreCaller creates a new read-only instance of ForcedInclusionStore, bound to a specific deployed contract.
func NewForcedInclusionStoreCaller(address common.Address, caller bind.ContractCaller) (*ForcedInclusionStoreCaller, error) {
	contract, err := bindForcedInclusionStore(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &ForcedInclusionStoreCaller{contract: contract}, nil
}

// NewForcedInclusionStoreTransactor creates a new write-only instance of ForcedInclusionStore, bound to a specific deployed contract.
func NewForcedInclusionStoreTransactor(address common.Address, transactor bind.ContractTransactor) (*ForcedInclusionStoreTransactor, error) {
	contract, err := bindForcedInclusionStore(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &ForcedInclusionStoreTransactor{contract: contract}, nil
}

// NewForcedInclusionStoreFilterer creates a new log filterer instance of ForcedInclusionStore, bound to a specific deployed contract.
func NewForcedInclusionStoreFilterer(address common.Address, filterer bind.ContractFilterer) (*ForcedInclusionStoreFilterer, error) {
	contract, err := bindForcedInclusionStore(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &ForcedInclusionStoreFilterer{contract: contract}, nil
}

// bindForcedInclusionStore binds a generic wrapper to an already deployed contract.
func bindForcedInclusionStore(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := ForcedInclusionStoreMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ForcedInclusionStore *ForcedInclusionStoreRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ForcedInclusionStore.Contract.ForcedInclusionStoreCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ForcedInclusionStore *ForcedInclusionStoreRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ForcedInclusionStore.Contract.ForcedInclusionStoreTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ForcedInclusionStore *ForcedInclusionStoreRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ForcedInclusionStore.Contract.ForcedInclusionStoreTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ForcedInclusionStore *ForcedInclusionStoreCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ForcedInclusionStore.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ForcedInclusionStore *ForcedInclusionStoreTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ForcedInclusionStore.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ForcedInclusionStore *ForcedInclusionStoreTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ForcedInclusionStore.Contract.contract.Transact(opts, method, params...)
}

// FeeInGwei is a free data retrieval call binding the contract method 0xb2a39d43.
//
// Solidity: function feeInGwei() view returns(uint64)
func (_ForcedInclusionStore *ForcedInclusionStoreCaller) FeeInGwei(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _ForcedInclusionStore.contract.Call(opts, &out, "feeInGwei")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// FeeInGwei is a free data retrieval call binding the contract method 0xb2a39d43.
//
// Solidity: function feeInGwei() view returns(uint64)
func (_ForcedInclusionStore *ForcedInclusionStoreSession) FeeInGwei() (uint64, error) {
	return _ForcedInclusionStore.Contract.FeeInGwei(&_ForcedInclusionStore.CallOpts)
}

// FeeInGwei is a free data retrieval call binding the contract method 0xb2a39d43.
//
// Solidity: function feeInGwei() view returns(uint64)
func (_ForcedInclusionStore *ForcedInclusionStoreCallerSession) FeeInGwei() (uint64, error) {
	return _ForcedInclusionStore.Contract.FeeInGwei(&_ForcedInclusionStore.CallOpts)
}

// GetForcedInclusion is a free data retrieval call binding the contract method 0xa7c6b857.
//
// Solidity: function getForcedInclusion(uint256 index) view returns((bytes32,uint64,uint64,uint32,uint32,uint64))
func (_ForcedInclusionStore *ForcedInclusionStoreCaller) GetForcedInclusion(opts *bind.CallOpts, index *big.Int) (IForcedInclusionStoreForcedInclusion, error) {
	var out []interface{}
	err := _ForcedInclusionStore.contract.Call(opts, &out, "getForcedInclusion", index)

	if err != nil {
		return *new(IForcedInclusionStoreForcedInclusion), err
	}

	out0 := *abi.ConvertType(out[0], new(IForcedInclusionStoreForcedInclusion)).(*IForcedInclusionStoreForcedInclusion)

	return out0, err

}

// GetForcedInclusion is a free data retrieval call binding the contract method 0xa7c6b857.
//
// Solidity: function getForcedInclusion(uint256 index) view returns((bytes32,uint64,uint64,uint32,uint32,uint64))
func (_ForcedInclusionStore *ForcedInclusionStoreSession) GetForcedInclusion(index *big.Int) (IForcedInclusionStoreForcedInclusion, error) {
	return _ForcedInclusionStore.Contract.GetForcedInclusion(&_ForcedInclusionStore.CallOpts, index)
}

// GetForcedInclusion is a free data retrieval call binding the contract method 0xa7c6b857.
//
// Solidity: function getForcedInclusion(uint256 index) view returns((bytes32,uint64,uint64,uint32,uint32,uint64))
func (_ForcedInclusionStore *ForcedInclusionStoreCallerSession) GetForcedInclusion(index *big.Int) (IForcedInclusionStoreForcedInclusion, error) {
	return _ForcedInclusionStore.Contract.GetForcedInclusion(&_ForcedInclusionStore.CallOpts, index)
}

// GetOldestForcedInclusionDeadline is a free data retrieval call binding the contract method 0x1c07fbfe.
//
// Solidity: function getOldestForcedInclusionDeadline() view returns(uint256)
func (_ForcedInclusionStore *ForcedInclusionStoreCaller) GetOldestForcedInclusionDeadline(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _ForcedInclusionStore.contract.Call(opts, &out, "getOldestForcedInclusionDeadline")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetOldestForcedInclusionDeadline is a free data retrieval call binding the contract method 0x1c07fbfe.
//
// Solidity: function getOldestForcedInclusionDeadline() view returns(uint256)
func (_ForcedInclusionStore *ForcedInclusionStoreSession) GetOldestForcedInclusionDeadline() (*big.Int, error) {
	return _ForcedInclusionStore.Contract.GetOldestForcedInclusionDeadline(&_ForcedInclusionStore.CallOpts)
}

// GetOldestForcedInclusionDeadline is a free data retrieval call binding the contract method 0x1c07fbfe.
//
// Solidity: function getOldestForcedInclusionDeadline() view returns(uint256)
func (_ForcedInclusionStore *ForcedInclusionStoreCallerSession) GetOldestForcedInclusionDeadline() (*big.Int, error) {
	return _ForcedInclusionStore.Contract.GetOldestForcedInclusionDeadline(&_ForcedInclusionStore.CallOpts)
}

// Head is a free data retrieval call binding the contract method 0x8f7dcfa3.
//
// Solidity: function head() view returns(uint64)
func (_ForcedInclusionStore *ForcedInclusionStoreCaller) Head(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _ForcedInclusionStore.contract.Call(opts, &out, "head")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// Head is a free data retrieval call binding the contract method 0x8f7dcfa3.
//
// Solidity: function head() view returns(uint64)
func (_ForcedInclusionStore *ForcedInclusionStoreSession) Head() (uint64, error) {
	return _ForcedInclusionStore.Contract.Head(&_ForcedInclusionStore.CallOpts)
}

// Head is a free data retrieval call binding the contract method 0x8f7dcfa3.
//
// Solidity: function head() view returns(uint64)
func (_ForcedInclusionStore *ForcedInclusionStoreCallerSession) Head() (uint64, error) {
	return _ForcedInclusionStore.Contract.Head(&_ForcedInclusionStore.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_ForcedInclusionStore *ForcedInclusionStoreCaller) Impl(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ForcedInclusionStore.contract.Call(opts, &out, "impl")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_ForcedInclusionStore *ForcedInclusionStoreSession) Impl() (common.Address, error) {
	return _ForcedInclusionStore.Contract.Impl(&_ForcedInclusionStore.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_ForcedInclusionStore *ForcedInclusionStoreCallerSession) Impl() (common.Address, error) {
	return _ForcedInclusionStore.Contract.Impl(&_ForcedInclusionStore.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_ForcedInclusionStore *ForcedInclusionStoreCaller) InNonReentrant(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _ForcedInclusionStore.contract.Call(opts, &out, "inNonReentrant")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_ForcedInclusionStore *ForcedInclusionStoreSession) InNonReentrant() (bool, error) {
	return _ForcedInclusionStore.Contract.InNonReentrant(&_ForcedInclusionStore.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_ForcedInclusionStore *ForcedInclusionStoreCallerSession) InNonReentrant() (bool, error) {
	return _ForcedInclusionStore.Contract.InNonReentrant(&_ForcedInclusionStore.CallOpts)
}

// Inbox is a free data retrieval call binding the contract method 0xfb0e722b.
//
// Solidity: function inbox() view returns(address)
func (_ForcedInclusionStore *ForcedInclusionStoreCaller) Inbox(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ForcedInclusionStore.contract.Call(opts, &out, "inbox")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Inbox is a free data retrieval call binding the contract method 0xfb0e722b.
//
// Solidity: function inbox() view returns(address)
func (_ForcedInclusionStore *ForcedInclusionStoreSession) Inbox() (common.Address, error) {
	return _ForcedInclusionStore.Contract.Inbox(&_ForcedInclusionStore.CallOpts)
}

// Inbox is a free data retrieval call binding the contract method 0xfb0e722b.
//
// Solidity: function inbox() view returns(address)
func (_ForcedInclusionStore *ForcedInclusionStoreCallerSession) Inbox() (common.Address, error) {
	return _ForcedInclusionStore.Contract.Inbox(&_ForcedInclusionStore.CallOpts)
}

// InboxWrapper is a free data retrieval call binding the contract method 0x59df1118.
//
// Solidity: function inboxWrapper() view returns(address)
func (_ForcedInclusionStore *ForcedInclusionStoreCaller) InboxWrapper(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ForcedInclusionStore.contract.Call(opts, &out, "inboxWrapper")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// InboxWrapper is a free data retrieval call binding the contract method 0x59df1118.
//
// Solidity: function inboxWrapper() view returns(address)
func (_ForcedInclusionStore *ForcedInclusionStoreSession) InboxWrapper() (common.Address, error) {
	return _ForcedInclusionStore.Contract.InboxWrapper(&_ForcedInclusionStore.CallOpts)
}

// InboxWrapper is a free data retrieval call binding the contract method 0x59df1118.
//
// Solidity: function inboxWrapper() view returns(address)
func (_ForcedInclusionStore *ForcedInclusionStoreCallerSession) InboxWrapper() (common.Address, error) {
	return _ForcedInclusionStore.Contract.InboxWrapper(&_ForcedInclusionStore.CallOpts)
}

// InclusionDelay is a free data retrieval call binding the contract method 0xf765b4c3.
//
// Solidity: function inclusionDelay() view returns(uint8)
func (_ForcedInclusionStore *ForcedInclusionStoreCaller) InclusionDelay(opts *bind.CallOpts) (uint8, error) {
	var out []interface{}
	err := _ForcedInclusionStore.contract.Call(opts, &out, "inclusionDelay")

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// InclusionDelay is a free data retrieval call binding the contract method 0xf765b4c3.
//
// Solidity: function inclusionDelay() view returns(uint8)
func (_ForcedInclusionStore *ForcedInclusionStoreSession) InclusionDelay() (uint8, error) {
	return _ForcedInclusionStore.Contract.InclusionDelay(&_ForcedInclusionStore.CallOpts)
}

// InclusionDelay is a free data retrieval call binding the contract method 0xf765b4c3.
//
// Solidity: function inclusionDelay() view returns(uint8)
func (_ForcedInclusionStore *ForcedInclusionStoreCallerSession) InclusionDelay() (uint8, error) {
	return _ForcedInclusionStore.Contract.InclusionDelay(&_ForcedInclusionStore.CallOpts)
}

// IsOldestForcedInclusionDue is a free data retrieval call binding the contract method 0x16db8952.
//
// Solidity: function isOldestForcedInclusionDue() view returns(bool)
func (_ForcedInclusionStore *ForcedInclusionStoreCaller) IsOldestForcedInclusionDue(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _ForcedInclusionStore.contract.Call(opts, &out, "isOldestForcedInclusionDue")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsOldestForcedInclusionDue is a free data retrieval call binding the contract method 0x16db8952.
//
// Solidity: function isOldestForcedInclusionDue() view returns(bool)
func (_ForcedInclusionStore *ForcedInclusionStoreSession) IsOldestForcedInclusionDue() (bool, error) {
	return _ForcedInclusionStore.Contract.IsOldestForcedInclusionDue(&_ForcedInclusionStore.CallOpts)
}

// IsOldestForcedInclusionDue is a free data retrieval call binding the contract method 0x16db8952.
//
// Solidity: function isOldestForcedInclusionDue() view returns(bool)
func (_ForcedInclusionStore *ForcedInclusionStoreCallerSession) IsOldestForcedInclusionDue() (bool, error) {
	return _ForcedInclusionStore.Contract.IsOldestForcedInclusionDue(&_ForcedInclusionStore.CallOpts)
}

// LastProcessedAtBatchId is a free data retrieval call binding the contract method 0xd3f1696d.
//
// Solidity: function lastProcessedAtBatchId() view returns(uint64)
func (_ForcedInclusionStore *ForcedInclusionStoreCaller) LastProcessedAtBatchId(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _ForcedInclusionStore.contract.Call(opts, &out, "lastProcessedAtBatchId")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// LastProcessedAtBatchId is a free data retrieval call binding the contract method 0xd3f1696d.
//
// Solidity: function lastProcessedAtBatchId() view returns(uint64)
func (_ForcedInclusionStore *ForcedInclusionStoreSession) LastProcessedAtBatchId() (uint64, error) {
	return _ForcedInclusionStore.Contract.LastProcessedAtBatchId(&_ForcedInclusionStore.CallOpts)
}

// LastProcessedAtBatchId is a free data retrieval call binding the contract method 0xd3f1696d.
//
// Solidity: function lastProcessedAtBatchId() view returns(uint64)
func (_ForcedInclusionStore *ForcedInclusionStoreCallerSession) LastProcessedAtBatchId() (uint64, error) {
	return _ForcedInclusionStore.Contract.LastProcessedAtBatchId(&_ForcedInclusionStore.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ForcedInclusionStore *ForcedInclusionStoreCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ForcedInclusionStore.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ForcedInclusionStore *ForcedInclusionStoreSession) Owner() (common.Address, error) {
	return _ForcedInclusionStore.Contract.Owner(&_ForcedInclusionStore.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ForcedInclusionStore *ForcedInclusionStoreCallerSession) Owner() (common.Address, error) {
	return _ForcedInclusionStore.Contract.Owner(&_ForcedInclusionStore.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_ForcedInclusionStore *ForcedInclusionStoreCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _ForcedInclusionStore.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_ForcedInclusionStore *ForcedInclusionStoreSession) Paused() (bool, error) {
	return _ForcedInclusionStore.Contract.Paused(&_ForcedInclusionStore.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_ForcedInclusionStore *ForcedInclusionStoreCallerSession) Paused() (bool, error) {
	return _ForcedInclusionStore.Contract.Paused(&_ForcedInclusionStore.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_ForcedInclusionStore *ForcedInclusionStoreCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ForcedInclusionStore.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_ForcedInclusionStore *ForcedInclusionStoreSession) PendingOwner() (common.Address, error) {
	return _ForcedInclusionStore.Contract.PendingOwner(&_ForcedInclusionStore.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_ForcedInclusionStore *ForcedInclusionStoreCallerSession) PendingOwner() (common.Address, error) {
	return _ForcedInclusionStore.Contract.PendingOwner(&_ForcedInclusionStore.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_ForcedInclusionStore *ForcedInclusionStoreCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _ForcedInclusionStore.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_ForcedInclusionStore *ForcedInclusionStoreSession) ProxiableUUID() ([32]byte, error) {
	return _ForcedInclusionStore.Contract.ProxiableUUID(&_ForcedInclusionStore.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_ForcedInclusionStore *ForcedInclusionStoreCallerSession) ProxiableUUID() ([32]byte, error) {
	return _ForcedInclusionStore.Contract.ProxiableUUID(&_ForcedInclusionStore.CallOpts)
}

// Queue is a free data retrieval call binding the contract method 0xddf0b009.
//
// Solidity: function queue(uint256 id) view returns(bytes32 blobHash, uint64 feeInGwei, uint64 createdAtBatchId, uint32 blobByteOffset, uint32 blobByteSize, uint64 blobCreatedIn)
func (_ForcedInclusionStore *ForcedInclusionStoreCaller) Queue(opts *bind.CallOpts, id *big.Int) (struct {
	BlobHash         [32]byte
	FeeInGwei        uint64
	CreatedAtBatchId uint64
	BlobByteOffset   uint32
	BlobByteSize     uint32
	BlobCreatedIn    uint64
}, error) {
	var out []interface{}
	err := _ForcedInclusionStore.contract.Call(opts, &out, "queue", id)

	outstruct := new(struct {
		BlobHash         [32]byte
		FeeInGwei        uint64
		CreatedAtBatchId uint64
		BlobByteOffset   uint32
		BlobByteSize     uint32
		BlobCreatedIn    uint64
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.BlobHash = *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)
	outstruct.FeeInGwei = *abi.ConvertType(out[1], new(uint64)).(*uint64)
	outstruct.CreatedAtBatchId = *abi.ConvertType(out[2], new(uint64)).(*uint64)
	outstruct.BlobByteOffset = *abi.ConvertType(out[3], new(uint32)).(*uint32)
	outstruct.BlobByteSize = *abi.ConvertType(out[4], new(uint32)).(*uint32)
	outstruct.BlobCreatedIn = *abi.ConvertType(out[5], new(uint64)).(*uint64)

	return *outstruct, err

}

// Queue is a free data retrieval call binding the contract method 0xddf0b009.
//
// Solidity: function queue(uint256 id) view returns(bytes32 blobHash, uint64 feeInGwei, uint64 createdAtBatchId, uint32 blobByteOffset, uint32 blobByteSize, uint64 blobCreatedIn)
func (_ForcedInclusionStore *ForcedInclusionStoreSession) Queue(id *big.Int) (struct {
	BlobHash         [32]byte
	FeeInGwei        uint64
	CreatedAtBatchId uint64
	BlobByteOffset   uint32
	BlobByteSize     uint32
	BlobCreatedIn    uint64
}, error) {
	return _ForcedInclusionStore.Contract.Queue(&_ForcedInclusionStore.CallOpts, id)
}

// Queue is a free data retrieval call binding the contract method 0xddf0b009.
//
// Solidity: function queue(uint256 id) view returns(bytes32 blobHash, uint64 feeInGwei, uint64 createdAtBatchId, uint32 blobByteOffset, uint32 blobByteSize, uint64 blobCreatedIn)
func (_ForcedInclusionStore *ForcedInclusionStoreCallerSession) Queue(id *big.Int) (struct {
	BlobHash         [32]byte
	FeeInGwei        uint64
	CreatedAtBatchId uint64
	BlobByteOffset   uint32
	BlobByteSize     uint32
	BlobCreatedIn    uint64
}, error) {
	return _ForcedInclusionStore.Contract.Queue(&_ForcedInclusionStore.CallOpts, id)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_ForcedInclusionStore *ForcedInclusionStoreCaller) Resolver(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ForcedInclusionStore.contract.Call(opts, &out, "resolver")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_ForcedInclusionStore *ForcedInclusionStoreSession) Resolver() (common.Address, error) {
	return _ForcedInclusionStore.Contract.Resolver(&_ForcedInclusionStore.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_ForcedInclusionStore *ForcedInclusionStoreCallerSession) Resolver() (common.Address, error) {
	return _ForcedInclusionStore.Contract.Resolver(&_ForcedInclusionStore.CallOpts)
}

// Tail is a free data retrieval call binding the contract method 0x13d8c840.
//
// Solidity: function tail() view returns(uint64)
func (_ForcedInclusionStore *ForcedInclusionStoreCaller) Tail(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _ForcedInclusionStore.contract.Call(opts, &out, "tail")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// Tail is a free data retrieval call binding the contract method 0x13d8c840.
//
// Solidity: function tail() view returns(uint64)
func (_ForcedInclusionStore *ForcedInclusionStoreSession) Tail() (uint64, error) {
	return _ForcedInclusionStore.Contract.Tail(&_ForcedInclusionStore.CallOpts)
}

// Tail is a free data retrieval call binding the contract method 0x13d8c840.
//
// Solidity: function tail() view returns(uint64)
func (_ForcedInclusionStore *ForcedInclusionStoreCallerSession) Tail() (uint64, error) {
	return _ForcedInclusionStore.Contract.Tail(&_ForcedInclusionStore.CallOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_ForcedInclusionStore *ForcedInclusionStoreTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ForcedInclusionStore.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_ForcedInclusionStore *ForcedInclusionStoreSession) AcceptOwnership() (*types.Transaction, error) {
	return _ForcedInclusionStore.Contract.AcceptOwnership(&_ForcedInclusionStore.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_ForcedInclusionStore *ForcedInclusionStoreTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _ForcedInclusionStore.Contract.AcceptOwnership(&_ForcedInclusionStore.TransactOpts)
}

// ConsumeOldestForcedInclusion is a paid mutator transaction binding the contract method 0x23524905.
//
// Solidity: function consumeOldestForcedInclusion(address _feeRecipient) returns((bytes32,uint64,uint64,uint32,uint32,uint64) inclusion_)
func (_ForcedInclusionStore *ForcedInclusionStoreTransactor) ConsumeOldestForcedInclusion(opts *bind.TransactOpts, _feeRecipient common.Address) (*types.Transaction, error) {
	return _ForcedInclusionStore.contract.Transact(opts, "consumeOldestForcedInclusion", _feeRecipient)
}

// ConsumeOldestForcedInclusion is a paid mutator transaction binding the contract method 0x23524905.
//
// Solidity: function consumeOldestForcedInclusion(address _feeRecipient) returns((bytes32,uint64,uint64,uint32,uint32,uint64) inclusion_)
func (_ForcedInclusionStore *ForcedInclusionStoreSession) ConsumeOldestForcedInclusion(_feeRecipient common.Address) (*types.Transaction, error) {
	return _ForcedInclusionStore.Contract.ConsumeOldestForcedInclusion(&_ForcedInclusionStore.TransactOpts, _feeRecipient)
}

// ConsumeOldestForcedInclusion is a paid mutator transaction binding the contract method 0x23524905.
//
// Solidity: function consumeOldestForcedInclusion(address _feeRecipient) returns((bytes32,uint64,uint64,uint32,uint32,uint64) inclusion_)
func (_ForcedInclusionStore *ForcedInclusionStoreTransactorSession) ConsumeOldestForcedInclusion(_feeRecipient common.Address) (*types.Transaction, error) {
	return _ForcedInclusionStore.Contract.ConsumeOldestForcedInclusion(&_ForcedInclusionStore.TransactOpts, _feeRecipient)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_ForcedInclusionStore *ForcedInclusionStoreTransactor) Init(opts *bind.TransactOpts, _owner common.Address) (*types.Transaction, error) {
	return _ForcedInclusionStore.contract.Transact(opts, "init", _owner)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_ForcedInclusionStore *ForcedInclusionStoreSession) Init(_owner common.Address) (*types.Transaction, error) {
	return _ForcedInclusionStore.Contract.Init(&_ForcedInclusionStore.TransactOpts, _owner)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_ForcedInclusionStore *ForcedInclusionStoreTransactorSession) Init(_owner common.Address) (*types.Transaction, error) {
	return _ForcedInclusionStore.Contract.Init(&_ForcedInclusionStore.TransactOpts, _owner)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_ForcedInclusionStore *ForcedInclusionStoreTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ForcedInclusionStore.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_ForcedInclusionStore *ForcedInclusionStoreSession) Pause() (*types.Transaction, error) {
	return _ForcedInclusionStore.Contract.Pause(&_ForcedInclusionStore.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_ForcedInclusionStore *ForcedInclusionStoreTransactorSession) Pause() (*types.Transaction, error) {
	return _ForcedInclusionStore.Contract.Pause(&_ForcedInclusionStore.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ForcedInclusionStore *ForcedInclusionStoreTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ForcedInclusionStore.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ForcedInclusionStore *ForcedInclusionStoreSession) RenounceOwnership() (*types.Transaction, error) {
	return _ForcedInclusionStore.Contract.RenounceOwnership(&_ForcedInclusionStore.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ForcedInclusionStore *ForcedInclusionStoreTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _ForcedInclusionStore.Contract.RenounceOwnership(&_ForcedInclusionStore.TransactOpts)
}

// StoreForcedInclusion is a paid mutator transaction binding the contract method 0x642c34fa.
//
// Solidity: function storeForcedInclusion(uint8 blobIndex, uint32 blobByteOffset, uint32 blobByteSize) payable returns()
func (_ForcedInclusionStore *ForcedInclusionStoreTransactor) StoreForcedInclusion(opts *bind.TransactOpts, blobIndex uint8, blobByteOffset uint32, blobByteSize uint32) (*types.Transaction, error) {
	return _ForcedInclusionStore.contract.Transact(opts, "storeForcedInclusion", blobIndex, blobByteOffset, blobByteSize)
}

// StoreForcedInclusion is a paid mutator transaction binding the contract method 0x642c34fa.
//
// Solidity: function storeForcedInclusion(uint8 blobIndex, uint32 blobByteOffset, uint32 blobByteSize) payable returns()
func (_ForcedInclusionStore *ForcedInclusionStoreSession) StoreForcedInclusion(blobIndex uint8, blobByteOffset uint32, blobByteSize uint32) (*types.Transaction, error) {
	return _ForcedInclusionStore.Contract.StoreForcedInclusion(&_ForcedInclusionStore.TransactOpts, blobIndex, blobByteOffset, blobByteSize)
}

// StoreForcedInclusion is a paid mutator transaction binding the contract method 0x642c34fa.
//
// Solidity: function storeForcedInclusion(uint8 blobIndex, uint32 blobByteOffset, uint32 blobByteSize) payable returns()
func (_ForcedInclusionStore *ForcedInclusionStoreTransactorSession) StoreForcedInclusion(blobIndex uint8, blobByteOffset uint32, blobByteSize uint32) (*types.Transaction, error) {
	return _ForcedInclusionStore.Contract.StoreForcedInclusion(&_ForcedInclusionStore.TransactOpts, blobIndex, blobByteOffset, blobByteSize)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ForcedInclusionStore *ForcedInclusionStoreTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _ForcedInclusionStore.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ForcedInclusionStore *ForcedInclusionStoreSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _ForcedInclusionStore.Contract.TransferOwnership(&_ForcedInclusionStore.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ForcedInclusionStore *ForcedInclusionStoreTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _ForcedInclusionStore.Contract.TransferOwnership(&_ForcedInclusionStore.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_ForcedInclusionStore *ForcedInclusionStoreTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ForcedInclusionStore.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_ForcedInclusionStore *ForcedInclusionStoreSession) Unpause() (*types.Transaction, error) {
	return _ForcedInclusionStore.Contract.Unpause(&_ForcedInclusionStore.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_ForcedInclusionStore *ForcedInclusionStoreTransactorSession) Unpause() (*types.Transaction, error) {
	return _ForcedInclusionStore.Contract.Unpause(&_ForcedInclusionStore.TransactOpts)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_ForcedInclusionStore *ForcedInclusionStoreTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _ForcedInclusionStore.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_ForcedInclusionStore *ForcedInclusionStoreSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _ForcedInclusionStore.Contract.UpgradeTo(&_ForcedInclusionStore.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_ForcedInclusionStore *ForcedInclusionStoreTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _ForcedInclusionStore.Contract.UpgradeTo(&_ForcedInclusionStore.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_ForcedInclusionStore *ForcedInclusionStoreTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _ForcedInclusionStore.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_ForcedInclusionStore *ForcedInclusionStoreSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _ForcedInclusionStore.Contract.UpgradeToAndCall(&_ForcedInclusionStore.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_ForcedInclusionStore *ForcedInclusionStoreTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _ForcedInclusionStore.Contract.UpgradeToAndCall(&_ForcedInclusionStore.TransactOpts, newImplementation, data)
}

// ForcedInclusionStoreAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the ForcedInclusionStore contract.
type ForcedInclusionStoreAdminChangedIterator struct {
	Event *ForcedInclusionStoreAdminChanged // Event containing the contract specifics and raw log

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
func (it *ForcedInclusionStoreAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ForcedInclusionStoreAdminChanged)
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
		it.Event = new(ForcedInclusionStoreAdminChanged)
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
func (it *ForcedInclusionStoreAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ForcedInclusionStoreAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ForcedInclusionStoreAdminChanged represents a AdminChanged event raised by the ForcedInclusionStore contract.
type ForcedInclusionStoreAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*ForcedInclusionStoreAdminChangedIterator, error) {

	logs, sub, err := _ForcedInclusionStore.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &ForcedInclusionStoreAdminChangedIterator{contract: _ForcedInclusionStore.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *ForcedInclusionStoreAdminChanged) (event.Subscription, error) {

	logs, sub, err := _ForcedInclusionStore.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ForcedInclusionStoreAdminChanged)
				if err := _ForcedInclusionStore.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) ParseAdminChanged(log types.Log) (*ForcedInclusionStoreAdminChanged, error) {
	event := new(ForcedInclusionStoreAdminChanged)
	if err := _ForcedInclusionStore.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ForcedInclusionStoreBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the ForcedInclusionStore contract.
type ForcedInclusionStoreBeaconUpgradedIterator struct {
	Event *ForcedInclusionStoreBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *ForcedInclusionStoreBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ForcedInclusionStoreBeaconUpgraded)
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
		it.Event = new(ForcedInclusionStoreBeaconUpgraded)
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
func (it *ForcedInclusionStoreBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ForcedInclusionStoreBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ForcedInclusionStoreBeaconUpgraded represents a BeaconUpgraded event raised by the ForcedInclusionStore contract.
type ForcedInclusionStoreBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*ForcedInclusionStoreBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _ForcedInclusionStore.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &ForcedInclusionStoreBeaconUpgradedIterator{contract: _ForcedInclusionStore.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *ForcedInclusionStoreBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _ForcedInclusionStore.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ForcedInclusionStoreBeaconUpgraded)
				if err := _ForcedInclusionStore.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) ParseBeaconUpgraded(log types.Log) (*ForcedInclusionStoreBeaconUpgraded, error) {
	event := new(ForcedInclusionStoreBeaconUpgraded)
	if err := _ForcedInclusionStore.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ForcedInclusionStoreForcedInclusionConsumedIterator is returned from FilterForcedInclusionConsumed and is used to iterate over the raw logs and unpacked data for ForcedInclusionConsumed events raised by the ForcedInclusionStore contract.
type ForcedInclusionStoreForcedInclusionConsumedIterator struct {
	Event *ForcedInclusionStoreForcedInclusionConsumed // Event containing the contract specifics and raw log

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
func (it *ForcedInclusionStoreForcedInclusionConsumedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ForcedInclusionStoreForcedInclusionConsumed)
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
		it.Event = new(ForcedInclusionStoreForcedInclusionConsumed)
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
func (it *ForcedInclusionStoreForcedInclusionConsumedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ForcedInclusionStoreForcedInclusionConsumedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ForcedInclusionStoreForcedInclusionConsumed represents a ForcedInclusionConsumed event raised by the ForcedInclusionStore contract.
type ForcedInclusionStoreForcedInclusionConsumed struct {
	ForcedInclusion IForcedInclusionStoreForcedInclusion
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterForcedInclusionConsumed is a free log retrieval operation binding the contract event 0xf809dd2f6c75fbd4675267b566cae3fc3091966f0efbfca97341e5c7eb9a4fe4.
//
// Solidity: event ForcedInclusionConsumed((bytes32,uint64,uint64,uint32,uint32,uint64) forcedInclusion)
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) FilterForcedInclusionConsumed(opts *bind.FilterOpts) (*ForcedInclusionStoreForcedInclusionConsumedIterator, error) {

	logs, sub, err := _ForcedInclusionStore.contract.FilterLogs(opts, "ForcedInclusionConsumed")
	if err != nil {
		return nil, err
	}
	return &ForcedInclusionStoreForcedInclusionConsumedIterator{contract: _ForcedInclusionStore.contract, event: "ForcedInclusionConsumed", logs: logs, sub: sub}, nil
}

// WatchForcedInclusionConsumed is a free log subscription operation binding the contract event 0xf809dd2f6c75fbd4675267b566cae3fc3091966f0efbfca97341e5c7eb9a4fe4.
//
// Solidity: event ForcedInclusionConsumed((bytes32,uint64,uint64,uint32,uint32,uint64) forcedInclusion)
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) WatchForcedInclusionConsumed(opts *bind.WatchOpts, sink chan<- *ForcedInclusionStoreForcedInclusionConsumed) (event.Subscription, error) {

	logs, sub, err := _ForcedInclusionStore.contract.WatchLogs(opts, "ForcedInclusionConsumed")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ForcedInclusionStoreForcedInclusionConsumed)
				if err := _ForcedInclusionStore.contract.UnpackLog(event, "ForcedInclusionConsumed", log); err != nil {
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

// ParseForcedInclusionConsumed is a log parse operation binding the contract event 0xf809dd2f6c75fbd4675267b566cae3fc3091966f0efbfca97341e5c7eb9a4fe4.
//
// Solidity: event ForcedInclusionConsumed((bytes32,uint64,uint64,uint32,uint32,uint64) forcedInclusion)
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) ParseForcedInclusionConsumed(log types.Log) (*ForcedInclusionStoreForcedInclusionConsumed, error) {
	event := new(ForcedInclusionStoreForcedInclusionConsumed)
	if err := _ForcedInclusionStore.contract.UnpackLog(event, "ForcedInclusionConsumed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ForcedInclusionStoreForcedInclusionStoredIterator is returned from FilterForcedInclusionStored and is used to iterate over the raw logs and unpacked data for ForcedInclusionStored events raised by the ForcedInclusionStore contract.
type ForcedInclusionStoreForcedInclusionStoredIterator struct {
	Event *ForcedInclusionStoreForcedInclusionStored // Event containing the contract specifics and raw log

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
func (it *ForcedInclusionStoreForcedInclusionStoredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ForcedInclusionStoreForcedInclusionStored)
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
		it.Event = new(ForcedInclusionStoreForcedInclusionStored)
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
func (it *ForcedInclusionStoreForcedInclusionStoredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ForcedInclusionStoreForcedInclusionStoredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ForcedInclusionStoreForcedInclusionStored represents a ForcedInclusionStored event raised by the ForcedInclusionStore contract.
type ForcedInclusionStoreForcedInclusionStored struct {
	ForcedInclusion IForcedInclusionStoreForcedInclusion
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterForcedInclusionStored is a free log retrieval operation binding the contract event 0xae657aef29b5c692a97f741e24336b517560eaafaaf57dfafc0a24781b631ff1.
//
// Solidity: event ForcedInclusionStored((bytes32,uint64,uint64,uint32,uint32,uint64) forcedInclusion)
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) FilterForcedInclusionStored(opts *bind.FilterOpts) (*ForcedInclusionStoreForcedInclusionStoredIterator, error) {

	logs, sub, err := _ForcedInclusionStore.contract.FilterLogs(opts, "ForcedInclusionStored")
	if err != nil {
		return nil, err
	}
	return &ForcedInclusionStoreForcedInclusionStoredIterator{contract: _ForcedInclusionStore.contract, event: "ForcedInclusionStored", logs: logs, sub: sub}, nil
}

// WatchForcedInclusionStored is a free log subscription operation binding the contract event 0xae657aef29b5c692a97f741e24336b517560eaafaaf57dfafc0a24781b631ff1.
//
// Solidity: event ForcedInclusionStored((bytes32,uint64,uint64,uint32,uint32,uint64) forcedInclusion)
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) WatchForcedInclusionStored(opts *bind.WatchOpts, sink chan<- *ForcedInclusionStoreForcedInclusionStored) (event.Subscription, error) {

	logs, sub, err := _ForcedInclusionStore.contract.WatchLogs(opts, "ForcedInclusionStored")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ForcedInclusionStoreForcedInclusionStored)
				if err := _ForcedInclusionStore.contract.UnpackLog(event, "ForcedInclusionStored", log); err != nil {
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

// ParseForcedInclusionStored is a log parse operation binding the contract event 0xae657aef29b5c692a97f741e24336b517560eaafaaf57dfafc0a24781b631ff1.
//
// Solidity: event ForcedInclusionStored((bytes32,uint64,uint64,uint32,uint32,uint64) forcedInclusion)
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) ParseForcedInclusionStored(log types.Log) (*ForcedInclusionStoreForcedInclusionStored, error) {
	event := new(ForcedInclusionStoreForcedInclusionStored)
	if err := _ForcedInclusionStore.contract.UnpackLog(event, "ForcedInclusionStored", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ForcedInclusionStoreInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the ForcedInclusionStore contract.
type ForcedInclusionStoreInitializedIterator struct {
	Event *ForcedInclusionStoreInitialized // Event containing the contract specifics and raw log

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
func (it *ForcedInclusionStoreInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ForcedInclusionStoreInitialized)
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
		it.Event = new(ForcedInclusionStoreInitialized)
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
func (it *ForcedInclusionStoreInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ForcedInclusionStoreInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ForcedInclusionStoreInitialized represents a Initialized event raised by the ForcedInclusionStore contract.
type ForcedInclusionStoreInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) FilterInitialized(opts *bind.FilterOpts) (*ForcedInclusionStoreInitializedIterator, error) {

	logs, sub, err := _ForcedInclusionStore.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &ForcedInclusionStoreInitializedIterator{contract: _ForcedInclusionStore.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *ForcedInclusionStoreInitialized) (event.Subscription, error) {

	logs, sub, err := _ForcedInclusionStore.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ForcedInclusionStoreInitialized)
				if err := _ForcedInclusionStore.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) ParseInitialized(log types.Log) (*ForcedInclusionStoreInitialized, error) {
	event := new(ForcedInclusionStoreInitialized)
	if err := _ForcedInclusionStore.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ForcedInclusionStoreOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the ForcedInclusionStore contract.
type ForcedInclusionStoreOwnershipTransferStartedIterator struct {
	Event *ForcedInclusionStoreOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *ForcedInclusionStoreOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ForcedInclusionStoreOwnershipTransferStarted)
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
		it.Event = new(ForcedInclusionStoreOwnershipTransferStarted)
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
func (it *ForcedInclusionStoreOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ForcedInclusionStoreOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ForcedInclusionStoreOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the ForcedInclusionStore contract.
type ForcedInclusionStoreOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*ForcedInclusionStoreOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ForcedInclusionStore.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &ForcedInclusionStoreOwnershipTransferStartedIterator{contract: _ForcedInclusionStore.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *ForcedInclusionStoreOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ForcedInclusionStore.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ForcedInclusionStoreOwnershipTransferStarted)
				if err := _ForcedInclusionStore.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) ParseOwnershipTransferStarted(log types.Log) (*ForcedInclusionStoreOwnershipTransferStarted, error) {
	event := new(ForcedInclusionStoreOwnershipTransferStarted)
	if err := _ForcedInclusionStore.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ForcedInclusionStoreOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the ForcedInclusionStore contract.
type ForcedInclusionStoreOwnershipTransferredIterator struct {
	Event *ForcedInclusionStoreOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *ForcedInclusionStoreOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ForcedInclusionStoreOwnershipTransferred)
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
		it.Event = new(ForcedInclusionStoreOwnershipTransferred)
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
func (it *ForcedInclusionStoreOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ForcedInclusionStoreOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ForcedInclusionStoreOwnershipTransferred represents a OwnershipTransferred event raised by the ForcedInclusionStore contract.
type ForcedInclusionStoreOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*ForcedInclusionStoreOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ForcedInclusionStore.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &ForcedInclusionStoreOwnershipTransferredIterator{contract: _ForcedInclusionStore.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *ForcedInclusionStoreOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ForcedInclusionStore.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ForcedInclusionStoreOwnershipTransferred)
				if err := _ForcedInclusionStore.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) ParseOwnershipTransferred(log types.Log) (*ForcedInclusionStoreOwnershipTransferred, error) {
	event := new(ForcedInclusionStoreOwnershipTransferred)
	if err := _ForcedInclusionStore.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ForcedInclusionStorePausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the ForcedInclusionStore contract.
type ForcedInclusionStorePausedIterator struct {
	Event *ForcedInclusionStorePaused // Event containing the contract specifics and raw log

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
func (it *ForcedInclusionStorePausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ForcedInclusionStorePaused)
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
		it.Event = new(ForcedInclusionStorePaused)
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
func (it *ForcedInclusionStorePausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ForcedInclusionStorePausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ForcedInclusionStorePaused represents a Paused event raised by the ForcedInclusionStore contract.
type ForcedInclusionStorePaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) FilterPaused(opts *bind.FilterOpts) (*ForcedInclusionStorePausedIterator, error) {

	logs, sub, err := _ForcedInclusionStore.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &ForcedInclusionStorePausedIterator{contract: _ForcedInclusionStore.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *ForcedInclusionStorePaused) (event.Subscription, error) {

	logs, sub, err := _ForcedInclusionStore.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ForcedInclusionStorePaused)
				if err := _ForcedInclusionStore.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) ParsePaused(log types.Log) (*ForcedInclusionStorePaused, error) {
	event := new(ForcedInclusionStorePaused)
	if err := _ForcedInclusionStore.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ForcedInclusionStoreUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the ForcedInclusionStore contract.
type ForcedInclusionStoreUnpausedIterator struct {
	Event *ForcedInclusionStoreUnpaused // Event containing the contract specifics and raw log

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
func (it *ForcedInclusionStoreUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ForcedInclusionStoreUnpaused)
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
		it.Event = new(ForcedInclusionStoreUnpaused)
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
func (it *ForcedInclusionStoreUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ForcedInclusionStoreUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ForcedInclusionStoreUnpaused represents a Unpaused event raised by the ForcedInclusionStore contract.
type ForcedInclusionStoreUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) FilterUnpaused(opts *bind.FilterOpts) (*ForcedInclusionStoreUnpausedIterator, error) {

	logs, sub, err := _ForcedInclusionStore.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &ForcedInclusionStoreUnpausedIterator{contract: _ForcedInclusionStore.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *ForcedInclusionStoreUnpaused) (event.Subscription, error) {

	logs, sub, err := _ForcedInclusionStore.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ForcedInclusionStoreUnpaused)
				if err := _ForcedInclusionStore.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) ParseUnpaused(log types.Log) (*ForcedInclusionStoreUnpaused, error) {
	event := new(ForcedInclusionStoreUnpaused)
	if err := _ForcedInclusionStore.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ForcedInclusionStoreUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the ForcedInclusionStore contract.
type ForcedInclusionStoreUpgradedIterator struct {
	Event *ForcedInclusionStoreUpgraded // Event containing the contract specifics and raw log

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
func (it *ForcedInclusionStoreUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ForcedInclusionStoreUpgraded)
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
		it.Event = new(ForcedInclusionStoreUpgraded)
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
func (it *ForcedInclusionStoreUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ForcedInclusionStoreUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ForcedInclusionStoreUpgraded represents a Upgraded event raised by the ForcedInclusionStore contract.
type ForcedInclusionStoreUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*ForcedInclusionStoreUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _ForcedInclusionStore.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &ForcedInclusionStoreUpgradedIterator{contract: _ForcedInclusionStore.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *ForcedInclusionStoreUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _ForcedInclusionStore.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ForcedInclusionStoreUpgraded)
				if err := _ForcedInclusionStore.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_ForcedInclusionStore *ForcedInclusionStoreFilterer) ParseUpgraded(log types.Log) (*ForcedInclusionStoreUpgraded, error) {
	event := new(ForcedInclusionStoreUpgraded)
	if err := _ForcedInclusionStore.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
