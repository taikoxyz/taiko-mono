// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package guardianprover

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

// TaikoDataBlockMetadata is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataBlockMetadata struct {
	L1Hash       [32]byte
	Difficulty   [32]byte
	BlobHash     [32]byte
	ExtraData    [32]byte
	DepositsHash [32]byte
	Coinbase     common.Address
	Id           uint64
	GasLimit     uint32
	Timestamp    uint64
	L1Height     uint64
	MinTier      uint16
	BlobUsed     bool
}

// TaikoDataTierProof is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataTierProof struct {
	Tier uint16
	Data []byte
}

// TaikoDataTransition is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataTransition struct {
	ParentHash [32]byte
	BlockHash  [32]byte
	SignalRoot [32]byte
	Graffiti   [32]byte
}

// GuardianProverMetaData contains all meta data concerning the GuardianProver contract.
var GuardianProverMetaData = &bind.MetaData{
	ABI: "[{\"inputs\":[],\"name\":\"INVALID_GUARDIAN\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"INVALID_GUARDIAN_SET\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"INVALID_PAUSE_STATUS\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"INVALID_PROOF\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"PROVING_FAILED\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"REENTRANT_CALL\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"RESOLVER_DENIED\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"RESOLVER_INVALID_MANAGER\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"RESOLVER_UNEXPECTED_CHAINID\",\"type\":\"error\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"chainId\",\"type\":\"uint64\"},{\"internalType\":\"string\",\"name\":\"name\",\"type\":\"string\"}],\"name\":\"RESOLVER_ZERO_ADDR\",\"type\":\"error\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint64\",\"name\":\"blockId\",\"type\":\"uint64\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"approvalBits\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"bool\",\"name\":\"proofSubmitted\",\"type\":\"bool\"}],\"name\":\"Approved\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address[5]\",\"name\":\"\",\"type\":\"address[5]\"}],\"name\":\"GuardiansUpdated\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint8\",\"name\":\"version\",\"type\":\"uint8\"}],\"name\":\"Initialized\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"previousOwner\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"OwnershipTransferStarted\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"previousOwner\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"OwnershipTransferred\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"account\",\"type\":\"address\"}],\"name\":\"Paused\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"account\",\"type\":\"address\"}],\"name\":\"Unpaused\",\"type\":\"event\"},{\"inputs\":[],\"name\":\"NUM_GUARDIANS\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"REQUIRED_GUARDIANS\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"acceptOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"addressManager\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"name\":\"approvals\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"approvalBits\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"l1Hash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"difficulty\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"blobHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"extraData\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"depositsHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"coinbase\",\"type\":\"address\"},{\"internalType\":\"uint64\",\"name\":\"id\",\"type\":\"uint64\"},{\"internalType\":\"uint32\",\"name\":\"gasLimit\",\"type\":\"uint32\"},{\"internalType\":\"uint64\",\"name\":\"timestamp\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"l1Height\",\"type\":\"uint64\"},{\"internalType\":\"uint16\",\"name\":\"minTier\",\"type\":\"uint16\"},{\"internalType\":\"bool\",\"name\":\"blobUsed\",\"type\":\"bool\"}],\"internalType\":\"structTaikoData.BlockMetadata\",\"name\":\"meta\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"parentHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"blockHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"signalRoot\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"graffiti\",\"type\":\"bytes32\"}],\"internalType\":\"structTaikoData.Transition\",\"name\":\"tran\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"uint16\",\"name\":\"tier\",\"type\":\"uint16\"},{\"internalType\":\"bytes\",\"name\":\"data\",\"type\":\"bytes\"}],\"internalType\":\"structTaikoData.TierProof\",\"name\":\"proof\",\"type\":\"tuple\"}],\"name\":\"approve\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"guardian\",\"type\":\"address\"}],\"name\":\"guardianIds\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"id\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"name\":\"guardians\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_addressManager\",\"type\":\"address\"}],\"name\":\"init\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"owner\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"pause\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"paused\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"pendingOwner\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"renounceOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"chainId\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"name\",\"type\":\"bytes32\"},{\"internalType\":\"bool\",\"name\":\"allowZeroAddress\",\"type\":\"bool\"}],\"name\":\"resolve\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"addr\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"name\",\"type\":\"bytes32\"},{\"internalType\":\"bool\",\"name\":\"allowZeroAddress\",\"type\":\"bool\"}],\"name\":\"resolve\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"addr\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address[5]\",\"name\":\"_guardians\",\"type\":\"address[5]\"}],\"name\":\"setGuardians\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"transferOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"unpause\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"}]",
}

