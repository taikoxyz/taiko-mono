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

// IPreconfRouterConfig is an auto generated low-level Go binding around an user-defined struct.
type IPreconfRouterConfig struct {
	HandOverSlots *big.Int
}

// PreconfRouterMetaData contains all meta data concerning the PreconfRouter contract.
var PreconfRouterMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"_proposeBatchEntrypoint\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_preconfWhitelist\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_fallbackPreconfer\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"fallbackPreconfer\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getConfig\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structIPreconfRouter.Config\",\"components\":[{\"name\":\"handOverSlots\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"impl\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inNonReentrant\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"preconfWhitelist\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIPreconfWhitelist\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proposeBatch\",\"inputs\":[{\"name\":\"_params\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"_txList\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.BatchInfo\",\"components\":[{\"name\":\"txsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blocks\",\"type\":\"tuple[]\",\"internalType\":\"structITaikoInbox.BlockParams[]\",\"components\":[{\"name\":\"numTransactions\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"timeShift\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"signalSlots\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}]},{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"extraData\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"coinbase\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"proposedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobCreatedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobByteOffset\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobByteSize\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"gasLimit\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"lastBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastBlockTimestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"anchorBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"anchorBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"baseFeeConfig\",\"type\":\"tuple\",\"internalType\":\"structLibSharedData.BaseFeeConfig\",\"components\":[{\"name\":\"adjustmentQuotient\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"gasIssuancePerSecond\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"minGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxGasIssuancePerBlock\",\"type\":\"uint32\",\"internalType\":\"uint32\"}]}]},{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.BatchMetadata\",\"components\":[{\"name\":\"infoHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"batchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"proposedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proposeBatchEntrypoint\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIProposeBatch\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proposeBatchWithExpectedLastBlockId\",\"inputs\":[{\"name\":\"_params\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"_txList\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"_expectedLastBlockId\",\"type\":\"uint96\",\"internalType\":\"uint96\"}],\"outputs\":[{\"name\":\"info_\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.BatchInfo\",\"components\":[{\"name\":\"txsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blocks\",\"type\":\"tuple[]\",\"internalType\":\"structITaikoInbox.BlockParams[]\",\"components\":[{\"name\":\"numTransactions\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"timeShift\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"signalSlots\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}]},{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"extraData\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"coinbase\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"proposedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobCreatedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobByteOffset\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobByteSize\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"gasLimit\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"lastBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastBlockTimestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"anchorBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"anchorBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"baseFeeConfig\",\"type\":\"tuple\",\"internalType\":\"structLibSharedData.BaseFeeConfig\",\"components\":[{\"name\":\"adjustmentQuotient\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"gasIssuancePerSecond\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"minGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxGasIssuancePerBlock\",\"type\":\"uint32\",\"internalType\":\"uint32\"}]}]},{\"name\":\"meta_\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.BatchMetadata\",\"components\":[{\"name\":\"infoHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"batchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"proposedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolver\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCESS_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FUNC_NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ForcedInclusionNotSupported\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidLastBlockId\",\"inputs\":[{\"name\":\"_actual\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"_expected\",\"type\":\"uint96\",\"internalType\":\"uint96\"}]},{\"type\":\"error\",\"name\":\"NotPreconferOrFallback\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ProposerIsNotPreconfer\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_VALUE\",\"inputs\":[]}]",
}

// PreconfRouterABI is the input ABI used to generate the binding from.
// Deprecated: Use PreconfRouterMetaData.ABI instead.
var PreconfRouterABI = PreconfRouterMetaData.ABI

// PreconfRouter is an auto generated Go binding around an Ethereum contract.
type PreconfRouter struct {
	PreconfRouterCaller     // Read-only binding to the contract
	PreconfRouterTransactor // Write-only binding to the contract
	PreconfRouterFilterer   // Log filterer for contract events
}

