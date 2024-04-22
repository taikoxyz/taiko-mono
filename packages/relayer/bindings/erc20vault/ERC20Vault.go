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
	DestChainId uint64
	DestOwner   common.Address
	To          common.Address
	Fee         uint64
	Token       common.Address
	GasLimit    uint32
	Amount      *big.Int
}

// ERC20VaultCanonicalERC20 is an auto generated low-level Go binding around an user-defined struct.
type ERC20VaultCanonicalERC20 struct {
	ChainId  uint64
	Addr     common.Address
	Decimals uint8
	Symbol   string
	Name     string
}

// IBridgeMessage is an auto generated low-level Go binding around an user-defined struct.
type IBridgeMessage struct {
	Id          uint64
	Fee         uint64
	GasLimit    uint32
	From        common.Address
	SrcChainId  uint64
	SrcOwner    common.Address
	DestChainId uint64
	DestOwner   common.Address
	To          common.Address
	Value       *big.Int
	Data        []byte
}

// ERC20VaultMetaData contains all meta data concerning the ERC20Vault contract.
var ERC20VaultMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"addressManager\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"bridgedToCanonical\",\"inputs\":[{\"name\":\"btoken\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"addr\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"decimals\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"symbol\",\"type\":\"string\",\"internalType\":\"string\"},{\"name\":\"name\",\"type\":\"string\",\"internalType\":\"string\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"btokenBlacklist\",\"inputs\":[{\"name\":\"btoken\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"blacklisted\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"canonicalToBridged\",\"inputs\":[{\"name\":\"chainId\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"ctoken\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"btoken\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"changeBridgedToken\",\"inputs\":[{\"name\":\"_ctoken\",\"type\":\"tuple\",\"internalType\":\"structERC20Vault.CanonicalERC20\",\"components\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"addr\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"decimals\",\"type\":\"uint8\",\"internalType\":\"uint8\"},{\"name\":\"symbol\",\"type\":\"string\",\"internalType\":\"string\"},{\"name\":\"name\",\"type\":\"string\",\"internalType\":\"string\"}]},{\"name\":\"_btokenNew\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"btokenOld_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_addressManager\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"lastUnpausedAt\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"name\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"onMessageInvocation\",\"inputs\":[{\"name\":\"_data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"onMessageRecalled\",\"inputs\":[{\"name\":\"_message\",\"type\":\"tuple\",\"internalType\":\"structIBridge.Message\",\"components\":[{\"name\":\"id\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"fee\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"gasLimit\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"from\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"srcChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"srcOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"destChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"destOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]},{\"name\":\"_msgHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolve\",\"inputs\":[{\"name\":\"_chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_allowZeroAddress\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"addresspayable\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"resolve\",\"inputs\":[{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_allowZeroAddress\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"addresspayable\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"sendToken\",\"inputs\":[{\"name\":\"_op\",\"type\":\"tuple\",\"internalType\":\"structERC20Vault.BridgeTransferOp\",\"components\":[{\"name\":\"destChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"destOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"fee\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"token\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"gasLimit\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"amount\",\"type\":\"uint256\",\"internalType\":\"uint256\"}]}],\"outputs\":[{\"name\":\"message_\",\"type\":\"tuple\",\"internalType\":\"structIBridge.Message\",\"components\":[{\"name\":\"id\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"fee\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"gasLimit\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"from\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"srcChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"srcOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"destChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"destOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]}],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"supportsInterface\",\"inputs\":[{\"name\":\"_interfaceId\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BridgedTokenChanged\",\"inputs\":[{\"name\":\"srcChainId\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"ctoken\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"btokenOld\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"btokenNew\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"ctokenSymbol\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"ctokenName\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"ctokenDecimal\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BridgedTokenDeployed\",\"inputs\":[{\"name\":\"srcChainId\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"ctoken\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"btoken\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"ctokenSymbol\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"ctokenName\",\"type\":\"string\",\"indexed\":false,\"internalType\":\"string\"},{\"name\":\"ctokenDecimal\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TokenReceived\",\"inputs\":[{\"name\":\"msgHash\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"from\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"srcChainId\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"},{\"name\":\"ctoken\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TokenReleased\",\"inputs\":[{\"name\":\"msgHash\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"from\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"ctoken\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"TokenSent\",\"inputs\":[{\"name\":\"msgHash\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"from\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"destChainId\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"},{\"name\":\"ctoken\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"token\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"ETH_TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_INVALID_MANAGER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_UNEXPECTED_CHAINID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_ZERO_ADDR\",\"inputs\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"type\":\"error\",\"name\":\"VAULT_BTOKEN_BLACKLISTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"VAULT_CTOKEN_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"VAULT_INVALID_AMOUNT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"VAULT_INVALID_NEW_BTOKEN\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"VAULT_INVALID_TO\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"VAULT_INVALID_TOKEN\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"VAULT_NOT_SAME_OWNER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"VAULT_PERMISSION_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDR_MANAGER\",\"inputs\":[]}]",
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
// Solidity: function bridgedToCanonical(address btoken) view returns(uint64 chainId, address addr, uint8 decimals, string symbol, string name)
func (_ERC20Vault *ERC20VaultCaller) BridgedToCanonical(opts *bind.CallOpts, btoken common.Address) (struct {
	ChainId  uint64
	Addr     common.Address
	Decimals uint8
	Symbol   string
	Name     string
}, error) {
	var out []interface{}
	err := _ERC20Vault.contract.Call(opts, &out, "bridgedToCanonical", btoken)

	outstruct := new(struct {
		ChainId  uint64
		Addr     common.Address
		Decimals uint8
		Symbol   string
		Name     string
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.ChainId = *abi.ConvertType(out[0], new(uint64)).(*uint64)
	outstruct.Addr = *abi.ConvertType(out[1], new(common.Address)).(*common.Address)
	outstruct.Decimals = *abi.ConvertType(out[2], new(uint8)).(*uint8)
	outstruct.Symbol = *abi.ConvertType(out[3], new(string)).(*string)
	outstruct.Name = *abi.ConvertType(out[4], new(string)).(*string)

	return *outstruct, err

}

// BridgedToCanonical is a free data retrieval call binding the contract method 0x9aa8605c.
//
// Solidity: function bridgedToCanonical(address btoken) view returns(uint64 chainId, address addr, uint8 decimals, string symbol, string name)
func (_ERC20Vault *ERC20VaultSession) BridgedToCanonical(btoken common.Address) (struct {
	ChainId  uint64
	Addr     common.Address
	Decimals uint8
	Symbol   string
	Name     string
}, error) {
	return _ERC20Vault.Contract.BridgedToCanonical(&_ERC20Vault.CallOpts, btoken)
}

// BridgedToCanonical is a free data retrieval call binding the contract method 0x9aa8605c.
//
// Solidity: function bridgedToCanonical(address btoken) view returns(uint64 chainId, address addr, uint8 decimals, string symbol, string name)
func (_ERC20Vault *ERC20VaultCallerSession) BridgedToCanonical(btoken common.Address) (struct {
	ChainId  uint64
	Addr     common.Address
	Decimals uint8
	Symbol   string
	Name     string
}, error) {
	return _ERC20Vault.Contract.BridgedToCanonical(&_ERC20Vault.CallOpts, btoken)
}

// BtokenBlacklist is a free data retrieval call binding the contract method 0xcaec3e4e.
//
// Solidity: function btokenBlacklist(address btoken) view returns(bool blacklisted)
func (_ERC20Vault *ERC20VaultCaller) BtokenBlacklist(opts *bind.CallOpts, btoken common.Address) (bool, error) {
	var out []interface{}
	err := _ERC20Vault.contract.Call(opts, &out, "btokenBlacklist", btoken)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// BtokenBlacklist is a free data retrieval call binding the contract method 0xcaec3e4e.
//
// Solidity: function btokenBlacklist(address btoken) view returns(bool blacklisted)
func (_ERC20Vault *ERC20VaultSession) BtokenBlacklist(btoken common.Address) (bool, error) {
	return _ERC20Vault.Contract.BtokenBlacklist(&_ERC20Vault.CallOpts, btoken)
}

// BtokenBlacklist is a free data retrieval call binding the contract method 0xcaec3e4e.
//
// Solidity: function btokenBlacklist(address btoken) view returns(bool blacklisted)
func (_ERC20Vault *ERC20VaultCallerSession) BtokenBlacklist(btoken common.Address) (bool, error) {
	return _ERC20Vault.Contract.BtokenBlacklist(&_ERC20Vault.CallOpts, btoken)
}

// CanonicalToBridged is a free data retrieval call binding the contract method 0x67090ccf.
//
// Solidity: function canonicalToBridged(uint256 chainId, address ctoken) view returns(address btoken)
func (_ERC20Vault *ERC20VaultCaller) CanonicalToBridged(opts *bind.CallOpts, chainId *big.Int, ctoken common.Address) (common.Address, error) {
	var out []interface{}
	err := _ERC20Vault.contract.Call(opts, &out, "canonicalToBridged", chainId, ctoken)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// CanonicalToBridged is a free data retrieval call binding the contract method 0x67090ccf.
//
// Solidity: function canonicalToBridged(uint256 chainId, address ctoken) view returns(address btoken)
func (_ERC20Vault *ERC20VaultSession) CanonicalToBridged(chainId *big.Int, ctoken common.Address) (common.Address, error) {
	return _ERC20Vault.Contract.CanonicalToBridged(&_ERC20Vault.CallOpts, chainId, ctoken)
}

// CanonicalToBridged is a free data retrieval call binding the contract method 0x67090ccf.
//
// Solidity: function canonicalToBridged(uint256 chainId, address ctoken) view returns(address btoken)
func (_ERC20Vault *ERC20VaultCallerSession) CanonicalToBridged(chainId *big.Int, ctoken common.Address) (common.Address, error) {
	return _ERC20Vault.Contract.CanonicalToBridged(&_ERC20Vault.CallOpts, chainId, ctoken)
}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_ERC20Vault *ERC20VaultCaller) LastUnpausedAt(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _ERC20Vault.contract.Call(opts, &out, "lastUnpausedAt")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_ERC20Vault *ERC20VaultSession) LastUnpausedAt() (uint64, error) {
	return _ERC20Vault.Contract.LastUnpausedAt(&_ERC20Vault.CallOpts)
}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_ERC20Vault *ERC20VaultCallerSession) LastUnpausedAt() (uint64, error) {
	return _ERC20Vault.Contract.LastUnpausedAt(&_ERC20Vault.CallOpts)
}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() pure returns(bytes32)
func (_ERC20Vault *ERC20VaultCaller) Name(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _ERC20Vault.contract.Call(opts, &out, "name")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() pure returns(bytes32)
func (_ERC20Vault *ERC20VaultSession) Name() ([32]byte, error) {
	return _ERC20Vault.Contract.Name(&_ERC20Vault.CallOpts)
}

// Name is a free data retrieval call binding the contract method 0x06fdde03.
//
// Solidity: function name() pure returns(bytes32)
func (_ERC20Vault *ERC20VaultCallerSession) Name() ([32]byte, error) {
	return _ERC20Vault.Contract.Name(&_ERC20Vault.CallOpts)
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

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_ERC20Vault *ERC20VaultCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _ERC20Vault.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_ERC20Vault *ERC20VaultSession) Paused() (bool, error) {
	return _ERC20Vault.Contract.Paused(&_ERC20Vault.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_ERC20Vault *ERC20VaultCallerSession) Paused() (bool, error) {
	return _ERC20Vault.Contract.Paused(&_ERC20Vault.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_ERC20Vault *ERC20VaultCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _ERC20Vault.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_ERC20Vault *ERC20VaultSession) PendingOwner() (common.Address, error) {
	return _ERC20Vault.Contract.PendingOwner(&_ERC20Vault.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_ERC20Vault *ERC20VaultCallerSession) PendingOwner() (common.Address, error) {
	return _ERC20Vault.Contract.PendingOwner(&_ERC20Vault.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_ERC20Vault *ERC20VaultCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _ERC20Vault.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_ERC20Vault *ERC20VaultSession) ProxiableUUID() ([32]byte, error) {
	return _ERC20Vault.Contract.ProxiableUUID(&_ERC20Vault.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_ERC20Vault *ERC20VaultCallerSession) ProxiableUUID() ([32]byte, error) {
	return _ERC20Vault.Contract.ProxiableUUID(&_ERC20Vault.CallOpts)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_ERC20Vault *ERC20VaultCaller) Resolve(opts *bind.CallOpts, _chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _ERC20Vault.contract.Call(opts, &out, "resolve", _chainId, _name, _allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_ERC20Vault *ERC20VaultSession) Resolve(_chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _ERC20Vault.Contract.Resolve(&_ERC20Vault.CallOpts, _chainId, _name, _allowZeroAddress)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_ERC20Vault *ERC20VaultCallerSession) Resolve(_chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _ERC20Vault.Contract.Resolve(&_ERC20Vault.CallOpts, _chainId, _name, _allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_ERC20Vault *ERC20VaultCaller) Resolve0(opts *bind.CallOpts, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _ERC20Vault.contract.Call(opts, &out, "resolve0", _name, _allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_ERC20Vault *ERC20VaultSession) Resolve0(_name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _ERC20Vault.Contract.Resolve0(&_ERC20Vault.CallOpts, _name, _allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_ERC20Vault *ERC20VaultCallerSession) Resolve0(_name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _ERC20Vault.Contract.Resolve0(&_ERC20Vault.CallOpts, _name, _allowZeroAddress)
}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 _interfaceId) pure returns(bool)
func (_ERC20Vault *ERC20VaultCaller) SupportsInterface(opts *bind.CallOpts, _interfaceId [4]byte) (bool, error) {
	var out []interface{}
	err := _ERC20Vault.contract.Call(opts, &out, "supportsInterface", _interfaceId)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 _interfaceId) pure returns(bool)
func (_ERC20Vault *ERC20VaultSession) SupportsInterface(_interfaceId [4]byte) (bool, error) {
	return _ERC20Vault.Contract.SupportsInterface(&_ERC20Vault.CallOpts, _interfaceId)
}

// SupportsInterface is a free data retrieval call binding the contract method 0x01ffc9a7.
//
// Solidity: function supportsInterface(bytes4 _interfaceId) pure returns(bool)
func (_ERC20Vault *ERC20VaultCallerSession) SupportsInterface(_interfaceId [4]byte) (bool, error) {
	return _ERC20Vault.Contract.SupportsInterface(&_ERC20Vault.CallOpts, _interfaceId)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_ERC20Vault *ERC20VaultTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ERC20Vault.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_ERC20Vault *ERC20VaultSession) AcceptOwnership() (*types.Transaction, error) {
	return _ERC20Vault.Contract.AcceptOwnership(&_ERC20Vault.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_ERC20Vault *ERC20VaultTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _ERC20Vault.Contract.AcceptOwnership(&_ERC20Vault.TransactOpts)
}

// ChangeBridgedToken is a paid mutator transaction binding the contract method 0x0ecd8be9.
//
// Solidity: function changeBridgedToken((uint64,address,uint8,string,string) _ctoken, address _btokenNew) returns(address btokenOld_)
func (_ERC20Vault *ERC20VaultTransactor) ChangeBridgedToken(opts *bind.TransactOpts, _ctoken ERC20VaultCanonicalERC20, _btokenNew common.Address) (*types.Transaction, error) {
	return _ERC20Vault.contract.Transact(opts, "changeBridgedToken", _ctoken, _btokenNew)
}

// ChangeBridgedToken is a paid mutator transaction binding the contract method 0x0ecd8be9.
//
// Solidity: function changeBridgedToken((uint64,address,uint8,string,string) _ctoken, address _btokenNew) returns(address btokenOld_)
func (_ERC20Vault *ERC20VaultSession) ChangeBridgedToken(_ctoken ERC20VaultCanonicalERC20, _btokenNew common.Address) (*types.Transaction, error) {
	return _ERC20Vault.Contract.ChangeBridgedToken(&_ERC20Vault.TransactOpts, _ctoken, _btokenNew)
}

// ChangeBridgedToken is a paid mutator transaction binding the contract method 0x0ecd8be9.
//
// Solidity: function changeBridgedToken((uint64,address,uint8,string,string) _ctoken, address _btokenNew) returns(address btokenOld_)
func (_ERC20Vault *ERC20VaultTransactorSession) ChangeBridgedToken(_ctoken ERC20VaultCanonicalERC20, _btokenNew common.Address) (*types.Transaction, error) {
	return _ERC20Vault.Contract.ChangeBridgedToken(&_ERC20Vault.TransactOpts, _ctoken, _btokenNew)
}

// Init is a paid mutator transaction binding the contract method 0xf09a4016.
//
// Solidity: function init(address _owner, address _addressManager) returns()
func (_ERC20Vault *ERC20VaultTransactor) Init(opts *bind.TransactOpts, _owner common.Address, _addressManager common.Address) (*types.Transaction, error) {
	return _ERC20Vault.contract.Transact(opts, "init", _owner, _addressManager)
}

// Init is a paid mutator transaction binding the contract method 0xf09a4016.
//
// Solidity: function init(address _owner, address _addressManager) returns()
func (_ERC20Vault *ERC20VaultSession) Init(_owner common.Address, _addressManager common.Address) (*types.Transaction, error) {
	return _ERC20Vault.Contract.Init(&_ERC20Vault.TransactOpts, _owner, _addressManager)
}

// Init is a paid mutator transaction binding the contract method 0xf09a4016.
//
// Solidity: function init(address _owner, address _addressManager) returns()
func (_ERC20Vault *ERC20VaultTransactorSession) Init(_owner common.Address, _addressManager common.Address) (*types.Transaction, error) {
	return _ERC20Vault.Contract.Init(&_ERC20Vault.TransactOpts, _owner, _addressManager)
}

// OnMessageInvocation is a paid mutator transaction binding the contract method 0x7f07c947.
//
// Solidity: function onMessageInvocation(bytes _data) payable returns()
func (_ERC20Vault *ERC20VaultTransactor) OnMessageInvocation(opts *bind.TransactOpts, _data []byte) (*types.Transaction, error) {
	return _ERC20Vault.contract.Transact(opts, "onMessageInvocation", _data)
}

// OnMessageInvocation is a paid mutator transaction binding the contract method 0x7f07c947.
//
// Solidity: function onMessageInvocation(bytes _data) payable returns()
func (_ERC20Vault *ERC20VaultSession) OnMessageInvocation(_data []byte) (*types.Transaction, error) {
	return _ERC20Vault.Contract.OnMessageInvocation(&_ERC20Vault.TransactOpts, _data)
}

// OnMessageInvocation is a paid mutator transaction binding the contract method 0x7f07c947.
//
// Solidity: function onMessageInvocation(bytes _data) payable returns()
func (_ERC20Vault *ERC20VaultTransactorSession) OnMessageInvocation(_data []byte) (*types.Transaction, error) {
	return _ERC20Vault.Contract.OnMessageInvocation(&_ERC20Vault.TransactOpts, _data)
}

// OnMessageRecalled is a paid mutator transaction binding the contract method 0x0178733a.
//
// Solidity: function onMessageRecalled((uint64,uint64,uint32,address,uint64,address,uint64,address,address,uint256,bytes) _message, bytes32 _msgHash) payable returns()
func (_ERC20Vault *ERC20VaultTransactor) OnMessageRecalled(opts *bind.TransactOpts, _message IBridgeMessage, _msgHash [32]byte) (*types.Transaction, error) {
	return _ERC20Vault.contract.Transact(opts, "onMessageRecalled", _message, _msgHash)
}

// OnMessageRecalled is a paid mutator transaction binding the contract method 0x0178733a.
//
// Solidity: function onMessageRecalled((uint64,uint64,uint32,address,uint64,address,uint64,address,address,uint256,bytes) _message, bytes32 _msgHash) payable returns()
func (_ERC20Vault *ERC20VaultSession) OnMessageRecalled(_message IBridgeMessage, _msgHash [32]byte) (*types.Transaction, error) {
	return _ERC20Vault.Contract.OnMessageRecalled(&_ERC20Vault.TransactOpts, _message, _msgHash)
}

// OnMessageRecalled is a paid mutator transaction binding the contract method 0x0178733a.
//
// Solidity: function onMessageRecalled((uint64,uint64,uint32,address,uint64,address,uint64,address,address,uint256,bytes) _message, bytes32 _msgHash) payable returns()
func (_ERC20Vault *ERC20VaultTransactorSession) OnMessageRecalled(_message IBridgeMessage, _msgHash [32]byte) (*types.Transaction, error) {
	return _ERC20Vault.Contract.OnMessageRecalled(&_ERC20Vault.TransactOpts, _message, _msgHash)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_ERC20Vault *ERC20VaultTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ERC20Vault.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_ERC20Vault *ERC20VaultSession) Pause() (*types.Transaction, error) {
	return _ERC20Vault.Contract.Pause(&_ERC20Vault.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_ERC20Vault *ERC20VaultTransactorSession) Pause() (*types.Transaction, error) {
	return _ERC20Vault.Contract.Pause(&_ERC20Vault.TransactOpts)
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

// SendToken is a paid mutator transaction binding the contract method 0xb84d9ffe.
//
// Solidity: function sendToken((uint64,address,address,uint64,address,uint32,uint256) _op) payable returns((uint64,uint64,uint32,address,uint64,address,uint64,address,address,uint256,bytes) message_)
func (_ERC20Vault *ERC20VaultTransactor) SendToken(opts *bind.TransactOpts, _op ERC20VaultBridgeTransferOp) (*types.Transaction, error) {
	return _ERC20Vault.contract.Transact(opts, "sendToken", _op)
}

// SendToken is a paid mutator transaction binding the contract method 0xb84d9ffe.
//
// Solidity: function sendToken((uint64,address,address,uint64,address,uint32,uint256) _op) payable returns((uint64,uint64,uint32,address,uint64,address,uint64,address,address,uint256,bytes) message_)
func (_ERC20Vault *ERC20VaultSession) SendToken(_op ERC20VaultBridgeTransferOp) (*types.Transaction, error) {
	return _ERC20Vault.Contract.SendToken(&_ERC20Vault.TransactOpts, _op)
}

// SendToken is a paid mutator transaction binding the contract method 0xb84d9ffe.
//
// Solidity: function sendToken((uint64,address,address,uint64,address,uint32,uint256) _op) payable returns((uint64,uint64,uint32,address,uint64,address,uint64,address,address,uint256,bytes) message_)
func (_ERC20Vault *ERC20VaultTransactorSession) SendToken(_op ERC20VaultBridgeTransferOp) (*types.Transaction, error) {
	return _ERC20Vault.Contract.SendToken(&_ERC20Vault.TransactOpts, _op)
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

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_ERC20Vault *ERC20VaultTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _ERC20Vault.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_ERC20Vault *ERC20VaultSession) Unpause() (*types.Transaction, error) {
	return _ERC20Vault.Contract.Unpause(&_ERC20Vault.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_ERC20Vault *ERC20VaultTransactorSession) Unpause() (*types.Transaction, error) {
	return _ERC20Vault.Contract.Unpause(&_ERC20Vault.TransactOpts)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_ERC20Vault *ERC20VaultTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _ERC20Vault.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_ERC20Vault *ERC20VaultSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _ERC20Vault.Contract.UpgradeTo(&_ERC20Vault.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_ERC20Vault *ERC20VaultTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _ERC20Vault.Contract.UpgradeTo(&_ERC20Vault.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_ERC20Vault *ERC20VaultTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _ERC20Vault.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_ERC20Vault *ERC20VaultSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _ERC20Vault.Contract.UpgradeToAndCall(&_ERC20Vault.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_ERC20Vault *ERC20VaultTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _ERC20Vault.Contract.UpgradeToAndCall(&_ERC20Vault.TransactOpts, newImplementation, data)
}

// ERC20VaultAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the ERC20Vault contract.
type ERC20VaultAdminChangedIterator struct {
	Event *ERC20VaultAdminChanged // Event containing the contract specifics and raw log

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
func (it *ERC20VaultAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ERC20VaultAdminChanged)
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
		it.Event = new(ERC20VaultAdminChanged)
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
func (it *ERC20VaultAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ERC20VaultAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ERC20VaultAdminChanged represents a AdminChanged event raised by the ERC20Vault contract.
type ERC20VaultAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_ERC20Vault *ERC20VaultFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*ERC20VaultAdminChangedIterator, error) {

	logs, sub, err := _ERC20Vault.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &ERC20VaultAdminChangedIterator{contract: _ERC20Vault.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_ERC20Vault *ERC20VaultFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *ERC20VaultAdminChanged) (event.Subscription, error) {

	logs, sub, err := _ERC20Vault.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ERC20VaultAdminChanged)
				if err := _ERC20Vault.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_ERC20Vault *ERC20VaultFilterer) ParseAdminChanged(log types.Log) (*ERC20VaultAdminChanged, error) {
	event := new(ERC20VaultAdminChanged)
	if err := _ERC20Vault.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ERC20VaultBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the ERC20Vault contract.
type ERC20VaultBeaconUpgradedIterator struct {
	Event *ERC20VaultBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *ERC20VaultBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ERC20VaultBeaconUpgraded)
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
		it.Event = new(ERC20VaultBeaconUpgraded)
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
func (it *ERC20VaultBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ERC20VaultBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ERC20VaultBeaconUpgraded represents a BeaconUpgraded event raised by the ERC20Vault contract.
type ERC20VaultBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_ERC20Vault *ERC20VaultFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*ERC20VaultBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _ERC20Vault.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &ERC20VaultBeaconUpgradedIterator{contract: _ERC20Vault.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_ERC20Vault *ERC20VaultFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *ERC20VaultBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _ERC20Vault.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ERC20VaultBeaconUpgraded)
				if err := _ERC20Vault.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_ERC20Vault *ERC20VaultFilterer) ParseBeaconUpgraded(log types.Log) (*ERC20VaultBeaconUpgraded, error) {
	event := new(ERC20VaultBeaconUpgraded)
	if err := _ERC20Vault.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ERC20VaultBridgedTokenChangedIterator is returned from FilterBridgedTokenChanged and is used to iterate over the raw logs and unpacked data for BridgedTokenChanged events raised by the ERC20Vault contract.
type ERC20VaultBridgedTokenChangedIterator struct {
	Event *ERC20VaultBridgedTokenChanged // Event containing the contract specifics and raw log

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
func (it *ERC20VaultBridgedTokenChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ERC20VaultBridgedTokenChanged)
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
		it.Event = new(ERC20VaultBridgedTokenChanged)
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
func (it *ERC20VaultBridgedTokenChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ERC20VaultBridgedTokenChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ERC20VaultBridgedTokenChanged represents a BridgedTokenChanged event raised by the ERC20Vault contract.
type ERC20VaultBridgedTokenChanged struct {
	SrcChainId    *big.Int
	Ctoken        common.Address
	BtokenOld     common.Address
	BtokenNew     common.Address
	CtokenSymbol  string
	CtokenName    string
	CtokenDecimal uint8
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterBridgedTokenChanged is a free log retrieval operation binding the contract event 0x031d68e1805917560c34a5f55a7dd91bef98f911190ed02cdbb53caedae6c39d.
//
// Solidity: event BridgedTokenChanged(uint256 indexed srcChainId, address indexed ctoken, address btokenOld, address btokenNew, string ctokenSymbol, string ctokenName, uint8 ctokenDecimal)
func (_ERC20Vault *ERC20VaultFilterer) FilterBridgedTokenChanged(opts *bind.FilterOpts, srcChainId []*big.Int, ctoken []common.Address) (*ERC20VaultBridgedTokenChangedIterator, error) {

	var srcChainIdRule []interface{}
	for _, srcChainIdItem := range srcChainId {
		srcChainIdRule = append(srcChainIdRule, srcChainIdItem)
	}
	var ctokenRule []interface{}
	for _, ctokenItem := range ctoken {
		ctokenRule = append(ctokenRule, ctokenItem)
	}

	logs, sub, err := _ERC20Vault.contract.FilterLogs(opts, "BridgedTokenChanged", srcChainIdRule, ctokenRule)
	if err != nil {
		return nil, err
	}
	return &ERC20VaultBridgedTokenChangedIterator{contract: _ERC20Vault.contract, event: "BridgedTokenChanged", logs: logs, sub: sub}, nil
}

// WatchBridgedTokenChanged is a free log subscription operation binding the contract event 0x031d68e1805917560c34a5f55a7dd91bef98f911190ed02cdbb53caedae6c39d.
//
// Solidity: event BridgedTokenChanged(uint256 indexed srcChainId, address indexed ctoken, address btokenOld, address btokenNew, string ctokenSymbol, string ctokenName, uint8 ctokenDecimal)
func (_ERC20Vault *ERC20VaultFilterer) WatchBridgedTokenChanged(opts *bind.WatchOpts, sink chan<- *ERC20VaultBridgedTokenChanged, srcChainId []*big.Int, ctoken []common.Address) (event.Subscription, error) {

	var srcChainIdRule []interface{}
	for _, srcChainIdItem := range srcChainId {
		srcChainIdRule = append(srcChainIdRule, srcChainIdItem)
	}
	var ctokenRule []interface{}
	for _, ctokenItem := range ctoken {
		ctokenRule = append(ctokenRule, ctokenItem)
	}

	logs, sub, err := _ERC20Vault.contract.WatchLogs(opts, "BridgedTokenChanged", srcChainIdRule, ctokenRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ERC20VaultBridgedTokenChanged)
				if err := _ERC20Vault.contract.UnpackLog(event, "BridgedTokenChanged", log); err != nil {
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

// ParseBridgedTokenChanged is a log parse operation binding the contract event 0x031d68e1805917560c34a5f55a7dd91bef98f911190ed02cdbb53caedae6c39d.
//
// Solidity: event BridgedTokenChanged(uint256 indexed srcChainId, address indexed ctoken, address btokenOld, address btokenNew, string ctokenSymbol, string ctokenName, uint8 ctokenDecimal)
func (_ERC20Vault *ERC20VaultFilterer) ParseBridgedTokenChanged(log types.Log) (*ERC20VaultBridgedTokenChanged, error) {
	event := new(ERC20VaultBridgedTokenChanged)
	if err := _ERC20Vault.contract.UnpackLog(event, "BridgedTokenChanged", log); err != nil {
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

// ERC20VaultOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the ERC20Vault contract.
type ERC20VaultOwnershipTransferStartedIterator struct {
	Event *ERC20VaultOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *ERC20VaultOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ERC20VaultOwnershipTransferStarted)
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
		it.Event = new(ERC20VaultOwnershipTransferStarted)
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
func (it *ERC20VaultOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ERC20VaultOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ERC20VaultOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the ERC20Vault contract.
type ERC20VaultOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_ERC20Vault *ERC20VaultFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*ERC20VaultOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ERC20Vault.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &ERC20VaultOwnershipTransferStartedIterator{contract: _ERC20Vault.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_ERC20Vault *ERC20VaultFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *ERC20VaultOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _ERC20Vault.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ERC20VaultOwnershipTransferStarted)
				if err := _ERC20Vault.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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
func (_ERC20Vault *ERC20VaultFilterer) ParseOwnershipTransferStarted(log types.Log) (*ERC20VaultOwnershipTransferStarted, error) {
	event := new(ERC20VaultOwnershipTransferStarted)
	if err := _ERC20Vault.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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

// ERC20VaultPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the ERC20Vault contract.
type ERC20VaultPausedIterator struct {
	Event *ERC20VaultPaused // Event containing the contract specifics and raw log

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
func (it *ERC20VaultPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ERC20VaultPaused)
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
		it.Event = new(ERC20VaultPaused)
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
func (it *ERC20VaultPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ERC20VaultPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ERC20VaultPaused represents a Paused event raised by the ERC20Vault contract.
type ERC20VaultPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_ERC20Vault *ERC20VaultFilterer) FilterPaused(opts *bind.FilterOpts) (*ERC20VaultPausedIterator, error) {

	logs, sub, err := _ERC20Vault.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &ERC20VaultPausedIterator{contract: _ERC20Vault.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_ERC20Vault *ERC20VaultFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *ERC20VaultPaused) (event.Subscription, error) {

	logs, sub, err := _ERC20Vault.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ERC20VaultPaused)
				if err := _ERC20Vault.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_ERC20Vault *ERC20VaultFilterer) ParsePaused(log types.Log) (*ERC20VaultPaused, error) {
	event := new(ERC20VaultPaused)
	if err := _ERC20Vault.contract.UnpackLog(event, "Paused", log); err != nil {
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
	SrcChainId uint64
	Ctoken     common.Address
	Token      common.Address
	Amount     *big.Int
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterTokenReceived is a free log retrieval operation binding the contract event 0x75a051823424fc80e92556c41cb0ad977ae1dcb09c68a9c38acab86b11a69f89.
//
// Solidity: event TokenReceived(bytes32 indexed msgHash, address indexed from, address indexed to, uint64 srcChainId, address ctoken, address token, uint256 amount)
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

// WatchTokenReceived is a free log subscription operation binding the contract event 0x75a051823424fc80e92556c41cb0ad977ae1dcb09c68a9c38acab86b11a69f89.
//
// Solidity: event TokenReceived(bytes32 indexed msgHash, address indexed from, address indexed to, uint64 srcChainId, address ctoken, address token, uint256 amount)
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

// ParseTokenReceived is a log parse operation binding the contract event 0x75a051823424fc80e92556c41cb0ad977ae1dcb09c68a9c38acab86b11a69f89.
//
// Solidity: event TokenReceived(bytes32 indexed msgHash, address indexed from, address indexed to, uint64 srcChainId, address ctoken, address token, uint256 amount)
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
	Ctoken  common.Address
	Token   common.Address
	Amount  *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterTokenReleased is a free log retrieval operation binding the contract event 0x3dea0f5955b148debf6212261e03bd80eaf8534bee43780452d16637dcc22dd5.
//
// Solidity: event TokenReleased(bytes32 indexed msgHash, address indexed from, address ctoken, address token, uint256 amount)
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

// WatchTokenReleased is a free log subscription operation binding the contract event 0x3dea0f5955b148debf6212261e03bd80eaf8534bee43780452d16637dcc22dd5.
//
// Solidity: event TokenReleased(bytes32 indexed msgHash, address indexed from, address ctoken, address token, uint256 amount)
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

// ParseTokenReleased is a log parse operation binding the contract event 0x3dea0f5955b148debf6212261e03bd80eaf8534bee43780452d16637dcc22dd5.
//
// Solidity: event TokenReleased(bytes32 indexed msgHash, address indexed from, address ctoken, address token, uint256 amount)
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
	DestChainId uint64
	Ctoken      common.Address
	Token       common.Address
	Amount      *big.Int
	Raw         types.Log // Blockchain specific contextual infos
}

// FilterTokenSent is a free log retrieval operation binding the contract event 0xeb8a69f21b7a981e25f90d9f1e2ab7fa5bdbfddbc0ac160344145fc5caa6ddd2.
//
// Solidity: event TokenSent(bytes32 indexed msgHash, address indexed from, address indexed to, uint64 destChainId, address ctoken, address token, uint256 amount)
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

// WatchTokenSent is a free log subscription operation binding the contract event 0xeb8a69f21b7a981e25f90d9f1e2ab7fa5bdbfddbc0ac160344145fc5caa6ddd2.
//
// Solidity: event TokenSent(bytes32 indexed msgHash, address indexed from, address indexed to, uint64 destChainId, address ctoken, address token, uint256 amount)
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

// ParseTokenSent is a log parse operation binding the contract event 0xeb8a69f21b7a981e25f90d9f1e2ab7fa5bdbfddbc0ac160344145fc5caa6ddd2.
//
// Solidity: event TokenSent(bytes32 indexed msgHash, address indexed from, address indexed to, uint64 destChainId, address ctoken, address token, uint256 amount)
func (_ERC20Vault *ERC20VaultFilterer) ParseTokenSent(log types.Log) (*ERC20VaultTokenSent, error) {
	event := new(ERC20VaultTokenSent)
	if err := _ERC20Vault.contract.UnpackLog(event, "TokenSent", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ERC20VaultUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the ERC20Vault contract.
type ERC20VaultUnpausedIterator struct {
	Event *ERC20VaultUnpaused // Event containing the contract specifics and raw log

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
func (it *ERC20VaultUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ERC20VaultUnpaused)
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
		it.Event = new(ERC20VaultUnpaused)
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
func (it *ERC20VaultUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ERC20VaultUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ERC20VaultUnpaused represents a Unpaused event raised by the ERC20Vault contract.
type ERC20VaultUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_ERC20Vault *ERC20VaultFilterer) FilterUnpaused(opts *bind.FilterOpts) (*ERC20VaultUnpausedIterator, error) {

	logs, sub, err := _ERC20Vault.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &ERC20VaultUnpausedIterator{contract: _ERC20Vault.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_ERC20Vault *ERC20VaultFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *ERC20VaultUnpaused) (event.Subscription, error) {

	logs, sub, err := _ERC20Vault.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ERC20VaultUnpaused)
				if err := _ERC20Vault.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_ERC20Vault *ERC20VaultFilterer) ParseUnpaused(log types.Log) (*ERC20VaultUnpaused, error) {
	event := new(ERC20VaultUnpaused)
	if err := _ERC20Vault.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// ERC20VaultUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the ERC20Vault contract.
type ERC20VaultUpgradedIterator struct {
	Event *ERC20VaultUpgraded // Event containing the contract specifics and raw log

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
func (it *ERC20VaultUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(ERC20VaultUpgraded)
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
		it.Event = new(ERC20VaultUpgraded)
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
func (it *ERC20VaultUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *ERC20VaultUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// ERC20VaultUpgraded represents a Upgraded event raised by the ERC20Vault contract.
type ERC20VaultUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_ERC20Vault *ERC20VaultFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*ERC20VaultUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _ERC20Vault.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &ERC20VaultUpgradedIterator{contract: _ERC20Vault.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_ERC20Vault *ERC20VaultFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *ERC20VaultUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _ERC20Vault.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(ERC20VaultUpgraded)
				if err := _ERC20Vault.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_ERC20Vault *ERC20VaultFilterer) ParseUpgraded(log types.Log) (*ERC20VaultUpgraded, error) {
	event := new(ERC20VaultUpgraded)
	if err := _ERC20Vault.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
