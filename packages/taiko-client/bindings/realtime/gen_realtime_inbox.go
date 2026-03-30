// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package realtime

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

// ICheckpointStoreCheckpoint is an auto generated low-level Go binding around an user-defined struct.
type ICheckpointStoreCheckpoint struct {
	BlockNumber *big.Int
	BlockHash   [32]byte
	StateRoot   [32]byte
}

// IInboxDerivationSource is an auto generated low-level Go binding around an user-defined struct.
type IInboxDerivationSource struct {
	IsForcedInclusion bool
	BlobSlice         LibBlobsBlobSlice
}

// IRealTimeInboxCommitment is an auto generated low-level Go binding around an user-defined struct.
type IRealTimeInboxCommitment struct {
	ProposalHash           [32]byte
	LastFinalizedBlockHash [32]byte
	Checkpoint             ICheckpointStoreCheckpoint
}

// IRealTimeInboxConfig is an auto generated low-level Go binding around an user-defined struct.
type IRealTimeInboxConfig struct {
	ProofVerifier      common.Address
	SignalService      common.Address
	BasefeeSharingPctg uint8
}

// IRealTimeInboxProposal is an auto generated low-level Go binding around an user-defined struct.
type IRealTimeInboxProposal struct {
	MaxAnchorBlockNumber *big.Int
	MaxAnchorBlockHash   [32]byte
	BasefeeSharingPctg   uint8
	Sources              []IInboxDerivationSource
	SignalSlotsHash      [32]byte
}

// IRealTimeInboxProposeInput is an auto generated low-level Go binding around an user-defined struct.
type IRealTimeInboxProposeInput struct {
	BlobReference        LibBlobsBlobReference
	SignalSlots          [][32]byte
	MaxAnchorBlockNumber *big.Int
}

// LibBlobsBlobReference is an auto generated low-level Go binding around an user-defined struct.
type LibBlobsBlobReference struct {
	BlobStartIndex uint16
	NumBlobs       uint16
	Offset         *big.Int
}

// LibBlobsBlobSlice is an auto generated low-level Go binding around an user-defined struct.
type LibBlobsBlobSlice struct {
	BlobHashes [][32]byte
	Offset     *big.Int
	Timestamp  *big.Int
}

// RealTimeInboxClientMetaData contains all meta data concerning the RealTimeInboxClient contract.
var RealTimeInboxClientMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"constructor\",\"inputs\":[{\"name\":\"_config\",\"type\":\"tuple\",\"internalType\":\"structIRealTimeInbox.Config\",\"components\":[{\"name\":\"proofVerifier\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"signalService\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"}]}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"activate\",\"inputs\":[{\"name\":\"_genesisBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"decodeProposeInput\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"input_\",\"type\":\"tuple\",\"internalType\":\"structIRealTimeInbox.ProposeInput\",\"components\":[{\"name\":\"blobReference\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobReference\",\"components\":[{\"name\":\"blobStartIndex\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"numBlobs\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"}]},{\"name\":\"signalSlots\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"maxAnchorBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"encodeProposeInput\",\"inputs\":[{\"name\":\"_input\",\"type\":\"tuple\",\"internalType\":\"structIRealTimeInbox.ProposeInput\",\"components\":[{\"name\":\"blobReference\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobReference\",\"components\":[{\"name\":\"blobStartIndex\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"numBlobs\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"}]},{\"name\":\"signalSlots\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"maxAnchorBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}],\"outputs\":[{\"name\":\"encoded_\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"getConfig\",\"inputs\":[],\"outputs\":[{\"name\":\"config_\",\"type\":\"tuple\",\"internalType\":\"structIRealTimeInbox.Config\",\"components\":[{\"name\":\"proofVerifier\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"signalService\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getLastFinalizedBlockHash\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"hashCommitment\",\"inputs\":[{\"name\":\"_commitment\",\"type\":\"tuple\",\"internalType\":\"structIRealTimeInbox.Commitment\",\"components\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"lastFinalizedBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashProposal\",\"inputs\":[{\"name\":\"_proposal\",\"type\":\"tuple\",\"internalType\":\"structIRealTimeInbox.Proposal\",\"components\":[{\"name\":\"maxAnchorBlockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"maxAnchorBlockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"sources\",\"type\":\"tuple[]\",\"internalType\":\"structIInbox.DerivationSource[]\",\"components\":[{\"name\":\"isForcedInclusion\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]},{\"name\":\"signalSlotsHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"hashSignalSlots\",\"inputs\":[{\"name\":\"_signalSlots\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"impl\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"inNonReentrant\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"lastFinalizedBlockHash\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"propose\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"_checkpoint\",\"type\":\"tuple\",\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"_proof\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolver\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"event\",\"name\":\"Activated\",\"inputs\":[{\"name\":\"genesisBlockHash\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"ProposedAndProved\",\"inputs\":[{\"name\":\"proposalHash\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"lastFinalizedBlockHash\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"maxAnchorBlockNumber\",\"type\":\"uint48\",\"indexed\":false,\"internalType\":\"uint48\"},{\"name\":\"basefeeSharingPctg\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"},{\"name\":\"sources\",\"type\":\"tuple[]\",\"indexed\":false,\"internalType\":\"structIInbox.DerivationSource[]\",\"components\":[{\"name\":\"isForcedInclusion\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"blobSlice\",\"type\":\"tuple\",\"internalType\":\"structLibBlobs.BlobSlice\",\"components\":[{\"name\":\"blobHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"offset\",\"type\":\"uint24\",\"internalType\":\"uint24\"},{\"name\":\"timestamp\",\"type\":\"uint48\",\"internalType\":\"uint48\"}]}]},{\"name\":\"signalSlots\",\"type\":\"bytes32[]\",\"indexed\":false,\"internalType\":\"bytes32[]\"},{\"name\":\"checkpoint\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structICheckpointStore.Checkpoint\",\"components\":[{\"name\":\"blockNumber\",\"type\":\"uint48\",\"internalType\":\"uint48\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ACCESS_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"AlreadyActivated\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"BlobNotFound\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"FUNC_NOT_IMPLEMENTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"InvalidGenesisBlockHash\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"MaxAnchorBlockTooOld\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NoBlobs\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"NotActivated\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SignalSlotNotSent\",\"inputs\":[{\"name\":\"slot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"type\":\"error\",\"name\":\"ZERO_ADDRESS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_VALUE\",\"inputs\":[]}]",
}

