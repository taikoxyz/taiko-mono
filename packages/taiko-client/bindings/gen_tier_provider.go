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

// ITierProviderTier is an auto generated low-level Go binding around an user-defined struct.
type ITierProviderTier struct {
	VerifierName              [32]byte
	ValidityBond              *big.Int
	ContestBond               *big.Int
	CooldownWindow            *big.Int
	ProvingWindow             uint16
	MaxBlocksToVerifyPerProof uint8
}

// TierProviderMetaData contains all meta data concerning the TierProvider contract.
var TierProviderMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"BOND_UNIT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint96\",\"internalType\":\"uint96\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"GRACE_PERIOD\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint16\",\"internalType\":\"uint16\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getMinTier\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint16\",\"internalType\":\"uint16\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getProvider\",\"inputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTier\",\"inputs\":[{\"name\":\"_tierId\",\"type\":\"uint16\",\"internalType\":\"uint16\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structITierProvider.Tier\",\"components\":[{\"name\":\"verifierName\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"validityBond\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"contestBond\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"cooldownWindow\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"provingWindow\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"maxBlocksToVerifyPerProof\",\"type\":\"uint8\",\"internalType\":\"uint8\"}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getTierIds\",\"inputs\":[],\"outputs\":[{\"name\":\"tiers_\",\"type\":\"uint16[]\",\"internalType\":\"uint16[]\"}],\"stateMutability\":\"pure\"},{\"type\":\"error\",\"name\":\"TIER_NOT_FOUND\",\"inputs\":[]}]",
}

// TierProviderABI is the input ABI used to generate the binding from.
// Deprecated: Use TierProviderMetaData.ABI instead.
var TierProviderABI = TierProviderMetaData.ABI

// TierProvider is an auto generated Go binding around an Ethereum contract.
type TierProvider struct {
	TierProviderCaller     // Read-only binding to the contract
	TierProviderTransactor // Write-only binding to the contract
	TierProviderFilterer   // Log filterer for contract events
}

// TierProviderCaller is an auto generated read-only Go binding around an Ethereum contract.
type TierProviderCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TierProviderTransactor is an auto generated write-only Go binding around an Ethereum contract.
type TierProviderTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TierProviderFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type TierProviderFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TierProviderSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type TierProviderSession struct {
	Contract     *TierProvider     // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// TierProviderCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type TierProviderCallerSession struct {
	Contract *TierProviderCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts       // Call options to use throughout this session
}

// TierProviderTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type TierProviderTransactorSession struct {
	Contract     *TierProviderTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts       // Transaction auth options to use throughout this session
}

// TierProviderRaw is an auto generated low-level Go binding around an Ethereum contract.
type TierProviderRaw struct {
	Contract *TierProvider // Generic contract binding to access the raw methods on
}

// TierProviderCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type TierProviderCallerRaw struct {
	Contract *TierProviderCaller // Generic read-only contract binding to access the raw methods on
}

// TierProviderTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type TierProviderTransactorRaw struct {
	Contract *TierProviderTransactor // Generic write-only contract binding to access the raw methods on
}

