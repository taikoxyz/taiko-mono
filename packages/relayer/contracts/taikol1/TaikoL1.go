// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package taikol1

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
	Id                uint64
	Timestamp         uint64
	L1Height          uint64
	L1Hash            [32]byte
	MixHash           [32]byte
	DepositsRoot      [32]byte
	TxListHash        [32]byte
	TxListByteStart   *big.Int
	TxListByteEnd     *big.Int
	GasLimit          uint32
	Beneficiary       common.Address
	CacheTxListInfo   uint8
	Treasure          common.Address
	DepositsProcessed []TaikoDataEthDeposit
}

// TaikoDataConfig is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataConfig struct {
	ChainId                 *big.Int
	MaxNumProposedBlocks    *big.Int
	RingBufferSize          *big.Int
	MaxNumVerifiedBlocks    *big.Int
	MaxVerificationsPerTx   *big.Int
	BlockMaxGasLimit        *big.Int
	MaxTransactionsPerBlock *big.Int
	MaxBytesPerTxList       *big.Int
	MinTxGasLimit           *big.Int
	TxListCacheExpiry       *big.Int
	ProofCooldownPeriod     *big.Int
	MinEthDepositsPerBlock  uint64
	MaxEthDepositsPerBlock  uint64
	MaxEthDepositAmount     *big.Int
	MinEthDepositAmount     *big.Int
	ProofTimeTarget         uint64
	AdjustmentQuotient      uint8
	RelaySignalRoot         bool
	EnableSoloProposer      bool
}

// TaikoDataEthDeposit is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataEthDeposit struct {
	Recipient common.Address
	Amount    *big.Int
}

// TaikoDataForkChoice is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataForkChoice struct {
	Key        [32]byte
	BlockHash  [32]byte
	SignalRoot [32]byte
	ProvenAt   uint64
	Prover     common.Address
	GasUsed    uint32
}

// TaikoDataStateVariables is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataStateVariables struct {
	Basefee                 uint64
	AccBlockFees            uint64
	GenesisHeight           uint64
	GenesisTimestamp        uint64
	NumBlocks               uint64
	ProofTimeIssued         uint64
	LastVerifiedBlockId     uint64
	AccProposedAt           uint64
	NextEthDepositToProcess uint64
	NumEthDeposits          uint64
}

// TaikoL1MetaData contains all meta data concerning the TaikoL1 contract.
var TaikoL1MetaData = &bind.MetaData{
	ABI: "[{\"inputs\":[],\"name\":\"L1_0_FEE_BASE\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_ALREADY_PROVEN\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_ANCHOR_CALLDATA\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_ANCHOR_DEST\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_ANCHOR_GAS_LIMIT\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_ANCHOR_RECEIPT_ADDR\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_ANCHOR_RECEIPT_DATA\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_ANCHOR_RECEIPT_LOGS\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_ANCHOR_RECEIPT_PROOF\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_ANCHOR_RECEIPT_STATUS\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_ANCHOR_RECEIPT_TOPICS\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_ANCHOR_SIG_R\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_ANCHOR_SIG_S\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_ANCHOR_TX_PROOF\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_ANCHOR_TYPE\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_BLOCK_NUMBER\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_BLOCK_NUMBER\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_CANNOT_BE_FIRST_PROVER\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_COMMITTED\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_CONFLICT_PROOF\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_CONTRACT_NOT_ALLOWED\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_DUP_PROVERS\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_EXTRA_DATA\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_GAS_LIMIT\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_ID\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_ID\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INPUT_SIZE\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INVALID_PARAM\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_METADATA_FIELD\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_META_MISMATCH\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_NOT_COMMITTED\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_NOT_ORACLE_PROVER\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_PROOF_LENGTH\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_PROVER\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_SOLO_PROPOSER\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_TOO_MANY_BLOCKS\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_TX_LIST\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_ZKP\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"RESOLVER_DENIED\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"RESOLVER_INVALID_ADDR\",\"type\":\"error\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint64\",\"name\":\"commitSlot\",\"type\":\"uint64\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"commitHash\",\"type\":\"bytes32\"}],\"name\":\"BlockCommitted\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"id\",\"type\":\"uint256\"},{\"components\":[{\"internalType\":\"uint256\",\"name\":\"id\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"l1Height\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"l1Hash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"beneficiary\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"txListHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"mixHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes\",\"name\":\"extraData\",\"type\":\"bytes\"},{\"internalType\":\"uint64\",\"name\":\"gasLimit\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"timestamp\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"commitHeight\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"commitSlot\",\"type\":\"uint64\"}],\"indexed\":false,\"internalType\":\"structTaikoData.BlockMetadata\",\"name\":\"meta\",\"type\":\"tuple\"}],\"name\":\"BlockProposed\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"id\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"parentHash\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"blockHash\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"prover\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint64\",\"name\":\"provenAt\",\"type\":\"uint64\"}],\"name\":\"BlockProven\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"id\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"blockHash\",\"type\":\"bytes32\"}],\"name\":\"BlockVerified\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"srcHeight\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"srcHash\",\"type\":\"bytes32\"}],\"name\":\"HeaderSynced\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint8\",\"name\":\"version\",\"type\":\"uint8\"}],\"name\":\"Initialized\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"previousOwner\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"OwnershipTransferred\",\"type\":\"event\"},{\"inputs\":[],\"name\":\"addressManager\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"commitSlot\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"commitHash\",\"type\":\"bytes32\"}],\"name\":\"commitBlock\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"getBlockFee\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"getConfig\",\"outputs\":[{\"components\":[{\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"maxNumProposedBlocks\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"maxVerificationsPerTx\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"commitConfirmations\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"blockMaxGasLimit\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"maxTransactionsPerBlock\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"maxBytesPerTxList\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"minTxGasLimit\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"anchorTxGasLimit\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"slotSmoothingFactor\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"rewardBurnBips\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"proposerDepositPctg\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"basefeeMAF\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"blockTimeMAF\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"proofTimeMAF\",\"type\":\"uint256\"},{\"internalType\":\"uint64\",\"name\":\"feeMultiplierPctg\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"feeGracePeriodPctg\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"feeMaxPctg\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"blockTimeCap\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"proofTimeCap\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"bootstrapDiscountHalvingPeriod\",\"type\":\"uint64\"},{\"internalType\":\"bool\",\"name\":\"enableTokenomics\",\"type\":\"bool\"},{\"internalType\":\"bool\",\"name\":\"enablePublicInputsCheck\",\"type\":\"bool\"},{\"internalType\":\"bool\",\"name\":\"enableAnchorValidation\",\"type\":\"bool\"}],\"internalType\":\"structTaikoData.Config\",\"name\":\"\",\"type\":\"tuple\"}],\"stateMutability\":\"pure\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"id\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"parentHash\",\"type\":\"bytes32\"}],\"name\":\"getForkChoice\",\"outputs\":[{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"blockHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"prover\",\"type\":\"address\"},{\"internalType\":\"uint64\",\"name\":\"provenAt\",\"type\":\"uint64\"}],\"internalType\":\"structTaikoData.ForkChoice\",\"name\":\"\",\"type\":\"tuple\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"getLatestSyncedHeader\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"provenAt\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"proposedAt\",\"type\":\"uint64\"}],\"name\":\"getProofReward\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"reward\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"id\",\"type\":\"uint256\"}],\"name\":\"getProposedBlock\",\"outputs\":[{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"metaHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint256\",\"name\":\"deposit\",\"type\":\"uint256\"},{\"internalType\":\"address\",\"name\":\"proposer\",\"type\":\"address\"},{\"internalType\":\"uint64\",\"name\":\"proposedAt\",\"type\":\"uint64\"}],\"internalType\":\"structTaikoData.ProposedBlock\",\"name\":\"\",\"type\":\"tuple\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"addr\",\"type\":\"address\"}],\"name\":\"getBalance\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"getStateVariables\",\"outputs\":[{\"components\":[{\"internalType\":\"uint256\",\"name\":\"basefee\",\"type\":\"uint256\"},{\"internalType\":\"uint64\",\"name\":\"genesisHeight\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"genesisTimestamp\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"nextBlockId\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"lastProposedAt\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"avgBlockTime\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"latestVerifiedHeight\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"lastBlockId\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"avgProofTime\",\"type\":\"uint64\"}],\"internalType\":\"structLibUtils.StateVariables\",\"name\":\"\",\"type\":\"tuple\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"number\",\"type\":\"uint256\"}],\"name\":\"getSyncedHeader\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_addressManager\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"_genesisBlockHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint256\",\"name\":\"_basefee\",\"type\":\"uint256\"}],\"name\":\"init\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"commitSlot\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"commitHeight\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"commitHash\",\"type\":\"bytes32\"}],\"name\":\"isCommitValid\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"owner\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes[]\",\"name\":\"inputs\",\"type\":\"bytes[]\"}],\"name\":\"proposeBlock\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"blockId\",\"type\":\"uint256\"},{\"internalType\":\"bytes[]\",\"name\":\"inputs\",\"type\":\"bytes[]\"}],\"name\":\"proveBlock\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"blockId\",\"type\":\"uint256\"},{\"internalType\":\"bytes[]\",\"name\":\"inputs\",\"type\":\"bytes[]\"}],\"name\":\"proveBlockInvalid\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"renounceOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"string\",\"name\":\"name\",\"type\":\"string\"},{\"internalType\":\"bool\",\"name\":\"allowZeroAddress\",\"type\":\"bool\"}],\"name\":\"resolve\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"internalType\":\"string\",\"name\":\"name\",\"type\":\"string\"},{\"internalType\":\"bool\",\"name\":\"allowZeroAddress\",\"type\":\"bool\"}],\"name\":\"resolve\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"hash\",\"type\":\"bytes32\"},{\"internalType\":\"uint8\",\"name\":\"k\",\"type\":\"uint8\"}],\"name\":\"signWithGoldenTouch\",\"outputs\":[{\"internalType\":\"uint8\",\"name\":\"v\",\"type\":\"uint8\"},{\"internalType\":\"uint256\",\"name\":\"r\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"s\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"state\",\"outputs\":[{\"internalType\":\"uint64\",\"name\":\"genesisHeight\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"genesisTimestamp\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"__reservedA1\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"__reservedA2\",\"type\":\"uint64\"},{\"internalType\":\"uint256\",\"name\":\"basefee\",\"type\":\"uint256\"},{\"internalType\":\"uint64\",\"name\":\"nextBlockId\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"lastProposedAt\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"avgBlockTime\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"__avgGasLimit\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"latestVerifiedHeight\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"lastBlockId\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"avgProofTime\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"__reservedC1\",\"type\":\"uint64\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"transferOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"maxBlocks\",\"type\":\"uint256\"}],\"name\":\"verifyBlocks\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"withdrawBalance\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"}]",
}