// RealTimeInboxClientABI is the input ABI used to generate the binding from.
// Deprecated: Use RealTimeInboxClientMetaData.ABI instead.
var RealTimeInboxClientABI = RealTimeInboxClientMetaData.ABI

// RealTimeInboxClient is an auto generated Go binding around an Ethereum contract.
type RealTimeInboxClient struct {
	RealTimeInboxClientCaller     // Read-only binding to the contract
	RealTimeInboxClientTransactor // Write-only binding to the contract
	RealTimeInboxClientFilterer   // Log filterer for contract events
}

// RealTimeInboxClientCaller is an auto generated read-only Go binding around an Ethereum contract.
type RealTimeInboxClientCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// RealTimeInboxClientTransactor is an auto generated write-only Go binding around an Ethereum contract.
type RealTimeInboxClientTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// RealTimeInboxClientFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type RealTimeInboxClientFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// RealTimeInboxClientSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type RealTimeInboxClientSession struct {
	Contract     *RealTimeInboxClient // Generic contract binding to set the session for
	CallOpts     bind.CallOpts        // Call options to use throughout this session
	TransactOpts bind.TransactOpts    // Transaction auth options to use throughout this session
}

// RealTimeInboxClientCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type RealTimeInboxClientCallerSession struct {
	Contract *RealTimeInboxClientCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts              // Call options to use throughout this session
}

// RealTimeInboxClientTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type RealTimeInboxClientTransactorSession struct {
	Contract     *RealTimeInboxClientTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts              // Transaction auth options to use throughout this session
}

// RealTimeInboxClientRaw is an auto generated low-level Go binding around an Ethereum contract.
type RealTimeInboxClientRaw struct {
	Contract *RealTimeInboxClient // Generic contract binding to access the raw methods on
}

// RealTimeInboxClientCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type RealTimeInboxClientCallerRaw struct {
	Contract *RealTimeInboxClientCaller // Generic read-only contract binding to access the raw methods on
}

// RealTimeInboxClientTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type RealTimeInboxClientTransactorRaw struct {
	Contract *RealTimeInboxClientTransactor // Generic write-only contract binding to access the raw methods on
}

