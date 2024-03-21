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

// LibDepositingMetaData contains all meta data concerning the LibDepositing contract.
var LibDepositingMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"event\",\"name\":\"EthDeposited\",\"inputs\":[{\"name\":\"deposit\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structTaikoData.EthDeposit\",\"components\":[{\"name\":\"recipient\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"id\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"L1_INVALID_ETH_DEPOSIT\",\"inputs\":[]}]",
}

// LibDepositingABI is the input ABI used to generate the binding from.
// Deprecated: Use LibDepositingMetaData.ABI instead.
var LibDepositingABI = LibDepositingMetaData.ABI

// LibDepositing is an auto generated Go binding around an Ethereum contract.
type LibDepositing struct {
	LibDepositingCaller     // Read-only binding to the contract
	LibDepositingTransactor // Write-only binding to the contract
	LibDepositingFilterer   // Log filterer for contract events
}

// LibDepositingCaller is an auto generated read-only Go binding around an Ethereum contract.
type LibDepositingCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// LibDepositingTransactor is an auto generated write-only Go binding around an Ethereum contract.
type LibDepositingTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// LibDepositingFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type LibDepositingFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// LibDepositingSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type LibDepositingSession struct {
	Contract     *LibDepositing    // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// LibDepositingCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type LibDepositingCallerSession struct {
	Contract *LibDepositingCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts        // Call options to use throughout this session
}

// LibDepositingTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type LibDepositingTransactorSession struct {
	Contract     *LibDepositingTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts        // Transaction auth options to use throughout this session
}

// LibDepositingRaw is an auto generated low-level Go binding around an Ethereum contract.
type LibDepositingRaw struct {
	Contract *LibDepositing // Generic contract binding to access the raw methods on
}

// LibDepositingCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type LibDepositingCallerRaw struct {
	Contract *LibDepositingCaller // Generic read-only contract binding to access the raw methods on
}

// LibDepositingTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type LibDepositingTransactorRaw struct {
	Contract *LibDepositingTransactor // Generic write-only contract binding to access the raw methods on
}

// NewLibDepositing creates a new instance of LibDepositing, bound to a specific deployed contract.
func NewLibDepositing(address common.Address, backend bind.ContractBackend) (*LibDepositing, error) {
	contract, err := bindLibDepositing(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &LibDepositing{LibDepositingCaller: LibDepositingCaller{contract: contract}, LibDepositingTransactor: LibDepositingTransactor{contract: contract}, LibDepositingFilterer: LibDepositingFilterer{contract: contract}}, nil
}

// NewLibDepositingCaller creates a new read-only instance of LibDepositing, bound to a specific deployed contract.
func NewLibDepositingCaller(address common.Address, caller bind.ContractCaller) (*LibDepositingCaller, error) {
	contract, err := bindLibDepositing(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &LibDepositingCaller{contract: contract}, nil
}

// NewLibDepositingTransactor creates a new write-only instance of LibDepositing, bound to a specific deployed contract.
func NewLibDepositingTransactor(address common.Address, transactor bind.ContractTransactor) (*LibDepositingTransactor, error) {
	contract, err := bindLibDepositing(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &LibDepositingTransactor{contract: contract}, nil
}

// NewLibDepositingFilterer creates a new log filterer instance of LibDepositing, bound to a specific deployed contract.
func NewLibDepositingFilterer(address common.Address, filterer bind.ContractFilterer) (*LibDepositingFilterer, error) {
	contract, err := bindLibDepositing(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &LibDepositingFilterer{contract: contract}, nil
}

// bindLibDepositing binds a generic wrapper to an already deployed contract.
func bindLibDepositing(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := LibDepositingMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_LibDepositing *LibDepositingRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _LibDepositing.Contract.LibDepositingCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_LibDepositing *LibDepositingRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _LibDepositing.Contract.LibDepositingTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_LibDepositing *LibDepositingRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _LibDepositing.Contract.LibDepositingTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_LibDepositing *LibDepositingCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _LibDepositing.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_LibDepositing *LibDepositingTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _LibDepositing.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_LibDepositing *LibDepositingTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _LibDepositing.Contract.contract.Transact(opts, method, params...)
}

// LibDepositingEthDepositedIterator is returned from FilterEthDeposited and is used to iterate over the raw logs and unpacked data for EthDeposited events raised by the LibDepositing contract.
type LibDepositingEthDepositedIterator struct {
	Event *LibDepositingEthDeposited // Event containing the contract specifics and raw log

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
func (it *LibDepositingEthDepositedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(LibDepositingEthDeposited)
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
		it.Event = new(LibDepositingEthDeposited)
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
func (it *LibDepositingEthDepositedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *LibDepositingEthDepositedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// LibDepositingEthDeposited represents a EthDeposited event raised by the LibDepositing contract.
type LibDepositingEthDeposited struct {
	Deposit TaikoDataEthDeposit
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterEthDeposited is a free log retrieval operation binding the contract event 0x7120a3b075ad25974c5eed76dedb3a217c76c9c6d1f1e201caeba9b89de9a9d9.
//
// Solidity: event EthDeposited((address,uint96,uint64) deposit)
func (_LibDepositing *LibDepositingFilterer) FilterEthDeposited(opts *bind.FilterOpts) (*LibDepositingEthDepositedIterator, error) {

	logs, sub, err := _LibDepositing.contract.FilterLogs(opts, "EthDeposited")
	if err != nil {
		return nil, err
	}
	return &LibDepositingEthDepositedIterator{contract: _LibDepositing.contract, event: "EthDeposited", logs: logs, sub: sub}, nil
}

// WatchEthDeposited is a free log subscription operation binding the contract event 0x7120a3b075ad25974c5eed76dedb3a217c76c9c6d1f1e201caeba9b89de9a9d9.
//
// Solidity: event EthDeposited((address,uint96,uint64) deposit)
func (_LibDepositing *LibDepositingFilterer) WatchEthDeposited(opts *bind.WatchOpts, sink chan<- *LibDepositingEthDeposited) (event.Subscription, error) {

	logs, sub, err := _LibDepositing.contract.WatchLogs(opts, "EthDeposited")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(LibDepositingEthDeposited)
				if err := _LibDepositing.contract.UnpackLog(event, "EthDeposited", log); err != nil {
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

// ParseEthDeposited is a log parse operation binding the contract event 0x7120a3b075ad25974c5eed76dedb3a217c76c9c6d1f1e201caeba9b89de9a9d9.
//
// Solidity: event EthDeposited((address,uint96,uint64) deposit)
func (_LibDepositing *LibDepositingFilterer) ParseEthDeposited(log types.Log) (*LibDepositingEthDeposited, error) {
	event := new(LibDepositingEthDeposited)
	if err := _LibDepositing.contract.UnpackLog(event, "EthDeposited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
