// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package taikol2

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

// ICrossChainSyncSnippet is an auto generated low-level Go binding around an user-defined struct.
type ICrossChainSyncSnippet struct {
	RemoteBlockId uint64
	SyncedInBlock uint64
	BlockHash     [32]byte
	SignalRoot    [32]byte
}

// TaikoL2Config is an auto generated low-level Go binding around an user-defined struct.
type TaikoL2Config struct {
	GasTargetPerL1Block       uint32
	BasefeeAdjustmentQuotient uint8
}

// TaikoL2MetaData contains all meta data concerning the TaikoL2 contract.
var TaikoL2MetaData = &bind.MetaData{
	ABI: "[{\"inputs\":[],\"name\":\"EIP1559_INVALID_PARAMS\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"INVALID_PAUSE_STATUS\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L2_BASEFEE_MISMATCH\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L2_INVALID_CHAIN_ID\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L2_INVALID_GOLDEN_TOUCH_K\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L2_INVALID_PARAM\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L2_INVALID_SENDER\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L2_PUBLIC_INPUT_HASH_MISMATCH\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L2_TOO_LATE\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"Overflow\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"REENTRANT_CALL\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"RESOLVER_DENIED\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"RESOLVER_INVALID_MANAGER\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"RESOLVER_UNEXPECTED_CHAINID\",\"type\":\"error\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"chainId\",\"type\":\"uint64\"},{\"internalType\":\"string\",\"name\":\"name\",\"type\":\"string\"}],\"name\":\"RESOLVER_ZERO_ADDR\",\"type\":\"error\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"previousAdmin\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"newAdmin\",\"type\":\"address\"}],\"name\":\"AdminChanged\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"parentHash\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"uint64\",\"name\":\"gasExcess\",\"type\":\"uint64\"}],\"name\":\"Anchored\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"beacon\",\"type\":\"address\"}],\"name\":\"BeaconUpgraded\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint64\",\"name\":\"syncedInBlock\",\"type\":\"uint64\"},{\"indexed\":true,\"internalType\":\"uint64\",\"name\":\"blockId\",\"type\":\"uint64\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"blockHash\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"signalRoot\",\"type\":\"bytes32\"}],\"name\":\"CrossChainSynced\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint8\",\"name\":\"version\",\"type\":\"uint8\"}],\"name\":\"Initialized\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"previousOwner\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"OwnershipTransferred\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"account\",\"type\":\"address\"}],\"name\":\"Paused\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"account\",\"type\":\"address\"}],\"name\":\"Unpaused\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"implementation\",\"type\":\"address\"}],\"name\":\"Upgraded\",\"type\":\"event\"},{\"inputs\":[],\"name\":\"GOLDEN_TOUCH_ADDRESS\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"GOLDEN_TOUCH_PRIVATEKEY\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"addressManager\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"l1BlockHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"l1SignalRoot\",\"type\":\"bytes32\"},{\"internalType\":\"uint64\",\"name\":\"l1Height\",\"type\":\"uint64\"},{\"internalType\":\"uint32\",\"name\":\"parentGasUsed\",\"type\":\"uint32\"}],\"name\":\"anchor\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"gasExcess\",\"outputs\":[{\"internalType\":\"uint64\",\"name\":\"\",\"type\":\"uint64\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"l1Height\",\"type\":\"uint64\"},{\"internalType\":\"uint32\",\"name\":\"parentGasUsed\",\"type\":\"uint32\"}],\"name\":\"getBasefee\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"basefee\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"blockId\",\"type\":\"uint64\"}],\"name\":\"getBlockHash\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"getConfig\",\"outputs\":[{\"components\":[{\"internalType\":\"uint32\",\"name\":\"gasTargetPerL1Block\",\"type\":\"uint32\"},{\"internalType\":\"uint8\",\"name\":\"basefeeAdjustmentQuotient\",\"type\":\"uint8\"}],\"internalType\":\"structTaikoL2.Config\",\"name\":\"config\",\"type\":\"tuple\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"blockId\",\"type\":\"uint64\"}],\"name\":\"getSyncedSnippet\",\"outputs\":[{\"components\":[{\"internalType\":\"uint64\",\"name\":\"remoteBlockId\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"syncedInBlock\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"blockHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"signalRoot\",\"type\":\"bytes32\"}],\"internalType\":\"structICrossChainSync.Snippet\",\"name\":\"\",\"type\":\"tuple\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_signalService\",\"type\":\"address\"},{\"internalType\":\"uint64\",\"name\":\"_gasExcess\",\"type\":\"uint64\"}],\"name\":\"init\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"blockId\",\"type\":\"uint256\"}],\"name\":\"l2Hashes\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"blockHash\",\"type\":\"bytes32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"latestSyncedL1Height\",\"outputs\":[{\"internalType\":\"uint64\",\"name\":\"\",\"type\":\"uint64\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"owner\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"pause\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"paused\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"proxiableUUID\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"publicInputHash\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"renounceOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"chainId\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"name\",\"type\":\"bytes32\"},{\"internalType\":\"bool\",\"name\":\"allowZeroAddress\",\"type\":\"bool\"}],\"name\":\"resolve\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"addr\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"name\",\"type\":\"bytes32\"},{\"internalType\":\"bool\",\"name\":\"allowZeroAddress\",\"type\":\"bool\"}],\"name\":\"resolve\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"addr\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"digest\",\"type\":\"bytes32\"},{\"internalType\":\"uint8\",\"name\":\"k\",\"type\":\"uint8\"}],\"name\":\"signAnchor\",\"outputs\":[{\"internalType\":\"uint8\",\"name\":\"v\",\"type\":\"uint8\"},{\"internalType\":\"uint256\",\"name\":\"r\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"s\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"signalService\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"skipFeeCheck\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"pure\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"l1height\",\"type\":\"uint256\"}],\"name\":\"snippets\",\"outputs\":[{\"internalType\":\"uint64\",\"name\":\"remoteBlockId\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"syncedInBlock\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"blockHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"signalRoot\",\"type\":\"bytes32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"transferOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"unpause\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"newImplementation\",\"type\":\"address\"}],\"name\":\"upgradeTo\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"newImplementation\",\"type\":\"address\"},{\"internalType\":\"bytes\",\"name\":\"data\",\"type\":\"bytes\"}],\"name\":\"upgradeToAndCall\",\"outputs\":[],\"stateMutability\":\"payable\",\"type\":\"function\"}]",
}

