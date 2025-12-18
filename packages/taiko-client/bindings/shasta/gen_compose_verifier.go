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

// ComposeVerifierMetaData contains all meta data concerning the ComposeVerifier contract.
var ComposeVerifierMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"getVerifierAddress\",\"inputs\":[{\"name\":\"_verifierId\",\"type\":\"uint8\",\"internalType\":\"enumComposeVerifier.VerifierType\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"opVerifier\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"risc0RethVerifier\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"sgxGethVerifier\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"sgxRethVerifier\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"sp1RethVerifier\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"tdxGethVerifier\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"verifyProof\",\"inputs\":[{\"name\":\"_proposalAge\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"_commitmentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_proof\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"view\"},{\"type\":\"error\",\"name\":\"CV_INVALID_SUB_VERIFIER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CV_INVALID_SUB_VERIFIER_ORDER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"CV_VERIFIERS_INSUFFICIENT\",\"inputs\":[]}]",
}

// ComposeVerifierABI is the input ABI used to generate the binding from.
// Deprecated: Use ComposeVerifierMetaData.ABI instead.
var ComposeVerifierABI = ComposeVerifierMetaData.ABI

// ComposeVerifier is an auto generated Go binding around an Ethereum contract.
type ComposeVerifier struct {
	ComposeVerifierCaller     // Read-only binding to the contract
	ComposeVerifierTransactor // Write-only binding to the contract
	ComposeVerifierFilterer   // Log filterer for contract events
}

// ComposeVerifierCaller is an auto generated read-only Go binding around an Ethereum contract.
type ComposeVerifierCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ComposeVerifierTransactor is an auto generated write-only Go binding around an Ethereum contract.
type ComposeVerifierTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ComposeVerifierFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type ComposeVerifierFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ComposeVerifierSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type ComposeVerifierSession struct {
	Contract     *ComposeVerifier  // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// ComposeVerifierCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type ComposeVerifierCallerSession struct {
	Contract *ComposeVerifierCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts          // Call options to use throughout this session
}

// ComposeVerifierTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type ComposeVerifierTransactorSession struct {
	Contract     *ComposeVerifierTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts          // Transaction auth options to use throughout this session
}

// ComposeVerifierRaw is an auto generated low-level Go binding around an Ethereum contract.
type ComposeVerifierRaw struct {
	Contract *ComposeVerifier // Generic contract binding to access the raw methods on
}

// ComposeVerifierCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type ComposeVerifierCallerRaw struct {
	Contract *ComposeVerifierCaller // Generic read-only contract binding to access the raw methods on
}

// ComposeVerifierTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type ComposeVerifierTransactorRaw struct {
	Contract *ComposeVerifierTransactor // Generic write-only contract binding to access the raw methods on
}

