// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package taikol2

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

// TaikoDataConfig is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataConfig struct {
	ChainId                        *big.Int
	MaxNumBlocks                   *big.Int
	BlockHashHistory               *big.Int
	ZkProofsPerBlock               *big.Int
	MaxVerificationsPerTx          *big.Int
	CommitConfirmations            *big.Int
	MaxProofsPerForkChoice         *big.Int
	BlockMaxGasLimit               *big.Int
	MaxTransactionsPerBlock        *big.Int
	MaxBytesPerTxList              *big.Int
	MinTxGasLimit                  *big.Int
	AnchorTxGasLimit               *big.Int
	FeePremiumLamda                *big.Int
	RewardBurnBips                 *big.Int
	ProposerDepositPctg            *big.Int
	FeeBaseMAF                     *big.Int
	BlockTimeMAF                   *big.Int
	ProofTimeMAF                   *big.Int
	RewardMultiplierPctg           uint64
	FeeGracePeriodPctg             uint64
	FeeMaxPeriodPctg               uint64
	BlockTimeCap                   uint64
	ProofTimeCap                   uint64
	BootstrapDiscountHalvingPeriod uint64
	InitialUncleDelay              uint64
	EnableTokenomics               bool
	EnablePublicInputsCheck        bool
	EnableProofValidation          bool
}

// TaikoL2ABI is the input ABI used to generate the binding from.
const TaikoL2ABI = "[{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_addressManager\",\"type\":\"address\"}],\"stateMutability\":\"nonpayable\",\"type\":\"constructor\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"bytes32\",\"name\":\"txListHash\",\"type\":\"bytes32\"}],\"name\":\"BlockInvalidated\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"height\",\"type\":\"uint256\"},{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"srcHeight\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"srcHash\",\"type\":\"bytes32\"}],\"name\":\"HeaderSynced\",\"type\":\"event\"},{\"inputs\":[],\"name\":\"addressManager\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"l1Height\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"l1Hash\",\"type\":\"bytes32\"}],\"name\":\"anchor\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"number\",\"type\":\"uint256\"}],\"name\":\"getBlockHash\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"getConfig\",\"outputs\":[{\"components\":[{\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"maxNumBlocks\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"blockHashHistory\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"zkProofsPerBlock\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"maxVerificationsPerTx\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"commitConfirmations\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"maxProofsPerForkChoice\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"blockMaxGasLimit\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"maxTransactionsPerBlock\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"maxBytesPerTxList\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"minTxGasLimit\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"anchorTxGasLimit\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"feePremiumLamda\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"rewardBurnBips\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"proposerDepositPctg\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"feeBaseMAF\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"blockTimeMAF\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"proofTimeMAF\",\"type\":\"uint256\"},{\"internalType\":\"uint64\",\"name\":\"rewardMultiplierPctg\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"feeGracePeriodPctg\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"feeMaxPeriodPctg\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"blockTimeCap\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"proofTimeCap\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"bootstrapDiscountHalvingPeriod\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"initialUncleDelay\",\"type\":\"uint64\"},{\"internalType\":\"bool\",\"name\":\"enableTokenomics\",\"type\":\"bool\"},{\"internalType\":\"bool\",\"name\":\"enablePublicInputsCheck\",\"type\":\"bool\"},{\"internalType\":\"bool\",\"name\":\"enableProofValidation\",\"type\":\"bool\"}],\"internalType\":\"structTaikoData.Config\",\"name\":\"config\",\"type\":\"tuple\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"getLatestSyncedHeader\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"number\",\"type\":\"uint256\"}],\"name\":\"getSyncedHeader\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes\",\"name\":\"txList\",\"type\":\"bytes\"},{\"internalType\":\"enumLibInvalidTxList.Reason\",\"name\":\"hint\",\"type\":\"uint8\"},{\"internalType\":\"uint256\",\"name\":\"txIdx\",\"type\":\"uint256\"}],\"name\":\"invalidateBlock\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"latestSyncedL1Height\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"publicInputHash\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"string\",\"name\":\"name\",\"type\":\"string\"},{\"internalType\":\"bool\",\"name\":\"allowZeroAddress\",\"type\":\"bool\"}],\"name\":\"resolve\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"internalType\":\"string\",\"name\":\"name\",\"type\":\"string\"},{\"internalType\":\"bool\",\"name\":\"allowZeroAddress\",\"type\":\"bool\"}],\"name\":\"resolve\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"}]"

