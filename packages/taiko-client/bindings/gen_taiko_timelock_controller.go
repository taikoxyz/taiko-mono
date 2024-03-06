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

// TaikoTimelockControllerMetaData contains all meta data concerning the TaikoTimelockController contract.
var TaikoTimelockControllerMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"receive\",\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"CANCELLER_ROLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"DEFAULT_ADMIN_ROLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"EXECUTOR_ROLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"PROPOSER_ROLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"TIMELOCK_ADMIN_ROLE\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"addressManager\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"cancel\",\"inputs\":[{\"name\":\"id\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"execute\",\"inputs\":[{\"name\":\"target\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"payload\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"predecessor\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"salt\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"executeBatch\",\"inputs\":[{\"name\":\"targets\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"values\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"payloads\",\"type\":\"bytes[]\",\"internalType\":\"bytes[]\"},{\"name\":\"predecessor\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"salt\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"getMinDelay\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getRoleAdmin\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getTimestamp\",\"inputs\":[{\"name\":\"id\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"timestamp\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"grantRole\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"hasRole\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"hashOperation\",\"inputs\":[{\"name\":\"target\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"predecessor\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"salt\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"hash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashOperationBatch\",\"inputs\":[{\"name\":\"targets\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"values\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"payloads\",\"type\":\"bytes[]\",\"internalType\":\"bytes[]\"},{\"name\":\"predecessor\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"salt\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"hash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_minDelay\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isOperation\",\"inputs\":[{\"name\":\"id\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"registered\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isOperationDone\",\"inputs\":[{\"name\":\"id\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"done\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isOperationPending\",\"inputs\":[{\"name\":\"id\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"pending\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isOperationReady\",\"inputs\":[{\"name\":\"id\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"ready\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"onERC1155BatchReceived\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"onERC1155Received\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"onERC721Received\",\"inputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"renounceRole\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolve\",\"inputs\":[{\"name\":\"_chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_allowZeroAddress\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"addresspayable\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"resolve\",\"inputs\":[{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_allowZeroAddress\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"addresspayable\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"revokeRole\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"schedule\",\"inputs\":[{\"name\":\"target\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"predecessor\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"salt\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"delay\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"scheduleBatch\",\"inputs\":[{\"name\":\"targets\",\"type\":\"address[]\",\"internalType\":\"address[]\"},{\"name\":\"values\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"},{\"name\":\"payloads\",\"type\":\"bytes[]\",\"internalType\":\"bytes[]\"},{\"name\":\"predecessor\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"salt\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"delay\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"supportsInterface\",\"inputs\":[{\"name\":\"interfaceId\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"updateDelay\",\"inputs\":[{\"name\":\"newDelay\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"CallExecuted\",\"inputs\":[{\"name\":\"id\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"index\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"target\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"data\",\"type\":\"bytes\",\"indexed\":false,\"internalType\":\"bytes\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"CallScheduled\",\"inputs\":[{\"name\":\"id\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"index\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"target\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"data\",\"type\":\"bytes\",\"indexed\":false,\"internalType\":\"bytes\"},{\"name\":\"predecessor\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"delay\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Cancelled\",\"inputs\":[{\"name\":\"id\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"MinDelayChange\",\"inputs\":[{\"name\":\"oldDuration\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"newDuration\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RoleAdminChanged\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"previousAdminRole\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"newAdminRole\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RoleGranted\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"sender\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"RoleRevoked\",\"inputs\":[{\"name\":\"role\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"sender\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_INVALID_MANAGER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_UNEXPECTED_CHAINID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_ZERO_ADDR\",\"inputs\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"type\":\"error\",\"name\":\"ZERO_ADDR_MANAGER\",\"inputs\":[]}]",
}

// TaikoTimelockControllerABI is the input ABI used to generate the binding from.
// Deprecated: Use TaikoTimelockControllerMetaData.ABI instead.
var TaikoTimelockControllerABI = TaikoTimelockControllerMetaData.ABI

// TaikoTimelockController is an auto generated Go binding around an Ethereum contract.
type TaikoTimelockController struct {
	TaikoTimelockControllerCaller     // Read-only binding to the contract
	TaikoTimelockControllerTransactor // Write-only binding to the contract
	TaikoTimelockControllerFilterer   // Log filterer for contract events
}

// TaikoTimelockControllerCaller is an auto generated read-only Go binding around an Ethereum contract.
type TaikoTimelockControllerCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoTimelockControllerTransactor is an auto generated write-only Go binding around an Ethereum contract.
type TaikoTimelockControllerTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoTimelockControllerFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type TaikoTimelockControllerFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoTimelockControllerSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type TaikoTimelockControllerSession struct {
	Contract     *TaikoTimelockController // Generic contract binding to set the session for
	CallOpts     bind.CallOpts            // Call options to use throughout this session
	TransactOpts bind.TransactOpts        // Transaction auth options to use throughout this session
}

// TaikoTimelockControllerCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type TaikoTimelockControllerCallerSession struct {
	Contract *TaikoTimelockControllerCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts                  // Call options to use throughout this session
}

// TaikoTimelockControllerTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type TaikoTimelockControllerTransactorSession struct {
	Contract     *TaikoTimelockControllerTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts                  // Transaction auth options to use throughout this session
}

// TaikoTimelockControllerRaw is an auto generated low-level Go binding around an Ethereum contract.
type TaikoTimelockControllerRaw struct {
	Contract *TaikoTimelockController // Generic contract binding to access the raw methods on
}

// TaikoTimelockControllerCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type TaikoTimelockControllerCallerRaw struct {
	Contract *TaikoTimelockControllerCaller // Generic read-only contract binding to access the raw methods on
}

// TaikoTimelockControllerTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type TaikoTimelockControllerTransactorRaw struct {
	Contract *TaikoTimelockControllerTransactor // Generic write-only contract binding to access the raw methods on
}

