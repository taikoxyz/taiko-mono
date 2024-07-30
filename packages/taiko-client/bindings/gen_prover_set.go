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

// ProverSetMetaData contains all meta data concerning the ProverSet contract.
var ProverSetMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"receive\",\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"addressManager\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"admin\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"approveAllowance\",\"inputs\":[{\"name\":\"_address\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_allowance\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"delegate\",\"inputs\":[{\"name\":\"_delegatee\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"depositBond\",\"inputs\":[{\"name\":\"_amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"enableProver\",\"inputs\":[{\"name\":\"_prover\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_isProver\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"impl\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inNonReentrant\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_admin\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_rollupAddressManager\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isProver\",\"inputs\":[{\"name\":\"prover\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"isProver\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isValidSignature\",\"inputs\":[{\"name\":\"_hash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_signature\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"magicValue_\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"lastUnpausedAt\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proposeBlock\",\"inputs\":[{\"name\":\"_params\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"_txList\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"proposeBlockV2\",\"inputs\":[{\"name\":\"_params\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"_txList\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"proveBlock\",\"inputs\":[{\"name\":\"_blockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_input\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolve\",\"inputs\":[{\"name\":\"_chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_allowZeroAddress\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"resolve\",\"inputs\":[{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_allowZeroAddress\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"withdrawBond\",\"inputs\":[{\"name\":\"_amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"withdrawEtherToAdmin\",\"inputs\":[{\"name\":\"_amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"withdrawToAdmin\",\"inputs\":[{\"name\":\"_amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ProverEnabled\",\"inputs\":[{\"name\":\"prover\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"enabled\",\"type\":\"bool\",\"indexed\":true,\"internalType\":\"bool\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ETH_TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FUNC_NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"PERMISSION_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_INVALID_MANAGER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_UNEXPECTED_CHAINID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_ZERO_ADDR\",\"inputs\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_VALUE\",\"inputs\":[]}]",
}

// ProverSetABI is the input ABI used to generate the binding from.
// Deprecated: Use ProverSetMetaData.ABI instead.
var ProverSetABI = ProverSetMetaData.ABI

// ProverSet is an auto generated Go binding around an Ethereum contract.
type ProverSet struct {
	ProverSetCaller     // Read-only binding to the contract
	ProverSetTransactor // Write-only binding to the contract
	ProverSetFilterer   // Log filterer for contract events
}

// ProverSetCaller is an auto generated read-only Go binding around an Ethereum contract.
type ProverSetCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ProverSetTransactor is an auto generated write-only Go binding around an Ethereum contract.
type ProverSetTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ProverSetFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type ProverSetFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ProverSetSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type ProverSetSession struct {
	Contract     *ProverSet        // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// ProverSetCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type ProverSetCallerSession struct {
	Contract *ProverSetCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts    // Call options to use throughout this session
}

// ProverSetTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type ProverSetTransactorSession struct {
	Contract     *ProverSetTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts    // Transaction auth options to use throughout this session
}

// ProverSetRaw is an auto generated low-level Go binding around an Ethereum contract.
type ProverSetRaw struct {
	Contract *ProverSet // Generic contract binding to access the raw methods on
}

// ProverSetCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type ProverSetCallerRaw struct {
	Contract *ProverSetCaller // Generic read-only contract binding to access the raw methods on
}

// ProverSetTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type ProverSetTransactorRaw struct {
	Contract *ProverSetTransactor // Generic write-only contract binding to access the raw methods on
}

