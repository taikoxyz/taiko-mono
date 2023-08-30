// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package erc721vault

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

// BaseNFTVaultBridgeTransferOp is an auto generated low-level Go binding around an user-defined struct.
type BaseNFTVaultBridgeTransferOp struct {
	DestChainId *big.Int
	To          common.Address
	Token       common.Address
	TokenIds    []*big.Int
	Amounts     []*big.Int
	GasLimit    *big.Int
	Fee         *big.Int
	RefundTo    common.Address
	Memo        string
}

// BaseNFTVaultCanonicalNFT is an auto generated low-level Go binding around an user-defined struct.
type BaseNFTVaultCanonicalNFT struct {
	ChainId *big.Int
	Addr    common.Address
	Symbol  string
	Name    string
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

// ERC721VaultMetaData contains all meta data concerning the ERC721Vault contract.
var ERC721VaultMetaData = &bind.MetaData{
	ABI: "[{\"inputs\":[],\"name\":\"RESOLVER_DENIED\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"RESOLVER_INVALID_ADDR\",\"type\":\"error\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"name\",\"type\":\"bytes32\"}],\"name\":\"RESOLVER_ZERO_ADDR\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"VAULT_INTERFACE_NOT_SUPPORTED\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"VAULT_INVALID_AMOUNT\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"VAULT_INVALID_FROM\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"VAULT_INVALID_SRC_CHAIN_ID\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"VAULT_INVALID_TO\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"VAULT_INVALID_TOKEN\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"VAULT_INVALID_USER\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"VAULT_MAX_TOKEN_PER_TXN_EXCEEDED\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"VAULT_MESSAGE_NOT_FAILED\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"VAULT_MESSAGE_RELEASED_ALREADY\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"VAULT_TOKEN_ARRAY_MISMATCH\",\"type\":\"error\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"addressManager\",\"type\":\"address\"}],\"name\":\"AddressManagerChanged\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"ctoken\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"btoken\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"string\",\"name\":\"ctokenSymbol\",\"type\":\"string\"},{\"indexed\":false,\"internalType\":\"string\",\"name\":\"ctokenName\",\"type\":\"string\"}],\"name\":\"BridgedTokenDeployed\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint8\",\"name\":\"version\",\"type\":\"uint8\"}],\"name\":\"Initialized\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"previousOwner\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"OwnershipTransferred\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"bytes32\",\"name\":\"msgHash\",\"type\":\"bytes32\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"from\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"srcChainId\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"token\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256[]\",\"name\":\"tokenIds\",\"type\":\"uint256[]\"},{\"indexed\":false,\"internalType\":\"uint256[]\",\"name\":\"amounts\",\"type\":\"uint256[]\"}],\"name\":\"TokenReceived\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"bytes32\",\"name\":\"msgHash\",\"type\":\"bytes32\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"from\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"token\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256[]\",\"name\":\"tokenIds\",\"type\":\"uint256[]\"},{\"indexed\":false,\"internalType\":\"uint256[]\",\"name\":\"amounts\",\"type\":\"uint256[]\"}],\"name\":\"TokenReleased\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"bytes32\",\"name\":\"msgHash\",\"type\":\"bytes32\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"from\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"destChainId\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"token\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256[]\",\"name\":\"tokenIds\",\"type\":\"uint256[]\"},{\"indexed\":false,\"internalType\":\"uint256[]\",\"name\":\"amounts\",\"type\":\"uint256[]\"}],\"name\":\"TokenSent\",\"type\":\"event\"},{\"inputs\":[],\"name\":\"ERC1155_INTERFACE_ID\",\"outputs\":[{\"internalType\":\"bytes4\",\"name\":\"\",\"type\":\"bytes4\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"ERC721_INTERFACE_ID\",\"outputs\":[{\"internalType\":\"bytes4\",\"name\":\"\",\"type\":\"bytes4\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"addressManager\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"name\":\"bridgedToCanonical\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"addr\",\"type\":\"address\"},{\"internalType\":\"string\",\"name\":\"symbol\",\"type\":\"string\"},{\"internalType\":\"string\",\"name\":\"name\",\"type\":\"string\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"name\":\"canonicalToBridged\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"addressManager\",\"type\":\"address\"}],\"name\":\"init\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"name\":\"isBridgedToken\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"},{\"internalType\":\"bytes\",\"name\":\"\",\"type\":\"bytes\"}],\"name\":\"onERC721Received\",\"outputs\":[{\"internalType\":\"bytes4\",\"name\":\"\",\"type\":\"bytes4\"}],\"stateMutability\":\"pure\",\"type\":\"function\"},{\"inputs\":[{\"components\":[{\"internalType\":\"uint256\",\"name\":\"id\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"from\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"srcChainId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"destChainId\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"user\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"refundTo\",\"type\":\"address\"},{\"internalType\":\"uint256\",\"name\":\"value\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"fee\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"gasLimit\",\"type\":\"uint256\"},{\"internalType\":\"bytes\",\"name\":\"data\",\"type\":\"bytes\"},{\"internalType\":\"string\",\"name\":\"memo\",\"type\":\"string\"}],\"internalType\":\"structIBridge.Message\",\"name\":\"message\",\"type\":\"tuple\"}],\"name\":\"onMessageRecalled\",\"outputs\":[],\"stateMutability\":\"payable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"owner\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"components\":[{\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"addr\",\"type\":\"address\"},{\"internalType\":\"string\",\"name\":\"symbol\",\"type\":\"string\"},{\"internalType\":\"string\",\"name\":\"name\",\"type\":\"string\"}],\"internalType\":\"structBaseNFTVault.CanonicalNFT\",\"name\":\"ctoken\",\"type\":\"tuple\"},{\"internalType\":\"address\",\"name\":\"from\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"internalType\":\"uint256[]\",\"name\":\"tokenIds\",\"type\":\"uint256[]\"}],\"name\":\"receiveToken\",\"outputs\":[],\"stateMutability\":\"payable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"renounceOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"name\",\"type\":\"bytes32\"},{\"internalType\":\"bool\",\"name\":\"allowZeroAddress\",\"type\":\"bool\"}],\"name\":\"resolve\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"addr\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"name\",\"type\":\"bytes32\"},{\"internalType\":\"bool\",\"name\":\"allowZeroAddress\",\"type\":\"bool\"}],\"name\":\"resolve\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"addr\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"components\":[{\"internalType\":\"uint256\",\"name\":\"destChainId\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"internalType\":\"address\",\"name\":\"token\",\"type\":\"address\"},{\"internalType\":\"uint256[]\",\"name\":\"tokenIds\",\"type\":\"uint256[]\"},{\"internalType\":\"uint256[]\",\"name\":\"amounts\",\"type\":\"uint256[]\"},{\"internalType\":\"uint256\",\"name\":\"gasLimit\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"fee\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"refundTo\",\"type\":\"address\"},{\"internalType\":\"string\",\"name\":\"memo\",\"type\":\"string\"}],\"internalType\":\"structBaseNFTVault.BridgeTransferOp\",\"name\":\"opt\",\"type\":\"tuple\"}],\"name\":\"sendToken\",\"outputs\":[],\"stateMutability\":\"payable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"newAddressManager\",\"type\":\"address\"}],\"name\":\"setAddressManager\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes4\",\"name\":\"interfaceId\",\"type\":\"bytes4\"}],\"name\":\"supportsInterface\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"transferOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"}]",
}

// ERC721VaultABI is the input ABI used to generate the binding from.
// Deprecated: Use ERC721VaultMetaData.ABI instead.
var ERC721VaultABI = ERC721VaultMetaData.ABI

// ERC721Vault is an auto generated Go binding around an Ethereum contract.
type ERC721Vault struct {
	ERC721VaultCaller     // Read-only binding to the contract
	ERC721VaultTransactor // Write-only binding to the contract
	ERC721VaultFilterer   // Log filterer for contract events
}

// ERC721VaultCaller is an auto generated read-only Go binding around an Ethereum contract.
type ERC721VaultCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ERC721VaultTransactor is an auto generated write-only Go binding around an Ethereum contract.
type ERC721VaultTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ERC721VaultFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type ERC721VaultFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// ERC721VaultSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type ERC721VaultSession struct {
	Contract     *ERC721Vault      // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// ERC721VaultCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type ERC721VaultCallerSession struct {
	Contract *ERC721VaultCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts      // Call options to use throughout this session
}

