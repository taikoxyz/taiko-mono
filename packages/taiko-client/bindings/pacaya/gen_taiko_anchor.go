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

// TaikoAnchorClientMetaData contains all meta data concerning the TaikoAnchorClient contract.
var TaikoAnchorClientMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"_resolver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_signalService\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_pacayaForkHeight\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"GOLDEN_TOUCH_ADDRESS\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"adjustExcess\",\"inputs\":[{\"name\":\"_currGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_currGasTarget\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_newGasTarget\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"outputs\":[{\"name\":\"newGasExcess_\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"anchor\",\"inputs\":[{\"name\":\"_l1BlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_l1StateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_l1BlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_parentGasUsed\",\"type\":\"uint32\",\"internalType\":\"uint32\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"anchorV2\",\"inputs\":[{\"name\":\"_anchorBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_anchorStateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_parentGasUsed\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"_baseFeeConfig\",\"type\":\"tuple\",\"internalType\":\"structLibSharedData.BaseFeeConfig\",\"components\":[{\"name\":\"adjustmentQuotient\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"gasIssuancePerSecond\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"minGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxGasIssuancePerBlock\",\"type\":\"uint32\",\"internalType\":\"uint32\"}]}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"anchorV3\",\"inputs\":[{\"name\":\"_anchorBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_anchorStateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_parentGasUsed\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"_baseFeeConfig\",\"type\":\"tuple\",\"internalType\":\"structLibSharedData.BaseFeeConfig\",\"components\":[{\"name\":\"adjustmentQuotient\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"gasIssuancePerSecond\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"minGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxGasIssuancePerBlock\",\"type\":\"uint32\",\"internalType\":\"uint32\"}]},{\"name\":\"_signalSlots\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"calculateBaseFee\",\"inputs\":[{\"name\":\"_baseFeeConfig\",\"type\":\"tuple\",\"internalType\":\"structLibSharedData.BaseFeeConfig\",\"components\":[{\"name\":\"adjustmentQuotient\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"gasIssuancePerSecond\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"minGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxGasIssuancePerBlock\",\"type\":\"uint32\",\"internalType\":\"uint32\"}]},{\"name\":\"_blocktime\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_parentGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_parentGasUsed\",\"type\":\"uint32\",\"internalType\":\"uint32\"}],\"outputs\":[{\"name\":\"basefee_\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"parentGasExcess_\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getBasefee\",\"inputs\":[{\"name\":\"_anchorBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_parentGasUsed\",\"type\":\"uint32\",\"internalType\":\"uint32\"}],\"outputs\":[{\"name\":\"basefee_\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"parentGasExcess_\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getBasefeeV2\",\"inputs\":[{\"name\":\"_parentGasUsed\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"_blockTimestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_baseFeeConfig\",\"type\":\"tuple\",\"internalType\":\"structLibSharedData.BaseFeeConfig\",\"components\":[{\"name\":\"adjustmentQuotient\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"gasIssuancePerSecond\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"minGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxGasIssuancePerBlock\",\"type\":\"uint32\",\"internalType\":\"uint32\"}]}],\"outputs\":[{\"name\":\"basefee_\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"newGasTarget_\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"newGasExcess_\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getBlockHash\",\"inputs\":[{\"name\":\"_blockId\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"impl\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inNonReentrant\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_l1ChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_initialGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isOnL1\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"l1ChainId\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"lastSyncedBlock\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pacayaForkHeight\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"parentGasExcess\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"parentGasTarget\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"parentTimestamp\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"publicInputHash\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolver\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"signalService\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISignalService\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"skipFeeCheck\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"withdraw\",\"inputs\":[{\"name\":\"_token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_to\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Anchored\",\"inputs\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"parentGasExcess\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"EIP1559Update\",\"inputs\":[{\"name\":\"oldGasTarget\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"},{\"name\":\"newGasTarget\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"},{\"name\":\"oldGasExcess\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"},{\"name\":\"newGasExcess\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"},{\"name\":\"basefee\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCESS_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ETH_TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FUNC_NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L2_BASEFEE_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L2_DEPRECATED_METHOD\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L2_FORK_ERROR\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L2_INVALID_L1_CHAIN_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L2_INVALID_L2_CHAIN_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L2_INVALID_SENDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L2_PUBLIC_INPUT_HASH_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L2_TOO_LATE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_VALUE\",\"inputs\":[]}]",
}

// TaikoAnchorClientABI is the input ABI used to generate the binding from.
// Deprecated: Use TaikoAnchorClientMetaData.ABI instead.
var TaikoAnchorClientABI = TaikoAnchorClientMetaData.ABI

// TaikoAnchorClient is an auto generated Go binding around an Ethereum contract.
type TaikoAnchorClient struct {
	TaikoAnchorClientCaller     // Read-only binding to the contract
	TaikoAnchorClientTransactor // Write-only binding to the contract
	TaikoAnchorClientFilterer   // Log filterer for contract events
}

// TaikoAnchorClientCaller is an auto generated read-only Go binding around an Ethereum contract.
type TaikoAnchorClientCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoAnchorClientTransactor is an auto generated write-only Go binding around an Ethereum contract.
type TaikoAnchorClientTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoAnchorClientFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type TaikoAnchorClientFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoAnchorClientSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type TaikoAnchorClientSession struct {
	Contract     *TaikoAnchorClient // Generic contract binding to set the session for
	CallOpts     bind.CallOpts      // Call options to use throughout this session
	TransactOpts bind.TransactOpts  // Transaction auth options to use throughout this session
}

// TaikoAnchorClientCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type TaikoAnchorClientCallerSession struct {
	Contract *TaikoAnchorClientCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts            // Call options to use throughout this session
}

// TaikoAnchorClientTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type TaikoAnchorClientTransactorSession struct {
	Contract     *TaikoAnchorClientTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts            // Transaction auth options to use throughout this session
}

// TaikoAnchorClientRaw is an auto generated low-level Go binding around an Ethereum contract.
type TaikoAnchorClientRaw struct {
	Contract *TaikoAnchorClient // Generic contract binding to access the raw methods on
}

// TaikoAnchorClientCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type TaikoAnchorClientCallerRaw struct {
	Contract *TaikoAnchorClientCaller // Generic read-only contract binding to access the raw methods on
}

// TaikoAnchorClientTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type TaikoAnchorClientTransactorRaw struct {
	Contract *TaikoAnchorClientTransactor // Generic write-only contract binding to access the raw methods on
}

