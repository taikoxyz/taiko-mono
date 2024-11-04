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

// LibProvingMetaData contains all meta data concerning the LibProving contract.
var LibProvingMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"event\",\"name\":\"BlockVerifiedV2\",\"inputs\":[{\"name\":\"blockId\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"prover\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"tier\",\"type\":\"uint16\",\"indexed\":false,\"internalType\":\"uint16\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondCredited\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"blockId\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondDebited\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"blockId\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BondDeposited\",\"inputs\":[{\"name\":\"user\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ProvingPaused\",\"inputs\":[{\"name\":\"paused\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransitionContestedV2\",\"inputs\":[{\"name\":\"blockId\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"tran\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structTaikoData.Transition\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"graffiti\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"contester\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"contestBond\",\"type\":\"uint96\",\"indexed\":false,\"internalType\":\"uint96\"},{\"name\":\"tier\",\"type\":\"uint16\",\"indexed\":false,\"internalType\":\"uint16\"},{\"name\":\"proposedIn\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TransitionProvedV2\",\"inputs\":[{\"name\":\"blockId\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"tran\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structTaikoData.Transition\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"graffiti\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"prover\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"validityBond\",\"type\":\"uint96\",\"indexed\":false,\"internalType\":\"uint96\"},{\"name\":\"tier\",\"type\":\"uint16\",\"indexed\":false,\"internalType\":\"uint16\"},{\"name\":\"proposedIn\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"L1_ALREADY_CONTESTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_ALREADY_PROVED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_BLOCK_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_BLOCK_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_CANNOT_CONTEST\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_DIFF_VERIFIER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_INVALID_BLOCK_ID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_INVALID_MSG_VALUE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_INVALID_PARAMS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_INVALID_TIER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_INVALID_TRANSITION\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_NOT_ASSIGNED_PROVER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_PROVING_PAUSED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_TRANSITION_ID_ZERO\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"L1_UNEXPECTED_TRANSITION_ID\",\"inputs\":[]}]",
}

// LibProvingABI is the input ABI used to generate the binding from.
// Deprecated: Use LibProvingMetaData.ABI instead.
var LibProvingABI = LibProvingMetaData.ABI

// LibProving is an auto generated Go binding around an Ethereum contract.
type LibProving struct {
	LibProvingCaller     // Read-only binding to the contract
	LibProvingTransactor // Write-only binding to the contract
	LibProvingFilterer   // Log filterer for contract events
}

// LibProvingCaller is an auto generated read-only Go binding around an Ethereum contract.
type LibProvingCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// LibProvingTransactor is an auto generated write-only Go binding around an Ethereum contract.
type LibProvingTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// LibProvingFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type LibProvingFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// LibProvingSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type LibProvingSession struct {
	Contract     *LibProving       // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// LibProvingCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type LibProvingCallerSession struct {
	Contract *LibProvingCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts     // Call options to use throughout this session
}

// LibProvingTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type LibProvingTransactorSession struct {
	Contract     *LibProvingTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts     // Transaction auth options to use throughout this session
}

// LibProvingRaw is an auto generated low-level Go binding around an Ethereum contract.
type LibProvingRaw struct {
	Contract *LibProving // Generic contract binding to access the raw methods on
}

// LibProvingCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type LibProvingCallerRaw struct {
	Contract *LibProvingCaller // Generic read-only contract binding to access the raw methods on
}

// LibProvingTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type LibProvingTransactorRaw struct {
	Contract *LibProvingTransactor // Generic write-only contract binding to access the raw methods on
}

