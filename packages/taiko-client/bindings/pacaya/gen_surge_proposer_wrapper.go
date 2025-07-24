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

// SurgeProposerWrapperMetaData contains all meta data concerning the SurgeProposerWrapper contract.
var SurgeProposerWrapperMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"_admin\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_taikoWrapper\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_taikoInbox\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"authorizeCaller\",\"inputs\":[{\"name\":\"caller\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"deauthorizeCaller\",\"inputs\":[{\"name\":\"caller\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"depositBond\",\"inputs\":[{\"name\":\"_amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"proposeBatch\",\"inputs\":[{\"name\":\"_params\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"_txList\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.BatchInfo\",\"components\":[{\"name\":\"txsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blocks\",\"type\":\"tuple[]\",\"internalType\":\"structITaikoInbox.BlockParams[]\",\"components\":[{\"name\":\"numTransactions\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"timeShift\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"signalSlots\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}]},{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"extraData\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"coinbase\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"proposedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobCreatedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"blobByteOffset\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"blobByteSize\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"gasLimit\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"baseFee\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"lastBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"lastBlockTimestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"anchorBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"anchorBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"baseFeeConfig\",\"type\":\"tuple\",\"internalType\":\"structLibSharedData.BaseFeeConfig\",\"components\":[{\"name\":\"adjustmentQuotient\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"gasIssuancePerSecond\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"minGasExcess\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxGasIssuancePerBlock\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}]},{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.BatchMetadata\",\"components\":[{\"name\":\"infoHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"batchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"proposedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proveBatches\",\"inputs\":[{\"name\":\"_params\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"_proof\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"setAdmin\",\"inputs\":[{\"name\":\"newAdmin\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"withdrawBond\",\"inputs\":[{\"name\":\"_amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"error\",\"name\":\"NotAdmin\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotAuthorized\",\"inputs\":[]}]",
}

// SurgeProposerWrapperABI is the input ABI used to generate the binding from.
// Deprecated: Use SurgeProposerWrapperMetaData.ABI instead.
var SurgeProposerWrapperABI = SurgeProposerWrapperMetaData.ABI

// SurgeProposerWrapper is an auto generated Go binding around an Ethereum contract.
type SurgeProposerWrapper struct {
	SurgeProposerWrapperCaller     // Read-only binding to the contract
	SurgeProposerWrapperTransactor // Write-only binding to the contract
	SurgeProposerWrapperFilterer   // Log filterer for contract events
}

// SurgeProposerWrapperCaller is an auto generated read-only Go binding around an Ethereum contract.
type SurgeProposerWrapperCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SurgeProposerWrapperTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SurgeProposerWrapperTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SurgeProposerWrapperFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SurgeProposerWrapperFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SurgeProposerWrapperSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SurgeProposerWrapperSession struct {
	Contract     *SurgeProposerWrapper // Generic contract binding to set the session for
	CallOpts     bind.CallOpts         // Call options to use throughout this session
	TransactOpts bind.TransactOpts     // Transaction auth options to use throughout this session
}

// SurgeProposerWrapperCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SurgeProposerWrapperCallerSession struct {
	Contract *SurgeProposerWrapperCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts               // Call options to use throughout this session
}

// SurgeProposerWrapperTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SurgeProposerWrapperTransactorSession struct {
	Contract     *SurgeProposerWrapperTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts               // Transaction auth options to use throughout this session
}

// SurgeProposerWrapperRaw is an auto generated low-level Go binding around an Ethereum contract.
type SurgeProposerWrapperRaw struct {
	Contract *SurgeProposerWrapper // Generic contract binding to access the raw methods on
}

// SurgeProposerWrapperCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SurgeProposerWrapperCallerRaw struct {
	Contract *SurgeProposerWrapperCaller // Generic read-only contract binding to access the raw methods on
}

// SurgeProposerWrapperTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SurgeProposerWrapperTransactorRaw struct {
	Contract *SurgeProposerWrapperTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSurgeProposerWrapper creates a new instance of SurgeProposerWrapper, bound to a specific deployed contract.
