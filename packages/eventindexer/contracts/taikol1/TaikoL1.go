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

// TaikoDataBlock is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataBlock struct {
	MetaHash             [32]byte
	Prover               common.Address
	ProofBond            *big.Int
	BlockId              uint64
	ProposedAt           uint64
	NextTransitionId     uint32
	VerifiedTransitionId uint32
	Reserved             [7][32]byte
}

// TaikoDataBlockMetadata is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataBlockMetadata struct {
	Id                uint64
	Timestamp         uint64
	L1Height          uint64
	L1Hash            [32]byte
	MixHash           [32]byte
	TxListHash        [32]byte
	TxListByteStart   *big.Int
	TxListByteEnd     *big.Int
	GasLimit          uint32
	Proposer          common.Address
	DepositsProcessed []TaikoDataEthDeposit
}

// TaikoDataConfig is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataConfig struct {
	ChainId                          *big.Int
	RelaySignalRoot                  bool
	BlockMaxProposals                uint64
	BlockRingBufferSize              uint64
	BlockMaxVerificationsPerTx       uint64
	BlockMaxGasLimit                 uint32
	BlockFeeBaseGas                  uint32
	BlockMaxTxListBytes              *big.Int
	BlockTxListExpiry                *big.Int
	ProposerRewardPerSecond          *big.Int
	ProposerRewardMax                *big.Int
	ProofRegularCooldown             *big.Int
	ProofOracleCooldown              *big.Int
	ProofWindow                      uint16
	ProofBond                        *big.Int
	SkipProverAssignmentVerificaiton bool
	EthDepositRingBufferSize         *big.Int
	EthDepositMinCountPerBlock       uint64
	EthDepositMaxCountPerBlock       uint64
	EthDepositMinAmount              *big.Int
	EthDepositMaxAmount              *big.Int
	EthDepositGas                    *big.Int
	EthDepositMaxFee                 *big.Int
}

// TaikoDataEthDeposit is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataEthDeposit struct {
	Recipient common.Address
	Amount    *big.Int
	Id        uint64
}

// TaikoDataSlotA is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataSlotA struct {
	GenesisHeight           uint64
	GenesisTimestamp        uint64
	NumEthDeposits          uint64
	NextEthDepositToProcess uint64
}

// TaikoDataSlotB is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataSlotB struct {
	NumBlocks               uint64
	NextEthDepositToProcess uint64
	LastVerifiedAt          uint64
	LastVerifiedBlockId     uint64
}

// TaikoDataStateVariables is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataStateVariables struct {
	GenesisHeight           uint64
	GenesisTimestamp        uint64
	NumBlocks               uint64
	LastVerifiedBlockId     uint64
	NextEthDepositToProcess uint64
	NumEthDeposits          uint64
}

// TaikoDataTransition is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataTransition struct {
	Key        [32]byte
	BlockHash  [32]byte
	SignalRoot [32]byte
	Prover     common.Address
	ProvenAt   uint64
	Reserved   [6][32]byte
}

