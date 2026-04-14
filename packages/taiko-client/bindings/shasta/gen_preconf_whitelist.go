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

// PreconfWhitelistMetaData contains all meta data concerning the PreconfWhitelist contract.
var PreconfWhitelistMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"_ejectorManagerAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"OPERATOR_CHANGE_DELAY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"RANDOMNESS_DELAY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"addOperator\",\"inputs\":[{\"name\":\"_proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_sequencer\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"checkProposer\",\"inputs\":[{\"name\":\"_proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"endOfSubmissionWindowTimestamp_\",\"type\":\"uint48\",\"internalType\":\"uint48\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ejecters\",\"inputs\":[{\"name\":\"ejecter\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"isEjecter\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"epochStartTimestamp\",\"inputs\":[{\"name\":\"_offset\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint32\",\"internalType\":\"uint32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getOperatorForCurrentEpoch\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getOperatorForNextEpoch\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"impl\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inNonReentrant\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isOperatorActive\",\"inputs\":[{\"name\":\"_proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_epochTimestamp\",\"type\":\"uint32\",\"internalType\":\"uint32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"latestActivationEpoch\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint32\",\"internalType\":\"uint32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"operatorCount\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint8\",\"internalType\":\"uint8\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"operatorMapping\",\"inputs\":[{\"name\":\"index\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"operators\",\"inputs\":[{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"activeSince\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"deprecatedInactiveSince\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"index\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sequencerAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"removeOperator\",\"inputs\":[{\"name\":\"_operatorIndex\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"removeOperatorByAddress\",\"inputs\":[{\"name\":\"_proposer\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolver\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"setEjecter\",\"inputs\":[{\"name\":\"_ejecter\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_isEjecter\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"EjecterUpdated\",\"inputs\":[{\"name\":\"ejecter\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"isEjecter\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OperatorAdded\",\"inputs\":[{\"name\":\"proposer\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"sequencer\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"activeSince\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OperatorRemoved\",\"inputs\":[{\"name\":\"proposer\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"sequencer\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"inactiveSince\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCESS_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CannotRemoveLastOperator\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FUNC_NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidEjectorManager\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidOperatorAddress\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidOperatorIndex\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidProposer\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NoActiveOperatorRemaining\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotOwnerOrEjecter\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotOwnerOrEjectorManager\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"OperatorAlreadyExists\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_VALUE\",\"inputs\":[]}]",
}

// PreconfWhitelistABI is the input ABI used to generate the binding from.
// Deprecated: Use PreconfWhitelistMetaData.ABI instead.
var PreconfWhitelistABI = PreconfWhitelistMetaData.ABI

// PreconfWhitelist is an auto generated Go binding around an Ethereum contract.
type PreconfWhitelist struct {
	PreconfWhitelistCaller     // Read-only binding to the contract
	PreconfWhitelistTransactor // Write-only binding to the contract
	PreconfWhitelistFilterer   // Log filterer for contract events
}

// PreconfWhitelistCaller is an auto generated read-only Go binding around an Ethereum contract.
type PreconfWhitelistCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// PreconfWhitelistTransactor is an auto generated write-only Go binding around an Ethereum contract.
type PreconfWhitelistTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// PreconfWhitelistFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type PreconfWhitelistFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// PreconfWhitelistSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type PreconfWhitelistSession struct {
	Contract     *PreconfWhitelist // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// PreconfWhitelistCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type PreconfWhitelistCallerSession struct {
	Contract *PreconfWhitelistCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts           // Call options to use throughout this session
}

// PreconfWhitelistTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type PreconfWhitelistTransactorSession struct {
	Contract     *PreconfWhitelistTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts           // Transaction auth options to use throughout this session
}

// PreconfWhitelistRaw is an auto generated low-level Go binding around an Ethereum contract.
type PreconfWhitelistRaw struct {
	Contract *PreconfWhitelist // Generic contract binding to access the raw methods on
}

// PreconfWhitelistCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type PreconfWhitelistCallerRaw struct {
	Contract *PreconfWhitelistCaller // Generic read-only contract binding to access the raw methods on
}

// PreconfWhitelistTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type PreconfWhitelistTransactorRaw struct {
	Contract *PreconfWhitelistTransactor // Generic write-only contract binding to access the raw methods on
}