// NewRealTimeInboxClient creates a new instance of RealTimeInboxClient, bound to a specific deployed contract.
func NewRealTimeInboxClient(address common.Address, backend bind.ContractBackend) (*RealTimeInboxClient, error) {
	contract, err := bindRealTimeInboxClient(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &RealTimeInboxClient{RealTimeInboxClientCaller: RealTimeInboxClientCaller{contract: contract}, RealTimeInboxClientTransactor: RealTimeInboxClientTransactor{contract: contract}, RealTimeInboxClientFilterer: RealTimeInboxClientFilterer{contract: contract}}, nil
}

// NewRealTimeInboxClientCaller creates a new read-only instance of RealTimeInboxClient, bound to a specific deployed contract.
func NewRealTimeInboxClientCaller(address common.Address, caller bind.ContractCaller) (*RealTimeInboxClientCaller, error) {
	contract, err := bindRealTimeInboxClient(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &RealTimeInboxClientCaller{contract: contract}, nil
}

// NewRealTimeInboxClientTransactor creates a new write-only instance of RealTimeInboxClient, bound to a specific deployed contract.
func NewRealTimeInboxClientTransactor(address common.Address, transactor bind.ContractTransactor) (*RealTimeInboxClientTransactor, error) {
	contract, err := bindRealTimeInboxClient(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &RealTimeInboxClientTransactor{contract: contract}, nil
}

// NewRealTimeInboxClientFilterer creates a new log filterer instance of RealTimeInboxClient, bound to a specific deployed contract.
func NewRealTimeInboxClientFilterer(address common.Address, filterer bind.ContractFilterer) (*RealTimeInboxClientFilterer, error) {
	contract, err := bindRealTimeInboxClient(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &RealTimeInboxClientFilterer{contract: contract}, nil
}

// bindRealTimeInboxClient binds a generic wrapper to an already deployed contract.
func bindRealTimeInboxClient(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := RealTimeInboxClientMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_RealTimeInboxClient *RealTimeInboxClientRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _RealTimeInboxClient.Contract.RealTimeInboxClientCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_RealTimeInboxClient *RealTimeInboxClientRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _RealTimeInboxClient.Contract.RealTimeInboxClientTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_RealTimeInboxClient *RealTimeInboxClientRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _RealTimeInboxClient.Contract.RealTimeInboxClientTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_RealTimeInboxClient *RealTimeInboxClientCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _RealTimeInboxClient.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_RealTimeInboxClient *RealTimeInboxClientTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _RealTimeInboxClient.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_RealTimeInboxClient *RealTimeInboxClientTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _RealTimeInboxClient.Contract.contract.Transact(opts, method, params...)
}

// DecodeProposeInput is a free data retrieval call binding the contract method 0xafb63ad4.
//
// Solidity: function decodeProposeInput(bytes _data) pure returns(((uint16,uint16,uint24),bytes32[],uint48) input_)
func (_RealTimeInboxClient *RealTimeInboxClientCaller) DecodeProposeInput(opts *bind.CallOpts, _data []byte) (IRealTimeInboxProposeInput, error) {
	var out []interface{}
	err := _RealTimeInboxClient.contract.Call(opts, &out, "decodeProposeInput", _data)

	if err != nil {
		return *new(IRealTimeInboxProposeInput), err
	}

	out0 := *abi.ConvertType(out[0], new(IRealTimeInboxProposeInput)).(*IRealTimeInboxProposeInput)

	return out0, err

}

// DecodeProposeInput is a free data retrieval call binding the contract method 0xafb63ad4.
//
// Solidity: function decodeProposeInput(bytes _data) pure returns(((uint16,uint16,uint24),bytes32[],uint48) input_)
func (_RealTimeInboxClient *RealTimeInboxClientSession) DecodeProposeInput(_data []byte) (IRealTimeInboxProposeInput, error) {
	return _RealTimeInboxClient.Contract.DecodeProposeInput(&_RealTimeInboxClient.CallOpts, _data)
}

// DecodeProposeInput is a free data retrieval call binding the contract method 0xafb63ad4.
//
// Solidity: function decodeProposeInput(bytes _data) pure returns(((uint16,uint16,uint24),bytes32[],uint48) input_)
func (_RealTimeInboxClient *RealTimeInboxClientCallerSession) DecodeProposeInput(_data []byte) (IRealTimeInboxProposeInput, error) {
	return _RealTimeInboxClient.Contract.DecodeProposeInput(&_RealTimeInboxClient.CallOpts, _data)
}

// EncodeProposeInput is a free data retrieval call binding the contract method 0x0cf2cafa.
//
// Solidity: function encodeProposeInput(((uint16,uint16,uint24),bytes32[],uint48) _input) pure returns(bytes encoded_)
func (_RealTimeInboxClient *RealTimeInboxClientCaller) EncodeProposeInput(opts *bind.CallOpts, _input IRealTimeInboxProposeInput) ([]byte, error) {
	var out []interface{}
	err := _RealTimeInboxClient.contract.Call(opts, &out, "encodeProposeInput", _input)

	if err != nil {
		return *new([]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([]byte)).(*[]byte)

	return out0, err

}

// EncodeProposeInput is a free data retrieval call binding the contract method 0x0cf2cafa.
//
// Solidity: function encodeProposeInput(((uint16,uint16,uint24),bytes32[],uint48) _input) pure returns(bytes encoded_)
func (_RealTimeInboxClient *RealTimeInboxClientSession) EncodeProposeInput(_input IRealTimeInboxProposeInput) ([]byte, error) {
	return _RealTimeInboxClient.Contract.EncodeProposeInput(&_RealTimeInboxClient.CallOpts, _input)
}

// EncodeProposeInput is a free data retrieval call binding the contract method 0x0cf2cafa.
//
// Solidity: function encodeProposeInput(((uint16,uint16,uint24),bytes32[],uint48) _input) pure returns(bytes encoded_)
func (_RealTimeInboxClient *RealTimeInboxClientCallerSession) EncodeProposeInput(_input IRealTimeInboxProposeInput) ([]byte, error) {
	return _RealTimeInboxClient.Contract.EncodeProposeInput(&_RealTimeInboxClient.CallOpts, _input)
}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() view returns((address,address,uint8) config_)
func (_RealTimeInboxClient *RealTimeInboxClientCaller) GetConfig(opts *bind.CallOpts) (IRealTimeInboxConfig, error) {
	var out []interface{}
	err := _RealTimeInboxClient.contract.Call(opts, &out, "getConfig")

	if err != nil {
		return *new(IRealTimeInboxConfig), err
	}

	out0 := *abi.ConvertType(out[0], new(IRealTimeInboxConfig)).(*IRealTimeInboxConfig)

	return out0, err

}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() view returns((address,address,uint8) config_)
func (_RealTimeInboxClient *RealTimeInboxClientSession) GetConfig() (IRealTimeInboxConfig, error) {
	return _RealTimeInboxClient.Contract.GetConfig(&_RealTimeInboxClient.CallOpts)
}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() view returns((address,address,uint8) config_)
func (_RealTimeInboxClient *RealTimeInboxClientCallerSession) GetConfig() (IRealTimeInboxConfig, error) {
	return _RealTimeInboxClient.Contract.GetConfig(&_RealTimeInboxClient.CallOpts)
}

// GetLastFinalizedBlockHash is a free data retrieval call binding the contract method 0x187d4c2c.
//
// Solidity: function getLastFinalizedBlockHash() view returns(bytes32)
func (_RealTimeInboxClient *RealTimeInboxClientCaller) GetLastFinalizedBlockHash(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _RealTimeInboxClient.contract.Call(opts, &out, "getLastFinalizedBlockHash")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetLastFinalizedBlockHash is a free data retrieval call binding the contract method 0x187d4c2c.
//
// Solidity: function getLastFinalizedBlockHash() view returns(bytes32)
func (_RealTimeInboxClient *RealTimeInboxClientSession) GetLastFinalizedBlockHash() ([32]byte, error) {
	return _RealTimeInboxClient.Contract.GetLastFinalizedBlockHash(&_RealTimeInboxClient.CallOpts)
}

// GetLastFinalizedBlockHash is a free data retrieval call binding the contract method 0x187d4c2c.
//
// Solidity: function getLastFinalizedBlockHash() view returns(bytes32)
func (_RealTimeInboxClient *RealTimeInboxClientCallerSession) GetLastFinalizedBlockHash() ([32]byte, error) {
	return _RealTimeInboxClient.Contract.GetLastFinalizedBlockHash(&_RealTimeInboxClient.CallOpts)
}

// HashCommitment is a free data retrieval call binding the contract method 0xb8eff75b.
//
// Solidity: function hashCommitment((bytes32,bytes32,(uint48,bytes32,bytes32)) _commitment) pure returns(bytes32)
func (_RealTimeInboxClient *RealTimeInboxClientCaller) HashCommitment(opts *bind.CallOpts, _commitment IRealTimeInboxCommitment) ([32]byte, error) {
	var out []interface{}
	err := _RealTimeInboxClient.contract.Call(opts, &out, "hashCommitment", _commitment)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashCommitment is a free data retrieval call binding the contract method 0xb8eff75b.
//
// Solidity: function hashCommitment((bytes32,bytes32,(uint48,bytes32,bytes32)) _commitment) pure returns(bytes32)
func (_RealTimeInboxClient *RealTimeInboxClientSession) HashCommitment(_commitment IRealTimeInboxCommitment) ([32]byte, error) {
	return _RealTimeInboxClient.Contract.HashCommitment(&_RealTimeInboxClient.CallOpts, _commitment)
}

// HashCommitment is a free data retrieval call binding the contract method 0xb8eff75b.
//
// Solidity: function hashCommitment((bytes32,bytes32,(uint48,bytes32,bytes32)) _commitment) pure returns(bytes32)
func (_RealTimeInboxClient *RealTimeInboxClientCallerSession) HashCommitment(_commitment IRealTimeInboxCommitment) ([32]byte, error) {
	return _RealTimeInboxClient.Contract.HashCommitment(&_RealTimeInboxClient.CallOpts, _commitment)
}

// HashProposal is a free data retrieval call binding the contract method 0x2f5f1d61.
//
// Solidity: function hashProposal((uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[],bytes32) _proposal) pure returns(bytes32)
func (_RealTimeInboxClient *RealTimeInboxClientCaller) HashProposal(opts *bind.CallOpts, _proposal IRealTimeInboxProposal) ([32]byte, error) {
	var out []interface{}
	err := _RealTimeInboxClient.contract.Call(opts, &out, "hashProposal", _proposal)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashProposal is a free data retrieval call binding the contract method 0x2f5f1d61.
//
// Solidity: function hashProposal((uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[],bytes32) _proposal) pure returns(bytes32)
func (_RealTimeInboxClient *RealTimeInboxClientSession) HashProposal(_proposal IRealTimeInboxProposal) ([32]byte, error) {
	return _RealTimeInboxClient.Contract.HashProposal(&_RealTimeInboxClient.CallOpts, _proposal)
}

// HashProposal is a free data retrieval call binding the contract method 0x2f5f1d61.
//
// Solidity: function hashProposal((uint48,bytes32,uint8,(bool,(bytes32[],uint24,uint48))[],bytes32) _proposal) pure returns(bytes32)
func (_RealTimeInboxClient *RealTimeInboxClientCallerSession) HashProposal(_proposal IRealTimeInboxProposal) ([32]byte, error) {
	return _RealTimeInboxClient.Contract.HashProposal(&_RealTimeInboxClient.CallOpts, _proposal)
}

// HashSignalSlots is a free data retrieval call binding the contract method 0x6fa5c006.
//
// Solidity: function hashSignalSlots(bytes32[] _signalSlots) pure returns(bytes32)
func (_RealTimeInboxClient *RealTimeInboxClientCaller) HashSignalSlots(opts *bind.CallOpts, _signalSlots [][32]byte) ([32]byte, error) {
	var out []interface{}
	err := _RealTimeInboxClient.contract.Call(opts, &out, "hashSignalSlots", _signalSlots)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashSignalSlots is a free data retrieval call binding the contract method 0x6fa5c006.
//
// Solidity: function hashSignalSlots(bytes32[] _signalSlots) pure returns(bytes32)
func (_RealTimeInboxClient *RealTimeInboxClientSession) HashSignalSlots(_signalSlots [][32]byte) ([32]byte, error) {
	return _RealTimeInboxClient.Contract.HashSignalSlots(&_RealTimeInboxClient.CallOpts, _signalSlots)
}

// HashSignalSlots is a free data retrieval call binding the contract method 0x6fa5c006.
//
// Solidity: function hashSignalSlots(bytes32[] _signalSlots) pure returns(bytes32)
func (_RealTimeInboxClient *RealTimeInboxClientCallerSession) HashSignalSlots(_signalSlots [][32]byte) ([32]byte, error) {
	return _RealTimeInboxClient.Contract.HashSignalSlots(&_RealTimeInboxClient.CallOpts, _signalSlots)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_RealTimeInboxClient *RealTimeInboxClientCaller) Impl(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _RealTimeInboxClient.contract.Call(opts, &out, "impl")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_RealTimeInboxClient *RealTimeInboxClientSession) Impl() (common.Address, error) {
	return _RealTimeInboxClient.Contract.Impl(&_RealTimeInboxClient.CallOpts)
}

// Impl is a free data retrieval call binding the contract method 0x8abf6077.
//
// Solidity: function impl() view returns(address)
func (_RealTimeInboxClient *RealTimeInboxClientCallerSession) Impl() (common.Address, error) {
	return _RealTimeInboxClient.Contract.Impl(&_RealTimeInboxClient.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_RealTimeInboxClient *RealTimeInboxClientCaller) InNonReentrant(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _RealTimeInboxClient.contract.Call(opts, &out, "inNonReentrant")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_RealTimeInboxClient *RealTimeInboxClientSession) InNonReentrant() (bool, error) {
	return _RealTimeInboxClient.Contract.InNonReentrant(&_RealTimeInboxClient.CallOpts)
}

// InNonReentrant is a free data retrieval call binding the contract method 0x3075db56.
//
// Solidity: function inNonReentrant() view returns(bool)
func (_RealTimeInboxClient *RealTimeInboxClientCallerSession) InNonReentrant() (bool, error) {
	return _RealTimeInboxClient.Contract.InNonReentrant(&_RealTimeInboxClient.CallOpts)
}

// LastFinalizedBlockHash is a free data retrieval call binding the contract method 0x99181bdc.
//
// Solidity: function lastFinalizedBlockHash() view returns(bytes32)
func (_RealTimeInboxClient *RealTimeInboxClientCaller) LastFinalizedBlockHash(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _RealTimeInboxClient.contract.Call(opts, &out, "lastFinalizedBlockHash")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// LastFinalizedBlockHash is a free data retrieval call binding the contract method 0x99181bdc.
//
// Solidity: function lastFinalizedBlockHash() view returns(bytes32)
func (_RealTimeInboxClient *RealTimeInboxClientSession) LastFinalizedBlockHash() ([32]byte, error) {
	return _RealTimeInboxClient.Contract.LastFinalizedBlockHash(&_RealTimeInboxClient.CallOpts)
}

// LastFinalizedBlockHash is a free data retrieval call binding the contract method 0x99181bdc.
//
// Solidity: function lastFinalizedBlockHash() view returns(bytes32)
func (_RealTimeInboxClient *RealTimeInboxClientCallerSession) LastFinalizedBlockHash() ([32]byte, error) {
	return _RealTimeInboxClient.Contract.LastFinalizedBlockHash(&_RealTimeInboxClient.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_RealTimeInboxClient *RealTimeInboxClientCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _RealTimeInboxClient.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_RealTimeInboxClient *RealTimeInboxClientSession) Owner() (common.Address, error) {
	return _RealTimeInboxClient.Contract.Owner(&_RealTimeInboxClient.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_RealTimeInboxClient *RealTimeInboxClientCallerSession) Owner() (common.Address, error) {
	return _RealTimeInboxClient.Contract.Owner(&_RealTimeInboxClient.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_RealTimeInboxClient *RealTimeInboxClientCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _RealTimeInboxClient.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_RealTimeInboxClient *RealTimeInboxClientSession) Paused() (bool, error) {
	return _RealTimeInboxClient.Contract.Paused(&_RealTimeInboxClient.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_RealTimeInboxClient *RealTimeInboxClientCallerSession) Paused() (bool, error) {
	return _RealTimeInboxClient.Contract.Paused(&_RealTimeInboxClient.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_RealTimeInboxClient *RealTimeInboxClientCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _RealTimeInboxClient.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_RealTimeInboxClient *RealTimeInboxClientSession) PendingOwner() (common.Address, error) {
	return _RealTimeInboxClient.Contract.PendingOwner(&_RealTimeInboxClient.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_RealTimeInboxClient *RealTimeInboxClientCallerSession) PendingOwner() (common.Address, error) {
	return _RealTimeInboxClient.Contract.PendingOwner(&_RealTimeInboxClient.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_RealTimeInboxClient *RealTimeInboxClientCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _RealTimeInboxClient.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_RealTimeInboxClient *RealTimeInboxClientSession) ProxiableUUID() ([32]byte, error) {
	return _RealTimeInboxClient.Contract.ProxiableUUID(&_RealTimeInboxClient.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_RealTimeInboxClient *RealTimeInboxClientCallerSession) ProxiableUUID() ([32]byte, error) {
	return _RealTimeInboxClient.Contract.ProxiableUUID(&_RealTimeInboxClient.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_RealTimeInboxClient *RealTimeInboxClientCaller) Resolver(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _RealTimeInboxClient.contract.Call(opts, &out, "resolver")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_RealTimeInboxClient *RealTimeInboxClientSession) Resolver() (common.Address, error) {
	return _RealTimeInboxClient.Contract.Resolver(&_RealTimeInboxClient.CallOpts)
}

// Resolver is a free data retrieval call binding the contract method 0x04f3bcec.
//
// Solidity: function resolver() view returns(address)
func (_RealTimeInboxClient *RealTimeInboxClientCallerSession) Resolver() (common.Address, error) {
	return _RealTimeInboxClient.Contract.Resolver(&_RealTimeInboxClient.CallOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_RealTimeInboxClient *RealTimeInboxClientTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _RealTimeInboxClient.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_RealTimeInboxClient *RealTimeInboxClientSession) AcceptOwnership() (*types.Transaction, error) {
	return _RealTimeInboxClient.Contract.AcceptOwnership(&_RealTimeInboxClient.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_RealTimeInboxClient *RealTimeInboxClientTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _RealTimeInboxClient.Contract.AcceptOwnership(&_RealTimeInboxClient.TransactOpts)
}

// Activate is a paid mutator transaction binding the contract method 0x59db6e85.
//
// Solidity: function activate(bytes32 _genesisBlockHash) returns()
func (_RealTimeInboxClient *RealTimeInboxClientTransactor) Activate(opts *bind.TransactOpts, _genesisBlockHash [32]byte) (*types.Transaction, error) {
	return _RealTimeInboxClient.contract.Transact(opts, "activate", _genesisBlockHash)
}

// Activate is a paid mutator transaction binding the contract method 0x59db6e85.
//
// Solidity: function activate(bytes32 _genesisBlockHash) returns()
func (_RealTimeInboxClient *RealTimeInboxClientSession) Activate(_genesisBlockHash [32]byte) (*types.Transaction, error) {
	return _RealTimeInboxClient.Contract.Activate(&_RealTimeInboxClient.TransactOpts, _genesisBlockHash)
}

// Activate is a paid mutator transaction binding the contract method 0x59db6e85.
//
// Solidity: function activate(bytes32 _genesisBlockHash) returns()
func (_RealTimeInboxClient *RealTimeInboxClientTransactorSession) Activate(_genesisBlockHash [32]byte) (*types.Transaction, error) {
	return _RealTimeInboxClient.Contract.Activate(&_RealTimeInboxClient.TransactOpts, _genesisBlockHash)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_RealTimeInboxClient *RealTimeInboxClientTransactor) Init(opts *bind.TransactOpts, _owner common.Address) (*types.Transaction, error) {
	return _RealTimeInboxClient.contract.Transact(opts, "init", _owner)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_RealTimeInboxClient *RealTimeInboxClientSession) Init(_owner common.Address) (*types.Transaction, error) {
	return _RealTimeInboxClient.Contract.Init(&_RealTimeInboxClient.TransactOpts, _owner)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _owner) returns()
func (_RealTimeInboxClient *RealTimeInboxClientTransactorSession) Init(_owner common.Address) (*types.Transaction, error) {
	return _RealTimeInboxClient.Contract.Init(&_RealTimeInboxClient.TransactOpts, _owner)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_RealTimeInboxClient *RealTimeInboxClientTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _RealTimeInboxClient.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_RealTimeInboxClient *RealTimeInboxClientSession) Pause() (*types.Transaction, error) {
	return _RealTimeInboxClient.Contract.Pause(&_RealTimeInboxClient.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_RealTimeInboxClient *RealTimeInboxClientTransactorSession) Pause() (*types.Transaction, error) {
	return _RealTimeInboxClient.Contract.Pause(&_RealTimeInboxClient.TransactOpts)
}

// Propose is a paid mutator transaction binding the contract method 0x44732c62.
//
// Solidity: function propose(bytes _data, (uint48,bytes32,bytes32) _checkpoint, bytes _proof) returns()
func (_RealTimeInboxClient *RealTimeInboxClientTransactor) Propose(opts *bind.TransactOpts, _data []byte, _checkpoint ICheckpointStoreCheckpoint, _proof []byte) (*types.Transaction, error) {
	return _RealTimeInboxClient.contract.Transact(opts, "propose", _data, _checkpoint, _proof)
}

// Propose is a paid mutator transaction binding the contract method 0x44732c62.
//
// Solidity: function propose(bytes _data, (uint48,bytes32,bytes32) _checkpoint, bytes _proof) returns()
func (_RealTimeInboxClient *RealTimeInboxClientSession) Propose(_data []byte, _checkpoint ICheckpointStoreCheckpoint, _proof []byte) (*types.Transaction, error) {
	return _RealTimeInboxClient.Contract.Propose(&_RealTimeInboxClient.TransactOpts, _data, _checkpoint, _proof)
}

// Propose is a paid mutator transaction binding the contract method 0x44732c62.
//
// Solidity: function propose(bytes _data, (uint48,bytes32,bytes32) _checkpoint, bytes _proof) returns()
func (_RealTimeInboxClient *RealTimeInboxClientTransactorSession) Propose(_data []byte, _checkpoint ICheckpointStoreCheckpoint, _proof []byte) (*types.Transaction, error) {
	return _RealTimeInboxClient.Contract.Propose(&_RealTimeInboxClient.TransactOpts, _data, _checkpoint, _proof)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_RealTimeInboxClient *RealTimeInboxClientTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _RealTimeInboxClient.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_RealTimeInboxClient *RealTimeInboxClientSession) RenounceOwnership() (*types.Transaction, error) {
	return _RealTimeInboxClient.Contract.RenounceOwnership(&_RealTimeInboxClient.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_RealTimeInboxClient *RealTimeInboxClientTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _RealTimeInboxClient.Contract.RenounceOwnership(&_RealTimeInboxClient.TransactOpts)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_RealTimeInboxClient *RealTimeInboxClientTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _RealTimeInboxClient.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_RealTimeInboxClient *RealTimeInboxClientSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _RealTimeInboxClient.Contract.TransferOwnership(&_RealTimeInboxClient.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_RealTimeInboxClient *RealTimeInboxClientTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _RealTimeInboxClient.Contract.TransferOwnership(&_RealTimeInboxClient.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_RealTimeInboxClient *RealTimeInboxClientTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _RealTimeInboxClient.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_RealTimeInboxClient *RealTimeInboxClientSession) Unpause() (*types.Transaction, error) {
	return _RealTimeInboxClient.Contract.Unpause(&_RealTimeInboxClient.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_RealTimeInboxClient *RealTimeInboxClientTransactorSession) Unpause() (*types.Transaction, error) {
	return _RealTimeInboxClient.Contract.Unpause(&_RealTimeInboxClient.TransactOpts)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_RealTimeInboxClient *RealTimeInboxClientTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _RealTimeInboxClient.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_RealTimeInboxClient *RealTimeInboxClientSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _RealTimeInboxClient.Contract.UpgradeTo(&_RealTimeInboxClient.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_RealTimeInboxClient *RealTimeInboxClientTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _RealTimeInboxClient.Contract.UpgradeTo(&_RealTimeInboxClient.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_RealTimeInboxClient *RealTimeInboxClientTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _RealTimeInboxClient.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_RealTimeInboxClient *RealTimeInboxClientSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _RealTimeInboxClient.Contract.UpgradeToAndCall(&_RealTimeInboxClient.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_RealTimeInboxClient *RealTimeInboxClientTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _RealTimeInboxClient.Contract.UpgradeToAndCall(&_RealTimeInboxClient.TransactOpts, newImplementation, data)
}

// RealTimeInboxClientActivatedIterator is returned from FilterActivated and is used to iterate over the raw logs and unpacked data for Activated events raised by the RealTimeInboxClient contract.
type RealTimeInboxClientActivatedIterator struct {
	Event *RealTimeInboxClientActivated // Event containing the contract specifics and raw log

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
func (it *RealTimeInboxClientActivatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RealTimeInboxClientActivated)
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
		it.Event = new(RealTimeInboxClientActivated)
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
func (it *RealTimeInboxClientActivatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RealTimeInboxClientActivatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RealTimeInboxClientActivated represents a Activated event raised by the RealTimeInboxClient contract.
type RealTimeInboxClientActivated struct {
	GenesisBlockHash [32]byte
	Raw              types.Log // Blockchain specific contextual infos
}

// FilterActivated is a free log retrieval operation binding the contract event 0xe1abfe35306def8dbc83e3cb0bc76ffd144cee4ab7707b4e888afd4d24c2d6ca.
//
// Solidity: event Activated(bytes32 genesisBlockHash)
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) FilterActivated(opts *bind.FilterOpts) (*RealTimeInboxClientActivatedIterator, error) {

	logs, sub, err := _RealTimeInboxClient.contract.FilterLogs(opts, "Activated")
	if err != nil {
		return nil, err
	}
	return &RealTimeInboxClientActivatedIterator{contract: _RealTimeInboxClient.contract, event: "Activated", logs: logs, sub: sub}, nil
}

// WatchActivated is a free log subscription operation binding the contract event 0xe1abfe35306def8dbc83e3cb0bc76ffd144cee4ab7707b4e888afd4d24c2d6ca.
//
// Solidity: event Activated(bytes32 genesisBlockHash)
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) WatchActivated(opts *bind.WatchOpts, sink chan<- *RealTimeInboxClientActivated) (event.Subscription, error) {

	logs, sub, err := _RealTimeInboxClient.contract.WatchLogs(opts, "Activated")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RealTimeInboxClientActivated)
				if err := _RealTimeInboxClient.contract.UnpackLog(event, "Activated", log); err != nil {
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

// ParseActivated is a log parse operation binding the contract event 0xe1abfe35306def8dbc83e3cb0bc76ffd144cee4ab7707b4e888afd4d24c2d6ca.
//
// Solidity: event Activated(bytes32 genesisBlockHash)
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) ParseActivated(log types.Log) (*RealTimeInboxClientActivated, error) {
	event := new(RealTimeInboxClientActivated)
	if err := _RealTimeInboxClient.contract.UnpackLog(event, "Activated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RealTimeInboxClientAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the RealTimeInboxClient contract.
type RealTimeInboxClientAdminChangedIterator struct {
	Event *RealTimeInboxClientAdminChanged // Event containing the contract specifics and raw log

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
func (it *RealTimeInboxClientAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RealTimeInboxClientAdminChanged)
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
		it.Event = new(RealTimeInboxClientAdminChanged)
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
func (it *RealTimeInboxClientAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RealTimeInboxClientAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RealTimeInboxClientAdminChanged represents a AdminChanged event raised by the RealTimeInboxClient contract.
type RealTimeInboxClientAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*RealTimeInboxClientAdminChangedIterator, error) {

	logs, sub, err := _RealTimeInboxClient.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &RealTimeInboxClientAdminChangedIterator{contract: _RealTimeInboxClient.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *RealTimeInboxClientAdminChanged) (event.Subscription, error) {

	logs, sub, err := _RealTimeInboxClient.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RealTimeInboxClientAdminChanged)
				if err := _RealTimeInboxClient.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) ParseAdminChanged(log types.Log) (*RealTimeInboxClientAdminChanged, error) {
	event := new(RealTimeInboxClientAdminChanged)
	if err := _RealTimeInboxClient.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RealTimeInboxClientBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the RealTimeInboxClient contract.
type RealTimeInboxClientBeaconUpgradedIterator struct {
	Event *RealTimeInboxClientBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *RealTimeInboxClientBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RealTimeInboxClientBeaconUpgraded)
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
		it.Event = new(RealTimeInboxClientBeaconUpgraded)
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
func (it *RealTimeInboxClientBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RealTimeInboxClientBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RealTimeInboxClientBeaconUpgraded represents a BeaconUpgraded event raised by the RealTimeInboxClient contract.
type RealTimeInboxClientBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*RealTimeInboxClientBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _RealTimeInboxClient.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &RealTimeInboxClientBeaconUpgradedIterator{contract: _RealTimeInboxClient.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *RealTimeInboxClientBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _RealTimeInboxClient.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RealTimeInboxClientBeaconUpgraded)
				if err := _RealTimeInboxClient.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) ParseBeaconUpgraded(log types.Log) (*RealTimeInboxClientBeaconUpgraded, error) {
	event := new(RealTimeInboxClientBeaconUpgraded)
	if err := _RealTimeInboxClient.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RealTimeInboxClientInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the RealTimeInboxClient contract.
type RealTimeInboxClientInitializedIterator struct {
	Event *RealTimeInboxClientInitialized // Event containing the contract specifics and raw log

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
func (it *RealTimeInboxClientInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RealTimeInboxClientInitialized)
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
		it.Event = new(RealTimeInboxClientInitialized)
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
func (it *RealTimeInboxClientInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RealTimeInboxClientInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RealTimeInboxClientInitialized represents a Initialized event raised by the RealTimeInboxClient contract.
type RealTimeInboxClientInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) FilterInitialized(opts *bind.FilterOpts) (*RealTimeInboxClientInitializedIterator, error) {

	logs, sub, err := _RealTimeInboxClient.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &RealTimeInboxClientInitializedIterator{contract: _RealTimeInboxClient.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *RealTimeInboxClientInitialized) (event.Subscription, error) {

	logs, sub, err := _RealTimeInboxClient.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RealTimeInboxClientInitialized)
				if err := _RealTimeInboxClient.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) ParseInitialized(log types.Log) (*RealTimeInboxClientInitialized, error) {
	event := new(RealTimeInboxClientInitialized)
	if err := _RealTimeInboxClient.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RealTimeInboxClientOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the RealTimeInboxClient contract.
type RealTimeInboxClientOwnershipTransferStartedIterator struct {
	Event *RealTimeInboxClientOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *RealTimeInboxClientOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RealTimeInboxClientOwnershipTransferStarted)
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
		it.Event = new(RealTimeInboxClientOwnershipTransferStarted)
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
func (it *RealTimeInboxClientOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RealTimeInboxClientOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RealTimeInboxClientOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the RealTimeInboxClient contract.
type RealTimeInboxClientOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*RealTimeInboxClientOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _RealTimeInboxClient.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &RealTimeInboxClientOwnershipTransferStartedIterator{contract: _RealTimeInboxClient.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *RealTimeInboxClientOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _RealTimeInboxClient.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RealTimeInboxClientOwnershipTransferStarted)
				if err := _RealTimeInboxClient.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) ParseOwnershipTransferStarted(log types.Log) (*RealTimeInboxClientOwnershipTransferStarted, error) {
	event := new(RealTimeInboxClientOwnershipTransferStarted)
	if err := _RealTimeInboxClient.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RealTimeInboxClientOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the RealTimeInboxClient contract.
type RealTimeInboxClientOwnershipTransferredIterator struct {
	Event *RealTimeInboxClientOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *RealTimeInboxClientOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RealTimeInboxClientOwnershipTransferred)
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
		it.Event = new(RealTimeInboxClientOwnershipTransferred)
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
func (it *RealTimeInboxClientOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RealTimeInboxClientOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RealTimeInboxClientOwnershipTransferred represents a OwnershipTransferred event raised by the RealTimeInboxClient contract.
type RealTimeInboxClientOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*RealTimeInboxClientOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _RealTimeInboxClient.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &RealTimeInboxClientOwnershipTransferredIterator{contract: _RealTimeInboxClient.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *RealTimeInboxClientOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _RealTimeInboxClient.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RealTimeInboxClientOwnershipTransferred)
				if err := _RealTimeInboxClient.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) ParseOwnershipTransferred(log types.Log) (*RealTimeInboxClientOwnershipTransferred, error) {
	event := new(RealTimeInboxClientOwnershipTransferred)
	if err := _RealTimeInboxClient.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RealTimeInboxClientPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the RealTimeInboxClient contract.
type RealTimeInboxClientPausedIterator struct {
	Event *RealTimeInboxClientPaused // Event containing the contract specifics and raw log

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
func (it *RealTimeInboxClientPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RealTimeInboxClientPaused)
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
		it.Event = new(RealTimeInboxClientPaused)
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
func (it *RealTimeInboxClientPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RealTimeInboxClientPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RealTimeInboxClientPaused represents a Paused event raised by the RealTimeInboxClient contract.
type RealTimeInboxClientPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) FilterPaused(opts *bind.FilterOpts) (*RealTimeInboxClientPausedIterator, error) {

	logs, sub, err := _RealTimeInboxClient.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &RealTimeInboxClientPausedIterator{contract: _RealTimeInboxClient.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *RealTimeInboxClientPaused) (event.Subscription, error) {

	logs, sub, err := _RealTimeInboxClient.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RealTimeInboxClientPaused)
				if err := _RealTimeInboxClient.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) ParsePaused(log types.Log) (*RealTimeInboxClientPaused, error) {
	event := new(RealTimeInboxClientPaused)
	if err := _RealTimeInboxClient.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RealTimeInboxClientProposedAndProvedIterator is returned from FilterProposedAndProved and is used to iterate over the raw logs and unpacked data for ProposedAndProved events raised by the RealTimeInboxClient contract.
type RealTimeInboxClientProposedAndProvedIterator struct {
	Event *RealTimeInboxClientProposedAndProved // Event containing the contract specifics and raw log

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
func (it *RealTimeInboxClientProposedAndProvedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RealTimeInboxClientProposedAndProved)
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
		it.Event = new(RealTimeInboxClientProposedAndProved)
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
func (it *RealTimeInboxClientProposedAndProvedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RealTimeInboxClientProposedAndProvedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RealTimeInboxClientProposedAndProved represents a ProposedAndProved event raised by the RealTimeInboxClient contract.
type RealTimeInboxClientProposedAndProved struct {
	ProposalHash           [32]byte
	LastFinalizedBlockHash [32]byte
	MaxAnchorBlockNumber   *big.Int
	BasefeeSharingPctg     uint8
	Sources                []IInboxDerivationSource
	SignalSlots            [][32]byte
	Checkpoint             ICheckpointStoreCheckpoint
	Raw                    types.Log // Blockchain specific contextual infos
}

// FilterProposedAndProved is a free log retrieval operation binding the contract event 0x6a83684767411a20c1678ebbcc048bc140fafff380f72410e3e1a22971c8f80d.
//
// Solidity: event ProposedAndProved(bytes32 indexed proposalHash, bytes32 lastFinalizedBlockHash, uint48 maxAnchorBlockNumber, uint8 basefeeSharingPctg, (bool,(bytes32[],uint24,uint48))[] sources, bytes32[] signalSlots, (uint48,bytes32,bytes32) checkpoint)
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) FilterProposedAndProved(opts *bind.FilterOpts, proposalHash [][32]byte) (*RealTimeInboxClientProposedAndProvedIterator, error) {

	var proposalHashRule []interface{}
	for _, proposalHashItem := range proposalHash {
		proposalHashRule = append(proposalHashRule, proposalHashItem)
	}

	logs, sub, err := _RealTimeInboxClient.contract.FilterLogs(opts, "ProposedAndProved", proposalHashRule)
	if err != nil {
		return nil, err
	}
	return &RealTimeInboxClientProposedAndProvedIterator{contract: _RealTimeInboxClient.contract, event: "ProposedAndProved", logs: logs, sub: sub}, nil
}

// WatchProposedAndProved is a free log subscription operation binding the contract event 0x6a83684767411a20c1678ebbcc048bc140fafff380f72410e3e1a22971c8f80d.
//
// Solidity: event ProposedAndProved(bytes32 indexed proposalHash, bytes32 lastFinalizedBlockHash, uint48 maxAnchorBlockNumber, uint8 basefeeSharingPctg, (bool,(bytes32[],uint24,uint48))[] sources, bytes32[] signalSlots, (uint48,bytes32,bytes32) checkpoint)
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) WatchProposedAndProved(opts *bind.WatchOpts, sink chan<- *RealTimeInboxClientProposedAndProved, proposalHash [][32]byte) (event.Subscription, error) {

	var proposalHashRule []interface{}
	for _, proposalHashItem := range proposalHash {
		proposalHashRule = append(proposalHashRule, proposalHashItem)
	}

	logs, sub, err := _RealTimeInboxClient.contract.WatchLogs(opts, "ProposedAndProved", proposalHashRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RealTimeInboxClientProposedAndProved)
				if err := _RealTimeInboxClient.contract.UnpackLog(event, "ProposedAndProved", log); err != nil {
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

// ParseProposedAndProved is a log parse operation binding the contract event 0x6a83684767411a20c1678ebbcc048bc140fafff380f72410e3e1a22971c8f80d.
//
// Solidity: event ProposedAndProved(bytes32 indexed proposalHash, bytes32 lastFinalizedBlockHash, uint48 maxAnchorBlockNumber, uint8 basefeeSharingPctg, (bool,(bytes32[],uint24,uint48))[] sources, bytes32[] signalSlots, (uint48,bytes32,bytes32) checkpoint)
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) ParseProposedAndProved(log types.Log) (*RealTimeInboxClientProposedAndProved, error) {
	event := new(RealTimeInboxClientProposedAndProved)
	if err := _RealTimeInboxClient.contract.UnpackLog(event, "ProposedAndProved", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RealTimeInboxClientUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the RealTimeInboxClient contract.
type RealTimeInboxClientUnpausedIterator struct {
	Event *RealTimeInboxClientUnpaused // Event containing the contract specifics and raw log

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
func (it *RealTimeInboxClientUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RealTimeInboxClientUnpaused)
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
		it.Event = new(RealTimeInboxClientUnpaused)
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
func (it *RealTimeInboxClientUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RealTimeInboxClientUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RealTimeInboxClientUnpaused represents a Unpaused event raised by the RealTimeInboxClient contract.
type RealTimeInboxClientUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) FilterUnpaused(opts *bind.FilterOpts) (*RealTimeInboxClientUnpausedIterator, error) {

	logs, sub, err := _RealTimeInboxClient.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &RealTimeInboxClientUnpausedIterator{contract: _RealTimeInboxClient.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *RealTimeInboxClientUnpaused) (event.Subscription, error) {

	logs, sub, err := _RealTimeInboxClient.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RealTimeInboxClientUnpaused)
				if err := _RealTimeInboxClient.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) ParseUnpaused(log types.Log) (*RealTimeInboxClientUnpaused, error) {
	event := new(RealTimeInboxClientUnpaused)
	if err := _RealTimeInboxClient.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// RealTimeInboxClientUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the RealTimeInboxClient contract.
type RealTimeInboxClientUpgradedIterator struct {
	Event *RealTimeInboxClientUpgraded // Event containing the contract specifics and raw log

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
func (it *RealTimeInboxClientUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(RealTimeInboxClientUpgraded)
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
		it.Event = new(RealTimeInboxClientUpgraded)
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
func (it *RealTimeInboxClientUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *RealTimeInboxClientUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// RealTimeInboxClientUpgraded represents a Upgraded event raised by the RealTimeInboxClient contract.
type RealTimeInboxClientUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*RealTimeInboxClientUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _RealTimeInboxClient.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &RealTimeInboxClientUpgradedIterator{contract: _RealTimeInboxClient.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *RealTimeInboxClientUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _RealTimeInboxClient.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(RealTimeInboxClientUpgraded)
				if err := _RealTimeInboxClient.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_RealTimeInboxClient *RealTimeInboxClientFilterer) ParseUpgraded(log types.Log) (*RealTimeInboxClientUpgraded, error) {
	event := new(RealTimeInboxClientUpgraded)
	if err := _RealTimeInboxClient.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
