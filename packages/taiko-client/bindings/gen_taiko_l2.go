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

// LibL2ConfigConfig is an auto generated low-level Go binding around an user-defined struct.
type LibL2ConfigConfig struct {
	GasTargetPerL1Block       uint32
	BasefeeAdjustmentQuotient uint8
}

// TaikoL2ClientMetaData contains all meta data concerning the TaikoL2Client contract.
var TaikoL2ClientMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"GOLDEN_TOUCH_ADDRESS\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"addressManager\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"adjustExcess\",\"inputs\":[{\"name\":\"_currGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_currGasTarget\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_newGasTarget\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"outputs\":[{\"name\":\"newGasExcess_\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"anchor\",\"inputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_l1StateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_l1BlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_parentGasUsed\",\"type\":\"uint32\",\"internalType\":\"uint32\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"anchorV2\",\"inputs\":[{\"name\":\"_anchorBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_anchorStateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_parentGasUsed\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"_baseFeeConfig\",\"type\":\"tuple\",\"internalType\":\"structTaikoData.BaseFeeConfig\",\"components\":[{\"name\":\"adjustmentQuotient\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"gasIssuancePerSecond\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"minGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxGasIssuancePerBlock\",\"type\":\"uint32\",\"internalType\":\"uint32\"}]}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"calculateBaseFee\",\"inputs\":[{\"name\":\"_baseFeeConfig\",\"type\":\"tuple\",\"internalType\":\"structTaikoData.BaseFeeConfig\",\"components\":[{\"name\":\"adjustmentQuotient\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"gasIssuancePerSecond\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"minGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxGasIssuancePerBlock\",\"type\":\"uint32\",\"internalType\":\"uint32\"}]},{\"name\":\"_blocktime\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_parentGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_parentGasUsed\",\"type\":\"uint32\",\"internalType\":\"uint32\"}],\"outputs\":[{\"name\":\"basefee_\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"parentGasExcess_\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getBasefee\",\"inputs\":[{\"name\":\"_anchorBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_parentGasUsed\",\"type\":\"uint32\",\"internalType\":\"uint32\"}],\"outputs\":[{\"name\":\"basefee_\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"parentGasExcess_\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getBlockHash\",\"inputs\":[{\"name\":\"_blockId\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getConfig\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structLibL2Config.Config\",\"components\":[{\"name\":\"gasTargetPerL1Block\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"basefeeAdjustmentQuotient\",\"type\":\"uint8\",\"internalType\":\"uint8\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"impl\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inNonReentrant\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_rollupAddressManager\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_l1ChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_initialGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"l1ChainId\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"lastSyncedBlock\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"lastUnpausedAt\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"ontakeForkHeight\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"parentGasExcess\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"parentGasTarget\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"parentTimestamp\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"publicInputHash\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolve\",\"inputs\":[{\"name\":\"_chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_allowZeroAddress\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"resolve\",\"inputs\":[{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_allowZeroAddress\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"skipFeeCheck\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"withdraw\",\"inputs\":[{\"name\":\"_token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_to\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Anchored\",\"inputs\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"parentGasExcess\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"EIP1559_INVALID_PARAMS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ETH_TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FUNC_NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L2_BASEFEE_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L2_FORK_ERROR\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L2_INVALID_L1_CHAIN_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L2_INVALID_L2_CHAIN_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L2_INVALID_PARAM\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L2_INVALID_SENDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L2_PUBLIC_INPUT_HASH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L2_TOO_LATE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_INVALID_MANAGER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_UNEXPECTED_CHAINID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_ZERO_ADDR\",\"inputs\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_VALUE\",\"inputs\":[]}]",
}

// TaikoL2ClientABI is the input ABI used to generate the binding from.
// Deprecated: Use TaikoL2ClientMetaData.ABI instead.
var TaikoL2ClientABI = TaikoL2ClientMetaData.ABI

// TaikoL2Client is an auto generated Go binding around an Ethereum contract.
type TaikoL2Client struct {
	TaikoL2ClientCaller     // Read-only binding to the contract
	TaikoL2ClientTransactor // Write-only binding to the contract
	TaikoL2ClientFilterer   // Log filterer for contract events
}

// TaikoL2ClientCaller is an auto generated read-only Go binding around an Ethereum contract.
type TaikoL2ClientCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoL2ClientTransactor is an auto generated write-only Go binding around an Ethereum contract.
type TaikoL2ClientTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoL2ClientFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type TaikoL2ClientFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoL2ClientSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type TaikoL2ClientSession struct {
	Contract     *TaikoL2Client    // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// TaikoL2ClientCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type TaikoL2ClientCallerSession struct {
	Contract *TaikoL2ClientCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts        // Call options to use throughout this session
}

// TaikoL2ClientTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type TaikoL2ClientTransactorSession struct {
	Contract     *TaikoL2ClientTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts        // Transaction auth options to use throughout this session
}

// TaikoL2ClientRaw is an auto generated low-level Go binding around an Ethereum contract.
type TaikoL2ClientRaw struct {
	Contract *TaikoL2Client // Generic contract binding to access the raw methods on
}

// TaikoL2ClientCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type TaikoL2ClientCallerRaw struct {
	Contract *TaikoL2ClientCaller // Generic read-only contract binding to access the raw methods on
}

// TaikoL2ClientTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type TaikoL2ClientTransactorRaw struct {
	Contract *TaikoL2ClientTransactor // Generic write-only contract binding to access the raw methods on
}