// NewPreconfWhitelist creates a new instance of PreconfWhitelist, bound to a specific deployed contract.
func NewPreconfWhitelist(address common.Address, backend bind.ContractBackend) (*PreconfWhitelist, error) {
	contract, err := bindPreconfWhitelist(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &PreconfWhitelist{PreconfWhitelistCaller: PreconfWhitelistCaller{contract: contract}, PreconfWhitelistTransactor: PreconfWhitelistTransactor{contract: contract}, PreconfWhitelistFilterer: PreconfWhitelistFilterer{contract: contract}}, nil
}

// NewPreconfWhitelistCaller creates a new read-only instance of PreconfWhitelist, bound to a specific deployed contract.
func NewPreconfWhitelistCaller(address common.Address, caller bind.ContractCaller) (*PreconfWhitelistCaller, error) {
	contract, err := bindPreconfWhitelist(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &PreconfWhitelistCaller{contract: contract}, nil
}

// NewPreconfWhitelistTransactor creates a new write-only instance of PreconfWhitelist, bound to a specific deployed contract.
func NewPreconfWhitelistTransactor(address common.Address, transactor bind.ContractTransactor) (*PreconfWhitelistTransactor, error) {
	contract, err := bindPreconfWhitelist(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &PreconfWhitelistTransactor{contract: contract}, nil
}

// NewPreconfWhitelistFilterer creates a new log filterer instance of PreconfWhitelist, bound to a specific deployed contract.
func NewPreconfWhitelistFilterer(address common.Address, filterer bind.ContractFilterer) (*PreconfWhitelistFilterer, error) {
	contract, err := bindPreconfWhitelist(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &PreconfWhitelistFilterer{contract: contract}, nil
}

// bindPreconfWhitelist binds a generic wrapper to an already deployed contract.
func bindPreconfWhitelist(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := PreconfWhitelistMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_PreconfWhitelist *PreconfWhitelistRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _PreconfWhitelist.Contract.PreconfWhitelistCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_PreconfWhitelist *PreconfWhitelistRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.PreconfWhitelistTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_PreconfWhitelist *PreconfWhitelistRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.PreconfWhitelistTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_PreconfWhitelist *PreconfWhitelistCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _PreconfWhitelist.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_PreconfWhitelist *PreconfWhitelistTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_PreconfWhitelist *PreconfWhitelistTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.contract.Transact(opts, method, params...)
}

// OPERATORCHANGEDELAY is a free data retrieval call binding the contract method 0xf96214de.
//
// Solidity: function OPERATOR_CHANGE_DELAY() view returns(uint8)
func (_PreconfWhitelist *PreconfWhitelistCaller) OPERATORCHANGEDELAY(opts *bind.CallOpts) (uint8, error) {
	var out []interface{}
	err := _PreconfWhitelist.contract.Call(opts, &out, "OPERATOR_CHANGE_DELAY")

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// OPERATORCHANGEDELAY is a free data retrieval call binding the contract method 0xf96214de.
//
// Solidity: function OPERATOR_CHANGE_DELAY() view returns(uint8)
func (_PreconfWhitelist *PreconfWhitelistSession) OPERATORCHANGEDELAY() (uint8, error) {
	return _PreconfWhitelist.Contract.OPERATORCHANGEDELAY(&_PreconfWhitelist.CallOpts)
}

// OPERATORCHANGEDELAY is a free data retrieval call binding the contract method 0xf96214de.
//
// Solidity: function OPERATOR_CHANGE_DELAY() view returns(uint8)
func (_PreconfWhitelist *PreconfWhitelistCallerSession) OPERATORCHANGEDELAY() (uint8, error) {
	return _PreconfWhitelist.Contract.OPERATORCHANGEDELAY(&_PreconfWhitelist.CallOpts)
}

// RANDOMNESSDELAY is a free data retrieval call binding the contract method 0x2fb17ffc.
//
// Solidity: function RANDOMNESS_DELAY() view returns(uint8)
func (_PreconfWhitelist *PreconfWhitelistCaller) RANDOMNESSDELAY(opts *bind.CallOpts) (uint8, error) {
	var out []interface{}
	err := _PreconfWhitelist.contract.Call(opts, &out, "RANDOMNESS_DELAY")

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// RANDOMNESSDELAY is a free data retrieval call binding the contract method 0x2fb17ffc.
//
// Solidity: function RANDOMNESS_DELAY() view returns(uint8)
func (_PreconfWhitelist *PreconfWhitelistSession) RANDOMNESSDELAY() (uint8, error) {
	return _PreconfWhitelist.Contract.RANDOMNESSDELAY(&_PreconfWhitelist.CallOpts)
}

// RANDOMNESSDELAY is a free data retrieval call binding the contract method 0x2fb17ffc.
//
// Solidity: function RANDOMNESS_DELAY() view returns(uint8)
func (_PreconfWhitelist *PreconfWhitelistCallerSession) RANDOMNESSDELAY() (uint8, error) {
	return _PreconfWhitelist.Contract.RANDOMNESSDELAY(&_PreconfWhitelist.CallOpts)
}

// CheckProposer is a free data retrieval call binding the contract method 0xac0004da.
//
// Solidity: function checkProposer(address _proposer, bytes ) view returns(uint48 endOfSubmissionWindowTimestamp_)
func (_PreconfWhitelist *PreconfWhitelistCaller) CheckProposer(opts *bind.CallOpts, _proposer common.Address, arg1 []byte) (*big.Int, error) {
	var out []interface{}
	err := _PreconfWhitelist.contract.Call(opts, &out, "checkProposer", _proposer, arg1)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// CheckProposer is a free data retrieval call binding the contract method 0xac0004da.
//
// Solidity: function checkProposer(address _proposer, bytes ) view returns(uint48 endOfSubmissionWindowTimestamp_)
func (_PreconfWhitelist *PreconfWhitelistSession) CheckProposer(_proposer common.Address, arg1 []byte) (*big.Int, error) {
	return _PreconfWhitelist.Contract.CheckProposer(&_PreconfWhitelist.CallOpts, _proposer, arg1)
}

// CheckProposer is a free data retrieval call binding the contract method 0xac0004da.
//
// Solidity: function checkProposer(address _proposer, bytes ) view returns(uint48 endOfSubmissionWindowTimestamp_)
func (_PreconfWhitelist *PreconfWhitelistCallerSession) CheckProposer(_proposer common.Address, arg1 []byte) (*big.Int, error) {
	return _PreconfWhitelist.Contract.CheckProposer(&_PreconfWhitelist.CallOpts, _proposer, arg1)
}

// Ejecters is a free data retrieval call binding the contract method 0x107538eb.
//
// Solidity: function ejecters(address ejecter) view returns(bool isEjecter)
func (_PreconfWhitelist *PreconfWhitelistCaller) Ejecters(opts *bind.CallOpts, ejecter common.Address) (bool, error) {
	var out []interface{}
	err := _PreconfWhitelist.contract.Call(opts, &out, "ejecters", ejecter)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Ejecters is a free data retrieval call binding the contract method 0x107538eb.
//
// Solidity: function ejecters(address ejecter) view returns(bool isEjecter)
func (_PreconfWhitelist *PreconfWhitelistSession) Ejecters(ejecter common.Address) (bool, error) {
	return _PreconfWhitelist.Contract.Ejecters(&_PreconfWhitelist.CallOpts, ejecter)
}

// Ejecters is a free data retrieval call binding the contract method 0x107538eb.
//
// Solidity: function ejecters(address ejecter) view returns(bool isEjecter)
func (_PreconfWhitelist *PreconfWhitelistCallerSession) Ejecters(ejecter common.Address) (bool, error) {
	return _PreconfWhitelist.Contract.Ejecters(&_PreconfWhitelist.CallOpts, ejecter)
}

// EpochStartTimestamp is a free data retrieval call binding the contract method 0x42b83b8e.
//
// Solidity: function epochStartTimestamp(uint256 _offset) view returns(uint32)
func (_PreconfWhitelist *PreconfWhitelistCaller) EpochStartTimestamp(opts *bind.CallOpts, _offset *big.Int) (uint32, error) {
	var out []interface{}
	err := _PreconfWhitelist.contract.Call(opts, &out, "epochStartTimestamp", _offset)

	if err != nil {
		return *new(uint32), err
	}

	out0 := *abi.ConvertType(out[0], new(uint32)).(*uint32)

	return out0, err

}

// EpochStartTimestamp is a free data retrieval call binding the contract method 0x42b83b8e.
//
// Solidity: function epochStartTimestamp(uint256 _offset) view returns(uint32)
func (_PreconfWhitelist *PreconfWhitelistSession) EpochStartTimestamp(_offset *big.Int) (uint32, error) {
	return _PreconfWhitelist.Contract.EpochStartTimestamp(&_PreconfWhitelist.CallOpts, _offset)
}

// EpochStartTimestamp is a free data retrieval call binding the contract method 0x42b83b8e.
//
// Solidity: function epochStartTimestamp(uint256 _offset) view returns(uint32)
func (_PreconfWhitelist *PreconfWhitelistCallerSession) EpochStartTimestamp(_offset *big.Int) (uint32, error) {
	return _PreconfWhitelist.Contract.EpochStartTimestamp(&_PreconfWhitelist.CallOpts, _offset)
}

// GetOperatorForCurrentEpoch is a free data retrieval call binding the contract method 0x343f0a68.
//
// Solidity: function getOperatorForCurrentEpoch() view returns(address)
func (_PreconfWhitelist *PreconfWhitelistCaller) GetOperatorForCurrentEpoch(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _PreconfWhitelist.contract.Call(opts, &out, "getOperatorForCurrentEpoch")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetOperatorForCurrentEpoch is a free data retrieval call binding the contract method 0x343f0a68.
//
// Solidity: function getOperatorForCurrentEpoch() view returns(address)
func (_PreconfWhitelist *PreconfWhitelistSession) GetOperatorForCurrentEpoch() (common.Address, error) {
	return _PreconfWhitelist.Contract.GetOperatorForCurrentEpoch(&_PreconfWhitelist.CallOpts)
}

// GetOperatorForCurrentEpoch is a free data retrieval call binding the contract method 0x343f0a68.
//
// Solidity: function getOperatorForCurrentEpoch() view returns(address)
func (_PreconfWhitelist *PreconfWhitelistCallerSession) GetOperatorForCurrentEpoch() (common.Address, error) {
	return _PreconfWhitelist.Contract.GetOperatorForCurrentEpoch(&_PreconfWhitelist.CallOpts)
}

// GetOperatorForNextEpoch is a free data retrieval call binding the contract method 0x72a8a551.
//
// Solidity: function getOperatorForNextEpoch() view returns(address)
func (_PreconfWhitelist *PreconfWhitelistCaller) GetOperatorForNextEpoch(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _PreconfWhitelist.contract.Call(opts, &out, "getOperatorForNextEpoch")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetOperatorForNextEpoch is a free data retrieval call binding the contract method 0x72a8a551.
//
// Solidity: function getOperatorForNextEpoch() view returns(address)
func (_PreconfWhitelist *PreconfWhitelistSession) GetOperatorForNextEpoch() (common.Address, error) {
	return _PreconfWhitelist.Contract.GetOperatorForNextEpoch(&_PreconfWhitelist.CallOpts)
}

// GetOperatorForNextEpoch is a free data retrieval call binding the contract method 0x72a8a551.
//
// Solidity: function getOperatorForNextEpoch() view returns(address)
func (_PreconfWhitelist *PreconfWhitelistCallerSession) GetOperatorForNextEpoch() (common.Address, error) {
	return _PreconfWhitelist.Contract.GetOperatorForNextEpoch(&_PreconfWhitelist.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_PreconfWhitelist *PreconfWhitelistCaller) Impl(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _PreconfWhitelist.contract.Call(opts, &out, "impl")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_PreconfWhitelist *PreconfWhitelistSession) Impl() (common.Address, error) {
	return _PreconfWhitelist.Contract.Impl(&_PreconfWhitelist.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_PreconfWhitelist *PreconfWhitelistCallerSession) Impl() (common.Address, error) {
	return _PreconfWhitelist.Contract.Impl(&_PreconfWhitelist.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_PreconfWhitelist *PreconfWhitelistCaller) InNonReentrant(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _PreconfWhitelist.contract.Call(opts, &out, "inNonReentrant")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_PreconfWhitelist *PreconfWhitelistSession) InNonReentrant() (bool, error) {
	return _PreconfWhitelist.Contract.InNonReentrant(&_PreconfWhitelist.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_PreconfWhitelist *PreconfWhitelistCallerSession) InNonReentrant() (bool, error) {
	return _PreconfWhitelist.Contract.InNonReentrant(&_PreconfWhitelist.CallOpts)
}

// IsOperatorActive is a free data retrieval call binding the contract method 0x316eae6a.
//
// Solidity: function isOperatorActive(address _proposer, uint32 _epochTimestamp) view returns(bool)
func (_PreconfWhitelist *PreconfWhitelistCaller) IsOperatorActive(opts *bind.CallOpts, _proposer common.Address, _epochTimestamp uint32) (bool, error) {
	var out []interface{}
	err := _PreconfWhitelist.contract.Call(opts, &out, "isOperatorActive", _proposer, _epochTimestamp)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsOperatorActive is a free data retrieval call binding the contract method 0x316eae6a.
//
// Solidity: function isOperatorActive(address _proposer, uint32 _epochTimestamp) view returns(bool)
func (_PreconfWhitelist *PreconfWhitelistSession) IsOperatorActive(_proposer common.Address, _epochTimestamp uint32) (bool, error) {
	return _PreconfWhitelist.Contract.IsOperatorActive(&_PreconfWhitelist.CallOpts, _proposer, _epochTimestamp)
}

// IsOperatorActive is a free data retrieval call binding the contract method 0x316eae6a.
//
// Solidity: function isOperatorActive(address _proposer, uint32 _epochTimestamp) view returns(bool)
func (_PreconfWhitelist *PreconfWhitelistCallerSession) IsOperatorActive(_proposer common.Address, _epochTimestamp uint32) (bool, error) {
	return _PreconfWhitelist.Contract.IsOperatorActive(&_PreconfWhitelist.CallOpts, _proposer, _epochTimestamp)
}

// LatestActivationEpoch is a free data retrieval call binding the contract method 0x7f918e2c.
//
// Solidity: function latestActivationEpoch() view returns(uint32)
func (_PreconfWhitelist *PreconfWhitelistCaller) LatestActivationEpoch(opts *bind.CallOpts) (uint32, error) {
	var out []interface{}
	err := _PreconfWhitelist.contract.Call(opts, &out, "latestActivationEpoch")

	if err != nil {
		return *new(uint32), err
	}

	out0 := *abi.ConvertType(out[0], new(uint32)).(*uint32)

	return out0, err

}

// LatestActivationEpoch is a free data retrieval call binding the contract method 0x7f918e2c.
//
// Solidity: function latestActivationEpoch() view returns(uint32)
func (_PreconfWhitelist *PreconfWhitelistSession) LatestActivationEpoch() (uint32, error) {
	return _PreconfWhitelist.Contract.LatestActivationEpoch(&_PreconfWhitelist.CallOpts)
}

// LatestActivationEpoch is a free data retrieval call binding the contract method 0x7f918e2c.
//
// Solidity: function latestActivationEpoch() view returns(uint32)
func (_PreconfWhitelist *PreconfWhitelistCallerSession) LatestActivationEpoch() (uint32, error) {
	return _PreconfWhitelist.Contract.LatestActivationEpoch(&_PreconfWhitelist.CallOpts)
}

// OperatorCount is a free data retrieval call binding the contract method 0x7c6f3158.
//
// Solidity: function operatorCount() view returns(uint8)
func (_PreconfWhitelist *PreconfWhitelistCaller) OperatorCount(opts *bind.CallOpts) (uint8, error) {
	var out []interface{}
	err := _PreconfWhitelist.contract.Call(opts, &out, "operatorCount")

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// OperatorCount is a free data retrieval call binding the contract method 0x7c6f3158.
//
// Solidity: function operatorCount() view returns(uint8)
func (_PreconfWhitelist *PreconfWhitelistSession) OperatorCount() (uint8, error) {
	return _PreconfWhitelist.Contract.OperatorCount(&_PreconfWhitelist.CallOpts)
}

// OperatorCount is a free data retrieval call binding the contract method 0x7c6f3158.
//
// Solidity: function operatorCount() view returns(uint8)
func (_PreconfWhitelist *PreconfWhitelistCallerSession) OperatorCount() (uint8, error) {
	return _PreconfWhitelist.Contract.OperatorCount(&_PreconfWhitelist.CallOpts)
}

// OperatorMapping is a free data retrieval call binding the contract method 0xcecad1f7.
//
// Solidity: function operatorMapping(uint256 index) view returns(address proposer)
func (_PreconfWhitelist *PreconfWhitelistCaller) OperatorMapping(opts *bind.CallOpts, index *big.Int) (common.Address, error) {
	var out []interface{}
	err := _PreconfWhitelist.contract.Call(opts, &out, "operatorMapping", index)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// OperatorMapping is a free data retrieval call binding the contract method 0xcecad1f7.
//
// Solidity: function operatorMapping(uint256 index) view returns(address proposer)
func (_PreconfWhitelist *PreconfWhitelistSession) OperatorMapping(index *big.Int) (common.Address, error) {
	return _PreconfWhitelist.Contract.OperatorMapping(&_PreconfWhitelist.CallOpts, index)
}

// OperatorMapping is a free data retrieval call binding the contract method 0xcecad1f7.
//
// Solidity: function operatorMapping(uint256 index) view returns(address proposer)
func (_PreconfWhitelist *PreconfWhitelistCallerSession) OperatorMapping(index *big.Int) (common.Address, error) {
	return _PreconfWhitelist.Contract.OperatorMapping(&_PreconfWhitelist.CallOpts, index)
}

// Operators is a free data retrieval call binding the contract method 0x13e7c9d8.
//
// Solidity: function operators(address proposer) view returns(uint32 activeSince, uint32 deprecatedInactiveSince, uint8 index, address sequencerAddress)
func (_PreconfWhitelist *PreconfWhitelistCaller) Operators(opts *bind.CallOpts, proposer common.Address) (struct {
	ActiveSince             uint32
	DeprecatedInactiveSince uint32
	Index                   uint8
	SequencerAddress        common.Address
}, error) {
	var out []interface{}
	err := _PreconfWhitelist.contract.Call(opts, &out, "operators", proposer)

	outstruct := new(struct {
		ActiveSince             uint32
		DeprecatedInactiveSince uint32
		Index                   uint8
		SequencerAddress        common.Address
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.ActiveSince = *abi.ConvertType(out[0], new(uint32)).(*uint32)
	outstruct.DeprecatedInactiveSince = *abi.ConvertType(out[1], new(uint32)).(*uint32)
	outstruct.Index = *abi.ConvertType(out[2], new(uint8)).(*uint8)
	outstruct.SequencerAddress = *abi.ConvertType(out[3], new(common.Address)).(*common.Address)

	return *outstruct, err

}

// Operators is a free data retrieval call binding the contract method 0x13e7c9d8.
//
// Solidity: function operators(address proposer) view returns(uint32 activeSince, uint32 deprecatedInactiveSince, uint8 index, address sequencerAddress)
func (_PreconfWhitelist *PreconfWhitelistSession) Operators(proposer common.Address) (struct {
	ActiveSince             uint32
	DeprecatedInactiveSince uint32
	Index                   uint8
	SequencerAddress        common.Address
}, error) {
	return _PreconfWhitelist.Contract.Operators(&_PreconfWhitelist.CallOpts, proposer)
}

// Operators is a free data retrieval call binding the contract method 0x13e7c9d8.
//
// Solidity: function operators(address proposer) view returns(uint32 activeSince, uint32 deprecatedInactiveSince, uint8 index, address sequencerAddress)
func (_PreconfWhitelist *PreconfWhitelistCallerSession) Operators(proposer common.Address) (struct {
	ActiveSince             uint32
	DeprecatedInactiveSince uint32
	Index                   uint8
	SequencerAddress        common.Address
}, error) {
	return _PreconfWhitelist.Contract.Operators(&_PreconfWhitelist.CallOpts, proposer)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_PreconfWhitelist *PreconfWhitelistCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _PreconfWhitelist.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_PreconfWhitelist *PreconfWhitelistSession) Owner() (common.Address, error) {
	return _PreconfWhitelist.Contract.Owner(&_PreconfWhitelist.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_PreconfWhitelist *PreconfWhitelistCallerSession) Owner() (common.Address, error) {
	return _PreconfWhitelist.Contract.Owner(&_PreconfWhitelist.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_PreconfWhitelist *PreconfWhitelistCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _PreconfWhitelist.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_PreconfWhitelist *PreconfWhitelistSession) Paused() (bool, error) {
	return _PreconfWhitelist.Contract.Paused(&_PreconfWhitelist.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_PreconfWhitelist *PreconfWhitelistCallerSession) Paused() (bool, error) {
	return _PreconfWhitelist.Contract.Paused(&_PreconfWhitelist.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_PreconfWhitelist *PreconfWhitelistCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _PreconfWhitelist.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_PreconfWhitelist *PreconfWhitelistSession) PendingOwner() (common.Address, error) {
	return _PreconfWhitelist.Contract.PendingOwner(&_PreconfWhitelist.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_PreconfWhitelist *PreconfWhitelistCallerSession) PendingOwner() (common.Address, error) {
	return _PreconfWhitelist.Contract.PendingOwner(&_PreconfWhitelist.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_PreconfWhitelist *PreconfWhitelistCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _PreconfWhitelist.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_PreconfWhitelist *PreconfWhitelistSession) ProxiableUUID() ([32]byte, error) {
	return _PreconfWhitelist.Contract.ProxiableUUID(&_PreconfWhitelist.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_PreconfWhitelist *PreconfWhitelistCallerSession) ProxiableUUID() ([32]byte, error) {
	return _PreconfWhitelist.Contract.ProxiableUUID(&_PreconfWhitelist.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_PreconfWhitelist *PreconfWhitelistCaller) Resolver(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _PreconfWhitelist.contract.Call(opts, &out, "resolver")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_PreconfWhitelist *PreconfWhitelistSession) Resolver() (common.Address, error) {
	return _PreconfWhitelist.Contract.Resolver(&_PreconfWhitelist.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_PreconfWhitelist *PreconfWhitelistCallerSession) Resolver() (common.Address, error) {
	return _PreconfWhitelist.Contract.Resolver(&_PreconfWhitelist.CallOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_PreconfWhitelist *PreconfWhitelistTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _PreconfWhitelist.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_PreconfWhitelist *PreconfWhitelistSession) AcceptOwnership() (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.AcceptOwnership(&_PreconfWhitelist.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_PreconfWhitelist *PreconfWhitelistTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.AcceptOwnership(&_PreconfWhitelist.TransactOpts)
}

// AddOperator is a paid mutator transaction binding the contract method 0x8a1af4c4.
//
// Solidity: function addOperator(address _proposer, address _sequencer) returns()
func (_PreconfWhitelist *PreconfWhitelistTransactor) AddOperator(opts *bind.TransactOpts, _proposer common.Address, _sequencer common.Address) (*types.Transaction, error) {
	return _PreconfWhitelist.contract.Transact(opts, "addOperator", _proposer, _sequencer)
}

// AddOperator is a paid mutator transaction binding the contract method 0x8a1af4c4.
//
// Solidity: function addOperator(address _proposer, address _sequencer) returns()
func (_PreconfWhitelist *PreconfWhitelistSession) AddOperator(_proposer common.Address, _sequencer common.Address) (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.AddOperator(&_PreconfWhitelist.TransactOpts, _proposer, _sequencer)
}

// AddOperator is a paid mutator transaction binding the contract method 0x8a1af4c4.
//
// Solidity: function addOperator(address _proposer, address _sequencer) returns()
func (_PreconfWhitelist *PreconfWhitelistTransactorSession) AddOperator(_proposer common.Address, _sequencer common.Address) (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.AddOperator(&_PreconfWhitelist.TransactOpts, _proposer, _sequencer)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_PreconfWhitelist *PreconfWhitelistTransactor) Init(opts *bind.TransactOpts, _owner common.Address) (*types.Transaction, error) {
	return _PreconfWhitelist.contract.Transact(opts, "init", _owner)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_PreconfWhitelist *PreconfWhitelistSession) Init(_owner common.Address) (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.Init(&_PreconfWhitelist.TransactOpts, _owner)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_PreconfWhitelist *PreconfWhitelistTransactorSession) Init(_owner common.Address) (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.Init(&_PreconfWhitelist.TransactOpts, _owner)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_PreconfWhitelist *PreconfWhitelistTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _PreconfWhitelist.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_PreconfWhitelist *PreconfWhitelistSession) Pause() (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.Pause(&_PreconfWhitelist.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_PreconfWhitelist *PreconfWhitelistTransactorSession) Pause() (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.Pause(&_PreconfWhitelist.TransactOpts)
}

// RemoveOperator is a paid mutator transaction binding the contract method 0xf46673f6.
//
// Solidity: function removeOperator(uint256 _operatorIndex) returns()
func (_PreconfWhitelist *PreconfWhitelistTransactor) RemoveOperator(opts *bind.TransactOpts, _operatorIndex *big.Int) (*types.Transaction, error) {
	return _PreconfWhitelist.contract.Transact(opts, "removeOperator", _operatorIndex)
}

// RemoveOperator is a paid mutator transaction binding the contract method 0xf46673f6.
//
// Solidity: function removeOperator(uint256 _operatorIndex) returns()
func (_PreconfWhitelist *PreconfWhitelistSession) RemoveOperator(_operatorIndex *big.Int) (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.RemoveOperator(&_PreconfWhitelist.TransactOpts, _operatorIndex)
}

// RemoveOperator is a paid mutator transaction binding the contract method 0xf46673f6.
//
// Solidity: function removeOperator(uint256 _operatorIndex) returns()
func (_PreconfWhitelist *PreconfWhitelistTransactorSession) RemoveOperator(_operatorIndex *big.Int) (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.RemoveOperator(&_PreconfWhitelist.TransactOpts, _operatorIndex)
}

// RemoveOperatorByAddress is a paid mutator transaction binding the contract method 0x9b724f9e.
//
// Solidity: function removeOperatorByAddress(address _proposer) returns()
func (_PreconfWhitelist *PreconfWhitelistTransactor) RemoveOperatorByAddress(opts *bind.TransactOpts, _proposer common.Address) (*types.Transaction, error) {
	return _PreconfWhitelist.contract.Transact(opts, "removeOperatorByAddress", _proposer)
}

// RemoveOperatorByAddress is a paid mutator transaction binding the contract method 0x9b724f9e.
//
// Solidity: function removeOperatorByAddress(address _proposer) returns()
func (_PreconfWhitelist *PreconfWhitelistSession) RemoveOperatorByAddress(_proposer common.Address) (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.RemoveOperatorByAddress(&_PreconfWhitelist.TransactOpts, _proposer)
}

// RemoveOperatorByAddress is a paid mutator transaction binding the contract method 0x9b724f9e.
//
// Solidity: function removeOperatorByAddress(address _proposer) returns()
func (_PreconfWhitelist *PreconfWhitelistTransactorSession) RemoveOperatorByAddress(_proposer common.Address) (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.RemoveOperatorByAddress(&_PreconfWhitelist.TransactOpts, _proposer)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_PreconfWhitelist *PreconfWhitelistTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _PreconfWhitelist.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_PreconfWhitelist *PreconfWhitelistSession) RenounceOwnership() (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.RenounceOwnership(&_PreconfWhitelist.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_PreconfWhitelist *PreconfWhitelistTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.RenounceOwnership(&_PreconfWhitelist.TransactOpts)
}

// SetEjecter is a paid mutator transaction binding the contract method 0x6240b71c.
//
// Solidity: function setEjecter(address _ejecter, bool _isEjecter) returns()
func (_PreconfWhitelist *PreconfWhitelistTransactor) SetEjecter(opts *bind.TransactOpts, _ejecter common.Address, _isEjecter bool) (*types.Transaction, error) {
	return _PreconfWhitelist.contract.Transact(opts, "setEjecter", _ejecter, _isEjecter)
}

// SetEjecter is a paid mutator transaction binding the contract method 0x6240b71c.
//
// Solidity: function setEjecter(address _ejecter, bool _isEjecter) returns()
func (_PreconfWhitelist *PreconfWhitelistSession) SetEjecter(_ejecter common.Address, _isEjecter bool) (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.SetEjecter(&_PreconfWhitelist.TransactOpts, _ejecter, _isEjecter)
}

// SetEjecter is a paid mutator transaction binding the contract method 0x6240b71c.
//
// Solidity: function setEjecter(address _ejecter, bool _isEjecter) returns()
func (_PreconfWhitelist *PreconfWhitelistTransactorSession) SetEjecter(_ejecter common.Address, _isEjecter bool) (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.SetEjecter(&_PreconfWhitelist.TransactOpts, _ejecter, _isEjecter)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_PreconfWhitelist *PreconfWhitelistTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _PreconfWhitelist.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_PreconfWhitelist *PreconfWhitelistSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.TransferOwnership(&_PreconfWhitelist.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_PreconfWhitelist *PreconfWhitelistTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.TransferOwnership(&_PreconfWhitelist.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_PreconfWhitelist *PreconfWhitelistTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _PreconfWhitelist.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_PreconfWhitelist *PreconfWhitelistSession) Unpause() (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.Unpause(&_PreconfWhitelist.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_PreconfWhitelist *PreconfWhitelistTransactorSession) Unpause() (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.Unpause(&_PreconfWhitelist.TransactOpts)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_PreconfWhitelist *PreconfWhitelistTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _PreconfWhitelist.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_PreconfWhitelist *PreconfWhitelistSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.UpgradeTo(&_PreconfWhitelist.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_PreconfWhitelist *PreconfWhitelistTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.UpgradeTo(&_PreconfWhitelist.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_PreconfWhitelist *PreconfWhitelistTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _PreconfWhitelist.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_PreconfWhitelist *PreconfWhitelistSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.UpgradeToAndCall(&_PreconfWhitelist.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_PreconfWhitelist *PreconfWhitelistTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _PreconfWhitelist.Contract.UpgradeToAndCall(&_PreconfWhitelist.TransactOpts, newImplementation, data)
}

// PreconfWhitelistAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the PreconfWhitelist contract.
type PreconfWhitelistAdminChangedIterator struct {
	Event *PreconfWhitelistAdminChanged // Event containing the contract specifics and raw log

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
func (it *PreconfWhitelistAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PreconfWhitelistAdminChanged)
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
		it.Event = new(PreconfWhitelistAdminChanged)
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
func (it *PreconfWhitelistAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PreconfWhitelistAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PreconfWhitelistAdminChanged represents a AdminChanged event raised by the PreconfWhitelist contract.
type PreconfWhitelistAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_PreconfWhitelist *PreconfWhitelistFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*PreconfWhitelistAdminChangedIterator, error) {

	logs, sub, err := _PreconfWhitelist.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &PreconfWhitelistAdminChangedIterator{contract: _PreconfWhitelist.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_PreconfWhitelist *PreconfWhitelistFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *PreconfWhitelistAdminChanged) (event.Subscription, error) {

	logs, sub, err := _PreconfWhitelist.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PreconfWhitelistAdminChanged)
				if err := _PreconfWhitelist.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_PreconfWhitelist *PreconfWhitelistFilterer) ParseAdminChanged(log types.Log) (*PreconfWhitelistAdminChanged, error) {
	event := new(PreconfWhitelistAdminChanged)
	if err := _PreconfWhitelist.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PreconfWhitelistBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the PreconfWhitelist contract.
type PreconfWhitelistBeaconUpgradedIterator struct {
	Event *PreconfWhitelistBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *PreconfWhitelistBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PreconfWhitelistBeaconUpgraded)
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
		it.Event = new(PreconfWhitelistBeaconUpgraded)
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
func (it *PreconfWhitelistBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PreconfWhitelistBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PreconfWhitelistBeaconUpgraded represents a BeaconUpgraded event raised by the PreconfWhitelist contract.
type PreconfWhitelistBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_PreconfWhitelist *PreconfWhitelistFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*PreconfWhitelistBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _PreconfWhitelist.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &PreconfWhitelistBeaconUpgradedIterator{contract: _PreconfWhitelist.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_PreconfWhitelist *PreconfWhitelistFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *PreconfWhitelistBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _PreconfWhitelist.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PreconfWhitelistBeaconUpgraded)
				if err := _PreconfWhitelist.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_PreconfWhitelist *PreconfWhitelistFilterer) ParseBeaconUpgraded(log types.Log) (*PreconfWhitelistBeaconUpgraded, error) {
	event := new(PreconfWhitelistBeaconUpgraded)
	if err := _PreconfWhitelist.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PreconfWhitelistEjecterUpdatedIterator is returned from FilterEjecterUpdated and is used to iterate over the raw logs and unpacked data for EjecterUpdated events raised by the PreconfWhitelist contract.
type PreconfWhitelistEjecterUpdatedIterator struct {
	Event *PreconfWhitelistEjecterUpdated // Event containing the contract specifics and raw log

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
func (it *PreconfWhitelistEjecterUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PreconfWhitelistEjecterUpdated)
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
		it.Event = new(PreconfWhitelistEjecterUpdated)
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
func (it *PreconfWhitelistEjecterUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PreconfWhitelistEjecterUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PreconfWhitelistEjecterUpdated represents a EjecterUpdated event raised by the PreconfWhitelist contract.
type PreconfWhitelistEjecterUpdated struct {
	Ejecter   common.Address
	IsEjecter bool
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterEjecterUpdated is a free log retrieval operation binding the contract event 0x4517b9cadd80ff3722ce16d2ab8a83d39a8e57ee04a761501325b52a627543f9.
//
// Solidity: event EjecterUpdated(address indexed ejecter, bool isEjecter)
func (_PreconfWhitelist *PreconfWhitelistFilterer) FilterEjecterUpdated(opts *bind.FilterOpts, ejecter []common.Address) (*PreconfWhitelistEjecterUpdatedIterator, error) {

	var ejecterRule []interface{}
	for _, ejecterItem := range ejecter {
		ejecterRule = append(ejecterRule, ejecterItem)
	}

	logs, sub, err := _PreconfWhitelist.contract.FilterLogs(opts, "EjecterUpdated", ejecterRule)
	if err != nil {
		return nil, err
	}
	return &PreconfWhitelistEjecterUpdatedIterator{contract: _PreconfWhitelist.contract, event: "EjecterUpdated", logs: logs, sub: sub}, nil
}

// WatchEjecterUpdated is a free log subscription operation binding the contract event 0x4517b9cadd80ff3722ce16d2ab8a83d39a8e57ee04a761501325b52a627543f9.
//
// Solidity: event EjecterUpdated(address indexed ejecter, bool isEjecter)
func (_PreconfWhitelist *PreconfWhitelistFilterer) WatchEjecterUpdated(opts *bind.WatchOpts, sink chan<- *PreconfWhitelistEjecterUpdated, ejecter []common.Address) (event.Subscription, error) {

	var ejecterRule []interface{}
	for _, ejecterItem := range ejecter {
		ejecterRule = append(ejecterRule, ejecterItem)
	}

	logs, sub, err := _PreconfWhitelist.contract.WatchLogs(opts, "EjecterUpdated", ejecterRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PreconfWhitelistEjecterUpdated)
				if err := _PreconfWhitelist.contract.UnpackLog(event, "EjecterUpdated", log); err != nil {
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

// ParseEjecterUpdated is a log parse operation binding the contract event 0x4517b9cadd80ff3722ce16d2ab8a83d39a8e57ee04a761501325b52a627543f9.
//
// Solidity: event EjecterUpdated(address indexed ejecter, bool isEjecter)
func (_PreconfWhitelist *PreconfWhitelistFilterer) ParseEjecterUpdated(log types.Log) (*PreconfWhitelistEjecterUpdated, error) {
	event := new(PreconfWhitelistEjecterUpdated)
	if err := _PreconfWhitelist.contract.UnpackLog(event, "EjecterUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PreconfWhitelistInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the PreconfWhitelist contract.
type PreconfWhitelistInitializedIterator struct {
	Event *PreconfWhitelistInitialized // Event containing the contract specifics and raw log

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
func (it *PreconfWhitelistInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PreconfWhitelistInitialized)
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
		it.Event = new(PreconfWhitelistInitialized)
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
func (it *PreconfWhitelistInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PreconfWhitelistInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PreconfWhitelistInitialized represents a Initialized event raised by the PreconfWhitelist contract.
type PreconfWhitelistInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_PreconfWhitelist *PreconfWhitelistFilterer) FilterInitialized(opts *bind.FilterOpts) (*PreconfWhitelistInitializedIterator, error) {

	logs, sub, err := _PreconfWhitelist.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &PreconfWhitelistInitializedIterator{contract: _PreconfWhitelist.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_PreconfWhitelist *PreconfWhitelistFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *PreconfWhitelistInitialized) (event.Subscription, error) {

	logs, sub, err := _PreconfWhitelist.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PreconfWhitelistInitialized)
				if err := _PreconfWhitelist.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_PreconfWhitelist *PreconfWhitelistFilterer) ParseInitialized(log types.Log) (*PreconfWhitelistInitialized, error) {
	event := new(PreconfWhitelistInitialized)
	if err := _PreconfWhitelist.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PreconfWhitelistOperatorAddedIterator is returned from FilterOperatorAdded and is used to iterate over the raw logs and unpacked data for OperatorAdded events raised by the PreconfWhitelist contract.
type PreconfWhitelistOperatorAddedIterator struct {
	Event *PreconfWhitelistOperatorAdded // Event containing the contract specifics and raw log

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
func (it *PreconfWhitelistOperatorAddedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PreconfWhitelistOperatorAdded)
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
		it.Event = new(PreconfWhitelistOperatorAdded)
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
func (it *PreconfWhitelistOperatorAddedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PreconfWhitelistOperatorAddedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PreconfWhitelistOperatorAdded represents a OperatorAdded event raised by the PreconfWhitelist contract.
type PreconfWhitelistOperatorAdded struct {
	Proposer    common.Address
	Sequencer   common.Address
	ActiveSince *big.Int
	Raw         types.Log // Blockchain specific contextual infos
}

// FilterOperatorAdded is a free log retrieval operation binding the contract event 0x20c899c9053446f0d7a408c709f0196e2c26c6a985dcad854dc19ad567c4531f.
//
// Solidity: event OperatorAdded(address indexed proposer, address indexed sequencer, uint256 activeSince)
func (_PreconfWhitelist *PreconfWhitelistFilterer) FilterOperatorAdded(opts *bind.FilterOpts, proposer []common.Address, sequencer []common.Address) (*PreconfWhitelistOperatorAddedIterator, error) {

	var proposerRule []interface{}
	for _, proposerItem := range proposer {
		proposerRule = append(proposerRule, proposerItem)
	}
	var sequencerRule []interface{}
	for _, sequencerItem := range sequencer {
		sequencerRule = append(sequencerRule, sequencerItem)
	}

	logs, sub, err := _PreconfWhitelist.contract.FilterLogs(opts, "OperatorAdded", proposerRule, sequencerRule)
	if err != nil {
		return nil, err
	}
	return &PreconfWhitelistOperatorAddedIterator{contract: _PreconfWhitelist.contract, event: "OperatorAdded", logs: logs, sub: sub}, nil
}

// WatchOperatorAdded is a free log subscription operation binding the contract event 0x20c899c9053446f0d7a408c709f0196e2c26c6a985dcad854dc19ad567c4531f.
//
// Solidity: event OperatorAdded(address indexed proposer, address indexed sequencer, uint256 activeSince)
func (_PreconfWhitelist *PreconfWhitelistFilterer) WatchOperatorAdded(opts *bind.WatchOpts, sink chan<- *PreconfWhitelistOperatorAdded, proposer []common.Address, sequencer []common.Address) (event.Subscription, error) {

	var proposerRule []interface{}
	for _, proposerItem := range proposer {
		proposerRule = append(proposerRule, proposerItem)
	}
	var sequencerRule []interface{}
	for _, sequencerItem := range sequencer {
		sequencerRule = append(sequencerRule, sequencerItem)
	}

	logs, sub, err := _PreconfWhitelist.contract.WatchLogs(opts, "OperatorAdded", proposerRule, sequencerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PreconfWhitelistOperatorAdded)
				if err := _PreconfWhitelist.contract.UnpackLog(event, "OperatorAdded", log); err != nil {
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

// ParseOperatorAdded is a log parse operation binding the contract event 0x20c899c9053446f0d7a408c709f0196e2c26c6a985dcad854dc19ad567c4531f.
//
// Solidity: event OperatorAdded(address indexed proposer, address indexed sequencer, uint256 activeSince)
func (_PreconfWhitelist *PreconfWhitelistFilterer) ParseOperatorAdded(log types.Log) (*PreconfWhitelistOperatorAdded, error) {
	event := new(PreconfWhitelistOperatorAdded)
	if err := _PreconfWhitelist.contract.UnpackLog(event, "OperatorAdded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PreconfWhitelistOperatorRemovedIterator is returned from FilterOperatorRemoved and is used to iterate over the raw logs and unpacked data for OperatorRemoved events raised by the PreconfWhitelist contract.
type PreconfWhitelistOperatorRemovedIterator struct {
	Event *PreconfWhitelistOperatorRemoved // Event containing the contract specifics and raw log

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
func (it *PreconfWhitelistOperatorRemovedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PreconfWhitelistOperatorRemoved)
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
		it.Event = new(PreconfWhitelistOperatorRemoved)
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
func (it *PreconfWhitelistOperatorRemovedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PreconfWhitelistOperatorRemovedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PreconfWhitelistOperatorRemoved represents a OperatorRemoved event raised by the PreconfWhitelist contract.
type PreconfWhitelistOperatorRemoved struct {
	Proposer      common.Address
	Sequencer     common.Address
	InactiveSince *big.Int
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOperatorRemoved is a free log retrieval operation binding the contract event 0xa85b3d3497f1e4522d447f02e1a1d16506431ba902da11611a51d8502400e4ea.
//
// Solidity: event OperatorRemoved(address indexed proposer, address indexed sequencer, uint256 inactiveSince)
func (_PreconfWhitelist *PreconfWhitelistFilterer) FilterOperatorRemoved(opts *bind.FilterOpts, proposer []common.Address, sequencer []common.Address) (*PreconfWhitelistOperatorRemovedIterator, error) {

	var proposerRule []interface{}
	for _, proposerItem := range proposer {
		proposerRule = append(proposerRule, proposerItem)
	}
	var sequencerRule []interface{}
	for _, sequencerItem := range sequencer {
		sequencerRule = append(sequencerRule, sequencerItem)
	}

	logs, sub, err := _PreconfWhitelist.contract.FilterLogs(opts, "OperatorRemoved", proposerRule, sequencerRule)
	if err != nil {
		return nil, err
	}
	return &PreconfWhitelistOperatorRemovedIterator{contract: _PreconfWhitelist.contract, event: "OperatorRemoved", logs: logs, sub: sub}, nil
}

// WatchOperatorRemoved is a free log subscription operation binding the contract event 0xa85b3d3497f1e4522d447f02e1a1d16506431ba902da11611a51d8502400e4ea.
//
// Solidity: event OperatorRemoved(address indexed proposer, address indexed sequencer, uint256 inactiveSince)
func (_PreconfWhitelist *PreconfWhitelistFilterer) WatchOperatorRemoved(opts *bind.WatchOpts, sink chan<- *PreconfWhitelistOperatorRemoved, proposer []common.Address, sequencer []common.Address) (event.Subscription, error) {

	var proposerRule []interface{}
	for _, proposerItem := range proposer {
		proposerRule = append(proposerRule, proposerItem)
	}
	var sequencerRule []interface{}
	for _, sequencerItem := range sequencer {
		sequencerRule = append(sequencerRule, sequencerItem)
	}

	logs, sub, err := _PreconfWhitelist.contract.WatchLogs(opts, "OperatorRemoved", proposerRule, sequencerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PreconfWhitelistOperatorRemoved)
				if err := _PreconfWhitelist.contract.UnpackLog(event, "OperatorRemoved", log); err != nil {
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

// ParseOperatorRemoved is a log parse operation binding the contract event 0xa85b3d3497f1e4522d447f02e1a1d16506431ba902da11611a51d8502400e4ea.
//
// Solidity: event OperatorRemoved(address indexed proposer, address indexed sequencer, uint256 inactiveSince)
func (_PreconfWhitelist *PreconfWhitelistFilterer) ParseOperatorRemoved(log types.Log) (*PreconfWhitelistOperatorRemoved, error) {
	event := new(PreconfWhitelistOperatorRemoved)
	if err := _PreconfWhitelist.contract.UnpackLog(event, "OperatorRemoved", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PreconfWhitelistOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the PreconfWhitelist contract.
type PreconfWhitelistOwnershipTransferStartedIterator struct {
	Event *PreconfWhitelistOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *PreconfWhitelistOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PreconfWhitelistOwnershipTransferStarted)
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
		it.Event = new(PreconfWhitelistOwnershipTransferStarted)
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
func (it *PreconfWhitelistOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PreconfWhitelistOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PreconfWhitelistOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the PreconfWhitelist contract.
type PreconfWhitelistOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_PreconfWhitelist *PreconfWhitelistFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*PreconfWhitelistOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _PreconfWhitelist.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &PreconfWhitelistOwnershipTransferStartedIterator{contract: _PreconfWhitelist.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_PreconfWhitelist *PreconfWhitelistFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *PreconfWhitelistOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _PreconfWhitelist.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PreconfWhitelistOwnershipTransferStarted)
				if err := _PreconfWhitelist.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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
func (_PreconfWhitelist *PreconfWhitelistFilterer) ParseOwnershipTransferStarted(log types.Log) (*PreconfWhitelistOwnershipTransferStarted, error) {
	event := new(PreconfWhitelistOwnershipTransferStarted)
	if err := _PreconfWhitelist.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PreconfWhitelistOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the PreconfWhitelist contract.
type PreconfWhitelistOwnershipTransferredIterator struct {
	Event *PreconfWhitelistOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *PreconfWhitelistOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PreconfWhitelistOwnershipTransferred)
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
		it.Event = new(PreconfWhitelistOwnershipTransferred)
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
func (it *PreconfWhitelistOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PreconfWhitelistOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PreconfWhitelistOwnershipTransferred represents a OwnershipTransferred event raised by the PreconfWhitelist contract.
type PreconfWhitelistOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_PreconfWhitelist *PreconfWhitelistFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*PreconfWhitelistOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _PreconfWhitelist.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &PreconfWhitelistOwnershipTransferredIterator{contract: _PreconfWhitelist.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_PreconfWhitelist *PreconfWhitelistFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *PreconfWhitelistOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _PreconfWhitelist.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PreconfWhitelistOwnershipTransferred)
				if err := _PreconfWhitelist.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_PreconfWhitelist *PreconfWhitelistFilterer) ParseOwnershipTransferred(log types.Log) (*PreconfWhitelistOwnershipTransferred, error) {
	event := new(PreconfWhitelistOwnershipTransferred)
	if err := _PreconfWhitelist.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PreconfWhitelistPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the PreconfWhitelist contract.
type PreconfWhitelistPausedIterator struct {
	Event *PreconfWhitelistPaused // Event containing the contract specifics and raw log

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
func (it *PreconfWhitelistPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PreconfWhitelistPaused)
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
		it.Event = new(PreconfWhitelistPaused)
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
func (it *PreconfWhitelistPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PreconfWhitelistPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PreconfWhitelistPaused represents a Paused event raised by the PreconfWhitelist contract.
type PreconfWhitelistPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_PreconfWhitelist *PreconfWhitelistFilterer) FilterPaused(opts *bind.FilterOpts) (*PreconfWhitelistPausedIterator, error) {

	logs, sub, err := _PreconfWhitelist.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &PreconfWhitelistPausedIterator{contract: _PreconfWhitelist.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_PreconfWhitelist *PreconfWhitelistFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *PreconfWhitelistPaused) (event.Subscription, error) {

	logs, sub, err := _PreconfWhitelist.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PreconfWhitelistPaused)
				if err := _PreconfWhitelist.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_PreconfWhitelist *PreconfWhitelistFilterer) ParsePaused(log types.Log) (*PreconfWhitelistPaused, error) {
	event := new(PreconfWhitelistPaused)
	if err := _PreconfWhitelist.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PreconfWhitelistUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the PreconfWhitelist contract.
type PreconfWhitelistUnpausedIterator struct {
	Event *PreconfWhitelistUnpaused // Event containing the contract specifics and raw log

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
func (it *PreconfWhitelistUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PreconfWhitelistUnpaused)
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
		it.Event = new(PreconfWhitelistUnpaused)
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
func (it *PreconfWhitelistUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PreconfWhitelistUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PreconfWhitelistUnpaused represents a Unpaused event raised by the PreconfWhitelist contract.
type PreconfWhitelistUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_PreconfWhitelist *PreconfWhitelistFilterer) FilterUnpaused(opts *bind.FilterOpts) (*PreconfWhitelistUnpausedIterator, error) {

	logs, sub, err := _PreconfWhitelist.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &PreconfWhitelistUnpausedIterator{contract: _PreconfWhitelist.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_PreconfWhitelist *PreconfWhitelistFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *PreconfWhitelistUnpaused) (event.Subscription, error) {

	logs, sub, err := _PreconfWhitelist.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PreconfWhitelistUnpaused)
				if err := _PreconfWhitelist.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_PreconfWhitelist *PreconfWhitelistFilterer) ParseUnpaused(log types.Log) (*PreconfWhitelistUnpaused, error) {
	event := new(PreconfWhitelistUnpaused)
	if err := _PreconfWhitelist.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PreconfWhitelistUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the PreconfWhitelist contract.
type PreconfWhitelistUpgradedIterator struct {
	Event *PreconfWhitelistUpgraded // Event containing the contract specifics and raw log

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
func (it *PreconfWhitelistUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PreconfWhitelistUpgraded)
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
		it.Event = new(PreconfWhitelistUpgraded)
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
func (it *PreconfWhitelistUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PreconfWhitelistUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PreconfWhitelistUpgraded represents a Upgraded event raised by the PreconfWhitelist contract.
type PreconfWhitelistUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_PreconfWhitelist *PreconfWhitelistFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*PreconfWhitelistUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _PreconfWhitelist.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &PreconfWhitelistUpgradedIterator{contract: _PreconfWhitelist.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_PreconfWhitelist *PreconfWhitelistFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *PreconfWhitelistUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _PreconfWhitelist.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PreconfWhitelistUpgraded)
				if err := _PreconfWhitelist.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_PreconfWhitelist *PreconfWhitelistFilterer) ParseUpgraded(log types.Log) (*PreconfWhitelistUpgraded, error) {
	event := new(PreconfWhitelistUpgraded)
	if err := _PreconfWhitelist.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
