// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package iheadersync

import (
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
	_ = big.NewInt
	_ = strings.NewReader
	_ = ethereum.NotFound
	_ = bind.Bind
	_ = common.Big1
	_ = types.BloomLookup
	_ = event.NewSubscription
)

// IHeaderSyncABI is the input ABI used to generate the binding from.
const IHeaderSyncABI = "[{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"height\",\"type\":\"uint256\"},{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"srcHeight\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"srcHash\",\"type\":\"bytes32\"}],\"name\":\"HeaderSynced\",\"type\":\"event\"},{\"inputs\":[],\"name\":\"getLatestSyncedHeader\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"number\",\"type\":\"uint256\"}],\"name\":\"getSyncedHeader\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"view\",\"type\":\"function\"}]"

// IHeaderSync is an auto generated Go binding around an Ethereum contract.
type IHeaderSync struct {
	IHeaderSyncCaller     // Read-only binding to the contract
	IHeaderSyncTransactor // Write-only binding to the contract
	IHeaderSyncFilterer   // Log filterer for contract events
}

// IHeaderSyncCaller is an auto generated read-only Go binding around an Ethereum contract.
type IHeaderSyncCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// IHeaderSyncTransactor is an auto generated write-only Go binding around an Ethereum contract.
type IHeaderSyncTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// IHeaderSyncFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type IHeaderSyncFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// IHeaderSyncSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type IHeaderSyncSession struct {
	Contract     *IHeaderSync      // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// IHeaderSyncCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type IHeaderSyncCallerSession struct {
	Contract *IHeaderSyncCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts      // Call options to use throughout this session
}

// IHeaderSyncTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type IHeaderSyncTransactorSession struct {
	Contract     *IHeaderSyncTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts      // Transaction auth options to use throughout this session
}

// IHeaderSyncRaw is an auto generated low-level Go binding around an Ethereum contract.
type IHeaderSyncRaw struct {
	Contract *IHeaderSync // Generic contract binding to access the raw methods on
}

// IHeaderSyncCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type IHeaderSyncCallerRaw struct {
	Contract *IHeaderSyncCaller // Generic read-only contract binding to access the raw methods on
}

// IHeaderSyncTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type IHeaderSyncTransactorRaw struct {
	Contract *IHeaderSyncTransactor // Generic write-only contract binding to access the raw methods on
}