// NewTaikoTimelockController creates a new instance of TaikoTimelockController, bound to a specific deployed contract.
func NewTaikoTimelockController(address common.Address, backend bind.ContractBackend) (*TaikoTimelockController, error) {
	contract, err := bindTaikoTimelockController(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &TaikoTimelockController{TaikoTimelockControllerCaller: TaikoTimelockControllerCaller{contract: contract}, TaikoTimelockControllerTransactor: TaikoTimelockControllerTransactor{contract: contract}, TaikoTimelockControllerFilterer: TaikoTimelockControllerFilterer{contract: contract}}, nil
}

// NewTaikoTimelockControllerCaller creates a new read-only instance of TaikoTimelockController, bound to a specific deployed contract.
func NewTaikoTimelockControllerCaller(address common.Address, caller bind.ContractCaller) (*TaikoTimelockControllerCaller, error) {
	contract, err := bindTaikoTimelockController(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &TaikoTimelockControllerCaller{contract: contract}, nil
}

// NewTaikoTimelockControllerTransactor creates a new write-only instance of TaikoTimelockController, bound to a specific deployed contract.
func NewTaikoTimelockControllerTransactor(address common.Address, transactor bind.ContractTransactor) (*TaikoTimelockControllerTransactor, error) {
	contract, err := bindTaikoTimelockController(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &TaikoTimelockControllerTransactor{contract: contract}, nil
}

// NewTaikoTimelockControllerFilterer creates a new log filterer instance of TaikoTimelockController, bound to a specific deployed contract.
func NewTaikoTimelockControllerFilterer(address common.Address, filterer bind.ContractFilterer) (*TaikoTimelockControllerFilterer, error) {
	contract, err := bindTaikoTimelockController(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &TaikoTimelockControllerFilterer{contract: contract}, nil
}

// bindTaikoTimelockController binds a generic wrapper to an already deployed contract.
func bindTaikoTimelockController(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := TaikoTimelockControllerMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TaikoTimelockController *TaikoTimelockControllerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TaikoTimelockController.Contract.TaikoTimelockControllerCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TaikoTimelockController *TaikoTimelockControllerRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.TaikoTimelockControllerTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TaikoTimelockController *TaikoTimelockControllerRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.TaikoTimelockControllerTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TaikoTimelockController *TaikoTimelockControllerCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TaikoTimelockController.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TaikoTimelockController *TaikoTimelockControllerTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TaikoTimelockController *TaikoTimelockControllerTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.contract.Transact(opts, method, params...)
}

// CANCELLERROLE is a free data retrieval call binding the contract method 0xb08e51c0.
//
// Solidity: function CANCELLER_ROLE() view returns(bytes32)
func (_TaikoTimelockController *TaikoTimelockControllerCaller) CANCELLERROLE(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _TaikoTimelockController.contract.Call(opts, &out, "CANCELLER_ROLE")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// CANCELLERROLE is a free data retrieval call binding the contract method 0xb08e51c0.
//
// Solidity: function CANCELLER_ROLE() view returns(bytes32)
func (_TaikoTimelockController *TaikoTimelockControllerSession) CANCELLERROLE() ([32]byte, error) {
	return _TaikoTimelockController.Contract.CANCELLERROLE(&_TaikoTimelockController.CallOpts)
}

// CANCELLERROLE is a free data retrieval call binding the contract method 0xb08e51c0.
//
// Solidity: function CANCELLER_ROLE() view returns(bytes32)
func (_TaikoTimelockController *TaikoTimelockControllerCallerSession) CANCELLERROLE() ([32]byte, error) {
	return _TaikoTimelockController.Contract.CANCELLERROLE(&_TaikoTimelockController.CallOpts)
}

// DEFAULTADMINROLE is a free data retrieval call binding the contract method 0xa217fddf.
//
// Solidity: function DEFAULT_ADMIN_ROLE() view returns(bytes32)
func (_TaikoTimelockController *TaikoTimelockControllerCaller) DEFAULTADMINROLE(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _TaikoTimelockController.contract.Call(opts, &out, "DEFAULT_ADMIN_ROLE")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// DEFAULTADMINROLE is a free data retrieval call binding the contract method 0xa217fddf.
//
// Solidity: function DEFAULT_ADMIN_ROLE() view returns(bytes32)
func (_TaikoTimelockController *TaikoTimelockControllerSession) DEFAULTADMINROLE() ([32]byte, error) {
	return _TaikoTimelockController.Contract.DEFAULTADMINROLE(&_TaikoTimelockController.CallOpts)
}

// DEFAULTADMINROLE is a free data retrieval call binding the contract method 0xa217fddf.
//
// Solidity: function DEFAULT_ADMIN_ROLE() view returns(bytes32)
func (_TaikoTimelockController *TaikoTimelockControllerCallerSession) DEFAULTADMINROLE() ([32]byte, error) {
	return _TaikoTimelockController.Contract.DEFAULTADMINROLE(&_TaikoTimelockController.CallOpts)
}

// EXECUTORROLE is a free data retrieval call binding the contract method 0x07bd0265.
//
// Solidity: function EXECUTOR_ROLE() view returns(bytes32)
func (_TaikoTimelockController *TaikoTimelockControllerCaller) EXECUTORROLE(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _TaikoTimelockController.contract.Call(opts, &out, "EXECUTOR_ROLE")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// EXECUTORROLE is a free data retrieval call binding the contract method 0x07bd0265.
//
// Solidity: function EXECUTOR_ROLE() view returns(bytes32)
func (_TaikoTimelockController *TaikoTimelockControllerSession) EXECUTORROLE() ([32]byte, error) {
	return _TaikoTimelockController.Contract.EXECUTORROLE(&_TaikoTimelockController.CallOpts)
}

// EXECUTORROLE is a free data retrieval call binding the contract method 0x07bd0265.
//
// Solidity: function EXECUTOR_ROLE() view returns(bytes32)
func (_TaikoTimelockController *TaikoTimelockControllerCallerSession) EXECUTORROLE() ([32]byte, error) {
	return _TaikoTimelockController.Contract.EXECUTORROLE(&_TaikoTimelockController.CallOpts)
}

// PROPOSERROLE is a free data retrieval call binding the contract method 0x8f61f4f5.
//
// Solidity: function PROPOSER_ROLE() view returns(bytes32)
func (_TaikoTimelockController *TaikoTimelockControllerCaller) PROPOSERROLE(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _TaikoTimelockController.contract.Call(opts, &out, "PROPOSER_ROLE")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// PROPOSERROLE is a free data retrieval call binding the contract method 0x8f61f4f5.
//
// Solidity: function PROPOSER_ROLE() view returns(bytes32)
func (_TaikoTimelockController *TaikoTimelockControllerSession) PROPOSERROLE() ([32]byte, error) {
	return _TaikoTimelockController.Contract.PROPOSERROLE(&_TaikoTimelockController.CallOpts)
}

// PROPOSERROLE is a free data retrieval call binding the contract method 0x8f61f4f5.
//
// Solidity: function PROPOSER_ROLE() view returns(bytes32)
func (_TaikoTimelockController *TaikoTimelockControllerCallerSession) PROPOSERROLE() ([32]byte, error) {
	return _TaikoTimelockController.Contract.PROPOSERROLE(&_TaikoTimelockController.CallOpts)
}

// TIMELOCKADMINROLE is a free data retrieval call binding the contract method 0x0d3cf6fc.
//
// Solidity: function TIMELOCK_ADMIN_ROLE() view returns(bytes32)
func (_TaikoTimelockController *TaikoTimelockControllerCaller) TIMELOCKADMINROLE(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _TaikoTimelockController.contract.Call(opts, &out, "TIMELOCK_ADMIN_ROLE")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// TIMELOCKADMINROLE is a free data retrieval call binding the contract method 0x0d3cf6fc.
//
// Solidity: function TIMELOCK_ADMIN_ROLE() view returns(bytes32)
func (_TaikoTimelockController *TaikoTimelockControllerSession) TIMELOCKADMINROLE() ([32]byte, error) {
	return _TaikoTimelockController.Contract.TIMELOCKADMINROLE(&_TaikoTimelockController.CallOpts)
}

// TIMELOCKADMINROLE is a free data retrieval call binding the contract method 0x0d3cf6fc.
//
// Solidity: function TIMELOCK_ADMIN_ROLE() view returns(bytes32)
func (_TaikoTimelockController *TaikoTimelockControllerCallerSession) TIMELOCKADMINROLE() ([32]byte, error) {
	return _TaikoTimelockController.Contract.TIMELOCKADMINROLE(&_TaikoTimelockController.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_TaikoTimelockController *TaikoTimelockControllerCaller) AddressManager(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoTimelockController.contract.Call(opts, &out, "addressManager")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_TaikoTimelockController *TaikoTimelockControllerSession) AddressManager() (common.Address, error) {
	return _TaikoTimelockController.Contract.AddressManager(&_TaikoTimelockController.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_TaikoTimelockController *TaikoTimelockControllerCallerSession) AddressManager() (common.Address, error) {
	return _TaikoTimelockController.Contract.AddressManager(&_TaikoTimelockController.CallOpts)
}

// GetMinDelay is a free data retrieval call binding the contract method 0xf27a0c92.
//
// Solidity: function getMinDelay() view returns(uint256)
func (_TaikoTimelockController *TaikoTimelockControllerCaller) GetMinDelay(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _TaikoTimelockController.contract.Call(opts, &out, "getMinDelay")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetMinDelay is a free data retrieval call binding the contract method 0xf27a0c92.
//
// Solidity: function getMinDelay() view returns(uint256)
func (_TaikoTimelockController *TaikoTimelockControllerSession) GetMinDelay() (*big.Int, error) {
	return _TaikoTimelockController.Contract.GetMinDelay(&_TaikoTimelockController.CallOpts)
}

// GetMinDelay is a free data retrieval call binding the contract method 0xf27a0c92.
//
// Solidity: function getMinDelay() view returns(uint256)
func (_TaikoTimelockController *TaikoTimelockControllerCallerSession) GetMinDelay() (*big.Int, error) {
	return _TaikoTimelockController.Contract.GetMinDelay(&_TaikoTimelockController.CallOpts)
}

// GetRoleAdmin is a free data retrieval call binding the contract method 0x248a9ca3.
//
// Solidity: function getRoleAdmin(bytes32 role) view returns(bytes32)
func (_TaikoTimelockController *TaikoTimelockControllerCaller) GetRoleAdmin(opts *bind.CallOpts, role [32]byte) ([32]byte, error) {
	var out []interface{}
	err := _TaikoTimelockController.contract.Call(opts, &out, "getRoleAdmin", role)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetRoleAdmin is a free data retrieval call binding the contract method 0x248a9ca3.
//
// Solidity: function getRoleAdmin(bytes32 role) view returns(bytes32)
func (_TaikoTimelockController *TaikoTimelockControllerSession) GetRoleAdmin(role [32]byte) ([32]byte, error) {
	return _TaikoTimelockController.Contract.GetRoleAdmin(&_TaikoTimelockController.CallOpts, role)
}

// GetRoleAdmin is a free data retrieval call binding the contract method 0x248a9ca3.
//
// Solidity: function getRoleAdmin(bytes32 role) view returns(bytes32)
func (_TaikoTimelockController *TaikoTimelockControllerCallerSession) GetRoleAdmin(role [32]byte) ([32]byte, error) {
	return _TaikoTimelockController.Contract.GetRoleAdmin(&_TaikoTimelockController.CallOpts, role)
}

// GetTimestamp is a free data retrieval call binding the contract method 0xd45c4435.
//
// Solidity: function getTimestamp(bytes32 id) view returns(uint256 timestamp)
func (_TaikoTimelockController *TaikoTimelockControllerCaller) GetTimestamp(opts *bind.CallOpts, id [32]byte) (*big.Int, error) {
	var out []interface{}
	err := _TaikoTimelockController.contract.Call(opts, &out, "getTimestamp", id)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTimestamp is a free data retrieval call binding the contract method 0xd45c4435.
//
// Solidity: function getTimestamp(bytes32 id) view returns(uint256 timestamp)
func (_TaikoTimelockController *TaikoTimelockControllerSession) GetTimestamp(id [32]byte) (*big.Int, error) {
	return _TaikoTimelockController.Contract.GetTimestamp(&_TaikoTimelockController.CallOpts, id)
}

// GetTimestamp is a free data retrieval call binding the contract method 0xd45c4435.
//
// Solidity: function getTimestamp(bytes32 id) view returns(uint256 timestamp)
func (_TaikoTimelockController *TaikoTimelockControllerCallerSession) GetTimestamp(id [32]byte) (*big.Int, error) {
	return _TaikoTimelockController.Contract.GetTimestamp(&_TaikoTimelockController.CallOpts, id)
}

// HasRole is a free data retrieval call binding the contract method 0x91d14854.
//
// Solidity: function hasRole(bytes32 role, address account) view returns(bool)
func (_TaikoTimelockController *TaikoTimelockControllerCaller) HasRole(opts *bind.CallOpts, role [32]byte, account common.Address) (bool, error) {
	var out []interface{}
	err := _TaikoTimelockController.contract.Call(opts, &out, "hasRole", role, account)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// HasRole is a free data retrieval call binding the contract method 0x91d14854.
//
// Solidity: function hasRole(bytes32 role, address account) view returns(bool)
func (_TaikoTimelockController *TaikoTimelockControllerSession) HasRole(role [32]byte, account common.Address) (bool, error) {
	return _TaikoTimelockController.Contract.HasRole(&_TaikoTimelockController.CallOpts, role, account)
}

// HasRole is a free data retrieval call binding the contract method 0x91d14854.
//
// Solidity: function hasRole(bytes32 role, address account) view returns(bool)
func (_TaikoTimelockController *TaikoTimelockControllerCallerSession) HasRole(role [32]byte, account common.Address) (bool, error) {
	return _TaikoTimelockController.Contract.HasRole(&_TaikoTimelockController.CallOpts, role, account)
}

// HashOperation is a free data retrieval call binding the contract method 0x8065657f.
//
// Solidity: function hashOperation(address target, uint256 value, bytes data, bytes32 predecessor, bytes32 salt) pure returns(bytes32 hash)
func (_TaikoTimelockController *TaikoTimelockControllerCaller) HashOperation(opts *bind.CallOpts, target common.Address, value *big.Int, data []byte, predecessor [32]byte, salt [32]byte) ([32]byte, error) {
	var out []interface{}
	err := _TaikoTimelockController.contract.Call(opts, &out, "hashOperation", target, value, data, predecessor, salt)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashOperation is a free data retrieval call binding the contract method 0x8065657f.
//
// Solidity: function hashOperation(address target, uint256 value, bytes data, bytes32 predecessor, bytes32 salt) pure returns(bytes32 hash)
func (_TaikoTimelockController *TaikoTimelockControllerSession) HashOperation(target common.Address, value *big.Int, data []byte, predecessor [32]byte, salt [32]byte) ([32]byte, error) {
	return _TaikoTimelockController.Contract.HashOperation(&_TaikoTimelockController.CallOpts, target, value, data, predecessor, salt)
}

// HashOperation is a free data retrieval call binding the contract method 0x8065657f.
//
// Solidity: function hashOperation(address target, uint256 value, bytes data, bytes32 predecessor, bytes32 salt) pure returns(bytes32 hash)
func (_TaikoTimelockController *TaikoTimelockControllerCallerSession) HashOperation(target common.Address, value *big.Int, data []byte, predecessor [32]byte, salt [32]byte) ([32]byte, error) {
	return _TaikoTimelockController.Contract.HashOperation(&_TaikoTimelockController.CallOpts, target, value, data, predecessor, salt)
}

// HashOperationBatch is a free data retrieval call binding the contract method 0xb1c5f427.
//
// Solidity: function hashOperationBatch(address[] targets, uint256[] values, bytes[] payloads, bytes32 predecessor, bytes32 salt) pure returns(bytes32 hash)
func (_TaikoTimelockController *TaikoTimelockControllerCaller) HashOperationBatch(opts *bind.CallOpts, targets []common.Address, values []*big.Int, payloads [][]byte, predecessor [32]byte, salt [32]byte) ([32]byte, error) {
	var out []interface{}
	err := _TaikoTimelockController.contract.Call(opts, &out, "hashOperationBatch", targets, values, payloads, predecessor, salt)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashOperationBatch is a free data retrieval call binding the contract method 0xb1c5f427.
//
// Solidity: function hashOperationBatch(address[] targets, uint256[] values, bytes[] payloads, bytes32 predecessor, bytes32 salt) pure returns(bytes32 hash)
func (_TaikoTimelockController *TaikoTimelockControllerSession) HashOperationBatch(targets []common.Address, values []*big.Int, payloads [][]byte, predecessor [32]byte, salt [32]byte) ([32]byte, error) {
	return _TaikoTimelockController.Contract.HashOperationBatch(&_TaikoTimelockController.CallOpts, targets, values, payloads, predecessor, salt)
}

// HashOperationBatch is a free data retrieval call binding the contract method 0xb1c5f427.
//
// Solidity: function hashOperationBatch(address[] targets, uint256[] values, bytes[] payloads, bytes32 predecessor, bytes32 salt) pure returns(bytes32 hash)
func (_TaikoTimelockController *TaikoTimelockControllerCallerSession) HashOperationBatch(targets []common.Address, values []*big.Int, payloads [][]byte, predecessor [32]byte, salt [32]byte) ([32]byte, error) {
	return _TaikoTimelockController.Contract.HashOperationBatch(&_TaikoTimelockController.CallOpts, targets, values, payloads, predecessor, salt)
}

// IsOperation is a free data retrieval call binding the contract method 0x31d50750.
//
// Solidity: function isOperation(bytes32 id) view returns(bool registered)
func (_TaikoTimelockController *TaikoTimelockControllerCaller) IsOperation(opts *bind.CallOpts, id [32]byte) (bool, error) {
	var out []interface{}
	err := _TaikoTimelockController.contract.Call(opts, &out, "isOperation", id)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsOperation is a free data retrieval call binding the contract method 0x31d50750.
//
// Solidity: function isOperation(bytes32 id) view returns(bool registered)
func (_TaikoTimelockController *TaikoTimelockControllerSession) IsOperation(id [32]byte) (bool, error) {
	return _TaikoTimelockController.Contract.IsOperation(&_TaikoTimelockController.CallOpts, id)
}

// IsOperation is a free data retrieval call binding the contract method 0x31d50750.
//
// Solidity: function isOperation(bytes32 id) view returns(bool registered)
func (_TaikoTimelockController *TaikoTimelockControllerCallerSession) IsOperation(id [32]byte) (bool, error) {
	return _TaikoTimelockController.Contract.IsOperation(&_TaikoTimelockController.CallOpts, id)
}

// IsOperationDone is a free data retrieval call binding the contract method 0x2ab0f529.
//
// Solidity: function isOperationDone(bytes32 id) view returns(bool done)
func (_TaikoTimelockController *TaikoTimelockControllerCaller) IsOperationDone(opts *bind.CallOpts, id [32]byte) (bool, error) {
	var out []interface{}
	err := _TaikoTimelockController.contract.Call(opts, &out, "isOperationDone", id)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsOperationDone is a free data retrieval call binding the contract method 0x2ab0f529.
//
// Solidity: function isOperationDone(bytes32 id) view returns(bool done)
func (_TaikoTimelockController *TaikoTimelockControllerSession) IsOperationDone(id [32]byte) (bool, error) {
	return _TaikoTimelockController.Contract.IsOperationDone(&_TaikoTimelockController.CallOpts, id)
}

// IsOperationDone is a free data retrieval call binding the contract method 0x2ab0f529.
//
// Solidity: function isOperationDone(bytes32 id) view returns(bool done)
func (_TaikoTimelockController *TaikoTimelockControllerCallerSession) IsOperationDone(id [32]byte) (bool, error) {
	return _TaikoTimelockController.Contract.IsOperationDone(&_TaikoTimelockController.CallOpts, id)
}

// IsOperationPending is a free data retrieval call binding the contract method 0x584b153e.
//
// Solidity: function isOperationPending(bytes32 id) view returns(bool pending)
func (_TaikoTimelockController *TaikoTimelockControllerCaller) IsOperationPending(opts *bind.CallOpts, id [32]byte) (bool, error) {
	var out []interface{}
	err := _TaikoTimelockController.contract.Call(opts, &out, "isOperationPending", id)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsOperationPending is a free data retrieval call binding the contract method 0x584b153e.
//
// Solidity: function isOperationPending(bytes32 id) view returns(bool pending)
func (_TaikoTimelockController *TaikoTimelockControllerSession) IsOperationPending(id [32]byte) (bool, error) {
	return _TaikoTimelockController.Contract.IsOperationPending(&_TaikoTimelockController.CallOpts, id)
}

// IsOperationPending is a free data retrieval call binding the contract method 0x584b153e.
//
// Solidity: function isOperationPending(bytes32 id) view returns(bool pending)
func (_TaikoTimelockController *TaikoTimelockControllerCallerSession) IsOperationPending(id [32]byte) (bool, error) {
	return _TaikoTimelockController.Contract.IsOperationPending(&_TaikoTimelockController.CallOpts, id)
}

// IsOperationReady is a free data retrieval call binding the contract method 0x13bc9f20.
//
// Solidity: function isOperationReady(bytes32 id) view returns(bool ready)
func (_TaikoTimelockController *TaikoTimelockControllerCaller) IsOperationReady(opts *bind.CallOpts, id [32]byte) (bool, error) {
	var out []interface{}
	err := _TaikoTimelockController.contract.Call(opts, &out, "isOperationReady", id)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsOperationReady is a free data retrieval call binding the contract method 0x13bc9f20.
//
// Solidity: function isOperationReady(bytes32 id) view returns(bool ready)
func (_TaikoTimelockController *TaikoTimelockControllerSession) IsOperationReady(id [32]byte) (bool, error) {
	return _TaikoTimelockController.Contract.IsOperationReady(&_TaikoTimelockController.CallOpts, id)
}

// IsOperationReady is a free data retrieval call binding the contract method 0x13bc9f20.
//
// Solidity: function isOperationReady(bytes32 id) view returns(bool ready)
func (_TaikoTimelockController *TaikoTimelockControllerCallerSession) IsOperationReady(id [32]byte) (bool, error) {
	return _TaikoTimelockController.Contract.IsOperationReady(&_TaikoTimelockController.CallOpts, id)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoTimelockController *TaikoTimelockControllerCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoTimelockController.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoTimelockController *TaikoTimelockControllerSession) Owner() (common.Address, error) {
	return _TaikoTimelockController.Contract.Owner(&_TaikoTimelockController.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoTimelockController *TaikoTimelockControllerCallerSession) Owner() (common.Address, error) {
	return _TaikoTimelockController.Contract.Owner(&_TaikoTimelockController.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_TaikoTimelockController *TaikoTimelockControllerCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _TaikoTimelockController.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_TaikoTimelockController *TaikoTimelockControllerSession) Paused() (bool, error) {
	return _TaikoTimelockController.Contract.Paused(&_TaikoTimelockController.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_TaikoTimelockController *TaikoTimelockControllerCallerSession) Paused() (bool, error) {
	return _TaikoTimelockController.Contract.Paused(&_TaikoTimelockController.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_TaikoTimelockController *TaikoTimelockControllerCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoTimelockController.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_TaikoTimelockController *TaikoTimelockControllerSession) PendingOwner() (common.Address, error) {
	return _TaikoTimelockController.Contract.PendingOwner(&_TaikoTimelockController.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_TaikoTimelockController *TaikoTimelockControllerCallerSession) PendingOwner() (common.Address, error) {
	return _TaikoTimelockController.Contract.PendingOwner(&_TaikoTimelockController.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_TaikoTimelockController *TaikoTimelockControllerCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _TaikoTimelockController.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_TaikoTimelockController *TaikoTimelockControllerSession) ProxiableUUID() ([32]byte, error) {
	return _TaikoTimelockController.Contract.ProxiableUUID(&_TaikoTimelockController.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_TaikoTimelockController *TaikoTimelockControllerCallerSession) ProxiableUUID() ([32]byte, error) {
	return _TaikoTimelockController.Contract.ProxiableUUID(&_TaikoTimelockController.CallOpts)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_TaikoTimelockController *TaikoTimelockControllerCaller) Resolve(opts *bind.CallOpts, _chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _TaikoTimelockController.contract.Call(opts, &out, "resolve", _chainId, _name, _allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_TaikoTimelockController *TaikoTimelockControllerSession) Resolve(_chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _TaikoTimelockController.Contract.Resolve(&_TaikoTimelockController.CallOpts, _chainId, _name, _allowZeroAddress)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_TaikoTimelockController *TaikoTimelockControllerCallerSession) Resolve(_chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _TaikoTimelockController.Contract.Resolve(&_TaikoTimelockController.CallOpts, _chainId, _name, _allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_TaikoTimelockController *TaikoTimelockControllerCaller) Resolve0(opts *bind.CallOpts, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _TaikoTimelockController.contract.Call(opts, &out, "resolve0", _name, _allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_TaikoTimelockController *TaikoTimelockControllerSession) Resolve0(_name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _TaikoTimelockController.Contract.Resolve0(&_TaikoTimelockController.CallOpts, _name, _allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_TaikoTimelockController *TaikoTimelockControllerCallerSession) Resolve0(_name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _TaikoTimelockController.Contract.Resolve0(&_TaikoTimelockController.CallOpts, _name, _allowZeroAddress)
}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 interfaceId) view returns(bool)
func (_TaikoTimelockController *TaikoTimelockControllerCaller) SupportsInterface(opts *bind.CallOpts, interfaceId [4]byte) (bool, error) {
	var out []interface{}
	err := _TaikoTimelockController.contract.Call(opts, &out, "supportsInterface", interfaceId)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 interfaceId) view returns(bool)
func (_TaikoTimelockController *TaikoTimelockControllerSession) SupportsInterface(interfaceId [4]byte) (bool, error) {
	return _TaikoTimelockController.Contract.SupportsInterface(&_TaikoTimelockController.CallOpts, interfaceId)
}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 interfaceId) view returns(bool)
func (_TaikoTimelockController *TaikoTimelockControllerCallerSession) SupportsInterface(interfaceId [4]byte) (bool, error) {
	return _TaikoTimelockController.Contract.SupportsInterface(&_TaikoTimelockController.CallOpts, interfaceId)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoTimelockController.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_TaikoTimelockController *TaikoTimelockControllerSession) AcceptOwnership() (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.AcceptOwnership(&_TaikoTimelockController.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.AcceptOwnership(&_TaikoTimelockController.TransactOpts)
}

// Cancel is a paid mutator transaction binding the contract method 0xc4d252f5.
//
// Solidity: function cancel(bytes32 id) returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactor) Cancel(opts *bind.TransactOpts, id [32]byte) (*types.Transaction, error) {
	return _TaikoTimelockController.contract.Transact(opts, "cancel", id)
}

// Cancel is a paid mutator transaction binding the contract method 0xc4d252f5.
//
// Solidity: function cancel(bytes32 id) returns()
func (_TaikoTimelockController *TaikoTimelockControllerSession) Cancel(id [32]byte) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.Cancel(&_TaikoTimelockController.TransactOpts, id)
}

// Cancel is a paid mutator transaction binding the contract method 0xc4d252f5.
//
// Solidity: function cancel(bytes32 id) returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactorSession) Cancel(id [32]byte) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.Cancel(&_TaikoTimelockController.TransactOpts, id)
}

// Execute is a paid mutator transaction binding the contract method 0x134008d3.
//
// Solidity: function execute(address target, uint256 value, bytes payload, bytes32 predecessor, bytes32 salt) payable returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactor) Execute(opts *bind.TransactOpts, target common.Address, value *big.Int, payload []byte, predecessor [32]byte, salt [32]byte) (*types.Transaction, error) {
	return _TaikoTimelockController.contract.Transact(opts, "execute", target, value, payload, predecessor, salt)
}

// Execute is a paid mutator transaction binding the contract method 0x134008d3.
//
// Solidity: function execute(address target, uint256 value, bytes payload, bytes32 predecessor, bytes32 salt) payable returns()
func (_TaikoTimelockController *TaikoTimelockControllerSession) Execute(target common.Address, value *big.Int, payload []byte, predecessor [32]byte, salt [32]byte) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.Execute(&_TaikoTimelockController.TransactOpts, target, value, payload, predecessor, salt)
}

// Execute is a paid mutator transaction binding the contract method 0x134008d3.
//
// Solidity: function execute(address target, uint256 value, bytes payload, bytes32 predecessor, bytes32 salt) payable returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactorSession) Execute(target common.Address, value *big.Int, payload []byte, predecessor [32]byte, salt [32]byte) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.Execute(&_TaikoTimelockController.TransactOpts, target, value, payload, predecessor, salt)
}

// ExecuteBatch is a paid mutator transaction binding the contract method 0xe38335e5.
//
// Solidity: function executeBatch(address[] targets, uint256[] values, bytes[] payloads, bytes32 predecessor, bytes32 salt) payable returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactor) ExecuteBatch(opts *bind.TransactOpts, targets []common.Address, values []*big.Int, payloads [][]byte, predecessor [32]byte, salt [32]byte) (*types.Transaction, error) {
	return _TaikoTimelockController.contract.Transact(opts, "executeBatch", targets, values, payloads, predecessor, salt)
}

// ExecuteBatch is a paid mutator transaction binding the contract method 0xe38335e5.
//
// Solidity: function executeBatch(address[] targets, uint256[] values, bytes[] payloads, bytes32 predecessor, bytes32 salt) payable returns()
func (_TaikoTimelockController *TaikoTimelockControllerSession) ExecuteBatch(targets []common.Address, values []*big.Int, payloads [][]byte, predecessor [32]byte, salt [32]byte) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.ExecuteBatch(&_TaikoTimelockController.TransactOpts, targets, values, payloads, predecessor, salt)
}

// ExecuteBatch is a paid mutator transaction binding the contract method 0xe38335e5.
//
// Solidity: function executeBatch(address[] targets, uint256[] values, bytes[] payloads, bytes32 predecessor, bytes32 salt) payable returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactorSession) ExecuteBatch(targets []common.Address, values []*big.Int, payloads [][]byte, predecessor [32]byte, salt [32]byte) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.ExecuteBatch(&_TaikoTimelockController.TransactOpts, targets, values, payloads, predecessor, salt)
}

// GrantRole is a paid mutator transaction binding the contract method 0x2f2ff15d.
//
// Solidity: function grantRole(bytes32 role, address account) returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactor) GrantRole(opts *bind.TransactOpts, role [32]byte, account common.Address) (*types.Transaction, error) {
	return _TaikoTimelockController.contract.Transact(opts, "grantRole", role, account)
}

// GrantRole is a paid mutator transaction binding the contract method 0x2f2ff15d.
//
// Solidity: function grantRole(bytes32 role, address account) returns()
func (_TaikoTimelockController *TaikoTimelockControllerSession) GrantRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.GrantRole(&_TaikoTimelockController.TransactOpts, role, account)
}

// GrantRole is a paid mutator transaction binding the contract method 0x2f2ff15d.
//
// Solidity: function grantRole(bytes32 role, address account) returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactorSession) GrantRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.GrantRole(&_TaikoTimelockController.TransactOpts, role, account)
}

// Init is a paid mutator transaction binding the contract method 0x399ae724.
//
// Solidity: function init(address _owner, uint256 _minDelay) returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactor) Init(opts *bind.TransactOpts, _owner common.Address, _minDelay *big.Int) (*types.Transaction, error) {
	return _TaikoTimelockController.contract.Transact(opts, "init", _owner, _minDelay)
}

// Init is a paid mutator transaction binding the contract method 0x399ae724.
//
// Solidity: function init(address _owner, uint256 _minDelay) returns()
func (_TaikoTimelockController *TaikoTimelockControllerSession) Init(_owner common.Address, _minDelay *big.Int) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.Init(&_TaikoTimelockController.TransactOpts, _owner, _minDelay)
}

// Init is a paid mutator transaction binding the contract method 0x399ae724.
//
// Solidity: function init(address _owner, uint256 _minDelay) returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactorSession) Init(_owner common.Address, _minDelay *big.Int) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.Init(&_TaikoTimelockController.TransactOpts, _owner, _minDelay)
}

// OnERC1155BatchReceived is a paid mutator transaction binding the contract method 0xbc197c81.
//
// Solidity: function onERC1155BatchReceived(address , address , uint256[] , uint256[] , bytes ) returns(bytes4)
func (_TaikoTimelockController *TaikoTimelockControllerTransactor) OnERC1155BatchReceived(opts *bind.TransactOpts, arg0 common.Address, arg1 common.Address, arg2 []*big.Int, arg3 []*big.Int, arg4 []byte) (*types.Transaction, error) {
	return _TaikoTimelockController.contract.Transact(opts, "onERC1155BatchReceived", arg0, arg1, arg2, arg3, arg4)
}

// OnERC1155BatchReceived is a paid mutator transaction binding the contract method 0xbc197c81.
//
// Solidity: function onERC1155BatchReceived(address , address , uint256[] , uint256[] , bytes ) returns(bytes4)
func (_TaikoTimelockController *TaikoTimelockControllerSession) OnERC1155BatchReceived(arg0 common.Address, arg1 common.Address, arg2 []*big.Int, arg3 []*big.Int, arg4 []byte) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.OnERC1155BatchReceived(&_TaikoTimelockController.TransactOpts, arg0, arg1, arg2, arg3, arg4)
}

// OnERC1155BatchReceived is a paid mutator transaction binding the contract method 0xbc197c81.
//
// Solidity: function onERC1155BatchReceived(address , address , uint256[] , uint256[] , bytes ) returns(bytes4)
func (_TaikoTimelockController *TaikoTimelockControllerTransactorSession) OnERC1155BatchReceived(arg0 common.Address, arg1 common.Address, arg2 []*big.Int, arg3 []*big.Int, arg4 []byte) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.OnERC1155BatchReceived(&_TaikoTimelockController.TransactOpts, arg0, arg1, arg2, arg3, arg4)
}

// OnERC1155Received is a paid mutator transaction binding the contract method 0xf23a6e61.
//
// Solidity: function onERC1155Received(address , address , uint256 , uint256 , bytes ) returns(bytes4)
func (_TaikoTimelockController *TaikoTimelockControllerTransactor) OnERC1155Received(opts *bind.TransactOpts, arg0 common.Address, arg1 common.Address, arg2 *big.Int, arg3 *big.Int, arg4 []byte) (*types.Transaction, error) {
	return _TaikoTimelockController.contract.Transact(opts, "onERC1155Received", arg0, arg1, arg2, arg3, arg4)
}

// OnERC1155Received is a paid mutator transaction binding the contract method 0xf23a6e61.
//
// Solidity: function onERC1155Received(address , address , uint256 , uint256 , bytes ) returns(bytes4)
func (_TaikoTimelockController *TaikoTimelockControllerSession) OnERC1155Received(arg0 common.Address, arg1 common.Address, arg2 *big.Int, arg3 *big.Int, arg4 []byte) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.OnERC1155Received(&_TaikoTimelockController.TransactOpts, arg0, arg1, arg2, arg3, arg4)
}

// OnERC1155Received is a paid mutator transaction binding the contract method 0xf23a6e61.
//
// Solidity: function onERC1155Received(address , address , uint256 , uint256 , bytes ) returns(bytes4)
func (_TaikoTimelockController *TaikoTimelockControllerTransactorSession) OnERC1155Received(arg0 common.Address, arg1 common.Address, arg2 *big.Int, arg3 *big.Int, arg4 []byte) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.OnERC1155Received(&_TaikoTimelockController.TransactOpts, arg0, arg1, arg2, arg3, arg4)
}

// OnERC721Received is a paid mutator transaction binding the contract method 0x150b7a02.
//
// Solidity: function onERC721Received(address , address , uint256 , bytes ) returns(bytes4)
func (_TaikoTimelockController *TaikoTimelockControllerTransactor) OnERC721Received(opts *bind.TransactOpts, arg0 common.Address, arg1 common.Address, arg2 *big.Int, arg3 []byte) (*types.Transaction, error) {
	return _TaikoTimelockController.contract.Transact(opts, "onERC721Received", arg0, arg1, arg2, arg3)
}

// OnERC721Received is a paid mutator transaction binding the contract method 0x150b7a02.
//
// Solidity: function onERC721Received(address , address , uint256 , bytes ) returns(bytes4)
func (_TaikoTimelockController *TaikoTimelockControllerSession) OnERC721Received(arg0 common.Address, arg1 common.Address, arg2 *big.Int, arg3 []byte) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.OnERC721Received(&_TaikoTimelockController.TransactOpts, arg0, arg1, arg2, arg3)
}

// OnERC721Received is a paid mutator transaction binding the contract method 0x150b7a02.
//
// Solidity: function onERC721Received(address , address , uint256 , bytes ) returns(bytes4)
func (_TaikoTimelockController *TaikoTimelockControllerTransactorSession) OnERC721Received(arg0 common.Address, arg1 common.Address, arg2 *big.Int, arg3 []byte) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.OnERC721Received(&_TaikoTimelockController.TransactOpts, arg0, arg1, arg2, arg3)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoTimelockController.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_TaikoTimelockController *TaikoTimelockControllerSession) Pause() (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.Pause(&_TaikoTimelockController.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactorSession) Pause() (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.Pause(&_TaikoTimelockController.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoTimelockController.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoTimelockController *TaikoTimelockControllerSession) RenounceOwnership() (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.RenounceOwnership(&_TaikoTimelockController.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.RenounceOwnership(&_TaikoTimelockController.TransactOpts)
}

// RenounceRole is a paid mutator transaction binding the contract method 0x36568abe.
//
// Solidity: function renounceRole(bytes32 role, address account) returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactor) RenounceRole(opts *bind.TransactOpts, role [32]byte, account common.Address) (*types.Transaction, error) {
	return _TaikoTimelockController.contract.Transact(opts, "renounceRole", role, account)
}

// RenounceRole is a paid mutator transaction binding the contract method 0x36568abe.
//
// Solidity: function renounceRole(bytes32 role, address account) returns()
func (_TaikoTimelockController *TaikoTimelockControllerSession) RenounceRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.RenounceRole(&_TaikoTimelockController.TransactOpts, role, account)
}

// RenounceRole is a paid mutator transaction binding the contract method 0x36568abe.
//
// Solidity: function renounceRole(bytes32 role, address account) returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactorSession) RenounceRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.RenounceRole(&_TaikoTimelockController.TransactOpts, role, account)
}

// RevokeRole is a paid mutator transaction binding the contract method 0xd547741f.
//
// Solidity: function revokeRole(bytes32 role, address account) returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactor) RevokeRole(opts *bind.TransactOpts, role [32]byte, account common.Address) (*types.Transaction, error) {
	return _TaikoTimelockController.contract.Transact(opts, "revokeRole", role, account)
}

// RevokeRole is a paid mutator transaction binding the contract method 0xd547741f.
//
// Solidity: function revokeRole(bytes32 role, address account) returns()
func (_TaikoTimelockController *TaikoTimelockControllerSession) RevokeRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.RevokeRole(&_TaikoTimelockController.TransactOpts, role, account)
}

// RevokeRole is a paid mutator transaction binding the contract method 0xd547741f.
//
// Solidity: function revokeRole(bytes32 role, address account) returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactorSession) RevokeRole(role [32]byte, account common.Address) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.RevokeRole(&_TaikoTimelockController.TransactOpts, role, account)
}

// Schedule is a paid mutator transaction binding the contract method 0x01d5062a.
//
// Solidity: function schedule(address target, uint256 value, bytes data, bytes32 predecessor, bytes32 salt, uint256 delay) returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactor) Schedule(opts *bind.TransactOpts, target common.Address, value *big.Int, data []byte, predecessor [32]byte, salt [32]byte, delay *big.Int) (*types.Transaction, error) {
	return _TaikoTimelockController.contract.Transact(opts, "schedule", target, value, data, predecessor, salt, delay)
}

// Schedule is a paid mutator transaction binding the contract method 0x01d5062a.
//
// Solidity: function schedule(address target, uint256 value, bytes data, bytes32 predecessor, bytes32 salt, uint256 delay) returns()
func (_TaikoTimelockController *TaikoTimelockControllerSession) Schedule(target common.Address, value *big.Int, data []byte, predecessor [32]byte, salt [32]byte, delay *big.Int) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.Schedule(&_TaikoTimelockController.TransactOpts, target, value, data, predecessor, salt, delay)
}

// Schedule is a paid mutator transaction binding the contract method 0x01d5062a.
//
// Solidity: function schedule(address target, uint256 value, bytes data, bytes32 predecessor, bytes32 salt, uint256 delay) returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactorSession) Schedule(target common.Address, value *big.Int, data []byte, predecessor [32]byte, salt [32]byte, delay *big.Int) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.Schedule(&_TaikoTimelockController.TransactOpts, target, value, data, predecessor, salt, delay)
}

// ScheduleBatch is a paid mutator transaction binding the contract method 0x8f2a0bb0.
//
// Solidity: function scheduleBatch(address[] targets, uint256[] values, bytes[] payloads, bytes32 predecessor, bytes32 salt, uint256 delay) returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactor) ScheduleBatch(opts *bind.TransactOpts, targets []common.Address, values []*big.Int, payloads [][]byte, predecessor [32]byte, salt [32]byte, delay *big.Int) (*types.Transaction, error) {
	return _TaikoTimelockController.contract.Transact(opts, "scheduleBatch", targets, values, payloads, predecessor, salt, delay)
}

// ScheduleBatch is a paid mutator transaction binding the contract method 0x8f2a0bb0.
//
// Solidity: function scheduleBatch(address[] targets, uint256[] values, bytes[] payloads, bytes32 predecessor, bytes32 salt, uint256 delay) returns()
func (_TaikoTimelockController *TaikoTimelockControllerSession) ScheduleBatch(targets []common.Address, values []*big.Int, payloads [][]byte, predecessor [32]byte, salt [32]byte, delay *big.Int) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.ScheduleBatch(&_TaikoTimelockController.TransactOpts, targets, values, payloads, predecessor, salt, delay)
}

// ScheduleBatch is a paid mutator transaction binding the contract method 0x8f2a0bb0.
//
// Solidity: function scheduleBatch(address[] targets, uint256[] values, bytes[] payloads, bytes32 predecessor, bytes32 salt, uint256 delay) returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactorSession) ScheduleBatch(targets []common.Address, values []*big.Int, payloads [][]byte, predecessor [32]byte, salt [32]byte, delay *big.Int) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.ScheduleBatch(&_TaikoTimelockController.TransactOpts, targets, values, payloads, predecessor, salt, delay)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _TaikoTimelockController.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoTimelockController *TaikoTimelockControllerSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.TransferOwnership(&_TaikoTimelockController.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.TransferOwnership(&_TaikoTimelockController.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoTimelockController.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_TaikoTimelockController *TaikoTimelockControllerSession) Unpause() (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.Unpause(&_TaikoTimelockController.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactorSession) Unpause() (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.Unpause(&_TaikoTimelockController.TransactOpts)
}

// UpdateDelay is a paid mutator transaction binding the contract method 0x64d62353.
//
// Solidity: function updateDelay(uint256 newDelay) returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactor) UpdateDelay(opts *bind.TransactOpts, newDelay *big.Int) (*types.Transaction, error) {
	return _TaikoTimelockController.contract.Transact(opts, "updateDelay", newDelay)
}

