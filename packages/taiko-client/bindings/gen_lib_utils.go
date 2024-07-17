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

// LibUtilsMetaData contains all meta data concerning the LibUtils contract.
var LibUtilsMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"event\",\"name\":\"BlockVerified\",\"inputs\":[{\"name\":\"blockId\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"prover\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"tier\",\"type\":\"uint16\",\"indexed\":false,\"internalType\":\"uint16\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BlockVerified2\",\"inputs\":[{\"name\":\"blockId\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"prover\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"tier\",\"type\":\"uint16\",\"indexed\":false,\"internalType\":\"uint16\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"L1_BLOCK_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_INVALID_BLOCK_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_INVALID_GENESIS_HASH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_TRANSITION_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_UNEXPECTED_TRANSITION_ID\",\"inputs\":[]}]",
}

// LibUtilsABI is the input ABI used to generate the binding from.
// Deprecated: Use LibUtilsMetaData.ABI instead.
var LibUtilsABI = LibUtilsMetaData.ABI

// LibUtils is an auto generated Go binding around an Ethereum contract.
type LibUtils struct {
	LibUtilsCaller     // Read-only binding to the contract
	LibUtilsTransactor // Write-only binding to the contract
	LibUtilsFilterer   // Log filterer for contract events
}

// LibUtilsCaller is an auto generated read-only Go binding around an Ethereum contract.
type LibUtilsCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// LibUtilsTransactor is an auto generated write-only Go binding around an Ethereum contract.
type LibUtilsTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// LibUtilsFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type LibUtilsFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// LibUtilsSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type LibUtilsSession struct {
	Contract     *LibUtils         // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// LibUtilsCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type LibUtilsCallerSession struct {
	Contract *LibUtilsCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts   // Call options to use throughout this session
}

// LibUtilsTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type LibUtilsTransactorSession struct {
	Contract     *LibUtilsTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts   // Transaction auth options to use throughout this session
}

// LibUtilsRaw is an auto generated low-level Go binding around an Ethereum contract.
type LibUtilsRaw struct {
	Contract *LibUtils // Generic contract binding to access the raw methods on
}

// LibUtilsCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type LibUtilsCallerRaw struct {
	Contract *LibUtilsCaller // Generic read-only contract binding to access the raw methods on
}

// LibUtilsTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type LibUtilsTransactorRaw struct {
	Contract *LibUtilsTransactor // Generic write-only contract binding to access the raw methods on
}

