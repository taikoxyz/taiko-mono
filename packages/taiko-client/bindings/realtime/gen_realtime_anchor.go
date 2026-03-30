// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package realtime

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

// AnchorBlockState is an auto generated low-level Go binding around an user-defined struct.
type AnchorBlockState struct {
	AnchorBlockNumber *big.Int
	AncestorsHash     [32]byte
}

// RealTimeAnchorMetaData contains all meta data concerning the RealTimeAnchor contract.
var RealTimeAnchorMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"GOLDEN_TOUCH_ADDRESS\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"anchorV4WithSignalSlots\",\"inputs\":[{\"name\":\"_checkpoint\",\"type\":\"tuple\",\"internalType\":\"struct ICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"_signalSlots\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"getBlockState\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structAnchor.BlockState\",\"components\":[{\"name\":\"anchorBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"ancestorsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"stateMutability\":\"view\"}]",
}

// RealTimeAnchorABI is the input ABI used to generate the binding from.
// Deprecated: Use RealTimeAnchorMetaData.ABI instead.
var RealTimeAnchorABI = RealTimeAnchorMetaData.ABI

// RealTimeAnchor is an auto generated Go binding around an Ethereum contract.
type RealTimeAnchor struct {
	RealTimeAnchorCaller     // Read-only binding to the contract
	RealTimeAnchorTransactor // Write-only binding to the contract
	RealTimeAnchorFilterer   // Log filterer for contract events
}

// RealTimeAnchorCaller is an auto generated read-only Go binding around an Ethereum contract.
type RealTimeAnchorCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// RealTimeAnchorTransactor is an auto generated write-only Go binding around an Ethereum contract.
type RealTimeAnchorTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// RealTimeAnchorFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type RealTimeAnchorFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// RealTimeAnchorRaw is an auto generated low-level Go binding around an Ethereum contract.
type RealTimeAnchorRaw struct {
	Contract *RealTimeAnchor // Generic contract binding to access the raw methods on
}

// RealTimeAnchorCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type RealTimeAnchorCallerRaw struct {
	Contract *RealTimeAnchorCaller // Generic read-only contract binding to access the raw methods on
}

// RealTimeAnchorTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type RealTimeAnchorTransactorRaw struct {
	Contract *RealTimeAnchorTransactor // Generic write-only contract binding to access the raw methods on
}

// NewRealTimeAnchor creates a new instance of RealTimeAnchor, bound to a specific deployed contract.
func NewRealTimeAnchor(address common.Address, backend bind.ContractBackend) (*RealTimeAnchor, error) {
	contract, err := bindRealTimeAnchor(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &RealTimeAnchor{RealTimeAnchorCaller: RealTimeAnchorCaller{contract: contract}, RealTimeAnchorTransactor: RealTimeAnchorTransactor{contract: contract}, RealTimeAnchorFilterer: RealTimeAnchorFilterer{contract: contract}}, nil
}

// NewRealTimeAnchorCaller creates a new read-only instance of RealTimeAnchor, bound to a specific deployed contract.
func NewRealTimeAnchorCaller(address common.Address, caller bind.ContractCaller) (*RealTimeAnchorCaller, error) {
	contract, err := bindRealTimeAnchor(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &RealTimeAnchorCaller{contract: contract}, nil
}

// NewRealTimeAnchorTransactor creates a new write-only instance of RealTimeAnchor, bound to a specific deployed contract.
func NewRealTimeAnchorTransactor(address common.Address, transactor bind.ContractTransactor) (*RealTimeAnchorTransactor, error) {
	contract, err := bindRealTimeAnchor(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &RealTimeAnchorTransactor{contract: contract}, nil
}

// NewRealTimeAnchorFilterer creates a new log filterer instance of RealTimeAnchor, bound to a specific deployed contract.
func NewRealTimeAnchorFilterer(address common.Address, filterer bind.ContractFilterer) (*RealTimeAnchorFilterer, error) {
	contract, err := bindRealTimeAnchor(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &RealTimeAnchorFilterer{contract: contract}, nil
}

// bindRealTimeAnchor binds a generic wrapper to an already deployed contract.
func bindRealTimeAnchor(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := RealTimeAnchorMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_RealTimeAnchor *RealTimeAnchorRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _RealTimeAnchor.Contract.RealTimeAnchorCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_RealTimeAnchor *RealTimeAnchorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _RealTimeAnchor.Contract.RealTimeAnchorTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_RealTimeAnchor *RealTimeAnchorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _RealTimeAnchor.Contract.RealTimeAnchorTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_RealTimeAnchor *RealTimeAnchorCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _RealTimeAnchor.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_RealTimeAnchor *RealTimeAnchorTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _RealTimeAnchor.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_RealTimeAnchor *RealTimeAnchorTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _RealTimeAnchor.Contract.contract.Transact(opts, method, params...)
}

// GOLDENTOUCHADDRESS is a free data retrieval call binding the contract method 0x9ee512f2.
//
// Solidity: function GOLDEN_TOUCH_ADDRESS() view returns(address)
func (_RealTimeAnchor *RealTimeAnchorCaller) GOLDENTOUCHADDRESS(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _RealTimeAnchor.contract.Call(opts, &out, "GOLDEN_TOUCH_ADDRESS")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err
}

// GetBlockState is a free data retrieval call binding the contract method 0x0f439bd9.
//
// Solidity: function getBlockState() view returns((uint48,bytes32))
func (_RealTimeAnchor *RealTimeAnchorCaller) GetBlockState(opts *bind.CallOpts) (AnchorBlockState, error) {
	var out []interface{}
	err := _RealTimeAnchor.contract.Call(opts, &out, "getBlockState")

	if err != nil {
		return *new(AnchorBlockState), err
	}

	out0 := *abi.ConvertType(out[0], new(AnchorBlockState)).(*AnchorBlockState)

	return out0, err
}

// AnchorV4WithSignalSlots is a paid mutator transaction binding the contract method.
//
// Solidity: function anchorV4WithSignalSlots((uint48,bytes32,bytes32) _checkpoint, bytes32[] _signalSlots) returns()
func (_RealTimeAnchor *RealTimeAnchorTransactor) AnchorV4WithSignalSlots(opts *bind.TransactOpts, _checkpoint ICheckpointStoreCheckpoint, _signalSlots [][32]byte) (*types.Transaction, error) {
	return _RealTimeAnchor.contract.Transact(opts, "anchorV4WithSignalSlots", _checkpoint, _signalSlots)
}
