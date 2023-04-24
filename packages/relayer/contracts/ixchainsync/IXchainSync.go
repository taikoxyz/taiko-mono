// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package ixchainsync

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

// IXchainSyncMetaData contains all meta data concerning the IXchainSync contract.
var IXchainSyncMetaData = &bind.MetaData{
	ABI: "[{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"srcHeight\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"blockHash\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"signalRoot\",\"type\":\"bytes32\"}],\"name\":\"XchainSynced\",\"type\":\"event\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"number\",\"type\":\"uint256\"}],\"name\":\"getXchainBlockHash\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"number\",\"type\":\"uint256\"}],\"name\":\"getXchainSignalRoot\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"view\",\"type\":\"function\"}]",
}

// IXchainSyncABI is the input ABI used to generate the binding from.
// Deprecated: Use IXchainSyncMetaData.ABI instead.
var IXchainSyncABI = IXchainSyncMetaData.ABI

// IXchainSync is an auto generated Go binding around an Ethereum contract.
type IXchainSync struct {
	IXchainSyncCaller     // Read-only binding to the contract
	IXchainSyncTransactor // Write-only binding to the contract
	IXchainSyncFilterer   // Log filterer for contract events
}

// IXchainSyncCaller is an auto generated read-only Go binding around an Ethereum contract.
type IXchainSyncCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// IXchainSyncTransactor is an auto generated write-only Go binding around an Ethereum contract.
type IXchainSyncTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// IXchainSyncFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type IXchainSyncFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// IXchainSyncSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type IXchainSyncSession struct {
	Contract     *IXchainSync      // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// IXchainSyncCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type IXchainSyncCallerSession struct {
	Contract *IXchainSyncCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts      // Call options to use throughout this session
}

// IXchainSyncTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type IXchainSyncTransactorSession struct {
	Contract     *IXchainSyncTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts      // Transaction auth options to use throughout this session
}

// IXchainSyncRaw is an auto generated low-level Go binding around an Ethereum contract.
type IXchainSyncRaw struct {
	Contract *IXchainSync // Generic contract binding to access the raw methods on
}

// IXchainSyncCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type IXchainSyncCallerRaw struct {
	Contract *IXchainSyncCaller // Generic read-only contract binding to access the raw methods on
}

// IXchainSyncTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type IXchainSyncTransactorRaw struct {
	Contract *IXchainSyncTransactor // Generic write-only contract binding to access the raw methods on
}

