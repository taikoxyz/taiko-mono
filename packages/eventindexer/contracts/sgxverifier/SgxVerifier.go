// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package sgxverifier

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

// IVerifierContext is an auto generated low-level Go binding around an user-defined struct.
type IVerifierContext struct {
	MetaHash     [32]byte
	BlobHash     [32]byte
	Prover       common.Address
	BlockId      uint64
	IsContesting bool
	BlobUsed     bool
	MsgSender    common.Address
}

// TaikoDataTierProof is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataTierProof struct {
	Tier uint16
	Data []byte
}

// TaikoDataTransition is an auto generated low-level Go binding around an user-defined struct.
type TaikoDataTransition struct {
	ParentHash [32]byte
	BlockHash  [32]byte
	StateRoot  [32]byte
	Graffiti   [32]byte
}

// V3StructCertificationData is an auto generated low-level Go binding around an user-defined struct.
type V3StructCertificationData struct {
	CertType             uint16
	CertDataSize         uint32
	DecodedCertDataArray [3][]byte
}

// V3StructECDSAQuoteV3AuthData is an auto generated low-level Go binding around an user-defined struct.
type V3StructECDSAQuoteV3AuthData struct {
	Ecdsa256BitSignature []byte
	EcdsaAttestationKey  []byte
	PckSignedQeReport    V3StructEnclaveReport
	QeReportSignature    []byte
	QeAuthData           V3StructQEAuthData
	Certification        V3StructCertificationData
}

// V3StructEnclaveReport is an auto generated low-level Go binding around an user-defined struct.
type V3StructEnclaveReport struct {
	CpuSvn     [16]byte
	MiscSelect [4]byte
	Reserved1  [28]byte
	Attributes [16]byte
	MrEnclave  [32]byte
	Reserved2  [32]byte
	MrSigner   [32]byte
	Reserved3  []byte
	IsvProdId  uint16
	IsvSvn     uint16
	Reserved4  []byte
	ReportData []byte
}

// V3StructHeader is an auto generated low-level Go binding around an user-defined struct.
type V3StructHeader struct {
	Version            [2]byte
	AttestationKeyType [2]byte
	TeeType            [4]byte
	QeSvn              [2]byte
	PceSvn             [2]byte
	QeVendorId         [16]byte
	UserData           [20]byte
}

// V3StructParsedV3QuoteStruct is an auto generated low-level Go binding around an user-defined struct.
type V3StructParsedV3QuoteStruct struct {
	Header             V3StructHeader
	LocalEnclaveReport V3StructEnclaveReport
	V3AuthData         V3StructECDSAQuoteV3AuthData
}

// V3StructQEAuthData is an auto generated low-level Go binding around an user-defined struct.
type V3StructQEAuthData struct {
	ParsedDataSize uint16
	Data           []byte
}

// SgxVerifierMetaData contains all meta data concerning the SgxVerifier contract.
var SgxVerifierMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"function\",\"name\":\"INSTANCE_EXPIRY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"INSTANCE_VALIDITY_DELAY\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"addInstances\",\"inputs\":[{\"name\":\"_instances\",\"type\":\"address[]\",\"internalType\":\"address[]\"}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"addressManager\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"addressRegistered\",\"inputs\":[{\"name\":\"instanceAddress\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[{\"name\":\"alreadyAttested\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"deleteInstances\",\"inputs\":[{\"name\":\"_ids\",\"type\":\"uint256[]\",\"internalType\":\"uint256[]\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_addressManager\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"instances\",\"inputs\":[{\"name\":\"instanceId\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"outputs\":[{\"name\":\"addr\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"validSince\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"lastUnpausedAt\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"nextInstanceId\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"registerInstance\",\"inputs\":[{\"name\":\"_attestation\",\"type\":\"tuple\",\"internalType\":\"structV3Struct.ParsedV3QuoteStruct\",\"components\":[{\"name\":\"header\",\"type\":\"tuple\",\"internalType\":\"structV3Struct.Header\",\"components\":[{\"name\":\"version\",\"type\":\"bytes2\",\"internalType\":\"bytes2\"},{\"name\":\"attestationKeyType\",\"type\":\"bytes2\",\"internalType\":\"bytes2\"},{\"name\":\"teeType\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"},{\"name\":\"qeSvn\",\"type\":\"bytes2\",\"internalType\":\"bytes2\"},{\"name\":\"pceSvn\",\"type\":\"bytes2\",\"internalType\":\"bytes2\"},{\"name\":\"qeVendorId\",\"type\":\"bytes16\",\"internalType\":\"bytes16\"},{\"name\":\"userData\",\"type\":\"bytes20\",\"internalType\":\"bytes20\"}]},{\"name\":\"localEnclaveReport\",\"type\":\"tuple\",\"internalType\":\"structV3Struct.EnclaveReport\",\"components\":[{\"name\":\"cpuSvn\",\"type\":\"bytes16\",\"internalType\":\"bytes16\"},{\"name\":\"miscSelect\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"},{\"name\":\"reserved1\",\"type\":\"bytes28\",\"internalType\":\"bytes28\"},{\"name\":\"attributes\",\"type\":\"bytes16\",\"internalType\":\"bytes16\"},{\"name\":\"mrEnclave\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"reserved2\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"mrSigner\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"reserved3\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"isvProdId\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"isvSvn\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"reserved4\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"reportData\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]},{\"name\":\"v3AuthData\",\"type\":\"tuple\",\"internalType\":\"structV3Struct.ECDSAQuoteV3AuthData\",\"components\":[{\"name\":\"ecdsa256BitSignature\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"ecdsaAttestationKey\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"pckSignedQeReport\",\"type\":\"tuple\",\"internalType\":\"structV3Struct.EnclaveReport\",\"components\":[{\"name\":\"cpuSvn\",\"type\":\"bytes16\",\"internalType\":\"bytes16\"},{\"name\":\"miscSelect\",\"type\":\"bytes4\",\"internalType\":\"bytes4\"},{\"name\":\"reserved1\",\"type\":\"bytes28\",\"internalType\":\"bytes28\"},{\"name\":\"attributes\",\"type\":\"bytes16\",\"internalType\":\"bytes16\"},{\"name\":\"mrEnclave\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"reserved2\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"mrSigner\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"reserved3\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"isvProdId\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"isvSvn\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"reserved4\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"reportData\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]},{\"name\":\"qeReportSignature\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"qeAuthData\",\"type\":\"tuple\",\"internalType\":\"structV3Struct.QEAuthData\",\"components\":[{\"name\":\"parsedDataSize\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]},{\"name\":\"certification\",\"type\":\"tuple\",\"internalType\":\"structV3Struct.CertificationData\",\"components\":[{\"name\":\"certType\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"certDataSize\",\"type\":\"uint32\",\"internalType\":\"uint32\"},{\"name\":\"decodedCertDataArray\",\"type\":\"bytes[3]\",\"internalType\":\"bytes[3]\"}]}]}]}],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolve\",\"inputs\":[{\"name\":\"_chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_allowZeroAddress\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"addresspayable\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"resolve\",\"inputs\":[{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_allowZeroAddress\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"addresspayable\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"verifyProof\",\"inputs\":[{\"name\":\"_ctx\",\"type\":\"tuple\",\"internalType\":\"structIVerifier.Context\",\"components\":[{\"name\":\"metaHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blobHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"prover\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"blockId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"isContesting\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"blobUsed\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"msgSender\",\"type\":\"address\",\"internalType\":\"address\"}]},{\"name\":\"_tran\",\"type\":\"tuple\",\"internalType\":\"structTaikoData.Transition\",\"components\":[{\"name\":\"parentHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"blockHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"stateRoot\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"graffiti\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"name\":\"_proof\",\"type\":\"tuple\",\"internalType\":\"structTaikoData.TierProof\",\"components\":[{\"name\":\"tier\",\"type\":\"uint16\",\"internalType\":\"uint16\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}]}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"InstanceAdded\",\"inputs\":[{\"name\":\"id\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"instance\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"replaced\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"validSince\",\"type\":\"uint256\",\"indexed\":false,\"internalType\":\"uint256\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"InstanceDeleted\",\"inputs\":[{\"name\":\"id\",\"type\":\"uint256\",\"indexed\":true,\"internalType\":\"uint256\"},{\"name\":\"instance\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_INVALID_MANAGER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_UNEXPECTED_CHAINID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_ZERO_ADDR\",\"inputs\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"type\":\"error\",\"name\":\"SGX_ALREADY_ATTESTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SGX_INVALID_ATTESTATION\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SGX_INVALID_INSTANCE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SGX_INVALID_PROOF\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"SGX_RA_NOT_SUPPORTED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ZERO_ADDR_MANAGER\",\"inputs\":[]}]",
}

