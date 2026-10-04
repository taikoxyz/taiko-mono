// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package anchor

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

// AnchorBlockState is an auto generated low-level Go binding around an user-defined struct.
type AnchorBlockState struct {
	AnchorBlockNumber *big.Int
	AncestorsHash     [32]byte
}

// ICheckpointStoreCheckpoint is an auto generated low-level Go binding around an user-defined struct.
type ICheckpointStoreCheckpoint struct {
	BlockNumber *big.Int
	BlockHash   [32]byte
	StateRoot   [32]byte
}

// AnchorMetaData contains all meta data concerning the Anchor contract.
var AnchorMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"_checkpointStore\",\"type\":\"address\",\"internalType\":\"contractICheckpointStore\"},{\"name\":\"_l1ChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_etnaTimestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"ANCHOR_GAS_LIMIT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"BEACON_ROOTS\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"GOLDEN_TOUCH_ADDRESS\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"anchorV4\",\"inputs\":[{\"name\":\"_checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"blockHashes\",\"inputs\":[{\"name\":\"blockNumber\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"checkpointStore\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractICheckpointStore\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"etnaTimestamp\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getBlockState\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structAnchor.BlockState\",\"components\":[{\"name\":\"anchorBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"ancestorsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"impl\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inNonReentrant\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"l1ChainId\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolver\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"revealCheckpoint\",\"inputs\":[{\"name\":\"_l2Timestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_headerRlp\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"checkpoint_\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"withdraw\",\"inputs\":[{\"name\":\"_token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_to\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Anchored\",\"inputs\":[{\"name\":\"prevAnchorBlockNumber\",\"type\":\"uint48\",\"indexed\":false,\"internalType\":\"uint48\"},{\"name\":\"anchorBlockNumber\",\"type\":\"uint48\",\"indexed\":false,\"internalType\":\"uint48\"},{\"name\":\"ancestorsHash\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Withdrawn\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCESS_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AncestorsHashMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AnchorDisabled\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CheckpointConflict\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ContentLengthMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ETH_TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"EmptyItem\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FUNC_NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidAddress\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidDataRemainder\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidHeader\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidL1ChainId\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidL1Header\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidL2ChainId\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidSender\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1BlockHashNotFound\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UnexpectedList\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"UnexpectedString\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_VALUE\",\"inputs\":[]}]",
}

// AnchorABI is the input ABI used to generate the binding from.
// Deprecated: Use AnchorMetaData.ABI instead.
var AnchorABI = AnchorMetaData.ABI

// Anchor is an auto generated Go binding around an Ethereum contract.
type Anchor struct {
	AnchorCaller     // Read-only binding to the contract
	AnchorTransactor // Write-only binding to the contract
	AnchorFilterer   // Log filterer for contract events
}

// AnchorCaller is an auto generated read-only Go binding around an Ethereum contract.
type AnchorCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AnchorTransactor is an auto generated write-only Go binding around an Ethereum contract.
type AnchorTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AnchorFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type AnchorFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AnchorSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type AnchorSession struct {
	Contract     *Anchor           // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// AnchorCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type AnchorCallerSession struct {
	Contract *AnchorCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts // Call options to use throughout this session
}

// AnchorTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type AnchorTransactorSession struct {
	Contract     *AnchorTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// AnchorRaw is an auto generated low-level Go binding around an Ethereum contract.
type AnchorRaw struct {
	Contract *Anchor // Generic contract binding to access the raw methods on
}

// AnchorCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type AnchorCallerRaw struct {
	Contract *AnchorCaller // Generic read-only contract binding to access the raw methods on
}

// AnchorTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type AnchorTransactorRaw struct {
	Contract *AnchorTransactor // Generic write-only contract binding to access the raw methods on
}