// TaikoL1ABI is the input ABI used to generate the binding from.
// Deprecated: Use TaikoL1MetaData.ABI instead.
var TaikoL1ABI = TaikoL1MetaData.ABI

// TaikoL1 is an auto generated Go binding around an Ethereum contract.
type TaikoL1 struct {
	TaikoL1Caller     // Read-only binding to the contract
	TaikoL1Transactor // Write-only binding to the contract
	TaikoL1Filterer   // Log filterer for contract events
}

// TaikoL1Caller is an auto generated read-only Go binding around an Ethereum contract.
type TaikoL1Caller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoL1Transactor is an auto generated write-only Go binding around an Ethereum contract.
type TaikoL1Transactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoL1Filterer is an auto generated log filtering Go binding around an Ethereum contract events.
type TaikoL1Filterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// TaikoL1Session is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type TaikoL1Session struct {
	Contract     *TaikoL1          // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// TaikoL1CallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type TaikoL1CallerSession struct {
	Contract *TaikoL1Caller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts  // Call options to use throughout this session
}

// TaikoL1TransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type TaikoL1TransactorSession struct {
	Contract     *TaikoL1Transactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts  // Transaction auth options to use throughout this session
}

// TaikoL1Raw is an auto generated low-level Go binding around an Ethereum contract.
type TaikoL1Raw struct {
	Contract *TaikoL1 // Generic contract binding to access the raw methods on
}

// TaikoL1CallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type TaikoL1CallerRaw struct {
	Contract *TaikoL1Caller // Generic read-only contract binding to access the raw methods on
}

// TaikoL1TransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type TaikoL1TransactorRaw struct {
	Contract *TaikoL1Transactor // Generic write-only contract binding to access the raw methods on
}

