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

// IVerifierContext is an auto generated low-level Go binding around an user-defined struct.
type IVerifierContext struct {
	BatchId    uint64
	MetaHash   [32]byte
	Transition ITaikoInboxTransition
}

// SurgeVerifierMetaData contains all meta data concerning the SurgeVerifier contract.
var SurgeVerifierMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"_taikoInbox\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"impl\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inNonReentrant\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_sgxRethVerifier\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_risc0RethVerifier\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_sp1RethVerifier\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_sgxGethVerifier\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"markUpgradeable\",\"inputs\":[{\"name\":\"_proofType\",\"type\":\"uint16\",\"internalType\":\"LibProofType.ProofType\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolver\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"risc0RethVerifier\",\"inputs\":[],\"outputs\":[{\"name\":\"upgradeable\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"addr\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"sgxGethVerifier\",\"inputs\":[],\"outputs\":[{\"name\":\"upgradeable\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"addr\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"sgxRethVerifier\",\"inputs\":[],\"outputs\":[{\"name\":\"upgradeable\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"addr\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"sp1RethVerifier\",\"inputs\":[],\"outputs\":[{\"name\":\"upgradeable\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"addr\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"taikoInbox\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"upgradeVerifier\",\"inputs\":[{\"name\":\"_proofType\",\"type\":\"uint16\",\"internalType\":\"LibProofType.ProofType\"},{\"name\":\"_newVerifier\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"verifyProof\",\"inputs\":[{\"name\":\"_ctxs\",\"type\":\"tuple[]\",\"internalType\":\"structIVerifier.Context[]\",\"components\":[{\"name\":\"batchId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"metaHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"transition\",\"type\":\"tuple\",\"internalType\":\"structITaikoInbox.Transition\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]},{\"name\":\"_proof\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint16\",\"internalType\":\"LibProofType.ProofType\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCESS_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FUNCTION_DISABLED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FUNC_NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PROOF_TYPE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"VERIFIER_NOT_MARKED_UPGRADEABLE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_VALUE\",\"inputs\":[]}]",
}

// SurgeVerifierABI is the input ABI used to generate the binding from.
// Deprecated: Use SurgeVerifierMetaData.ABI instead.
var SurgeVerifierABI = SurgeVerifierMetaData.ABI

// SurgeVerifier is an auto generated Go binding around an Ethereum contract.
type SurgeVerifier struct {
	SurgeVerifierCaller     // Read-only binding to the contract
	SurgeVerifierTransactor // Write-only binding to the contract
	SurgeVerifierFilterer   // Log filterer for contract events
}

// SurgeVerifierCaller is an auto generated read-only Go binding around an Ethereum contract.
type SurgeVerifierCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SurgeVerifierTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SurgeVerifierTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SurgeVerifierFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SurgeVerifierFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SurgeVerifierSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SurgeVerifierSession struct {
	Contract     *SurgeVerifier    // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// SurgeVerifierCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SurgeVerifierCallerSession struct {
	Contract *SurgeVerifierCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts        // Call options to use throughout this session
}

// SurgeVerifierTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SurgeVerifierTransactorSession struct {
	Contract     *SurgeVerifierTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts        // Transaction auth options to use throughout this session
}

// SurgeVerifierRaw is an auto generated low-level Go binding around an Ethereum contract.
type SurgeVerifierRaw struct {
	Contract *SurgeVerifier // Generic contract binding to access the raw methods on
}

// SurgeVerifierCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SurgeVerifierCallerRaw struct {
	Contract *SurgeVerifierCaller // Generic read-only contract binding to access the raw methods on
}

// SurgeVerifierTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SurgeVerifierTransactorRaw struct {
	Contract *SurgeVerifierTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSurgeVerifier creates a new instance of SurgeVerifier, bound to a specific deployed contract.
