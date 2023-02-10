// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package bridge

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

// IBridgeContext is an auto generated low-level Go binding around an user-defined struct.
type IBridgeContext struct {
	MsgHash    [32]byte
	Sender     common.Address
	SrcChainId *big.Int
}

// IBridgeMessage is an auto generated low-level Go binding around an user-defined struct.
type IBridgeMessage struct {
	Id            *big.Int
	Sender        common.Address
	SrcChainId    *big.Int
	DestChainId   *big.Int
	Owner         common.Address
	To            common.Address
	RefundAddress common.Address
	DepositValue  *big.Int
	CallValue     *big.Int
	ProcessingFee *big.Int
	GasLimit      *big.Int
	Data          []byte
	Memo          string
}

// BridgeABI is the input ABI used to generate the binding from.
const BridgeABI = "[{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"bool\",\"name\":\"enabled\",\"type\":\"bool\"}],\"name\":\"DestChainEnabled\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"bytes32\",\"name\":\"msgHash\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"EtherReleased\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint8\",\"name\":\"version\",\"type\":\"uint8\"}],\"name\":\"Initialized\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"bytes32\",\"name\":\"msgHash\",\"type\":\"bytes32\"},{\"components\":[{\"internalType\":\"uint256\",\"name\":\"id\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"sender\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"srcChainId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"destChainId\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"owner\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"refundAddress\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"depositValue\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"callValue\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"processingFee\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"gasLimit\",\"type\":\"uint256\"},{\"internalType\":\"bytes\",\"name\":\"data\",\"type\":\"bytes\"},{\"internalType\":\"string\",\"name\":\"memo\",\"type\":\"string\"}],\"indexed\":false,\"internalType\":\"structIBridge.Message\",\"name\":\"message\",\"type\":\"tuple\"}],\"name\":\"MessageSent\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"bytes32\",\"name\":\"msgHash\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"enumLibBridgeStatus.MessageStatus\",\"name\":\"status\",\"type\":\"uint8\"}],\"name\":\"MessageStatusChanged\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"previousOwner\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"OwnershipTransferred\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"address\",\"name\":\"sender\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"msgHash\",\"type\":\"bytes32\"}],\"name\":\"SignalSent\",\"type\":\"event\"},{\"inputs\":[],\"name\":\"addressManager\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"context\",\"outputs\":[{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"msgHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"sender\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"srcChainId\",\"type\":\"uint256\"}],\"internalType\":\"structIBridge.Context\",\"name\":\"\",\"type\":\"tuple\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"msgHash\",\"type\":\"bytes32\"}],\"name\":\"getMessageStatus\",\"outputs\":[{\"internalType\":\"enumLibBridgeStatus.MessageStatus\",\"name\":\"\",\"type\":\"uint8\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"msgHash\",\"type\":\"bytes32\"}],\"name\":\"getMessageStatusSlot\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"pure\",\"type\":\"function\"},{\"inputs\":[{\"components\":[{\"internalType\":\"uint256\",\"name\":\"id\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"sender\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"srcChainId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"destChainId\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"owner\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"refundAddress\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"depositValue\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"callValue\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"processingFee\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"gasLimit\",\"type\":\"uint256\"},{\"internalType\":\"bytes\",\"name\":\"data\",\"type\":\"bytes\"},{\"internalType\":\"string\",\"name\":\"memo\",\"type\":\"string\"}],\"internalType\":\"structIBridge.Message\",\"name\":\"message\",\"type\":\"tuple\"}],\"name\":\"hashMessage\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"pure\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_addressManager\",\"type\":\"address\"}],\"name\":\"init\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"_chainId\",\"type\":\"uint256\"}],\"name\":\"isDestChainEnabled\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"enabled\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"msgHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint256\",\"name\":\"destChainId\",\"type\":\"uint256\"},{\"internalType\":\"bytes\",\"name\":\"proof\",\"type\":\"bytes\"}],\"name\":\"isMessageFailed\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"msgHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint256\",\"name\":\"srcChainId\",\"type\":\"uint256\"},{\"internalType\":\"bytes\",\"name\":\"proof\",\"type\":\"bytes\"}],\"name\":\"isMessageReceived\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"msgHash\",\"type\":\"bytes32\"}],\"name\":\"isMessageSent\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"owner\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"components\":[{\"internalType\":\"uint256\",\"name\":\"id\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"sender\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"srcChainId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"destChainId\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"owner\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"refundAddress\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"depositValue\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"callValue\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"processingFee\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"gasLimit\",\"type\":\"uint256\"},{\"internalType\":\"bytes\",\"name\":\"data\",\"type\":\"bytes\"},{\"internalType\":\"string\",\"name\":\"memo\",\"type\":\"string\"}],\"internalType\":\"structIBridge.Message\",\"name\":\"message\",\"type\":\"tuple\"},{\"internalType\":\"bytes\",\"name\":\"proof\",\"type\":\"bytes\"}],\"name\":\"processMessage\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"components\":[{\"internalType\":\"uint256\",\"name\":\"id\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"sender\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"srcChainId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"destChainId\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"owner\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"refundAddress\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"depositValue\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"callValue\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"processingFee\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"gasLimit\",\"type\":\"uint256\"},{\"internalType\":\"bytes\",\"name\":\"data\",\"type\":\"bytes\"},{\"internalType\":\"string\",\"name\":\"memo\",\"type\":\"string\"}],\"internalType\":\"structIBridge.Message\",\"name\":\"message\",\"type\":\"tuple\"},{\"internalType\":\"bytes\",\"name\":\"proof\",\"type\":\"bytes\"}],\"name\":\"releaseEther\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"renounceOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"string\",\"name\":\"name\",\"type\":\"string\"},{\"internalType\":\"bool\",\"name\":\"allowZeroAddress\",\"type\":\"bool\"}],\"name\":\"resolve\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"internalType\":\"string\",\"name\":\"name\",\"type\":\"string\"},{\"internalType\":\"bool\",\"name\":\"allowZeroAddress\",\"type\":\"bool\"}],\"name\":\"resolve\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"components\":[{\"internalType\":\"uint256\",\"name\":\"id\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"sender\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"srcChainId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"destChainId\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"owner\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"refundAddress\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"depositValue\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"callValue\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"processingFee\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"gasLimit\",\"type\":\"uint256\"},{\"internalType\":\"bytes\",\"name\":\"data\",\"type\":\"bytes\"},{\"internalType\":\"string\",\"name\":\"memo\",\"type\":\"string\"}],\"internalType\":\"structIBridge.Message\",\"name\":\"message\",\"type\":\"tuple\"},{\"internalType\":\"bool\",\"name\":\"isLastAttempt\",\"type\":\"bool\"}],\"name\":\"retryMessage\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"components\":[{\"internalType\":\"uint256\",\"name\":\"id\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"sender\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"srcChainId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"destChainId\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"owner\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"refundAddress\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"depositValue\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"callValue\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"processingFee\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"gasLimit\",\"type\":\"uint256\"},{\"internalType\":\"bytes\",\"name\":\"data\",\"type\":\"bytes\"},{\"internalType\":\"string\",\"name\":\"memo\",\"type\":\"string\"}],\"internalType\":\"structIBridge.Message\",\"name\":\"message\",\"type\":\"tuple\"}],\"name\":\"sendMessage\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"msgHash\",\"type\":\"bytes32\"}],\"stateMutability\":\"payable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"transferOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"stateMutability\":\"payable\",\"type\":\"receive\"}]"