// TaikoL2ABI is the input ABI used to generate the binding from.
// Deprecated: Use TaikoL2MetaData.ABI instead.
var TaikoL2ABI = TaikoL2MetaData.ABI

// TaikoL2 is an auto generated Go binding around an Ethereum contract.
type TaikoL2 struct {
	TaikoL2Caller     // Read-only binding to the contract
	TaikoL2Transactor // Write-only binding to the contract
	TaikoL2Filterer   // Log filterer for contract events
}

// TaikoL2Caller is an auto generated read-only Go binding around an Ethereum contract.
type TaikoL2Caller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoL2Transactor is an auto generated write-only Go binding around an Ethereum contract.
type TaikoL2Transactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoL2Filterer is an auto generated log filtering Go binding around an Ethereum contract events.
type TaikoL2Filterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoL2Session is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type TaikoL2Session struct {
	Contract     *TaikoL2          // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// TaikoL2CallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type TaikoL2CallerSession struct {
	Contract *TaikoL2Caller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts  // Call options to use throughout this session
}

// TaikoL2TransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type TaikoL2TransactorSession struct {
	Contract     *TaikoL2Transactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts  // Transaction auth options to use throughout this session
}

// TaikoL2Raw is an auto generated low-level Go binding around an Ethereum contract.
type TaikoL2Raw struct {
	Contract *TaikoL2 // Generic contract binding to access the raw methods on
}

// TaikoL2CallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type TaikoL2CallerRaw struct {
	Contract *TaikoL2Caller // Generic read-only contract binding to access the raw methods on
}

// TaikoL2TransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type TaikoL2TransactorRaw struct {
	Contract *TaikoL2Transactor // Generic write-only contract binding to access the raw methods on
}