// NewTaikoL1 creates a new instance of TaikoL1, bound to a specific deployed contract.
func NewTaikoL1(address common.Address, backend bind.ContractBackend) (*TaikoL1, error) {
	contract, err := bindTaikoL1(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &TaikoL1{TaikoL1Caller: TaikoL1Caller{contract: contract}, TaikoL1Transactor: TaikoL1Transactor{contract: contract}, TaikoL1Filterer: TaikoL1Filterer{contract: contract}}, nil
}

// NewTaikoL1Caller creates a new read-only instance of TaikoL1, bound to a specific deployed contract.
func NewTaikoL1Caller(address common.Address, caller bind.ContractCaller) (*TaikoL1Caller, error) {
	contract, err := bindTaikoL1(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &TaikoL1Caller{contract: contract}, nil
}

// NewTaikoL1Transactor creates a new write-only instance of TaikoL1, bound to a specific deployed contract.
func NewTaikoL1Transactor(address common.Address, transactor bind.ContractTransactor) (*TaikoL1Transactor, error) {
	contract, err := bindTaikoL1(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &TaikoL1Transactor{contract: contract}, nil
}

// NewTaikoL1Filterer creates a new log filterer instance of TaikoL1, bound to a specific deployed contract.
func NewTaikoL1Filterer(address common.Address, filterer bind.ContractFilterer) (*TaikoL1Filterer, error) {
	contract, err := bindTaikoL1(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &TaikoL1Filterer{contract: contract}, nil
}

// bindTaikoL1 binds a generic wrapper to an already deployed contract.
func bindTaikoL1(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := TaikoL1MetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TaikoL1 *TaikoL1Raw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TaikoL1.Contract.TaikoL1Caller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TaikoL1 *TaikoL1Raw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL1.Contract.TaikoL1Transactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TaikoL1 *TaikoL1Raw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TaikoL1.Contract.TaikoL1Transactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_TaikoL1 *TaikoL1CallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _TaikoL1.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_TaikoL1 *TaikoL1TransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL1.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_TaikoL1 *TaikoL1TransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _TaikoL1.Contract.contract.Transact(opts, method, params...)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_TaikoL1 *TaikoL1Caller) AddressManager(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "addressManager")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_TaikoL1 *TaikoL1Session) AddressManager() (common.Address, error) {
	return _TaikoL1.Contract.AddressManager(&_TaikoL1.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_TaikoL1 *TaikoL1CallerSession) AddressManager() (common.Address, error) {
	return _TaikoL1.Contract.AddressManager(&_TaikoL1.CallOpts)
}

// GetBlock is a free data retrieval call binding the contract method 0x04c07569.
//
// Solidity: function getBlock(uint256 blockId) view returns(bytes32 _metaHash, uint256 _deposit, address _proposer, uint64 _proposedAt)
func (_TaikoL1 *TaikoL1Caller) GetBlock(opts *bind.CallOpts, blockId *big.Int) (struct {
	MetaHash   [32]byte
	Deposit    *big.Int
	Proposer   common.Address
	ProposedAt uint64
}, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getBlock", blockId)

	outstruct := new(struct {
		MetaHash   [32]byte
		Deposit    *big.Int
		Proposer   common.Address
		ProposedAt uint64
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.MetaHash = *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)
	outstruct.Deposit = *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)
	outstruct.Proposer = *abi.ConvertType(out[2], new(common.Address)).(*common.Address)
	outstruct.ProposedAt = *abi.ConvertType(out[3], new(uint64)).(*uint64)

	return *outstruct, err

}

// GetBlock is a free data retrieval call binding the contract method 0x04c07569.
//
// Solidity: function getBlock(uint256 blockId) view returns(bytes32 _metaHash, uint256 _deposit, address _proposer, uint64 _proposedAt)
func (_TaikoL1 *TaikoL1Session) GetBlock(blockId *big.Int) (struct {
	MetaHash   [32]byte
	Deposit    *big.Int
	Proposer   common.Address
	ProposedAt uint64
}, error) {
	return _TaikoL1.Contract.GetBlock(&_TaikoL1.CallOpts, blockId)
}

// GetBlock is a free data retrieval call binding the contract method 0x04c07569.
//
// Solidity: function getBlock(uint256 blockId) view returns(bytes32 _metaHash, uint256 _deposit, address _proposer, uint64 _proposedAt)
func (_TaikoL1 *TaikoL1CallerSession) GetBlock(blockId *big.Int) (struct {
	MetaHash   [32]byte
	Deposit    *big.Int
	Proposer   common.Address
	ProposedAt uint64
}, error) {
	return _TaikoL1.Contract.GetBlock(&_TaikoL1.CallOpts, blockId)
}

// GetBlockFee is a free data retrieval call binding the contract method 0x7baf0bc7.
//
// Solidity: function getBlockFee() view returns(uint64)
func (_TaikoL1 *TaikoL1Caller) GetBlockFee(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getBlockFee")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// GetBlockFee is a free data retrieval call binding the contract method 0x7baf0bc7.
//
// Solidity: function getBlockFee() view returns(uint64)
func (_TaikoL1 *TaikoL1Session) GetBlockFee() (uint64, error) {
	return _TaikoL1.Contract.GetBlockFee(&_TaikoL1.CallOpts)
}

// GetBlockFee is a free data retrieval call binding the contract method 0x7baf0bc7.
//
// Solidity: function getBlockFee() view returns(uint64)
func (_TaikoL1 *TaikoL1CallerSession) GetBlockFee() (uint64, error) {
	return _TaikoL1.Contract.GetBlockFee(&_TaikoL1.CallOpts)
}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() pure returns((uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint64,uint64,uint96,uint96,uint64,uint8,bool,bool))
func (_TaikoL1 *TaikoL1Caller) GetConfig(opts *bind.CallOpts) (TaikoDataConfig, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getConfig")

	if err != nil {
		return *new(TaikoDataConfig), err
	}

	out0 := *abi.ConvertType(out[0], new(TaikoDataConfig)).(*TaikoDataConfig)

	return out0, err

}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() pure returns((uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint64,uint64,uint96,uint96,uint64,uint8,bool,bool))
func (_TaikoL1 *TaikoL1Session) GetConfig() (TaikoDataConfig, error) {
	return _TaikoL1.Contract.GetConfig(&_TaikoL1.CallOpts)
}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() pure returns((uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint64,uint64,uint96,uint96,uint64,uint8,bool,bool))
func (_TaikoL1 *TaikoL1CallerSession) GetConfig() (TaikoDataConfig, error) {
	return _TaikoL1.Contract.GetConfig(&_TaikoL1.CallOpts)
}

// GetForkChoice is a free data retrieval call binding the contract method 0x7163e0ed.
//
// Solidity: function getForkChoice(uint256 blockId, bytes32 parentHash, uint32 parentGasUsed) view returns((bytes32,bytes32,bytes32,uint64,address,uint32))
func (_TaikoL1 *TaikoL1Caller) GetForkChoice(opts *bind.CallOpts, blockId *big.Int, parentHash [32]byte, parentGasUsed uint32) (TaikoDataForkChoice, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getForkChoice", blockId, parentHash, parentGasUsed)

	if err != nil {
		return *new(TaikoDataForkChoice), err
	}

	out0 := *abi.ConvertType(out[0], new(TaikoDataForkChoice)).(*TaikoDataForkChoice)

	return out0, err

}

// GetForkChoice is a free data retrieval call binding the contract method 0x7163e0ed.
//
// Solidity: function getForkChoice(uint256 blockId, bytes32 parentHash, uint32 parentGasUsed) view returns((bytes32,bytes32,bytes32,uint64,address,uint32))
func (_TaikoL1 *TaikoL1Session) GetForkChoice(blockId *big.Int, parentHash [32]byte, parentGasUsed uint32) (TaikoDataForkChoice, error) {
	return _TaikoL1.Contract.GetForkChoice(&_TaikoL1.CallOpts, blockId, parentHash, parentGasUsed)
}

// GetForkChoice is a free data retrieval call binding the contract method 0x7163e0ed.
//
// Solidity: function getForkChoice(uint256 blockId, bytes32 parentHash, uint32 parentGasUsed) view returns((bytes32,bytes32,bytes32,uint64,address,uint32))
func (_TaikoL1 *TaikoL1CallerSession) GetForkChoice(blockId *big.Int, parentHash [32]byte, parentGasUsed uint32) (TaikoDataForkChoice, error) {
	return _TaikoL1.Contract.GetForkChoice(&_TaikoL1.CallOpts, blockId, parentHash, parentGasUsed)
}

// GetProofReward is a free data retrieval call binding the contract method 0x4ee56f9e.
//
// Solidity: function getProofReward(uint64 provenAt, uint64 proposedAt) view returns(uint64)
func (_TaikoL1 *TaikoL1Caller) GetProofReward(opts *bind.CallOpts, provenAt uint64, proposedAt uint64) (uint64, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getProofReward", provenAt, proposedAt)

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// GetProofReward is a free data retrieval call binding the contract method 0x4ee56f9e.
//
// Solidity: function getProofReward(uint64 provenAt, uint64 proposedAt) view returns(uint64)
func (_TaikoL1 *TaikoL1Session) GetProofReward(provenAt uint64, proposedAt uint64) (uint64, error) {
	return _TaikoL1.Contract.GetProofReward(&_TaikoL1.CallOpts, provenAt, proposedAt)
}

// GetProofReward is a free data retrieval call binding the contract method 0x4ee56f9e.
//
// Solidity: function getProofReward(uint64 provenAt, uint64 proposedAt) view returns(uint64)
func (_TaikoL1 *TaikoL1CallerSession) GetProofReward(provenAt uint64, proposedAt uint64) (uint64, error) {
	return _TaikoL1.Contract.GetProofReward(&_TaikoL1.CallOpts, provenAt, proposedAt)
}

// GetStateVariables is a free data retrieval call binding the contract method 0xdde89cf5.
//
// Solidity: function getStateVariables() view returns((uint64,uint64,uint64,uint64,uint64,uint64,uint64,uint64,uint64,uint64))
func (_TaikoL1 *TaikoL1Caller) GetStateVariables(opts *bind.CallOpts) (TaikoDataStateVariables, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getStateVariables")

	if err != nil {
		return *new(TaikoDataStateVariables), err
	}

	out0 := *abi.ConvertType(out[0], new(TaikoDataStateVariables)).(*TaikoDataStateVariables)

	return out0, err

}

// GetStateVariables is a free data retrieval call binding the contract method 0xdde89cf5.
//
// Solidity: function getStateVariables() view returns((uint64,uint64,uint64,uint64,uint64,uint64,uint64,uint64,uint64,uint64))
func (_TaikoL1 *TaikoL1Session) GetStateVariables() (TaikoDataStateVariables, error) {
	return _TaikoL1.Contract.GetStateVariables(&_TaikoL1.CallOpts)
}

// GetStateVariables is a free data retrieval call binding the contract method 0xdde89cf5.
//
// Solidity: function getStateVariables() view returns((uint64,uint64,uint64,uint64,uint64,uint64,uint64,uint64,uint64,uint64))
func (_TaikoL1 *TaikoL1CallerSession) GetStateVariables() (TaikoDataStateVariables, error) {
	return _TaikoL1.Contract.GetStateVariables(&_TaikoL1.CallOpts)
}

// GetTaikoTokenBalance is a free data retrieval call binding the contract method 0x8dff9cea.
//
// Solidity: function getTaikoTokenBalance(address addr) view returns(uint256)
func (_TaikoL1 *TaikoL1Caller) GetTaikoTokenBalance(opts *bind.CallOpts, addr common.Address) (*big.Int, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getTaikoTokenBalance", addr)

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// GetTaikoTokenBalance is a free data retrieval call binding the contract method 0x8dff9cea.
//
// Solidity: function getTaikoTokenBalance(address addr) view returns(uint256)
func (_TaikoL1 *TaikoL1Session) GetTaikoTokenBalance(addr common.Address) (*big.Int, error) {
	return _TaikoL1.Contract.GetTaikoTokenBalance(&_TaikoL1.CallOpts, addr)
}

// GetTaikoTokenBalance is a free data retrieval call binding the contract method 0x8dff9cea.
//
// Solidity: function getTaikoTokenBalance(address addr) view returns(uint256)
func (_TaikoL1 *TaikoL1CallerSession) GetTaikoTokenBalance(addr common.Address) (*big.Int, error) {
	return _TaikoL1.Contract.GetTaikoTokenBalance(&_TaikoL1.CallOpts, addr)
}

// GetVerifierName is a free data retrieval call binding the contract method 0x0372303d.
//
// Solidity: function getVerifierName(uint16 id) pure returns(string)
func (_TaikoL1 *TaikoL1Caller) GetVerifierName(opts *bind.CallOpts, id uint16) (string, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getVerifierName", id)

	if err != nil {
		return *new(string), err
	}

	out0 := *abi.ConvertType(out[0], new(string)).(*string)

	return out0, err

}

// GetVerifierName is a free data retrieval call binding the contract method 0x0372303d.
//
// Solidity: function getVerifierName(uint16 id) pure returns(string)
func (_TaikoL1 *TaikoL1Session) GetVerifierName(id uint16) (string, error) {
	return _TaikoL1.Contract.GetVerifierName(&_TaikoL1.CallOpts, id)
}

// GetVerifierName is a free data retrieval call binding the contract method 0x0372303d.
//
// Solidity: function getVerifierName(uint16 id) pure returns(string)
func (_TaikoL1 *TaikoL1CallerSession) GetVerifierName(id uint16) (string, error) {
	return _TaikoL1.Contract.GetVerifierName(&_TaikoL1.CallOpts, id)
}

// GetCrossChainBlockHash is a free data retrieval call binding the contract method 0xa4e6775f.
//
// Solidity: function getCrossChainBlockHash(uint256 blockId) view returns(bytes32)
func (_TaikoL1 *TaikoL1Caller) GetCrossChainBlockHash(opts *bind.CallOpts, blockId *big.Int) ([32]byte, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getCrossChainBlockHash", blockId)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetCrossChainBlockHash is a free data retrieval call binding the contract method 0xa4e6775f.
//
// Solidity: function getCrossChainBlockHash(uint256 blockId) view returns(bytes32)
func (_TaikoL1 *TaikoL1Session) GetCrossChainBlockHash(blockId *big.Int) ([32]byte, error) {
	return _TaikoL1.Contract.GetCrossChainBlockHash(&_TaikoL1.CallOpts, blockId)
}

// GetCrossChainBlockHash is a free data retrieval call binding the contract method 0xa4e6775f.
//
// Solidity: function getCrossChainBlockHash(uint256 blockId) view returns(bytes32)
func (_TaikoL1 *TaikoL1CallerSession) GetCrossChainBlockHash(blockId *big.Int) ([32]byte, error) {
	return _TaikoL1.Contract.GetCrossChainBlockHash(&_TaikoL1.CallOpts, blockId)
}

// GetCrossChainSignalRoot is a free data retrieval call binding the contract method 0x609bbd06.
//
// Solidity: function getCrossChainSignalRoot(uint256 blockId) view returns(bytes32)
func (_TaikoL1 *TaikoL1Caller) GetCrossChainSignalRoot(opts *bind.CallOpts, blockId *big.Int) ([32]byte, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getCrossChainSignalRoot", blockId)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetCrossChainSignalRoot is a free data retrieval call binding the contract method 0x609bbd06.
//
// Solidity: function getCrossChainSignalRoot(uint256 blockId) view returns(bytes32)
func (_TaikoL1 *TaikoL1Session) GetCrossChainSignalRoot(blockId *big.Int) ([32]byte, error) {
	return _TaikoL1.Contract.GetCrossChainSignalRoot(&_TaikoL1.CallOpts, blockId)
}

// GetCrossChainSignalRoot is a free data retrieval call binding the contract method 0x609bbd06.
//
// Solidity: function getCrossChainSignalRoot(uint256 blockId) view returns(bytes32)
func (_TaikoL1 *TaikoL1CallerSession) GetCrossChainSignalRoot(blockId *big.Int) ([32]byte, error) {
	return _TaikoL1.Contract.GetCrossChainSignalRoot(&_TaikoL1.CallOpts, blockId)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoL1 *TaikoL1Caller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoL1 *TaikoL1Session) Owner() (common.Address, error) {
	return _TaikoL1.Contract.Owner(&_TaikoL1.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_TaikoL1 *TaikoL1CallerSession) Owner() (common.Address, error) {
	return _TaikoL1.Contract.Owner(&_TaikoL1.CallOpts)
}

// Resolve is a free data retrieval call binding the contract method 0x0ca4dffd.
//
// Solidity: function resolve(string name, bool allowZeroAddress) view returns(address)
func (_TaikoL1 *TaikoL1Caller) Resolve(opts *bind.CallOpts, name string, allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "resolve", name, allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve is a free data retrieval call binding the contract method 0x0ca4dffd.
//
// Solidity: function resolve(string name, bool allowZeroAddress) view returns(address)
func (_TaikoL1 *TaikoL1Session) Resolve(name string, allowZeroAddress bool) (common.Address, error) {
	return _TaikoL1.Contract.Resolve(&_TaikoL1.CallOpts, name, allowZeroAddress)
}

// Resolve is a free data retrieval call binding the contract method 0x0ca4dffd.
//
// Solidity: function resolve(string name, bool allowZeroAddress) view returns(address)
func (_TaikoL1 *TaikoL1CallerSession) Resolve(name string, allowZeroAddress bool) (common.Address, error) {
	return _TaikoL1.Contract.Resolve(&_TaikoL1.CallOpts, name, allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0x1be2bfa7.
//
// Solidity: function resolve(uint256 chainId, string name, bool allowZeroAddress) view returns(address)
func (_TaikoL1 *TaikoL1Caller) Resolve0(opts *bind.CallOpts, chainId *big.Int, name string, allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "resolve0", chainId, name, allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve0 is a free data retrieval call binding the contract method 0x1be2bfa7.
//
// Solidity: function resolve(uint256 chainId, string name, bool allowZeroAddress) view returns(address)
func (_TaikoL1 *TaikoL1Session) Resolve0(chainId *big.Int, name string, allowZeroAddress bool) (common.Address, error) {
	return _TaikoL1.Contract.Resolve0(&_TaikoL1.CallOpts, chainId, name, allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0x1be2bfa7.
//
// Solidity: function resolve(uint256 chainId, string name, bool allowZeroAddress) view returns(address)
func (_TaikoL1 *TaikoL1CallerSession) Resolve0(chainId *big.Int, name string, allowZeroAddress bool) (common.Address, error) {
	return _TaikoL1.Contract.Resolve0(&_TaikoL1.CallOpts, chainId, name, allowZeroAddress)
}

// State is a free data retrieval call binding the contract method 0xc19d93fb.
//
// Solidity: function state() view returns(bytes32 staticRefs, uint64 genesisHeight, uint64 genesisTimestamp, uint64 __reserved71, uint64 __reserved72, uint64 accProposedAt, uint64 accBlockFees, uint64 numBlocks, uint64 nextEthDepositToProcess, uint64 basefee, uint64 proofTimeIssued, uint64 lastVerifiedBlockId, uint64 __reserved91)
func (_TaikoL1 *TaikoL1Caller) State(opts *bind.CallOpts) (struct {
	StaticRefs              [32]byte
	GenesisHeight           uint64
	GenesisTimestamp        uint64
	Reserved71              uint64
	Reserved72              uint64
	AccProposedAt           uint64
	AccBlockFees            uint64
	NumBlocks               uint64
	NextEthDepositToProcess uint64
	Basefee                 uint64
	ProofTimeIssued         uint64
	LastVerifiedBlockId     uint64
	Reserved91              uint64
}, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "state")

	outstruct := new(struct {
		StaticRefs              [32]byte
		GenesisHeight           uint64
		GenesisTimestamp        uint64
		Reserved71              uint64
		Reserved72              uint64
		AccProposedAt           uint64
		AccBlockFees            uint64
		NumBlocks               uint64
		NextEthDepositToProcess uint64
		Basefee                 uint64
		ProofTimeIssued         uint64
		LastVerifiedBlockId     uint64
		Reserved91              uint64
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.StaticRefs = *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)
	outstruct.GenesisHeight = *abi.ConvertType(out[1], new(uint64)).(*uint64)
	outstruct.GenesisTimestamp = *abi.ConvertType(out[2], new(uint64)).(*uint64)
	outstruct.Reserved71 = *abi.ConvertType(out[3], new(uint64)).(*uint64)
	outstruct.Reserved72 = *abi.ConvertType(out[4], new(uint64)).(*uint64)
	outstruct.AccProposedAt = *abi.ConvertType(out[5], new(uint64)).(*uint64)
	outstruct.AccBlockFees = *abi.ConvertType(out[6], new(uint64)).(*uint64)
	outstruct.NumBlocks = *abi.ConvertType(out[7], new(uint64)).(*uint64)
	outstruct.NextEthDepositToProcess = *abi.ConvertType(out[8], new(uint64)).(*uint64)
	outstruct.Basefee = *abi.ConvertType(out[9], new(uint64)).(*uint64)
	outstruct.ProofTimeIssued = *abi.ConvertType(out[10], new(uint64)).(*uint64)
	outstruct.LastVerifiedBlockId = *abi.ConvertType(out[11], new(uint64)).(*uint64)
	outstruct.Reserved91 = *abi.ConvertType(out[12], new(uint64)).(*uint64)

	return *outstruct, err

}

// State is a free data retrieval call binding the contract method 0xc19d93fb.
//
// Solidity: function state() view returns(bytes32 staticRefs, uint64 genesisHeight, uint64 genesisTimestamp, uint64 __reserved71, uint64 __reserved72, uint64 accProposedAt, uint64 accBlockFees, uint64 numBlocks, uint64 nextEthDepositToProcess, uint64 basefee, uint64 proofTimeIssued, uint64 lastVerifiedBlockId, uint64 __reserved91)
func (_TaikoL1 *TaikoL1Session) State() (struct {
	StaticRefs              [32]byte
	GenesisHeight           uint64
	GenesisTimestamp        uint64
	Reserved71              uint64
	Reserved72              uint64
	AccProposedAt           uint64
	AccBlockFees            uint64
	NumBlocks               uint64
	NextEthDepositToProcess uint64
	Basefee                 uint64
	ProofTimeIssued         uint64
	LastVerifiedBlockId     uint64
	Reserved91              uint64
}, error) {
	return _TaikoL1.Contract.State(&_TaikoL1.CallOpts)
}

// State is a free data retrieval call binding the contract method 0xc19d93fb.
//
// Solidity: function state() view returns(bytes32 staticRefs, uint64 genesisHeight, uint64 genesisTimestamp, uint64 __reserved71, uint64 __reserved72, uint64 accProposedAt, uint64 accBlockFees, uint64 numBlocks, uint64 nextEthDepositToProcess, uint64 basefee, uint64 proofTimeIssued, uint64 lastVerifiedBlockId, uint64 __reserved91)
func (_TaikoL1 *TaikoL1CallerSession) State() (struct {
	StaticRefs              [32]byte
	GenesisHeight           uint64
	GenesisTimestamp        uint64
	Reserved71              uint64
	Reserved72              uint64
	AccProposedAt           uint64
	AccBlockFees            uint64
	NumBlocks               uint64
	NextEthDepositToProcess uint64
	Basefee                 uint64
	ProofTimeIssued         uint64
	LastVerifiedBlockId     uint64
	Reserved91              uint64
}, error) {
	return _TaikoL1.Contract.State(&_TaikoL1.CallOpts)
}

// DepositEtherToL2 is a paid mutator transaction binding the contract method 0xa22f7670.
//
// Solidity: function depositEtherToL2() payable returns()
func (_TaikoL1 *TaikoL1Transactor) DepositEtherToL2(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "depositEtherToL2")
}

// DepositEtherToL2 is a paid mutator transaction binding the contract method 0xa22f7670.
//
// Solidity: function depositEtherToL2() payable returns()
func (_TaikoL1 *TaikoL1Session) DepositEtherToL2() (*types.Transaction, error) {
	return _TaikoL1.Contract.DepositEtherToL2(&_TaikoL1.TransactOpts)
}

// DepositEtherToL2 is a paid mutator transaction binding the contract method 0xa22f7670.
//
// Solidity: function depositEtherToL2() payable returns()
func (_TaikoL1 *TaikoL1TransactorSession) DepositEtherToL2() (*types.Transaction, error) {
	return _TaikoL1.Contract.DepositEtherToL2(&_TaikoL1.TransactOpts)
}

// DepositTaikoToken is a paid mutator transaction binding the contract method 0x98f39aba.
//
// Solidity: function depositTaikoToken(uint256 amount) returns()
func (_TaikoL1 *TaikoL1Transactor) DepositTaikoToken(opts *bind.TransactOpts, amount *big.Int) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "depositTaikoToken", amount)
}

// DepositTaikoToken is a paid mutator transaction binding the contract method 0x98f39aba.
//
// Solidity: function depositTaikoToken(uint256 amount) returns()
func (_TaikoL1 *TaikoL1Session) DepositTaikoToken(amount *big.Int) (*types.Transaction, error) {
	return _TaikoL1.Contract.DepositTaikoToken(&_TaikoL1.TransactOpts, amount)
}

// DepositTaikoToken is a paid mutator transaction binding the contract method 0x98f39aba.
//
// Solidity: function depositTaikoToken(uint256 amount) returns()
func (_TaikoL1 *TaikoL1TransactorSession) DepositTaikoToken(amount *big.Int) (*types.Transaction, error) {
	return _TaikoL1.Contract.DepositTaikoToken(&_TaikoL1.TransactOpts, amount)
}

// Init is a paid mutator transaction binding the contract method 0x578c65a4.
//
// Solidity: function init(address _addressManager, bytes32 _genesisBlockHash, uint64 _initBasefee, uint64 _initProofTimeIssued) returns()
func (_TaikoL1 *TaikoL1Transactor) Init(opts *bind.TransactOpts, _addressManager common.Address, _genesisBlockHash [32]byte, _initBasefee uint64, _initProofTimeIssued uint64) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "init", _addressManager, _genesisBlockHash, _initBasefee, _initProofTimeIssued)
}

// Init is a paid mutator transaction binding the contract method 0x578c65a4.
//
// Solidity: function init(address _addressManager, bytes32 _genesisBlockHash, uint64 _initBasefee, uint64 _initProofTimeIssued) returns()
func (_TaikoL1 *TaikoL1Session) Init(_addressManager common.Address, _genesisBlockHash [32]byte, _initBasefee uint64, _initProofTimeIssued uint64) (*types.Transaction, error) {
	return _TaikoL1.Contract.Init(&_TaikoL1.TransactOpts, _addressManager, _genesisBlockHash, _initBasefee, _initProofTimeIssued)
}

// Init is a paid mutator transaction binding the contract method 0x578c65a4.
//
// Solidity: function init(address _addressManager, bytes32 _genesisBlockHash, uint64 _initBasefee, uint64 _initProofTimeIssued) returns()
func (_TaikoL1 *TaikoL1TransactorSession) Init(_addressManager common.Address, _genesisBlockHash [32]byte, _initBasefee uint64, _initProofTimeIssued uint64) (*types.Transaction, error) {
	return _TaikoL1.Contract.Init(&_TaikoL1.TransactOpts, _addressManager, _genesisBlockHash, _initBasefee, _initProofTimeIssued)
}

// ProposeBlock is a paid mutator transaction binding the contract method 0xef16e845.
//
// Solidity: function proposeBlock(bytes input, bytes txList) returns((uint64,uint64,uint64,bytes32,bytes32,bytes32,bytes32,uint24,uint24,uint32,address,uint8,address,(address,uint96)[]) meta)
func (_TaikoL1 *TaikoL1Transactor) ProposeBlock(opts *bind.TransactOpts, input []byte, txList []byte) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "proposeBlock", input, txList)
}

// ProposeBlock is a paid mutator transaction binding the contract method 0xef16e845.
//
// Solidity: function proposeBlock(bytes input, bytes txList) returns((uint64,uint64,uint64,bytes32,bytes32,bytes32,bytes32,uint24,uint24,uint32,address,uint8,address,(address,uint96)[]) meta)
func (_TaikoL1 *TaikoL1Session) ProposeBlock(input []byte, txList []byte) (*types.Transaction, error) {
	return _TaikoL1.Contract.ProposeBlock(&_TaikoL1.TransactOpts, input, txList)
}

// ProposeBlock is a paid mutator transaction binding the contract method 0xef16e845.
//
// Solidity: function proposeBlock(bytes input, bytes txList) returns((uint64,uint64,uint64,bytes32,bytes32,bytes32,bytes32,uint24,uint24,uint32,address,uint8,address,(address,uint96)[]) meta)
func (_TaikoL1 *TaikoL1TransactorSession) ProposeBlock(input []byte, txList []byte) (*types.Transaction, error) {
	return _TaikoL1.Contract.ProposeBlock(&_TaikoL1.TransactOpts, input, txList)
}

// ProveBlock is a paid mutator transaction binding the contract method 0xf3840f60.
//
// Solidity: function proveBlock(uint256 blockId, bytes input) returns()
func (_TaikoL1 *TaikoL1Transactor) ProveBlock(opts *bind.TransactOpts, blockId *big.Int, input []byte) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "proveBlock", blockId, input)
}

// ProveBlock is a paid mutator transaction binding the contract method 0xf3840f60.
//
// Solidity: function proveBlock(uint256 blockId, bytes input) returns()
func (_TaikoL1 *TaikoL1Session) ProveBlock(blockId *big.Int, input []byte) (*types.Transaction, error) {
	return _TaikoL1.Contract.ProveBlock(&_TaikoL1.TransactOpts, blockId, input)
}

// ProveBlock is a paid mutator transaction binding the contract method 0xf3840f60.
//
// Solidity: function proveBlock(uint256 blockId, bytes input) returns()
func (_TaikoL1 *TaikoL1TransactorSession) ProveBlock(blockId *big.Int, input []byte) (*types.Transaction, error) {
	return _TaikoL1.Contract.ProveBlock(&_TaikoL1.TransactOpts, blockId, input)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoL1 *TaikoL1Transactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoL1 *TaikoL1Session) RenounceOwnership() (*types.Transaction, error) {
	return _TaikoL1.Contract.RenounceOwnership(&_TaikoL1.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_TaikoL1 *TaikoL1TransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _TaikoL1.Contract.RenounceOwnership(&_TaikoL1.TransactOpts)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoL1 *TaikoL1Transactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoL1 *TaikoL1Session) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _TaikoL1.Contract.TransferOwnership(&_TaikoL1.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_TaikoL1 *TaikoL1TransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _TaikoL1.Contract.TransferOwnership(&_TaikoL1.TransactOpts, newOwner)
}

// VerifyBlocks is a paid mutator transaction binding the contract method 0x2fb5ae0a.
//
// Solidity: function verifyBlocks(uint256 maxBlocks) returns()
func (_TaikoL1 *TaikoL1Transactor) VerifyBlocks(opts *bind.TransactOpts, maxBlocks *big.Int) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "verifyBlocks", maxBlocks)
}

// VerifyBlocks is a paid mutator transaction binding the contract method 0x2fb5ae0a.
//
// Solidity: function verifyBlocks(uint256 maxBlocks) returns()
func (_TaikoL1 *TaikoL1Session) VerifyBlocks(maxBlocks *big.Int) (*types.Transaction, error) {
	return _TaikoL1.Contract.VerifyBlocks(&_TaikoL1.TransactOpts, maxBlocks)
}

// VerifyBlocks is a paid mutator transaction binding the contract method 0x2fb5ae0a.
//
// Solidity: function verifyBlocks(uint256 maxBlocks) returns()
func (_TaikoL1 *TaikoL1TransactorSession) VerifyBlocks(maxBlocks *big.Int) (*types.Transaction, error) {
	return _TaikoL1.Contract.VerifyBlocks(&_TaikoL1.TransactOpts, maxBlocks)
}

// WithdrawTaikoToken is a paid mutator transaction binding the contract method 0x5043f059.
//
// Solidity: function withdrawTaikoToken(uint256 amount) returns()
func (_TaikoL1 *TaikoL1Transactor) WithdrawTaikoToken(opts *bind.TransactOpts, amount *big.Int) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "withdrawTaikoToken", amount)
}

// WithdrawTaikoToken is a paid mutator transaction binding the contract method 0x5043f059.
//
// Solidity: function withdrawTaikoToken(uint256 amount) returns()
func (_TaikoL1 *TaikoL1Session) WithdrawTaikoToken(amount *big.Int) (*types.Transaction, error) {
	return _TaikoL1.Contract.WithdrawTaikoToken(&_TaikoL1.TransactOpts, amount)
}

// WithdrawTaikoToken is a paid mutator transaction binding the contract method 0x5043f059.
//
// Solidity: function withdrawTaikoToken(uint256 amount) returns()
func (_TaikoL1 *TaikoL1TransactorSession) WithdrawTaikoToken(amount *big.Int) (*types.Transaction, error) {
	return _TaikoL1.Contract.WithdrawTaikoToken(&_TaikoL1.TransactOpts, amount)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_TaikoL1 *TaikoL1Transactor) Receive(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _TaikoL1.contract.RawTransact(opts, nil) // calldata is disallowed for receive function
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_TaikoL1 *TaikoL1Session) Receive() (*types.Transaction, error) {
	return _TaikoL1.Contract.Receive(&_TaikoL1.TransactOpts)
}

// Receive is a paid mutator transaction binding the contract receive function.
//
// Solidity: receive() payable returns()
func (_TaikoL1 *TaikoL1TransactorSession) Receive() (*types.Transaction, error) {
	return _TaikoL1.Contract.Receive(&_TaikoL1.TransactOpts)
}

// TaikoL1BlockProposedIterator is returned from FilterBlockProposed and is used to iterate over the raw logs and unpacked data for BlockProposed events raised by the TaikoL1 contract.
type TaikoL1BlockProposedIterator struct {
	Event *TaikoL1BlockProposed // Event containing the contract specifics and raw log

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
func (it *TaikoL1BlockProposedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BlockProposed)
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
		it.Event = new(TaikoL1BlockProposed)
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
func (it *TaikoL1BlockProposedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BlockProposedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BlockProposed represents a BlockProposed event raised by the TaikoL1 contract.
type TaikoL1BlockProposed struct {
	Id   *big.Int
	Meta TaikoDataBlockMetadata
	Raw  types.Log // Blockchain specific contextual infos
}

// FilterBlockProposed is a free log retrieval operation binding the contract event 0x31cc3eebb5aea55796fe5ba252fe1833fd17d063cb6e83634758fa58e7181535.
//
// Solidity: event BlockProposed(uint256 indexed id, (uint64,uint64,uint64,bytes32,bytes32,bytes32,bytes32,uint24,uint24,uint32,address,uint8,address,(address,uint96)[]) meta)
func (_TaikoL1 *TaikoL1Filterer) FilterBlockProposed(opts *bind.FilterOpts, id []*big.Int) (*TaikoL1BlockProposedIterator, error) {

	var idRule []interface{}
	for _, idItem := range id {
		idRule = append(idRule, idItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BlockProposed", idRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BlockProposedIterator{contract: _TaikoL1.contract, event: "BlockProposed", logs: logs, sub: sub}, nil
}

// WatchBlockProposed is a free log subscription operation binding the contract event 0x31cc3eebb5aea55796fe5ba252fe1833fd17d063cb6e83634758fa58e7181535.
//
// Solidity: event BlockProposed(uint256 indexed id, (uint64,uint64,uint64,bytes32,bytes32,bytes32,bytes32,uint24,uint24,uint32,address,uint8,address,(address,uint96)[]) meta)
func (_TaikoL1 *TaikoL1Filterer) WatchBlockProposed(opts *bind.WatchOpts, sink chan<- *TaikoL1BlockProposed, id []*big.Int) (event.Subscription, error) {

	var idRule []interface{}
	for _, idItem := range id {
		idRule = append(idRule, idItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BlockProposed", idRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BlockProposed)
				if err := _TaikoL1.contract.UnpackLog(event, "BlockProposed", log); err != nil {
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

// ParseBlockProposed is a log parse operation binding the contract event 0x31cc3eebb5aea55796fe5ba252fe1833fd17d063cb6e83634758fa58e7181535.
//
// Solidity: event BlockProposed(uint256 indexed id, (uint64,uint64,uint64,bytes32,bytes32,bytes32,bytes32,uint24,uint24,uint32,address,uint8,address,(address,uint96)[]) meta)
func (_TaikoL1 *TaikoL1Filterer) ParseBlockProposed(log types.Log) (*TaikoL1BlockProposed, error) {
	event := new(TaikoL1BlockProposed)
	if err := _TaikoL1.contract.UnpackLog(event, "BlockProposed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BlockProvenIterator is returned from FilterBlockProven and is used to iterate over the raw logs and unpacked data for BlockProven events raised by the TaikoL1 contract.
type TaikoL1BlockProvenIterator struct {
	Event *TaikoL1BlockProven // Event containing the contract specifics and raw log

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
func (it *TaikoL1BlockProvenIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BlockProven)
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
		it.Event = new(TaikoL1BlockProven)
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
func (it *TaikoL1BlockProvenIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BlockProvenIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BlockProven represents a BlockProven event raised by the TaikoL1 contract.
type TaikoL1BlockProven struct {
	Id         *big.Int
	ParentHash [32]byte
	BlockHash  [32]byte
	SignalRoot [32]byte
	Prover     common.Address
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterBlockProven is a free log retrieval operation binding the contract event 0xd93fde3ea1bb11dcd7a4e66320a05fc5aa63983b6447eff660084c4b1b1b499b.
//
// Solidity: event BlockProven(uint256 indexed id, bytes32 parentHash, bytes32 blockHash, bytes32 signalRoot, address prover)
func (_TaikoL1 *TaikoL1Filterer) FilterBlockProven(opts *bind.FilterOpts, id []*big.Int) (*TaikoL1BlockProvenIterator, error) {

	var idRule []interface{}
	for _, idItem := range id {
		idRule = append(idRule, idItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BlockProven", idRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BlockProvenIterator{contract: _TaikoL1.contract, event: "BlockProven", logs: logs, sub: sub}, nil
}

// WatchBlockProven is a free log subscription operation binding the contract event 0xd93fde3ea1bb11dcd7a4e66320a05fc5aa63983b6447eff660084c4b1b1b499b.
//
// Solidity: event BlockProven(uint256 indexed id, bytes32 parentHash, bytes32 blockHash, bytes32 signalRoot, address prover)
func (_TaikoL1 *TaikoL1Filterer) WatchBlockProven(opts *bind.WatchOpts, sink chan<- *TaikoL1BlockProven, id []*big.Int) (event.Subscription, error) {

	var idRule []interface{}
	for _, idItem := range id {
		idRule = append(idRule, idItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BlockProven", idRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BlockProven)
				if err := _TaikoL1.contract.UnpackLog(event, "BlockProven", log); err != nil {
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

// ParseBlockProven is a log parse operation binding the contract event 0xd93fde3ea1bb11dcd7a4e66320a05fc5aa63983b6447eff660084c4b1b1b499b.
//
// Solidity: event BlockProven(uint256 indexed id, bytes32 parentHash, bytes32 blockHash, bytes32 signalRoot, address prover)
func (_TaikoL1 *TaikoL1Filterer) ParseBlockProven(log types.Log) (*TaikoL1BlockProven, error) {
	event := new(TaikoL1BlockProven)
	if err := _TaikoL1.contract.UnpackLog(event, "BlockProven", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BlockVerifiedIterator is returned from FilterBlockVerified and is used to iterate over the raw logs and unpacked data for BlockVerified events raised by the TaikoL1 contract.
type TaikoL1BlockVerifiedIterator struct {
	Event *TaikoL1BlockVerified // Event containing the contract specifics and raw log

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
func (it *TaikoL1BlockVerifiedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BlockVerified)
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
		it.Event = new(TaikoL1BlockVerified)
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
func (it *TaikoL1BlockVerifiedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BlockVerifiedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BlockVerified represents a BlockVerified event raised by the TaikoL1 contract.
type TaikoL1BlockVerified struct {
	Id        *big.Int
	BlockHash [32]byte
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterBlockVerified is a free log retrieval operation binding the contract event 0x68b82650828a9621868d09dc161400acbe189fa002e3fb7cf9dea5c2c6f928ee.
//
// Solidity: event BlockVerified(uint256 indexed id, bytes32 blockHash)
func (_TaikoL1 *TaikoL1Filterer) FilterBlockVerified(opts *bind.FilterOpts, id []*big.Int) (*TaikoL1BlockVerifiedIterator, error) {

	var idRule []interface{}
	for _, idItem := range id {
		idRule = append(idRule, idItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BlockVerified", idRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BlockVerifiedIterator{contract: _TaikoL1.contract, event: "BlockVerified", logs: logs, sub: sub}, nil
}

// WatchBlockVerified is a free log subscription operation binding the contract event 0x68b82650828a9621868d09dc161400acbe189fa002e3fb7cf9dea5c2c6f928ee.
//
// Solidity: event BlockVerified(uint256 indexed id, bytes32 blockHash)
func (_TaikoL1 *TaikoL1Filterer) WatchBlockVerified(opts *bind.WatchOpts, sink chan<- *TaikoL1BlockVerified, id []*big.Int) (event.Subscription, error) {

	var idRule []interface{}
	for _, idItem := range id {
		idRule = append(idRule, idItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BlockVerified", idRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BlockVerified)
				if err := _TaikoL1.contract.UnpackLog(event, "BlockVerified", log); err != nil {
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

// ParseBlockVerified is a log parse operation binding the contract event 0x68b82650828a9621868d09dc161400acbe189fa002e3fb7cf9dea5c2c6f928ee.
//
// Solidity: event BlockVerified(uint256 indexed id, bytes32 blockHash)
func (_TaikoL1 *TaikoL1Filterer) ParseBlockVerified(log types.Log) (*TaikoL1BlockVerified, error) {
	event := new(TaikoL1BlockVerified)
	if err := _TaikoL1.contract.UnpackLog(event, "BlockVerified", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1EthDepositedIterator is returned from FilterEthDeposited and is used to iterate over the raw logs and unpacked data for EthDeposited events raised by the TaikoL1 contract.
type TaikoL1EthDepositedIterator struct {
	Event *TaikoL1EthDeposited // Event containing the contract specifics and raw log

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
func (it *TaikoL1EthDepositedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1EthDeposited)
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
		it.Event = new(TaikoL1EthDeposited)
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
func (it *TaikoL1EthDepositedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1EthDepositedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1EthDeposited represents a EthDeposited event raised by the TaikoL1 contract.
type TaikoL1EthDeposited struct {
	Deposit TaikoDataEthDeposit
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterEthDeposited is a free log retrieval operation binding the contract event 0x1c146ddfc652d3b24f1c37ed1cabbb690bf0e198aea624f49211500467182eba.
//
// Solidity: event EthDeposited((address,uint96) deposit)
func (_TaikoL1 *TaikoL1Filterer) FilterEthDeposited(opts *bind.FilterOpts) (*TaikoL1EthDepositedIterator, error) {

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "EthDeposited")
	if err != nil {
		return nil, err
	}
	return &TaikoL1EthDepositedIterator{contract: _TaikoL1.contract, event: "EthDeposited", logs: logs, sub: sub}, nil
}

// WatchEthDeposited is a free log subscription operation binding the contract event 0x1c146ddfc652d3b24f1c37ed1cabbb690bf0e198aea624f49211500467182eba.
//
// Solidity: event EthDeposited((address,uint96) deposit)
func (_TaikoL1 *TaikoL1Filterer) WatchEthDeposited(opts *bind.WatchOpts, sink chan<- *TaikoL1EthDeposited) (event.Subscription, error) {

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "EthDeposited")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1EthDeposited)
				if err := _TaikoL1.contract.UnpackLog(event, "EthDeposited", log); err != nil {
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

// ParseEthDeposited is a log parse operation binding the contract event 0x1c146ddfc652d3b24f1c37ed1cabbb690bf0e198aea624f49211500467182eba.
//
// Solidity: event EthDeposited((address,uint96) deposit)
func (_TaikoL1 *TaikoL1Filterer) ParseEthDeposited(log types.Log) (*TaikoL1EthDeposited, error) {
	event := new(TaikoL1EthDeposited)
	if err := _TaikoL1.contract.UnpackLog(event, "EthDeposited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1InitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the TaikoL1 contract.
type TaikoL1InitializedIterator struct {
	Event *TaikoL1Initialized // Event containing the contract specifics and raw log

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
func (it *TaikoL1InitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1Initialized)
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
		it.Event = new(TaikoL1Initialized)
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
func (it *TaikoL1InitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1InitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1Initialized represents a Initialized event raised by the TaikoL1 contract.
type TaikoL1Initialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_TaikoL1 *TaikoL1Filterer) FilterInitialized(opts *bind.FilterOpts) (*TaikoL1InitializedIterator, error) {

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &TaikoL1InitializedIterator{contract: _TaikoL1.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_TaikoL1 *TaikoL1Filterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *TaikoL1Initialized) (event.Subscription, error) {

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1Initialized)
				if err := _TaikoL1.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_TaikoL1 *TaikoL1Filterer) ParseInitialized(log types.Log) (*TaikoL1Initialized, error) {
	event := new(TaikoL1Initialized)
	if err := _TaikoL1.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1OwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the TaikoL1 contract.
type TaikoL1OwnershipTransferredIterator struct {
	Event *TaikoL1OwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *TaikoL1OwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1OwnershipTransferred)
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
		it.Event = new(TaikoL1OwnershipTransferred)
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
func (it *TaikoL1OwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1OwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1OwnershipTransferred represents a OwnershipTransferred event raised by the TaikoL1 contract.
type TaikoL1OwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_TaikoL1 *TaikoL1Filterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*TaikoL1OwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1OwnershipTransferredIterator{contract: _TaikoL1.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_TaikoL1 *TaikoL1Filterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *TaikoL1OwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1OwnershipTransferred)
				if err := _TaikoL1.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_TaikoL1 *TaikoL1Filterer) ParseOwnershipTransferred(log types.Log) (*TaikoL1OwnershipTransferred, error) {
	event := new(TaikoL1OwnershipTransferred)
	if err := _TaikoL1.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1CrossChainSyncedIterator is returned from FilterCrossChainSynced and is used to iterate over the raw logs and unpacked data for CrossChainSynced events raised by the TaikoL1 contract.
type TaikoL1CrossChainSyncedIterator struct {
	Event *TaikoL1CrossChainSynced // Event containing the contract specifics and raw log

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
func (it *TaikoL1CrossChainSyncedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1CrossChainSynced)
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
		it.Event = new(TaikoL1CrossChainSynced)
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
func (it *TaikoL1CrossChainSyncedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1CrossChainSyncedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1CrossChainSynced represents a CrossChainSynced event raised by the TaikoL1 contract.
type TaikoL1CrossChainSynced struct {
	SrcHeight  *big.Int
	BlockHash  [32]byte
	SignalRoot [32]byte
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterCrossChainSynced is a free log retrieval operation binding the contract event 0xc7edd3d480c294297f3924d0ffab64074e7fb22e004ea492d5dd691fa1fc99c0.
//
// Solidity: event CrossChainSynced(uint256 indexed srcHeight, bytes32 blockHash, bytes32 signalRoot)
func (_TaikoL1 *TaikoL1Filterer) FilterCrossChainSynced(opts *bind.FilterOpts, srcHeight []*big.Int) (*TaikoL1CrossChainSyncedIterator, error) {

	var srcHeightRule []interface{}
	for _, srcHeightItem := range srcHeight {
		srcHeightRule = append(srcHeightRule, srcHeightItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "CrossChainSynced", srcHeightRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1CrossChainSyncedIterator{contract: _TaikoL1.contract, event: "CrossChainSynced", logs: logs, sub: sub}, nil
}

// WatchCrossChainSynced is a free log subscription operation binding the contract event 0xc7edd3d480c294297f3924d0ffab64074e7fb22e004ea492d5dd691fa1fc99c0.
//
// Solidity: event CrossChainSynced(uint256 indexed srcHeight, bytes32 blockHash, bytes32 signalRoot)
func (_TaikoL1 *TaikoL1Filterer) WatchCrossChainSynced(opts *bind.WatchOpts, sink chan<- *TaikoL1CrossChainSynced, srcHeight []*big.Int) (event.Subscription, error) {

	var srcHeightRule []interface{}
	for _, srcHeightItem := range srcHeight {
		srcHeightRule = append(srcHeightRule, srcHeightItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "CrossChainSynced", srcHeightRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1CrossChainSynced)
				if err := _TaikoL1.contract.UnpackLog(event, "CrossChainSynced", log); err != nil {
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

// ParseCrossChainSynced is a log parse operation binding the contract event 0xc7edd3d480c294297f3924d0ffab64074e7fb22e004ea492d5dd691fa1fc99c0.
//
// Solidity: event CrossChainSynced(uint256 indexed srcHeight, bytes32 blockHash, bytes32 signalRoot)
func (_TaikoL1 *TaikoL1Filterer) ParseCrossChainSynced(log types.Log) (*TaikoL1CrossChainSynced, error) {
	event := new(TaikoL1CrossChainSynced)
	if err := _TaikoL1.contract.UnpackLog(event, "CrossChainSynced", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