// TaikoL2 is an auto generated Go binding around an Ethereum contract.
type TaikoL2 struct {
	TaikoL2Caller     // Read-only binding to the contract
	TaikoL2Transactor // Write-only binding to the contract
	TaikoL2Filterer   // Log filterer for contract events
}

// TaikoL2Caller is an auto generated read-only Go binding around an Ethereum contract.
type TaikoL2Caller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoL2Transactor is an auto generated write-only Go binding around an Ethereum contract.
type TaikoL2Transactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoL2Filterer is an auto generated log filtering Go binding around an Ethereum contract events.
type TaikoL2Filterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoL2Session is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type TaikoL2Session struct {
	Contract     *TaikoL2          // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// TaikoL2CallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type TaikoL2CallerSession struct {
	Contract *TaikoL2Caller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts  // Call options to use throughout this session
}

// TaikoL2TransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type TaikoL2TransactorSession struct {
	Contract     *TaikoL2Transactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts  // Transaction auth options to use throughout this session
}

// TaikoL2Raw is an auto generated low-level Go binding around an Ethereum contract.
type TaikoL2Raw struct {
	Contract *TaikoL2 // Generic contract binding to access the raw methods on
}

// TaikoL2CallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type TaikoL2CallerRaw struct {
	Contract *TaikoL2Caller // Generic read-only contract binding to access the raw methods on
}

// TaikoL2TransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type TaikoL2TransactorRaw struct {
	Contract *TaikoL2Transactor // Generic write-only contract binding to access the raw methods on
}