// UpdateDelay is a paid mutator transaction binding the contract method 0x64d62353.
//
// Solidity: function updateDelay(uint256 newDelay) returns()
func (_TaikoTimelockController *TaikoTimelockControllerSession) UpdateDelay(newDelay *big.Int) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.UpdateDelay(&_TaikoTimelockController.TransactOpts, newDelay)
}

// UpdateDelay is a paid mutator transaction binding the contract method 0x64d62353.
//
// Solidity: function updateDelay(uint256 newDelay) returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactorSession) UpdateDelay(newDelay *big.Int) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.UpdateDelay(&_TaikoTimelockController.TransactOpts, newDelay)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _TaikoTimelockController.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_TaikoTimelockController *TaikoTimelockControllerSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.UpgradeTo(&_TaikoTimelockController.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.UpgradeTo(&_TaikoTimelockController.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _TaikoTimelockController.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_TaikoTimelockController *TaikoTimelockControllerSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.UpgradeToAndCall(&_TaikoTimelockController.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.UpgradeToAndCall(&_TaikoTimelockController.TransactOpts, newImplementation, data)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactor) Receive(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoTimelockController.contract.RawTransact(opts, nil) // calldata is disallowed for receive function
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_TaikoTimelockController *TaikoTimelockControllerSession) Receive() (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.Receive(&_TaikoTimelockController.TransactOpts)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_TaikoTimelockController *TaikoTimelockControllerTransactorSession) Receive() (*types.Transaction, error) {
	return _TaikoTimelockController.Contract.Receive(&_TaikoTimelockController.TransactOpts)
}

// TaikoTimelockControllerAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the TaikoTimelockController contract.
type TaikoTimelockControllerAdminChangedIterator struct {
	Event *TaikoTimelockControllerAdminChanged // Event containing the contract specifics and raw log

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
func (it *TaikoTimelockControllerAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoTimelockControllerAdminChanged)
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
		it.Event = new(TaikoTimelockControllerAdminChanged)
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
func (it *TaikoTimelockControllerAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoTimelockControllerAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoTimelockControllerAdminChanged represents a AdminChanged event raised by the TaikoTimelockController contract.
type TaikoTimelockControllerAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*TaikoTimelockControllerAdminChangedIterator, error) {

	logs, sub, err := _TaikoTimelockController.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &TaikoTimelockControllerAdminChangedIterator{contract: _TaikoTimelockController.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *TaikoTimelockControllerAdminChanged) (event.Subscription, error) {

	logs, sub, err := _TaikoTimelockController.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoTimelockControllerAdminChanged)
				if err := _TaikoTimelockController.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) ParseAdminChanged(log types.Log) (*TaikoTimelockControllerAdminChanged, error) {
	event := new(TaikoTimelockControllerAdminChanged)
	if err := _TaikoTimelockController.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoTimelockControllerBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the TaikoTimelockController contract.
type TaikoTimelockControllerBeaconUpgradedIterator struct {
	Event *TaikoTimelockControllerBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *TaikoTimelockControllerBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoTimelockControllerBeaconUpgraded)
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
		it.Event = new(TaikoTimelockControllerBeaconUpgraded)
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
func (it *TaikoTimelockControllerBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoTimelockControllerBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoTimelockControllerBeaconUpgraded represents a BeaconUpgraded event raised by the TaikoTimelockController contract.
type TaikoTimelockControllerBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*TaikoTimelockControllerBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _TaikoTimelockController.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &TaikoTimelockControllerBeaconUpgradedIterator{contract: _TaikoTimelockController.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *TaikoTimelockControllerBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _TaikoTimelockController.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoTimelockControllerBeaconUpgraded)
				if err := _TaikoTimelockController.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) ParseBeaconUpgraded(log types.Log) (*TaikoTimelockControllerBeaconUpgraded, error) {
	event := new(TaikoTimelockControllerBeaconUpgraded)
	if err := _TaikoTimelockController.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoTimelockControllerCallExecutedIterator is returned from FilterCallExecuted and is used to iterate over the raw logs and unpacked data for CallExecuted events raised by the TaikoTimelockController contract.
type TaikoTimelockControllerCallExecutedIterator struct {
	Event *TaikoTimelockControllerCallExecuted // Event containing the contract specifics and raw log

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
func (it *TaikoTimelockControllerCallExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoTimelockControllerCallExecuted)
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
		it.Event = new(TaikoTimelockControllerCallExecuted)
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
func (it *TaikoTimelockControllerCallExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoTimelockControllerCallExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoTimelockControllerCallExecuted represents a CallExecuted event raised by the TaikoTimelockController contract.
type TaikoTimelockControllerCallExecuted struct {
	Id     [32]byte
	Index  *big.Int
	Target common.Address
	Value  *big.Int
	Data   []byte
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterCallExecuted is a free log retrieval operation binding the contract event 0xc2617efa69bab66782fa219543714338489c4e9e178271560a91b82c3f612b58.
//
// Solidity: event CallExecuted(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) FilterCallExecuted(opts *bind.FilterOpts, id [][32]byte, index []*big.Int) (*TaikoTimelockControllerCallExecutedIterator, error) {

	var idRule []interface{}
	for _, idItem := range id {
		idRule = append(idRule, idItem)
	}
	var indexRule []interface{}
	for _, indexItem := range index {
		indexRule = append(indexRule, indexItem)
	}

	logs, sub, err := _TaikoTimelockController.contract.FilterLogs(opts, "CallExecuted", idRule, indexRule)
	if err != nil {
		return nil, err
	}
	return &TaikoTimelockControllerCallExecutedIterator{contract: _TaikoTimelockController.contract, event: "CallExecuted", logs: logs, sub: sub}, nil
}

// WatchCallExecuted is a free log subscription operation binding the contract event 0xc2617efa69bab66782fa219543714338489c4e9e178271560a91b82c3f612b58.
//
// Solidity: event CallExecuted(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) WatchCallExecuted(opts *bind.WatchOpts, sink chan<- *TaikoTimelockControllerCallExecuted, id [][32]byte, index []*big.Int) (event.Subscription, error) {

	var idRule []interface{}
	for _, idItem := range id {
		idRule = append(idRule, idItem)
	}
	var indexRule []interface{}
	for _, indexItem := range index {
		indexRule = append(indexRule, indexItem)
	}

	logs, sub, err := _TaikoTimelockController.contract.WatchLogs(opts, "CallExecuted", idRule, indexRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoTimelockControllerCallExecuted)
				if err := _TaikoTimelockController.contract.UnpackLog(event, "CallExecuted", log); err != nil {
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

// ParseCallExecuted is a log parse operation binding the contract event 0xc2617efa69bab66782fa219543714338489c4e9e178271560a91b82c3f612b58.
//
// Solidity: event CallExecuted(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) ParseCallExecuted(log types.Log) (*TaikoTimelockControllerCallExecuted, error) {
	event := new(TaikoTimelockControllerCallExecuted)
	if err := _TaikoTimelockController.contract.UnpackLog(event, "CallExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoTimelockControllerCallScheduledIterator is returned from FilterCallScheduled and is used to iterate over the raw logs and unpacked data for CallScheduled events raised by the TaikoTimelockController contract.
type TaikoTimelockControllerCallScheduledIterator struct {
	Event *TaikoTimelockControllerCallScheduled // Event containing the contract specifics and raw log

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
func (it *TaikoTimelockControllerCallScheduledIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoTimelockControllerCallScheduled)
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
		it.Event = new(TaikoTimelockControllerCallScheduled)
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
func (it *TaikoTimelockControllerCallScheduledIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoTimelockControllerCallScheduledIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoTimelockControllerCallScheduled represents a CallScheduled event raised by the TaikoTimelockController contract.
type TaikoTimelockControllerCallScheduled struct {
	Id          [32]byte
	Index       *big.Int
	Target      common.Address
	Value       *big.Int
	Data        []byte
	Predecessor [32]byte
	Delay       *big.Int
	Raw         types.Log // Blockchain specific contextual infos
}

// FilterCallScheduled is a free log retrieval operation binding the contract event 0x4cf4410cc57040e44862ef0f45f3dd5a5e02db8eb8add648d4b0e236f1d07dca.
//
// Solidity: event CallScheduled(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data, bytes32 predecessor, uint256 delay)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) FilterCallScheduled(opts *bind.FilterOpts, id [][32]byte, index []*big.Int) (*TaikoTimelockControllerCallScheduledIterator, error) {

	var idRule []interface{}
	for _, idItem := range id {
		idRule = append(idRule, idItem)
	}
	var indexRule []interface{}
	for _, indexItem := range index {
		indexRule = append(indexRule, indexItem)
	}

	logs, sub, err := _TaikoTimelockController.contract.FilterLogs(opts, "CallScheduled", idRule, indexRule)
	if err != nil {
		return nil, err
	}
	return &TaikoTimelockControllerCallScheduledIterator{contract: _TaikoTimelockController.contract, event: "CallScheduled", logs: logs, sub: sub}, nil
}

// WatchCallScheduled is a free log subscription operation binding the contract event 0x4cf4410cc57040e44862ef0f45f3dd5a5e02db8eb8add648d4b0e236f1d07dca.
//
// Solidity: event CallScheduled(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data, bytes32 predecessor, uint256 delay)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) WatchCallScheduled(opts *bind.WatchOpts, sink chan<- *TaikoTimelockControllerCallScheduled, id [][32]byte, index []*big.Int) (event.Subscription, error) {

	var idRule []interface{}
	for _, idItem := range id {
		idRule = append(idRule, idItem)
	}
	var indexRule []interface{}
	for _, indexItem := range index {
		indexRule = append(indexRule, indexItem)
	}

	logs, sub, err := _TaikoTimelockController.contract.WatchLogs(opts, "CallScheduled", idRule, indexRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoTimelockControllerCallScheduled)
				if err := _TaikoTimelockController.contract.UnpackLog(event, "CallScheduled", log); err != nil {
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

// ParseCallScheduled is a log parse operation binding the contract event 0x4cf4410cc57040e44862ef0f45f3dd5a5e02db8eb8add648d4b0e236f1d07dca.
//
// Solidity: event CallScheduled(bytes32 indexed id, uint256 indexed index, address target, uint256 value, bytes data, bytes32 predecessor, uint256 delay)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) ParseCallScheduled(log types.Log) (*TaikoTimelockControllerCallScheduled, error) {
	event := new(TaikoTimelockControllerCallScheduled)
	if err := _TaikoTimelockController.contract.UnpackLog(event, "CallScheduled", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoTimelockControllerCancelledIterator is returned from FilterCancelled and is used to iterate over the raw logs and unpacked data for Cancelled events raised by the TaikoTimelockController contract.
type TaikoTimelockControllerCancelledIterator struct {
	Event *TaikoTimelockControllerCancelled // Event containing the contract specifics and raw log

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
func (it *TaikoTimelockControllerCancelledIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoTimelockControllerCancelled)
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
		it.Event = new(TaikoTimelockControllerCancelled)
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
func (it *TaikoTimelockControllerCancelledIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoTimelockControllerCancelledIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoTimelockControllerCancelled represents a Cancelled event raised by the TaikoTimelockController contract.
type TaikoTimelockControllerCancelled struct {
	Id  [32]byte
	Raw types.Log // Blockchain specific contextual infos
}

// FilterCancelled is a free log retrieval operation binding the contract event 0xbaa1eb22f2a492ba1a5fea61b8df4d27c6c8b5f3971e63bb58fa14ff72eedb70.
//
// Solidity: event Cancelled(bytes32 indexed id)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) FilterCancelled(opts *bind.FilterOpts, id [][32]byte) (*TaikoTimelockControllerCancelledIterator, error) {

	var idRule []interface{}
	for _, idItem := range id {
		idRule = append(idRule, idItem)
	}

	logs, sub, err := _TaikoTimelockController.contract.FilterLogs(opts, "Cancelled", idRule)
	if err != nil {
		return nil, err
	}
	return &TaikoTimelockControllerCancelledIterator{contract: _TaikoTimelockController.contract, event: "Cancelled", logs: logs, sub: sub}, nil
}

// WatchCancelled is a free log subscription operation binding the contract event 0xbaa1eb22f2a492ba1a5fea61b8df4d27c6c8b5f3971e63bb58fa14ff72eedb70.
//
// Solidity: event Cancelled(bytes32 indexed id)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) WatchCancelled(opts *bind.WatchOpts, sink chan<- *TaikoTimelockControllerCancelled, id [][32]byte) (event.Subscription, error) {

	var idRule []interface{}
	for _, idItem := range id {
		idRule = append(idRule, idItem)
	}

	logs, sub, err := _TaikoTimelockController.contract.WatchLogs(opts, "Cancelled", idRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoTimelockControllerCancelled)
				if err := _TaikoTimelockController.contract.UnpackLog(event, "Cancelled", log); err != nil {
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

// ParseCancelled is a log parse operation binding the contract event 0xbaa1eb22f2a492ba1a5fea61b8df4d27c6c8b5f3971e63bb58fa14ff72eedb70.
//
// Solidity: event Cancelled(bytes32 indexed id)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) ParseCancelled(log types.Log) (*TaikoTimelockControllerCancelled, error) {
	event := new(TaikoTimelockControllerCancelled)
	if err := _TaikoTimelockController.contract.UnpackLog(event, "Cancelled", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoTimelockControllerInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the TaikoTimelockController contract.
type TaikoTimelockControllerInitializedIterator struct {
	Event *TaikoTimelockControllerInitialized // Event containing the contract specifics and raw log

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
func (it *TaikoTimelockControllerInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoTimelockControllerInitialized)
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
		it.Event = new(TaikoTimelockControllerInitialized)
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
func (it *TaikoTimelockControllerInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoTimelockControllerInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoTimelockControllerInitialized represents a Initialized event raised by the TaikoTimelockController contract.
type TaikoTimelockControllerInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) FilterInitialized(opts *bind.FilterOpts) (*TaikoTimelockControllerInitializedIterator, error) {

	logs, sub, err := _TaikoTimelockController.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &TaikoTimelockControllerInitializedIterator{contract: _TaikoTimelockController.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *TaikoTimelockControllerInitialized) (event.Subscription, error) {

	logs, sub, err := _TaikoTimelockController.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoTimelockControllerInitialized)
				if err := _TaikoTimelockController.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) ParseInitialized(log types.Log) (*TaikoTimelockControllerInitialized, error) {
	event := new(TaikoTimelockControllerInitialized)
	if err := _TaikoTimelockController.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoTimelockControllerMinDelayChangeIterator is returned from FilterMinDelayChange and is used to iterate over the raw logs and unpacked data for MinDelayChange events raised by the TaikoTimelockController contract.
type TaikoTimelockControllerMinDelayChangeIterator struct {
	Event *TaikoTimelockControllerMinDelayChange // Event containing the contract specifics and raw log

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
func (it *TaikoTimelockControllerMinDelayChangeIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoTimelockControllerMinDelayChange)
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
		it.Event = new(TaikoTimelockControllerMinDelayChange)
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
func (it *TaikoTimelockControllerMinDelayChangeIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoTimelockControllerMinDelayChangeIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoTimelockControllerMinDelayChange represents a MinDelayChange event raised by the TaikoTimelockController contract.
type TaikoTimelockControllerMinDelayChange struct {
	OldDuration *big.Int
	NewDuration *big.Int
	Raw         types.Log // Blockchain specific contextual infos
}

// FilterMinDelayChange is a free log retrieval operation binding the contract event 0x11c24f4ead16507c69ac467fbd5e4eed5fb5c699626d2cc6d66421df253886d5.
//
// Solidity: event MinDelayChange(uint256 oldDuration, uint256 newDuration)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) FilterMinDelayChange(opts *bind.FilterOpts) (*TaikoTimelockControllerMinDelayChangeIterator, error) {

	logs, sub, err := _TaikoTimelockController.contract.FilterLogs(opts, "MinDelayChange")
	if err != nil {
		return nil, err
	}
	return &TaikoTimelockControllerMinDelayChangeIterator{contract: _TaikoTimelockController.contract, event: "MinDelayChange", logs: logs, sub: sub}, nil
}

// WatchMinDelayChange is a free log subscription operation binding the contract event 0x11c24f4ead16507c69ac467fbd5e4eed5fb5c699626d2cc6d66421df253886d5.
//
// Solidity: event MinDelayChange(uint256 oldDuration, uint256 newDuration)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) WatchMinDelayChange(opts *bind.WatchOpts, sink chan<- *TaikoTimelockControllerMinDelayChange) (event.Subscription, error) {

	logs, sub, err := _TaikoTimelockController.contract.WatchLogs(opts, "MinDelayChange")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoTimelockControllerMinDelayChange)
				if err := _TaikoTimelockController.contract.UnpackLog(event, "MinDelayChange", log); err != nil {
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

// ParseMinDelayChange is a log parse operation binding the contract event 0x11c24f4ead16507c69ac467fbd5e4eed5fb5c699626d2cc6d66421df253886d5.
//
// Solidity: event MinDelayChange(uint256 oldDuration, uint256 newDuration)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) ParseMinDelayChange(log types.Log) (*TaikoTimelockControllerMinDelayChange, error) {
	event := new(TaikoTimelockControllerMinDelayChange)
	if err := _TaikoTimelockController.contract.UnpackLog(event, "MinDelayChange", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoTimelockControllerOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the TaikoTimelockController contract.
type TaikoTimelockControllerOwnershipTransferStartedIterator struct {
	Event *TaikoTimelockControllerOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *TaikoTimelockControllerOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoTimelockControllerOwnershipTransferStarted)
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
		it.Event = new(TaikoTimelockControllerOwnershipTransferStarted)
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
func (it *TaikoTimelockControllerOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoTimelockControllerOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoTimelockControllerOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the TaikoTimelockController contract.
type TaikoTimelockControllerOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*TaikoTimelockControllerOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoTimelockController.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &TaikoTimelockControllerOwnershipTransferStartedIterator{contract: _TaikoTimelockController.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *TaikoTimelockControllerOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoTimelockController.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoTimelockControllerOwnershipTransferStarted)
				if err := _TaikoTimelockController.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) ParseOwnershipTransferStarted(log types.Log) (*TaikoTimelockControllerOwnershipTransferStarted, error) {
	event := new(TaikoTimelockControllerOwnershipTransferStarted)
	if err := _TaikoTimelockController.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoTimelockControllerOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the TaikoTimelockController contract.
type TaikoTimelockControllerOwnershipTransferredIterator struct {
	Event *TaikoTimelockControllerOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *TaikoTimelockControllerOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoTimelockControllerOwnershipTransferred)
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
		it.Event = new(TaikoTimelockControllerOwnershipTransferred)
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
func (it *TaikoTimelockControllerOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoTimelockControllerOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoTimelockControllerOwnershipTransferred represents a OwnershipTransferred event raised by the TaikoTimelockController contract.
type TaikoTimelockControllerOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*TaikoTimelockControllerOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoTimelockController.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &TaikoTimelockControllerOwnershipTransferredIterator{contract: _TaikoTimelockController.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *TaikoTimelockControllerOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoTimelockController.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoTimelockControllerOwnershipTransferred)
				if err := _TaikoTimelockController.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) ParseOwnershipTransferred(log types.Log) (*TaikoTimelockControllerOwnershipTransferred, error) {
	event := new(TaikoTimelockControllerOwnershipTransferred)
	if err := _TaikoTimelockController.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoTimelockControllerPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the TaikoTimelockController contract.
type TaikoTimelockControllerPausedIterator struct {
	Event *TaikoTimelockControllerPaused // Event containing the contract specifics and raw log

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
func (it *TaikoTimelockControllerPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoTimelockControllerPaused)
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
		it.Event = new(TaikoTimelockControllerPaused)
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
func (it *TaikoTimelockControllerPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoTimelockControllerPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoTimelockControllerPaused represents a Paused event raised by the TaikoTimelockController contract.
type TaikoTimelockControllerPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) FilterPaused(opts *bind.FilterOpts) (*TaikoTimelockControllerPausedIterator, error) {

	logs, sub, err := _TaikoTimelockController.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &TaikoTimelockControllerPausedIterator{contract: _TaikoTimelockController.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *TaikoTimelockControllerPaused) (event.Subscription, error) {

	logs, sub, err := _TaikoTimelockController.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoTimelockControllerPaused)
				if err := _TaikoTimelockController.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) ParsePaused(log types.Log) (*TaikoTimelockControllerPaused, error) {
	event := new(TaikoTimelockControllerPaused)
	if err := _TaikoTimelockController.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoTimelockControllerRoleAdminChangedIterator is returned from FilterRoleAdminChanged and is used to iterate over the raw logs and unpacked data for RoleAdminChanged events raised by the TaikoTimelockController contract.
type TaikoTimelockControllerRoleAdminChangedIterator struct {
	Event *TaikoTimelockControllerRoleAdminChanged // Event containing the contract specifics and raw log

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
func (it *TaikoTimelockControllerRoleAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoTimelockControllerRoleAdminChanged)
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
		it.Event = new(TaikoTimelockControllerRoleAdminChanged)
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
func (it *TaikoTimelockControllerRoleAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoTimelockControllerRoleAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoTimelockControllerRoleAdminChanged represents a RoleAdminChanged event raised by the TaikoTimelockController contract.
type TaikoTimelockControllerRoleAdminChanged struct {
	Role              [32]byte
	PreviousAdminRole [32]byte
	NewAdminRole      [32]byte
	Raw               types.Log // Blockchain specific contextual infos
}

// FilterRoleAdminChanged is a free log retrieval operation binding the contract event 0xbd79b86ffe0ab8e8776151514217cd7cacd52c909f66475c3af44e129f0b00ff.
//
// Solidity: event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) FilterRoleAdminChanged(opts *bind.FilterOpts, role [][32]byte, previousAdminRole [][32]byte, newAdminRole [][32]byte) (*TaikoTimelockControllerRoleAdminChangedIterator, error) {

	var roleRule []interface{}
	for _, roleItem := range role {
		roleRule = append(roleRule, roleItem)
	}
	var previousAdminRoleRule []interface{}
	for _, previousAdminRoleItem := range previousAdminRole {
		previousAdminRoleRule = append(previousAdminRoleRule, previousAdminRoleItem)
	}
	var newAdminRoleRule []interface{}
	for _, newAdminRoleItem := range newAdminRole {
		newAdminRoleRule = append(newAdminRoleRule, newAdminRoleItem)
	}

	logs, sub, err := _TaikoTimelockController.contract.FilterLogs(opts, "RoleAdminChanged", roleRule, previousAdminRoleRule, newAdminRoleRule)
	if err != nil {
		return nil, err
	}
	return &TaikoTimelockControllerRoleAdminChangedIterator{contract: _TaikoTimelockController.contract, event: "RoleAdminChanged", logs: logs, sub: sub}, nil
}

// WatchRoleAdminChanged is a free log subscription operation binding the contract event 0xbd79b86ffe0ab8e8776151514217cd7cacd52c909f66475c3af44e129f0b00ff.
//
// Solidity: event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) WatchRoleAdminChanged(opts *bind.WatchOpts, sink chan<- *TaikoTimelockControllerRoleAdminChanged, role [][32]byte, previousAdminRole [][32]byte, newAdminRole [][32]byte) (event.Subscription, error) {

	var roleRule []interface{}
	for _, roleItem := range role {
		roleRule = append(roleRule, roleItem)
	}
	var previousAdminRoleRule []interface{}
	for _, previousAdminRoleItem := range previousAdminRole {
		previousAdminRoleRule = append(previousAdminRoleRule, previousAdminRoleItem)
	}
	var newAdminRoleRule []interface{}
	for _, newAdminRoleItem := range newAdminRole {
		newAdminRoleRule = append(newAdminRoleRule, newAdminRoleItem)
	}

	logs, sub, err := _TaikoTimelockController.contract.WatchLogs(opts, "RoleAdminChanged", roleRule, previousAdminRoleRule, newAdminRoleRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoTimelockControllerRoleAdminChanged)
				if err := _TaikoTimelockController.contract.UnpackLog(event, "RoleAdminChanged", log); err != nil {
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

// ParseRoleAdminChanged is a log parse operation binding the contract event 0xbd79b86ffe0ab8e8776151514217cd7cacd52c909f66475c3af44e129f0b00ff.
//
// Solidity: event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) ParseRoleAdminChanged(log types.Log) (*TaikoTimelockControllerRoleAdminChanged, error) {
	event := new(TaikoTimelockControllerRoleAdminChanged)
	if err := _TaikoTimelockController.contract.UnpackLog(event, "RoleAdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoTimelockControllerRoleGrantedIterator is returned from FilterRoleGranted and is used to iterate over the raw logs and unpacked data for RoleGranted events raised by the TaikoTimelockController contract.
type TaikoTimelockControllerRoleGrantedIterator struct {
	Event *TaikoTimelockControllerRoleGranted // Event containing the contract specifics and raw log

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
func (it *TaikoTimelockControllerRoleGrantedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoTimelockControllerRoleGranted)
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
		it.Event = new(TaikoTimelockControllerRoleGranted)
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
func (it *TaikoTimelockControllerRoleGrantedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoTimelockControllerRoleGrantedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoTimelockControllerRoleGranted represents a RoleGranted event raised by the TaikoTimelockController contract.
type TaikoTimelockControllerRoleGranted struct {
	Role    [32]byte
	Account common.Address
	Sender  common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterRoleGranted is a free log retrieval operation binding the contract event 0x2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d.
//
// Solidity: event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) FilterRoleGranted(opts *bind.FilterOpts, role [][32]byte, account []common.Address, sender []common.Address) (*TaikoTimelockControllerRoleGrantedIterator, error) {

	var roleRule []interface{}
	for _, roleItem := range role {
		roleRule = append(roleRule, roleItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var senderRule []interface{}
	for _, senderItem := range sender {
		senderRule = append(senderRule, senderItem)
	}

	logs, sub, err := _TaikoTimelockController.contract.FilterLogs(opts, "RoleGranted", roleRule, accountRule, senderRule)
	if err != nil {
		return nil, err
	}
	return &TaikoTimelockControllerRoleGrantedIterator{contract: _TaikoTimelockController.contract, event: "RoleGranted", logs: logs, sub: sub}, nil
}

// WatchRoleGranted is a free log subscription operation binding the contract event 0x2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d.
//
// Solidity: event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) WatchRoleGranted(opts *bind.WatchOpts, sink chan<- *TaikoTimelockControllerRoleGranted, role [][32]byte, account []common.Address, sender []common.Address) (event.Subscription, error) {

	var roleRule []interface{}
	for _, roleItem := range role {
		roleRule = append(roleRule, roleItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var senderRule []interface{}
	for _, senderItem := range sender {
		senderRule = append(senderRule, senderItem)
	}

	logs, sub, err := _TaikoTimelockController.contract.WatchLogs(opts, "RoleGranted", roleRule, accountRule, senderRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoTimelockControllerRoleGranted)
				if err := _TaikoTimelockController.contract.UnpackLog(event, "RoleGranted", log); err != nil {
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

// ParseRoleGranted is a log parse operation binding the contract event 0x2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d.
//
// Solidity: event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) ParseRoleGranted(log types.Log) (*TaikoTimelockControllerRoleGranted, error) {
	event := new(TaikoTimelockControllerRoleGranted)
	if err := _TaikoTimelockController.contract.UnpackLog(event, "RoleGranted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoTimelockControllerRoleRevokedIterator is returned from FilterRoleRevoked and is used to iterate over the raw logs and unpacked data for RoleRevoked events raised by the TaikoTimelockController contract.
type TaikoTimelockControllerRoleRevokedIterator struct {
	Event *TaikoTimelockControllerRoleRevoked // Event containing the contract specifics and raw log

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
func (it *TaikoTimelockControllerRoleRevokedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoTimelockControllerRoleRevoked)
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
		it.Event = new(TaikoTimelockControllerRoleRevoked)
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
func (it *TaikoTimelockControllerRoleRevokedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoTimelockControllerRoleRevokedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoTimelockControllerRoleRevoked represents a RoleRevoked event raised by the TaikoTimelockController contract.
type TaikoTimelockControllerRoleRevoked struct {
	Role    [32]byte
	Account common.Address
	Sender  common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterRoleRevoked is a free log retrieval operation binding the contract event 0xf6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b.
//
// Solidity: event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) FilterRoleRevoked(opts *bind.FilterOpts, role [][32]byte, account []common.Address, sender []common.Address) (*TaikoTimelockControllerRoleRevokedIterator, error) {

	var roleRule []interface{}
	for _, roleItem := range role {
		roleRule = append(roleRule, roleItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var senderRule []interface{}
	for _, senderItem := range sender {
		senderRule = append(senderRule, senderItem)
	}

	logs, sub, err := _TaikoTimelockController.contract.FilterLogs(opts, "RoleRevoked", roleRule, accountRule, senderRule)
	if err != nil {
		return nil, err
	}
	return &TaikoTimelockControllerRoleRevokedIterator{contract: _TaikoTimelockController.contract, event: "RoleRevoked", logs: logs, sub: sub}, nil
}

// WatchRoleRevoked is a free log subscription operation binding the contract event 0xf6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b.
//
// Solidity: event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) WatchRoleRevoked(opts *bind.WatchOpts, sink chan<- *TaikoTimelockControllerRoleRevoked, role [][32]byte, account []common.Address, sender []common.Address) (event.Subscription, error) {

	var roleRule []interface{}
	for _, roleItem := range role {
		roleRule = append(roleRule, roleItem)
	}
	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}
	var senderRule []interface{}
	for _, senderItem := range sender {
		senderRule = append(senderRule, senderItem)
	}

	logs, sub, err := _TaikoTimelockController.contract.WatchLogs(opts, "RoleRevoked", roleRule, accountRule, senderRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoTimelockControllerRoleRevoked)
				if err := _TaikoTimelockController.contract.UnpackLog(event, "RoleRevoked", log); err != nil {
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

// ParseRoleRevoked is a log parse operation binding the contract event 0xf6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b.
//
// Solidity: event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) ParseRoleRevoked(log types.Log) (*TaikoTimelockControllerRoleRevoked, error) {
	event := new(TaikoTimelockControllerRoleRevoked)
	if err := _TaikoTimelockController.contract.UnpackLog(event, "RoleRevoked", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoTimelockControllerUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the TaikoTimelockController contract.
type TaikoTimelockControllerUnpausedIterator struct {
	Event *TaikoTimelockControllerUnpaused // Event containing the contract specifics and raw log

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
func (it *TaikoTimelockControllerUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoTimelockControllerUnpaused)
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
		it.Event = new(TaikoTimelockControllerUnpaused)
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
func (it *TaikoTimelockControllerUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoTimelockControllerUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoTimelockControllerUnpaused represents a Unpaused event raised by the TaikoTimelockController contract.
type TaikoTimelockControllerUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) FilterUnpaused(opts *bind.FilterOpts) (*TaikoTimelockControllerUnpausedIterator, error) {

	logs, sub, err := _TaikoTimelockController.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &TaikoTimelockControllerUnpausedIterator{contract: _TaikoTimelockController.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *TaikoTimelockControllerUnpaused) (event.Subscription, error) {

	logs, sub, err := _TaikoTimelockController.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoTimelockControllerUnpaused)
				if err := _TaikoTimelockController.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) ParseUnpaused(log types.Log) (*TaikoTimelockControllerUnpaused, error) {
	event := new(TaikoTimelockControllerUnpaused)
	if err := _TaikoTimelockController.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoTimelockControllerUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the TaikoTimelockController contract.
type TaikoTimelockControllerUpgradedIterator struct {
	Event *TaikoTimelockControllerUpgraded // Event containing the contract specifics and raw log

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
func (it *TaikoTimelockControllerUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoTimelockControllerUpgraded)
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
		it.Event = new(TaikoTimelockControllerUpgraded)
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
func (it *TaikoTimelockControllerUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoTimelockControllerUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoTimelockControllerUpgraded represents a Upgraded event raised by the TaikoTimelockController contract.
type TaikoTimelockControllerUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*TaikoTimelockControllerUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _TaikoTimelockController.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &TaikoTimelockControllerUpgradedIterator{contract: _TaikoTimelockController.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *TaikoTimelockControllerUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _TaikoTimelockController.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoTimelockControllerUpgraded)
				if err := _TaikoTimelockController.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_TaikoTimelockController *TaikoTimelockControllerFilterer) ParseUpgraded(log types.Log) (*TaikoTimelockControllerUpgraded, error) {
	event := new(TaikoTimelockControllerUpgraded)
	if err := _TaikoTimelockController.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
