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

// ResolverBaseMetaData contains all meta data concerning the ResolverBase contract.
var ResolverBaseMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"resolve\",\"inputs\":[{\"name\":\"_chainId\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_allowZeroAddress\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"addr_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"RESOLVED_TO_ZERO_ADDRESS\",\"inputs\":[]}]",
}

// ResolverBaseABI is the input ABI used to generate the binding from.
// Deprecated: Use ResolverBaseMetaData.ABI instead.
var ResolverBaseABI = ResolverBaseMetaData.ABI

// ResolverBase is an auto generated Go binding around an Ethereum contract.
type ResolverBase struct {
	ResolverBaseCaller     // Read-only binding to the contract
	ResolverBaseTransactor // Write-only binding to the contract
	ResolverBaseFilterer   // Log filterer for contract events
}

// ResolverBaseCaller is an auto generated read-only Go binding around an Ethereum contract.
type ResolverBaseCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ResolverBaseTransactor is an auto generated write-only Go binding around an Ethereum contract.
type ResolverBaseTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ResolverBaseFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type ResolverBaseFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ResolverBaseSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type ResolverBaseSession struct {
	Contract     *ResolverBase     // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// ResolverBaseCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type ResolverBaseCallerSession struct {
	Contract *ResolverBaseCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts       // Call options to use throughout this session
}

// ResolverBaseTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type ResolverBaseTransactorSession struct {
	Contract     *ResolverBaseTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts       // Transaction auth options to use throughout this session
}

// ResolverBaseRaw is an auto generated low-level Go binding around an Ethereum contract.
type ResolverBaseRaw struct {
	Contract *ResolverBase // Generic contract binding to access the raw methods on
}

// ResolverBaseCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type ResolverBaseCallerRaw struct {
	Contract *ResolverBaseCaller // Generic read-only contract binding to access the raw methods on
}

// ResolverBaseTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type ResolverBaseTransactorRaw struct {
	Contract *ResolverBaseTransactor // Generic write-only contract binding to access the raw methods on
}

// NewResolverBase creates a new instance of ResolverBase, bound to a specific deployed contract.
func NewResolverBase(address common.Address, backend bind.ContractBackend) (*ResolverBase, error) {
	contract, err := bindResolverBase(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &ResolverBase{ResolverBaseCaller: ResolverBaseCaller{contract: contract}, ResolverBaseTransactor: ResolverBaseTransactor{contract: contract}, ResolverBaseFilterer: ResolverBaseFilterer{contract: contract}}, nil
}

// NewResolverBaseCaller creates a new read-only instance of ResolverBase, bound to a specific deployed contract.
func NewResolverBaseCaller(address common.Address, caller bind.ContractCaller) (*ResolverBaseCaller, error) {
	contract, err := bindResolverBase(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &ResolverBaseCaller{contract: contract}, nil
}

// NewResolverBaseTransactor creates a new write-only instance of ResolverBase, bound to a specific deployed contract.
func NewResolverBaseTransactor(address common.Address, transactor bind.ContractTransactor) (*ResolverBaseTransactor, error) {
	contract, err := bindResolverBase(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &ResolverBaseTransactor{contract: contract}, nil
}

// NewResolverBaseFilterer creates a new log filterer instance of ResolverBase, bound to a specific deployed contract.
func NewResolverBaseFilterer(address common.Address, filterer bind.ContractFilterer) (*ResolverBaseFilterer, error) {
	contract, err := bindResolverBase(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &ResolverBaseFilterer{contract: contract}, nil
}

// bindResolverBase binds a generic wrapper to an already deployed contract.
func bindResolverBase(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := ResolverBaseMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ResolverBase *ResolverBaseRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ResolverBase.Contract.ResolverBaseCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ResolverBase *ResolverBaseRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ResolverBase.Contract.ResolverBaseTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ResolverBase *ResolverBaseRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ResolverBase.Contract.ResolverBaseTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ResolverBase *ResolverBaseCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ResolverBase.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ResolverBase *ResolverBaseTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ResolverBase.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ResolverBase *ResolverBaseTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ResolverBase.Contract.contract.Transact(opts, method, params...)
}

// Resolve is a free data retrieval call binding the contract method 0x6c6563f6.
//
// Solidity: function resolve(uint256 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address addr_)
func (_ResolverBase *ResolverBaseCaller) Resolve(opts *bind.CallOpts, _chainId *big.Int, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _ResolverBase.contract.Call(opts, &out, "resolve", _chainId, _name, _allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve is a free data retrieval call binding the contract method 0x6c6563f6.
//
// Solidity: function resolve(uint256 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address addr_)
func (_ResolverBase *ResolverBaseSession) Resolve(_chainId *big.Int, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _ResolverBase.Contract.Resolve(&_ResolverBase.CallOpts, _chainId, _name, _allowZeroAddress)
}

// Resolve is a free data retrieval call binding the contract method 0x6c6563f6.
//
// Solidity: function resolve(uint256 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address addr_)
func (_ResolverBase *ResolverBaseCallerSession) Resolve(_chainId *big.Int, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _ResolverBase.Contract.Resolve(&_ResolverBase.CallOpts, _chainId, _name, _allowZeroAddress)
}