func NewSurgeProposerWrapper(address common.Address, backend bind.ContractBackend) (*SurgeProposerWrapper, error) {
	contract, err := bindSurgeProposerWrapper(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SurgeProposerWrapper{SurgeProposerWrapperCaller: SurgeProposerWrapperCaller{contract: contract}, SurgeProposerWrapperTransactor: SurgeProposerWrapperTransactor{contract: contract}, SurgeProposerWrapperFilterer: SurgeProposerWrapperFilterer{contract: contract}}, nil
}

// NewSurgeProposerWrapperCaller creates a new read-only instance of SurgeProposerWrapper, bound to a specific deployed contract.
func NewSurgeProposerWrapperCaller(address common.Address, caller bind.ContractCaller) (*SurgeProposerWrapperCaller, error) {
	contract, err := bindSurgeProposerWrapper(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SurgeProposerWrapperCaller{contract: contract}, nil
}

// NewSurgeProposerWrapperTransactor creates a new write-only instance of SurgeProposerWrapper, bound to a specific deployed contract.
func NewSurgeProposerWrapperTransactor(address common.Address, transactor bind.ContractTransactor) (*SurgeProposerWrapperTransactor, error) {
	contract, err := bindSurgeProposerWrapper(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SurgeProposerWrapperTransactor{contract: contract}, nil
}

// NewSurgeProposerWrapperFilterer creates a new log filterer instance of SurgeProposerWrapper, bound to a specific deployed contract.
func NewSurgeProposerWrapperFilterer(address common.Address, filterer bind.ContractFilterer) (*SurgeProposerWrapperFilterer, error) {
	contract, err := bindSurgeProposerWrapper(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SurgeProposerWrapperFilterer{contract: contract}, nil
}

// bindSurgeProposerWrapper binds a generic wrapper to an already deployed contract.
func bindSurgeProposerWrapper(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SurgeProposerWrapperMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SurgeProposerWrapper *SurgeProposerWrapperRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SurgeProposerWrapper.Contract.SurgeProposerWrapperCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SurgeProposerWrapper *SurgeProposerWrapperRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SurgeProposerWrapper.Contract.SurgeProposerWrapperTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SurgeProposerWrapper *SurgeProposerWrapperRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SurgeProposerWrapper.Contract.SurgeProposerWrapperTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SurgeProposerWrapper *SurgeProposerWrapperCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SurgeProposerWrapper.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SurgeProposerWrapper *SurgeProposerWrapperTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SurgeProposerWrapper.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SurgeProposerWrapper *SurgeProposerWrapperTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SurgeProposerWrapper.Contract.contract.Transact(opts, method, params...)
}

// AuthorizeCaller is a paid mutator transaction binding the contract method 0x2c388d5d.
//
// Solidity: function authorizeCaller(address caller) returns()
func (_SurgeProposerWrapper *SurgeProposerWrapperTransactor) AuthorizeCaller(opts *bind.TransactOpts, caller common.Address) (*types.Transaction, error) {
	return _SurgeProposerWrapper.contract.Transact(opts, "authorizeCaller", caller)
}

// AuthorizeCaller is a paid mutator transaction binding the contract method 0x2c388d5d.
//
// Solidity: function authorizeCaller(address caller) returns()
func (_SurgeProposerWrapper *SurgeProposerWrapperSession) AuthorizeCaller(caller common.Address) (*types.Transaction, error) {
	return _SurgeProposerWrapper.Contract.AuthorizeCaller(&_SurgeProposerWrapper.TransactOpts, caller)
}

// AuthorizeCaller is a paid mutator transaction binding the contract method 0x2c388d5d.
//
// Solidity: function authorizeCaller(address caller) returns()
func (_SurgeProposerWrapper *SurgeProposerWrapperTransactorSession) AuthorizeCaller(caller common.Address) (*types.Transaction, error) {
	return _SurgeProposerWrapper.Contract.AuthorizeCaller(&_SurgeProposerWrapper.TransactOpts, caller)
}

// DeauthorizeCaller is a paid mutator transaction binding the contract method 0x6873c21d.
//
// Solidity: function deauthorizeCaller(address caller) returns()
func (_SurgeProposerWrapper *SurgeProposerWrapperTransactor) DeauthorizeCaller(opts *bind.TransactOpts, caller common.Address) (*types.Transaction, error) {
	return _SurgeProposerWrapper.contract.Transact(opts, "deauthorizeCaller", caller)
}

// DeauthorizeCaller is a paid mutator transaction binding the contract method 0x6873c21d.
//
// Solidity: function deauthorizeCaller(address caller) returns()
func (_SurgeProposerWrapper *SurgeProposerWrapperSession) DeauthorizeCaller(caller common.Address) (*types.Transaction, error) {
	return _SurgeProposerWrapper.Contract.DeauthorizeCaller(&_SurgeProposerWrapper.TransactOpts, caller)
}

// DeauthorizeCaller is a paid mutator transaction binding the contract method 0x6873c21d.
//
// Solidity: function deauthorizeCaller(address caller) returns()
func (_SurgeProposerWrapper *SurgeProposerWrapperTransactorSession) DeauthorizeCaller(caller common.Address) (*types.Transaction, error) {
	return _SurgeProposerWrapper.Contract.DeauthorizeCaller(&_SurgeProposerWrapper.TransactOpts, caller)
}

// DepositBond is a paid mutator transaction binding the contract method 0x4dcb05f9.
//
// Solidity: function depositBond(uint256 _amount) payable returns()
func (_SurgeProposerWrapper *SurgeProposerWrapperTransactor) DepositBond(opts *bind.TransactOpts, _amount *big.Int) (*types.Transaction, error) {
	return _SurgeProposerWrapper.contract.Transact(opts, "depositBond", _amount)
}

// DepositBond is a paid mutator transaction binding the contract method 0x4dcb05f9.
//
// Solidity: function depositBond(uint256 _amount) payable returns()
func (_SurgeProposerWrapper *SurgeProposerWrapperSession) DepositBond(_amount *big.Int) (*types.Transaction, error) {
	return _SurgeProposerWrapper.Contract.DepositBond(&_SurgeProposerWrapper.TransactOpts, _amount)
}

// DepositBond is a paid mutator transaction binding the contract method 0x4dcb05f9.
//
// Solidity: function depositBond(uint256 _amount) payable returns()
func (_SurgeProposerWrapper *SurgeProposerWrapperTransactorSession) DepositBond(_amount *big.Int) (*types.Transaction, error) {
	return _SurgeProposerWrapper.Contract.DepositBond(&_SurgeProposerWrapper.TransactOpts, _amount)
}

// ProposeBatch is a paid mutator transaction binding the contract method 0x47faad14.
//
// Solidity: function proposeBatch(bytes _params, bytes _txList) returns((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint64,uint32,uint32,uint32,uint96,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint64)), (bytes32,address,uint64,uint64))
func (_SurgeProposerWrapper *SurgeProposerWrapperTransactor) ProposeBatch(opts *bind.TransactOpts, _params []byte, _txList []byte) (*types.Transaction, error) {
	return _SurgeProposerWrapper.contract.Transact(opts, "proposeBatch", _params, _txList)
}

// ProposeBatch is a paid mutator transaction binding the contract method 0x47faad14.
//
// Solidity: function proposeBatch(bytes _params, bytes _txList) returns((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint64,uint32,uint32,uint32,uint96,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint64)), (bytes32,address,uint64,uint64))
func (_SurgeProposerWrapper *SurgeProposerWrapperSession) ProposeBatch(_params []byte, _txList []byte) (*types.Transaction, error) {
	return _SurgeProposerWrapper.Contract.ProposeBatch(&_SurgeProposerWrapper.TransactOpts, _params, _txList)
}

// ProposeBatch is a paid mutator transaction binding the contract method 0x47faad14.
//
// Solidity: function proposeBatch(bytes _params, bytes _txList) returns((bytes32,(uint16,uint8,bytes32[])[],bytes32[],bytes32,address,uint64,uint64,uint32,uint32,uint32,uint96,uint64,uint64,uint64,bytes32,(uint8,uint8,uint32,uint64,uint64)), (bytes32,address,uint64,uint64))
func (_SurgeProposerWrapper *SurgeProposerWrapperTransactorSession) ProposeBatch(_params []byte, _txList []byte) (*types.Transaction, error) {
	return _SurgeProposerWrapper.Contract.ProposeBatch(&_SurgeProposerWrapper.TransactOpts, _params, _txList)
}

// ProveBatches is a paid mutator transaction binding the contract method 0xc9cc2843.
//
// Solidity: function proveBatches(bytes _params, bytes _proof) returns()
func (_SurgeProposerWrapper *SurgeProposerWrapperTransactor) ProveBatches(opts *bind.TransactOpts, _params []byte, _proof []byte) (*types.Transaction, error) {
	return _SurgeProposerWrapper.contract.Transact(opts, "proveBatches", _params, _proof)
}

// ProveBatches is a paid mutator transaction binding the contract method 0xc9cc2843.
//
// Solidity: function proveBatches(bytes _params, bytes _proof) returns()
func (_SurgeProposerWrapper *SurgeProposerWrapperSession) ProveBatches(_params []byte, _proof []byte) (*types.Transaction, error) {
	return _SurgeProposerWrapper.Contract.ProveBatches(&_SurgeProposerWrapper.TransactOpts, _params, _proof)
}

// ProveBatches is a paid mutator transaction binding the contract method 0xc9cc2843.
//
// Solidity: function proveBatches(bytes _params, bytes _proof) returns()
func (_SurgeProposerWrapper *SurgeProposerWrapperTransactorSession) ProveBatches(_params []byte, _proof []byte) (*types.Transaction, error) {
	return _SurgeProposerWrapper.Contract.ProveBatches(&_SurgeProposerWrapper.TransactOpts, _params, _proof)
}

// SetAdmin is a paid mutator transaction binding the contract method 0x704b6c02.
//
// Solidity: function setAdmin(address newAdmin) returns()
func (_SurgeProposerWrapper *SurgeProposerWrapperTransactor) SetAdmin(opts *bind.TransactOpts, newAdmin common.Address) (*types.Transaction, error) {
	return _SurgeProposerWrapper.contract.Transact(opts, "setAdmin", newAdmin)
}

// SetAdmin is a paid mutator transaction binding the contract method 0x704b6c02.
//
// Solidity: function setAdmin(address newAdmin) returns()
func (_SurgeProposerWrapper *SurgeProposerWrapperSession) SetAdmin(newAdmin common.Address) (*types.Transaction, error) {
	return _SurgeProposerWrapper.Contract.SetAdmin(&_SurgeProposerWrapper.TransactOpts, newAdmin)
}

// SetAdmin is a paid mutator transaction binding the contract method 0x704b6c02.
//
// Solidity: function setAdmin(address newAdmin) returns()
func (_SurgeProposerWrapper *SurgeProposerWrapperTransactorSession) SetAdmin(newAdmin common.Address) (*types.Transaction, error) {
	return _SurgeProposerWrapper.Contract.SetAdmin(&_SurgeProposerWrapper.TransactOpts, newAdmin)
}

// WithdrawBond is a paid mutator transaction binding the contract method 0xc3daab96.
//
// Solidity: function withdrawBond(uint256 _amount) returns()
func (_SurgeProposerWrapper *SurgeProposerWrapperTransactor) WithdrawBond(opts *bind.TransactOpts, _amount *big.Int) (*types.Transaction, error) {
	return _SurgeProposerWrapper.contract.Transact(opts, "withdrawBond", _amount)
}

// WithdrawBond is a paid mutator transaction binding the contract method 0xc3daab96.
//
// Solidity: function withdrawBond(uint256 _amount) returns()
func (_SurgeProposerWrapper *SurgeProposerWrapperSession) WithdrawBond(_amount *big.Int) (*types.Transaction, error) {
	return _SurgeProposerWrapper.Contract.WithdrawBond(&_SurgeProposerWrapper.TransactOpts, _amount)
}

// WithdrawBond is a paid mutator transaction binding the contract method 0xc3daab96.
//
// Solidity: function withdrawBond(uint256 _amount) returns()
func (_SurgeProposerWrapper *SurgeProposerWrapperTransactorSession) WithdrawBond(_amount *big.Int) (*types.Transaction, error) {
	return _SurgeProposerWrapper.Contract.WithdrawBond(&_SurgeProposerWrapper.TransactOpts, _amount)
}
