// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package assignmenthook

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

// AssignmentHookProverAssignment is an auto generated low-level Go binding around an user-defined struct.
type AssignmentHookProverAssignment struct {
	FeeToken       common.Address
	Expiry         uint64
	MaxBlockId     uint64
	MaxProposedIn  uint64
	MetaHash       [32]byte
	ParentMetaHash [32]byte
	TierFees       []TaikoDataTierFee
	Signature      []byte
}

// TaikoDataBlock is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataBlock struct {
	MetaHash             [32]byte
	AssignedProver       common.Address
	LivenessBond         *big.Int
	BlockId              uint64
	ProposedAt           uint64
	ProposedIn           uint64
	NextTransitionId     uint32
	VerifiedTransitionId uint32
}

// TaikoDataBlockMetadata is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataBlockMetadata struct {
	L1Hash         [32]byte
	Difficulty     [32]byte
	BlobHash       [32]byte
	ExtraData      [32]byte
	DepositsHash   [32]byte
	Coinbase       common.Address
	Id             uint64
	GasLimit       uint32
	Timestamp      uint64
	L1Height       uint64
	MinTier        uint16
	BlobUsed       bool
	ParentMetaHash [32]byte
	Sender         common.Address
}

// TaikoDataTierFee is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataTierFee struct {
	Tier uint16
	Fee  *big.Int
}

// AssignmentHookMetaData contains all meta data concerning the AssignmentHook contract.
var AssignmentHookMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"MAX_GAS_PAYING_PROVER\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"addressManager\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"hashAssignment\",\"inputs\":[{\"name\":\"_assignment\",\"type\":\"tuple\",\"internalType\":\"structAssignmentHook.ProverAssignment\",\"components\":[{\"name\":\"feeToken\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"expiry\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxProposedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"metaHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentMetaHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"tierFees\",\"type\":\"tuple[]\",\"internalType\":\"structTaikoData.TierFee[]\",\"components\":[{\"name\":\"tier\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"fee\",\"type\":\"uint128\",\"internalType\":\"uint128\"}]},{\"name\":\"signature\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]},{\"name\":\"_taikoL1Address\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_blockProposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_assignedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_blobHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_addressManager\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"lastUnpausedAt\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"onBlockProposed\",\"inputs\":[{\"name\":\"_blk\",\"type\":\"tuple\",\"internalType\":\"structTaikoData.Block\",\"components\":[{\"name\":\"metaHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"assignedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"livenessBond\",\"type\":\"uint96\",\"internalType\":\"uint96\"},{\"name\":\"blockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"proposedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"proposedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"nextTransitionId\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"verifiedTransitionId\",\"type\":\"uint32\",\"internalType\":\"uint32\"}]},{\"name\":\"_meta\",\"type\":\"tuple\",\"internalType\":\"structTaikoData.BlockMetadata\",\"components\":[{\"name\":\"l1Hash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"difficulty\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blobHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"extraData\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"depositsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"coinbase\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"id\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"gasLimit\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"timestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"l1Height\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"minTier\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"blobUsed\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"parentMetaHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"sender\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolve\",\"inputs\":[{\"name\":\"_chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_allowZeroAddress\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"addresspayable\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"resolve\",\"inputs\":[{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_allowZeroAddress\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"addresspayable\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BlockAssigned\",\"inputs\":[{\"name\":\"assignedProver\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"meta\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structTaikoData.BlockMetadata\",\"components\":[{\"name\":\"l1Hash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"difficulty\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blobHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"extraData\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"depositsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"coinbase\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"id\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"gasLimit\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"timestamp\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"l1Height\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"minTier\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"blobUsed\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"parentMetaHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"sender\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"assignment\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structAssignmentHook.ProverAssignment\",\"components\":[{\"name\":\"feeToken\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"expiry\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxBlockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"maxProposedIn\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"metaHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"parentMetaHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"tierFees\",\"type\":\"tuple[]\",\"internalType\":\"structTaikoData.TierFee[]\",\"components\":[{\"name\":\"tier\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"fee\",\"type\":\"uint128\",\"internalType\":\"uint128\"}]},{\"name\":\"signature\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"EtherPaymentFailed\",\"inputs\":[{\"name\":\"to\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"maxGas\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ETH_TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"HOOK_ASSIGNMENT_EXPIRED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"HOOK_ASSIGNMENT_INVALID_SIG\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"HOOK_TIER_NOT_FOUND\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_INVALID_MANAGER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_UNEXPECTED_CHAINID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_ZERO_ADDR\",\"inputs\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"type\":\"error\",\"name\":\"ZERO_ADDR_MANAGER\",\"inputs\":[]}]",
}