// NewTaikoL2 creates a new instance of TaikoL2, bound to a specific deployed contract.
func NewTaikoL2(address common.Address, backend bind.ContractBackend) (*TaikoL2, error) {
	contract, err := bindTaikoL2(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &TaikoL2{TaikoL2Caller: TaikoL2Caller{contract: contract}, TaikoL2Transactor: TaikoL2Transactor{contract: contract}, TaikoL2Filterer: TaikoL2Filterer{contract: contract}}, nil
}

// NewTaikoL2Caller creates a new read-only instance of TaikoL2, bound to a specific deployed contract.
func NewTaikoL2Caller(address common.Address, caller bind.ContractCaller) (*TaikoL2Caller, error) {
	contract, err := bindTaikoL2(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &TaikoL2Caller{contract: contract}, nil
}

// NewTaikoL2Transactor creates a new write-only instance of TaikoL2, bound to a specific deployed contract.
func NewTaikoL2Transactor(address common.Address, transactor bind.ContractTransactor) (*TaikoL2Transactor, error) {
	contract, err := bindTaikoL2(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &TaikoL2Transactor{contract: contract}, nil
}

// NewTaikoL2Filterer creates a new log filterer instance of TaikoL2, bound to a specific deployed contract.
func NewTaikoL2Filterer(address common.Address, filterer bind.ContractFilterer) (*TaikoL2Filterer, error) {
	contract, err := bindTaikoL2(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &TaikoL2Filterer{contract: contract}, nil
}

// bindTaikoL2 binds a generic wrapper to an already deployed contract.
func bindTaikoL2(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := abi.JSON(strings.NewReader(TaikoL2ABI))
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TaikoL2 *TaikoL2Raw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TaikoL2.Contract.TaikoL2Caller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TaikoL2 *TaikoL2Raw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL2.Contract.TaikoL2Transactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TaikoL2 *TaikoL2Raw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TaikoL2.Contract.TaikoL2Transactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TaikoL2 *TaikoL2CallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TaikoL2.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TaikoL2 *TaikoL2TransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL2.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TaikoL2 *TaikoL2TransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TaikoL2.Contract.contract.Transact(opts, method, params...)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_TaikoL2 *TaikoL2Caller) AddressManager(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "addressManager")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_TaikoL2 *TaikoL2Session) AddressManager() (common.Address, error) {
	return _TaikoL2.Contract.AddressManager(&_TaikoL2.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_TaikoL2 *TaikoL2CallerSession) AddressManager() (common.Address, error) {
	return _TaikoL2.Contract.AddressManager(&_TaikoL2.CallOpts)
}

// GetBlockHash is a free data retrieval call binding the contract method 0xee82ac5e.
//
// Solidity: function getBlockHash(uint256 number) view returns(bytes32)
func (_TaikoL2 *TaikoL2Caller) GetBlockHash(opts *bind.CallOpts, number *big.Int) ([32]byte, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "getBlockHash", number)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetBlockHash is a free data retrieval call binding the contract method 0xee82ac5e.
//
// Solidity: function getBlockHash(uint256 number) view returns(bytes32)
func (_TaikoL2 *TaikoL2Session) GetBlockHash(number *big.Int) ([32]byte, error) {
	return _TaikoL2.Contract.GetBlockHash(&_TaikoL2.CallOpts, number)
}

// GetBlockHash is a free data retrieval call binding the contract method 0xee82ac5e.
//
// Solidity: function getBlockHash(uint256 number) view returns(bytes32)
func (_TaikoL2 *TaikoL2CallerSession) GetBlockHash(number *big.Int) ([32]byte, error) {
	return _TaikoL2.Contract.GetBlockHash(&_TaikoL2.CallOpts, number)
}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() view returns((uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint64,uint64,uint64,uint64,uint64,uint64,uint64,bool,bool,bool) config)
func (_TaikoL2 *TaikoL2Caller) GetConfig(opts *bind.CallOpts) (TaikoDataConfig, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "getConfig")

	if err != nil {
		return *new(TaikoDataConfig), err
	}

	out0 := *abi.ConvertType(out[0], new(TaikoDataConfig)).(*TaikoDataConfig)

	return out0, err

}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() view returns((uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint64,uint64,uint64,uint64,uint64,uint64,uint64,bool,bool,bool) config)
func (_TaikoL2 *TaikoL2Session) GetConfig() (TaikoDataConfig, error) {
	return _TaikoL2.Contract.GetConfig(&_TaikoL2.CallOpts)
}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() view returns((uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint64,uint64,uint64,uint64,uint64,uint64,uint64,bool,bool,bool) config)
func (_TaikoL2 *TaikoL2CallerSession) GetConfig() (TaikoDataConfig, error) {
	return _TaikoL2.Contract.GetConfig(&_TaikoL2.CallOpts)
}

// GetLatestSyncedHeader is a free data retrieval call binding the contract method 0x5155ce9f.
//
// Solidity: function getLatestSyncedHeader() view returns(bytes32)
func (_TaikoL2 *TaikoL2Caller) GetLatestSyncedHeader(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "getLatestSyncedHeader")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetLatestSyncedHeader is a free data retrieval call binding the contract method 0x5155ce9f.
//
// Solidity: function getLatestSyncedHeader() view returns(bytes32)
func (_TaikoL2 *TaikoL2Session) GetLatestSyncedHeader() ([32]byte, error) {
	return _TaikoL2.Contract.GetLatestSyncedHeader(&_TaikoL2.CallOpts)
}

// GetLatestSyncedHeader is a free data retrieval call binding the contract method 0x5155ce9f.
//
// Solidity: function getLatestSyncedHeader() view returns(bytes32)
func (_TaikoL2 *TaikoL2CallerSession) GetLatestSyncedHeader() ([32]byte, error) {
	return _TaikoL2.Contract.GetLatestSyncedHeader(&_TaikoL2.CallOpts)
}

// GetSyncedHeader is a free data retrieval call binding the contract method 0x25bf86f2.
//
// Solidity: function getSyncedHeader(uint256 number) view returns(bytes32)
func (_TaikoL2 *TaikoL2Caller) GetSyncedHeader(opts *bind.CallOpts, number *big.Int) ([32]byte, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "getSyncedHeader", number)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetSyncedHeader is a free data retrieval call binding the contract method 0x25bf86f2.
//
// Solidity: function getSyncedHeader(uint256 number) view returns(bytes32)
func (_TaikoL2 *TaikoL2Session) GetSyncedHeader(number *big.Int) ([32]byte, error) {
	return _TaikoL2.Contract.GetSyncedHeader(&_TaikoL2.CallOpts, number)
}

// GetSyncedHeader is a free data retrieval call binding the contract method 0x25bf86f2.
//
// Solidity: function getSyncedHeader(uint256 number) view returns(bytes32)
func (_TaikoL2 *TaikoL2CallerSession) GetSyncedHeader(number *big.Int) ([32]byte, error) {
	return _TaikoL2.Contract.GetSyncedHeader(&_TaikoL2.CallOpts, number)
}

// LatestSyncedL1Height is a free data retrieval call binding the contract method 0xc7b96908.
//
// Solidity: function latestSyncedL1Height() view returns(uint256)
func (_TaikoL2 *TaikoL2Caller) LatestSyncedL1Height(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "latestSyncedL1Height")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// LatestSyncedL1Height is a free data retrieval call binding the contract method 0xc7b96908.
//
// Solidity: function latestSyncedL1Height() view returns(uint256)
func (_TaikoL2 *TaikoL2Session) LatestSyncedL1Height() (*big.Int, error) {
	return _TaikoL2.Contract.LatestSyncedL1Height(&_TaikoL2.CallOpts)
}

// LatestSyncedL1Height is a free data retrieval call binding the contract method 0xc7b96908.
//
// Solidity: function latestSyncedL1Height() view returns(uint256)
func (_TaikoL2 *TaikoL2CallerSession) LatestSyncedL1Height() (*big.Int, error) {
	return _TaikoL2.Contract.LatestSyncedL1Height(&_TaikoL2.CallOpts)
}

// PublicInputHash is a free data retrieval call binding the contract method 0xdac5df78.
//
// Solidity: function publicInputHash() view returns(bytes32)
func (_TaikoL2 *TaikoL2Caller) PublicInputHash(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "publicInputHash")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// PublicInputHash is a free data retrieval call binding the contract method 0xdac5df78.
//
// Solidity: function publicInputHash() view returns(bytes32)
func (_TaikoL2 *TaikoL2Session) PublicInputHash() ([32]byte, error) {
	return _TaikoL2.Contract.PublicInputHash(&_TaikoL2.CallOpts)
}

// PublicInputHash is a free data retrieval call binding the contract method 0xdac5df78.
//
// Solidity: function publicInputHash() view returns(bytes32)
func (_TaikoL2 *TaikoL2CallerSession) PublicInputHash() ([32]byte, error) {
	return _TaikoL2.Contract.PublicInputHash(&_TaikoL2.CallOpts)
}

// Resolve is a free data retrieval call binding the contract method 0x0ca4dffd.
//
// Solidity: function resolve(string name, bool allowZeroAddress) view returns(address)
func (_TaikoL2 *TaikoL2Caller) Resolve(opts *bind.CallOpts, name string, allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "resolve", name, allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve is a free data retrieval call binding the contract method 0x0ca4dffd.
//
// Solidity: function resolve(string name, bool allowZeroAddress) view returns(address)
func (_TaikoL2 *TaikoL2Session) Resolve(name string, allowZeroAddress bool) (common.Address, error) {
	return _TaikoL2.Contract.Resolve(&_TaikoL2.CallOpts, name, allowZeroAddress)
}

// Resolve is a free data retrieval call binding the contract method 0x0ca4dffd.
//
// Solidity: function resolve(string name, bool allowZeroAddress) view returns(address)
func (_TaikoL2 *TaikoL2CallerSession) Resolve(name string, allowZeroAddress bool) (common.Address, error) {
	return _TaikoL2.Contract.Resolve(&_TaikoL2.CallOpts, name, allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0x1be2bfa7.
//
// Solidity: function resolve(uint256 chainId, string name, bool allowZeroAddress) view returns(address)
func (_TaikoL2 *TaikoL2Caller) Resolve0(opts *bind.CallOpts, chainId *big.Int, name string, allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _TaikoL2.contract.Call(opts, &out, "resolve0", chainId, name, allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve0 is a free data retrieval call binding the contract method 0x1be2bfa7.
//
// Solidity: function resolve(uint256 chainId, string name, bool allowZeroAddress) view returns(address)
func (_TaikoL2 *TaikoL2Session) Resolve0(chainId *big.Int, name string, allowZeroAddress bool) (common.Address, error) {
	return _TaikoL2.Contract.Resolve0(&_TaikoL2.CallOpts, chainId, name, allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0x1be2bfa7.
//
// Solidity: function resolve(uint256 chainId, string name, bool allowZeroAddress) view returns(address)
func (_TaikoL2 *TaikoL2CallerSession) Resolve0(chainId *big.Int, name string, allowZeroAddress bool) (common.Address, error) {
	return _TaikoL2.Contract.Resolve0(&_TaikoL2.CallOpts, chainId, name, allowZeroAddress)
}

// Anchor is a paid mutator transaction binding the contract method 0xa0ca2d08.
//
// Solidity: function anchor(uint256 l1Height, bytes32 l1Hash) returns()
func (_TaikoL2 *TaikoL2Transactor) Anchor(opts *bind.TransactOpts, l1Height *big.Int, l1Hash [32]byte) (*types.Transaction, error) {
	return _TaikoL2.contract.Transact(opts, "anchor", l1Height, l1Hash)
}

// Anchor is a paid mutator transaction binding the contract method 0xa0ca2d08.
//
// Solidity: function anchor(uint256 l1Height, bytes32 l1Hash) returns()
func (_TaikoL2 *TaikoL2Session) Anchor(l1Height *big.Int, l1Hash [32]byte) (*types.Transaction, error) {
	return _TaikoL2.Contract.Anchor(&_TaikoL2.TransactOpts, l1Height, l1Hash)
}

// Anchor is a paid mutator transaction binding the contract method 0xa0ca2d08.
//
// Solidity: function anchor(uint256 l1Height, bytes32 l1Hash) returns()
func (_TaikoL2 *TaikoL2TransactorSession) Anchor(l1Height *big.Int, l1Hash [32]byte) (*types.Transaction, error) {
	return _TaikoL2.Contract.Anchor(&_TaikoL2.TransactOpts, l1Height, l1Hash)
}

// InvalidateBlock is a paid mutator transaction binding the contract method 0x975e09a0.
//
// Solidity: function invalidateBlock(bytes txList, uint8 hint, uint256 txIdx) returns()
func (_TaikoL2 *TaikoL2Transactor) InvalidateBlock(opts *bind.TransactOpts, txList []byte, hint uint8, txIdx *big.Int) (*types.Transaction, error) {
	return _TaikoL2.contract.Transact(opts, "invalidateBlock", txList, hint, txIdx)
}

// InvalidateBlock is a paid mutator transaction binding the contract method 0x975e09a0.
//
// Solidity: function invalidateBlock(bytes txList, uint8 hint, uint256 txIdx) returns()
func (_TaikoL2 *TaikoL2Session) InvalidateBlock(txList []byte, hint uint8, txIdx *big.Int) (*types.Transaction, error) {
	return _TaikoL2.Contract.InvalidateBlock(&_TaikoL2.TransactOpts, txList, hint, txIdx)
}

// InvalidateBlock is a paid mutator transaction binding the contract method 0x975e09a0.
//
// Solidity: function invalidateBlock(bytes txList, uint8 hint, uint256 txIdx) returns()
func (_TaikoL2 *TaikoL2TransactorSession) InvalidateBlock(txList []byte, hint uint8, txIdx *big.Int) (*types.Transaction, error) {
	return _TaikoL2.Contract.InvalidateBlock(&_TaikoL2.TransactOpts, txList, hint, txIdx)
}

// TaikoL2BlockInvalidatedIterator is returned from FilterBlockInvalidated and is used to iterate over the raw logs and unpacked data for BlockInvalidated events raised by the TaikoL2 contract.
type TaikoL2BlockInvalidatedIterator struct {
	Event *TaikoL2BlockInvalidated // Event containing the contract specifics and raw log

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
func (it *TaikoL2BlockInvalidatedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL2BlockInvalidated)
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
		it.Event = new(TaikoL2BlockInvalidated)
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
func (it *TaikoL2BlockInvalidatedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL2BlockInvalidatedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL2BlockInvalidated represents a BlockInvalidated event raised by the TaikoL2 contract.
type TaikoL2BlockInvalidated struct {
	TxListHash [32]byte
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterBlockInvalidated is a free log retrieval operation binding the contract event 0x64b299ff9f8ba674288abb53380419048a4271dda03b837ecba6b40e6ddea4a2.
//
// Solidity: event BlockInvalidated(bytes32 indexed txListHash)
func (_TaikoL2 *TaikoL2Filterer) FilterBlockInvalidated(opts *bind.FilterOpts, txListHash [][32]byte) (*TaikoL2BlockInvalidatedIterator, error) {

	var txListHashRule []interface{}
	for _, txListHashItem := range txListHash {
		txListHashRule = append(txListHashRule, txListHashItem)
	}

	logs, sub, err := _TaikoL2.contract.FilterLogs(opts, "BlockInvalidated", txListHashRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL2BlockInvalidatedIterator{contract: _TaikoL2.contract, event: "BlockInvalidated", logs: logs, sub: sub}, nil
}

// WatchBlockInvalidated is a free log subscription operation binding the contract event 0x64b299ff9f8ba674288abb53380419048a4271dda03b837ecba6b40e6ddea4a2.
//
// Solidity: event BlockInvalidated(bytes32 indexed txListHash)
func (_TaikoL2 *TaikoL2Filterer) WatchBlockInvalidated(opts *bind.WatchOpts, sink chan<- *TaikoL2BlockInvalidated, txListHash [][32]byte) (event.Subscription, error) {

	var txListHashRule []interface{}
	for _, txListHashItem := range txListHash {
		txListHashRule = append(txListHashRule, txListHashItem)
	}

	logs, sub, err := _TaikoL2.contract.WatchLogs(opts, "BlockInvalidated", txListHashRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL2BlockInvalidated)
				if err := _TaikoL2.contract.UnpackLog(event, "BlockInvalidated", log); err != nil {
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

// ParseBlockInvalidated is a log parse operation binding the contract event 0x64b299ff9f8ba674288abb53380419048a4271dda03b837ecba6b40e6ddea4a2.
//
// Solidity: event BlockInvalidated(bytes32 indexed txListHash)
func (_TaikoL2 *TaikoL2Filterer) ParseBlockInvalidated(log types.Log) (*TaikoL2BlockInvalidated, error) {
	event := new(TaikoL2BlockInvalidated)
	if err := _TaikoL2.contract.UnpackLog(event, "BlockInvalidated", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL2HeaderSyncedIterator is returned from FilterHeaderSynced and is used to iterate over the raw logs and unpacked data for HeaderSynced events raised by the TaikoL2 contract.
type TaikoL2HeaderSyncedIterator struct {
	Event *TaikoL2HeaderSynced // Event containing the contract specifics and raw log

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
func (it *TaikoL2HeaderSyncedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL2HeaderSynced)
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
		it.Event = new(TaikoL2HeaderSynced)
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
func (it *TaikoL2HeaderSyncedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL2HeaderSyncedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL2HeaderSynced represents a HeaderSynced event raised by the TaikoL2 contract.
type TaikoL2HeaderSynced struct {
	Height    *big.Int
	SrcHeight *big.Int
	SrcHash   [32]byte
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterHeaderSynced is a free log retrieval operation binding the contract event 0x930c750845026c7bb04c0e3d9111d512b4c86981713c4944a35a10a4a7a854f3.
//
// Solidity: event HeaderSynced(uint256 indexed height, uint256 indexed srcHeight, bytes32 srcHash)
func (_TaikoL2 *TaikoL2Filterer) FilterHeaderSynced(opts *bind.FilterOpts, height []*big.Int, srcHeight []*big.Int) (*TaikoL2HeaderSyncedIterator, error) {

	var heightRule []interface{}
	for _, heightItem := range height {
		heightRule = append(heightRule, heightItem)
	}
	var srcHeightRule []interface{}
	for _, srcHeightItem := range srcHeight {
		srcHeightRule = append(srcHeightRule, srcHeightItem)
	}

	logs, sub, err := _TaikoL2.contract.FilterLogs(opts, "HeaderSynced", heightRule, srcHeightRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL2HeaderSyncedIterator{contract: _TaikoL2.contract, event: "HeaderSynced", logs: logs, sub: sub}, nil
}

// WatchHeaderSynced is a free log subscription operation binding the contract event 0x930c750845026c7bb04c0e3d9111d512b4c86981713c4944a35a10a4a7a854f3.
//
// Solidity: event HeaderSynced(uint256 indexed height, uint256 indexed srcHeight, bytes32 srcHash)
func (_TaikoL2 *TaikoL2Filterer) WatchHeaderSynced(opts *bind.WatchOpts, sink chan<- *TaikoL2HeaderSynced, height []*big.Int, srcHeight []*big.Int) (event.Subscription, error) {

	var heightRule []interface{}
	for _, heightItem := range height {
		heightRule = append(heightRule, heightItem)
	}
	var srcHeightRule []interface{}
	for _, srcHeightItem := range srcHeight {
		srcHeightRule = append(srcHeightRule, srcHeightItem)
	}

	logs, sub, err := _TaikoL2.contract.WatchLogs(opts, "HeaderSynced", heightRule, srcHeightRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL2HeaderSynced)
				if err := _TaikoL2.contract.UnpackLog(event, "HeaderSynced", log); err != nil {
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

// ParseHeaderSynced is a log parse operation binding the contract event 0x930c750845026c7bb04c0e3d9111d512b4c86981713c4944a35a10a4a7a854f3.
//
// Solidity: event HeaderSynced(uint256 indexed height, uint256 indexed srcHeight, bytes32 srcHash)
func (_TaikoL2 *TaikoL2Filterer) ParseHeaderSynced(log types.Log) (*TaikoL2HeaderSynced, error) {
	event := new(TaikoL2HeaderSynced)
	if err := _TaikoL2.contract.UnpackLog(event, "HeaderSynced", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
