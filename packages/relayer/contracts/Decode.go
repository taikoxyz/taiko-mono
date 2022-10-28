// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package contracts

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

// DecodeABI is the input ABI used to generate the binding from.
const DecodeABI = "[{\"inputs\":[{\"internalType\":\"bytes\",\"name\":\"proof\",\"type\":\"bytes\"}],\"name\":\"decode\",\"outputs\":[],\"stateMutability\":\"pure\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes\",\"name\":\"proof\",\"type\":\"bytes\"}],\"name\":\"decodeBoth\",\"outputs\":[],\"stateMutability\":\"pure\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes\",\"name\":\"proof\",\"type\":\"bytes\"}],\"name\":\"decodeProof\",\"outputs\":[],\"stateMutability\":\"pure\",\"type\":\"function\"}]"

// Decode is an auto generated Go binding around an Ethereum contract.
type Decode struct {
	DecodeCaller     // Read-only binding to the contract
	DecodeTransactor // Write-only binding to the contract
	DecodeFilterer   // Log filterer for contract events
}

// DecodeCaller is an auto generated read-only Go binding around an Ethereum contract.
type DecodeCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// DecodeTransactor is an auto generated write-only Go binding around an Ethereum contract.
type DecodeTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// DecodeFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type DecodeFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// DecodeSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type DecodeSession struct {
	Contract     *Decode           // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// DecodeCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type DecodeCallerSession struct {
	Contract *DecodeCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts // Call options to use throughout this session
}

// DecodeTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type DecodeTransactorSession struct {
	Contract     *DecodeTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// DecodeRaw is an auto generated low-level Go binding around an Ethereum contract.
type DecodeRaw struct {
	Contract *Decode // Generic contract binding to access the raw methods on
}

// DecodeCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type DecodeCallerRaw struct {
	Contract *DecodeCaller // Generic read-only contract binding to access the raw methods on
}

// DecodeTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type DecodeTransactorRaw struct {
	Contract *DecodeTransactor // Generic write-only contract binding to access the raw methods on
}

// NewDecode creates a new instance of Decode, bound to a specific deployed contract.
func NewDecode(address common.Address, backend bind.ContractBackend) (*Decode, error) {
	contract, err := bindDecode(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &Decode{DecodeCaller: DecodeCaller{contract: contract}, DecodeTransactor: DecodeTransactor{contract: contract}, DecodeFilterer: DecodeFilterer{contract: contract}}, nil
}

// NewDecodeCaller creates a new read-only instance of Decode, bound to a specific deployed contract.
func NewDecodeCaller(address common.Address, caller bind.ContractCaller) (*DecodeCaller, error) {
	contract, err := bindDecode(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &DecodeCaller{contract: contract}, nil
}

// NewDecodeTransactor creates a new write-only instance of Decode, bound to a specific deployed contract.
func NewDecodeTransactor(address common.Address, transactor bind.ContractTransactor) (*DecodeTransactor, error) {
	contract, err := bindDecode(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &DecodeTransactor{contract: contract}, nil
}

// NewDecodeFilterer creates a new log filterer instance of Decode, bound to a specific deployed contract.
func NewDecodeFilterer(address common.Address, filterer bind.ContractFilterer) (*DecodeFilterer, error) {
	contract, err := bindDecode(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &DecodeFilterer{contract: contract}, nil
}

// bindDecode binds a generic wrapper to an already deployed contract.
func bindDecode(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := abi.JSON(strings.NewReader(DecodeABI))
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_Decode *DecodeRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _Decode.Contract.DecodeCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_Decode *DecodeRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Decode.Contract.DecodeTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_Decode *DecodeRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _Decode.Contract.DecodeTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_Decode *DecodeCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _Decode.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_Decode *DecodeTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Decode.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_Decode *DecodeTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _Decode.Contract.contract.Transact(opts, method, params...)
}

// Decode is a free data retrieval call binding the contract method 0xe5c5e9a3.
//
// Solidity: function decode(bytes proof) pure returns()
func (_Decode *DecodeCaller) Decode(opts *bind.CallOpts, proof []byte) error {
	var out []interface{}
	err := _Decode.contract.Call(opts, &out, "decode", proof)

	if err != nil {
		return err
	}

	return err

}

// Decode is a free data retrieval call binding the contract method 0xe5c5e9a3.
//
// Solidity: function decode(bytes proof) pure returns()
func (_Decode *DecodeSession) Decode(proof []byte) error {
	return _Decode.Contract.Decode(&_Decode.CallOpts, proof)
}

// Decode is a free data retrieval call binding the contract method 0xe5c5e9a3.
//
// Solidity: function decode(bytes proof) pure returns()
func (_Decode *DecodeCallerSession) Decode(proof []byte) error {
	return _Decode.Contract.Decode(&_Decode.CallOpts, proof)
}

// DecodeBoth is a free data retrieval call binding the contract method 0xdb47a70e.
//
// Solidity: function decodeBoth(bytes proof) pure returns()
func (_Decode *DecodeCaller) DecodeBoth(opts *bind.CallOpts, proof []byte) error {
	var out []interface{}
	err := _Decode.contract.Call(opts, &out, "decodeBoth", proof)

	if err != nil {
		return err
	}

	return err

}

// DecodeBoth is a free data retrieval call binding the contract method 0xdb47a70e.
//
// Solidity: function decodeBoth(bytes proof) pure returns()
func (_Decode *DecodeSession) DecodeBoth(proof []byte) error {
	return _Decode.Contract.DecodeBoth(&_Decode.CallOpts, proof)
}

// DecodeBoth is a free data retrieval call binding the contract method 0xdb47a70e.
//
// Solidity: function decodeBoth(bytes proof) pure returns()
func (_Decode *DecodeCallerSession) DecodeBoth(proof []byte) error {
	return _Decode.Contract.DecodeBoth(&_Decode.CallOpts, proof)
}

// DecodeProof is a free data retrieval call binding the contract method 0xc9d4ef1f.
//
// Solidity: function decodeProof(bytes proof) pure returns()
func (_Decode *DecodeCaller) DecodeProof(opts *bind.CallOpts, proof []byte) error {
	var out []interface{}
	err := _Decode.contract.Call(opts, &out, "decodeProof", proof)

	if err != nil {
		return err
	}

	return err

}

// DecodeProof is a free data retrieval call binding the contract method 0xc9d4ef1f.
//
// Solidity: function decodeProof(bytes proof) pure returns()
func (_Decode *DecodeSession) DecodeProof(proof []byte) error {
	return _Decode.Contract.DecodeProof(&_Decode.CallOpts, proof)
}

// DecodeProof is a free data retrieval call binding the contract method 0xc9d4ef1f.
//
// Solidity: function decodeProof(bytes proof) pure returns()
func (_Decode *DecodeCallerSession) DecodeProof(proof []byte) error {
	return _Decode.Contract.DecodeProof(&_Decode.CallOpts, proof)
}
