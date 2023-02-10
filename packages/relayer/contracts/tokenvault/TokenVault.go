// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package tokenvault

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

// TokenVaultCanonicalERC20 is an auto generated low-level Go binding around an user-defined struct.
type TokenVaultCanonicalERC20 struct {
	ChainId  *big.Int
	Addr     common.Address
	Decimals uint8
	Symbol   string
	Name     string
}

// TokenVaultABI is the input ABI used to generate the binding from.
const TokenVaultABI = "[{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"srcChainId\",\"type\":\"uint256\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"canonicalToken\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"bridgedToken\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"string\",\"name\":\"canonicalTokenSymbol\",\"type\":\"string\"},{\"indexed\":false,\"internalType\":\"string\",\"name\":\"canonicalTokenName\",\"type\":\"string\"},{\"indexed\":false,\"internalType\":\"uint8\",\"name\":\"canonicalTokenDecimal\",\"type\":\"uint8\"}],\"name\":\"BridgedERC20Deployed\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"bytes32\",\"name\":\"msgHash\",\"type\":\"bytes32\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"from\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"srcChainId\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"token\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"ERC20Received\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"bytes32\",\"name\":\"msgHash\",\"type\":\"bytes32\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"from\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"token\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"ERC20Released\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"bytes32\",\"name\":\"msgHash\",\"type\":\"bytes32\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"from\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"destChainId\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"token\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"ERC20Sent\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"bytes32\",\"name\":\"msgHash\",\"type\":\"bytes32\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"from\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"destChainId\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"EtherSent\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint8\",\"name\":\"version\",\"type\":\"uint8\"}],\"name\":\"Initialized\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"previousOwner\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"OwnershipTransferred\",\"type\":\"event\"},{\"inputs\":[],\"name\":\"addressManager\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"name\":\"bridgedToCanonical\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"addr\",\"type\":\"address\"},{\"internalType\":\"uint8\",\"name\":\"decimals\",\"type\":\"uint8\"},{\"internalType\":\"string\",\"name\":\"symbol\",\"type\":\"string\"},{\"internalType\":\"string\",\"name\":\"name\",\"type\":\"string\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"name\":\"canonicalToBridged\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"addressManager\",\"type\":\"address\"}],\"name\":\"init\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"name\":\"isBridgedToken\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"name\":\"messageDeposits\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"token\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"owner\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"components\":[{\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"addr\",\"type\":\"address\"},{\"internalType\":\"uint8\",\"name\":\"decimals\",\"type\":\"uint8\"},{\"internalType\":\"string\",\"name\":\"symbol\",\"type\":\"string\"},{\"internalType\":\"string\",\"name\":\"name\",\"type\":\"string\"}],\"internalType\":\"structTokenVault.CanonicalERC20\",\"name\":\"canonicalToken\",\"type\":\"tuple\"},{\"internalType\":\"address\",\"name\":\"from\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"receiveERC20\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"components\":[{\"internalType\":\"uint256\",\"name\":\"id\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"sender\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"srcChainId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"destChainId\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"owner\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"refundAddress\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"depositValue\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"callValue\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"processingFee\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"gasLimit\",\"type\":\"uint256\"},{\"internalType\":\"bytes\",\"name\":\"data\",\"type\":\"bytes\"},{\"internalType\":\"string\",\"name\":\"memo\",\"type\":\"string\"}],\"internalType\":\"structIBridge.Message\",\"name\":\"message\",\"type\":\"tuple\"},{\"internalType\":\"bytes\",\"name\":\"proof\",\"type\":\"bytes\"}],\"name\":\"releaseERC20\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"renounceOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"string\",\"name\":\"name\",\"type\":\"string\"},{\"internalType\":\"bool\",\"name\":\"allowZeroAddress\",\"type\":\"bool\"}],\"name\":\"resolve\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"internalType\":\"string\",\"name\":\"name\",\"type\":\"string\"},{\"internalType\":\"bool\",\"name\":\"allowZeroAddress\",\"type\":\"bool\"}],\"name\":\"resolve\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"destChainId\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"token\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"gasLimit\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"processingFee\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"refundAddress\",\"type\":\"address\"},{\"internalType\":\"string\",\"name\":\"memo\",\"type\":\"string\"}],\"name\":\"sendERC20\",\"outputs\":[],\"stateMutability\":\"payable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"destChainId\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"gasLimit\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"processingFee\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"refundAddress\",\"type\":\"address\"},{\"internalType\":\"string\",\"name\":\"memo\",\"type\":\"string\"}],\"name\":\"sendEther\",\"outputs\":[],\"stateMutability\":\"payable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"transferOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"}]"

// TokenVault is an auto generated Go binding around an Ethereum contract.
type TokenVault struct {
	TokenVaultCaller     // Read-only binding to the contract
	TokenVaultTransactor // Write-only binding to the contract
	TokenVaultFilterer   // Log filterer for contract events
}

// TokenVaultCaller is an auto generated read-only Go binding around an Ethereum contract.
type TokenVaultCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TokenVaultTransactor is an auto generated write-only Go binding around an Ethereum contract.
type TokenVaultTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TokenVaultFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type TokenVaultFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TokenVaultSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type TokenVaultSession struct {
	Contract     *TokenVault       // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// TokenVaultCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type TokenVaultCallerSession struct {
	Contract *TokenVaultCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts     // Call options to use throughout this session
}

// TokenVaultTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type TokenVaultTransactorSession struct {
	Contract     *TokenVaultTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts     // Transaction auth options to use throughout this session
}