// SgxVerifierABI is the input ABI used to generate the binding from.
// Deprecated: Use SgxVerifierMetaData.ABI instead.
var SgxVerifierABI = SgxVerifierMetaData.ABI

// SgxVerifier is an auto generated Go binding around an Ethereum contract.
type SgxVerifier struct {
	SgxVerifierCaller     // Read-only binding to the contract
	SgxVerifierTransactor // Write-only binding to the contract
	SgxVerifierFilterer   // Log filterer for contract events
}

// SgxVerifierCaller is an auto generated read-only Go binding around an Ethereum contract.
type SgxVerifierCaller struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SgxVerifierTransactor is an auto generated write-only Go binding around an Ethereum contract.
type SgxVerifierTransactor struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SgxVerifierFilterer is an auto generated log filtering Go binding around an Ethereum contract events.
type SgxVerifierFilterer struct {
	contract *bind.BoundContract // Generic contract wrapper for the low level calls
}

// SgxVerifierSession is an auto generated Go binding around an Ethereum contract,
// with pre-set call and transact options.
type SgxVerifierSession struct {
	Contract     *SgxVerifier      // Generic contract binding to set the session for
	CallOpts     bind.CallOpts     // Call options to use throughout this session
	TransactOpts bind.TransactOpts // Transaction auth options to use throughout this session
}

// SgxVerifierCallerSession is an auto generated read-only Go binding around an Ethereum contract,
// with pre-set call options.
type SgxVerifierCallerSession struct {
	Contract *SgxVerifierCaller // Generic contract caller binding to set the session for
	CallOpts bind.CallOpts      // Call options to use throughout this session
}

// SgxVerifierTransactorSession is an auto generated write-only Go binding around an Ethereum contract,
// with pre-set transact options.
type SgxVerifierTransactorSession struct {
	Contract     *SgxVerifierTransactor // Generic contract transactor binding to set the session for
	TransactOpts bind.TransactOpts      // Transaction auth options to use throughout this session
}

// SgxVerifierRaw is an auto generated low-level Go binding around an Ethereum contract.
type SgxVerifierRaw struct {
	Contract *SgxVerifier // Generic contract binding to access the raw methods on
}

// SgxVerifierCallerRaw is an auto generated low-level read-only Go binding around an Ethereum contract.
type SgxVerifierCallerRaw struct {
	Contract *SgxVerifierCaller // Generic read-only contract binding to access the raw methods on
}

// SgxVerifierTransactorRaw is an auto generated low-level write-only Go binding around an Ethereum contract.
type SgxVerifierTransactorRaw struct {
	Contract *SgxVerifierTransactor // Generic write-only contract binding to access the raw methods on
}

// NewSgxVerifier creates a new instance of SgxVerifier, bound to a specific deployed contract.
func NewSgxVerifier(address common.Address, backend bind.ContractBackend) (*SgxVerifier, error) {
	contract, err := bindSgxVerifier(address, backend, backend, backend)
	if err != nil {
		return nil, err
	}
	return &SgxVerifier{SgxVerifierCaller: SgxVerifierCaller{contract: contract}, SgxVerifierTransactor: SgxVerifierTransactor{contract: contract}, SgxVerifierFilterer: SgxVerifierFilterer{contract: contract}}, nil
}

// NewSgxVerifierCaller creates a new read-only instance of SgxVerifier, bound to a specific deployed contract.
func NewSgxVerifierCaller(address common.Address, caller bind.ContractCaller) (*SgxVerifierCaller, error) {
	contract, err := bindSgxVerifier(address, caller, nil, nil)
	if err != nil {
		return nil, err
	}
	return &SgxVerifierCaller{contract: contract}, nil
}

// NewSgxVerifierTransactor creates a new write-only instance of SgxVerifier, bound to a specific deployed contract.
func NewSgxVerifierTransactor(address common.Address, transactor bind.ContractTransactor) (*SgxVerifierTransactor, error) {
	contract, err := bindSgxVerifier(address, nil, transactor, nil)
	if err != nil {
		return nil, err
	}
	return &SgxVerifierTransactor{contract: contract}, nil
}

// NewSgxVerifierFilterer creates a new log filterer instance of SgxVerifier, bound to a specific deployed contract.
func NewSgxVerifierFilterer(address common.Address, filterer bind.ContractFilterer) (*SgxVerifierFilterer, error) {
	contract, err := bindSgxVerifier(address, nil, nil, filterer)
	if err != nil {
		return nil, err
	}
	return &SgxVerifierFilterer{contract: contract}, nil
}

// bindSgxVerifier binds a generic wrapper to an already deployed contract.
func bindSgxVerifier(address common.Address, caller bind.ContractCaller, transactor bind.ContractTransactor, filterer bind.ContractFilterer) (*bind.BoundContract, error) {
	parsed, err := SgxVerifierMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SgxVerifier *SgxVerifierRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SgxVerifier.Contract.SgxVerifierCaller.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SgxVerifier *SgxVerifierRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SgxVerifier.Contract.SgxVerifierTransactor.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SgxVerifier *SgxVerifierRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SgxVerifier.Contract.SgxVerifierTransactor.contract.Transact(opts, method, params...)
}

