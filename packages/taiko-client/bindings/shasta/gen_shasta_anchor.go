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

// AnchorBlockParams is an auto generated low-level Go binding around an user-defined struct.
type AnchorBlockParams struct {
	BlockIndex        uint16
	AnchorBlockNumber *big.Int
	AnchorBlockHash   [32]byte
	AnchorStateRoot   [32]byte
}

// AnchorBlockState is an auto generated low-level Go binding around an user-defined struct.
type AnchorBlockState struct {
	AnchorBlockNumber *big.Int
	AncestorsHash     [32]byte
}

// AnchorProposalParams is an auto generated low-level Go binding around an user-defined struct.
type AnchorProposalParams struct {
	ProposalId           *big.Int
	Proposer             common.Address
	ProverAuth           []byte
	BondInstructionsHash [32]byte
	BondInstructions     []LibBondsBondInstruction
}

// AnchorProposalState is an auto generated low-level Go binding around an user-defined struct.
type AnchorProposalState struct {
	BondInstructionsHash [32]byte
	DesignatedProver     common.Address
	IsLowBondProposal    bool
}

// AnchorProverAuth is an auto generated low-level Go binding around an user-defined struct.
type AnchorProverAuth struct {
	ProposalId *big.Int
	Proposer   common.Address
	ProvingFee *big.Int
	Signature  []byte
}

// ShastaAnchorMetaData contains all meta data concerning the ShastaAnchor contract.
var ShastaAnchorMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"_checkpointStore\",\"type\":\"address\",\"internalType\":\"contractICheckpointStore\"},{\"name\":\"_bondManager\",\"type\":\"address\",\"internalType\":\"contractIBondManager\"},{\"name\":\"_livenessBond\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"_provabilityBond\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"_shastaForkHeight\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_l1ChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"ANCHOR_GAS_LIMIT\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"GOLDEN_TOUCH_ADDRESS\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"_isMatchingProverAuthContext\",\"inputs\":[{\"name\":\"_auth\",\"type\":\"tuple\",\"internalType\":\"structAnchor.ProverAuth\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"provingFee\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"signature\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]},{\"name\":\"_proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"_proposer\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"anchor\",\"inputs\":[{\"name\":\"_proposalParams\",\"type\":\"tuple\",\"internalType\":\"structAnchor.ProposalParams\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"proverAuth\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"bondInstructionsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"bondInstructions\",\"type\":\"tuple[]\",\"internalType\":\"structLibBonds.BondInstruction[]\",\"components\":[{\"name\":\"proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"bondType\",\"type\":\"uint8\",\"internalType\":\"enumLibBonds.BondType\"},{\"name\":\"payer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"payee\",\"type\":\"address\",\"internalType\":\"address\"}]}]},{\"name\":\"_blockParams\",\"type\":\"tuple\",\"internalType\":\"structAnchor.BlockParams\",\"components\":[{\"name\":\"blockIndex\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"anchorBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"anchorBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"anchorStateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"bondManager\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractIBondManager\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"checkpointStore\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"contractICheckpointStore\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getBlockState\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structAnchor.BlockState\",\"components\":[{\"name\":\"anchorBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"ancestorsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getDesignatedProver\",\"inputs\":[{\"name\":\"_proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"_proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_proverAuth\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"_currentDesignatedProver\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"isLowBondProposal_\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"designatedProver_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"provingFeeToTransfer_\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getProposalState\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"tuple\",\"internalType\":\"structAnchor.ProposalState\",\"components\":[{\"name\":\"bondInstructionsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"designatedProver\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"isLowBondProposal\",\"type\":\"bool\",\"internalType\":\"bool\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"impl\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inNonReentrant\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"l1ChainId\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"livenessBond\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"provabilityBond\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolver\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"shastaForkHeight\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"validateProverAuth\",\"inputs\":[{\"name\":\"_proposalId\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"_proposer\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_proverAuth\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"signer_\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"provingFee_\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"withdraw\",\"inputs\":[{\"name\":\"_token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_to\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Anchored\",\"inputs\":[{\"name\":\"bondInstructionsHash\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"designatedProver\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"isLowBondProposal\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"},{\"name\":\"anchorBlockNumber\",\"type\":\"uint48\",\"indexed\":false,\"internalType\":\"uint48\"},{\"name\":\"ancestorsHash\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Withdrawn\",\"inputs\":[{\"name\":\"token\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCESS_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AncestorsHashMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"BondInstructionsHashMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ETH_TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FUNC_NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidAddress\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidAnchorBlockNumber\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidBlockIndex\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidForkHeight\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidL1ChainId\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidL2ChainId\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidSender\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NonZeroAnchorBlockHash\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NonZeroAnchorStateRoot\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NonZeroBlockIndex\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ProposalIdMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ProposerMismatch\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_VALUE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZeroBlockCount\",\"inputs\":[]}]",
}

// ShastaAnchorABI is the input ABI used to generate the binding from.
// Deprecated: Use ShastaAnchorMetaData.ABI instead.
var ShastaAnchorABI = ShastaAnchorMetaData.ABI

// ShastaAnchor is an auto generated Go binding around an Ethereum contract.
type ShastaAnchor struct {
	ShastaAnchorCaller     // Read-only binding to the contract
	ShastaAnchorTransactor // Write-only binding to the contract
	ShastaAnchorFilterer   // Log filterer for contract events
}

// ShastaAnchorCaller is an auto generated read-only Go binding around an Ethereum contract.
type ShastaAnchorCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ShastaAnchorTransactor is an auto generated write-only Go binding around an Ethereum contract.
type ShastaAnchorTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ShastaAnchorFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type ShastaAnchorFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ShastaAnchorSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type ShastaAnchorSession struct {
	Contract     *ShastaAnchor     // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// ShastaAnchorCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type ShastaAnchorCallerSession struct {
	Contract *ShastaAnchorCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts       // Call options to use throughout this session
}

// ShastaAnchorTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type ShastaAnchorTransactorSession struct {
	Contract     *ShastaAnchorTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts       // Transaction auth options to use throughout this session
}

// ShastaAnchorRaw is an auto generated low-level Go binding around an Ethereum contract.
type ShastaAnchorRaw struct {
	Contract *ShastaAnchor // Generic contract binding to access the raw methods on
}

// ShastaAnchorCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type ShastaAnchorCallerRaw struct {
	Contract *ShastaAnchorCaller // Generic read-only contract binding to access the raw methods on
}

// ShastaAnchorTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type ShastaAnchorTransactorRaw struct {
	Contract *ShastaAnchorTransactor // Generic write-only contract binding to access the raw methods on
}