// NewAnchor creates a new instance of Anchor, bound to a specific deployed contract.
func NewAnchor(address common.Address, backend bind.ContractBackend) (*Anchor, error) {
	contract, err := bindAnchor(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &Anchor{AnchorCaller: AnchorCaller{contract: contract}, AnchorTransactor: AnchorTransactor{contract: contract}, AnchorFilterer: AnchorFilterer{contract: contract}}, nil
}

// NewAnchorCaller creates a new read-only instance of Anchor, bound to a specific deployed contract.
func NewAnchorCaller(address common.Address, caller bind.ContractCaller) (*AnchorCaller, error) {
	contract, err := bindAnchor(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &AnchorCaller{contract: contract}, nil
}

// NewAnchorTransactor creates a new write-only instance of Anchor, bound to a specific deployed contract.
func NewAnchorTransactor(address common.Address, transactor bind.ContractTransactor) (*AnchorTransactor, error) {
	contract, err := bindAnchor(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &AnchorTransactor{contract: contract}, nil
}

// NewAnchorFilterer creates a new log filterer instance of Anchor, bound to a specific deployed contract.
func NewAnchorFilterer(address common.Address, filterer bind.ContractFilterer) (*AnchorFilterer, error) {
	contract, err := bindAnchor(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &AnchorFilterer{contract: contract}, nil
}

// bindAnchor binds a generic wrapper to an already deployed contract.
func bindAnchor(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := AnchorMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_Anchor *AnchorRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _Anchor.Contract.AnchorCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_Anchor *AnchorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Anchor.Contract.AnchorTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_Anchor *AnchorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _Anchor.Contract.AnchorTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_Anchor *AnchorCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _Anchor.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_Anchor *AnchorTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Anchor.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_Anchor *AnchorTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _Anchor.Contract.contract.Transact(opts, method, params...)
}

// ANCHORGASLIMIT is a free data retrieval call binding the contract method 0xc46e3a66.
//
// Solidity: function ANCHOR_GAS_LIMIT() view returns(uint64)
func (_Anchor *AnchorCaller) ANCHORGASLIMIT(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _Anchor.contract.Call(opts, &out, "ANCHOR_GAS_LIMIT")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// ANCHORGASLIMIT is a free data retrieval call binding the contract method 0xc46e3a66.
//
// Solidity: function ANCHOR_GAS_LIMIT() view returns(uint64)
func (_Anchor *AnchorSession) ANCHORGASLIMIT() (uint64, error) {
	return _Anchor.Contract.ANCHORGASLIMIT(&_Anchor.CallOpts)
}

// ANCHORGASLIMIT is a free data retrieval call binding the contract method 0xc46e3a66.
//
// Solidity: function ANCHOR_GAS_LIMIT() view returns(uint64)
func (_Anchor *AnchorCallerSession) ANCHORGASLIMIT() (uint64, error) {
	return _Anchor.Contract.ANCHORGASLIMIT(&_Anchor.CallOpts)
}

// BEACONROOTS is a free data retrieval call binding the contract method 0x56d7e8fd.
//
// Solidity: function BEACON_ROOTS() view returns(address)
func (_Anchor *AnchorCaller) BEACONROOTS(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _Anchor.contract.Call(opts, &out, "BEACON_ROOTS")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// BEACONROOTS is a free data retrieval call binding the contract method 0x56d7e8fd.
//
// Solidity: function BEACON_ROOTS() view returns(address)
func (_Anchor *AnchorSession) BEACONROOTS() (common.Address, error) {
	return _Anchor.Contract.BEACONROOTS(&_Anchor.CallOpts)
}

// BEACONROOTS is a free data retrieval call binding the contract method 0x56d7e8fd.
//
// Solidity: function BEACON_ROOTS() view returns(address)
func (_Anchor *AnchorCallerSession) BEACONROOTS() (common.Address, error) {
	return _Anchor.Contract.BEACONROOTS(&_Anchor.CallOpts)
}

// GOLDENTOUCHADDRESS is a free data retrieval call binding the contract method 0x9ee512f2.
//
// Solidity: function GOLDEN_TOUCH_ADDRESS() view returns(address)
func (_Anchor *AnchorCaller) GOLDENTOUCHADDRESS(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _Anchor.contract.Call(opts, &out, "GOLDEN_TOUCH_ADDRESS")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GOLDENTOUCHADDRESS is a free data retrieval call binding the contract method 0x9ee512f2.
//
// Solidity: function GOLDEN_TOUCH_ADDRESS() view returns(address)
func (_Anchor *AnchorSession) GOLDENTOUCHADDRESS() (common.Address, error) {
	return _Anchor.Contract.GOLDENTOUCHADDRESS(&_Anchor.CallOpts)
}

// GOLDENTOUCHADDRESS is a free data retrieval call binding the contract method 0x9ee512f2.
//
// Solidity: function GOLDEN_TOUCH_ADDRESS() view returns(address)
func (_Anchor *AnchorCallerSession) GOLDENTOUCHADDRESS() (common.Address, error) {
	return _Anchor.Contract.GOLDENTOUCHADDRESS(&_Anchor.CallOpts)
}

// BlockHashes is a free data retrieval call binding the contract method 0x34cdf78d.
//
// Solidity: function blockHashes(uint256 blockNumber) view returns(bytes32 blockHash)
func (_Anchor *AnchorCaller) BlockHashes(opts *bind.CallOpts, blockNumber *big.Int) ([32]byte, error) {
	var out []interface{}
	err := _Anchor.contract.Call(opts, &out, "blockHashes", blockNumber)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// BlockHashes is a free data retrieval call binding the contract method 0x34cdf78d.
//
// Solidity: function blockHashes(uint256 blockNumber) view returns(bytes32 blockHash)
func (_Anchor *AnchorSession) BlockHashes(blockNumber *big.Int) ([32]byte, error) {
	return _Anchor.Contract.BlockHashes(&_Anchor.CallOpts, blockNumber)
}

// BlockHashes is a free data retrieval call binding the contract method 0x34cdf78d.
//
// Solidity: function blockHashes(uint256 blockNumber) view returns(bytes32 blockHash)
func (_Anchor *AnchorCallerSession) BlockHashes(blockNumber *big.Int) ([32]byte, error) {
	return _Anchor.Contract.BlockHashes(&_Anchor.CallOpts, blockNumber)
}

// CheckpointStore is a free data retrieval call binding the contract method 0x955a7244.
//
// Solidity: function checkpointStore() view returns(address)
func (_Anchor *AnchorCaller) CheckpointStore(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _Anchor.contract.Call(opts, &out, "checkpointStore")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CheckpointStore is a free data retrieval call binding the contract method 0x955a7244.
//
// Solidity: function checkpointStore() view returns(address)
func (_Anchor *AnchorSession) CheckpointStore() (common.Address, error) {
	return _Anchor.Contract.CheckpointStore(&_Anchor.CallOpts)
}

// CheckpointStore is a free data retrieval call binding the contract method 0x955a7244.
//
// Solidity: function checkpointStore() view returns(address)
func (_Anchor *AnchorCallerSession) CheckpointStore() (common.Address, error) {
	return _Anchor.Contract.CheckpointStore(&_Anchor.CallOpts)
}

// EtnaTimestamp is a free data retrieval call binding the contract method 0x3b141589.
//
// Solidity: function etnaTimestamp() view returns(uint64)
func (_Anchor *AnchorCaller) EtnaTimestamp(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _Anchor.contract.Call(opts, &out, "etnaTimestamp")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// EtnaTimestamp is a free data retrieval call binding the contract method 0x3b141589.
//
// Solidity: function etnaTimestamp() view returns(uint64)
func (_Anchor *AnchorSession) EtnaTimestamp() (uint64, error) {
	return _Anchor.Contract.EtnaTimestamp(&_Anchor.CallOpts)
}

// EtnaTimestamp is a free data retrieval call binding the contract method 0x3b141589.
//
// Solidity: function etnaTimestamp() view returns(uint64)
func (_Anchor *AnchorCallerSession) EtnaTimestamp() (uint64, error) {
	return _Anchor.Contract.EtnaTimestamp(&_Anchor.CallOpts)
}

// GetBlockState is a free data retrieval call binding the contract method 0x0f439bd9.
//
// Solidity: function getBlockState() view returns((uint48,bytes32))
func (_Anchor *AnchorCaller) GetBlockState(opts *bind.CallOpts) (AnchorBlockState, error) {
	var out []interface{}
	err := _Anchor.contract.Call(opts, &out, "getBlockState")

	if err != nil {
		return *new(AnchorBlockState), err
	}

	out0 := *abi.ConvertType(out[0], new(AnchorBlockState)).(*AnchorBlockState)

	return out0, err

}

// GetBlockState is a free data retrieval call binding the contract method 0x0f439bd9.
//
// Solidity: function getBlockState() view returns((uint48,bytes32))
func (_Anchor *AnchorSession) GetBlockState() (AnchorBlockState, error) {
	return _Anchor.Contract.GetBlockState(&_Anchor.CallOpts)
}

// GetBlockState is a free data retrieval call binding the contract method 0x0f439bd9.
//
// Solidity: function getBlockState() view returns((uint48,bytes32))
func (_Anchor *AnchorCallerSession) GetBlockState() (AnchorBlockState, error) {
	return _Anchor.Contract.GetBlockState(&_Anchor.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_Anchor *AnchorCaller) Impl(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _Anchor.contract.Call(opts, &out, "impl")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_Anchor *AnchorSession) Impl() (common.Address, error) {
	return _Anchor.Contract.Impl(&_Anchor.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_Anchor *AnchorCallerSession) Impl() (common.Address, error) {
	return _Anchor.Contract.Impl(&_Anchor.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_Anchor *AnchorCaller) InNonReentrant(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _Anchor.contract.Call(opts, &out, "inNonReentrant")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_Anchor *AnchorSession) InNonReentrant() (bool, error) {
	return _Anchor.Contract.InNonReentrant(&_Anchor.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_Anchor *AnchorCallerSession) InNonReentrant() (bool, error) {
	return _Anchor.Contract.InNonReentrant(&_Anchor.CallOpts)
}

// L1ChainId is a free data retrieval call binding the contract method 0x12622e5b.
//
// Solidity: function l1ChainId() view returns(uint64)
func (_Anchor *AnchorCaller) L1ChainId(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _Anchor.contract.Call(opts, &out, "l1ChainId")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// L1ChainId is a free data retrieval call binding the contract method 0x12622e5b.
//
// Solidity: function l1ChainId() view returns(uint64)
func (_Anchor *AnchorSession) L1ChainId() (uint64, error) {
	return _Anchor.Contract.L1ChainId(&_Anchor.CallOpts)
}

// L1ChainId is a free data retrieval call binding the contract method 0x12622e5b.
//
// Solidity: function l1ChainId() view returns(uint64)
func (_Anchor *AnchorCallerSession) L1ChainId() (uint64, error) {
	return _Anchor.Contract.L1ChainId(&_Anchor.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_Anchor *AnchorCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _Anchor.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_Anchor *AnchorSession) Owner() (common.Address, error) {
	return _Anchor.Contract.Owner(&_Anchor.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_Anchor *AnchorCallerSession) Owner() (common.Address, error) {
	return _Anchor.Contract.Owner(&_Anchor.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_Anchor *AnchorCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _Anchor.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_Anchor *AnchorSession) Paused() (bool, error) {
	return _Anchor.Contract.Paused(&_Anchor.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_Anchor *AnchorCallerSession) Paused() (bool, error) {
	return _Anchor.Contract.Paused(&_Anchor.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_Anchor *AnchorCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _Anchor.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_Anchor *AnchorSession) PendingOwner() (common.Address, error) {
	return _Anchor.Contract.PendingOwner(&_Anchor.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_Anchor *AnchorCallerSession) PendingOwner() (common.Address, error) {
	return _Anchor.Contract.PendingOwner(&_Anchor.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_Anchor *AnchorCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _Anchor.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_Anchor *AnchorSession) ProxiableUUID() ([32]byte, error) {
	return _Anchor.Contract.ProxiableUUID(&_Anchor.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_Anchor *AnchorCallerSession) ProxiableUUID() ([32]byte, error) {
	return _Anchor.Contract.ProxiableUUID(&_Anchor.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_Anchor *AnchorCaller) Resolver(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _Anchor.contract.Call(opts, &out, "resolver")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_Anchor *AnchorSession) Resolver() (common.Address, error) {
	return _Anchor.Contract.Resolver(&_Anchor.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_Anchor *AnchorCallerSession) Resolver() (common.Address, error) {
	return _Anchor.Contract.Resolver(&_Anchor.CallOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_Anchor *AnchorTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Anchor.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_Anchor *AnchorSession) AcceptOwnership() (*types.Transaction, error) {
	return _Anchor.Contract.AcceptOwnership(&_Anchor.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_Anchor *AnchorTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _Anchor.Contract.AcceptOwnership(&_Anchor.TransactOpts)
}

// AnchorV4 is a paid mutator transaction binding the contract method 0x523e6854.
//
// Solidity: function anchorV4((uint48,bytes32,bytes32) _checkpoint) returns()
func (_Anchor *AnchorTransactor) AnchorV4(opts *bind.TransactOpts, _checkpoint ICheckpointStoreCheckpoint) (*types.Transaction, error) {
	return _Anchor.contract.Transact(opts, "anchorV4", _checkpoint)
}

// AnchorV4 is a paid mutator transaction binding the contract method 0x523e6854.
//
// Solidity: function anchorV4((uint48,bytes32,bytes32) _checkpoint) returns()
func (_Anchor *AnchorSession) AnchorV4(_checkpoint ICheckpointStoreCheckpoint) (*types.Transaction, error) {
	return _Anchor.Contract.AnchorV4(&_Anchor.TransactOpts, _checkpoint)
}

// AnchorV4 is a paid mutator transaction binding the contract method 0x523e6854.
//
// Solidity: function anchorV4((uint48,bytes32,bytes32) _checkpoint) returns()
func (_Anchor *AnchorTransactorSession) AnchorV4(_checkpoint ICheckpointStoreCheckpoint) (*types.Transaction, error) {
	return _Anchor.Contract.AnchorV4(&_Anchor.TransactOpts, _checkpoint)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_Anchor *AnchorTransactor) Init(opts *bind.TransactOpts, _owner common.Address) (*types.Transaction, error) {
	return _Anchor.contract.Transact(opts, "init", _owner)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_Anchor *AnchorSession) Init(_owner common.Address) (*types.Transaction, error) {
	return _Anchor.Contract.Init(&_Anchor.TransactOpts, _owner)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_Anchor *AnchorTransactorSession) Init(_owner common.Address) (*types.Transaction, error) {
	return _Anchor.Contract.Init(&_Anchor.TransactOpts, _owner)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_Anchor *AnchorTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Anchor.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_Anchor *AnchorSession) Pause() (*types.Transaction, error) {
	return _Anchor.Contract.Pause(&_Anchor.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_Anchor *AnchorTransactorSession) Pause() (*types.Transaction, error) {
	return _Anchor.Contract.Pause(&_Anchor.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_Anchor *AnchorTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Anchor.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_Anchor *AnchorSession) RenounceOwnership() (*types.Transaction, error) {
	return _Anchor.Contract.RenounceOwnership(&_Anchor.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_Anchor *AnchorTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _Anchor.Contract.RenounceOwnership(&_Anchor.TransactOpts)
}

// RevealCheckpoint is a paid mutator transaction binding the contract method 0x6c7d3fdf.
//
// Solidity: function revealCheckpoint(uint64 _l2Timestamp, bytes _headerRlp) returns((uint48,bytes32,bytes32) checkpoint_)
func (_Anchor *AnchorTransactor) RevealCheckpoint(opts *bind.TransactOpts, _l2Timestamp uint64, _headerRlp []byte) (*types.Transaction, error) {
	return _Anchor.contract.Transact(opts, "revealCheckpoint", _l2Timestamp, _headerRlp)
}

// RevealCheckpoint is a paid mutator transaction binding the contract method 0x6c7d3fdf.
//
// Solidity: function revealCheckpoint(uint64 _l2Timestamp, bytes _headerRlp) returns((uint48,bytes32,bytes32) checkpoint_)
func (_Anchor *AnchorSession) RevealCheckpoint(_l2Timestamp uint64, _headerRlp []byte) (*types.Transaction, error) {
	return _Anchor.Contract.RevealCheckpoint(&_Anchor.TransactOpts, _l2Timestamp, _headerRlp)
}

// RevealCheckpoint is a paid mutator transaction binding the contract method 0x6c7d3fdf.
//
// Solidity: function revealCheckpoint(uint64 _l2Timestamp, bytes _headerRlp) returns((uint48,bytes32,bytes32) checkpoint_)
func (_Anchor *AnchorTransactorSession) RevealCheckpoint(_l2Timestamp uint64, _headerRlp []byte) (*types.Transaction, error) {
	return _Anchor.Contract.RevealCheckpoint(&_Anchor.TransactOpts, _l2Timestamp, _headerRlp)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_Anchor *AnchorTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _Anchor.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_Anchor *AnchorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _Anchor.Contract.TransferOwnership(&_Anchor.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_Anchor *AnchorTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _Anchor.Contract.TransferOwnership(&_Anchor.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_Anchor *AnchorTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Anchor.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_Anchor *AnchorSession) Unpause() (*types.Transaction, error) {
	return _Anchor.Contract.Unpause(&_Anchor.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_Anchor *AnchorTransactorSession) Unpause() (*types.Transaction, error) {
	return _Anchor.Contract.Unpause(&_Anchor.TransactOpts)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_Anchor *AnchorTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _Anchor.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_Anchor *AnchorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _Anchor.Contract.UpgradeTo(&_Anchor.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_Anchor *AnchorTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _Anchor.Contract.UpgradeTo(&_Anchor.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_Anchor *AnchorTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _Anchor.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_Anchor *AnchorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _Anchor.Contract.UpgradeToAndCall(&_Anchor.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_Anchor *AnchorTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _Anchor.Contract.UpgradeToAndCall(&_Anchor.TransactOpts, newImplementation, data)
}

// Withdraw is a paid mutator transaction binding the contract method 0xf940e385.
//
// Solidity: function withdraw(address _token, address _to) returns()
func (_Anchor *AnchorTransactor) Withdraw(opts *bind.TransactOpts, _token common.Address, _to common.Address) (*types.Transaction, error) {
	return _Anchor.contract.Transact(opts, "withdraw", _token, _to)
}

// Withdraw is a paid mutator transaction binding the contract method 0xf940e385.
//
// Solidity: function withdraw(address _token, address _to) returns()
func (_Anchor *AnchorSession) Withdraw(_token common.Address, _to common.Address) (*types.Transaction, error) {
	return _Anchor.Contract.Withdraw(&_Anchor.TransactOpts, _token, _to)
}

// Withdraw is a paid mutator transaction binding the contract method 0xf940e385.
//
// Solidity: function withdraw(address _token, address _to) returns()
func (_Anchor *AnchorTransactorSession) Withdraw(_token common.Address, _to common.Address) (*types.Transaction, error) {
	return _Anchor.Contract.Withdraw(&_Anchor.TransactOpts, _token, _to)
}

// AnchorAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the Anchor contract.
type AnchorAdminChangedIterator struct {
	Event *AnchorAdminChanged // Event containing the contract specifics and raw log

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
func (it *AnchorAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AnchorAdminChanged)
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
		it.Event = new(AnchorAdminChanged)
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
func (it *AnchorAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AnchorAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AnchorAdminChanged represents a AdminChanged event raised by the Anchor contract.
type AnchorAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_Anchor *AnchorFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*AnchorAdminChangedIterator, error) {

	logs, sub, err := _Anchor.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &AnchorAdminChangedIterator{contract: _Anchor.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_Anchor *AnchorFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *AnchorAdminChanged) (event.Subscription, error) {

	logs, sub, err := _Anchor.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AnchorAdminChanged)
				if err := _Anchor.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_Anchor *AnchorFilterer) ParseAdminChanged(log types.Log) (*AnchorAdminChanged, error) {
	event := new(AnchorAdminChanged)
	if err := _Anchor.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AnchorAnchoredIterator is returned from FilterAnchored and is used to iterate over the raw logs and unpacked data for Anchored events raised by the Anchor contract.
type AnchorAnchoredIterator struct {
	Event *AnchorAnchored // Event containing the contract specifics and raw log

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
func (it *AnchorAnchoredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AnchorAnchored)
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
		it.Event = new(AnchorAnchored)
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
func (it *AnchorAnchoredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AnchorAnchoredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AnchorAnchored represents a Anchored event raised by the Anchor contract.
type AnchorAnchored struct {
	PrevAnchorBlockNumber *big.Int
	AnchorBlockNumber     *big.Int
	AncestorsHash         [32]byte
	Raw                   types.Log // Blockchain specific contextual infos
}

// FilterAnchored is a free log retrieval operation binding the contract event 0x7efb645089c13cff3d84f896f1bf50411e06ae8453a771bd7e3ea45ffb97ac38.
//
// Solidity: event Anchored(uint48 prevAnchorBlockNumber, uint48 anchorBlockNumber, bytes32 ancestorsHash)
func (_Anchor *AnchorFilterer) FilterAnchored(opts *bind.FilterOpts) (*AnchorAnchoredIterator, error) {

	logs, sub, err := _Anchor.contract.FilterLogs(opts, "Anchored")
	if err != nil {
		return nil, err
	}
	return &AnchorAnchoredIterator{contract: _Anchor.contract, event: "Anchored", logs: logs, sub: sub}, nil
}

// WatchAnchored is a free log subscription operation binding the contract event 0x7efb645089c13cff3d84f896f1bf50411e06ae8453a771bd7e3ea45ffb97ac38.
//
// Solidity: event Anchored(uint48 prevAnchorBlockNumber, uint48 anchorBlockNumber, bytes32 ancestorsHash)
func (_Anchor *AnchorFilterer) WatchAnchored(opts *bind.WatchOpts, sink chan<- *AnchorAnchored) (event.Subscription, error) {

	logs, sub, err := _Anchor.contract.WatchLogs(opts, "Anchored")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AnchorAnchored)
				if err := _Anchor.contract.UnpackLog(event, "Anchored", log); err != nil {
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

// ParseAnchored is a log parse operation binding the contract event 0x7efb645089c13cff3d84f896f1bf50411e06ae8453a771bd7e3ea45ffb97ac38.
//
// Solidity: event Anchored(uint48 prevAnchorBlockNumber, uint48 anchorBlockNumber, bytes32 ancestorsHash)
func (_Anchor *AnchorFilterer) ParseAnchored(log types.Log) (*AnchorAnchored, error) {
	event := new(AnchorAnchored)
	if err := _Anchor.contract.UnpackLog(event, "Anchored", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AnchorBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the Anchor contract.
type AnchorBeaconUpgradedIterator struct {
	Event *AnchorBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *AnchorBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AnchorBeaconUpgraded)
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
		it.Event = new(AnchorBeaconUpgraded)
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
func (it *AnchorBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AnchorBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AnchorBeaconUpgraded represents a BeaconUpgraded event raised by the Anchor contract.
type AnchorBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_Anchor *AnchorFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*AnchorBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _Anchor.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &AnchorBeaconUpgradedIterator{contract: _Anchor.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_Anchor *AnchorFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *AnchorBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _Anchor.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AnchorBeaconUpgraded)
				if err := _Anchor.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_Anchor *AnchorFilterer) ParseBeaconUpgraded(log types.Log) (*AnchorBeaconUpgraded, error) {
	event := new(AnchorBeaconUpgraded)
	if err := _Anchor.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AnchorInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the Anchor contract.
type AnchorInitializedIterator struct {
	Event *AnchorInitialized // Event containing the contract specifics and raw log

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
func (it *AnchorInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AnchorInitialized)
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
		it.Event = new(AnchorInitialized)
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
func (it *AnchorInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AnchorInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AnchorInitialized represents a Initialized event raised by the Anchor contract.
type AnchorInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_Anchor *AnchorFilterer) FilterInitialized(opts *bind.FilterOpts) (*AnchorInitializedIterator, error) {

	logs, sub, err := _Anchor.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &AnchorInitializedIterator{contract: _Anchor.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_Anchor *AnchorFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *AnchorInitialized) (event.Subscription, error) {

	logs, sub, err := _Anchor.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AnchorInitialized)
				if err := _Anchor.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_Anchor *AnchorFilterer) ParseInitialized(log types.Log) (*AnchorInitialized, error) {
	event := new(AnchorInitialized)
	if err := _Anchor.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AnchorOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the Anchor contract.
type AnchorOwnershipTransferStartedIterator struct {
	Event *AnchorOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *AnchorOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AnchorOwnershipTransferStarted)
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
		it.Event = new(AnchorOwnershipTransferStarted)
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
func (it *AnchorOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AnchorOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AnchorOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the Anchor contract.
type AnchorOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_Anchor *AnchorFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*AnchorOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _Anchor.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &AnchorOwnershipTransferStartedIterator{contract: _Anchor.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_Anchor *AnchorFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *AnchorOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _Anchor.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AnchorOwnershipTransferStarted)
				if err := _Anchor.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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
func (_Anchor *AnchorFilterer) ParseOwnershipTransferStarted(log types.Log) (*AnchorOwnershipTransferStarted, error) {
	event := new(AnchorOwnershipTransferStarted)
	if err := _Anchor.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AnchorOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the Anchor contract.
type AnchorOwnershipTransferredIterator struct {
	Event *AnchorOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *AnchorOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AnchorOwnershipTransferred)
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
		it.Event = new(AnchorOwnershipTransferred)
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
func (it *AnchorOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AnchorOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AnchorOwnershipTransferred represents a OwnershipTransferred event raised by the Anchor contract.
type AnchorOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_Anchor *AnchorFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*AnchorOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _Anchor.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &AnchorOwnershipTransferredIterator{contract: _Anchor.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_Anchor *AnchorFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *AnchorOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _Anchor.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AnchorOwnershipTransferred)
				if err := _Anchor.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_Anchor *AnchorFilterer) ParseOwnershipTransferred(log types.Log) (*AnchorOwnershipTransferred, error) {
	event := new(AnchorOwnershipTransferred)
	if err := _Anchor.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AnchorPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the Anchor contract.
type AnchorPausedIterator struct {
	Event *AnchorPaused // Event containing the contract specifics and raw log

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
func (it *AnchorPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AnchorPaused)
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
		it.Event = new(AnchorPaused)
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
func (it *AnchorPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AnchorPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AnchorPaused represents a Paused event raised by the Anchor contract.
type AnchorPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_Anchor *AnchorFilterer) FilterPaused(opts *bind.FilterOpts) (*AnchorPausedIterator, error) {

	logs, sub, err := _Anchor.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &AnchorPausedIterator{contract: _Anchor.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_Anchor *AnchorFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *AnchorPaused) (event.Subscription, error) {

	logs, sub, err := _Anchor.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AnchorPaused)
				if err := _Anchor.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_Anchor *AnchorFilterer) ParsePaused(log types.Log) (*AnchorPaused, error) {
	event := new(AnchorPaused)
	if err := _Anchor.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AnchorUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the Anchor contract.
type AnchorUnpausedIterator struct {
	Event *AnchorUnpaused // Event containing the contract specifics and raw log

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
func (it *AnchorUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AnchorUnpaused)
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
		it.Event = new(AnchorUnpaused)
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
func (it *AnchorUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AnchorUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AnchorUnpaused represents a Unpaused event raised by the Anchor contract.
type AnchorUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_Anchor *AnchorFilterer) FilterUnpaused(opts *bind.FilterOpts) (*AnchorUnpausedIterator, error) {

	logs, sub, err := _Anchor.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &AnchorUnpausedIterator{contract: _Anchor.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_Anchor *AnchorFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *AnchorUnpaused) (event.Subscription, error) {

	logs, sub, err := _Anchor.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AnchorUnpaused)
				if err := _Anchor.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_Anchor *AnchorFilterer) ParseUnpaused(log types.Log) (*AnchorUnpaused, error) {
	event := new(AnchorUnpaused)
	if err := _Anchor.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AnchorUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the Anchor contract.
type AnchorUpgradedIterator struct {
	Event *AnchorUpgraded // Event containing the contract specifics and raw log

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
func (it *AnchorUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AnchorUpgraded)
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
		it.Event = new(AnchorUpgraded)
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
func (it *AnchorUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AnchorUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AnchorUpgraded represents a Upgraded event raised by the Anchor contract.
type AnchorUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_Anchor *AnchorFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*AnchorUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _Anchor.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &AnchorUpgradedIterator{contract: _Anchor.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_Anchor *AnchorFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *AnchorUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _Anchor.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AnchorUpgraded)
				if err := _Anchor.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_Anchor *AnchorFilterer) ParseUpgraded(log types.Log) (*AnchorUpgraded, error) {
	event := new(AnchorUpgraded)
	if err := _Anchor.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AnchorWithdrawnIterator is returned from FilterWithdrawn and is used to iterate over the raw logs and unpacked data for Withdrawn events raised by the Anchor contract.
type AnchorWithdrawnIterator struct {
	Event *AnchorWithdrawn // Event containing the contract specifics and raw log

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
func (it *AnchorWithdrawnIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AnchorWithdrawn)
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
		it.Event = new(AnchorWithdrawn)
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
func (it *AnchorWithdrawnIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AnchorWithdrawnIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AnchorWithdrawn represents a Withdrawn event raised by the Anchor contract.
type AnchorWithdrawn struct {
	Token  common.Address
	To     common.Address
	Amount *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterWithdrawn is a free log retrieval operation binding the contract event 0xd1c19fbcd4551a5edfb66d43d2e337c04837afda3482b42bdf569a8fccdae5fb.
//
// Solidity: event Withdrawn(address token, address to, uint256 amount)
func (_Anchor *AnchorFilterer) FilterWithdrawn(opts *bind.FilterOpts) (*AnchorWithdrawnIterator, error) {

	logs, sub, err := _Anchor.contract.FilterLogs(opts, "Withdrawn")
	if err != nil {
		return nil, err
	}
	return &AnchorWithdrawnIterator{contract: _Anchor.contract, event: "Withdrawn", logs: logs, sub: sub}, nil
}

// WatchWithdrawn is a free log subscription operation binding the contract event 0xd1c19fbcd4551a5edfb66d43d2e337c04837afda3482b42bdf569a8fccdae5fb.
//
// Solidity: event Withdrawn(address token, address to, uint256 amount)
func (_Anchor *AnchorFilterer) WatchWithdrawn(opts *bind.WatchOpts, sink chan<- *AnchorWithdrawn) (event.Subscription, error) {

	logs, sub, err := _Anchor.contract.WatchLogs(opts, "Withdrawn")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AnchorWithdrawn)
				if err := _Anchor.contract.UnpackLog(event, "Withdrawn", log); err != nil {
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

// ParseWithdrawn is a log parse operation binding the contract event 0xd1c19fbcd4551a5edfb66d43d2e337c04837afda3482b42bdf569a8fccdae5fb.
//
// Solidity: event Withdrawn(address token, address to, uint256 amount)
func (_Anchor *AnchorFilterer) ParseWithdrawn(log types.Log) (*AnchorWithdrawn, error) {
	event := new(AnchorWithdrawn)
	if err := _Anchor.contract.UnpackLog(event, "Withdrawn", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
