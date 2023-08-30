// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package erc20vault

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

// ERC20VaultBridgeTransferOp is an auto generated low-level Go binding around an user-defined struct.
type ERC20VaultBridgeTransferOp struct {
	DestChainId *big.Int
	To          common.Address
	Token       common.Address
	Amount      *big.Int
	GasLimit    *big.Int
	Fee         *big.Int
	RefundTo    common.Address
	Memo        string
}

// ERC20VaultCanonicalERC20 is an auto generated low-level Go binding around an user-defined struct.
type ERC20VaultCanonicalERC20 struct {
	ChainId  *big.Int
	Addr     common.Address
	Decimals uint8
	Symbol   string
	Name     string
}

// IBridgeMessage is an auto generated low-level Go binding around an user-defined struct.
type IBridgeMessage struct {
	Id          *big.Int
	From        common.Address
	SrcChainId  *big.Int
	DestChainId *big.Int
	User        common.Address
	To          common.Address
	RefundTo    common.Address
	Value       *big.Int
	Fee         *big.Int
	GasLimit    *big.Int
	Data        []byte
	Memo        string
}

// ERC20VaultMetaData contains all meta data concerning the ERC20Vault contract.
var ERC20VaultMetaData = &bind.MetaData{
	ABI: "[{\"inputs\":[],\"name\":\"RESOLVER_DENIED\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"RESOLVER_INVALID_ADDR\",\"type\":\"error\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"name\",\"type\":\"bytes32\"}],\"name\":\"RESOLVER_ZERO_ADDR\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"VAULT_INVALID_AMOUNT\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"VAULT_INVALID_FROM\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"VAULT_INVALID_SRC_CHAIN_ID\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"VAULT_INVALID_TO\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"VAULT_INVALID_TOKEN\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"VAULT_INVALID_USER\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"VAULT_MESSAGE_NOT_FAILED\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"VAULT_MESSAGE_RELEASED_ALREADY\",\"type\":\"error\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"addressManager\",\"type\":\"address\"}],\"name\":\"AddressManagerChanged\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"srcChainId\",\"type\":\"uint256\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"ctoken\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"btoken\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"string\",\"name\":\"ctokenSymbol\",\"type\":\"string\"},{\"indexed\":false,\"internalType\":\"string\",\"name\":\"ctokenName\",\"type\":\"string\"},{\"indexed\":false,\"internalType\":\"uint8\",\"name\":\"ctokenDecimal\",\"type\":\"uint8\"}],\"name\":\"BridgedTokenDeployed\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint8\",\"name\":\"version\",\"type\":\"uint8\"}],\"name\":\"Initialized\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"previousOwner\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"OwnershipTransferred\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"bytes32\",\"name\":\"msgHash\",\"type\":\"bytes32\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"from\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"srcChainId\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"token\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"TokenReceived\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"bytes32\",\"name\":\"msgHash\",\"type\":\"bytes32\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"from\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"token\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"TokenReleased\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"bytes32\",\"name\":\"msgHash\",\"type\":\"bytes32\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"from\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"destChainId\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"token\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"TokenSent\",\"type\":\"event\"},{\"inputs\":[],\"name\":\"addressManager\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"name\":\"bridgedToCanonical\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"addr\",\"type\":\"address\"},{\"internalType\":\"uint8\",\"name\":\"decimals\",\"type\":\"uint8\"},{\"internalType\":\"string\",\"name\":\"symbol\",\"type\":\"string\"},{\"internalType\":\"string\",\"name\":\"name\",\"type\":\"string\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"name\":\"canonicalToBridged\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"addressManager\",\"type\":\"address\"}],\"name\":\"init\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"name\":\"isBridgedToken\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"components\":[{\"internalType\":\"uint256\",\"name\":\"id\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"from\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"srcChainId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"destChainId\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"user\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"refundTo\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"value\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"fee\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"gasLimit\",\"type\":\"uint256\"},{\"internalType\":\"bytes\",\"name\":\"data\",\"type\":\"bytes\"},{\"internalType\":\"string\",\"name\":\"memo\",\"type\":\"string\"}],\"internalType\":\"structIBridge.Message\",\"name\":\"message\",\"type\":\"tuple\"}],\"name\":\"onMessageRecalled\",\"outputs\":[],\"stateMutability\":\"payable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"owner\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"components\":[{\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"addr\",\"type\":\"address\"},{\"internalType\":\"uint8\",\"name\":\"decimals\",\"type\":\"uint8\"},{\"internalType\":\"string\",\"name\":\"symbol\",\"type\":\"string\"},{\"internalType\":\"string\",\"name\":\"name\",\"type\":\"string\"}],\"internalType\":\"structERC20Vault.CanonicalERC20\",\"name\":\"ctoken\",\"type\":\"tuple\"},{\"internalType\":\"address\",\"name\":\"from\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"receiveToken\",\"outputs\":[],\"stateMutability\":\"payable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"renounceOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"name\",\"type\":\"bytes32\"},{\"internalType\":\"bool\",\"name\":\"allowZeroAddress\",\"type\":\"bool\"}],\"name\":\"resolve\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"addr\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"name\",\"type\":\"bytes32\"},{\"internalType\":\"bool\",\"name\":\"allowZeroAddress\",\"type\":\"bool\"}],\"name\":\"resolve\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"addr\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"components\":[{\"internalType\":\"uint256\",\"name\":\"destChainId\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"token\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"gasLimit\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"fee\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"refundTo\",\"type\":\"address\"},{\"internalType\":\"string\",\"name\":\"memo\",\"type\":\"string\"}],\"internalType\":\"structERC20Vault.BridgeTransferOp\",\"name\":\"opt\",\"type\":\"tuple\"}],\"name\":\"sendToken\",\"outputs\":[],\"stateMutability\":\"payable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"newAddressManager\",\"type\":\"address\"}],\"name\":\"setAddressManager\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes4\",\"name\":\"interfaceId\",\"type\":\"bytes4\"}],\"name\":\"supportsInterface\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"transferOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"}]",
}