// NewComposeVerifier creates a new instance of ComposeVerifier, bound to a specific deployed contract.
func NewComposeVerifier(address common.Address, backend bind.ContractBackend) (*ComposeVerifier, error) {
	contract, err := bindComposeVerifier(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &ComposeVerifier{ComposeVerifierCaller: ComposeVerifierCaller{contract: contract}, ComposeVerifierTransactor: ComposeVerifierTransactor{contract: contract}, ComposeVerifierFilterer: ComposeVerifierFilterer{contract: contract}}, nil
}

// NewComposeVerifierCaller creates a new read-only instance of ComposeVerifier, bound to a specific deployed contract.
func NewComposeVerifierCaller(address common.Address, caller bind.ContractCaller) (*ComposeVerifierCaller, error) {
	contract, err := bindComposeVerifier(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &ComposeVerifierCaller{contract: contract}, nil
}

// NewComposeVerifierTransactor creates a new write-only instance of ComposeVerifier, bound to a specific deployed contract.
func NewComposeVerifierTransactor(address common.Address, transactor bind.ContractTransactor) (*ComposeVerifierTransactor, error) {
	contract, err := bindComposeVerifier(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &ComposeVerifierTransactor{contract: contract}, nil
}

// NewComposeVerifierFilterer creates a new log filterer instance of ComposeVerifier, bound to a specific deployed contract.
func NewComposeVerifierFilterer(address common.Address, filterer bind.ContractFilterer) (*ComposeVerifierFilterer, error) {
	contract, err := bindComposeVerifier(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &ComposeVerifierFilterer{contract: contract}, nil
}

// bindComposeVerifier binds a generic wrapper to an already deployed contract.
func bindComposeVerifier(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := ComposeVerifierMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ComposeVerifier *ComposeVerifierRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ComposeVerifier.Contract.ComposeVerifierCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ComposeVerifier *ComposeVerifierRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ComposeVerifier.Contract.ComposeVerifierTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ComposeVerifier *ComposeVerifierRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ComposeVerifier.Contract.ComposeVerifierTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ComposeVerifier *ComposeVerifierCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ComposeVerifier.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ComposeVerifier *ComposeVerifierTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ComposeVerifier.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ComposeVerifier *ComposeVerifierTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ComposeVerifier.Contract.contract.Transact(opts, method, params...)
}

// GetVerifierAddress is a free data retrieval call binding the contract method 0x42b57409.
//
// Solidity: function getVerifierAddress(uint8 _verifierId) view returns(address)
func (_ComposeVerifier *ComposeVerifierCaller) GetVerifierAddress(opts *bind.CallOpts, _verifierId uint8) (common.Address, error) {
	var out []interface{}
	err := _ComposeVerifier.contract.Call(opts, &out, "getVerifierAddress", _verifierId)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GetVerifierAddress is a free data retrieval call binding the contract method 0x42b57409.
//
// Solidity: function getVerifierAddress(uint8 _verifierId) view returns(address)
func (_ComposeVerifier *ComposeVerifierSession) GetVerifierAddress(_verifierId uint8) (common.Address, error) {
	return _ComposeVerifier.Contract.GetVerifierAddress(&_ComposeVerifier.CallOpts, _verifierId)
}

// GetVerifierAddress is a free data retrieval call binding the contract method 0x42b57409.
//
// Solidity: function getVerifierAddress(uint8 _verifierId) view returns(address)
func (_ComposeVerifier *ComposeVerifierCallerSession) GetVerifierAddress(_verifierId uint8) (common.Address, error) {
	return _ComposeVerifier.Contract.GetVerifierAddress(&_ComposeVerifier.CallOpts, _verifierId)
}

// OpVerifier is a free data retrieval call binding the contract method 0xd09aed48.
//
// Solidity: function opVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierCaller) OpVerifier(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ComposeVerifier.contract.Call(opts, &out, "opVerifier")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// OpVerifier is a free data retrieval call binding the contract method 0xd09aed48.
//
// Solidity: function opVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierSession) OpVerifier() (common.Address, error) {
	return _ComposeVerifier.Contract.OpVerifier(&_ComposeVerifier.CallOpts)
}

// OpVerifier is a free data retrieval call binding the contract method 0xd09aed48.
//
// Solidity: function opVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierCallerSession) OpVerifier() (common.Address, error) {
	return _ComposeVerifier.Contract.OpVerifier(&_ComposeVerifier.CallOpts)
}

// Risc0RethVerifier is a free data retrieval call binding the contract method 0x97b56f57.
//
// Solidity: function risc0RethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierCaller) Risc0RethVerifier(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ComposeVerifier.contract.Call(opts, &out, "risc0RethVerifier")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Risc0RethVerifier is a free data retrieval call binding the contract method 0x97b56f57.
//
// Solidity: function risc0RethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierSession) Risc0RethVerifier() (common.Address, error) {
	return _ComposeVerifier.Contract.Risc0RethVerifier(&_ComposeVerifier.CallOpts)
}

// Risc0RethVerifier is a free data retrieval call binding the contract method 0x97b56f57.
//
// Solidity: function risc0RethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierCallerSession) Risc0RethVerifier() (common.Address, error) {
	return _ComposeVerifier.Contract.Risc0RethVerifier(&_ComposeVerifier.CallOpts)
}

// SgxGethVerifier is a free data retrieval call binding the contract method 0x680bca47.
//
// Solidity: function sgxGethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierCaller) SgxGethVerifier(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ComposeVerifier.contract.Call(opts, &out, "sgxGethVerifier")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SgxGethVerifier is a free data retrieval call binding the contract method 0x680bca47.
//
// Solidity: function sgxGethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierSession) SgxGethVerifier() (common.Address, error) {
	return _ComposeVerifier.Contract.SgxGethVerifier(&_ComposeVerifier.CallOpts)
}

// SgxGethVerifier is a free data retrieval call binding the contract method 0x680bca47.
//
// Solidity: function sgxGethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierCallerSession) SgxGethVerifier() (common.Address, error) {
	return _ComposeVerifier.Contract.SgxGethVerifier(&_ComposeVerifier.CallOpts)
}