// GuardianProverABI is the input ABI used to generate the binding from.
// Deprecated: Use GuardianProverMetaData.ABI instead.
var GuardianProverABI = GuardianProverMetaData.ABI

// GuardianProver is an auto generated Go binding around an Ethereum contract.
type GuardianProver struct {
	GuardianProverCaller     // Read-only binding to the contract
	GuardianProverTransactor // Write-only binding to the contract
	GuardianProverFilterer   // Log filterer for contract events
}

// GuardianProverCaller is an auto generated read-only Go binding around an Ethereum contract.
type GuardianProverCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// GuardianProverTransactor is an auto generated write-only Go binding around an Ethereum contract.
type GuardianProverTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// GuardianProverFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type GuardianProverFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// GuardianProverSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type GuardianProverSession struct {
	Contract     *GuardianProver   // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// GuardianProverCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type GuardianProverCallerSession struct {
	Contract *GuardianProverCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts         // Call options to use throughout this session
}

// GuardianProverTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type GuardianProverTransactorSession struct {
	Contract     *GuardianProverTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts         // Transaction auth options to use throughout this session
}

// GuardianProverRaw is an auto generated low-level Go binding around an Ethereum contract.
type GuardianProverRaw struct {
	Contract *GuardianProver // Generic contract binding to access the raw methods on
}

// GuardianProverCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type GuardianProverCallerRaw struct {
	Contract *GuardianProverCaller // Generic read-only contract binding to access the raw methods on
}

// GuardianProverTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type GuardianProverTransactorRaw struct {
	Contract *GuardianProverTransactor // Generic write-only contract binding to access the raw methods on
}