// ERC20VaultABI is the input ABI used to generate the binding from.
// Deprecated: Use ERC20VaultMetaData.ABI instead.
var ERC20VaultABI = ERC20VaultMetaData.ABI

// ERC20Vault is an auto generated Go binding around an Ethereum contract.
type ERC20Vault struct {
	ERC20VaultCaller     // Read-only binding to the contract
	ERC20VaultTransactor // Write-only binding to the contract
	ERC20VaultFilterer   // Log filterer for contract events
}

// ERC20VaultCaller is an auto generated read-only Go binding around an Ethereum contract.
type ERC20VaultCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ERC20VaultTransactor is an auto generated write-only Go binding around an Ethereum contract.
type ERC20VaultTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ERC20VaultFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type ERC20VaultFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ERC20VaultSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type ERC20VaultSession struct {
	Contract     *ERC20Vault       // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// ERC20VaultCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type ERC20VaultCallerSession struct {
	Contract *ERC20VaultCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts     // Call options to use throughout this session
}

// ERC20VaultTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type ERC20VaultTransactorSession struct {
	Contract     *ERC20VaultTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts     // Transaction auth options to use throughout this session
}

// ERC20VaultRaw is an auto generated low-level Go binding around an Ethereum contract.
type ERC20VaultRaw struct {
	Contract *ERC20Vault // Generic contract binding to access the raw methods on
}

// ERC20VaultCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type ERC20VaultCallerRaw struct {
	Contract *ERC20VaultCaller // Generic read-only contract binding to access the raw methods on
}

// ERC20VaultTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type ERC20VaultTransactorRaw struct {
	Contract *ERC20VaultTransactor // Generic write-only contract binding to access the raw methods on
}