// TaikoL1MetaData contains all meta data concerning the TaikoL1 contract.
var TaikoL1MetaData = &bind.MetaData{
	ABI: "[{\"inputs\":[],\"name\":\"L1_ALREADY_PROVEN\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_ALREADY_PROVEN\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_BLOCK_ID_MISMATCH\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_BLOCK_ID_MISMATCH\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_BLOCK_ID_MISMATCH\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_EVIDENCE_MISMATCH\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_EVIDENCE_MISMATCH\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INSUFFICIENT_TOKEN\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INSUFFICIENT_TOKEN\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INVALID_ASSIGNMENT\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INVALID_ASSIGNMENT\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INVALID_BLOCK_ID\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INVALID_BLOCK_ID\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INVALID_BLOCK_ID\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INVALID_CONFIG\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INVALID_CONFIG\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INVALID_ETH_DEPOSIT\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INVALID_ETH_DEPOSIT\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INVALID_EVIDENCE\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INVALID_EVIDENCE\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INVALID_METADATA\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INVALID_METADATA\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INVALID_ORACLE_PROVER\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INVALID_ORACLE_PROVER\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INVALID_PARAM\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INVALID_PROOF\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INVALID_PROPOSER\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INVALID_PROPOSER\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INVALID_PROVER\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INVALID_PROVER\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INVALID_PROVER_SIG\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_INVALID_PROVER_SIG\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_NOT_PROVEABLE\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_NOT_PROVEABLE\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_SAME_PROOF\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_SAME_PROOF\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_TOO_MANY_BLOCKS\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_TOO_MANY_BLOCKS\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_TRANSITION_NOT_FOUND\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_TRANSITION_NOT_FOUND\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_TX_LIST\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_TX_LIST\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_TX_LIST_HASH\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_TX_LIST_HASH\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_TX_LIST_NOT_EXIST\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_TX_LIST_NOT_EXIST\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_TX_LIST_RANGE\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_TX_LIST_RANGE\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_UNEXPECTED_TRANSITION_ID\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"L1_UNEXPECTED_TRANSITION_ID\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"RESOLVER_DENIED\",\"type\":\"error\"},{\"inputs\":[],\"name\":\"RESOLVER_INVALID_ADDR\",\"type\":\"error\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"name\",\"type\":\"bytes32\"}],\"name\":\"RESOLVER_ZERO_ADDR\",\"type\":\"error\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"addressManager\",\"type\":\"address\"}],\"name\":\"AddressManagerChanged\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"blockId\",\"type\":\"uint256\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"prover\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"reward\",\"type\":\"uint256\"},{\"components\":[{\"internalType\":\"uint64\",\"name\":\"id\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"timestamp\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"l1Height\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"l1Hash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"mixHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"txListHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint24\",\"name\":\"txListByteStart\",\"type\":\"uint24\"},{\"internalType\":\"uint24\",\"name\":\"txListByteEnd\",\"type\":\"uint24\"},{\"internalType\":\"uint32\",\"name\":\"gasLimit\",\"type\":\"uint32\"},{\"internalType\":\"address\",\"name\":\"proposer\",\"type\":\"address\"},{\"components\":[{\"internalType\":\"address\",\"name\":\"recipient\",\"type\":\"address\"},{\"internalType\":\"uint96\",\"name\":\"amount\",\"type\":\"uint96\"},{\"internalType\":\"uint64\",\"name\":\"id\",\"type\":\"uint64\"}],\"internalType\":\"structTaikoData.EthDeposit[]\",\"name\":\"depositsProcessed\",\"type\":\"tuple[]\"}],\"indexed\":false,\"internalType\":\"structTaikoData.BlockMetadata\",\"name\":\"meta\",\"type\":\"tuple\"}],\"name\":\"BlockProposed\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"blockId\",\"type\":\"uint256\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"prover\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"reward\",\"type\":\"uint256\"},{\"components\":[{\"internalType\":\"uint64\",\"name\":\"id\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"timestamp\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"l1Height\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"l1Hash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"mixHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"txListHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint24\",\"name\":\"txListByteStart\",\"type\":\"uint24\"},{\"internalType\":\"uint24\",\"name\":\"txListByteEnd\",\"type\":\"uint24\"},{\"internalType\":\"uint32\",\"name\":\"gasLimit\",\"type\":\"uint32\"},{\"internalType\":\"address\",\"name\":\"proposer\",\"type\":\"address\"},{\"components\":[{\"internalType\":\"address\",\"name\":\"recipient\",\"type\":\"address\"},{\"internalType\":\"uint96\",\"name\":\"amount\",\"type\":\"uint96\"},{\"internalType\":\"uint64\",\"name\":\"id\",\"type\":\"uint64\"}],\"internalType\":\"structTaikoData.EthDeposit[]\",\"name\":\"depositsProcessed\",\"type\":\"tuple[]\"}],\"indexed\":false,\"internalType\":\"structTaikoData.BlockMetadata\",\"name\":\"meta\",\"type\":\"tuple\"}],\"name\":\"BlockProposed\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"blockId\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"parentHash\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"blockHash\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"signalRoot\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"prover\",\"type\":\"address\"}],\"name\":\"BlockProven\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"blockId\",\"type\":\"uint256\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"parentHash\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"blockHash\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"signalRoot\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"address\",\"name\":\"prover\",\"type\":\"address\"}],\"name\":\"BlockProven\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"blockId\",\"type\":\"uint256\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"prover\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"blockHash\",\"type\":\"bytes32\"}],\"name\":\"BlockVerified\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint256\",\"name\":\"blockId\",\"type\":\"uint256\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"prover\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"blockHash\",\"type\":\"bytes32\"}],\"name\":\"BlockVerified\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"from\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint64\",\"name\":\"blockId\",\"type\":\"uint64\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"bond\",\"type\":\"uint256\"}],\"name\":\"BondReceived\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"from\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint64\",\"name\":\"blockId\",\"type\":\"uint64\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"bond\",\"type\":\"uint256\"}],\"name\":\"BondReceived\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint64\",\"name\":\"blockId\",\"type\":\"uint64\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"bond\",\"type\":\"uint256\"}],\"name\":\"BondReturned\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint64\",\"name\":\"blockId\",\"type\":\"uint64\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"bond\",\"type\":\"uint256\"}],\"name\":\"BondReturned\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint64\",\"name\":\"blockId\",\"type\":\"uint64\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"bond\",\"type\":\"uint256\"}],\"name\":\"BondRewarded\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"to\",\"type\":\"address\"},{\"indexed\":false,\"internalType\":\"uint64\",\"name\":\"blockId\",\"type\":\"uint64\"},{\"indexed\":false,\"internalType\":\"uint256\",\"name\":\"bond\",\"type\":\"uint256\"}],\"name\":\"BondRewarded\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint64\",\"name\":\"srcHeight\",\"type\":\"uint64\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"blockHash\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"signalRoot\",\"type\":\"bytes32\"}],\"name\":\"CrossChainSynced\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"uint64\",\"name\":\"srcHeight\",\"type\":\"uint64\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"blockHash\",\"type\":\"bytes32\"},{\"indexed\":false,\"internalType\":\"bytes32\",\"name\":\"signalRoot\",\"type\":\"bytes32\"}],\"name\":\"CrossChainSynced\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"components\":[{\"internalType\":\"address\",\"name\":\"recipient\",\"type\":\"address\"},{\"internalType\":\"uint96\",\"name\":\"amount\",\"type\":\"uint96\"},{\"internalType\":\"uint64\",\"name\":\"id\",\"type\":\"uint64\"}],\"indexed\":false,\"internalType\":\"structTaikoData.EthDeposit\",\"name\":\"deposit\",\"type\":\"tuple\"}],\"name\":\"EthDeposited\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"components\":[{\"internalType\":\"address\",\"name\":\"recipient\",\"type\":\"address\"},{\"internalType\":\"uint96\",\"name\":\"amount\",\"type\":\"uint96\"},{\"internalType\":\"uint64\",\"name\":\"id\",\"type\":\"uint64\"}],\"indexed\":false,\"internalType\":\"structTaikoData.EthDeposit\",\"name\":\"deposit\",\"type\":\"tuple\"}],\"name\":\"EthDeposited\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"internalType\":\"uint8\",\"name\":\"version\",\"type\":\"uint8\"}],\"name\":\"Initialized\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"internalType\":\"address\",\"name\":\"previousOwner\",\"type\":\"address\"},{\"indexed\":true,\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"OwnershipTransferred\",\"type\":\"event\"},{\"inputs\":[],\"name\":\"addressManager\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"canDepositEthToL2\",\"outputs\":[{\"internalType\":\"bool\",\"name\":\"\",\"type\":\"bool\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"recipient\",\"type\":\"address\"}],\"name\":\"depositEtherToL2\",\"outputs\":[],\"stateMutability\":\"payable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"depositTaikoToken\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"blockId\",\"type\":\"uint64\"}],\"name\":\"getBlock\",\"outputs\":[{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"metaHash\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"prover\",\"type\":\"address\"},{\"internalType\":\"uint96\",\"name\":\"proofBond\",\"type\":\"uint96\"},{\"internalType\":\"uint64\",\"name\":\"blockId\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"proposedAt\",\"type\":\"uint64\"},{\"internalType\":\"uint32\",\"name\":\"nextTransitionId\",\"type\":\"uint32\"},{\"internalType\":\"uint32\",\"name\":\"verifiedTransitionId\",\"type\":\"uint32\"},{\"internalType\":\"bytes32[7]\",\"name\":\"__reserved\",\"type\":\"bytes32[7]\"}],\"internalType\":\"structTaikoData.Block\",\"name\":\"blk\",\"type\":\"tuple\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"getConfig\",\"outputs\":[{\"components\":[{\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"internalType\":\"bool\",\"name\":\"relaySignalRoot\",\"type\":\"bool\"},{\"internalType\":\"uint64\",\"name\":\"blockMaxProposals\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"blockRingBufferSize\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"blockMaxVerificationsPerTx\",\"type\":\"uint64\"},{\"internalType\":\"uint32\",\"name\":\"blockMaxGasLimit\",\"type\":\"uint32\"},{\"internalType\":\"uint32\",\"name\":\"blockFeeBaseGas\",\"type\":\"uint32\"},{\"internalType\":\"uint24\",\"name\":\"blockMaxTxListBytes\",\"type\":\"uint24\"},{\"internalType\":\"uint256\",\"name\":\"blockTxListExpiry\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"proposerRewardPerSecond\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"proposerRewardMax\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"proofRegularCooldown\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"proofOracleCooldown\",\"type\":\"uint256\"},{\"internalType\":\"uint16\",\"name\":\"proofWindow\",\"type\":\"uint16\"},{\"internalType\":\"uint96\",\"name\":\"proofBond\",\"type\":\"uint96\"},{\"internalType\":\"bool\",\"name\":\"skipProverAssignmentVerificaiton\",\"type\":\"bool\"},{\"internalType\":\"uint256\",\"name\":\"ethDepositRingBufferSize\",\"type\":\"uint256\"},{\"internalType\":\"uint64\",\"name\":\"ethDepositMinCountPerBlock\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"ethDepositMaxCountPerBlock\",\"type\":\"uint64\"},{\"internalType\":\"uint96\",\"name\":\"ethDepositMinAmount\",\"type\":\"uint96\"},{\"internalType\":\"uint96\",\"name\":\"ethDepositMaxAmount\",\"type\":\"uint96\"},{\"internalType\":\"uint256\",\"name\":\"ethDepositGas\",\"type\":\"uint256\"},{\"internalType\":\"uint256\",\"name\":\"ethDepositMaxFee\",\"type\":\"uint256\"}],\"internalType\":\"structTaikoData.Config\",\"name\":\"\",\"type\":\"tuple\"}],\"stateMutability\":\"pure\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"blockId\",\"type\":\"uint64\"}],\"name\":\"getCrossChainBlockHash\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"blockId\",\"type\":\"uint64\"}],\"name\":\"getCrossChainSignalRoot\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"getStateVariables\",\"outputs\":[{\"components\":[{\"internalType\":\"uint64\",\"name\":\"genesisHeight\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"genesisTimestamp\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"numBlocks\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"lastVerifiedBlockId\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"nextEthDepositToProcess\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"numEthDeposits\",\"type\":\"uint64\"}],\"internalType\":\"structTaikoData.StateVariables\",\"name\":\"\",\"type\":\"tuple\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"addr\",\"type\":\"address\"}],\"name\":\"getTaikoTokenBalance\",\"outputs\":[{\"internalType\":\"uint256\",\"name\":\"\",\"type\":\"uint256\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"blockId\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"parentHash\",\"type\":\"bytes32\"}],\"name\":\"getTransition\",\"outputs\":[{\"components\":[{\"internalType\":\"bytes32\",\"name\":\"key\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"blockHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"signalRoot\",\"type\":\"bytes32\"},{\"internalType\":\"address\",\"name\":\"prover\",\"type\":\"address\"},{\"internalType\":\"uint64\",\"name\":\"provenAt\",\"type\":\"uint64\"},{\"internalType\":\"bytes32[6]\",\"name\":\"__reserved\",\"type\":\"bytes32[6]\"}],\"internalType\":\"structTaikoData.Transition\",\"name\":\"\",\"type\":\"tuple\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint16\",\"name\":\"id\",\"type\":\"uint16\"}],\"name\":\"getVerifierName\",\"outputs\":[{\"internalType\":\"bytes32\",\"name\":\"\",\"type\":\"bytes32\"}],\"stateMutability\":\"pure\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"_addressManager\",\"type\":\"address\"},{\"internalType\":\"bytes32\",\"name\":\"_genesisBlockHash\",\"type\":\"bytes32\"}],\"name\":\"init\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"owner\",\"outputs\":[{\"internalType\":\"address\",\"name\":\"\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes\",\"name\":\"input\",\"type\":\"bytes\"},{\"internalType\":\"bytes\",\"name\":\"assignment\",\"type\":\"bytes\"},{\"internalType\":\"bytes\",\"name\":\"txList\",\"type\":\"bytes\"}],\"name\":\"proposeBlock\",\"outputs\":[{\"components\":[{\"internalType\":\"uint64\",\"name\":\"id\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"timestamp\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"l1Height\",\"type\":\"uint64\"},{\"internalType\":\"bytes32\",\"name\":\"l1Hash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"mixHash\",\"type\":\"bytes32\"},{\"internalType\":\"bytes32\",\"name\":\"txListHash\",\"type\":\"bytes32\"},{\"internalType\":\"uint24\",\"name\":\"txListByteStart\",\"type\":\"uint24\"},{\"internalType\":\"uint24\",\"name\":\"txListByteEnd\",\"type\":\"uint24\"},{\"internalType\":\"uint32\",\"name\":\"gasLimit\",\"type\":\"uint32\"},{\"internalType\":\"address\",\"name\":\"proposer\",\"type\":\"address\"},{\"components\":[{\"internalType\":\"address\",\"name\":\"recipient\",\"type\":\"address\"},{\"internalType\":\"uint96\",\"name\":\"amount\",\"type\":\"uint96\"},{\"internalType\":\"uint64\",\"name\":\"id\",\"type\":\"uint64\"}],\"internalType\":\"structTaikoData.EthDeposit[]\",\"name\":\"depositsProcessed\",\"type\":\"tuple[]\"}],\"internalType\":\"structTaikoData.BlockMetadata\",\"name\":\"meta\",\"type\":\"tuple\"}],\"stateMutability\":\"payable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"blockId\",\"type\":\"uint64\"},{\"internalType\":\"bytes\",\"name\":\"input\",\"type\":\"bytes\"}],\"name\":\"proveBlock\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"renounceOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"chainId\",\"type\":\"uint256\"},{\"internalType\":\"bytes32\",\"name\":\"name\",\"type\":\"bytes32\"},{\"internalType\":\"bool\",\"name\":\"allowZeroAddress\",\"type\":\"bool\"}],\"name\":\"resolve\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"addr\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"bytes32\",\"name\":\"name\",\"type\":\"bytes32\"},{\"internalType\":\"bool\",\"name\":\"allowZeroAddress\",\"type\":\"bool\"}],\"name\":\"resolve\",\"outputs\":[{\"internalType\":\"addresspayable\",\"name\":\"addr\",\"type\":\"address\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"newAddressManager\",\"type\":\"address\"}],\"name\":\"setAddressManager\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[],\"name\":\"state\",\"outputs\":[{\"components\":[{\"internalType\":\"uint64\",\"name\":\"genesisHeight\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"genesisTimestamp\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"numEthDeposits\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"nextEthDepositToProcess\",\"type\":\"uint64\"}],\"internalType\":\"structTaikoData.SlotA\",\"name\":\"slotA\",\"type\":\"tuple\"},{\"components\":[{\"internalType\":\"uint64\",\"name\":\"numBlocks\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"nextEthDepositToProcess\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"lastVerifiedAt\",\"type\":\"uint64\"},{\"internalType\":\"uint64\",\"name\":\"lastVerifiedBlockId\",\"type\":\"uint64\"}],\"internalType\":\"structTaikoData.SlotB\",\"name\":\"slotB\",\"type\":\"tuple\"}],\"stateMutability\":\"view\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"address\",\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"transferOwnership\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint64\",\"name\":\"maxBlocks\",\"type\":\"uint64\"}],\"name\":\"verifyBlocks\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"inputs\":[{\"internalType\":\"uint256\",\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"withdrawTaikoToken\",\"outputs\":[],\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"stateMutability\":\"payable\",\"type\":\"receive\"}]",
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

// CanDepositEthToL2 is a free data retrieval call binding the contract method 0xcf151d9a.
//
// Solidity: function canDepositEthToL2(uint256 amount) view returns(bool)
func (_TaikoL1 *TaikoL1Caller) CanDepositEthToL2(opts *bind.CallOpts, amount *big.Int) (bool, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "canDepositEthToL2", amount)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// CanDepositEthToL2 is a free data retrieval call binding the contract method 0xcf151d9a.
//
// Solidity: function canDepositEthToL2(uint256 amount) view returns(bool)
func (_TaikoL1 *TaikoL1Session) CanDepositEthToL2(amount *big.Int) (bool, error) {
	return _TaikoL1.Contract.CanDepositEthToL2(&_TaikoL1.CallOpts, amount)
}

// CanDepositEthToL2 is a free data retrieval call binding the contract method 0xcf151d9a.
//
// Solidity: function canDepositEthToL2(uint256 amount) view returns(bool)
func (_TaikoL1 *TaikoL1CallerSession) CanDepositEthToL2(amount *big.Int) (bool, error) {
	return _TaikoL1.Contract.CanDepositEthToL2(&_TaikoL1.CallOpts, amount)
}

// GetBlock is a free data retrieval call binding the contract method 0x5fa15e79.
//
// Solidity: function getBlock(uint64 blockId) view returns((bytes32,address,uint96,uint64,uint64,uint32,uint32,bytes32[7]) blk)
func (_TaikoL1 *TaikoL1Caller) GetBlock(opts *bind.CallOpts, blockId uint64) (TaikoDataBlock, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getBlock", blockId)

	if err != nil {
		return *new(TaikoDataBlock), err
	}

	out0 := *abi.ConvertType(out[0], new(TaikoDataBlock)).(*TaikoDataBlock)

	return out0, err

}

// GetBlock is a free data retrieval call binding the contract method 0x5fa15e79.
//
// Solidity: function getBlock(uint64 blockId) view returns((bytes32,address,uint96,uint64,uint64,uint32,uint32,bytes32[7]) blk)
func (_TaikoL1 *TaikoL1Session) GetBlock(blockId uint64) (TaikoDataBlock, error) {
	return _TaikoL1.Contract.GetBlock(&_TaikoL1.CallOpts, blockId)
}

// GetBlock is a free data retrieval call binding the contract method 0x5fa15e79.
//
// Solidity: function getBlock(uint64 blockId) view returns((bytes32,address,uint96,uint64,uint64,uint32,uint32,bytes32[7]) blk)
func (_TaikoL1 *TaikoL1CallerSession) GetBlock(blockId uint64) (TaikoDataBlock, error) {
	return _TaikoL1.Contract.GetBlock(&_TaikoL1.CallOpts, blockId)
}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() pure returns((uint256,bool,uint64,uint64,uint64,uint32,uint32,uint24,uint256,uint256,uint256,uint256,uint256,uint16,uint96,bool,uint256,uint64,uint64,uint96,uint96,uint256,uint256))
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
// Solidity: function getConfig() pure returns((uint256,bool,uint64,uint64,uint64,uint32,uint32,uint24,uint256,uint256,uint256,uint256,uint256,uint16,uint96,bool,uint256,uint64,uint64,uint96,uint96,uint256,uint256))
func (_TaikoL1 *TaikoL1Session) GetConfig() (TaikoDataConfig, error) {
	return _TaikoL1.Contract.GetConfig(&_TaikoL1.CallOpts)
}

// GetConfig is a free data retrieval call binding the contract method 0xc3f909d4.
//
// Solidity: function getConfig() pure returns((uint256,bool,uint64,uint64,uint64,uint32,uint32,uint24,uint256,uint256,uint256,uint256,uint256,uint16,uint96,bool,uint256,uint64,uint64,uint96,uint96,uint256,uint256))
func (_TaikoL1 *TaikoL1CallerSession) GetConfig() (TaikoDataConfig, error) {
	return _TaikoL1.Contract.GetConfig(&_TaikoL1.CallOpts)
}

// GetCrossChainBlockHash is a free data retrieval call binding the contract method 0xbdd6bc36.
//
// Solidity: function getCrossChainBlockHash(uint64 blockId) view returns(bytes32)
func (_TaikoL1 *TaikoL1Caller) GetCrossChainBlockHash(opts *bind.CallOpts, blockId uint64) ([32]byte, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getCrossChainBlockHash", blockId)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetCrossChainBlockHash is a free data retrieval call binding the contract method 0xbdd6bc36.
//
// Solidity: function getCrossChainBlockHash(uint64 blockId) view returns(bytes32)
func (_TaikoL1 *TaikoL1Session) GetCrossChainBlockHash(blockId uint64) ([32]byte, error) {
	return _TaikoL1.Contract.GetCrossChainBlockHash(&_TaikoL1.CallOpts, blockId)
}

// GetCrossChainBlockHash is a free data retrieval call binding the contract method 0xbdd6bc36.
//
// Solidity: function getCrossChainBlockHash(uint64 blockId) view returns(bytes32)
func (_TaikoL1 *TaikoL1CallerSession) GetCrossChainBlockHash(blockId uint64) ([32]byte, error) {
	return _TaikoL1.Contract.GetCrossChainBlockHash(&_TaikoL1.CallOpts, blockId)
}

// GetCrossChainSignalRoot is a free data retrieval call binding the contract method 0x0599d294.
//
// Solidity: function getCrossChainSignalRoot(uint64 blockId) view returns(bytes32)
func (_TaikoL1 *TaikoL1Caller) GetCrossChainSignalRoot(opts *bind.CallOpts, blockId uint64) ([32]byte, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getCrossChainSignalRoot", blockId)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetCrossChainSignalRoot is a free data retrieval call binding the contract method 0x0599d294.
//
// Solidity: function getCrossChainSignalRoot(uint64 blockId) view returns(bytes32)
func (_TaikoL1 *TaikoL1Session) GetCrossChainSignalRoot(blockId uint64) ([32]byte, error) {
	return _TaikoL1.Contract.GetCrossChainSignalRoot(&_TaikoL1.CallOpts, blockId)
}

// GetCrossChainSignalRoot is a free data retrieval call binding the contract method 0x0599d294.
//
// Solidity: function getCrossChainSignalRoot(uint64 blockId) view returns(bytes32)
func (_TaikoL1 *TaikoL1CallerSession) GetCrossChainSignalRoot(blockId uint64) ([32]byte, error) {
	return _TaikoL1.Contract.GetCrossChainSignalRoot(&_TaikoL1.CallOpts, blockId)
}

// GetStateVariables is a free data retrieval call binding the contract method 0xdde89cf5.
//
// Solidity: function getStateVariables() view returns((uint64,uint64,uint64,uint64,uint64,uint64))
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
// Solidity: function getStateVariables() view returns((uint64,uint64,uint64,uint64,uint64,uint64))
func (_TaikoL1 *TaikoL1Session) GetStateVariables() (TaikoDataStateVariables, error) {
	return _TaikoL1.Contract.GetStateVariables(&_TaikoL1.CallOpts)
}

// GetStateVariables is a free data retrieval call binding the contract method 0xdde89cf5.
//
// Solidity: function getStateVariables() view returns((uint64,uint64,uint64,uint64,uint64,uint64))
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

// GetTransition is a free data retrieval call binding the contract method 0xfd257e29.
//
// Solidity: function getTransition(uint64 blockId, bytes32 parentHash) view returns((bytes32,bytes32,bytes32,address,uint64,bytes32[6]))
func (_TaikoL1 *TaikoL1Caller) GetTransition(opts *bind.CallOpts, blockId uint64, parentHash [32]byte) (TaikoDataTransition, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getTransition", blockId, parentHash)

	if err != nil {
		return *new(TaikoDataTransition), err
	}

	out0 := *abi.ConvertType(out[0], new(TaikoDataTransition)).(*TaikoDataTransition)

	return out0, err

}

// GetTransition is a free data retrieval call binding the contract method 0xfd257e29.
//
// Solidity: function getTransition(uint64 blockId, bytes32 parentHash) view returns((bytes32,bytes32,bytes32,address,uint64,bytes32[6]))
func (_TaikoL1 *TaikoL1Session) GetTransition(blockId uint64, parentHash [32]byte) (TaikoDataTransition, error) {
	return _TaikoL1.Contract.GetTransition(&_TaikoL1.CallOpts, blockId, parentHash)
}

// GetTransition is a free data retrieval call binding the contract method 0xfd257e29.
//
// Solidity: function getTransition(uint64 blockId, bytes32 parentHash) view returns((bytes32,bytes32,bytes32,address,uint64,bytes32[6]))
func (_TaikoL1 *TaikoL1CallerSession) GetTransition(blockId uint64, parentHash [32]byte) (TaikoDataTransition, error) {
	return _TaikoL1.Contract.GetTransition(&_TaikoL1.CallOpts, blockId, parentHash)
}

// GetVerifierName is a free data retrieval call binding the contract method 0x0372303d.
//
// Solidity: function getVerifierName(uint16 id) pure returns(bytes32)
func (_TaikoL1 *TaikoL1Caller) GetVerifierName(opts *bind.CallOpts, id uint16) ([32]byte, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "getVerifierName", id)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// GetVerifierName is a free data retrieval call binding the contract method 0x0372303d.
//
// Solidity: function getVerifierName(uint16 id) pure returns(bytes32)
func (_TaikoL1 *TaikoL1Session) GetVerifierName(id uint16) ([32]byte, error) {
	return _TaikoL1.Contract.GetVerifierName(&_TaikoL1.CallOpts, id)
}

// GetVerifierName is a free data retrieval call binding the contract method 0x0372303d.
//
// Solidity: function getVerifierName(uint16 id) pure returns(bytes32)
func (_TaikoL1 *TaikoL1CallerSession) GetVerifierName(id uint16) ([32]byte, error) {
	return _TaikoL1.Contract.GetVerifierName(&_TaikoL1.CallOpts, id)
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

// Resolve is a free data retrieval call binding the contract method 0x6c6563f6.
//
// Solidity: function resolve(uint256 chainId, bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_TaikoL1 *TaikoL1Caller) Resolve(opts *bind.CallOpts, chainId *big.Int, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "resolve", chainId, name, allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve is a free data retrieval call binding the contract method 0x6c6563f6.
//
// Solidity: function resolve(uint256 chainId, bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_TaikoL1 *TaikoL1Session) Resolve(chainId *big.Int, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _TaikoL1.Contract.Resolve(&_TaikoL1.CallOpts, chainId, name, allowZeroAddress)
}

// Resolve is a free data retrieval call binding the contract method 0x6c6563f6.
//
// Solidity: function resolve(uint256 chainId, bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_TaikoL1 *TaikoL1CallerSession) Resolve(chainId *big.Int, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _TaikoL1.Contract.Resolve(&_TaikoL1.CallOpts, chainId, name, allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_TaikoL1 *TaikoL1Caller) Resolve0(opts *bind.CallOpts, name [32]byte, allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "resolve0", name, allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_TaikoL1 *TaikoL1Session) Resolve0(name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _TaikoL1.Contract.Resolve0(&_TaikoL1.CallOpts, name, allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 name, bool allowZeroAddress) view returns(address addr)
func (_TaikoL1 *TaikoL1CallerSession) Resolve0(name [32]byte, allowZeroAddress bool) (common.Address, error) {
	return _TaikoL1.Contract.Resolve0(&_TaikoL1.CallOpts, name, allowZeroAddress)
}

// State is a free data retrieval call binding the contract method 0xc19d93fb.
//
// Solidity: function state() view returns((uint64,uint64,uint64,uint64) slotA, (uint64,uint64,uint64,uint64) slotB)
func (_TaikoL1 *TaikoL1Caller) State(opts *bind.CallOpts) (struct {
	SlotA TaikoDataSlotA
	SlotB TaikoDataSlotB
}, error) {
	var out []interface{}
	err := _TaikoL1.contract.Call(opts, &out, "state")

	outstruct := new(struct {
		SlotA TaikoDataSlotA
		SlotB TaikoDataSlotB
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.SlotA = *abi.ConvertType(out[0], new(TaikoDataSlotA)).(*TaikoDataSlotA)
	outstruct.SlotB = *abi.ConvertType(out[1], new(TaikoDataSlotB)).(*TaikoDataSlotB)

	return *outstruct, err

}

// State is a free data retrieval call binding the contract method 0xc19d93fb.
//
// Solidity: function state() view returns((uint64,uint64,uint64,uint64) slotA, (uint64,uint64,uint64,uint64) slotB)
func (_TaikoL1 *TaikoL1Session) State() (struct {
	SlotA TaikoDataSlotA
	SlotB TaikoDataSlotB
}, error) {
	return _TaikoL1.Contract.State(&_TaikoL1.CallOpts)
}

// State is a free data retrieval call binding the contract method 0xc19d93fb.
//
// Solidity: function state() view returns((uint64,uint64,uint64,uint64) slotA, (uint64,uint64,uint64,uint64) slotB)
func (_TaikoL1 *TaikoL1CallerSession) State() (struct {
	SlotA TaikoDataSlotA
	SlotB TaikoDataSlotB
}, error) {
	return _TaikoL1.Contract.State(&_TaikoL1.CallOpts)
}

// DepositEtherToL2 is a paid mutator transaction binding the contract method 0x047a289d.
//
// Solidity: function depositEtherToL2(address recipient) payable returns()
func (_TaikoL1 *TaikoL1Transactor) DepositEtherToL2(opts *bind.TransactOpts, recipient common.Address) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "depositEtherToL2", recipient)
}

// DepositEtherToL2 is a paid mutator transaction binding the contract method 0x047a289d.
//
// Solidity: function depositEtherToL2(address recipient) payable returns()
func (_TaikoL1 *TaikoL1Session) DepositEtherToL2(recipient common.Address) (*types.Transaction, error) {
	return _TaikoL1.Contract.DepositEtherToL2(&_TaikoL1.TransactOpts, recipient)
}

// DepositEtherToL2 is a paid mutator transaction binding the contract method 0x047a289d.
//
// Solidity: function depositEtherToL2(address recipient) payable returns()
func (_TaikoL1 *TaikoL1TransactorSession) DepositEtherToL2(recipient common.Address) (*types.Transaction, error) {
	return _TaikoL1.Contract.DepositEtherToL2(&_TaikoL1.TransactOpts, recipient)
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

// Init is a paid mutator transaction binding the contract method 0x2cc0b254.
//
// Solidity: function init(address _addressManager, bytes32 _genesisBlockHash) returns()
func (_TaikoL1 *TaikoL1Transactor) Init(opts *bind.TransactOpts, _addressManager common.Address, _genesisBlockHash [32]byte) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "init", _addressManager, _genesisBlockHash)
}

// Init is a paid mutator transaction binding the contract method 0x2cc0b254.
//
// Solidity: function init(address _addressManager, bytes32 _genesisBlockHash) returns()
func (_TaikoL1 *TaikoL1Session) Init(_addressManager common.Address, _genesisBlockHash [32]byte) (*types.Transaction, error) {
	return _TaikoL1.Contract.Init(&_TaikoL1.TransactOpts, _addressManager, _genesisBlockHash)
}

// Init is a paid mutator transaction binding the contract method 0x2cc0b254.
//
// Solidity: function init(address _addressManager, bytes32 _genesisBlockHash) returns()
func (_TaikoL1 *TaikoL1TransactorSession) Init(_addressManager common.Address, _genesisBlockHash [32]byte) (*types.Transaction, error) {
	return _TaikoL1.Contract.Init(&_TaikoL1.TransactOpts, _addressManager, _genesisBlockHash)
}

// ProposeBlock is a paid mutator transaction binding the contract method 0xb6d5a397.
//
// Solidity: function proposeBlock(bytes input, bytes assignment, bytes txList) payable returns((uint64,uint64,uint64,bytes32,bytes32,bytes32,uint24,uint24,uint32,address,(address,uint96,uint64)[]) meta)
func (_TaikoL1 *TaikoL1Transactor) ProposeBlock(opts *bind.TransactOpts, input []byte, assignment []byte, txList []byte) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "proposeBlock", input, assignment, txList)
}

