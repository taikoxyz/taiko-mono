// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package shasta

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

// BondManagerMetaData contains all meta data concerning the BondManager contract.
var BondManagerMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"_bondToken\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_minBond\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"_withdrawalDelay\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"_bondOperator\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_signalService\",\"type\":\"address\",\"internalType\":\"contractISignalService\"},{\"name\":\"_l1Inbox\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_l1ChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_livenessBond\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"bond\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"balance\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"withdrawalRequestedAt\",\"type\":\"uint48\",\"internalType\":\"uint48\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"bondOperator\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"bondToken\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIERC20\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"cancelWithdrawal\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"creditBond\",\"inputs\":[{\"name\":\"_address\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_bond\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"debitBond\",\"inputs\":[{\"name\":\"_address\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_bond\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"amountDebited_\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"deposit\",\"inputs\":[{\"name\":\"_amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"depositTo\",\"inputs\":[{\"name\":\"_recipient\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"getBondBalance\",\"inputs\":[{\"name\":\"_address\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"hasSufficientBond\",\"inputs\":[{\"name\":\"_address\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_additionalBond\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"impl\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inNonReentrant\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"l1ChainId\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"l1Inbox\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"livenessBond\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"minBond\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"processBondInstruction\",\"inputs\":[{\"name\":\"_instruction\",\"type\":\"tuple\",\"internalType\":\"structLibBonds.BondInstruction\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"bondType\",\"type\":\"uint8\",\"internalType\":\"enumLibBonds.BondType\"},{\"name\":\"payer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"payee\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"_proof\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"processedSignals\",\"inputs\":[{\"name\":\"signal\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"processed\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"requestWithdrawal\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolver\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"signalService\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractISignalService\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"withdraw\",\"inputs\":[{\"name\":\"_to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"withdrawalDelay\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint48\",\"internalType\":\"uint48\"}],\"stateMutability\":\"view\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondCredited\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondDebited\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondDeposited\",\"inputs\":[{\"name\":\"depositor\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"recipient\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondInstructionProcessed\",\"inputs\":[{\"name\":\"signal\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"instruction\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structLibBonds.BondInstruction\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"bondType\",\"type\":\"uint8\",\"internalType\":\"enumLibBonds.BondType\"},{\"name\":\"payer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"payee\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"debitedAmount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondWithdrawn\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"WithdrawalCancelled\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"WithdrawalRequested\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"withdrawableAt\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCESS_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FUNC_NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidAddress\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidBondType\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidL1ChainId\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MustMaintainMinBond\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NoBondInstruction\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NoBondToWithdraw\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NoWithdrawalRequested\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SignalAlreadyProcessed\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"WithdrawalAlreadyRequested\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_VALUE\",\"inputs\":[]}]",
}

// BondManagerABI is the input ABI used to generate the binding from.
// Deprecated: Use BondManagerMetaData.ABI instead.
var BondManagerABI = BondManagerMetaData.ABI

// BondManager is an auto generated Go binding around an Ethereum contract.
type BondManager struct {
	BondManagerCaller     // Read-only binding to the contract
	BondManagerTransactor // Write-only binding to the contract
	BondManagerFilterer   // Log filterer for contract events
}

// BondManagerCaller is an auto generated read-only Go binding around an Ethereum contract.
type BondManagerCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// BondManagerTransactor is an auto generated write-only Go binding around an Ethereum contract.
type BondManagerTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// BondManagerFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type BondManagerFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// BondManagerSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type BondManagerSession struct {
	Contract     *BondManager      // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// BondManagerCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type BondManagerCallerSession struct {
	Contract *BondManagerCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts      // Call options to use throughout this session
}

// BondManagerTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type BondManagerTransactorSession struct {
	Contract     *BondManagerTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts      // Transaction auth options to use throughout this session
}

// BondManagerRaw is an auto generated low-level Go binding around an Ethereum contract.
type BondManagerRaw struct {
	Contract *BondManager // Generic contract binding to access the raw methods on
}

// BondManagerCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type BondManagerCallerRaw struct {
	Contract *BondManagerCaller // Generic read-only contract binding to access the raw methods on
}

// BondManagerTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type BondManagerTransactorRaw struct {
	Contract *BondManagerTransactor // Generic write-only contract binding to access the raw methods on
}