// NewERC20Vault creates a new instance of ERC20Vault, bound to a specific deployed contract.
func NewERC20Vault(address common.Address, backend bind.ContractBackend) (*ERC20Vault, error) {
	contract, err := bindERC20Vault(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &ERC20Vault{ERC20VaultCaller: ERC20VaultCaller{contract: contract}, ERC20VaultTransactor: ERC20VaultTransactor{contract: contract}, ERC20VaultFilterer: ERC20VaultFilterer{contract: contract}}, nil
}

// NewERC20VaultCaller creates a new read-only instance of ERC20Vault, bound to a specific deployed contract.
func NewERC20VaultCaller(address common.Address, caller bind.ContractCaller) (*ERC20VaultCaller, error) {
	contract, err := bindERC20Vault(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &ERC20VaultCaller{contract: contract}, nil
}

// NewERC20VaultTransactor creates a new write-only instance of ERC20Vault, bound to a specific deployed contract.
func NewERC20VaultTransactor(address common.Address, transactor bind.ContractTransactor) (*ERC20VaultTransactor, error) {
	contract, err := bindERC20Vault(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &ERC20VaultTransactor{contract: contract}, nil
}

// NewERC20VaultFilterer creates a new log filterer instance of ERC20Vault, bound to a specific deployed contract.
func NewERC20VaultFilterer(address common.Address, filterer bind.ContractFilterer) (*ERC20VaultFilterer, error) {
	contract, err := bindERC20Vault(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &ERC20VaultFilterer{contract: contract}, nil
}

// bindERC20Vault binds a generic wrapper to an already deployed contract.
func bindERC20Vault(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := ERC20VaultMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ERC20Vault *ERC20VaultRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ERC20Vault.Contract.ERC20VaultCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ERC20Vault *ERC20VaultRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ERC20Vault.Contract.ERC20VaultTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ERC20Vault *ERC20VaultRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ERC20Vault.Contract.ERC20VaultTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ERC20Vault *ERC20VaultCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ERC20Vault.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ERC20Vault *ERC20VaultTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ERC20Vault.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ERC20Vault *ERC20VaultTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ERC20Vault.Contract.contract.Transact(opts, method, params...)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_ERC20Vault *ERC20VaultCaller) AddressManager(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ERC20Vault.contract.Call(opts, &out, "addressManager")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_ERC20Vault *ERC20VaultSession) AddressManager() (common.Address, error) {
	return _ERC20Vault.Contract.AddressManager(&_ERC20Vault.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_ERC20Vault *ERC20VaultCallerSession) AddressManager() (common.Address, error) {
	return _ERC20Vault.Contract.AddressManager(&_ERC20Vault.CallOpts)
}

// BridgedToCanonical is a free data retrieval call binding the contract method 0x9aa8605c.
//
// Solidity: function bridgedToCanonical(address ) view returns(uint256 chainId, address addr, uint8 decimals, string symbol, string name)
func (_ERC20Vault *ERC20VaultCaller) BridgedToCanonical(opts *bind.CallOpts, arg0 common.Address) (struct {
	ChainId  *big.Int
	Addr     common.Address
	Decimals uint8
	Symbol   string
	Name     string
}, error) {
	var out []interface{}
	err := _ERC20Vault.contract.Call(opts, &out, "bridgedToCanonical", arg0)

	outstruct := new(struct {
		ChainId  *big.Int
		Addr     common.Address
		Decimals uint8
		Symbol   string
		Name     string
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.ChainId = *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	outstruct.Addr = *abi.ConvertType(out[1], new(common.Address)).(*common.Address)
	outstruct.Decimals = *abi.ConvertType(out[2], new(uint8)).(*uint8)
	outstruct.Symbol = *abi.ConvertType(out[3], new(string)).(*string)
	outstruct.Name = *abi.ConvertType(out[4], new(string)).(*string)

	return *outstruct, err

}

// BridgedToCanonical is a free data retrieval call binding the contract method 0x9aa8605c.
//
// Solidity: function bridgedToCanonical(address ) view returns(uint256 chainId, address addr, uint8 decimals, string symbol, string name)
func (_ERC20Vault *ERC20VaultSession) BridgedToCanonical(arg0 common.Address) (struct {
	ChainId  *big.Int
	Addr     common.Address
	Decimals uint8
	Symbol   string
	Name     string
}, error) {
	return _ERC20Vault.Contract.BridgedToCanonical(&_ERC20Vault.CallOpts, arg0)
}

// BridgedToCanonical is a free data retrieval call binding the contract method 0x9aa8605c.
//
// Solidity: function bridgedToCanonical(address ) view returns(uint256 chainId, address addr, uint8 decimals, string symbol, string name)
func (_ERC20Vault *ERC20VaultCallerSession) BridgedToCanonical(arg0 common.Address) (struct {
	ChainId  *big.Int
	Addr     common.Address
	Decimals uint8
	Symbol   string
	Name     string
}, error) {
	return _ERC20Vault.Contract.BridgedToCanonical(&_ERC20Vault.CallOpts, arg0)
}

// CanonicalToBridged is a free data retrieval call binding the contract method 0x67090ccf.
//
// Solidity: function canonicalToBridged(uint256 , address ) view returns(address)
func (_ERC20Vault *ERC20VaultCaller) CanonicalToBridged(opts *bind.CallOpts, arg0 *big.Int, arg1 common.Address) (common.Address, error) {
	var out []interface{}
	err := _ERC20Vault.contract.Call(opts, &out, "canonicalToBridged", arg0, arg1)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CanonicalToBridged is a free data retrieval call binding the contract method 0x67090ccf.
//
// Solidity: function canonicalToBridged(uint256 , address ) view returns(address)
func (_ERC20Vault *ERC20VaultSession) CanonicalToBridged(arg0 *big.Int, arg1 common.Address) (common.Address, error) {
	return _ERC20Vault.Contract.CanonicalToBridged(&_ERC20Vault.CallOpts, arg0, arg1)
}

// CanonicalToBridged is a free data retrieval call binding the contract method 0x67090ccf.
//
// Solidity: function canonicalToBridged(uint256 , address ) view returns(address)
func (_ERC20Vault *ERC20VaultCallerSession) CanonicalToBridged(arg0 *big.Int, arg1 common.Address) (common.Address, error) {
	return _ERC20Vault.Contract.CanonicalToBridged(&_ERC20Vault.CallOpts, arg0, arg1)
}

// IsBridgedToken is a free data retrieval call binding the contract method 0xc287e578.
//
// Solidity: function isBridgedToken(address ) view returns(bool)
func (_ERC20Vault *ERC20VaultCaller) IsBridgedToken(opts *bind.CallOpts, arg0 common.Address) (bool, error) {
	var out []interface{}
	err := _ERC20Vault.contract.Call(opts, &out, "isBridgedToken", arg0)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsBridgedToken is a free data retrieval call binding the contract method 0xc287e578.
//
// Solidity: function isBridgedToken(address ) view returns(bool)
func (_ERC20Vault *ERC20VaultSession) IsBridgedToken(arg0 common.Address) (bool, error) {
	return _ERC20Vault.Contract.IsBridgedToken(&_ERC20Vault.CallOpts, arg0)
}

// IsBridgedToken is a free data retrieval call binding the contract method 0xc287e578.
//
// Solidity: function isBridgedToken(address ) view returns(bool)
func (_ERC20Vault *ERC20VaultCallerSession) IsBridgedToken(arg0 common.Address) (bool, error) {
	return _ERC20Vault.Contract.IsBridgedToken(&_ERC20Vault.CallOpts, arg0)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ERC20Vault *ERC20VaultCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ERC20Vault.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ERC20Vault *ERC20VaultSession) Owner() (common.Address, error) {
	return _ERC20Vault.Contract.Owner(&_ERC20Vault.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ERC20Vault *ERC20VaultCallerSession) Owner() (common.Address, error) {
	return _ERC20Vault.Contract.Owner(&_ERC20Vault.CallOpts)
}

// Resolve is a free data retrieval call binding the contract method 0x6c6563f6.
//
// Solidity: function resolve(uint256 chainId, bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_ERC20Vault *ERC20VaultCaller) Resolve(opts *bind.CallOpts, chainId *big.Int, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _ERC20Vault.contract.Call(opts, &out, "resolve", chainId, name, allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve is a free data retrieval call binding the contract method 0x6c6563f6.
//
// Solidity: function resolve(uint256 chainId, bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_ERC20Vault *ERC20VaultSession) Resolve(chainId *big.Int, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _ERC20Vault.Contract.Resolve(&_ERC20Vault.CallOpts, chainId, name, allowZeroAddress)
}

// Resolve is a free data retrieval call binding the contract method 0x6c6563f6.
//
// Solidity: function resolve(uint256 chainId, bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_ERC20Vault *ERC20VaultCallerSession) Resolve(chainId *big.Int, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _ERC20Vault.Contract.Resolve(&_ERC20Vault.CallOpts, chainId, name, allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_ERC20Vault *ERC20VaultCaller) Resolve0(opts *bind.CallOpts, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _ERC20Vault.contract.Call(opts, &out, "resolve0", name, allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_ERC20Vault *ERC20VaultSession) Resolve0(name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _ERC20Vault.Contract.Resolve0(&_ERC20Vault.CallOpts, name, allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_ERC20Vault *ERC20VaultCallerSession) Resolve0(name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _ERC20Vault.Contract.Resolve0(&_ERC20Vault.CallOpts, name, allowZeroAddress)
}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 interfaceId) view returns(bool)
func (_ERC20Vault *ERC20VaultCaller) SupportsInterface(opts *bind.CallOpts, interfaceId [4]byte) (bool, error) {
	var out []interface{}
	err := _ERC20Vault.contract.Call(opts, &out, "supportsInterface", interfaceId)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 interfaceId) view returns(bool)
func (_ERC20Vault *ERC20VaultSession) SupportsInterface(interfaceId [4]byte) (bool, error) {
	return _ERC20Vault.Contract.SupportsInterface(&_ERC20Vault.CallOpts, interfaceId)
}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 interfaceId) view returns(bool)
func (_ERC20Vault *ERC20VaultCallerSession) SupportsInterface(interfaceId [4]byte) (bool, error) {
	return _ERC20Vault.Contract.SupportsInterface(&_ERC20Vault.CallOpts, interfaceId)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address addressManager) returns()
func (_ERC20Vault *ERC20VaultTransactor) Init(opts *bind.TransactOpts, addressManager common.Address) (*types.Transaction, error) {
	return _ERC20Vault.contract.Transact(opts, "init", addressManager)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address addressManager) returns()
func (_ERC20Vault *ERC20VaultSession) Init(addressManager common.Address) (*types.Transaction, error) {
	return _ERC20Vault.Contract.Init(&_ERC20Vault.TransactOpts, addressManager)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address addressManager) returns()
func (_ERC20Vault *ERC20VaultTransactorSession) Init(addressManager common.Address) (*types.Transaction, error) {
	return _ERC20Vault.Contract.Init(&_ERC20Vault.TransactOpts, addressManager)
}

// OnMessageRecalled is a paid mutator transaction binding the contract method 0x32a642ca.
//
// Solidity: function onMessageRecalled((uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,bytes,string) message) payable returns()
func (_ERC20Vault *ERC20VaultTransactor) OnMessageRecalled(opts *bind.TransactOpts, message IBridgeMessage) (*types.Transaction, error) {
	return _ERC20Vault.contract.Transact(opts, "onMessageRecalled", message)
}

// OnMessageRecalled is a paid mutator transaction binding the contract method 0x32a642ca.
//
// Solidity: function onMessageRecalled((uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,bytes,string) message) payable returns()
func (_ERC20Vault *ERC20VaultSession) OnMessageRecalled(message IBridgeMessage) (*types.Transaction, error) {
	return _ERC20Vault.Contract.OnMessageRecalled(&_ERC20Vault.TransactOpts, message)
}

// OnMessageRecalled is a paid mutator transaction binding the contract method 0x32a642ca.
//
// Solidity: function onMessageRecalled((uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,bytes,string) message) payable returns()
func (_ERC20Vault *ERC20VaultTransactorSession) OnMessageRecalled(message IBridgeMessage) (*types.Transaction, error) {
	return _ERC20Vault.Contract.OnMessageRecalled(&_ERC20Vault.TransactOpts, message)
}

// ReceiveToken is a paid mutator transaction binding the contract method 0xcb03d23c.
//
// Solidity: function receiveToken((uint256,address,uint8,string,string) ctoken, address from, address to, uint256 amount) payable returns()
func (_ERC20Vault *ERC20VaultTransactor) ReceiveToken(opts *bind.TransactOpts, ctoken ERC20VaultCanonicalERC20, from common.Address, to common.Address, amount *big.Int) (*types.Transaction, error) {
	return _ERC20Vault.contract.Transact(opts, "receiveToken", ctoken, from, to, amount)
}

// ReceiveToken is a paid mutator transaction binding the contract method 0xcb03d23c.
//
// Solidity: function receiveToken((uint256,address,uint8,string,string) ctoken, address from, address to, uint256 amount) payable returns()
func (_ERC20Vault *ERC20VaultSession) ReceiveToken(ctoken ERC20VaultCanonicalERC20, from common.Address, to common.Address, amount *big.Int) (*types.Transaction, error) {
	return _ERC20Vault.Contract.ReceiveToken(&_ERC20Vault.TransactOpts, ctoken, from, to, amount)
}

// ReceiveToken is a paid mutator transaction binding the contract method 0xcb03d23c.
//
// Solidity: function receiveToken((uint256,address,uint8,string,string) ctoken, address from, address to, uint256 amount) payable returns()
func (_ERC20Vault *ERC20VaultTransactorSession) ReceiveToken(ctoken ERC20VaultCanonicalERC20, from common.Address, to common.Address, amount *big.Int) (*types.Transaction, error) {
	return _ERC20Vault.Contract.ReceiveToken(&_ERC20Vault.TransactOpts, ctoken, from, to, amount)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ERC20Vault *ERC20VaultTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ERC20Vault.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ERC20Vault *ERC20VaultSession) RenounceOwnership() (*types.Transaction, error) {
	return _ERC20Vault.Contract.RenounceOwnership(&_ERC20Vault.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ERC20Vault *ERC20VaultTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _ERC20Vault.Contract.RenounceOwnership(&_ERC20Vault.TransactOpts)
}

// SendToken is a paid mutator transaction binding the contract method 0xe2dc9033.
//
// Solidity: function sendToken((uint256,address,address,uint256,uint256,uint256,address,string) opt) payable returns()
func (_ERC20Vault *ERC20VaultTransactor) SendToken(opts *bind.TransactOpts, opt ERC20VaultBridgeTransferOp) (*types.Transaction, error) {
	return _ERC20Vault.contract.Transact(opts, "sendToken", opt)
}

// SendToken is a paid mutator transaction binding the contract method 0xe2dc9033.
//
// Solidity: function sendToken((uint256,address,address,uint256,uint256,uint256,address,string) opt) payable returns()
func (_ERC20Vault *ERC20VaultSession) SendToken(opt ERC20VaultBridgeTransferOp) (*types.Transaction, error) {
	return _ERC20Vault.Contract.SendToken(&_ERC20Vault.TransactOpts, opt)
}

// SendToken is a paid mutator transaction binding the contract method 0xe2dc9033.
//
// Solidity: function sendToken((uint256,address,address,uint256,uint256,uint256,address,string) opt) payable returns()
func (_ERC20Vault *ERC20VaultTransactorSession) SendToken(opt ERC20VaultBridgeTransferOp) (*types.Transaction, error) {
	return _ERC20Vault.Contract.SendToken(&_ERC20Vault.TransactOpts, opt)
}

// SetAddressManager is a paid mutator transaction binding the contract method 0x0652b57a.
//
// Solidity: function setAddressManager(address newAddressManager) returns()
func (_ERC20Vault *ERC20VaultTransactor) SetAddressManager(opts *bind.TransactOpts, newAddressManager common.Address) (*types.Transaction, error) {
	return _ERC20Vault.contract.Transact(opts, "setAddressManager", newAddressManager)
}

// SetAddressManager is a paid mutator transaction binding the contract method 0x0652b57a.
//
// Solidity: function setAddressManager(address newAddressManager) returns()
func (_ERC20Vault *ERC20VaultSession) SetAddressManager(newAddressManager common.Address) (*types.Transaction, error) {
	return _ERC20Vault.Contract.SetAddressManager(&_ERC20Vault.TransactOpts, newAddressManager)
}

// SetAddressManager is a paid mutator transaction binding the contract method 0x0652b57a.
//
// Solidity: function setAddressManager(address newAddressManager) returns()
func (_ERC20Vault *ERC20VaultTransactorSession) SetAddressManager(newAddressManager common.Address) (*types.Transaction, error) {
	return _ERC20Vault.Contract.SetAddressManager(&_ERC20Vault.TransactOpts, newAddressManager)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ERC20Vault *ERC20VaultTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _ERC20Vault.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ERC20Vault *ERC20VaultSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _ERC20Vault.Contract.TransferOwnership(&_ERC20Vault.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ERC20Vault *ERC20VaultTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _ERC20Vault.Contract.TransferOwnership(&_ERC20Vault.TransactOpts, newOwner)
}

// ERC20VaultAddressManagerChangedIterator is returned from FilterAddressManagerChanged and is used to iterate over the raw logs and unpacked data for AddressManagerChanged events raised by the ERC20Vault contract.
type ERC20VaultAddressManagerChangedIterator struct {
	Event *ERC20VaultAddressManagerChanged // Event containing the contract specifics and raw log

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
func (it *ERC20VaultAddressManagerChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ERC20VaultAddressManagerChanged)
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
		it.Event = new(ERC20VaultAddressManagerChanged)
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
func (it *ERC20VaultAddressManagerChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ERC20VaultAddressManagerChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ERC20VaultAddressManagerChanged represents a AddressManagerChanged event raised by the ERC20Vault contract.
type ERC20VaultAddressManagerChanged struct {
	AddressManager common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterAddressManagerChanged is a free log retrieval operation binding the contract event 0x399ded90cb5ed8d89ef7e76ff4af65c373f06d3bf5d7eef55f4228e7b702a18b.
//
// Solidity: event AddressManagerChanged(address indexed addressManager)
func (_ERC20Vault *ERC20VaultFilterer) FilterAddressManagerChanged(opts *bind.FilterOpts, addressManager []common.Address) (*ERC20VaultAddressManagerChangedIterator, error) {

	var addressManagerRule []interface{}
	for _, addressManagerItem := range addressManager {
		addressManagerRule = append(addressManagerRule, addressManagerItem)
	}

	logs, sub, err := _ERC20Vault.contract.FilterLogs(opts, "AddressManagerChanged", addressManagerRule)
	if err != nil {
		return nil, err
	}
	return &ERC20VaultAddressManagerChangedIterator{contract: _ERC20Vault.contract, event: "AddressManagerChanged", logs: logs, sub: sub}, nil
}

// WatchAddressManagerChanged is a free log subscription operation binding the contract event 0x399ded90cb5ed8d89ef7e76ff4af65c373f06d3bf5d7eef55f4228e7b702a18b.
//
// Solidity: event AddressManagerChanged(address indexed addressManager)
func (_ERC20Vault *ERC20VaultFilterer) WatchAddressManagerChanged(opts *bind.WatchOpts, sink chan<- *ERC20VaultAddressManagerChanged, addressManager []common.Address) (event.Subscription, error) {

	var addressManagerRule []interface{}
	for _, addressManagerItem := range addressManager {
		addressManagerRule = append(addressManagerRule, addressManagerItem)
	}

	logs, sub, err := _ERC20Vault.contract.WatchLogs(opts, "AddressManagerChanged", addressManagerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ERC20VaultAddressManagerChanged)
				if err := _ERC20Vault.contract.UnpackLog(event, "AddressManagerChanged", log); err != nil {
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

// ParseAddressManagerChanged is a log parse operation binding the contract event 0x399ded90cb5ed8d89ef7e76ff4af65c373f06d3bf5d7eef55f4228e7b702a18b.
//
// Solidity: event AddressManagerChanged(address indexed addressManager)
func (_ERC20Vault *ERC20VaultFilterer) ParseAddressManagerChanged(log types.Log) (*ERC20VaultAddressManagerChanged, error) {
	event := new(ERC20VaultAddressManagerChanged)
	if err := _ERC20Vault.contract.UnpackLog(event, "AddressManagerChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ERC20VaultBridgedTokenDeployedIterator is returned from FilterBridgedTokenDeployed and is used to iterate over the raw logs and unpacked data for BridgedTokenDeployed events raised by the ERC20Vault contract.
type ERC20VaultBridgedTokenDeployedIterator struct {
	Event *ERC20VaultBridgedTokenDeployed // Event containing the contract specifics and raw log

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
func (it *ERC20VaultBridgedTokenDeployedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ERC20VaultBridgedTokenDeployed)
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
		it.Event = new(ERC20VaultBridgedTokenDeployed)
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
func (it *ERC20VaultBridgedTokenDeployedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ERC20VaultBridgedTokenDeployedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ERC20VaultBridgedTokenDeployed represents a BridgedTokenDeployed event raised by the ERC20Vault contract.
type ERC20VaultBridgedTokenDeployed struct {
	SrcChainId    *big.Int
	Ctoken        common.Address
	Btoken        common.Address
	CtokenSymbol  string
	CtokenName    string
	CtokenDecimal uint8
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterBridgedTokenDeployed is a free log retrieval operation binding the contract event 0xb6b427556e8cb0ebf9175da4bc48c64c4f56e44cfaf8c3ab5ebf8e2ea1309079.
//
// Solidity: event BridgedTokenDeployed(uint256 indexed srcChainId, address indexed ctoken, address indexed btoken, string ctokenSymbol, string ctokenName, uint8 ctokenDecimal)
func (_ERC20Vault *ERC20VaultFilterer) FilterBridgedTokenDeployed(opts *bind.FilterOpts, srcChainId []*big.Int, ctoken []common.Address, btoken []common.Address) (*ERC20VaultBridgedTokenDeployedIterator, error) {

	var srcChainIdRule []interface{}
	for _, srcChainIdItem := range srcChainId {
		srcChainIdRule = append(srcChainIdRule, srcChainIdItem)
	}
	var ctokenRule []interface{}
	for _, ctokenItem := range ctoken {
		ctokenRule = append(ctokenRule, ctokenItem)
	}
	var btokenRule []interface{}
	for _, btokenItem := range btoken {
		btokenRule = append(btokenRule, btokenItem)
	}

	logs, sub, err := _ERC20Vault.contract.FilterLogs(opts, "BridgedTokenDeployed", srcChainIdRule, ctokenRule, btokenRule)
	if err != nil {
		return nil, err
	}
	return &ERC20VaultBridgedTokenDeployedIterator{contract: _ERC20Vault.contract, event: "BridgedTokenDeployed", logs: logs, sub: sub}, nil
}

// WatchBridgedTokenDeployed is a free log subscription operation binding the contract event 0xb6b427556e8cb0ebf9175da4bc48c64c4f56e44cfaf8c3ab5ebf8e2ea1309079.
//
// Solidity: event BridgedTokenDeployed(uint256 indexed srcChainId, address indexed ctoken, address indexed btoken, string ctokenSymbol, string ctokenName, uint8 ctokenDecimal)
func (_ERC20Vault *ERC20VaultFilterer) WatchBridgedTokenDeployed(opts *bind.WatchOpts, sink chan<- *ERC20VaultBridgedTokenDeployed, srcChainId []*big.Int, ctoken []common.Address, btoken []common.Address) (event.Subscription, error) {

	var srcChainIdRule []interface{}
	for _, srcChainIdItem := range srcChainId {
		srcChainIdRule = append(srcChainIdRule, srcChainIdItem)
	}
	var ctokenRule []interface{}
	for _, ctokenItem := range ctoken {
		ctokenRule = append(ctokenRule, ctokenItem)
	}
	var btokenRule []interface{}
	for _, btokenItem := range btoken {
		btokenRule = append(btokenRule, btokenItem)
	}

	logs, sub, err := _ERC20Vault.contract.WatchLogs(opts, "BridgedTokenDeployed", srcChainIdRule, ctokenRule, btokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ERC20VaultBridgedTokenDeployed)
				if err := _ERC20Vault.contract.UnpackLog(event, "BridgedTokenDeployed", log); err != nil {
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

// ParseBridgedTokenDeployed is a log parse operation binding the contract event 0xb6b427556e8cb0ebf9175da4bc48c64c4f56e44cfaf8c3ab5ebf8e2ea1309079.
//
// Solidity: event BridgedTokenDeployed(uint256 indexed srcChainId, address indexed ctoken, address indexed btoken, string ctokenSymbol, string ctokenName, uint8 ctokenDecimal)
func (_ERC20Vault *ERC20VaultFilterer) ParseBridgedTokenDeployed(log types.Log) (*ERC20VaultBridgedTokenDeployed, error) {
	event := new(ERC20VaultBridgedTokenDeployed)
	if err := _ERC20Vault.contract.UnpackLog(event, "BridgedTokenDeployed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ERC20VaultInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the ERC20Vault contract.
type ERC20VaultInitializedIterator struct {
	Event *ERC20VaultInitialized // Event containing the contract specifics and raw log

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
func (it *ERC20VaultInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ERC20VaultInitialized)
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
		it.Event = new(ERC20VaultInitialized)
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
func (it *ERC20VaultInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ERC20VaultInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ERC20VaultInitialized represents a Initialized event raised by the ERC20Vault contract.
type ERC20VaultInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_ERC20Vault *ERC20VaultFilterer) FilterInitialized(opts *bind.FilterOpts) (*ERC20VaultInitializedIterator, error) {

	logs, sub, err := _ERC20Vault.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &ERC20VaultInitializedIterator{contract: _ERC20Vault.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_ERC20Vault *ERC20VaultFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *ERC20VaultInitialized) (event.Subscription, error) {

	logs, sub, err := _ERC20Vault.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ERC20VaultInitialized)
				if err := _ERC20Vault.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_ERC20Vault *ERC20VaultFilterer) ParseInitialized(log types.Log) (*ERC20VaultInitialized, error) {
	event := new(ERC20VaultInitialized)
	if err := _ERC20Vault.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ERC20VaultOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the ERC20Vault contract.
type ERC20VaultOwnershipTransferredIterator struct {
	Event *ERC20VaultOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *ERC20VaultOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ERC20VaultOwnershipTransferred)
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
		it.Event = new(ERC20VaultOwnershipTransferred)
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
func (it *ERC20VaultOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ERC20VaultOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ERC20VaultOwnershipTransferred represents a OwnershipTransferred event raised by the ERC20Vault contract.
type ERC20VaultOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_ERC20Vault *ERC20VaultFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*ERC20VaultOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ERC20Vault.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &ERC20VaultOwnershipTransferredIterator{contract: _ERC20Vault.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_ERC20Vault *ERC20VaultFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *ERC20VaultOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ERC20Vault.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ERC20VaultOwnershipTransferred)
				if err := _ERC20Vault.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_ERC20Vault *ERC20VaultFilterer) ParseOwnershipTransferred(log types.Log) (*ERC20VaultOwnershipTransferred, error) {
	event := new(ERC20VaultOwnershipTransferred)
	if err := _ERC20Vault.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ERC20VaultTokenReceivedIterator is returned from FilterTokenReceived and is used to iterate over the raw logs and unpacked data for TokenReceived events raised by the ERC20Vault contract.
type ERC20VaultTokenReceivedIterator struct {
	Event *ERC20VaultTokenReceived // Event containing the contract specifics and raw log

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
func (it *ERC20VaultTokenReceivedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ERC20VaultTokenReceived)
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
		it.Event = new(ERC20VaultTokenReceived)
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
func (it *ERC20VaultTokenReceivedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ERC20VaultTokenReceivedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ERC20VaultTokenReceived represents a TokenReceived event raised by the ERC20Vault contract.
type ERC20VaultTokenReceived struct {
	MsgHash    [32]byte
	From       common.Address
	To         common.Address
	SrcChainId *big.Int
	Token      common.Address
	Amount     *big.Int
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterTokenReceived is a free log retrieval operation binding the contract event 0x883b72735ca0ee2cdd2a462a393658b1a0b36ebd8756e4c22b7509a92ff86a02.
//
// Solidity: event TokenReceived(bytes32 indexed msgHash, address indexed from, address indexed to, uint256 srcChainId, address token, uint256 amount)
func (_ERC20Vault *ERC20VaultFilterer) FilterTokenReceived(opts *bind.FilterOpts, msgHash [][32]byte, from []common.Address, to []common.Address) (*ERC20VaultTokenReceivedIterator, error) {

	var msgHashRule []interface{}
	for _, msgHashItem := range msgHash {
		msgHashRule = append(msgHashRule, msgHashItem)
	}
	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}
	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}

	logs, sub, err := _ERC20Vault.contract.FilterLogs(opts, "TokenReceived", msgHashRule, fromRule, toRule)
	if err != nil {
		return nil, err
	}
	return &ERC20VaultTokenReceivedIterator{contract: _ERC20Vault.contract, event: "TokenReceived", logs: logs, sub: sub}, nil
}

// WatchTokenReceived is a free log subscription operation binding the contract event 0x883b72735ca0ee2cdd2a462a393658b1a0b36ebd8756e4c22b7509a92ff86a02.
//
// Solidity: event TokenReceived(bytes32 indexed msgHash, address indexed from, address indexed to, uint256 srcChainId, address token, uint256 amount)
func (_ERC20Vault *ERC20VaultFilterer) WatchTokenReceived(opts *bind.WatchOpts, sink chan<- *ERC20VaultTokenReceived, msgHash [][32]byte, from []common.Address, to []common.Address) (event.Subscription, error) {

	var msgHashRule []interface{}
	for _, msgHashItem := range msgHash {
		msgHashRule = append(msgHashRule, msgHashItem)
	}
	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}
	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}

	logs, sub, err := _ERC20Vault.contract.WatchLogs(opts, "TokenReceived", msgHashRule, fromRule, toRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ERC20VaultTokenReceived)
				if err := _ERC20Vault.contract.UnpackLog(event, "TokenReceived", log); err != nil {
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

// ParseTokenReceived is a log parse operation binding the contract event 0x883b72735ca0ee2cdd2a462a393658b1a0b36ebd8756e4c22b7509a92ff86a02.
//
// Solidity: event TokenReceived(bytes32 indexed msgHash, address indexed from, address indexed to, uint256 srcChainId, address token, uint256 amount)
func (_ERC20Vault *ERC20VaultFilterer) ParseTokenReceived(log types.Log) (*ERC20VaultTokenReceived, error) {
	event := new(ERC20VaultTokenReceived)
	if err := _ERC20Vault.contract.UnpackLog(event, "TokenReceived", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ERC20VaultTokenReleasedIterator is returned from FilterTokenReleased and is used to iterate over the raw logs and unpacked data for TokenReleased events raised by the ERC20Vault contract.
type ERC20VaultTokenReleasedIterator struct {
	Event *ERC20VaultTokenReleased // Event containing the contract specifics and raw log

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
func (it *ERC20VaultTokenReleasedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ERC20VaultTokenReleased)
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
		it.Event = new(ERC20VaultTokenReleased)
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
func (it *ERC20VaultTokenReleasedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ERC20VaultTokenReleasedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ERC20VaultTokenReleased represents a TokenReleased event raised by the ERC20Vault contract.
type ERC20VaultTokenReleased struct {
	MsgHash [32]byte
	From    common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterTokenReleased is a free log retrieval operation binding the contract event 0x75c5fedbd5fff6123ad9b70827e9742ea1eee996583d6e14249f1429fc4fd993.
//
// Solidity: event TokenReleased(bytes32 indexed msgHash, address indexed from, address token, uint256 amount)
func (_ERC20Vault *ERC20VaultFilterer) FilterTokenReleased(opts *bind.FilterOpts, msgHash [][32]byte, from []common.Address) (*ERC20VaultTokenReleasedIterator, error) {

	var msgHashRule []interface{}
	for _, msgHashItem := range msgHash {
		msgHashRule = append(msgHashRule, msgHashItem)
	}
	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}

	logs, sub, err := _ERC20Vault.contract.FilterLogs(opts, "TokenReleased", msgHashRule, fromRule)
	if err != nil {
		return nil, err
	}
	return &ERC20VaultTokenReleasedIterator{contract: _ERC20Vault.contract, event: "TokenReleased", logs: logs, sub: sub}, nil
}

// WatchTokenReleased is a free log subscription operation binding the contract event 0x75c5fedbd5fff6123ad9b70827e9742ea1eee996583d6e14249f1429fc4fd993.
//
// Solidity: event TokenReleased(bytes32 indexed msgHash, address indexed from, address token, uint256 amount)
func (_ERC20Vault *ERC20VaultFilterer) WatchTokenReleased(opts *bind.WatchOpts, sink chan<- *ERC20VaultTokenReleased, msgHash [][32]byte, from []common.Address) (event.Subscription, error) {

	var msgHashRule []interface{}
	for _, msgHashItem := range msgHash {
		msgHashRule = append(msgHashRule, msgHashItem)
	}
	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}

	logs, sub, err := _ERC20Vault.contract.WatchLogs(opts, "TokenReleased", msgHashRule, fromRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ERC20VaultTokenReleased)
				if err := _ERC20Vault.contract.UnpackLog(event, "TokenReleased", log); err != nil {
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

// ParseTokenReleased is a log parse operation binding the contract event 0x75c5fedbd5fff6123ad9b70827e9742ea1eee996583d6e14249f1429fc4fd993.
//
// Solidity: event TokenReleased(bytes32 indexed msgHash, address indexed from, address token, uint256 amount)
func (_ERC20Vault *ERC20VaultFilterer) ParseTokenReleased(log types.Log) (*ERC20VaultTokenReleased, error) {
	event := new(ERC20VaultTokenReleased)
	if err := _ERC20Vault.contract.UnpackLog(event, "TokenReleased", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ERC20VaultTokenSentIterator is returned from FilterTokenSent and is used to iterate over the raw logs and unpacked data for TokenSent events raised by the ERC20Vault contract.
type ERC20VaultTokenSentIterator struct {
	Event *ERC20VaultTokenSent // Event containing the contract specifics and raw log

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
func (it *ERC20VaultTokenSentIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ERC20VaultTokenSent)
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
		it.Event = new(ERC20VaultTokenSent)
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
func (it *ERC20VaultTokenSentIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ERC20VaultTokenSentIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ERC20VaultTokenSent represents a TokenSent event raised by the ERC20Vault contract.
type ERC20VaultTokenSent struct {
	MsgHash     [32]byte
	From        common.Address
	To          common.Address
	DestChainId *big.Int
	Token       common.Address
	Amount      *big.Int
	Raw         types.Log // Blockchain specific contextual infos
}

// FilterTokenSent is a free log retrieval operation binding the contract event 0x91462591aed3d13dcadac8ed73fdc175ec6e79b798ca205822e7ec33dc019e88.
//
// Solidity: event TokenSent(bytes32 indexed msgHash, address indexed from, address indexed to, uint256 destChainId, address token, uint256 amount)
func (_ERC20Vault *ERC20VaultFilterer) FilterTokenSent(opts *bind.FilterOpts, msgHash [][32]byte, from []common.Address, to []common.Address) (*ERC20VaultTokenSentIterator, error) {

	var msgHashRule []interface{}
	for _, msgHashItem := range msgHash {
		msgHashRule = append(msgHashRule, msgHashItem)
	}
	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}
	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}

	logs, sub, err := _ERC20Vault.contract.FilterLogs(opts, "TokenSent", msgHashRule, fromRule, toRule)
	if err != nil {
		return nil, err
	}
	return &ERC20VaultTokenSentIterator{contract: _ERC20Vault.contract, event: "TokenSent", logs: logs, sub: sub}, nil
}

// WatchTokenSent is a free log subscription operation binding the contract event 0x91462591aed3d13dcadac8ed73fdc175ec6e79b798ca205822e7ec33dc019e88.
//
// Solidity: event TokenSent(bytes32 indexed msgHash, address indexed from, address indexed to, uint256 destChainId, address token, uint256 amount)
func (_ERC20Vault *ERC20VaultFilterer) WatchTokenSent(opts *bind.WatchOpts, sink chan<- *ERC20VaultTokenSent, msgHash [][32]byte, from []common.Address, to []common.Address) (event.Subscription, error) {

	var msgHashRule []interface{}
	for _, msgHashItem := range msgHash {
		msgHashRule = append(msgHashRule, msgHashItem)
	}
	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}
	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}

	logs, sub, err := _ERC20Vault.contract.WatchLogs(opts, "TokenSent", msgHashRule, fromRule, toRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ERC20VaultTokenSent)
				if err := _ERC20Vault.contract.UnpackLog(event, "TokenSent", log); err != nil {
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

// ParseTokenSent is a log parse operation binding the contract event 0x91462591aed3d13dcadac8ed73fdc175ec6e79b798ca205822e7ec33dc019e88.
//
// Solidity: event TokenSent(bytes32 indexed msgHash, address indexed from, address indexed to, uint256 destChainId, address token, uint256 amount)
func (_ERC20Vault *ERC20VaultFilterer) ParseTokenSent(log types.Log) (*ERC20VaultTokenSent, error) {
	event := new(ERC20VaultTokenSent)
	if err := _ERC20Vault.contract.UnpackLog(event, "TokenSent", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
