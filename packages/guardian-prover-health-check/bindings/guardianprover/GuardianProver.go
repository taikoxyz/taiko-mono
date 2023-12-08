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
	L1Hash           [32]byte
	Difficulty       [32]byte
	BlobHash         [32]byte
	ExtraData        [32]byte
	DepositsHash     [32]byte
	Coinbase         common.Address
	Id               uint64
	GasLimit         uint32
	Timestamp        uint64
	L1Height         uint64
	TxListByteOffset *big.Int
	TxListByteSize   *big.Int
	MinTier          uint16
	BlobUsed         bool
	ParentMetaHash   [32]byte
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
	ABI: "[{\"inputs\":[],\"name\":\"INVALID_GUARDIAN\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"INVALID_GUARDIAN_SET\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"INVALID_MIN_GUARDIANS\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"INVALID_PAUSE_STATUS\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"INVALID_PROOF\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"PROVING_FAILED\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"REENTRANT_CALL\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"RESOLVER_DENIED\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"RESOLVER_INVALID_MANAGER\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"RESOLVER_UNEXPECTED_CHAINID\",\"type\":\"error\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"chainId\",\"type\":\"uint64\"},{\"internalType\":\"string\",\"name\":\"name\",\"type\":\"string\"}],\"name\":\"RESOLVER_ZERO_ADDR\",\"type\":\"error\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"previousAdmin\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"newAdmin\",\"type\":\"address\"}],\"name\":\"AdminChanged\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"operationId\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"approvalBits\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"bool\",\"name\":\"proofSubmitted\",\"type\":\"bool\"}],\"name\":\"Approved\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"beacon\",\"type\":\"address\"}],\"name\":\"BeaconUpgraded\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint32\",\"name\":\"version\",\"type\":\"uint32\"},{\"indexed\":false,\"internalType\":\"address[]\",\"name\":\"guardians\",\"type\":\"address[]\"}],\"name\":\"GuardiansUpdated\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint8\",\"name\":\"version\",\"type\":\"uint8\"}],\"name\":\"Initialized\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"previousOwner\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"OwnershipTransferred\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"account\",\"type\":\"address\"}],\"name\":\"Paused\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"account\",\"type\":\"address\"}],\"name\":\"Unpaused\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"implementation\",\"type\":\"address\"}],\"name\":\"Upgraded\",\"type\":\"event\"},{\"inputs\":[],\"name\":\"MIN_NUM_GUARDIANS\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"addressManager\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"l1Hash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"difficulty\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"blobHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"extraData\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"depositsHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"coinbase\",\"type\":\"address\"},{\"internalType\":\"uint64\",\"name\":\"id\",\"type\":\"uint64\"},{\"internalType\":\"uint32\",\"name\":\"gasLimit\",\"type\":\"uint32\"},{\"internalType\":\"uint64\",\"name\":\"timestamp\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"l1Height\",\"type\":\"uint64\"},{\"internalType\":\"uint24\",\"name\":\"txListByteOffset\",\"type\":\"uint24\"},{\"internalType\":\"uint24\",\"name\":\"txListByteSize\",\"type\":\"uint24\"},{\"internalType\":\"uint16\",\"name\":\"minTier\",\"type\":\"uint16\"},{\"internalType\":\"bool\",\"name\":\"blobUsed\",\"type\":\"bool\"},{\"internalType\":\"bytes32\",\"name\":\"parentMetaHash\",\"type\":\"bytes32\"}],\"internalType\":\"structTaikoData.BlockMetadata\",\"name\":\"meta\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"parentHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"blockHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"signalRoot\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"graffiti\",\"type\":\"bytes32\"}],\"internalType\":\"structTaikoData.Transition\",\"name\":\"tran\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"uint16\",\"name\":\"tier\",\"type\":\"uint16\"},{\"internalType\":\"bytes\",\"name\":\"data\",\"type\":\"bytes\"}],\"internalType\":\"structTaikoData.TierProof\",\"name\":\"proof\",\"type\":\"tuple\"}],\"name\":\"approve\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"approved\",\"type\":\"bool\"}],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"guardian\",\"type\":\"address\"}],\"name\":\"guardianIds\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"id\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"name\":\"guardians\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_addressManager\",\"type\":\"address\"}],\"name\":\"init\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"hash\",\"type\":\"bytes32\"}],\"name\":\"isApproved\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"minGuardians\",\"outputs\":[{\"internalType\":\"uint32\",\"name\":\"\",\"type\":\"uint32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"numGuardians\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"owner\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"pause\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"paused\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"proxiableUUID\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"renounceOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"chainId\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"name\",\"type\":\"bytes32\"},{\"internalType\":\"bool\",\"name\":\"allowZeroAddress\",\"type\":\"bool\"}],\"name\":\"resolve\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"addr\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"name\",\"type\":\"bytes32\"},{\"internalType\":\"bool\",\"name\":\"allowZeroAddress\",\"type\":\"bool\"}],\"name\":\"resolve\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"addr\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address[]\",\"name\":\"_guardians\",\"type\":\"address[]\"},{\"internalType\":\"uint8\",\"name\":\"_minGuardians\",\"type\":\"uint8\"}],\"name\":\"setGuardians\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"transferOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"unpause\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"newImplementation\",\"type\":\"address\"}],\"name\":\"upgradeTo\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"newImplementation\",\"type\":\"address\"},{\"internalType\":\"bytes\",\"name\":\"data\",\"type\":\"bytes\"}],\"name\":\"upgradeToAndCall\",\"outputs\":[],\"stateMutability\":\"payable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"version\",\"outputs\":[{\"internalType\":\"uint32\",\"name\":\"\",\"type\":\"uint32\"}],\"stateMutability\":\"view\",\"type\":\"function\"}]",
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