// NewLibUtils creates a new instance of LibUtils, bound to a specific deployed contract.
func NewLibUtils(address common.Address, backend bind.ContractBackend) (*LibUtils, error) {
	contract, err := bindLibUtils(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &LibUtils{LibUtilsCaller: LibUtilsCaller{contract: contract}, LibUtilsTransactor: LibUtilsTransactor{contract: contract}, LibUtilsFilterer: LibUtilsFilterer{contract: contract}}, nil
}

// NewLibUtilsCaller creates a new read-only instance of LibUtils, bound to a specific deployed contract.
func NewLibUtilsCaller(address common.Address, caller bind.ContractCaller) (*LibUtilsCaller, error) {
	contract, err := bindLibUtils(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &LibUtilsCaller{contract: contract}, nil
}

// NewLibUtilsTransactor creates a new write-only instance of LibUtils, bound to a specific deployed contract.
func NewLibUtilsTransactor(address common.Address, transactor bind.ContractTransactor) (*LibUtilsTransactor, error) {
	contract, err := bindLibUtils(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &LibUtilsTransactor{contract: contract}, nil
}

// NewLibUtilsFilterer creates a new log filterer instance of LibUtils, bound to a specific deployed contract.
func NewLibUtilsFilterer(address common.Address, filterer bind.ContractFilterer) (*LibUtilsFilterer, error) {
	contract, err := bindLibUtils(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &LibUtilsFilterer{contract: contract}, nil
}

// bindLibUtils binds a generic wrapper to an already deployed contract.
func bindLibUtils(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := LibUtilsMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_LibUtils *LibUtilsRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _LibUtils.Contract.LibUtilsCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_LibUtils *LibUtilsRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _LibUtils.Contract.LibUtilsTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_LibUtils *LibUtilsRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _LibUtils.Contract.LibUtilsTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_LibUtils *LibUtilsCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _LibUtils.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_LibUtils *LibUtilsTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _LibUtils.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_LibUtils *LibUtilsTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _LibUtils.Contract.contract.Transact(opts, method, params...)
}

// LibUtilsBlockVerifiedIterator is returned from FilterBlockVerified and is used to iterate over the raw logs and unpacked data for BlockVerified events raised by the LibUtils contract.
type LibUtilsBlockVerifiedIterator struct {
	Event *LibUtilsBlockVerified // Event containing the contract specifics and raw log

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
func (it *LibUtilsBlockVerifiedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(LibUtilsBlockVerified)
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
		it.Event = new(LibUtilsBlockVerified)
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
func (it *LibUtilsBlockVerifiedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *LibUtilsBlockVerifiedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// LibUtilsBlockVerified represents a BlockVerified event raised by the LibUtils contract.
type LibUtilsBlockVerified struct {
	BlockId   *big.Int
	Prover    common.Address
	BlockHash [32]byte
	StateRoot [32]byte
	Tier      uint16
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterBlockVerified is a free log retrieval operation binding the contract event 0xdecbd2c61cbda254917d6fd4c980a470701e8f9f1b744f6ad163ca70ca5db289.
//
// Solidity: event BlockVerified(uint256 indexed blockId, address indexed prover, bytes32 blockHash, bytes32 stateRoot, uint16 tier)
func (_LibUtils *LibUtilsFilterer) FilterBlockVerified(opts *bind.FilterOpts, blockId []*big.Int, prover []common.Address) (*LibUtilsBlockVerifiedIterator, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}
	var proverRule []interface{}
	for _, proverItem := range prover {
		proverRule = append(proverRule, proverItem)
	}

	logs, sub, err := _LibUtils.contract.FilterLogs(opts, "BlockVerified", blockIdRule, proverRule)
	if err != nil {
		return nil, err
	}
	return &LibUtilsBlockVerifiedIterator{contract: _LibUtils.contract, event: "BlockVerified", logs: logs, sub: sub}, nil
}

// WatchBlockVerified is a free log subscription operation binding the contract event 0xdecbd2c61cbda254917d6fd4c980a470701e8f9f1b744f6ad163ca70ca5db289.
//
// Solidity: event BlockVerified(uint256 indexed blockId, address indexed prover, bytes32 blockHash, bytes32 stateRoot, uint16 tier)
func (_LibUtils *LibUtilsFilterer) WatchBlockVerified(opts *bind.WatchOpts, sink chan<- *LibUtilsBlockVerified, blockId []*big.Int, prover []common.Address) (event.Subscription, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}
	var proverRule []interface{}
	for _, proverItem := range prover {
		proverRule = append(proverRule, proverItem)
	}

	logs, sub, err := _LibUtils.contract.WatchLogs(opts, "BlockVerified", blockIdRule, proverRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(LibUtilsBlockVerified)
				if err := _LibUtils.contract.UnpackLog(event, "BlockVerified", log); err != nil {
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

// ParseBlockVerified is a log parse operation binding the contract event 0xdecbd2c61cbda254917d6fd4c980a470701e8f9f1b744f6ad163ca70ca5db289.
//
// Solidity: event BlockVerified(uint256 indexed blockId, address indexed prover, bytes32 blockHash, bytes32 stateRoot, uint16 tier)
func (_LibUtils *LibUtilsFilterer) ParseBlockVerified(log types.Log) (*LibUtilsBlockVerified, error) {
	event := new(LibUtilsBlockVerified)
	if err := _LibUtils.contract.UnpackLog(event, "BlockVerified", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// LibUtilsBlockVerified2Iterator is returned from FilterBlockVerified2 and is used to iterate over the raw logs and unpacked data for BlockVerified2 events raised by the LibUtils contract.
type LibUtilsBlockVerified2Iterator struct {
	Event *LibUtilsBlockVerified2 // Event containing the contract specifics and raw log

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
func (it *LibUtilsBlockVerified2Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(LibUtilsBlockVerified2)
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
		it.Event = new(LibUtilsBlockVerified2)
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
func (it *LibUtilsBlockVerified2Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *LibUtilsBlockVerified2Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// LibUtilsBlockVerified2 represents a BlockVerified2 event raised by the LibUtils contract.
type LibUtilsBlockVerified2 struct {
	BlockId   *big.Int
	Prover    common.Address
	BlockHash [32]byte
	Tier      uint16
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterBlockVerified2 is a free log retrieval operation binding the contract event 0xa12efc32945119002b96e2c528a7832e0b446590488c91c06ca2201c6642ac22.
//
// Solidity: event BlockVerified2(uint256 indexed blockId, address indexed prover, bytes32 blockHash, uint16 tier)
func (_LibUtils *LibUtilsFilterer) FilterBlockVerified2(opts *bind.FilterOpts, blockId []*big.Int, prover []common.Address) (*LibUtilsBlockVerified2Iterator, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}
	var proverRule []interface{}
	for _, proverItem := range prover {
		proverRule = append(proverRule, proverItem)
	}

	logs, sub, err := _LibUtils.contract.FilterLogs(opts, "BlockVerified2", blockIdRule, proverRule)
	if err != nil {
		return nil, err
	}
	return &LibUtilsBlockVerified2Iterator{contract: _LibUtils.contract, event: "BlockVerified2", logs: logs, sub: sub}, nil
}

// WatchBlockVerified2 is a free log subscription operation binding the contract event 0xa12efc32945119002b96e2c528a7832e0b446590488c91c06ca2201c6642ac22.
//
// Solidity: event BlockVerified2(uint256 indexed blockId, address indexed prover, bytes32 blockHash, uint16 tier)
func (_LibUtils *LibUtilsFilterer) WatchBlockVerified2(opts *bind.WatchOpts, sink chan<- *LibUtilsBlockVerified2, blockId []*big.Int, prover []common.Address) (event.Subscription, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}
	var proverRule []interface{}
	for _, proverItem := range prover {
		proverRule = append(proverRule, proverItem)
	}

	logs, sub, err := _LibUtils.contract.WatchLogs(opts, "BlockVerified2", blockIdRule, proverRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(LibUtilsBlockVerified2)
				if err := _LibUtils.contract.UnpackLog(event, "BlockVerified2", log); err != nil {
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

// ParseBlockVerified2 is a log parse operation binding the contract event 0xa12efc32945119002b96e2c528a7832e0b446590488c91c06ca2201c6642ac22.
//
// Solidity: event BlockVerified2(uint256 indexed blockId, address indexed prover, bytes32 blockHash, uint16 tier)
func (_LibUtils *LibUtilsFilterer) ParseBlockVerified2(log types.Log) (*LibUtilsBlockVerified2, error) {
	event := new(LibUtilsBlockVerified2)
	if err := _LibUtils.contract.UnpackLog(event, "BlockVerified2", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