// NewTaikoL2 creates a new instance of TaikoL2, bound to a specific deployed contract.
func NewTaikoL2(address common.Address, backend bind.ContractBackend) (*TaikoL2, error) {
	contract, err := bindTaikoL2(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &TaikoL2{TaikoL2Caller: TaikoL2Caller{contract: contract}, TaikoL2Transactor: TaikoL2Transactor{contract: contract}, TaikoL2Filterer: TaikoL2Filterer{contract: contract}}, nil
}

// NewTaikoL2Caller creates a new read-only instance of TaikoL2, bound to a specific deployed contract.
func NewTaikoL2Caller(address common.Address, caller bind.ContractCaller) (*TaikoL2Caller, error) {
	contract, err := bindTaikoL2(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &TaikoL2Caller{contract: contract}, nil
}

// NewTaikoL2Transactor creates a new write-only instance of TaikoL2, bound to a specific deployed contract.
func NewTaikoL2Transactor(address common.Address, transactor bind.ContractTransactor) (*TaikoL2Transactor, error) {
	contract, err := bindTaikoL2(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &TaikoL2Transactor{contract: contract}, nil
}

// NewTaikoL2Filterer creates a new log filterer instance of TaikoL2, bound to a specific deployed contract.
func NewTaikoL2Filterer(address common.Address, filterer bind.ContractFilterer) (*TaikoL2Filterer, error) {
	contract, err := bindTaikoL2(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &TaikoL2Filterer{contract: contract}, nil
}

// bindTaikoL2 binds a generic wrapper to an already deployed contract.
func bindTaikoL2(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := TaikoL2MetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TaikoL2 *TaikoL2Raw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TaikoL2.Contract.TaikoL2Caller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TaikoL2 *TaikoL2Raw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL2.Contract.TaikoL2Transactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TaikoL2 *TaikoL2Raw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TaikoL2.Contract.TaikoL2Transactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TaikoL2 *TaikoL2CallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TaikoL2.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TaikoL2 *TaikoL2TransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL2.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TaikoL2 *TaikoL2TransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TaikoL2.Contract.contract.Transact(opts, method, params...)
}

// GOLDENTOUCHADDRESS is a free data retrieval call binding the contract method 0x9ee512f2.
//
// Solidity: function GOLDEN_TOUCH_ADDRESS() view returns(address)
func (_TaikoL2 *TaikoL2Caller) GOLDENTOUCHADDRESS(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "GOLDEN_TOUCH_ADDRESS")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GOLDENTOUCHADDRESS is a free data retrieval call binding the contract method 0x9ee512f2.
//
// Solidity: function GOLDEN_TOUCH_ADDRESS() view returns(address)
func (_TaikoL2 *TaikoL2Session) GOLDENTOUCHADDRESS() (common.Address, error) {
	return _TaikoL2.Contract.GOLDENTOUCHADDRESS(&_TaikoL2.CallOpts)
}

// GOLDENTOUCHADDRESS is a free data retrieval call binding the contract method 0x9ee512f2.
//
// Solidity: function GOLDEN_TOUCH_ADDRESS() view returns(address)
func (_TaikoL2 *TaikoL2CallerSession) GOLDENTOUCHADDRESS() (common.Address, error) {
	return _TaikoL2.Contract.GOLDENTOUCHADDRESS(&_TaikoL2.CallOpts)
}

// GOLDENTOUCHPRIVATEKEY is a free data retrieval call binding the contract method 0x10da3738.
//
// Solidity: function GOLDEN_TOUCH_PRIVATEKEY() view returns(uint256)
func (_TaikoL2 *TaikoL2Caller) GOLDENTOUCHPRIVATEKEY(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "GOLDEN_TOUCH_PRIVATEKEY")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GOLDENTOUCHPRIVATEKEY is a free data retrieval call binding the contract method 0x10da3738.
//
// Solidity: function GOLDEN_TOUCH_PRIVATEKEY() view returns(uint256)
func (_TaikoL2 *TaikoL2Session) GOLDENTOUCHPRIVATEKEY() (*big.Int, error) {
	return _TaikoL2.Contract.GOLDENTOUCHPRIVATEKEY(&_TaikoL2.CallOpts)
}

// GOLDENTOUCHPRIVATEKEY is a free data retrieval call binding the contract method 0x10da3738.
//
// Solidity: function GOLDEN_TOUCH_PRIVATEKEY() view returns(uint256)
func (_TaikoL2 *TaikoL2CallerSession) GOLDENTOUCHPRIVATEKEY() (*big.Int, error) {
	return _TaikoL2.Contract.GOLDENTOUCHPRIVATEKEY(&_TaikoL2.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_TaikoL2 *TaikoL2Caller) AddressManager(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "addressManager")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_TaikoL2 *TaikoL2Session) AddressManager() (common.Address, error) {
	return _TaikoL2.Contract.AddressManager(&_TaikoL2.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_TaikoL2 *TaikoL2CallerSession) AddressManager() (common.Address, error) {
	return _TaikoL2.Contract.AddressManager(&_TaikoL2.CallOpts)
}

// GasExcess is a free data retrieval call binding the contract method 0xf535bd56.
//
// Solidity: function gasExcess() view returns(uint64)
func (_TaikoL2 *TaikoL2Caller) GasExcess(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "gasExcess")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// GasExcess is a free data retrieval call binding the contract method 0xf535bd56.
//
// Solidity: function gasExcess() view returns(uint64)
func (_TaikoL2 *TaikoL2Session) GasExcess() (uint64, error) {
	return _TaikoL2.Contract.GasExcess(&_TaikoL2.CallOpts)
}

// GasExcess is a free data retrieval call binding the contract method 0xf535bd56.
//
// Solidity: function gasExcess() view returns(uint64)
func (_TaikoL2 *TaikoL2CallerSession) GasExcess() (uint64, error) {
	return _TaikoL2.Contract.GasExcess(&_TaikoL2.CallOpts)
}

// GetBasefee is a free data retrieval call binding the contract method 0xa7e022d1.
//
// Solidity: function getBasefee(uint64 l1Height, uint32 parentGasUsed) view returns(uint256 basefee)
func (_TaikoL2 *TaikoL2Caller) GetBasefee(opts *bind.CallOpts, l1Height uint64, parentGasUsed uint32) (*big.Int, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "getBasefee", l1Height, parentGasUsed)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetBasefee is a free data retrieval call binding the contract method 0xa7e022d1.
//
// Solidity: function getBasefee(uint64 l1Height, uint32 parentGasUsed) view returns(uint256 basefee)
func (_TaikoL2 *TaikoL2Session) GetBasefee(l1Height uint64, parentGasUsed uint32) (*big.Int, error) {
	return _TaikoL2.Contract.GetBasefee(&_TaikoL2.CallOpts, l1Height, parentGasUsed)
}

// GetBasefee is a free data retrieval call binding the contract method 0xa7e022d1.
//
// Solidity: function getBasefee(uint64 l1Height, uint32 parentGasUsed) view returns(uint256 basefee)
func (_TaikoL2 *TaikoL2CallerSession) GetBasefee(l1Height uint64, parentGasUsed uint32) (*big.Int, error) {
	return _TaikoL2.Contract.GetBasefee(&_TaikoL2.CallOpts, l1Height, parentGasUsed)
}

// GetBlockHash is a free data retrieval call binding the contract method 0x23ac7136.
//
// Solidity: function getBlockHash(uint64 blockId) view returns(bytes32)
func (_TaikoL2 *TaikoL2Caller) GetBlockHash(opts *bind.CallOpts, blockId uint64) ([32]byte, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "getBlockHash", blockId)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetBlockHash is a free data retrieval call binding the contract method 0x23ac7136.
//
// Solidity: function getBlockHash(uint64 blockId) view returns(bytes32)
func (_TaikoL2 *TaikoL2Session) GetBlockHash(blockId uint64) ([32]byte, error) {
	return _TaikoL2.Contract.GetBlockHash(&_TaikoL2.CallOpts, blockId)
}

// GetBlockHash is a free data retrieval call binding the contract method 0x23ac7136.
//
// Solidity: function getBlockHash(uint64 blockId) view returns(bytes32)
func (_TaikoL2 *TaikoL2CallerSession) GetBlockHash(blockId uint64) ([32]byte, error) {
	return _TaikoL2.Contract.GetBlockHash(&_TaikoL2.CallOpts, blockId)
}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() view returns((uint32,uint8) config)
func (_TaikoL2 *TaikoL2Caller) GetConfig(opts *bind.CallOpts) (TaikoL2Config, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "getConfig")

	if err != nil {
		return *new(TaikoL2Config), err
	}

	out0 := *abi.ConvertType(out[0], new(TaikoL2Config)).(*TaikoL2Config)

	return out0, err

}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() view returns((uint32,uint8) config)
func (_TaikoL2 *TaikoL2Session) GetConfig() (TaikoL2Config, error) {
	return _TaikoL2.Contract.GetConfig(&_TaikoL2.CallOpts)
}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() view returns((uint32,uint8) config)
func (_TaikoL2 *TaikoL2CallerSession) GetConfig() (TaikoL2Config, error) {
	return _TaikoL2.Contract.GetConfig(&_TaikoL2.CallOpts)
}

// GetSyncedSnippet is a free data retrieval call binding the contract method 0x8cfb0459.
//
// Solidity: function getSyncedSnippet(uint64 blockId) view returns((uint64,uint64,bytes32,bytes32))
func (_TaikoL2 *TaikoL2Caller) GetSyncedSnippet(opts *bind.CallOpts, blockId uint64) (ICrossChainSyncSnippet, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "getSyncedSnippet", blockId)

	if err != nil {
		return *new(ICrossChainSyncSnippet), err
	}

	out0 := *abi.ConvertType(out[0], new(ICrossChainSyncSnippet)).(*ICrossChainSyncSnippet)

	return out0, err

}

// GetSyncedSnippet is a free data retrieval call binding the contract method 0x8cfb0459.
//
// Solidity: function getSyncedSnippet(uint64 blockId) view returns((uint64,uint64,bytes32,bytes32))
func (_TaikoL2 *TaikoL2Session) GetSyncedSnippet(blockId uint64) (ICrossChainSyncSnippet, error) {
	return _TaikoL2.Contract.GetSyncedSnippet(&_TaikoL2.CallOpts, blockId)
}

// GetSyncedSnippet is a free data retrieval call binding the contract method 0x8cfb0459.
//
// Solidity: function getSyncedSnippet(uint64 blockId) view returns((uint64,uint64,bytes32,bytes32))
func (_TaikoL2 *TaikoL2CallerSession) GetSyncedSnippet(blockId uint64) (ICrossChainSyncSnippet, error) {
	return _TaikoL2.Contract.GetSyncedSnippet(&_TaikoL2.CallOpts, blockId)
}

// L2Hashes is a free data retrieval call binding the contract method 0x8551f41e.
//
// Solidity: function l2Hashes(uint256 blockId) view returns(bytes32 blockHash)
func (_TaikoL2 *TaikoL2Caller) L2Hashes(opts *bind.CallOpts, blockId *big.Int) ([32]byte, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "l2Hashes", blockId)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// L2Hashes is a free data retrieval call binding the contract method 0x8551f41e.
//
// Solidity: function l2Hashes(uint256 blockId) view returns(bytes32 blockHash)
func (_TaikoL2 *TaikoL2Session) L2Hashes(blockId *big.Int) ([32]byte, error) {
	return _TaikoL2.Contract.L2Hashes(&_TaikoL2.CallOpts, blockId)
}

// L2Hashes is a free data retrieval call binding the contract method 0x8551f41e.
//
// Solidity: function l2Hashes(uint256 blockId) view returns(bytes32 blockHash)
func (_TaikoL2 *TaikoL2CallerSession) L2Hashes(blockId *big.Int) ([32]byte, error) {
	return _TaikoL2.Contract.L2Hashes(&_TaikoL2.CallOpts, blockId)
}

// LatestSyncedL1Height is a free data retrieval call binding the contract method 0xc7b96908.
//
// Solidity: function latestSyncedL1Height() view returns(uint64)
func (_TaikoL2 *TaikoL2Caller) LatestSyncedL1Height(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "latestSyncedL1Height")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// LatestSyncedL1Height is a free data retrieval call binding the contract method 0xc7b96908.
//
// Solidity: function latestSyncedL1Height() view returns(uint64)
func (_TaikoL2 *TaikoL2Session) LatestSyncedL1Height() (uint64, error) {
	return _TaikoL2.Contract.LatestSyncedL1Height(&_TaikoL2.CallOpts)
}

// LatestSyncedL1Height is a free data retrieval call binding the contract method 0xc7b96908.
//
// Solidity: function latestSyncedL1Height() view returns(uint64)
func (_TaikoL2 *TaikoL2CallerSession) LatestSyncedL1Height() (uint64, error) {
	return _TaikoL2.Contract.LatestSyncedL1Height(&_TaikoL2.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoL2 *TaikoL2Caller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoL2 *TaikoL2Session) Owner() (common.Address, error) {
	return _TaikoL2.Contract.Owner(&_TaikoL2.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoL2 *TaikoL2CallerSession) Owner() (common.Address, error) {
	return _TaikoL2.Contract.Owner(&_TaikoL2.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_TaikoL2 *TaikoL2Caller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_TaikoL2 *TaikoL2Session) Paused() (bool, error) {
	return _TaikoL2.Contract.Paused(&_TaikoL2.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_TaikoL2 *TaikoL2CallerSession) Paused() (bool, error) {
	return _TaikoL2.Contract.Paused(&_TaikoL2.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_TaikoL2 *TaikoL2Caller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_TaikoL2 *TaikoL2Session) ProxiableUUID() ([32]byte, error) {
	return _TaikoL2.Contract.ProxiableUUID(&_TaikoL2.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_TaikoL2 *TaikoL2CallerSession) ProxiableUUID() ([32]byte, error) {
	return _TaikoL2.Contract.ProxiableUUID(&_TaikoL2.CallOpts)
}

// PublicInputHash is a free data retrieval call binding the contract method 0xdac5df78.
//
// Solidity: function publicInputHash() view returns(bytes32)
func (_TaikoL2 *TaikoL2Caller) PublicInputHash(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "publicInputHash")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// PublicInputHash is a free data retrieval call binding the contract method 0xdac5df78.
//
// Solidity: function publicInputHash() view returns(bytes32)
func (_TaikoL2 *TaikoL2Session) PublicInputHash() ([32]byte, error) {
	return _TaikoL2.Contract.PublicInputHash(&_TaikoL2.CallOpts)
}

// PublicInputHash is a free data retrieval call binding the contract method 0xdac5df78.
//
// Solidity: function publicInputHash() view returns(bytes32)
func (_TaikoL2 *TaikoL2CallerSession) PublicInputHash() ([32]byte, error) {
	return _TaikoL2.Contract.PublicInputHash(&_TaikoL2.CallOpts)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 chainId, bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_TaikoL2 *TaikoL2Caller) Resolve(opts *bind.CallOpts, chainId uint64, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "resolve", chainId, name, allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 chainId, bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_TaikoL2 *TaikoL2Session) Resolve(chainId uint64, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _TaikoL2.Contract.Resolve(&_TaikoL2.CallOpts, chainId, name, allowZeroAddress)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 chainId, bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_TaikoL2 *TaikoL2CallerSession) Resolve(chainId uint64, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _TaikoL2.Contract.Resolve(&_TaikoL2.CallOpts, chainId, name, allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_TaikoL2 *TaikoL2Caller) Resolve0(opts *bind.CallOpts, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "resolve0", name, allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_TaikoL2 *TaikoL2Session) Resolve0(name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _TaikoL2.Contract.Resolve0(&_TaikoL2.CallOpts, name, allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_TaikoL2 *TaikoL2CallerSession) Resolve0(name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _TaikoL2.Contract.Resolve0(&_TaikoL2.CallOpts, name, allowZeroAddress)
}

// SignAnchor is a free data retrieval call binding the contract method 0x591aad8a.
//
// Solidity: function signAnchor(bytes32 digest, uint8 k) view returns(uint8 v, uint256 r, uint256 s)
func (_TaikoL2 *TaikoL2Caller) SignAnchor(opts *bind.CallOpts, digest [32]byte, k uint8) (struct {
	V uint8
	R *big.Int
	S *big.Int
}, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "signAnchor", digest, k)

	outstruct := new(struct {
		V uint8
		R *big.Int
		S *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.V = *abi.ConvertType(out[0], new(uint8)).(*uint8)
	outstruct.R = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)
	outstruct.S = *abi.ConvertType(out[2], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// SignAnchor is a free data retrieval call binding the contract method 0x591aad8a.
//
// Solidity: function signAnchor(bytes32 digest, uint8 k) view returns(uint8 v, uint256 r, uint256 s)
func (_TaikoL2 *TaikoL2Session) SignAnchor(digest [32]byte, k uint8) (struct {
	V uint8
	R *big.Int
	S *big.Int
}, error) {
	return _TaikoL2.Contract.SignAnchor(&_TaikoL2.CallOpts, digest, k)
}

// SignAnchor is a free data retrieval call binding the contract method 0x591aad8a.
//
// Solidity: function signAnchor(bytes32 digest, uint8 k) view returns(uint8 v, uint256 r, uint256 s)
func (_TaikoL2 *TaikoL2CallerSession) SignAnchor(digest [32]byte, k uint8) (struct {
	V uint8
	R *big.Int
	S *big.Int
}, error) {
	return _TaikoL2.Contract.SignAnchor(&_TaikoL2.CallOpts, digest, k)
}

// SignalService is a free data retrieval call binding the contract method 0x62d09453.
//
// Solidity: function signalService() view returns(address)
func (_TaikoL2 *TaikoL2Caller) SignalService(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "signalService")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SignalService is a free data retrieval call binding the contract method 0x62d09453.
//
// Solidity: function signalService() view returns(address)
func (_TaikoL2 *TaikoL2Session) SignalService() (common.Address, error) {
	return _TaikoL2.Contract.SignalService(&_TaikoL2.CallOpts)
}

// SignalService is a free data retrieval call binding the contract method 0x62d09453.
//
// Solidity: function signalService() view returns(address)
func (_TaikoL2 *TaikoL2CallerSession) SignalService() (common.Address, error) {
	return _TaikoL2.Contract.SignalService(&_TaikoL2.CallOpts)
}

// SkipFeeCheck is a free data retrieval call binding the contract method 0x2f980473.
//
// Solidity: function skipFeeCheck() pure returns(bool)
func (_TaikoL2 *TaikoL2Caller) SkipFeeCheck(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "skipFeeCheck")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// SkipFeeCheck is a free data retrieval call binding the contract method 0x2f980473.
//
// Solidity: function skipFeeCheck() pure returns(bool)
func (_TaikoL2 *TaikoL2Session) SkipFeeCheck() (bool, error) {
	return _TaikoL2.Contract.SkipFeeCheck(&_TaikoL2.CallOpts)
}

// SkipFeeCheck is a free data retrieval call binding the contract method 0x2f980473.
//
// Solidity: function skipFeeCheck() pure returns(bool)
func (_TaikoL2 *TaikoL2CallerSession) SkipFeeCheck() (bool, error) {
	return _TaikoL2.Contract.SkipFeeCheck(&_TaikoL2.CallOpts)
}

// Snippets is a free data retrieval call binding the contract method 0xe8e2c5fb.
//
// Solidity: function snippets(uint256 l1height) view returns(uint64 remoteBlockId, uint64 syncedInBlock, bytes32 blockHash, bytes32 signalRoot)
func (_TaikoL2 *TaikoL2Caller) Snippets(opts *bind.CallOpts, l1height *big.Int) (struct {
	RemoteBlockId uint64
	SyncedInBlock uint64
	BlockHash     [32]byte
	SignalRoot    [32]byte
}, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "snippets", l1height)

	outstruct := new(struct {
		RemoteBlockId uint64
		SyncedInBlock uint64
		BlockHash     [32]byte
		SignalRoot    [32]byte
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.RemoteBlockId = *abi.ConvertType(out[0], new(uint64)).(*uint64)
	outstruct.SyncedInBlock = *abi.ConvertType(out[1], new(uint64)).(*uint64)
	outstruct.BlockHash = *abi.ConvertType(out[2], new([32]byte)).(*[32]byte)
	outstruct.SignalRoot = *abi.ConvertType(out[3], new([32]byte)).(*[32]byte)

	return *outstruct, err

}

// Snippets is a free data retrieval call binding the contract method 0xe8e2c5fb.
//
// Solidity: function snippets(uint256 l1height) view returns(uint64 remoteBlockId, uint64 syncedInBlock, bytes32 blockHash, bytes32 signalRoot)
func (_TaikoL2 *TaikoL2Session) Snippets(l1height *big.Int) (struct {
	RemoteBlockId uint64
	SyncedInBlock uint64
	BlockHash     [32]byte
	SignalRoot    [32]byte
}, error) {
	return _TaikoL2.Contract.Snippets(&_TaikoL2.CallOpts, l1height)
}

// Snippets is a free data retrieval call binding the contract method 0xe8e2c5fb.
//
// Solidity: function snippets(uint256 l1height) view returns(uint64 remoteBlockId, uint64 syncedInBlock, bytes32 blockHash, bytes32 signalRoot)
func (_TaikoL2 *TaikoL2CallerSession) Snippets(l1height *big.Int) (struct {
	RemoteBlockId uint64
	SyncedInBlock uint64
	BlockHash     [32]byte
	SignalRoot    [32]byte
}, error) {
	return _TaikoL2.Contract.Snippets(&_TaikoL2.CallOpts, l1height)
}

// Anchor is a paid mutator transaction binding the contract method 0xda69d3db.
//
// Solidity: function anchor(bytes32 l1BlockHash, bytes32 l1SignalRoot, uint64 l1Height, uint32 parentGasUsed) returns()
func (_TaikoL2 *TaikoL2Transactor) Anchor(opts *bind.TransactOpts, l1BlockHash [32]byte, l1SignalRoot [32]byte, l1Height uint64, parentGasUsed uint32) (*types.Transaction, error) {
	return _TaikoL2.contract.Transact(opts, "anchor", l1BlockHash, l1SignalRoot, l1Height, parentGasUsed)
}

// Anchor is a paid mutator transaction binding the contract method 0xda69d3db.
//
// Solidity: function anchor(bytes32 l1BlockHash, bytes32 l1SignalRoot, uint64 l1Height, uint32 parentGasUsed) returns()
func (_TaikoL2 *TaikoL2Session) Anchor(l1BlockHash [32]byte, l1SignalRoot [32]byte, l1Height uint64, parentGasUsed uint32) (*types.Transaction, error) {
	return _TaikoL2.Contract.Anchor(&_TaikoL2.TransactOpts, l1BlockHash, l1SignalRoot, l1Height, parentGasUsed)
}

// Anchor is a paid mutator transaction binding the contract method 0xda69d3db.
//
// Solidity: function anchor(bytes32 l1BlockHash, bytes32 l1SignalRoot, uint64 l1Height, uint32 parentGasUsed) returns()
func (_TaikoL2 *TaikoL2TransactorSession) Anchor(l1BlockHash [32]byte, l1SignalRoot [32]byte, l1Height uint64, parentGasUsed uint32) (*types.Transaction, error) {
	return _TaikoL2.Contract.Anchor(&_TaikoL2.TransactOpts, l1BlockHash, l1SignalRoot, l1Height, parentGasUsed)
}

// Init is a paid mutator transaction binding the contract method 0xb259f48b.
//
// Solidity: function init(address _signalService, uint64 _gasExcess) returns()
func (_TaikoL2 *TaikoL2Transactor) Init(opts *bind.TransactOpts, _signalService common.Address, _gasExcess uint64) (*types.Transaction, error) {
	return _TaikoL2.contract.Transact(opts, "init", _signalService, _gasExcess)
}

// Init is a paid mutator transaction binding the contract method 0xb259f48b.
//
// Solidity: function init(address _signalService, uint64 _gasExcess) returns()
func (_TaikoL2 *TaikoL2Session) Init(_signalService common.Address, _gasExcess uint64) (*types.Transaction, error) {
	return _TaikoL2.Contract.Init(&_TaikoL2.TransactOpts, _signalService, _gasExcess)
}

// Init is a paid mutator transaction binding the contract method 0xb259f48b.
//
// Solidity: function init(address _signalService, uint64 _gasExcess) returns()
func (_TaikoL2 *TaikoL2TransactorSession) Init(_signalService common.Address, _gasExcess uint64) (*types.Transaction, error) {
	return _TaikoL2.Contract.Init(&_TaikoL2.TransactOpts, _signalService, _gasExcess)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_TaikoL2 *TaikoL2Transactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL2.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_TaikoL2 *TaikoL2Session) Pause() (*types.Transaction, error) {
	return _TaikoL2.Contract.Pause(&_TaikoL2.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_TaikoL2 *TaikoL2TransactorSession) Pause() (*types.Transaction, error) {
	return _TaikoL2.Contract.Pause(&_TaikoL2.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoL2 *TaikoL2Transactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL2.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoL2 *TaikoL2Session) RenounceOwnership() (*types.Transaction, error) {
	return _TaikoL2.Contract.RenounceOwnership(&_TaikoL2.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoL2 *TaikoL2TransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _TaikoL2.Contract.RenounceOwnership(&_TaikoL2.TransactOpts)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoL2 *TaikoL2Transactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _TaikoL2.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoL2 *TaikoL2Session) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _TaikoL2.Contract.TransferOwnership(&_TaikoL2.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoL2 *TaikoL2TransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _TaikoL2.Contract.TransferOwnership(&_TaikoL2.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_TaikoL2 *TaikoL2Transactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL2.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_TaikoL2 *TaikoL2Session) Unpause() (*types.Transaction, error) {
	return _TaikoL2.Contract.Unpause(&_TaikoL2.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_TaikoL2 *TaikoL2TransactorSession) Unpause() (*types.Transaction, error) {
	return _TaikoL2.Contract.Unpause(&_TaikoL2.TransactOpts)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_TaikoL2 *TaikoL2Transactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _TaikoL2.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_TaikoL2 *TaikoL2Session) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _TaikoL2.Contract.UpgradeTo(&_TaikoL2.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_TaikoL2 *TaikoL2TransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _TaikoL2.Contract.UpgradeTo(&_TaikoL2.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_TaikoL2 *TaikoL2Transactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _TaikoL2.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_TaikoL2 *TaikoL2Session) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _TaikoL2.Contract.UpgradeToAndCall(&_TaikoL2.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_TaikoL2 *TaikoL2TransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _TaikoL2.Contract.UpgradeToAndCall(&_TaikoL2.TransactOpts, newImplementation, data)
}

// TaikoL2AdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the TaikoL2 contract.
type TaikoL2AdminChangedIterator struct {
	Event *TaikoL2AdminChanged // Event containing the contract specifics and raw log

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
func (it *TaikoL2AdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL2AdminChanged)
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
		it.Event = new(TaikoL2AdminChanged)
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
func (it *TaikoL2AdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL2AdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL2AdminChanged represents a AdminChanged event raised by the TaikoL2 contract.
type TaikoL2AdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_TaikoL2 *TaikoL2Filterer) FilterAdminChanged(opts *bind.FilterOpts) (*TaikoL2AdminChangedIterator, error) {

	logs, sub, err := _TaikoL2.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &TaikoL2AdminChangedIterator{contract: _TaikoL2.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_TaikoL2 *TaikoL2Filterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *TaikoL2AdminChanged) (event.Subscription, error) {

	logs, sub, err := _TaikoL2.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL2AdminChanged)
				if err := _TaikoL2.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_TaikoL2 *TaikoL2Filterer) ParseAdminChanged(log types.Log) (*TaikoL2AdminChanged, error) {
	event := new(TaikoL2AdminChanged)
	if err := _TaikoL2.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL2AnchoredIterator is returned from FilterAnchored and is used to iterate over the raw logs and unpacked data for Anchored events raised by the TaikoL2 contract.
type TaikoL2AnchoredIterator struct {
	Event *TaikoL2Anchored // Event containing the contract specifics and raw log

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
func (it *TaikoL2AnchoredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL2Anchored)
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
		it.Event = new(TaikoL2Anchored)
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
func (it *TaikoL2AnchoredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL2AnchoredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL2Anchored represents a Anchored event raised by the TaikoL2 contract.
type TaikoL2Anchored struct {
	ParentHash [32]byte
	GasExcess  uint64
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterAnchored is a free log retrieval operation binding the contract event 0x41c3f410f5c8ac36bb46b1dccef0de0f964087c9e688795fa02ecfa2c20b3fe4.
//
// Solidity: event Anchored(bytes32 parentHash, uint64 gasExcess)
func (_TaikoL2 *TaikoL2Filterer) FilterAnchored(opts *bind.FilterOpts) (*TaikoL2AnchoredIterator, error) {

	logs, sub, err := _TaikoL2.contract.FilterLogs(opts, "Anchored")
	if err != nil {
		return nil, err
	}
	return &TaikoL2AnchoredIterator{contract: _TaikoL2.contract, event: "Anchored", logs: logs, sub: sub}, nil
}

// WatchAnchored is a free log subscription operation binding the contract event 0x41c3f410f5c8ac36bb46b1dccef0de0f964087c9e688795fa02ecfa2c20b3fe4.
//
// Solidity: event Anchored(bytes32 parentHash, uint64 gasExcess)
func (_TaikoL2 *TaikoL2Filterer) WatchAnchored(opts *bind.WatchOpts, sink chan<- *TaikoL2Anchored) (event.Subscription, error) {

	logs, sub, err := _TaikoL2.contract.WatchLogs(opts, "Anchored")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL2Anchored)
				if err := _TaikoL2.contract.UnpackLog(event, "Anchored", log); err != nil {
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

// ParseAnchored is a log parse operation binding the contract event 0x41c3f410f5c8ac36bb46b1dccef0de0f964087c9e688795fa02ecfa2c20b3fe4.
//
// Solidity: event Anchored(bytes32 parentHash, uint64 gasExcess)
func (_TaikoL2 *TaikoL2Filterer) ParseAnchored(log types.Log) (*TaikoL2Anchored, error) {
	event := new(TaikoL2Anchored)
	if err := _TaikoL2.contract.UnpackLog(event, "Anchored", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL2BeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the TaikoL2 contract.
type TaikoL2BeaconUpgradedIterator struct {
	Event *TaikoL2BeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *TaikoL2BeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL2BeaconUpgraded)
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
		it.Event = new(TaikoL2BeaconUpgraded)
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
func (it *TaikoL2BeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL2BeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL2BeaconUpgraded represents a BeaconUpgraded event raised by the TaikoL2 contract.
type TaikoL2BeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_TaikoL2 *TaikoL2Filterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*TaikoL2BeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _TaikoL2.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL2BeaconUpgradedIterator{contract: _TaikoL2.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_TaikoL2 *TaikoL2Filterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *TaikoL2BeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _TaikoL2.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL2BeaconUpgraded)
				if err := _TaikoL2.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_TaikoL2 *TaikoL2Filterer) ParseBeaconUpgraded(log types.Log) (*TaikoL2BeaconUpgraded, error) {
	event := new(TaikoL2BeaconUpgraded)
	if err := _TaikoL2.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL2CrossChainSyncedIterator is returned from FilterCrossChainSynced and is used to iterate over the raw logs and unpacked data for CrossChainSynced events raised by the TaikoL2 contract.
type TaikoL2CrossChainSyncedIterator struct {
	Event *TaikoL2CrossChainSynced // Event containing the contract specifics and raw log

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
func (it *TaikoL2CrossChainSyncedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL2CrossChainSynced)
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
		it.Event = new(TaikoL2CrossChainSynced)
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
func (it *TaikoL2CrossChainSyncedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL2CrossChainSyncedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL2CrossChainSynced represents a CrossChainSynced event raised by the TaikoL2 contract.
type TaikoL2CrossChainSynced struct {
	SyncedInBlock uint64
	BlockId       uint64
	BlockHash     [32]byte
	SignalRoot    [32]byte
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterCrossChainSynced is a free log retrieval operation binding the contract event 0xf35ec3b262cf74881db1b8051c635496bccb1497a1e776dacb463d0e0e2b0f51.
//
// Solidity: event CrossChainSynced(uint64 indexed syncedInBlock, uint64 indexed blockId, bytes32 blockHash, bytes32 signalRoot)
func (_TaikoL2 *TaikoL2Filterer) FilterCrossChainSynced(opts *bind.FilterOpts, syncedInBlock []uint64, blockId []uint64) (*TaikoL2CrossChainSyncedIterator, error) {

	var syncedInBlockRule []interface{}
	for _, syncedInBlockItem := range syncedInBlock {
		syncedInBlockRule = append(syncedInBlockRule, syncedInBlockItem)
	}
	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _TaikoL2.contract.FilterLogs(opts, "CrossChainSynced", syncedInBlockRule, blockIdRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL2CrossChainSyncedIterator{contract: _TaikoL2.contract, event: "CrossChainSynced", logs: logs, sub: sub}, nil
}

// WatchCrossChainSynced is a free log subscription operation binding the contract event 0xf35ec3b262cf74881db1b8051c635496bccb1497a1e776dacb463d0e0e2b0f51.
//
// Solidity: event CrossChainSynced(uint64 indexed syncedInBlock, uint64 indexed blockId, bytes32 blockHash, bytes32 signalRoot)
func (_TaikoL2 *TaikoL2Filterer) WatchCrossChainSynced(opts *bind.WatchOpts, sink chan<- *TaikoL2CrossChainSynced, syncedInBlock []uint64, blockId []uint64) (event.Subscription, error) {

	var syncedInBlockRule []interface{}
	for _, syncedInBlockItem := range syncedInBlock {
		syncedInBlockRule = append(syncedInBlockRule, syncedInBlockItem)
	}
	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _TaikoL2.contract.WatchLogs(opts, "CrossChainSynced", syncedInBlockRule, blockIdRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL2CrossChainSynced)
				if err := _TaikoL2.contract.UnpackLog(event, "CrossChainSynced", log); err != nil {
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

// ParseCrossChainSynced is a log parse operation binding the contract event 0xf35ec3b262cf74881db1b8051c635496bccb1497a1e776dacb463d0e0e2b0f51.
//
// Solidity: event CrossChainSynced(uint64 indexed syncedInBlock, uint64 indexed blockId, bytes32 blockHash, bytes32 signalRoot)
func (_TaikoL2 *TaikoL2Filterer) ParseCrossChainSynced(log types.Log) (*TaikoL2CrossChainSynced, error) {
	event := new(TaikoL2CrossChainSynced)
	if err := _TaikoL2.contract.UnpackLog(event, "CrossChainSynced", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL2InitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the TaikoL2 contract.
type TaikoL2InitializedIterator struct {
	Event *TaikoL2Initialized // Event containing the contract specifics and raw log

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
func (it *TaikoL2InitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL2Initialized)
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
		it.Event = new(TaikoL2Initialized)
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
func (it *TaikoL2InitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL2InitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL2Initialized represents a Initialized event raised by the TaikoL2 contract.
type TaikoL2Initialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_TaikoL2 *TaikoL2Filterer) FilterInitialized(opts *bind.FilterOpts) (*TaikoL2InitializedIterator, error) {

	logs, sub, err := _TaikoL2.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &TaikoL2InitializedIterator{contract: _TaikoL2.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_TaikoL2 *TaikoL2Filterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *TaikoL2Initialized) (event.Subscription, error) {

	logs, sub, err := _TaikoL2.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL2Initialized)
				if err := _TaikoL2.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_TaikoL2 *TaikoL2Filterer) ParseInitialized(log types.Log) (*TaikoL2Initialized, error) {
	event := new(TaikoL2Initialized)
	if err := _TaikoL2.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL2OwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the TaikoL2 contract.
type TaikoL2OwnershipTransferredIterator struct {
	Event *TaikoL2OwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *TaikoL2OwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL2OwnershipTransferred)
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
		it.Event = new(TaikoL2OwnershipTransferred)
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
func (it *TaikoL2OwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL2OwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL2OwnershipTransferred represents a OwnershipTransferred event raised by the TaikoL2 contract.
type TaikoL2OwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_TaikoL2 *TaikoL2Filterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*TaikoL2OwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoL2.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL2OwnershipTransferredIterator{contract: _TaikoL2.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_TaikoL2 *TaikoL2Filterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *TaikoL2OwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoL2.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL2OwnershipTransferred)
				if err := _TaikoL2.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_TaikoL2 *TaikoL2Filterer) ParseOwnershipTransferred(log types.Log) (*TaikoL2OwnershipTransferred, error) {
	event := new(TaikoL2OwnershipTransferred)
	if err := _TaikoL2.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL2PausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the TaikoL2 contract.
type TaikoL2PausedIterator struct {
	Event *TaikoL2Paused // Event containing the contract specifics and raw log

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
func (it *TaikoL2PausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL2Paused)
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
		it.Event = new(TaikoL2Paused)
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
func (it *TaikoL2PausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL2PausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL2Paused represents a Paused event raised by the TaikoL2 contract.
type TaikoL2Paused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_TaikoL2 *TaikoL2Filterer) FilterPaused(opts *bind.FilterOpts) (*TaikoL2PausedIterator, error) {

	logs, sub, err := _TaikoL2.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &TaikoL2PausedIterator{contract: _TaikoL2.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_TaikoL2 *TaikoL2Filterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *TaikoL2Paused) (event.Subscription, error) {

	logs, sub, err := _TaikoL2.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL2Paused)
				if err := _TaikoL2.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_TaikoL2 *TaikoL2Filterer) ParsePaused(log types.Log) (*TaikoL2Paused, error) {
	event := new(TaikoL2Paused)
	if err := _TaikoL2.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL2UnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the TaikoL2 contract.
type TaikoL2UnpausedIterator struct {
	Event *TaikoL2Unpaused // Event containing the contract specifics and raw log

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
func (it *TaikoL2UnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL2Unpaused)
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
		it.Event = new(TaikoL2Unpaused)
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
func (it *TaikoL2UnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL2UnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL2Unpaused represents a Unpaused event raised by the TaikoL2 contract.
type TaikoL2Unpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_TaikoL2 *TaikoL2Filterer) FilterUnpaused(opts *bind.FilterOpts) (*TaikoL2UnpausedIterator, error) {

	logs, sub, err := _TaikoL2.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &TaikoL2UnpausedIterator{contract: _TaikoL2.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_TaikoL2 *TaikoL2Filterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *TaikoL2Unpaused) (event.Subscription, error) {

	logs, sub, err := _TaikoL2.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL2Unpaused)
				if err := _TaikoL2.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_TaikoL2 *TaikoL2Filterer) ParseUnpaused(log types.Log) (*TaikoL2Unpaused, error) {
	event := new(TaikoL2Unpaused)
	if err := _TaikoL2.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL2UpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the TaikoL2 contract.
type TaikoL2UpgradedIterator struct {
	Event *TaikoL2Upgraded // Event containing the contract specifics and raw log

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
func (it *TaikoL2UpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL2Upgraded)
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
		it.Event = new(TaikoL2Upgraded)
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
func (it *TaikoL2UpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL2UpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL2Upgraded represents a Upgraded event raised by the TaikoL2 contract.
type TaikoL2Upgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_TaikoL2 *TaikoL2Filterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*TaikoL2UpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _TaikoL2.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL2UpgradedIterator{contract: _TaikoL2.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_TaikoL2 *TaikoL2Filterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *TaikoL2Upgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _TaikoL2.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL2Upgraded)
				if err := _TaikoL2.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_TaikoL2 *TaikoL2Filterer) ParseUpgraded(log types.Log) (*TaikoL2Upgraded, error) {
	event := new(TaikoL2Upgraded)
	if err := _TaikoL2.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
