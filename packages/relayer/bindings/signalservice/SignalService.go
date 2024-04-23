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
	ABI: "[{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"addressManager\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"authorize\",\"inputs\":[{\"name\":\"_addr\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_authorize\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"getSignalSlot\",\"inputs\":[{\"name\":\"_chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_app\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_signal\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getSyncedChainData\",\"inputs\":[{\"name\":\"_chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_kind\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_blockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"outputs\":[{\"name\":\"blockId_\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"chainData_\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_addressManager\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isAuthorized\",\"inputs\":[{\"name\":\"addr\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"authorized\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isChainDataSynced\",\"inputs\":[{\"name\":\"_chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_kind\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_blockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_chainData\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isSignalSent\",\"inputs\":[{\"name\":\"_app\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_signal\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"lastUnpausedAt\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proveSignalReceived\",\"inputs\":[{\"name\":\"_chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_app\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_signal\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_proof\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"numCacheOps_\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolve\",\"inputs\":[{\"name\":\"_chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_allowZeroAddress\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"addresspayable\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"resolve\",\"inputs\":[{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_allowZeroAddress\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"addresspayable\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"sendSignal\",\"inputs\":[{\"name\":\"_signal\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"signalForChainData\",\"inputs\":[{\"name\":\"_chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_kind\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_blockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"syncChainData\",\"inputs\":[{\"name\":\"_chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_kind\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_blockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_chainData\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"topBlockId\",\"inputs\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"kind\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"blockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"verifySignalReceived\",\"inputs\":[{\"name\":\"_chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_app\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_signal\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_proof\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Authorized\",\"inputs\":[{\"name\":\"addr\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"authrized\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ChainDataSynced\",\"inputs\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"indexed\":true,\"internalType\":\"uint64\"},{\"name\":\"blockId\",\"type\":\"uint64\",\"indexed\":true,\"internalType\":\"uint64\"},{\"name\":\"kind\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"data\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"signal\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"SignalSent\",\"inputs\":[{\"name\":\"app\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"signal\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"slot\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"value\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"LTP_INVALID_ACCOUNT_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"LTP_INVALID_INCLUSION_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_INVALID_MANAGER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_UNEXPECTED_CHAINID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_ZERO_ADDR\",\"inputs\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"type\":\"error\",\"name\":\"SS_EMPTY_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SS_INVALID_HOPS_WITH_LOOP\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SS_INVALID_LAST_HOP_CHAINID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SS_INVALID_MID_HOP_CHAINID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SS_INVALID_SENDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SS_INVALID_STATE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SS_INVALID_VALUE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SS_SIGNAL_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SS_UNAUTHORIZED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SS_UNSUPPORTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDR_MANAGER\",\"inputs\":[]}]",
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