// ProposeBlock is a paid mutator transaction binding the contract method 0xb6d5a397.
//
// Solidity: function proposeBlock(bytes input, bytes assignment, bytes txList) payable returns((uint64,uint64,uint64,bytes32,bytes32,bytes32,uint24,uint24,uint32,address,(address,uint96,uint64)[]) meta)
func (_TaikoL1 *TaikoL1Session) ProposeBlock(input []byte, assignment []byte, txList []byte) (*types.Transaction, error) {
	return _TaikoL1.Contract.ProposeBlock(&_TaikoL1.TransactOpts, input, assignment, txList)
}

// ProposeBlock is a paid mutator transaction binding the contract method 0xb6d5a397.
//
// Solidity: function proposeBlock(bytes input, bytes assignment, bytes txList) payable returns((uint64,uint64,uint64,bytes32,bytes32,bytes32,uint24,uint24,uint32,address,(address,uint96,uint64)[]) meta)
func (_TaikoL1 *TaikoL1TransactorSession) ProposeBlock(input []byte, assignment []byte, txList []byte) (*types.Transaction, error) {
	return _TaikoL1.Contract.ProposeBlock(&_TaikoL1.TransactOpts, input, assignment, txList)
}

// ProveBlock is a paid mutator transaction binding the contract method 0x10d008bd.
//
// Solidity: function proveBlock(uint64 blockId, bytes input) returns()
func (_TaikoL1 *TaikoL1Transactor) ProveBlock(opts *bind.TransactOpts, blockId uint64, input []byte) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "proveBlock", blockId, input)
}

