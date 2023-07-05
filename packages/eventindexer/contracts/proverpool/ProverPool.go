// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package proverpool

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

// ProverPoolProver is an auto generated low-level Go binding around an user-defined struct.
type ProverPoolProver struct {
	StakedAmount    uint64
	RewardPerGas    uint32
	CurrentCapacity uint32
}

// ProverPoolStaker is an auto generated low-level Go binding around an user-defined struct.
type ProverPoolStaker struct {
	ExitRequestedAt uint64
	ExitAmount      uint64
	MaxCapacity     uint32
	ProverId        uint32
}

// ProverPoolMetaData contains all meta data concerning the ProverPool contract.
var ProverPoolMetaData = &bind.MetaData{
	ABI: "[{\"inputs\":[],\"name\":\"CHANGE_TOO_FREQUENT\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"INVALID_PARAMS\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"NO_MATURE_EXIT\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"PROVER_NOT_GOOD_ENOUGH\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"RESOLVER_DENIED\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"RESOLVER_INVALID_ADDR\",\"type\":\"error\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"name\",\"type\":\"bytes32\"}],\"name\":\"RESOLVER_ZERO_ADDR\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"UNAUTHORIZED\",\"type\":\"error\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"addressManager\",\"type\":\"address\"}],\"name\":\"AddressManagerChanged\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"addr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint64\",\"name\":\"amount\",\"type\":\"uint64\"}],\"name\":\"Exited\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint8\",\"name\":\"version\",\"type\":\"uint8\"}],\"name\":\"Initialized\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"previousOwner\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"OwnershipTransferred\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"addr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint64\",\"name\":\"amount\",\"type\":\"uint64\"}],\"name\":\"Slashed\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"addr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint64\",\"name\":\"amount\",\"type\":\"uint64\"},{\"indexed\":false,\"internalType\":\"uint32\",\"name\":\"rewardPerGas\",\"type\":\"uint32\"},{\"indexed\":false,\"internalType\":\"uint32\",\"name\":\"currentCapacity\",\"type\":\"uint32\"}],\"name\":\"Staked\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"addr\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint64\",\"name\":\"amount\",\"type\":\"uint64\"}],\"name\":\"Withdrawn\",\"type\":\"event\"},{\"inputs\":[],\"name\":\"EXIT_PERIOD\",\"outputs\":[{\"internalType\":\"uint64\",\"name\":\"\",\"type\":\"uint64\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"MAX_CAPACITY_LOWER_BOUND\",\"outputs\":[{\"internalType\":\"uint32\",\"name\":\"\",\"type\":\"uint32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"MAX_NUM_PROVERS\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"MIN_CHANGE_DELAY\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"MIN_SLASH_AMOUNT\",\"outputs\":[{\"internalType\":\"uint64\",\"name\":\"\",\"type\":\"uint64\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"MIN_STAKE_PER_CAPACITY\",\"outputs\":[{\"internalType\":\"uint64\",\"name\":\"\",\"type\":\"uint64\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"SLASH_POINTS\",\"outputs\":[{\"internalType\":\"uint64\",\"name\":\"\",\"type\":\"uint64\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"addressManager\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"blockId\",\"type\":\"uint64\"},{\"internalType\":\"uint32\",\"name\":\"feePerGas\",\"type\":\"uint32\"}],\"name\":\"assignProver\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"prover\",\"type\":\"address\"},{\"internalType\":\"uint32\",\"name\":\"rewardPerGas\",\"type\":\"uint32\"}],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"exit\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"getCapacity\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"capacity\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint32\",\"name\":\"feePerGas\",\"type\":\"uint32\"}],\"name\":\"getProverWeights\",\"outputs\":[{\"internalType\":\"uint256[32]\",\"name\":\"weights\",\"type\":\"uint256[32]\"},{\"internalType\":\"uint32[32]\",\"name\":\"erpg\",\"type\":\"uint32[32]\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"getProvers\",\"outputs\":[{\"components\":[{\"internalType\":\"uint64\",\"name\":\"stakedAmount\",\"type\":\"uint64\"},{\"internalType\":\"uint32\",\"name\":\"rewardPerGas\",\"type\":\"uint32\"},{\"internalType\":\"uint32\",\"name\":\"currentCapacity\",\"type\":\"uint32\"}],\"internalType\":\"structProverPool.Prover[]\",\"name\":\"_provers\",\"type\":\"tuple[]\"},{\"internalType\":\"address[]\",\"name\":\"_stakers\",\"type\":\"address[]\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"addr\",\"type\":\"address\"}],\"name\":\"getStaker\",\"outputs\":[{\"components\":[{\"internalType\":\"uint64\",\"name\":\"exitRequestedAt\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"exitAmount\",\"type\":\"uint64\"},{\"internalType\":\"uint32\",\"name\":\"maxCapacity\",\"type\":\"uint32\"},{\"internalType\":\"uint32\",\"name\":\"proverId\",\"type\":\"uint32\"}],\"internalType\":\"structProverPool.Staker\",\"name\":\"staker\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"uint64\",\"name\":\"stakedAmount\",\"type\":\"uint64\"},{\"internalType\":\"uint32\",\"name\":\"rewardPerGas\",\"type\":\"uint32\"},{\"internalType\":\"uint32\",\"name\":\"currentCapacity\",\"type\":\"uint32\"}],\"internalType\":\"structProverPool.Prover\",\"name\":\"prover\",\"type\":\"tuple\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_addressManager\",\"type\":\"address\"}],\"name\":\"init\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"owner\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"id\",\"type\":\"uint256\"}],\"name\":\"proverIdToAddress\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"prover\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"name\":\"provers\",\"outputs\":[{\"internalType\":\"uint64\",\"name\":\"stakedAmount\",\"type\":\"uint64\"},{\"internalType\":\"uint32\",\"name\":\"rewardPerGas\",\"type\":\"uint32\"},{\"internalType\":\"uint32\",\"name\":\"currentCapacity\",\"type\":\"uint32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"addr\",\"type\":\"address\"}],\"name\":\"releaseProver\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"renounceOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"name\",\"type\":\"bytes32\"},{\"internalType\":\"bool\",\"name\":\"allowZeroAddress\",\"type\":\"bool\"}],\"name\":\"resolve\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"name\",\"type\":\"bytes32\"},{\"internalType\":\"bool\",\"name\":\"allowZeroAddress\",\"type\":\"bool\"}],\"name\":\"resolve\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"newAddressManager\",\"type\":\"address\"}],\"name\":\"setAddressManager\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"addr\",\"type\":\"address\"}],\"name\":\"slashProver\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"amount\",\"type\":\"uint64\"},{\"internalType\":\"uint32\",\"name\":\"rewardPerGas\",\"type\":\"uint32\"},{\"internalType\":\"uint32\",\"name\":\"maxCapacity\",\"type\":\"uint32\"}],\"name\":\"stake\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"staker\",\"type\":\"address\"}],\"name\":\"stakers\",\"outputs\":[{\"internalType\":\"uint64\",\"name\":\"exitRequestedAt\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"exitAmount\",\"type\":\"uint64\"},{\"internalType\":\"uint32\",\"name\":\"maxCapacity\",\"type\":\"uint32\"},{\"internalType\":\"uint32\",\"name\":\"proverId\",\"type\":\"uint32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"transferOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"withdraw\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"}]",
}