// AssignmentHookABI is the input ABI used to generate the binding from.
// Deprecated: Use AssignmentHookMetaData.ABI instead.
var AssignmentHookABI = AssignmentHookMetaData.ABI

// AssignmentHook is an auto generated Go binding around an Ethereum contract.
type AssignmentHook struct {
	AssignmentHookCaller     // Read-only binding to the contract
	AssignmentHookTransactor // Write-only binding to the contract
	AssignmentHookFilterer   // Log filterer for contract events
}

// AssignmentHookCaller is an auto generated read-only Go binding around an Ethereum contract.
type AssignmentHookCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AssignmentHookTransactor is an auto generated write-only Go binding around an Ethereum contract.
type AssignmentHookTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AssignmentHookFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type AssignmentHookFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// AssignmentHookSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type AssignmentHookSession struct {
	Contract     *AssignmentHook   // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// AssignmentHookCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type AssignmentHookCallerSession struct {
	Contract *AssignmentHookCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts         // Call options to use throughout this session
}

// AssignmentHookTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type AssignmentHookTransactorSession struct {
	Contract     *AssignmentHookTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts         // Transaction auth options to use throughout this session
}

// AssignmentHookRaw is an auto generated low-level Go binding around an Ethereum contract.
type AssignmentHookRaw struct {
	Contract *AssignmentHook // Generic contract binding to access the raw methods on
}

// AssignmentHookCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type AssignmentHookCallerRaw struct {
	Contract *AssignmentHookCaller // Generic read-only contract binding to access the raw methods on
}

// AssignmentHookTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type AssignmentHookTransactorRaw struct {
	Contract *AssignmentHookTransactor // Generic write-only contract binding to access the raw methods on
}