// NewTierProvider creates a new instance of TierProvider, bound to a specific deployed contract.
func NewTierProvider(address common.Address, backend bind.ContractBackend) (*TierProvider, error) {
	contract, err := bindTierProvider(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &TierProvider{TierProviderCaller: TierProviderCaller{contract: contract}, TierProviderTransactor: TierProviderTransactor{contract: contract}, TierProviderFilterer: TierProviderFilterer{contract: contract}}, nil
}

// NewTierProviderCaller creates a new read-only instance of TierProvider, bound to a specific deployed contract.
func NewTierProviderCaller(address common.Address, caller bind.ContractCaller) (*TierProviderCaller, error) {
	contract, err := bindTierProvider(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &TierProviderCaller{contract: contract}, nil
}

// NewTierProviderTransactor creates a new write-only instance of TierProvider, bound to a specific deployed contract.
func NewTierProviderTransactor(address common.Address, transactor bind.ContractTransactor) (*TierProviderTransactor, error) {
	contract, err := bindTierProvider(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &TierProviderTransactor{contract: contract}, nil
}

// NewTierProviderFilterer creates a new log filterer instance of TierProvider, bound to a specific deployed contract.
func NewTierProviderFilterer(address common.Address, filterer bind.ContractFilterer) (*TierProviderFilterer, error) {
	contract, err := bindTierProvider(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &TierProviderFilterer{contract: contract}, nil
}

// bindTierProvider binds a generic wrapper to an already deployed contract.
func bindTierProvider(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := TierProviderMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TierProvider *TierProviderRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TierProvider.Contract.TierProviderCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TierProvider *TierProviderRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TierProvider.Contract.TierProviderTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TierProvider *TierProviderRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TierProvider.Contract.TierProviderTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TierProvider *TierProviderCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TierProvider.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TierProvider *TierProviderTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TierProvider.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TierProvider *TierProviderTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TierProvider.Contract.contract.Transact(opts, method, params...)
}

// BONDUNIT is a free data retrieval call binding the contract method 0x8165fd26.
//
// Solidity: function BOND_UNIT() view returns(uint96)
func (_TierProvider *TierProviderCaller) BONDUNIT(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _TierProvider.contract.Call(opts, &out, "BOND_UNIT")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// BONDUNIT is a free data retrieval call binding the contract method 0x8165fd26.
//
// Solidity: function BOND_UNIT() view returns(uint96)
func (_TierProvider *TierProviderSession) BONDUNIT() (*big.Int, error) {
	return _TierProvider.Contract.BONDUNIT(&_TierProvider.CallOpts)
}

// BONDUNIT is a free data retrieval call binding the contract method 0x8165fd26.
//
// Solidity: function BOND_UNIT() view returns(uint96)
func (_TierProvider *TierProviderCallerSession) BONDUNIT() (*big.Int, error) {
	return _TierProvider.Contract.BONDUNIT(&_TierProvider.CallOpts)
}

// GRACEPERIOD is a free data retrieval call binding the contract method 0xc1a287e2.
//
// Solidity: function GRACE_PERIOD() view returns(uint16)
func (_TierProvider *TierProviderCaller) GRACEPERIOD(opts *bind.CallOpts) (uint16, error) {
	var out []interface{}
	err := _TierProvider.contract.Call(opts, &out, "GRACE_PERIOD")

	if err != nil {
		return *new(uint16), err
	}

	out0 := *abi.ConvertType(out[0], new(uint16)).(*uint16)

	return out0, err

}

// GRACEPERIOD is a free data retrieval call binding the contract method 0xc1a287e2.
//
// Solidity: function GRACE_PERIOD() view returns(uint16)
func (_TierProvider *TierProviderSession) GRACEPERIOD() (uint16, error) {
	return _TierProvider.Contract.GRACEPERIOD(&_TierProvider.CallOpts)
}

// GRACEPERIOD is a free data retrieval call binding the contract method 0xc1a287e2.
//
// Solidity: function GRACE_PERIOD() view returns(uint16)
func (_TierProvider *TierProviderCallerSession) GRACEPERIOD() (uint16, error) {
	return _TierProvider.Contract.GRACEPERIOD(&_TierProvider.CallOpts)
}

// GetMinTier is a free data retrieval call binding the contract method 0x52c5c56b.
//
// Solidity: function getMinTier(address , uint256 ) pure returns(uint16)
func (_TierProvider *TierProviderCaller) GetMinTier(opts *bind.CallOpts, arg0 common.Address, arg1 *big.Int) (uint16, error) {
	var out []interface{}
	err := _TierProvider.contract.Call(opts, &out, "getMinTier", arg0, arg1)

	if err != nil {
		return *new(uint16), err
	}

	out0 := *abi.ConvertType(out[0], new(uint16)).(*uint16)

	return out0, err

}

// GetMinTier is a free data retrieval call binding the contract method 0x52c5c56b.
//
// Solidity: function getMinTier(address , uint256 ) pure returns(uint16)
func (_TierProvider *TierProviderSession) GetMinTier(arg0 common.Address, arg1 *big.Int) (uint16, error) {
	return _TierProvider.Contract.GetMinTier(&_TierProvider.CallOpts, arg0, arg1)
}

// GetMinTier is a free data retrieval call binding the contract method 0x52c5c56b.
//
// Solidity: function getMinTier(address , uint256 ) pure returns(uint16)
func (_TierProvider *TierProviderCallerSession) GetMinTier(arg0 common.Address, arg1 *big.Int) (uint16, error) {
	return _TierProvider.Contract.GetMinTier(&_TierProvider.CallOpts, arg0, arg1)
}

// GetProvider is a free data retrieval call binding the contract method 0x5c42d079.
//
// Solidity: function getProvider(uint256 ) view returns(address)
func (_TierProvider *TierProviderCaller) GetProvider(opts *bind.CallOpts, arg0 *big.Int) (common.Address, error) {
	var out []interface{}
	err := _TierProvider.contract.Call(opts, &out, "getProvider", arg0)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetProvider is a free data retrieval call binding the contract method 0x5c42d079.
//
// Solidity: function getProvider(uint256 ) view returns(address)
func (_TierProvider *TierProviderSession) GetProvider(arg0 *big.Int) (common.Address, error) {
	return _TierProvider.Contract.GetProvider(&_TierProvider.CallOpts, arg0)
}

// GetProvider is a free data retrieval call binding the contract method 0x5c42d079.
//
// Solidity: function getProvider(uint256 ) view returns(address)
func (_TierProvider *TierProviderCallerSession) GetProvider(arg0 *big.Int) (common.Address, error) {
	return _TierProvider.Contract.GetProvider(&_TierProvider.CallOpts, arg0)
}

// GetTier is a free data retrieval call binding the contract method 0x576c3de7.
//
// Solidity: function getTier(uint16 _tierId) pure returns((bytes32,uint96,uint96,uint24,uint16,uint8))
func (_TierProvider *TierProviderCaller) GetTier(opts *bind.CallOpts, _tierId uint16) (ITierProviderTier, error) {
	var out []interface{}
	err := _TierProvider.contract.Call(opts, &out, "getTier", _tierId)

	if err != nil {
		return *new(ITierProviderTier), err
	}

	out0 := *abi.ConvertType(out[0], new(ITierProviderTier)).(*ITierProviderTier)

	return out0, err

}

// GetTier is a free data retrieval call binding the contract method 0x576c3de7.
//
// Solidity: function getTier(uint16 _tierId) pure returns((bytes32,uint96,uint96,uint24,uint16,uint8))
func (_TierProvider *TierProviderSession) GetTier(_tierId uint16) (ITierProviderTier, error) {
	return _TierProvider.Contract.GetTier(&_TierProvider.CallOpts, _tierId)
}

// GetTier is a free data retrieval call binding the contract method 0x576c3de7.
//
// Solidity: function getTier(uint16 _tierId) pure returns((bytes32,uint96,uint96,uint24,uint16,uint8))
func (_TierProvider *TierProviderCallerSession) GetTier(_tierId uint16) (ITierProviderTier, error) {
	return _TierProvider.Contract.GetTier(&_TierProvider.CallOpts, _tierId)
}

// GetTierIds is a free data retrieval call binding the contract method 0xd8cde1c6.
//
// Solidity: function getTierIds() pure returns(uint16[] tiers_)
func (_TierProvider *TierProviderCaller) GetTierIds(opts *bind.CallOpts) ([]uint16, error) {
	var out []interface{}
	err := _TierProvider.contract.Call(opts, &out, "getTierIds")

	if err != nil {
		return *new([]uint16), err
	}

	out0 := *abi.ConvertType(out[0], new([]uint16)).(*[]uint16)

	return out0, err

}

// GetTierIds is a free data retrieval call binding the contract method 0xd8cde1c6.
//
// Solidity: function getTierIds() pure returns(uint16[] tiers_)
func (_TierProvider *TierProviderSession) GetTierIds() ([]uint16, error) {
	return _TierProvider.Contract.GetTierIds(&_TierProvider.CallOpts)
}

// GetTierIds is a free data retrieval call binding the contract method 0xd8cde1c6.
//
// Solidity: function getTierIds() pure returns(uint16[] tiers_)
func (_TierProvider *TierProviderCallerSession) GetTierIds() ([]uint16, error) {
	return _TierProvider.Contract.GetTierIds(&_TierProvider.CallOpts)
}