// NewTaikoAnchorClient creates a new instance of TaikoAnchorClient, bound to a specific deployed contract.
func NewTaikoAnchorClient(address common.Address, backend bind.ContractBackend) (*TaikoAnchorClient, error) {
	contract, err := bindTaikoAnchorClient(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &TaikoAnchorClient{TaikoAnchorClientCaller: TaikoAnchorClientCaller{contract: contract}, TaikoAnchorClientTransactor: TaikoAnchorClientTransactor{contract: contract}, TaikoAnchorClientFilterer: TaikoAnchorClientFilterer{contract: contract}}, nil
}

// NewTaikoAnchorClientCaller creates a new read-only instance of TaikoAnchorClient, bound to a specific deployed contract.
func NewTaikoAnchorClientCaller(address common.Address, caller bind.ContractCaller) (*TaikoAnchorClientCaller, error) {
	contract, err := bindTaikoAnchorClient(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &TaikoAnchorClientCaller{contract: contract}, nil
}

// NewTaikoAnchorClientTransactor creates a new write-only instance of TaikoAnchorClient, bound to a specific deployed contract.
func NewTaikoAnchorClientTransactor(address common.Address, transactor bind.ContractTransactor) (*TaikoAnchorClientTransactor, error) {
	contract, err := bindTaikoAnchorClient(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &TaikoAnchorClientTransactor{contract: contract}, nil
}

// NewTaikoAnchorClientFilterer creates a new log filterer instance of TaikoAnchorClient, bound to a specific deployed contract.
func NewTaikoAnchorClientFilterer(address common.Address, filterer bind.ContractFilterer) (*TaikoAnchorClientFilterer, error) {
	contract, err := bindTaikoAnchorClient(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &TaikoAnchorClientFilterer{contract: contract}, nil
}

// bindTaikoAnchorClient binds a generic wrapper to an already deployed contract.
func bindTaikoAnchorClient(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := TaikoAnchorClientMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TaikoAnchorClient *TaikoAnchorClientRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TaikoAnchorClient.Contract.TaikoAnchorClientCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TaikoAnchorClient *TaikoAnchorClientRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.TaikoAnchorClientTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TaikoAnchorClient *TaikoAnchorClientRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.TaikoAnchorClientTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TaikoAnchorClient *TaikoAnchorClientCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TaikoAnchorClient.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TaikoAnchorClient *TaikoAnchorClientTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TaikoAnchorClient *TaikoAnchorClientTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.contract.Transact(opts, method, params...)
}

// GOLDENTOUCHADDRESS is a free data retrieval call binding the contract method 0x9ee512f2.
//
// Solidity: function GOLDEN_TOUCH_ADDRESS() view returns(address)
func (_TaikoAnchorClient *TaikoAnchorClientCaller) GOLDENTOUCHADDRESS(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoAnchorClient.contract.Call(opts, &out, "GOLDEN_TOUCH_ADDRESS")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GOLDENTOUCHADDRESS is a free data retrieval call binding the contract method 0x9ee512f2.
//
// Solidity: function GOLDEN_TOUCH_ADDRESS() view returns(address)
func (_TaikoAnchorClient *TaikoAnchorClientSession) GOLDENTOUCHADDRESS() (common.Address, error) {
	return _TaikoAnchorClient.Contract.GOLDENTOUCHADDRESS(&_TaikoAnchorClient.CallOpts)
}

// GOLDENTOUCHADDRESS is a free data retrieval call binding the contract method 0x9ee512f2.
//
// Solidity: function GOLDEN_TOUCH_ADDRESS() view returns(address)
func (_TaikoAnchorClient *TaikoAnchorClientCallerSession) GOLDENTOUCHADDRESS() (common.Address, error) {
	return _TaikoAnchorClient.Contract.GOLDENTOUCHADDRESS(&_TaikoAnchorClient.CallOpts)
}

// AdjustExcess is a free data retrieval call binding the contract method 0x136dc4a8.
//
// Solidity: function adjustExcess(uint64 _currGasExcess, uint64 _currGasTarget, uint64 _newGasTarget) pure returns(uint64 newGasExcess_)
func (_TaikoAnchorClient *TaikoAnchorClientCaller) AdjustExcess(opts *bind.CallOpts, _currGasExcess uint64, _currGasTarget uint64, _newGasTarget uint64) (uint64, error) {
	var out []interface{}
	err := _TaikoAnchorClient.contract.Call(opts, &out, "adjustExcess", _currGasExcess, _currGasTarget, _newGasTarget)

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// AdjustExcess is a free data retrieval call binding the contract method 0x136dc4a8.
//
// Solidity: function adjustExcess(uint64 _currGasExcess, uint64 _currGasTarget, uint64 _newGasTarget) pure returns(uint64 newGasExcess_)
func (_TaikoAnchorClient *TaikoAnchorClientSession) AdjustExcess(_currGasExcess uint64, _currGasTarget uint64, _newGasTarget uint64) (uint64, error) {
	return _TaikoAnchorClient.Contract.AdjustExcess(&_TaikoAnchorClient.CallOpts, _currGasExcess, _currGasTarget, _newGasTarget)
}

// AdjustExcess is a free data retrieval call binding the contract method 0x136dc4a8.
//
// Solidity: function adjustExcess(uint64 _currGasExcess, uint64 _currGasTarget, uint64 _newGasTarget) pure returns(uint64 newGasExcess_)
func (_TaikoAnchorClient *TaikoAnchorClientCallerSession) AdjustExcess(_currGasExcess uint64, _currGasTarget uint64, _newGasTarget uint64) (uint64, error) {
	return _TaikoAnchorClient.Contract.AdjustExcess(&_TaikoAnchorClient.CallOpts, _currGasExcess, _currGasTarget, _newGasTarget)
}

// CalculateBaseFee is a free data retrieval call binding the contract method 0xe902461a.
//
// Solidity: function calculateBaseFee((uint8,uint8,uint32,uint64,uint32) _baseFeeConfig, uint64 _blocktime, uint64 _parentGasExcess, uint32 _parentGasUsed) pure returns(uint256 basefee_, uint64 parentGasExcess_)
func (_TaikoAnchorClient *TaikoAnchorClientCaller) CalculateBaseFee(opts *bind.CallOpts, _baseFeeConfig LibSharedDataBaseFeeConfig, _blocktime uint64, _parentGasExcess uint64, _parentGasUsed uint32) (struct {
	Basefee         *big.Int
	ParentGasExcess uint64
}, error) {
	var out []interface{}
	err := _TaikoAnchorClient.contract.Call(opts, &out, "calculateBaseFee", _baseFeeConfig, _blocktime, _parentGasExcess, _parentGasUsed)

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
func (_TaikoAnchorClient *TaikoAnchorClientSession) CalculateBaseFee(_baseFeeConfig LibSharedDataBaseFeeConfig, _blocktime uint64, _parentGasExcess uint64, _parentGasUsed uint32) (struct {
	Basefee         *big.Int
	ParentGasExcess uint64
}, error) {
	return _TaikoAnchorClient.Contract.CalculateBaseFee(&_TaikoAnchorClient.CallOpts, _baseFeeConfig, _blocktime, _parentGasExcess, _parentGasUsed)
}

// CalculateBaseFee is a free data retrieval call binding the contract method 0xe902461a.
//
// Solidity: function calculateBaseFee((uint8,uint8,uint32,uint64,uint32) _baseFeeConfig, uint64 _blocktime, uint64 _parentGasExcess, uint32 _parentGasUsed) pure returns(uint256 basefee_, uint64 parentGasExcess_)
func (_TaikoAnchorClient *TaikoAnchorClientCallerSession) CalculateBaseFee(_baseFeeConfig LibSharedDataBaseFeeConfig, _blocktime uint64, _parentGasExcess uint64, _parentGasUsed uint32) (struct {
	Basefee         *big.Int
	ParentGasExcess uint64
}, error) {
	return _TaikoAnchorClient.Contract.CalculateBaseFee(&_TaikoAnchorClient.CallOpts, _baseFeeConfig, _blocktime, _parentGasExcess, _parentGasUsed)
}

// GetBasefee is a free data retrieval call binding the contract method 0xa7e022d1.
//
// Solidity: function getBasefee(uint64 _anchorBlockId, uint32 _parentGasUsed) pure returns(uint256 basefee_, uint64 parentGasExcess_)
func (_TaikoAnchorClient *TaikoAnchorClientCaller) GetBasefee(opts *bind.CallOpts, _anchorBlockId uint64, _parentGasUsed uint32) (struct {
	Basefee         *big.Int
	ParentGasExcess uint64
}, error) {
	var out []interface{}
	err := _TaikoAnchorClient.contract.Call(opts, &out, "getBasefee", _anchorBlockId, _parentGasUsed)

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
// Solidity: function getBasefee(uint64 _anchorBlockId, uint32 _parentGasUsed) pure returns(uint256 basefee_, uint64 parentGasExcess_)
func (_TaikoAnchorClient *TaikoAnchorClientSession) GetBasefee(_anchorBlockId uint64, _parentGasUsed uint32) (struct {
	Basefee         *big.Int
	ParentGasExcess uint64
}, error) {
	return _TaikoAnchorClient.Contract.GetBasefee(&_TaikoAnchorClient.CallOpts, _anchorBlockId, _parentGasUsed)
}

// GetBasefee is a free data retrieval call binding the contract method 0xa7e022d1.
//
// Solidity: function getBasefee(uint64 _anchorBlockId, uint32 _parentGasUsed) pure returns(uint256 basefee_, uint64 parentGasExcess_)
func (_TaikoAnchorClient *TaikoAnchorClientCallerSession) GetBasefee(_anchorBlockId uint64, _parentGasUsed uint32) (struct {
	Basefee         *big.Int
	ParentGasExcess uint64
}, error) {
	return _TaikoAnchorClient.Contract.GetBasefee(&_TaikoAnchorClient.CallOpts, _anchorBlockId, _parentGasUsed)
}

// GetBasefeeV2 is a free data retrieval call binding the contract method 0x893f5460.
//
// Solidity: function getBasefeeV2(uint32 _parentGasUsed, uint64 _blockTimestamp, (uint8,uint8,uint32,uint64,uint32) _baseFeeConfig) view returns(uint256 basefee_, uint64 newGasTarget_, uint64 newGasExcess_)
func (_TaikoAnchorClient *TaikoAnchorClientCaller) GetBasefeeV2(opts *bind.CallOpts, _parentGasUsed uint32, _blockTimestamp uint64, _baseFeeConfig LibSharedDataBaseFeeConfig) (struct {
	Basefee      *big.Int
	NewGasTarget uint64
	NewGasExcess uint64
}, error) {
	var out []interface{}
	err := _TaikoAnchorClient.contract.Call(opts, &out, "getBasefeeV2", _parentGasUsed, _blockTimestamp, _baseFeeConfig)

	outstruct := new(struct {
		Basefee      *big.Int
		NewGasTarget uint64
		NewGasExcess uint64
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Basefee = *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	outstruct.NewGasTarget = *abi.ConvertType(out[1], new(uint64)).(*uint64)
	outstruct.NewGasExcess = *abi.ConvertType(out[2], new(uint64)).(*uint64)

	return *outstruct, err

}

// GetBasefeeV2 is a free data retrieval call binding the contract method 0x893f5460.
//
// Solidity: function getBasefeeV2(uint32 _parentGasUsed, uint64 _blockTimestamp, (uint8,uint8,uint32,uint64,uint32) _baseFeeConfig) view returns(uint256 basefee_, uint64 newGasTarget_, uint64 newGasExcess_)
func (_TaikoAnchorClient *TaikoAnchorClientSession) GetBasefeeV2(_parentGasUsed uint32, _blockTimestamp uint64, _baseFeeConfig LibSharedDataBaseFeeConfig) (struct {
	Basefee      *big.Int
	NewGasTarget uint64
	NewGasExcess uint64
}, error) {
	return _TaikoAnchorClient.Contract.GetBasefeeV2(&_TaikoAnchorClient.CallOpts, _parentGasUsed, _blockTimestamp, _baseFeeConfig)
}

// GetBasefeeV2 is a free data retrieval call binding the contract method 0x893f5460.
//
// Solidity: function getBasefeeV2(uint32 _parentGasUsed, uint64 _blockTimestamp, (uint8,uint8,uint32,uint64,uint32) _baseFeeConfig) view returns(uint256 basefee_, uint64 newGasTarget_, uint64 newGasExcess_)
func (_TaikoAnchorClient *TaikoAnchorClientCallerSession) GetBasefeeV2(_parentGasUsed uint32, _blockTimestamp uint64, _baseFeeConfig LibSharedDataBaseFeeConfig) (struct {
	Basefee      *big.Int
	NewGasTarget uint64
	NewGasExcess uint64
}, error) {
	return _TaikoAnchorClient.Contract.GetBasefeeV2(&_TaikoAnchorClient.CallOpts, _parentGasUsed, _blockTimestamp, _baseFeeConfig)
}

// GetBlockHash is a free data retrieval call binding the contract method 0xee82ac5e.
//
// Solidity: function getBlockHash(uint256 _blockId) view returns(bytes32)
func (_TaikoAnchorClient *TaikoAnchorClientCaller) GetBlockHash(opts *bind.CallOpts, _blockId *big.Int) ([32]byte, error) {
	var out []interface{}
	err := _TaikoAnchorClient.contract.Call(opts, &out, "getBlockHash", _blockId)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetBlockHash is a free data retrieval call binding the contract method 0xee82ac5e.
//
// Solidity: function getBlockHash(uint256 _blockId) view returns(bytes32)
func (_TaikoAnchorClient *TaikoAnchorClientSession) GetBlockHash(_blockId *big.Int) ([32]byte, error) {
	return _TaikoAnchorClient.Contract.GetBlockHash(&_TaikoAnchorClient.CallOpts, _blockId)
}

// GetBlockHash is a free data retrieval call binding the contract method 0xee82ac5e.
//
// Solidity: function getBlockHash(uint256 _blockId) view returns(bytes32)
func (_TaikoAnchorClient *TaikoAnchorClientCallerSession) GetBlockHash(_blockId *big.Int) ([32]byte, error) {
	return _TaikoAnchorClient.Contract.GetBlockHash(&_TaikoAnchorClient.CallOpts, _blockId)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_TaikoAnchorClient *TaikoAnchorClientCaller) Impl(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoAnchorClient.contract.Call(opts, &out, "impl")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_TaikoAnchorClient *TaikoAnchorClientSession) Impl() (common.Address, error) {
	return _TaikoAnchorClient.Contract.Impl(&_TaikoAnchorClient.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_TaikoAnchorClient *TaikoAnchorClientCallerSession) Impl() (common.Address, error) {
	return _TaikoAnchorClient.Contract.Impl(&_TaikoAnchorClient.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_TaikoAnchorClient *TaikoAnchorClientCaller) InNonReentrant(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _TaikoAnchorClient.contract.Call(opts, &out, "inNonReentrant")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_TaikoAnchorClient *TaikoAnchorClientSession) InNonReentrant() (bool, error) {
	return _TaikoAnchorClient.Contract.InNonReentrant(&_TaikoAnchorClient.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_TaikoAnchorClient *TaikoAnchorClientCallerSession) InNonReentrant() (bool, error) {
	return _TaikoAnchorClient.Contract.InNonReentrant(&_TaikoAnchorClient.CallOpts)
}

// IsOnL1 is a free data retrieval call binding the contract method 0xa4b23554.
//
// Solidity: function isOnL1() pure returns(bool)
func (_TaikoAnchorClient *TaikoAnchorClientCaller) IsOnL1(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _TaikoAnchorClient.contract.Call(opts, &out, "isOnL1")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsOnL1 is a free data retrieval call binding the contract method 0xa4b23554.
//
// Solidity: function isOnL1() pure returns(bool)
func (_TaikoAnchorClient *TaikoAnchorClientSession) IsOnL1() (bool, error) {
	return _TaikoAnchorClient.Contract.IsOnL1(&_TaikoAnchorClient.CallOpts)
}

// IsOnL1 is a free data retrieval call binding the contract method 0xa4b23554.
//
// Solidity: function isOnL1() pure returns(bool)
func (_TaikoAnchorClient *TaikoAnchorClientCallerSession) IsOnL1() (bool, error) {
	return _TaikoAnchorClient.Contract.IsOnL1(&_TaikoAnchorClient.CallOpts)
}

// L1ChainId is a free data retrieval call binding the contract method 0x12622e5b.
//
// Solidity: function l1ChainId() view returns(uint64)
func (_TaikoAnchorClient *TaikoAnchorClientCaller) L1ChainId(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _TaikoAnchorClient.contract.Call(opts, &out, "l1ChainId")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// L1ChainId is a free data retrieval call binding the contract method 0x12622e5b.
//
// Solidity: function l1ChainId() view returns(uint64)
func (_TaikoAnchorClient *TaikoAnchorClientSession) L1ChainId() (uint64, error) {
	return _TaikoAnchorClient.Contract.L1ChainId(&_TaikoAnchorClient.CallOpts)
}

// L1ChainId is a free data retrieval call binding the contract method 0x12622e5b.
//
// Solidity: function l1ChainId() view returns(uint64)
func (_TaikoAnchorClient *TaikoAnchorClientCallerSession) L1ChainId() (uint64, error) {
	return _TaikoAnchorClient.Contract.L1ChainId(&_TaikoAnchorClient.CallOpts)
}

// LastSyncedBlock is a free data retrieval call binding the contract method 0x33d5ac9b.
//
// Solidity: function lastSyncedBlock() view returns(uint64)
func (_TaikoAnchorClient *TaikoAnchorClientCaller) LastSyncedBlock(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _TaikoAnchorClient.contract.Call(opts, &out, "lastSyncedBlock")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// LastSyncedBlock is a free data retrieval call binding the contract method 0x33d5ac9b.
//
// Solidity: function lastSyncedBlock() view returns(uint64)
func (_TaikoAnchorClient *TaikoAnchorClientSession) LastSyncedBlock() (uint64, error) {
	return _TaikoAnchorClient.Contract.LastSyncedBlock(&_TaikoAnchorClient.CallOpts)
}

// LastSyncedBlock is a free data retrieval call binding the contract method 0x33d5ac9b.
//
// Solidity: function lastSyncedBlock() view returns(uint64)
func (_TaikoAnchorClient *TaikoAnchorClientCallerSession) LastSyncedBlock() (uint64, error) {
	return _TaikoAnchorClient.Contract.LastSyncedBlock(&_TaikoAnchorClient.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoAnchorClient *TaikoAnchorClientCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoAnchorClient.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoAnchorClient *TaikoAnchorClientSession) Owner() (common.Address, error) {
	return _TaikoAnchorClient.Contract.Owner(&_TaikoAnchorClient.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoAnchorClient *TaikoAnchorClientCallerSession) Owner() (common.Address, error) {
	return _TaikoAnchorClient.Contract.Owner(&_TaikoAnchorClient.CallOpts)
}

// PacayaForkHeight is a free data retrieval call binding the contract method 0xba9f41e8.
//
// Solidity: function pacayaForkHeight() view returns(uint64)
func (_TaikoAnchorClient *TaikoAnchorClientCaller) PacayaForkHeight(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _TaikoAnchorClient.contract.Call(opts, &out, "pacayaForkHeight")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// PacayaForkHeight is a free data retrieval call binding the contract method 0xba9f41e8.
//
// Solidity: function pacayaForkHeight() view returns(uint64)
func (_TaikoAnchorClient *TaikoAnchorClientSession) PacayaForkHeight() (uint64, error) {
	return _TaikoAnchorClient.Contract.PacayaForkHeight(&_TaikoAnchorClient.CallOpts)
}

// PacayaForkHeight is a free data retrieval call binding the contract method 0xba9f41e8.
//
// Solidity: function pacayaForkHeight() view returns(uint64)
func (_TaikoAnchorClient *TaikoAnchorClientCallerSession) PacayaForkHeight() (uint64, error) {
	return _TaikoAnchorClient.Contract.PacayaForkHeight(&_TaikoAnchorClient.CallOpts)
}

// ParentGasExcess is a free data retrieval call binding the contract method 0xb8c7b30c.
//
// Solidity: function parentGasExcess() view returns(uint64)
func (_TaikoAnchorClient *TaikoAnchorClientCaller) ParentGasExcess(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _TaikoAnchorClient.contract.Call(opts, &out, "parentGasExcess")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// ParentGasExcess is a free data retrieval call binding the contract method 0xb8c7b30c.
//
// Solidity: function parentGasExcess() view returns(uint64)
func (_TaikoAnchorClient *TaikoAnchorClientSession) ParentGasExcess() (uint64, error) {
	return _TaikoAnchorClient.Contract.ParentGasExcess(&_TaikoAnchorClient.CallOpts)
}

// ParentGasExcess is a free data retrieval call binding the contract method 0xb8c7b30c.
//
// Solidity: function parentGasExcess() view returns(uint64)
func (_TaikoAnchorClient *TaikoAnchorClientCallerSession) ParentGasExcess() (uint64, error) {
	return _TaikoAnchorClient.Contract.ParentGasExcess(&_TaikoAnchorClient.CallOpts)
}

// ParentGasTarget is a free data retrieval call binding the contract method 0xa7137c0f.
//
// Solidity: function parentGasTarget() view returns(uint64)
func (_TaikoAnchorClient *TaikoAnchorClientCaller) ParentGasTarget(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _TaikoAnchorClient.contract.Call(opts, &out, "parentGasTarget")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// ParentGasTarget is a free data retrieval call binding the contract method 0xa7137c0f.
//
// Solidity: function parentGasTarget() view returns(uint64)
func (_TaikoAnchorClient *TaikoAnchorClientSession) ParentGasTarget() (uint64, error) {
	return _TaikoAnchorClient.Contract.ParentGasTarget(&_TaikoAnchorClient.CallOpts)
}

// ParentGasTarget is a free data retrieval call binding the contract method 0xa7137c0f.
//
// Solidity: function parentGasTarget() view returns(uint64)
func (_TaikoAnchorClient *TaikoAnchorClientCallerSession) ParentGasTarget() (uint64, error) {
	return _TaikoAnchorClient.Contract.ParentGasTarget(&_TaikoAnchorClient.CallOpts)
}

// ParentTimestamp is a free data retrieval call binding the contract method 0x539b8ade.
//
// Solidity: function parentTimestamp() view returns(uint64)
func (_TaikoAnchorClient *TaikoAnchorClientCaller) ParentTimestamp(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _TaikoAnchorClient.contract.Call(opts, &out, "parentTimestamp")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// ParentTimestamp is a free data retrieval call binding the contract method 0x539b8ade.
//
// Solidity: function parentTimestamp() view returns(uint64)
func (_TaikoAnchorClient *TaikoAnchorClientSession) ParentTimestamp() (uint64, error) {
	return _TaikoAnchorClient.Contract.ParentTimestamp(&_TaikoAnchorClient.CallOpts)
}

// ParentTimestamp is a free data retrieval call binding the contract method 0x539b8ade.
//
// Solidity: function parentTimestamp() view returns(uint64)
func (_TaikoAnchorClient *TaikoAnchorClientCallerSession) ParentTimestamp() (uint64, error) {
	return _TaikoAnchorClient.Contract.ParentTimestamp(&_TaikoAnchorClient.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_TaikoAnchorClient *TaikoAnchorClientCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _TaikoAnchorClient.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_TaikoAnchorClient *TaikoAnchorClientSession) Paused() (bool, error) {
	return _TaikoAnchorClient.Contract.Paused(&_TaikoAnchorClient.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_TaikoAnchorClient *TaikoAnchorClientCallerSession) Paused() (bool, error) {
	return _TaikoAnchorClient.Contract.Paused(&_TaikoAnchorClient.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_TaikoAnchorClient *TaikoAnchorClientCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoAnchorClient.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_TaikoAnchorClient *TaikoAnchorClientSession) PendingOwner() (common.Address, error) {
	return _TaikoAnchorClient.Contract.PendingOwner(&_TaikoAnchorClient.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_TaikoAnchorClient *TaikoAnchorClientCallerSession) PendingOwner() (common.Address, error) {
	return _TaikoAnchorClient.Contract.PendingOwner(&_TaikoAnchorClient.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_TaikoAnchorClient *TaikoAnchorClientCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _TaikoAnchorClient.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_TaikoAnchorClient *TaikoAnchorClientSession) ProxiableUUID() ([32]byte, error) {
	return _TaikoAnchorClient.Contract.ProxiableUUID(&_TaikoAnchorClient.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_TaikoAnchorClient *TaikoAnchorClientCallerSession) ProxiableUUID() ([32]byte, error) {
	return _TaikoAnchorClient.Contract.ProxiableUUID(&_TaikoAnchorClient.CallOpts)
}

// PublicInputHash is a free data retrieval call binding the contract method 0xdac5df78.
//
// Solidity: function publicInputHash() view returns(bytes32)
func (_TaikoAnchorClient *TaikoAnchorClientCaller) PublicInputHash(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _TaikoAnchorClient.contract.Call(opts, &out, "publicInputHash")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// PublicInputHash is a free data retrieval call binding the contract method 0xdac5df78.
//
// Solidity: function publicInputHash() view returns(bytes32)
func (_TaikoAnchorClient *TaikoAnchorClientSession) PublicInputHash() ([32]byte, error) {
	return _TaikoAnchorClient.Contract.PublicInputHash(&_TaikoAnchorClient.CallOpts)
}

// PublicInputHash is a free data retrieval call binding the contract method 0xdac5df78.
//
// Solidity: function publicInputHash() view returns(bytes32)
func (_TaikoAnchorClient *TaikoAnchorClientCallerSession) PublicInputHash() ([32]byte, error) {
	return _TaikoAnchorClient.Contract.PublicInputHash(&_TaikoAnchorClient.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_TaikoAnchorClient *TaikoAnchorClientCaller) Resolver(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoAnchorClient.contract.Call(opts, &out, "resolver")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_TaikoAnchorClient *TaikoAnchorClientSession) Resolver() (common.Address, error) {
	return _TaikoAnchorClient.Contract.Resolver(&_TaikoAnchorClient.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_TaikoAnchorClient *TaikoAnchorClientCallerSession) Resolver() (common.Address, error) {
	return _TaikoAnchorClient.Contract.Resolver(&_TaikoAnchorClient.CallOpts)
}

// SignalService is a free data retrieval call binding the contract method 0x62d09453.
//
// Solidity: function signalService() view returns(address)
func (_TaikoAnchorClient *TaikoAnchorClientCaller) SignalService(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoAnchorClient.contract.Call(opts, &out, "signalService")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SignalService is a free data retrieval call binding the contract method 0x62d09453.
//
// Solidity: function signalService() view returns(address)
func (_TaikoAnchorClient *TaikoAnchorClientSession) SignalService() (common.Address, error) {
	return _TaikoAnchorClient.Contract.SignalService(&_TaikoAnchorClient.CallOpts)
}

// SignalService is a free data retrieval call binding the contract method 0x62d09453.
//
// Solidity: function signalService() view returns(address)
func (_TaikoAnchorClient *TaikoAnchorClientCallerSession) SignalService() (common.Address, error) {
	return _TaikoAnchorClient.Contract.SignalService(&_TaikoAnchorClient.CallOpts)
}

// SkipFeeCheck is a free data retrieval call binding the contract method 0x2f980473.
//
// Solidity: function skipFeeCheck() pure returns(bool)
func (_TaikoAnchorClient *TaikoAnchorClientCaller) SkipFeeCheck(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _TaikoAnchorClient.contract.Call(opts, &out, "skipFeeCheck")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// SkipFeeCheck is a free data retrieval call binding the contract method 0x2f980473.
//
// Solidity: function skipFeeCheck() pure returns(bool)
func (_TaikoAnchorClient *TaikoAnchorClientSession) SkipFeeCheck() (bool, error) {
	return _TaikoAnchorClient.Contract.SkipFeeCheck(&_TaikoAnchorClient.CallOpts)
}

// SkipFeeCheck is a free data retrieval call binding the contract method 0x2f980473.
//
// Solidity: function skipFeeCheck() pure returns(bool)
func (_TaikoAnchorClient *TaikoAnchorClientCallerSession) SkipFeeCheck() (bool, error) {
	return _TaikoAnchorClient.Contract.SkipFeeCheck(&_TaikoAnchorClient.CallOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_TaikoAnchorClient *TaikoAnchorClientTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoAnchorClient.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_TaikoAnchorClient *TaikoAnchorClientSession) AcceptOwnership() (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.AcceptOwnership(&_TaikoAnchorClient.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_TaikoAnchorClient *TaikoAnchorClientTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.AcceptOwnership(&_TaikoAnchorClient.TransactOpts)
}

// Anchor is a paid mutator transaction binding the contract method 0xda69d3db.
//
// Solidity: function anchor(bytes32 _l1BlockHash, bytes32 _l1StateRoot, uint64 _l1BlockId, uint32 _parentGasUsed) returns()
func (_TaikoAnchorClient *TaikoAnchorClientTransactor) Anchor(opts *bind.TransactOpts, _l1BlockHash [32]byte, _l1StateRoot [32]byte, _l1BlockId uint64, _parentGasUsed uint32) (*types.Transaction, error) {
	return _TaikoAnchorClient.contract.Transact(opts, "anchor", _l1BlockHash, _l1StateRoot, _l1BlockId, _parentGasUsed)
}

// Anchor is a paid mutator transaction binding the contract method 0xda69d3db.
//
// Solidity: function anchor(bytes32 _l1BlockHash, bytes32 _l1StateRoot, uint64 _l1BlockId, uint32 _parentGasUsed) returns()
func (_TaikoAnchorClient *TaikoAnchorClientSession) Anchor(_l1BlockHash [32]byte, _l1StateRoot [32]byte, _l1BlockId uint64, _parentGasUsed uint32) (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.Anchor(&_TaikoAnchorClient.TransactOpts, _l1BlockHash, _l1StateRoot, _l1BlockId, _parentGasUsed)
}

// Anchor is a paid mutator transaction binding the contract method 0xda69d3db.
//
// Solidity: function anchor(bytes32 _l1BlockHash, bytes32 _l1StateRoot, uint64 _l1BlockId, uint32 _parentGasUsed) returns()
func (_TaikoAnchorClient *TaikoAnchorClientTransactorSession) Anchor(_l1BlockHash [32]byte, _l1StateRoot [32]byte, _l1BlockId uint64, _parentGasUsed uint32) (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.Anchor(&_TaikoAnchorClient.TransactOpts, _l1BlockHash, _l1StateRoot, _l1BlockId, _parentGasUsed)
}

// AnchorV2 is a paid mutator transaction binding the contract method 0xfd85eb2d.
//
// Solidity: function anchorV2(uint64 _anchorBlockId, bytes32 _anchorStateRoot, uint32 _parentGasUsed, (uint8,uint8,uint32,uint64,uint32) _baseFeeConfig) returns()
func (_TaikoAnchorClient *TaikoAnchorClientTransactor) AnchorV2(opts *bind.TransactOpts, _anchorBlockId uint64, _anchorStateRoot [32]byte, _parentGasUsed uint32, _baseFeeConfig LibSharedDataBaseFeeConfig) (*types.Transaction, error) {
	return _TaikoAnchorClient.contract.Transact(opts, "anchorV2", _anchorBlockId, _anchorStateRoot, _parentGasUsed, _baseFeeConfig)
}

// AnchorV2 is a paid mutator transaction binding the contract method 0xfd85eb2d.
//
// Solidity: function anchorV2(uint64 _anchorBlockId, bytes32 _anchorStateRoot, uint32 _parentGasUsed, (uint8,uint8,uint32,uint64,uint32) _baseFeeConfig) returns()
func (_TaikoAnchorClient *TaikoAnchorClientSession) AnchorV2(_anchorBlockId uint64, _anchorStateRoot [32]byte, _parentGasUsed uint32, _baseFeeConfig LibSharedDataBaseFeeConfig) (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.AnchorV2(&_TaikoAnchorClient.TransactOpts, _anchorBlockId, _anchorStateRoot, _parentGasUsed, _baseFeeConfig)
}

// AnchorV2 is a paid mutator transaction binding the contract method 0xfd85eb2d.
//
// Solidity: function anchorV2(uint64 _anchorBlockId, bytes32 _anchorStateRoot, uint32 _parentGasUsed, (uint8,uint8,uint32,uint64,uint32) _baseFeeConfig) returns()
func (_TaikoAnchorClient *TaikoAnchorClientTransactorSession) AnchorV2(_anchorBlockId uint64, _anchorStateRoot [32]byte, _parentGasUsed uint32, _baseFeeConfig LibSharedDataBaseFeeConfig) (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.AnchorV2(&_TaikoAnchorClient.TransactOpts, _anchorBlockId, _anchorStateRoot, _parentGasUsed, _baseFeeConfig)
}

// AnchorV3 is a paid mutator transaction binding the contract method 0x48080a45.
//
// Solidity: function anchorV3(uint64 _anchorBlockId, bytes32 _anchorStateRoot, uint32 _parentGasUsed, (uint8,uint8,uint32,uint64,uint32) _baseFeeConfig, bytes32[] _signalSlots) returns()
func (_TaikoAnchorClient *TaikoAnchorClientTransactor) AnchorV3(opts *bind.TransactOpts, _anchorBlockId uint64, _anchorStateRoot [32]byte, _parentGasUsed uint32, _baseFeeConfig LibSharedDataBaseFeeConfig, _signalSlots [][32]byte) (*types.Transaction, error) {
	return _TaikoAnchorClient.contract.Transact(opts, "anchorV3", _anchorBlockId, _anchorStateRoot, _parentGasUsed, _baseFeeConfig, _signalSlots)
}

// AnchorV3 is a paid mutator transaction binding the contract method 0x48080a45.
//
// Solidity: function anchorV3(uint64 _anchorBlockId, bytes32 _anchorStateRoot, uint32 _parentGasUsed, (uint8,uint8,uint32,uint64,uint32) _baseFeeConfig, bytes32[] _signalSlots) returns()
func (_TaikoAnchorClient *TaikoAnchorClientSession) AnchorV3(_anchorBlockId uint64, _anchorStateRoot [32]byte, _parentGasUsed uint32, _baseFeeConfig LibSharedDataBaseFeeConfig, _signalSlots [][32]byte) (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.AnchorV3(&_TaikoAnchorClient.TransactOpts, _anchorBlockId, _anchorStateRoot, _parentGasUsed, _baseFeeConfig, _signalSlots)
}

// AnchorV3 is a paid mutator transaction binding the contract method 0x48080a45.
//
// Solidity: function anchorV3(uint64 _anchorBlockId, bytes32 _anchorStateRoot, uint32 _parentGasUsed, (uint8,uint8,uint32,uint64,uint32) _baseFeeConfig, bytes32[] _signalSlots) returns()
func (_TaikoAnchorClient *TaikoAnchorClientTransactorSession) AnchorV3(_anchorBlockId uint64, _anchorStateRoot [32]byte, _parentGasUsed uint32, _baseFeeConfig LibSharedDataBaseFeeConfig, _signalSlots [][32]byte) (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.AnchorV3(&_TaikoAnchorClient.TransactOpts, _anchorBlockId, _anchorStateRoot, _parentGasUsed, _baseFeeConfig, _signalSlots)
}

// Init is a paid mutator transaction binding the contract method 0xb310e9e9.
//
// Solidity: function init(address _owner, uint64 _l1ChainId, uint64 _initialGasExcess) returns()
func (_TaikoAnchorClient *TaikoAnchorClientTransactor) Init(opts *bind.TransactOpts, _owner common.Address, _l1ChainId uint64, _initialGasExcess uint64) (*types.Transaction, error) {
	return _TaikoAnchorClient.contract.Transact(opts, "init", _owner, _l1ChainId, _initialGasExcess)
}

// Init is a paid mutator transaction binding the contract method 0xb310e9e9.
//
// Solidity: function init(address _owner, uint64 _l1ChainId, uint64 _initialGasExcess) returns()
func (_TaikoAnchorClient *TaikoAnchorClientSession) Init(_owner common.Address, _l1ChainId uint64, _initialGasExcess uint64) (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.Init(&_TaikoAnchorClient.TransactOpts, _owner, _l1ChainId, _initialGasExcess)
}

// Init is a paid mutator transaction binding the contract method 0xb310e9e9.
//
// Solidity: function init(address _owner, uint64 _l1ChainId, uint64 _initialGasExcess) returns()
func (_TaikoAnchorClient *TaikoAnchorClientTransactorSession) Init(_owner common.Address, _l1ChainId uint64, _initialGasExcess uint64) (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.Init(&_TaikoAnchorClient.TransactOpts, _owner, _l1ChainId, _initialGasExcess)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_TaikoAnchorClient *TaikoAnchorClientTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoAnchorClient.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_TaikoAnchorClient *TaikoAnchorClientSession) Pause() (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.Pause(&_TaikoAnchorClient.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_TaikoAnchorClient *TaikoAnchorClientTransactorSession) Pause() (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.Pause(&_TaikoAnchorClient.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoAnchorClient *TaikoAnchorClientTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoAnchorClient.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoAnchorClient *TaikoAnchorClientSession) RenounceOwnership() (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.RenounceOwnership(&_TaikoAnchorClient.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoAnchorClient *TaikoAnchorClientTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.RenounceOwnership(&_TaikoAnchorClient.TransactOpts)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoAnchorClient *TaikoAnchorClientTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _TaikoAnchorClient.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoAnchorClient *TaikoAnchorClientSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.TransferOwnership(&_TaikoAnchorClient.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoAnchorClient *TaikoAnchorClientTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.TransferOwnership(&_TaikoAnchorClient.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_TaikoAnchorClient *TaikoAnchorClientTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoAnchorClient.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_TaikoAnchorClient *TaikoAnchorClientSession) Unpause() (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.Unpause(&_TaikoAnchorClient.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_TaikoAnchorClient *TaikoAnchorClientTransactorSession) Unpause() (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.Unpause(&_TaikoAnchorClient.TransactOpts)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_TaikoAnchorClient *TaikoAnchorClientTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _TaikoAnchorClient.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_TaikoAnchorClient *TaikoAnchorClientSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.UpgradeTo(&_TaikoAnchorClient.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_TaikoAnchorClient *TaikoAnchorClientTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.UpgradeTo(&_TaikoAnchorClient.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_TaikoAnchorClient *TaikoAnchorClientTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _TaikoAnchorClient.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_TaikoAnchorClient *TaikoAnchorClientSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.UpgradeToAndCall(&_TaikoAnchorClient.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_TaikoAnchorClient *TaikoAnchorClientTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.UpgradeToAndCall(&_TaikoAnchorClient.TransactOpts, newImplementation, data)
}

// Withdraw is a paid mutator transaction binding the contract method 0xf940e385.
//
// Solidity: function withdraw(address _token, address _to) returns()
func (_TaikoAnchorClient *TaikoAnchorClientTransactor) Withdraw(opts *bind.TransactOpts, _token common.Address, _to common.Address) (*types.Transaction, error) {
	return _TaikoAnchorClient.contract.Transact(opts, "withdraw", _token, _to)
}

// Withdraw is a paid mutator transaction binding the contract method 0xf940e385.
//
// Solidity: function withdraw(address _token, address _to) returns()
func (_TaikoAnchorClient *TaikoAnchorClientSession) Withdraw(_token common.Address, _to common.Address) (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.Withdraw(&_TaikoAnchorClient.TransactOpts, _token, _to)
}

// Withdraw is a paid mutator transaction binding the contract method 0xf940e385.
//
// Solidity: function withdraw(address _token, address _to) returns()
func (_TaikoAnchorClient *TaikoAnchorClientTransactorSession) Withdraw(_token common.Address, _to common.Address) (*types.Transaction, error) {
	return _TaikoAnchorClient.Contract.Withdraw(&_TaikoAnchorClient.TransactOpts, _token, _to)
}

// TaikoAnchorClientAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the TaikoAnchorClient contract.
type TaikoAnchorClientAdminChangedIterator struct {
	Event *TaikoAnchorClientAdminChanged // Event containing the contract specifics and raw log

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
func (it *TaikoAnchorClientAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoAnchorClientAdminChanged)
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
		it.Event = new(TaikoAnchorClientAdminChanged)
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
func (it *TaikoAnchorClientAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoAnchorClientAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoAnchorClientAdminChanged represents a AdminChanged event raised by the TaikoAnchorClient contract.
type TaikoAnchorClientAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*TaikoAnchorClientAdminChangedIterator, error) {

	logs, sub, err := _TaikoAnchorClient.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &TaikoAnchorClientAdminChangedIterator{contract: _TaikoAnchorClient.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *TaikoAnchorClientAdminChanged) (event.Subscription, error) {

	logs, sub, err := _TaikoAnchorClient.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoAnchorClientAdminChanged)
				if err := _TaikoAnchorClient.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) ParseAdminChanged(log types.Log) (*TaikoAnchorClientAdminChanged, error) {
	event := new(TaikoAnchorClientAdminChanged)
	if err := _TaikoAnchorClient.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoAnchorClientAnchoredIterator is returned from FilterAnchored and is used to iterate over the raw logs and unpacked data for Anchored events raised by the TaikoAnchorClient contract.
type TaikoAnchorClientAnchoredIterator struct {
	Event *TaikoAnchorClientAnchored // Event containing the contract specifics and raw log

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
func (it *TaikoAnchorClientAnchoredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoAnchorClientAnchored)
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
		it.Event = new(TaikoAnchorClientAnchored)
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
func (it *TaikoAnchorClientAnchoredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoAnchorClientAnchoredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoAnchorClientAnchored represents a Anchored event raised by the TaikoAnchorClient contract.
type TaikoAnchorClientAnchored struct {
	ParentHash      [32]byte
	ParentGasExcess uint64
	Raw             types.Log // Blockchain specific contextual infos
}

// FilterAnchored is a free log retrieval operation binding the contract event 0x41c3f410f5c8ac36bb46b1dccef0de0f964087c9e688795fa02ecfa2c20b3fe4.
//
// Solidity: event Anchored(bytes32 parentHash, uint64 parentGasExcess)
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) FilterAnchored(opts *bind.FilterOpts) (*TaikoAnchorClientAnchoredIterator, error) {

	logs, sub, err := _TaikoAnchorClient.contract.FilterLogs(opts, "Anchored")
	if err != nil {
		return nil, err
	}
	return &TaikoAnchorClientAnchoredIterator{contract: _TaikoAnchorClient.contract, event: "Anchored", logs: logs, sub: sub}, nil
}

// WatchAnchored is a free log subscription operation binding the contract event 0x41c3f410f5c8ac36bb46b1dccef0de0f964087c9e688795fa02ecfa2c20b3fe4.
//
// Solidity: event Anchored(bytes32 parentHash, uint64 parentGasExcess)
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) WatchAnchored(opts *bind.WatchOpts, sink chan<- *TaikoAnchorClientAnchored) (event.Subscription, error) {

	logs, sub, err := _TaikoAnchorClient.contract.WatchLogs(opts, "Anchored")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoAnchorClientAnchored)
				if err := _TaikoAnchorClient.contract.UnpackLog(event, "Anchored", log); err != nil {
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
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) ParseAnchored(log types.Log) (*TaikoAnchorClientAnchored, error) {
	event := new(TaikoAnchorClientAnchored)
	if err := _TaikoAnchorClient.contract.UnpackLog(event, "Anchored", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoAnchorClientBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the TaikoAnchorClient contract.
type TaikoAnchorClientBeaconUpgradedIterator struct {
	Event *TaikoAnchorClientBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *TaikoAnchorClientBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoAnchorClientBeaconUpgraded)
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
		it.Event = new(TaikoAnchorClientBeaconUpgraded)
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
func (it *TaikoAnchorClientBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoAnchorClientBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoAnchorClientBeaconUpgraded represents a BeaconUpgraded event raised by the TaikoAnchorClient contract.
type TaikoAnchorClientBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*TaikoAnchorClientBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _TaikoAnchorClient.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &TaikoAnchorClientBeaconUpgradedIterator{contract: _TaikoAnchorClient.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *TaikoAnchorClientBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _TaikoAnchorClient.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoAnchorClientBeaconUpgraded)
				if err := _TaikoAnchorClient.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) ParseBeaconUpgraded(log types.Log) (*TaikoAnchorClientBeaconUpgraded, error) {
	event := new(TaikoAnchorClientBeaconUpgraded)
	if err := _TaikoAnchorClient.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoAnchorClientEIP1559UpdateIterator is returned from FilterEIP1559Update and is used to iterate over the raw logs and unpacked data for EIP1559Update events raised by the TaikoAnchorClient contract.
type TaikoAnchorClientEIP1559UpdateIterator struct {
	Event *TaikoAnchorClientEIP1559Update // Event containing the contract specifics and raw log

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
func (it *TaikoAnchorClientEIP1559UpdateIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoAnchorClientEIP1559Update)
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
		it.Event = new(TaikoAnchorClientEIP1559Update)
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
func (it *TaikoAnchorClientEIP1559UpdateIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoAnchorClientEIP1559UpdateIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoAnchorClientEIP1559Update represents a EIP1559Update event raised by the TaikoAnchorClient contract.
type TaikoAnchorClientEIP1559Update struct {
	OldGasTarget uint64
	NewGasTarget uint64
	OldGasExcess uint64
	NewGasExcess uint64
	Basefee      *big.Int
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterEIP1559Update is a free log retrieval operation binding the contract event 0x781ae5c2215806150d5c71a4ed5336e5dc3ad32aef04fc0f626a6ee0c2f8d1c8.
//
// Solidity: event EIP1559Update(uint64 oldGasTarget, uint64 newGasTarget, uint64 oldGasExcess, uint64 newGasExcess, uint256 basefee)
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) FilterEIP1559Update(opts *bind.FilterOpts) (*TaikoAnchorClientEIP1559UpdateIterator, error) {

	logs, sub, err := _TaikoAnchorClient.contract.FilterLogs(opts, "EIP1559Update")
	if err != nil {
		return nil, err
	}
	return &TaikoAnchorClientEIP1559UpdateIterator{contract: _TaikoAnchorClient.contract, event: "EIP1559Update", logs: logs, sub: sub}, nil
}

// WatchEIP1559Update is a free log subscription operation binding the contract event 0x781ae5c2215806150d5c71a4ed5336e5dc3ad32aef04fc0f626a6ee0c2f8d1c8.
//
// Solidity: event EIP1559Update(uint64 oldGasTarget, uint64 newGasTarget, uint64 oldGasExcess, uint64 newGasExcess, uint256 basefee)
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) WatchEIP1559Update(opts *bind.WatchOpts, sink chan<- *TaikoAnchorClientEIP1559Update) (event.Subscription, error) {

	logs, sub, err := _TaikoAnchorClient.contract.WatchLogs(opts, "EIP1559Update")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoAnchorClientEIP1559Update)
				if err := _TaikoAnchorClient.contract.UnpackLog(event, "EIP1559Update", log); err != nil {
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

// ParseEIP1559Update is a log parse operation binding the contract event 0x781ae5c2215806150d5c71a4ed5336e5dc3ad32aef04fc0f626a6ee0c2f8d1c8.
//
// Solidity: event EIP1559Update(uint64 oldGasTarget, uint64 newGasTarget, uint64 oldGasExcess, uint64 newGasExcess, uint256 basefee)
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) ParseEIP1559Update(log types.Log) (*TaikoAnchorClientEIP1559Update, error) {
	event := new(TaikoAnchorClientEIP1559Update)
	if err := _TaikoAnchorClient.contract.UnpackLog(event, "EIP1559Update", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoAnchorClientInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the TaikoAnchorClient contract.
type TaikoAnchorClientInitializedIterator struct {
	Event *TaikoAnchorClientInitialized // Event containing the contract specifics and raw log

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
func (it *TaikoAnchorClientInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoAnchorClientInitialized)
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
		it.Event = new(TaikoAnchorClientInitialized)
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
func (it *TaikoAnchorClientInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoAnchorClientInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoAnchorClientInitialized represents a Initialized event raised by the TaikoAnchorClient contract.
type TaikoAnchorClientInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) FilterInitialized(opts *bind.FilterOpts) (*TaikoAnchorClientInitializedIterator, error) {

	logs, sub, err := _TaikoAnchorClient.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &TaikoAnchorClientInitializedIterator{contract: _TaikoAnchorClient.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *TaikoAnchorClientInitialized) (event.Subscription, error) {

	logs, sub, err := _TaikoAnchorClient.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoAnchorClientInitialized)
				if err := _TaikoAnchorClient.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) ParseInitialized(log types.Log) (*TaikoAnchorClientInitialized, error) {
	event := new(TaikoAnchorClientInitialized)
	if err := _TaikoAnchorClient.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoAnchorClientOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the TaikoAnchorClient contract.
type TaikoAnchorClientOwnershipTransferStartedIterator struct {
	Event *TaikoAnchorClientOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *TaikoAnchorClientOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoAnchorClientOwnershipTransferStarted)
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
		it.Event = new(TaikoAnchorClientOwnershipTransferStarted)
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
func (it *TaikoAnchorClientOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoAnchorClientOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoAnchorClientOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the TaikoAnchorClient contract.
type TaikoAnchorClientOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*TaikoAnchorClientOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoAnchorClient.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &TaikoAnchorClientOwnershipTransferStartedIterator{contract: _TaikoAnchorClient.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *TaikoAnchorClientOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoAnchorClient.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoAnchorClientOwnershipTransferStarted)
				if err := _TaikoAnchorClient.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) ParseOwnershipTransferStarted(log types.Log) (*TaikoAnchorClientOwnershipTransferStarted, error) {
	event := new(TaikoAnchorClientOwnershipTransferStarted)
	if err := _TaikoAnchorClient.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoAnchorClientOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the TaikoAnchorClient contract.
type TaikoAnchorClientOwnershipTransferredIterator struct {
	Event *TaikoAnchorClientOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *TaikoAnchorClientOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoAnchorClientOwnershipTransferred)
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
		it.Event = new(TaikoAnchorClientOwnershipTransferred)
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
func (it *TaikoAnchorClientOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoAnchorClientOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoAnchorClientOwnershipTransferred represents a OwnershipTransferred event raised by the TaikoAnchorClient contract.
type TaikoAnchorClientOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*TaikoAnchorClientOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoAnchorClient.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &TaikoAnchorClientOwnershipTransferredIterator{contract: _TaikoAnchorClient.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *TaikoAnchorClientOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoAnchorClient.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoAnchorClientOwnershipTransferred)
				if err := _TaikoAnchorClient.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) ParseOwnershipTransferred(log types.Log) (*TaikoAnchorClientOwnershipTransferred, error) {
	event := new(TaikoAnchorClientOwnershipTransferred)
	if err := _TaikoAnchorClient.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoAnchorClientPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the TaikoAnchorClient contract.
type TaikoAnchorClientPausedIterator struct {
	Event *TaikoAnchorClientPaused // Event containing the contract specifics and raw log

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
func (it *TaikoAnchorClientPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoAnchorClientPaused)
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
		it.Event = new(TaikoAnchorClientPaused)
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
func (it *TaikoAnchorClientPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoAnchorClientPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoAnchorClientPaused represents a Paused event raised by the TaikoAnchorClient contract.
type TaikoAnchorClientPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) FilterPaused(opts *bind.FilterOpts) (*TaikoAnchorClientPausedIterator, error) {

	logs, sub, err := _TaikoAnchorClient.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &TaikoAnchorClientPausedIterator{contract: _TaikoAnchorClient.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *TaikoAnchorClientPaused) (event.Subscription, error) {

	logs, sub, err := _TaikoAnchorClient.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoAnchorClientPaused)
				if err := _TaikoAnchorClient.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) ParsePaused(log types.Log) (*TaikoAnchorClientPaused, error) {
	event := new(TaikoAnchorClientPaused)
	if err := _TaikoAnchorClient.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoAnchorClientUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the TaikoAnchorClient contract.
type TaikoAnchorClientUnpausedIterator struct {
	Event *TaikoAnchorClientUnpaused // Event containing the contract specifics and raw log

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
func (it *TaikoAnchorClientUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoAnchorClientUnpaused)
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
		it.Event = new(TaikoAnchorClientUnpaused)
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
func (it *TaikoAnchorClientUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoAnchorClientUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoAnchorClientUnpaused represents a Unpaused event raised by the TaikoAnchorClient contract.
type TaikoAnchorClientUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) FilterUnpaused(opts *bind.FilterOpts) (*TaikoAnchorClientUnpausedIterator, error) {

	logs, sub, err := _TaikoAnchorClient.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &TaikoAnchorClientUnpausedIterator{contract: _TaikoAnchorClient.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *TaikoAnchorClientUnpaused) (event.Subscription, error) {

	logs, sub, err := _TaikoAnchorClient.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoAnchorClientUnpaused)
				if err := _TaikoAnchorClient.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) ParseUnpaused(log types.Log) (*TaikoAnchorClientUnpaused, error) {
	event := new(TaikoAnchorClientUnpaused)
	if err := _TaikoAnchorClient.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoAnchorClientUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the TaikoAnchorClient contract.
type TaikoAnchorClientUpgradedIterator struct {
	Event *TaikoAnchorClientUpgraded // Event containing the contract specifics and raw log

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
func (it *TaikoAnchorClientUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoAnchorClientUpgraded)
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
		it.Event = new(TaikoAnchorClientUpgraded)
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
func (it *TaikoAnchorClientUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoAnchorClientUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoAnchorClientUpgraded represents a Upgraded event raised by the TaikoAnchorClient contract.
type TaikoAnchorClientUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*TaikoAnchorClientUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _TaikoAnchorClient.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &TaikoAnchorClientUpgradedIterator{contract: _TaikoAnchorClient.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *TaikoAnchorClientUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _TaikoAnchorClient.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoAnchorClientUpgraded)
				if err := _TaikoAnchorClient.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_TaikoAnchorClient *TaikoAnchorClientFilterer) ParseUpgraded(log types.Log) (*TaikoAnchorClientUpgraded, error) {
	event := new(TaikoAnchorClientUpgraded)
	if err := _TaikoAnchorClient.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
