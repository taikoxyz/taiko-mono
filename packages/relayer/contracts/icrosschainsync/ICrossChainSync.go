// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package icrosschainsync

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

// ICrossChainSyncMetaData contains all meta data concerning the ICrossChainSync contract.
var ICrossChainSyncMetaData = &bind.MetaData{
	ABI: "[{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"srcHeight\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"blockHash\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"signalRoot\",\"type\":\"bytes32\"}],\"name\":\"CrossChainSynced\",\"type\":\"event\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"number\",\"type\":\"uint256\"}],\"name\":\"getCrossChainBlockHash\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"number\",\"type\":\"uint256\"}],\"name\":\"getCrossChainSignalRoot\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"view\",\"type\":\"function\"}]",
}

// ICrossChainSyncABI is the input ABI used to generate the binding from.
// Deprecated: Use ICrossChainSyncMetaData.ABI instead.
var ICrossChainSyncABI = ICrossChainSyncMetaData.ABI

// ICrossChainSync is an auto generated Go binding around an Ethereum contract.
type ICrossChainSync struct {
	ICrossChainSyncCaller     // Read-only binding to the contract
	ICrossChainSyncTransactor // Write-only binding to the contract
	ICrossChainSyncFilterer   // Log filterer for contract events
}

// ICrossChainSyncCaller is an auto generated read-only Go binding around an Ethereum contract.
type ICrossChainSyncCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ICrossChainSyncTransactor is an auto generated write-only Go binding around an Ethereum contract.
type ICrossChainSyncTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ICrossChainSyncFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type ICrossChainSyncFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ICrossChainSyncSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type ICrossChainSyncSession struct {
	Contract     *ICrossChainSync  // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// ICrossChainSyncCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type ICrossChainSyncCallerSession struct {
	Contract *ICrossChainSyncCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts          // Call options to use throughout this session
}

// ICrossChainSyncTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type ICrossChainSyncTransactorSession struct {
	Contract     *ICrossChainSyncTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts          // Transaction auth options to use throughout this session
}

// ICrossChainSyncRaw is an auto generated low-level Go binding around an Ethereum contract.
type ICrossChainSyncRaw struct {
	Contract *ICrossChainSync // Generic contract binding to access the raw methods on
}

// ICrossChainSyncCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type ICrossChainSyncCallerRaw struct {
	Contract *ICrossChainSyncCaller // Generic read-only contract binding to access the raw methods on
}

// ICrossChainSyncTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type ICrossChainSyncTransactorRaw struct {
	Contract *ICrossChainSyncTransactor // Generic write-only contract binding to access the raw methods on
}