// NewProverSet creates a new instance of ProverSet, bound to a specific deployed contract.
func NewProverSet(address common.Address, backend bind.ContractBackend) (*ProverSet, error) {
	contract, err := bindProverSet(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &ProverSet{ProverSetCaller: ProverSetCaller{contract: contract}, ProverSetTransactor: ProverSetTransactor{contract: contract}, ProverSetFilterer: ProverSetFilterer{contract: contract}}, nil
}

// NewProverSetCaller creates a new read-only instance of ProverSet, bound to a specific deployed contract.
func NewProverSetCaller(address common.Address, caller bind.ContractCaller) (*ProverSetCaller, error) {
	contract, err := bindProverSet(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &ProverSetCaller{contract: contract}, nil
}

// NewProverSetTransactor creates a new write-only instance of ProverSet, bound to a specific deployed contract.
func NewProverSetTransactor(address common.Address, transactor bind.ContractTransactor) (*ProverSetTransactor, error) {
	contract, err := bindProverSet(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &ProverSetTransactor{contract: contract}, nil
}

// NewProverSetFilterer creates a new log filterer instance of ProverSet, bound to a specific deployed contract.
func NewProverSetFilterer(address common.Address, filterer bind.ContractFilterer) (*ProverSetFilterer, error) {
	contract, err := bindProverSet(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &ProverSetFilterer{contract: contract}, nil
}

// bindProverSet binds a generic wrapper to an already deployed contract.
func bindProverSet(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := ProverSetMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ProverSet *ProverSetRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ProverSet.Contract.ProverSetCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ProverSet *ProverSetRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ProverSet.Contract.ProverSetTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ProverSet *ProverSetRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ProverSet.Contract.ProverSetTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ProverSet *ProverSetCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ProverSet.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ProverSet *ProverSetTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ProverSet.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ProverSet *ProverSetTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ProverSet.Contract.contract.Transact(opts, method, params...)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_ProverSet *ProverSetCaller) AddressManager(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ProverSet.contract.Call(opts, &out, "addressManager")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_ProverSet *ProverSetSession) AddressManager() (common.Address, error) {
	return _ProverSet.Contract.AddressManager(&_ProverSet.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_ProverSet *ProverSetCallerSession) AddressManager() (common.Address, error) {
	return _ProverSet.Contract.AddressManager(&_ProverSet.CallOpts)
}

// Admin is a free data retrieval call binding the contract method 0xf851a440.
//
// Solidity: function admin() view returns(address)
func (_ProverSet *ProverSetCaller) Admin(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ProverSet.contract.Call(opts, &out, "admin")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Admin is a free data retrieval call binding the contract method 0xf851a440.
//
// Solidity: function admin() view returns(address)
func (_ProverSet *ProverSetSession) Admin() (common.Address, error) {
	return _ProverSet.Contract.Admin(&_ProverSet.CallOpts)
}

// Admin is a free data retrieval call binding the contract method 0xf851a440.
//
// Solidity: function admin() view returns(address)
func (_ProverSet *ProverSetCallerSession) Admin() (common.Address, error) {
	return _ProverSet.Contract.Admin(&_ProverSet.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_ProverSet *ProverSetCaller) Impl(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ProverSet.contract.Call(opts, &out, "impl")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_ProverSet *ProverSetSession) Impl() (common.Address, error) {
	return _ProverSet.Contract.Impl(&_ProverSet.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_ProverSet *ProverSetCallerSession) Impl() (common.Address, error) {
	return _ProverSet.Contract.Impl(&_ProverSet.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_ProverSet *ProverSetCaller) InNonReentrant(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _ProverSet.contract.Call(opts, &out, "inNonReentrant")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_ProverSet *ProverSetSession) InNonReentrant() (bool, error) {
	return _ProverSet.Contract.InNonReentrant(&_ProverSet.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_ProverSet *ProverSetCallerSession) InNonReentrant() (bool, error) {
	return _ProverSet.Contract.InNonReentrant(&_ProverSet.CallOpts)
}

// IsProver is a free data retrieval call binding the contract method 0x0a245924.
//
// Solidity: function isProver(address prover) view returns(bool isProver)
func (_ProverSet *ProverSetCaller) IsProver(opts *bind.CallOpts, prover common.Address) (bool, error) {
	var out []interface{}
	err := _ProverSet.contract.Call(opts, &out, "isProver", prover)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsProver is a free data retrieval call binding the contract method 0x0a245924.
//
// Solidity: function isProver(address prover) view returns(bool isProver)
func (_ProverSet *ProverSetSession) IsProver(prover common.Address) (bool, error) {
	return _ProverSet.Contract.IsProver(&_ProverSet.CallOpts, prover)
}

// IsProver is a free data retrieval call binding the contract method 0x0a245924.
//
// Solidity: function isProver(address prover) view returns(bool isProver)
func (_ProverSet *ProverSetCallerSession) IsProver(prover common.Address) (bool, error) {
	return _ProverSet.Contract.IsProver(&_ProverSet.CallOpts, prover)
}

// IsValidSignature is a free data retrieval call binding the contract method 0x1626ba7e.
//
// Solidity: function isValidSignature(bytes32 _hash, bytes _signature) view returns(bytes4 magicValue_)
func (_ProverSet *ProverSetCaller) IsValidSignature(opts *bind.CallOpts, _hash [32]byte, _signature []byte) ([4]byte, error) {
	var out []interface{}
	err := _ProverSet.contract.Call(opts, &out, "isValidSignature", _hash, _signature)

	if err != nil {
		return *new([4]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([4]byte)).(*[4]byte)

	return out0, err

}

// IsValidSignature is a free data retrieval call binding the contract method 0x1626ba7e.
//
// Solidity: function isValidSignature(bytes32 _hash, bytes _signature) view returns(bytes4 magicValue_)
func (_ProverSet *ProverSetSession) IsValidSignature(_hash [32]byte, _signature []byte) ([4]byte, error) {
	return _ProverSet.Contract.IsValidSignature(&_ProverSet.CallOpts, _hash, _signature)
}

// IsValidSignature is a free data retrieval call binding the contract method 0x1626ba7e.
//
// Solidity: function isValidSignature(bytes32 _hash, bytes _signature) view returns(bytes4 magicValue_)
func (_ProverSet *ProverSetCallerSession) IsValidSignature(_hash [32]byte, _signature []byte) ([4]byte, error) {
	return _ProverSet.Contract.IsValidSignature(&_ProverSet.CallOpts, _hash, _signature)
}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_ProverSet *ProverSetCaller) LastUnpausedAt(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _ProverSet.contract.Call(opts, &out, "lastUnpausedAt")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_ProverSet *ProverSetSession) LastUnpausedAt() (uint64, error) {
	return _ProverSet.Contract.LastUnpausedAt(&_ProverSet.CallOpts)
}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_ProverSet *ProverSetCallerSession) LastUnpausedAt() (uint64, error) {
	return _ProverSet.Contract.LastUnpausedAt(&_ProverSet.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ProverSet *ProverSetCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ProverSet.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ProverSet *ProverSetSession) Owner() (common.Address, error) {
	return _ProverSet.Contract.Owner(&_ProverSet.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ProverSet *ProverSetCallerSession) Owner() (common.Address, error) {
	return _ProverSet.Contract.Owner(&_ProverSet.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_ProverSet *ProverSetCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _ProverSet.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_ProverSet *ProverSetSession) Paused() (bool, error) {
	return _ProverSet.Contract.Paused(&_ProverSet.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_ProverSet *ProverSetCallerSession) Paused() (bool, error) {
	return _ProverSet.Contract.Paused(&_ProverSet.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_ProverSet *ProverSetCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ProverSet.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_ProverSet *ProverSetSession) PendingOwner() (common.Address, error) {
	return _ProverSet.Contract.PendingOwner(&_ProverSet.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_ProverSet *ProverSetCallerSession) PendingOwner() (common.Address, error) {
	return _ProverSet.Contract.PendingOwner(&_ProverSet.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_ProverSet *ProverSetCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _ProverSet.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_ProverSet *ProverSetSession) ProxiableUUID() ([32]byte, error) {
	return _ProverSet.Contract.ProxiableUUID(&_ProverSet.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_ProverSet *ProverSetCallerSession) ProxiableUUID() ([32]byte, error) {
	return _ProverSet.Contract.ProxiableUUID(&_ProverSet.CallOpts)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_ProverSet *ProverSetCaller) Resolve(opts *bind.CallOpts, _chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _ProverSet.contract.Call(opts, &out, "resolve", _chainId, _name, _allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_ProverSet *ProverSetSession) Resolve(_chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _ProverSet.Contract.Resolve(&_ProverSet.CallOpts, _chainId, _name, _allowZeroAddress)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_ProverSet *ProverSetCallerSession) Resolve(_chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _ProverSet.Contract.Resolve(&_ProverSet.CallOpts, _chainId, _name, _allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_ProverSet *ProverSetCaller) Resolve0(opts *bind.CallOpts, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _ProverSet.contract.Call(opts, &out, "resolve0", _name, _allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_ProverSet *ProverSetSession) Resolve0(_name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _ProverSet.Contract.Resolve0(&_ProverSet.CallOpts, _name, _allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_ProverSet *ProverSetCallerSession) Resolve0(_name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _ProverSet.Contract.Resolve0(&_ProverSet.CallOpts, _name, _allowZeroAddress)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_ProverSet *ProverSetTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ProverSet.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_ProverSet *ProverSetSession) AcceptOwnership() (*types.Transaction, error) {
	return _ProverSet.Contract.AcceptOwnership(&_ProverSet.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_ProverSet *ProverSetTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _ProverSet.Contract.AcceptOwnership(&_ProverSet.TransactOpts)
}

// ApproveAllowance is a paid mutator transaction binding the contract method 0x0a1553a5.
//
// Solidity: function approveAllowance(address _address, uint256 _allowance) returns()
func (_ProverSet *ProverSetTransactor) ApproveAllowance(opts *bind.TransactOpts, _address common.Address, _allowance *big.Int) (*types.Transaction, error) {
	return _ProverSet.contract.Transact(opts, "approveAllowance", _address, _allowance)
}

// ApproveAllowance is a paid mutator transaction binding the contract method 0x0a1553a5.
//
// Solidity: function approveAllowance(address _address, uint256 _allowance) returns()
func (_ProverSet *ProverSetSession) ApproveAllowance(_address common.Address, _allowance *big.Int) (*types.Transaction, error) {
	return _ProverSet.Contract.ApproveAllowance(&_ProverSet.TransactOpts, _address, _allowance)
}

// ApproveAllowance is a paid mutator transaction binding the contract method 0x0a1553a5.
//
// Solidity: function approveAllowance(address _address, uint256 _allowance) returns()
func (_ProverSet *ProverSetTransactorSession) ApproveAllowance(_address common.Address, _allowance *big.Int) (*types.Transaction, error) {
	return _ProverSet.Contract.ApproveAllowance(&_ProverSet.TransactOpts, _address, _allowance)
}

// Delegate is a paid mutator transaction binding the contract method 0x5c19a95c.
//
// Solidity: function delegate(address _delegatee) returns()
func (_ProverSet *ProverSetTransactor) Delegate(opts *bind.TransactOpts, _delegatee common.Address) (*types.Transaction, error) {
	return _ProverSet.contract.Transact(opts, "delegate", _delegatee)
}

// Delegate is a paid mutator transaction binding the contract method 0x5c19a95c.
//
// Solidity: function delegate(address _delegatee) returns()
func (_ProverSet *ProverSetSession) Delegate(_delegatee common.Address) (*types.Transaction, error) {
	return _ProverSet.Contract.Delegate(&_ProverSet.TransactOpts, _delegatee)
}

// Delegate is a paid mutator transaction binding the contract method 0x5c19a95c.
//
// Solidity: function delegate(address _delegatee) returns()
func (_ProverSet *ProverSetTransactorSession) Delegate(_delegatee common.Address) (*types.Transaction, error) {
	return _ProverSet.Contract.Delegate(&_ProverSet.TransactOpts, _delegatee)
}

// DepositBond is a paid mutator transaction binding the contract method 0x4dcb05f9.
//
// Solidity: function depositBond(uint256 _amount) returns()
func (_ProverSet *ProverSetTransactor) DepositBond(opts *bind.TransactOpts, _amount *big.Int) (*types.Transaction, error) {
	return _ProverSet.contract.Transact(opts, "depositBond", _amount)
}

// DepositBond is a paid mutator transaction binding the contract method 0x4dcb05f9.
//
// Solidity: function depositBond(uint256 _amount) returns()
func (_ProverSet *ProverSetSession) DepositBond(_amount *big.Int) (*types.Transaction, error) {
	return _ProverSet.Contract.DepositBond(&_ProverSet.TransactOpts, _amount)
}

// DepositBond is a paid mutator transaction binding the contract method 0x4dcb05f9.
//
// Solidity: function depositBond(uint256 _amount) returns()
func (_ProverSet *ProverSetTransactorSession) DepositBond(_amount *big.Int) (*types.Transaction, error) {
	return _ProverSet.Contract.DepositBond(&_ProverSet.TransactOpts, _amount)
}

// EnableProver is a paid mutator transaction binding the contract method 0xcb4cd0a4.
//
// Solidity: function enableProver(address _prover, bool _isProver) returns()
func (_ProverSet *ProverSetTransactor) EnableProver(opts *bind.TransactOpts, _prover common.Address, _isProver bool) (*types.Transaction, error) {
	return _ProverSet.contract.Transact(opts, "enableProver", _prover, _isProver)
}

// EnableProver is a paid mutator transaction binding the contract method 0xcb4cd0a4.
//
// Solidity: function enableProver(address _prover, bool _isProver) returns()
func (_ProverSet *ProverSetSession) EnableProver(_prover common.Address, _isProver bool) (*types.Transaction, error) {
	return _ProverSet.Contract.EnableProver(&_ProverSet.TransactOpts, _prover, _isProver)
}

// EnableProver is a paid mutator transaction binding the contract method 0xcb4cd0a4.
//
// Solidity: function enableProver(address _prover, bool _isProver) returns()
func (_ProverSet *ProverSetTransactorSession) EnableProver(_prover common.Address, _isProver bool) (*types.Transaction, error) {
	return _ProverSet.Contract.EnableProver(&_ProverSet.TransactOpts, _prover, _isProver)
}

// Init is a paid mutator transaction binding the contract method 0x184b9559.
//
// Solidity: function init(address _owner, address _admin, address _rollupAddressManager) returns()
func (_ProverSet *ProverSetTransactor) Init(opts *bind.TransactOpts, _owner common.Address, _admin common.Address, _rollupAddressManager common.Address) (*types.Transaction, error) {
	return _ProverSet.contract.Transact(opts, "init", _owner, _admin, _rollupAddressManager)
}

// Init is a paid mutator transaction binding the contract method 0x184b9559.
//
// Solidity: function init(address _owner, address _admin, address _rollupAddressManager) returns()
func (_ProverSet *ProverSetSession) Init(_owner common.Address, _admin common.Address, _rollupAddressManager common.Address) (*types.Transaction, error) {
	return _ProverSet.Contract.Init(&_ProverSet.TransactOpts, _owner, _admin, _rollupAddressManager)
}

// Init is a paid mutator transaction binding the contract method 0x184b9559.
//
// Solidity: function init(address _owner, address _admin, address _rollupAddressManager) returns()
func (_ProverSet *ProverSetTransactorSession) Init(_owner common.Address, _admin common.Address, _rollupAddressManager common.Address) (*types.Transaction, error) {
	return _ProverSet.Contract.Init(&_ProverSet.TransactOpts, _owner, _admin, _rollupAddressManager)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_ProverSet *ProverSetTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ProverSet.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_ProverSet *ProverSetSession) Pause() (*types.Transaction, error) {
	return _ProverSet.Contract.Pause(&_ProverSet.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_ProverSet *ProverSetTransactorSession) Pause() (*types.Transaction, error) {
	return _ProverSet.Contract.Pause(&_ProverSet.TransactOpts)
}

// ProposeBlock is a paid mutator transaction binding the contract method 0xef16e845.
//
// Solidity: function proposeBlock(bytes _params, bytes _txList) payable returns()
func (_ProverSet *ProverSetTransactor) ProposeBlock(opts *bind.TransactOpts, _params []byte, _txList []byte) (*types.Transaction, error) {
	return _ProverSet.contract.Transact(opts, "proposeBlock", _params, _txList)
}

// ProposeBlock is a paid mutator transaction binding the contract method 0xef16e845.
//
// Solidity: function proposeBlock(bytes _params, bytes _txList) payable returns()
func (_ProverSet *ProverSetSession) ProposeBlock(_params []byte, _txList []byte) (*types.Transaction, error) {
	return _ProverSet.Contract.ProposeBlock(&_ProverSet.TransactOpts, _params, _txList)
}

// ProposeBlock is a paid mutator transaction binding the contract method 0xef16e845.
//
// Solidity: function proposeBlock(bytes _params, bytes _txList) payable returns()
func (_ProverSet *ProverSetTransactorSession) ProposeBlock(_params []byte, _txList []byte) (*types.Transaction, error) {
	return _ProverSet.Contract.ProposeBlock(&_ProverSet.TransactOpts, _params, _txList)
}

// ProposeBlockV2 is a paid mutator transaction binding the contract method 0x648885fb.
//
// Solidity: function proposeBlockV2(bytes _params, bytes _txList) payable returns()
func (_ProverSet *ProverSetTransactor) ProposeBlockV2(opts *bind.TransactOpts, _params []byte, _txList []byte) (*types.Transaction, error) {
	return _ProverSet.contract.Transact(opts, "proposeBlockV2", _params, _txList)
}

// ProposeBlockV2 is a paid mutator transaction binding the contract method 0x648885fb.
//
// Solidity: function proposeBlockV2(bytes _params, bytes _txList) payable returns()
func (_ProverSet *ProverSetSession) ProposeBlockV2(_params []byte, _txList []byte) (*types.Transaction, error) {
	return _ProverSet.Contract.ProposeBlockV2(&_ProverSet.TransactOpts, _params, _txList)
}

// ProposeBlockV2 is a paid mutator transaction binding the contract method 0x648885fb.
//
// Solidity: function proposeBlockV2(bytes _params, bytes _txList) payable returns()
func (_ProverSet *ProverSetTransactorSession) ProposeBlockV2(_params []byte, _txList []byte) (*types.Transaction, error) {
	return _ProverSet.Contract.ProposeBlockV2(&_ProverSet.TransactOpts, _params, _txList)
}

// ProveBlock is a paid mutator transaction binding the contract method 0x10d008bd.
//
// Solidity: function proveBlock(uint64 _blockId, bytes _input) returns()
func (_ProverSet *ProverSetTransactor) ProveBlock(opts *bind.TransactOpts, _blockId uint64, _input []byte) (*types.Transaction, error) {
	return _ProverSet.contract.Transact(opts, "proveBlock", _blockId, _input)
}

// ProveBlock is a paid mutator transaction binding the contract method 0x10d008bd.
//
// Solidity: function proveBlock(uint64 _blockId, bytes _input) returns()
func (_ProverSet *ProverSetSession) ProveBlock(_blockId uint64, _input []byte) (*types.Transaction, error) {
	return _ProverSet.Contract.ProveBlock(&_ProverSet.TransactOpts, _blockId, _input)
}

// ProveBlock is a paid mutator transaction binding the contract method 0x10d008bd.
//
// Solidity: function proveBlock(uint64 _blockId, bytes _input) returns()
func (_ProverSet *ProverSetTransactorSession) ProveBlock(_blockId uint64, _input []byte) (*types.Transaction, error) {
	return _ProverSet.Contract.ProveBlock(&_ProverSet.TransactOpts, _blockId, _input)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ProverSet *ProverSetTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ProverSet.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ProverSet *ProverSetSession) RenounceOwnership() (*types.Transaction, error) {
	return _ProverSet.Contract.RenounceOwnership(&_ProverSet.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ProverSet *ProverSetTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _ProverSet.Contract.RenounceOwnership(&_ProverSet.TransactOpts)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ProverSet *ProverSetTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _ProverSet.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ProverSet *ProverSetSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _ProverSet.Contract.TransferOwnership(&_ProverSet.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ProverSet *ProverSetTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _ProverSet.Contract.TransferOwnership(&_ProverSet.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_ProverSet *ProverSetTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ProverSet.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_ProverSet *ProverSetSession) Unpause() (*types.Transaction, error) {
	return _ProverSet.Contract.Unpause(&_ProverSet.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_ProverSet *ProverSetTransactorSession) Unpause() (*types.Transaction, error) {
	return _ProverSet.Contract.Unpause(&_ProverSet.TransactOpts)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_ProverSet *ProverSetTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _ProverSet.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_ProverSet *ProverSetSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _ProverSet.Contract.UpgradeTo(&_ProverSet.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_ProverSet *ProverSetTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _ProverSet.Contract.UpgradeTo(&_ProverSet.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_ProverSet *ProverSetTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _ProverSet.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_ProverSet *ProverSetSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _ProverSet.Contract.UpgradeToAndCall(&_ProverSet.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_ProverSet *ProverSetTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _ProverSet.Contract.UpgradeToAndCall(&_ProverSet.TransactOpts, newImplementation, data)
}

// WithdrawBond is a paid mutator transaction binding the contract method 0xc3daab96.
//
// Solidity: function withdrawBond(uint256 _amount) returns()
func (_ProverSet *ProverSetTransactor) WithdrawBond(opts *bind.TransactOpts, _amount *big.Int) (*types.Transaction, error) {
	return _ProverSet.contract.Transact(opts, "withdrawBond", _amount)
}

// WithdrawBond is a paid mutator transaction binding the contract method 0xc3daab96.
//
// Solidity: function withdrawBond(uint256 _amount) returns()
func (_ProverSet *ProverSetSession) WithdrawBond(_amount *big.Int) (*types.Transaction, error) {
	return _ProverSet.Contract.WithdrawBond(&_ProverSet.TransactOpts, _amount)
}

// WithdrawBond is a paid mutator transaction binding the contract method 0xc3daab96.
//
// Solidity: function withdrawBond(uint256 _amount) returns()
func (_ProverSet *ProverSetTransactorSession) WithdrawBond(_amount *big.Int) (*types.Transaction, error) {
	return _ProverSet.Contract.WithdrawBond(&_ProverSet.TransactOpts, _amount)
}

// WithdrawEtherToAdmin is a paid mutator transaction binding the contract method 0x7ddb9fec.
//
// Solidity: function withdrawEtherToAdmin(uint256 _amount) returns()
func (_ProverSet *ProverSetTransactor) WithdrawEtherToAdmin(opts *bind.TransactOpts, _amount *big.Int) (*types.Transaction, error) {
	return _ProverSet.contract.Transact(opts, "withdrawEtherToAdmin", _amount)
}

// WithdrawEtherToAdmin is a paid mutator transaction binding the contract method 0x7ddb9fec.
//
// Solidity: function withdrawEtherToAdmin(uint256 _amount) returns()
func (_ProverSet *ProverSetSession) WithdrawEtherToAdmin(_amount *big.Int) (*types.Transaction, error) {
	return _ProverSet.Contract.WithdrawEtherToAdmin(&_ProverSet.TransactOpts, _amount)
}

// WithdrawEtherToAdmin is a paid mutator transaction binding the contract method 0x7ddb9fec.
//
// Solidity: function withdrawEtherToAdmin(uint256 _amount) returns()
func (_ProverSet *ProverSetTransactorSession) WithdrawEtherToAdmin(_amount *big.Int) (*types.Transaction, error) {
	return _ProverSet.Contract.WithdrawEtherToAdmin(&_ProverSet.TransactOpts, _amount)
}

// WithdrawToAdmin is a paid mutator transaction binding the contract method 0x8bd809fd.
//
// Solidity: function withdrawToAdmin(uint256 _amount) returns()
func (_ProverSet *ProverSetTransactor) WithdrawToAdmin(opts *bind.TransactOpts, _amount *big.Int) (*types.Transaction, error) {
	return _ProverSet.contract.Transact(opts, "withdrawToAdmin", _amount)
}

// WithdrawToAdmin is a paid mutator transaction binding the contract method 0x8bd809fd.
//
// Solidity: function withdrawToAdmin(uint256 _amount) returns()
func (_ProverSet *ProverSetSession) WithdrawToAdmin(_amount *big.Int) (*types.Transaction, error) {
	return _ProverSet.Contract.WithdrawToAdmin(&_ProverSet.TransactOpts, _amount)
}

// WithdrawToAdmin is a paid mutator transaction binding the contract method 0x8bd809fd.
//
// Solidity: function withdrawToAdmin(uint256 _amount) returns()
func (_ProverSet *ProverSetTransactorSession) WithdrawToAdmin(_amount *big.Int) (*types.Transaction, error) {
	return _ProverSet.Contract.WithdrawToAdmin(&_ProverSet.TransactOpts, _amount)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_ProverSet *ProverSetTransactor) Receive(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ProverSet.contract.RawTransact(opts, nil) // calldata is disallowed for receive function
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_ProverSet *ProverSetSession) Receive() (*types.Transaction, error) {
	return _ProverSet.Contract.Receive(&_ProverSet.TransactOpts)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_ProverSet *ProverSetTransactorSession) Receive() (*types.Transaction, error) {
	return _ProverSet.Contract.Receive(&_ProverSet.TransactOpts)
}

// ProverSetAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the ProverSet contract.
type ProverSetAdminChangedIterator struct {
	Event *ProverSetAdminChanged // Event containing the contract specifics and raw log

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
func (it *ProverSetAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ProverSetAdminChanged)
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
		it.Event = new(ProverSetAdminChanged)
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
func (it *ProverSetAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ProverSetAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ProverSetAdminChanged represents a AdminChanged event raised by the ProverSet contract.
type ProverSetAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_ProverSet *ProverSetFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*ProverSetAdminChangedIterator, error) {

	logs, sub, err := _ProverSet.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &ProverSetAdminChangedIterator{contract: _ProverSet.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_ProverSet *ProverSetFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *ProverSetAdminChanged) (event.Subscription, error) {

	logs, sub, err := _ProverSet.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ProverSetAdminChanged)
				if err := _ProverSet.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_ProverSet *ProverSetFilterer) ParseAdminChanged(log types.Log) (*ProverSetAdminChanged, error) {
	event := new(ProverSetAdminChanged)
	if err := _ProverSet.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ProverSetBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the ProverSet contract.
type ProverSetBeaconUpgradedIterator struct {
	Event *ProverSetBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *ProverSetBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ProverSetBeaconUpgraded)
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
		it.Event = new(ProverSetBeaconUpgraded)
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
func (it *ProverSetBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ProverSetBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ProverSetBeaconUpgraded represents a BeaconUpgraded event raised by the ProverSet contract.
type ProverSetBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_ProverSet *ProverSetFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*ProverSetBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _ProverSet.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &ProverSetBeaconUpgradedIterator{contract: _ProverSet.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_ProverSet *ProverSetFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *ProverSetBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _ProverSet.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ProverSetBeaconUpgraded)
				if err := _ProverSet.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_ProverSet *ProverSetFilterer) ParseBeaconUpgraded(log types.Log) (*ProverSetBeaconUpgraded, error) {
	event := new(ProverSetBeaconUpgraded)
	if err := _ProverSet.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ProverSetInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the ProverSet contract.
type ProverSetInitializedIterator struct {
	Event *ProverSetInitialized // Event containing the contract specifics and raw log

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
func (it *ProverSetInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ProverSetInitialized)
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
		it.Event = new(ProverSetInitialized)
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
func (it *ProverSetInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ProverSetInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ProverSetInitialized represents a Initialized event raised by the ProverSet contract.
type ProverSetInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_ProverSet *ProverSetFilterer) FilterInitialized(opts *bind.FilterOpts) (*ProverSetInitializedIterator, error) {

	logs, sub, err := _ProverSet.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &ProverSetInitializedIterator{contract: _ProverSet.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_ProverSet *ProverSetFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *ProverSetInitialized) (event.Subscription, error) {

	logs, sub, err := _ProverSet.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ProverSetInitialized)
				if err := _ProverSet.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_ProverSet *ProverSetFilterer) ParseInitialized(log types.Log) (*ProverSetInitialized, error) {
	event := new(ProverSetInitialized)
	if err := _ProverSet.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ProverSetOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the ProverSet contract.
type ProverSetOwnershipTransferStartedIterator struct {
	Event *ProverSetOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *ProverSetOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ProverSetOwnershipTransferStarted)
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
		it.Event = new(ProverSetOwnershipTransferStarted)
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
func (it *ProverSetOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ProverSetOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ProverSetOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the ProverSet contract.
type ProverSetOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_ProverSet *ProverSetFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*ProverSetOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ProverSet.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &ProverSetOwnershipTransferStartedIterator{contract: _ProverSet.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_ProverSet *ProverSetFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *ProverSetOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ProverSet.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ProverSetOwnershipTransferStarted)
				if err := _ProverSet.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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
func (_ProverSet *ProverSetFilterer) ParseOwnershipTransferStarted(log types.Log) (*ProverSetOwnershipTransferStarted, error) {
	event := new(ProverSetOwnershipTransferStarted)
	if err := _ProverSet.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ProverSetOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the ProverSet contract.
type ProverSetOwnershipTransferredIterator struct {
	Event *ProverSetOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *ProverSetOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ProverSetOwnershipTransferred)
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
		it.Event = new(ProverSetOwnershipTransferred)
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
func (it *ProverSetOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ProverSetOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ProverSetOwnershipTransferred represents a OwnershipTransferred event raised by the ProverSet contract.
type ProverSetOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_ProverSet *ProverSetFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*ProverSetOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ProverSet.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &ProverSetOwnershipTransferredIterator{contract: _ProverSet.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_ProverSet *ProverSetFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *ProverSetOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ProverSet.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ProverSetOwnershipTransferred)
				if err := _ProverSet.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_ProverSet *ProverSetFilterer) ParseOwnershipTransferred(log types.Log) (*ProverSetOwnershipTransferred, error) {
	event := new(ProverSetOwnershipTransferred)
	if err := _ProverSet.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ProverSetPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the ProverSet contract.
type ProverSetPausedIterator struct {
	Event *ProverSetPaused // Event containing the contract specifics and raw log

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
func (it *ProverSetPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ProverSetPaused)
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
		it.Event = new(ProverSetPaused)
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
func (it *ProverSetPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ProverSetPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ProverSetPaused represents a Paused event raised by the ProverSet contract.
type ProverSetPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_ProverSet *ProverSetFilterer) FilterPaused(opts *bind.FilterOpts) (*ProverSetPausedIterator, error) {

	logs, sub, err := _ProverSet.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &ProverSetPausedIterator{contract: _ProverSet.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_ProverSet *ProverSetFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *ProverSetPaused) (event.Subscription, error) {

	logs, sub, err := _ProverSet.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ProverSetPaused)
				if err := _ProverSet.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_ProverSet *ProverSetFilterer) ParsePaused(log types.Log) (*ProverSetPaused, error) {
	event := new(ProverSetPaused)
	if err := _ProverSet.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ProverSetProverEnabledIterator is returned from FilterProverEnabled and is used to iterate over the raw logs and unpacked data for ProverEnabled events raised by the ProverSet contract.
type ProverSetProverEnabledIterator struct {
	Event *ProverSetProverEnabled // Event containing the contract specifics and raw log

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
func (it *ProverSetProverEnabledIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ProverSetProverEnabled)
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
		it.Event = new(ProverSetProverEnabled)
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
func (it *ProverSetProverEnabledIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ProverSetProverEnabledIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ProverSetProverEnabled represents a ProverEnabled event raised by the ProverSet contract.
type ProverSetProverEnabled struct {
	Prover  common.Address
	Enabled bool
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterProverEnabled is a free log retrieval operation binding the contract event 0x9f0c7298008bc8a24d3717fb47d215e91deb098d3486d802bf98cf6d177633a7.
//
// Solidity: event ProverEnabled(address indexed prover, bool indexed enabled)
func (_ProverSet *ProverSetFilterer) FilterProverEnabled(opts *bind.FilterOpts, prover []common.Address, enabled []bool) (*ProverSetProverEnabledIterator, error) {

	var proverRule []interface{}
	for _, proverItem := range prover {
		proverRule = append(proverRule, proverItem)
	}
	var enabledRule []interface{}
	for _, enabledItem := range enabled {
		enabledRule = append(enabledRule, enabledItem)
	}

	logs, sub, err := _ProverSet.contract.FilterLogs(opts, "ProverEnabled", proverRule, enabledRule)
	if err != nil {
		return nil, err
	}
	return &ProverSetProverEnabledIterator{contract: _ProverSet.contract, event: "ProverEnabled", logs: logs, sub: sub}, nil
}

// WatchProverEnabled is a free log subscription operation binding the contract event 0x9f0c7298008bc8a24d3717fb47d215e91deb098d3486d802bf98cf6d177633a7.
//
// Solidity: event ProverEnabled(address indexed prover, bool indexed enabled)
func (_ProverSet *ProverSetFilterer) WatchProverEnabled(opts *bind.WatchOpts, sink chan<- *ProverSetProverEnabled, prover []common.Address, enabled []bool) (event.Subscription, error) {

	var proverRule []interface{}
	for _, proverItem := range prover {
		proverRule = append(proverRule, proverItem)
	}
	var enabledRule []interface{}
	for _, enabledItem := range enabled {
		enabledRule = append(enabledRule, enabledItem)
	}

	logs, sub, err := _ProverSet.contract.WatchLogs(opts, "ProverEnabled", proverRule, enabledRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ProverSetProverEnabled)
				if err := _ProverSet.contract.UnpackLog(event, "ProverEnabled", log); err != nil {
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

// ParseProverEnabled is a log parse operation binding the contract event 0x9f0c7298008bc8a24d3717fb47d215e91deb098d3486d802bf98cf6d177633a7.
//
// Solidity: event ProverEnabled(address indexed prover, bool indexed enabled)
func (_ProverSet *ProverSetFilterer) ParseProverEnabled(log types.Log) (*ProverSetProverEnabled, error) {
	event := new(ProverSetProverEnabled)
	if err := _ProverSet.contract.UnpackLog(event, "ProverEnabled", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ProverSetUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the ProverSet contract.
type ProverSetUnpausedIterator struct {
	Event *ProverSetUnpaused // Event containing the contract specifics and raw log

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
func (it *ProverSetUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ProverSetUnpaused)
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
		it.Event = new(ProverSetUnpaused)
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
func (it *ProverSetUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ProverSetUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ProverSetUnpaused represents a Unpaused event raised by the ProverSet contract.
type ProverSetUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_ProverSet *ProverSetFilterer) FilterUnpaused(opts *bind.FilterOpts) (*ProverSetUnpausedIterator, error) {

	logs, sub, err := _ProverSet.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &ProverSetUnpausedIterator{contract: _ProverSet.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_ProverSet *ProverSetFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *ProverSetUnpaused) (event.Subscription, error) {

	logs, sub, err := _ProverSet.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ProverSetUnpaused)
				if err := _ProverSet.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_ProverSet *ProverSetFilterer) ParseUnpaused(log types.Log) (*ProverSetUnpaused, error) {
	event := new(ProverSetUnpaused)
	if err := _ProverSet.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ProverSetUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the ProverSet contract.
type ProverSetUpgradedIterator struct {
	Event *ProverSetUpgraded // Event containing the contract specifics and raw log

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
func (it *ProverSetUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ProverSetUpgraded)
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
		it.Event = new(ProverSetUpgraded)
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
func (it *ProverSetUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ProverSetUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ProverSetUpgraded represents a Upgraded event raised by the ProverSet contract.
type ProverSetUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_ProverSet *ProverSetFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*ProverSetUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _ProverSet.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &ProverSetUpgradedIterator{contract: _ProverSet.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_ProverSet *ProverSetFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *ProverSetUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _ProverSet.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ProverSetUpgraded)
				if err := _ProverSet.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_ProverSet *ProverSetFilterer) ParseUpgraded(log types.Log) (*ProverSetUpgraded, error) {
	event := new(ProverSetUpgraded)
	if err := _ProverSet.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