// ERC721VaultTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type ERC721VaultTransactorSession struct {
	Contract     *ERC721VaultTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts      // Transaction auth options to use throughout this session
}

// ERC721VaultRaw is an auto generated low-level Go binding around an Ethereum contract.
type ERC721VaultRaw struct {
	Contract *ERC721Vault // Generic contract binding to access the raw methods on
}

// ERC721VaultCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type ERC721VaultCallerRaw struct {
	Contract *ERC721VaultCaller // Generic read-only contract binding to access the raw methods on
}

// ERC721VaultTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type ERC721VaultTransactorRaw struct {
	Contract *ERC721VaultTransactor // Generic write-only contract binding to access the raw methods on
}

// NewERC721Vault creates a new instance of ERC721Vault, bound to a specific deployed contract.
func NewERC721Vault(address common.Address, backend bind.ContractBackend) (*ERC721Vault, error) {
	contract, err := bindERC721Vault(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &ERC721Vault{ERC721VaultCaller: ERC721VaultCaller{contract: contract}, ERC721VaultTransactor: ERC721VaultTransactor{contract: contract}, ERC721VaultFilterer: ERC721VaultFilterer{contract: contract}}, nil
}

// NewERC721VaultCaller creates a new read-only instance of ERC721Vault, bound to a specific deployed contract.
func NewERC721VaultCaller(address common.Address, caller bind.ContractCaller) (*ERC721VaultCaller, error) {
	contract, err := bindERC721Vault(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &ERC721VaultCaller{contract: contract}, nil
}

// NewERC721VaultTransactor creates a new write-only instance of ERC721Vault, bound to a specific deployed contract.
func NewERC721VaultTransactor(address common.Address, transactor bind.ContractTransactor) (*ERC721VaultTransactor, error) {
	contract, err := bindERC721Vault(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &ERC721VaultTransactor{contract: contract}, nil
}

// NewERC721VaultFilterer creates a new log filterer instance of ERC721Vault, bound to a specific deployed contract.
func NewERC721VaultFilterer(address common.Address, filterer bind.ContractFilterer) (*ERC721VaultFilterer, error) {
	contract, err := bindERC721Vault(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &ERC721VaultFilterer{contract: contract}, nil
}

// bindERC721Vault binds a generic wrapper to an already deployed contract.
func bindERC721Vault(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := ERC721VaultMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ERC721Vault *ERC721VaultRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ERC721Vault.Contract.ERC721VaultCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ERC721Vault *ERC721VaultRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ERC721Vault.Contract.ERC721VaultTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ERC721Vault *ERC721VaultRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ERC721Vault.Contract.ERC721VaultTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_ERC721Vault *ERC721VaultCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _ERC721Vault.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_ERC721Vault *ERC721VaultTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ERC721Vault.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_ERC721Vault *ERC721VaultTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _ERC721Vault.Contract.contract.Transact(opts, method, params...)
}

// ERC1155INTERFACEID is a free data retrieval call binding the contract method 0x2ca069a5.
//
// Solidity: function ERC1155_INTERFACE_ID() view returns(bytes4)
func (_ERC721Vault *ERC721VaultCaller) ERC1155INTERFACEID(opts *bind.CallOpts) ([4]byte, error) {
	var out []interface{}
	err := _ERC721Vault.contract.Call(opts, &out, "ERC1155_INTERFACE_ID")

	if err != nil {
		return *new([4]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([4]byte)).(*[4]byte)

	return out0, err

}

// ERC1155INTERFACEID is a free data retrieval call binding the contract method 0x2ca069a5.
//
// Solidity: function ERC1155_INTERFACE_ID() view returns(bytes4)
func (_ERC721Vault *ERC721VaultSession) ERC1155INTERFACEID() ([4]byte, error) {
	return _ERC721Vault.Contract.ERC1155INTERFACEID(&_ERC721Vault.CallOpts)
}

// ERC1155INTERFACEID is a free data retrieval call binding the contract method 0x2ca069a5.
//
// Solidity: function ERC1155_INTERFACE_ID() view returns(bytes4)
func (_ERC721Vault *ERC721VaultCallerSession) ERC1155INTERFACEID() ([4]byte, error) {
	return _ERC721Vault.Contract.ERC1155INTERFACEID(&_ERC721Vault.CallOpts)
}

// ERC721INTERFACEID is a free data retrieval call binding the contract method 0x59f4a907.
//
// Solidity: function ERC721_INTERFACE_ID() view returns(bytes4)
func (_ERC721Vault *ERC721VaultCaller) ERC721INTERFACEID(opts *bind.CallOpts) ([4]byte, error) {
	var out []interface{}
	err := _ERC721Vault.contract.Call(opts, &out, "ERC721_INTERFACE_ID")

	if err != nil {
		return *new([4]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([4]byte)).(*[4]byte)

	return out0, err

}

// ERC721INTERFACEID is a free data retrieval call binding the contract method 0x59f4a907.
//
// Solidity: function ERC721_INTERFACE_ID() view returns(bytes4)
func (_ERC721Vault *ERC721VaultSession) ERC721INTERFACEID() ([4]byte, error) {
	return _ERC721Vault.Contract.ERC721INTERFACEID(&_ERC721Vault.CallOpts)
}

// ERC721INTERFACEID is a free data retrieval call binding the contract method 0x59f4a907.
//
// Solidity: function ERC721_INTERFACE_ID() view returns(bytes4)
func (_ERC721Vault *ERC721VaultCallerSession) ERC721INTERFACEID() ([4]byte, error) {
	return _ERC721Vault.Contract.ERC721INTERFACEID(&_ERC721Vault.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_ERC721Vault *ERC721VaultCaller) AddressManager(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ERC721Vault.contract.Call(opts, &out, "addressManager")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_ERC721Vault *ERC721VaultSession) AddressManager() (common.Address, error) {
	return _ERC721Vault.Contract.AddressManager(&_ERC721Vault.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_ERC721Vault *ERC721VaultCallerSession) AddressManager() (common.Address, error) {
	return _ERC721Vault.Contract.AddressManager(&_ERC721Vault.CallOpts)
}

// BridgedToCanonical is a free data retrieval call binding the contract method 0x9aa8605c.
//
// Solidity: function bridgedToCanonical(address ) view returns(uint256 chainId, address addr, string symbol, string name)
func (_ERC721Vault *ERC721VaultCaller) BridgedToCanonical(opts *bind.CallOpts, arg0 common.Address) (struct {
	ChainId *big.Int
	Addr    common.Address
	Symbol  string
	Name    string
}, error) {
	var out []interface{}
	err := _ERC721Vault.contract.Call(opts, &out, "bridgedToCanonical", arg0)

	outstruct := new(struct {
		ChainId *big.Int
		Addr    common.Address
		Symbol  string
		Name    string
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.ChainId = *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	outstruct.Addr = *abi.ConvertType(out[1], new(common.Address)).(*common.Address)
	outstruct.Symbol = *abi.ConvertType(out[2], new(string)).(*string)
	outstruct.Name = *abi.ConvertType(out[3], new(string)).(*string)

	return *outstruct, err

}

// BridgedToCanonical is a free data retrieval call binding the contract method 0x9aa8605c.
//
// Solidity: function bridgedToCanonical(address ) view returns(uint256 chainId, address addr, string symbol, string name)
func (_ERC721Vault *ERC721VaultSession) BridgedToCanonical(arg0 common.Address) (struct {
	ChainId *big.Int
	Addr    common.Address
	Symbol  string
	Name    string
}, error) {
	return _ERC721Vault.Contract.BridgedToCanonical(&_ERC721Vault.CallOpts, arg0)
}

// BridgedToCanonical is a free data retrieval call binding the contract method 0x9aa8605c.
//
// Solidity: function bridgedToCanonical(address ) view returns(uint256 chainId, address addr, string symbol, string name)
func (_ERC721Vault *ERC721VaultCallerSession) BridgedToCanonical(arg0 common.Address) (struct {
	ChainId *big.Int
	Addr    common.Address
	Symbol  string
	Name    string
}, error) {
	return _ERC721Vault.Contract.BridgedToCanonical(&_ERC721Vault.CallOpts, arg0)
}

// CanonicalToBridged is a free data retrieval call binding the contract method 0x67090ccf.
//
// Solidity: function canonicalToBridged(uint256 , address ) view returns(address)
func (_ERC721Vault *ERC721VaultCaller) CanonicalToBridged(opts *bind.CallOpts, arg0 *big.Int, arg1 common.Address) (common.Address, error) {
	var out []interface{}
	err := _ERC721Vault.contract.Call(opts, &out, "canonicalToBridged", arg0, arg1)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CanonicalToBridged is a free data retrieval call binding the contract method 0x67090ccf.
//
// Solidity: function canonicalToBridged(uint256 , address ) view returns(address)
func (_ERC721Vault *ERC721VaultSession) CanonicalToBridged(arg0 *big.Int, arg1 common.Address) (common.Address, error) {
	return _ERC721Vault.Contract.CanonicalToBridged(&_ERC721Vault.CallOpts, arg0, arg1)
}

// CanonicalToBridged is a free data retrieval call binding the contract method 0x67090ccf.
//
// Solidity: function canonicalToBridged(uint256 , address ) view returns(address)
func (_ERC721Vault *ERC721VaultCallerSession) CanonicalToBridged(arg0 *big.Int, arg1 common.Address) (common.Address, error) {
	return _ERC721Vault.Contract.CanonicalToBridged(&_ERC721Vault.CallOpts, arg0, arg1)
}

// IsBridgedToken is a free data retrieval call binding the contract method 0xc287e578.
//
// Solidity: function isBridgedToken(address ) view returns(bool)
func (_ERC721Vault *ERC721VaultCaller) IsBridgedToken(opts *bind.CallOpts, arg0 common.Address) (bool, error) {
	var out []interface{}
	err := _ERC721Vault.contract.Call(opts, &out, "isBridgedToken", arg0)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsBridgedToken is a free data retrieval call binding the contract method 0xc287e578.
//
// Solidity: function isBridgedToken(address ) view returns(bool)
func (_ERC721Vault *ERC721VaultSession) IsBridgedToken(arg0 common.Address) (bool, error) {
	return _ERC721Vault.Contract.IsBridgedToken(&_ERC721Vault.CallOpts, arg0)
}

// IsBridgedToken is a free data retrieval call binding the contract method 0xc287e578.
//
// Solidity: function isBridgedToken(address ) view returns(bool)
func (_ERC721Vault *ERC721VaultCallerSession) IsBridgedToken(arg0 common.Address) (bool, error) {
	return _ERC721Vault.Contract.IsBridgedToken(&_ERC721Vault.CallOpts, arg0)
}

// OnERC721Received is a free data retrieval call binding the contract method 0x150b7a02.
//
// Solidity: function onERC721Received(address , address , uint256 , bytes ) pure returns(bytes4)
func (_ERC721Vault *ERC721VaultCaller) OnERC721Received(opts *bind.CallOpts, arg0 common.Address, arg1 common.Address, arg2 *big.Int, arg3 []byte) ([4]byte, error) {
	var out []interface{}
	err := _ERC721Vault.contract.Call(opts, &out, "onERC721Received", arg0, arg1, arg2, arg3)

	if err != nil {
		return *new([4]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([4]byte)).(*[4]byte)

	return out0, err

}

// OnERC721Received is a free data retrieval call binding the contract method 0x150b7a02.
//
// Solidity: function onERC721Received(address , address , uint256 , bytes ) pure returns(bytes4)
func (_ERC721Vault *ERC721VaultSession) OnERC721Received(arg0 common.Address, arg1 common.Address, arg2 *big.Int, arg3 []byte) ([4]byte, error) {
	return _ERC721Vault.Contract.OnERC721Received(&_ERC721Vault.CallOpts, arg0, arg1, arg2, arg3)
}

// OnERC721Received is a free data retrieval call binding the contract method 0x150b7a02.
//
// Solidity: function onERC721Received(address , address , uint256 , bytes ) pure returns(bytes4)
func (_ERC721Vault *ERC721VaultCallerSession) OnERC721Received(arg0 common.Address, arg1 common.Address, arg2 *big.Int, arg3 []byte) ([4]byte, error) {
	return _ERC721Vault.Contract.OnERC721Received(&_ERC721Vault.CallOpts, arg0, arg1, arg2, arg3)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ERC721Vault *ERC721VaultCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ERC721Vault.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ERC721Vault *ERC721VaultSession) Owner() (common.Address, error) {
	return _ERC721Vault.Contract.Owner(&_ERC721Vault.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_ERC721Vault *ERC721VaultCallerSession) Owner() (common.Address, error) {
	return _ERC721Vault.Contract.Owner(&_ERC721Vault.CallOpts)
}

// Resolve is a free data retrieval call binding the contract method 0x6c6563f6.
//
// Solidity: function resolve(uint256 chainId, bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_ERC721Vault *ERC721VaultCaller) Resolve(opts *bind.CallOpts, chainId *big.Int, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _ERC721Vault.contract.Call(opts, &out, "resolve", chainId, name, allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve is a free data retrieval call binding the contract method 0x6c6563f6.
//
// Solidity: function resolve(uint256 chainId, bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_ERC721Vault *ERC721VaultSession) Resolve(chainId *big.Int, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _ERC721Vault.Contract.Resolve(&_ERC721Vault.CallOpts, chainId, name, allowZeroAddress)
}

// Resolve is a free data retrieval call binding the contract method 0x6c6563f6.
//
// Solidity: function resolve(uint256 chainId, bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_ERC721Vault *ERC721VaultCallerSession) Resolve(chainId *big.Int, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _ERC721Vault.Contract.Resolve(&_ERC721Vault.CallOpts, chainId, name, allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_ERC721Vault *ERC721VaultCaller) Resolve0(opts *bind.CallOpts, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _ERC721Vault.contract.Call(opts, &out, "resolve0", name, allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_ERC721Vault *ERC721VaultSession) Resolve0(name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _ERC721Vault.Contract.Resolve0(&_ERC721Vault.CallOpts, name, allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_ERC721Vault *ERC721VaultCallerSession) Resolve0(name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _ERC721Vault.Contract.Resolve0(&_ERC721Vault.CallOpts, name, allowZeroAddress)
}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 interfaceId) view returns(bool)
func (_ERC721Vault *ERC721VaultCaller) SupportsInterface(opts *bind.CallOpts, interfaceId [4]byte) (bool, error) {
	var out []interface{}
	err := _ERC721Vault.contract.Call(opts, &out, "supportsInterface", interfaceId)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 interfaceId) view returns(bool)
func (_ERC721Vault *ERC721VaultSession) SupportsInterface(interfaceId [4]byte) (bool, error) {
	return _ERC721Vault.Contract.SupportsInterface(&_ERC721Vault.CallOpts, interfaceId)
}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 interfaceId) view returns(bool)
func (_ERC721Vault *ERC721VaultCallerSession) SupportsInterface(interfaceId [4]byte) (bool, error) {
	return _ERC721Vault.Contract.SupportsInterface(&_ERC721Vault.CallOpts, interfaceId)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address addressManager) returns()
func (_ERC721Vault *ERC721VaultTransactor) Init(opts *bind.TransactOpts, addressManager common.Address) (*types.Transaction, error) {
	return _ERC721Vault.contract.Transact(opts, "init", addressManager)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address addressManager) returns()
func (_ERC721Vault *ERC721VaultSession) Init(addressManager common.Address) (*types.Transaction, error) {
	return _ERC721Vault.Contract.Init(&_ERC721Vault.TransactOpts, addressManager)
}

// Init is a paid mutator transaction binding the contract method 0x19ab453c.
//
// Solidity: function init(address addressManager) returns()
func (_ERC721Vault *ERC721VaultTransactorSession) Init(addressManager common.Address) (*types.Transaction, error) {
	return _ERC721Vault.Contract.Init(&_ERC721Vault.TransactOpts, addressManager)
}

// OnMessageRecalled is a paid mutator transaction binding the contract method 0x32a642ca.
//
// Solidity: function onMessageRecalled((uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,bytes,string) message) payable returns()
func (_ERC721Vault *ERC721VaultTransactor) OnMessageRecalled(opts *bind.TransactOpts, message IBridgeMessage) (*types.Transaction, error) {
	return _ERC721Vault.contract.Transact(opts, "onMessageRecalled", message)
}

// OnMessageRecalled is a paid mutator transaction binding the contract method 0x32a642ca.
//
// Solidity: function onMessageRecalled((uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,bytes,string) message) payable returns()
func (_ERC721Vault *ERC721VaultSession) OnMessageRecalled(message IBridgeMessage) (*types.Transaction, error) {
	return _ERC721Vault.Contract.OnMessageRecalled(&_ERC721Vault.TransactOpts, message)
}

// OnMessageRecalled is a paid mutator transaction binding the contract method 0x32a642ca.
//
// Solidity: function onMessageRecalled((uint256,address,uint256,uint256,address,address,address,uint256,uint256,uint256,bytes,string) message) payable returns()
func (_ERC721Vault *ERC721VaultTransactorSession) OnMessageRecalled(message IBridgeMessage) (*types.Transaction, error) {
	return _ERC721Vault.Contract.OnMessageRecalled(&_ERC721Vault.TransactOpts, message)
}

// ReceiveToken is a paid mutator transaction binding the contract method 0xa9976baf.
//
// Solidity: function receiveToken((uint256,address,string,string) ctoken, address from, address to, uint256[] tokenIds) payable returns()
func (_ERC721Vault *ERC721VaultTransactor) ReceiveToken(opts *bind.TransactOpts, ctoken BaseNFTVaultCanonicalNFT, from common.Address, to common.Address, tokenIds []*big.Int) (*types.Transaction, error) {
	return _ERC721Vault.contract.Transact(opts, "receiveToken", ctoken, from, to, tokenIds)
}

// ReceiveToken is a paid mutator transaction binding the contract method 0xa9976baf.
//
// Solidity: function receiveToken((uint256,address,string,string) ctoken, address from, address to, uint256[] tokenIds) payable returns()
func (_ERC721Vault *ERC721VaultSession) ReceiveToken(ctoken BaseNFTVaultCanonicalNFT, from common.Address, to common.Address, tokenIds []*big.Int) (*types.Transaction, error) {
	return _ERC721Vault.Contract.ReceiveToken(&_ERC721Vault.TransactOpts, ctoken, from, to, tokenIds)
}

// ReceiveToken is a paid mutator transaction binding the contract method 0xa9976baf.
//
// Solidity: function receiveToken((uint256,address,string,string) ctoken, address from, address to, uint256[] tokenIds) payable returns()
func (_ERC721Vault *ERC721VaultTransactorSession) ReceiveToken(ctoken BaseNFTVaultCanonicalNFT, from common.Address, to common.Address, tokenIds []*big.Int) (*types.Transaction, error) {
	return _ERC721Vault.Contract.ReceiveToken(&_ERC721Vault.TransactOpts, ctoken, from, to, tokenIds)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ERC721Vault *ERC721VaultTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ERC721Vault.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ERC721Vault *ERC721VaultSession) RenounceOwnership() (*types.Transaction, error) {
	return _ERC721Vault.Contract.RenounceOwnership(&_ERC721Vault.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_ERC721Vault *ERC721VaultTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _ERC721Vault.Contract.RenounceOwnership(&_ERC721Vault.TransactOpts)
}

// SendToken is a paid mutator transaction binding the contract method 0x73339643.
//
// Solidity: function sendToken((uint256,address,address,uint256[],uint256[],uint256,uint256,address,string) opt) payable returns()
func (_ERC721Vault *ERC721VaultTransactor) SendToken(opts *bind.TransactOpts, opt BaseNFTVaultBridgeTransferOp) (*types.Transaction, error) {
	return _ERC721Vault.contract.Transact(opts, "sendToken", opt)
}

// SendToken is a paid mutator transaction binding the contract method 0x73339643.
//
// Solidity: function sendToken((uint256,address,address,uint256[],uint256[],uint256,uint256,address,string) opt) payable returns()
func (_ERC721Vault *ERC721VaultSession) SendToken(opt BaseNFTVaultBridgeTransferOp) (*types.Transaction, error) {
	return _ERC721Vault.Contract.SendToken(&_ERC721Vault.TransactOpts, opt)
}

// SendToken is a paid mutator transaction binding the contract method 0x73339643.
//
// Solidity: function sendToken((uint256,address,address,uint256[],uint256[],uint256,uint256,address,string) opt) payable returns()
func (_ERC721Vault *ERC721VaultTransactorSession) SendToken(opt BaseNFTVaultBridgeTransferOp) (*types.Transaction, error) {
	return _ERC721Vault.Contract.SendToken(&_ERC721Vault.TransactOpts, opt)
}

// SetAddressManager is a paid mutator transaction binding the contract method 0x0652b57a.
//
// Solidity: function setAddressManager(address newAddressManager) returns()
func (_ERC721Vault *ERC721VaultTransactor) SetAddressManager(opts *bind.TransactOpts, newAddressManager common.Address) (*types.Transaction, error) {
	return _ERC721Vault.contract.Transact(opts, "setAddressManager", newAddressManager)
}

// SetAddressManager is a paid mutator transaction binding the contract method 0x0652b57a.
//
// Solidity: function setAddressManager(address newAddressManager) returns()
func (_ERC721Vault *ERC721VaultSession) SetAddressManager(newAddressManager common.Address) (*types.Transaction, error) {
	return _ERC721Vault.Contract.SetAddressManager(&_ERC721Vault.TransactOpts, newAddressManager)
}

// SetAddressManager is a paid mutator transaction binding the contract method 0x0652b57a.
//
// Solidity: function setAddressManager(address newAddressManager) returns()
func (_ERC721Vault *ERC721VaultTransactorSession) SetAddressManager(newAddressManager common.Address) (*types.Transaction, error) {
	return _ERC721Vault.Contract.SetAddressManager(&_ERC721Vault.TransactOpts, newAddressManager)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ERC721Vault *ERC721VaultTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _ERC721Vault.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ERC721Vault *ERC721VaultSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _ERC721Vault.Contract.TransferOwnership(&_ERC721Vault.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_ERC721Vault *ERC721VaultTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _ERC721Vault.Contract.TransferOwnership(&_ERC721Vault.TransactOpts, newOwner)
}

// ERC721VaultAddressManagerChangedIterator is returned from FilterAddressManagerChanged and is used to iterate over the raw logs and unpacked data for AddressManagerChanged events raised by the ERC721Vault contract.
type ERC721VaultAddressManagerChangedIterator struct {
	Event *ERC721VaultAddressManagerChanged // Event containing the contract specifics and raw log

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
func (it *ERC721VaultAddressManagerChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ERC721VaultAddressManagerChanged)
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
		it.Event = new(ERC721VaultAddressManagerChanged)
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
func (it *ERC721VaultAddressManagerChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ERC721VaultAddressManagerChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ERC721VaultAddressManagerChanged represents a AddressManagerChanged event raised by the ERC721Vault contract.
type ERC721VaultAddressManagerChanged struct {
	AddressManager common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterAddressManagerChanged is a free log retrieval operation binding the contract event 0x399ded90cb5ed8d89ef7e76ff4af65c373f06d3bf5d7eef55f4228e7b702a18b.
//
// Solidity: event AddressManagerChanged(address indexed addressManager)
func (_ERC721Vault *ERC721VaultFilterer) FilterAddressManagerChanged(opts *bind.FilterOpts, addressManager []common.Address) (*ERC721VaultAddressManagerChangedIterator, error) {

	var addressManagerRule []interface{}
	for _, addressManagerItem := range addressManager {
		addressManagerRule = append(addressManagerRule, addressManagerItem)
	}

	logs, sub, err := _ERC721Vault.contract.FilterLogs(opts, "AddressManagerChanged", addressManagerRule)
	if err != nil {
		return nil, err
	}
	return &ERC721VaultAddressManagerChangedIterator{contract: _ERC721Vault.contract, event: "AddressManagerChanged", logs: logs, sub: sub}, nil
}

// WatchAddressManagerChanged is a free log subscription operation binding the contract event 0x399ded90cb5ed8d89ef7e76ff4af65c373f06d3bf5d7eef55f4228e7b702a18b.
//
// Solidity: event AddressManagerChanged(address indexed addressManager)
func (_ERC721Vault *ERC721VaultFilterer) WatchAddressManagerChanged(opts *bind.WatchOpts, sink chan<- *ERC721VaultAddressManagerChanged, addressManager []common.Address) (event.Subscription, error) {

	var addressManagerRule []interface{}
	for _, addressManagerItem := range addressManager {
		addressManagerRule = append(addressManagerRule, addressManagerItem)
	}

	logs, sub, err := _ERC721Vault.contract.WatchLogs(opts, "AddressManagerChanged", addressManagerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ERC721VaultAddressManagerChanged)
				if err := _ERC721Vault.contract.UnpackLog(event, "AddressManagerChanged", log); err != nil {
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
func (_ERC721Vault *ERC721VaultFilterer) ParseAddressManagerChanged(log types.Log) (*ERC721VaultAddressManagerChanged, error) {
	event := new(ERC721VaultAddressManagerChanged)
	if err := _ERC721Vault.contract.UnpackLog(event, "AddressManagerChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ERC721VaultBridgedTokenDeployedIterator is returned from FilterBridgedTokenDeployed and is used to iterate over the raw logs and unpacked data for BridgedTokenDeployed events raised by the ERC721Vault contract.
type ERC721VaultBridgedTokenDeployedIterator struct {
	Event *ERC721VaultBridgedTokenDeployed // Event containing the contract specifics and raw log

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
func (it *ERC721VaultBridgedTokenDeployedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ERC721VaultBridgedTokenDeployed)
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
		it.Event = new(ERC721VaultBridgedTokenDeployed)
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
func (it *ERC721VaultBridgedTokenDeployedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ERC721VaultBridgedTokenDeployedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ERC721VaultBridgedTokenDeployed represents a BridgedTokenDeployed event raised by the ERC721Vault contract.
type ERC721VaultBridgedTokenDeployed struct {
	ChainId      *big.Int
	Ctoken       common.Address
	Btoken       common.Address
	CtokenSymbol string
	CtokenName   string
	Raw          types.Log // Blockchain specific contextual infos
}

// FilterBridgedTokenDeployed is a free log retrieval operation binding the contract event 0x2da3c4d305298f6df3653c23d98b4c055f72f7e6f981b2c477ccbec92b1ee579.
//
// Solidity: event BridgedTokenDeployed(uint256 indexed chainId, address indexed ctoken, address indexed btoken, string ctokenSymbol, string ctokenName)
func (_ERC721Vault *ERC721VaultFilterer) FilterBridgedTokenDeployed(opts *bind.FilterOpts, chainId []*big.Int, ctoken []common.Address, btoken []common.Address) (*ERC721VaultBridgedTokenDeployedIterator, error) {

	var chainIdRule []interface{}
	for _, chainIdItem := range chainId {
		chainIdRule = append(chainIdRule, chainIdItem)
	}
	var ctokenRule []interface{}
	for _, ctokenItem := range ctoken {
		ctokenRule = append(ctokenRule, ctokenItem)
	}
	var btokenRule []interface{}
	for _, btokenItem := range btoken {
		btokenRule = append(btokenRule, btokenItem)
	}

	logs, sub, err := _ERC721Vault.contract.FilterLogs(opts, "BridgedTokenDeployed", chainIdRule, ctokenRule, btokenRule)
	if err != nil {
		return nil, err
	}
	return &ERC721VaultBridgedTokenDeployedIterator{contract: _ERC721Vault.contract, event: "BridgedTokenDeployed", logs: logs, sub: sub}, nil
}

// WatchBridgedTokenDeployed is a free log subscription operation binding the contract event 0x2da3c4d305298f6df3653c23d98b4c055f72f7e6f981b2c477ccbec92b1ee579.
//
// Solidity: event BridgedTokenDeployed(uint256 indexed chainId, address indexed ctoken, address indexed btoken, string ctokenSymbol, string ctokenName)
func (_ERC721Vault *ERC721VaultFilterer) WatchBridgedTokenDeployed(opts *bind.WatchOpts, sink chan<- *ERC721VaultBridgedTokenDeployed, chainId []*big.Int, ctoken []common.Address, btoken []common.Address) (event.Subscription, error) {

	var chainIdRule []interface{}
	for _, chainIdItem := range chainId {
		chainIdRule = append(chainIdRule, chainIdItem)
	}
	var ctokenRule []interface{}
	for _, ctokenItem := range ctoken {
		ctokenRule = append(ctokenRule, ctokenItem)
	}
	var btokenRule []interface{}
	for _, btokenItem := range btoken {
		btokenRule = append(btokenRule, btokenItem)
	}

	logs, sub, err := _ERC721Vault.contract.WatchLogs(opts, "BridgedTokenDeployed", chainIdRule, ctokenRule, btokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ERC721VaultBridgedTokenDeployed)
				if err := _ERC721Vault.contract.UnpackLog(event, "BridgedTokenDeployed", log); err != nil {
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

// ParseBridgedTokenDeployed is a log parse operation binding the contract event 0x2da3c4d305298f6df3653c23d98b4c055f72f7e6f981b2c477ccbec92b1ee579.
//
// Solidity: event BridgedTokenDeployed(uint256 indexed chainId, address indexed ctoken, address indexed btoken, string ctokenSymbol, string ctokenName)
func (_ERC721Vault *ERC721VaultFilterer) ParseBridgedTokenDeployed(log types.Log) (*ERC721VaultBridgedTokenDeployed, error) {
	event := new(ERC721VaultBridgedTokenDeployed)
	if err := _ERC721Vault.contract.UnpackLog(event, "BridgedTokenDeployed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ERC721VaultInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the ERC721Vault contract.
type ERC721VaultInitializedIterator struct {
	Event *ERC721VaultInitialized // Event containing the contract specifics and raw log

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
func (it *ERC721VaultInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ERC721VaultInitialized)
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
		it.Event = new(ERC721VaultInitialized)
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
func (it *ERC721VaultInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ERC721VaultInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ERC721VaultInitialized represents a Initialized event raised by the ERC721Vault contract.
type ERC721VaultInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_ERC721Vault *ERC721VaultFilterer) FilterInitialized(opts *bind.FilterOpts) (*ERC721VaultInitializedIterator, error) {

	logs, sub, err := _ERC721Vault.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &ERC721VaultInitializedIterator{contract: _ERC721Vault.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_ERC721Vault *ERC721VaultFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *ERC721VaultInitialized) (event.Subscription, error) {

	logs, sub, err := _ERC721Vault.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ERC721VaultInitialized)
				if err := _ERC721Vault.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_ERC721Vault *ERC721VaultFilterer) ParseInitialized(log types.Log) (*ERC721VaultInitialized, error) {
	event := new(ERC721VaultInitialized)
	if err := _ERC721Vault.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ERC721VaultOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the ERC721Vault contract.
type ERC721VaultOwnershipTransferredIterator struct {
	Event *ERC721VaultOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *ERC721VaultOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ERC721VaultOwnershipTransferred)
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
		it.Event = new(ERC721VaultOwnershipTransferred)
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
func (it *ERC721VaultOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ERC721VaultOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ERC721VaultOwnershipTransferred represents a OwnershipTransferred event raised by the ERC721Vault contract.
type ERC721VaultOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_ERC721Vault *ERC721VaultFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*ERC721VaultOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ERC721Vault.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &ERC721VaultOwnershipTransferredIterator{contract: _ERC721Vault.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_ERC721Vault *ERC721VaultFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *ERC721VaultOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ERC721Vault.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ERC721VaultOwnershipTransferred)
				if err := _ERC721Vault.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_ERC721Vault *ERC721VaultFilterer) ParseOwnershipTransferred(log types.Log) (*ERC721VaultOwnershipTransferred, error) {
	event := new(ERC721VaultOwnershipTransferred)
	if err := _ERC721Vault.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ERC721VaultTokenReceivedIterator is returned from FilterTokenReceived and is used to iterate over the raw logs and unpacked data for TokenReceived events raised by the ERC721Vault contract.
type ERC721VaultTokenReceivedIterator struct {
	Event *ERC721VaultTokenReceived // Event containing the contract specifics and raw log

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
func (it *ERC721VaultTokenReceivedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ERC721VaultTokenReceived)
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
		it.Event = new(ERC721VaultTokenReceived)
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
func (it *ERC721VaultTokenReceivedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ERC721VaultTokenReceivedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ERC721VaultTokenReceived represents a TokenReceived event raised by the ERC721Vault contract.
type ERC721VaultTokenReceived struct {
	MsgHash    [32]byte
	From       common.Address
	To         common.Address
	SrcChainId *big.Int
	Token      common.Address
	TokenIds   []*big.Int
	Amounts    []*big.Int
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterTokenReceived is a free log retrieval operation binding the contract event 0x0f60c37489e435ed8490c30b01c1fa57e62510e88b351b75796ad3d95babe6b1.
//
// Solidity: event TokenReceived(bytes32 indexed msgHash, address indexed from, address indexed to, uint256 srcChainId, address token, uint256[] tokenIds, uint256[] amounts)
func (_ERC721Vault *ERC721VaultFilterer) FilterTokenReceived(opts *bind.FilterOpts, msgHash [][32]byte, from []common.Address, to []common.Address) (*ERC721VaultTokenReceivedIterator, error) {

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

	logs, sub, err := _ERC721Vault.contract.FilterLogs(opts, "TokenReceived", msgHashRule, fromRule, toRule)
	if err != nil {
		return nil, err
	}
	return &ERC721VaultTokenReceivedIterator{contract: _ERC721Vault.contract, event: "TokenReceived", logs: logs, sub: sub}, nil
}

// WatchTokenReceived is a free log subscription operation binding the contract event 0x0f60c37489e435ed8490c30b01c1fa57e62510e88b351b75796ad3d95babe6b1.
//
// Solidity: event TokenReceived(bytes32 indexed msgHash, address indexed from, address indexed to, uint256 srcChainId, address token, uint256[] tokenIds, uint256[] amounts)
func (_ERC721Vault *ERC721VaultFilterer) WatchTokenReceived(opts *bind.WatchOpts, sink chan<- *ERC721VaultTokenReceived, msgHash [][32]byte, from []common.Address, to []common.Address) (event.Subscription, error) {

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

	logs, sub, err := _ERC721Vault.contract.WatchLogs(opts, "TokenReceived", msgHashRule, fromRule, toRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ERC721VaultTokenReceived)
				if err := _ERC721Vault.contract.UnpackLog(event, "TokenReceived", log); err != nil {
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

// ParseTokenReceived is a log parse operation binding the contract event 0x0f60c37489e435ed8490c30b01c1fa57e62510e88b351b75796ad3d95babe6b1.
//
// Solidity: event TokenReceived(bytes32 indexed msgHash, address indexed from, address indexed to, uint256 srcChainId, address token, uint256[] tokenIds, uint256[] amounts)
func (_ERC721Vault *ERC721VaultFilterer) ParseTokenReceived(log types.Log) (*ERC721VaultTokenReceived, error) {
	event := new(ERC721VaultTokenReceived)
	if err := _ERC721Vault.contract.UnpackLog(event, "TokenReceived", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ERC721VaultTokenReleasedIterator is returned from FilterTokenReleased and is used to iterate over the raw logs and unpacked data for TokenReleased events raised by the ERC721Vault contract.
type ERC721VaultTokenReleasedIterator struct {
	Event *ERC721VaultTokenReleased // Event containing the contract specifics and raw log

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
func (it *ERC721VaultTokenReleasedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ERC721VaultTokenReleased)
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
		it.Event = new(ERC721VaultTokenReleased)
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
func (it *ERC721VaultTokenReleasedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ERC721VaultTokenReleasedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ERC721VaultTokenReleased represents a TokenReleased event raised by the ERC721Vault contract.
type ERC721VaultTokenReleased struct {
	MsgHash  [32]byte
	From     common.Address
	Token    common.Address
	TokenIds []*big.Int
	Amounts  []*big.Int
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterTokenReleased is a free log retrieval operation binding the contract event 0xe8449897bd3c926a272780c39ba13e77bf7a2c823479a75bfbc13ef631183dfd.
//
// Solidity: event TokenReleased(bytes32 indexed msgHash, address indexed from, address token, uint256[] tokenIds, uint256[] amounts)
func (_ERC721Vault *ERC721VaultFilterer) FilterTokenReleased(opts *bind.FilterOpts, msgHash [][32]byte, from []common.Address) (*ERC721VaultTokenReleasedIterator, error) {

	var msgHashRule []interface{}
	for _, msgHashItem := range msgHash {
		msgHashRule = append(msgHashRule, msgHashItem)
	}
	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}

	logs, sub, err := _ERC721Vault.contract.FilterLogs(opts, "TokenReleased", msgHashRule, fromRule)
	if err != nil {
		return nil, err
	}
	return &ERC721VaultTokenReleasedIterator{contract: _ERC721Vault.contract, event: "TokenReleased", logs: logs, sub: sub}, nil
}

// WatchTokenReleased is a free log subscription operation binding the contract event 0xe8449897bd3c926a272780c39ba13e77bf7a2c823479a75bfbc13ef631183dfd.
//
// Solidity: event TokenReleased(bytes32 indexed msgHash, address indexed from, address token, uint256[] tokenIds, uint256[] amounts)
func (_ERC721Vault *ERC721VaultFilterer) WatchTokenReleased(opts *bind.WatchOpts, sink chan<- *ERC721VaultTokenReleased, msgHash [][32]byte, from []common.Address) (event.Subscription, error) {

	var msgHashRule []interface{}
	for _, msgHashItem := range msgHash {
		msgHashRule = append(msgHashRule, msgHashItem)
	}
	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}

	logs, sub, err := _ERC721Vault.contract.WatchLogs(opts, "TokenReleased", msgHashRule, fromRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ERC721VaultTokenReleased)
				if err := _ERC721Vault.contract.UnpackLog(event, "TokenReleased", log); err != nil {
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

// ParseTokenReleased is a log parse operation binding the contract event 0xe8449897bd3c926a272780c39ba13e77bf7a2c823479a75bfbc13ef631183dfd.
//
// Solidity: event TokenReleased(bytes32 indexed msgHash, address indexed from, address token, uint256[] tokenIds, uint256[] amounts)
func (_ERC721Vault *ERC721VaultFilterer) ParseTokenReleased(log types.Log) (*ERC721VaultTokenReleased, error) {
	event := new(ERC721VaultTokenReleased)
	if err := _ERC721Vault.contract.UnpackLog(event, "TokenReleased", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ERC721VaultTokenSentIterator is returned from FilterTokenSent and is used to iterate over the raw logs and unpacked data for TokenSent events raised by the ERC721Vault contract.
type ERC721VaultTokenSentIterator struct {
	Event *ERC721VaultTokenSent // Event containing the contract specifics and raw log

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
func (it *ERC721VaultTokenSentIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ERC721VaultTokenSent)
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
		it.Event = new(ERC721VaultTokenSent)
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
func (it *ERC721VaultTokenSentIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ERC721VaultTokenSentIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ERC721VaultTokenSent represents a TokenSent event raised by the ERC721Vault contract.
type ERC721VaultTokenSent struct {
	MsgHash     [32]byte
	From        common.Address
	To          common.Address
	DestChainId *big.Int
	Token       common.Address
	TokenIds    []*big.Int
	Amounts     []*big.Int
	Raw         types.Log // Blockchain specific contextual infos
}

// FilterTokenSent is a free log retrieval operation binding the contract event 0x5e54276405062454e6226625b28a6fea0a838d6b054e38955667234afb3345a3.
//
// Solidity: event TokenSent(bytes32 indexed msgHash, address indexed from, address indexed to, uint256 destChainId, address token, uint256[] tokenIds, uint256[] amounts)
func (_ERC721Vault *ERC721VaultFilterer) FilterTokenSent(opts *bind.FilterOpts, msgHash [][32]byte, from []common.Address, to []common.Address) (*ERC721VaultTokenSentIterator, error) {

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

	logs, sub, err := _ERC721Vault.contract.FilterLogs(opts, "TokenSent", msgHashRule, fromRule, toRule)
	if err != nil {
		return nil, err
	}
	return &ERC721VaultTokenSentIterator{contract: _ERC721Vault.contract, event: "TokenSent", logs: logs, sub: sub}, nil
}

// WatchTokenSent is a free log subscription operation binding the contract event 0x5e54276405062454e6226625b28a6fea0a838d6b054e38955667234afb3345a3.
//
// Solidity: event TokenSent(bytes32 indexed msgHash, address indexed from, address indexed to, uint256 destChainId, address token, uint256[] tokenIds, uint256[] amounts)
func (_ERC721Vault *ERC721VaultFilterer) WatchTokenSent(opts *bind.WatchOpts, sink chan<- *ERC721VaultTokenSent, msgHash [][32]byte, from []common.Address, to []common.Address) (event.Subscription, error) {

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

	logs, sub, err := _ERC721Vault.contract.WatchLogs(opts, "TokenSent", msgHashRule, fromRule, toRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ERC721VaultTokenSent)
				if err := _ERC721Vault.contract.UnpackLog(event, "TokenSent", log); err != nil {
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

// ParseTokenSent is a log parse operation binding the contract event 0x5e54276405062454e6226625b28a6fea0a838d6b054e38955667234afb3345a3.
//
// Solidity: event TokenSent(bytes32 indexed msgHash, address indexed from, address indexed to, uint256 destChainId, address token, uint256[] tokenIds, uint256[] amounts)
func (_ERC721Vault *ERC721VaultFilterer) ParseTokenSent(log types.Log) (*ERC721VaultTokenSent, error) {
	event := new(ERC721VaultTokenSent)
	if err := _ERC721Vault.contract.UnpackLog(event, "TokenSent", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