// NewTaikoL2Client creates a new instance of TaikoL2Client, bound to a specific deployed contract.
func NewTaikoL2Client(address common.Address, backend bind.ContractBackend) (*TaikoL2Client, error) {
	contract, err := bindTaikoL2Client(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &TaikoL2Client{TaikoL2ClientCaller: TaikoL2ClientCaller{contract: contract}, TaikoL2ClientTransactor: TaikoL2ClientTransactor{contract: contract}, TaikoL2ClientFilterer: TaikoL2ClientFilterer{contract: contract}}, nil
}

// NewTaikoL2ClientCaller creates a new read-only instance of TaikoL2Client, bound to a specific deployed contract.
func NewTaikoL2ClientCaller(address common.Address, caller bind.ContractCaller) (*TaikoL2ClientCaller, error) {
	contract, err := bindTaikoL2Client(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &TaikoL2ClientCaller{contract: contract}, nil
}

// NewTaikoL2ClientTransactor creates a new write-only instance of TaikoL2Client, bound to a specific deployed contract.
func NewTaikoL2ClientTransactor(address common.Address, transactor bind.ContractTransactor) (*TaikoL2ClientTransactor, error) {
	contract, err := bindTaikoL2Client(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &TaikoL2ClientTransactor{contract: contract}, nil
}

// NewTaikoL2ClientFilterer creates a new log filterer instance of TaikoL2Client, bound to a specific deployed contract.
func NewTaikoL2ClientFilterer(address common.Address, filterer bind.ContractFilterer) (*TaikoL2ClientFilterer, error) {
	contract, err := bindTaikoL2Client(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &TaikoL2ClientFilterer{contract: contract}, nil
}

// bindTaikoL2Client binds a generic wrapper to an already deployed contract.
func bindTaikoL2Client(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := TaikoL2ClientMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TaikoL2Client *TaikoL2ClientRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TaikoL2Client.Contract.TaikoL2ClientCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TaikoL2Client *TaikoL2ClientRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL2Client.Contract.TaikoL2ClientTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TaikoL2Client *TaikoL2ClientRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TaikoL2Client.Contract.TaikoL2ClientTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TaikoL2Client *TaikoL2ClientCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TaikoL2Client.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TaikoL2Client *TaikoL2ClientTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL2Client.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TaikoL2Client *TaikoL2ClientTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TaikoL2Client.Contract.contract.Transact(opts, method, params...)
}

// GOLDENTOUCHADDRESS is a free data retrieval call binding the contract method 0x9ee512f2.
//
// Solidity: function GOLDEN_TOUCH_ADDRESS() view returns(address)
func (_TaikoL2Client *TaikoL2ClientCaller) GOLDENTOUCHADDRESS(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoL2Client.contract.Call(opts, &out, "GOLDEN_TOUCH_ADDRESS")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GOLDENTOUCHADDRESS is a free data retrieval call binding the contract method 0x9ee512f2.
//
// Solidity: function GOLDEN_TOUCH_ADDRESS() view returns(address)
func (_TaikoL2Client *TaikoL2ClientSession) GOLDENTOUCHADDRESS() (common.Address, error) {
	return _TaikoL2Client.Contract.GOLDENTOUCHADDRESS(&_TaikoL2Client.CallOpts)
}

// GOLDENTOUCHADDRESS is a free data retrieval call binding the contract method 0x9ee512f2.
//
// Solidity: function GOLDEN_TOUCH_ADDRESS() view returns(address)
func (_TaikoL2Client *TaikoL2ClientCallerSession) GOLDENTOUCHADDRESS() (common.Address, error) {
	return _TaikoL2Client.Contract.GOLDENTOUCHADDRESS(&_TaikoL2Client.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_TaikoL2Client *TaikoL2ClientCaller) AddressManager(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoL2Client.contract.Call(opts, &out, "addressManager")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_TaikoL2Client *TaikoL2ClientSession) AddressManager() (common.Address, error) {
	return _TaikoL2Client.Contract.AddressManager(&_TaikoL2Client.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_TaikoL2Client *TaikoL2ClientCallerSession) AddressManager() (common.Address, error) {
	return _TaikoL2Client.Contract.AddressManager(&_TaikoL2Client.CallOpts)
}

// AdjustExcess is a free data retrieval call binding the contract method 0x136dc4a8.
//
// Solidity: function adjustExcess(uint64 _currGasExcess, uint64 _currGasTarget, uint64 _newGasTarget) pure returns(uint64 newGasExcess_)
func (_TaikoL2Client *TaikoL2ClientCaller) AdjustExcess(opts *bind.CallOpts, _currGasExcess uint64, _currGasTarget uint64, _newGasTarget uint64) (uint64, error) {
	var out []interface{}
	err := _TaikoL2Client.contract.Call(opts, &out, "adjustExcess", _currGasExcess, _currGasTarget, _newGasTarget)

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// AdjustExcess is a free data retrieval call binding the contract method 0x136dc4a8.
//
// Solidity: function adjustExcess(uint64 _currGasExcess, uint64 _currGasTarget, uint64 _newGasTarget) pure returns(uint64 newGasExcess_)
func (_TaikoL2Client *TaikoL2ClientSession) AdjustExcess(_currGasExcess uint64, _currGasTarget uint64, _newGasTarget uint64) (uint64, error) {
	return _TaikoL2Client.Contract.AdjustExcess(&_TaikoL2Client.CallOpts, _currGasExcess, _currGasTarget, _newGasTarget)
}

// AdjustExcess is a free data retrieval call binding the contract method 0x136dc4a8.
//
// Solidity: function adjustExcess(uint64 _currGasExcess, uint64 _currGasTarget, uint64 _newGasTarget) pure returns(uint64 newGasExcess_)
func (_TaikoL2Client *TaikoL2ClientCallerSession) AdjustExcess(_currGasExcess uint64, _currGasTarget uint64, _newGasTarget uint64) (uint64, error) {
	return _TaikoL2Client.Contract.AdjustExcess(&_TaikoL2Client.CallOpts, _currGasExcess, _currGasTarget, _newGasTarget)
}

// CalculateBaseFee is a free data retrieval call binding the contract method 0xe902461a.
//
// Solidity: function calculateBaseFee((uint8,uint8,uint32,uint64,uint32) _baseFeeConfig, uint64 _blocktime, uint64 _parentGasExcess, uint32 _parentGasUsed) pure returns(uint256 basefee_, uint64 parentGasExcess_)
func (_TaikoL2Client *TaikoL2ClientCaller) CalculateBaseFee(opts *bind.CallOpts, _baseFeeConfig TaikoDataBaseFeeConfig, _blocktime uint64, _parentGasExcess uint64, _parentGasUsed uint32) (struct {
	Basefee         *big.Int
	ParentGasExcess uint64
}, error) {
	var out []interface{}
	err := _TaikoL2Client.contract.Call(opts, &out, "calculateBaseFee", _baseFeeConfig, _blocktime, _parentGasExcess, _parentGasUsed)

	outstruct := new(struct {
		Basefee         *big.Int
		ParentGasExcess uint64
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Basefee = *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	outstruct.ParentGasExcess = *abi.ConvertType(out[1], new(uint64)).(*uint64)

	return *outstruct, err

}

// CalculateBaseFee is a free data retrieval call binding the contract method 0xe902461a.
//
// Solidity: function calculateBaseFee((uint8,uint8,uint32,uint64,uint32) _baseFeeConfig, uint64 _blocktime, uint64 _parentGasExcess, uint32 _parentGasUsed) pure returns(uint256 basefee_, uint64 parentGasExcess_)
func (_TaikoL2Client *TaikoL2ClientSession) CalculateBaseFee(_baseFeeConfig TaikoDataBaseFeeConfig, _blocktime uint64, _parentGasExcess uint64, _parentGasUsed uint32) (struct {
	Basefee         *big.Int
	ParentGasExcess uint64
}, error) {
	return _TaikoL2Client.Contract.CalculateBaseFee(&_TaikoL2Client.CallOpts, _baseFeeConfig, _blocktime, _parentGasExcess, _parentGasUsed)
}

// CalculateBaseFee is a free data retrieval call binding the contract method 0xe902461a.
//
// Solidity: function calculateBaseFee((uint8,uint8,uint32,uint64,uint32) _baseFeeConfig, uint64 _blocktime, uint64 _parentGasExcess, uint32 _parentGasUsed) pure returns(uint256 basefee_, uint64 parentGasExcess_)
func (_TaikoL2Client *TaikoL2ClientCallerSession) CalculateBaseFee(_baseFeeConfig TaikoDataBaseFeeConfig, _blocktime uint64, _parentGasExcess uint64, _parentGasUsed uint32) (struct {
	Basefee         *big.Int
	ParentGasExcess uint64
}, error) {
	return _TaikoL2Client.Contract.CalculateBaseFee(&_TaikoL2Client.CallOpts, _baseFeeConfig, _blocktime, _parentGasExcess, _parentGasUsed)
}

// GetBasefee is a free data retrieval call binding the contract method 0xa7e022d1.
//
// Solidity: function getBasefee(uint64 _anchorBlockId, uint32 _parentGasUsed) view returns(uint256 basefee_, uint64 parentGasExcess_)
func (_TaikoL2Client *TaikoL2ClientCaller) GetBasefee(opts *bind.CallOpts, _anchorBlockId uint64, _parentGasUsed uint32) (struct {
	Basefee         *big.Int
	ParentGasExcess uint64
}, error) {
	var out []interface{}
	err := _TaikoL2Client.contract.Call(opts, &out, "getBasefee", _anchorBlockId, _parentGasUsed)

	outstruct := new(struct {
		Basefee         *big.Int
		ParentGasExcess uint64
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Basefee = *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	outstruct.ParentGasExcess = *abi.ConvertType(out[1], new(uint64)).(*uint64)

	return *outstruct, err

}

// GetBasefee is a free data retrieval call binding the contract method 0xa7e022d1.
//
// Solidity: function getBasefee(uint64 _anchorBlockId, uint32 _parentGasUsed) view returns(uint256 basefee_, uint64 parentGasExcess_)
func (_TaikoL2Client *TaikoL2ClientSession) GetBasefee(_anchorBlockId uint64, _parentGasUsed uint32) (struct {
	Basefee         *big.Int
	ParentGasExcess uint64
}, error) {
	return _TaikoL2Client.Contract.GetBasefee(&_TaikoL2Client.CallOpts, _anchorBlockId, _parentGasUsed)
}

// GetBasefee is a free data retrieval call binding the contract method 0xa7e022d1.
//
// Solidity: function getBasefee(uint64 _anchorBlockId, uint32 _parentGasUsed) view returns(uint256 basefee_, uint64 parentGasExcess_)
func (_TaikoL2Client *TaikoL2ClientCallerSession) GetBasefee(_anchorBlockId uint64, _parentGasUsed uint32) (struct {
	Basefee         *big.Int
	ParentGasExcess uint64
}, error) {
	return _TaikoL2Client.Contract.GetBasefee(&_TaikoL2Client.CallOpts, _anchorBlockId, _parentGasUsed)
}

// GetBlockHash is a free data retrieval call binding the contract method 0xee82ac5e.
//
// Solidity: function getBlockHash(uint256 _blockId) view returns(bytes32)
func (_TaikoL2Client *TaikoL2ClientCaller) GetBlockHash(opts *bind.CallOpts, _blockId *big.Int) ([32]byte, error) {
	var out []interface{}
	err := _TaikoL2Client.contract.Call(opts, &out, "getBlockHash", _blockId)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetBlockHash is a free data retrieval call binding the contract method 0xee82ac5e.
//
// Solidity: function getBlockHash(uint256 _blockId) view returns(bytes32)
func (_TaikoL2Client *TaikoL2ClientSession) GetBlockHash(_blockId *big.Int) ([32]byte, error) {
	return _TaikoL2Client.Contract.GetBlockHash(&_TaikoL2Client.CallOpts, _blockId)
}

// GetBlockHash is a free data retrieval call binding the contract method 0xee82ac5e.
//
// Solidity: function getBlockHash(uint256 _blockId) view returns(bytes32)
func (_TaikoL2Client *TaikoL2ClientCallerSession) GetBlockHash(_blockId *big.Int) ([32]byte, error) {
	return _TaikoL2Client.Contract.GetBlockHash(&_TaikoL2Client.CallOpts, _blockId)
}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() view returns((uint32,uint8))
func (_TaikoL2Client *TaikoL2ClientCaller) GetConfig(opts *bind.CallOpts) (LibL2ConfigConfig, error) {
	var out []interface{}
	err := _TaikoL2Client.contract.Call(opts, &out, "getConfig")

	if err != nil {
		return *new(LibL2ConfigConfig), err
	}

	out0 := *abi.ConvertType(out[0], new(LibL2ConfigConfig)).(*LibL2ConfigConfig)

	return out0, err

}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() view returns((uint32,uint8))
func (_TaikoL2Client *TaikoL2ClientSession) GetConfig() (LibL2ConfigConfig, error) {
	return _TaikoL2Client.Contract.GetConfig(&_TaikoL2Client.CallOpts)
}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() view returns((uint32,uint8))
func (_TaikoL2Client *TaikoL2ClientCallerSession) GetConfig() (LibL2ConfigConfig, error) {
	return _TaikoL2Client.Contract.GetConfig(&_TaikoL2Client.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_TaikoL2Client *TaikoL2ClientCaller) Impl(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoL2Client.contract.Call(opts, &out, "impl")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_TaikoL2Client *TaikoL2ClientSession) Impl() (common.Address, error) {
	return _TaikoL2Client.Contract.Impl(&_TaikoL2Client.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_TaikoL2Client *TaikoL2ClientCallerSession) Impl() (common.Address, error) {
	return _TaikoL2Client.Contract.Impl(&_TaikoL2Client.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_TaikoL2Client *TaikoL2ClientCaller) InNonReentrant(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _TaikoL2Client.contract.Call(opts, &out, "inNonReentrant")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_TaikoL2Client *TaikoL2ClientSession) InNonReentrant() (bool, error) {
	return _TaikoL2Client.Contract.InNonReentrant(&_TaikoL2Client.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_TaikoL2Client *TaikoL2ClientCallerSession) InNonReentrant() (bool, error) {
	return _TaikoL2Client.Contract.InNonReentrant(&_TaikoL2Client.CallOpts)
}

// L1ChainId is a free data retrieval call binding the contract method 0x12622e5b.
//
// Solidity: function l1ChainId() view returns(uint64)
func (_TaikoL2Client *TaikoL2ClientCaller) L1ChainId(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _TaikoL2Client.contract.Call(opts, &out, "l1ChainId")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// L1ChainId is a free data retrieval call binding the contract method 0x12622e5b.
//
// Solidity: function l1ChainId() view returns(uint64)
func (_TaikoL2Client *TaikoL2ClientSession) L1ChainId() (uint64, error) {
	return _TaikoL2Client.Contract.L1ChainId(&_TaikoL2Client.CallOpts)
}

// L1ChainId is a free data retrieval call binding the contract method 0x12622e5b.
//
// Solidity: function l1ChainId() view returns(uint64)
func (_TaikoL2Client *TaikoL2ClientCallerSession) L1ChainId() (uint64, error) {
	return _TaikoL2Client.Contract.L1ChainId(&_TaikoL2Client.CallOpts)
}

// LastSyncedBlock is a free data retrieval call binding the contract method 0x33d5ac9b.
//
// Solidity: function lastSyncedBlock() view returns(uint64)
func (_TaikoL2Client *TaikoL2ClientCaller) LastSyncedBlock(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _TaikoL2Client.contract.Call(opts, &out, "lastSyncedBlock")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// LastSyncedBlock is a free data retrieval call binding the contract method 0x33d5ac9b.
//
// Solidity: function lastSyncedBlock() view returns(uint64)
func (_TaikoL2Client *TaikoL2ClientSession) LastSyncedBlock() (uint64, error) {
	return _TaikoL2Client.Contract.LastSyncedBlock(&_TaikoL2Client.CallOpts)
}

// LastSyncedBlock is a free data retrieval call binding the contract method 0x33d5ac9b.
//
// Solidity: function lastSyncedBlock() view returns(uint64)
func (_TaikoL2Client *TaikoL2ClientCallerSession) LastSyncedBlock() (uint64, error) {
	return _TaikoL2Client.Contract.LastSyncedBlock(&_TaikoL2Client.CallOpts)
}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_TaikoL2Client *TaikoL2ClientCaller) LastUnpausedAt(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _TaikoL2Client.contract.Call(opts, &out, "lastUnpausedAt")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_TaikoL2Client *TaikoL2ClientSession) LastUnpausedAt() (uint64, error) {
	return _TaikoL2Client.Contract.LastUnpausedAt(&_TaikoL2Client.CallOpts)
}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_TaikoL2Client *TaikoL2ClientCallerSession) LastUnpausedAt() (uint64, error) {
	return _TaikoL2Client.Contract.LastUnpausedAt(&_TaikoL2Client.CallOpts)
}

// OntakeForkHeight is a free data retrieval call binding the contract method 0x356aec04.
//
// Solidity: function ontakeForkHeight() pure returns(uint64)
func (_TaikoL2Client *TaikoL2ClientCaller) OntakeForkHeight(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _TaikoL2Client.contract.Call(opts, &out, "ontakeForkHeight")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// OntakeForkHeight is a free data retrieval call binding the contract method 0x356aec04.
//
// Solidity: function ontakeForkHeight() pure returns(uint64)
func (_TaikoL2Client *TaikoL2ClientSession) OntakeForkHeight() (uint64, error) {
	return _TaikoL2Client.Contract.OntakeForkHeight(&_TaikoL2Client.CallOpts)
}

// OntakeForkHeight is a free data retrieval call binding the contract method 0x356aec04.
//
// Solidity: function ontakeForkHeight() pure returns(uint64)
func (_TaikoL2Client *TaikoL2ClientCallerSession) OntakeForkHeight() (uint64, error) {
	return _TaikoL2Client.Contract.OntakeForkHeight(&_TaikoL2Client.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoL2Client *TaikoL2ClientCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoL2Client.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoL2Client *TaikoL2ClientSession) Owner() (common.Address, error) {
	return _TaikoL2Client.Contract.Owner(&_TaikoL2Client.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoL2Client *TaikoL2ClientCallerSession) Owner() (common.Address, error) {
	return _TaikoL2Client.Contract.Owner(&_TaikoL2Client.CallOpts)
}

// ParentGasExcess is a free data retrieval call binding the contract method 0xb8c7b30c.
//
// Solidity: function parentGasExcess() view returns(uint64)
func (_TaikoL2Client *TaikoL2ClientCaller) ParentGasExcess(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _TaikoL2Client.contract.Call(opts, &out, "parentGasExcess")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// ParentGasExcess is a free data retrieval call binding the contract method 0xb8c7b30c.
//
// Solidity: function parentGasExcess() view returns(uint64)
func (_TaikoL2Client *TaikoL2ClientSession) ParentGasExcess() (uint64, error) {
	return _TaikoL2Client.Contract.ParentGasExcess(&_TaikoL2Client.CallOpts)
}

// ParentGasExcess is a free data retrieval call binding the contract method 0xb8c7b30c.
//
// Solidity: function parentGasExcess() view returns(uint64)
func (_TaikoL2Client *TaikoL2ClientCallerSession) ParentGasExcess() (uint64, error) {
	return _TaikoL2Client.Contract.ParentGasExcess(&_TaikoL2Client.CallOpts)
}

// ParentGasTarget is a free data retrieval call binding the contract method 0xa7137c0f.
//
// Solidity: function parentGasTarget() view returns(uint64)
func (_TaikoL2Client *TaikoL2ClientCaller) ParentGasTarget(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _TaikoL2Client.contract.Call(opts, &out, "parentGasTarget")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// ParentGasTarget is a free data retrieval call binding the contract method 0xa7137c0f.
//
// Solidity: function parentGasTarget() view returns(uint64)
func (_TaikoL2Client *TaikoL2ClientSession) ParentGasTarget() (uint64, error) {
	return _TaikoL2Client.Contract.ParentGasTarget(&_TaikoL2Client.CallOpts)
}

// ParentGasTarget is a free data retrieval call binding the contract method 0xa7137c0f.
//
// Solidity: function parentGasTarget() view returns(uint64)
func (_TaikoL2Client *TaikoL2ClientCallerSession) ParentGasTarget() (uint64, error) {
	return _TaikoL2Client.Contract.ParentGasTarget(&_TaikoL2Client.CallOpts)
}

// ParentTimestamp is a free data retrieval call binding the contract method 0x539b8ade.
//
// Solidity: function parentTimestamp() view returns(uint64)
func (_TaikoL2Client *TaikoL2ClientCaller) ParentTimestamp(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _TaikoL2Client.contract.Call(opts, &out, "parentTimestamp")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// ParentTimestamp is a free data retrieval call binding the contract method 0x539b8ade.
//
// Solidity: function parentTimestamp() view returns(uint64)
func (_TaikoL2Client *TaikoL2ClientSession) ParentTimestamp() (uint64, error) {
	return _TaikoL2Client.Contract.ParentTimestamp(&_TaikoL2Client.CallOpts)
}

// ParentTimestamp is a free data retrieval call binding the contract method 0x539b8ade.
//
// Solidity: function parentTimestamp() view returns(uint64)
func (_TaikoL2Client *TaikoL2ClientCallerSession) ParentTimestamp() (uint64, error) {
	return _TaikoL2Client.Contract.ParentTimestamp(&_TaikoL2Client.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_TaikoL2Client *TaikoL2ClientCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _TaikoL2Client.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_TaikoL2Client *TaikoL2ClientSession) Paused() (bool, error) {
	return _TaikoL2Client.Contract.Paused(&_TaikoL2Client.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_TaikoL2Client *TaikoL2ClientCallerSession) Paused() (bool, error) {
	return _TaikoL2Client.Contract.Paused(&_TaikoL2Client.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_TaikoL2Client *TaikoL2ClientCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoL2Client.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_TaikoL2Client *TaikoL2ClientSession) PendingOwner() (common.Address, error) {
	return _TaikoL2Client.Contract.PendingOwner(&_TaikoL2Client.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_TaikoL2Client *TaikoL2ClientCallerSession) PendingOwner() (common.Address, error) {
	return _TaikoL2Client.Contract.PendingOwner(&_TaikoL2Client.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_TaikoL2Client *TaikoL2ClientCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _TaikoL2Client.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_TaikoL2Client *TaikoL2ClientSession) ProxiableUUID() ([32]byte, error) {
	return _TaikoL2Client.Contract.ProxiableUUID(&_TaikoL2Client.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_TaikoL2Client *TaikoL2ClientCallerSession) ProxiableUUID() ([32]byte, error) {
	return _TaikoL2Client.Contract.ProxiableUUID(&_TaikoL2Client.CallOpts)
}

// PublicInputHash is a free data retrieval call binding the contract method 0xdac5df78.
//
// Solidity: function publicInputHash() view returns(bytes32)
func (_TaikoL2Client *TaikoL2ClientCaller) PublicInputHash(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _TaikoL2Client.contract.Call(opts, &out, "publicInputHash")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// PublicInputHash is a free data retrieval call binding the contract method 0xdac5df78.
//
// Solidity: function publicInputHash() view returns(bytes32)
func (_TaikoL2Client *TaikoL2ClientSession) PublicInputHash() ([32]byte, error) {
	return _TaikoL2Client.Contract.PublicInputHash(&_TaikoL2Client.CallOpts)
}

// PublicInputHash is a free data retrieval call binding the contract method 0xdac5df78.
//
// Solidity: function publicInputHash() view returns(bytes32)
func (_TaikoL2Client *TaikoL2ClientCallerSession) PublicInputHash() ([32]byte, error) {
	return _TaikoL2Client.Contract.PublicInputHash(&_TaikoL2Client.CallOpts)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_TaikoL2Client *TaikoL2ClientCaller) Resolve(opts *bind.CallOpts, _chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _TaikoL2Client.contract.Call(opts, &out, "resolve", _chainId, _name, _allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_TaikoL2Client *TaikoL2ClientSession) Resolve(_chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _TaikoL2Client.Contract.Resolve(&_TaikoL2Client.CallOpts, _chainId, _name, _allowZeroAddress)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_TaikoL2Client *TaikoL2ClientCallerSession) Resolve(_chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _TaikoL2Client.Contract.Resolve(&_TaikoL2Client.CallOpts, _chainId, _name, _allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_TaikoL2Client *TaikoL2ClientCaller) Resolve0(opts *bind.CallOpts, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _TaikoL2Client.contract.Call(opts, &out, "resolve0", _name, _allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_TaikoL2Client *TaikoL2ClientSession) Resolve0(_name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _TaikoL2Client.Contract.Resolve0(&_TaikoL2Client.CallOpts, _name, _allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_TaikoL2Client *TaikoL2ClientCallerSession) Resolve0(_name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _TaikoL2Client.Contract.Resolve0(&_TaikoL2Client.CallOpts, _name, _allowZeroAddress)
}

// SkipFeeCheck is a free data retrieval call binding the contract method 0x2f980473.
//
// Solidity: function skipFeeCheck() pure returns(bool)
func (_TaikoL2Client *TaikoL2ClientCaller) SkipFeeCheck(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _TaikoL2Client.contract.Call(opts, &out, "skipFeeCheck")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// SkipFeeCheck is a free data retrieval call binding the contract method 0x2f980473.
//
// Solidity: function skipFeeCheck() pure returns(bool)
func (_TaikoL2Client *TaikoL2ClientSession) SkipFeeCheck() (bool, error) {
	return _TaikoL2Client.Contract.SkipFeeCheck(&_TaikoL2Client.CallOpts)
}

// SkipFeeCheck is a free data retrieval call binding the contract method 0x2f980473.
//
// Solidity: function skipFeeCheck() pure returns(bool)
func (_TaikoL2Client *TaikoL2ClientCallerSession) SkipFeeCheck() (bool, error) {
	return _TaikoL2Client.Contract.SkipFeeCheck(&_TaikoL2Client.CallOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_TaikoL2Client *TaikoL2ClientTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL2Client.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_TaikoL2Client *TaikoL2ClientSession) AcceptOwnership() (*types.Transaction, error) {
	return _TaikoL2Client.Contract.AcceptOwnership(&_TaikoL2Client.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_TaikoL2Client *TaikoL2ClientTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _TaikoL2Client.Contract.AcceptOwnership(&_TaikoL2Client.TransactOpts)
}

// Anchor is a paid mutator transaction binding the contract method 0xda69d3db.
//
// Solidity: function anchor(bytes32 , bytes32 _l1StateRoot, uint64 _l1BlockId, uint32 _parentGasUsed) returns()
func (_TaikoL2Client *TaikoL2ClientTransactor) Anchor(opts *bind.TransactOpts, arg0 [32]byte, _l1StateRoot [32]byte, _l1BlockId uint64, _parentGasUsed uint32) (*types.Transaction, error) {
	return _TaikoL2Client.contract.Transact(opts, "anchor", arg0, _l1StateRoot, _l1BlockId, _parentGasUsed)
}

// Anchor is a paid mutator transaction binding the contract method 0xda69d3db.
//
// Solidity: function anchor(bytes32 , bytes32 _l1StateRoot, uint64 _l1BlockId, uint32 _parentGasUsed) returns()
func (_TaikoL2Client *TaikoL2ClientSession) Anchor(arg0 [32]byte, _l1StateRoot [32]byte, _l1BlockId uint64, _parentGasUsed uint32) (*types.Transaction, error) {
	return _TaikoL2Client.Contract.Anchor(&_TaikoL2Client.TransactOpts, arg0, _l1StateRoot, _l1BlockId, _parentGasUsed)
}

// Anchor is a paid mutator transaction binding the contract method 0xda69d3db.
//
// Solidity: function anchor(bytes32 , bytes32 _l1StateRoot, uint64 _l1BlockId, uint32 _parentGasUsed) returns()
func (_TaikoL2Client *TaikoL2ClientTransactorSession) Anchor(arg0 [32]byte, _l1StateRoot [32]byte, _l1BlockId uint64, _parentGasUsed uint32) (*types.Transaction, error) {
	return _TaikoL2Client.Contract.Anchor(&_TaikoL2Client.TransactOpts, arg0, _l1StateRoot, _l1BlockId, _parentGasUsed)
}

// AnchorV2 is a paid mutator transaction binding the contract method 0xfd85eb2d.
//
// Solidity: function anchorV2(uint64 _anchorBlockId, bytes32 _anchorStateRoot, uint32 _parentGasUsed, (uint8,uint8,uint32,uint64,uint32) _baseFeeConfig) returns()
func (_TaikoL2Client *TaikoL2ClientTransactor) AnchorV2(opts *bind.TransactOpts, _anchorBlockId uint64, _anchorStateRoot [32]byte, _parentGasUsed uint32, _baseFeeConfig TaikoDataBaseFeeConfig) (*types.Transaction, error) {
	return _TaikoL2Client.contract.Transact(opts, "anchorV2", _anchorBlockId, _anchorStateRoot, _parentGasUsed, _baseFeeConfig)
}

// AnchorV2 is a paid mutator transaction binding the contract method 0xfd85eb2d.
//
// Solidity: function anchorV2(uint64 _anchorBlockId, bytes32 _anchorStateRoot, uint32 _parentGasUsed, (uint8,uint8,uint32,uint64,uint32) _baseFeeConfig) returns()
func (_TaikoL2Client *TaikoL2ClientSession) AnchorV2(_anchorBlockId uint64, _anchorStateRoot [32]byte, _parentGasUsed uint32, _baseFeeConfig TaikoDataBaseFeeConfig) (*types.Transaction, error) {
	return _TaikoL2Client.Contract.AnchorV2(&_TaikoL2Client.TransactOpts, _anchorBlockId, _anchorStateRoot, _parentGasUsed, _baseFeeConfig)
}

// AnchorV2 is a paid mutator transaction binding the contract method 0xfd85eb2d.
//
// Solidity: function anchorV2(uint64 _anchorBlockId, bytes32 _anchorStateRoot, uint32 _parentGasUsed, (uint8,uint8,uint32,uint64,uint32) _baseFeeConfig) returns()
func (_TaikoL2Client *TaikoL2ClientTransactorSession) AnchorV2(_anchorBlockId uint64, _anchorStateRoot [32]byte, _parentGasUsed uint32, _baseFeeConfig TaikoDataBaseFeeConfig) (*types.Transaction, error) {
	return _TaikoL2Client.Contract.AnchorV2(&_TaikoL2Client.TransactOpts, _anchorBlockId, _anchorStateRoot, _parentGasUsed, _baseFeeConfig)
}

// Init is a paid mutator transaction binding the contract method 0x5950f9f1.
//
// Solidity: function init(address _owner, address _rollupAddressManager, uint64 _l1ChainId, uint64 _initialGasExcess) returns()
func (_TaikoL2Client *TaikoL2ClientTransactor) Init(opts *bind.TransactOpts, _owner common.Address, _rollupAddressManager common.Address, _l1ChainId uint64, _initialGasExcess uint64) (*types.Transaction, error) {
	return _TaikoL2Client.contract.Transact(opts, "init", _owner, _rollupAddressManager, _l1ChainId, _initialGasExcess)
}

// Init is a paid mutator transaction binding the contract method 0x5950f9f1.
//
// Solidity: function init(address _owner, address _rollupAddressManager, uint64 _l1ChainId, uint64 _initialGasExcess) returns()
func (_TaikoL2Client *TaikoL2ClientSession) Init(_owner common.Address, _rollupAddressManager common.Address, _l1ChainId uint64, _initialGasExcess uint64) (*types.Transaction, error) {
	return _TaikoL2Client.Contract.Init(&_TaikoL2Client.TransactOpts, _owner, _rollupAddressManager, _l1ChainId, _initialGasExcess)
}

// Init is a paid mutator transaction binding the contract method 0x5950f9f1.
//
// Solidity: function init(address _owner, address _rollupAddressManager, uint64 _l1ChainId, uint64 _initialGasExcess) returns()
func (_TaikoL2Client *TaikoL2ClientTransactorSession) Init(_owner common.Address, _rollupAddressManager common.Address, _l1ChainId uint64, _initialGasExcess uint64) (*types.Transaction, error) {
	return _TaikoL2Client.Contract.Init(&_TaikoL2Client.TransactOpts, _owner, _rollupAddressManager, _l1ChainId, _initialGasExcess)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_TaikoL2Client *TaikoL2ClientTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL2Client.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_TaikoL2Client *TaikoL2ClientSession) Pause() (*types.Transaction, error) {
	return _TaikoL2Client.Contract.Pause(&_TaikoL2Client.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_TaikoL2Client *TaikoL2ClientTransactorSession) Pause() (*types.Transaction, error) {
	return _TaikoL2Client.Contract.Pause(&_TaikoL2Client.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoL2Client *TaikoL2ClientTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL2Client.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoL2Client *TaikoL2ClientSession) RenounceOwnership() (*types.Transaction, error) {
	return _TaikoL2Client.Contract.RenounceOwnership(&_TaikoL2Client.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoL2Client *TaikoL2ClientTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _TaikoL2Client.Contract.RenounceOwnership(&_TaikoL2Client.TransactOpts)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoL2Client *TaikoL2ClientTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _TaikoL2Client.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoL2Client *TaikoL2ClientSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _TaikoL2Client.Contract.TransferOwnership(&_TaikoL2Client.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoL2Client *TaikoL2ClientTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _TaikoL2Client.Contract.TransferOwnership(&_TaikoL2Client.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_TaikoL2Client *TaikoL2ClientTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL2Client.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_TaikoL2Client *TaikoL2ClientSession) Unpause() (*types.Transaction, error) {
	return _TaikoL2Client.Contract.Unpause(&_TaikoL2Client.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_TaikoL2Client *TaikoL2ClientTransactorSession) Unpause() (*types.Transaction, error) {
	return _TaikoL2Client.Contract.Unpause(&_TaikoL2Client.TransactOpts)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_TaikoL2Client *TaikoL2ClientTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _TaikoL2Client.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_TaikoL2Client *TaikoL2ClientSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _TaikoL2Client.Contract.UpgradeTo(&_TaikoL2Client.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_TaikoL2Client *TaikoL2ClientTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _TaikoL2Client.Contract.UpgradeTo(&_TaikoL2Client.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_TaikoL2Client *TaikoL2ClientTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _TaikoL2Client.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_TaikoL2Client *TaikoL2ClientSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _TaikoL2Client.Contract.UpgradeToAndCall(&_TaikoL2Client.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_TaikoL2Client *TaikoL2ClientTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _TaikoL2Client.Contract.UpgradeToAndCall(&_TaikoL2Client.TransactOpts, newImplementation, data)
}

// Withdraw is a paid mutator transaction binding the contract method 0xf940e385.
//
// Solidity: function withdraw(address _token, address _to) returns()
func (_TaikoL2Client *TaikoL2ClientTransactor) Withdraw(opts *bind.TransactOpts, _token common.Address, _to common.Address) (*types.Transaction, error) {
	return _TaikoL2Client.contract.Transact(opts, "withdraw", _token, _to)
}

// Withdraw is a paid mutator transaction binding the contract method 0xf940e385.
//
// Solidity: function withdraw(address _token, address _to) returns()
func (_TaikoL2Client *TaikoL2ClientSession) Withdraw(_token common.Address, _to common.Address) (*types.Transaction, error) {
	return _TaikoL2Client.Contract.Withdraw(&_TaikoL2Client.TransactOpts, _token, _to)
}

// Withdraw is a paid mutator transaction binding the contract method 0xf940e385.
//
// Solidity: function withdraw(address _token, address _to) returns()
func (_TaikoL2Client *TaikoL2ClientTransactorSession) Withdraw(_token common.Address, _to common.Address) (*types.Transaction, error) {
	return _TaikoL2Client.Contract.Withdraw(&_TaikoL2Client.TransactOpts, _token, _to)
}

// TaikoL2ClientAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the TaikoL2Client contract.
type TaikoL2ClientAdminChangedIterator struct {
	Event *TaikoL2ClientAdminChanged // Event containing the contract specifics and raw log

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
func (it *TaikoL2ClientAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL2ClientAdminChanged)
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
		it.Event = new(TaikoL2ClientAdminChanged)
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
func (it *TaikoL2ClientAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL2ClientAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL2ClientAdminChanged represents a AdminChanged event raised by the TaikoL2Client contract.
type TaikoL2ClientAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_TaikoL2Client *TaikoL2ClientFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*TaikoL2ClientAdminChangedIterator, error) {

	logs, sub, err := _TaikoL2Client.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &TaikoL2ClientAdminChangedIterator{contract: _TaikoL2Client.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_TaikoL2Client *TaikoL2ClientFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *TaikoL2ClientAdminChanged) (event.Subscription, error) {

	logs, sub, err := _TaikoL2Client.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL2ClientAdminChanged)
				if err := _TaikoL2Client.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_TaikoL2Client *TaikoL2ClientFilterer) ParseAdminChanged(log types.Log) (*TaikoL2ClientAdminChanged, error) {
	event := new(TaikoL2ClientAdminChanged)
	if err := _TaikoL2Client.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL2ClientAnchoredIterator is returned from FilterAnchored and is used to iterate over the raw logs and unpacked data for Anchored events raised by the TaikoL2Client contract.
type TaikoL2ClientAnchoredIterator struct {
	Event *TaikoL2ClientAnchored // Event containing the contract specifics and raw log

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
func (it *TaikoL2ClientAnchoredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL2ClientAnchored)
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
		it.Event = new(TaikoL2ClientAnchored)
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
func (it *TaikoL2ClientAnchoredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL2ClientAnchoredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL2ClientAnchored represents a Anchored event raised by the TaikoL2Client contract.
type TaikoL2ClientAnchored struct {
	ParentHash      [32]byte
	ParentGasExcess uint64
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterAnchored is a free log retrieval operation binding the contract event 0x41c3f410f5c8ac36bb46b1dccef0de0f964087c9e688795fa02ecfa2c20b3fe4.
//
// Solidity: event Anchored(bytes32 parentHash, uint64 parentGasExcess)
func (_TaikoL2Client *TaikoL2ClientFilterer) FilterAnchored(opts *bind.FilterOpts) (*TaikoL2ClientAnchoredIterator, error) {

	logs, sub, err := _TaikoL2Client.contract.FilterLogs(opts, "Anchored")
	if err != nil {
		return nil, err
	}
	return &TaikoL2ClientAnchoredIterator{contract: _TaikoL2Client.contract, event: "Anchored", logs: logs, sub: sub}, nil
}

// WatchAnchored is a free log subscription operation binding the contract event 0x41c3f410f5c8ac36bb46b1dccef0de0f964087c9e688795fa02ecfa2c20b3fe4.
//
// Solidity: event Anchored(bytes32 parentHash, uint64 parentGasExcess)
func (_TaikoL2Client *TaikoL2ClientFilterer) WatchAnchored(opts *bind.WatchOpts, sink chan<- *TaikoL2ClientAnchored) (event.Subscription, error) {

	logs, sub, err := _TaikoL2Client.contract.WatchLogs(opts, "Anchored")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL2ClientAnchored)
				if err := _TaikoL2Client.contract.UnpackLog(event, "Anchored", log); err != nil {
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
// Solidity: event Anchored(bytes32 parentHash, uint64 parentGasExcess)
func (_TaikoL2Client *TaikoL2ClientFilterer) ParseAnchored(log types.Log) (*TaikoL2ClientAnchored, error) {
	event := new(TaikoL2ClientAnchored)
	if err := _TaikoL2Client.contract.UnpackLog(event, "Anchored", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL2ClientBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the TaikoL2Client contract.
type TaikoL2ClientBeaconUpgradedIterator struct {
	Event *TaikoL2ClientBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *TaikoL2ClientBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL2ClientBeaconUpgraded)
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
		it.Event = new(TaikoL2ClientBeaconUpgraded)
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
func (it *TaikoL2ClientBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL2ClientBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL2ClientBeaconUpgraded represents a BeaconUpgraded event raised by the TaikoL2Client contract.
type TaikoL2ClientBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_TaikoL2Client *TaikoL2ClientFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*TaikoL2ClientBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _TaikoL2Client.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL2ClientBeaconUpgradedIterator{contract: _TaikoL2Client.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_TaikoL2Client *TaikoL2ClientFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *TaikoL2ClientBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _TaikoL2Client.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL2ClientBeaconUpgraded)
				if err := _TaikoL2Client.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_TaikoL2Client *TaikoL2ClientFilterer) ParseBeaconUpgraded(log types.Log) (*TaikoL2ClientBeaconUpgraded, error) {
	event := new(TaikoL2ClientBeaconUpgraded)
	if err := _TaikoL2Client.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL2ClientInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the TaikoL2Client contract.
type TaikoL2ClientInitializedIterator struct {
	Event *TaikoL2ClientInitialized // Event containing the contract specifics and raw log

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
func (it *TaikoL2ClientInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL2ClientInitialized)
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
		it.Event = new(TaikoL2ClientInitialized)
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
func (it *TaikoL2ClientInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL2ClientInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL2ClientInitialized represents a Initialized event raised by the TaikoL2Client contract.
type TaikoL2ClientInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_TaikoL2Client *TaikoL2ClientFilterer) FilterInitialized(opts *bind.FilterOpts) (*TaikoL2ClientInitializedIterator, error) {

	logs, sub, err := _TaikoL2Client.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &TaikoL2ClientInitializedIterator{contract: _TaikoL2Client.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_TaikoL2Client *TaikoL2ClientFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *TaikoL2ClientInitialized) (event.Subscription, error) {

	logs, sub, err := _TaikoL2Client.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL2ClientInitialized)
				if err := _TaikoL2Client.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_TaikoL2Client *TaikoL2ClientFilterer) ParseInitialized(log types.Log) (*TaikoL2ClientInitialized, error) {
	event := new(TaikoL2ClientInitialized)
	if err := _TaikoL2Client.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL2ClientOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the TaikoL2Client contract.
type TaikoL2ClientOwnershipTransferStartedIterator struct {
	Event *TaikoL2ClientOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *TaikoL2ClientOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL2ClientOwnershipTransferStarted)
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
		it.Event = new(TaikoL2ClientOwnershipTransferStarted)
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
func (it *TaikoL2ClientOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL2ClientOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL2ClientOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the TaikoL2Client contract.
type TaikoL2ClientOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_TaikoL2Client *TaikoL2ClientFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*TaikoL2ClientOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoL2Client.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL2ClientOwnershipTransferStartedIterator{contract: _TaikoL2Client.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_TaikoL2Client *TaikoL2ClientFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *TaikoL2ClientOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoL2Client.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL2ClientOwnershipTransferStarted)
				if err := _TaikoL2Client.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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
func (_TaikoL2Client *TaikoL2ClientFilterer) ParseOwnershipTransferStarted(log types.Log) (*TaikoL2ClientOwnershipTransferStarted, error) {
	event := new(TaikoL2ClientOwnershipTransferStarted)
	if err := _TaikoL2Client.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL2ClientOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the TaikoL2Client contract.
type TaikoL2ClientOwnershipTransferredIterator struct {
	Event *TaikoL2ClientOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *TaikoL2ClientOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL2ClientOwnershipTransferred)
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
		it.Event = new(TaikoL2ClientOwnershipTransferred)
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
func (it *TaikoL2ClientOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL2ClientOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL2ClientOwnershipTransferred represents a OwnershipTransferred event raised by the TaikoL2Client contract.
type TaikoL2ClientOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_TaikoL2Client *TaikoL2ClientFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*TaikoL2ClientOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoL2Client.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL2ClientOwnershipTransferredIterator{contract: _TaikoL2Client.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_TaikoL2Client *TaikoL2ClientFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *TaikoL2ClientOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoL2Client.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL2ClientOwnershipTransferred)
				if err := _TaikoL2Client.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_TaikoL2Client *TaikoL2ClientFilterer) ParseOwnershipTransferred(log types.Log) (*TaikoL2ClientOwnershipTransferred, error) {
	event := new(TaikoL2ClientOwnershipTransferred)
	if err := _TaikoL2Client.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL2ClientPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the TaikoL2Client contract.
type TaikoL2ClientPausedIterator struct {
	Event *TaikoL2ClientPaused // Event containing the contract specifics and raw log

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
func (it *TaikoL2ClientPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL2ClientPaused)
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
		it.Event = new(TaikoL2ClientPaused)
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
func (it *TaikoL2ClientPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL2ClientPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL2ClientPaused represents a Paused event raised by the TaikoL2Client contract.
type TaikoL2ClientPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_TaikoL2Client *TaikoL2ClientFilterer) FilterPaused(opts *bind.FilterOpts) (*TaikoL2ClientPausedIterator, error) {

	logs, sub, err := _TaikoL2Client.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &TaikoL2ClientPausedIterator{contract: _TaikoL2Client.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_TaikoL2Client *TaikoL2ClientFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *TaikoL2ClientPaused) (event.Subscription, error) {

	logs, sub, err := _TaikoL2Client.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL2ClientPaused)
				if err := _TaikoL2Client.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_TaikoL2Client *TaikoL2ClientFilterer) ParsePaused(log types.Log) (*TaikoL2ClientPaused, error) {
	event := new(TaikoL2ClientPaused)
	if err := _TaikoL2Client.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL2ClientUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the TaikoL2Client contract.
type TaikoL2ClientUnpausedIterator struct {
	Event *TaikoL2ClientUnpaused // Event containing the contract specifics and raw log

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
func (it *TaikoL2ClientUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL2ClientUnpaused)
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
		it.Event = new(TaikoL2ClientUnpaused)
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
func (it *TaikoL2ClientUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL2ClientUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL2ClientUnpaused represents a Unpaused event raised by the TaikoL2Client contract.
type TaikoL2ClientUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_TaikoL2Client *TaikoL2ClientFilterer) FilterUnpaused(opts *bind.FilterOpts) (*TaikoL2ClientUnpausedIterator, error) {

	logs, sub, err := _TaikoL2Client.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &TaikoL2ClientUnpausedIterator{contract: _TaikoL2Client.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_TaikoL2Client *TaikoL2ClientFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *TaikoL2ClientUnpaused) (event.Subscription, error) {

	logs, sub, err := _TaikoL2Client.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL2ClientUnpaused)
				if err := _TaikoL2Client.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_TaikoL2Client *TaikoL2ClientFilterer) ParseUnpaused(log types.Log) (*TaikoL2ClientUnpaused, error) {
	event := new(TaikoL2ClientUnpaused)
	if err := _TaikoL2Client.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL2ClientUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the TaikoL2Client contract.
type TaikoL2ClientUpgradedIterator struct {
	Event *TaikoL2ClientUpgraded // Event containing the contract specifics and raw log

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
func (it *TaikoL2ClientUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL2ClientUpgraded)
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
		it.Event = new(TaikoL2ClientUpgraded)
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
func (it *TaikoL2ClientUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL2ClientUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL2ClientUpgraded represents a Upgraded event raised by the TaikoL2Client contract.
type TaikoL2ClientUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_TaikoL2Client *TaikoL2ClientFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*TaikoL2ClientUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _TaikoL2Client.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL2ClientUpgradedIterator{contract: _TaikoL2Client.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_TaikoL2Client *TaikoL2ClientFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *TaikoL2ClientUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _TaikoL2Client.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL2ClientUpgraded)
				if err := _TaikoL2Client.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_TaikoL2Client *TaikoL2ClientFilterer) ParseUpgraded(log types.Log) (*TaikoL2ClientUpgraded, error) {
	event := new(TaikoL2ClientUpgraded)
	if err := _TaikoL2Client.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