// ProverPoolABI is the input ABI used to generate the binding from.
// Deprecated: Use ProverPoolMetaData.ABI instead.
var ProverPoolABI = ProverPoolMetaData.ABI

// ProverPool is an auto generated Go binding around an Ethereum contract.
type ProverPool struct {
	ProverPoolCaller     // Read-only binding to the contract
	ProverPoolTransactor // Write-only binding to the contract
	ProverPoolFilterer   // Log filterer for contract events
}

// ProverPoolCaller is an auto generated read-only Go binding around an Ethereum contract.
type ProverPoolCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ProverPoolTransactor is an auto generated write-only Go binding around an Ethereum contract.
type ProverPoolTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ProverPoolFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type ProverPoolFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ProverPoolSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type ProverPoolSession struct {
	Contract     *ProverPool       // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// ProverPoolCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type ProverPoolCallerSession struct {
	Contract *ProverPoolCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts     // Call options to use throughout this session
}

// ProverPoolTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type ProverPoolTransactorSession struct {
	Contract     *ProverPoolTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts     // Transaction auth options to use throughout this session
}

// ProverPoolRaw is an auto generated low-level Go binding around an Ethereum contract.
type ProverPoolRaw struct {
	Contract *ProverPool // Generic contract binding to access the raw methods on
}

// ProverPoolCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type ProverPoolCallerRaw struct {
	Contract *ProverPoolCaller // Generic read-only contract binding to access the raw methods on
}

// ProverPoolTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type ProverPoolTransactorRaw struct {
	Contract *ProverPoolTransactor // Generic write-only contract binding to access the raw methods on
}