// NewIHeaderSync creates a new instance of IHeaderSync, bound to a specific deployed contract.
func NewIHeaderSync(address common.Address, backend bind.ContractBackend) (*IHeaderSync, error) {
	contract, err := bindIHeaderSync(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &IHeaderSync{IHeaderSyncCaller: IHeaderSyncCaller{contract: contract}, IHeaderSyncTransactor: IHeaderSyncTransactor{contract: contract}, IHeaderSyncFilterer: IHeaderSyncFilterer{contract: contract}}, nil
}

// NewIHeaderSyncCaller creates a new read-only instance of IHeaderSync, bound to a specific deployed contract.
func NewIHeaderSyncCaller(address common.Address, caller bind.ContractCaller) (*IHeaderSyncCaller, error) {
	contract, err := bindIHeaderSync(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &IHeaderSyncCaller{contract: contract}, nil
}

// NewIHeaderSyncTransactor creates a new write-only instance of IHeaderSync, bound to a specific deployed contract.
func NewIHeaderSyncTransactor(address common.Address, transactor bind.ContractTransactor) (*IHeaderSyncTransactor, error) {
	contract, err := bindIHeaderSync(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &IHeaderSyncTransactor{contract: contract}, nil
}

// NewIHeaderSyncFilterer creates a new log filterer instance of IHeaderSync, bound to a specific deployed contract.
func NewIHeaderSyncFilterer(address common.Address, filterer bind.ContractFilterer) (*IHeaderSyncFilterer, error) {
	contract, err := bindIHeaderSync(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &IHeaderSyncFilterer{contract: contract}, nil
}

// bindIHeaderSync binds a generic wrapper to an already deployed contract.
func bindIHeaderSync(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := abi.JSON(strings.NewReader(IHeaderSyncABI))
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_IHeaderSync *IHeaderSyncRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _IHeaderSync.Contract.IHeaderSyncCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_IHeaderSync *IHeaderSyncRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _IHeaderSync.Contract.IHeaderSyncTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_IHeaderSync *IHeaderSyncRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _IHeaderSync.Contract.IHeaderSyncTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_IHeaderSync *IHeaderSyncCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _IHeaderSync.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_IHeaderSync *IHeaderSyncTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _IHeaderSync.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_IHeaderSync *IHeaderSyncTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _IHeaderSync.Contract.contract.Transact(opts, method, params...)
}

// GetLatestSyncedHeader is a free data retrieval call binding the contract method 0x5155ce9f.
//
// Solidity: function getLatestSyncedHeader() view returns(bytes32)
func (_IHeaderSync *IHeaderSyncCaller) GetLatestSyncedHeader(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _IHeaderSync.contract.Call(opts, &out, "getLatestSyncedHeader")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetLatestSyncedHeader is a free data retrieval call binding the contract method 0x5155ce9f.
//
// Solidity: function getLatestSyncedHeader() view returns(bytes32)
func (_IHeaderSync *IHeaderSyncSession) GetLatestSyncedHeader() ([32]byte, error) {
	return _IHeaderSync.Contract.GetLatestSyncedHeader(&_IHeaderSync.CallOpts)
}

// GetLatestSyncedHeader is a free data retrieval call binding the contract method 0x5155ce9f.
//
// Solidity: function getLatestSyncedHeader() view returns(bytes32)
func (_IHeaderSync *IHeaderSyncCallerSession) GetLatestSyncedHeader() ([32]byte, error) {
	return _IHeaderSync.Contract.GetLatestSyncedHeader(&_IHeaderSync.CallOpts)
}

// GetSyncedHeader is a free data retrieval call binding the contract method 0x25bf86f2.
//
// Solidity: function getSyncedHeader(uint256 number) view returns(bytes32)
func (_IHeaderSync *IHeaderSyncCaller) GetSyncedHeader(opts *bind.CallOpts, number *big.Int) ([32]byte, error) {
	var out []interface{}
	err := _IHeaderSync.contract.Call(opts, &out, "getSyncedHeader", number)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetSyncedHeader is a free data retrieval call binding the contract method 0x25bf86f2.
//
// Solidity: function getSyncedHeader(uint256 number) view returns(bytes32)
func (_IHeaderSync *IHeaderSyncSession) GetSyncedHeader(number *big.Int) ([32]byte, error) {
	return _IHeaderSync.Contract.GetSyncedHeader(&_IHeaderSync.CallOpts, number)
}

// GetSyncedHeader is a free data retrieval call binding the contract method 0x25bf86f2.
//
// Solidity: function getSyncedHeader(uint256 number) view returns(bytes32)
func (_IHeaderSync *IHeaderSyncCallerSession) GetSyncedHeader(number *big.Int) ([32]byte, error) {
	return _IHeaderSync.Contract.GetSyncedHeader(&_IHeaderSync.CallOpts, number)
}

// IHeaderSyncHeaderSyncedIterator is returned from FilterHeaderSynced and is used to iterate over the raw logs and unpacked data for HeaderSynced events raised by the IHeaderSync contract.
type IHeaderSyncHeaderSyncedIterator struct {
	Event *IHeaderSyncHeaderSynced // Event containing the contract specifics and raw log

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
func (it *IHeaderSyncHeaderSyncedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(IHeaderSyncHeaderSynced)
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
		it.Event = new(IHeaderSyncHeaderSynced)
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
func (it *IHeaderSyncHeaderSyncedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *IHeaderSyncHeaderSyncedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// IHeaderSyncHeaderSynced represents a HeaderSynced event raised by the IHeaderSync contract.
type IHeaderSyncHeaderSynced struct {
	Height    *big.Int
	SrcHeight *big.Int
	SrcHash   [32]byte
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterHeaderSynced is a free log retrieval operation binding the contract event 0x930c750845026c7bb04c0e3d9111d512b4c86981713c4944a35a10a4a7a854f3.
//
// Solidity: event HeaderSynced(uint256 indexed height, uint256 indexed srcHeight, bytes32 srcHash)
func (_IHeaderSync *IHeaderSyncFilterer) FilterHeaderSynced(opts *bind.FilterOpts, height []*big.Int, srcHeight []*big.Int) (*IHeaderSyncHeaderSyncedIterator, error) {

	var heightRule []interface{}
	for _, heightItem := range height {
		heightRule = append(heightRule, heightItem)
	}
	var srcHeightRule []interface{}
	for _, srcHeightItem := range srcHeight {
		srcHeightRule = append(srcHeightRule, srcHeightItem)
	}

	logs, sub, err := _IHeaderSync.contract.FilterLogs(opts, "HeaderSynced", heightRule, srcHeightRule)
	if err != nil {
		return nil, err
	}
	return &IHeaderSyncHeaderSyncedIterator{contract: _IHeaderSync.contract, event: "HeaderSynced", logs: logs, sub: sub}, nil
}

// WatchHeaderSynced is a free log subscription operation binding the contract event 0x930c750845026c7bb04c0e3d9111d512b4c86981713c4944a35a10a4a7a854f3.
//
// Solidity: event HeaderSynced(uint256 indexed height, uint256 indexed srcHeight, bytes32 srcHash)
func (_IHeaderSync *IHeaderSyncFilterer) WatchHeaderSynced(opts *bind.WatchOpts, sink chan<- *IHeaderSyncHeaderSynced, height []*big.Int, srcHeight []*big.Int) (event.Subscription, error) {

	var heightRule []interface{}
	for _, heightItem := range height {
		heightRule = append(heightRule, heightItem)
	}
	var srcHeightRule []interface{}
	for _, srcHeightItem := range srcHeight {
		srcHeightRule = append(srcHeightRule, srcHeightItem)
	}

	logs, sub, err := _IHeaderSync.contract.WatchLogs(opts, "HeaderSynced", heightRule, srcHeightRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(IHeaderSyncHeaderSynced)
				if err := _IHeaderSync.contract.UnpackLog(event, "HeaderSynced", log); err != nil {
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

// ParseHeaderSynced is a log parse operation binding the contract event 0x930c750845026c7bb04c0e3d9111d512b4c86981713c4944a35a10a4a7a854f3.
//
// Solidity: event HeaderSynced(uint256 indexed height, uint256 indexed srcHeight, bytes32 srcHash)
func (_IHeaderSync *IHeaderSyncFilterer) ParseHeaderSynced(log types.Log) (*IHeaderSyncHeaderSynced, error) {
	event := new(IHeaderSyncHeaderSynced)
	if err := _IHeaderSync.contract.UnpackLog(event, "HeaderSynced", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