// MINNUMGUARDIANS is a free data retrieval call binding the contract method 0x353ce811.
//
// Solidity: function MIN_NUM_GUARDIANS() view returns(uint256)
func (_GuardianProver *GuardianProverCaller) MINNUMGUARDIANS(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _GuardianProver.contract.Call(opts, &out, "MIN_NUM_GUARDIANS")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// MINNUMGUARDIANS is a free data retrieval call binding the contract method 0x353ce811.
//
// Solidity: function MIN_NUM_GUARDIANS() view returns(uint256)
func (_GuardianProver *GuardianProverSession) MINNUMGUARDIANS() (*big.Int, error) {
	return _GuardianProver.Contract.MINNUMGUARDIANS(&_GuardianProver.CallOpts)
}

// MINNUMGUARDIANS is a free data retrieval call binding the contract method 0x353ce811.
//
// Solidity: function MIN_NUM_GUARDIANS() view returns(uint256)
func (_GuardianProver *GuardianProverCallerSession) MINNUMGUARDIANS() (*big.Int, error) {
	return _GuardianProver.Contract.MINNUMGUARDIANS(&_GuardianProver.CallOpts)
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

// IsApproved is a free data retrieval call binding the contract method 0x48aefc32.
//
// Solidity: function isApproved(bytes32 hash) view returns(bool)
func (_GuardianProver *GuardianProverCaller) IsApproved(opts *bind.CallOpts, hash [32]byte) (bool, error) {
	var out []interface{}
	err := _GuardianProver.contract.Call(opts, &out, "isApproved", hash)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsApproved is a free data retrieval call binding the contract method 0x48aefc32.
//
// Solidity: function isApproved(bytes32 hash) view returns(bool)
func (_GuardianProver *GuardianProverSession) IsApproved(hash [32]byte) (bool, error) {
	return _GuardianProver.Contract.IsApproved(&_GuardianProver.CallOpts, hash)
}

// IsApproved is a free data retrieval call binding the contract method 0x48aefc32.
//
// Solidity: function isApproved(bytes32 hash) view returns(bool)
func (_GuardianProver *GuardianProverCallerSession) IsApproved(hash [32]byte) (bool, error) {
	return _GuardianProver.Contract.IsApproved(&_GuardianProver.CallOpts, hash)
}

// MinGuardians is a free data retrieval call binding the contract method 0x2d6f5ca7.
//
// Solidity: function minGuardians() view returns(uint32)
func (_GuardianProver *GuardianProverCaller) MinGuardians(opts *bind.CallOpts) (uint32, error) {
	var out []interface{}
	err := _GuardianProver.contract.Call(opts, &out, "minGuardians")

	if err != nil {
		return *new(uint32), err
	}

	out0 := *abi.ConvertType(out[0], new(uint32)).(*uint32)

	return out0, err

}

// MinGuardians is a free data retrieval call binding the contract method 0x2d6f5ca7.
//
// Solidity: function minGuardians() view returns(uint32)
func (_GuardianProver *GuardianProverSession) MinGuardians() (uint32, error) {
	return _GuardianProver.Contract.MinGuardians(&_GuardianProver.CallOpts)
}

// MinGuardians is a free data retrieval call binding the contract method 0x2d6f5ca7.
//
// Solidity: function minGuardians() view returns(uint32)
func (_GuardianProver *GuardianProverCallerSession) MinGuardians() (uint32, error) {
	return _GuardianProver.Contract.MinGuardians(&_GuardianProver.CallOpts)
}

// NumGuardians is a free data retrieval call binding the contract method 0xd13cbca3.
//
// Solidity: function numGuardians() view returns(uint256)
func (_GuardianProver *GuardianProverCaller) NumGuardians(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _GuardianProver.contract.Call(opts, &out, "numGuardians")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// NumGuardians is a free data retrieval call binding the contract method 0xd13cbca3.
//
// Solidity: function numGuardians() view returns(uint256)
func (_GuardianProver *GuardianProverSession) NumGuardians() (*big.Int, error) {
	return _GuardianProver.Contract.NumGuardians(&_GuardianProver.CallOpts)
}

// NumGuardians is a free data retrieval call binding the contract method 0xd13cbca3.
//
// Solidity: function numGuardians() view returns(uint256)
func (_GuardianProver *GuardianProverCallerSession) NumGuardians() (*big.Int, error) {
	return _GuardianProver.Contract.NumGuardians(&_GuardianProver.CallOpts)
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

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_GuardianProver *GuardianProverCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _GuardianProver.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_GuardianProver *GuardianProverSession) ProxiableUUID() ([32]byte, error) {
	return _GuardianProver.Contract.ProxiableUUID(&_GuardianProver.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_GuardianProver *GuardianProverCallerSession) ProxiableUUID() ([32]byte, error) {
	return _GuardianProver.Contract.ProxiableUUID(&_GuardianProver.CallOpts)
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

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() view returns(uint32)
func (_GuardianProver *GuardianProverCaller) Version(opts *bind.CallOpts) (uint32, error) {
	var out []interface{}
	err := _GuardianProver.contract.Call(opts, &out, "version")

	if err != nil {
		return *new(uint32), err
	}

	out0 := *abi.ConvertType(out[0], new(uint32)).(*uint32)

	return out0, err

}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() view returns(uint32)
func (_GuardianProver *GuardianProverSession) Version() (uint32, error) {
	return _GuardianProver.Contract.Version(&_GuardianProver.CallOpts)
}

// Version is a free data retrieval call binding the contract method 0x54fd4d50.
//
// Solidity: function version() view returns(uint32)
func (_GuardianProver *GuardianProverCallerSession) Version() (uint32, error) {
	return _GuardianProver.Contract.Version(&_GuardianProver.CallOpts)
}

// Approve is a paid mutator transaction binding the contract method 0x492d2474.
//
// Solidity: function approve((bytes32,bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint24,uint24,uint16,bool,bytes32) meta, (bytes32,bytes32,bytes32,bytes32) tran, (uint16,bytes) proof) returns(bool approved)
func (_GuardianProver *GuardianProverTransactor) Approve(opts *bind.TransactOpts, meta TaikoDataBlockMetadata, tran TaikoDataTransition, proof TaikoDataTierProof) (*types.Transaction, error) {
	return _GuardianProver.contract.Transact(opts, "approve", meta, tran, proof)
}

// Approve is a paid mutator transaction binding the contract method 0x492d2474.
//
// Solidity: function approve((bytes32,bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint24,uint24,uint16,bool,bytes32) meta, (bytes32,bytes32,bytes32,bytes32) tran, (uint16,bytes) proof) returns(bool approved)
func (_GuardianProver *GuardianProverSession) Approve(meta TaikoDataBlockMetadata, tran TaikoDataTransition, proof TaikoDataTierProof) (*types.Transaction, error) {
	return _GuardianProver.Contract.Approve(&_GuardianProver.TransactOpts, meta, tran, proof)
}

// Approve is a paid mutator transaction binding the contract method 0x492d2474.
//
// Solidity: function approve((bytes32,bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint24,uint24,uint16,bool,bytes32) meta, (bytes32,bytes32,bytes32,bytes32) tran, (uint16,bytes) proof) returns(bool approved)
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

// SetGuardians is a paid mutator transaction binding the contract method 0xe94e9e99.
//
// Solidity: function setGuardians(address[] _guardians, uint8 _minGuardians) returns()
func (_GuardianProver *GuardianProverTransactor) SetGuardians(opts *bind.TransactOpts, _guardians []common.Address, _minGuardians uint8) (*types.Transaction, error) {
	return _GuardianProver.contract.Transact(opts, "setGuardians", _guardians, _minGuardians)
}

// SetGuardians is a paid mutator transaction binding the contract method 0xe94e9e99.
//
// Solidity: function setGuardians(address[] _guardians, uint8 _minGuardians) returns()
func (_GuardianProver *GuardianProverSession) SetGuardians(_guardians []common.Address, _minGuardians uint8) (*types.Transaction, error) {
	return _GuardianProver.Contract.SetGuardians(&_GuardianProver.TransactOpts, _guardians, _minGuardians)
}

// SetGuardians is a paid mutator transaction binding the contract method 0xe94e9e99.
//
// Solidity: function setGuardians(address[] _guardians, uint8 _minGuardians) returns()
func (_GuardianProver *GuardianProverTransactorSession) SetGuardians(_guardians []common.Address, _minGuardians uint8) (*types.Transaction, error) {
	return _GuardianProver.Contract.SetGuardians(&_GuardianProver.TransactOpts, _guardians, _minGuardians)
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

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_GuardianProver *GuardianProverTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _GuardianProver.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_GuardianProver *GuardianProverSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _GuardianProver.Contract.UpgradeTo(&_GuardianProver.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_GuardianProver *GuardianProverTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _GuardianProver.Contract.UpgradeTo(&_GuardianProver.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_GuardianProver *GuardianProverTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _GuardianProver.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_GuardianProver *GuardianProverSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _GuardianProver.Contract.UpgradeToAndCall(&_GuardianProver.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_GuardianProver *GuardianProverTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _GuardianProver.Contract.UpgradeToAndCall(&_GuardianProver.TransactOpts, newImplementation, data)
}

// GuardianProverAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the GuardianProver contract.
type GuardianProverAdminChangedIterator struct {
	Event *GuardianProverAdminChanged // Event containing the contract specifics and raw log

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
func (it *GuardianProverAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(GuardianProverAdminChanged)
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
		it.Event = new(GuardianProverAdminChanged)
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
func (it *GuardianProverAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *GuardianProverAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// GuardianProverAdminChanged represents a AdminChanged event raised by the GuardianProver contract.
type GuardianProverAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_GuardianProver *GuardianProverFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*GuardianProverAdminChangedIterator, error) {

	logs, sub, err := _GuardianProver.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &GuardianProverAdminChangedIterator{contract: _GuardianProver.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_GuardianProver *GuardianProverFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *GuardianProverAdminChanged) (event.Subscription, error) {

	logs, sub, err := _GuardianProver.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(GuardianProverAdminChanged)
				if err := _GuardianProver.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_GuardianProver *GuardianProverFilterer) ParseAdminChanged(log types.Log) (*GuardianProverAdminChanged, error) {
	event := new(GuardianProverAdminChanged)
	if err := _GuardianProver.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
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
	OperationId    *big.Int
	ApprovalBits   *big.Int
	ProofSubmitted bool
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterApproved is a free log retrieval operation binding the contract event 0x344afde5e92a836ece804d851bb090d420129616171e9911ade0a3f4d785e311.
//
// Solidity: event Approved(uint256 indexed operationId, uint256 approvalBits, bool proofSubmitted)
func (_GuardianProver *GuardianProverFilterer) FilterApproved(opts *bind.FilterOpts, operationId []*big.Int) (*GuardianProverApprovedIterator, error) {

	var operationIdRule []interface{}
	for _, operationIdItem := range operationId {
		operationIdRule = append(operationIdRule, operationIdItem)
	}

	logs, sub, err := _GuardianProver.contract.FilterLogs(opts, "Approved", operationIdRule)
	if err != nil {
		return nil, err
	}
	return &GuardianProverApprovedIterator{contract: _GuardianProver.contract, event: "Approved", logs: logs, sub: sub}, nil
}

// WatchApproved is a free log subscription operation binding the contract event 0x344afde5e92a836ece804d851bb090d420129616171e9911ade0a3f4d785e311.
//
// Solidity: event Approved(uint256 indexed operationId, uint256 approvalBits, bool proofSubmitted)
func (_GuardianProver *GuardianProverFilterer) WatchApproved(opts *bind.WatchOpts, sink chan<- *GuardianProverApproved, operationId []*big.Int) (event.Subscription, error) {

	var operationIdRule []interface{}
	for _, operationIdItem := range operationId {
		operationIdRule = append(operationIdRule, operationIdItem)
	}

	logs, sub, err := _GuardianProver.contract.WatchLogs(opts, "Approved", operationIdRule)
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

// ParseApproved is a log parse operation binding the contract event 0x344afde5e92a836ece804d851bb090d420129616171e9911ade0a3f4d785e311.
//
// Solidity: event Approved(uint256 indexed operationId, uint256 approvalBits, bool proofSubmitted)
func (_GuardianProver *GuardianProverFilterer) ParseApproved(log types.Log) (*GuardianProverApproved, error) {
	event := new(GuardianProverApproved)
	if err := _GuardianProver.contract.UnpackLog(event, "Approved", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// GuardianProverBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the GuardianProver contract.
type GuardianProverBeaconUpgradedIterator struct {
	Event *GuardianProverBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *GuardianProverBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(GuardianProverBeaconUpgraded)
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
		it.Event = new(GuardianProverBeaconUpgraded)
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
func (it *GuardianProverBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *GuardianProverBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// GuardianProverBeaconUpgraded represents a BeaconUpgraded event raised by the GuardianProver contract.
type GuardianProverBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_GuardianProver *GuardianProverFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*GuardianProverBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _GuardianProver.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &GuardianProverBeaconUpgradedIterator{contract: _GuardianProver.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_GuardianProver *GuardianProverFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *GuardianProverBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _GuardianProver.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(GuardianProverBeaconUpgraded)
				if err := _GuardianProver.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_GuardianProver *GuardianProverFilterer) ParseBeaconUpgraded(log types.Log) (*GuardianProverBeaconUpgraded, error) {
	event := new(GuardianProverBeaconUpgraded)
	if err := _GuardianProver.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
	Version   uint32
	Guardians []common.Address
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterGuardiansUpdated is a free log retrieval operation binding the contract event 0x5132e5b598a417dfc5c7488e5360aef3e865fe4b238cd5ea2a8282e0ca8d10ef.
//
// Solidity: event GuardiansUpdated(uint32 version, address[] guardians)
func (_GuardianProver *GuardianProverFilterer) FilterGuardiansUpdated(opts *bind.FilterOpts) (*GuardianProverGuardiansUpdatedIterator, error) {

	logs, sub, err := _GuardianProver.contract.FilterLogs(opts, "GuardiansUpdated")
	if err != nil {
		return nil, err
	}
	return &GuardianProverGuardiansUpdatedIterator{contract: _GuardianProver.contract, event: "GuardiansUpdated", logs: logs, sub: sub}, nil
}

// WatchGuardiansUpdated is a free log subscription operation binding the contract event 0x5132e5b598a417dfc5c7488e5360aef3e865fe4b238cd5ea2a8282e0ca8d10ef.
//
// Solidity: event GuardiansUpdated(uint32 version, address[] guardians)
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

// ParseGuardiansUpdated is a log parse operation binding the contract event 0x5132e5b598a417dfc5c7488e5360aef3e865fe4b238cd5ea2a8282e0ca8d10ef.
//
// Solidity: event GuardiansUpdated(uint32 version, address[] guardians)
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

// GuardianProverUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the GuardianProver contract.
type GuardianProverUpgradedIterator struct {
	Event *GuardianProverUpgraded // Event containing the contract specifics and raw log

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
func (it *GuardianProverUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(GuardianProverUpgraded)
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
		it.Event = new(GuardianProverUpgraded)
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
func (it *GuardianProverUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *GuardianProverUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// GuardianProverUpgraded represents a Upgraded event raised by the GuardianProver contract.
type GuardianProverUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_GuardianProver *GuardianProverFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*GuardianProverUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _GuardianProver.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &GuardianProverUpgradedIterator{contract: _GuardianProver.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_GuardianProver *GuardianProverFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *GuardianProverUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _GuardianProver.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(GuardianProverUpgraded)
				if err := _GuardianProver.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_GuardianProver *GuardianProverFilterer) ParseUpgraded(log types.Log) (*GuardianProverUpgraded, error) {
	event := new(GuardianProverUpgraded)
	if err := _GuardianProver.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