// ProveBlock is a paid mutator transaction binding the contract method 0x10d008bd.
//
// Solidity: function proveBlock(uint64 blockId, bytes input) returns()
func (_TaikoL1 *TaikoL1Session) ProveBlock(blockId uint64, input []byte) (*types.Transaction, error) {
	return _TaikoL1.Contract.ProveBlock(&_TaikoL1.TransactOpts, blockId, input)
}

// ProveBlock is a paid mutator transaction binding the contract method 0x10d008bd.
//
// Solidity: function proveBlock(uint64 blockId, bytes input) returns()
func (_TaikoL1 *TaikoL1TransactorSession) ProveBlock(blockId uint64, input []byte) (*types.Transaction, error) {
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

// SetAddressManager is a paid mutator transaction binding the contract method 0x0652b57a.
//
// Solidity: function setAddressManager(address newAddressManager) returns()
func (_TaikoL1 *TaikoL1Transactor) SetAddressManager(opts *bind.TransactOpts, newAddressManager common.Address) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "setAddressManager", newAddressManager)
}

// SetAddressManager is a paid mutator transaction binding the contract method 0x0652b57a.
//
// Solidity: function setAddressManager(address newAddressManager) returns()
func (_TaikoL1 *TaikoL1Session) SetAddressManager(newAddressManager common.Address) (*types.Transaction, error) {
	return _TaikoL1.Contract.SetAddressManager(&_TaikoL1.TransactOpts, newAddressManager)
}