// NewAssignmentHook creates a new instance of AssignmentHook, bound to a specific deployed contract.
func NewAssignmentHook(address common.Address, backend bind.ContractBackend) (*AssignmentHook, error) {
	contract, err := bindAssignmentHook(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &AssignmentHook{AssignmentHookCaller: AssignmentHookCaller{contract: contract}, AssignmentHookTransactor: AssignmentHookTransactor{contract: contract}, AssignmentHookFilterer: AssignmentHookFilterer{contract: contract}}, nil
}

// NewAssignmentHookCaller creates a new read-only instance of AssignmentHook, bound to a specific deployed contract.
func NewAssignmentHookCaller(address common.Address, caller bind.ContractCaller) (*AssignmentHookCaller, error) {
	contract, err := bindAssignmentHook(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &AssignmentHookCaller{contract: contract}, nil
}

// NewAssignmentHookTransactor creates a new write-only instance of AssignmentHook, bound to a specific deployed contract.
func NewAssignmentHookTransactor(address common.Address, transactor bind.ContractTransactor) (*AssignmentHookTransactor, error) {
	contract, err := bindAssignmentHook(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &AssignmentHookTransactor{contract: contract}, nil
}

// NewAssignmentHookFilterer creates a new log filterer instance of AssignmentHook, bound to a specific deployed contract.
func NewAssignmentHookFilterer(address common.Address, filterer bind.ContractFilterer) (*AssignmentHookFilterer, error) {
	contract, err := bindAssignmentHook(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &AssignmentHookFilterer{contract: contract}, nil
}

// bindAssignmentHook binds a generic wrapper to an already deployed contract.
func bindAssignmentHook(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := AssignmentHookMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_AssignmentHook *AssignmentHookRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _AssignmentHook.Contract.AssignmentHookCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_AssignmentHook *AssignmentHookRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AssignmentHook.Contract.AssignmentHookTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_AssignmentHook *AssignmentHookRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _AssignmentHook.Contract.AssignmentHookTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_AssignmentHook *AssignmentHookCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _AssignmentHook.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_AssignmentHook *AssignmentHookTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AssignmentHook.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_AssignmentHook *AssignmentHookTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _AssignmentHook.Contract.contract.Transact(opts, method, params...)
}

// MAXGASPAYINGPROVER is a free data retrieval call binding the contract method 0x12925031.
//
// Solidity: function MAX_GAS_PAYING_PROVER() view returns(uint256)
func (_AssignmentHook *AssignmentHookCaller) MAXGASPAYINGPROVER(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _AssignmentHook.contract.Call(opts, &out, "MAX_GAS_PAYING_PROVER")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// MAXGASPAYINGPROVER is a free data retrieval call binding the contract method 0x12925031.
//
// Solidity: function MAX_GAS_PAYING_PROVER() view returns(uint256)
func (_AssignmentHook *AssignmentHookSession) MAXGASPAYINGPROVER() (*big.Int, error) {
	return _AssignmentHook.Contract.MAXGASPAYINGPROVER(&_AssignmentHook.CallOpts)
}

// MAXGASPAYINGPROVER is a free data retrieval call binding the contract method 0x12925031.
//
// Solidity: function MAX_GAS_PAYING_PROVER() view returns(uint256)
func (_AssignmentHook *AssignmentHookCallerSession) MAXGASPAYINGPROVER() (*big.Int, error) {
	return _AssignmentHook.Contract.MAXGASPAYINGPROVER(&_AssignmentHook.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_AssignmentHook *AssignmentHookCaller) AddressManager(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AssignmentHook.contract.Call(opts, &out, "addressManager")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_AssignmentHook *AssignmentHookSession) AddressManager() (common.Address, error) {
	return _AssignmentHook.Contract.AddressManager(&_AssignmentHook.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_AssignmentHook *AssignmentHookCallerSession) AddressManager() (common.Address, error) {
	return _AssignmentHook.Contract.AddressManager(&_AssignmentHook.CallOpts)
}

// HashAssignment is a free data retrieval call binding the contract method 0xaf3a0228.
//
// Solidity: function hashAssignment((address,uint64,uint64,uint64,bytes32,bytes32,(uint16,uint128)[],bytes) _assignment, address _taikoL1Address, address _blockProposer, address _assignedProver, bytes32 _blobHash) view returns(bytes32)
func (_AssignmentHook *AssignmentHookCaller) HashAssignment(opts *bind.CallOpts, _assignment AssignmentHookProverAssignment, _taikoL1Address common.Address, _blockProposer common.Address, _assignedProver common.Address, _blobHash [32]byte) ([32]byte, error) {
	var out []interface{}
	err := _AssignmentHook.contract.Call(opts, &out, "hashAssignment", _assignment, _taikoL1Address, _blockProposer, _assignedProver, _blobHash)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashAssignment is a free data retrieval call binding the contract method 0xaf3a0228.
//
// Solidity: function hashAssignment((address,uint64,uint64,uint64,bytes32,bytes32,(uint16,uint128)[],bytes) _assignment, address _taikoL1Address, address _blockProposer, address _assignedProver, bytes32 _blobHash) view returns(bytes32)
func (_AssignmentHook *AssignmentHookSession) HashAssignment(_assignment AssignmentHookProverAssignment, _taikoL1Address common.Address, _blockProposer common.Address, _assignedProver common.Address, _blobHash [32]byte) ([32]byte, error) {
	return _AssignmentHook.Contract.HashAssignment(&_AssignmentHook.CallOpts, _assignment, _taikoL1Address, _blockProposer, _assignedProver, _blobHash)
}

// HashAssignment is a free data retrieval call binding the contract method 0xaf3a0228.
//
// Solidity: function hashAssignment((address,uint64,uint64,uint64,bytes32,bytes32,(uint16,uint128)[],bytes) _assignment, address _taikoL1Address, address _blockProposer, address _assignedProver, bytes32 _blobHash) view returns(bytes32)
func (_AssignmentHook *AssignmentHookCallerSession) HashAssignment(_assignment AssignmentHookProverAssignment, _taikoL1Address common.Address, _blockProposer common.Address, _assignedProver common.Address, _blobHash [32]byte) ([32]byte, error) {
	return _AssignmentHook.Contract.HashAssignment(&_AssignmentHook.CallOpts, _assignment, _taikoL1Address, _blockProposer, _assignedProver, _blobHash)
}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_AssignmentHook *AssignmentHookCaller) LastUnpausedAt(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _AssignmentHook.contract.Call(opts, &out, "lastUnpausedAt")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_AssignmentHook *AssignmentHookSession) LastUnpausedAt() (uint64, error) {
	return _AssignmentHook.Contract.LastUnpausedAt(&_AssignmentHook.CallOpts)
}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_AssignmentHook *AssignmentHookCallerSession) LastUnpausedAt() (uint64, error) {
	return _AssignmentHook.Contract.LastUnpausedAt(&_AssignmentHook.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_AssignmentHook *AssignmentHookCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AssignmentHook.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_AssignmentHook *AssignmentHookSession) Owner() (common.Address, error) {
	return _AssignmentHook.Contract.Owner(&_AssignmentHook.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_AssignmentHook *AssignmentHookCallerSession) Owner() (common.Address, error) {
	return _AssignmentHook.Contract.Owner(&_AssignmentHook.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_AssignmentHook *AssignmentHookCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _AssignmentHook.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_AssignmentHook *AssignmentHookSession) Paused() (bool, error) {
	return _AssignmentHook.Contract.Paused(&_AssignmentHook.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_AssignmentHook *AssignmentHookCallerSession) Paused() (bool, error) {
	return _AssignmentHook.Contract.Paused(&_AssignmentHook.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_AssignmentHook *AssignmentHookCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _AssignmentHook.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_AssignmentHook *AssignmentHookSession) PendingOwner() (common.Address, error) {
	return _AssignmentHook.Contract.PendingOwner(&_AssignmentHook.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_AssignmentHook *AssignmentHookCallerSession) PendingOwner() (common.Address, error) {
	return _AssignmentHook.Contract.PendingOwner(&_AssignmentHook.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_AssignmentHook *AssignmentHookCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _AssignmentHook.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_AssignmentHook *AssignmentHookSession) ProxiableUUID() ([32]byte, error) {
	return _AssignmentHook.Contract.ProxiableUUID(&_AssignmentHook.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_AssignmentHook *AssignmentHookCallerSession) ProxiableUUID() ([32]byte, error) {
	return _AssignmentHook.Contract.ProxiableUUID(&_AssignmentHook.CallOpts)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_AssignmentHook *AssignmentHookCaller) Resolve(opts *bind.CallOpts, _chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _AssignmentHook.contract.Call(opts, &out, "resolve", _chainId, _name, _allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_AssignmentHook *AssignmentHookSession) Resolve(_chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _AssignmentHook.Contract.Resolve(&_AssignmentHook.CallOpts, _chainId, _name, _allowZeroAddress)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_AssignmentHook *AssignmentHookCallerSession) Resolve(_chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _AssignmentHook.Contract.Resolve(&_AssignmentHook.CallOpts, _chainId, _name, _allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_AssignmentHook *AssignmentHookCaller) Resolve0(opts *bind.CallOpts, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _AssignmentHook.contract.Call(opts, &out, "resolve0", _name, _allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_AssignmentHook *AssignmentHookSession) Resolve0(_name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _AssignmentHook.Contract.Resolve0(&_AssignmentHook.CallOpts, _name, _allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_AssignmentHook *AssignmentHookCallerSession) Resolve0(_name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _AssignmentHook.Contract.Resolve0(&_AssignmentHook.CallOpts, _name, _allowZeroAddress)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_AssignmentHook *AssignmentHookTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AssignmentHook.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_AssignmentHook *AssignmentHookSession) AcceptOwnership() (*types.Transaction, error) {
	return _AssignmentHook.Contract.AcceptOwnership(&_AssignmentHook.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_AssignmentHook *AssignmentHookTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _AssignmentHook.Contract.AcceptOwnership(&_AssignmentHook.TransactOpts)
}

// Init is a paid mutator transaction binding the contract method 0xf09a4016.
//
// Solidity: function init(address _owner, address _addressManager) returns()
func (_AssignmentHook *AssignmentHookTransactor) Init(opts *bind.TransactOpts, _owner common.Address, _addressManager common.Address) (*types.Transaction, error) {
	return _AssignmentHook.contract.Transact(opts, "init", _owner, _addressManager)
}

// Init is a paid mutator transaction binding the contract method 0xf09a4016.
//
// Solidity: function init(address _owner, address _addressManager) returns()
func (_AssignmentHook *AssignmentHookSession) Init(_owner common.Address, _addressManager common.Address) (*types.Transaction, error) {
	return _AssignmentHook.Contract.Init(&_AssignmentHook.TransactOpts, _owner, _addressManager)
}

// Init is a paid mutator transaction binding the contract method 0xf09a4016.
//
// Solidity: function init(address _owner, address _addressManager) returns()
func (_AssignmentHook *AssignmentHookTransactorSession) Init(_owner common.Address, _addressManager common.Address) (*types.Transaction, error) {
	return _AssignmentHook.Contract.Init(&_AssignmentHook.TransactOpts, _owner, _addressManager)
}

// OnBlockProposed is a paid mutator transaction binding the contract method 0x36b6ea4e.
//
// Solidity: function onBlockProposed((bytes32,address,uint96,uint64,uint64,uint64,uint32,uint32) _blk, (bytes32,bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint16,bool,bytes32,address) _meta, bytes _data) payable returns()
func (_AssignmentHook *AssignmentHookTransactor) OnBlockProposed(opts *bind.TransactOpts, _blk TaikoDataBlock, _meta TaikoDataBlockMetadata, _data []byte) (*types.Transaction, error) {
	return _AssignmentHook.contract.Transact(opts, "onBlockProposed", _blk, _meta, _data)
}

// OnBlockProposed is a paid mutator transaction binding the contract method 0x36b6ea4e.
//
// Solidity: function onBlockProposed((bytes32,address,uint96,uint64,uint64,uint64,uint32,uint32) _blk, (bytes32,bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint16,bool,bytes32,address) _meta, bytes _data) payable returns()
func (_AssignmentHook *AssignmentHookSession) OnBlockProposed(_blk TaikoDataBlock, _meta TaikoDataBlockMetadata, _data []byte) (*types.Transaction, error) {
	return _AssignmentHook.Contract.OnBlockProposed(&_AssignmentHook.TransactOpts, _blk, _meta, _data)
}

// OnBlockProposed is a paid mutator transaction binding the contract method 0x36b6ea4e.
//
// Solidity: function onBlockProposed((bytes32,address,uint96,uint64,uint64,uint64,uint32,uint32) _blk, (bytes32,bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint16,bool,bytes32,address) _meta, bytes _data) payable returns()
func (_AssignmentHook *AssignmentHookTransactorSession) OnBlockProposed(_blk TaikoDataBlock, _meta TaikoDataBlockMetadata, _data []byte) (*types.Transaction, error) {
	return _AssignmentHook.Contract.OnBlockProposed(&_AssignmentHook.TransactOpts, _blk, _meta, _data)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_AssignmentHook *AssignmentHookTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AssignmentHook.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_AssignmentHook *AssignmentHookSession) Pause() (*types.Transaction, error) {
	return _AssignmentHook.Contract.Pause(&_AssignmentHook.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_AssignmentHook *AssignmentHookTransactorSession) Pause() (*types.Transaction, error) {
	return _AssignmentHook.Contract.Pause(&_AssignmentHook.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_AssignmentHook *AssignmentHookTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AssignmentHook.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_AssignmentHook *AssignmentHookSession) RenounceOwnership() (*types.Transaction, error) {
	return _AssignmentHook.Contract.RenounceOwnership(&_AssignmentHook.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_AssignmentHook *AssignmentHookTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _AssignmentHook.Contract.RenounceOwnership(&_AssignmentHook.TransactOpts)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_AssignmentHook *AssignmentHookTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _AssignmentHook.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_AssignmentHook *AssignmentHookSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _AssignmentHook.Contract.TransferOwnership(&_AssignmentHook.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_AssignmentHook *AssignmentHookTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _AssignmentHook.Contract.TransferOwnership(&_AssignmentHook.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_AssignmentHook *AssignmentHookTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _AssignmentHook.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_AssignmentHook *AssignmentHookSession) Unpause() (*types.Transaction, error) {
	return _AssignmentHook.Contract.Unpause(&_AssignmentHook.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_AssignmentHook *AssignmentHookTransactorSession) Unpause() (*types.Transaction, error) {
	return _AssignmentHook.Contract.Unpause(&_AssignmentHook.TransactOpts)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_AssignmentHook *AssignmentHookTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _AssignmentHook.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_AssignmentHook *AssignmentHookSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _AssignmentHook.Contract.UpgradeTo(&_AssignmentHook.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_AssignmentHook *AssignmentHookTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _AssignmentHook.Contract.UpgradeTo(&_AssignmentHook.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_AssignmentHook *AssignmentHookTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _AssignmentHook.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_AssignmentHook *AssignmentHookSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _AssignmentHook.Contract.UpgradeToAndCall(&_AssignmentHook.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_AssignmentHook *AssignmentHookTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _AssignmentHook.Contract.UpgradeToAndCall(&_AssignmentHook.TransactOpts, newImplementation, data)
}

// AssignmentHookAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the AssignmentHook contract.
type AssignmentHookAdminChangedIterator struct {
	Event *AssignmentHookAdminChanged // Event containing the contract specifics and raw log

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
func (it *AssignmentHookAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AssignmentHookAdminChanged)
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
		it.Event = new(AssignmentHookAdminChanged)
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
func (it *AssignmentHookAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AssignmentHookAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AssignmentHookAdminChanged represents a AdminChanged event raised by the AssignmentHook contract.
type AssignmentHookAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_AssignmentHook *AssignmentHookFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*AssignmentHookAdminChangedIterator, error) {

	logs, sub, err := _AssignmentHook.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &AssignmentHookAdminChangedIterator{contract: _AssignmentHook.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_AssignmentHook *AssignmentHookFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *AssignmentHookAdminChanged) (event.Subscription, error) {

	logs, sub, err := _AssignmentHook.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AssignmentHookAdminChanged)
				if err := _AssignmentHook.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_AssignmentHook *AssignmentHookFilterer) ParseAdminChanged(log types.Log) (*AssignmentHookAdminChanged, error) {
	event := new(AssignmentHookAdminChanged)
	if err := _AssignmentHook.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AssignmentHookBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the AssignmentHook contract.
type AssignmentHookBeaconUpgradedIterator struct {
	Event *AssignmentHookBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *AssignmentHookBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AssignmentHookBeaconUpgraded)
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
		it.Event = new(AssignmentHookBeaconUpgraded)
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
func (it *AssignmentHookBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AssignmentHookBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AssignmentHookBeaconUpgraded represents a BeaconUpgraded event raised by the AssignmentHook contract.
type AssignmentHookBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_AssignmentHook *AssignmentHookFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*AssignmentHookBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _AssignmentHook.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &AssignmentHookBeaconUpgradedIterator{contract: _AssignmentHook.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_AssignmentHook *AssignmentHookFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *AssignmentHookBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _AssignmentHook.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AssignmentHookBeaconUpgraded)
				if err := _AssignmentHook.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_AssignmentHook *AssignmentHookFilterer) ParseBeaconUpgraded(log types.Log) (*AssignmentHookBeaconUpgraded, error) {
	event := new(AssignmentHookBeaconUpgraded)
	if err := _AssignmentHook.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AssignmentHookBlockAssignedIterator is returned from FilterBlockAssigned and is used to iterate over the raw logs and unpacked data for BlockAssigned events raised by the AssignmentHook contract.
type AssignmentHookBlockAssignedIterator struct {
	Event *AssignmentHookBlockAssigned // Event containing the contract specifics and raw log

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
func (it *AssignmentHookBlockAssignedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AssignmentHookBlockAssigned)
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
		it.Event = new(AssignmentHookBlockAssigned)
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
func (it *AssignmentHookBlockAssignedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AssignmentHookBlockAssignedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AssignmentHookBlockAssigned represents a BlockAssigned event raised by the AssignmentHook contract.
type AssignmentHookBlockAssigned struct {
	AssignedProver common.Address
	Meta           TaikoDataBlockMetadata
	Assignment     AssignmentHookProverAssignment
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterBlockAssigned is a free log retrieval operation binding the contract event 0x983b2c64d5e49fdb74b580110b1c64f6f6572b114331e9fee6b7531627eaf0b1.
//
// Solidity: event BlockAssigned(address indexed assignedProver, (bytes32,bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint16,bool,bytes32,address) meta, (address,uint64,uint64,uint64,bytes32,bytes32,(uint16,uint128)[],bytes) assignment)
func (_AssignmentHook *AssignmentHookFilterer) FilterBlockAssigned(opts *bind.FilterOpts, assignedProver []common.Address) (*AssignmentHookBlockAssignedIterator, error) {

	var assignedProverRule []interface{}
	for _, assignedProverItem := range assignedProver {
		assignedProverRule = append(assignedProverRule, assignedProverItem)
	}

	logs, sub, err := _AssignmentHook.contract.FilterLogs(opts, "BlockAssigned", assignedProverRule)
	if err != nil {
		return nil, err
	}
	return &AssignmentHookBlockAssignedIterator{contract: _AssignmentHook.contract, event: "BlockAssigned", logs: logs, sub: sub}, nil
}

// WatchBlockAssigned is a free log subscription operation binding the contract event 0x983b2c64d5e49fdb74b580110b1c64f6f6572b114331e9fee6b7531627eaf0b1.
//
// Solidity: event BlockAssigned(address indexed assignedProver, (bytes32,bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint16,bool,bytes32,address) meta, (address,uint64,uint64,uint64,bytes32,bytes32,(uint16,uint128)[],bytes) assignment)
func (_AssignmentHook *AssignmentHookFilterer) WatchBlockAssigned(opts *bind.WatchOpts, sink chan<- *AssignmentHookBlockAssigned, assignedProver []common.Address) (event.Subscription, error) {

	var assignedProverRule []interface{}
	for _, assignedProverItem := range assignedProver {
		assignedProverRule = append(assignedProverRule, assignedProverItem)
	}

	logs, sub, err := _AssignmentHook.contract.WatchLogs(opts, "BlockAssigned", assignedProverRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AssignmentHookBlockAssigned)
				if err := _AssignmentHook.contract.UnpackLog(event, "BlockAssigned", log); err != nil {
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

// ParseBlockAssigned is a log parse operation binding the contract event 0x983b2c64d5e49fdb74b580110b1c64f6f6572b114331e9fee6b7531627eaf0b1.
//
// Solidity: event BlockAssigned(address indexed assignedProver, (bytes32,bytes32,bytes32,bytes32,bytes32,address,uint64,uint32,uint64,uint64,uint16,bool,bytes32,address) meta, (address,uint64,uint64,uint64,bytes32,bytes32,(uint16,uint128)[],bytes) assignment)
func (_AssignmentHook *AssignmentHookFilterer) ParseBlockAssigned(log types.Log) (*AssignmentHookBlockAssigned, error) {
	event := new(AssignmentHookBlockAssigned)
	if err := _AssignmentHook.contract.UnpackLog(event, "BlockAssigned", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AssignmentHookEtherPaymentFailedIterator is returned from FilterEtherPaymentFailed and is used to iterate over the raw logs and unpacked data for EtherPaymentFailed events raised by the AssignmentHook contract.
type AssignmentHookEtherPaymentFailedIterator struct {
	Event *AssignmentHookEtherPaymentFailed // Event containing the contract specifics and raw log

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
func (it *AssignmentHookEtherPaymentFailedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AssignmentHookEtherPaymentFailed)
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
		it.Event = new(AssignmentHookEtherPaymentFailed)
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
func (it *AssignmentHookEtherPaymentFailedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AssignmentHookEtherPaymentFailedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AssignmentHookEtherPaymentFailed represents a EtherPaymentFailed event raised by the AssignmentHook contract.
type AssignmentHookEtherPaymentFailed struct {
	To     common.Address
	MaxGas *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterEtherPaymentFailed is a free log retrieval operation binding the contract event 0x193fbe934858a5b7669033de55612da355d11604360d59535b5bfaa25c42209e.
//
// Solidity: event EtherPaymentFailed(address to, uint256 maxGas)
func (_AssignmentHook *AssignmentHookFilterer) FilterEtherPaymentFailed(opts *bind.FilterOpts) (*AssignmentHookEtherPaymentFailedIterator, error) {

	logs, sub, err := _AssignmentHook.contract.FilterLogs(opts, "EtherPaymentFailed")
	if err != nil {
		return nil, err
	}
	return &AssignmentHookEtherPaymentFailedIterator{contract: _AssignmentHook.contract, event: "EtherPaymentFailed", logs: logs, sub: sub}, nil
}

// WatchEtherPaymentFailed is a free log subscription operation binding the contract event 0x193fbe934858a5b7669033de55612da355d11604360d59535b5bfaa25c42209e.
//
// Solidity: event EtherPaymentFailed(address to, uint256 maxGas)
func (_AssignmentHook *AssignmentHookFilterer) WatchEtherPaymentFailed(opts *bind.WatchOpts, sink chan<- *AssignmentHookEtherPaymentFailed) (event.Subscription, error) {

	logs, sub, err := _AssignmentHook.contract.WatchLogs(opts, "EtherPaymentFailed")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AssignmentHookEtherPaymentFailed)
				if err := _AssignmentHook.contract.UnpackLog(event, "EtherPaymentFailed", log); err != nil {
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

// ParseEtherPaymentFailed is a log parse operation binding the contract event 0x193fbe934858a5b7669033de55612da355d11604360d59535b5bfaa25c42209e.
//
// Solidity: event EtherPaymentFailed(address to, uint256 maxGas)
func (_AssignmentHook *AssignmentHookFilterer) ParseEtherPaymentFailed(log types.Log) (*AssignmentHookEtherPaymentFailed, error) {
	event := new(AssignmentHookEtherPaymentFailed)
	if err := _AssignmentHook.contract.UnpackLog(event, "EtherPaymentFailed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AssignmentHookInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the AssignmentHook contract.
type AssignmentHookInitializedIterator struct {
	Event *AssignmentHookInitialized // Event containing the contract specifics and raw log

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
func (it *AssignmentHookInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AssignmentHookInitialized)
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
		it.Event = new(AssignmentHookInitialized)
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
func (it *AssignmentHookInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AssignmentHookInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AssignmentHookInitialized represents a Initialized event raised by the AssignmentHook contract.
type AssignmentHookInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_AssignmentHook *AssignmentHookFilterer) FilterInitialized(opts *bind.FilterOpts) (*AssignmentHookInitializedIterator, error) {

	logs, sub, err := _AssignmentHook.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &AssignmentHookInitializedIterator{contract: _AssignmentHook.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_AssignmentHook *AssignmentHookFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *AssignmentHookInitialized) (event.Subscription, error) {

	logs, sub, err := _AssignmentHook.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AssignmentHookInitialized)
				if err := _AssignmentHook.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_AssignmentHook *AssignmentHookFilterer) ParseInitialized(log types.Log) (*AssignmentHookInitialized, error) {
	event := new(AssignmentHookInitialized)
	if err := _AssignmentHook.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AssignmentHookOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the AssignmentHook contract.
type AssignmentHookOwnershipTransferStartedIterator struct {
	Event *AssignmentHookOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *AssignmentHookOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AssignmentHookOwnershipTransferStarted)
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
		it.Event = new(AssignmentHookOwnershipTransferStarted)
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
func (it *AssignmentHookOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AssignmentHookOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AssignmentHookOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the AssignmentHook contract.
type AssignmentHookOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_AssignmentHook *AssignmentHookFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*AssignmentHookOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _AssignmentHook.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &AssignmentHookOwnershipTransferStartedIterator{contract: _AssignmentHook.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_AssignmentHook *AssignmentHookFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *AssignmentHookOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _AssignmentHook.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AssignmentHookOwnershipTransferStarted)
				if err := _AssignmentHook.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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
func (_AssignmentHook *AssignmentHookFilterer) ParseOwnershipTransferStarted(log types.Log) (*AssignmentHookOwnershipTransferStarted, error) {
	event := new(AssignmentHookOwnershipTransferStarted)
	if err := _AssignmentHook.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AssignmentHookOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the AssignmentHook contract.
type AssignmentHookOwnershipTransferredIterator struct {
	Event *AssignmentHookOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *AssignmentHookOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AssignmentHookOwnershipTransferred)
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
		it.Event = new(AssignmentHookOwnershipTransferred)
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
func (it *AssignmentHookOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AssignmentHookOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AssignmentHookOwnershipTransferred represents a OwnershipTransferred event raised by the AssignmentHook contract.
type AssignmentHookOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_AssignmentHook *AssignmentHookFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*AssignmentHookOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _AssignmentHook.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &AssignmentHookOwnershipTransferredIterator{contract: _AssignmentHook.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_AssignmentHook *AssignmentHookFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *AssignmentHookOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _AssignmentHook.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AssignmentHookOwnershipTransferred)
				if err := _AssignmentHook.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_AssignmentHook *AssignmentHookFilterer) ParseOwnershipTransferred(log types.Log) (*AssignmentHookOwnershipTransferred, error) {
	event := new(AssignmentHookOwnershipTransferred)
	if err := _AssignmentHook.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AssignmentHookPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the AssignmentHook contract.
type AssignmentHookPausedIterator struct {
	Event *AssignmentHookPaused // Event containing the contract specifics and raw log

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
func (it *AssignmentHookPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AssignmentHookPaused)
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
		it.Event = new(AssignmentHookPaused)
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
func (it *AssignmentHookPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AssignmentHookPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AssignmentHookPaused represents a Paused event raised by the AssignmentHook contract.
type AssignmentHookPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_AssignmentHook *AssignmentHookFilterer) FilterPaused(opts *bind.FilterOpts) (*AssignmentHookPausedIterator, error) {

	logs, sub, err := _AssignmentHook.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &AssignmentHookPausedIterator{contract: _AssignmentHook.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_AssignmentHook *AssignmentHookFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *AssignmentHookPaused) (event.Subscription, error) {

	logs, sub, err := _AssignmentHook.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AssignmentHookPaused)
				if err := _AssignmentHook.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_AssignmentHook *AssignmentHookFilterer) ParsePaused(log types.Log) (*AssignmentHookPaused, error) {
	event := new(AssignmentHookPaused)
	if err := _AssignmentHook.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AssignmentHookUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the AssignmentHook contract.
type AssignmentHookUnpausedIterator struct {
	Event *AssignmentHookUnpaused // Event containing the contract specifics and raw log

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
func (it *AssignmentHookUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AssignmentHookUnpaused)
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
		it.Event = new(AssignmentHookUnpaused)
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
func (it *AssignmentHookUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AssignmentHookUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AssignmentHookUnpaused represents a Unpaused event raised by the AssignmentHook contract.
type AssignmentHookUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_AssignmentHook *AssignmentHookFilterer) FilterUnpaused(opts *bind.FilterOpts) (*AssignmentHookUnpausedIterator, error) {

	logs, sub, err := _AssignmentHook.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &AssignmentHookUnpausedIterator{contract: _AssignmentHook.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_AssignmentHook *AssignmentHookFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *AssignmentHookUnpaused) (event.Subscription, error) {

	logs, sub, err := _AssignmentHook.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AssignmentHookUnpaused)
				if err := _AssignmentHook.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_AssignmentHook *AssignmentHookFilterer) ParseUnpaused(log types.Log) (*AssignmentHookUnpaused, error) {
	event := new(AssignmentHookUnpaused)
	if err := _AssignmentHook.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// AssignmentHookUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the AssignmentHook contract.
type AssignmentHookUpgradedIterator struct {
	Event *AssignmentHookUpgraded // Event containing the contract specifics and raw log

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
func (it *AssignmentHookUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(AssignmentHookUpgraded)
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
		it.Event = new(AssignmentHookUpgraded)
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
func (it *AssignmentHookUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *AssignmentHookUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// AssignmentHookUpgraded represents a Upgraded event raised by the AssignmentHook contract.
type AssignmentHookUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_AssignmentHook *AssignmentHookFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*AssignmentHookUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _AssignmentHook.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &AssignmentHookUpgradedIterator{contract: _AssignmentHook.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_AssignmentHook *AssignmentHookFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *AssignmentHookUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _AssignmentHook.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(AssignmentHookUpgraded)
				if err := _AssignmentHook.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_AssignmentHook *AssignmentHookFilterer) ParseUpgraded(log types.Log) (*AssignmentHookUpgraded, error) {
	event := new(AssignmentHookUpgraded)
	if err := _AssignmentHook.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