func NewSurgeVerifier(address common.Address, backend bind.ContractBackend) (*SurgeVerifier, error) {
	contract, err := bindSurgeVerifier(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SurgeVerifier{SurgeVerifierCaller: SurgeVerifierCaller{contract: contract}, SurgeVerifierTransactor: SurgeVerifierTransactor{contract: contract}, SurgeVerifierFilterer: SurgeVerifierFilterer{contract: contract}}, nil
}

// NewSurgeVerifierCaller creates a new read-only instance of SurgeVerifier, bound to a specific deployed contract.
func NewSurgeVerifierCaller(address common.Address, caller bind.ContractCaller) (*SurgeVerifierCaller, error) {
	contract, err := bindSurgeVerifier(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SurgeVerifierCaller{contract: contract}, nil
}

// NewSurgeVerifierTransactor creates a new write-only instance of SurgeVerifier, bound to a specific deployed contract.
func NewSurgeVerifierTransactor(address common.Address, transactor bind.ContractTransactor) (*SurgeVerifierTransactor, error) {
	contract, err := bindSurgeVerifier(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SurgeVerifierTransactor{contract: contract}, nil
}

// NewSurgeVerifierFilterer creates a new log filterer instance of SurgeVerifier, bound to a specific deployed contract.
func NewSurgeVerifierFilterer(address common.Address, filterer bind.ContractFilterer) (*SurgeVerifierFilterer, error) {
	contract, err := bindSurgeVerifier(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SurgeVerifierFilterer{contract: contract}, nil
}

// bindSurgeVerifier binds a generic wrapper to an already deployed contract.
func bindSurgeVerifier(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SurgeVerifierMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SurgeVerifier *SurgeVerifierRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SurgeVerifier.Contract.SurgeVerifierCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SurgeVerifier *SurgeVerifierRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SurgeVerifier.Contract.SurgeVerifierTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SurgeVerifier *SurgeVerifierRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SurgeVerifier.Contract.SurgeVerifierTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SurgeVerifier *SurgeVerifierCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SurgeVerifier.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SurgeVerifier *SurgeVerifierTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SurgeVerifier.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SurgeVerifier *SurgeVerifierTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SurgeVerifier.Contract.contract.Transact(opts, method, params...)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_SurgeVerifier *SurgeVerifierCaller) Impl(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SurgeVerifier.contract.Call(opts, &out, "impl")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_SurgeVerifier *SurgeVerifierSession) Impl() (common.Address, error) {
	return _SurgeVerifier.Contract.Impl(&_SurgeVerifier.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_SurgeVerifier *SurgeVerifierCallerSession) Impl() (common.Address, error) {
	return _SurgeVerifier.Contract.Impl(&_SurgeVerifier.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_SurgeVerifier *SurgeVerifierCaller) InNonReentrant(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _SurgeVerifier.contract.Call(opts, &out, "inNonReentrant")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_SurgeVerifier *SurgeVerifierSession) InNonReentrant() (bool, error) {
	return _SurgeVerifier.Contract.InNonReentrant(&_SurgeVerifier.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_SurgeVerifier *SurgeVerifierCallerSession) InNonReentrant() (bool, error) {
	return _SurgeVerifier.Contract.InNonReentrant(&_SurgeVerifier.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_SurgeVerifier *SurgeVerifierCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SurgeVerifier.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_SurgeVerifier *SurgeVerifierSession) Owner() (common.Address, error) {
	return _SurgeVerifier.Contract.Owner(&_SurgeVerifier.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_SurgeVerifier *SurgeVerifierCallerSession) Owner() (common.Address, error) {
	return _SurgeVerifier.Contract.Owner(&_SurgeVerifier.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_SurgeVerifier *SurgeVerifierCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _SurgeVerifier.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_SurgeVerifier *SurgeVerifierSession) Paused() (bool, error) {
	return _SurgeVerifier.Contract.Paused(&_SurgeVerifier.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_SurgeVerifier *SurgeVerifierCallerSession) Paused() (bool, error) {
	return _SurgeVerifier.Contract.Paused(&_SurgeVerifier.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_SurgeVerifier *SurgeVerifierCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SurgeVerifier.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_SurgeVerifier *SurgeVerifierSession) ProxiableUUID() ([32]byte, error) {
	return _SurgeVerifier.Contract.ProxiableUUID(&_SurgeVerifier.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_SurgeVerifier *SurgeVerifierCallerSession) ProxiableUUID() ([32]byte, error) {
	return _SurgeVerifier.Contract.ProxiableUUID(&_SurgeVerifier.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_SurgeVerifier *SurgeVerifierCaller) Resolver(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SurgeVerifier.contract.Call(opts, &out, "resolver")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_SurgeVerifier *SurgeVerifierSession) Resolver() (common.Address, error) {
	return _SurgeVerifier.Contract.Resolver(&_SurgeVerifier.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_SurgeVerifier *SurgeVerifierCallerSession) Resolver() (common.Address, error) {
	return _SurgeVerifier.Contract.Resolver(&_SurgeVerifier.CallOpts)
}

// Risc0RethVerifier is a free data retrieval call binding the contract method 0x97b56f57.
//
// Solidity: function risc0RethVerifier() view returns(bool upgradeable, address addr)
func (_SurgeVerifier *SurgeVerifierCaller) Risc0RethVerifier(opts *bind.CallOpts) (struct {
	Upgradeable bool
	Addr        common.Address
}, error) {
	var out []interface{}
	err := _SurgeVerifier.contract.Call(opts, &out, "risc0RethVerifier")

	outstruct := new(struct {
		Upgradeable bool
		Addr        common.Address
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Upgradeable = *abi.ConvertType(out[0], new(bool)).(*bool)
	outstruct.Addr = *abi.ConvertType(out[1], new(common.Address)).(*common.Address)

	return *outstruct, err

}

// Risc0RethVerifier is a free data retrieval call binding the contract method 0x97b56f57.
//
// Solidity: function risc0RethVerifier() view returns(bool upgradeable, address addr)
func (_SurgeVerifier *SurgeVerifierSession) Risc0RethVerifier() (struct {
	Upgradeable bool
	Addr        common.Address
}, error) {
	return _SurgeVerifier.Contract.Risc0RethVerifier(&_SurgeVerifier.CallOpts)
}

// Risc0RethVerifier is a free data retrieval call binding the contract method 0x97b56f57.
//
// Solidity: function risc0RethVerifier() view returns(bool upgradeable, address addr)
func (_SurgeVerifier *SurgeVerifierCallerSession) Risc0RethVerifier() (struct {
	Upgradeable bool
	Addr        common.Address
}, error) {
	return _SurgeVerifier.Contract.Risc0RethVerifier(&_SurgeVerifier.CallOpts)
}

// SgxGethVerifier is a free data retrieval call binding the contract method 0x680bca47.
//
// Solidity: function sgxGethVerifier() view returns(bool upgradeable, address addr)
func (_SurgeVerifier *SurgeVerifierCaller) SgxGethVerifier(opts *bind.CallOpts) (struct {
	Upgradeable bool
	Addr        common.Address
}, error) {
	var out []interface{}
	err := _SurgeVerifier.contract.Call(opts, &out, "sgxGethVerifier")

	outstruct := new(struct {
		Upgradeable bool
		Addr        common.Address
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Upgradeable = *abi.ConvertType(out[0], new(bool)).(*bool)
	outstruct.Addr = *abi.ConvertType(out[1], new(common.Address)).(*common.Address)

	return *outstruct, err

}

// SgxGethVerifier is a free data retrieval call binding the contract method 0x680bca47.
//
// Solidity: function sgxGethVerifier() view returns(bool upgradeable, address addr)
func (_SurgeVerifier *SurgeVerifierSession) SgxGethVerifier() (struct {
	Upgradeable bool
	Addr        common.Address
}, error) {
	return _SurgeVerifier.Contract.SgxGethVerifier(&_SurgeVerifier.CallOpts)
}

// SgxGethVerifier is a free data retrieval call binding the contract method 0x680bca47.
//
// Solidity: function sgxGethVerifier() view returns(bool upgradeable, address addr)
func (_SurgeVerifier *SurgeVerifierCallerSession) SgxGethVerifier() (struct {
	Upgradeable bool
	Addr        common.Address
}, error) {
	return _SurgeVerifier.Contract.SgxGethVerifier(&_SurgeVerifier.CallOpts)
}

// SgxRethVerifier is a free data retrieval call binding the contract method 0x4185d422.
//
// Solidity: function sgxRethVerifier() view returns(bool upgradeable, address addr)
func (_SurgeVerifier *SurgeVerifierCaller) SgxRethVerifier(opts *bind.CallOpts) (struct {
	Upgradeable bool
	Addr        common.Address
}, error) {
	var out []interface{}
	err := _SurgeVerifier.contract.Call(opts, &out, "sgxRethVerifier")

	outstruct := new(struct {
		Upgradeable bool
		Addr        common.Address
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Upgradeable = *abi.ConvertType(out[0], new(bool)).(*bool)
	outstruct.Addr = *abi.ConvertType(out[1], new(common.Address)).(*common.Address)

	return *outstruct, err

}

// SgxRethVerifier is a free data retrieval call binding the contract method 0x4185d422.
//
// Solidity: function sgxRethVerifier() view returns(bool upgradeable, address addr)
func (_SurgeVerifier *SurgeVerifierSession) SgxRethVerifier() (struct {
	Upgradeable bool
	Addr        common.Address
}, error) {
	return _SurgeVerifier.Contract.SgxRethVerifier(&_SurgeVerifier.CallOpts)
}

// SgxRethVerifier is a free data retrieval call binding the contract method 0x4185d422.
//
// Solidity: function sgxRethVerifier() view returns(bool upgradeable, address addr)
func (_SurgeVerifier *SurgeVerifierCallerSession) SgxRethVerifier() (struct {
	Upgradeable bool
	Addr        common.Address
}, error) {
	return _SurgeVerifier.Contract.SgxRethVerifier(&_SurgeVerifier.CallOpts)
}

// Sp1RethVerifier is a free data retrieval call binding the contract method 0x8d732463.
//
// Solidity: function sp1RethVerifier() view returns(bool upgradeable, address addr)
func (_SurgeVerifier *SurgeVerifierCaller) Sp1RethVerifier(opts *bind.CallOpts) (struct {
	Upgradeable bool
	Addr        common.Address
}, error) {
	var out []interface{}
	err := _SurgeVerifier.contract.Call(opts, &out, "sp1RethVerifier")

	outstruct := new(struct {
		Upgradeable bool
		Addr        common.Address
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Upgradeable = *abi.ConvertType(out[0], new(bool)).(*bool)
	outstruct.Addr = *abi.ConvertType(out[1], new(common.Address)).(*common.Address)

	return *outstruct, err

}

// Sp1RethVerifier is a free data retrieval call binding the contract method 0x8d732463.
//
// Solidity: function sp1RethVerifier() view returns(bool upgradeable, address addr)
func (_SurgeVerifier *SurgeVerifierSession) Sp1RethVerifier() (struct {
	Upgradeable bool
	Addr        common.Address
}, error) {
	return _SurgeVerifier.Contract.Sp1RethVerifier(&_SurgeVerifier.CallOpts)
}

// Sp1RethVerifier is a free data retrieval call binding the contract method 0x8d732463.
//
// Solidity: function sp1RethVerifier() view returns(bool upgradeable, address addr)
func (_SurgeVerifier *SurgeVerifierCallerSession) Sp1RethVerifier() (struct {
	Upgradeable bool
	Addr        common.Address
}, error) {
	return _SurgeVerifier.Contract.Sp1RethVerifier(&_SurgeVerifier.CallOpts)
}

// TaikoInbox is a free data retrieval call binding the contract method 0x5de92721.
//
// Solidity: function taikoInbox() view returns(address)
func (_SurgeVerifier *SurgeVerifierCaller) TaikoInbox(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SurgeVerifier.contract.Call(opts, &out, "taikoInbox")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// TaikoInbox is a free data retrieval call binding the contract method 0x5de92721.
//
// Solidity: function taikoInbox() view returns(address)
func (_SurgeVerifier *SurgeVerifierSession) TaikoInbox() (common.Address, error) {
	return _SurgeVerifier.Contract.TaikoInbox(&_SurgeVerifier.CallOpts)
}

// TaikoInbox is a free data retrieval call binding the contract method 0x5de92721.
//
// Solidity: function taikoInbox() view returns(address)
func (_SurgeVerifier *SurgeVerifierCallerSession) TaikoInbox() (common.Address, error) {
	return _SurgeVerifier.Contract.TaikoInbox(&_SurgeVerifier.CallOpts)
}

// Init is a paid mutator transaction binding the contract method 0x359ef75b.
//
// Solidity: function init(address _owner, address _sgxRethVerifier, address _risc0RethVerifier, address _sp1RethVerifier, address _sgxGethVerifier) returns()
func (_SurgeVerifier *SurgeVerifierTransactor) Init(opts *bind.TransactOpts, _owner common.Address, _sgxRethVerifier common.Address, _risc0RethVerifier common.Address, _sp1RethVerifier common.Address, _sgxGethVerifier common.Address) (*types.Transaction, error) {
	return _SurgeVerifier.contract.Transact(opts, "init", _owner, _sgxRethVerifier, _risc0RethVerifier, _sp1RethVerifier, _sgxGethVerifier)
}

// Init is a paid mutator transaction binding the contract method 0x359ef75b.
//
// Solidity: function init(address _owner, address _sgxRethVerifier, address _risc0RethVerifier, address _sp1RethVerifier, address _sgxGethVerifier) returns()
func (_SurgeVerifier *SurgeVerifierSession) Init(_owner common.Address, _sgxRethVerifier common.Address, _risc0RethVerifier common.Address, _sp1RethVerifier common.Address, _sgxGethVerifier common.Address) (*types.Transaction, error) {
	return _SurgeVerifier.Contract.Init(&_SurgeVerifier.TransactOpts, _owner, _sgxRethVerifier, _risc0RethVerifier, _sp1RethVerifier, _sgxGethVerifier)
}

// Init is a paid mutator transaction binding the contract method 0x359ef75b.
//
// Solidity: function init(address _owner, address _sgxRethVerifier, address _risc0RethVerifier, address _sp1RethVerifier, address _sgxGethVerifier) returns()
func (_SurgeVerifier *SurgeVerifierTransactorSession) Init(_owner common.Address, _sgxRethVerifier common.Address, _risc0RethVerifier common.Address, _sp1RethVerifier common.Address, _sgxGethVerifier common.Address) (*types.Transaction, error) {
	return _SurgeVerifier.Contract.Init(&_SurgeVerifier.TransactOpts, _owner, _sgxRethVerifier, _risc0RethVerifier, _sp1RethVerifier, _sgxGethVerifier)
}

// MarkUpgradeable is a paid mutator transaction binding the contract method 0xca9c6594.
//
// Solidity: function markUpgradeable(uint16 _proofType) returns()
func (_SurgeVerifier *SurgeVerifierTransactor) MarkUpgradeable(opts *bind.TransactOpts, _proofType uint16) (*types.Transaction, error) {
	return _SurgeVerifier.contract.Transact(opts, "markUpgradeable", _proofType)
}

// MarkUpgradeable is a paid mutator transaction binding the contract method 0xca9c6594.
//
// Solidity: function markUpgradeable(uint16 _proofType) returns()
func (_SurgeVerifier *SurgeVerifierSession) MarkUpgradeable(_proofType uint16) (*types.Transaction, error) {
	return _SurgeVerifier.Contract.MarkUpgradeable(&_SurgeVerifier.TransactOpts, _proofType)
}

// MarkUpgradeable is a paid mutator transaction binding the contract method 0xca9c6594.
//
// Solidity: function markUpgradeable(uint16 _proofType) returns()
func (_SurgeVerifier *SurgeVerifierTransactorSession) MarkUpgradeable(_proofType uint16) (*types.Transaction, error) {
	return _SurgeVerifier.Contract.MarkUpgradeable(&_SurgeVerifier.TransactOpts, _proofType)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_SurgeVerifier *SurgeVerifierTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SurgeVerifier.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_SurgeVerifier *SurgeVerifierSession) Pause() (*types.Transaction, error) {
	return _SurgeVerifier.Contract.Pause(&_SurgeVerifier.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_SurgeVerifier *SurgeVerifierTransactorSession) Pause() (*types.Transaction, error) {
	return _SurgeVerifier.Contract.Pause(&_SurgeVerifier.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_SurgeVerifier *SurgeVerifierTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SurgeVerifier.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_SurgeVerifier *SurgeVerifierSession) RenounceOwnership() (*types.Transaction, error) {
	return _SurgeVerifier.Contract.RenounceOwnership(&_SurgeVerifier.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_SurgeVerifier *SurgeVerifierTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _SurgeVerifier.Contract.RenounceOwnership(&_SurgeVerifier.TransactOpts)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_SurgeVerifier *SurgeVerifierTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _SurgeVerifier.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_SurgeVerifier *SurgeVerifierSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _SurgeVerifier.Contract.TransferOwnership(&_SurgeVerifier.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_SurgeVerifier *SurgeVerifierTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _SurgeVerifier.Contract.TransferOwnership(&_SurgeVerifier.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_SurgeVerifier *SurgeVerifierTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SurgeVerifier.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_SurgeVerifier *SurgeVerifierSession) Unpause() (*types.Transaction, error) {
	return _SurgeVerifier.Contract.Unpause(&_SurgeVerifier.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_SurgeVerifier *SurgeVerifierTransactorSession) Unpause() (*types.Transaction, error) {
	return _SurgeVerifier.Contract.Unpause(&_SurgeVerifier.TransactOpts)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_SurgeVerifier *SurgeVerifierTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _SurgeVerifier.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_SurgeVerifier *SurgeVerifierSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _SurgeVerifier.Contract.UpgradeTo(&_SurgeVerifier.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_SurgeVerifier *SurgeVerifierTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _SurgeVerifier.Contract.UpgradeTo(&_SurgeVerifier.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_SurgeVerifier *SurgeVerifierTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _SurgeVerifier.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_SurgeVerifier *SurgeVerifierSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _SurgeVerifier.Contract.UpgradeToAndCall(&_SurgeVerifier.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_SurgeVerifier *SurgeVerifierTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _SurgeVerifier.Contract.UpgradeToAndCall(&_SurgeVerifier.TransactOpts, newImplementation, data)
}

// UpgradeVerifier is a paid mutator transaction binding the contract method 0x1b8cae09.
//
// Solidity: function upgradeVerifier(uint16 _proofType, address _newVerifier) returns()
func (_SurgeVerifier *SurgeVerifierTransactor) UpgradeVerifier(opts *bind.TransactOpts, _proofType uint16, _newVerifier common.Address) (*types.Transaction, error) {
	return _SurgeVerifier.contract.Transact(opts, "upgradeVerifier", _proofType, _newVerifier)
}

// UpgradeVerifier is a paid mutator transaction binding the contract method 0x1b8cae09.
//
// Solidity: function upgradeVerifier(uint16 _proofType, address _newVerifier) returns()
func (_SurgeVerifier *SurgeVerifierSession) UpgradeVerifier(_proofType uint16, _newVerifier common.Address) (*types.Transaction, error) {
	return _SurgeVerifier.Contract.UpgradeVerifier(&_SurgeVerifier.TransactOpts, _proofType, _newVerifier)
}

// UpgradeVerifier is a paid mutator transaction binding the contract method 0x1b8cae09.
//
// Solidity: function upgradeVerifier(uint16 _proofType, address _newVerifier) returns()
func (_SurgeVerifier *SurgeVerifierTransactorSession) UpgradeVerifier(_proofType uint16, _newVerifier common.Address) (*types.Transaction, error) {
	return _SurgeVerifier.Contract.UpgradeVerifier(&_SurgeVerifier.TransactOpts, _proofType, _newVerifier)
}

// VerifyProof is a paid mutator transaction binding the contract method 0x9b26b724.
//
// Solidity: function verifyProof((uint64,bytes32,(bytes32,bytes32,bytes32))[] _ctxs, bytes _proof) returns(uint16)
func (_SurgeVerifier *SurgeVerifierTransactor) VerifyProof(opts *bind.TransactOpts, _ctxs []IVerifierContext, _proof []byte) (*types.Transaction, error) {
	return _SurgeVerifier.contract.Transact(opts, "verifyProof", _ctxs, _proof)
}

// VerifyProof is a paid mutator transaction binding the contract method 0x9b26b724.
//
// Solidity: function verifyProof((uint64,bytes32,(bytes32,bytes32,bytes32))[] _ctxs, bytes _proof) returns(uint16)
func (_SurgeVerifier *SurgeVerifierSession) VerifyProof(_ctxs []IVerifierContext, _proof []byte) (*types.Transaction, error) {
	return _SurgeVerifier.Contract.VerifyProof(&_SurgeVerifier.TransactOpts, _ctxs, _proof)
}

// VerifyProof is a paid mutator transaction binding the contract method 0x9b26b724.
//
// Solidity: function verifyProof((uint64,bytes32,(bytes32,bytes32,bytes32))[] _ctxs, bytes _proof) returns(uint16)
func (_SurgeVerifier *SurgeVerifierTransactorSession) VerifyProof(_ctxs []IVerifierContext, _proof []byte) (*types.Transaction, error) {
	return _SurgeVerifier.Contract.VerifyProof(&_SurgeVerifier.TransactOpts, _ctxs, _proof)
}

// SurgeVerifierAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the SurgeVerifier contract.
type SurgeVerifierAdminChangedIterator struct {
	Event *SurgeVerifierAdminChanged // Event containing the contract specifics and raw log

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
func (it *SurgeVerifierAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SurgeVerifierAdminChanged)
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
		it.Event = new(SurgeVerifierAdminChanged)
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
func (it *SurgeVerifierAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SurgeVerifierAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SurgeVerifierAdminChanged represents a AdminChanged event raised by the SurgeVerifier contract.
type SurgeVerifierAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_SurgeVerifier *SurgeVerifierFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*SurgeVerifierAdminChangedIterator, error) {

	logs, sub, err := _SurgeVerifier.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &SurgeVerifierAdminChangedIterator{contract: _SurgeVerifier.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_SurgeVerifier *SurgeVerifierFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *SurgeVerifierAdminChanged) (event.Subscription, error) {

	logs, sub, err := _SurgeVerifier.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SurgeVerifierAdminChanged)
				if err := _SurgeVerifier.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_SurgeVerifier *SurgeVerifierFilterer) ParseAdminChanged(log types.Log) (*SurgeVerifierAdminChanged, error) {
	event := new(SurgeVerifierAdminChanged)
	if err := _SurgeVerifier.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SurgeVerifierBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the SurgeVerifier contract.
type SurgeVerifierBeaconUpgradedIterator struct {
	Event *SurgeVerifierBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *SurgeVerifierBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SurgeVerifierBeaconUpgraded)
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
		it.Event = new(SurgeVerifierBeaconUpgraded)
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
func (it *SurgeVerifierBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SurgeVerifierBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SurgeVerifierBeaconUpgraded represents a BeaconUpgraded event raised by the SurgeVerifier contract.
type SurgeVerifierBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_SurgeVerifier *SurgeVerifierFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*SurgeVerifierBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _SurgeVerifier.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &SurgeVerifierBeaconUpgradedIterator{contract: _SurgeVerifier.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_SurgeVerifier *SurgeVerifierFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *SurgeVerifierBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _SurgeVerifier.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SurgeVerifierBeaconUpgraded)
				if err := _SurgeVerifier.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_SurgeVerifier *SurgeVerifierFilterer) ParseBeaconUpgraded(log types.Log) (*SurgeVerifierBeaconUpgraded, error) {
	event := new(SurgeVerifierBeaconUpgraded)
	if err := _SurgeVerifier.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SurgeVerifierInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the SurgeVerifier contract.
type SurgeVerifierInitializedIterator struct {
	Event *SurgeVerifierInitialized // Event containing the contract specifics and raw log

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
func (it *SurgeVerifierInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SurgeVerifierInitialized)
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
		it.Event = new(SurgeVerifierInitialized)
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
func (it *SurgeVerifierInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SurgeVerifierInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SurgeVerifierInitialized represents a Initialized event raised by the SurgeVerifier contract.
type SurgeVerifierInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_SurgeVerifier *SurgeVerifierFilterer) FilterInitialized(opts *bind.FilterOpts) (*SurgeVerifierInitializedIterator, error) {

	logs, sub, err := _SurgeVerifier.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &SurgeVerifierInitializedIterator{contract: _SurgeVerifier.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_SurgeVerifier *SurgeVerifierFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *SurgeVerifierInitialized) (event.Subscription, error) {

	logs, sub, err := _SurgeVerifier.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SurgeVerifierInitialized)
				if err := _SurgeVerifier.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_SurgeVerifier *SurgeVerifierFilterer) ParseInitialized(log types.Log) (*SurgeVerifierInitialized, error) {
	event := new(SurgeVerifierInitialized)
	if err := _SurgeVerifier.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SurgeVerifierOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the SurgeVerifier contract.
type SurgeVerifierOwnershipTransferredIterator struct {
	Event *SurgeVerifierOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *SurgeVerifierOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SurgeVerifierOwnershipTransferred)
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
		it.Event = new(SurgeVerifierOwnershipTransferred)
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
func (it *SurgeVerifierOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SurgeVerifierOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SurgeVerifierOwnershipTransferred represents a OwnershipTransferred event raised by the SurgeVerifier contract.
type SurgeVerifierOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_SurgeVerifier *SurgeVerifierFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*SurgeVerifierOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SurgeVerifier.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &SurgeVerifierOwnershipTransferredIterator{contract: _SurgeVerifier.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_SurgeVerifier *SurgeVerifierFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *SurgeVerifierOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SurgeVerifier.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SurgeVerifierOwnershipTransferred)
				if err := _SurgeVerifier.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_SurgeVerifier *SurgeVerifierFilterer) ParseOwnershipTransferred(log types.Log) (*SurgeVerifierOwnershipTransferred, error) {
	event := new(SurgeVerifierOwnershipTransferred)
	if err := _SurgeVerifier.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SurgeVerifierPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the SurgeVerifier contract.
type SurgeVerifierPausedIterator struct {
	Event *SurgeVerifierPaused // Event containing the contract specifics and raw log

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
func (it *SurgeVerifierPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SurgeVerifierPaused)
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
		it.Event = new(SurgeVerifierPaused)
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
func (it *SurgeVerifierPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SurgeVerifierPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SurgeVerifierPaused represents a Paused event raised by the SurgeVerifier contract.
type SurgeVerifierPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_SurgeVerifier *SurgeVerifierFilterer) FilterPaused(opts *bind.FilterOpts) (*SurgeVerifierPausedIterator, error) {

	logs, sub, err := _SurgeVerifier.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &SurgeVerifierPausedIterator{contract: _SurgeVerifier.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_SurgeVerifier *SurgeVerifierFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *SurgeVerifierPaused) (event.Subscription, error) {

	logs, sub, err := _SurgeVerifier.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SurgeVerifierPaused)
				if err := _SurgeVerifier.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_SurgeVerifier *SurgeVerifierFilterer) ParsePaused(log types.Log) (*SurgeVerifierPaused, error) {
	event := new(SurgeVerifierPaused)
	if err := _SurgeVerifier.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SurgeVerifierUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the SurgeVerifier contract.
type SurgeVerifierUnpausedIterator struct {
	Event *SurgeVerifierUnpaused // Event containing the contract specifics and raw log

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
func (it *SurgeVerifierUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SurgeVerifierUnpaused)
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
		it.Event = new(SurgeVerifierUnpaused)
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
func (it *SurgeVerifierUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SurgeVerifierUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SurgeVerifierUnpaused represents a Unpaused event raised by the SurgeVerifier contract.
type SurgeVerifierUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_SurgeVerifier *SurgeVerifierFilterer) FilterUnpaused(opts *bind.FilterOpts) (*SurgeVerifierUnpausedIterator, error) {

	logs, sub, err := _SurgeVerifier.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &SurgeVerifierUnpausedIterator{contract: _SurgeVerifier.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_SurgeVerifier *SurgeVerifierFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *SurgeVerifierUnpaused) (event.Subscription, error) {

	logs, sub, err := _SurgeVerifier.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SurgeVerifierUnpaused)
				if err := _SurgeVerifier.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_SurgeVerifier *SurgeVerifierFilterer) ParseUnpaused(log types.Log) (*SurgeVerifierUnpaused, error) {
	event := new(SurgeVerifierUnpaused)
	if err := _SurgeVerifier.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SurgeVerifierUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the SurgeVerifier contract.
type SurgeVerifierUpgradedIterator struct {
	Event *SurgeVerifierUpgraded // Event containing the contract specifics and raw log

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
func (it *SurgeVerifierUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SurgeVerifierUpgraded)
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
		it.Event = new(SurgeVerifierUpgraded)
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
func (it *SurgeVerifierUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SurgeVerifierUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SurgeVerifierUpgraded represents a Upgraded event raised by the SurgeVerifier contract.
type SurgeVerifierUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_SurgeVerifier *SurgeVerifierFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*SurgeVerifierUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _SurgeVerifier.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &SurgeVerifierUpgradedIterator{contract: _SurgeVerifier.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_SurgeVerifier *SurgeVerifierFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *SurgeVerifierUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _SurgeVerifier.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SurgeVerifierUpgraded)
				if err := _SurgeVerifier.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_SurgeVerifier *SurgeVerifierFilterer) ParseUpgraded(log types.Log) (*SurgeVerifierUpgraded, error) {
	event := new(SurgeVerifierUpgraded)
	if err := _SurgeVerifier.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