// NewShastaAnchor creates a new instance of ShastaAnchor, bound to a specific deployed contract.
func NewShastaAnchor(address common.Address, backend bind.ContractBackend) (*ShastaAnchor, error) {
	contract, err := bindShastaAnchor(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &ShastaAnchor{ShastaAnchorCaller: ShastaAnchorCaller{contract: contract}, ShastaAnchorTransactor: ShastaAnchorTransactor{contract: contract}, ShastaAnchorFilterer: ShastaAnchorFilterer{contract: contract}}, nil
}

// NewShastaAnchorCaller creates a new read-only instance of ShastaAnchor, bound to a specific deployed contract.
func NewShastaAnchorCaller(address common.Address, caller bind.ContractCaller) (*ShastaAnchorCaller, error) {
	contract, err := bindShastaAnchor(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &ShastaAnchorCaller{contract: contract}, nil
}

// NewShastaAnchorTransactor creates a new write-only instance of ShastaAnchor, bound to a specific deployed contract.
func NewShastaAnchorTransactor(address common.Address, transactor bind.ContractTransactor) (*ShastaAnchorTransactor, error) {
	contract, err := bindShastaAnchor(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &ShastaAnchorTransactor{contract: contract}, nil
}

// NewShastaAnchorFilterer creates a new log filterer instance of ShastaAnchor, bound to a specific deployed contract.
func NewShastaAnchorFilterer(address common.Address, filterer bind.ContractFilterer) (*ShastaAnchorFilterer, error) {
	contract, err := bindShastaAnchor(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &ShastaAnchorFilterer{contract: contract}, nil
}

// bindShastaAnchor binds a generic wrapper to an already deployed contract.
func bindShastaAnchor(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := ShastaAnchorMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ShastaAnchor *ShastaAnchorRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ShastaAnchor.Contract.ShastaAnchorCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ShastaAnchor *ShastaAnchorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ShastaAnchor.Contract.ShastaAnchorTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ShastaAnchor *ShastaAnchorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ShastaAnchor.Contract.ShastaAnchorTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ShastaAnchor *ShastaAnchorCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ShastaAnchor.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ShastaAnchor *ShastaAnchorTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ShastaAnchor.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ShastaAnchor *ShastaAnchorTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ShastaAnchor.Contract.contract.Transact(opts, method, params...)
}

// ANCHORGASLIMIT is a free data retrieval call binding the contract method 0xc46e3a66.
//
// Solidity: function ANCHOR_GAS_LIMIT() view returns(uint64)
func (_ShastaAnchor *ShastaAnchorCaller) ANCHORGASLIMIT(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _ShastaAnchor.contract.Call(opts, &out, "ANCHOR_GAS_LIMIT")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// ANCHORGASLIMIT is a free data retrieval call binding the contract method 0xc46e3a66.
//
// Solidity: function ANCHOR_GAS_LIMIT() view returns(uint64)
func (_ShastaAnchor *ShastaAnchorSession) ANCHORGASLIMIT() (uint64, error) {
	return _ShastaAnchor.Contract.ANCHORGASLIMIT(&_ShastaAnchor.CallOpts)
}

// ANCHORGASLIMIT is a free data retrieval call binding the contract method 0xc46e3a66.
//
// Solidity: function ANCHOR_GAS_LIMIT() view returns(uint64)
func (_ShastaAnchor *ShastaAnchorCallerSession) ANCHORGASLIMIT() (uint64, error) {
	return _ShastaAnchor.Contract.ANCHORGASLIMIT(&_ShastaAnchor.CallOpts)
}

// GOLDENTOUCHADDRESS is a free data retrieval call binding the contract method 0x9ee512f2.
//
// Solidity: function GOLDEN_TOUCH_ADDRESS() view returns(address)
func (_ShastaAnchor *ShastaAnchorCaller) GOLDENTOUCHADDRESS(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ShastaAnchor.contract.Call(opts, &out, "GOLDEN_TOUCH_ADDRESS")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// GOLDENTOUCHADDRESS is a free data retrieval call binding the contract method 0x9ee512f2.
//
// Solidity: function GOLDEN_TOUCH_ADDRESS() view returns(address)
func (_ShastaAnchor *ShastaAnchorSession) GOLDENTOUCHADDRESS() (common.Address, error) {
	return _ShastaAnchor.Contract.GOLDENTOUCHADDRESS(&_ShastaAnchor.CallOpts)
}

// GOLDENTOUCHADDRESS is a free data retrieval call binding the contract method 0x9ee512f2.
//
// Solidity: function GOLDEN_TOUCH_ADDRESS() view returns(address)
func (_ShastaAnchor *ShastaAnchorCallerSession) GOLDENTOUCHADDRESS() (common.Address, error) {
	return _ShastaAnchor.Contract.GOLDENTOUCHADDRESS(&_ShastaAnchor.CallOpts)
}

// IsMatchingProverAuthContext is a free data retrieval call binding the contract method 0xddececb2.
//
// Solidity: function _isMatchingProverAuthContext((uint48,address,uint256,bytes) _auth, uint48 _proposalId, address _proposer) pure returns(bool)
func (_ShastaAnchor *ShastaAnchorCaller) IsMatchingProverAuthContext(opts *bind.CallOpts, _auth AnchorProverAuth, _proposalId *big.Int, _proposer common.Address) (bool, error) {
	var out []interface{}
	err := _ShastaAnchor.contract.Call(opts, &out, "_isMatchingProverAuthContext", _auth, _proposalId, _proposer)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsMatchingProverAuthContext is a free data retrieval call binding the contract method 0xddececb2.
//
// Solidity: function _isMatchingProverAuthContext((uint48,address,uint256,bytes) _auth, uint48 _proposalId, address _proposer) pure returns(bool)
func (_ShastaAnchor *ShastaAnchorSession) IsMatchingProverAuthContext(_auth AnchorProverAuth, _proposalId *big.Int, _proposer common.Address) (bool, error) {
	return _ShastaAnchor.Contract.IsMatchingProverAuthContext(&_ShastaAnchor.CallOpts, _auth, _proposalId, _proposer)
}

// IsMatchingProverAuthContext is a free data retrieval call binding the contract method 0xddececb2.
//
// Solidity: function _isMatchingProverAuthContext((uint48,address,uint256,bytes) _auth, uint48 _proposalId, address _proposer) pure returns(bool)
func (_ShastaAnchor *ShastaAnchorCallerSession) IsMatchingProverAuthContext(_auth AnchorProverAuth, _proposalId *big.Int, _proposer common.Address) (bool, error) {
	return _ShastaAnchor.Contract.IsMatchingProverAuthContext(&_ShastaAnchor.CallOpts, _auth, _proposalId, _proposer)
}

// BondManager is a free data retrieval call binding the contract method 0x363cc427.
//
// Solidity: function bondManager() view returns(address)
func (_ShastaAnchor *ShastaAnchorCaller) BondManager(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ShastaAnchor.contract.Call(opts, &out, "bondManager")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// BondManager is a free data retrieval call binding the contract method 0x363cc427.
//
// Solidity: function bondManager() view returns(address)
func (_ShastaAnchor *ShastaAnchorSession) BondManager() (common.Address, error) {
	return _ShastaAnchor.Contract.BondManager(&_ShastaAnchor.CallOpts)
}

// BondManager is a free data retrieval call binding the contract method 0x363cc427.
//
// Solidity: function bondManager() view returns(address)
func (_ShastaAnchor *ShastaAnchorCallerSession) BondManager() (common.Address, error) {
	return _ShastaAnchor.Contract.BondManager(&_ShastaAnchor.CallOpts)
}

// CheckpointStore is a free data retrieval call binding the contract method 0x955a7244.
//
// Solidity: function checkpointStore() view returns(address)
func (_ShastaAnchor *ShastaAnchorCaller) CheckpointStore(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ShastaAnchor.contract.Call(opts, &out, "checkpointStore")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CheckpointStore is a free data retrieval call binding the contract method 0x955a7244.
//
// Solidity: function checkpointStore() view returns(address)
func (_ShastaAnchor *ShastaAnchorSession) CheckpointStore() (common.Address, error) {
	return _ShastaAnchor.Contract.CheckpointStore(&_ShastaAnchor.CallOpts)
}

// CheckpointStore is a free data retrieval call binding the contract method 0x955a7244.
//
// Solidity: function checkpointStore() view returns(address)
func (_ShastaAnchor *ShastaAnchorCallerSession) CheckpointStore() (common.Address, error) {
	return _ShastaAnchor.Contract.CheckpointStore(&_ShastaAnchor.CallOpts)
}

// GetBlockState is a free data retrieval call binding the contract method 0x0f439bd9.
//
// Solidity: function getBlockState() view returns((uint48,bytes32))
func (_ShastaAnchor *ShastaAnchorCaller) GetBlockState(opts *bind.CallOpts) (AnchorBlockState, error) {
	var out []interface{}
	err := _ShastaAnchor.contract.Call(opts, &out, "getBlockState")

	if err != nil {
		return *new(AnchorBlockState), err
	}

	out0 := *abi.ConvertType(out[0], new(AnchorBlockState)).(*AnchorBlockState)

	return out0, err

}

// GetBlockState is a free data retrieval call binding the contract method 0x0f439bd9.
//
// Solidity: function getBlockState() view returns((uint48,bytes32))
func (_ShastaAnchor *ShastaAnchorSession) GetBlockState() (AnchorBlockState, error) {
	return _ShastaAnchor.Contract.GetBlockState(&_ShastaAnchor.CallOpts)
}

// GetBlockState is a free data retrieval call binding the contract method 0x0f439bd9.
//
// Solidity: function getBlockState() view returns((uint48,bytes32))
func (_ShastaAnchor *ShastaAnchorCallerSession) GetBlockState() (AnchorBlockState, error) {
	return _ShastaAnchor.Contract.GetBlockState(&_ShastaAnchor.CallOpts)
}

// GetDesignatedProver is a free data retrieval call binding the contract method 0xb3d5e45f.
//
// Solidity: function getDesignatedProver(uint48 _proposalId, address _proposer, bytes _proverAuth, address _currentDesignatedProver) view returns(bool isLowBondProposal_, address designatedProver_, uint256 provingFeeToTransfer_)
func (_ShastaAnchor *ShastaAnchorCaller) GetDesignatedProver(opts *bind.CallOpts, _proposalId *big.Int, _proposer common.Address, _proverAuth []byte, _currentDesignatedProver common.Address) (struct {
	IsLowBondProposal    bool
	DesignatedProver     common.Address
	ProvingFeeToTransfer *big.Int
}, error) {
	var out []interface{}
	err := _ShastaAnchor.contract.Call(opts, &out, "getDesignatedProver", _proposalId, _proposer, _proverAuth, _currentDesignatedProver)

	outstruct := new(struct {
		IsLowBondProposal    bool
		DesignatedProver     common.Address
		ProvingFeeToTransfer *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.IsLowBondProposal = *abi.ConvertType(out[0], new(bool)).(*bool)
	outstruct.DesignatedProver = *abi.ConvertType(out[1], new(common.Address)).(*common.Address)
	outstruct.ProvingFeeToTransfer = *abi.ConvertType(out[2], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// GetDesignatedProver is a free data retrieval call binding the contract method 0xb3d5e45f.
//
// Solidity: function getDesignatedProver(uint48 _proposalId, address _proposer, bytes _proverAuth, address _currentDesignatedProver) view returns(bool isLowBondProposal_, address designatedProver_, uint256 provingFeeToTransfer_)
func (_ShastaAnchor *ShastaAnchorSession) GetDesignatedProver(_proposalId *big.Int, _proposer common.Address, _proverAuth []byte, _currentDesignatedProver common.Address) (struct {
	IsLowBondProposal    bool
	DesignatedProver     common.Address
	ProvingFeeToTransfer *big.Int
}, error) {
	return _ShastaAnchor.Contract.GetDesignatedProver(&_ShastaAnchor.CallOpts, _proposalId, _proposer, _proverAuth, _currentDesignatedProver)
}

// GetDesignatedProver is a free data retrieval call binding the contract method 0xb3d5e45f.
//
// Solidity: function getDesignatedProver(uint48 _proposalId, address _proposer, bytes _proverAuth, address _currentDesignatedProver) view returns(bool isLowBondProposal_, address designatedProver_, uint256 provingFeeToTransfer_)
func (_ShastaAnchor *ShastaAnchorCallerSession) GetDesignatedProver(_proposalId *big.Int, _proposer common.Address, _proverAuth []byte, _currentDesignatedProver common.Address) (struct {
	IsLowBondProposal    bool
	DesignatedProver     common.Address
	ProvingFeeToTransfer *big.Int
}, error) {
	return _ShastaAnchor.Contract.GetDesignatedProver(&_ShastaAnchor.CallOpts, _proposalId, _proposer, _proverAuth, _currentDesignatedProver)
}

// GetProposalState is a free data retrieval call binding the contract method 0xaade375b.
//
// Solidity: function getProposalState() view returns((bytes32,address,bool))
func (_ShastaAnchor *ShastaAnchorCaller) GetProposalState(opts *bind.CallOpts) (AnchorProposalState, error) {
	var out []interface{}
	err := _ShastaAnchor.contract.Call(opts, &out, "getProposalState")

	if err != nil {
		return *new(AnchorProposalState), err
	}

	out0 := *abi.ConvertType(out[0], new(AnchorProposalState)).(*AnchorProposalState)

	return out0, err

}

// GetProposalState is a free data retrieval call binding the contract method 0xaade375b.
//
// Solidity: function getProposalState() view returns((bytes32,address,bool))
func (_ShastaAnchor *ShastaAnchorSession) GetProposalState() (AnchorProposalState, error) {
	return _ShastaAnchor.Contract.GetProposalState(&_ShastaAnchor.CallOpts)
}

// GetProposalState is a free data retrieval call binding the contract method 0xaade375b.
//
// Solidity: function getProposalState() view returns((bytes32,address,bool))
func (_ShastaAnchor *ShastaAnchorCallerSession) GetProposalState() (AnchorProposalState, error) {
	return _ShastaAnchor.Contract.GetProposalState(&_ShastaAnchor.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_ShastaAnchor *ShastaAnchorCaller) Impl(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ShastaAnchor.contract.Call(opts, &out, "impl")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_ShastaAnchor *ShastaAnchorSession) Impl() (common.Address, error) {
	return _ShastaAnchor.Contract.Impl(&_ShastaAnchor.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_ShastaAnchor *ShastaAnchorCallerSession) Impl() (common.Address, error) {
	return _ShastaAnchor.Contract.Impl(&_ShastaAnchor.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_ShastaAnchor *ShastaAnchorCaller) InNonReentrant(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _ShastaAnchor.contract.Call(opts, &out, "inNonReentrant")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_ShastaAnchor *ShastaAnchorSession) InNonReentrant() (bool, error) {
	return _ShastaAnchor.Contract.InNonReentrant(&_ShastaAnchor.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_ShastaAnchor *ShastaAnchorCallerSession) InNonReentrant() (bool, error) {
	return _ShastaAnchor.Contract.InNonReentrant(&_ShastaAnchor.CallOpts)
}

// L1ChainId is a free data retrieval call binding the contract method 0x12622e5b.
//
// Solidity: function l1ChainId() view returns(uint64)
func (_ShastaAnchor *ShastaAnchorCaller) L1ChainId(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _ShastaAnchor.contract.Call(opts, &out, "l1ChainId")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// L1ChainId is a free data retrieval call binding the contract method 0x12622e5b.
//
// Solidity: function l1ChainId() view returns(uint64)
func (_ShastaAnchor *ShastaAnchorSession) L1ChainId() (uint64, error) {
	return _ShastaAnchor.Contract.L1ChainId(&_ShastaAnchor.CallOpts)
}

// L1ChainId is a free data retrieval call binding the contract method 0x12622e5b.
//
// Solidity: function l1ChainId() view returns(uint64)
func (_ShastaAnchor *ShastaAnchorCallerSession) L1ChainId() (uint64, error) {
	return _ShastaAnchor.Contract.L1ChainId(&_ShastaAnchor.CallOpts)
}

// LivenessBond is a free data retrieval call binding the contract method 0xd4414221.
//
// Solidity: function livenessBond() view returns(uint256)
func (_ShastaAnchor *ShastaAnchorCaller) LivenessBond(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _ShastaAnchor.contract.Call(opts, &out, "livenessBond")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// LivenessBond is a free data retrieval call binding the contract method 0xd4414221.
//
// Solidity: function livenessBond() view returns(uint256)
func (_ShastaAnchor *ShastaAnchorSession) LivenessBond() (*big.Int, error) {
	return _ShastaAnchor.Contract.LivenessBond(&_ShastaAnchor.CallOpts)
}

// LivenessBond is a free data retrieval call binding the contract method 0xd4414221.
//
// Solidity: function livenessBond() view returns(uint256)
func (_ShastaAnchor *ShastaAnchorCallerSession) LivenessBond() (*big.Int, error) {
	return _ShastaAnchor.Contract.LivenessBond(&_ShastaAnchor.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ShastaAnchor *ShastaAnchorCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ShastaAnchor.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ShastaAnchor *ShastaAnchorSession) Owner() (common.Address, error) {
	return _ShastaAnchor.Contract.Owner(&_ShastaAnchor.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ShastaAnchor *ShastaAnchorCallerSession) Owner() (common.Address, error) {
	return _ShastaAnchor.Contract.Owner(&_ShastaAnchor.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_ShastaAnchor *ShastaAnchorCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _ShastaAnchor.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_ShastaAnchor *ShastaAnchorSession) Paused() (bool, error) {
	return _ShastaAnchor.Contract.Paused(&_ShastaAnchor.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_ShastaAnchor *ShastaAnchorCallerSession) Paused() (bool, error) {
	return _ShastaAnchor.Contract.Paused(&_ShastaAnchor.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_ShastaAnchor *ShastaAnchorCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ShastaAnchor.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_ShastaAnchor *ShastaAnchorSession) PendingOwner() (common.Address, error) {
	return _ShastaAnchor.Contract.PendingOwner(&_ShastaAnchor.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_ShastaAnchor *ShastaAnchorCallerSession) PendingOwner() (common.Address, error) {
	return _ShastaAnchor.Contract.PendingOwner(&_ShastaAnchor.CallOpts)
}

// ProvabilityBond is a free data retrieval call binding the contract method 0xcf1a0f22.
//
// Solidity: function provabilityBond() view returns(uint256)
func (_ShastaAnchor *ShastaAnchorCaller) ProvabilityBond(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _ShastaAnchor.contract.Call(opts, &out, "provabilityBond")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// ProvabilityBond is a free data retrieval call binding the contract method 0xcf1a0f22.
//
// Solidity: function provabilityBond() view returns(uint256)
func (_ShastaAnchor *ShastaAnchorSession) ProvabilityBond() (*big.Int, error) {
	return _ShastaAnchor.Contract.ProvabilityBond(&_ShastaAnchor.CallOpts)
}

// ProvabilityBond is a free data retrieval call binding the contract method 0xcf1a0f22.
//
// Solidity: function provabilityBond() view returns(uint256)
func (_ShastaAnchor *ShastaAnchorCallerSession) ProvabilityBond() (*big.Int, error) {
	return _ShastaAnchor.Contract.ProvabilityBond(&_ShastaAnchor.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_ShastaAnchor *ShastaAnchorCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _ShastaAnchor.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_ShastaAnchor *ShastaAnchorSession) ProxiableUUID() ([32]byte, error) {
	return _ShastaAnchor.Contract.ProxiableUUID(&_ShastaAnchor.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_ShastaAnchor *ShastaAnchorCallerSession) ProxiableUUID() ([32]byte, error) {
	return _ShastaAnchor.Contract.ProxiableUUID(&_ShastaAnchor.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_ShastaAnchor *ShastaAnchorCaller) Resolver(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ShastaAnchor.contract.Call(opts, &out, "resolver")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_ShastaAnchor *ShastaAnchorSession) Resolver() (common.Address, error) {
	return _ShastaAnchor.Contract.Resolver(&_ShastaAnchor.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_ShastaAnchor *ShastaAnchorCallerSession) Resolver() (common.Address, error) {
	return _ShastaAnchor.Contract.Resolver(&_ShastaAnchor.CallOpts)
}

// ShastaForkHeight is a free data retrieval call binding the contract method 0xf37f2868.
//
// Solidity: function shastaForkHeight() view returns(uint64)
func (_ShastaAnchor *ShastaAnchorCaller) ShastaForkHeight(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _ShastaAnchor.contract.Call(opts, &out, "shastaForkHeight")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// ShastaForkHeight is a free data retrieval call binding the contract method 0xf37f2868.
//
// Solidity: function shastaForkHeight() view returns(uint64)
func (_ShastaAnchor *ShastaAnchorSession) ShastaForkHeight() (uint64, error) {
	return _ShastaAnchor.Contract.ShastaForkHeight(&_ShastaAnchor.CallOpts)
}

// ShastaForkHeight is a free data retrieval call binding the contract method 0xf37f2868.
//
// Solidity: function shastaForkHeight() view returns(uint64)
func (_ShastaAnchor *ShastaAnchorCallerSession) ShastaForkHeight() (uint64, error) {
	return _ShastaAnchor.Contract.ShastaForkHeight(&_ShastaAnchor.CallOpts)
}

// ValidateProverAuth is a free data retrieval call binding the contract method 0xa37ea515.
//
// Solidity: function validateProverAuth(uint48 _proposalId, address _proposer, bytes _proverAuth) pure returns(address signer_, uint256 provingFee_)
func (_ShastaAnchor *ShastaAnchorCaller) ValidateProverAuth(opts *bind.CallOpts, _proposalId *big.Int, _proposer common.Address, _proverAuth []byte) (struct {
	Signer     common.Address
	ProvingFee *big.Int
}, error) {
	var out []interface{}
	err := _ShastaAnchor.contract.Call(opts, &out, "validateProverAuth", _proposalId, _proposer, _proverAuth)

	outstruct := new(struct {
		Signer     common.Address
		ProvingFee *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Signer = *abi.ConvertType(out[0], new(common.Address)).(*common.Address)
	outstruct.ProvingFee = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// ValidateProverAuth is a free data retrieval call binding the contract method 0xa37ea515.
//
// Solidity: function validateProverAuth(uint48 _proposalId, address _proposer, bytes _proverAuth) pure returns(address signer_, uint256 provingFee_)
func (_ShastaAnchor *ShastaAnchorSession) ValidateProverAuth(_proposalId *big.Int, _proposer common.Address, _proverAuth []byte) (struct {
	Signer     common.Address
	ProvingFee *big.Int
}, error) {
	return _ShastaAnchor.Contract.ValidateProverAuth(&_ShastaAnchor.CallOpts, _proposalId, _proposer, _proverAuth)
}

// ValidateProverAuth is a free data retrieval call binding the contract method 0xa37ea515.
//
// Solidity: function validateProverAuth(uint48 _proposalId, address _proposer, bytes _proverAuth) pure returns(address signer_, uint256 provingFee_)
func (_ShastaAnchor *ShastaAnchorCallerSession) ValidateProverAuth(_proposalId *big.Int, _proposer common.Address, _proverAuth []byte) (struct {
	Signer     common.Address
	ProvingFee *big.Int
}, error) {
	return _ShastaAnchor.Contract.ValidateProverAuth(&_ShastaAnchor.CallOpts, _proposalId, _proposer, _proverAuth)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_ShastaAnchor *ShastaAnchorTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ShastaAnchor.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_ShastaAnchor *ShastaAnchorSession) AcceptOwnership() (*types.Transaction, error) {
	return _ShastaAnchor.Contract.AcceptOwnership(&_ShastaAnchor.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_ShastaAnchor *ShastaAnchorTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _ShastaAnchor.Contract.AcceptOwnership(&_ShastaAnchor.TransactOpts)
}

// Anchor is a paid mutator transaction binding the contract method 0xc9f115bc.
//
// Solidity: function anchor((uint48,address,bytes,bytes32,(uint48,uint8,address,address)[]) _proposalParams, (uint16,uint48,bytes32,bytes32) _blockParams) returns()
func (_ShastaAnchor *ShastaAnchorTransactor) Anchor(opts *bind.TransactOpts, _proposalParams AnchorProposalParams, _blockParams AnchorBlockParams) (*types.Transaction, error) {
	return _ShastaAnchor.contract.Transact(opts, "anchor", _proposalParams, _blockParams)
}

// Anchor is a paid mutator transaction binding the contract method 0xc9f115bc.
//
// Solidity: function anchor((uint48,address,bytes,bytes32,(uint48,uint8,address,address)[]) _proposalParams, (uint16,uint48,bytes32,bytes32) _blockParams) returns()
func (_ShastaAnchor *ShastaAnchorSession) Anchor(_proposalParams AnchorProposalParams, _blockParams AnchorBlockParams) (*types.Transaction, error) {
	return _ShastaAnchor.Contract.Anchor(&_ShastaAnchor.TransactOpts, _proposalParams, _blockParams)
}

// Anchor is a paid mutator transaction binding the contract method 0xc9f115bc.
//
// Solidity: function anchor((uint48,address,bytes,bytes32,(uint48,uint8,address,address)[]) _proposalParams, (uint16,uint48,bytes32,bytes32) _blockParams) returns()
func (_ShastaAnchor *ShastaAnchorTransactorSession) Anchor(_proposalParams AnchorProposalParams, _blockParams AnchorBlockParams) (*types.Transaction, error) {
	return _ShastaAnchor.Contract.Anchor(&_ShastaAnchor.TransactOpts, _proposalParams, _blockParams)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_ShastaAnchor *ShastaAnchorTransactor) Init(opts *bind.TransactOpts, _owner common.Address) (*types.Transaction, error) {
	return _ShastaAnchor.contract.Transact(opts, "init", _owner)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_ShastaAnchor *ShastaAnchorSession) Init(_owner common.Address) (*types.Transaction, error) {
	return _ShastaAnchor.Contract.Init(&_ShastaAnchor.TransactOpts, _owner)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_ShastaAnchor *ShastaAnchorTransactorSession) Init(_owner common.Address) (*types.Transaction, error) {
	return _ShastaAnchor.Contract.Init(&_ShastaAnchor.TransactOpts, _owner)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_ShastaAnchor *ShastaAnchorTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ShastaAnchor.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_ShastaAnchor *ShastaAnchorSession) Pause() (*types.Transaction, error) {
	return _ShastaAnchor.Contract.Pause(&_ShastaAnchor.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_ShastaAnchor *ShastaAnchorTransactorSession) Pause() (*types.Transaction, error) {
	return _ShastaAnchor.Contract.Pause(&_ShastaAnchor.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ShastaAnchor *ShastaAnchorTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ShastaAnchor.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ShastaAnchor *ShastaAnchorSession) RenounceOwnership() (*types.Transaction, error) {
	return _ShastaAnchor.Contract.RenounceOwnership(&_ShastaAnchor.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ShastaAnchor *ShastaAnchorTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _ShastaAnchor.Contract.RenounceOwnership(&_ShastaAnchor.TransactOpts)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ShastaAnchor *ShastaAnchorTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _ShastaAnchor.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ShastaAnchor *ShastaAnchorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _ShastaAnchor.Contract.TransferOwnership(&_ShastaAnchor.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ShastaAnchor *ShastaAnchorTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _ShastaAnchor.Contract.TransferOwnership(&_ShastaAnchor.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_ShastaAnchor *ShastaAnchorTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ShastaAnchor.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_ShastaAnchor *ShastaAnchorSession) Unpause() (*types.Transaction, error) {
	return _ShastaAnchor.Contract.Unpause(&_ShastaAnchor.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_ShastaAnchor *ShastaAnchorTransactorSession) Unpause() (*types.Transaction, error) {
	return _ShastaAnchor.Contract.Unpause(&_ShastaAnchor.TransactOpts)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_ShastaAnchor *ShastaAnchorTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _ShastaAnchor.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_ShastaAnchor *ShastaAnchorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _ShastaAnchor.Contract.UpgradeTo(&_ShastaAnchor.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_ShastaAnchor *ShastaAnchorTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _ShastaAnchor.Contract.UpgradeTo(&_ShastaAnchor.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_ShastaAnchor *ShastaAnchorTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _ShastaAnchor.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_ShastaAnchor *ShastaAnchorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _ShastaAnchor.Contract.UpgradeToAndCall(&_ShastaAnchor.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_ShastaAnchor *ShastaAnchorTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _ShastaAnchor.Contract.UpgradeToAndCall(&_ShastaAnchor.TransactOpts, newImplementation, data)
}

// Withdraw is a paid mutator transaction binding the contract method 0xf940e385.
//
// Solidity: function withdraw(address _token, address _to) returns()
func (_ShastaAnchor *ShastaAnchorTransactor) Withdraw(opts *bind.TransactOpts, _token common.Address, _to common.Address) (*types.Transaction, error) {
	return _ShastaAnchor.contract.Transact(opts, "withdraw", _token, _to)
}

// Withdraw is a paid mutator transaction binding the contract method 0xf940e385.
//
// Solidity: function withdraw(address _token, address _to) returns()
func (_ShastaAnchor *ShastaAnchorSession) Withdraw(_token common.Address, _to common.Address) (*types.Transaction, error) {
	return _ShastaAnchor.Contract.Withdraw(&_ShastaAnchor.TransactOpts, _token, _to)
}

// Withdraw is a paid mutator transaction binding the contract method 0xf940e385.
//
// Solidity: function withdraw(address _token, address _to) returns()
func (_ShastaAnchor *ShastaAnchorTransactorSession) Withdraw(_token common.Address, _to common.Address) (*types.Transaction, error) {
	return _ShastaAnchor.Contract.Withdraw(&_ShastaAnchor.TransactOpts, _token, _to)
}

// ShastaAnchorAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the ShastaAnchor contract.
type ShastaAnchorAdminChangedIterator struct {
	Event *ShastaAnchorAdminChanged // Event containing the contract specifics and raw log

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
func (it *ShastaAnchorAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaAnchorAdminChanged)
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
		it.Event = new(ShastaAnchorAdminChanged)
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
func (it *ShastaAnchorAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaAnchorAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaAnchorAdminChanged represents a AdminChanged event raised by the ShastaAnchor contract.
type ShastaAnchorAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_ShastaAnchor *ShastaAnchorFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*ShastaAnchorAdminChangedIterator, error) {

	logs, sub, err := _ShastaAnchor.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &ShastaAnchorAdminChangedIterator{contract: _ShastaAnchor.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_ShastaAnchor *ShastaAnchorFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *ShastaAnchorAdminChanged) (event.Subscription, error) {

	logs, sub, err := _ShastaAnchor.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaAnchorAdminChanged)
				if err := _ShastaAnchor.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_ShastaAnchor *ShastaAnchorFilterer) ParseAdminChanged(log types.Log) (*ShastaAnchorAdminChanged, error) {
	event := new(ShastaAnchorAdminChanged)
	if err := _ShastaAnchor.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ShastaAnchorAnchoredIterator is returned from FilterAnchored and is used to iterate over the raw logs and unpacked data for Anchored events raised by the ShastaAnchor contract.
type ShastaAnchorAnchoredIterator struct {
	Event *ShastaAnchorAnchored // Event containing the contract specifics and raw log

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
func (it *ShastaAnchorAnchoredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaAnchorAnchored)
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
		it.Event = new(ShastaAnchorAnchored)
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
func (it *ShastaAnchorAnchoredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaAnchorAnchoredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaAnchorAnchored represents a Anchored event raised by the ShastaAnchor contract.
type ShastaAnchorAnchored struct {
	BondInstructionsHash [32]byte
	DesignatedProver     common.Address
	IsLowBondProposal    bool
	AnchorBlockNumber    *big.Int
	AncestorsHash        [32]byte
	Raw                  types.Log // Blockchain specific contextual infos
}

// FilterAnchored is a free log retrieval operation binding the contract event 0xabe1ab2ba22c672adbc29e35de36db78e8b2d2ce5d60026329d52da5f31e9734.
//
// Solidity: event Anchored(bytes32 bondInstructionsHash, address designatedProver, bool isLowBondProposal, uint48 anchorBlockNumber, bytes32 ancestorsHash)
func (_ShastaAnchor *ShastaAnchorFilterer) FilterAnchored(opts *bind.FilterOpts) (*ShastaAnchorAnchoredIterator, error) {

	logs, sub, err := _ShastaAnchor.contract.FilterLogs(opts, "Anchored")
	if err != nil {
		return nil, err
	}
	return &ShastaAnchorAnchoredIterator{contract: _ShastaAnchor.contract, event: "Anchored", logs: logs, sub: sub}, nil
}

// WatchAnchored is a free log subscription operation binding the contract event 0xabe1ab2ba22c672adbc29e35de36db78e8b2d2ce5d60026329d52da5f31e9734.
//
// Solidity: event Anchored(bytes32 bondInstructionsHash, address designatedProver, bool isLowBondProposal, uint48 anchorBlockNumber, bytes32 ancestorsHash)
func (_ShastaAnchor *ShastaAnchorFilterer) WatchAnchored(opts *bind.WatchOpts, sink chan<- *ShastaAnchorAnchored) (event.Subscription, error) {

	logs, sub, err := _ShastaAnchor.contract.WatchLogs(opts, "Anchored")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaAnchorAnchored)
				if err := _ShastaAnchor.contract.UnpackLog(event, "Anchored", log); err != nil {
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

// ParseAnchored is a log parse operation binding the contract event 0xabe1ab2ba22c672adbc29e35de36db78e8b2d2ce5d60026329d52da5f31e9734.
//
// Solidity: event Anchored(bytes32 bondInstructionsHash, address designatedProver, bool isLowBondProposal, uint48 anchorBlockNumber, bytes32 ancestorsHash)
func (_ShastaAnchor *ShastaAnchorFilterer) ParseAnchored(log types.Log) (*ShastaAnchorAnchored, error) {
	event := new(ShastaAnchorAnchored)
	if err := _ShastaAnchor.contract.UnpackLog(event, "Anchored", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ShastaAnchorBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the ShastaAnchor contract.
type ShastaAnchorBeaconUpgradedIterator struct {
	Event *ShastaAnchorBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *ShastaAnchorBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaAnchorBeaconUpgraded)
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
		it.Event = new(ShastaAnchorBeaconUpgraded)
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
func (it *ShastaAnchorBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaAnchorBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaAnchorBeaconUpgraded represents a BeaconUpgraded event raised by the ShastaAnchor contract.
type ShastaAnchorBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_ShastaAnchor *ShastaAnchorFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*ShastaAnchorBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _ShastaAnchor.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &ShastaAnchorBeaconUpgradedIterator{contract: _ShastaAnchor.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_ShastaAnchor *ShastaAnchorFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *ShastaAnchorBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _ShastaAnchor.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaAnchorBeaconUpgraded)
				if err := _ShastaAnchor.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_ShastaAnchor *ShastaAnchorFilterer) ParseBeaconUpgraded(log types.Log) (*ShastaAnchorBeaconUpgraded, error) {
	event := new(ShastaAnchorBeaconUpgraded)
	if err := _ShastaAnchor.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ShastaAnchorInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the ShastaAnchor contract.
type ShastaAnchorInitializedIterator struct {
	Event *ShastaAnchorInitialized // Event containing the contract specifics and raw log

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
func (it *ShastaAnchorInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaAnchorInitialized)
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
		it.Event = new(ShastaAnchorInitialized)
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
func (it *ShastaAnchorInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaAnchorInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaAnchorInitialized represents a Initialized event raised by the ShastaAnchor contract.
type ShastaAnchorInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_ShastaAnchor *ShastaAnchorFilterer) FilterInitialized(opts *bind.FilterOpts) (*ShastaAnchorInitializedIterator, error) {

	logs, sub, err := _ShastaAnchor.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &ShastaAnchorInitializedIterator{contract: _ShastaAnchor.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_ShastaAnchor *ShastaAnchorFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *ShastaAnchorInitialized) (event.Subscription, error) {

	logs, sub, err := _ShastaAnchor.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaAnchorInitialized)
				if err := _ShastaAnchor.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_ShastaAnchor *ShastaAnchorFilterer) ParseInitialized(log types.Log) (*ShastaAnchorInitialized, error) {
	event := new(ShastaAnchorInitialized)
	if err := _ShastaAnchor.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ShastaAnchorOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the ShastaAnchor contract.
type ShastaAnchorOwnershipTransferStartedIterator struct {
	Event *ShastaAnchorOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *ShastaAnchorOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaAnchorOwnershipTransferStarted)
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
		it.Event = new(ShastaAnchorOwnershipTransferStarted)
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
func (it *ShastaAnchorOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaAnchorOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaAnchorOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the ShastaAnchor contract.
type ShastaAnchorOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_ShastaAnchor *ShastaAnchorFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*ShastaAnchorOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ShastaAnchor.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &ShastaAnchorOwnershipTransferStartedIterator{contract: _ShastaAnchor.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_ShastaAnchor *ShastaAnchorFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *ShastaAnchorOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ShastaAnchor.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaAnchorOwnershipTransferStarted)
				if err := _ShastaAnchor.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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
func (_ShastaAnchor *ShastaAnchorFilterer) ParseOwnershipTransferStarted(log types.Log) (*ShastaAnchorOwnershipTransferStarted, error) {
	event := new(ShastaAnchorOwnershipTransferStarted)
	if err := _ShastaAnchor.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ShastaAnchorOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the ShastaAnchor contract.
type ShastaAnchorOwnershipTransferredIterator struct {
	Event *ShastaAnchorOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *ShastaAnchorOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaAnchorOwnershipTransferred)
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
		it.Event = new(ShastaAnchorOwnershipTransferred)
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
func (it *ShastaAnchorOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaAnchorOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaAnchorOwnershipTransferred represents a OwnershipTransferred event raised by the ShastaAnchor contract.
type ShastaAnchorOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_ShastaAnchor *ShastaAnchorFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*ShastaAnchorOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ShastaAnchor.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &ShastaAnchorOwnershipTransferredIterator{contract: _ShastaAnchor.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_ShastaAnchor *ShastaAnchorFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *ShastaAnchorOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ShastaAnchor.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaAnchorOwnershipTransferred)
				if err := _ShastaAnchor.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_ShastaAnchor *ShastaAnchorFilterer) ParseOwnershipTransferred(log types.Log) (*ShastaAnchorOwnershipTransferred, error) {
	event := new(ShastaAnchorOwnershipTransferred)
	if err := _ShastaAnchor.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ShastaAnchorPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the ShastaAnchor contract.
type ShastaAnchorPausedIterator struct {
	Event *ShastaAnchorPaused // Event containing the contract specifics and raw log

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
func (it *ShastaAnchorPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaAnchorPaused)
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
		it.Event = new(ShastaAnchorPaused)
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
func (it *ShastaAnchorPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaAnchorPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaAnchorPaused represents a Paused event raised by the ShastaAnchor contract.
type ShastaAnchorPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_ShastaAnchor *ShastaAnchorFilterer) FilterPaused(opts *bind.FilterOpts) (*ShastaAnchorPausedIterator, error) {

	logs, sub, err := _ShastaAnchor.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &ShastaAnchorPausedIterator{contract: _ShastaAnchor.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_ShastaAnchor *ShastaAnchorFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *ShastaAnchorPaused) (event.Subscription, error) {

	logs, sub, err := _ShastaAnchor.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaAnchorPaused)
				if err := _ShastaAnchor.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_ShastaAnchor *ShastaAnchorFilterer) ParsePaused(log types.Log) (*ShastaAnchorPaused, error) {
	event := new(ShastaAnchorPaused)
	if err := _ShastaAnchor.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ShastaAnchorUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the ShastaAnchor contract.
type ShastaAnchorUnpausedIterator struct {
	Event *ShastaAnchorUnpaused // Event containing the contract specifics and raw log

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
func (it *ShastaAnchorUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaAnchorUnpaused)
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
		it.Event = new(ShastaAnchorUnpaused)
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
func (it *ShastaAnchorUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaAnchorUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaAnchorUnpaused represents a Unpaused event raised by the ShastaAnchor contract.
type ShastaAnchorUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_ShastaAnchor *ShastaAnchorFilterer) FilterUnpaused(opts *bind.FilterOpts) (*ShastaAnchorUnpausedIterator, error) {

	logs, sub, err := _ShastaAnchor.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &ShastaAnchorUnpausedIterator{contract: _ShastaAnchor.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_ShastaAnchor *ShastaAnchorFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *ShastaAnchorUnpaused) (event.Subscription, error) {

	logs, sub, err := _ShastaAnchor.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaAnchorUnpaused)
				if err := _ShastaAnchor.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_ShastaAnchor *ShastaAnchorFilterer) ParseUnpaused(log types.Log) (*ShastaAnchorUnpaused, error) {
	event := new(ShastaAnchorUnpaused)
	if err := _ShastaAnchor.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ShastaAnchorUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the ShastaAnchor contract.
type ShastaAnchorUpgradedIterator struct {
	Event *ShastaAnchorUpgraded // Event containing the contract specifics and raw log

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
func (it *ShastaAnchorUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaAnchorUpgraded)
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
		it.Event = new(ShastaAnchorUpgraded)
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
func (it *ShastaAnchorUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaAnchorUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaAnchorUpgraded represents a Upgraded event raised by the ShastaAnchor contract.
type ShastaAnchorUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_ShastaAnchor *ShastaAnchorFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*ShastaAnchorUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _ShastaAnchor.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &ShastaAnchorUpgradedIterator{contract: _ShastaAnchor.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_ShastaAnchor *ShastaAnchorFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *ShastaAnchorUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _ShastaAnchor.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaAnchorUpgraded)
				if err := _ShastaAnchor.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_ShastaAnchor *ShastaAnchorFilterer) ParseUpgraded(log types.Log) (*ShastaAnchorUpgraded, error) {
	event := new(ShastaAnchorUpgraded)
	if err := _ShastaAnchor.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ShastaAnchorWithdrawnIterator is returned from FilterWithdrawn and is used to iterate over the raw logs and unpacked data for Withdrawn events raised by the ShastaAnchor contract.
type ShastaAnchorWithdrawnIterator struct {
	Event *ShastaAnchorWithdrawn // Event containing the contract specifics and raw log

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
func (it *ShastaAnchorWithdrawnIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ShastaAnchorWithdrawn)
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
		it.Event = new(ShastaAnchorWithdrawn)
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
func (it *ShastaAnchorWithdrawnIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ShastaAnchorWithdrawnIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ShastaAnchorWithdrawn represents a Withdrawn event raised by the ShastaAnchor contract.
type ShastaAnchorWithdrawn struct {
	Token  common.Address
	To     common.Address
	Amount *big.Int
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterWithdrawn is a free log retrieval operation binding the contract event 0xd1c19fbcd4551a5edfb66d43d2e337c04837afda3482b42bdf569a8fccdae5fb.
//
// Solidity: event Withdrawn(address token, address to, uint256 amount)
func (_ShastaAnchor *ShastaAnchorFilterer) FilterWithdrawn(opts *bind.FilterOpts) (*ShastaAnchorWithdrawnIterator, error) {

	logs, sub, err := _ShastaAnchor.contract.FilterLogs(opts, "Withdrawn")
	if err != nil {
		return nil, err
	}
	return &ShastaAnchorWithdrawnIterator{contract: _ShastaAnchor.contract, event: "Withdrawn", logs: logs, sub: sub}, nil
}

// WatchWithdrawn is a free log subscription operation binding the contract event 0xd1c19fbcd4551a5edfb66d43d2e337c04837afda3482b42bdf569a8fccdae5fb.
//
// Solidity: event Withdrawn(address token, address to, uint256 amount)
func (_ShastaAnchor *ShastaAnchorFilterer) WatchWithdrawn(opts *bind.WatchOpts, sink chan<- *ShastaAnchorWithdrawn) (event.Subscription, error) {

	logs, sub, err := _ShastaAnchor.contract.WatchLogs(opts, "Withdrawn")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ShastaAnchorWithdrawn)
				if err := _ShastaAnchor.contract.UnpackLog(event, "Withdrawn", log); err != nil {
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

// ParseWithdrawn is a log parse operation binding the contract event 0xd1c19fbcd4551a5edfb66d43d2e337c04837afda3482b42bdf569a8fccdae5fb.
//
// Solidity: event Withdrawn(address token, address to, uint256 amount)
func (_ShastaAnchor *ShastaAnchorFilterer) ParseWithdrawn(log types.Log) (*ShastaAnchorWithdrawn, error) {
	event := new(ShastaAnchorWithdrawn)
	if err := _ShastaAnchor.contract.UnpackLog(event, "Withdrawn", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