// NewLibProving creates a new instance of LibProving, bound to a specific deployed contract.
func NewLibProving(address common.Address, backend bind.ContractBackend) (*LibProving, error) {
	contract, err := bindLibProving(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &LibProving{LibProvingCaller: LibProvingCaller{contract: contract}, LibProvingTransactor: LibProvingTransactor{contract: contract}, LibProvingFilterer: LibProvingFilterer{contract: contract}}, nil
}

// NewLibProvingCaller creates a new read-only instance of LibProving, bound to a specific deployed contract.
func NewLibProvingCaller(address common.Address, caller bind.ContractCaller) (*LibProvingCaller, error) {
	contract, err := bindLibProving(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &LibProvingCaller{contract: contract}, nil
}

// NewLibProvingTransactor creates a new write-only instance of LibProving, bound to a specific deployed contract.
func NewLibProvingTransactor(address common.Address, transactor bind.ContractTransactor) (*LibProvingTransactor, error) {
	contract, err := bindLibProving(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &LibProvingTransactor{contract: contract}, nil
}

// NewLibProvingFilterer creates a new log filterer instance of LibProving, bound to a specific deployed contract.
func NewLibProvingFilterer(address common.Address, filterer bind.ContractFilterer) (*LibProvingFilterer, error) {
	contract, err := bindLibProving(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &LibProvingFilterer{contract: contract}, nil
}

// bindLibProving binds a generic wrapper to an already deployed contract.
func bindLibProving(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := LibProvingMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_LibProving *LibProvingRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _LibProving.Contract.LibProvingCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_LibProving *LibProvingRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _LibProving.Contract.LibProvingTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_LibProving *LibProvingRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _LibProving.Contract.LibProvingTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_LibProving *LibProvingCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _LibProving.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_LibProving *LibProvingTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _LibProving.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_LibProving *LibProvingTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _LibProving.Contract.contract.Transact(opts, method, params...)
}

// LibProvingBlockVerifiedV2Iterator is returned from FilterBlockVerifiedV2 and is used to iterate over the raw logs and unpacked data for BlockVerifiedV2 events raised by the LibProving contract.
type LibProvingBlockVerifiedV2Iterator struct {
	Event *LibProvingBlockVerifiedV2 // Event containing the contract specifics and raw log

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
func (it *LibProvingBlockVerifiedV2Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(LibProvingBlockVerifiedV2)
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
		it.Event = new(LibProvingBlockVerifiedV2)
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
func (it *LibProvingBlockVerifiedV2Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *LibProvingBlockVerifiedV2Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// LibProvingBlockVerifiedV2 represents a BlockVerifiedV2 event raised by the LibProving contract.
type LibProvingBlockVerifiedV2 struct {
	BlockId   *big.Int
	Prover    common.Address
	BlockHash [32]byte
	Tier      uint16
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterBlockVerifiedV2 is a free log retrieval operation binding the contract event 0xe5a390d9800811154279af0c1a80d3bdf558ea91f1301e7c6ec3c1ad83e80aef.
//
// Solidity: event BlockVerifiedV2(uint256 indexed blockId, address indexed prover, bytes32 blockHash, uint16 tier)
func (_LibProving *LibProvingFilterer) FilterBlockVerifiedV2(opts *bind.FilterOpts, blockId []*big.Int, prover []common.Address) (*LibProvingBlockVerifiedV2Iterator, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}
	var proverRule []interface{}
	for _, proverItem := range prover {
		proverRule = append(proverRule, proverItem)
	}

	logs, sub, err := _LibProving.contract.FilterLogs(opts, "BlockVerifiedV2", blockIdRule, proverRule)
	if err != nil {
		return nil, err
	}
	return &LibProvingBlockVerifiedV2Iterator{contract: _LibProving.contract, event: "BlockVerifiedV2", logs: logs, sub: sub}, nil
}

// WatchBlockVerifiedV2 is a free log subscription operation binding the contract event 0xe5a390d9800811154279af0c1a80d3bdf558ea91f1301e7c6ec3c1ad83e80aef.
//
// Solidity: event BlockVerifiedV2(uint256 indexed blockId, address indexed prover, bytes32 blockHash, uint16 tier)
func (_LibProving *LibProvingFilterer) WatchBlockVerifiedV2(opts *bind.WatchOpts, sink chan<- *LibProvingBlockVerifiedV2, blockId []*big.Int, prover []common.Address) (event.Subscription, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}
	var proverRule []interface{}
	for _, proverItem := range prover {
		proverRule = append(proverRule, proverItem)
	}

	logs, sub, err := _LibProving.contract.WatchLogs(opts, "BlockVerifiedV2", blockIdRule, proverRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(LibProvingBlockVerifiedV2)
				if err := _LibProving.contract.UnpackLog(event, "BlockVerifiedV2", log); err != nil {
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

// ParseBlockVerifiedV2 is a log parse operation binding the contract event 0xe5a390d9800811154279af0c1a80d3bdf558ea91f1301e7c6ec3c1ad83e80aef.
//
// Solidity: event BlockVerifiedV2(uint256 indexed blockId, address indexed prover, bytes32 blockHash, uint16 tier)
func (_LibProving *LibProvingFilterer) ParseBlockVerifiedV2(log types.Log) (*LibProvingBlockVerifiedV2, error) {
	event := new(LibProvingBlockVerifiedV2)
	if err := _LibProving.contract.UnpackLog(event, "BlockVerifiedV2", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// LibProvingBondCreditedIterator is returned from FilterBondCredited and is used to iterate over the raw logs and unpacked data for BondCredited events raised by the LibProving contract.
type LibProvingBondCreditedIterator struct {
	Event *LibProvingBondCredited // Event containing the contract specifics and raw log

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
func (it *LibProvingBondCreditedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(LibProvingBondCredited)
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
		it.Event = new(LibProvingBondCredited)
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
func (it *LibProvingBondCreditedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *LibProvingBondCreditedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// LibProvingBondCredited represents a BondCredited event raised by the LibProving contract.
type LibProvingBondCredited struct {
	User    common.Address
	BlockId *big.Int
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterBondCredited is a free log retrieval operation binding the contract event 0x767672484792852973001cc22546fd96c3d7466da3c383e42741793dce5e4169.
//
// Solidity: event BondCredited(address indexed user, uint256 blockId, uint256 amount)
func (_LibProving *LibProvingFilterer) FilterBondCredited(opts *bind.FilterOpts, user []common.Address) (*LibProvingBondCreditedIterator, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _LibProving.contract.FilterLogs(opts, "BondCredited", userRule)
	if err != nil {
		return nil, err
	}
	return &LibProvingBondCreditedIterator{contract: _LibProving.contract, event: "BondCredited", logs: logs, sub: sub}, nil
}

// WatchBondCredited is a free log subscription operation binding the contract event 0x767672484792852973001cc22546fd96c3d7466da3c383e42741793dce5e4169.
//
// Solidity: event BondCredited(address indexed user, uint256 blockId, uint256 amount)
func (_LibProving *LibProvingFilterer) WatchBondCredited(opts *bind.WatchOpts, sink chan<- *LibProvingBondCredited, user []common.Address) (event.Subscription, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _LibProving.contract.WatchLogs(opts, "BondCredited", userRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(LibProvingBondCredited)
				if err := _LibProving.contract.UnpackLog(event, "BondCredited", log); err != nil {
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

// ParseBondCredited is a log parse operation binding the contract event 0x767672484792852973001cc22546fd96c3d7466da3c383e42741793dce5e4169.
//
// Solidity: event BondCredited(address indexed user, uint256 blockId, uint256 amount)
func (_LibProving *LibProvingFilterer) ParseBondCredited(log types.Log) (*LibProvingBondCredited, error) {
	event := new(LibProvingBondCredited)
	if err := _LibProving.contract.UnpackLog(event, "BondCredited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// LibProvingBondDebitedIterator is returned from FilterBondDebited and is used to iterate over the raw logs and unpacked data for BondDebited events raised by the LibProving contract.
type LibProvingBondDebitedIterator struct {
	Event *LibProvingBondDebited // Event containing the contract specifics and raw log

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
func (it *LibProvingBondDebitedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(LibProvingBondDebited)
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
		it.Event = new(LibProvingBondDebited)
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
func (it *LibProvingBondDebitedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *LibProvingBondDebitedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// LibProvingBondDebited represents a BondDebited event raised by the LibProving contract.
type LibProvingBondDebited struct {
	User    common.Address
	BlockId *big.Int
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterBondDebited is a free log retrieval operation binding the contract event 0xf4636413c66bd7ef2a1d735c30d22543acb0fba1b0892503bef0734b237c3f37.
//
// Solidity: event BondDebited(address indexed user, uint256 blockId, uint256 amount)
func (_LibProving *LibProvingFilterer) FilterBondDebited(opts *bind.FilterOpts, user []common.Address) (*LibProvingBondDebitedIterator, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _LibProving.contract.FilterLogs(opts, "BondDebited", userRule)
	if err != nil {
		return nil, err
	}
	return &LibProvingBondDebitedIterator{contract: _LibProving.contract, event: "BondDebited", logs: logs, sub: sub}, nil
}

// WatchBondDebited is a free log subscription operation binding the contract event 0xf4636413c66bd7ef2a1d735c30d22543acb0fba1b0892503bef0734b237c3f37.
//
// Solidity: event BondDebited(address indexed user, uint256 blockId, uint256 amount)
func (_LibProving *LibProvingFilterer) WatchBondDebited(opts *bind.WatchOpts, sink chan<- *LibProvingBondDebited, user []common.Address) (event.Subscription, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _LibProving.contract.WatchLogs(opts, "BondDebited", userRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(LibProvingBondDebited)
				if err := _LibProving.contract.UnpackLog(event, "BondDebited", log); err != nil {
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

// ParseBondDebited is a log parse operation binding the contract event 0xf4636413c66bd7ef2a1d735c30d22543acb0fba1b0892503bef0734b237c3f37.
//
// Solidity: event BondDebited(address indexed user, uint256 blockId, uint256 amount)
func (_LibProving *LibProvingFilterer) ParseBondDebited(log types.Log) (*LibProvingBondDebited, error) {
	event := new(LibProvingBondDebited)
	if err := _LibProving.contract.UnpackLog(event, "BondDebited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// LibProvingBondDepositedIterator is returned from FilterBondDeposited and is used to iterate over the raw logs and unpacked data for BondDeposited events raised by the LibProving contract.
type LibProvingBondDepositedIterator struct {
	Event *LibProvingBondDeposited // Event containing the contract specifics and raw log

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
func (it *LibProvingBondDepositedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(LibProvingBondDeposited)
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
		it.Event = new(LibProvingBondDeposited)
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
func (it *LibProvingBondDepositedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *LibProvingBondDepositedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// LibProvingBondDeposited represents a BondDeposited event raised by the LibProving contract.
type LibProvingBondDeposited struct {
	User   common.Address
	Amount *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBondDeposited is a free log retrieval operation binding the contract event 0x8ed8c6869618197b68315ade66e75ed3906c97b111fa3ab81e5760046825c7db.
//
// Solidity: event BondDeposited(address indexed user, uint256 amount)
func (_LibProving *LibProvingFilterer) FilterBondDeposited(opts *bind.FilterOpts, user []common.Address) (*LibProvingBondDepositedIterator, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _LibProving.contract.FilterLogs(opts, "BondDeposited", userRule)
	if err != nil {
		return nil, err
	}
	return &LibProvingBondDepositedIterator{contract: _LibProving.contract, event: "BondDeposited", logs: logs, sub: sub}, nil
}

// WatchBondDeposited is a free log subscription operation binding the contract event 0x8ed8c6869618197b68315ade66e75ed3906c97b111fa3ab81e5760046825c7db.
//
// Solidity: event BondDeposited(address indexed user, uint256 amount)
func (_LibProving *LibProvingFilterer) WatchBondDeposited(opts *bind.WatchOpts, sink chan<- *LibProvingBondDeposited, user []common.Address) (event.Subscription, error) {

	var userRule []interface{}
	for _, userItem := range user {
		userRule = append(userRule, userItem)
	}

	logs, sub, err := _LibProving.contract.WatchLogs(opts, "BondDeposited", userRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(LibProvingBondDeposited)
				if err := _LibProving.contract.UnpackLog(event, "BondDeposited", log); err != nil {
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

// ParseBondDeposited is a log parse operation binding the contract event 0x8ed8c6869618197b68315ade66e75ed3906c97b111fa3ab81e5760046825c7db.
//
// Solidity: event BondDeposited(address indexed user, uint256 amount)
func (_LibProving *LibProvingFilterer) ParseBondDeposited(log types.Log) (*LibProvingBondDeposited, error) {
	event := new(LibProvingBondDeposited)
	if err := _LibProving.contract.UnpackLog(event, "BondDeposited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// LibProvingProvingPausedIterator is returned from FilterProvingPaused and is used to iterate over the raw logs and unpacked data for ProvingPaused events raised by the LibProving contract.
type LibProvingProvingPausedIterator struct {
	Event *LibProvingProvingPaused // Event containing the contract specifics and raw log

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
func (it *LibProvingProvingPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(LibProvingProvingPaused)
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
		it.Event = new(LibProvingProvingPaused)
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
func (it *LibProvingProvingPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *LibProvingProvingPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// LibProvingProvingPaused represents a ProvingPaused event raised by the LibProving contract.
type LibProvingProvingPaused struct {
	Paused bool
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterProvingPaused is a free log retrieval operation binding the contract event 0xed64db85835d07c3c990b8ebdd55e32d64e5ed53143b6ef2179e7bfaf17ddc3b.
//
// Solidity: event ProvingPaused(bool paused)
func (_LibProving *LibProvingFilterer) FilterProvingPaused(opts *bind.FilterOpts) (*LibProvingProvingPausedIterator, error) {

	logs, sub, err := _LibProving.contract.FilterLogs(opts, "ProvingPaused")
	if err != nil {
		return nil, err
	}
	return &LibProvingProvingPausedIterator{contract: _LibProving.contract, event: "ProvingPaused", logs: logs, sub: sub}, nil
}

// WatchProvingPaused is a free log subscription operation binding the contract event 0xed64db85835d07c3c990b8ebdd55e32d64e5ed53143b6ef2179e7bfaf17ddc3b.
//
// Solidity: event ProvingPaused(bool paused)
func (_LibProving *LibProvingFilterer) WatchProvingPaused(opts *bind.WatchOpts, sink chan<- *LibProvingProvingPaused) (event.Subscription, error) {

	logs, sub, err := _LibProving.contract.WatchLogs(opts, "ProvingPaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(LibProvingProvingPaused)
				if err := _LibProving.contract.UnpackLog(event, "ProvingPaused", log); err != nil {
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

// ParseProvingPaused is a log parse operation binding the contract event 0xed64db85835d07c3c990b8ebdd55e32d64e5ed53143b6ef2179e7bfaf17ddc3b.
//
// Solidity: event ProvingPaused(bool paused)
func (_LibProving *LibProvingFilterer) ParseProvingPaused(log types.Log) (*LibProvingProvingPaused, error) {
	event := new(LibProvingProvingPaused)
	if err := _LibProving.contract.UnpackLog(event, "ProvingPaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// LibProvingTransitionContestedV2Iterator is returned from FilterTransitionContestedV2 and is used to iterate over the raw logs and unpacked data for TransitionContestedV2 events raised by the LibProving contract.
type LibProvingTransitionContestedV2Iterator struct {
	Event *LibProvingTransitionContestedV2 // Event containing the contract specifics and raw log

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
func (it *LibProvingTransitionContestedV2Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(LibProvingTransitionContestedV2)
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
		it.Event = new(LibProvingTransitionContestedV2)
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
func (it *LibProvingTransitionContestedV2Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *LibProvingTransitionContestedV2Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// LibProvingTransitionContestedV2 represents a TransitionContestedV2 event raised by the LibProving contract.
type LibProvingTransitionContestedV2 struct {
	BlockId     *big.Int
	Tran        TaikoDataTransition
	Contester   common.Address
	ContestBond *big.Int
	Tier        uint16
	ProposedIn  uint64
	Raw         types.Log // Blockchain specific contextual infos
}

// FilterTransitionContestedV2 is a free log retrieval operation binding the contract event 0x53b2379d5e9bcacdfe56b4a51c3fd92ebfff4b1e8e8638f7f7e85163260a6f99.
//
// Solidity: event TransitionContestedV2(uint256 indexed blockId, (bytes32,bytes32,bytes32,bytes32) tran, address contester, uint96 contestBond, uint16 tier, uint64 proposedIn)
func (_LibProving *LibProvingFilterer) FilterTransitionContestedV2(opts *bind.FilterOpts, blockId []*big.Int) (*LibProvingTransitionContestedV2Iterator, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _LibProving.contract.FilterLogs(opts, "TransitionContestedV2", blockIdRule)
	if err != nil {
		return nil, err
	}
	return &LibProvingTransitionContestedV2Iterator{contract: _LibProving.contract, event: "TransitionContestedV2", logs: logs, sub: sub}, nil
}

// WatchTransitionContestedV2 is a free log subscription operation binding the contract event 0x53b2379d5e9bcacdfe56b4a51c3fd92ebfff4b1e8e8638f7f7e85163260a6f99.
//
// Solidity: event TransitionContestedV2(uint256 indexed blockId, (bytes32,bytes32,bytes32,bytes32) tran, address contester, uint96 contestBond, uint16 tier, uint64 proposedIn)
func (_LibProving *LibProvingFilterer) WatchTransitionContestedV2(opts *bind.WatchOpts, sink chan<- *LibProvingTransitionContestedV2, blockId []*big.Int) (event.Subscription, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _LibProving.contract.WatchLogs(opts, "TransitionContestedV2", blockIdRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(LibProvingTransitionContestedV2)
				if err := _LibProving.contract.UnpackLog(event, "TransitionContestedV2", log); err != nil {
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

// ParseTransitionContestedV2 is a log parse operation binding the contract event 0x53b2379d5e9bcacdfe56b4a51c3fd92ebfff4b1e8e8638f7f7e85163260a6f99.
//
// Solidity: event TransitionContestedV2(uint256 indexed blockId, (bytes32,bytes32,bytes32,bytes32) tran, address contester, uint96 contestBond, uint16 tier, uint64 proposedIn)
func (_LibProving *LibProvingFilterer) ParseTransitionContestedV2(log types.Log) (*LibProvingTransitionContestedV2, error) {
	event := new(LibProvingTransitionContestedV2)
	if err := _LibProving.contract.UnpackLog(event, "TransitionContestedV2", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// LibProvingTransitionProvedV2Iterator is returned from FilterTransitionProvedV2 and is used to iterate over the raw logs and unpacked data for TransitionProvedV2 events raised by the LibProving contract.
type LibProvingTransitionProvedV2Iterator struct {
	Event *LibProvingTransitionProvedV2 // Event containing the contract specifics and raw log

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
func (it *LibProvingTransitionProvedV2Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(LibProvingTransitionProvedV2)
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
		it.Event = new(LibProvingTransitionProvedV2)
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
func (it *LibProvingTransitionProvedV2Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *LibProvingTransitionProvedV2Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// LibProvingTransitionProvedV2 represents a TransitionProvedV2 event raised by the LibProving contract.
type LibProvingTransitionProvedV2 struct {
	BlockId      *big.Int
	Tran         TaikoDataTransition
	Prover       common.Address
	ValidityBond *big.Int
	Tier         uint16
	ProposedIn   uint64
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterTransitionProvedV2 is a free log retrieval operation binding the contract event 0x11a9112e5724f21b226e2535a95a264a80c9626ed4c0923faaa9fa6556467488.
//
// Solidity: event TransitionProvedV2(uint256 indexed blockId, (bytes32,bytes32,bytes32,bytes32) tran, address prover, uint96 validityBond, uint16 tier, uint64 proposedIn)
func (_LibProving *LibProvingFilterer) FilterTransitionProvedV2(opts *bind.FilterOpts, blockId []*big.Int) (*LibProvingTransitionProvedV2Iterator, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _LibProving.contract.FilterLogs(opts, "TransitionProvedV2", blockIdRule)
	if err != nil {
		return nil, err
	}
	return &LibProvingTransitionProvedV2Iterator{contract: _LibProving.contract, event: "TransitionProvedV2", logs: logs, sub: sub}, nil
}

// WatchTransitionProvedV2 is a free log subscription operation binding the contract event 0x11a9112e5724f21b226e2535a95a264a80c9626ed4c0923faaa9fa6556467488.
//
// Solidity: event TransitionProvedV2(uint256 indexed blockId, (bytes32,bytes32,bytes32,bytes32) tran, address prover, uint96 validityBond, uint16 tier, uint64 proposedIn)
func (_LibProving *LibProvingFilterer) WatchTransitionProvedV2(opts *bind.WatchOpts, sink chan<- *LibProvingTransitionProvedV2, blockId []*big.Int) (event.Subscription, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _LibProving.contract.WatchLogs(opts, "TransitionProvedV2", blockIdRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(LibProvingTransitionProvedV2)
				if err := _LibProving.contract.UnpackLog(event, "TransitionProvedV2", log); err != nil {
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

// ParseTransitionProvedV2 is a log parse operation binding the contract event 0x11a9112e5724f21b226e2535a95a264a80c9626ed4c0923faaa9fa6556467488.
//
// Solidity: event TransitionProvedV2(uint256 indexed blockId, (bytes32,bytes32,bytes32,bytes32) tran, address prover, uint96 validityBond, uint16 tier, uint64 proposedIn)
func (_LibProving *LibProvingFilterer) ParseTransitionProvedV2(log types.Log) (*LibProvingTransitionProvedV2, error) {
	event := new(LibProvingTransitionProvedV2)
	if err := _LibProving.contract.UnpackLog(event, "TransitionProvedV2", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