// NewProverPool creates a new instance of ProverPool, bound to a specific deployed contract.
func NewProverPool(address common.Address, backend bind.ContractBackend) (*ProverPool, error) {
	contract, err := bindProverPool(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &ProverPool{ProverPoolCaller: ProverPoolCaller{contract: contract}, ProverPoolTransactor: ProverPoolTransactor{contract: contract}, ProverPoolFilterer: ProverPoolFilterer{contract: contract}}, nil
}

// NewProverPoolCaller creates a new read-only instance of ProverPool, bound to a specific deployed contract.
func NewProverPoolCaller(address common.Address, caller bind.ContractCaller) (*ProverPoolCaller, error) {
	contract, err := bindProverPool(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &ProverPoolCaller{contract: contract}, nil
}

// NewProverPoolTransactor creates a new write-only instance of ProverPool, bound to a specific deployed contract.
func NewProverPoolTransactor(address common.Address, transactor bind.ContractTransactor) (*ProverPoolTransactor, error) {
	contract, err := bindProverPool(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &ProverPoolTransactor{contract: contract}, nil
}

// NewProverPoolFilterer creates a new log filterer instance of ProverPool, bound to a specific deployed contract.
func NewProverPoolFilterer(address common.Address, filterer bind.ContractFilterer) (*ProverPoolFilterer, error) {
	contract, err := bindProverPool(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &ProverPoolFilterer{contract: contract}, nil
}

// bindProverPool binds a generic wrapper to an already deployed contract.
func bindProverPool(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := ProverPoolMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ProverPool *ProverPoolRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ProverPool.Contract.ProverPoolCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ProverPool *ProverPoolRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ProverPool.Contract.ProverPoolTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ProverPool *ProverPoolRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ProverPool.Contract.ProverPoolTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ProverPool *ProverPoolCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ProverPool.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ProverPool *ProverPoolTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ProverPool.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ProverPool *ProverPoolTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ProverPool.Contract.contract.Transact(opts, method, params...)
}

// EXITPERIOD is a free data retrieval call binding the contract method 0xc04b5f65.
//
// Solidity: function EXIT_PERIOD() view returns(uint64)
func (_ProverPool *ProverPoolCaller) EXITPERIOD(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _ProverPool.contract.Call(opts, &out, "EXIT_PERIOD")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// EXITPERIOD is a free data retrieval call binding the contract method 0xc04b5f65.
//
// Solidity: function EXIT_PERIOD() view returns(uint64)
func (_ProverPool *ProverPoolSession) EXITPERIOD() (uint64, error) {
	return _ProverPool.Contract.EXITPERIOD(&_ProverPool.CallOpts)
}

// EXITPERIOD is a free data retrieval call binding the contract method 0xc04b5f65.
//
// Solidity: function EXIT_PERIOD() view returns(uint64)
func (_ProverPool *ProverPoolCallerSession) EXITPERIOD() (uint64, error) {
	return _ProverPool.Contract.EXITPERIOD(&_ProverPool.CallOpts)
}

// MAXCAPACITYLOWERBOUND is a free data retrieval call binding the contract method 0x35acc933.
//
// Solidity: function MAX_CAPACITY_LOWER_BOUND() view returns(uint32)
func (_ProverPool *ProverPoolCaller) MAXCAPACITYLOWERBOUND(opts *bind.CallOpts) (uint32, error) {
	var out []interface{}
	err := _ProverPool.contract.Call(opts, &out, "MAX_CAPACITY_LOWER_BOUND")

	if err != nil {
		return *new(uint32), err
	}

	out0 := *abi.ConvertType(out[0], new(uint32)).(*uint32)

	return out0, err

}

// MAXCAPACITYLOWERBOUND is a free data retrieval call binding the contract method 0x35acc933.
//
// Solidity: function MAX_CAPACITY_LOWER_BOUND() view returns(uint32)
func (_ProverPool *ProverPoolSession) MAXCAPACITYLOWERBOUND() (uint32, error) {
	return _ProverPool.Contract.MAXCAPACITYLOWERBOUND(&_ProverPool.CallOpts)
}

// MAXCAPACITYLOWERBOUND is a free data retrieval call binding the contract method 0x35acc933.
//
// Solidity: function MAX_CAPACITY_LOWER_BOUND() view returns(uint32)
func (_ProverPool *ProverPoolCallerSession) MAXCAPACITYLOWERBOUND() (uint32, error) {
	return _ProverPool.Contract.MAXCAPACITYLOWERBOUND(&_ProverPool.CallOpts)
}

// MAXNUMPROVERS is a free data retrieval call binding the contract method 0x62c0fd98.
//
// Solidity: function MAX_NUM_PROVERS() view returns(uint256)
func (_ProverPool *ProverPoolCaller) MAXNUMPROVERS(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _ProverPool.contract.Call(opts, &out, "MAX_NUM_PROVERS")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// MAXNUMPROVERS is a free data retrieval call binding the contract method 0x62c0fd98.
//
// Solidity: function MAX_NUM_PROVERS() view returns(uint256)
func (_ProverPool *ProverPoolSession) MAXNUMPROVERS() (*big.Int, error) {
	return _ProverPool.Contract.MAXNUMPROVERS(&_ProverPool.CallOpts)
}

// MAXNUMPROVERS is a free data retrieval call binding the contract method 0x62c0fd98.
//
// Solidity: function MAX_NUM_PROVERS() view returns(uint256)
func (_ProverPool *ProverPoolCallerSession) MAXNUMPROVERS() (*big.Int, error) {
	return _ProverPool.Contract.MAXNUMPROVERS(&_ProverPool.CallOpts)
}

// MINCHANGEDELAY is a free data retrieval call binding the contract method 0x71aff3a6.
//
// Solidity: function MIN_CHANGE_DELAY() view returns(uint256)
func (_ProverPool *ProverPoolCaller) MINCHANGEDELAY(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _ProverPool.contract.Call(opts, &out, "MIN_CHANGE_DELAY")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// MINCHANGEDELAY is a free data retrieval call binding the contract method 0x71aff3a6.
//
// Solidity: function MIN_CHANGE_DELAY() view returns(uint256)
func (_ProverPool *ProverPoolSession) MINCHANGEDELAY() (*big.Int, error) {
	return _ProverPool.Contract.MINCHANGEDELAY(&_ProverPool.CallOpts)
}

// MINCHANGEDELAY is a free data retrieval call binding the contract method 0x71aff3a6.
//
// Solidity: function MIN_CHANGE_DELAY() view returns(uint256)
func (_ProverPool *ProverPoolCallerSession) MINCHANGEDELAY() (*big.Int, error) {
	return _ProverPool.Contract.MINCHANGEDELAY(&_ProverPool.CallOpts)
}

// MINSLASHAMOUNT is a free data retrieval call binding the contract method 0x1972bc0d.
//
// Solidity: function MIN_SLASH_AMOUNT() view returns(uint64)
func (_ProverPool *ProverPoolCaller) MINSLASHAMOUNT(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _ProverPool.contract.Call(opts, &out, "MIN_SLASH_AMOUNT")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// MINSLASHAMOUNT is a free data retrieval call binding the contract method 0x1972bc0d.
//
// Solidity: function MIN_SLASH_AMOUNT() view returns(uint64)
func (_ProverPool *ProverPoolSession) MINSLASHAMOUNT() (uint64, error) {
	return _ProverPool.Contract.MINSLASHAMOUNT(&_ProverPool.CallOpts)
}

// MINSLASHAMOUNT is a free data retrieval call binding the contract method 0x1972bc0d.
//
// Solidity: function MIN_SLASH_AMOUNT() view returns(uint64)
func (_ProverPool *ProverPoolCallerSession) MINSLASHAMOUNT() (uint64, error) {
	return _ProverPool.Contract.MINSLASHAMOUNT(&_ProverPool.CallOpts)
}

// MINSTAKEPERCAPACITY is a free data retrieval call binding the contract method 0x7d62c057.
//
// Solidity: function MIN_STAKE_PER_CAPACITY() view returns(uint64)
func (_ProverPool *ProverPoolCaller) MINSTAKEPERCAPACITY(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _ProverPool.contract.Call(opts, &out, "MIN_STAKE_PER_CAPACITY")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// MINSTAKEPERCAPACITY is a free data retrieval call binding the contract method 0x7d62c057.
//
// Solidity: function MIN_STAKE_PER_CAPACITY() view returns(uint64)
func (_ProverPool *ProverPoolSession) MINSTAKEPERCAPACITY() (uint64, error) {
	return _ProverPool.Contract.MINSTAKEPERCAPACITY(&_ProverPool.CallOpts)
}

// MINSTAKEPERCAPACITY is a free data retrieval call binding the contract method 0x7d62c057.
//
// Solidity: function MIN_STAKE_PER_CAPACITY() view returns(uint64)
func (_ProverPool *ProverPoolCallerSession) MINSTAKEPERCAPACITY() (uint64, error) {
	return _ProverPool.Contract.MINSTAKEPERCAPACITY(&_ProverPool.CallOpts)
}

// SLASHPOINTS is a free data retrieval call binding the contract method 0xdd9fb65c.
//
// Solidity: function SLASH_POINTS() view returns(uint64)
func (_ProverPool *ProverPoolCaller) SLASHPOINTS(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _ProverPool.contract.Call(opts, &out, "SLASH_POINTS")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// SLASHPOINTS is a free data retrieval call binding the contract method 0xdd9fb65c.
//
// Solidity: function SLASH_POINTS() view returns(uint64)
func (_ProverPool *ProverPoolSession) SLASHPOINTS() (uint64, error) {
	return _ProverPool.Contract.SLASHPOINTS(&_ProverPool.CallOpts)
}

// SLASHPOINTS is a free data retrieval call binding the contract method 0xdd9fb65c.
//
// Solidity: function SLASH_POINTS() view returns(uint64)
func (_ProverPool *ProverPoolCallerSession) SLASHPOINTS() (uint64, error) {
	return _ProverPool.Contract.SLASHPOINTS(&_ProverPool.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_ProverPool *ProverPoolCaller) AddressManager(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ProverPool.contract.Call(opts, &out, "addressManager")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_ProverPool *ProverPoolSession) AddressManager() (common.Address, error) {
	return _ProverPool.Contract.AddressManager(&_ProverPool.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_ProverPool *ProverPoolCallerSession) AddressManager() (common.Address, error) {
	return _ProverPool.Contract.AddressManager(&_ProverPool.CallOpts)
}

// GetCapacity is a free data retrieval call binding the contract method 0xc40000d4.
//
// Solidity: function getCapacity() view returns(uint256 capacity)
func (_ProverPool *ProverPoolCaller) GetCapacity(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _ProverPool.contract.Call(opts, &out, "getCapacity")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetCapacity is a free data retrieval call binding the contract method 0xc40000d4.
//
// Solidity: function getCapacity() view returns(uint256 capacity)
func (_ProverPool *ProverPoolSession) GetCapacity() (*big.Int, error) {
	return _ProverPool.Contract.GetCapacity(&_ProverPool.CallOpts)
}

// GetCapacity is a free data retrieval call binding the contract method 0xc40000d4.
//
// Solidity: function getCapacity() view returns(uint256 capacity)
func (_ProverPool *ProverPoolCallerSession) GetCapacity() (*big.Int, error) {
	return _ProverPool.Contract.GetCapacity(&_ProverPool.CallOpts)
}

// GetProverWeights is a free data retrieval call binding the contract method 0x3acba718.
//
// Solidity: function getProverWeights(uint32 feePerGas) view returns(uint256[32] weights, uint32[32] erpg)
func (_ProverPool *ProverPoolCaller) GetProverWeights(opts *bind.CallOpts, feePerGas uint32) (struct {
	Weights [32]*big.Int
	Erpg    [32]uint32
}, error) {
	var out []interface{}
	err := _ProverPool.contract.Call(opts, &out, "getProverWeights", feePerGas)

	outstruct := new(struct {
		Weights [32]*big.Int
		Erpg    [32]uint32
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Weights = *abi.ConvertType(out[0], new([32]*big.Int)).(*[32]*big.Int)
	outstruct.Erpg = *abi.ConvertType(out[1], new([32]uint32)).(*[32]uint32)

	return *outstruct, err

}

// GetProverWeights is a free data retrieval call binding the contract method 0x3acba718.
//
// Solidity: function getProverWeights(uint32 feePerGas) view returns(uint256[32] weights, uint32[32] erpg)
func (_ProverPool *ProverPoolSession) GetProverWeights(feePerGas uint32) (struct {
	Weights [32]*big.Int
	Erpg    [32]uint32
}, error) {
	return _ProverPool.Contract.GetProverWeights(&_ProverPool.CallOpts, feePerGas)
}

// GetProverWeights is a free data retrieval call binding the contract method 0x3acba718.
//
// Solidity: function getProverWeights(uint32 feePerGas) view returns(uint256[32] weights, uint32[32] erpg)
func (_ProverPool *ProverPoolCallerSession) GetProverWeights(feePerGas uint32) (struct {
	Weights [32]*big.Int
	Erpg    [32]uint32
}, error) {
	return _ProverPool.Contract.GetProverWeights(&_ProverPool.CallOpts, feePerGas)
}

// GetProvers is a free data retrieval call binding the contract method 0xc0bfd036.
//
// Solidity: function getProvers() view returns((uint64,uint32,uint32)[] _provers, address[] _stakers)
func (_ProverPool *ProverPoolCaller) GetProvers(opts *bind.CallOpts) (struct {
	Provers []ProverPoolProver
	Stakers []common.Address
}, error) {
	var out []interface{}
	err := _ProverPool.contract.Call(opts, &out, "getProvers")

	outstruct := new(struct {
		Provers []ProverPoolProver
		Stakers []common.Address
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Provers = *abi.ConvertType(out[0], new([]ProverPoolProver)).(*[]ProverPoolProver)
	outstruct.Stakers = *abi.ConvertType(out[1], new([]common.Address)).(*[]common.Address)

	return *outstruct, err

}

// GetProvers is a free data retrieval call binding the contract method 0xc0bfd036.
//
// Solidity: function getProvers() view returns((uint64,uint32,uint32)[] _provers, address[] _stakers)
func (_ProverPool *ProverPoolSession) GetProvers() (struct {
	Provers []ProverPoolProver
	Stakers []common.Address
}, error) {
	return _ProverPool.Contract.GetProvers(&_ProverPool.CallOpts)
}

// GetProvers is a free data retrieval call binding the contract method 0xc0bfd036.
//
// Solidity: function getProvers() view returns((uint64,uint32,uint32)[] _provers, address[] _stakers)
func (_ProverPool *ProverPoolCallerSession) GetProvers() (struct {
	Provers []ProverPoolProver
	Stakers []common.Address
}, error) {
	return _ProverPool.Contract.GetProvers(&_ProverPool.CallOpts)
}

// GetStaker is a free data retrieval call binding the contract method 0xa23c44b1.
//
// Solidity: function getStaker(address addr) view returns((uint64,uint64,uint32,uint32) staker, (uint64,uint32,uint32) prover)
func (_ProverPool *ProverPoolCaller) GetStaker(opts *bind.CallOpts, addr common.Address) (struct {
	Staker ProverPoolStaker
	Prover ProverPoolProver
}, error) {
	var out []interface{}
	err := _ProverPool.contract.Call(opts, &out, "getStaker", addr)

	outstruct := new(struct {
		Staker ProverPoolStaker
		Prover ProverPoolProver
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Staker = *abi.ConvertType(out[0], new(ProverPoolStaker)).(*ProverPoolStaker)
	outstruct.Prover = *abi.ConvertType(out[1], new(ProverPoolProver)).(*ProverPoolProver)

	return *outstruct, err

}

// GetStaker is a free data retrieval call binding the contract method 0xa23c44b1.
//
// Solidity: function getStaker(address addr) view returns((uint64,uint64,uint32,uint32) staker, (uint64,uint32,uint32) prover)
func (_ProverPool *ProverPoolSession) GetStaker(addr common.Address) (struct {
	Staker ProverPoolStaker
	Prover ProverPoolProver
}, error) {
	return _ProverPool.Contract.GetStaker(&_ProverPool.CallOpts, addr)
}

// GetStaker is a free data retrieval call binding the contract method 0xa23c44b1.
//
// Solidity: function getStaker(address addr) view returns((uint64,uint64,uint32,uint32) staker, (uint64,uint32,uint32) prover)
func (_ProverPool *ProverPoolCallerSession) GetStaker(addr common.Address) (struct {
	Staker ProverPoolStaker
	Prover ProverPoolProver
}, error) {
	return _ProverPool.Contract.GetStaker(&_ProverPool.CallOpts, addr)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ProverPool *ProverPoolCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ProverPool.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ProverPool *ProverPoolSession) Owner() (common.Address, error) {
	return _ProverPool.Contract.Owner(&_ProverPool.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ProverPool *ProverPoolCallerSession) Owner() (common.Address, error) {
	return _ProverPool.Contract.Owner(&_ProverPool.CallOpts)
}

// ProverIdToAddress is a free data retrieval call binding the contract method 0xf064afa0.
//
// Solidity: function proverIdToAddress(uint256 id) view returns(address prover)
func (_ProverPool *ProverPoolCaller) ProverIdToAddress(opts *bind.CallOpts, id *big.Int) (common.Address, error) {
	var out []interface{}
	err := _ProverPool.contract.Call(opts, &out, "proverIdToAddress", id)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// ProverIdToAddress is a free data retrieval call binding the contract method 0xf064afa0.
//
// Solidity: function proverIdToAddress(uint256 id) view returns(address prover)
func (_ProverPool *ProverPoolSession) ProverIdToAddress(id *big.Int) (common.Address, error) {
	return _ProverPool.Contract.ProverIdToAddress(&_ProverPool.CallOpts, id)
}

// ProverIdToAddress is a free data retrieval call binding the contract method 0xf064afa0.
//
// Solidity: function proverIdToAddress(uint256 id) view returns(address prover)
func (_ProverPool *ProverPoolCallerSession) ProverIdToAddress(id *big.Int) (common.Address, error) {
	return _ProverPool.Contract.ProverIdToAddress(&_ProverPool.CallOpts, id)
}

// Provers is a free data retrieval call binding the contract method 0xfd1190ea.
//
// Solidity: function provers(uint256 ) view returns(uint64 stakedAmount, uint32 rewardPerGas, uint32 currentCapacity)
func (_ProverPool *ProverPoolCaller) Provers(opts *bind.CallOpts, arg0 *big.Int) (struct {
	StakedAmount    uint64
	RewardPerGas    uint32
	CurrentCapacity uint32
}, error) {
	var out []interface{}
	err := _ProverPool.contract.Call(opts, &out, "provers", arg0)

	outstruct := new(struct {
		StakedAmount    uint64
		RewardPerGas    uint32
		CurrentCapacity uint32
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.StakedAmount = *abi.ConvertType(out[0], new(uint64)).(*uint64)
	outstruct.RewardPerGas = *abi.ConvertType(out[1], new(uint32)).(*uint32)
	outstruct.CurrentCapacity = *abi.ConvertType(out[2], new(uint32)).(*uint32)

	return *outstruct, err

}

// Provers is a free data retrieval call binding the contract method 0xfd1190ea.
//
// Solidity: function provers(uint256 ) view returns(uint64 stakedAmount, uint32 rewardPerGas, uint32 currentCapacity)
func (_ProverPool *ProverPoolSession) Provers(arg0 *big.Int) (struct {
	StakedAmount    uint64
	RewardPerGas    uint32
	CurrentCapacity uint32
}, error) {
	return _ProverPool.Contract.Provers(&_ProverPool.CallOpts, arg0)
}

// Provers is a free data retrieval call binding the contract method 0xfd1190ea.
//
// Solidity: function provers(uint256 ) view returns(uint64 stakedAmount, uint32 rewardPerGas, uint32 currentCapacity)
func (_ProverPool *ProverPoolCallerSession) Provers(arg0 *big.Int) (struct {
	StakedAmount    uint64
	RewardPerGas    uint32
	CurrentCapacity uint32
}, error) {
	return _ProverPool.Contract.Provers(&_ProverPool.CallOpts, arg0)
}

// Resolve is a free data retrieval call binding the contract method 0x6c6563f6.
//
// Solidity: function resolve(uint256 chainId, bytes32 name, bool allowZeroAddress) view returns(address)
func (_ProverPool *ProverPoolCaller) Resolve(opts *bind.CallOpts, chainId *big.Int, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _ProverPool.contract.Call(opts, &out, "resolve", chainId, name, allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve is a free data retrieval call binding the contract method 0x6c6563f6.
//
// Solidity: function resolve(uint256 chainId, bytes32 name, bool allowZeroAddress) view returns(address)
func (_ProverPool *ProverPoolSession) Resolve(chainId *big.Int, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _ProverPool.Contract.Resolve(&_ProverPool.CallOpts, chainId, name, allowZeroAddress)
}

// Resolve is a free data retrieval call binding the contract method 0x6c6563f6.
//
// Solidity: function resolve(uint256 chainId, bytes32 name, bool allowZeroAddress) view returns(address)
func (_ProverPool *ProverPoolCallerSession) Resolve(chainId *big.Int, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _ProverPool.Contract.Resolve(&_ProverPool.CallOpts, chainId, name, allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 name, bool allowZeroAddress) view returns(address)
func (_ProverPool *ProverPoolCaller) Resolve0(opts *bind.CallOpts, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _ProverPool.contract.Call(opts, &out, "resolve0", name, allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 name, bool allowZeroAddress) view returns(address)
func (_ProverPool *ProverPoolSession) Resolve0(name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _ProverPool.Contract.Resolve0(&_ProverPool.CallOpts, name, allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 name, bool allowZeroAddress) view returns(address)
func (_ProverPool *ProverPoolCallerSession) Resolve0(name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _ProverPool.Contract.Resolve0(&_ProverPool.CallOpts, name, allowZeroAddress)
}

// Stakers is a free data retrieval call binding the contract method 0x9168ae72.
//
// Solidity: function stakers(address staker) view returns(uint64 exitRequestedAt, uint64 exitAmount, uint32 maxCapacity, uint32 proverId)
func (_ProverPool *ProverPoolCaller) Stakers(opts *bind.CallOpts, staker common.Address) (struct {
	ExitRequestedAt uint64
	ExitAmount      uint64
	MaxCapacity     uint32
	ProverId        uint32
}, error) {
	var out []interface{}
	err := _ProverPool.contract.Call(opts, &out, "stakers", staker)

	outstruct := new(struct {
		ExitRequestedAt uint64
		ExitAmount      uint64
		MaxCapacity     uint32
		ProverId        uint32
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.ExitRequestedAt = *abi.ConvertType(out[0], new(uint64)).(*uint64)
	outstruct.ExitAmount = *abi.ConvertType(out[1], new(uint64)).(*uint64)
	outstruct.MaxCapacity = *abi.ConvertType(out[2], new(uint32)).(*uint32)
	outstruct.ProverId = *abi.ConvertType(out[3], new(uint32)).(*uint32)

	return *outstruct, err

}

// Stakers is a free data retrieval call binding the contract method 0x9168ae72.
//
// Solidity: function stakers(address staker) view returns(uint64 exitRequestedAt, uint64 exitAmount, uint32 maxCapacity, uint32 proverId)
func (_ProverPool *ProverPoolSession) Stakers(staker common.Address) (struct {
	ExitRequestedAt uint64
	ExitAmount      uint64
	MaxCapacity     uint32
	ProverId        uint32
}, error) {
	return _ProverPool.Contract.Stakers(&_ProverPool.CallOpts, staker)
}

// Stakers is a free data retrieval call binding the contract method 0x9168ae72.
//
// Solidity: function stakers(address staker) view returns(uint64 exitRequestedAt, uint64 exitAmount, uint32 maxCapacity, uint32 proverId)
func (_ProverPool *ProverPoolCallerSession) Stakers(staker common.Address) (struct {
	ExitRequestedAt uint64
	ExitAmount      uint64
	MaxCapacity     uint32
	ProverId        uint32
}, error) {
	return _ProverPool.Contract.Stakers(&_ProverPool.CallOpts, staker)
}

// AssignProver is a paid mutator transaction binding the contract method 0xbd849fe9.
//
// Solidity: function assignProver(uint64 blockId, uint32 feePerGas) returns(address prover, uint32 rewardPerGas)
func (_ProverPool *ProverPoolTransactor) AssignProver(opts *bind.TransactOpts, blockId uint64, feePerGas uint32) (*types.Transaction, error) {
	return _ProverPool.contract.Transact(opts, "assignProver", blockId, feePerGas)
}

// AssignProver is a paid mutator transaction binding the contract method 0xbd849fe9.
//
// Solidity: function assignProver(uint64 blockId, uint32 feePerGas) returns(address prover, uint32 rewardPerGas)
func (_ProverPool *ProverPoolSession) AssignProver(blockId uint64, feePerGas uint32) (*types.Transaction, error) {
	return _ProverPool.Contract.AssignProver(&_ProverPool.TransactOpts, blockId, feePerGas)
}

// AssignProver is a paid mutator transaction binding the contract method 0xbd849fe9.
//
// Solidity: function assignProver(uint64 blockId, uint32 feePerGas) returns(address prover, uint32 rewardPerGas)
func (_ProverPool *ProverPoolTransactorSession) AssignProver(blockId uint64, feePerGas uint32) (*types.Transaction, error) {
	return _ProverPool.Contract.AssignProver(&_ProverPool.TransactOpts, blockId, feePerGas)
}

// Exit is a paid mutator transaction binding the contract method 0xe9fad8ee.
//
// Solidity: function exit() returns()
func (_ProverPool *ProverPoolTransactor) Exit(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ProverPool.contract.Transact(opts, "exit")
}

// Exit is a paid mutator transaction binding the contract method 0xe9fad8ee.
//
// Solidity: function exit() returns()
func (_ProverPool *ProverPoolSession) Exit() (*types.Transaction, error) {
	return _ProverPool.Contract.Exit(&_ProverPool.TransactOpts)
}

// Exit is a paid mutator transaction binding the contract method 0xe9fad8ee.
//
// Solidity: function exit() returns()
func (_ProverPool *ProverPoolTransactorSession) Exit() (*types.Transaction, error) {
	return _ProverPool.Contract.Exit(&_ProverPool.TransactOpts)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _addressManager) returns()
func (_ProverPool *ProverPoolTransactor) Init(opts *bind.TransactOpts, _addressManager common.Address) (*types.Transaction, error) {
	return _ProverPool.contract.Transact(opts, "init", _addressManager)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _addressManager) returns()
func (_ProverPool *ProverPoolSession) Init(_addressManager common.Address) (*types.Transaction, error) {
	return _ProverPool.Contract.Init(&_ProverPool.TransactOpts, _addressManager)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _addressManager) returns()
func (_ProverPool *ProverPoolTransactorSession) Init(_addressManager common.Address) (*types.Transaction, error) {
	return _ProverPool.Contract.Init(&_ProverPool.TransactOpts, _addressManager)
}

// ReleaseProver is a paid mutator transaction binding the contract method 0xcba0414f.
//
// Solidity: function releaseProver(address addr) returns()
func (_ProverPool *ProverPoolTransactor) ReleaseProver(opts *bind.TransactOpts, addr common.Address) (*types.Transaction, error) {
	return _ProverPool.contract.Transact(opts, "releaseProver", addr)
}

// ReleaseProver is a paid mutator transaction binding the contract method 0xcba0414f.
//
// Solidity: function releaseProver(address addr) returns()
func (_ProverPool *ProverPoolSession) ReleaseProver(addr common.Address) (*types.Transaction, error) {
	return _ProverPool.Contract.ReleaseProver(&_ProverPool.TransactOpts, addr)
}

// ReleaseProver is a paid mutator transaction binding the contract method 0xcba0414f.
//
// Solidity: function releaseProver(address addr) returns()
func (_ProverPool *ProverPoolTransactorSession) ReleaseProver(addr common.Address) (*types.Transaction, error) {
	return _ProverPool.Contract.ReleaseProver(&_ProverPool.TransactOpts, addr)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ProverPool *ProverPoolTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ProverPool.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ProverPool *ProverPoolSession) RenounceOwnership() (*types.Transaction, error) {
	return _ProverPool.Contract.RenounceOwnership(&_ProverPool.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ProverPool *ProverPoolTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _ProverPool.Contract.RenounceOwnership(&_ProverPool.TransactOpts)
}

// SetAddressManager is a paid mutator transaction binding the contract method 0x0652b57a.
//
// Solidity: function setAddressManager(address newAddressManager) returns()
func (_ProverPool *ProverPoolTransactor) SetAddressManager(opts *bind.TransactOpts, newAddressManager common.Address) (*types.Transaction, error) {
	return _ProverPool.contract.Transact(opts, "setAddressManager", newAddressManager)
}

// SetAddressManager is a paid mutator transaction binding the contract method 0x0652b57a.
//
// Solidity: function setAddressManager(address newAddressManager) returns()
func (_ProverPool *ProverPoolSession) SetAddressManager(newAddressManager common.Address) (*types.Transaction, error) {
	return _ProverPool.Contract.SetAddressManager(&_ProverPool.TransactOpts, newAddressManager)
}

// SetAddressManager is a paid mutator transaction binding the contract method 0x0652b57a.
//
// Solidity: function setAddressManager(address newAddressManager) returns()
func (_ProverPool *ProverPoolTransactorSession) SetAddressManager(newAddressManager common.Address) (*types.Transaction, error) {
	return _ProverPool.Contract.SetAddressManager(&_ProverPool.TransactOpts, newAddressManager)
}

// SlashProver is a paid mutator transaction binding the contract method 0xcd362a5b.
//
// Solidity: function slashProver(address addr) returns()
func (_ProverPool *ProverPoolTransactor) SlashProver(opts *bind.TransactOpts, addr common.Address) (*types.Transaction, error) {
	return _ProverPool.contract.Transact(opts, "slashProver", addr)
}

// SlashProver is a paid mutator transaction binding the contract method 0xcd362a5b.
//
// Solidity: function slashProver(address addr) returns()
func (_ProverPool *ProverPoolSession) SlashProver(addr common.Address) (*types.Transaction, error) {
	return _ProverPool.Contract.SlashProver(&_ProverPool.TransactOpts, addr)
}

// SlashProver is a paid mutator transaction binding the contract method 0xcd362a5b.
//
// Solidity: function slashProver(address addr) returns()
func (_ProverPool *ProverPoolTransactorSession) SlashProver(addr common.Address) (*types.Transaction, error) {
	return _ProverPool.Contract.SlashProver(&_ProverPool.TransactOpts, addr)
}

// Stake is a paid mutator transaction binding the contract method 0xb19ead66.
//
// Solidity: function stake(uint64 amount, uint32 rewardPerGas, uint32 maxCapacity) returns()
func (_ProverPool *ProverPoolTransactor) Stake(opts *bind.TransactOpts, amount uint64, rewardPerGas uint32, maxCapacity uint32) (*types.Transaction, error) {
	return _ProverPool.contract.Transact(opts, "stake", amount, rewardPerGas, maxCapacity)
}

// Stake is a paid mutator transaction binding the contract method 0xb19ead66.
//
// Solidity: function stake(uint64 amount, uint32 rewardPerGas, uint32 maxCapacity) returns()
func (_ProverPool *ProverPoolSession) Stake(amount uint64, rewardPerGas uint32, maxCapacity uint32) (*types.Transaction, error) {
	return _ProverPool.Contract.Stake(&_ProverPool.TransactOpts, amount, rewardPerGas, maxCapacity)
}

// Stake is a paid mutator transaction binding the contract method 0xb19ead66.
//
// Solidity: function stake(uint64 amount, uint32 rewardPerGas, uint32 maxCapacity) returns()
func (_ProverPool *ProverPoolTransactorSession) Stake(amount uint64, rewardPerGas uint32, maxCapacity uint32) (*types.Transaction, error) {
	return _ProverPool.Contract.Stake(&_ProverPool.TransactOpts, amount, rewardPerGas, maxCapacity)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ProverPool *ProverPoolTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _ProverPool.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ProverPool *ProverPoolSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _ProverPool.Contract.TransferOwnership(&_ProverPool.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ProverPool *ProverPoolTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _ProverPool.Contract.TransferOwnership(&_ProverPool.TransactOpts, newOwner)
}

// Withdraw is a paid mutator transaction binding the contract method 0x3ccfd60b.
//
// Solidity: function withdraw() returns()
func (_ProverPool *ProverPoolTransactor) Withdraw(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ProverPool.contract.Transact(opts, "withdraw")
}

// Withdraw is a paid mutator transaction binding the contract method 0x3ccfd60b.
//
// Solidity: function withdraw() returns()
func (_ProverPool *ProverPoolSession) Withdraw() (*types.Transaction, error) {
	return _ProverPool.Contract.Withdraw(&_ProverPool.TransactOpts)
}

// Withdraw is a paid mutator transaction binding the contract method 0x3ccfd60b.
//
// Solidity: function withdraw() returns()
func (_ProverPool *ProverPoolTransactorSession) Withdraw() (*types.Transaction, error) {
	return _ProverPool.Contract.Withdraw(&_ProverPool.TransactOpts)
}

// ProverPoolAddressManagerChangedIterator is returned from FilterAddressManagerChanged and is used to iterate over the raw logs and unpacked data for AddressManagerChanged events raised by the ProverPool contract.
type ProverPoolAddressManagerChangedIterator struct {
	Event *ProverPoolAddressManagerChanged // Event containing the contract specifics and raw log

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
func (it *ProverPoolAddressManagerChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ProverPoolAddressManagerChanged)
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
		it.Event = new(ProverPoolAddressManagerChanged)
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
func (it *ProverPoolAddressManagerChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ProverPoolAddressManagerChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ProverPoolAddressManagerChanged represents a AddressManagerChanged event raised by the ProverPool contract.
type ProverPoolAddressManagerChanged struct {
	AddressManager common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterAddressManagerChanged is a free log retrieval operation binding the contract event 0x399ded90cb5ed8d89ef7e76ff4af65c373f06d3bf5d7eef55f4228e7b702a18b.
//
// Solidity: event AddressManagerChanged(address addressManager)
func (_ProverPool *ProverPoolFilterer) FilterAddressManagerChanged(opts *bind.FilterOpts) (*ProverPoolAddressManagerChangedIterator, error) {

	logs, sub, err := _ProverPool.contract.FilterLogs(opts, "AddressManagerChanged")
	if err != nil {
		return nil, err
	}
	return &ProverPoolAddressManagerChangedIterator{contract: _ProverPool.contract, event: "AddressManagerChanged", logs: logs, sub: sub}, nil
}

// WatchAddressManagerChanged is a free log subscription operation binding the contract event 0x399ded90cb5ed8d89ef7e76ff4af65c373f06d3bf5d7eef55f4228e7b702a18b.
//
// Solidity: event AddressManagerChanged(address addressManager)
func (_ProverPool *ProverPoolFilterer) WatchAddressManagerChanged(opts *bind.WatchOpts, sink chan<- *ProverPoolAddressManagerChanged) (event.Subscription, error) {

	logs, sub, err := _ProverPool.contract.WatchLogs(opts, "AddressManagerChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ProverPoolAddressManagerChanged)
				if err := _ProverPool.contract.UnpackLog(event, "AddressManagerChanged", log); err != nil {
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

// ParseAddressManagerChanged is a log parse operation binding the contract event 0x399ded90cb5ed8d89ef7e76ff4af65c373f06d3bf5d7eef55f4228e7b702a18b.
//
// Solidity: event AddressManagerChanged(address addressManager)
func (_ProverPool *ProverPoolFilterer) ParseAddressManagerChanged(log types.Log) (*ProverPoolAddressManagerChanged, error) {
	event := new(ProverPoolAddressManagerChanged)
	if err := _ProverPool.contract.UnpackLog(event, "AddressManagerChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ProverPoolExitedIterator is returned from FilterExited and is used to iterate over the raw logs and unpacked data for Exited events raised by the ProverPool contract.
type ProverPoolExitedIterator struct {
	Event *ProverPoolExited // Event containing the contract specifics and raw log

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
func (it *ProverPoolExitedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ProverPoolExited)
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
		it.Event = new(ProverPoolExited)
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
func (it *ProverPoolExitedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ProverPoolExitedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ProverPoolExited represents a Exited event raised by the ProverPool contract.
type ProverPoolExited struct {
	Addr   common.Address
	Amount uint64
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterExited is a free log retrieval operation binding the contract event 0x7b870040d0137f84191e3e446a10f48b5ac5d26ec96be3f795fcfc4c954410fe.
//
// Solidity: event Exited(address indexed addr, uint64 amount)
func (_ProverPool *ProverPoolFilterer) FilterExited(opts *bind.FilterOpts, addr []common.Address) (*ProverPoolExitedIterator, error) {

	var addrRule []interface{}
	for _, addrItem := range addr {
		addrRule = append(addrRule, addrItem)
	}

	logs, sub, err := _ProverPool.contract.FilterLogs(opts, "Exited", addrRule)
	if err != nil {
		return nil, err
	}
	return &ProverPoolExitedIterator{contract: _ProverPool.contract, event: "Exited", logs: logs, sub: sub}, nil
}

// WatchExited is a free log subscription operation binding the contract event 0x7b870040d0137f84191e3e446a10f48b5ac5d26ec96be3f795fcfc4c954410fe.
//
// Solidity: event Exited(address indexed addr, uint64 amount)
func (_ProverPool *ProverPoolFilterer) WatchExited(opts *bind.WatchOpts, sink chan<- *ProverPoolExited, addr []common.Address) (event.Subscription, error) {

	var addrRule []interface{}
	for _, addrItem := range addr {
		addrRule = append(addrRule, addrItem)
	}

	logs, sub, err := _ProverPool.contract.WatchLogs(opts, "Exited", addrRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ProverPoolExited)
				if err := _ProverPool.contract.UnpackLog(event, "Exited", log); err != nil {
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

// ParseExited is a log parse operation binding the contract event 0x7b870040d0137f84191e3e446a10f48b5ac5d26ec96be3f795fcfc4c954410fe.
//
// Solidity: event Exited(address indexed addr, uint64 amount)
func (_ProverPool *ProverPoolFilterer) ParseExited(log types.Log) (*ProverPoolExited, error) {
	event := new(ProverPoolExited)
	if err := _ProverPool.contract.UnpackLog(event, "Exited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ProverPoolInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the ProverPool contract.
type ProverPoolInitializedIterator struct {
	Event *ProverPoolInitialized // Event containing the contract specifics and raw log

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
func (it *ProverPoolInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ProverPoolInitialized)
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
		it.Event = new(ProverPoolInitialized)
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
func (it *ProverPoolInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ProverPoolInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ProverPoolInitialized represents a Initialized event raised by the ProverPool contract.
type ProverPoolInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_ProverPool *ProverPoolFilterer) FilterInitialized(opts *bind.FilterOpts) (*ProverPoolInitializedIterator, error) {

	logs, sub, err := _ProverPool.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &ProverPoolInitializedIterator{contract: _ProverPool.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_ProverPool *ProverPoolFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *ProverPoolInitialized) (event.Subscription, error) {

	logs, sub, err := _ProverPool.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ProverPoolInitialized)
				if err := _ProverPool.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_ProverPool *ProverPoolFilterer) ParseInitialized(log types.Log) (*ProverPoolInitialized, error) {
	event := new(ProverPoolInitialized)
	if err := _ProverPool.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ProverPoolOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the ProverPool contract.
type ProverPoolOwnershipTransferredIterator struct {
	Event *ProverPoolOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *ProverPoolOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ProverPoolOwnershipTransferred)
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
		it.Event = new(ProverPoolOwnershipTransferred)
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
func (it *ProverPoolOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ProverPoolOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ProverPoolOwnershipTransferred represents a OwnershipTransferred event raised by the ProverPool contract.
type ProverPoolOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_ProverPool *ProverPoolFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*ProverPoolOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ProverPool.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &ProverPoolOwnershipTransferredIterator{contract: _ProverPool.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_ProverPool *ProverPoolFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *ProverPoolOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ProverPool.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ProverPoolOwnershipTransferred)
				if err := _ProverPool.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_ProverPool *ProverPoolFilterer) ParseOwnershipTransferred(log types.Log) (*ProverPoolOwnershipTransferred, error) {
	event := new(ProverPoolOwnershipTransferred)
	if err := _ProverPool.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ProverPoolSlashedIterator is returned from FilterSlashed and is used to iterate over the raw logs and unpacked data for Slashed events raised by the ProverPool contract.
type ProverPoolSlashedIterator struct {
	Event *ProverPoolSlashed // Event containing the contract specifics and raw log

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
func (it *ProverPoolSlashedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ProverPoolSlashed)
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
		it.Event = new(ProverPoolSlashed)
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
func (it *ProverPoolSlashedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ProverPoolSlashedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ProverPoolSlashed represents a Slashed event raised by the ProverPool contract.
type ProverPoolSlashed struct {
	Addr   common.Address
	Amount uint64
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterSlashed is a free log retrieval operation binding the contract event 0xdd80bbe216163c1792fa59b50e56f1a7ac79674c4815b65da0ef875a39655e08.
//
// Solidity: event Slashed(address indexed addr, uint64 amount)
func (_ProverPool *ProverPoolFilterer) FilterSlashed(opts *bind.FilterOpts, addr []common.Address) (*ProverPoolSlashedIterator, error) {

	var addrRule []interface{}
	for _, addrItem := range addr {
		addrRule = append(addrRule, addrItem)
	}

	logs, sub, err := _ProverPool.contract.FilterLogs(opts, "Slashed", addrRule)
	if err != nil {
		return nil, err
	}
	return &ProverPoolSlashedIterator{contract: _ProverPool.contract, event: "Slashed", logs: logs, sub: sub}, nil
}

// WatchSlashed is a free log subscription operation binding the contract event 0xdd80bbe216163c1792fa59b50e56f1a7ac79674c4815b65da0ef875a39655e08.
//
// Solidity: event Slashed(address indexed addr, uint64 amount)
func (_ProverPool *ProverPoolFilterer) WatchSlashed(opts *bind.WatchOpts, sink chan<- *ProverPoolSlashed, addr []common.Address) (event.Subscription, error) {

	var addrRule []interface{}
	for _, addrItem := range addr {
		addrRule = append(addrRule, addrItem)
	}

	logs, sub, err := _ProverPool.contract.WatchLogs(opts, "Slashed", addrRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ProverPoolSlashed)
				if err := _ProverPool.contract.UnpackLog(event, "Slashed", log); err != nil {
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

// ParseSlashed is a log parse operation binding the contract event 0xdd80bbe216163c1792fa59b50e56f1a7ac79674c4815b65da0ef875a39655e08.
//
// Solidity: event Slashed(address indexed addr, uint64 amount)
func (_ProverPool *ProverPoolFilterer) ParseSlashed(log types.Log) (*ProverPoolSlashed, error) {
	event := new(ProverPoolSlashed)
	if err := _ProverPool.contract.UnpackLog(event, "Slashed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ProverPoolStakedIterator is returned from FilterStaked and is used to iterate over the raw logs and unpacked data for Staked events raised by the ProverPool contract.
type ProverPoolStakedIterator struct {
	Event *ProverPoolStaked // Event containing the contract specifics and raw log

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
func (it *ProverPoolStakedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ProverPoolStaked)
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
		it.Event = new(ProverPoolStaked)
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
func (it *ProverPoolStakedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ProverPoolStakedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ProverPoolStaked represents a Staked event raised by the ProverPool contract.
type ProverPoolStaked struct {
	Addr            common.Address
	Amount          uint64
	RewardPerGas    uint32
	CurrentCapacity uint32
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterStaked is a free log retrieval operation binding the contract event 0x5ca6ec890c0c084d4fe6c6c49e6aea6fd8dbf1460730c83b5b12bf22811851e3.
//
// Solidity: event Staked(address indexed addr, uint64 amount, uint32 rewardPerGas, uint32 currentCapacity)
func (_ProverPool *ProverPoolFilterer) FilterStaked(opts *bind.FilterOpts, addr []common.Address) (*ProverPoolStakedIterator, error) {

	var addrRule []interface{}
	for _, addrItem := range addr {
		addrRule = append(addrRule, addrItem)
	}

	logs, sub, err := _ProverPool.contract.FilterLogs(opts, "Staked", addrRule)
	if err != nil {
		return nil, err
	}
	return &ProverPoolStakedIterator{contract: _ProverPool.contract, event: "Staked", logs: logs, sub: sub}, nil
}

// WatchStaked is a free log subscription operation binding the contract event 0x5ca6ec890c0c084d4fe6c6c49e6aea6fd8dbf1460730c83b5b12bf22811851e3.
//
// Solidity: event Staked(address indexed addr, uint64 amount, uint32 rewardPerGas, uint32 currentCapacity)
func (_ProverPool *ProverPoolFilterer) WatchStaked(opts *bind.WatchOpts, sink chan<- *ProverPoolStaked, addr []common.Address) (event.Subscription, error) {

	var addrRule []interface{}
	for _, addrItem := range addr {
		addrRule = append(addrRule, addrItem)
	}

	logs, sub, err := _ProverPool.contract.WatchLogs(opts, "Staked", addrRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ProverPoolStaked)
				if err := _ProverPool.contract.UnpackLog(event, "Staked", log); err != nil {
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

// ParseStaked is a log parse operation binding the contract event 0x5ca6ec890c0c084d4fe6c6c49e6aea6fd8dbf1460730c83b5b12bf22811851e3.
//
// Solidity: event Staked(address indexed addr, uint64 amount, uint32 rewardPerGas, uint32 currentCapacity)
func (_ProverPool *ProverPoolFilterer) ParseStaked(log types.Log) (*ProverPoolStaked, error) {
	event := new(ProverPoolStaked)
	if err := _ProverPool.contract.UnpackLog(event, "Staked", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ProverPoolWithdrawnIterator is returned from FilterWithdrawn and is used to iterate over the raw logs and unpacked data for Withdrawn events raised by the ProverPool contract.
type ProverPoolWithdrawnIterator struct {
	Event *ProverPoolWithdrawn // Event containing the contract specifics and raw log

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
func (it *ProverPoolWithdrawnIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ProverPoolWithdrawn)
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
		it.Event = new(ProverPoolWithdrawn)
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
func (it *ProverPoolWithdrawnIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ProverPoolWithdrawnIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ProverPoolWithdrawn represents a Withdrawn event raised by the ProverPool contract.
type ProverPoolWithdrawn struct {
	Addr   common.Address
	Amount uint64
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterWithdrawn is a free log retrieval operation binding the contract event 0xbae95d59332d6e1e8f1ae78e7bebdaeef072d57b731c8790a636667e3a0a87ee.
//
// Solidity: event Withdrawn(address indexed addr, uint64 amount)
func (_ProverPool *ProverPoolFilterer) FilterWithdrawn(opts *bind.FilterOpts, addr []common.Address) (*ProverPoolWithdrawnIterator, error) {

	var addrRule []interface{}
	for _, addrItem := range addr {
		addrRule = append(addrRule, addrItem)
	}

	logs, sub, err := _ProverPool.contract.FilterLogs(opts, "Withdrawn", addrRule)
	if err != nil {
		return nil, err
	}
	return &ProverPoolWithdrawnIterator{contract: _ProverPool.contract, event: "Withdrawn", logs: logs, sub: sub}, nil
}

// WatchWithdrawn is a free log subscription operation binding the contract event 0xbae95d59332d6e1e8f1ae78e7bebdaeef072d57b731c8790a636667e3a0a87ee.
//
// Solidity: event Withdrawn(address indexed addr, uint64 amount)
func (_ProverPool *ProverPoolFilterer) WatchWithdrawn(opts *bind.WatchOpts, sink chan<- *ProverPoolWithdrawn, addr []common.Address) (event.Subscription, error) {

	var addrRule []interface{}
	for _, addrItem := range addr {
		addrRule = append(addrRule, addrItem)
	}

	logs, sub, err := _ProverPool.contract.WatchLogs(opts, "Withdrawn", addrRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ProverPoolWithdrawn)
				if err := _ProverPool.contract.UnpackLog(event, "Withdrawn", log); err != nil {
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

// ParseWithdrawn is a log parse operation binding the contract event 0xbae95d59332d6e1e8f1ae78e7bebdaeef072d57b731c8790a636667e3a0a87ee.
//
// Solidity: event Withdrawn(address indexed addr, uint64 amount)
func (_ProverPool *ProverPoolFilterer) ParseWithdrawn(log types.Log) (*ProverPoolWithdrawn, error) {
	event := new(ProverPoolWithdrawn)
	if err := _ProverPool.contract.UnpackLog(event, "Withdrawn", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