// GetSignalSlot is a free data retrieval call binding the contract method 0x91f3f74b.
//
// Solidity: function getSignalSlot(uint64 _chainId, address _app, bytes32 _signal) pure returns(bytes32)
func (_SignalService *SignalServiceCaller) GetSignalSlot(opts *bind.CallOpts, _chainId uint64, _app common.Address, _signal [32]byte) ([32]byte, error) {
	var out []interface{}
	err := _SignalService.contract.Call(opts, &out, "getSignalSlot", _chainId, _app, _signal)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetSignalSlot is a free data retrieval call binding the contract method 0x91f3f74b.
//
// Solidity: function getSignalSlot(uint64 _chainId, address _app, bytes32 _signal) pure returns(bytes32)
func (_SignalService *SignalServiceSession) GetSignalSlot(_chainId uint64, _app common.Address, _signal [32]byte) ([32]byte, error) {
	return _SignalService.Contract.GetSignalSlot(&_SignalService.CallOpts, _chainId, _app, _signal)
}

// GetSignalSlot is a free data retrieval call binding the contract method 0x91f3f74b.
//
// Solidity: function getSignalSlot(uint64 _chainId, address _app, bytes32 _signal) pure returns(bytes32)
func (_SignalService *SignalServiceCallerSession) GetSignalSlot(_chainId uint64, _app common.Address, _signal [32]byte) ([32]byte, error) {
	return _SignalService.Contract.GetSignalSlot(&_SignalService.CallOpts, _chainId, _app, _signal)
}

// GetSyncedChainData is a free data retrieval call binding the contract method 0xdfc8ff1d.
//
// Solidity: function getSyncedChainData(uint64 _chainId, bytes32 _kind, uint64 _blockId) view returns(uint64 blockId_, bytes32 chainData_)
func (_SignalService *SignalServiceCaller) GetSyncedChainData(opts *bind.CallOpts, _chainId uint64, _kind [32]byte, _blockId uint64) (struct {
	BlockId   uint64
	ChainData [32]byte
}, error) {
	var out []interface{}
	err := _SignalService.contract.Call(opts, &out, "getSyncedChainData", _chainId, _kind, _blockId)

	outstruct := new(struct {
		BlockId   uint64
		ChainData [32]byte
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.BlockId = *abi.ConvertType(out[0], new(uint64)).(*uint64)
	outstruct.ChainData = *abi.ConvertType(out[1], new([32]byte)).(*[32]byte)

	return *outstruct, err

}

// GetSyncedChainData is a free data retrieval call binding the contract method 0xdfc8ff1d.
//
// Solidity: function getSyncedChainData(uint64 _chainId, bytes32 _kind, uint64 _blockId) view returns(uint64 blockId_, bytes32 chainData_)
func (_SignalService *SignalServiceSession) GetSyncedChainData(_chainId uint64, _kind [32]byte, _blockId uint64) (struct {
	BlockId   uint64
	ChainData [32]byte
}, error) {
	return _SignalService.Contract.GetSyncedChainData(&_SignalService.CallOpts, _chainId, _kind, _blockId)
}

// GetSyncedChainData is a free data retrieval call binding the contract method 0xdfc8ff1d.
//
// Solidity: function getSyncedChainData(uint64 _chainId, bytes32 _kind, uint64 _blockId) view returns(uint64 blockId_, bytes32 chainData_)
func (_SignalService *SignalServiceCallerSession) GetSyncedChainData(_chainId uint64, _kind [32]byte, _blockId uint64) (struct {
	BlockId   uint64
	ChainData [32]byte
}, error) {
	return _SignalService.Contract.GetSyncedChainData(&_SignalService.CallOpts, _chainId, _kind, _blockId)
}

// IsAuthorized is a free data retrieval call binding the contract method 0xfe9fbb80.
//
// Solidity: function isAuthorized(address addr) view returns(bool authorized)
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
// Solidity: function isAuthorized(address addr) view returns(bool authorized)
func (_SignalService *SignalServiceSession) IsAuthorized(addr common.Address) (bool, error) {
	return _SignalService.Contract.IsAuthorized(&_SignalService.CallOpts, addr)
}

// IsAuthorized is a free data retrieval call binding the contract method 0xfe9fbb80.
//
// Solidity: function isAuthorized(address addr) view returns(bool authorized)
func (_SignalService *SignalServiceCallerSession) IsAuthorized(addr common.Address) (bool, error) {
	return _SignalService.Contract.IsAuthorized(&_SignalService.CallOpts, addr)
}

// IsChainDataSynced is a free data retrieval call binding the contract method 0x3ced0e08.
//
// Solidity: function isChainDataSynced(uint64 _chainId, bytes32 _kind, uint64 _blockId, bytes32 _chainData) view returns(bool)
func (_SignalService *SignalServiceCaller) IsChainDataSynced(opts *bind.CallOpts, _chainId uint64, _kind [32]byte, _blockId uint64, _chainData [32]byte) (bool, error) {
	var out []interface{}
	err := _SignalService.contract.Call(opts, &out, "isChainDataSynced", _chainId, _kind, _blockId, _chainData)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsChainDataSynced is a free data retrieval call binding the contract method 0x3ced0e08.
//
// Solidity: function isChainDataSynced(uint64 _chainId, bytes32 _kind, uint64 _blockId, bytes32 _chainData) view returns(bool)
func (_SignalService *SignalServiceSession) IsChainDataSynced(_chainId uint64, _kind [32]byte, _blockId uint64, _chainData [32]byte) (bool, error) {
	return _SignalService.Contract.IsChainDataSynced(&_SignalService.CallOpts, _chainId, _kind, _blockId, _chainData)
}

// IsChainDataSynced is a free data retrieval call binding the contract method 0x3ced0e08.
//
// Solidity: function isChainDataSynced(uint64 _chainId, bytes32 _kind, uint64 _blockId, bytes32 _chainData) view returns(bool)
func (_SignalService *SignalServiceCallerSession) IsChainDataSynced(_chainId uint64, _kind [32]byte, _blockId uint64, _chainData [32]byte) (bool, error) {
	return _SignalService.Contract.IsChainDataSynced(&_SignalService.CallOpts, _chainId, _kind, _blockId, _chainData)
}

// IsSignalSent is a free data retrieval call binding the contract method 0x32676bc6.
//
// Solidity: function isSignalSent(address _app, bytes32 _signal) view returns(bool)
func (_SignalService *SignalServiceCaller) IsSignalSent(opts *bind.CallOpts, _app common.Address, _signal [32]byte) (bool, error) {
	var out []interface{}
	err := _SignalService.contract.Call(opts, &out, "isSignalSent", _app, _signal)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsSignalSent is a free data retrieval call binding the contract method 0x32676bc6.
//
// Solidity: function isSignalSent(address _app, bytes32 _signal) view returns(bool)
func (_SignalService *SignalServiceSession) IsSignalSent(_app common.Address, _signal [32]byte) (bool, error) {
	return _SignalService.Contract.IsSignalSent(&_SignalService.CallOpts, _app, _signal)
}

// IsSignalSent is a free data retrieval call binding the contract method 0x32676bc6.
//
// Solidity: function isSignalSent(address _app, bytes32 _signal) view returns(bool)
func (_SignalService *SignalServiceCallerSession) IsSignalSent(_app common.Address, _signal [32]byte) (bool, error) {
	return _SignalService.Contract.IsSignalSent(&_SignalService.CallOpts, _app, _signal)
}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_SignalService *SignalServiceCaller) LastUnpausedAt(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _SignalService.contract.Call(opts, &out, "lastUnpausedAt")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_SignalService *SignalServiceSession) LastUnpausedAt() (uint64, error) {
	return _SignalService.Contract.LastUnpausedAt(&_SignalService.CallOpts)
}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_SignalService *SignalServiceCallerSession) LastUnpausedAt() (uint64, error) {
	return _SignalService.Contract.LastUnpausedAt(&_SignalService.CallOpts)
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

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_SignalService *SignalServiceCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SignalService.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_SignalService *SignalServiceSession) ProxiableUUID() ([32]byte, error) {
	return _SignalService.Contract.ProxiableUUID(&_SignalService.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_SignalService *SignalServiceCallerSession) ProxiableUUID() ([32]byte, error) {
	return _SignalService.Contract.ProxiableUUID(&_SignalService.CallOpts)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_SignalService *SignalServiceCaller) Resolve(opts *bind.CallOpts, _chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _SignalService.contract.Call(opts, &out, "resolve", _chainId, _name, _allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_SignalService *SignalServiceSession) Resolve(_chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _SignalService.Contract.Resolve(&_SignalService.CallOpts, _chainId, _name, _allowZeroAddress)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_SignalService *SignalServiceCallerSession) Resolve(_chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _SignalService.Contract.Resolve(&_SignalService.CallOpts, _chainId, _name, _allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_SignalService *SignalServiceCaller) Resolve0(opts *bind.CallOpts, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _SignalService.contract.Call(opts, &out, "resolve0", _name, _allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_SignalService *SignalServiceSession) Resolve0(_name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _SignalService.Contract.Resolve0(&_SignalService.CallOpts, _name, _allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_SignalService *SignalServiceCallerSession) Resolve0(_name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _SignalService.Contract.Resolve0(&_SignalService.CallOpts, _name, _allowZeroAddress)
}

// SignalForChainData is a free data retrieval call binding the contract method 0x9b527cfa.
//
// Solidity: function signalForChainData(uint64 _chainId, bytes32 _kind, uint64 _blockId) pure returns(bytes32)
func (_SignalService *SignalServiceCaller) SignalForChainData(opts *bind.CallOpts, _chainId uint64, _kind [32]byte, _blockId uint64) ([32]byte, error) {
	var out []interface{}
	err := _SignalService.contract.Call(opts, &out, "signalForChainData", _chainId, _kind, _blockId)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// SignalForChainData is a free data retrieval call binding the contract method 0x9b527cfa.
//
// Solidity: function signalForChainData(uint64 _chainId, bytes32 _kind, uint64 _blockId) pure returns(bytes32)
func (_SignalService *SignalServiceSession) SignalForChainData(_chainId uint64, _kind [32]byte, _blockId uint64) ([32]byte, error) {
	return _SignalService.Contract.SignalForChainData(&_SignalService.CallOpts, _chainId, _kind, _blockId)
}

// SignalForChainData is a free data retrieval call binding the contract method 0x9b527cfa.
//
// Solidity: function signalForChainData(uint64 _chainId, bytes32 _kind, uint64 _blockId) pure returns(bytes32)
func (_SignalService *SignalServiceCallerSession) SignalForChainData(_chainId uint64, _kind [32]byte, _blockId uint64) ([32]byte, error) {
	return _SignalService.Contract.SignalForChainData(&_SignalService.CallOpts, _chainId, _kind, _blockId)
}

// TopBlockId is a free data retrieval call binding the contract method 0x355bcc3d.
//
// Solidity: function topBlockId(uint64 chainId, bytes32 kind) view returns(uint64 blockId)
func (_SignalService *SignalServiceCaller) TopBlockId(opts *bind.CallOpts, chainId uint64, kind [32]byte) (uint64, error) {
	var out []interface{}
	err := _SignalService.contract.Call(opts, &out, "topBlockId", chainId, kind)

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// TopBlockId is a free data retrieval call binding the contract method 0x355bcc3d.
//
// Solidity: function topBlockId(uint64 chainId, bytes32 kind) view returns(uint64 blockId)
func (_SignalService *SignalServiceSession) TopBlockId(chainId uint64, kind [32]byte) (uint64, error) {
	return _SignalService.Contract.TopBlockId(&_SignalService.CallOpts, chainId, kind)
}

// TopBlockId is a free data retrieval call binding the contract method 0x355bcc3d.
//
// Solidity: function topBlockId(uint64 chainId, bytes32 kind) view returns(uint64 blockId)
func (_SignalService *SignalServiceCallerSession) TopBlockId(chainId uint64, kind [32]byte) (uint64, error) {
	return _SignalService.Contract.TopBlockId(&_SignalService.CallOpts, chainId, kind)
}

// VerifySignalReceived is a free data retrieval call binding the contract method 0xce9d0820.
//
// Solidity: function verifySignalReceived(uint64 _chainId, address _app, bytes32 _signal, bytes _proof) view returns()
func (_SignalService *SignalServiceCaller) VerifySignalReceived(opts *bind.CallOpts, _chainId uint64, _app common.Address, _signal [32]byte, _proof []byte) error {
	var out []interface{}
	err := _SignalService.contract.Call(opts, &out, "verifySignalReceived", _chainId, _app, _signal, _proof)

	if err != nil {
		return err
	}

	return err

}

// VerifySignalReceived is a free data retrieval call binding the contract method 0xce9d0820.
//
// Solidity: function verifySignalReceived(uint64 _chainId, address _app, bytes32 _signal, bytes _proof) view returns()
func (_SignalService *SignalServiceSession) VerifySignalReceived(_chainId uint64, _app common.Address, _signal [32]byte, _proof []byte) error {
	return _SignalService.Contract.VerifySignalReceived(&_SignalService.CallOpts, _chainId, _app, _signal, _proof)
}

// VerifySignalReceived is a free data retrieval call binding the contract method 0xce9d0820.
//
// Solidity: function verifySignalReceived(uint64 _chainId, address _app, bytes32 _signal, bytes _proof) view returns()
func (_SignalService *SignalServiceCallerSession) VerifySignalReceived(_chainId uint64, _app common.Address, _signal [32]byte, _proof []byte) error {
	return _SignalService.Contract.VerifySignalReceived(&_SignalService.CallOpts, _chainId, _app, _signal, _proof)
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

// Authorize is a paid mutator transaction binding the contract method 0x2d1fb389.
//
// Solidity: function authorize(address _addr, bool _authorize) returns()
func (_SignalService *SignalServiceTransactor) Authorize(opts *bind.TransactOpts, _addr common.Address, _authorize bool) (*types.Transaction, error) {
	return _SignalService.contract.Transact(opts, "authorize", _addr, _authorize)
}

// Authorize is a paid mutator transaction binding the contract method 0x2d1fb389.
//
// Solidity: function authorize(address _addr, bool _authorize) returns()
func (_SignalService *SignalServiceSession) Authorize(_addr common.Address, _authorize bool) (*types.Transaction, error) {
	return _SignalService.Contract.Authorize(&_SignalService.TransactOpts, _addr, _authorize)
}

// Authorize is a paid mutator transaction binding the contract method 0x2d1fb389.
//
// Solidity: function authorize(address _addr, bool _authorize) returns()
func (_SignalService *SignalServiceTransactorSession) Authorize(_addr common.Address, _authorize bool) (*types.Transaction, error) {
	return _SignalService.Contract.Authorize(&_SignalService.TransactOpts, _addr, _authorize)
}

// Init is a paid mutator transaction binding the contract method 0xf09a4016.
//
// Solidity: function init(address _owner, address _addressManager) returns()
func (_SignalService *SignalServiceTransactor) Init(opts *bind.TransactOpts, _owner common.Address, _addressManager common.Address) (*types.Transaction, error) {
	return _SignalService.contract.Transact(opts, "init", _owner, _addressManager)
}

// Init is a paid mutator transaction binding the contract method 0xf09a4016.
//
// Solidity: function init(address _owner, address _addressManager) returns()
func (_SignalService *SignalServiceSession) Init(_owner common.Address, _addressManager common.Address) (*types.Transaction, error) {
	return _SignalService.Contract.Init(&_SignalService.TransactOpts, _owner, _addressManager)
}

// Init is a paid mutator transaction binding the contract method 0xf09a4016.
//
// Solidity: function init(address _owner, address _addressManager) returns()
func (_SignalService *SignalServiceTransactorSession) Init(_owner common.Address, _addressManager common.Address) (*types.Transaction, error) {
	return _SignalService.Contract.Init(&_SignalService.TransactOpts, _owner, _addressManager)
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

// ProveSignalReceived is a paid mutator transaction binding the contract method 0x910af6ed.
//
// Solidity: function proveSignalReceived(uint64 _chainId, address _app, bytes32 _signal, bytes _proof) returns(uint256 numCacheOps_)
func (_SignalService *SignalServiceTransactor) ProveSignalReceived(opts *bind.TransactOpts, _chainId uint64, _app common.Address, _signal [32]byte, _proof []byte) (*types.Transaction, error) {
	return _SignalService.contract.Transact(opts, "proveSignalReceived", _chainId, _app, _signal, _proof)
}

// ProveSignalReceived is a paid mutator transaction binding the contract method 0x910af6ed.
//
// Solidity: function proveSignalReceived(uint64 _chainId, address _app, bytes32 _signal, bytes _proof) returns(uint256 numCacheOps_)
func (_SignalService *SignalServiceSession) ProveSignalReceived(_chainId uint64, _app common.Address, _signal [32]byte, _proof []byte) (*types.Transaction, error) {
	return _SignalService.Contract.ProveSignalReceived(&_SignalService.TransactOpts, _chainId, _app, _signal, _proof)
}

// ProveSignalReceived is a paid mutator transaction binding the contract method 0x910af6ed.
//
// Solidity: function proveSignalReceived(uint64 _chainId, address _app, bytes32 _signal, bytes _proof) returns(uint256 numCacheOps_)
func (_SignalService *SignalServiceTransactorSession) ProveSignalReceived(_chainId uint64, _app common.Address, _signal [32]byte, _proof []byte) (*types.Transaction, error) {
	return _SignalService.Contract.ProveSignalReceived(&_SignalService.TransactOpts, _chainId, _app, _signal, _proof)
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
// Solidity: function sendSignal(bytes32 _signal) returns(bytes32)
func (_SignalService *SignalServiceTransactor) SendSignal(opts *bind.TransactOpts, _signal [32]byte) (*types.Transaction, error) {
	return _SignalService.contract.Transact(opts, "sendSignal", _signal)
}

// SendSignal is a paid mutator transaction binding the contract method 0x66ca2bc0.
//
// Solidity: function sendSignal(bytes32 _signal) returns(bytes32)
func (_SignalService *SignalServiceSession) SendSignal(_signal [32]byte) (*types.Transaction, error) {
	return _SignalService.Contract.SendSignal(&_SignalService.TransactOpts, _signal)
}

// SendSignal is a paid mutator transaction binding the contract method 0x66ca2bc0.
//
// Solidity: function sendSignal(bytes32 _signal) returns(bytes32)
func (_SignalService *SignalServiceTransactorSession) SendSignal(_signal [32]byte) (*types.Transaction, error) {
	return _SignalService.Contract.SendSignal(&_SignalService.TransactOpts, _signal)
}

// SyncChainData is a paid mutator transaction binding the contract method 0x4f90a674.
//
// Solidity: function syncChainData(uint64 _chainId, bytes32 _kind, uint64 _blockId, bytes32 _chainData) returns(bytes32)
func (_SignalService *SignalServiceTransactor) SyncChainData(opts *bind.TransactOpts, _chainId uint64, _kind [32]byte, _blockId uint64, _chainData [32]byte) (*types.Transaction, error) {
	return _SignalService.contract.Transact(opts, "syncChainData", _chainId, _kind, _blockId, _chainData)
}

// SyncChainData is a paid mutator transaction binding the contract method 0x4f90a674.
//
// Solidity: function syncChainData(uint64 _chainId, bytes32 _kind, uint64 _blockId, bytes32 _chainData) returns(bytes32)
func (_SignalService *SignalServiceSession) SyncChainData(_chainId uint64, _kind [32]byte, _blockId uint64, _chainData [32]byte) (*types.Transaction, error) {
	return _SignalService.Contract.SyncChainData(&_SignalService.TransactOpts, _chainId, _kind, _blockId, _chainData)
}

// SyncChainData is a paid mutator transaction binding the contract method 0x4f90a674.
//
// Solidity: function syncChainData(uint64 _chainId, bytes32 _kind, uint64 _blockId, bytes32 _chainData) returns(bytes32)
func (_SignalService *SignalServiceTransactorSession) SyncChainData(_chainId uint64, _kind [32]byte, _blockId uint64, _chainData [32]byte) (*types.Transaction, error) {
	return _SignalService.Contract.SyncChainData(&_SignalService.TransactOpts, _chainId, _kind, _blockId, _chainData)
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

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_SignalService *SignalServiceTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _SignalService.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_SignalService *SignalServiceSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _SignalService.Contract.UpgradeTo(&_SignalService.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_SignalService *SignalServiceTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _SignalService.Contract.UpgradeTo(&_SignalService.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_SignalService *SignalServiceTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _SignalService.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_SignalService *SignalServiceSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _SignalService.Contract.UpgradeToAndCall(&_SignalService.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_SignalService *SignalServiceTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _SignalService.Contract.UpgradeToAndCall(&_SignalService.TransactOpts, newImplementation, data)
}

// SignalServiceAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the SignalService contract.
type SignalServiceAdminChangedIterator struct {
	Event *SignalServiceAdminChanged // Event containing the contract specifics and raw log

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
func (it *SignalServiceAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SignalServiceAdminChanged)
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
		it.Event = new(SignalServiceAdminChanged)
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
func (it *SignalServiceAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SignalServiceAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SignalServiceAdminChanged represents a AdminChanged event raised by the SignalService contract.
type SignalServiceAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_SignalService *SignalServiceFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*SignalServiceAdminChangedIterator, error) {

	logs, sub, err := _SignalService.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &SignalServiceAdminChangedIterator{contract: _SignalService.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_SignalService *SignalServiceFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *SignalServiceAdminChanged) (event.Subscription, error) {

	logs, sub, err := _SignalService.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SignalServiceAdminChanged)
				if err := _SignalService.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_SignalService *SignalServiceFilterer) ParseAdminChanged(log types.Log) (*SignalServiceAdminChanged, error) {
	event := new(SignalServiceAdminChanged)
	if err := _SignalService.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
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
	Addr      common.Address
	Authrized bool
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterAuthorized is a free log retrieval operation binding the contract event 0x4c0079b9bcd37cd5d29a13938effd97c881798cbc6bd52a3026a29d94b27d1bf.
//
// Solidity: event Authorized(address indexed addr, bool authrized)
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

// WatchAuthorized is a free log subscription operation binding the contract event 0x4c0079b9bcd37cd5d29a13938effd97c881798cbc6bd52a3026a29d94b27d1bf.
//
// Solidity: event Authorized(address indexed addr, bool authrized)
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

// ParseAuthorized is a log parse operation binding the contract event 0x4c0079b9bcd37cd5d29a13938effd97c881798cbc6bd52a3026a29d94b27d1bf.
//
// Solidity: event Authorized(address indexed addr, bool authrized)
func (_SignalService *SignalServiceFilterer) ParseAuthorized(log types.Log) (*SignalServiceAuthorized, error) {
	event := new(SignalServiceAuthorized)
	if err := _SignalService.contract.UnpackLog(event, "Authorized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SignalServiceBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the SignalService contract.
type SignalServiceBeaconUpgradedIterator struct {
	Event *SignalServiceBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *SignalServiceBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SignalServiceBeaconUpgraded)
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
		it.Event = new(SignalServiceBeaconUpgraded)
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
func (it *SignalServiceBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SignalServiceBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SignalServiceBeaconUpgraded represents a BeaconUpgraded event raised by the SignalService contract.
type SignalServiceBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_SignalService *SignalServiceFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*SignalServiceBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _SignalService.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &SignalServiceBeaconUpgradedIterator{contract: _SignalService.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_SignalService *SignalServiceFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *SignalServiceBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _SignalService.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SignalServiceBeaconUpgraded)
				if err := _SignalService.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_SignalService *SignalServiceFilterer) ParseBeaconUpgraded(log types.Log) (*SignalServiceBeaconUpgraded, error) {
	event := new(SignalServiceBeaconUpgraded)
	if err := _SignalService.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SignalServiceChainDataSyncedIterator is returned from FilterChainDataSynced and is used to iterate over the raw logs and unpacked data for ChainDataSynced events raised by the SignalService contract.
type SignalServiceChainDataSyncedIterator struct {
	Event *SignalServiceChainDataSynced // Event containing the contract specifics and raw log

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
func (it *SignalServiceChainDataSyncedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SignalServiceChainDataSynced)
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
		it.Event = new(SignalServiceChainDataSynced)
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
func (it *SignalServiceChainDataSyncedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SignalServiceChainDataSyncedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SignalServiceChainDataSynced represents a ChainDataSynced event raised by the SignalService contract.
type SignalServiceChainDataSynced struct {
	ChainId uint64
	BlockId uint64
	Kind    [32]byte
	Data    [32]byte
	Signal  [32]byte
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterChainDataSynced is a free log retrieval operation binding the contract event 0xde247c825b1fb2d7ff9e0e771cba6f9e757ad04479fcdc135d88ae91fd50b37d.
//
// Solidity: event ChainDataSynced(uint64 indexed chainId, uint64 indexed blockId, bytes32 indexed kind, bytes32 data, bytes32 signal)
func (_SignalService *SignalServiceFilterer) FilterChainDataSynced(opts *bind.FilterOpts, chainId []uint64, blockId []uint64, kind [][32]byte) (*SignalServiceChainDataSyncedIterator, error) {

	var chainIdRule []interface{}
	for _, chainIdItem := range chainId {
		chainIdRule = append(chainIdRule, chainIdItem)
	}
	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}
	var kindRule []interface{}
	for _, kindItem := range kind {
		kindRule = append(kindRule, kindItem)
	}

	logs, sub, err := _SignalService.contract.FilterLogs(opts, "ChainDataSynced", chainIdRule, blockIdRule, kindRule)
	if err != nil {
		return nil, err
	}
	return &SignalServiceChainDataSyncedIterator{contract: _SignalService.contract, event: "ChainDataSynced", logs: logs, sub: sub}, nil
}

// WatchChainDataSynced is a free log subscription operation binding the contract event 0xde247c825b1fb2d7ff9e0e771cba6f9e757ad04479fcdc135d88ae91fd50b37d.
//
// Solidity: event ChainDataSynced(uint64 indexed chainId, uint64 indexed blockId, bytes32 indexed kind, bytes32 data, bytes32 signal)
func (_SignalService *SignalServiceFilterer) WatchChainDataSynced(opts *bind.WatchOpts, sink chan<- *SignalServiceChainDataSynced, chainId []uint64, blockId []uint64, kind [][32]byte) (event.Subscription, error) {

	var chainIdRule []interface{}
	for _, chainIdItem := range chainId {
		chainIdRule = append(chainIdRule, chainIdItem)
	}
	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}
	var kindRule []interface{}
	for _, kindItem := range kind {
		kindRule = append(kindRule, kindItem)
	}

	logs, sub, err := _SignalService.contract.WatchLogs(opts, "ChainDataSynced", chainIdRule, blockIdRule, kindRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SignalServiceChainDataSynced)
				if err := _SignalService.contract.UnpackLog(event, "ChainDataSynced", log); err != nil {
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

// ParseChainDataSynced is a log parse operation binding the contract event 0xde247c825b1fb2d7ff9e0e771cba6f9e757ad04479fcdc135d88ae91fd50b37d.
//
// Solidity: event ChainDataSynced(uint64 indexed chainId, uint64 indexed blockId, bytes32 indexed kind, bytes32 data, bytes32 signal)
func (_SignalService *SignalServiceFilterer) ParseChainDataSynced(log types.Log) (*SignalServiceChainDataSynced, error) {
	event := new(SignalServiceChainDataSynced)
	if err := _SignalService.contract.UnpackLog(event, "ChainDataSynced", log); err != nil {
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

// SignalServiceSignalSentIterator is returned from FilterSignalSent and is used to iterate over the raw logs and unpacked data for SignalSent events raised by the SignalService contract.
type SignalServiceSignalSentIterator struct {
	Event *SignalServiceSignalSent // Event containing the contract specifics and raw log

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
func (it *SignalServiceSignalSentIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SignalServiceSignalSent)
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
		it.Event = new(SignalServiceSignalSent)
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
func (it *SignalServiceSignalSentIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SignalServiceSignalSentIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SignalServiceSignalSent represents a SignalSent event raised by the SignalService contract.
type SignalServiceSignalSent struct {
	App    common.Address
	Signal [32]byte
	Slot   [32]byte
	Value  [32]byte
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterSignalSent is a free log retrieval operation binding the contract event 0x0ad2d108660a211f47bf7fb43a0443cae181624995d3d42b88ee6879d200e973.
//
// Solidity: event SignalSent(address app, bytes32 signal, bytes32 slot, bytes32 value)
func (_SignalService *SignalServiceFilterer) FilterSignalSent(opts *bind.FilterOpts) (*SignalServiceSignalSentIterator, error) {

	logs, sub, err := _SignalService.contract.FilterLogs(opts, "SignalSent")
	if err != nil {
		return nil, err
	}
	return &SignalServiceSignalSentIterator{contract: _SignalService.contract, event: "SignalSent", logs: logs, sub: sub}, nil
}

// WatchSignalSent is a free log subscription operation binding the contract event 0x0ad2d108660a211f47bf7fb43a0443cae181624995d3d42b88ee6879d200e973.
//
// Solidity: event SignalSent(address app, bytes32 signal, bytes32 slot, bytes32 value)
func (_SignalService *SignalServiceFilterer) WatchSignalSent(opts *bind.WatchOpts, sink chan<- *SignalServiceSignalSent) (event.Subscription, error) {

	logs, sub, err := _SignalService.contract.WatchLogs(opts, "SignalSent")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SignalServiceSignalSent)
				if err := _SignalService.contract.UnpackLog(event, "SignalSent", log); err != nil {
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

// ParseSignalSent is a log parse operation binding the contract event 0x0ad2d108660a211f47bf7fb43a0443cae181624995d3d42b88ee6879d200e973.
//
// Solidity: event SignalSent(address app, bytes32 signal, bytes32 slot, bytes32 value)
func (_SignalService *SignalServiceFilterer) ParseSignalSent(log types.Log) (*SignalServiceSignalSent, error) {
	event := new(SignalServiceSignalSent)
	if err := _SignalService.contract.UnpackLog(event, "SignalSent", log); err != nil {
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

// SignalServiceUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the SignalService contract.
type SignalServiceUpgradedIterator struct {
	Event *SignalServiceUpgraded // Event containing the contract specifics and raw log

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
func (it *SignalServiceUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SignalServiceUpgraded)
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
		it.Event = new(SignalServiceUpgraded)
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
func (it *SignalServiceUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SignalServiceUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SignalServiceUpgraded represents a Upgraded event raised by the SignalService contract.
type SignalServiceUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_SignalService *SignalServiceFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*SignalServiceUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _SignalService.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &SignalServiceUpgradedIterator{contract: _SignalService.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_SignalService *SignalServiceFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *SignalServiceUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _SignalService.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SignalServiceUpgraded)
				if err := _SignalService.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_SignalService *SignalServiceFilterer) ParseUpgraded(log types.Log) (*SignalServiceUpgraded, error) {
	event := new(SignalServiceUpgraded)
	if err := _SignalService.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