// SetAddressManager is a paid mutator transaction binding the contract method 0x0652b57a.
//
// Solidity: function setAddressManager(address newAddressManager) returns()
func (_TaikoL1 *TaikoL1TransactorSession) SetAddressManager(newAddressManager common.Address) (*types.Transaction, error) {
	return _TaikoL1.Contract.SetAddressManager(&_TaikoL1.TransactOpts, newAddressManager)
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

// VerifyBlocks is a paid mutator transaction binding the contract method 0x8778209d.
//
// Solidity: function verifyBlocks(uint64 maxBlocks) returns()
func (_TaikoL1 *TaikoL1Transactor) VerifyBlocks(opts *bind.TransactOpts, maxBlocks uint64) (*types.Transaction, error) {
	return _TaikoL1.contract.Transact(opts, "verifyBlocks", maxBlocks)
}

// VerifyBlocks is a paid mutator transaction binding the contract method 0x8778209d.
//
// Solidity: function verifyBlocks(uint64 maxBlocks) returns()
func (_TaikoL1 *TaikoL1Session) VerifyBlocks(maxBlocks uint64) (*types.Transaction, error) {
	return _TaikoL1.Contract.VerifyBlocks(&_TaikoL1.TransactOpts, maxBlocks)
}

// VerifyBlocks is a paid mutator transaction binding the contract method 0x8778209d.
//
// Solidity: function verifyBlocks(uint64 maxBlocks) returns()
func (_TaikoL1 *TaikoL1TransactorSession) VerifyBlocks(maxBlocks uint64) (*types.Transaction, error) {
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

// TaikoL1AddressManagerChangedIterator is returned from FilterAddressManagerChanged and is used to iterate over the raw logs and unpacked data for AddressManagerChanged events raised by the TaikoL1 contract.
type TaikoL1AddressManagerChangedIterator struct {
	Event *TaikoL1AddressManagerChanged // Event containing the contract specifics and raw log

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
func (it *TaikoL1AddressManagerChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1AddressManagerChanged)
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
		it.Event = new(TaikoL1AddressManagerChanged)
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
func (it *TaikoL1AddressManagerChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1AddressManagerChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1AddressManagerChanged represents a AddressManagerChanged event raised by the TaikoL1 contract.
type TaikoL1AddressManagerChanged struct {
	AddressManager common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterAddressManagerChanged is a free log retrieval operation binding the contract event 0x399ded90cb5ed8d89ef7e76ff4af65c373f06d3bf5d7eef55f4228e7b702a18b.
//
// Solidity: event AddressManagerChanged(address indexed addressManager)
func (_TaikoL1 *TaikoL1Filterer) FilterAddressManagerChanged(opts *bind.FilterOpts, addressManager []common.Address) (*TaikoL1AddressManagerChangedIterator, error) {

	var addressManagerRule []interface{}
	for _, addressManagerItem := range addressManager {
		addressManagerRule = append(addressManagerRule, addressManagerItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "AddressManagerChanged", addressManagerRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1AddressManagerChangedIterator{contract: _TaikoL1.contract, event: "AddressManagerChanged", logs: logs, sub: sub}, nil
}

// WatchAddressManagerChanged is a free log subscription operation binding the contract event 0x399ded90cb5ed8d89ef7e76ff4af65c373f06d3bf5d7eef55f4228e7b702a18b.
//
// Solidity: event AddressManagerChanged(address indexed addressManager)
func (_TaikoL1 *TaikoL1Filterer) WatchAddressManagerChanged(opts *bind.WatchOpts, sink chan<- *TaikoL1AddressManagerChanged, addressManager []common.Address) (event.Subscription, error) {

	var addressManagerRule []interface{}
	for _, addressManagerItem := range addressManager {
		addressManagerRule = append(addressManagerRule, addressManagerItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "AddressManagerChanged", addressManagerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1AddressManagerChanged)
				if err := _TaikoL1.contract.UnpackLog(event, "AddressManagerChanged", log); err != nil {
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
func (_TaikoL1 *TaikoL1Filterer) ParseAddressManagerChanged(log types.Log) (*TaikoL1AddressManagerChanged, error) {
	event := new(TaikoL1AddressManagerChanged)
	if err := _TaikoL1.contract.UnpackLog(event, "AddressManagerChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
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
	BlockId *big.Int
	Prover  common.Address
	Reward  *big.Int
	Meta    TaikoDataBlockMetadata
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterBlockProposed is a free log retrieval operation binding the contract event 0xe3713939242e9072c6fbb16f90e98d4b583d66b9fae9208ba2148aa8d6e82af6.
//
// Solidity: event BlockProposed(uint256 indexed blockId, address indexed prover, uint256 reward, (uint64,uint64,uint64,bytes32,bytes32,bytes32,uint24,uint24,uint32,address,(address,uint96,uint64)[]) meta)
func (_TaikoL1 *TaikoL1Filterer) FilterBlockProposed(opts *bind.FilterOpts, blockId []*big.Int, prover []common.Address) (*TaikoL1BlockProposedIterator, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}
	var proverRule []interface{}
	for _, proverItem := range prover {
		proverRule = append(proverRule, proverItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BlockProposed", blockIdRule, proverRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BlockProposedIterator{contract: _TaikoL1.contract, event: "BlockProposed", logs: logs, sub: sub}, nil
}

// WatchBlockProposed is a free log subscription operation binding the contract event 0xe3713939242e9072c6fbb16f90e98d4b583d66b9fae9208ba2148aa8d6e82af6.
//
// Solidity: event BlockProposed(uint256 indexed blockId, address indexed prover, uint256 reward, (uint64,uint64,uint64,bytes32,bytes32,bytes32,uint24,uint24,uint32,address,(address,uint96,uint64)[]) meta)
func (_TaikoL1 *TaikoL1Filterer) WatchBlockProposed(opts *bind.WatchOpts, sink chan<- *TaikoL1BlockProposed, blockId []*big.Int, prover []common.Address) (event.Subscription, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}
	var proverRule []interface{}
	for _, proverItem := range prover {
		proverRule = append(proverRule, proverItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BlockProposed", blockIdRule, proverRule)
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

// ParseBlockProposed is a log parse operation binding the contract event 0xe3713939242e9072c6fbb16f90e98d4b583d66b9fae9208ba2148aa8d6e82af6.
//
// Solidity: event BlockProposed(uint256 indexed blockId, address indexed prover, uint256 reward, (uint64,uint64,uint64,bytes32,bytes32,bytes32,uint24,uint24,uint32,address,(address,uint96,uint64)[]) meta)
func (_TaikoL1 *TaikoL1Filterer) ParseBlockProposed(log types.Log) (*TaikoL1BlockProposed, error) {
	event := new(TaikoL1BlockProposed)
	if err := _TaikoL1.contract.UnpackLog(event, "BlockProposed", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BlockProposed0Iterator is returned from FilterBlockProposed0 and is used to iterate over the raw logs and unpacked data for BlockProposed0 events raised by the TaikoL1 contract.
type TaikoL1BlockProposed0Iterator struct {
	Event *TaikoL1BlockProposed0 // Event containing the contract specifics and raw log

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
func (it *TaikoL1BlockProposed0Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BlockProposed0)
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
		it.Event = new(TaikoL1BlockProposed0)
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
func (it *TaikoL1BlockProposed0Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BlockProposed0Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BlockProposed0 represents a BlockProposed0 event raised by the TaikoL1 contract.
type TaikoL1BlockProposed0 struct {
	BlockId *big.Int
	Prover  common.Address
	Reward  *big.Int
	Meta    TaikoDataBlockMetadata
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterBlockProposed0 is a free log retrieval operation binding the contract event 0xe3713939242e9072c6fbb16f90e98d4b583d66b9fae9208ba2148aa8d6e82af6.
//
// Solidity: event BlockProposed(uint256 indexed blockId, address indexed prover, uint256 reward, (uint64,uint64,uint64,bytes32,bytes32,bytes32,uint24,uint24,uint32,address,(address,uint96,uint64)[]) meta)
func (_TaikoL1 *TaikoL1Filterer) FilterBlockProposed0(opts *bind.FilterOpts, blockId []*big.Int, prover []common.Address) (*TaikoL1BlockProposed0Iterator, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}
	var proverRule []interface{}
	for _, proverItem := range prover {
		proverRule = append(proverRule, proverItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BlockProposed0", blockIdRule, proverRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BlockProposed0Iterator{contract: _TaikoL1.contract, event: "BlockProposed0", logs: logs, sub: sub}, nil
}

// WatchBlockProposed0 is a free log subscription operation binding the contract event 0xe3713939242e9072c6fbb16f90e98d4b583d66b9fae9208ba2148aa8d6e82af6.
//
// Solidity: event BlockProposed(uint256 indexed blockId, address indexed prover, uint256 reward, (uint64,uint64,uint64,bytes32,bytes32,bytes32,uint24,uint24,uint32,address,(address,uint96,uint64)[]) meta)
func (_TaikoL1 *TaikoL1Filterer) WatchBlockProposed0(opts *bind.WatchOpts, sink chan<- *TaikoL1BlockProposed0, blockId []*big.Int, prover []common.Address) (event.Subscription, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}
	var proverRule []interface{}
	for _, proverItem := range prover {
		proverRule = append(proverRule, proverItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BlockProposed0", blockIdRule, proverRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BlockProposed0)
				if err := _TaikoL1.contract.UnpackLog(event, "BlockProposed0", log); err != nil {
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

// ParseBlockProposed0 is a log parse operation binding the contract event 0xe3713939242e9072c6fbb16f90e98d4b583d66b9fae9208ba2148aa8d6e82af6.
//
// Solidity: event BlockProposed(uint256 indexed blockId, address indexed prover, uint256 reward, (uint64,uint64,uint64,bytes32,bytes32,bytes32,uint24,uint24,uint32,address,(address,uint96,uint64)[]) meta)
func (_TaikoL1 *TaikoL1Filterer) ParseBlockProposed0(log types.Log) (*TaikoL1BlockProposed0, error) {
	event := new(TaikoL1BlockProposed0)
	if err := _TaikoL1.contract.UnpackLog(event, "BlockProposed0", log); err != nil {
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
	BlockId    *big.Int
	ParentHash [32]byte
	BlockHash  [32]byte
	SignalRoot [32]byte
	Prover     common.Address
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterBlockProven is a free log retrieval operation binding the contract event 0xd93fde3ea1bb11dcd7a4e66320a05fc5aa63983b6447eff660084c4b1b1b499b.
//
// Solidity: event BlockProven(uint256 indexed blockId, bytes32 parentHash, bytes32 blockHash, bytes32 signalRoot, address prover)
func (_TaikoL1 *TaikoL1Filterer) FilterBlockProven(opts *bind.FilterOpts, blockId []*big.Int) (*TaikoL1BlockProvenIterator, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BlockProven", blockIdRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BlockProvenIterator{contract: _TaikoL1.contract, event: "BlockProven", logs: logs, sub: sub}, nil
}

// WatchBlockProven is a free log subscription operation binding the contract event 0xd93fde3ea1bb11dcd7a4e66320a05fc5aa63983b6447eff660084c4b1b1b499b.
//
// Solidity: event BlockProven(uint256 indexed blockId, bytes32 parentHash, bytes32 blockHash, bytes32 signalRoot, address prover)
func (_TaikoL1 *TaikoL1Filterer) WatchBlockProven(opts *bind.WatchOpts, sink chan<- *TaikoL1BlockProven, blockId []*big.Int) (event.Subscription, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BlockProven", blockIdRule)
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
// Solidity: event BlockProven(uint256 indexed blockId, bytes32 parentHash, bytes32 blockHash, bytes32 signalRoot, address prover)
func (_TaikoL1 *TaikoL1Filterer) ParseBlockProven(log types.Log) (*TaikoL1BlockProven, error) {
	event := new(TaikoL1BlockProven)
	if err := _TaikoL1.contract.UnpackLog(event, "BlockProven", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BlockProven0Iterator is returned from FilterBlockProven0 and is used to iterate over the raw logs and unpacked data for BlockProven0 events raised by the TaikoL1 contract.
type TaikoL1BlockProven0Iterator struct {
	Event *TaikoL1BlockProven0 // Event containing the contract specifics and raw log

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
func (it *TaikoL1BlockProven0Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BlockProven0)
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
		it.Event = new(TaikoL1BlockProven0)
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
func (it *TaikoL1BlockProven0Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BlockProven0Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BlockProven0 represents a BlockProven0 event raised by the TaikoL1 contract.
type TaikoL1BlockProven0 struct {
	BlockId    *big.Int
	ParentHash [32]byte
	BlockHash  [32]byte
	SignalRoot [32]byte
	Prover     common.Address
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterBlockProven0 is a free log retrieval operation binding the contract event 0xd93fde3ea1bb11dcd7a4e66320a05fc5aa63983b6447eff660084c4b1b1b499b.
//
// Solidity: event BlockProven(uint256 indexed blockId, bytes32 parentHash, bytes32 blockHash, bytes32 signalRoot, address prover)
func (_TaikoL1 *TaikoL1Filterer) FilterBlockProven0(opts *bind.FilterOpts, blockId []*big.Int) (*TaikoL1BlockProven0Iterator, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BlockProven0", blockIdRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BlockProven0Iterator{contract: _TaikoL1.contract, event: "BlockProven0", logs: logs, sub: sub}, nil
}

// WatchBlockProven0 is a free log subscription operation binding the contract event 0xd93fde3ea1bb11dcd7a4e66320a05fc5aa63983b6447eff660084c4b1b1b499b.
//
// Solidity: event BlockProven(uint256 indexed blockId, bytes32 parentHash, bytes32 blockHash, bytes32 signalRoot, address prover)
func (_TaikoL1 *TaikoL1Filterer) WatchBlockProven0(opts *bind.WatchOpts, sink chan<- *TaikoL1BlockProven0, blockId []*big.Int) (event.Subscription, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BlockProven0", blockIdRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BlockProven0)
				if err := _TaikoL1.contract.UnpackLog(event, "BlockProven0", log); err != nil {
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

// ParseBlockProven0 is a log parse operation binding the contract event 0xd93fde3ea1bb11dcd7a4e66320a05fc5aa63983b6447eff660084c4b1b1b499b.
//
// Solidity: event BlockProven(uint256 indexed blockId, bytes32 parentHash, bytes32 blockHash, bytes32 signalRoot, address prover)
func (_TaikoL1 *TaikoL1Filterer) ParseBlockProven0(log types.Log) (*TaikoL1BlockProven0, error) {
	event := new(TaikoL1BlockProven0)
	if err := _TaikoL1.contract.UnpackLog(event, "BlockProven0", log); err != nil {
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
	BlockId   *big.Int
	Prover    common.Address
	BlockHash [32]byte
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterBlockVerified is a free log retrieval operation binding the contract event 0xb2fa36cea736414fca28c5aca50d94c59d740984c4c878c3dd8ba26791309b1a.
//
// Solidity: event BlockVerified(uint256 indexed blockId, address indexed prover, bytes32 blockHash)
func (_TaikoL1 *TaikoL1Filterer) FilterBlockVerified(opts *bind.FilterOpts, blockId []*big.Int, prover []common.Address) (*TaikoL1BlockVerifiedIterator, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}
	var proverRule []interface{}
	for _, proverItem := range prover {
		proverRule = append(proverRule, proverItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BlockVerified", blockIdRule, proverRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BlockVerifiedIterator{contract: _TaikoL1.contract, event: "BlockVerified", logs: logs, sub: sub}, nil
}

// WatchBlockVerified is a free log subscription operation binding the contract event 0xb2fa36cea736414fca28c5aca50d94c59d740984c4c878c3dd8ba26791309b1a.
//
// Solidity: event BlockVerified(uint256 indexed blockId, address indexed prover, bytes32 blockHash)
func (_TaikoL1 *TaikoL1Filterer) WatchBlockVerified(opts *bind.WatchOpts, sink chan<- *TaikoL1BlockVerified, blockId []*big.Int, prover []common.Address) (event.Subscription, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}
	var proverRule []interface{}
	for _, proverItem := range prover {
		proverRule = append(proverRule, proverItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BlockVerified", blockIdRule, proverRule)
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

// ParseBlockVerified is a log parse operation binding the contract event 0xb2fa36cea736414fca28c5aca50d94c59d740984c4c878c3dd8ba26791309b1a.
//
// Solidity: event BlockVerified(uint256 indexed blockId, address indexed prover, bytes32 blockHash)
func (_TaikoL1 *TaikoL1Filterer) ParseBlockVerified(log types.Log) (*TaikoL1BlockVerified, error) {
	event := new(TaikoL1BlockVerified)
	if err := _TaikoL1.contract.UnpackLog(event, "BlockVerified", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BlockVerified0Iterator is returned from FilterBlockVerified0 and is used to iterate over the raw logs and unpacked data for BlockVerified0 events raised by the TaikoL1 contract.
type TaikoL1BlockVerified0Iterator struct {
	Event *TaikoL1BlockVerified0 // Event containing the contract specifics and raw log

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
func (it *TaikoL1BlockVerified0Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BlockVerified0)
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
		it.Event = new(TaikoL1BlockVerified0)
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
func (it *TaikoL1BlockVerified0Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BlockVerified0Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BlockVerified0 represents a BlockVerified0 event raised by the TaikoL1 contract.
type TaikoL1BlockVerified0 struct {
	BlockId   *big.Int
	Prover    common.Address
	BlockHash [32]byte
	Raw       types.Log // Blockchain specific contextual infos
}

// FilterBlockVerified0 is a free log retrieval operation binding the contract event 0xb2fa36cea736414fca28c5aca50d94c59d740984c4c878c3dd8ba26791309b1a.
//
// Solidity: event BlockVerified(uint256 indexed blockId, address indexed prover, bytes32 blockHash)
func (_TaikoL1 *TaikoL1Filterer) FilterBlockVerified0(opts *bind.FilterOpts, blockId []*big.Int, prover []common.Address) (*TaikoL1BlockVerified0Iterator, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}
	var proverRule []interface{}
	for _, proverItem := range prover {
		proverRule = append(proverRule, proverItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BlockVerified0", blockIdRule, proverRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BlockVerified0Iterator{contract: _TaikoL1.contract, event: "BlockVerified0", logs: logs, sub: sub}, nil
}

// WatchBlockVerified0 is a free log subscription operation binding the contract event 0xb2fa36cea736414fca28c5aca50d94c59d740984c4c878c3dd8ba26791309b1a.
//
// Solidity: event BlockVerified(uint256 indexed blockId, address indexed prover, bytes32 blockHash)
func (_TaikoL1 *TaikoL1Filterer) WatchBlockVerified0(opts *bind.WatchOpts, sink chan<- *TaikoL1BlockVerified0, blockId []*big.Int, prover []common.Address) (event.Subscription, error) {

	var blockIdRule []interface{}
	for _, blockIdItem := range blockId {
		blockIdRule = append(blockIdRule, blockIdItem)
	}
	var proverRule []interface{}
	for _, proverItem := range prover {
		proverRule = append(proverRule, proverItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BlockVerified0", blockIdRule, proverRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BlockVerified0)
				if err := _TaikoL1.contract.UnpackLog(event, "BlockVerified0", log); err != nil {
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

// ParseBlockVerified0 is a log parse operation binding the contract event 0xb2fa36cea736414fca28c5aca50d94c59d740984c4c878c3dd8ba26791309b1a.
//
// Solidity: event BlockVerified(uint256 indexed blockId, address indexed prover, bytes32 blockHash)
func (_TaikoL1 *TaikoL1Filterer) ParseBlockVerified0(log types.Log) (*TaikoL1BlockVerified0, error) {
	event := new(TaikoL1BlockVerified0)
	if err := _TaikoL1.contract.UnpackLog(event, "BlockVerified0", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BondReceivedIterator is returned from FilterBondReceived and is used to iterate over the raw logs and unpacked data for BondReceived events raised by the TaikoL1 contract.
type TaikoL1BondReceivedIterator struct {
	Event *TaikoL1BondReceived // Event containing the contract specifics and raw log

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
func (it *TaikoL1BondReceivedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BondReceived)
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
		it.Event = new(TaikoL1BondReceived)
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
func (it *TaikoL1BondReceivedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BondReceivedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BondReceived represents a BondReceived event raised by the TaikoL1 contract.
type TaikoL1BondReceived struct {
	From    common.Address
	BlockId uint64
	Bond    *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterBondReceived is a free log retrieval operation binding the contract event 0xbb2d4a4c4a679d81940f242e401d2b2cc3383dbcb0ae798c14bd7905b1f6cae2.
//
// Solidity: event BondReceived(address indexed from, uint64 blockId, uint256 bond)
func (_TaikoL1 *TaikoL1Filterer) FilterBondReceived(opts *bind.FilterOpts, from []common.Address) (*TaikoL1BondReceivedIterator, error) {

	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BondReceived", fromRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BondReceivedIterator{contract: _TaikoL1.contract, event: "BondReceived", logs: logs, sub: sub}, nil
}

// WatchBondReceived is a free log subscription operation binding the contract event 0xbb2d4a4c4a679d81940f242e401d2b2cc3383dbcb0ae798c14bd7905b1f6cae2.
//
// Solidity: event BondReceived(address indexed from, uint64 blockId, uint256 bond)
func (_TaikoL1 *TaikoL1Filterer) WatchBondReceived(opts *bind.WatchOpts, sink chan<- *TaikoL1BondReceived, from []common.Address) (event.Subscription, error) {

	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BondReceived", fromRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BondReceived)
				if err := _TaikoL1.contract.UnpackLog(event, "BondReceived", log); err != nil {
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

// ParseBondReceived is a log parse operation binding the contract event 0xbb2d4a4c4a679d81940f242e401d2b2cc3383dbcb0ae798c14bd7905b1f6cae2.
//
// Solidity: event BondReceived(address indexed from, uint64 blockId, uint256 bond)
func (_TaikoL1 *TaikoL1Filterer) ParseBondReceived(log types.Log) (*TaikoL1BondReceived, error) {
	event := new(TaikoL1BondReceived)
	if err := _TaikoL1.contract.UnpackLog(event, "BondReceived", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BondReceived0Iterator is returned from FilterBondReceived0 and is used to iterate over the raw logs and unpacked data for BondReceived0 events raised by the TaikoL1 contract.
type TaikoL1BondReceived0Iterator struct {
	Event *TaikoL1BondReceived0 // Event containing the contract specifics and raw log

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
func (it *TaikoL1BondReceived0Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BondReceived0)
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
		it.Event = new(TaikoL1BondReceived0)
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
func (it *TaikoL1BondReceived0Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BondReceived0Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BondReceived0 represents a BondReceived0 event raised by the TaikoL1 contract.
type TaikoL1BondReceived0 struct {
	From    common.Address
	BlockId uint64
	Bond    *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterBondReceived0 is a free log retrieval operation binding the contract event 0xbb2d4a4c4a679d81940f242e401d2b2cc3383dbcb0ae798c14bd7905b1f6cae2.
//
// Solidity: event BondReceived(address indexed from, uint64 blockId, uint256 bond)
func (_TaikoL1 *TaikoL1Filterer) FilterBondReceived0(opts *bind.FilterOpts, from []common.Address) (*TaikoL1BondReceived0Iterator, error) {

	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BondReceived0", fromRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BondReceived0Iterator{contract: _TaikoL1.contract, event: "BondReceived0", logs: logs, sub: sub}, nil
}

// WatchBondReceived0 is a free log subscription operation binding the contract event 0xbb2d4a4c4a679d81940f242e401d2b2cc3383dbcb0ae798c14bd7905b1f6cae2.
//
// Solidity: event BondReceived(address indexed from, uint64 blockId, uint256 bond)
func (_TaikoL1 *TaikoL1Filterer) WatchBondReceived0(opts *bind.WatchOpts, sink chan<- *TaikoL1BondReceived0, from []common.Address) (event.Subscription, error) {

	var fromRule []interface{}
	for _, fromItem := range from {
		fromRule = append(fromRule, fromItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BondReceived0", fromRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BondReceived0)
				if err := _TaikoL1.contract.UnpackLog(event, "BondReceived0", log); err != nil {
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

// ParseBondReceived0 is a log parse operation binding the contract event 0xbb2d4a4c4a679d81940f242e401d2b2cc3383dbcb0ae798c14bd7905b1f6cae2.
//
// Solidity: event BondReceived(address indexed from, uint64 blockId, uint256 bond)
func (_TaikoL1 *TaikoL1Filterer) ParseBondReceived0(log types.Log) (*TaikoL1BondReceived0, error) {
	event := new(TaikoL1BondReceived0)
	if err := _TaikoL1.contract.UnpackLog(event, "BondReceived0", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BondReturnedIterator is returned from FilterBondReturned and is used to iterate over the raw logs and unpacked data for BondReturned events raised by the TaikoL1 contract.
type TaikoL1BondReturnedIterator struct {
	Event *TaikoL1BondReturned // Event containing the contract specifics and raw log

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
func (it *TaikoL1BondReturnedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BondReturned)
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
		it.Event = new(TaikoL1BondReturned)
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
func (it *TaikoL1BondReturnedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BondReturnedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BondReturned represents a BondReturned event raised by the TaikoL1 contract.
type TaikoL1BondReturned struct {
	To      common.Address
	BlockId uint64
	Bond    *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterBondReturned is a free log retrieval operation binding the contract event 0xb14706301de9c688dd040a2ac19fc629179149bb39b0765094ef833e7bd907b2.
//
// Solidity: event BondReturned(address indexed to, uint64 blockId, uint256 bond)
func (_TaikoL1 *TaikoL1Filterer) FilterBondReturned(opts *bind.FilterOpts, to []common.Address) (*TaikoL1BondReturnedIterator, error) {

	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BondReturned", toRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BondReturnedIterator{contract: _TaikoL1.contract, event: "BondReturned", logs: logs, sub: sub}, nil
}

// WatchBondReturned is a free log subscription operation binding the contract event 0xb14706301de9c688dd040a2ac19fc629179149bb39b0765094ef833e7bd907b2.
//
// Solidity: event BondReturned(address indexed to, uint64 blockId, uint256 bond)
func (_TaikoL1 *TaikoL1Filterer) WatchBondReturned(opts *bind.WatchOpts, sink chan<- *TaikoL1BondReturned, to []common.Address) (event.Subscription, error) {

	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BondReturned", toRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BondReturned)
				if err := _TaikoL1.contract.UnpackLog(event, "BondReturned", log); err != nil {
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

// ParseBondReturned is a log parse operation binding the contract event 0xb14706301de9c688dd040a2ac19fc629179149bb39b0765094ef833e7bd907b2.
//
// Solidity: event BondReturned(address indexed to, uint64 blockId, uint256 bond)
func (_TaikoL1 *TaikoL1Filterer) ParseBondReturned(log types.Log) (*TaikoL1BondReturned, error) {
	event := new(TaikoL1BondReturned)
	if err := _TaikoL1.contract.UnpackLog(event, "BondReturned", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BondReturned0Iterator is returned from FilterBondReturned0 and is used to iterate over the raw logs and unpacked data for BondReturned0 events raised by the TaikoL1 contract.
type TaikoL1BondReturned0Iterator struct {
	Event *TaikoL1BondReturned0 // Event containing the contract specifics and raw log

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
func (it *TaikoL1BondReturned0Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BondReturned0)
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
		it.Event = new(TaikoL1BondReturned0)
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
func (it *TaikoL1BondReturned0Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BondReturned0Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BondReturned0 represents a BondReturned0 event raised by the TaikoL1 contract.
type TaikoL1BondReturned0 struct {
	To      common.Address
	BlockId uint64
	Bond    *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterBondReturned0 is a free log retrieval operation binding the contract event 0xb14706301de9c688dd040a2ac19fc629179149bb39b0765094ef833e7bd907b2.
//
// Solidity: event BondReturned(address indexed to, uint64 blockId, uint256 bond)
func (_TaikoL1 *TaikoL1Filterer) FilterBondReturned0(opts *bind.FilterOpts, to []common.Address) (*TaikoL1BondReturned0Iterator, error) {

	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BondReturned0", toRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BondReturned0Iterator{contract: _TaikoL1.contract, event: "BondReturned0", logs: logs, sub: sub}, nil
}

// WatchBondReturned0 is a free log subscription operation binding the contract event 0xb14706301de9c688dd040a2ac19fc629179149bb39b0765094ef833e7bd907b2.
//
// Solidity: event BondReturned(address indexed to, uint64 blockId, uint256 bond)
func (_TaikoL1 *TaikoL1Filterer) WatchBondReturned0(opts *bind.WatchOpts, sink chan<- *TaikoL1BondReturned0, to []common.Address) (event.Subscription, error) {

	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BondReturned0", toRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BondReturned0)
				if err := _TaikoL1.contract.UnpackLog(event, "BondReturned0", log); err != nil {
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

// ParseBondReturned0 is a log parse operation binding the contract event 0xb14706301de9c688dd040a2ac19fc629179149bb39b0765094ef833e7bd907b2.
//
// Solidity: event BondReturned(address indexed to, uint64 blockId, uint256 bond)
func (_TaikoL1 *TaikoL1Filterer) ParseBondReturned0(log types.Log) (*TaikoL1BondReturned0, error) {
	event := new(TaikoL1BondReturned0)
	if err := _TaikoL1.contract.UnpackLog(event, "BondReturned0", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BondRewardedIterator is returned from FilterBondRewarded and is used to iterate over the raw logs and unpacked data for BondRewarded events raised by the TaikoL1 contract.
type TaikoL1BondRewardedIterator struct {
	Event *TaikoL1BondRewarded // Event containing the contract specifics and raw log

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
func (it *TaikoL1BondRewardedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BondRewarded)
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
		it.Event = new(TaikoL1BondRewarded)
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
func (it *TaikoL1BondRewardedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BondRewardedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BondRewarded represents a BondRewarded event raised by the TaikoL1 contract.
type TaikoL1BondRewarded struct {
	To      common.Address
	BlockId uint64
	Bond    *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterBondRewarded is a free log retrieval operation binding the contract event 0x428d08856cfebcae4c1b981318595cf05b757406a9c92c9bffd3ebb9a10023a6.
//
// Solidity: event BondRewarded(address indexed to, uint64 blockId, uint256 bond)
func (_TaikoL1 *TaikoL1Filterer) FilterBondRewarded(opts *bind.FilterOpts, to []common.Address) (*TaikoL1BondRewardedIterator, error) {

	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BondRewarded", toRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BondRewardedIterator{contract: _TaikoL1.contract, event: "BondRewarded", logs: logs, sub: sub}, nil
}

// WatchBondRewarded is a free log subscription operation binding the contract event 0x428d08856cfebcae4c1b981318595cf05b757406a9c92c9bffd3ebb9a10023a6.
//
// Solidity: event BondRewarded(address indexed to, uint64 blockId, uint256 bond)
func (_TaikoL1 *TaikoL1Filterer) WatchBondRewarded(opts *bind.WatchOpts, sink chan<- *TaikoL1BondRewarded, to []common.Address) (event.Subscription, error) {

	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BondRewarded", toRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BondRewarded)
				if err := _TaikoL1.contract.UnpackLog(event, "BondRewarded", log); err != nil {
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

// ParseBondRewarded is a log parse operation binding the contract event 0x428d08856cfebcae4c1b981318595cf05b757406a9c92c9bffd3ebb9a10023a6.
//
// Solidity: event BondRewarded(address indexed to, uint64 blockId, uint256 bond)
func (_TaikoL1 *TaikoL1Filterer) ParseBondRewarded(log types.Log) (*TaikoL1BondRewarded, error) {
	event := new(TaikoL1BondRewarded)
	if err := _TaikoL1.contract.UnpackLog(event, "BondRewarded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1BondRewarded0Iterator is returned from FilterBondRewarded0 and is used to iterate over the raw logs and unpacked data for BondRewarded0 events raised by the TaikoL1 contract.
type TaikoL1BondRewarded0Iterator struct {
	Event *TaikoL1BondRewarded0 // Event containing the contract specifics and raw log

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
func (it *TaikoL1BondRewarded0Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1BondRewarded0)
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
		it.Event = new(TaikoL1BondRewarded0)
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
func (it *TaikoL1BondRewarded0Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1BondRewarded0Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1BondRewarded0 represents a BondRewarded0 event raised by the TaikoL1 contract.
type TaikoL1BondRewarded0 struct {
	To      common.Address
	BlockId uint64
	Bond    *big.Int
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterBondRewarded0 is a free log retrieval operation binding the contract event 0x428d08856cfebcae4c1b981318595cf05b757406a9c92c9bffd3ebb9a10023a6.
//
// Solidity: event BondRewarded(address indexed to, uint64 blockId, uint256 bond)
func (_TaikoL1 *TaikoL1Filterer) FilterBondRewarded0(opts *bind.FilterOpts, to []common.Address) (*TaikoL1BondRewarded0Iterator, error) {

	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "BondRewarded0", toRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1BondRewarded0Iterator{contract: _TaikoL1.contract, event: "BondRewarded0", logs: logs, sub: sub}, nil
}

// WatchBondRewarded0 is a free log subscription operation binding the contract event 0x428d08856cfebcae4c1b981318595cf05b757406a9c92c9bffd3ebb9a10023a6.
//
// Solidity: event BondRewarded(address indexed to, uint64 blockId, uint256 bond)
func (_TaikoL1 *TaikoL1Filterer) WatchBondRewarded0(opts *bind.WatchOpts, sink chan<- *TaikoL1BondRewarded0, to []common.Address) (event.Subscription, error) {

	var toRule []interface{}
	for _, toItem := range to {
		toRule = append(toRule, toItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "BondRewarded0", toRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1BondRewarded0)
				if err := _TaikoL1.contract.UnpackLog(event, "BondRewarded0", log); err != nil {
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

// ParseBondRewarded0 is a log parse operation binding the contract event 0x428d08856cfebcae4c1b981318595cf05b757406a9c92c9bffd3ebb9a10023a6.
//
// Solidity: event BondRewarded(address indexed to, uint64 blockId, uint256 bond)
func (_TaikoL1 *TaikoL1Filterer) ParseBondRewarded0(log types.Log) (*TaikoL1BondRewarded0, error) {
	event := new(TaikoL1BondRewarded0)
	if err := _TaikoL1.contract.UnpackLog(event, "BondRewarded0", log); err != nil {
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
	SrcHeight  uint64
	BlockHash  [32]byte
	SignalRoot [32]byte
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterCrossChainSynced is a free log retrieval operation binding the contract event 0x004ce985b8852a486571d0545799251fd671adcf33b7854a5f0f6a6a2431a555.
//
// Solidity: event CrossChainSynced(uint64 indexed srcHeight, bytes32 blockHash, bytes32 signalRoot)
func (_TaikoL1 *TaikoL1Filterer) FilterCrossChainSynced(opts *bind.FilterOpts, srcHeight []uint64) (*TaikoL1CrossChainSyncedIterator, error) {

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

// WatchCrossChainSynced is a free log subscription operation binding the contract event 0x004ce985b8852a486571d0545799251fd671adcf33b7854a5f0f6a6a2431a555.
//
// Solidity: event CrossChainSynced(uint64 indexed srcHeight, bytes32 blockHash, bytes32 signalRoot)
func (_TaikoL1 *TaikoL1Filterer) WatchCrossChainSynced(opts *bind.WatchOpts, sink chan<- *TaikoL1CrossChainSynced, srcHeight []uint64) (event.Subscription, error) {

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

// ParseCrossChainSynced is a log parse operation binding the contract event 0x004ce985b8852a486571d0545799251fd671adcf33b7854a5f0f6a6a2431a555.
//
// Solidity: event CrossChainSynced(uint64 indexed srcHeight, bytes32 blockHash, bytes32 signalRoot)
func (_TaikoL1 *TaikoL1Filterer) ParseCrossChainSynced(log types.Log) (*TaikoL1CrossChainSynced, error) {
	event := new(TaikoL1CrossChainSynced)
	if err := _TaikoL1.contract.UnpackLog(event, "CrossChainSynced", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1CrossChainSynced0Iterator is returned from FilterCrossChainSynced0 and is used to iterate over the raw logs and unpacked data for CrossChainSynced0 events raised by the TaikoL1 contract.
type TaikoL1CrossChainSynced0Iterator struct {
	Event *TaikoL1CrossChainSynced0 // Event containing the contract specifics and raw log

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
func (it *TaikoL1CrossChainSynced0Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1CrossChainSynced0)
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
		it.Event = new(TaikoL1CrossChainSynced0)
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
func (it *TaikoL1CrossChainSynced0Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1CrossChainSynced0Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1CrossChainSynced0 represents a CrossChainSynced0 event raised by the TaikoL1 contract.
type TaikoL1CrossChainSynced0 struct {
	SrcHeight  uint64
	BlockHash  [32]byte
	SignalRoot [32]byte
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterCrossChainSynced0 is a free log retrieval operation binding the contract event 0x004ce985b8852a486571d0545799251fd671adcf33b7854a5f0f6a6a2431a555.
//
// Solidity: event CrossChainSynced(uint64 indexed srcHeight, bytes32 blockHash, bytes32 signalRoot)
func (_TaikoL1 *TaikoL1Filterer) FilterCrossChainSynced0(opts *bind.FilterOpts, srcHeight []uint64) (*TaikoL1CrossChainSynced0Iterator, error) {

	var srcHeightRule []interface{}
	for _, srcHeightItem := range srcHeight {
		srcHeightRule = append(srcHeightRule, srcHeightItem)
	}

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "CrossChainSynced0", srcHeightRule)
	if err != nil {
		return nil, err
	}
	return &TaikoL1CrossChainSynced0Iterator{contract: _TaikoL1.contract, event: "CrossChainSynced0", logs: logs, sub: sub}, nil
}

// WatchCrossChainSynced0 is a free log subscription operation binding the contract event 0x004ce985b8852a486571d0545799251fd671adcf33b7854a5f0f6a6a2431a555.
//
// Solidity: event CrossChainSynced(uint64 indexed srcHeight, bytes32 blockHash, bytes32 signalRoot)
func (_TaikoL1 *TaikoL1Filterer) WatchCrossChainSynced0(opts *bind.WatchOpts, sink chan<- *TaikoL1CrossChainSynced0, srcHeight []uint64) (event.Subscription, error) {

	var srcHeightRule []interface{}
	for _, srcHeightItem := range srcHeight {
		srcHeightRule = append(srcHeightRule, srcHeightItem)
	}

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "CrossChainSynced0", srcHeightRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1CrossChainSynced0)
				if err := _TaikoL1.contract.UnpackLog(event, "CrossChainSynced0", log); err != nil {
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

// ParseCrossChainSynced0 is a log parse operation binding the contract event 0x004ce985b8852a486571d0545799251fd671adcf33b7854a5f0f6a6a2431a555.
//
// Solidity: event CrossChainSynced(uint64 indexed srcHeight, bytes32 blockHash, bytes32 signalRoot)
func (_TaikoL1 *TaikoL1Filterer) ParseCrossChainSynced0(log types.Log) (*TaikoL1CrossChainSynced0, error) {
	event := new(TaikoL1CrossChainSynced0)
	if err := _TaikoL1.contract.UnpackLog(event, "CrossChainSynced0", log); err != nil {
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

// FilterEthDeposited is a free log retrieval operation binding the contract event 0x7120a3b075ad25974c5eed76dedb3a217c76c9c6d1f1e201caeba9b89de9a9d9.
//
// Solidity: event EthDeposited((address,uint96,uint64) deposit)
func (_TaikoL1 *TaikoL1Filterer) FilterEthDeposited(opts *bind.FilterOpts) (*TaikoL1EthDepositedIterator, error) {

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "EthDeposited")
	if err != nil {
		return nil, err
	}
	return &TaikoL1EthDepositedIterator{contract: _TaikoL1.contract, event: "EthDeposited", logs: logs, sub: sub}, nil
}

// WatchEthDeposited is a free log subscription operation binding the contract event 0x7120a3b075ad25974c5eed76dedb3a217c76c9c6d1f1e201caeba9b89de9a9d9.
//
// Solidity: event EthDeposited((address,uint96,uint64) deposit)
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

// ParseEthDeposited is a log parse operation binding the contract event 0x7120a3b075ad25974c5eed76dedb3a217c76c9c6d1f1e201caeba9b89de9a9d9.
//
// Solidity: event EthDeposited((address,uint96,uint64) deposit)
func (_TaikoL1 *TaikoL1Filterer) ParseEthDeposited(log types.Log) (*TaikoL1EthDeposited, error) {
	event := new(TaikoL1EthDeposited)
	if err := _TaikoL1.contract.UnpackLog(event, "EthDeposited", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// TaikoL1EthDeposited0Iterator is returned from FilterEthDeposited0 and is used to iterate over the raw logs and unpacked data for EthDeposited0 events raised by the TaikoL1 contract.
type TaikoL1EthDeposited0Iterator struct {
	Event *TaikoL1EthDeposited0 // Event containing the contract specifics and raw log

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
func (it *TaikoL1EthDeposited0Iterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(TaikoL1EthDeposited0)
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
		it.Event = new(TaikoL1EthDeposited0)
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
func (it *TaikoL1EthDeposited0Iterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *TaikoL1EthDeposited0Iterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// TaikoL1EthDeposited0 represents a EthDeposited0 event raised by the TaikoL1 contract.
type TaikoL1EthDeposited0 struct {
	Deposit TaikoDataEthDeposit
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterEthDeposited0 is a free log retrieval operation binding the contract event 0x7120a3b075ad25974c5eed76dedb3a217c76c9c6d1f1e201caeba9b89de9a9d9.
//
// Solidity: event EthDeposited((address,uint96,uint64) deposit)
func (_TaikoL1 *TaikoL1Filterer) FilterEthDeposited0(opts *bind.FilterOpts) (*TaikoL1EthDeposited0Iterator, error) {

	logs, sub, err := _TaikoL1.contract.FilterLogs(opts, "EthDeposited0")
	if err != nil {
		return nil, err
	}
	return &TaikoL1EthDeposited0Iterator{contract: _TaikoL1.contract, event: "EthDeposited0", logs: logs, sub: sub}, nil
}

// WatchEthDeposited0 is a free log subscription operation binding the contract event 0x7120a3b075ad25974c5eed76dedb3a217c76c9c6d1f1e201caeba9b89de9a9d9.
//
// Solidity: event EthDeposited((address,uint96,uint64) deposit)
func (_TaikoL1 *TaikoL1Filterer) WatchEthDeposited0(opts *bind.WatchOpts, sink chan<- *TaikoL1EthDeposited0) (event.Subscription, error) {

	logs, sub, err := _TaikoL1.contract.WatchLogs(opts, "EthDeposited0")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(TaikoL1EthDeposited0)
				if err := _TaikoL1.contract.UnpackLog(event, "EthDeposited0", log); err != nil {
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

// ParseEthDeposited0 is a log parse operation binding the contract event 0x7120a3b075ad25974c5eed76dedb3a217c76c9c6d1f1e201caeba9b89de9a9d9.
//
// Solidity: event EthDeposited((address,uint96,uint64) deposit)
func (_TaikoL1 *TaikoL1Filterer) ParseEthDeposited0(log types.Log) (*TaikoL1EthDeposited0, error) {
	event := new(TaikoL1EthDeposited0)
	if err := _TaikoL1.contract.UnpackLog(event, "EthDeposited0", log); err != nil {
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