// NewBondManager creates a new instance of BondManager, bound to a specific deployed contract.
func NewBondManager(address common.Address, backend bind.ContractBackend) (*BondManager, error) {
	contract, err := bindBondManager(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &BondManager{BondManagerCaller: BondManagerCaller{contract: contract}, BondManagerTransactor: BondManagerTransactor{contract: contract}, BondManagerFilterer: BondManagerFilterer{contract: contract}}, nil
}

// NewBondManagerCaller creates a new read-only instance of BondManager, bound to a specific deployed contract.
func NewBondManagerCaller(address common.Address, caller bind.ContractCaller) (*BondManagerCaller, error) {
	contract, err := bindBondManager(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &BondManagerCaller{contract: contract}, nil
}

// NewBondManagerTransactor creates a new write-only instance of BondManager, bound to a specific deployed contract.
func NewBondManagerTransactor(address common.Address, transactor bind.ContractTransactor) (*BondManagerTransactor, error) {
	contract, err := bindBondManager(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &BondManagerTransactor{contract: contract}, nil
}

// NewBondManagerFilterer creates a new log filterer instance of BondManager, bound to a specific deployed contract.
func NewBondManagerFilterer(address common.Address, filterer bind.ContractFilterer) (*BondManagerFilterer, error) {
	contract, err := bindBondManager(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &BondManagerFilterer{contract: contract}, nil
}

// bindBondManager binds a generic wrapper to an already deployed contract.
func bindBondManager(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := BondManagerMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_BondManager *BondManagerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _BondManager.Contract.BondManagerCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_BondManager *BondManagerRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _BondManager.Contract.BondManagerTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_BondManager *BondManagerRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _BondManager.Contract.BondManagerTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_BondManager *BondManagerCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _BondManager.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_BondManager *BondManagerTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _BondManager.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_BondManager *BondManagerTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _BondManager.Contract.contract.Transact(opts, method, params...)
}

// Bond is a free data retrieval call binding the contract method 0x247ce85b.
//
// Solidity: function bond(address account) view returns(uint256 balance, uint48 withdrawalRequestedAt)
func (_BondManager *BondManagerCaller) Bond(opts *bind.CallOpts, account common.Address) (struct {
	Balance               *big.Int
	WithdrawalRequestedAt *big.Int
}, error) {
	var out []interface{}
	err := _BondManager.contract.Call(opts, &out, "bond", account)

	outstruct := new(struct {
		Balance               *big.Int
		WithdrawalRequestedAt *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Balance = *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	outstruct.WithdrawalRequestedAt = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// Bond is a free data retrieval call binding the contract method 0x247ce85b.
//
// Solidity: function bond(address account) view returns(uint256 balance, uint48 withdrawalRequestedAt)
func (_BondManager *BondManagerSession) Bond(account common.Address) (struct {
	Balance               *big.Int
	WithdrawalRequestedAt *big.Int
}, error) {
	return _BondManager.Contract.Bond(&_BondManager.CallOpts, account)
}

// Bond is a free data retrieval call binding the contract method 0x247ce85b.
//
// Solidity: function bond(address account) view returns(uint256 balance, uint48 withdrawalRequestedAt)
func (_BondManager *BondManagerCallerSession) Bond(account common.Address) (struct {
	Balance               *big.Int
	WithdrawalRequestedAt *big.Int
}, error) {
	return _BondManager.Contract.Bond(&_BondManager.CallOpts, account)
}

// BondOperator is a free data retrieval call binding the contract method 0x288d5550.
//
// Solidity: function bondOperator() view returns(address)
func (_BondManager *BondManagerCaller) BondOperator(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _BondManager.contract.Call(opts, &out, "bondOperator")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// BondOperator is a free data retrieval call binding the contract method 0x288d5550.
//
// Solidity: function bondOperator() view returns(address)
func (_BondManager *BondManagerSession) BondOperator() (common.Address, error) {
	return _BondManager.Contract.BondOperator(&_BondManager.CallOpts)
}

// BondOperator is a free data retrieval call binding the contract method 0x288d5550.
//
// Solidity: function bondOperator() view returns(address)
func (_BondManager *BondManagerCallerSession) BondOperator() (common.Address, error) {
	return _BondManager.Contract.BondOperator(&_BondManager.CallOpts)
}

// BondToken is a free data retrieval call binding the contract method 0xc28f4392.
//
// Solidity: function bondToken() view returns(address)
func (_BondManager *BondManagerCaller) BondToken(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _BondManager.contract.Call(opts, &out, "bondToken")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// BondToken is a free data retrieval call binding the contract method 0xc28f4392.
//
// Solidity: function bondToken() view returns(address)
func (_BondManager *BondManagerSession) BondToken() (common.Address, error) {
	return _BondManager.Contract.BondToken(&_BondManager.CallOpts)
}

// BondToken is a free data retrieval call binding the contract method 0xc28f4392.
//
// Solidity: function bondToken() view returns(address)
func (_BondManager *BondManagerCallerSession) BondToken() (common.Address, error) {
	return _BondManager.Contract.BondToken(&_BondManager.CallOpts)
}

// GetBondBalance is a free data retrieval call binding the contract method 0x33613cbe.
//
// Solidity: function getBondBalance(address _address) view returns(uint256)
func (_BondManager *BondManagerCaller) GetBondBalance(opts *bind.CallOpts, _address common.Address) (*big.Int, error) {
	var out []interface{}
	err := _BondManager.contract.Call(opts, &out, "getBondBalance", _address)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetBondBalance is a free data retrieval call binding the contract method 0x33613cbe.
//
// Solidity: function getBondBalance(address _address) view returns(uint256)
func (_BondManager *BondManagerSession) GetBondBalance(_address common.Address) (*big.Int, error) {
	return _BondManager.Contract.GetBondBalance(&_BondManager.CallOpts, _address)
}

// GetBondBalance is a free data retrieval call binding the contract method 0x33613cbe.
//
// Solidity: function getBondBalance(address _address) view returns(uint256)
func (_BondManager *BondManagerCallerSession) GetBondBalance(_address common.Address) (*big.Int, error) {
	return _BondManager.Contract.GetBondBalance(&_BondManager.CallOpts, _address)
}

// HasSufficientBond is a free data retrieval call binding the contract method 0xa116e486.
//
// Solidity: function hasSufficientBond(address _address, uint256 _additionalBond) view returns(bool)
func (_BondManager *BondManagerCaller) HasSufficientBond(opts *bind.CallOpts, _address common.Address, _additionalBond *big.Int) (bool, error) {
	var out []interface{}
	err := _BondManager.contract.Call(opts, &out, "hasSufficientBond", _address, _additionalBond)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// HasSufficientBond is a free data retrieval call binding the contract method 0xa116e486.
//
// Solidity: function hasSufficientBond(address _address, uint256 _additionalBond) view returns(bool)
func (_BondManager *BondManagerSession) HasSufficientBond(_address common.Address, _additionalBond *big.Int) (bool, error) {
	return _BondManager.Contract.HasSufficientBond(&_BondManager.CallOpts, _address, _additionalBond)
}

// HasSufficientBond is a free data retrieval call binding the contract method 0xa116e486.
//
// Solidity: function hasSufficientBond(address _address, uint256 _additionalBond) view returns(bool)
func (_BondManager *BondManagerCallerSession) HasSufficientBond(_address common.Address, _additionalBond *big.Int) (bool, error) {
	return _BondManager.Contract.HasSufficientBond(&_BondManager.CallOpts, _address, _additionalBond)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_BondManager *BondManagerCaller) Impl(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _BondManager.contract.Call(opts, &out, "impl")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_BondManager *BondManagerSession) Impl() (common.Address, error) {
	return _BondManager.Contract.Impl(&_BondManager.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_BondManager *BondManagerCallerSession) Impl() (common.Address, error) {
	return _BondManager.Contract.Impl(&_BondManager.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_BondManager *BondManagerCaller) InNonReentrant(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _BondManager.contract.Call(opts, &out, "inNonReentrant")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_BondManager *BondManagerSession) InNonReentrant() (bool, error) {
	return _BondManager.Contract.InNonReentrant(&_BondManager.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_BondManager *BondManagerCallerSession) InNonReentrant() (bool, error) {
	return _BondManager.Contract.InNonReentrant(&_BondManager.CallOpts)
}

// L1ChainId is a free data retrieval call binding the contract method 0x12622e5b.
//
// Solidity: function l1ChainId() view returns(uint64)
func (_BondManager *BondManagerCaller) L1ChainId(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _BondManager.contract.Call(opts, &out, "l1ChainId")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// L1ChainId is a free data retrieval call binding the contract method 0x12622e5b.
//
// Solidity: function l1ChainId() view returns(uint64)
func (_BondManager *BondManagerSession) L1ChainId() (uint64, error) {
	return _BondManager.Contract.L1ChainId(&_BondManager.CallOpts)
}

// L1ChainId is a free data retrieval call binding the contract method 0x12622e5b.
//
// Solidity: function l1ChainId() view returns(uint64)
func (_BondManager *BondManagerCallerSession) L1ChainId() (uint64, error) {
	return _BondManager.Contract.L1ChainId(&_BondManager.CallOpts)
}

// L1Inbox is a free data retrieval call binding the contract method 0x8134f385.
//
// Solidity: function l1Inbox() view returns(address)
func (_BondManager *BondManagerCaller) L1Inbox(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _BondManager.contract.Call(opts, &out, "l1Inbox")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// L1Inbox is a free data retrieval call binding the contract method 0x8134f385.
//
// Solidity: function l1Inbox() view returns(address)
func (_BondManager *BondManagerSession) L1Inbox() (common.Address, error) {
	return _BondManager.Contract.L1Inbox(&_BondManager.CallOpts)
}

// L1Inbox is a free data retrieval call binding the contract method 0x8134f385.
//
// Solidity: function l1Inbox() view returns(address)
func (_BondManager *BondManagerCallerSession) L1Inbox() (common.Address, error) {
	return _BondManager.Contract.L1Inbox(&_BondManager.CallOpts)
}

// LivenessBond is a free data retrieval call binding the contract method 0xd4414221.
//
// Solidity: function livenessBond() view returns(uint256)
func (_BondManager *BondManagerCaller) LivenessBond(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _BondManager.contract.Call(opts, &out, "livenessBond")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// LivenessBond is a free data retrieval call binding the contract method 0xd4414221.
//
// Solidity: function livenessBond() view returns(uint256)
func (_BondManager *BondManagerSession) LivenessBond() (*big.Int, error) {
	return _BondManager.Contract.LivenessBond(&_BondManager.CallOpts)
}

// LivenessBond is a free data retrieval call binding the contract method 0xd4414221.
//
// Solidity: function livenessBond() view returns(uint256)
func (_BondManager *BondManagerCallerSession) LivenessBond() (*big.Int, error) {
	return _BondManager.Contract.LivenessBond(&_BondManager.CallOpts)
}

// MinBond is a free data retrieval call binding the contract method 0x831518b7.
//
// Solidity: function minBond() view returns(uint256)
func (_BondManager *BondManagerCaller) MinBond(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _BondManager.contract.Call(opts, &out, "minBond")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// MinBond is a free data retrieval call binding the contract method 0x831518b7.
//
// Solidity: function minBond() view returns(uint256)
func (_BondManager *BondManagerSession) MinBond() (*big.Int, error) {
	return _BondManager.Contract.MinBond(&_BondManager.CallOpts)
}

// MinBond is a free data retrieval call binding the contract method 0x831518b7.
//
// Solidity: function minBond() view returns(uint256)
func (_BondManager *BondManagerCallerSession) MinBond() (*big.Int, error) {
	return _BondManager.Contract.MinBond(&_BondManager.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_BondManager *BondManagerCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _BondManager.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_BondManager *BondManagerSession) Owner() (common.Address, error) {
	return _BondManager.Contract.Owner(&_BondManager.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_BondManager *BondManagerCallerSession) Owner() (common.Address, error) {
	return _BondManager.Contract.Owner(&_BondManager.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_BondManager *BondManagerCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _BondManager.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_BondManager *BondManagerSession) Paused() (bool, error) {
	return _BondManager.Contract.Paused(&_BondManager.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_BondManager *BondManagerCallerSession) Paused() (bool, error) {
	return _BondManager.Contract.Paused(&_BondManager.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_BondManager *BondManagerCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _BondManager.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_BondManager *BondManagerSession) PendingOwner() (common.Address, error) {
	return _BondManager.Contract.PendingOwner(&_BondManager.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_BondManager *BondManagerCallerSession) PendingOwner() (common.Address, error) {
	return _BondManager.Contract.PendingOwner(&_BondManager.CallOpts)
}

// ProcessedSignals is a free data retrieval call binding the contract method 0xd703e480.
//
// Solidity: function processedSignals(bytes32 signal) view returns(bool processed)
func (_BondManager *BondManagerCaller) ProcessedSignals(opts *bind.CallOpts, signal [32]byte) (bool, error) {
	var out []interface{}
	err := _BondManager.contract.Call(opts, &out, "processedSignals", signal)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// ProcessedSignals is a free data retrieval call binding the contract method 0xd703e480.
//
// Solidity: function processedSignals(bytes32 signal) view returns(bool processed)
func (_BondManager *BondManagerSession) ProcessedSignals(signal [32]byte) (bool, error) {
	return _BondManager.Contract.ProcessedSignals(&_BondManager.CallOpts, signal)
}

// ProcessedSignals is a free data retrieval call binding the contract method 0xd703e480.
//
// Solidity: function processedSignals(bytes32 signal) view returns(bool processed)
func (_BondManager *BondManagerCallerSession) ProcessedSignals(signal [32]byte) (bool, error) {
	return _BondManager.Contract.ProcessedSignals(&_BondManager.CallOpts, signal)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_BondManager *BondManagerCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _BondManager.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_BondManager *BondManagerSession) ProxiableUUID() ([32]byte, error) {
	return _BondManager.Contract.ProxiableUUID(&_BondManager.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_BondManager *BondManagerCallerSession) ProxiableUUID() ([32]byte, error) {
	return _BondManager.Contract.ProxiableUUID(&_BondManager.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_BondManager *BondManagerCaller) Resolver(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _BondManager.contract.Call(opts, &out, "resolver")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_BondManager *BondManagerSession) Resolver() (common.Address, error) {
	return _BondManager.Contract.Resolver(&_BondManager.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_BondManager *BondManagerCallerSession) Resolver() (common.Address, error) {
	return _BondManager.Contract.Resolver(&_BondManager.CallOpts)
}

// SignalService is a free data retrieval call binding the contract method 0x62d09453.
//
// Solidity: function signalService() view returns(address)
func (_BondManager *BondManagerCaller) SignalService(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _BondManager.contract.Call(opts, &out, "signalService")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SignalService is a free data retrieval call binding the contract method 0x62d09453.
//
// Solidity: function signalService() view returns(address)
func (_BondManager *BondManagerSession) SignalService() (common.Address, error) {
	return _BondManager.Contract.SignalService(&_BondManager.CallOpts)
}

// SignalService is a free data retrieval call binding the contract method 0x62d09453.
//
// Solidity: function signalService() view returns(address)
func (_BondManager *BondManagerCallerSession) SignalService() (common.Address, error) {
	return _BondManager.Contract.SignalService(&_BondManager.CallOpts)
}

// WithdrawalDelay is a free data retrieval call binding the contract method 0xa7ab6961.
//
// Solidity: function withdrawalDelay() view returns(uint48)
func (_BondManager *BondManagerCaller) WithdrawalDelay(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _BondManager.contract.Call(opts, &out, "withdrawalDelay")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// WithdrawalDelay is a free data retrieval call binding the contract method 0xa7ab6961.
//
// Solidity: function withdrawalDelay() view returns(uint48)
func (_BondManager *BondManagerSession) WithdrawalDelay() (*big.Int, error) {
	return _BondManager.Contract.WithdrawalDelay(&_BondManager.CallOpts)
}

// WithdrawalDelay is a free data retrieval call binding the contract method 0xa7ab6961.
//
// Solidity: function withdrawalDelay() view returns(uint48)
func (_BondManager *BondManagerCallerSession) WithdrawalDelay() (*big.Int, error) {
	return _BondManager.Contract.WithdrawalDelay(&_BondManager.CallOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_BondManager *BondManagerTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _BondManager.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_BondManager *BondManagerSession) AcceptOwnership() (*types.Transaction, error) {
	return _BondManager.Contract.AcceptOwnership(&_BondManager.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_BondManager *BondManagerTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _BondManager.Contract.AcceptOwnership(&_BondManager.TransactOpts)
}

// CancelWithdrawal is a paid mutator transaction binding the contract method 0x22611280.
//
// Solidity: function cancelWithdrawal() returns()
func (_BondManager *BondManagerTransactor) CancelWithdrawal(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _BondManager.contract.Transact(opts, "cancelWithdrawal")
}

// CancelWithdrawal is a paid mutator transaction binding the contract method 0x22611280.
//
// Solidity: function cancelWithdrawal() returns()
func (_BondManager *BondManagerSession) CancelWithdrawal() (*types.Transaction, error) {
	return _BondManager.Contract.CancelWithdrawal(&_BondManager.TransactOpts)
}

// CancelWithdrawal is a paid mutator transaction binding the contract method 0x22611280.
//
// Solidity: function cancelWithdrawal() returns()
func (_BondManager *BondManagerTransactorSession) CancelWithdrawal() (*types.Transaction, error) {
	return _BondManager.Contract.CancelWithdrawal(&_BondManager.TransactOpts)
}

// CreditBond is a paid mutator transaction binding the contract method 0xbe32d1f4.
//
// Solidity: function creditBond(address _address, uint256 _bond) returns()
func (_BondManager *BondManagerTransactor) CreditBond(opts *bind.TransactOpts, _address common.Address, _bond *big.Int) (*types.Transaction, error) {
	return _BondManager.contract.Transact(opts, "creditBond", _address, _bond)
}

// CreditBond is a paid mutator transaction binding the contract method 0xbe32d1f4.
//
// Solidity: function creditBond(address _address, uint256 _bond) returns()
func (_BondManager *BondManagerSession) CreditBond(_address common.Address, _bond *big.Int) (*types.Transaction, error) {
	return _BondManager.Contract.CreditBond(&_BondManager.TransactOpts, _address, _bond)
}

// CreditBond is a paid mutator transaction binding the contract method 0xbe32d1f4.
//
// Solidity: function creditBond(address _address, uint256 _bond) returns()
func (_BondManager *BondManagerTransactorSession) CreditBond(_address common.Address, _bond *big.Int) (*types.Transaction, error) {
	return _BondManager.Contract.CreditBond(&_BondManager.TransactOpts, _address, _bond)
}

// DebitBond is a paid mutator transaction binding the contract method 0x391396de.
//
// Solidity: function debitBond(address _address, uint256 _bond) returns(uint256 amountDebited_)
func (_BondManager *BondManagerTransactor) DebitBond(opts *bind.TransactOpts, _address common.Address, _bond *big.Int) (*types.Transaction, error) {
	return _BondManager.contract.Transact(opts, "debitBond", _address, _bond)
}

// DebitBond is a paid mutator transaction binding the contract method 0x391396de.
//
// Solidity: function debitBond(address _address, uint256 _bond) returns(uint256 amountDebited_)
func (_BondManager *BondManagerSession) DebitBond(_address common.Address, _bond *big.Int) (*types.Transaction, error) {
	return _BondManager.Contract.DebitBond(&_BondManager.TransactOpts, _address, _bond)
}

// DebitBond is a paid mutator transaction binding the contract method 0x391396de.
//
// Solidity: function debitBond(address _address, uint256 _bond) returns(uint256 amountDebited_)
func (_BondManager *BondManagerTransactorSession) DebitBond(_address common.Address, _bond *big.Int) (*types.Transaction, error) {
	return _BondManager.Contract.DebitBond(&_BondManager.TransactOpts, _address, _bond)
}

// Deposit is a paid mutator transaction binding the contract method 0xb6b55f25.
//
// Solidity: function deposit(uint256 _amount) returns()
func (_BondManager *BondManagerTransactor) Deposit(opts *bind.TransactOpts, _amount *big.Int) (*types.Transaction, error) {
	return _BondManager.contract.Transact(opts, "deposit", _amount)
}

// Deposit is a paid mutator transaction binding the contract method 0xb6b55f25.
//
// Solidity: function deposit(uint256 _amount) returns()
func (_BondManager *BondManagerSession) Deposit(_amount *big.Int) (*types.Transaction, error) {
	return _BondManager.Contract.Deposit(&_BondManager.TransactOpts, _amount)
}

// Deposit is a paid mutator transaction binding the contract method 0xb6b55f25.
//
// Solidity: function deposit(uint256 _amount) returns()
func (_BondManager *BondManagerTransactorSession) Deposit(_amount *big.Int) (*types.Transaction, error) {
	return _BondManager.Contract.Deposit(&_BondManager.TransactOpts, _amount)
}

// DepositTo is a paid mutator transaction binding the contract method 0xffaad6a5.
//
// Solidity: function depositTo(address _recipient, uint256 _amount) returns()
func (_BondManager *BondManagerTransactor) DepositTo(opts *bind.TransactOpts, _recipient common.Address, _amount *big.Int) (*types.Transaction, error) {
	return _BondManager.contract.Transact(opts, "depositTo", _recipient, _amount)
}

// DepositTo is a paid mutator transaction binding the contract method 0xffaad6a5.
//
// Solidity: function depositTo(address _recipient, uint256 _amount) returns()
func (_BondManager *BondManagerSession) DepositTo(_recipient common.Address, _amount *big.Int) (*types.Transaction, error) {
	return _BondManager.Contract.DepositTo(&_BondManager.TransactOpts, _recipient, _amount)
}

// DepositTo is a paid mutator transaction binding the contract method 0xffaad6a5.
//
// Solidity: function depositTo(address _recipient, uint256 _amount) returns()
func (_BondManager *BondManagerTransactorSession) DepositTo(_recipient common.Address, _amount *big.Int) (*types.Transaction, error) {
	return _BondManager.Contract.DepositTo(&_BondManager.TransactOpts, _recipient, _amount)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_BondManager *BondManagerTransactor) Init(opts *bind.TransactOpts, _owner common.Address) (*types.Transaction, error) {
	return _BondManager.contract.Transact(opts, "init", _owner)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_BondManager *BondManagerSession) Init(_owner common.Address) (*types.Transaction, error) {
	return _BondManager.Contract.Init(&_BondManager.TransactOpts, _owner)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_BondManager *BondManagerTransactorSession) Init(_owner common.Address) (*types.Transaction, error) {
	return _BondManager.Contract.Init(&_BondManager.TransactOpts, _owner)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_BondManager *BondManagerTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _BondManager.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_BondManager *BondManagerSession) Pause() (*types.Transaction, error) {
	return _BondManager.Contract.Pause(&_BondManager.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_BondManager *BondManagerTransactorSession) Pause() (*types.Transaction, error) {
	return _BondManager.Contract.Pause(&_BondManager.TransactOpts)
}

// ProcessBondInstruction is a paid mutator transaction binding the contract method 0x713b5da2.
//
// Solidity: function processBondInstruction((uint48,uint8,address,address) _instruction, bytes _proof) returns()
func (_BondManager *BondManagerTransactor) ProcessBondInstruction(opts *bind.TransactOpts, _instruction LibBondsBondInstruction, _proof []byte) (*types.Transaction, error) {
	return _BondManager.contract.Transact(opts, "processBondInstruction", _instruction, _proof)
}

// ProcessBondInstruction is a paid mutator transaction binding the contract method 0x713b5da2.
//
// Solidity: function processBondInstruction((uint48,uint8,address,address) _instruction, bytes _proof) returns()
func (_BondManager *BondManagerSession) ProcessBondInstruction(_instruction LibBondsBondInstruction, _proof []byte) (*types.Transaction, error) {
	return _BondManager.Contract.ProcessBondInstruction(&_BondManager.TransactOpts, _instruction, _proof)
}

// ProcessBondInstruction is a paid mutator transaction binding the contract method 0x713b5da2.
//
// Solidity: function processBondInstruction((uint48,uint8,address,address) _instruction, bytes _proof) returns()
func (_BondManager *BondManagerTransactorSession) ProcessBondInstruction(_instruction LibBondsBondInstruction, _proof []byte) (*types.Transaction, error) {
	return _BondManager.Contract.ProcessBondInstruction(&_BondManager.TransactOpts, _instruction, _proof)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_BondManager *BondManagerTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _BondManager.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_BondManager *BondManagerSession) RenounceOwnership() (*types.Transaction, error) {
	return _BondManager.Contract.RenounceOwnership(&_BondManager.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_BondManager *BondManagerTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _BondManager.Contract.RenounceOwnership(&_BondManager.TransactOpts)
}

// RequestWithdrawal is a paid mutator transaction binding the contract method 0xdbaf2145.
//
// Solidity: function requestWithdrawal() returns()
func (_BondManager *BondManagerTransactor) RequestWithdrawal(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _BondManager.contract.Transact(opts, "requestWithdrawal")
}

// RequestWithdrawal is a paid mutator transaction binding the contract method 0xdbaf2145.
//
// Solidity: function requestWithdrawal() returns()
func (_BondManager *BondManagerSession) RequestWithdrawal() (*types.Transaction, error) {
	return _BondManager.Contract.RequestWithdrawal(&_BondManager.TransactOpts)
}

// RequestWithdrawal is a paid mutator transaction binding the contract method 0xdbaf2145.
//
// Solidity: function requestWithdrawal() returns()
func (_BondManager *BondManagerTransactorSession) RequestWithdrawal() (*types.Transaction, error) {
	return _BondManager.Contract.RequestWithdrawal(&_BondManager.TransactOpts)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_BondManager *BondManagerTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _BondManager.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_BondManager *BondManagerSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _BondManager.Contract.TransferOwnership(&_BondManager.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_BondManager *BondManagerTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _BondManager.Contract.TransferOwnership(&_BondManager.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_BondManager *BondManagerTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _BondManager.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_BondManager *BondManagerSession) Unpause() (*types.Transaction, error) {
	return _BondManager.Contract.Unpause(&_BondManager.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_BondManager *BondManagerTransactorSession) Unpause() (*types.Transaction, error) {
	return _BondManager.Contract.Unpause(&_BondManager.TransactOpts)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_BondManager *BondManagerTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _BondManager.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_BondManager *BondManagerSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _BondManager.Contract.UpgradeTo(&_BondManager.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_BondManager *BondManagerTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _BondManager.Contract.UpgradeTo(&_BondManager.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_BondManager *BondManagerTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _BondManager.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_BondManager *BondManagerSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _BondManager.Contract.UpgradeToAndCall(&_BondManager.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_BondManager *BondManagerTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _BondManager.Contract.UpgradeToAndCall(&_BondManager.TransactOpts, newImplementation, data)
}

// Withdraw is a paid mutator transaction binding the contract method 0xf3fef3a3.
//
// Solidity: function withdraw(address _to, uint256 _amount) returns()
func (_BondManager *BondManagerTransactor) Withdraw(opts *bind.TransactOpts, _to common.Address, _amount *big.Int) (*types.Transaction, error) {
	return _BondManager.contract.Transact(opts, "withdraw", _to, _amount)
}

// Withdraw is a paid mutator transaction binding the contract method 0xf3fef3a3.
//
// Solidity: function withdraw(address _to, uint256 _amount) returns()
func (_BondManager *BondManagerSession) Withdraw(_to common.Address, _amount *big.Int) (*types.Transaction, error) {
	return _BondManager.Contract.Withdraw(&_BondManager.TransactOpts, _to, _amount)
}

// Withdraw is a paid mutator transaction binding the contract method 0xf3fef3a3.
//
// Solidity: function withdraw(address _to, uint256 _amount) returns()
func (_BondManager *BondManagerTransactorSession) Withdraw(_to common.Address, _amount *big.Int) (*types.Transaction, error) {
	return _BondManager.Contract.Withdraw(&_BondManager.TransactOpts, _to, _amount)
}

// BondManagerAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the BondManager contract.
type BondManagerAdminChangedIterator struct {
	Event *BondManagerAdminChanged // Event containing the contract specifics and raw log

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
func (it *BondManagerAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BondManagerAdminChanged)
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
		it.Event = new(BondManagerAdminChanged)
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
func (it *BondManagerAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BondManagerAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BondManagerAdminChanged represents a AdminChanged event raised by the BondManager contract.
type BondManagerAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_BondManager *BondManagerFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*BondManagerAdminChangedIterator, error) {

	logs, sub, err := _BondManager.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &BondManagerAdminChangedIterator{contract: _BondManager.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_BondManager *BondManagerFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *BondManagerAdminChanged) (event.Subscription, error) {

	logs, sub, err := _BondManager.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BondManagerAdminChanged)
				if err := _BondManager.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_BondManager *BondManagerFilterer) ParseAdminChanged(log types.Log) (*BondManagerAdminChanged, error) {
	event := new(BondManagerAdminChanged)
	if err := _BondManager.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BondManagerBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the BondManager contract.
type BondManagerBeaconUpgradedIterator struct {
	Event *BondManagerBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *BondManagerBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BondManagerBeaconUpgraded)
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
		it.Event = new(BondManagerBeaconUpgraded)
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
func (it *BondManagerBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BondManagerBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BondManagerBeaconUpgraded represents a BeaconUpgraded event raised by the BondManager contract.
type BondManagerBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_BondManager *BondManagerFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*BondManagerBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _BondManager.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &BondManagerBeaconUpgradedIterator{contract: _BondManager.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_BondManager *BondManagerFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *BondManagerBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _BondManager.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BondManagerBeaconUpgraded)
				if err := _BondManager.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_BondManager *BondManagerFilterer) ParseBeaconUpgraded(log types.Log) (*BondManagerBeaconUpgraded, error) {
	event := new(BondManagerBeaconUpgraded)
	if err := _BondManager.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BondManagerBondCreditedIterator is returned from FilterBondCredited and is used to iterate over the raw logs and unpacked data for BondCredited events raised by the BondManager contract.
type BondManagerBondCreditedIterator struct {
	Event *BondManagerBondCredited // Event containing the contract specifics and raw log

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
func (it *BondManagerBondCreditedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BondManagerBondCredited)
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
		it.Event = new(BondManagerBondCredited)
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
func (it *BondManagerBondCreditedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BondManagerBondCreditedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BondManagerBondCredited represents a BondCredited event raised by the BondManager contract.
type BondManagerBondCredited struct {
	Account common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterBondCredited is a free log retrieval operation binding the contract event 0x6de6fe586196fa05b73b973026c5fda3968a2933989bff3a0b6bd57644fab606.
//
// Solidity: event BondCredited(address indexed account, uint256 amount)
func (_BondManager *BondManagerFilterer) FilterBondCredited(opts *bind.FilterOpts, account []common.Address) (*BondManagerBondCreditedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _BondManager.contract.FilterLogs(opts, "BondCredited", accountRule)
	if err != nil {
		return nil, err
	}
	return &BondManagerBondCreditedIterator{contract: _BondManager.contract, event: "BondCredited", logs: logs, sub: sub}, nil
}

// WatchBondCredited is a free log subscription operation binding the contract event 0x6de6fe586196fa05b73b973026c5fda3968a2933989bff3a0b6bd57644fab606.
//
// Solidity: event BondCredited(address indexed account, uint256 amount)
func (_BondManager *BondManagerFilterer) WatchBondCredited(opts *bind.WatchOpts, sink chan<- *BondManagerBondCredited, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _BondManager.contract.WatchLogs(opts, "BondCredited", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BondManagerBondCredited)
				if err := _BondManager.contract.UnpackLog(event, "BondCredited", log); err != nil {
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

// ParseBondCredited is a log parse operation binding the contract event 0x6de6fe586196fa05b73b973026c5fda3968a2933989bff3a0b6bd57644fab606.
//
// Solidity: event BondCredited(address indexed account, uint256 amount)
func (_BondManager *BondManagerFilterer) ParseBondCredited(log types.Log) (*BondManagerBondCredited, error) {
	event := new(BondManagerBondCredited)
	if err := _BondManager.contract.UnpackLog(event, "BondCredited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BondManagerBondDebitedIterator is returned from FilterBondDebited and is used to iterate over the raw logs and unpacked data for BondDebited events raised by the BondManager contract.
type BondManagerBondDebitedIterator struct {
	Event *BondManagerBondDebited // Event containing the contract specifics and raw log

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
func (it *BondManagerBondDebitedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BondManagerBondDebited)
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
		it.Event = new(BondManagerBondDebited)
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
func (it *BondManagerBondDebitedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BondManagerBondDebitedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BondManagerBondDebited represents a BondDebited event raised by the BondManager contract.
type BondManagerBondDebited struct {
	Account common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterBondDebited is a free log retrieval operation binding the contract event 0x85f32beeaff2d0019a8d196f06790c9a652191759c46643311344fd38920423c.
//
// Solidity: event BondDebited(address indexed account, uint256 amount)
func (_BondManager *BondManagerFilterer) FilterBondDebited(opts *bind.FilterOpts, account []common.Address) (*BondManagerBondDebitedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _BondManager.contract.FilterLogs(opts, "BondDebited", accountRule)
	if err != nil {
		return nil, err
	}
	return &BondManagerBondDebitedIterator{contract: _BondManager.contract, event: "BondDebited", logs: logs, sub: sub}, nil
}

// WatchBondDebited is a free log subscription operation binding the contract event 0x85f32beeaff2d0019a8d196f06790c9a652191759c46643311344fd38920423c.
//
// Solidity: event BondDebited(address indexed account, uint256 amount)
func (_BondManager *BondManagerFilterer) WatchBondDebited(opts *bind.WatchOpts, sink chan<- *BondManagerBondDebited, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _BondManager.contract.WatchLogs(opts, "BondDebited", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BondManagerBondDebited)
				if err := _BondManager.contract.UnpackLog(event, "BondDebited", log); err != nil {
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

// ParseBondDebited is a log parse operation binding the contract event 0x85f32beeaff2d0019a8d196f06790c9a652191759c46643311344fd38920423c.
//
// Solidity: event BondDebited(address indexed account, uint256 amount)
func (_BondManager *BondManagerFilterer) ParseBondDebited(log types.Log) (*BondManagerBondDebited, error) {
	event := new(BondManagerBondDebited)
	if err := _BondManager.contract.UnpackLog(event, "BondDebited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BondManagerBondDepositedIterator is returned from FilterBondDeposited and is used to iterate over the raw logs and unpacked data for BondDeposited events raised by the BondManager contract.
type BondManagerBondDepositedIterator struct {
	Event *BondManagerBondDeposited // Event containing the contract specifics and raw log

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
func (it *BondManagerBondDepositedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BondManagerBondDeposited)
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
		it.Event = new(BondManagerBondDeposited)
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
func (it *BondManagerBondDepositedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BondManagerBondDepositedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BondManagerBondDeposited represents a BondDeposited event raised by the BondManager contract.
type BondManagerBondDeposited struct {
	Depositor common.Address
	Recipient common.Address
	Amount    *big.Int
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterBondDeposited is a free log retrieval operation binding the contract event 0x9b864b4f862a880bff51342f7085ad151ac52d86cb54e8a4a5a29cf5c0ef15dd.
//
// Solidity: event BondDeposited(address indexed depositor, address indexed recipient, uint256 amount)
func (_BondManager *BondManagerFilterer) FilterBondDeposited(opts *bind.FilterOpts, depositor []common.Address, recipient []common.Address) (*BondManagerBondDepositedIterator, error) {

	var depositorRule []interface{}
	for _, depositorItem := range depositor {
		depositorRule = append(depositorRule, depositorItem)
	}
	var recipientRule []interface{}
	for _, recipientItem := range recipient {
		recipientRule = append(recipientRule, recipientItem)
	}

	logs, sub, err := _BondManager.contract.FilterLogs(opts, "BondDeposited", depositorRule, recipientRule)
	if err != nil {
		return nil, err
	}
	return &BondManagerBondDepositedIterator{contract: _BondManager.contract, event: "BondDeposited", logs: logs, sub: sub}, nil
}

// WatchBondDeposited is a free log subscription operation binding the contract event 0x9b864b4f862a880bff51342f7085ad151ac52d86cb54e8a4a5a29cf5c0ef15dd.
//
// Solidity: event BondDeposited(address indexed depositor, address indexed recipient, uint256 amount)
func (_BondManager *BondManagerFilterer) WatchBondDeposited(opts *bind.WatchOpts, sink chan<- *BondManagerBondDeposited, depositor []common.Address, recipient []common.Address) (event.Subscription, error) {

	var depositorRule []interface{}
	for _, depositorItem := range depositor {
		depositorRule = append(depositorRule, depositorItem)
	}
	var recipientRule []interface{}
	for _, recipientItem := range recipient {
		recipientRule = append(recipientRule, recipientItem)
	}

	logs, sub, err := _BondManager.contract.WatchLogs(opts, "BondDeposited", depositorRule, recipientRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BondManagerBondDeposited)
				if err := _BondManager.contract.UnpackLog(event, "BondDeposited", log); err != nil {
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

// ParseBondDeposited is a log parse operation binding the contract event 0x9b864b4f862a880bff51342f7085ad151ac52d86cb54e8a4a5a29cf5c0ef15dd.
//
// Solidity: event BondDeposited(address indexed depositor, address indexed recipient, uint256 amount)
func (_BondManager *BondManagerFilterer) ParseBondDeposited(log types.Log) (*BondManagerBondDeposited, error) {
	event := new(BondManagerBondDeposited)
	if err := _BondManager.contract.UnpackLog(event, "BondDeposited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BondManagerBondInstructionProcessedIterator is returned from FilterBondInstructionProcessed and is used to iterate over the raw logs and unpacked data for BondInstructionProcessed events raised by the BondManager contract.
type BondManagerBondInstructionProcessedIterator struct {
	Event *BondManagerBondInstructionProcessed // Event containing the contract specifics and raw log

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
func (it *BondManagerBondInstructionProcessedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BondManagerBondInstructionProcessed)
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
		it.Event = new(BondManagerBondInstructionProcessed)
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
func (it *BondManagerBondInstructionProcessedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BondManagerBondInstructionProcessedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BondManagerBondInstructionProcessed represents a BondInstructionProcessed event raised by the BondManager contract.
type BondManagerBondInstructionProcessed struct {
	Signal        [32]byte
	Instruction   LibBondsBondInstruction
	DebitedAmount *big.Int
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterBondInstructionProcessed is a free log retrieval operation binding the contract event 0x13fdc26e9f397a2fe2a2fbb12eb32f3651369014a9e5f099db2b010ceb810d88.
//
// Solidity: event BondInstructionProcessed(bytes32 indexed signal, (uint48,uint8,address,address) instruction, uint256 debitedAmount)
func (_BondManager *BondManagerFilterer) FilterBondInstructionProcessed(opts *bind.FilterOpts, signal [][32]byte) (*BondManagerBondInstructionProcessedIterator, error) {

	var signalRule []interface{}
	for _, signalItem := range signal {
		signalRule = append(signalRule, signalItem)
	}

	logs, sub, err := _BondManager.contract.FilterLogs(opts, "BondInstructionProcessed", signalRule)
	if err != nil {
		return nil, err
	}
	return &BondManagerBondInstructionProcessedIterator{contract: _BondManager.contract, event: "BondInstructionProcessed", logs: logs, sub: sub}, nil
}

// WatchBondInstructionProcessed is a free log subscription operation binding the contract event 0x13fdc26e9f397a2fe2a2fbb12eb32f3651369014a9e5f099db2b010ceb810d88.
//
// Solidity: event BondInstructionProcessed(bytes32 indexed signal, (uint48,uint8,address,address) instruction, uint256 debitedAmount)
func (_BondManager *BondManagerFilterer) WatchBondInstructionProcessed(opts *bind.WatchOpts, sink chan<- *BondManagerBondInstructionProcessed, signal [][32]byte) (event.Subscription, error) {

	var signalRule []interface{}
	for _, signalItem := range signal {
		signalRule = append(signalRule, signalItem)
	}

	logs, sub, err := _BondManager.contract.WatchLogs(opts, "BondInstructionProcessed", signalRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BondManagerBondInstructionProcessed)
				if err := _BondManager.contract.UnpackLog(event, "BondInstructionProcessed", log); err != nil {
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

// ParseBondInstructionProcessed is a log parse operation binding the contract event 0x13fdc26e9f397a2fe2a2fbb12eb32f3651369014a9e5f099db2b010ceb810d88.
//
// Solidity: event BondInstructionProcessed(bytes32 indexed signal, (uint48,uint8,address,address) instruction, uint256 debitedAmount)
func (_BondManager *BondManagerFilterer) ParseBondInstructionProcessed(log types.Log) (*BondManagerBondInstructionProcessed, error) {
	event := new(BondManagerBondInstructionProcessed)
	if err := _BondManager.contract.UnpackLog(event, "BondInstructionProcessed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BondManagerBondWithdrawnIterator is returned from FilterBondWithdrawn and is used to iterate over the raw logs and unpacked data for BondWithdrawn events raised by the BondManager contract.
type BondManagerBondWithdrawnIterator struct {
	Event *BondManagerBondWithdrawn // Event containing the contract specifics and raw log

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
func (it *BondManagerBondWithdrawnIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BondManagerBondWithdrawn)
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
		it.Event = new(BondManagerBondWithdrawn)
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
func (it *BondManagerBondWithdrawnIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BondManagerBondWithdrawnIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BondManagerBondWithdrawn represents a BondWithdrawn event raised by the BondManager contract.
type BondManagerBondWithdrawn struct {
	Account common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterBondWithdrawn is a free log retrieval operation binding the contract event 0x0d41118e36df44efb77a471fc49fb9c0be0406d802ef95520e9fbf606e65b455.
//
// Solidity: event BondWithdrawn(address indexed account, uint256 amount)
func (_BondManager *BondManagerFilterer) FilterBondWithdrawn(opts *bind.FilterOpts, account []common.Address) (*BondManagerBondWithdrawnIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _BondManager.contract.FilterLogs(opts, "BondWithdrawn", accountRule)
	if err != nil {
		return nil, err
	}
	return &BondManagerBondWithdrawnIterator{contract: _BondManager.contract, event: "BondWithdrawn", logs: logs, sub: sub}, nil
}

// WatchBondWithdrawn is a free log subscription operation binding the contract event 0x0d41118e36df44efb77a471fc49fb9c0be0406d802ef95520e9fbf606e65b455.
//
// Solidity: event BondWithdrawn(address indexed account, uint256 amount)
func (_BondManager *BondManagerFilterer) WatchBondWithdrawn(opts *bind.WatchOpts, sink chan<- *BondManagerBondWithdrawn, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _BondManager.contract.WatchLogs(opts, "BondWithdrawn", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BondManagerBondWithdrawn)
				if err := _BondManager.contract.UnpackLog(event, "BondWithdrawn", log); err != nil {
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

// ParseBondWithdrawn is a log parse operation binding the contract event 0x0d41118e36df44efb77a471fc49fb9c0be0406d802ef95520e9fbf606e65b455.
//
// Solidity: event BondWithdrawn(address indexed account, uint256 amount)
func (_BondManager *BondManagerFilterer) ParseBondWithdrawn(log types.Log) (*BondManagerBondWithdrawn, error) {
	event := new(BondManagerBondWithdrawn)
	if err := _BondManager.contract.UnpackLog(event, "BondWithdrawn", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BondManagerInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the BondManager contract.
type BondManagerInitializedIterator struct {
	Event *BondManagerInitialized // Event containing the contract specifics and raw log

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
func (it *BondManagerInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BondManagerInitialized)
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
		it.Event = new(BondManagerInitialized)
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
func (it *BondManagerInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BondManagerInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BondManagerInitialized represents a Initialized event raised by the BondManager contract.
type BondManagerInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_BondManager *BondManagerFilterer) FilterInitialized(opts *bind.FilterOpts) (*BondManagerInitializedIterator, error) {

	logs, sub, err := _BondManager.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &BondManagerInitializedIterator{contract: _BondManager.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_BondManager *BondManagerFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *BondManagerInitialized) (event.Subscription, error) {

	logs, sub, err := _BondManager.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BondManagerInitialized)
				if err := _BondManager.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_BondManager *BondManagerFilterer) ParseInitialized(log types.Log) (*BondManagerInitialized, error) {
	event := new(BondManagerInitialized)
	if err := _BondManager.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BondManagerOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the BondManager contract.
type BondManagerOwnershipTransferStartedIterator struct {
	Event *BondManagerOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *BondManagerOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BondManagerOwnershipTransferStarted)
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
		it.Event = new(BondManagerOwnershipTransferStarted)
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
func (it *BondManagerOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BondManagerOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BondManagerOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the BondManager contract.
type BondManagerOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_BondManager *BondManagerFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*BondManagerOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _BondManager.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &BondManagerOwnershipTransferStartedIterator{contract: _BondManager.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_BondManager *BondManagerFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *BondManagerOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _BondManager.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BondManagerOwnershipTransferStarted)
				if err := _BondManager.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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
func (_BondManager *BondManagerFilterer) ParseOwnershipTransferStarted(log types.Log) (*BondManagerOwnershipTransferStarted, error) {
	event := new(BondManagerOwnershipTransferStarted)
	if err := _BondManager.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BondManagerOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the BondManager contract.
type BondManagerOwnershipTransferredIterator struct {
	Event *BondManagerOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *BondManagerOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BondManagerOwnershipTransferred)
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
		it.Event = new(BondManagerOwnershipTransferred)
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
func (it *BondManagerOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BondManagerOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BondManagerOwnershipTransferred represents a OwnershipTransferred event raised by the BondManager contract.
type BondManagerOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_BondManager *BondManagerFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*BondManagerOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _BondManager.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &BondManagerOwnershipTransferredIterator{contract: _BondManager.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_BondManager *BondManagerFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *BondManagerOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _BondManager.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BondManagerOwnershipTransferred)
				if err := _BondManager.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_BondManager *BondManagerFilterer) ParseOwnershipTransferred(log types.Log) (*BondManagerOwnershipTransferred, error) {
	event := new(BondManagerOwnershipTransferred)
	if err := _BondManager.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BondManagerPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the BondManager contract.
type BondManagerPausedIterator struct {
	Event *BondManagerPaused // Event containing the contract specifics and raw log

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
func (it *BondManagerPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BondManagerPaused)
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
		it.Event = new(BondManagerPaused)
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
func (it *BondManagerPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BondManagerPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BondManagerPaused represents a Paused event raised by the BondManager contract.
type BondManagerPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_BondManager *BondManagerFilterer) FilterPaused(opts *bind.FilterOpts) (*BondManagerPausedIterator, error) {

	logs, sub, err := _BondManager.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &BondManagerPausedIterator{contract: _BondManager.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_BondManager *BondManagerFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *BondManagerPaused) (event.Subscription, error) {

	logs, sub, err := _BondManager.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BondManagerPaused)
				if err := _BondManager.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_BondManager *BondManagerFilterer) ParsePaused(log types.Log) (*BondManagerPaused, error) {
	event := new(BondManagerPaused)
	if err := _BondManager.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BondManagerUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the BondManager contract.
type BondManagerUnpausedIterator struct {
	Event *BondManagerUnpaused // Event containing the contract specifics and raw log

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
func (it *BondManagerUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BondManagerUnpaused)
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
		it.Event = new(BondManagerUnpaused)
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
func (it *BondManagerUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BondManagerUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BondManagerUnpaused represents a Unpaused event raised by the BondManager contract.
type BondManagerUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_BondManager *BondManagerFilterer) FilterUnpaused(opts *bind.FilterOpts) (*BondManagerUnpausedIterator, error) {

	logs, sub, err := _BondManager.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &BondManagerUnpausedIterator{contract: _BondManager.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_BondManager *BondManagerFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *BondManagerUnpaused) (event.Subscription, error) {

	logs, sub, err := _BondManager.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BondManagerUnpaused)
				if err := _BondManager.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_BondManager *BondManagerFilterer) ParseUnpaused(log types.Log) (*BondManagerUnpaused, error) {
	event := new(BondManagerUnpaused)
	if err := _BondManager.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BondManagerUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the BondManager contract.
type BondManagerUpgradedIterator struct {
	Event *BondManagerUpgraded // Event containing the contract specifics and raw log

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
func (it *BondManagerUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BondManagerUpgraded)
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
		it.Event = new(BondManagerUpgraded)
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
func (it *BondManagerUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BondManagerUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BondManagerUpgraded represents a Upgraded event raised by the BondManager contract.
type BondManagerUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_BondManager *BondManagerFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*BondManagerUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _BondManager.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &BondManagerUpgradedIterator{contract: _BondManager.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_BondManager *BondManagerFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *BondManagerUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _BondManager.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BondManagerUpgraded)
				if err := _BondManager.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_BondManager *BondManagerFilterer) ParseUpgraded(log types.Log) (*BondManagerUpgraded, error) {
	event := new(BondManagerUpgraded)
	if err := _BondManager.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BondManagerWithdrawalCancelledIterator is returned from FilterWithdrawalCancelled and is used to iterate over the raw logs and unpacked data for WithdrawalCancelled events raised by the BondManager contract.
type BondManagerWithdrawalCancelledIterator struct {
	Event *BondManagerWithdrawalCancelled // Event containing the contract specifics and raw log

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
func (it *BondManagerWithdrawalCancelledIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BondManagerWithdrawalCancelled)
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
		it.Event = new(BondManagerWithdrawalCancelled)
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
func (it *BondManagerWithdrawalCancelledIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BondManagerWithdrawalCancelledIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BondManagerWithdrawalCancelled represents a WithdrawalCancelled event raised by the BondManager contract.
type BondManagerWithdrawalCancelled struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterWithdrawalCancelled is a free log retrieval operation binding the contract event 0xc51fdb96728de385ec7859819e3997bc618362ef0dbca0ad051d856866cda3db.
//
// Solidity: event WithdrawalCancelled(address indexed account)
func (_BondManager *BondManagerFilterer) FilterWithdrawalCancelled(opts *bind.FilterOpts, account []common.Address) (*BondManagerWithdrawalCancelledIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _BondManager.contract.FilterLogs(opts, "WithdrawalCancelled", accountRule)
	if err != nil {
		return nil, err
	}
	return &BondManagerWithdrawalCancelledIterator{contract: _BondManager.contract, event: "WithdrawalCancelled", logs: logs, sub: sub}, nil
}

// WatchWithdrawalCancelled is a free log subscription operation binding the contract event 0xc51fdb96728de385ec7859819e3997bc618362ef0dbca0ad051d856866cda3db.
//
// Solidity: event WithdrawalCancelled(address indexed account)
func (_BondManager *BondManagerFilterer) WatchWithdrawalCancelled(opts *bind.WatchOpts, sink chan<- *BondManagerWithdrawalCancelled, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _BondManager.contract.WatchLogs(opts, "WithdrawalCancelled", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BondManagerWithdrawalCancelled)
				if err := _BondManager.contract.UnpackLog(event, "WithdrawalCancelled", log); err != nil {
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

// ParseWithdrawalCancelled is a log parse operation binding the contract event 0xc51fdb96728de385ec7859819e3997bc618362ef0dbca0ad051d856866cda3db.
//
// Solidity: event WithdrawalCancelled(address indexed account)
func (_BondManager *BondManagerFilterer) ParseWithdrawalCancelled(log types.Log) (*BondManagerWithdrawalCancelled, error) {
	event := new(BondManagerWithdrawalCancelled)
	if err := _BondManager.contract.UnpackLog(event, "WithdrawalCancelled", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BondManagerWithdrawalRequestedIterator is returned from FilterWithdrawalRequested and is used to iterate over the raw logs and unpacked data for WithdrawalRequested events raised by the BondManager contract.
type BondManagerWithdrawalRequestedIterator struct {
	Event *BondManagerWithdrawalRequested // Event containing the contract specifics and raw log

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
func (it *BondManagerWithdrawalRequestedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BondManagerWithdrawalRequested)
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
		it.Event = new(BondManagerWithdrawalRequested)
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
func (it *BondManagerWithdrawalRequestedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BondManagerWithdrawalRequestedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BondManagerWithdrawalRequested represents a WithdrawalRequested event raised by the BondManager contract.
type BondManagerWithdrawalRequested struct {
	Account        common.Address
	WithdrawableAt *big.Int
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterWithdrawalRequested is a free log retrieval operation binding the contract event 0xe670e4e82118d22a1f9ee18920455ebc958bae26a90a05d31d3378788b1b0e44.
//
// Solidity: event WithdrawalRequested(address indexed account, uint256 withdrawableAt)
func (_BondManager *BondManagerFilterer) FilterWithdrawalRequested(opts *bind.FilterOpts, account []common.Address) (*BondManagerWithdrawalRequestedIterator, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _BondManager.contract.FilterLogs(opts, "WithdrawalRequested", accountRule)
	if err != nil {
		return nil, err
	}
	return &BondManagerWithdrawalRequestedIterator{contract: _BondManager.contract, event: "WithdrawalRequested", logs: logs, sub: sub}, nil
}

// WatchWithdrawalRequested is a free log subscription operation binding the contract event 0xe670e4e82118d22a1f9ee18920455ebc958bae26a90a05d31d3378788b1b0e44.
//
// Solidity: event WithdrawalRequested(address indexed account, uint256 withdrawableAt)
func (_BondManager *BondManagerFilterer) WatchWithdrawalRequested(opts *bind.WatchOpts, sink chan<- *BondManagerWithdrawalRequested, account []common.Address) (event.Subscription, error) {

	var accountRule []interface{}
	for _, accountItem := range account {
		accountRule = append(accountRule, accountItem)
	}

	logs, sub, err := _BondManager.contract.WatchLogs(opts, "WithdrawalRequested", accountRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BondManagerWithdrawalRequested)
				if err := _BondManager.contract.UnpackLog(event, "WithdrawalRequested", log); err != nil {
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

// ParseWithdrawalRequested is a log parse operation binding the contract event 0xe670e4e82118d22a1f9ee18920455ebc958bae26a90a05d31d3378788b1b0e44.
//
// Solidity: event WithdrawalRequested(address indexed account, uint256 withdrawableAt)
func (_BondManager *BondManagerFilterer) ParseWithdrawalRequested(log types.Log) (*BondManagerWithdrawalRequested, error) {
	event := new(BondManagerWithdrawalRequested)
	if err := _BondManager.contract.UnpackLog(event, "WithdrawalRequested", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