// Call invokes the (constant) contract method with params as input values and
// sets the output to result. The result type might be a single field for simple
// returns, a slice of interfaces for anonymous returns and a struct for named
// returns.
func (_SgxVerifier *SgxVerifierCallerRaw) Call(opts *bind.CallOpts, result *[]interface{}, method string, params ...interface{}) error {
	return _SgxVerifier.Contract.contract.Call(opts, result, method, params...)
}

// Transfer initiates a plain transaction to move funds to the contract, calling
// its default method if one is available.
func (_SgxVerifier *SgxVerifierTransactorRaw) Transfer(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SgxVerifier.Contract.contract.Transfer(opts)
}

// Transact invokes the (paid) contract method with params as input values.
func (_SgxVerifier *SgxVerifierTransactorRaw) Transact(opts *bind.TransactOpts, method string, params ...interface{}) (*types.Transaction, error) {
	return _SgxVerifier.Contract.contract.Transact(opts, method, params...)
}

// INSTANCEEXPIRY is a free data retrieval call binding the contract method 0xd632cf35.
//
// Solidity: function INSTANCE_EXPIRY() view returns(uint64)
func (_SgxVerifier *SgxVerifierCaller) INSTANCEEXPIRY(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _SgxVerifier.contract.Call(opts, &out, "INSTANCE_EXPIRY")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// INSTANCEEXPIRY is a free data retrieval call binding the contract method 0xd632cf35.
//
// Solidity: function INSTANCE_EXPIRY() view returns(uint64)
func (_SgxVerifier *SgxVerifierSession) INSTANCEEXPIRY() (uint64, error) {
	return _SgxVerifier.Contract.INSTANCEEXPIRY(&_SgxVerifier.CallOpts)
}

// INSTANCEEXPIRY is a free data retrieval call binding the contract method 0xd632cf35.
//
// Solidity: function INSTANCE_EXPIRY() view returns(uint64)
func (_SgxVerifier *SgxVerifierCallerSession) INSTANCEEXPIRY() (uint64, error) {
	return _SgxVerifier.Contract.INSTANCEEXPIRY(&_SgxVerifier.CallOpts)
}

// INSTANCEVALIDITYDELAY is a free data retrieval call binding the contract method 0xb51ec328.
//
// Solidity: function INSTANCE_VALIDITY_DELAY() view returns(uint64)
func (_SgxVerifier *SgxVerifierCaller) INSTANCEVALIDITYDELAY(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _SgxVerifier.contract.Call(opts, &out, "INSTANCE_VALIDITY_DELAY")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// INSTANCEVALIDITYDELAY is a free data retrieval call binding the contract method 0xb51ec328.
//
// Solidity: function INSTANCE_VALIDITY_DELAY() view returns(uint64)
func (_SgxVerifier *SgxVerifierSession) INSTANCEVALIDITYDELAY() (uint64, error) {
	return _SgxVerifier.Contract.INSTANCEVALIDITYDELAY(&_SgxVerifier.CallOpts)
}

// INSTANCEVALIDITYDELAY is a free data retrieval call binding the contract method 0xb51ec328.
//
// Solidity: function INSTANCE_VALIDITY_DELAY() view returns(uint64)
func (_SgxVerifier *SgxVerifierCallerSession) INSTANCEVALIDITYDELAY() (uint64, error) {
	return _SgxVerifier.Contract.INSTANCEVALIDITYDELAY(&_SgxVerifier.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_SgxVerifier *SgxVerifierCaller) AddressManager(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SgxVerifier.contract.Call(opts, &out, "addressManager")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_SgxVerifier *SgxVerifierSession) AddressManager() (common.Address, error) {
	return _SgxVerifier.Contract.AddressManager(&_SgxVerifier.CallOpts)
}

// AddressManager is a free data retrieval call binding the contract method 0x3ab76e9f.
//
// Solidity: function addressManager() view returns(address)
func (_SgxVerifier *SgxVerifierCallerSession) AddressManager() (common.Address, error) {
	return _SgxVerifier.Contract.AddressManager(&_SgxVerifier.CallOpts)
}

// AddressRegistered is a free data retrieval call binding the contract method 0x9d7809b5.
//
// Solidity: function addressRegistered(address instanceAddress) view returns(bool alreadyAttested)
func (_SgxVerifier *SgxVerifierCaller) AddressRegistered(opts *bind.CallOpts, instanceAddress common.Address) (bool, error) {
	var out []interface{}
	err := _SgxVerifier.contract.Call(opts, &out, "addressRegistered", instanceAddress)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// AddressRegistered is a free data retrieval call binding the contract method 0x9d7809b5.
//
// Solidity: function addressRegistered(address instanceAddress) view returns(bool alreadyAttested)
func (_SgxVerifier *SgxVerifierSession) AddressRegistered(instanceAddress common.Address) (bool, error) {
	return _SgxVerifier.Contract.AddressRegistered(&_SgxVerifier.CallOpts, instanceAddress)
}

// AddressRegistered is a free data retrieval call binding the contract method 0x9d7809b5.
//
// Solidity: function addressRegistered(address instanceAddress) view returns(bool alreadyAttested)
func (_SgxVerifier *SgxVerifierCallerSession) AddressRegistered(instanceAddress common.Address) (bool, error) {
	return _SgxVerifier.Contract.AddressRegistered(&_SgxVerifier.CallOpts, instanceAddress)
}

// Instances is a free data retrieval call binding the contract method 0xa2f7b3a5.
//
// Solidity: function instances(uint256 instanceId) view returns(address addr, uint64 validSince)
func (_SgxVerifier *SgxVerifierCaller) Instances(opts *bind.CallOpts, instanceId *big.Int) (struct {
	Addr       common.Address
	ValidSince uint64
}, error) {
	var out []interface{}
	err := _SgxVerifier.contract.Call(opts, &out, "instances", instanceId)

	outstruct := new(struct {
		Addr       common.Address
		ValidSince uint64
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Addr = *abi.ConvertType(out[0], new(common.Address)).(*common.Address)
	outstruct.ValidSince = *abi.ConvertType(out[1], new(uint64)).(*uint64)

	return *outstruct, err

}

// Instances is a free data retrieval call binding the contract method 0xa2f7b3a5.
//
// Solidity: function instances(uint256 instanceId) view returns(address addr, uint64 validSince)
func (_SgxVerifier *SgxVerifierSession) Instances(instanceId *big.Int) (struct {
	Addr       common.Address
	ValidSince uint64
}, error) {
	return _SgxVerifier.Contract.Instances(&_SgxVerifier.CallOpts, instanceId)
}

// Instances is a free data retrieval call binding the contract method 0xa2f7b3a5.
//
// Solidity: function instances(uint256 instanceId) view returns(address addr, uint64 validSince)
func (_SgxVerifier *SgxVerifierCallerSession) Instances(instanceId *big.Int) (struct {
	Addr       common.Address
	ValidSince uint64
}, error) {
	return _SgxVerifier.Contract.Instances(&_SgxVerifier.CallOpts, instanceId)
}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_SgxVerifier *SgxVerifierCaller) LastUnpausedAt(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _SgxVerifier.contract.Call(opts, &out, "lastUnpausedAt")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_SgxVerifier *SgxVerifierSession) LastUnpausedAt() (uint64, error) {
	return _SgxVerifier.Contract.LastUnpausedAt(&_SgxVerifier.CallOpts)
}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_SgxVerifier *SgxVerifierCallerSession) LastUnpausedAt() (uint64, error) {
	return _SgxVerifier.Contract.LastUnpausedAt(&_SgxVerifier.CallOpts)
}

// NextInstanceId is a free data retrieval call binding the contract method 0xee45abb0.
//
// Solidity: function nextInstanceId() view returns(uint256)
func (_SgxVerifier *SgxVerifierCaller) NextInstanceId(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _SgxVerifier.contract.Call(opts, &out, "nextInstanceId")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// NextInstanceId is a free data retrieval call binding the contract method 0xee45abb0.
//
// Solidity: function nextInstanceId() view returns(uint256)
func (_SgxVerifier *SgxVerifierSession) NextInstanceId() (*big.Int, error) {
	return _SgxVerifier.Contract.NextInstanceId(&_SgxVerifier.CallOpts)
}

// NextInstanceId is a free data retrieval call binding the contract method 0xee45abb0.
//
// Solidity: function nextInstanceId() view returns(uint256)
func (_SgxVerifier *SgxVerifierCallerSession) NextInstanceId() (*big.Int, error) {
	return _SgxVerifier.Contract.NextInstanceId(&_SgxVerifier.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_SgxVerifier *SgxVerifierCaller) Owner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SgxVerifier.contract.Call(opts, &out, "owner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_SgxVerifier *SgxVerifierSession) Owner() (common.Address, error) {
	return _SgxVerifier.Contract.Owner(&_SgxVerifier.CallOpts)
}

// Owner is a free data retrieval call binding the contract method 0x8da5cb5b.
//
// Solidity: function owner() view returns(address)
func (_SgxVerifier *SgxVerifierCallerSession) Owner() (common.Address, error) {
	return _SgxVerifier.Contract.Owner(&_SgxVerifier.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_SgxVerifier *SgxVerifierCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _SgxVerifier.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_SgxVerifier *SgxVerifierSession) Paused() (bool, error) {
	return _SgxVerifier.Contract.Paused(&_SgxVerifier.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_SgxVerifier *SgxVerifierCallerSession) Paused() (bool, error) {
	return _SgxVerifier.Contract.Paused(&_SgxVerifier.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_SgxVerifier *SgxVerifierCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _SgxVerifier.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_SgxVerifier *SgxVerifierSession) PendingOwner() (common.Address, error) {
	return _SgxVerifier.Contract.PendingOwner(&_SgxVerifier.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_SgxVerifier *SgxVerifierCallerSession) PendingOwner() (common.Address, error) {
	return _SgxVerifier.Contract.PendingOwner(&_SgxVerifier.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_SgxVerifier *SgxVerifierCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _SgxVerifier.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_SgxVerifier *SgxVerifierSession) ProxiableUUID() ([32]byte, error) {
	return _SgxVerifier.Contract.ProxiableUUID(&_SgxVerifier.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_SgxVerifier *SgxVerifierCallerSession) ProxiableUUID() ([32]byte, error) {
	return _SgxVerifier.Contract.ProxiableUUID(&_SgxVerifier.CallOpts)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_SgxVerifier *SgxVerifierCaller) Resolve(opts *bind.CallOpts, _chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _SgxVerifier.contract.Call(opts, &out, "resolve", _chainId, _name, _allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_SgxVerifier *SgxVerifierSession) Resolve(_chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _SgxVerifier.Contract.Resolve(&_SgxVerifier.CallOpts, _chainId, _name, _allowZeroAddress)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_SgxVerifier *SgxVerifierCallerSession) Resolve(_chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _SgxVerifier.Contract.Resolve(&_SgxVerifier.CallOpts, _chainId, _name, _allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_SgxVerifier *SgxVerifierCaller) Resolve0(opts *bind.CallOpts, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _SgxVerifier.contract.Call(opts, &out, "resolve0", _name, _allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_SgxVerifier *SgxVerifierSession) Resolve0(_name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _SgxVerifier.Contract.Resolve0(&_SgxVerifier.CallOpts, _name, _allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_SgxVerifier *SgxVerifierCallerSession) Resolve0(_name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _SgxVerifier.Contract.Resolve0(&_SgxVerifier.CallOpts, _name, _allowZeroAddress)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_SgxVerifier *SgxVerifierTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SgxVerifier.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_SgxVerifier *SgxVerifierSession) AcceptOwnership() (*types.Transaction, error) {
	return _SgxVerifier.Contract.AcceptOwnership(&_SgxVerifier.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_SgxVerifier *SgxVerifierTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _SgxVerifier.Contract.AcceptOwnership(&_SgxVerifier.TransactOpts)
}

// AddInstances is a paid mutator transaction binding the contract method 0x16107290.
//
// Solidity: function addInstances(address[] _instances) returns(uint256[])
func (_SgxVerifier *SgxVerifierTransactor) AddInstances(opts *bind.TransactOpts, _instances []common.Address) (*types.Transaction, error) {
	return _SgxVerifier.contract.Transact(opts, "addInstances", _instances)
}

// AddInstances is a paid mutator transaction binding the contract method 0x16107290.
//
// Solidity: function addInstances(address[] _instances) returns(uint256[])
func (_SgxVerifier *SgxVerifierSession) AddInstances(_instances []common.Address) (*types.Transaction, error) {
	return _SgxVerifier.Contract.AddInstances(&_SgxVerifier.TransactOpts, _instances)
}

// AddInstances is a paid mutator transaction binding the contract method 0x16107290.
//
// Solidity: function addInstances(address[] _instances) returns(uint256[])
func (_SgxVerifier *SgxVerifierTransactorSession) AddInstances(_instances []common.Address) (*types.Transaction, error) {
	return _SgxVerifier.Contract.AddInstances(&_SgxVerifier.TransactOpts, _instances)
}

// DeleteInstances is a paid mutator transaction binding the contract method 0x4ef36a56.
//
// Solidity: function deleteInstances(uint256[] _ids) returns()
func (_SgxVerifier *SgxVerifierTransactor) DeleteInstances(opts *bind.TransactOpts, _ids []*big.Int) (*types.Transaction, error) {
	return _SgxVerifier.contract.Transact(opts, "deleteInstances", _ids)
}

// DeleteInstances is a paid mutator transaction binding the contract method 0x4ef36a56.
//
// Solidity: function deleteInstances(uint256[] _ids) returns()
func (_SgxVerifier *SgxVerifierSession) DeleteInstances(_ids []*big.Int) (*types.Transaction, error) {
	return _SgxVerifier.Contract.DeleteInstances(&_SgxVerifier.TransactOpts, _ids)
}

// DeleteInstances is a paid mutator transaction binding the contract method 0x4ef36a56.
//
// Solidity: function deleteInstances(uint256[] _ids) returns()
func (_SgxVerifier *SgxVerifierTransactorSession) DeleteInstances(_ids []*big.Int) (*types.Transaction, error) {
	return _SgxVerifier.Contract.DeleteInstances(&_SgxVerifier.TransactOpts, _ids)
}

// Init is a paid mutator transaction binding the contract method 0xf09a4016.
//
// Solidity: function init(address _owner, address _addressManager) returns()
func (_SgxVerifier *SgxVerifierTransactor) Init(opts *bind.TransactOpts, _owner common.Address, _addressManager common.Address) (*types.Transaction, error) {
	return _SgxVerifier.contract.Transact(opts, "init", _owner, _addressManager)
}

// Init is a paid mutator transaction binding the contract method 0xf09a4016.
//
// Solidity: function init(address _owner, address _addressManager) returns()
func (_SgxVerifier *SgxVerifierSession) Init(_owner common.Address, _addressManager common.Address) (*types.Transaction, error) {
	return _SgxVerifier.Contract.Init(&_SgxVerifier.TransactOpts, _owner, _addressManager)
}

// Init is a paid mutator transaction binding the contract method 0xf09a4016.
//
// Solidity: function init(address _owner, address _addressManager) returns()
func (_SgxVerifier *SgxVerifierTransactorSession) Init(_owner common.Address, _addressManager common.Address) (*types.Transaction, error) {
	return _SgxVerifier.Contract.Init(&_SgxVerifier.TransactOpts, _owner, _addressManager)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_SgxVerifier *SgxVerifierTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SgxVerifier.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_SgxVerifier *SgxVerifierSession) Pause() (*types.Transaction, error) {
	return _SgxVerifier.Contract.Pause(&_SgxVerifier.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_SgxVerifier *SgxVerifierTransactorSession) Pause() (*types.Transaction, error) {
	return _SgxVerifier.Contract.Pause(&_SgxVerifier.TransactOpts)
}

// RegisterInstance is a paid mutator transaction binding the contract method 0xa91951a2.
//
// Solidity: function registerInstance(((bytes2,bytes2,bytes4,bytes2,bytes2,bytes16,bytes20),(bytes16,bytes4,bytes28,bytes16,bytes32,bytes32,bytes32,bytes,uint16,uint16,bytes,bytes),(bytes,bytes,(bytes16,bytes4,bytes28,bytes16,bytes32,bytes32,bytes32,bytes,uint16,uint16,bytes,bytes),bytes,(uint16,bytes),(uint16,uint32,bytes[3]))) _attestation) returns(uint256)
func (_SgxVerifier *SgxVerifierTransactor) RegisterInstance(opts *bind.TransactOpts, _attestation V3StructParsedV3QuoteStruct) (*types.Transaction, error) {
	return _SgxVerifier.contract.Transact(opts, "registerInstance", _attestation)
}

// RegisterInstance is a paid mutator transaction binding the contract method 0xa91951a2.
//
// Solidity: function registerInstance(((bytes2,bytes2,bytes4,bytes2,bytes2,bytes16,bytes20),(bytes16,bytes4,bytes28,bytes16,bytes32,bytes32,bytes32,bytes,uint16,uint16,bytes,bytes),(bytes,bytes,(bytes16,bytes4,bytes28,bytes16,bytes32,bytes32,bytes32,bytes,uint16,uint16,bytes,bytes),bytes,(uint16,bytes),(uint16,uint32,bytes[3]))) _attestation) returns(uint256)
func (_SgxVerifier *SgxVerifierSession) RegisterInstance(_attestation V3StructParsedV3QuoteStruct) (*types.Transaction, error) {
	return _SgxVerifier.Contract.RegisterInstance(&_SgxVerifier.TransactOpts, _attestation)
}

// RegisterInstance is a paid mutator transaction binding the contract method 0xa91951a2.
//
// Solidity: function registerInstance(((bytes2,bytes2,bytes4,bytes2,bytes2,bytes16,bytes20),(bytes16,bytes4,bytes28,bytes16,bytes32,bytes32,bytes32,bytes,uint16,uint16,bytes,bytes),(bytes,bytes,(bytes16,bytes4,bytes28,bytes16,bytes32,bytes32,bytes32,bytes,uint16,uint16,bytes,bytes),bytes,(uint16,bytes),(uint16,uint32,bytes[3]))) _attestation) returns(uint256)
func (_SgxVerifier *SgxVerifierTransactorSession) RegisterInstance(_attestation V3StructParsedV3QuoteStruct) (*types.Transaction, error) {
	return _SgxVerifier.Contract.RegisterInstance(&_SgxVerifier.TransactOpts, _attestation)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_SgxVerifier *SgxVerifierTransactor) RenounceOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SgxVerifier.contract.Transact(opts, "renounceOwnership")
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_SgxVerifier *SgxVerifierSession) RenounceOwnership() (*types.Transaction, error) {
	return _SgxVerifier.Contract.RenounceOwnership(&_SgxVerifier.TransactOpts)
}

// RenounceOwnership is a paid mutator transaction binding the contract method 0x715018a6.
//
// Solidity: function renounceOwnership() returns()
func (_SgxVerifier *SgxVerifierTransactorSession) RenounceOwnership() (*types.Transaction, error) {
	return _SgxVerifier.Contract.RenounceOwnership(&_SgxVerifier.TransactOpts)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_SgxVerifier *SgxVerifierTransactor) TransferOwnership(opts *bind.TransactOpts, newOwner common.Address) (*types.Transaction, error) {
	return _SgxVerifier.contract.Transact(opts, "transferOwnership", newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_SgxVerifier *SgxVerifierSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _SgxVerifier.Contract.TransferOwnership(&_SgxVerifier.TransactOpts, newOwner)
}

// TransferOwnership is a paid mutator transaction binding the contract method 0xf2fde38b.
//
// Solidity: function transferOwnership(address newOwner) returns()
func (_SgxVerifier *SgxVerifierTransactorSession) TransferOwnership(newOwner common.Address) (*types.Transaction, error) {
	return _SgxVerifier.Contract.TransferOwnership(&_SgxVerifier.TransactOpts, newOwner)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_SgxVerifier *SgxVerifierTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _SgxVerifier.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_SgxVerifier *SgxVerifierSession) Unpause() (*types.Transaction, error) {
	return _SgxVerifier.Contract.Unpause(&_SgxVerifier.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_SgxVerifier *SgxVerifierTransactorSession) Unpause() (*types.Transaction, error) {
	return _SgxVerifier.Contract.Unpause(&_SgxVerifier.TransactOpts)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_SgxVerifier *SgxVerifierTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _SgxVerifier.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_SgxVerifier *SgxVerifierSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _SgxVerifier.Contract.UpgradeTo(&_SgxVerifier.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_SgxVerifier *SgxVerifierTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _SgxVerifier.Contract.UpgradeTo(&_SgxVerifier.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_SgxVerifier *SgxVerifierTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _SgxVerifier.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_SgxVerifier *SgxVerifierSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _SgxVerifier.Contract.UpgradeToAndCall(&_SgxVerifier.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_SgxVerifier *SgxVerifierTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _SgxVerifier.Contract.UpgradeToAndCall(&_SgxVerifier.TransactOpts, newImplementation, data)
}

// VerifyProof is a paid mutator transaction binding the contract method 0x21e89968.
//
// Solidity: function verifyProof((bytes32,bytes32,address,uint64,bool,bool,address) _ctx, (bytes32,bytes32,bytes32,bytes32) _tran, (uint16,bytes) _proof) returns()
func (_SgxVerifier *SgxVerifierTransactor) VerifyProof(opts *bind.TransactOpts, _ctx IVerifierContext, _tran TaikoDataTransition, _proof TaikoDataTierProof) (*types.Transaction, error) {
	return _SgxVerifier.contract.Transact(opts, "verifyProof", _ctx, _tran, _proof)
}

// VerifyProof is a paid mutator transaction binding the contract method 0x21e89968.
//
// Solidity: function verifyProof((bytes32,bytes32,address,uint64,bool,bool,address) _ctx, (bytes32,bytes32,bytes32,bytes32) _tran, (uint16,bytes) _proof) returns()
func (_SgxVerifier *SgxVerifierSession) VerifyProof(_ctx IVerifierContext, _tran TaikoDataTransition, _proof TaikoDataTierProof) (*types.Transaction, error) {
	return _SgxVerifier.Contract.VerifyProof(&_SgxVerifier.TransactOpts, _ctx, _tran, _proof)
}

// VerifyProof is a paid mutator transaction binding the contract method 0x21e89968.
//
// Solidity: function verifyProof((bytes32,bytes32,address,uint64,bool,bool,address) _ctx, (bytes32,bytes32,bytes32,bytes32) _tran, (uint16,bytes) _proof) returns()
func (_SgxVerifier *SgxVerifierTransactorSession) VerifyProof(_ctx IVerifierContext, _tran TaikoDataTransition, _proof TaikoDataTierProof) (*types.Transaction, error) {
	return _SgxVerifier.Contract.VerifyProof(&_SgxVerifier.TransactOpts, _ctx, _tran, _proof)
}

// SgxVerifierAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the SgxVerifier contract.
type SgxVerifierAdminChangedIterator struct {
	Event *SgxVerifierAdminChanged // Event containing the contract specifics and raw log

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
func (it *SgxVerifierAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SgxVerifierAdminChanged)
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
		it.Event = new(SgxVerifierAdminChanged)
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
func (it *SgxVerifierAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SgxVerifierAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SgxVerifierAdminChanged represents a AdminChanged event raised by the SgxVerifier contract.
type SgxVerifierAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_SgxVerifier *SgxVerifierFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*SgxVerifierAdminChangedIterator, error) {

	logs, sub, err := _SgxVerifier.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &SgxVerifierAdminChangedIterator{contract: _SgxVerifier.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_SgxVerifier *SgxVerifierFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *SgxVerifierAdminChanged) (event.Subscription, error) {

	logs, sub, err := _SgxVerifier.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SgxVerifierAdminChanged)
				if err := _SgxVerifier.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_SgxVerifier *SgxVerifierFilterer) ParseAdminChanged(log types.Log) (*SgxVerifierAdminChanged, error) {
	event := new(SgxVerifierAdminChanged)
	if err := _SgxVerifier.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SgxVerifierBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the SgxVerifier contract.
type SgxVerifierBeaconUpgradedIterator struct {
	Event *SgxVerifierBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *SgxVerifierBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SgxVerifierBeaconUpgraded)
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
		it.Event = new(SgxVerifierBeaconUpgraded)
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
func (it *SgxVerifierBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SgxVerifierBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SgxVerifierBeaconUpgraded represents a BeaconUpgraded event raised by the SgxVerifier contract.
type SgxVerifierBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_SgxVerifier *SgxVerifierFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*SgxVerifierBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _SgxVerifier.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &SgxVerifierBeaconUpgradedIterator{contract: _SgxVerifier.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_SgxVerifier *SgxVerifierFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *SgxVerifierBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _SgxVerifier.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SgxVerifierBeaconUpgraded)
				if err := _SgxVerifier.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_SgxVerifier *SgxVerifierFilterer) ParseBeaconUpgraded(log types.Log) (*SgxVerifierBeaconUpgraded, error) {
	event := new(SgxVerifierBeaconUpgraded)
	if err := _SgxVerifier.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SgxVerifierInitializedIterator is returned from FilterInitialized and is used to iterate over the raw logs and unpacked data for Initialized events raised by the SgxVerifier contract.
type SgxVerifierInitializedIterator struct {
	Event *SgxVerifierInitialized // Event containing the contract specifics and raw log

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
func (it *SgxVerifierInitializedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SgxVerifierInitialized)
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
		it.Event = new(SgxVerifierInitialized)
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
func (it *SgxVerifierInitializedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SgxVerifierInitializedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SgxVerifierInitialized represents a Initialized event raised by the SgxVerifier contract.
type SgxVerifierInitialized struct {
	Version uint8
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterInitialized is a free log retrieval operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_SgxVerifier *SgxVerifierFilterer) FilterInitialized(opts *bind.FilterOpts) (*SgxVerifierInitializedIterator, error) {

	logs, sub, err := _SgxVerifier.contract.FilterLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return &SgxVerifierInitializedIterator{contract: _SgxVerifier.contract, event: "Initialized", logs: logs, sub: sub}, nil
}

// WatchInitialized is a free log subscription operation binding the contract event 0x7f26b83ff96e1f2b6a682f133852f6798a09c465da95921460cefb3847402498.
//
// Solidity: event Initialized(uint8 version)
func (_SgxVerifier *SgxVerifierFilterer) WatchInitialized(opts *bind.WatchOpts, sink chan<- *SgxVerifierInitialized) (event.Subscription, error) {

	logs, sub, err := _SgxVerifier.contract.WatchLogs(opts, "Initialized")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SgxVerifierInitialized)
				if err := _SgxVerifier.contract.UnpackLog(event, "Initialized", log); err != nil {
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
func (_SgxVerifier *SgxVerifierFilterer) ParseInitialized(log types.Log) (*SgxVerifierInitialized, error) {
	event := new(SgxVerifierInitialized)
	if err := _SgxVerifier.contract.UnpackLog(event, "Initialized", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SgxVerifierInstanceAddedIterator is returned from FilterInstanceAdded and is used to iterate over the raw logs and unpacked data for InstanceAdded events raised by the SgxVerifier contract.
type SgxVerifierInstanceAddedIterator struct {
	Event *SgxVerifierInstanceAdded // Event containing the contract specifics and raw log

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
func (it *SgxVerifierInstanceAddedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SgxVerifierInstanceAdded)
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
		it.Event = new(SgxVerifierInstanceAdded)
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
func (it *SgxVerifierInstanceAddedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SgxVerifierInstanceAddedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SgxVerifierInstanceAdded represents a InstanceAdded event raised by the SgxVerifier contract.
type SgxVerifierInstanceAdded struct {
	Id         *big.Int
	Instance   common.Address
	Replaced   common.Address
	ValidSince *big.Int
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterInstanceAdded is a free log retrieval operation binding the contract event 0xbbe529d240965181270c1e2e32a80761e8807dda1ee9765e326178bd6804a9cb.
//
// Solidity: event InstanceAdded(uint256 indexed id, address indexed instance, address replaced, uint256 validSince)
func (_SgxVerifier *SgxVerifierFilterer) FilterInstanceAdded(opts *bind.FilterOpts, id []*big.Int, instance []common.Address) (*SgxVerifierInstanceAddedIterator, error) {

	var idRule []interface{}
	for _, idItem := range id {
		idRule = append(idRule, idItem)
	}
	var instanceRule []interface{}
	for _, instanceItem := range instance {
		instanceRule = append(instanceRule, instanceItem)
	}

	logs, sub, err := _SgxVerifier.contract.FilterLogs(opts, "InstanceAdded", idRule, instanceRule)
	if err != nil {
		return nil, err
	}
	return &SgxVerifierInstanceAddedIterator{contract: _SgxVerifier.contract, event: "InstanceAdded", logs: logs, sub: sub}, nil
}

// WatchInstanceAdded is a free log subscription operation binding the contract event 0xbbe529d240965181270c1e2e32a80761e8807dda1ee9765e326178bd6804a9cb.
//
// Solidity: event InstanceAdded(uint256 indexed id, address indexed instance, address replaced, uint256 validSince)
func (_SgxVerifier *SgxVerifierFilterer) WatchInstanceAdded(opts *bind.WatchOpts, sink chan<- *SgxVerifierInstanceAdded, id []*big.Int, instance []common.Address) (event.Subscription, error) {

	var idRule []interface{}
	for _, idItem := range id {
		idRule = append(idRule, idItem)
	}
	var instanceRule []interface{}
	for _, instanceItem := range instance {
		instanceRule = append(instanceRule, instanceItem)
	}

	logs, sub, err := _SgxVerifier.contract.WatchLogs(opts, "InstanceAdded", idRule, instanceRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SgxVerifierInstanceAdded)
				if err := _SgxVerifier.contract.UnpackLog(event, "InstanceAdded", log); err != nil {
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

// ParseInstanceAdded is a log parse operation binding the contract event 0xbbe529d240965181270c1e2e32a80761e8807dda1ee9765e326178bd6804a9cb.
//
// Solidity: event InstanceAdded(uint256 indexed id, address indexed instance, address replaced, uint256 validSince)
func (_SgxVerifier *SgxVerifierFilterer) ParseInstanceAdded(log types.Log) (*SgxVerifierInstanceAdded, error) {
	event := new(SgxVerifierInstanceAdded)
	if err := _SgxVerifier.contract.UnpackLog(event, "InstanceAdded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SgxVerifierInstanceDeletedIterator is returned from FilterInstanceDeleted and is used to iterate over the raw logs and unpacked data for InstanceDeleted events raised by the SgxVerifier contract.
type SgxVerifierInstanceDeletedIterator struct {
	Event *SgxVerifierInstanceDeleted // Event containing the contract specifics and raw log

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
func (it *SgxVerifierInstanceDeletedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SgxVerifierInstanceDeleted)
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
		it.Event = new(SgxVerifierInstanceDeleted)
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
func (it *SgxVerifierInstanceDeletedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SgxVerifierInstanceDeletedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SgxVerifierInstanceDeleted represents a InstanceDeleted event raised by the SgxVerifier contract.
type SgxVerifierInstanceDeleted struct {
	Id       *big.Int
	Instance common.Address
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterInstanceDeleted is a free log retrieval operation binding the contract event 0x89d0dca869ffe08b709ca9ff5adfd5ee8d9de2750d0561e15df614c7a2596d8e.
//
// Solidity: event InstanceDeleted(uint256 indexed id, address indexed instance)
func (_SgxVerifier *SgxVerifierFilterer) FilterInstanceDeleted(opts *bind.FilterOpts, id []*big.Int, instance []common.Address) (*SgxVerifierInstanceDeletedIterator, error) {

	var idRule []interface{}
	for _, idItem := range id {
		idRule = append(idRule, idItem)
	}
	var instanceRule []interface{}
	for _, instanceItem := range instance {
		instanceRule = append(instanceRule, instanceItem)
	}

	logs, sub, err := _SgxVerifier.contract.FilterLogs(opts, "InstanceDeleted", idRule, instanceRule)
	if err != nil {
		return nil, err
	}
	return &SgxVerifierInstanceDeletedIterator{contract: _SgxVerifier.contract, event: "InstanceDeleted", logs: logs, sub: sub}, nil
}

// WatchInstanceDeleted is a free log subscription operation binding the contract event 0x89d0dca869ffe08b709ca9ff5adfd5ee8d9de2750d0561e15df614c7a2596d8e.
//
// Solidity: event InstanceDeleted(uint256 indexed id, address indexed instance)
func (_SgxVerifier *SgxVerifierFilterer) WatchInstanceDeleted(opts *bind.WatchOpts, sink chan<- *SgxVerifierInstanceDeleted, id []*big.Int, instance []common.Address) (event.Subscription, error) {

	var idRule []interface{}
	for _, idItem := range id {
		idRule = append(idRule, idItem)
	}
	var instanceRule []interface{}
	for _, instanceItem := range instance {
		instanceRule = append(instanceRule, instanceItem)
	}

	logs, sub, err := _SgxVerifier.contract.WatchLogs(opts, "InstanceDeleted", idRule, instanceRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SgxVerifierInstanceDeleted)
				if err := _SgxVerifier.contract.UnpackLog(event, "InstanceDeleted", log); err != nil {
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

// ParseInstanceDeleted is a log parse operation binding the contract event 0x89d0dca869ffe08b709ca9ff5adfd5ee8d9de2750d0561e15df614c7a2596d8e.
//
// Solidity: event InstanceDeleted(uint256 indexed id, address indexed instance)
func (_SgxVerifier *SgxVerifierFilterer) ParseInstanceDeleted(log types.Log) (*SgxVerifierInstanceDeleted, error) {
	event := new(SgxVerifierInstanceDeleted)
	if err := _SgxVerifier.contract.UnpackLog(event, "InstanceDeleted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SgxVerifierOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the SgxVerifier contract.
type SgxVerifierOwnershipTransferStartedIterator struct {
	Event *SgxVerifierOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *SgxVerifierOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SgxVerifierOwnershipTransferStarted)
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
		it.Event = new(SgxVerifierOwnershipTransferStarted)
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
func (it *SgxVerifierOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SgxVerifierOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SgxVerifierOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the SgxVerifier contract.
type SgxVerifierOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_SgxVerifier *SgxVerifierFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*SgxVerifierOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SgxVerifier.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &SgxVerifierOwnershipTransferStartedIterator{contract: _SgxVerifier.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_SgxVerifier *SgxVerifierFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *SgxVerifierOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SgxVerifier.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SgxVerifierOwnershipTransferStarted)
				if err := _SgxVerifier.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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
func (_SgxVerifier *SgxVerifierFilterer) ParseOwnershipTransferStarted(log types.Log) (*SgxVerifierOwnershipTransferStarted, error) {
	event := new(SgxVerifierOwnershipTransferStarted)
	if err := _SgxVerifier.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SgxVerifierOwnershipTransferredIterator is returned from FilterOwnershipTransferred and is used to iterate over the raw logs and unpacked data for OwnershipTransferred events raised by the SgxVerifier contract.
type SgxVerifierOwnershipTransferredIterator struct {
	Event *SgxVerifierOwnershipTransferred // Event containing the contract specifics and raw log

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
func (it *SgxVerifierOwnershipTransferredIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SgxVerifierOwnershipTransferred)
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
		it.Event = new(SgxVerifierOwnershipTransferred)
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
func (it *SgxVerifierOwnershipTransferredIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SgxVerifierOwnershipTransferredIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SgxVerifierOwnershipTransferred represents a OwnershipTransferred event raised by the SgxVerifier contract.
type SgxVerifierOwnershipTransferred struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferred is a free log retrieval operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_SgxVerifier *SgxVerifierFilterer) FilterOwnershipTransferred(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*SgxVerifierOwnershipTransferredIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SgxVerifier.contract.FilterLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &SgxVerifierOwnershipTransferredIterator{contract: _SgxVerifier.contract, event: "OwnershipTransferred", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferred is a free log subscription operation binding the contract event 0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0.
//
// Solidity: event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
func (_SgxVerifier *SgxVerifierFilterer) WatchOwnershipTransferred(opts *bind.WatchOpts, sink chan<- *SgxVerifierOwnershipTransferred, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _SgxVerifier.contract.WatchLogs(opts, "OwnershipTransferred", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SgxVerifierOwnershipTransferred)
				if err := _SgxVerifier.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
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
func (_SgxVerifier *SgxVerifierFilterer) ParseOwnershipTransferred(log types.Log) (*SgxVerifierOwnershipTransferred, error) {
	event := new(SgxVerifierOwnershipTransferred)
	if err := _SgxVerifier.contract.UnpackLog(event, "OwnershipTransferred", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SgxVerifierPausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the SgxVerifier contract.
type SgxVerifierPausedIterator struct {
	Event *SgxVerifierPaused // Event containing the contract specifics and raw log

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
func (it *SgxVerifierPausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SgxVerifierPaused)
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
		it.Event = new(SgxVerifierPaused)
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
func (it *SgxVerifierPausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SgxVerifierPausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SgxVerifierPaused represents a Paused event raised by the SgxVerifier contract.
type SgxVerifierPaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_SgxVerifier *SgxVerifierFilterer) FilterPaused(opts *bind.FilterOpts) (*SgxVerifierPausedIterator, error) {

	logs, sub, err := _SgxVerifier.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &SgxVerifierPausedIterator{contract: _SgxVerifier.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_SgxVerifier *SgxVerifierFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *SgxVerifierPaused) (event.Subscription, error) {

	logs, sub, err := _SgxVerifier.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SgxVerifierPaused)
				if err := _SgxVerifier.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_SgxVerifier *SgxVerifierFilterer) ParsePaused(log types.Log) (*SgxVerifierPaused, error) {
	event := new(SgxVerifierPaused)
	if err := _SgxVerifier.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SgxVerifierUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the SgxVerifier contract.
type SgxVerifierUnpausedIterator struct {
	Event *SgxVerifierUnpaused // Event containing the contract specifics and raw log

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
func (it *SgxVerifierUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SgxVerifierUnpaused)
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
		it.Event = new(SgxVerifierUnpaused)
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
func (it *SgxVerifierUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SgxVerifierUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SgxVerifierUnpaused represents a Unpaused event raised by the SgxVerifier contract.
type SgxVerifierUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_SgxVerifier *SgxVerifierFilterer) FilterUnpaused(opts *bind.FilterOpts) (*SgxVerifierUnpausedIterator, error) {

	logs, sub, err := _SgxVerifier.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &SgxVerifierUnpausedIterator{contract: _SgxVerifier.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_SgxVerifier *SgxVerifierFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *SgxVerifierUnpaused) (event.Subscription, error) {

	logs, sub, err := _SgxVerifier.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SgxVerifierUnpaused)
				if err := _SgxVerifier.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_SgxVerifier *SgxVerifierFilterer) ParseUnpaused(log types.Log) (*SgxVerifierUnpaused, error) {
	event := new(SgxVerifierUnpaused)
	if err := _SgxVerifier.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// SgxVerifierUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the SgxVerifier contract.
type SgxVerifierUpgradedIterator struct {
	Event *SgxVerifierUpgraded // Event containing the contract specifics and raw log

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
func (it *SgxVerifierUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(SgxVerifierUpgraded)
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
		it.Event = new(SgxVerifierUpgraded)
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
func (it *SgxVerifierUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *SgxVerifierUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// SgxVerifierUpgraded represents a Upgraded event raised by the SgxVerifier contract.
type SgxVerifierUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_SgxVerifier *SgxVerifierFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*SgxVerifierUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _SgxVerifier.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &SgxVerifierUpgradedIterator{contract: _SgxVerifier.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_SgxVerifier *SgxVerifierFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *SgxVerifierUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _SgxVerifier.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(SgxVerifierUpgraded)
				if err := _SgxVerifier.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_SgxVerifier *SgxVerifierFilterer) ParseUpgraded(log types.Log) (*SgxVerifierUpgraded, error) {
	event := new(SgxVerifierUpgraded)
	if err := _SgxVerifier.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