// NewICrossChainSync creates a new instance of ICrossChainSync, bound to a specific deployed contract.
func NewICrossChainSync(address common.Address, backend bind.ContractBackend) (*ICrossChainSync, error) {
	contract, err := bindICrossChainSync(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &ICrossChainSync{ICrossChainSyncCaller: ICrossChainSyncCaller{contract: contract}, ICrossChainSyncTransactor: ICrossChainSyncTransactor{contract: contract}, ICrossChainSyncFilterer: ICrossChainSyncFilterer{contract: contract}}, nil
}

// NewICrossChainSyncCaller creates a new read-only instance of ICrossChainSync, bound to a specific deployed contract.
func NewICrossChainSyncCaller(address common.Address, caller bind.ContractCaller) (*ICrossChainSyncCaller, error) {
	contract, err := bindICrossChainSync(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &ICrossChainSyncCaller{contract: contract}, nil
}

// NewICrossChainSyncTransactor creates a new write-only instance of ICrossChainSync, bound to a specific deployed contract.
func NewICrossChainSyncTransactor(address common.Address, transactor bind.ContractTransactor) (*ICrossChainSyncTransactor, error) {
	contract, err := bindICrossChainSync(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &ICrossChainSyncTransactor{contract: contract}, nil
}

// NewICrossChainSyncFilterer creates a new log filterer instance of ICrossChainSync, bound to a specific deployed contract.
func NewICrossChainSyncFilterer(address common.Address, filterer bind.ContractFilterer) (*ICrossChainSyncFilterer, error) {
	contract, err := bindICrossChainSync(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &ICrossChainSyncFilterer{contract: contract}, nil
}

// bindICrossChainSync binds a generic wrapper to an already deployed contract.
func bindICrossChainSync(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := ICrossChainSyncMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ICrossChainSync *ICrossChainSyncRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ICrossChainSync.Contract.ICrossChainSyncCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ICrossChainSync *ICrossChainSyncRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ICrossChainSync.Contract.ICrossChainSyncTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ICrossChainSync *ICrossChainSyncRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ICrossChainSync.Contract.ICrossChainSyncTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ICrossChainSync *ICrossChainSyncCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ICrossChainSync.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ICrossChainSync *ICrossChainSyncTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ICrossChainSync.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ICrossChainSync *ICrossChainSyncTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ICrossChainSync.Contract.contract.Transact(opts, method, params...)
}

// GetCrossChainBlockHash is a free data retrieval call binding the contract method 0xbacb386d.
//
// Solidity: function getCrossChainBlockHash(uint256 number) view returns(bytes32)
func (_ICrossChainSync *ICrossChainSyncCaller) GetCrossChainBlockHash(opts *bind.CallOpts, number *big.Int) ([32]byte, error) {
	var out []interface{}
	err := _ICrossChainSync.contract.Call(opts, &out, "getCrossChainBlockHash", number)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetCrossChainBlockHash is a free data retrieval call binding the contract method 0xbacb386d.
//
// Solidity: function getCrossChainBlockHash(uint256 number) view returns(bytes32)
func (_ICrossChainSync *ICrossChainSyncSession) GetCrossChainBlockHash(number *big.Int) ([32]byte, error) {
	return _ICrossChainSync.Contract.GetCrossChainBlockHash(&_ICrossChainSync.CallOpts, number)
}

// GetCrossChainBlockHash is a free data retrieval call binding the contract method 0xbacb386d.
//
// Solidity: function getCrossChainBlockHash(uint256 number) view returns(bytes32)
func (_ICrossChainSync *ICrossChainSyncCallerSession) GetCrossChainBlockHash(number *big.Int) ([32]byte, error) {
	return _ICrossChainSync.Contract.GetCrossChainBlockHash(&_ICrossChainSync.CallOpts, number)
}

// GetCrossChainSignalRoot is a free data retrieval call binding the contract method 0xb8914ce4.
//
// Solidity: function getCrossChainSignalRoot(uint256 number) view returns(bytes32)
func (_ICrossChainSync *ICrossChainSyncCaller) GetCrossChainSignalRoot(opts *bind.CallOpts, number *big.Int) ([32]byte, error) {
	var out []interface{}
	err := _ICrossChainSync.contract.Call(opts, &out, "getCrossChainSignalRoot", number)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetCrossChainSignalRoot is a free data retrieval call binding the contract method 0xb8914ce4.
//
// Solidity: function getCrossChainSignalRoot(uint256 number) view returns(bytes32)
func (_ICrossChainSync *ICrossChainSyncSession) GetCrossChainSignalRoot(number *big.Int) ([32]byte, error) {
	return _ICrossChainSync.Contract.GetCrossChainSignalRoot(&_ICrossChainSync.CallOpts, number)
}

// GetCrossChainSignalRoot is a free data retrieval call binding the contract method 0xb8914ce4.
//
// Solidity: function getCrossChainSignalRoot(uint256 number) view returns(bytes32)
func (_ICrossChainSync *ICrossChainSyncCallerSession) GetCrossChainSignalRoot(number *big.Int) ([32]byte, error) {
	return _ICrossChainSync.Contract.GetCrossChainSignalRoot(&_ICrossChainSync.CallOpts, number)
}

// ICrossChainSyncCrossChainSyncedIterator is returned from FilterCrossChainSynced and is used to iterate over the raw logs and unpacked data for CrossChainSynced events raised by the ICrossChainSync contract.
type ICrossChainSyncCrossChainSyncedIterator struct {
	Event *ICrossChainSyncCrossChainSynced // Event containing the contract specifics and raw log

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
func (it *ICrossChainSyncCrossChainSyncedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ICrossChainSyncCrossChainSynced)
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
		it.Event = new(ICrossChainSyncCrossChainSynced)
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
func (it *ICrossChainSyncCrossChainSyncedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ICrossChainSyncCrossChainSyncedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ICrossChainSyncCrossChainSynced represents a CrossChainSynced event raised by the ICrossChainSync contract.
type ICrossChainSyncCrossChainSynced struct {
	SrcHeight  *big.Int
	BlockHash  [32]byte
	SignalRoot [32]byte
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterCrossChainSynced is a free log retrieval operation binding the contract event 0x7528bbd1cef0e5d13408706892a51ee8ef82bbf33d4ec0c37216f8beba71205b.
//
// Solidity: event CrossChainSynced(uint256 indexed srcHeight, bytes32 blockHash, bytes32 signalRoot)
func (_ICrossChainSync *ICrossChainSyncFilterer) FilterCrossChainSynced(opts *bind.FilterOpts, srcHeight []*big.Int) (*ICrossChainSyncCrossChainSyncedIterator, error) {

	var srcHeightRule []interface{}
	for _, srcHeightItem := range srcHeight {
		srcHeightRule = append(srcHeightRule, srcHeightItem)
	}

	logs, sub, err := _ICrossChainSync.contract.FilterLogs(opts, "CrossChainSynced", srcHeightRule)
	if err != nil {
		return nil, err
	}
	return &ICrossChainSyncCrossChainSyncedIterator{contract: _ICrossChainSync.contract, event: "CrossChainSynced", logs: logs, sub: sub}, nil
}

// WatchCrossChainSynced is a free log subscription operation binding the contract event 0x7528bbd1cef0e5d13408706892a51ee8ef82bbf33d4ec0c37216f8beba71205b.
//
// Solidity: event CrossChainSynced(uint256 indexed srcHeight, bytes32 blockHash, bytes32 signalRoot)
func (_ICrossChainSync *ICrossChainSyncFilterer) WatchCrossChainSynced(opts *bind.WatchOpts, sink chan<- *ICrossChainSyncCrossChainSynced, srcHeight []*big.Int) (event.Subscription, error) {

	var srcHeightRule []interface{}
	for _, srcHeightItem := range srcHeight {
		srcHeightRule = append(srcHeightRule, srcHeightItem)
	}

	logs, sub, err := _ICrossChainSync.contract.WatchLogs(opts, "CrossChainSynced", srcHeightRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ICrossChainSyncCrossChainSynced)
				if err := _ICrossChainSync.contract.UnpackLog(event, "CrossChainSynced", log); err != nil {
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

// ParseCrossChainSynced is a log parse operation binding the contract event 0x7528bbd1cef0e5d13408706892a51ee8ef82bbf33d4ec0c37216f8beba71205b.
//
// Solidity: event CrossChainSynced(uint256 indexed srcHeight, bytes32 blockHash, bytes32 signalRoot)
func (_ICrossChainSync *ICrossChainSyncFilterer) ParseCrossChainSynced(log types.Log) (*ICrossChainSyncCrossChainSynced, error) {
	event := new(ICrossChainSyncCrossChainSynced)
	if err := _ICrossChainSync.contract.UnpackLog(event, "CrossChainSynced", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
