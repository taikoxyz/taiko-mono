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

// IForcedInclusionStoreForcedInclusion is an auto generated low-level Go binding around an user-defined struct.
type IForcedInclusionStoreForcedInclusion struct {
	BlobHash         [32]byte
	FeeInGwei        uint64
	CreatedAtBatchId uint64
	BlobByteOffset   uint32
	BlobByteSize     uint32
	BlobCreatedIn    uint64
}

// TaikoWrapperClientMetaData contains all meta data concerning the TaikoWrapperClient contract.
var TaikoWrapperClientMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"_inbox\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_forcedInclusionStore\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_preconfRouter\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"MIN_TXS_PER_FORCED_INCLUSION\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint16\",\"internalType\":\"uint16\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"forcedInclusionStore\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIForcedInclusionStore\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"impl\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inNonReentrant\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inbox\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIProposeBatch\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"preconfRouter\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proposeBatch\",\"inputs\":[{\"name\":\"_params\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"_txList\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.BatchInfo\",\"components\":[{\"name\":\"txsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blocks\",\"type\":\"tuple[]\",\"internalType\":\"structITaikoInbox.BlockParams[]\",\"components\":[{\"name\":\"numTransactions\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"timeShift\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"signalSlots\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}]},{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"extraData\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"coinbase\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"proposedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobCreatedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobByteOffset\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobByteSize\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"gasLimit\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"baseFee\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"lastBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastBlockTimestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"anchorBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"anchorBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"baseFeeConfig\",\"type\":\"tuple\",\"internalType\":\"structLibSharedData.BaseFeeConfig\",\"components\":[{\"name\":\"adjustmentQuotient\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"gasIssuancePerSecond\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"minGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxGasIssuancePerBlock\",\"type\":\"uint32\",\"internalType\":\"uint32\"}]}]},{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.BatchMetadata\",\"components\":[{\"name\":\"infoHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"batchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"proposedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolver\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ForcedInclusionProcessed\",\"inputs\":[{\"name\":\"\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structIForcedInclusionStore.ForcedInclusion\",\"components\":[{\"name\":\"blobHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"feeInGwei\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"createdAtBatchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobByteOffset\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobByteSize\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobCreatedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCESS_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FUNCTION_DISABLED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FUNC_NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidBlobByteOffset\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidBlobByteSize\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidBlobCreatedIn\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidBlobCreatedIn\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidBlobHash\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidBlobHashesSize\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidBlobParams\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidBlockSize\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidBlockTxs\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidProposer\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidSignalSlots\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidTimeShift\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"OldestForcedInclusionDue\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_VALUE\",\"inputs\":[]}]",
}

// TaikoWrapperClientABI is the input ABI used to generate the binding from.
// Deprecated: Use TaikoWrapperClientMetaData.ABI instead.
var TaikoWrapperClientABI = TaikoWrapperClientMetaData.ABI

// TaikoWrapperClient is an auto generated Go binding around an Ethereum contract.
type TaikoWrapperClient struct {
	TaikoWrapperClientCaller     // Read-only binding to the contract
	TaikoWrapperClientTransactor // Write-only binding to the contract
	TaikoWrapperClientFilterer   // Log filterer for contract events
}

// TaikoWrapperClientCaller is an auto generated read-only Go binding around an Ethereum contract.
type TaikoWrapperClientCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoWrapperClientTransactor is an auto generated write-only Go binding around an Ethereum contract.
type TaikoWrapperClientTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoWrapperClientFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type TaikoWrapperClientFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoWrapperClientSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type TaikoWrapperClientSession struct {
	Contract     *TaikoWrapperClient // Generic contract binding to set the session for
	CallOpts     bind.CallOpts       // Call options to use throughout this session
	TransactOpts bind.TransactOpts   // Transaction auth options to use throughout this session
}

// TaikoWrapperClientCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type TaikoWrapperClientCallerSession struct {
	Contract *TaikoWrapperClientCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts             // Call options to use throughout this session
}

// TaikoWrapperClientTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type TaikoWrapperClientTransactorSession struct {
	Contract     *TaikoWrapperClientTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts             // Transaction auth options to use throughout this session
}