// NewIXchainSync creates a new instance of IXchainSync, bound to a specific deployed contract.
func NewIXchainSync(address common.Address, backend bind.ContractBackend) (*IXchainSync, error) {
	contract, err := bindIXchainSync(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &IXchainSync{IXchainSyncCaller: IXchainSyncCaller{contract: contract}, IXchainSyncTransactor: IXchainSyncTransactor{contract: contract}, IXchainSyncFilterer: IXchainSyncFilterer{contract: contract}}, nil
}

// NewIXchainSyncCaller creates a new read-only instance of IXchainSync, bound to a specific deployed contract.
func NewIXchainSyncCaller(address common.Address, caller bind.ContractCaller) (*IXchainSyncCaller, error) {
	contract, err := bindIXchainSync(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &IXchainSyncCaller{contract: contract}, nil
}

// NewIXchainSyncTransactor creates a new write-only instance of IXchainSync, bound to a specific deployed contract.
func NewIXchainSyncTransactor(address common.Address, transactor bind.ContractTransactor) (*IXchainSyncTransactor, error) {
	contract, err := bindIXchainSync(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &IXchainSyncTransactor{contract: contract}, nil
}

// NewIXchainSyncFilterer creates a new log filterer instance of IXchainSync, bound to a specific deployed contract.
func NewIXchainSyncFilterer(address common.Address, filterer bind.ContractFilterer) (*IXchainSyncFilterer, error) {
	contract, err := bindIXchainSync(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &IXchainSyncFilterer{contract: contract}, nil
}

// bindIXchainSync binds a generic wrapper to an already deployed contract.
func bindIXchainSync(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := IXchainSyncMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_IXchainSync *IXchainSyncRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _IXchainSync.Contract.IXchainSyncCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_IXchainSync *IXchainSyncRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _IXchainSync.Contract.IXchainSyncTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_IXchainSync *IXchainSyncRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _IXchainSync.Contract.IXchainSyncTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_IXchainSync *IXchainSyncCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _IXchainSync.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_IXchainSync *IXchainSyncTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _IXchainSync.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_IXchainSync *IXchainSyncTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _IXchainSync.Contract.contract.Transact(opts, method, params...)
}

// GetXchainBlockHash is a free data retrieval call binding the contract method 0xa4e6775f.
//
// Solidity: function getXchainBlockHash(uint256 number) view returns(bytes32)
func (_IXchainSync *IXchainSyncCaller) GetXchainBlockHash(opts *bind.CallOpts, number *big.Int) ([32]byte, error) {
	var out []interface{}
	err := _IXchainSync.contract.Call(opts, &out, "getXchainBlockHash", number)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetXchainBlockHash is a free data retrieval call binding the contract method 0xa4e6775f.
//
// Solidity: function getXchainBlockHash(uint256 number) view returns(bytes32)
func (_IXchainSync *IXchainSyncSession) GetXchainBlockHash(number *big.Int) ([32]byte, error) {
	return _IXchainSync.Contract.GetXchainBlockHash(&_IXchainSync.CallOpts, number)
}

// GetXchainBlockHash is a free data retrieval call binding the contract method 0xa4e6775f.
//
// Solidity: function getXchainBlockHash(uint256 number) view returns(bytes32)
func (_IXchainSync *IXchainSyncCallerSession) GetXchainBlockHash(number *big.Int) ([32]byte, error) {
	return _IXchainSync.Contract.GetXchainBlockHash(&_IXchainSync.CallOpts, number)
}

// GetXchainSignalRoot is a free data retrieval call binding the contract method 0x609bbd06.
//
// Solidity: function getXchainSignalRoot(uint256 number) view returns(bytes32)
func (_IXchainSync *IXchainSyncCaller) GetXchainSignalRoot(opts *bind.CallOpts, number *big.Int) ([32]byte, error) {
	var out []interface{}
	err := _IXchainSync.contract.Call(opts, &out, "getXchainSignalRoot", number)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetXchainSignalRoot is a free data retrieval call binding the contract method 0x609bbd06.
//
// Solidity: function getXchainSignalRoot(uint256 number) view returns(bytes32)
func (_IXchainSync *IXchainSyncSession) GetXchainSignalRoot(number *big.Int) ([32]byte, error) {
	return _IXchainSync.Contract.GetXchainSignalRoot(&_IXchainSync.CallOpts, number)
}

// GetXchainSignalRoot is a free data retrieval call binding the contract method 0x609bbd06.
//
// Solidity: function getXchainSignalRoot(uint256 number) view returns(bytes32)
func (_IXchainSync *IXchainSyncCallerSession) GetXchainSignalRoot(number *big.Int) ([32]byte, error) {
	return _IXchainSync.Contract.GetXchainSignalRoot(&_IXchainSync.CallOpts, number)
}

// IXchainSyncXchainSyncedIterator is returned from FilterXchainSynced and is used to iterate over the raw logs and unpacked data for XchainSynced events raised by the IXchainSync contract.
type IXchainSyncXchainSyncedIterator struct {
	Event *IXchainSyncXchainSynced // Event containing the contract specifics and raw log

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
func (it *IXchainSyncXchainSyncedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(IXchainSyncXchainSynced)
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
		it.Event = new(IXchainSyncXchainSynced)
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
func (it *IXchainSyncXchainSyncedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *IXchainSyncXchainSyncedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// IXchainSyncXchainSynced represents a XchainSynced event raised by the IXchainSync contract.
type IXchainSyncXchainSynced struct {
	SrcHeight  *big.Int
	BlockHash  [32]byte
	SignalRoot [32]byte
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterXchainSynced is a free log retrieval operation binding the contract event 0xc7edd3d480c294297f3924d0ffab64074e7fb22e004ea492d5dd691fa1fc99c0.
//
// Solidity: event XchainSynced(uint256 indexed srcHeight, bytes32 blockHash, bytes32 signalRoot)
func (_IXchainSync *IXchainSyncFilterer) FilterXchainSynced(opts *bind.FilterOpts, srcHeight []*big.Int) (*IXchainSyncXchainSyncedIterator, error) {

	var srcHeightRule []interface{}
	for _, srcHeightItem := range srcHeight {
		srcHeightRule = append(srcHeightRule, srcHeightItem)
	}

	logs, sub, err := _IXchainSync.contract.FilterLogs(opts, "XchainSynced", srcHeightRule)
	if err != nil {
		return nil, err
	}
	return &IXchainSyncXchainSyncedIterator{contract: _IXchainSync.contract, event: "XchainSynced", logs: logs, sub: sub}, nil
}

// WatchXchainSynced is a free log subscription operation binding the contract event 0xc7edd3d480c294297f3924d0ffab64074e7fb22e004ea492d5dd691fa1fc99c0.
//
// Solidity: event XchainSynced(uint256 indexed srcHeight, bytes32 blockHash, bytes32 signalRoot)
func (_IXchainSync *IXchainSyncFilterer) WatchXchainSynced(opts *bind.WatchOpts, sink chan<- *IXchainSyncXchainSynced, srcHeight []*big.Int) (event.Subscription, error) {

	var srcHeightRule []interface{}
	for _, srcHeightItem := range srcHeight {
		srcHeightRule = append(srcHeightRule, srcHeightItem)
	}

	logs, sub, err := _IXchainSync.contract.WatchLogs(opts, "XchainSynced", srcHeightRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(IXchainSyncXchainSynced)
				if err := _IXchainSync.contract.UnpackLog(event, "XchainSynced", log); err != nil {
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

// ParseXchainSynced is a log parse operation binding the contract event 0xc7edd3d480c294297f3924d0ffab64074e7fb22e004ea492d5dd691fa1fc99c0.
//
// Solidity: event XchainSynced(uint256 indexed srcHeight, bytes32 blockHash, bytes32 signalRoot)
func (_IXchainSync *IXchainSyncFilterer) ParseXchainSynced(log types.Log) (*IXchainSyncXchainSynced, error) {
	event := new(IXchainSyncXchainSynced)
	if err := _IXchainSync.contract.UnpackLog(event, "XchainSynced", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