// SgxRethVerifier is a free data retrieval call binding the contract method 0x4185d422.
//
// Solidity: function sgxRethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierCaller) SgxRethVerifier(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ComposeVerifier.contract.Call(opts, &out, "sgxRethVerifier")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// SgxRethVerifier is a free data retrieval call binding the contract method 0x4185d422.
//
// Solidity: function sgxRethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierSession) SgxRethVerifier() (common.Address, error) {
	return _ComposeVerifier.Contract.SgxRethVerifier(&_ComposeVerifier.CallOpts)
}

// SgxRethVerifier is a free data retrieval call binding the contract method 0x4185d422.
//
// Solidity: function sgxRethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierCallerSession) SgxRethVerifier() (common.Address, error) {
	return _ComposeVerifier.Contract.SgxRethVerifier(&_ComposeVerifier.CallOpts)
}

// Sp1RethVerifier is a free data retrieval call binding the contract method 0x8d732463.
//
// Solidity: function sp1RethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierCaller) Sp1RethVerifier(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ComposeVerifier.contract.Call(opts, &out, "sp1RethVerifier")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Sp1RethVerifier is a free data retrieval call binding the contract method 0x8d732463.
//
// Solidity: function sp1RethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierSession) Sp1RethVerifier() (common.Address, error) {
	return _ComposeVerifier.Contract.Sp1RethVerifier(&_ComposeVerifier.CallOpts)
}

// Sp1RethVerifier is a free data retrieval call binding the contract method 0x8d732463.
//
// Solidity: function sp1RethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierCallerSession) Sp1RethVerifier() (common.Address, error) {
	return _ComposeVerifier.Contract.Sp1RethVerifier(&_ComposeVerifier.CallOpts)
}

// TdxGethVerifier is a free data retrieval call binding the contract method 0xa936fa71.
//
// Solidity: function tdxGethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierCaller) TdxGethVerifier(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ComposeVerifier.contract.Call(opts, &out, "tdxGethVerifier")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// TdxGethVerifier is a free data retrieval call binding the contract method 0xa936fa71.
//
// Solidity: function tdxGethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierSession) TdxGethVerifier() (common.Address, error) {
	return _ComposeVerifier.Contract.TdxGethVerifier(&_ComposeVerifier.CallOpts)
}

// TdxGethVerifier is a free data retrieval call binding the contract method 0xa936fa71.
//
// Solidity: function tdxGethVerifier() view returns(address)
func (_ComposeVerifier *ComposeVerifierCallerSession) TdxGethVerifier() (common.Address, error) {
	return _ComposeVerifier.Contract.TdxGethVerifier(&_ComposeVerifier.CallOpts)
}

// VerifyProof is a free data retrieval call binding the contract method 0x14bcf3dd.
//
// Solidity: function verifyProof(uint256 _proposalAge, bytes32 _commitmentHash, bytes _proof) view returns()
func (_ComposeVerifier *ComposeVerifierCaller) VerifyProof(opts *bind.CallOpts, _proposalAge *big.Int, _commitmentHash [32]byte, _proof []byte) error {
	var out []interface{}
	err := _ComposeVerifier.contract.Call(opts, &out, "verifyProof", _proposalAge, _commitmentHash, _proof)

	if err != nil {
		return err
	}

	return err

}

// VerifyProof is a free data retrieval call binding the contract method 0x14bcf3dd.
//
// Solidity: function verifyProof(uint256 _proposalAge, bytes32 _commitmentHash, bytes _proof) view returns()
func (_ComposeVerifier *ComposeVerifierSession) VerifyProof(_proposalAge *big.Int, _commitmentHash [32]byte, _proof []byte) error {
	return _ComposeVerifier.Contract.VerifyProof(&_ComposeVerifier.CallOpts, _proposalAge, _commitmentHash, _proof)
}

// VerifyProof is a free data retrieval call binding the contract method 0x14bcf3dd.
//
// Solidity: function verifyProof(uint256 _proposalAge, bytes32 _commitmentHash, bytes _proof) view returns()
func (_ComposeVerifier *ComposeVerifierCallerSession) VerifyProof(_proposalAge *big.Int, _commitmentHash [32]byte, _proof []byte) error {
	return _ComposeVerifier.Contract.VerifyProof(&_ComposeVerifier.CallOpts, _proposalAge, _commitmentHash, _proof)
}