// NewGuardianProver creates a new instance of GuardianProver, bound to a specific deployed contract.
func NewGuardianProver(address common.Address, backend bind.ContractBackend) (*GuardianProver, error) {
	contract, err := bindGuardianProver(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &GuardianProver{GuardianProverCaller: GuardianProverCaller{contract: contract}, GuardianProverTransactor: GuardianProverTransactor{contract: contract}, GuardianProverFilterer: GuardianProverFilterer{contract: contract}}, nil
}

// NewGuardianProverCaller creates a new read-only instance of GuardianProver, bound to a specific deployed contract.
func NewGuardianProverCaller(address common.Address, caller bind.ContractCaller) (*GuardianProverCaller, error) {
	contract, err := bindGuardianProver(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &GuardianProverCaller{contract: contract}, nil
}

// NewGuardianProverTransactor creates a new write-only instance of GuardianProver, bound to a specific deployed contract.
func NewGuardianProverTransactor(address common.Address, transactor bind.ContractTransactor) (*GuardianProverTransactor, error) {
	contract, err := bindGuardianProver(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &GuardianProverTransactor{contract: contract}, nil
}

// NewGuardianProverFilterer creates a new log filterer instance of GuardianProver, bound to a specific deployed contract.
func NewGuardianProverFilterer(address common.Address, filterer bind.ContractFilterer) (*GuardianProverFilterer, error) {
	contract, err := bindGuardianProver(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &GuardianProverFilterer{contract: contract}, nil
}

// bindGuardianProver binds a generic wrapper to an already deployed contract.
func bindGuardianProver(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := GuardianProverMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_GuardianProver *GuardianProverRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _GuardianProver.Contract.GuardianProverCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_GuardianProver *GuardianProverRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _GuardianProver.Contract.GuardianProverTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_GuardianProver *GuardianProverRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _GuardianProver.Contract.GuardianProverTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_GuardianProver *GuardianProverCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _GuardianProver.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_GuardianProver *GuardianProverTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _GuardianProver.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_GuardianProver *GuardianProverTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _GuardianProver.Contract.contract.Transact(opts, method, params...)
}

// NUMGUARDIANS is a free data retrieval call binding the contract method 0x55ff4c83.
//
// Solidity: function NUM_GUARDIANS() view returns(uint256)
func (_GuardianProver *GuardianProverCaller) NUMGUARDIANS(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _GuardianProver.contract.Call(opts, &out, "NUM_GUARDIANS")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// NUMGUARDIANS is a free data retrieval call binding the contract method 0x55ff4c83.
//
// Solidity: function NUM_GUARDIANS() view returns(uint256)
func (_GuardianProver *GuardianProverSession) NUMGUARDIANS() (*big.Int, error) {
	return _GuardianProver.Contract.NUMGUARDIANS(&_GuardianProver.CallOpts)
}

// NUMGUARDIANS is a free data retrieval call binding the contract method 0x55ff4c83.
//
// Solidity: function NUM_GUARDIANS() view returns(uint256)
func (_GuardianProver *GuardianProverCallerSession) NUMGUARDIANS() (*big.Int, error) {
	return _GuardianProver.Contract.NUMGUARDIANS(&_GuardianProver.CallOpts)
}

// REQUIREDGUARDIANS is a free data retrieval call binding the contract method 0x05520401.
//
// Solidity: function REQUIRED_GUARDIANS() view returns(uint256)
func (_GuardianProver *GuardianProverCaller) REQUIREDGUARDIANS(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _GuardianProver.contract.Call(opts, &out, "REQUIRED_GUARDIANS")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// REQUIREDGUARDIANS is a free data retrieval call binding the contract method 0x05520401.
//
// Solidity: function REQUIRED_GUARDIANS() view returns(uint256)
func (_GuardianProver *GuardianProverSession) REQUIREDGUARDIANS() (*big.Int, error) {
	return _GuardianProver.Contract.REQUIREDGUARDIANS(&_GuardianProver.CallOpts)
}

// REQUIREDGUARDIANS is a free data retrieval call binding the contract method 0x05520401.
//
// Solidity: function REQUIRED_GUARDIANS() view returns(uint256)
func (_GuardianProver *GuardianProverCallerSession) REQUIREDGUARDIANS() (*big.Int, error) {
	return _GuardianProver.Contract.REQUIREDGUARDIANS(&_GuardianProver.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_GuardianProver *GuardianProverCaller) AddressManager(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _GuardianProver.contract.Call(opts, &out, "addressManager")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_GuardianProver *GuardianProverSession) AddressManager() (common.Address, error) {
	return _GuardianProver.Contract.AddressManager(&_GuardianProver.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_GuardianProver *GuardianProverCallerSession) AddressManager() (common.Address, error) {
	return _GuardianProver.Contract.AddressManager(&_GuardianProver.CallOpts)
}

// Approvals is a free data retrieval call binding the contract method 0xbf7c2131.
//
// Solidity: function approvals(bytes32 ) view returns(uint256 approvalBits)
func (_GuardianProver *GuardianProverCaller) Approvals(opts *bind.CallOpts, arg0 [32]byte) (*big.Int, error) {
	var out []interface{}
	err := _GuardianProver.contract.Call(opts, &out, "approvals", arg0)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// Approvals is a free data retrieval call binding the contract method 0xbf7c2131.
//
// Solidity: function approvals(bytes32 ) view returns(uint256 approvalBits)
func (_GuardianProver *GuardianProverSession) Approvals(arg0 [32]byte) (*big.Int, error) {
	return _GuardianProver.Contract.Approvals(&_GuardianProver.CallOpts, arg0)
}

// Approvals is a free data retrieval call binding the contract method 0xbf7c2131.
//
// Solidity: function approvals(bytes32 ) view returns(uint256 approvalBits)
func (_GuardianProver *GuardianProverCallerSession) Approvals(arg0 [32]byte) (*big.Int, error) {
	return _GuardianProver.Contract.Approvals(&_GuardianProver.CallOpts, arg0)
}

// GuardianIds is a free data retrieval call binding the contract method 0xb6158373.
//
// Solidity: function guardianIds(address guardian) view returns(uint256 id)
func (_GuardianProver *GuardianProverCaller) GuardianIds(opts *bind.CallOpts, guardian common.Address) (*big.Int, error) {
	var out []interface{}
	err := _GuardianProver.contract.Call(opts, &out, "guardianIds", guardian)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GuardianIds is a free data retrieval call binding the contract method 0xb6158373.
//
// Solidity: function guardianIds(address guardian) view returns(uint256 id)
func (_GuardianProver *GuardianProverSession) GuardianIds(guardian common.Address) (*big.Int, error) {
	return _GuardianProver.Contract.GuardianIds(&_GuardianProver.CallOpts, guardian)
}

// GuardianIds is a free data retrieval call binding the contract method 0xb6158373.
//
// Solidity: function guardianIds(address guardian) view returns(uint256 id)
func (_GuardianProver *GuardianProverCallerSession) GuardianIds(guardian common.Address) (*big.Int, error) {
	return _GuardianProver.Contract.GuardianIds(&_GuardianProver.CallOpts, guardian)
}

// Guardians is a free data retrieval call binding the contract method 0xf560c734.
//
// Solidity: function guardians(uint256 ) view returns(address)
func (_GuardianProver *GuardianProverCaller) Guardians(opts *bind.CallOpts, arg0 *big.Int) (common.Address, error) {
	var out []interface{}
	err := _GuardianProver.contract.Call(opts, &out, "guardians", arg0)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Guardians is a free data retrieval call binding the contract method 0xf560c734.
//
// Solidity: function guardians(uint256 ) view returns(address)
func (_GuardianProver *GuardianProverSession) Guardians(arg0 *big.Int) (common.Address, error) {
	return _GuardianProver.Contract.Guardians(&_GuardianProver.CallOpts, arg0)
}

// Guardians is a free data retrieval call binding the contract method 0xf560c734.
//
// Solidity: function guardians(uint256 ) view returns(address)
func (_GuardianProver *GuardianProverCallerSession) Guardians(arg0 *big.Int) (common.Address, error) {
	return _GuardianProver.Contract.Guardians(&_GuardianProver.CallOpts, arg0)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_GuardianProver *GuardianProverCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _GuardianProver.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_GuardianProver *GuardianProverSession) Owner() (common.Address, error) {
	return _GuardianProver.Contract.Owner(&_GuardianProver.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_GuardianProver *GuardianProverCallerSession) Owner() (common.Address, error) {
	return _GuardianProver.Contract.Owner(&_GuardianProver.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_GuardianProver *GuardianProverCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _GuardianProver.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_GuardianProver *GuardianProverSession) Paused() (bool, error) {
	return _GuardianProver.Contract.Paused(&_GuardianProver.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_GuardianProver *GuardianProverCallerSession) Paused() (bool, error) {
	return _GuardianProver.Contract.Paused(&_GuardianProver.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_GuardianProver *GuardianProverCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _GuardianProver.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_GuardianProver *GuardianProverSession) PendingOwner() (common.Address, error) {
	return _GuardianProver.Contract.PendingOwner(&_GuardianProver.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_GuardianProver *GuardianProverCallerSession) PendingOwner() (common.Address, error) {
	return _GuardianProver.Contract.PendingOwner(&_GuardianProver.CallOpts)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 chainId, bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_GuardianProver *GuardianProverCaller) Resolve(opts *bind.CallOpts, chainId uint64, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _GuardianProver.contract.Call(opts, &out, "resolve", chainId, name, allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 chainId, bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_GuardianProver *GuardianProverSession) Resolve(chainId uint64, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _GuardianProver.Contract.Resolve(&_GuardianProver.CallOpts, chainId, name, allowZeroAddress)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 chainId, bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_GuardianProver *GuardianProverCallerSession) Resolve(chainId uint64, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _GuardianProver.Contract.Resolve(&_GuardianProver.CallOpts, chainId, name, allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_GuardianProver *GuardianProverCaller) Resolve0(opts *bind.CallOpts, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _GuardianProver.contract.Call(opts, &out, "resolve0", name, allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_GuardianProver *GuardianProverSession) Resolve0(name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _GuardianProver.Contract.Resolve0(&_GuardianProver.CallOpts, name, allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_GuardianProver *GuardianProverCallerSession) Resolve0(name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _GuardianProver.Contract.Resolve0(&_GuardianProver.CallOpts, name, allowZeroAddress)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_GuardianProver *GuardianProverTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _GuardianProver.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_GuardianProver *GuardianProverSession) AcceptOwnership() (*types.Transaction, error) {
	return _GuardianProver.Contract.AcceptOwnership(&_GuardianProver.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_GuardianProver *GuardianProverTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _GuardianProver.Contract.AcceptOwnership(&_GuardianProver.TransactOpts)
}

// Approve is a paid mutator transaction binding the contract method 0x0bba05b8.
//
// Solidity: function approve((bytes32,bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint16,bool) meta, (bytes32,bytes32,bytes32,bytes32) tran, (uint16,bytes) proof) returns()
func (_GuardianProver *GuardianProverTransactor) Approve(opts *bind.TransactOpts, meta TaikoDataBlockMetadata, tran TaikoDataTransition, proof TaikoDataTierProof) (*types.Transaction, error) {
	return _GuardianProver.contract.Transact(opts, "approve", meta, tran, proof)
}

// Approve is a paid mutator transaction binding the contract method 0x0bba05b8.
//
// Solidity: function approve((bytes32,bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint16,bool) meta, (bytes32,bytes32,bytes32,bytes32) tran, (uint16,bytes) proof) returns()
func (_GuardianProver *GuardianProverSession) Approve(meta TaikoDataBlockMetadata, tran TaikoDataTransition, proof TaikoDataTierProof) (*types.Transaction, error) {
	return _GuardianProver.Contract.Approve(&_GuardianProver.TransactOpts, meta, tran, proof)
}

// Approve is a paid mutator transaction binding the contract method 0x0bba05b8.
//
// Solidity: function approve((bytes32,bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint16,bool) meta, (bytes32,bytes32,bytes32,bytes32) tran, (uint16,bytes) proof) returns()
func (_GuardianProver *GuardianProverTransactorSession) Approve(meta TaikoDataBlockMetadata, tran TaikoDataTransition, proof TaikoDataTierProof) (*types.Transaction, error) {
	return _GuardianProver.Contract.Approve(&_GuardianProver.TransactOpts, meta, tran, proof)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _addressManager) returns()
func (_GuardianProver *GuardianProverTransactor) Init(opts *bind.TransactOpts, _addressManager common.Address) (*types.Transaction, error) {
	return _GuardianProver.contract.Transact(opts, "init", _addressManager)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _addressManager) returns()
func (_GuardianProver *GuardianProverSession) Init(_addressManager common.Address) (*types.Transaction, error) {
	return _GuardianProver.Contract.Init(&_GuardianProver.TransactOpts, _addressManager)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _addressManager) returns()
func (_GuardianProver *GuardianProverTransactorSession) Init(_addressManager common.Address) (*types.Transaction, error) {
	return _GuardianProver.Contract.Init(&_GuardianProver.TransactOpts, _addressManager)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_GuardianProver *GuardianProverTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _GuardianProver.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_GuardianProver *GuardianProverSession) Pause() (*types.Transaction, error) {
	return _GuardianProver.Contract.Pause(&_GuardianProver.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_GuardianProver *GuardianProverTransactorSession) Pause() (*types.Transaction, error) {
	return _GuardianProver.Contract.Pause(&_GuardianProver.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_GuardianProver *GuardianProverTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _GuardianProver.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_GuardianProver *GuardianProverSession) RenounceOwnership() (*types.Transaction, error) {
	return _GuardianProver.Contract.RenounceOwnership(&_GuardianProver.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_GuardianProver *GuardianProverTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _GuardianProver.Contract.RenounceOwnership(&_GuardianProver.TransactOpts)
}

// SetGuardians is a paid mutator transaction binding the contract method 0x5cb1eb25.
//
// Solidity: function setGuardians(address[5] _guardians) returns()
func (_GuardianProver *GuardianProverTransactor) SetGuardians(opts *bind.TransactOpts, _guardians [5]common.Address) (*types.Transaction, error) {
	return _GuardianProver.contract.Transact(opts, "setGuardians", _guardians)
}

// SetGuardians is a paid mutator transaction binding the contract method 0x5cb1eb25.
//
// Solidity: function setGuardians(address[5] _guardians) returns()
func (_GuardianProver *GuardianProverSession) SetGuardians(_guardians [5]common.Address) (*types.Transaction, error) {
	return _GuardianProver.Contract.SetGuardians(&_GuardianProver.TransactOpts, _guardians)
}

// SetGuardians is a paid mutator transaction binding the contract method 0x5cb1eb25.
//
// Solidity: function setGuardians(address[5] _guardians) returns()
func (_GuardianProver *GuardianProverTransactorSession) SetGuardians(_guardians [5]common.Address) (*types.Transaction, error) {
	return _GuardianProver.Contract.SetGuardians(&_GuardianProver.TransactOpts, _guardians)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_GuardianProver *GuardianProverTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _GuardianProver.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_GuardianProver *GuardianProverSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _GuardianProver.Contract.TransferOwnership(&_GuardianProver.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_GuardianProver *GuardianProverTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _GuardianProver.Contract.TransferOwnership(&_GuardianProver.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_GuardianProver *GuardianProverTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _GuardianProver.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_GuardianProver *GuardianProverSession) Unpause() (*types.Transaction, error) {
	return _GuardianProver.Contract.Unpause(&_GuardianProver.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_GuardianProver *GuardianProverTransactorSession) Unpause() (*types.Transaction, error) {
	return _GuardianProver.Contract.Unpause(&_GuardianProver.TransactOpts)
}

// GuardianProverApprovedIterator is returned from FilterApproved and is used to iterate over the raw logs and unpacked data for Approved events raised by the GuardianProver contract.
type GuardianProverApprovedIterator struct {
	Event *GuardianProverApproved // Event containing the contract specifics and raw log

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
func (it *GuardianProverApprovedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(GuardianProverApproved)
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
		it.Event = new(GuardianProverApproved)
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
func (it *GuardianProverApprovedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *GuardianProverApprovedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// GuardianProverApproved represents a Approved event raised by the GuardianProver contract.
type GuardianProverApproved struct {
	BlockId        uint64
	ApprovalBits   *big.Int
	ProofSubmitted bool
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterApproved is a free log retrieval operation binding the contract event 0x491ef33230925e6876158c5f7551d4f58c2c7d04e41546850b1009678c20816a.
//
// Solidity: event Approved(uint64 indexed blockId, uint256 approvalBits, bool proofSubmitted)
func (_GuardianProver *GuardianProverFilterer) FilterApproved(opts *bind.FilterOpts, blockId []uint64) (*GuardianProverApprovedIterator, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _GuardianProver.contract.FilterLogs(opts, "Approved", blockIdRule)
	if err != nil {
		return nil, err
	}
	return &GuardianProverApprovedIterator{contract: _GuardianProver.contract, event: "Approved", logs: logs, sub: sub}, nil
}

// WatchApproved is a free log subscription operation binding the contract event 0x491ef33230925e6876158c5f7551d4f58c2c7d04e41546850b1009678c20816a.
//
// Solidity: event Approved(uint64 indexed blockId, uint256 approvalBits, bool proofSubmitted)
func (_GuardianProver *GuardianProverFilterer) WatchApproved(opts *bind.WatchOpts, sink chan<- *GuardianProverApproved, blockId []uint64) (event.Subscription, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _GuardianProver.contract.WatchLogs(opts, "Approved", blockIdRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(GuardianProverApproved)
				if err := _GuardianProver.contract.UnpackLog(event, "Approved", log); err != nil {
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

// ParseApproved is a log parse operation binding the contract event 0x491ef33230925e6876158c5f7551d4f58c2c7d04e41546850b1009678c20816a.
//
// Solidity: event Approved(uint64 indexed blockId, uint256 approvalBits, bool proofSubmitted)
func (_GuardianProver *GuardianProverFilterer) ParseApproved(log types.Log) (*GuardianProverApproved, error) {
	event := new(GuardianProverApproved)
	if err := _GuardianProver.contract.UnpackLog(event, "Approved", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// GuardianProverGuardiansUpdatedIterator is returned from FilterGuardiansUpdated and is used to iterate over the raw logs and unpacked data for GuardiansUpdated events raised by the GuardianProver contract.
type GuardianProverGuardiansUpdatedIterator struct {
	Event *GuardianProverGuardiansUpdated // Event containing the contract specifics and raw log

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
func (it *GuardianProverGuardiansUpdatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(GuardianProverGuardiansUpdated)
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
		it.Event = new(GuardianProverGuardiansUpdated)
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
func (it *GuardianProverGuardiansUpdatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *GuardianProverGuardiansUpdatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// GuardianProverGuardiansUpdated represents a GuardiansUpdated event raised by the GuardianProver contract.
type GuardianProverGuardiansUpdated struct {
	Arg0 [5]common.Address
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterGuardiansUpdated is a free log retrieval operation binding the contract event 0x9ce971150384a46b1b1f7cfdf16a84a1c346add127bf86ce2787fb41872b6fc9.
//
// Solidity: event GuardiansUpdated(address[5] arg0)
func (_GuardianProver *GuardianProverFilterer) FilterGuardiansUpdated(opts *bind.FilterOpts) (*GuardianProverGuardiansUpdatedIterator, error) {

	logs, sub, err := _GuardianProver.contract.FilterLogs(opts, "GuardiansUpdated")
	if err != nil {
		return nil, err
	}
	return &GuardianProverGuardiansUpdatedIterator{contract: _GuardianProver.contract, event: "GuardiansUpdated", logs: logs, sub: sub}, nil
}

// WatchGuardiansUpdated is a free log subscription operation binding the contract event 0x9ce971150384a46b1b1f7cfdf16a84a1c346add127bf86ce2787fb41872b6fc9.
//
// Solidity: event GuardiansUpdated(address[5] arg0)
func (_GuardianProver *GuardianProverFilterer) WatchGuardiansUpdated(opts *bind.WatchOpts, sink chan<- *GuardianProverGuardiansUpdated) (event.Subscription, error) {

	logs, sub, err := _GuardianProver.contract.WatchLogs(opts, "GuardiansUpdated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(GuardianProverGuardiansUpdated)
				if err := _GuardianProver.contract.UnpackLog(event, "GuardiansUpdated", log); err != nil {
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

// ParseGuardiansUpdated is a log parse operation binding the contract event 0x9ce971150384a46b1b1f7cfdf16a84a1c346add127bf86ce2787fb41872b6fc9.
//
// Solidity: event GuardiansUpdated(address[5] arg0)
func (_GuardianProver *GuardianProverFilterer) ParseGuardiansUpdated(log types.Log) (*GuardianProverGuardiansUpdated, error) {
	event := new(GuardianProverGuardiansUpdated)
	if err := _GuardianProver.contract.UnpackLog(event, "GuardiansUpdated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// GuardianProverInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the GuardianProver contract.
type GuardianProverInitializedIterator struct {
	Event *GuardianProverInitialized // Event containing the contract specifics and raw log

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
func (it *GuardianProverInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(GuardianProverInitialized)
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
		it.Event = new(GuardianProverInitialized)
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
func (it *GuardianProverInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *GuardianProverInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// GuardianProverInitialized represents a Initialized event raised by the GuardianProver contract.
type GuardianProverInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_GuardianProver *GuardianProverFilterer) FilterInitialized(opts *bind.FilterOpts) (*GuardianProverInitializedIterator, error) {

	logs, sub, err := _GuardianProver.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &GuardianProverInitializedIterator{contract: _GuardianProver.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_GuardianProver *GuardianProverFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *GuardianProverInitialized) (event.Subscription, error) {

	logs, sub, err := _GuardianProver.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(GuardianProverInitialized)
				if err := _GuardianProver.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_GuardianProver *GuardianProverFilterer) ParseInitialized(log types.Log) (*GuardianProverInitialized, error) {
	event := new(GuardianProverInitialized)
	if err := _GuardianProver.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// GuardianProverOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the GuardianProver contract.
type GuardianProverOwnershipTransferStartedIterator struct {
	Event *GuardianProverOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *GuardianProverOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(GuardianProverOwnershipTransferStarted)
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
		it.Event = new(GuardianProverOwnershipTransferStarted)
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
func (it *GuardianProverOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *GuardianProverOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// GuardianProverOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the GuardianProver contract.
type GuardianProverOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_GuardianProver *GuardianProverFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*GuardianProverOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _GuardianProver.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &GuardianProverOwnershipTransferStartedIterator{contract: _GuardianProver.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_GuardianProver *GuardianProverFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *GuardianProverOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _GuardianProver.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(GuardianProverOwnershipTransferStarted)
				if err := _GuardianProver.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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
func (_GuardianProver *GuardianProverFilterer) ParseOwnershipTransferStarted(log types.Log) (*GuardianProverOwnershipTransferStarted, error) {
	event := new(GuardianProverOwnershipTransferStarted)
	if err := _GuardianProver.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// GuardianProverOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the GuardianProver contract.
type GuardianProverOwnershipTransferredIterator struct {
	Event *GuardianProverOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *GuardianProverOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(GuardianProverOwnershipTransferred)
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
		it.Event = new(GuardianProverOwnershipTransferred)
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
func (it *GuardianProverOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *GuardianProverOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// GuardianProverOwnershipTransferred represents a OwnershipTransferred event raised by the GuardianProver contract.
type GuardianProverOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_GuardianProver *GuardianProverFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*GuardianProverOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _GuardianProver.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &GuardianProverOwnershipTransferredIterator{contract: _GuardianProver.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_GuardianProver *GuardianProverFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *GuardianProverOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _GuardianProver.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(GuardianProverOwnershipTransferred)
				if err := _GuardianProver.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_GuardianProver *GuardianProverFilterer) ParseOwnershipTransferred(log types.Log) (*GuardianProverOwnershipTransferred, error) {
	event := new(GuardianProverOwnershipTransferred)
	if err := _GuardianProver.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// GuardianProverPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the GuardianProver contract.
type GuardianProverPausedIterator struct {
	Event *GuardianProverPaused // Event containing the contract specifics and raw log

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
func (it *GuardianProverPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(GuardianProverPaused)
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
		it.Event = new(GuardianProverPaused)
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
func (it *GuardianProverPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *GuardianProverPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// GuardianProverPaused represents a Paused event raised by the GuardianProver contract.
type GuardianProverPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_GuardianProver *GuardianProverFilterer) FilterPaused(opts *bind.FilterOpts) (*GuardianProverPausedIterator, error) {

	logs, sub, err := _GuardianProver.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &GuardianProverPausedIterator{contract: _GuardianProver.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_GuardianProver *GuardianProverFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *GuardianProverPaused) (event.Subscription, error) {

	logs, sub, err := _GuardianProver.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(GuardianProverPaused)
				if err := _GuardianProver.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_GuardianProver *GuardianProverFilterer) ParsePaused(log types.Log) (*GuardianProverPaused, error) {
	event := new(GuardianProverPaused)
	if err := _GuardianProver.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// GuardianProverUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the GuardianProver contract.
type GuardianProverUnpausedIterator struct {
	Event *GuardianProverUnpaused // Event containing the contract specifics and raw log

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
func (it *GuardianProverUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(GuardianProverUnpaused)
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
		it.Event = new(GuardianProverUnpaused)
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
func (it *GuardianProverUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *GuardianProverUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// GuardianProverUnpaused represents a Unpaused event raised by the GuardianProver contract.
type GuardianProverUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_GuardianProver *GuardianProverFilterer) FilterUnpaused(opts *bind.FilterOpts) (*GuardianProverUnpausedIterator, error) {

	logs, sub, err := _GuardianProver.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &GuardianProverUnpausedIterator{contract: _GuardianProver.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_GuardianProver *GuardianProverFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *GuardianProverUnpaused) (event.Subscription, error) {

	logs, sub, err := _GuardianProver.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(GuardianProverUnpaused)
				if err := _GuardianProver.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_GuardianProver *GuardianProverFilterer) ParseUnpaused(log types.Log) (*GuardianProverUnpaused, error) {
	event := new(GuardianProverUnpaused)
	if err := _GuardianProver.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