// Bridge is an auto generated Go binding around an Ethereum contract.
type Bridge struct {
	BridgeCaller     // Read-only binding to the contract
	BridgeTransactor // Write-only binding to the contract
	BridgeFilterer   // Log filterer for contract events
}

// BridgeCaller is an auto generated read-only Go binding around an Ethereum contract.
type BridgeCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// BridgeTransactor is an auto generated write-only Go binding around an Ethereum contract.
type BridgeTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// BridgeFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type BridgeFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// BridgeSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type BridgeSession struct {
	Contract     *Bridge           // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// BridgeCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type BridgeCallerSession struct {
	Contract *BridgeCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts // Call options to use throughout this session
}

// BridgeTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type BridgeTransactorSession struct {
	Contract     *BridgeTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// BridgeRaw is an auto generated low-level Go binding around an Ethereum contract.
type BridgeRaw struct {
	Contract *Bridge // Generic contract binding to access the raw methods on
}

// BridgeCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type BridgeCallerRaw struct {
	Contract *BridgeCaller // Generic read-only contract binding to access the raw methods on
}

// BridgeTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type BridgeTransactorRaw struct {
	Contract *BridgeTransactor // Generic write-only contract binding to access the raw methods on
}

// NewBridge creates a new instance of Bridge, bound to a specific deployed contract.
func NewBridge(address common.Address, backend bind.ContractBackend) (*Bridge, error) {
	contract, err := bindBridge(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &Bridge{BridgeCaller: BridgeCaller{contract: contract}, BridgeTransactor: BridgeTransactor{contract: contract}, BridgeFilterer: BridgeFilterer{contract: contract}}, nil
}

// NewBridgeCaller creates a new read-only instance of Bridge, bound to a specific deployed contract.
func NewBridgeCaller(address common.Address, caller bind.ContractCaller) (*BridgeCaller, error) {
	contract, err := bindBridge(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &BridgeCaller{contract: contract}, nil
}

// NewBridgeTransactor creates a new write-only instance of Bridge, bound to a specific deployed contract.
func NewBridgeTransactor(address common.Address, transactor bind.ContractTransactor) (*BridgeTransactor, error) {
	contract, err := bindBridge(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &BridgeTransactor{contract: contract}, nil
}

// NewBridgeFilterer creates a new log filterer instance of Bridge, bound to a specific deployed contract.
func NewBridgeFilterer(address common.Address, filterer bind.ContractFilterer) (*BridgeFilterer, error) {
	contract, err := bindBridge(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &BridgeFilterer{contract: contract}, nil
}

// bindBridge binds a generic wrapper to an already deployed contract.
func bindBridge(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := abi.JSON(strings.NewReader(BridgeABI))
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_Bridge *BridgeRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _Bridge.Contract.BridgeCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_Bridge *BridgeRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Bridge.Contract.BridgeTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_Bridge *BridgeRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _Bridge.Contract.BridgeTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_Bridge *BridgeCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _Bridge.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_Bridge *BridgeTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Bridge.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_Bridge *BridgeTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _Bridge.Contract.contract.Transact(opts, method, params...)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_Bridge *BridgeCaller) AddressManager(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "addressManager")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_Bridge *BridgeSession) AddressManager() (common.Address, error) {
	return _Bridge.Contract.AddressManager(&_Bridge.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_Bridge *BridgeCallerSession) AddressManager() (common.Address, error) {
	return _Bridge.Contract.AddressManager(&_Bridge.CallOpts)
}

// Context is a free data retrieval call binding the contract method 0xd0496d6a.
//
// Solidity: function context() view returns((bytes32,address,uint256))
func (_Bridge *BridgeCaller) Context(opts *bind.CallOpts) (IBridgeContext, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "context")

	if err != nil {
		return *new(IBridgeContext), err
	}

	out0 := *abi.ConvertType(out[0], new(IBridgeContext)).(*IBridgeContext)

	return out0, err

}

// Context is a free data retrieval call binding the contract method 0xd0496d6a.
//
// Solidity: function context() view returns((bytes32,address,uint256))
func (_Bridge *BridgeSession) Context() (IBridgeContext, error) {
	return _Bridge.Contract.Context(&_Bridge.CallOpts)
}

// Context is a free data retrieval call binding the contract method 0xd0496d6a.
//
// Solidity: function context() view returns((bytes32,address,uint256))
func (_Bridge *BridgeCallerSession) Context() (IBridgeContext, error) {
	return _Bridge.Contract.Context(&_Bridge.CallOpts)
}

// GetMessageStatus is a free data retrieval call binding the contract method 0x5075a9d4.
//
// Solidity: function getMessageStatus(bytes32 msgHash) view returns(uint8)
func (_Bridge *BridgeCaller) GetMessageStatus(opts *bind.CallOpts, msgHash [32]byte) (uint8, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "getMessageStatus", msgHash)

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// GetMessageStatus is a free data retrieval call binding the contract method 0x5075a9d4.
//
// Solidity: function getMessageStatus(bytes32 msgHash) view returns(uint8)
func (_Bridge *BridgeSession) GetMessageStatus(msgHash [32]byte) (uint8, error) {
	return _Bridge.Contract.GetMessageStatus(&_Bridge.CallOpts, msgHash)
}

// GetMessageStatus is a free data retrieval call binding the contract method 0x5075a9d4.
//
// Solidity: function getMessageStatus(bytes32 msgHash) view returns(uint8)
func (_Bridge *BridgeCallerSession) GetMessageStatus(msgHash [32]byte) (uint8, error) {
	return _Bridge.Contract.GetMessageStatus(&_Bridge.CallOpts, msgHash)
}

// GetMessageStatusSlot is a free data retrieval call binding the contract method 0x606b5b74.
//
// Solidity: function getMessageStatusSlot(bytes32 msgHash) pure returns(bytes32)
func (_Bridge *BridgeCaller) GetMessageStatusSlot(opts *bind.CallOpts, msgHash [32]byte) ([32]byte, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "getMessageStatusSlot", msgHash)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetMessageStatusSlot is a free data retrieval call binding the contract method 0x606b5b74.
//
// Solidity: function getMessageStatusSlot(bytes32 msgHash) pure returns(bytes32)
func (_Bridge *BridgeSession) GetMessageStatusSlot(msgHash [32]byte) ([32]byte, error) {
	return _Bridge.Contract.GetMessageStatusSlot(&_Bridge.CallOpts, msgHash)
}

// GetMessageStatusSlot is a free data retrieval call binding the contract method 0x606b5b74.
//
// Solidity: function getMessageStatusSlot(bytes32 msgHash) pure returns(bytes32)
func (_Bridge *BridgeCallerSession) GetMessageStatusSlot(msgHash [32]byte) ([32]byte, error) {
	return _Bridge.Contract.GetMessageStatusSlot(&_Bridge.CallOpts, msgHash)
}

// HashMessage is a free data retrieval call binding the contract method 0x5817b0c3.
//
// Solidity: function hashMessage((uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,uint256,bytes,string) message) pure returns(bytes32)
func (_Bridge *BridgeCaller) HashMessage(opts *bind.CallOpts, message IBridgeMessage) ([32]byte, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "hashMessage", message)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashMessage is a free data retrieval call binding the contract method 0x5817b0c3.
//
// Solidity: function hashMessage((uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,uint256,bytes,string) message) pure returns(bytes32)
func (_Bridge *BridgeSession) HashMessage(message IBridgeMessage) ([32]byte, error) {
	return _Bridge.Contract.HashMessage(&_Bridge.CallOpts, message)
}

// HashMessage is a free data retrieval call binding the contract method 0x5817b0c3.
//
// Solidity: function hashMessage((uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,uint256,bytes,string) message) pure returns(bytes32)
func (_Bridge *BridgeCallerSession) HashMessage(message IBridgeMessage) ([32]byte, error) {
	return _Bridge.Contract.HashMessage(&_Bridge.CallOpts, message)
}

// IsDestChainEnabled is a free data retrieval call binding the contract method 0x5d0bd986.
//
// Solidity: function isDestChainEnabled(uint256 _chainId) view returns(bool enabled)
func (_Bridge *BridgeCaller) IsDestChainEnabled(opts *bind.CallOpts, _chainId *big.Int) (bool, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "isDestChainEnabled", _chainId)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsDestChainEnabled is a free data retrieval call binding the contract method 0x5d0bd986.
//
// Solidity: function isDestChainEnabled(uint256 _chainId) view returns(bool enabled)
func (_Bridge *BridgeSession) IsDestChainEnabled(_chainId *big.Int) (bool, error) {
	return _Bridge.Contract.IsDestChainEnabled(&_Bridge.CallOpts, _chainId)
}

// IsDestChainEnabled is a free data retrieval call binding the contract method 0x5d0bd986.
//
// Solidity: function isDestChainEnabled(uint256 _chainId) view returns(bool enabled)
func (_Bridge *BridgeCallerSession) IsDestChainEnabled(_chainId *big.Int) (bool, error) {
	return _Bridge.Contract.IsDestChainEnabled(&_Bridge.CallOpts, _chainId)
}

// IsMessageFailed is a free data retrieval call binding the contract method 0xce70f39b.
//
// Solidity: function isMessageFailed(bytes32 msgHash, uint256 destChainId, bytes proof) view returns(bool)
func (_Bridge *BridgeCaller) IsMessageFailed(opts *bind.CallOpts, msgHash [32]byte, destChainId *big.Int, proof []byte) (bool, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "isMessageFailed", msgHash, destChainId, proof)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsMessageFailed is a free data retrieval call binding the contract method 0xce70f39b.
//
// Solidity: function isMessageFailed(bytes32 msgHash, uint256 destChainId, bytes proof) view returns(bool)
func (_Bridge *BridgeSession) IsMessageFailed(msgHash [32]byte, destChainId *big.Int, proof []byte) (bool, error) {
	return _Bridge.Contract.IsMessageFailed(&_Bridge.CallOpts, msgHash, destChainId, proof)
}

// IsMessageFailed is a free data retrieval call binding the contract method 0xce70f39b.
//
// Solidity: function isMessageFailed(bytes32 msgHash, uint256 destChainId, bytes proof) view returns(bool)
func (_Bridge *BridgeCallerSession) IsMessageFailed(msgHash [32]byte, destChainId *big.Int, proof []byte) (bool, error) {
	return _Bridge.Contract.IsMessageFailed(&_Bridge.CallOpts, msgHash, destChainId, proof)
}

// IsMessageReceived is a free data retrieval call binding the contract method 0xa4444efd.
//
// Solidity: function isMessageReceived(bytes32 msgHash, uint256 srcChainId, bytes proof) view returns(bool)
func (_Bridge *BridgeCaller) IsMessageReceived(opts *bind.CallOpts, msgHash [32]byte, srcChainId *big.Int, proof []byte) (bool, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "isMessageReceived", msgHash, srcChainId, proof)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsMessageReceived is a free data retrieval call binding the contract method 0xa4444efd.
//
// Solidity: function isMessageReceived(bytes32 msgHash, uint256 srcChainId, bytes proof) view returns(bool)
func (_Bridge *BridgeSession) IsMessageReceived(msgHash [32]byte, srcChainId *big.Int, proof []byte) (bool, error) {
	return _Bridge.Contract.IsMessageReceived(&_Bridge.CallOpts, msgHash, srcChainId, proof)
}

// IsMessageReceived is a free data retrieval call binding the contract method 0xa4444efd.
//
// Solidity: function isMessageReceived(bytes32 msgHash, uint256 srcChainId, bytes proof) view returns(bool)
func (_Bridge *BridgeCallerSession) IsMessageReceived(msgHash [32]byte, srcChainId *big.Int, proof []byte) (bool, error) {
	return _Bridge.Contract.IsMessageReceived(&_Bridge.CallOpts, msgHash, srcChainId, proof)
}

// IsMessageSent is a free data retrieval call binding the contract method 0x540be6a3.
//
// Solidity: function isMessageSent(bytes32 msgHash) view returns(bool)
func (_Bridge *BridgeCaller) IsMessageSent(opts *bind.CallOpts, msgHash [32]byte) (bool, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "isMessageSent", msgHash)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsMessageSent is a free data retrieval call binding the contract method 0x540be6a3.
//
// Solidity: function isMessageSent(bytes32 msgHash) view returns(bool)
func (_Bridge *BridgeSession) IsMessageSent(msgHash [32]byte) (bool, error) {
	return _Bridge.Contract.IsMessageSent(&_Bridge.CallOpts, msgHash)
}

// IsMessageSent is a free data retrieval call binding the contract method 0x540be6a3.
//
// Solidity: function isMessageSent(bytes32 msgHash) view returns(bool)
func (_Bridge *BridgeCallerSession) IsMessageSent(msgHash [32]byte) (bool, error) {
	return _Bridge.Contract.IsMessageSent(&_Bridge.CallOpts, msgHash)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_Bridge *BridgeCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_Bridge *BridgeSession) Owner() (common.Address, error) {
	return _Bridge.Contract.Owner(&_Bridge.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_Bridge *BridgeCallerSession) Owner() (common.Address, error) {
	return _Bridge.Contract.Owner(&_Bridge.CallOpts)
}

// Resolve is a free data retrieval call binding the contract method 0x0ca4dffd.
//
// Solidity: function resolve(string name, bool allowZeroAddress) view returns(address)
func (_Bridge *BridgeCaller) Resolve(opts *bind.CallOpts, name string, allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "resolve", name, allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve is a free data retrieval call binding the contract method 0x0ca4dffd.
//
// Solidity: function resolve(string name, bool allowZeroAddress) view returns(address)
func (_Bridge *BridgeSession) Resolve(name string, allowZeroAddress bool) (common.Address, error) {
	return _Bridge.Contract.Resolve(&_Bridge.CallOpts, name, allowZeroAddress)
}

// Resolve is a free data retrieval call binding the contract method 0x0ca4dffd.
//
// Solidity: function resolve(string name, bool allowZeroAddress) view returns(address)
func (_Bridge *BridgeCallerSession) Resolve(name string, allowZeroAddress bool) (common.Address, error) {
	return _Bridge.Contract.Resolve(&_Bridge.CallOpts, name, allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0x1be2bfa7.
//
// Solidity: function resolve(uint256 chainId, string name, bool allowZeroAddress) view returns(address)
func (_Bridge *BridgeCaller) Resolve0(opts *bind.CallOpts, chainId *big.Int, name string, allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "resolve0", chainId, name, allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve0 is a free data retrieval call binding the contract method 0x1be2bfa7.
//
// Solidity: function resolve(uint256 chainId, string name, bool allowZeroAddress) view returns(address)
func (_Bridge *BridgeSession) Resolve0(chainId *big.Int, name string, allowZeroAddress bool) (common.Address, error) {
	return _Bridge.Contract.Resolve0(&_Bridge.CallOpts, chainId, name, allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0x1be2bfa7.
//
// Solidity: function resolve(uint256 chainId, string name, bool allowZeroAddress) view returns(address)
func (_Bridge *BridgeCallerSession) Resolve0(chainId *big.Int, name string, allowZeroAddress bool) (common.Address, error) {
	return _Bridge.Contract.Resolve0(&_Bridge.CallOpts, chainId, name, allowZeroAddress)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _addressManager) returns()
func (_Bridge *BridgeTransactor) Init(opts *bind.TransactOpts, _addressManager common.Address) (*types.Transaction, error) {
	return _Bridge.contract.Transact(opts, "init", _addressManager)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _addressManager) returns()
func (_Bridge *BridgeSession) Init(_addressManager common.Address) (*types.Transaction, error) {
	return _Bridge.Contract.Init(&_Bridge.TransactOpts, _addressManager)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address _addressManager) returns()
func (_Bridge *BridgeTransactorSession) Init(_addressManager common.Address) (*types.Transaction, error) {
	return _Bridge.Contract.Init(&_Bridge.TransactOpts, _addressManager)
}

// ProcessMessage is a paid mutator transaction binding the contract method 0xfee99b22.
//
// Solidity: function processMessage((uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,uint256,bytes,string) message, bytes proof) returns()
func (_Bridge *BridgeTransactor) ProcessMessage(opts *bind.TransactOpts, message IBridgeMessage, proof []byte) (*types.Transaction, error) {
	return _Bridge.contract.Transact(opts, "processMessage", message, proof)
}

// ProcessMessage is a paid mutator transaction binding the contract method 0xfee99b22.
//
// Solidity: function processMessage((uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,uint256,bytes,string) message, bytes proof) returns()
func (_Bridge *BridgeSession) ProcessMessage(message IBridgeMessage, proof []byte) (*types.Transaction, error) {
	return _Bridge.Contract.ProcessMessage(&_Bridge.TransactOpts, message, proof)
}

// ProcessMessage is a paid mutator transaction binding the contract method 0xfee99b22.
//
// Solidity: function processMessage((uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,uint256,bytes,string) message, bytes proof) returns()
func (_Bridge *BridgeTransactorSession) ProcessMessage(message IBridgeMessage, proof []byte) (*types.Transaction, error) {
	return _Bridge.Contract.ProcessMessage(&_Bridge.TransactOpts, message, proof)
}

// ReleaseEther is a paid mutator transaction binding the contract method 0xbac443e2.
//
// Solidity: function releaseEther((uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,uint256,bytes,string) message, bytes proof) returns()
func (_Bridge *BridgeTransactor) ReleaseEther(opts *bind.TransactOpts, message IBridgeMessage, proof []byte) (*types.Transaction, error) {
	return _Bridge.contract.Transact(opts, "releaseEther", message, proof)
}

// ReleaseEther is a paid mutator transaction binding the contract method 0xbac443e2.
//
// Solidity: function releaseEther((uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,uint256,bytes,string) message, bytes proof) returns()
func (_Bridge *BridgeSession) ReleaseEther(message IBridgeMessage, proof []byte) (*types.Transaction, error) {
	return _Bridge.Contract.ReleaseEther(&_Bridge.TransactOpts, message, proof)
}

// ReleaseEther is a paid mutator transaction binding the contract method 0xbac443e2.
//
// Solidity: function releaseEther((uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,uint256,bytes,string) message, bytes proof) returns()
func (_Bridge *BridgeTransactorSession) ReleaseEther(message IBridgeMessage, proof []byte) (*types.Transaction, error) {
	return _Bridge.Contract.ReleaseEther(&_Bridge.TransactOpts, message, proof)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_Bridge *BridgeTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Bridge.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_Bridge *BridgeSession) RenounceOwnership() (*types.Transaction, error) {
	return _Bridge.Contract.RenounceOwnership(&_Bridge.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_Bridge *BridgeTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _Bridge.Contract.RenounceOwnership(&_Bridge.TransactOpts)
}

// RetryMessage is a paid mutator transaction binding the contract method 0xf9803919.
//
// Solidity: function retryMessage((uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,uint256,bytes,string) message, bool isLastAttempt) returns()
func (_Bridge *BridgeTransactor) RetryMessage(opts *bind.TransactOpts, message IBridgeMessage, isLastAttempt bool) (*types.Transaction, error) {
	return _Bridge.contract.Transact(opts, "retryMessage", message, isLastAttempt)
}

// RetryMessage is a paid mutator transaction binding the contract method 0xf9803919.
//
// Solidity: function retryMessage((uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,uint256,bytes,string) message, bool isLastAttempt) returns()
func (_Bridge *BridgeSession) RetryMessage(message IBridgeMessage, isLastAttempt bool) (*types.Transaction, error) {
	return _Bridge.Contract.RetryMessage(&_Bridge.TransactOpts, message, isLastAttempt)
}

// RetryMessage is a paid mutator transaction binding the contract method 0xf9803919.
//
// Solidity: function retryMessage((uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,uint256,bytes,string) message, bool isLastAttempt) returns()
func (_Bridge *BridgeTransactorSession) RetryMessage(message IBridgeMessage, isLastAttempt bool) (*types.Transaction, error) {
	return _Bridge.Contract.RetryMessage(&_Bridge.TransactOpts, message, isLastAttempt)
}

// SendMessage is a paid mutator transaction binding the contract method 0x96e17852.
//
// Solidity: function sendMessage((uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,uint256,bytes,string) message) payable returns(bytes32 msgHash)
func (_Bridge *BridgeTransactor) SendMessage(opts *bind.TransactOpts, message IBridgeMessage) (*types.Transaction, error) {
	return _Bridge.contract.Transact(opts, "sendMessage", message)
}

// SendMessage is a paid mutator transaction binding the contract method 0x96e17852.
//
// Solidity: function sendMessage((uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,uint256,bytes,string) message) payable returns(bytes32 msgHash)
func (_Bridge *BridgeSession) SendMessage(message IBridgeMessage) (*types.Transaction, error) {
	return _Bridge.Contract.SendMessage(&_Bridge.TransactOpts, message)
}

// SendMessage is a paid mutator transaction binding the contract method 0x96e17852.
//
// Solidity: function sendMessage((uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,uint256,bytes,string) message) payable returns(bytes32 msgHash)
func (_Bridge *BridgeTransactorSession) SendMessage(message IBridgeMessage) (*types.Transaction, error) {
	return _Bridge.Contract.SendMessage(&_Bridge.TransactOpts, message)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_Bridge *BridgeTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _Bridge.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_Bridge *BridgeSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _Bridge.Contract.TransferOwnership(&_Bridge.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_Bridge *BridgeTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _Bridge.Contract.TransferOwnership(&_Bridge.TransactOpts, newOwner)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_Bridge *BridgeTransactor) Receive(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Bridge.contract.RawTransact(opts, nil) // calldata is disallowed for receive function
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_Bridge *BridgeSession) Receive() (*types.Transaction, error) {
	return _Bridge.Contract.Receive(&_Bridge.TransactOpts)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_Bridge *BridgeTransactorSession) Receive() (*types.Transaction, error) {
	return _Bridge.Contract.Receive(&_Bridge.TransactOpts)
}

// BridgeDestChainEnabledIterator is returned from FilterDestChainEnabled and is used to iterate over the raw logs and unpacked data for DestChainEnabled events raised by the Bridge contract.
type BridgeDestChainEnabledIterator struct {
	Event *BridgeDestChainEnabled // Event containing the contract specifics and raw log

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
func (it *BridgeDestChainEnabledIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BridgeDestChainEnabled)
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
		it.Event = new(BridgeDestChainEnabled)
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
func (it *BridgeDestChainEnabledIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BridgeDestChainEnabledIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BridgeDestChainEnabled represents a DestChainEnabled event raised by the Bridge contract.
type BridgeDestChainEnabled struct {
	ChainId *big.Int
	Enabled bool
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterDestChainEnabled is a free log retrieval operation binding the contract event 0x9f391218c06d4fc365ceb15f340bb3d77306b28ac0b8d4e519aec2654794536d.
//
// Solidity: event DestChainEnabled(uint256 indexed chainId, bool enabled)
func (_Bridge *BridgeFilterer) FilterDestChainEnabled(opts *bind.FilterOpts, chainId []*big.Int) (*BridgeDestChainEnabledIterator, error) {

	var chainIdRule []interface{}
	for _, chainIdItem := range chainId {
		chainIdRule = append(chainIdRule, chainIdItem)
	}

	logs, sub, err := _Bridge.contract.FilterLogs(opts, "DestChainEnabled", chainIdRule)
	if err != nil {
		return nil, err
	}
	return &BridgeDestChainEnabledIterator{contract: _Bridge.contract, event: "DestChainEnabled", logs: logs, sub: sub}, nil
}

// WatchDestChainEnabled is a free log subscription operation binding the contract event 0x9f391218c06d4fc365ceb15f340bb3d77306b28ac0b8d4e519aec2654794536d.
//
// Solidity: event DestChainEnabled(uint256 indexed chainId, bool enabled)
func (_Bridge *BridgeFilterer) WatchDestChainEnabled(opts *bind.WatchOpts, sink chan<- *BridgeDestChainEnabled, chainId []*big.Int) (event.Subscription, error) {

	var chainIdRule []interface{}
	for _, chainIdItem := range chainId {
		chainIdRule = append(chainIdRule, chainIdItem)
	}

	logs, sub, err := _Bridge.contract.WatchLogs(opts, "DestChainEnabled", chainIdRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BridgeDestChainEnabled)
				if err := _Bridge.contract.UnpackLog(event, "DestChainEnabled", log); err != nil {
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

// ParseDestChainEnabled is a log parse operation binding the contract event 0x9f391218c06d4fc365ceb15f340bb3d77306b28ac0b8d4e519aec2654794536d.
//
// Solidity: event DestChainEnabled(uint256 indexed chainId, bool enabled)
func (_Bridge *BridgeFilterer) ParseDestChainEnabled(log types.Log) (*BridgeDestChainEnabled, error) {
	event := new(BridgeDestChainEnabled)
	if err := _Bridge.contract.UnpackLog(event, "DestChainEnabled", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BridgeEtherReleasedIterator is returned from FilterEtherReleased and is used to iterate over the raw logs and unpacked data for EtherReleased events raised by the Bridge contract.
type BridgeEtherReleasedIterator struct {
	Event *BridgeEtherReleased // Event containing the contract specifics and raw log

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
func (it *BridgeEtherReleasedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BridgeEtherReleased)
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
		it.Event = new(BridgeEtherReleased)
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
func (it *BridgeEtherReleasedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BridgeEtherReleasedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BridgeEtherReleased represents a EtherReleased event raised by the Bridge contract.
type BridgeEtherReleased struct {
	MsgHash [32]byte
	To      common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterEtherReleased is a free log retrieval operation binding the contract event 0xea00c741e39d1d9ab1c6703152d71f9da09a782ed4ae128414730dadbb9bd847.
//
// Solidity: event EtherReleased(bytes32 indexed msgHash, address to, uint256 amount)
func (_Bridge *BridgeFilterer) FilterEtherReleased(opts *bind.FilterOpts, msgHash [][32]byte) (*BridgeEtherReleasedIterator, error) {

	var msgHashRule []interface{}
	for _, msgHashItem := range msgHash {
		msgHashRule = append(msgHashRule, msgHashItem)
	}

	logs, sub, err := _Bridge.contract.FilterLogs(opts, "EtherReleased", msgHashRule)
	if err != nil {
		return nil, err
	}
	return &BridgeEtherReleasedIterator{contract: _Bridge.contract, event: "EtherReleased", logs: logs, sub: sub}, nil
}

// WatchEtherReleased is a free log subscription operation binding the contract event 0xea00c741e39d1d9ab1c6703152d71f9da09a782ed4ae128414730dadbb9bd847.
//
// Solidity: event EtherReleased(bytes32 indexed msgHash, address to, uint256 amount)
func (_Bridge *BridgeFilterer) WatchEtherReleased(opts *bind.WatchOpts, sink chan<- *BridgeEtherReleased, msgHash [][32]byte) (event.Subscription, error) {

	var msgHashRule []interface{}
	for _, msgHashItem := range msgHash {
		msgHashRule = append(msgHashRule, msgHashItem)
	}

	logs, sub, err := _Bridge.contract.WatchLogs(opts, "EtherReleased", msgHashRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BridgeEtherReleased)
				if err := _Bridge.contract.UnpackLog(event, "EtherReleased", log); err != nil {
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

// ParseEtherReleased is a log parse operation binding the contract event 0xea00c741e39d1d9ab1c6703152d71f9da09a782ed4ae128414730dadbb9bd847.
//
// Solidity: event EtherReleased(bytes32 indexed msgHash, address to, uint256 amount)
func (_Bridge *BridgeFilterer) ParseEtherReleased(log types.Log) (*BridgeEtherReleased, error) {
	event := new(BridgeEtherReleased)
	if err := _Bridge.contract.UnpackLog(event, "EtherReleased", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BridgeInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the Bridge contract.
type BridgeInitializedIterator struct {
	Event *BridgeInitialized // Event containing the contract specifics and raw log

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
func (it *BridgeInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BridgeInitialized)
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
		it.Event = new(BridgeInitialized)
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
func (it *BridgeInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BridgeInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BridgeInitialized represents a Initialized event raised by the Bridge contract.
type BridgeInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_Bridge *BridgeFilterer) FilterInitialized(opts *bind.FilterOpts) (*BridgeInitializedIterator, error) {

	logs, sub, err := _Bridge.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &BridgeInitializedIterator{contract: _Bridge.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_Bridge *BridgeFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *BridgeInitialized) (event.Subscription, error) {

	logs, sub, err := _Bridge.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BridgeInitialized)
				if err := _Bridge.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_Bridge *BridgeFilterer) ParseInitialized(log types.Log) (*BridgeInitialized, error) {
	event := new(BridgeInitialized)
	if err := _Bridge.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BridgeMessageSentIterator is returned from FilterMessageSent and is used to iterate over the raw logs and unpacked data for MessageSent events raised by the Bridge contract.
type BridgeMessageSentIterator struct {
	Event *BridgeMessageSent // Event containing the contract specifics and raw log

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
func (it *BridgeMessageSentIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BridgeMessageSent)
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
		it.Event = new(BridgeMessageSent)
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
func (it *BridgeMessageSentIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BridgeMessageSentIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BridgeMessageSent represents a MessageSent event raised by the Bridge contract.
type BridgeMessageSent struct {
	MsgHash [32]byte
	Message IBridgeMessage
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterMessageSent is a free log retrieval operation binding the contract event 0x47866f7dacd4a276245be6ed543cae03c9c17eb17e6980cee28e3dd168b7f9f3.
//
// Solidity: event MessageSent(bytes32 indexed msgHash, (uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,uint256,bytes,string) message)
func (_Bridge *BridgeFilterer) FilterMessageSent(opts *bind.FilterOpts, msgHash [][32]byte) (*BridgeMessageSentIterator, error) {

	var msgHashRule []interface{}
	for _, msgHashItem := range msgHash {
		msgHashRule = append(msgHashRule, msgHashItem)
	}

	logs, sub, err := _Bridge.contract.FilterLogs(opts, "MessageSent", msgHashRule)
	if err != nil {
		return nil, err
	}
	return &BridgeMessageSentIterator{contract: _Bridge.contract, event: "MessageSent", logs: logs, sub: sub}, nil
}

// WatchMessageSent is a free log subscription operation binding the contract event 0x47866f7dacd4a276245be6ed543cae03c9c17eb17e6980cee28e3dd168b7f9f3.
//
// Solidity: event MessageSent(bytes32 indexed msgHash, (uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,uint256,bytes,string) message)
func (_Bridge *BridgeFilterer) WatchMessageSent(opts *bind.WatchOpts, sink chan<- *BridgeMessageSent, msgHash [][32]byte) (event.Subscription, error) {

	var msgHashRule []interface{}
	for _, msgHashItem := range msgHash {
		msgHashRule = append(msgHashRule, msgHashItem)
	}

	logs, sub, err := _Bridge.contract.WatchLogs(opts, "MessageSent", msgHashRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BridgeMessageSent)
				if err := _Bridge.contract.UnpackLog(event, "MessageSent", log); err != nil {
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

// ParseMessageSent is a log parse operation binding the contract event 0x47866f7dacd4a276245be6ed543cae03c9c17eb17e6980cee28e3dd168b7f9f3.
//
// Solidity: event MessageSent(bytes32 indexed msgHash, (uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,uint256,bytes,string) message)
func (_Bridge *BridgeFilterer) ParseMessageSent(log types.Log) (*BridgeMessageSent, error) {
	event := new(BridgeMessageSent)
	if err := _Bridge.contract.UnpackLog(event, "MessageSent", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BridgeMessageStatusChangedIterator is returned from FilterMessageStatusChanged and is used to iterate over the raw logs and unpacked data for MessageStatusChanged events raised by the Bridge contract.
type BridgeMessageStatusChangedIterator struct {
	Event *BridgeMessageStatusChanged // Event containing the contract specifics and raw log

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
func (it *BridgeMessageStatusChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BridgeMessageStatusChanged)
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
		it.Event = new(BridgeMessageStatusChanged)
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
func (it *BridgeMessageStatusChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BridgeMessageStatusChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BridgeMessageStatusChanged represents a MessageStatusChanged event raised by the Bridge contract.
type BridgeMessageStatusChanged struct {
	MsgHash [32]byte
	Status  uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterMessageStatusChanged is a free log retrieval operation binding the contract event 0x6c51882bc2ed67617f77a1e9b9a25d2caad8448647ecb093b357a603b2575634.
//
// Solidity: event MessageStatusChanged(bytes32 indexed msgHash, uint8 status)
func (_Bridge *BridgeFilterer) FilterMessageStatusChanged(opts *bind.FilterOpts, msgHash [][32]byte) (*BridgeMessageStatusChangedIterator, error) {

	var msgHashRule []interface{}
	for _, msgHashItem := range msgHash {
		msgHashRule = append(msgHashRule, msgHashItem)
	}

	logs, sub, err := _Bridge.contract.FilterLogs(opts, "MessageStatusChanged", msgHashRule)
	if err != nil {
		return nil, err
	}
	return &BridgeMessageStatusChangedIterator{contract: _Bridge.contract, event: "MessageStatusChanged", logs: logs, sub: sub}, nil
}

// WatchMessageStatusChanged is a free log subscription operation binding the contract event 0x6c51882bc2ed67617f77a1e9b9a25d2caad8448647ecb093b357a603b2575634.
//
// Solidity: event MessageStatusChanged(bytes32 indexed msgHash, uint8 status)
func (_Bridge *BridgeFilterer) WatchMessageStatusChanged(opts *bind.WatchOpts, sink chan<- *BridgeMessageStatusChanged, msgHash [][32]byte) (event.Subscription, error) {

	var msgHashRule []interface{}
	for _, msgHashItem := range msgHash {
		msgHashRule = append(msgHashRule, msgHashItem)
	}

	logs, sub, err := _Bridge.contract.WatchLogs(opts, "MessageStatusChanged", msgHashRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BridgeMessageStatusChanged)
				if err := _Bridge.contract.UnpackLog(event, "MessageStatusChanged", log); err != nil {
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

// ParseMessageStatusChanged is a log parse operation binding the contract event 0x6c51882bc2ed67617f77a1e9b9a25d2caad8448647ecb093b357a603b2575634.
//
// Solidity: event MessageStatusChanged(bytes32 indexed msgHash, uint8 status)
func (_Bridge *BridgeFilterer) ParseMessageStatusChanged(log types.Log) (*BridgeMessageStatusChanged, error) {
	event := new(BridgeMessageStatusChanged)
	if err := _Bridge.contract.UnpackLog(event, "MessageStatusChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BridgeOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the Bridge contract.
type BridgeOwnershipTransferredIterator struct {
	Event *BridgeOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *BridgeOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BridgeOwnershipTransferred)
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
		it.Event = new(BridgeOwnershipTransferred)
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
func (it *BridgeOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BridgeOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BridgeOwnershipTransferred represents a OwnershipTransferred event raised by the Bridge contract.
type BridgeOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_Bridge *BridgeFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*BridgeOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _Bridge.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &BridgeOwnershipTransferredIterator{contract: _Bridge.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_Bridge *BridgeFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *BridgeOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _Bridge.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BridgeOwnershipTransferred)
				if err := _Bridge.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_Bridge *BridgeFilterer) ParseOwnershipTransferred(log types.Log) (*BridgeOwnershipTransferred, error) {
	event := new(BridgeOwnershipTransferred)
	if err := _Bridge.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BridgeSignalSentIterator is returned from FilterSignalSent and is used to iterate over the raw logs and unpacked data for SignalSent events raised by the Bridge contract.
type BridgeSignalSentIterator struct {
	Event *BridgeSignalSent // Event containing the contract specifics and raw log

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
func (it *BridgeSignalSentIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BridgeSignalSent)
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
		it.Event = new(BridgeSignalSent)
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
func (it *BridgeSignalSentIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BridgeSignalSentIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BridgeSignalSent represents a SignalSent event raised by the Bridge contract.
type BridgeSignalSent struct {
	Sender  common.Address
	MsgHash [32]byte
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterSignalSent is a free log retrieval operation binding the contract event 0xf0958489d2a32db2b0faf27a72a31fdf28f2636ca5532f1b077ddc2f51b20d1d.
//
// Solidity: event SignalSent(address sender, bytes32 msgHash)
func (_Bridge *BridgeFilterer) FilterSignalSent(opts *bind.FilterOpts) (*BridgeSignalSentIterator, error) {

	logs, sub, err := _Bridge.contract.FilterLogs(opts, "SignalSent")
	if err != nil {
		return nil, err
	}
	return &BridgeSignalSentIterator{contract: _Bridge.contract, event: "SignalSent", logs: logs, sub: sub}, nil
}

// WatchSignalSent is a free log subscription operation binding the contract event 0xf0958489d2a32db2b0faf27a72a31fdf28f2636ca5532f1b077ddc2f51b20d1d.
//
// Solidity: event SignalSent(address sender, bytes32 msgHash)
func (_Bridge *BridgeFilterer) WatchSignalSent(opts *bind.WatchOpts, sink chan<- *BridgeSignalSent) (event.Subscription, error) {

	logs, sub, err := _Bridge.contract.WatchLogs(opts, "SignalSent")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BridgeSignalSent)
				if err := _Bridge.contract.UnpackLog(event, "SignalSent", log); err != nil {
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

// ParseSignalSent is a log parse operation binding the contract event 0xf0958489d2a32db2b0faf27a72a31fdf28f2636ca5532f1b077ddc2f51b20d1d.
//
// Solidity: event SignalSent(address sender, bytes32 msgHash)
func (_Bridge *BridgeFilterer) ParseSignalSent(log types.Log) (*BridgeSignalSent, error) {
	event := new(BridgeSignalSent)
	if err := _Bridge.contract.UnpackLog(event, "SignalSent", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