// TokenVaultRaw is an auto generated low-level Go binding around an Ethereum contract.
type TokenVaultRaw struct {
	Contract *TokenVault // Generic contract binding to access the raw methods on
}

// TokenVaultCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type TokenVaultCallerRaw struct {
	Contract *TokenVaultCaller // Generic read-only contract binding to access the raw methods on
}

// TokenVaultTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type TokenVaultTransactorRaw struct {
	Contract *TokenVaultTransactor // Generic write-only contract binding to access the raw methods on
}

// NewTokenVault creates a new instance of TokenVault, bound to a specific deployed contract.
func NewTokenVault(address common.Address, backend bind.ContractBackend) (*TokenVault, error) {
	contract, err := bindTokenVault(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &TokenVault{TokenVaultCaller: TokenVaultCaller{contract: contract}, TokenVaultTransactor: TokenVaultTransactor{contract: contract}, TokenVaultFilterer: TokenVaultFilterer{contract: contract}}, nil
}

// NewTokenVaultCaller creates a new read-only instance of TokenVault, bound to a specific deployed contract.
func NewTokenVaultCaller(address common.Address, caller bind.ContractCaller) (*TokenVaultCaller, error) {
	contract, err := bindTokenVault(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &TokenVaultCaller{contract: contract}, nil
}

// NewTokenVaultTransactor creates a new write-only instance of TokenVault, bound to a specific deployed contract.
func NewTokenVaultTransactor(address common.Address, transactor bind.ContractTransactor) (*TokenVaultTransactor, error) {
	contract, err := bindTokenVault(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &TokenVaultTransactor{contract: contract}, nil
}

// NewTokenVaultFilterer creates a new log filterer instance of TokenVault, bound to a specific deployed contract.
func NewTokenVaultFilterer(address common.Address, filterer bind.ContractFilterer) (*TokenVaultFilterer, error) {
	contract, err := bindTokenVault(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &TokenVaultFilterer{contract: contract}, nil
}

// bindTokenVault binds a generic wrapper to an already deployed contract.
func bindTokenVault(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := abi.JSON(strings.NewReader(TokenVaultABI))
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TokenVault *TokenVaultRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TokenVault.Contract.TokenVaultCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TokenVault *TokenVaultRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TokenVault.Contract.TokenVaultTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TokenVault *TokenVaultRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TokenVault.Contract.TokenVaultTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TokenVault *TokenVaultCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TokenVault.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TokenVault *TokenVaultTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TokenVault.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TokenVault *TokenVaultTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TokenVault.Contract.contract.Transact(opts, method, params...)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_TokenVault *TokenVaultCaller) AddressManager(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TokenVault.contract.Call(opts, &out, "addressManager")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_TokenVault *TokenVaultSession) AddressManager() (common.Address, error) {
	return _TokenVault.Contract.AddressManager(&_TokenVault.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_TokenVault *TokenVaultCallerSession) AddressManager() (common.Address, error) {
	return _TokenVault.Contract.AddressManager(&_TokenVault.CallOpts)
}

// BridgedToCanonical is a free data retrieval call binding the contract method 0x9aa8605c.
//
// Solidity: function bridgedToCanonical(address ) view returns(uint256 chainId, address addr, uint8 decimals, string symbol, string name)
func (_TokenVault *TokenVaultCaller) BridgedToCanonical(opts *bind.CallOpts, arg0 common.Address) (struct {
	ChainId  *big.Int
	Addr     common.Address
	Decimals uint8
	Symbol   string
	Name     string
}, error) {
	var out []interface{}
	err := _TokenVault.contract.Call(opts, &out, "bridgedToCanonical", arg0)

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
func (_TokenVault *TokenVaultSession) BridgedToCanonical(arg0 common.Address) (struct {
	ChainId  *big.Int
	Addr     common.Address
	Decimals uint8
	Symbol   string
	Name     string
}, error) {
	return _TokenVault.Contract.BridgedToCanonical(&_TokenVault.CallOpts, arg0)
}

// BridgedToCanonical is a free data retrieval call binding the contract method 0x9aa8605c.
//
// Solidity: function bridgedToCanonical(address ) view returns(uint256 chainId, address addr, uint8 decimals, string symbol, string name)
func (_TokenVault *TokenVaultCallerSession) BridgedToCanonical(arg0 common.Address) (struct {
	ChainId  *big.Int
	Addr     common.Address
	Decimals uint8
	Symbol   string
	Name     string
}, error) {
	return _TokenVault.Contract.BridgedToCanonical(&_TokenVault.CallOpts, arg0)
}

// CanonicalToBridged is a free data retrieval call binding the contract method 0x67090ccf.
//
// Solidity: function canonicalToBridged(uint256 , address ) view returns(address)
func (_TokenVault *TokenVaultCaller) CanonicalToBridged(opts *bind.CallOpts, arg0 *big.Int, arg1 common.Address) (common.Address, error) {
	var out []interface{}
	err := _TokenVault.contract.Call(opts, &out, "canonicalToBridged", arg0, arg1)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CanonicalToBridged is a free data retrieval call binding the contract method 0x67090ccf.
//
// Solidity: function canonicalToBridged(uint256 , address ) view returns(address)
func (_TokenVault *TokenVaultSession) CanonicalToBridged(arg0 *big.Int, arg1 common.Address) (common.Address, error) {
	return _TokenVault.Contract.CanonicalToBridged(&_TokenVault.CallOpts, arg0, arg1)
}

// CanonicalToBridged is a free data retrieval call binding the contract method 0x67090ccf.
//
// Solidity: function canonicalToBridged(uint256 , address ) view returns(address)
func (_TokenVault *TokenVaultCallerSession) CanonicalToBridged(arg0 *big.Int, arg1 common.Address) (common.Address, error) {
	return _TokenVault.Contract.CanonicalToBridged(&_TokenVault.CallOpts, arg0, arg1)
}

// IsBridgedToken is a free data retrieval call binding the contract method 0xc287e578.
//
// Solidity: function isBridgedToken(address ) view returns(bool)
func (_TokenVault *TokenVaultCaller) IsBridgedToken(opts *bind.CallOpts, arg0 common.Address) (bool, error) {
	var out []interface{}
	err := _TokenVault.contract.Call(opts, &out, "isBridgedToken", arg0)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsBridgedToken is a free data retrieval call binding the contract method 0xc287e578.
//
// Solidity: function isBridgedToken(address ) view returns(bool)
func (_TokenVault *TokenVaultSession) IsBridgedToken(arg0 common.Address) (bool, error) {
	return _TokenVault.Contract.IsBridgedToken(&_TokenVault.CallOpts, arg0)
}

// IsBridgedToken is a free data retrieval call binding the contract method 0xc287e578.
//
// Solidity: function isBridgedToken(address ) view returns(bool)
func (_TokenVault *TokenVaultCallerSession) IsBridgedToken(arg0 common.Address) (bool, error) {
	return _TokenVault.Contract.IsBridgedToken(&_TokenVault.CallOpts, arg0)
}

// MessageDeposits is a free data retrieval call binding the contract method 0x780b64f0.
//
// Solidity: function messageDeposits(bytes32 ) view returns(address token, uint256 amount)
func (_TokenVault *TokenVaultCaller) MessageDeposits(opts *bind.CallOpts, arg0 [32]byte) (struct {
	Token  common.Address
	Amount *big.Int
}, error) {
	var out []interface{}
	err := _TokenVault.contract.Call(opts, &out, "messageDeposits", arg0)

	outstruct := new(struct {
		Token  common.Address
		Amount *big.Int
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Token = *abi.ConvertType(out[0], new(common.Address)).(*common.Address)
	outstruct.Amount = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)

	return *outstruct, err

}

// MessageDeposits is a free data retrieval call binding the contract method 0x780b64f0.
//
// Solidity: function messageDeposits(bytes32 ) view returns(address token, uint256 amount)
func (_TokenVault *TokenVaultSession) MessageDeposits(arg0 [32]byte) (struct {
	Token  common.Address
	Amount *big.Int
}, error) {
	return _TokenVault.Contract.MessageDeposits(&_TokenVault.CallOpts, arg0)
}

// MessageDeposits is a free data retrieval call binding the contract method 0x780b64f0.
//
// Solidity: function messageDeposits(bytes32 ) view returns(address token, uint256 amount)
func (_TokenVault *TokenVaultCallerSession) MessageDeposits(arg0 [32]byte) (struct {
	Token  common.Address
	Amount *big.Int
}, error) {
	return _TokenVault.Contract.MessageDeposits(&_TokenVault.CallOpts, arg0)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TokenVault *TokenVaultCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TokenVault.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TokenVault *TokenVaultSession) Owner() (common.Address, error) {
	return _TokenVault.Contract.Owner(&_TokenVault.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TokenVault *TokenVaultCallerSession) Owner() (common.Address, error) {
	return _TokenVault.Contract.Owner(&_TokenVault.CallOpts)
}

// Resolve is a free data retrieval call binding the contract method 0x0ca4dffd.
//
// Solidity: function resolve(string name, bool allowZeroAddress) view returns(address)
func (_TokenVault *TokenVaultCaller) Resolve(opts *bind.CallOpts, name string, allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _TokenVault.contract.Call(opts, &out, "resolve", name, allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve is a free data retrieval call binding the contract method 0x0ca4dffd.
//
// Solidity: function resolve(string name, bool allowZeroAddress) view returns(address)
func (_TokenVault *TokenVaultSession) Resolve(name string, allowZeroAddress bool) (common.Address, error) {
	return _TokenVault.Contract.Resolve(&_TokenVault.CallOpts, name, allowZeroAddress)
}

// Resolve is a free data retrieval call binding the contract method 0x0ca4dffd.
//
// Solidity: function resolve(string name, bool allowZeroAddress) view returns(address)
func (_TokenVault *TokenVaultCallerSession) Resolve(name string, allowZeroAddress bool) (common.Address, error) {
	return _TokenVault.Contract.Resolve(&_TokenVault.CallOpts, name, allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0x1be2bfa7.
//
// Solidity: function resolve(uint256 chainId, string name, bool allowZeroAddress) view returns(address)
func (_TokenVault *TokenVaultCaller) Resolve0(opts *bind.CallOpts, chainId *big.Int, name string, allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _TokenVault.contract.Call(opts, &out, "resolve0", chainId, name, allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve0 is a free data retrieval call binding the contract method 0x1be2bfa7.
//
// Solidity: function resolve(uint256 chainId, string name, bool allowZeroAddress) view returns(address)
func (_TokenVault *TokenVaultSession) Resolve0(chainId *big.Int, name string, allowZeroAddress bool) (common.Address, error) {
	return _TokenVault.Contract.Resolve0(&_TokenVault.CallOpts, chainId, name, allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0x1be2bfa7.
//
// Solidity: function resolve(uint256 chainId, string name, bool allowZeroAddress) view returns(address)
func (_TokenVault *TokenVaultCallerSession) Resolve0(chainId *big.Int, name string, allowZeroAddress bool) (common.Address, error) {
	return _TokenVault.Contract.Resolve0(&_TokenVault.CallOpts, chainId, name, allowZeroAddress)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address addressManager) returns()
func (_TokenVault *TokenVaultTransactor) Init(opts *bind.TransactOpts, addressManager common.Address) (*types.Transaction, error) {
	return _TokenVault.contract.Transact(opts, "init", addressManager)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address addressManager) returns()
func (_TokenVault *TokenVaultSession) Init(addressManager common.Address) (*types.Transaction, error) {
	return _TokenVault.Contract.Init(&_TokenVault.TransactOpts, addressManager)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address addressManager) returns()
func (_TokenVault *TokenVaultTransactorSession) Init(addressManager common.Address) (*types.Transaction, error) {
	return _TokenVault.Contract.Init(&_TokenVault.TransactOpts, addressManager)
}

// ReceiveERC20 is a paid mutator transaction binding the contract method 0x0c6fab82.
//
// Solidity: function receiveERC20((uint256,address,uint8,string,string) canonicalToken, address from, address to, uint256 amount) returns()
func (_TokenVault *TokenVaultTransactor) ReceiveERC20(opts *bind.TransactOpts, canonicalToken TokenVaultCanonicalERC20, from common.Address, to common.Address, amount *big.Int) (*types.Transaction, error) {
	return _TokenVault.contract.Transact(opts, "receiveERC20", canonicalToken, from, to, amount)
}

// ReceiveERC20 is a paid mutator transaction binding the contract method 0x0c6fab82.
//
// Solidity: function receiveERC20((uint256,address,uint8,string,string) canonicalToken, address from, address to, uint256 amount) returns()
func (_TokenVault *TokenVaultSession) ReceiveERC20(canonicalToken TokenVaultCanonicalERC20, from common.Address, to common.Address, amount *big.Int) (*types.Transaction, error) {
	return _TokenVault.Contract.ReceiveERC20(&_TokenVault.TransactOpts, canonicalToken, from, to, amount)
}

// ReceiveERC20 is a paid mutator transaction binding the contract method 0x0c6fab82.
//
// Solidity: function receiveERC20((uint256,address,uint8,string,string) canonicalToken, address from, address to, uint256 amount) returns()
func (_TokenVault *TokenVaultTransactorSession) ReceiveERC20(canonicalToken TokenVaultCanonicalERC20, from common.Address, to common.Address, amount *big.Int) (*types.Transaction, error) {
	return _TokenVault.Contract.ReceiveERC20(&_TokenVault.TransactOpts, canonicalToken, from, to, amount)
}

// ReleaseERC20 is a paid mutator transaction binding the contract method 0x9754149b.
//
// Solidity: function releaseERC20((uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,uint256,bytes,string) message, bytes proof) returns()
func (_TokenVault *TokenVaultTransactor) ReleaseERC20(opts *bind.TransactOpts, message IBridgeMessage, proof []byte) (*types.Transaction, error) {
	return _TokenVault.contract.Transact(opts, "releaseERC20", message, proof)
}

// ReleaseERC20 is a paid mutator transaction binding the contract method 0x9754149b.
//
// Solidity: function releaseERC20((uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,uint256,bytes,string) message, bytes proof) returns()
func (_TokenVault *TokenVaultSession) ReleaseERC20(message IBridgeMessage, proof []byte) (*types.Transaction, error) {
	return _TokenVault.Contract.ReleaseERC20(&_TokenVault.TransactOpts, message, proof)
}

// ReleaseERC20 is a paid mutator transaction binding the contract method 0x9754149b.
//
// Solidity: function releaseERC20((uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,uint256,bytes,string) message, bytes proof) returns()
func (_TokenVault *TokenVaultTransactorSession) ReleaseERC20(message IBridgeMessage, proof []byte) (*types.Transaction, error) {
	return _TokenVault.Contract.ReleaseERC20(&_TokenVault.TransactOpts, message, proof)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TokenVault *TokenVaultTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TokenVault.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TokenVault *TokenVaultSession) RenounceOwnership() (*types.Transaction, error) {
	return _TokenVault.Contract.RenounceOwnership(&_TokenVault.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TokenVault *TokenVaultTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _TokenVault.Contract.RenounceOwnership(&_TokenVault.TransactOpts)
}

// SendERC20 is a paid mutator transaction binding the contract method 0xee1490b2.
//
// Solidity: function sendERC20(uint256 destChainId, address to, address token, uint256 amount, uint256 gasLimit, uint256 processingFee, address refundAddress, string memo) payable returns()
func (_TokenVault *TokenVaultTransactor) SendERC20(opts *bind.TransactOpts, destChainId *big.Int, to common.Address, token common.Address, amount *big.Int, gasLimit *big.Int, processingFee *big.Int, refundAddress common.Address, memo string) (*types.Transaction, error) {
	return _TokenVault.contract.Transact(opts, "sendERC20", destChainId, to, token, amount, gasLimit, processingFee, refundAddress, memo)
}

// SendERC20 is a paid mutator transaction binding the contract method 0xee1490b2.
//
// Solidity: function sendERC20(uint256 destChainId, address to, address token, uint256 amount, uint256 gasLimit, uint256 processingFee, address refundAddress, string memo) payable returns()
func (_TokenVault *TokenVaultSession) SendERC20(destChainId *big.Int, to common.Address, token common.Address, amount *big.Int, gasLimit *big.Int, processingFee *big.Int, refundAddress common.Address, memo string) (*types.Transaction, error) {
	return _TokenVault.Contract.SendERC20(&_TokenVault.TransactOpts, destChainId, to, token, amount, gasLimit, processingFee, refundAddress, memo)
}

// SendERC20 is a paid mutator transaction binding the contract method 0xee1490b2.
//
// Solidity: function sendERC20(uint256 destChainId, address to, address token, uint256 amount, uint256 gasLimit, uint256 processingFee, address refundAddress, string memo) payable returns()
func (_TokenVault *TokenVaultTransactorSession) SendERC20(destChainId *big.Int, to common.Address, token common.Address, amount *big.Int, gasLimit *big.Int, processingFee *big.Int, refundAddress common.Address, memo string) (*types.Transaction, error) {
	return _TokenVault.Contract.SendERC20(&_TokenVault.TransactOpts, destChainId, to, token, amount, gasLimit, processingFee, refundAddress, memo)
}

// SendEther is a paid mutator transaction binding the contract method 0x39da33ba.
//
// Solidity: function sendEther(uint256 destChainId, address to, uint256 gasLimit, uint256 processingFee, address refundAddress, string memo) payable returns()
func (_TokenVault *TokenVaultTransactor) SendEther(opts *bind.TransactOpts, destChainId *big.Int, to common.Address, gasLimit *big.Int, processingFee *big.Int, refundAddress common.Address, memo string) (*types.Transaction, error) {
	return _TokenVault.contract.Transact(opts, "sendEther", destChainId, to, gasLimit, processingFee, refundAddress, memo)
}

// SendEther is a paid mutator transaction binding the contract method 0x39da33ba.
//
// Solidity: function sendEther(uint256 destChainId, address to, uint256 gasLimit, uint256 processingFee, address refundAddress, string memo) payable returns()
func (_TokenVault *TokenVaultSession) SendEther(destChainId *big.Int, to common.Address, gasLimit *big.Int, processingFee *big.Int, refundAddress common.Address, memo string) (*types.Transaction, error) {
	return _TokenVault.Contract.SendEther(&_TokenVault.TransactOpts, destChainId, to, gasLimit, processingFee, refundAddress, memo)
}

// SendEther is a paid mutator transaction binding the contract method 0x39da33ba.
//
// Solidity: function sendEther(uint256 destChainId, address to, uint256 gasLimit, uint256 processingFee, address refundAddress, string memo) payable returns()
func (_TokenVault *TokenVaultTransactorSession) SendEther(destChainId *big.Int, to common.Address, gasLimit *big.Int, processingFee *big.Int, refundAddress common.Address, memo string) (*types.Transaction, error) {
	return _TokenVault.Contract.SendEther(&_TokenVault.TransactOpts, destChainId, to, gasLimit, processingFee, refundAddress, memo)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TokenVault *TokenVaultTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _TokenVault.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TokenVault *TokenVaultSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _TokenVault.Contract.TransferOwnership(&_TokenVault.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TokenVault *TokenVaultTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _TokenVault.Contract.TransferOwnership(&_TokenVault.TransactOpts, newOwner)
}

// TokenVaultBridgedERC20DeployedIterator is returned from FilterBridgedERC20Deployed and is used to iterate over the raw logs and unpacked data for BridgedERC20Deployed events raised by the TokenVault contract.
type TokenVaultBridgedERC20DeployedIterator struct {
	Event *TokenVaultBridgedERC20Deployed // Event containing the contract specifics and raw log

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
func (it *TokenVaultBridgedERC20DeployedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenVaultBridgedERC20Deployed)
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
		it.Event = new(TokenVaultBridgedERC20Deployed)
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
func (it *TokenVaultBridgedERC20DeployedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenVaultBridgedERC20DeployedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenVaultBridgedERC20Deployed represents a BridgedERC20Deployed event raised by the TokenVault contract.
type TokenVaultBridgedERC20Deployed struct {
	SrcChainId            *big.Int
	CanonicalToken        common.Address
	BridgedToken          common.Address
	CanonicalTokenSymbol  string
	CanonicalTokenName    string
	CanonicalTokenDecimal uint8
	Raw                   types.Log // Blockchain specific contextual infos
}

// FilterBridgedERC20Deployed is a free log retrieval operation binding the contract event 0x9e465b29e576a3e01584e31d607353f21b80c055e813af907c0a495f6cf4f7bc.
//
// Solidity: event BridgedERC20Deployed(uint256 indexed srcChainId, address indexed canonicalToken, address indexed bridgedToken, string canonicalTokenSymbol, string canonicalTokenName, uint8 canonicalTokenDecimal)
func (_TokenVault *TokenVaultFilterer) FilterBridgedERC20Deployed(opts *bind.FilterOpts, srcChainId []*big.Int, canonicalToken []common.Address, bridgedToken []common.Address) (*TokenVaultBridgedERC20DeployedIterator, error) {

	var srcChainIdRule []interface{}
	for _, srcChainIdItem := range srcChainId {
		srcChainIdRule = append(srcChainIdRule, srcChainIdItem)
	}
	var canonicalTokenRule []interface{}
	for _, canonicalTokenItem := range canonicalToken {
		canonicalTokenRule = append(canonicalTokenRule, canonicalTokenItem)
	}
	var bridgedTokenRule []interface{}
	for _, bridgedTokenItem := range bridgedToken {
		bridgedTokenRule = append(bridgedTokenRule, bridgedTokenItem)
	}

	logs, sub, err := _TokenVault.contract.FilterLogs(opts, "BridgedERC20Deployed", srcChainIdRule, canonicalTokenRule, bridgedTokenRule)
	if err != nil {
		return nil, err
	}
	return &TokenVaultBridgedERC20DeployedIterator{contract: _TokenVault.contract, event: "BridgedERC20Deployed", logs: logs, sub: sub}, nil
}

// WatchBridgedERC20Deployed is a free log subscription operation binding the contract event 0x9e465b29e576a3e01584e31d607353f21b80c055e813af907c0a495f6cf4f7bc.
//
// Solidity: event BridgedERC20Deployed(uint256 indexed srcChainId, address indexed canonicalToken, address indexed bridgedToken, string canonicalTokenSymbol, string canonicalTokenName, uint8 canonicalTokenDecimal)
func (_TokenVault *TokenVaultFilterer) WatchBridgedERC20Deployed(opts *bind.WatchOpts, sink chan<- *TokenVaultBridgedERC20Deployed, srcChainId []*big.Int, canonicalToken []common.Address, bridgedToken []common.Address) (event.Subscription, error) {

	var srcChainIdRule []interface{}
	for _, srcChainIdItem := range srcChainId {
		srcChainIdRule = append(srcChainIdRule, srcChainIdItem)
	}
	var canonicalTokenRule []interface{}
	for _, canonicalTokenItem := range canonicalToken {
		canonicalTokenRule = append(canonicalTokenRule, canonicalTokenItem)
	}
	var bridgedTokenRule []interface{}
	for _, bridgedTokenItem := range bridgedToken {
		bridgedTokenRule = append(bridgedTokenRule, bridgedTokenItem)
	}

	logs, sub, err := _TokenVault.contract.WatchLogs(opts, "BridgedERC20Deployed", srcChainIdRule, canonicalTokenRule, bridgedTokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenVaultBridgedERC20Deployed)
				if err := _TokenVault.contract.UnpackLog(event, "BridgedERC20Deployed", log); err != nil {
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

// ParseBridgedERC20Deployed is a log parse operation binding the contract event 0x9e465b29e576a3e01584e31d607353f21b80c055e813af907c0a495f6cf4f7bc.
//
// Solidity: event BridgedERC20Deployed(uint256 indexed srcChainId, address indexed canonicalToken, address indexed bridgedToken, string canonicalTokenSymbol, string canonicalTokenName, uint8 canonicalTokenDecimal)
func (_TokenVault *TokenVaultFilterer) ParseBridgedERC20Deployed(log types.Log) (*TokenVaultBridgedERC20Deployed, error) {
	event := new(TokenVaultBridgedERC20Deployed)
	if err := _TokenVault.contract.UnpackLog(event, "BridgedERC20Deployed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TokenVaultERC20ReceivedIterator is returned from FilterERC20Received and is used to iterate over the raw logs and unpacked data for ERC20Received events raised by the TokenVault contract.
type TokenVaultERC20ReceivedIterator struct {
	Event *TokenVaultERC20Received // Event containing the contract specifics and raw log

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
func (it *TokenVaultERC20ReceivedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenVaultERC20Received)
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
		it.Event = new(TokenVaultERC20Received)
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
func (it *TokenVaultERC20ReceivedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenVaultERC20ReceivedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenVaultERC20Received represents a ERC20Received event raised by the TokenVault contract.
type TokenVaultERC20Received struct {
	MsgHash    [32]byte
	From       common.Address
	To         common.Address
	SrcChainId *big.Int
	Token      common.Address
	Amount     *big.Int
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterERC20Received is a free log retrieval operation binding the contract event 0xe5da926519fc972010fe65b35c1e3339e6dc72b35ffaec203999c2a2a2593eac.
//
// Solidity: event ERC20Received(bytes32 indexed msgHash, address indexed from, address indexed to, uint256 srcChainId, address token, uint256 amount)
func (_TokenVault *TokenVaultFilterer) FilterERC20Received(opts *bind.FilterOpts, msgHash [][32]byte, from []common.Address, to []common.Address) (*TokenVaultERC20ReceivedIterator, error) {

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

	logs, sub, err := _TokenVault.contract.FilterLogs(opts, "ERC20Received", msgHashRule, fromRule, toRule)
	if err != nil {
		return nil, err
	}
	return &TokenVaultERC20ReceivedIterator{contract: _TokenVault.contract, event: "ERC20Received", logs: logs, sub: sub}, nil
}

// WatchERC20Received is a free log subscription operation binding the contract event 0xe5da926519fc972010fe65b35c1e3339e6dc72b35ffaec203999c2a2a2593eac.
//
// Solidity: event ERC20Received(bytes32 indexed msgHash, address indexed from, address indexed to, uint256 srcChainId, address token, uint256 amount)
func (_TokenVault *TokenVaultFilterer) WatchERC20Received(opts *bind.WatchOpts, sink chan<- *TokenVaultERC20Received, msgHash [][32]byte, from []common.Address, to []common.Address) (event.Subscription, error) {

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

	logs, sub, err := _TokenVault.contract.WatchLogs(opts, "ERC20Received", msgHashRule, fromRule, toRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenVaultERC20Received)
				if err := _TokenVault.contract.UnpackLog(event, "ERC20Received", log); err != nil {
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

// ParseERC20Received is a log parse operation binding the contract event 0xe5da926519fc972010fe65b35c1e3339e6dc72b35ffaec203999c2a2a2593eac.
//
// Solidity: event ERC20Received(bytes32 indexed msgHash, address indexed from, address indexed to, uint256 srcChainId, address token, uint256 amount)
func (_TokenVault *TokenVaultFilterer) ParseERC20Received(log types.Log) (*TokenVaultERC20Received, error) {
	event := new(TokenVaultERC20Received)
	if err := _TokenVault.contract.UnpackLog(event, "ERC20Received", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TokenVaultERC20ReleasedIterator is returned from FilterERC20Released and is used to iterate over the raw logs and unpacked data for ERC20Released events raised by the TokenVault contract.
type TokenVaultERC20ReleasedIterator struct {
	Event *TokenVaultERC20Released // Event containing the contract specifics and raw log

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
func (it *TokenVaultERC20ReleasedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenVaultERC20Released)
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
		it.Event = new(TokenVaultERC20Released)
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
func (it *TokenVaultERC20ReleasedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenVaultERC20ReleasedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenVaultERC20Released represents a ERC20Released event raised by the TokenVault contract.
type TokenVaultERC20Released struct {
	MsgHash [32]byte
	From    common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterERC20Released is a free log retrieval operation binding the contract event 0xc5d9f7cd7998e24ecf12ad69eca9339764e2cb13788d5d9616f502601b219af6.
//
// Solidity: event ERC20Released(bytes32 indexed msgHash, address indexed from, address token, uint256 amount)
func (_TokenVault *TokenVaultFilterer) FilterERC20Released(opts *bind.FilterOpts, msgHash [][32]byte, from []common.Address) (*TokenVaultERC20ReleasedIterator, error) {

	var msgHashRule []interface{}
	for _, msgHashItem := range msgHash {
		msgHashRule = append(msgHashRule, msgHashItem)
	}
	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}

	logs, sub, err := _TokenVault.contract.FilterLogs(opts, "ERC20Released", msgHashRule, fromRule)
	if err != nil {
		return nil, err
	}
	return &TokenVaultERC20ReleasedIterator{contract: _TokenVault.contract, event: "ERC20Released", logs: logs, sub: sub}, nil
}

// WatchERC20Released is a free log subscription operation binding the contract event 0xc5d9f7cd7998e24ecf12ad69eca9339764e2cb13788d5d9616f502601b219af6.
//
// Solidity: event ERC20Released(bytes32 indexed msgHash, address indexed from, address token, uint256 amount)
func (_TokenVault *TokenVaultFilterer) WatchERC20Released(opts *bind.WatchOpts, sink chan<- *TokenVaultERC20Released, msgHash [][32]byte, from []common.Address) (event.Subscription, error) {

	var msgHashRule []interface{}
	for _, msgHashItem := range msgHash {
		msgHashRule = append(msgHashRule, msgHashItem)
	}
	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}

	logs, sub, err := _TokenVault.contract.WatchLogs(opts, "ERC20Released", msgHashRule, fromRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenVaultERC20Released)
				if err := _TokenVault.contract.UnpackLog(event, "ERC20Released", log); err != nil {
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

// ParseERC20Released is a log parse operation binding the contract event 0xc5d9f7cd7998e24ecf12ad69eca9339764e2cb13788d5d9616f502601b219af6.
//
// Solidity: event ERC20Released(bytes32 indexed msgHash, address indexed from, address token, uint256 amount)
func (_TokenVault *TokenVaultFilterer) ParseERC20Released(log types.Log) (*TokenVaultERC20Released, error) {
	event := new(TokenVaultERC20Released)
	if err := _TokenVault.contract.UnpackLog(event, "ERC20Released", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TokenVaultERC20SentIterator is returned from FilterERC20Sent and is used to iterate over the raw logs and unpacked data for ERC20Sent events raised by the TokenVault contract.
type TokenVaultERC20SentIterator struct {
	Event *TokenVaultERC20Sent // Event containing the contract specifics and raw log

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
func (it *TokenVaultERC20SentIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenVaultERC20Sent)
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
		it.Event = new(TokenVaultERC20Sent)
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
func (it *TokenVaultERC20SentIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenVaultERC20SentIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenVaultERC20Sent represents a ERC20Sent event raised by the TokenVault contract.
type TokenVaultERC20Sent struct {
	MsgHash     [32]byte
	From        common.Address
	To          common.Address
	DestChainId *big.Int
	Token       common.Address
	Amount      *big.Int
	Raw         types.Log // Blockchain specific contextual infos
}

// FilterERC20Sent is a free log retrieval operation binding the contract event 0x325cab7553038374e17f39bb45e2a2c90f66c6a52798cb5f95c20d94c11c95e2.
//
// Solidity: event ERC20Sent(bytes32 indexed msgHash, address indexed from, address indexed to, uint256 destChainId, address token, uint256 amount)
func (_TokenVault *TokenVaultFilterer) FilterERC20Sent(opts *bind.FilterOpts, msgHash [][32]byte, from []common.Address, to []common.Address) (*TokenVaultERC20SentIterator, error) {

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

	logs, sub, err := _TokenVault.contract.FilterLogs(opts, "ERC20Sent", msgHashRule, fromRule, toRule)
	if err != nil {
		return nil, err
	}
	return &TokenVaultERC20SentIterator{contract: _TokenVault.contract, event: "ERC20Sent", logs: logs, sub: sub}, nil
}

// WatchERC20Sent is a free log subscription operation binding the contract event 0x325cab7553038374e17f39bb45e2a2c90f66c6a52798cb5f95c20d94c11c95e2.
//
// Solidity: event ERC20Sent(bytes32 indexed msgHash, address indexed from, address indexed to, uint256 destChainId, address token, uint256 amount)
func (_TokenVault *TokenVaultFilterer) WatchERC20Sent(opts *bind.WatchOpts, sink chan<- *TokenVaultERC20Sent, msgHash [][32]byte, from []common.Address, to []common.Address) (event.Subscription, error) {

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

	logs, sub, err := _TokenVault.contract.WatchLogs(opts, "ERC20Sent", msgHashRule, fromRule, toRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenVaultERC20Sent)
				if err := _TokenVault.contract.UnpackLog(event, "ERC20Sent", log); err != nil {
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

// ParseERC20Sent is a log parse operation binding the contract event 0x325cab7553038374e17f39bb45e2a2c90f66c6a52798cb5f95c20d94c11c95e2.
//
// Solidity: event ERC20Sent(bytes32 indexed msgHash, address indexed from, address indexed to, uint256 destChainId, address token, uint256 amount)
func (_TokenVault *TokenVaultFilterer) ParseERC20Sent(log types.Log) (*TokenVaultERC20Sent, error) {
	event := new(TokenVaultERC20Sent)
	if err := _TokenVault.contract.UnpackLog(event, "ERC20Sent", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TokenVaultEtherSentIterator is returned from FilterEtherSent and is used to iterate over the raw logs and unpacked data for EtherSent events raised by the TokenVault contract.
type TokenVaultEtherSentIterator struct {
	Event *TokenVaultEtherSent // Event containing the contract specifics and raw log

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
func (it *TokenVaultEtherSentIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenVaultEtherSent)
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
		it.Event = new(TokenVaultEtherSent)
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
func (it *TokenVaultEtherSentIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenVaultEtherSentIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenVaultEtherSent represents a EtherSent event raised by the TokenVault contract.
type TokenVaultEtherSent struct {
	MsgHash     [32]byte
	From        common.Address
	To          common.Address
	DestChainId *big.Int
	Amount      *big.Int
	Raw         types.Log // Blockchain specific contextual infos
}

// FilterEtherSent is a free log retrieval operation binding the contract event 0xe2f39179c279514a7b46983846e33f95a561128e0660602a211cc1e61cddb9bd.
//
// Solidity: event EtherSent(bytes32 indexed msgHash, address indexed from, address indexed to, uint256 destChainId, uint256 amount)
func (_TokenVault *TokenVaultFilterer) FilterEtherSent(opts *bind.FilterOpts, msgHash [][32]byte, from []common.Address, to []common.Address) (*TokenVaultEtherSentIterator, error) {

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

	logs, sub, err := _TokenVault.contract.FilterLogs(opts, "EtherSent", msgHashRule, fromRule, toRule)
	if err != nil {
		return nil, err
	}
	return &TokenVaultEtherSentIterator{contract: _TokenVault.contract, event: "EtherSent", logs: logs, sub: sub}, nil
}

// WatchEtherSent is a free log subscription operation binding the contract event 0xe2f39179c279514a7b46983846e33f95a561128e0660602a211cc1e61cddb9bd.
//
// Solidity: event EtherSent(bytes32 indexed msgHash, address indexed from, address indexed to, uint256 destChainId, uint256 amount)
func (_TokenVault *TokenVaultFilterer) WatchEtherSent(opts *bind.WatchOpts, sink chan<- *TokenVaultEtherSent, msgHash [][32]byte, from []common.Address, to []common.Address) (event.Subscription, error) {

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

	logs, sub, err := _TokenVault.contract.WatchLogs(opts, "EtherSent", msgHashRule, fromRule, toRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenVaultEtherSent)
				if err := _TokenVault.contract.UnpackLog(event, "EtherSent", log); err != nil {
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

// ParseEtherSent is a log parse operation binding the contract event 0xe2f39179c279514a7b46983846e33f95a561128e0660602a211cc1e61cddb9bd.
//
// Solidity: event EtherSent(bytes32 indexed msgHash, address indexed from, address indexed to, uint256 destChainId, uint256 amount)
func (_TokenVault *TokenVaultFilterer) ParseEtherSent(log types.Log) (*TokenVaultEtherSent, error) {
	event := new(TokenVaultEtherSent)
	if err := _TokenVault.contract.UnpackLog(event, "EtherSent", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TokenVaultInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the TokenVault contract.
type TokenVaultInitializedIterator struct {
	Event *TokenVaultInitialized // Event containing the contract specifics and raw log

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
func (it *TokenVaultInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenVaultInitialized)
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
		it.Event = new(TokenVaultInitialized)
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
func (it *TokenVaultInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenVaultInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenVaultInitialized represents a Initialized event raised by the TokenVault contract.
type TokenVaultInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_TokenVault *TokenVaultFilterer) FilterInitialized(opts *bind.FilterOpts) (*TokenVaultInitializedIterator, error) {

	logs, sub, err := _TokenVault.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &TokenVaultInitializedIterator{contract: _TokenVault.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_TokenVault *TokenVaultFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *TokenVaultInitialized) (event.Subscription, error) {

	logs, sub, err := _TokenVault.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenVaultInitialized)
				if err := _TokenVault.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_TokenVault *TokenVaultFilterer) ParseInitialized(log types.Log) (*TokenVaultInitialized, error) {
	event := new(TokenVaultInitialized)
	if err := _TokenVault.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TokenVaultOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the TokenVault contract.
type TokenVaultOwnershipTransferredIterator struct {
	Event *TokenVaultOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *TokenVaultOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TokenVaultOwnershipTransferred)
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
		it.Event = new(TokenVaultOwnershipTransferred)
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
func (it *TokenVaultOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TokenVaultOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TokenVaultOwnershipTransferred represents a OwnershipTransferred event raised by the TokenVault contract.
type TokenVaultOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_TokenVault *TokenVaultFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*TokenVaultOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TokenVault.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &TokenVaultOwnershipTransferredIterator{contract: _TokenVault.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_TokenVault *TokenVaultFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *TokenVaultOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TokenVault.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TokenVaultOwnershipTransferred)
				if err := _TokenVault.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_TokenVault *TokenVaultFilterer) ParseOwnershipTransferred(log types.Log) (*TokenVaultOwnershipTransferred, error) {
	event := new(TokenVaultOwnershipTransferred)
	if err := _TokenVault.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