// TaikoWrapperClientRaw is an auto generated low-level Go binding around an Ethereum contract.
type TaikoWrapperClientRaw struct {
	Contract *TaikoWrapperClient // Generic contract binding to access the raw methods on
}

// TaikoWrapperClientCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type TaikoWrapperClientCallerRaw struct {
	Contract *TaikoWrapperClientCaller // Generic read-only contract binding to access the raw methods on
}

// TaikoWrapperClientTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type TaikoWrapperClientTransactorRaw struct {
	Contract *TaikoWrapperClientTransactor // Generic write-only contract binding to access the raw methods on
}

// NewTaikoWrapperClient creates a new instance of TaikoWrapperClient, bound to a specific deployed contract.
func NewTaikoWrapperClient(address common.Address, backend bind.ContractBackend) (*TaikoWrapperClient, error) {
	contract, err := bindTaikoWrapperClient(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &TaikoWrapperClient{TaikoWrapperClientCaller: TaikoWrapperClientCaller{contract: contract}, TaikoWrapperClientTransactor: TaikoWrapperClientTransactor{contract: contract}, TaikoWrapperClientFilterer: TaikoWrapperClientFilterer{contract: contract}}, nil
}

// NewTaikoWrapperClientCaller creates a new read-only instance of TaikoWrapperClient, bound to a specific deployed contract.
func NewTaikoWrapperClientCaller(address common.Address, caller bind.ContractCaller) (*TaikoWrapperClientCaller, error) {
	contract, err := bindTaikoWrapperClient(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &TaikoWrapperClientCaller{contract: contract}, nil
}

// NewTaikoWrapperClientTransactor creates a new write-only instance of TaikoWrapperClient, bound to a specific deployed contract.
func NewTaikoWrapperClientTransactor(address common.Address, transactor bind.ContractTransactor) (*TaikoWrapperClientTransactor, error) {
	contract, err := bindTaikoWrapperClient(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &TaikoWrapperClientTransactor{contract: contract}, nil
}

// NewTaikoWrapperClientFilterer creates a new log filterer instance of TaikoWrapperClient, bound to a specific deployed contract.
func NewTaikoWrapperClientFilterer(address common.Address, filterer bind.ContractFilterer) (*TaikoWrapperClientFilterer, error) {
	contract, err := bindTaikoWrapperClient(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &TaikoWrapperClientFilterer{contract: contract}, nil
}

// bindTaikoWrapperClient binds a generic wrapper to an already deployed contract.
func bindTaikoWrapperClient(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := TaikoWrapperClientMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TaikoWrapperClient *TaikoWrapperClientRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TaikoWrapperClient.Contract.TaikoWrapperClientCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TaikoWrapperClient *TaikoWrapperClientRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoWrapperClient.Contract.TaikoWrapperClientTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TaikoWrapperClient *TaikoWrapperClientRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TaikoWrapperClient.Contract.TaikoWrapperClientTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TaikoWrapperClient *TaikoWrapperClientCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TaikoWrapperClient.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TaikoWrapperClient *TaikoWrapperClientTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoWrapperClient.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TaikoWrapperClient *TaikoWrapperClientTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TaikoWrapperClient.Contract.contract.Transact(opts, method, params...)
}

// MINTXSPERFORCEDINCLUSION is a free data retrieval call binding the contract method 0x936ee868.
//
// Solidity: function MIN_TXS_PER_FORCED_INCLUSION() view returns(uint16)
func (_TaikoWrapperClient *TaikoWrapperClientCaller) MINTXSPERFORCEDINCLUSION(opts *bind.CallOpts) (uint16, error) {
	var out []interface{}
	err := _TaikoWrapperClient.contract.Call(opts, &out, "MIN_TXS_PER_FORCED_INCLUSION")

	if err != nil {
		return *new(uint16), err
	}

	out0 := *abi.ConvertType(out[0], new(uint16)).(*uint16)

	return out0, err

}

// MINTXSPERFORCEDINCLUSION is a free data retrieval call binding the contract method 0x936ee868.
//
// Solidity: function MIN_TXS_PER_FORCED_INCLUSION() view returns(uint16)
func (_TaikoWrapperClient *TaikoWrapperClientSession) MINTXSPERFORCEDINCLUSION() (uint16, error) {
	return _TaikoWrapperClient.Contract.MINTXSPERFORCEDINCLUSION(&_TaikoWrapperClient.CallOpts)
}

// MINTXSPERFORCEDINCLUSION is a free data retrieval call binding the contract method 0x936ee868.
//
// Solidity: function MIN_TXS_PER_FORCED_INCLUSION() view returns(uint16)
func (_TaikoWrapperClient *TaikoWrapperClientCallerSession) MINTXSPERFORCEDINCLUSION() (uint16, error) {
	return _TaikoWrapperClient.Contract.MINTXSPERFORCEDINCLUSION(&_TaikoWrapperClient.CallOpts)
}

// ForcedInclusionStore is a free data retrieval call binding the contract method 0xf749e9d4.
//
// Solidity: function forcedInclusionStore() view returns(address)
func (_TaikoWrapperClient *TaikoWrapperClientCaller) ForcedInclusionStore(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoWrapperClient.contract.Call(opts, &out, "forcedInclusionStore")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// ForcedInclusionStore is a free data retrieval call binding the contract method 0xf749e9d4.
//
// Solidity: function forcedInclusionStore() view returns(address)
func (_TaikoWrapperClient *TaikoWrapperClientSession) ForcedInclusionStore() (common.Address, error) {
	return _TaikoWrapperClient.Contract.ForcedInclusionStore(&_TaikoWrapperClient.CallOpts)
}

// ForcedInclusionStore is a free data retrieval call binding the contract method 0xf749e9d4.
//
// Solidity: function forcedInclusionStore() view returns(address)
func (_TaikoWrapperClient *TaikoWrapperClientCallerSession) ForcedInclusionStore() (common.Address, error) {
	return _TaikoWrapperClient.Contract.ForcedInclusionStore(&_TaikoWrapperClient.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_TaikoWrapperClient *TaikoWrapperClientCaller) Impl(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoWrapperClient.contract.Call(opts, &out, "impl")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_TaikoWrapperClient *TaikoWrapperClientSession) Impl() (common.Address, error) {
	return _TaikoWrapperClient.Contract.Impl(&_TaikoWrapperClient.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_TaikoWrapperClient *TaikoWrapperClientCallerSession) Impl() (common.Address, error) {
	return _TaikoWrapperClient.Contract.Impl(&_TaikoWrapperClient.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_TaikoWrapperClient *TaikoWrapperClientCaller) InNonReentrant(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _TaikoWrapperClient.contract.Call(opts, &out, "inNonReentrant")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_TaikoWrapperClient *TaikoWrapperClientSession) InNonReentrant() (bool, error) {
	return _TaikoWrapperClient.Contract.InNonReentrant(&_TaikoWrapperClient.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_TaikoWrapperClient *TaikoWrapperClientCallerSession) InNonReentrant() (bool, error) {
	return _TaikoWrapperClient.Contract.InNonReentrant(&_TaikoWrapperClient.CallOpts)
}

// Inbox is a free data retrieval call binding the contract method 0xfb0e722b.
//
// Solidity: function inbox() view returns(address)
func (_TaikoWrapperClient *TaikoWrapperClientCaller) Inbox(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoWrapperClient.contract.Call(opts, &out, "inbox")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Inbox is a free data retrieval call binding the contract method 0xfb0e722b.
//
// Solidity: function inbox() view returns(address)
func (_TaikoWrapperClient *TaikoWrapperClientSession) Inbox() (common.Address, error) {
	return _TaikoWrapperClient.Contract.Inbox(&_TaikoWrapperClient.CallOpts)
}

// Inbox is a free data retrieval call binding the contract method 0xfb0e722b.
//
// Solidity: function inbox() view returns(address)
func (_TaikoWrapperClient *TaikoWrapperClientCallerSession) Inbox() (common.Address, error) {
	return _TaikoWrapperClient.Contract.Inbox(&_TaikoWrapperClient.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoWrapperClient *TaikoWrapperClientCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoWrapperClient.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoWrapperClient *TaikoWrapperClientSession) Owner() (common.Address, error) {
	return _TaikoWrapperClient.Contract.Owner(&_TaikoWrapperClient.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoWrapperClient *TaikoWrapperClientCallerSession) Owner() (common.Address, error) {
	return _TaikoWrapperClient.Contract.Owner(&_TaikoWrapperClient.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_TaikoWrapperClient *TaikoWrapperClientCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _TaikoWrapperClient.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_TaikoWrapperClient *TaikoWrapperClientSession) Paused() (bool, error) {
	return _TaikoWrapperClient.Contract.Paused(&_TaikoWrapperClient.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_TaikoWrapperClient *TaikoWrapperClientCallerSession) Paused() (bool, error) {
	return _TaikoWrapperClient.Contract.Paused(&_TaikoWrapperClient.CallOpts)
}

// PreconfRouter is a free data retrieval call binding the contract method 0xf4bb9077.
//
// Solidity: function preconfRouter() view returns(address)
func (_TaikoWrapperClient *TaikoWrapperClientCaller) PreconfRouter(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoWrapperClient.contract.Call(opts, &out, "preconfRouter")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PreconfRouter is a free data retrieval call binding the contract method 0xf4bb9077.
//
// Solidity: function preconfRouter() view returns(address)
func (_TaikoWrapperClient *TaikoWrapperClientSession) PreconfRouter() (common.Address, error) {
	return _TaikoWrapperClient.Contract.PreconfRouter(&_TaikoWrapperClient.CallOpts)
}

// PreconfRouter is a free data retrieval call binding the contract method 0xf4bb9077.
//
// Solidity: function preconfRouter() view returns(address)
func (_TaikoWrapperClient *TaikoWrapperClientCallerSession) PreconfRouter() (common.Address, error) {
	return _TaikoWrapperClient.Contract.PreconfRouter(&_TaikoWrapperClient.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_TaikoWrapperClient *TaikoWrapperClientCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _TaikoWrapperClient.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_TaikoWrapperClient *TaikoWrapperClientSession) ProxiableUUID() ([32]byte, error) {
	return _TaikoWrapperClient.Contract.ProxiableUUID(&_TaikoWrapperClient.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_TaikoWrapperClient *TaikoWrapperClientCallerSession) ProxiableUUID() ([32]byte, error) {
	return _TaikoWrapperClient.Contract.ProxiableUUID(&_TaikoWrapperClient.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_TaikoWrapperClient *TaikoWrapperClientCaller) Resolver(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoWrapperClient.contract.Call(opts, &out, "resolver")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_TaikoWrapperClient *TaikoWrapperClientSession) Resolver() (common.Address, error) {
	return _TaikoWrapperClient.Contract.Resolver(&_TaikoWrapperClient.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_TaikoWrapperClient *TaikoWrapperClientCallerSession) Resolver() (common.Address, error) {
	return _TaikoWrapperClient.Contract.Resolver(&_TaikoWrapperClient.CallOpts)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_TaikoWrapperClient *TaikoWrapperClientTransactor) Init(opts *bind.TransactOpts, _owner common.Address) (*types.Transaction, error) {
	return _TaikoWrapperClient.contract.Transact(opts, "init", _owner)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_TaikoWrapperClient *TaikoWrapperClientSession) Init(_owner common.Address) (*types.Transaction, error) {
	return _TaikoWrapperClient.Contract.Init(&_TaikoWrapperClient.TransactOpts, _owner)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_TaikoWrapperClient *TaikoWrapperClientTransactorSession) Init(_owner common.Address) (*types.Transaction, error) {
	return _TaikoWrapperClient.Contract.Init(&_TaikoWrapperClient.TransactOpts, _owner)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_TaikoWrapperClient *TaikoWrapperClientTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoWrapperClient.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_TaikoWrapperClient *TaikoWrapperClientSession) Pause() (*types.Transaction, error) {
	return _TaikoWrapperClient.Contract.Pause(&_TaikoWrapperClient.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_TaikoWrapperClient *TaikoWrapperClientTransactorSession) Pause() (*types.Transaction, error) {
	return _TaikoWrapperClient.Contract.Pause(&_TaikoWrapperClient.TransactOpts)
}

// ProposeBatch is a paid mutator transaction binding the contract method 0x47faad14.
//
// Solidity: function proposeBatch(bytes _params, bytes _txList) returns((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint64,uint32,uint32,uint32,uint96,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint32)), (bytes32,address,uint64,uint64))
func (_TaikoWrapperClient *TaikoWrapperClientTransactor) ProposeBatch(opts *bind.TransactOpts, _params []byte, _txList []byte) (*types.Transaction, error) {
	return _TaikoWrapperClient.contract.Transact(opts, "proposeBatch", _params, _txList)
}

// ProposeBatch is a paid mutator transaction binding the contract method 0x47faad14.
//
// Solidity: function proposeBatch(bytes _params, bytes _txList) returns((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint64,uint32,uint32,uint32,uint96,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint32)), (bytes32,address,uint64,uint64))
func (_TaikoWrapperClient *TaikoWrapperClientSession) ProposeBatch(_params []byte, _txList []byte) (*types.Transaction, error) {
	return _TaikoWrapperClient.Contract.ProposeBatch(&_TaikoWrapperClient.TransactOpts, _params, _txList)
}

// ProposeBatch is a paid mutator transaction binding the contract method 0x47faad14.
//
// Solidity: function proposeBatch(bytes _params, bytes _txList) returns((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint64,uint32,uint32,uint32,uint96,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint32)), (bytes32,address,uint64,uint64))
func (_TaikoWrapperClient *TaikoWrapperClientTransactorSession) ProposeBatch(_params []byte, _txList []byte) (*types.Transaction, error) {
	return _TaikoWrapperClient.Contract.ProposeBatch(&_TaikoWrapperClient.TransactOpts, _params, _txList)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoWrapperClient *TaikoWrapperClientTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoWrapperClient.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoWrapperClient *TaikoWrapperClientSession) RenounceOwnership() (*types.Transaction, error) {
	return _TaikoWrapperClient.Contract.RenounceOwnership(&_TaikoWrapperClient.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoWrapperClient *TaikoWrapperClientTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _TaikoWrapperClient.Contract.RenounceOwnership(&_TaikoWrapperClient.TransactOpts)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoWrapperClient *TaikoWrapperClientTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _TaikoWrapperClient.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoWrapperClient *TaikoWrapperClientSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _TaikoWrapperClient.Contract.TransferOwnership(&_TaikoWrapperClient.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoWrapperClient *TaikoWrapperClientTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _TaikoWrapperClient.Contract.TransferOwnership(&_TaikoWrapperClient.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_TaikoWrapperClient *TaikoWrapperClientTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoWrapperClient.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_TaikoWrapperClient *TaikoWrapperClientSession) Unpause() (*types.Transaction, error) {
	return _TaikoWrapperClient.Contract.Unpause(&_TaikoWrapperClient.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_TaikoWrapperClient *TaikoWrapperClientTransactorSession) Unpause() (*types.Transaction, error) {
	return _TaikoWrapperClient.Contract.Unpause(&_TaikoWrapperClient.TransactOpts)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_TaikoWrapperClient *TaikoWrapperClientTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _TaikoWrapperClient.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_TaikoWrapperClient *TaikoWrapperClientSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _TaikoWrapperClient.Contract.UpgradeTo(&_TaikoWrapperClient.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_TaikoWrapperClient *TaikoWrapperClientTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _TaikoWrapperClient.Contract.UpgradeTo(&_TaikoWrapperClient.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_TaikoWrapperClient *TaikoWrapperClientTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _TaikoWrapperClient.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_TaikoWrapperClient *TaikoWrapperClientSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _TaikoWrapperClient.Contract.UpgradeToAndCall(&_TaikoWrapperClient.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_TaikoWrapperClient *TaikoWrapperClientTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _TaikoWrapperClient.Contract.UpgradeToAndCall(&_TaikoWrapperClient.TransactOpts, newImplementation, data)
}

// TaikoWrapperClientAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the TaikoWrapperClient contract.
type TaikoWrapperClientAdminChangedIterator struct {
	Event *TaikoWrapperClientAdminChanged // Event containing the contract specifics and raw log

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
func (it *TaikoWrapperClientAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoWrapperClientAdminChanged)
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
		it.Event = new(TaikoWrapperClientAdminChanged)
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
func (it *TaikoWrapperClientAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoWrapperClientAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoWrapperClientAdminChanged represents a AdminChanged event raised by the TaikoWrapperClient contract.
type TaikoWrapperClientAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_TaikoWrapperClient *TaikoWrapperClientFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*TaikoWrapperClientAdminChangedIterator, error) {

	logs, sub, err := _TaikoWrapperClient.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &TaikoWrapperClientAdminChangedIterator{contract: _TaikoWrapperClient.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_TaikoWrapperClient *TaikoWrapperClientFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *TaikoWrapperClientAdminChanged) (event.Subscription, error) {

	logs, sub, err := _TaikoWrapperClient.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoWrapperClientAdminChanged)
				if err := _TaikoWrapperClient.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_TaikoWrapperClient *TaikoWrapperClientFilterer) ParseAdminChanged(log types.Log) (*TaikoWrapperClientAdminChanged, error) {
	event := new(TaikoWrapperClientAdminChanged)
	if err := _TaikoWrapperClient.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoWrapperClientBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the TaikoWrapperClient contract.
type TaikoWrapperClientBeaconUpgradedIterator struct {
	Event *TaikoWrapperClientBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *TaikoWrapperClientBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoWrapperClientBeaconUpgraded)
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
		it.Event = new(TaikoWrapperClientBeaconUpgraded)
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
func (it *TaikoWrapperClientBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoWrapperClientBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoWrapperClientBeaconUpgraded represents a BeaconUpgraded event raised by the TaikoWrapperClient contract.
type TaikoWrapperClientBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_TaikoWrapperClient *TaikoWrapperClientFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*TaikoWrapperClientBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _TaikoWrapperClient.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &TaikoWrapperClientBeaconUpgradedIterator{contract: _TaikoWrapperClient.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_TaikoWrapperClient *TaikoWrapperClientFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *TaikoWrapperClientBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _TaikoWrapperClient.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoWrapperClientBeaconUpgraded)
				if err := _TaikoWrapperClient.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_TaikoWrapperClient *TaikoWrapperClientFilterer) ParseBeaconUpgraded(log types.Log) (*TaikoWrapperClientBeaconUpgraded, error) {
	event := new(TaikoWrapperClientBeaconUpgraded)
	if err := _TaikoWrapperClient.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoWrapperClientForcedInclusionProcessedIterator is returned from FilterForcedInclusionProcessed and is used to iterate over the raw logs and unpacked data for ForcedInclusionProcessed events raised by the TaikoWrapperClient contract.
type TaikoWrapperClientForcedInclusionProcessedIterator struct {
	Event *TaikoWrapperClientForcedInclusionProcessed // Event containing the contract specifics and raw log

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
func (it *TaikoWrapperClientForcedInclusionProcessedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoWrapperClientForcedInclusionProcessed)
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
		it.Event = new(TaikoWrapperClientForcedInclusionProcessed)
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
func (it *TaikoWrapperClientForcedInclusionProcessedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoWrapperClientForcedInclusionProcessedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoWrapperClientForcedInclusionProcessed represents a ForcedInclusionProcessed event raised by the TaikoWrapperClient contract.
type TaikoWrapperClientForcedInclusionProcessed struct {
	Arg0 IForcedInclusionStoreForcedInclusion
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterForcedInclusionProcessed is a free log retrieval operation binding the contract event 0x0dfcd5ca69fd1388717b2c8957a5f27755c9f5255b01b4d48661eafcf91c146f.
//
// Solidity: event ForcedInclusionProcessed((bytes32,uint64,uint64,uint32,uint32,uint64) arg0)
func (_TaikoWrapperClient *TaikoWrapperClientFilterer) FilterForcedInclusionProcessed(opts *bind.FilterOpts) (*TaikoWrapperClientForcedInclusionProcessedIterator, error) {

	logs, sub, err := _TaikoWrapperClient.contract.FilterLogs(opts, "ForcedInclusionProcessed")
	if err != nil {
		return nil, err
	}
	return &TaikoWrapperClientForcedInclusionProcessedIterator{contract: _TaikoWrapperClient.contract, event: "ForcedInclusionProcessed", logs: logs, sub: sub}, nil
}

// WatchForcedInclusionProcessed is a free log subscription operation binding the contract event 0x0dfcd5ca69fd1388717b2c8957a5f27755c9f5255b01b4d48661eafcf91c146f.
//
// Solidity: event ForcedInclusionProcessed((bytes32,uint64,uint64,uint32,uint32,uint64) arg0)
func (_TaikoWrapperClient *TaikoWrapperClientFilterer) WatchForcedInclusionProcessed(opts *bind.WatchOpts, sink chan<- *TaikoWrapperClientForcedInclusionProcessed) (event.Subscription, error) {

	logs, sub, err := _TaikoWrapperClient.contract.WatchLogs(opts, "ForcedInclusionProcessed")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoWrapperClientForcedInclusionProcessed)
				if err := _TaikoWrapperClient.contract.UnpackLog(event, "ForcedInclusionProcessed", log); err != nil {
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

// ParseForcedInclusionProcessed is a log parse operation binding the contract event 0x0dfcd5ca69fd1388717b2c8957a5f27755c9f5255b01b4d48661eafcf91c146f.
//
// Solidity: event ForcedInclusionProcessed((bytes32,uint64,uint64,uint32,uint32,uint64) arg0)
func (_TaikoWrapperClient *TaikoWrapperClientFilterer) ParseForcedInclusionProcessed(log types.Log) (*TaikoWrapperClientForcedInclusionProcessed, error) {
	event := new(TaikoWrapperClientForcedInclusionProcessed)
	if err := _TaikoWrapperClient.contract.UnpackLog(event, "ForcedInclusionProcessed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoWrapperClientInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the TaikoWrapperClient contract.
type TaikoWrapperClientInitializedIterator struct {
	Event *TaikoWrapperClientInitialized // Event containing the contract specifics and raw log

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
func (it *TaikoWrapperClientInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoWrapperClientInitialized)
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
		it.Event = new(TaikoWrapperClientInitialized)
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
func (it *TaikoWrapperClientInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoWrapperClientInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoWrapperClientInitialized represents a Initialized event raised by the TaikoWrapperClient contract.
type TaikoWrapperClientInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_TaikoWrapperClient *TaikoWrapperClientFilterer) FilterInitialized(opts *bind.FilterOpts) (*TaikoWrapperClientInitializedIterator, error) {

	logs, sub, err := _TaikoWrapperClient.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &TaikoWrapperClientInitializedIterator{contract: _TaikoWrapperClient.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_TaikoWrapperClient *TaikoWrapperClientFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *TaikoWrapperClientInitialized) (event.Subscription, error) {

	logs, sub, err := _TaikoWrapperClient.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoWrapperClientInitialized)
				if err := _TaikoWrapperClient.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_TaikoWrapperClient *TaikoWrapperClientFilterer) ParseInitialized(log types.Log) (*TaikoWrapperClientInitialized, error) {
	event := new(TaikoWrapperClientInitialized)
	if err := _TaikoWrapperClient.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoWrapperClientOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the TaikoWrapperClient contract.
type TaikoWrapperClientOwnershipTransferredIterator struct {
	Event *TaikoWrapperClientOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *TaikoWrapperClientOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoWrapperClientOwnershipTransferred)
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
		it.Event = new(TaikoWrapperClientOwnershipTransferred)
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
func (it *TaikoWrapperClientOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoWrapperClientOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoWrapperClientOwnershipTransferred represents a OwnershipTransferred event raised by the TaikoWrapperClient contract.
type TaikoWrapperClientOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_TaikoWrapperClient *TaikoWrapperClientFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*TaikoWrapperClientOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoWrapperClient.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &TaikoWrapperClientOwnershipTransferredIterator{contract: _TaikoWrapperClient.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_TaikoWrapperClient *TaikoWrapperClientFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *TaikoWrapperClientOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoWrapperClient.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoWrapperClientOwnershipTransferred)
				if err := _TaikoWrapperClient.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_TaikoWrapperClient *TaikoWrapperClientFilterer) ParseOwnershipTransferred(log types.Log) (*TaikoWrapperClientOwnershipTransferred, error) {
	event := new(TaikoWrapperClientOwnershipTransferred)
	if err := _TaikoWrapperClient.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoWrapperClientPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the TaikoWrapperClient contract.
type TaikoWrapperClientPausedIterator struct {
	Event *TaikoWrapperClientPaused // Event containing the contract specifics and raw log

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
func (it *TaikoWrapperClientPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoWrapperClientPaused)
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
		it.Event = new(TaikoWrapperClientPaused)
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
func (it *TaikoWrapperClientPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoWrapperClientPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoWrapperClientPaused represents a Paused event raised by the TaikoWrapperClient contract.
type TaikoWrapperClientPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_TaikoWrapperClient *TaikoWrapperClientFilterer) FilterPaused(opts *bind.FilterOpts) (*TaikoWrapperClientPausedIterator, error) {

	logs, sub, err := _TaikoWrapperClient.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &TaikoWrapperClientPausedIterator{contract: _TaikoWrapperClient.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_TaikoWrapperClient *TaikoWrapperClientFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *TaikoWrapperClientPaused) (event.Subscription, error) {

	logs, sub, err := _TaikoWrapperClient.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoWrapperClientPaused)
				if err := _TaikoWrapperClient.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_TaikoWrapperClient *TaikoWrapperClientFilterer) ParsePaused(log types.Log) (*TaikoWrapperClientPaused, error) {
	event := new(TaikoWrapperClientPaused)
	if err := _TaikoWrapperClient.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoWrapperClientUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the TaikoWrapperClient contract.
type TaikoWrapperClientUnpausedIterator struct {
	Event *TaikoWrapperClientUnpaused // Event containing the contract specifics and raw log

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
func (it *TaikoWrapperClientUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoWrapperClientUnpaused)
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
		it.Event = new(TaikoWrapperClientUnpaused)
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
func (it *TaikoWrapperClientUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoWrapperClientUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoWrapperClientUnpaused represents a Unpaused event raised by the TaikoWrapperClient contract.
type TaikoWrapperClientUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_TaikoWrapperClient *TaikoWrapperClientFilterer) FilterUnpaused(opts *bind.FilterOpts) (*TaikoWrapperClientUnpausedIterator, error) {

	logs, sub, err := _TaikoWrapperClient.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &TaikoWrapperClientUnpausedIterator{contract: _TaikoWrapperClient.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_TaikoWrapperClient *TaikoWrapperClientFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *TaikoWrapperClientUnpaused) (event.Subscription, error) {

	logs, sub, err := _TaikoWrapperClient.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoWrapperClientUnpaused)
				if err := _TaikoWrapperClient.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_TaikoWrapperClient *TaikoWrapperClientFilterer) ParseUnpaused(log types.Log) (*TaikoWrapperClientUnpaused, error) {
	event := new(TaikoWrapperClientUnpaused)
	if err := _TaikoWrapperClient.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoWrapperClientUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the TaikoWrapperClient contract.
type TaikoWrapperClientUpgradedIterator struct {
	Event *TaikoWrapperClientUpgraded // Event containing the contract specifics and raw log

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
func (it *TaikoWrapperClientUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoWrapperClientUpgraded)
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
		it.Event = new(TaikoWrapperClientUpgraded)
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
func (it *TaikoWrapperClientUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoWrapperClientUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoWrapperClientUpgraded represents a Upgraded event raised by the TaikoWrapperClient contract.
type TaikoWrapperClientUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_TaikoWrapperClient *TaikoWrapperClientFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*TaikoWrapperClientUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _TaikoWrapperClient.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &TaikoWrapperClientUpgradedIterator{contract: _TaikoWrapperClient.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_TaikoWrapperClient *TaikoWrapperClientFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *TaikoWrapperClientUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _TaikoWrapperClient.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoWrapperClientUpgraded)
				if err := _TaikoWrapperClient.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_TaikoWrapperClient *TaikoWrapperClientFilterer) ParseUpgraded(log types.Log) (*TaikoWrapperClientUpgraded, error) {
	event := new(TaikoWrapperClientUpgraded)
	if err := _TaikoWrapperClient.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