// PreconfRouterCaller is an auto generated read-only Go binding around an Ethereum contract.
type PreconfRouterCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// PreconfRouterTransactor is an auto generated write-only Go binding around an Ethereum contract.
type PreconfRouterTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// PreconfRouterFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type PreconfRouterFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// PreconfRouterSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type PreconfRouterSession struct {
	Contract     *PreconfRouter    // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// PreconfRouterCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type PreconfRouterCallerSession struct {
	Contract *PreconfRouterCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts        // Call options to use throughout this session
}

// PreconfRouterTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type PreconfRouterTransactorSession struct {
	Contract     *PreconfRouterTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts        // Transaction auth options to use throughout this session
}

// PreconfRouterRaw is an auto generated low-level Go binding around an Ethereum contract.
type PreconfRouterRaw struct {
	Contract *PreconfRouter // Generic contract binding to access the raw methods on
}

// PreconfRouterCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type PreconfRouterCallerRaw struct {
	Contract *PreconfRouterCaller // Generic read-only contract binding to access the raw methods on
}

// PreconfRouterTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type PreconfRouterTransactorRaw struct {
	Contract *PreconfRouterTransactor // Generic write-only contract binding to access the raw methods on
}

// NewPreconfRouter creates a new instance of PreconfRouter, bound to a specific deployed contract.
func NewPreconfRouter(address common.Address, backend bind.ContractBackend) (*PreconfRouter, error) {
	contract, err := bindPreconfRouter(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &PreconfRouter{PreconfRouterCaller: PreconfRouterCaller{contract: contract}, PreconfRouterTransactor: PreconfRouterTransactor{contract: contract}, PreconfRouterFilterer: PreconfRouterFilterer{contract: contract}}, nil
}

// NewPreconfRouterCaller creates a new read-only instance of PreconfRouter, bound to a specific deployed contract.
func NewPreconfRouterCaller(address common.Address, caller bind.ContractCaller) (*PreconfRouterCaller, error) {
	contract, err := bindPreconfRouter(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &PreconfRouterCaller{contract: contract}, nil
}

// NewPreconfRouterTransactor creates a new write-only instance of PreconfRouter, bound to a specific deployed contract.
func NewPreconfRouterTransactor(address common.Address, transactor bind.ContractTransactor) (*PreconfRouterTransactor, error) {
	contract, err := bindPreconfRouter(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &PreconfRouterTransactor{contract: contract}, nil
}

// NewPreconfRouterFilterer creates a new log filterer instance of PreconfRouter, bound to a specific deployed contract.
func NewPreconfRouterFilterer(address common.Address, filterer bind.ContractFilterer) (*PreconfRouterFilterer, error) {
	contract, err := bindPreconfRouter(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &PreconfRouterFilterer{contract: contract}, nil
}

// bindPreconfRouter binds a generic wrapper to an already deployed contract.
func bindPreconfRouter(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := PreconfRouterMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_PreconfRouter *PreconfRouterRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _PreconfRouter.Contract.PreconfRouterCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_PreconfRouter *PreconfRouterRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _PreconfRouter.Contract.PreconfRouterTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_PreconfRouter *PreconfRouterRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _PreconfRouter.Contract.PreconfRouterTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_PreconfRouter *PreconfRouterCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _PreconfRouter.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_PreconfRouter *PreconfRouterTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _PreconfRouter.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_PreconfRouter *PreconfRouterTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _PreconfRouter.Contract.contract.Transact(opts, method, params...)
}

// FallbackPreconfer is a free data retrieval call binding the contract method 0xc75e78ec.
//
// Solidity: function fallbackPreconfer() view returns(address)
func (_PreconfRouter *PreconfRouterCaller) FallbackPreconfer(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _PreconfRouter.contract.Call(opts, &out, "fallbackPreconfer")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// FallbackPreconfer is a free data retrieval call binding the contract method 0xc75e78ec.
//
// Solidity: function fallbackPreconfer() view returns(address)
func (_PreconfRouter *PreconfRouterSession) FallbackPreconfer() (common.Address, error) {
	return _PreconfRouter.Contract.FallbackPreconfer(&_PreconfRouter.CallOpts)
}

// FallbackPreconfer is a free data retrieval call binding the contract method 0xc75e78ec.
//
// Solidity: function fallbackPreconfer() view returns(address)
func (_PreconfRouter *PreconfRouterCallerSession) FallbackPreconfer() (common.Address, error) {
	return _PreconfRouter.Contract.FallbackPreconfer(&_PreconfRouter.CallOpts)
}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() pure returns((uint256))
func (_PreconfRouter *PreconfRouterCaller) GetConfig(opts *bind.CallOpts) (IPreconfRouterConfig, error) {
	var out []interface{}
	err := _PreconfRouter.contract.Call(opts, &out, "getConfig")

	if err != nil {
		return *new(IPreconfRouterConfig), err
	}

	out0 := *abi.ConvertType(out[0], new(IPreconfRouterConfig)).(*IPreconfRouterConfig)

	return out0, err

}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() pure returns((uint256))
func (_PreconfRouter *PreconfRouterSession) GetConfig() (IPreconfRouterConfig, error) {
	return _PreconfRouter.Contract.GetConfig(&_PreconfRouter.CallOpts)
}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() pure returns((uint256))
func (_PreconfRouter *PreconfRouterCallerSession) GetConfig() (IPreconfRouterConfig, error) {
	return _PreconfRouter.Contract.GetConfig(&_PreconfRouter.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_PreconfRouter *PreconfRouterCaller) Impl(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _PreconfRouter.contract.Call(opts, &out, "impl")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_PreconfRouter *PreconfRouterSession) Impl() (common.Address, error) {
	return _PreconfRouter.Contract.Impl(&_PreconfRouter.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_PreconfRouter *PreconfRouterCallerSession) Impl() (common.Address, error) {
	return _PreconfRouter.Contract.Impl(&_PreconfRouter.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_PreconfRouter *PreconfRouterCaller) InNonReentrant(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _PreconfRouter.contract.Call(opts, &out, "inNonReentrant")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_PreconfRouter *PreconfRouterSession) InNonReentrant() (bool, error) {
	return _PreconfRouter.Contract.InNonReentrant(&_PreconfRouter.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_PreconfRouter *PreconfRouterCallerSession) InNonReentrant() (bool, error) {
	return _PreconfRouter.Contract.InNonReentrant(&_PreconfRouter.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_PreconfRouter *PreconfRouterCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _PreconfRouter.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_PreconfRouter *PreconfRouterSession) Owner() (common.Address, error) {
	return _PreconfRouter.Contract.Owner(&_PreconfRouter.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_PreconfRouter *PreconfRouterCallerSession) Owner() (common.Address, error) {
	return _PreconfRouter.Contract.Owner(&_PreconfRouter.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_PreconfRouter *PreconfRouterCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _PreconfRouter.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_PreconfRouter *PreconfRouterSession) Paused() (bool, error) {
	return _PreconfRouter.Contract.Paused(&_PreconfRouter.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_PreconfRouter *PreconfRouterCallerSession) Paused() (bool, error) {
	return _PreconfRouter.Contract.Paused(&_PreconfRouter.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_PreconfRouter *PreconfRouterCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _PreconfRouter.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_PreconfRouter *PreconfRouterSession) PendingOwner() (common.Address, error) {
	return _PreconfRouter.Contract.PendingOwner(&_PreconfRouter.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_PreconfRouter *PreconfRouterCallerSession) PendingOwner() (common.Address, error) {
	return _PreconfRouter.Contract.PendingOwner(&_PreconfRouter.CallOpts)
}

// PreconfWhitelist is a free data retrieval call binding the contract method 0xd91f24f1.
//
// Solidity: function preconfWhitelist() view returns(address)
func (_PreconfRouter *PreconfRouterCaller) PreconfWhitelist(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _PreconfRouter.contract.Call(opts, &out, "preconfWhitelist")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PreconfWhitelist is a free data retrieval call binding the contract method 0xd91f24f1.
//
// Solidity: function preconfWhitelist() view returns(address)
func (_PreconfRouter *PreconfRouterSession) PreconfWhitelist() (common.Address, error) {
	return _PreconfRouter.Contract.PreconfWhitelist(&_PreconfRouter.CallOpts)
}

// PreconfWhitelist is a free data retrieval call binding the contract method 0xd91f24f1.
//
// Solidity: function preconfWhitelist() view returns(address)
func (_PreconfRouter *PreconfRouterCallerSession) PreconfWhitelist() (common.Address, error) {
	return _PreconfRouter.Contract.PreconfWhitelist(&_PreconfRouter.CallOpts)
}

// ProposeBatchEntrypoint is a free data retrieval call binding the contract method 0x31d80cb7.
//
// Solidity: function proposeBatchEntrypoint() view returns(address)
func (_PreconfRouter *PreconfRouterCaller) ProposeBatchEntrypoint(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _PreconfRouter.contract.Call(opts, &out, "proposeBatchEntrypoint")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// ProposeBatchEntrypoint is a free data retrieval call binding the contract method 0x31d80cb7.
//
// Solidity: function proposeBatchEntrypoint() view returns(address)
func (_PreconfRouter *PreconfRouterSession) ProposeBatchEntrypoint() (common.Address, error) {
	return _PreconfRouter.Contract.ProposeBatchEntrypoint(&_PreconfRouter.CallOpts)
}

// ProposeBatchEntrypoint is a free data retrieval call binding the contract method 0x31d80cb7.
//
// Solidity: function proposeBatchEntrypoint() view returns(address)
func (_PreconfRouter *PreconfRouterCallerSession) ProposeBatchEntrypoint() (common.Address, error) {
	return _PreconfRouter.Contract.ProposeBatchEntrypoint(&_PreconfRouter.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_PreconfRouter *PreconfRouterCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _PreconfRouter.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_PreconfRouter *PreconfRouterSession) ProxiableUUID() ([32]byte, error) {
	return _PreconfRouter.Contract.ProxiableUUID(&_PreconfRouter.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_PreconfRouter *PreconfRouterCallerSession) ProxiableUUID() ([32]byte, error) {
	return _PreconfRouter.Contract.ProxiableUUID(&_PreconfRouter.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_PreconfRouter *PreconfRouterCaller) Resolver(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _PreconfRouter.contract.Call(opts, &out, "resolver")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_PreconfRouter *PreconfRouterSession) Resolver() (common.Address, error) {
	return _PreconfRouter.Contract.Resolver(&_PreconfRouter.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_PreconfRouter *PreconfRouterCallerSession) Resolver() (common.Address, error) {
	return _PreconfRouter.Contract.Resolver(&_PreconfRouter.CallOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_PreconfRouter *PreconfRouterTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _PreconfRouter.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_PreconfRouter *PreconfRouterSession) AcceptOwnership() (*types.Transaction, error) {
	return _PreconfRouter.Contract.AcceptOwnership(&_PreconfRouter.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_PreconfRouter *PreconfRouterTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _PreconfRouter.Contract.AcceptOwnership(&_PreconfRouter.TransactOpts)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_PreconfRouter *PreconfRouterTransactor) Init(opts *bind.TransactOpts, _owner common.Address) (*types.Transaction, error) {
	return _PreconfRouter.contract.Transact(opts, "init", _owner)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_PreconfRouter *PreconfRouterSession) Init(_owner common.Address) (*types.Transaction, error) {
	return _PreconfRouter.Contract.Init(&_PreconfRouter.TransactOpts, _owner)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_PreconfRouter *PreconfRouterTransactorSession) Init(_owner common.Address) (*types.Transaction, error) {
	return _PreconfRouter.Contract.Init(&_PreconfRouter.TransactOpts, _owner)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_PreconfRouter *PreconfRouterTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _PreconfRouter.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_PreconfRouter *PreconfRouterSession) Pause() (*types.Transaction, error) {
	return _PreconfRouter.Contract.Pause(&_PreconfRouter.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_PreconfRouter *PreconfRouterTransactorSession) Pause() (*types.Transaction, error) {
	return _PreconfRouter.Contract.Pause(&_PreconfRouter.TransactOpts)
}

// ProposeBatch is a paid mutator transaction binding the contract method 0x47faad14.
//
// Solidity: function proposeBatch(bytes _params, bytes _txList) returns((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint64,uint32,uint32,uint32,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint32)), (bytes32,address,uint64,uint64))
func (_PreconfRouter *PreconfRouterTransactor) ProposeBatch(opts *bind.TransactOpts, _params []byte, _txList []byte) (*types.Transaction, error) {
	return _PreconfRouter.contract.Transact(opts, "proposeBatch", _params, _txList)
}

// ProposeBatch is a paid mutator transaction binding the contract method 0x47faad14.
//
// Solidity: function proposeBatch(bytes _params, bytes _txList) returns((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint64,uint32,uint32,uint32,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint32)), (bytes32,address,uint64,uint64))
func (_PreconfRouter *PreconfRouterSession) ProposeBatch(_params []byte, _txList []byte) (*types.Transaction, error) {
	return _PreconfRouter.Contract.ProposeBatch(&_PreconfRouter.TransactOpts, _params, _txList)
}

// ProposeBatch is a paid mutator transaction binding the contract method 0x47faad14.
//
// Solidity: function proposeBatch(bytes _params, bytes _txList) returns((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint64,uint32,uint32,uint32,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint32)), (bytes32,address,uint64,uint64))
func (_PreconfRouter *PreconfRouterTransactorSession) ProposeBatch(_params []byte, _txList []byte) (*types.Transaction, error) {
	return _PreconfRouter.Contract.ProposeBatch(&_PreconfRouter.TransactOpts, _params, _txList)
}

// ProposeBatchWithExpectedLastBlockId is a paid mutator transaction binding the contract method 0xc939ac47.
//
// Solidity: function proposeBatchWithExpectedLastBlockId(bytes _params, bytes _txList, uint96 _expectedLastBlockId) returns((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint64,uint32,uint32,uint32,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint32)) info_, (bytes32,address,uint64,uint64) meta_)
func (_PreconfRouter *PreconfRouterTransactor) ProposeBatchWithExpectedLastBlockId(opts *bind.TransactOpts, _params []byte, _txList []byte, _expectedLastBlockId *big.Int) (*types.Transaction, error) {
	return _PreconfRouter.contract.Transact(opts, "proposeBatchWithExpectedLastBlockId", _params, _txList, _expectedLastBlockId)
}

// ProposeBatchWithExpectedLastBlockId is a paid mutator transaction binding the contract method 0xc939ac47.
//
// Solidity: function proposeBatchWithExpectedLastBlockId(bytes _params, bytes _txList, uint96 _expectedLastBlockId) returns((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint64,uint32,uint32,uint32,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint32)) info_, (bytes32,address,uint64,uint64) meta_)
func (_PreconfRouter *PreconfRouterSession) ProposeBatchWithExpectedLastBlockId(_params []byte, _txList []byte, _expectedLastBlockId *big.Int) (*types.Transaction, error) {
	return _PreconfRouter.Contract.ProposeBatchWithExpectedLastBlockId(&_PreconfRouter.TransactOpts, _params, _txList, _expectedLastBlockId)
}

// ProposeBatchWithExpectedLastBlockId is a paid mutator transaction binding the contract method 0xc939ac47.
//
// Solidity: function proposeBatchWithExpectedLastBlockId(bytes _params, bytes _txList, uint96 _expectedLastBlockId) returns((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint64,uint32,uint32,uint32,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint32)) info_, (bytes32,address,uint64,uint64) meta_)
func (_PreconfRouter *PreconfRouterTransactorSession) ProposeBatchWithExpectedLastBlockId(_params []byte, _txList []byte, _expectedLastBlockId *big.Int) (*types.Transaction, error) {
	return _PreconfRouter.Contract.ProposeBatchWithExpectedLastBlockId(&_PreconfRouter.TransactOpts, _params, _txList, _expectedLastBlockId)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_PreconfRouter *PreconfRouterTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _PreconfRouter.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_PreconfRouter *PreconfRouterSession) RenounceOwnership() (*types.Transaction, error) {
	return _PreconfRouter.Contract.RenounceOwnership(&_PreconfRouter.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_PreconfRouter *PreconfRouterTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _PreconfRouter.Contract.RenounceOwnership(&_PreconfRouter.TransactOpts)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_PreconfRouter *PreconfRouterTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _PreconfRouter.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_PreconfRouter *PreconfRouterSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _PreconfRouter.Contract.TransferOwnership(&_PreconfRouter.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_PreconfRouter *PreconfRouterTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _PreconfRouter.Contract.TransferOwnership(&_PreconfRouter.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_PreconfRouter *PreconfRouterTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _PreconfRouter.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_PreconfRouter *PreconfRouterSession) Unpause() (*types.Transaction, error) {
	return _PreconfRouter.Contract.Unpause(&_PreconfRouter.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_PreconfRouter *PreconfRouterTransactorSession) Unpause() (*types.Transaction, error) {
	return _PreconfRouter.Contract.Unpause(&_PreconfRouter.TransactOpts)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_PreconfRouter *PreconfRouterTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _PreconfRouter.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_PreconfRouter *PreconfRouterSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _PreconfRouter.Contract.UpgradeTo(&_PreconfRouter.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_PreconfRouter *PreconfRouterTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _PreconfRouter.Contract.UpgradeTo(&_PreconfRouter.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_PreconfRouter *PreconfRouterTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _PreconfRouter.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_PreconfRouter *PreconfRouterSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _PreconfRouter.Contract.UpgradeToAndCall(&_PreconfRouter.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_PreconfRouter *PreconfRouterTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _PreconfRouter.Contract.UpgradeToAndCall(&_PreconfRouter.TransactOpts, newImplementation, data)
}

// PreconfRouterAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the PreconfRouter contract.
type PreconfRouterAdminChangedIterator struct {
	Event *PreconfRouterAdminChanged // Event containing the contract specifics and raw log

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
func (it *PreconfRouterAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PreconfRouterAdminChanged)
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
		it.Event = new(PreconfRouterAdminChanged)
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
func (it *PreconfRouterAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PreconfRouterAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PreconfRouterAdminChanged represents a AdminChanged event raised by the PreconfRouter contract.
type PreconfRouterAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_PreconfRouter *PreconfRouterFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*PreconfRouterAdminChangedIterator, error) {

	logs, sub, err := _PreconfRouter.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &PreconfRouterAdminChangedIterator{contract: _PreconfRouter.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_PreconfRouter *PreconfRouterFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *PreconfRouterAdminChanged) (event.Subscription, error) {

	logs, sub, err := _PreconfRouter.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PreconfRouterAdminChanged)
				if err := _PreconfRouter.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_PreconfRouter *PreconfRouterFilterer) ParseAdminChanged(log types.Log) (*PreconfRouterAdminChanged, error) {
	event := new(PreconfRouterAdminChanged)
	if err := _PreconfRouter.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PreconfRouterBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the PreconfRouter contract.
type PreconfRouterBeaconUpgradedIterator struct {
	Event *PreconfRouterBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *PreconfRouterBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PreconfRouterBeaconUpgraded)
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
		it.Event = new(PreconfRouterBeaconUpgraded)
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
func (it *PreconfRouterBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PreconfRouterBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PreconfRouterBeaconUpgraded represents a BeaconUpgraded event raised by the PreconfRouter contract.
type PreconfRouterBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_PreconfRouter *PreconfRouterFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*PreconfRouterBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _PreconfRouter.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &PreconfRouterBeaconUpgradedIterator{contract: _PreconfRouter.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_PreconfRouter *PreconfRouterFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *PreconfRouterBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _PreconfRouter.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PreconfRouterBeaconUpgraded)
				if err := _PreconfRouter.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_PreconfRouter *PreconfRouterFilterer) ParseBeaconUpgraded(log types.Log) (*PreconfRouterBeaconUpgraded, error) {
	event := new(PreconfRouterBeaconUpgraded)
	if err := _PreconfRouter.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PreconfRouterInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the PreconfRouter contract.
type PreconfRouterInitializedIterator struct {
	Event *PreconfRouterInitialized // Event containing the contract specifics and raw log

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
func (it *PreconfRouterInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PreconfRouterInitialized)
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
		it.Event = new(PreconfRouterInitialized)
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
func (it *PreconfRouterInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PreconfRouterInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PreconfRouterInitialized represents a Initialized event raised by the PreconfRouter contract.
type PreconfRouterInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_PreconfRouter *PreconfRouterFilterer) FilterInitialized(opts *bind.FilterOpts) (*PreconfRouterInitializedIterator, error) {

	logs, sub, err := _PreconfRouter.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &PreconfRouterInitializedIterator{contract: _PreconfRouter.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_PreconfRouter *PreconfRouterFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *PreconfRouterInitialized) (event.Subscription, error) {

	logs, sub, err := _PreconfRouter.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PreconfRouterInitialized)
				if err := _PreconfRouter.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_PreconfRouter *PreconfRouterFilterer) ParseInitialized(log types.Log) (*PreconfRouterInitialized, error) {
	event := new(PreconfRouterInitialized)
	if err := _PreconfRouter.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PreconfRouterOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the PreconfRouter contract.
type PreconfRouterOwnershipTransferStartedIterator struct {
	Event *PreconfRouterOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *PreconfRouterOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PreconfRouterOwnershipTransferStarted)
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
		it.Event = new(PreconfRouterOwnershipTransferStarted)
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
func (it *PreconfRouterOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PreconfRouterOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PreconfRouterOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the PreconfRouter contract.
type PreconfRouterOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_PreconfRouter *PreconfRouterFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*PreconfRouterOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _PreconfRouter.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &PreconfRouterOwnershipTransferStartedIterator{contract: _PreconfRouter.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_PreconfRouter *PreconfRouterFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *PreconfRouterOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _PreconfRouter.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PreconfRouterOwnershipTransferStarted)
				if err := _PreconfRouter.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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
func (_PreconfRouter *PreconfRouterFilterer) ParseOwnershipTransferStarted(log types.Log) (*PreconfRouterOwnershipTransferStarted, error) {
	event := new(PreconfRouterOwnershipTransferStarted)
	if err := _PreconfRouter.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PreconfRouterOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the PreconfRouter contract.
type PreconfRouterOwnershipTransferredIterator struct {
	Event *PreconfRouterOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *PreconfRouterOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PreconfRouterOwnershipTransferred)
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
		it.Event = new(PreconfRouterOwnershipTransferred)
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
func (it *PreconfRouterOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PreconfRouterOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PreconfRouterOwnershipTransferred represents a OwnershipTransferred event raised by the PreconfRouter contract.
type PreconfRouterOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_PreconfRouter *PreconfRouterFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*PreconfRouterOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _PreconfRouter.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &PreconfRouterOwnershipTransferredIterator{contract: _PreconfRouter.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_PreconfRouter *PreconfRouterFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *PreconfRouterOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _PreconfRouter.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PreconfRouterOwnershipTransferred)
				if err := _PreconfRouter.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_PreconfRouter *PreconfRouterFilterer) ParseOwnershipTransferred(log types.Log) (*PreconfRouterOwnershipTransferred, error) {
	event := new(PreconfRouterOwnershipTransferred)
	if err := _PreconfRouter.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PreconfRouterPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the PreconfRouter contract.
type PreconfRouterPausedIterator struct {
	Event *PreconfRouterPaused // Event containing the contract specifics and raw log

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
func (it *PreconfRouterPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PreconfRouterPaused)
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
		it.Event = new(PreconfRouterPaused)
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
func (it *PreconfRouterPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PreconfRouterPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PreconfRouterPaused represents a Paused event raised by the PreconfRouter contract.
type PreconfRouterPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_PreconfRouter *PreconfRouterFilterer) FilterPaused(opts *bind.FilterOpts) (*PreconfRouterPausedIterator, error) {

	logs, sub, err := _PreconfRouter.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &PreconfRouterPausedIterator{contract: _PreconfRouter.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_PreconfRouter *PreconfRouterFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *PreconfRouterPaused) (event.Subscription, error) {

	logs, sub, err := _PreconfRouter.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PreconfRouterPaused)
				if err := _PreconfRouter.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_PreconfRouter *PreconfRouterFilterer) ParsePaused(log types.Log) (*PreconfRouterPaused, error) {
	event := new(PreconfRouterPaused)
	if err := _PreconfRouter.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PreconfRouterUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the PreconfRouter contract.
type PreconfRouterUnpausedIterator struct {
	Event *PreconfRouterUnpaused // Event containing the contract specifics and raw log

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
func (it *PreconfRouterUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PreconfRouterUnpaused)
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
		it.Event = new(PreconfRouterUnpaused)
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
func (it *PreconfRouterUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PreconfRouterUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PreconfRouterUnpaused represents a Unpaused event raised by the PreconfRouter contract.
type PreconfRouterUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_PreconfRouter *PreconfRouterFilterer) FilterUnpaused(opts *bind.FilterOpts) (*PreconfRouterUnpausedIterator, error) {

	logs, sub, err := _PreconfRouter.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &PreconfRouterUnpausedIterator{contract: _PreconfRouter.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_PreconfRouter *PreconfRouterFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *PreconfRouterUnpaused) (event.Subscription, error) {

	logs, sub, err := _PreconfRouter.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PreconfRouterUnpaused)
				if err := _PreconfRouter.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_PreconfRouter *PreconfRouterFilterer) ParseUnpaused(log types.Log) (*PreconfRouterUnpaused, error) {
	event := new(PreconfRouterUnpaused)
	if err := _PreconfRouter.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// PreconfRouterUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the PreconfRouter contract.
type PreconfRouterUpgradedIterator struct {
	Event *PreconfRouterUpgraded // Event containing the contract specifics and raw log

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
func (it *PreconfRouterUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(PreconfRouterUpgraded)
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
		it.Event = new(PreconfRouterUpgraded)
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
func (it *PreconfRouterUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *PreconfRouterUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// PreconfRouterUpgraded represents a Upgraded event raised by the PreconfRouter contract.
type PreconfRouterUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_PreconfRouter *PreconfRouterFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*PreconfRouterUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _PreconfRouter.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &PreconfRouterUpgradedIterator{contract: _PreconfRouter.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_PreconfRouter *PreconfRouterFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *PreconfRouterUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _PreconfRouter.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(PreconfRouterUpgraded)
				if err := _PreconfRouter.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_PreconfRouter *PreconfRouterFilterer) ParseUpgraded(log types.Log) (*PreconfRouterUpgraded, error) {
	event := new(PreconfRouterUpgraded)
	if err := _PreconfRouter.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
