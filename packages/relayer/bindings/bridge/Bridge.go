// Code generated - DO NOT EDIT.
// This file is a generated binding and any manual changes will be lost.

package bridge

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

// IBridgeContext is an auto generated low-level Go binding around an user-defined struct.
type IBridgeContext struct {
	MsgHash    [32]byte
	From       common.Address
	SrcChainId uint64
}

// IBridgeMessage is an auto generated low-level Go binding around an user-defined struct.
type IBridgeMessage struct {
	Id          *big.Int
	From        common.Address
	SrcChainId  uint64
	DestChainId uint64
	SrcOwner    common.Address
	DestOwner   common.Address
	To          common.Address
	RefundTo    common.Address
	Value       *big.Int
	Fee         *big.Int
	GasLimit    *big.Int
	Data        []byte
	Memo        string
}

// BridgeMetaData contains all meta data concerning the Bridge contract.
var BridgeMetaData = &bind.MetaData{
	ABI: "[{\"type\":\"receive\",\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"acceptOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"addressManager\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"context\",\"inputs\":[],\"outputs\":[{\"name\":\"ctx_\",\"type\":\"tuple\",\"internalType\":\"structIBridge.Context\",\"components\":[{\"name\":\"msgHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"from\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"srcChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"}]}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"getInvocationDelays\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"\",\"type\":\"uint256\",\"internalType\":\"uint256\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"hashMessage\",\"inputs\":[{\"name\":\"_message\",\"type\":\"tuple\",\"internalType\":\"structIBridge.Message\",\"components\":[{\"name\":\"id\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"from\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"srcChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"destChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"srcOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"destOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"refundTo\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"fee\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"gasLimit\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"memo\",\"type\":\"string\",\"internalType\":\"string\"}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"init\",\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"_addressManager\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"isDestChainEnabled\",\"inputs\":[{\"name\":\"_chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"outputs\":[{\"name\":\"enabled_\",\"type\":\"bool\",\"internalType\":\"bool\"},{\"name\":\"destBridge_\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isMessageFailed\",\"inputs\":[{\"name\":\"_message\",\"type\":\"tuple\",\"internalType\":\"structIBridge.Message\",\"components\":[{\"name\":\"id\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"from\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"srcChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"destChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"srcOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"destOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"refundTo\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"fee\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"gasLimit\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"memo\",\"type\":\"string\",\"internalType\":\"string\"}]},{\"name\":\"_proof\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isMessageReceived\",\"inputs\":[{\"name\":\"_message\",\"type\":\"tuple\",\"internalType\":\"structIBridge.Message\",\"components\":[{\"name\":\"id\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"from\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"srcChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"destChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"srcOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"destOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"refundTo\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"fee\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"gasLimit\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"memo\",\"type\":\"string\",\"internalType\":\"string\"}]},{\"name\":\"_proof\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"isMessageSent\",\"inputs\":[{\"name\":\"_message\",\"type\":\"tuple\",\"internalType\":\"structIBridge.Message\",\"components\":[{\"name\":\"id\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"from\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"srcChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"destChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"srcOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"destOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"refundTo\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"fee\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"gasLimit\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"memo\",\"type\":\"string\",\"internalType\":\"string\"}]}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"lastUnpausedAt\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint64\",\"internalType\":\"uint64\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"messageStatus\",\"inputs\":[{\"name\":\"msgHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"status\",\"type\":\"uint8\",\"internalType\":\"enumIBridge.Status\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"nextMessageId\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"uint128\",\"internalType\":\"uint128\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"owner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"paused\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"pendingOwner\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"processMessage\",\"inputs\":[{\"name\":\"_message\",\"type\":\"tuple\",\"internalType\":\"structIBridge.Message\",\"components\":[{\"name\":\"id\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"from\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"srcChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"destChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"srcOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"destOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"refundTo\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"fee\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"gasLimit\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"memo\",\"type\":\"string\",\"internalType\":\"string\"}]},{\"name\":\"_proof\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proofReceipt\",\"inputs\":[{\"name\":\"msgHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"receivedAt\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"preferredExecutor\",\"type\":\"address\",\"internalType\":\"address\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"proveMessageFailed\",\"inputs\":[{\"name\":\"_message\",\"type\":\"tuple\",\"internalType\":\"structIBridge.Message\",\"components\":[{\"name\":\"id\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"from\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"srcChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"destChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"srcOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"destOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"refundTo\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"fee\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"gasLimit\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"memo\",\"type\":\"string\",\"internalType\":\"string\"}]},{\"name\":\"_proof\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proveMessageReceived\",\"inputs\":[{\"name\":\"_message\",\"type\":\"tuple\",\"internalType\":\"structIBridge.Message\",\"components\":[{\"name\":\"id\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"from\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"srcChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"destChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"srcOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"destOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"refundTo\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"fee\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"gasLimit\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"memo\",\"type\":\"string\",\"internalType\":\"string\"}]},{\"name\":\"_proof\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"proxiableUUID\",\"inputs\":[],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"recallMessage\",\"inputs\":[{\"name\":\"_message\",\"type\":\"tuple\",\"internalType\":\"structIBridge.Message\",\"components\":[{\"name\":\"id\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"from\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"srcChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"destChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"srcOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"destOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"refundTo\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"fee\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"gasLimit\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"memo\",\"type\":\"string\",\"internalType\":\"string\"}]},{\"name\":\"_proof\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"renounceOwnership\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"resolve\",\"inputs\":[{\"name\":\"_chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_allowZeroAddress\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"addresspayable\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"resolve\",\"inputs\":[{\"name\":\"_name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"_allowZeroAddress\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[{\"name\":\"\",\"type\":\"address\",\"internalType\":\"addresspayable\"}],\"stateMutability\":\"view\"},{\"type\":\"function\",\"name\":\"retryMessage\",\"inputs\":[{\"name\":\"_message\",\"type\":\"tuple\",\"internalType\":\"structIBridge.Message\",\"components\":[{\"name\":\"id\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"from\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"srcChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"destChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"srcOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"destOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"refundTo\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"fee\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"gasLimit\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"memo\",\"type\":\"string\",\"internalType\":\"string\"}]},{\"name\":\"_isLastAttempt\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"sendMessage\",\"inputs\":[{\"name\":\"_message\",\"type\":\"tuple\",\"internalType\":\"structIBridge.Message\",\"components\":[{\"name\":\"id\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"from\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"srcChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"destChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"srcOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"destOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"refundTo\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"fee\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"gasLimit\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"memo\",\"type\":\"string\",\"internalType\":\"string\"}]}],\"outputs\":[{\"name\":\"msgHash_\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"},{\"name\":\"message_\",\"type\":\"tuple\",\"internalType\":\"structIBridge.Message\",\"components\":[{\"name\":\"id\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"from\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"srcChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"destChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"srcOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"destOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"refundTo\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"fee\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"gasLimit\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"memo\",\"type\":\"string\",\"internalType\":\"string\"}]}],\"stateMutability\":\"payable\"},{\"type\":\"function\",\"name\":\"signalForFailedMessage\",\"inputs\":[{\"name\":\"_msgHash\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}],\"stateMutability\":\"pure\"},{\"type\":\"function\",\"name\":\"suspendMessages\",\"inputs\":[{\"name\":\"_msgHashes\",\"type\":\"bytes32[]\",\"internalType\":\"bytes32[]\"},{\"name\":\"_suspend\",\"type\":\"bool\",\"internalType\":\"bool\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"transferOwnership\",\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"unpause\",\"inputs\":[],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeTo\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"}],\"outputs\":[],\"stateMutability\":\"nonpayable\"},{\"type\":\"function\",\"name\":\"upgradeToAndCall\",\"inputs\":[{\"name\":\"newImplementation\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"}],\"outputs\":[],\"stateMutability\":\"payable\"},{\"type\":\"event\",\"name\":\"AddressBanned\",\"inputs\":[{\"name\":\"addr\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"banned\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"AdminChanged\",\"inputs\":[{\"name\":\"previousAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"},{\"name\":\"newAdmin\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"BeaconUpgraded\",\"inputs\":[{\"name\":\"beacon\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Initialized\",\"inputs\":[{\"name\":\"version\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"uint8\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"MessageExecuted\",\"inputs\":[{\"name\":\"msgHash\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"MessageRecalled\",\"inputs\":[{\"name\":\"msgHash\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"MessageReceived\",\"inputs\":[{\"name\":\"msgHash\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"message\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structIBridge.Message\",\"components\":[{\"name\":\"id\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"from\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"srcChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"destChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"srcOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"destOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"refundTo\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"fee\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"gasLimit\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"memo\",\"type\":\"string\",\"internalType\":\"string\"}]},{\"name\":\"isRecall\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"MessageRetried\",\"inputs\":[{\"name\":\"msgHash\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"MessageSent\",\"inputs\":[{\"name\":\"msgHash\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"message\",\"type\":\"tuple\",\"indexed\":false,\"internalType\":\"structIBridge.Message\",\"components\":[{\"name\":\"id\",\"type\":\"uint128\",\"internalType\":\"uint128\"},{\"name\":\"from\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"srcChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"destChainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"srcOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"destOwner\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"to\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"refundTo\",\"type\":\"address\",\"internalType\":\"address\"},{\"name\":\"value\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"fee\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"gasLimit\",\"type\":\"uint256\",\"internalType\":\"uint256\"},{\"name\":\"data\",\"type\":\"bytes\",\"internalType\":\"bytes\"},{\"name\":\"memo\",\"type\":\"string\",\"internalType\":\"string\"}]}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"MessageStatusChanged\",\"inputs\":[{\"name\":\"msgHash\",\"type\":\"bytes32\",\"indexed\":true,\"internalType\":\"bytes32\"},{\"name\":\"status\",\"type\":\"uint8\",\"indexed\":false,\"internalType\":\"enumIBridge.Status\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"MessageSuspended\",\"inputs\":[{\"name\":\"msgHash\",\"type\":\"bytes32\",\"indexed\":false,\"internalType\":\"bytes32\"},{\"name\":\"suspended\",\"type\":\"bool\",\"indexed\":false,\"internalType\":\"bool\"},{\"name\":\"receivedAt\",\"type\":\"uint64\",\"indexed\":false,\"internalType\":\"uint64\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferStarted\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"OwnershipTransferred\",\"inputs\":[{\"name\":\"previousOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"},{\"name\":\"newOwner\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Paused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Unpaused\",\"inputs\":[{\"name\":\"account\",\"type\":\"address\",\"indexed\":false,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"event\",\"name\":\"Upgraded\",\"inputs\":[{\"name\":\"implementation\",\"type\":\"address\",\"indexed\":true,\"internalType\":\"address\"}],\"anonymous\":false},{\"type\":\"error\",\"name\":\"B_INVALID_CHAINID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"B_INVALID_CONTEXT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"B_INVALID_GAS_LIMIT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"B_INVALID_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"B_INVALID_USER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"B_INVALID_VALUE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"B_INVOCATION_TOO_EARLY\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"B_MESSAGE_NOT_PROVEN\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"B_MESSAGE_NOT_SENT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"B_MESSAGE_NOT_SUSPENDED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"B_MESSAGE_SUSPENDED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"B_NON_RETRIABLE\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"B_NOT_ENOUGH_GASLEFT\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"B_NOT_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"B_NOT_RECEIVED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"B_PERMISSION_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"B_STATUS_MISMATCH\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"ETH_TRANSFER_FAILED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"INVALID_PAUSE_STATUS\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"REENTRANT_CALL\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_DENIED\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_INVALID_MANAGER\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_UNEXPECTED_CHAINID\",\"inputs\":[]},{\"type\":\"error\",\"name\":\"RESOLVER_ZERO_ADDR\",\"inputs\":[{\"name\":\"chainId\",\"type\":\"uint64\",\"internalType\":\"uint64\"},{\"name\":\"name\",\"type\":\"bytes32\",\"internalType\":\"bytes32\"}]},{\"type\":\"error\",\"name\":\"ZERO_ADDR_MANAGER\",\"inputs\":[]}]",
}

// BridgeABI is the input ABI used to generate the binding from.
// Deprecated: Use BridgeMetaData.ABI instead.
var BridgeABI = BridgeMetaData.ABI

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
	parsed, err := BridgeMetaData.GetAbi()
	if err != nil {
		return nil, err
	}
	return bind.NewBoundContract(address, *parsed, caller, transactor, filterer), nil
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
// Solidity: function context() view returns((bytes32,address,uint64) ctx_)
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
// Solidity: function context() view returns((bytes32,address,uint64) ctx_)
func (_Bridge *BridgeSession) Context() (IBridgeContext, error) {
	return _Bridge.Contract.Context(&_Bridge.CallOpts)
}

// Context is a free data retrieval call binding the contract method 0xd0496d6a.
//
// Solidity: function context() view returns((bytes32,address,uint64) ctx_)
func (_Bridge *BridgeCallerSession) Context() (IBridgeContext, error) {
	return _Bridge.Contract.Context(&_Bridge.CallOpts)
}

// GetInvocationDelays is a free data retrieval call binding the contract method 0x7844845b.
//
// Solidity: function getInvocationDelays() view returns(uint256, uint256)
func (_Bridge *BridgeCaller) GetInvocationDelays(opts *bind.CallOpts) (*big.Int, *big.Int, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "getInvocationDelays")

	if err != nil {
		return *new(*big.Int), *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)
	out1 := *abi.ConvertType(out[1], new(*big.Int)).(**big.Int)

	return out0, out1, err

}

// GetInvocationDelays is a free data retrieval call binding the contract method 0x7844845b.
//
// Solidity: function getInvocationDelays() view returns(uint256, uint256)
func (_Bridge *BridgeSession) GetInvocationDelays() (*big.Int, *big.Int, error) {
	return _Bridge.Contract.GetInvocationDelays(&_Bridge.CallOpts)
}

// GetInvocationDelays is a free data retrieval call binding the contract method 0x7844845b.
//
// Solidity: function getInvocationDelays() view returns(uint256, uint256)
func (_Bridge *BridgeCallerSession) GetInvocationDelays() (*big.Int, *big.Int, error) {
	return _Bridge.Contract.GetInvocationDelays(&_Bridge.CallOpts)
}

// HashMessage is a free data retrieval call binding the contract method 0x302ac399.
//
// Solidity: function hashMessage((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message) pure returns(bytes32)
func (_Bridge *BridgeCaller) HashMessage(opts *bind.CallOpts, _message IBridgeMessage) ([32]byte, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "hashMessage", _message)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// HashMessage is a free data retrieval call binding the contract method 0x302ac399.
//
// Solidity: function hashMessage((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message) pure returns(bytes32)
func (_Bridge *BridgeSession) HashMessage(_message IBridgeMessage) ([32]byte, error) {
	return _Bridge.Contract.HashMessage(&_Bridge.CallOpts, _message)
}

// HashMessage is a free data retrieval call binding the contract method 0x302ac399.
//
// Solidity: function hashMessage((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message) pure returns(bytes32)
func (_Bridge *BridgeCallerSession) HashMessage(_message IBridgeMessage) ([32]byte, error) {
	return _Bridge.Contract.HashMessage(&_Bridge.CallOpts, _message)
}

// IsDestChainEnabled is a free data retrieval call binding the contract method 0x8e3881a9.
//
// Solidity: function isDestChainEnabled(uint64 _chainId) view returns(bool enabled_, address destBridge_)
func (_Bridge *BridgeCaller) IsDestChainEnabled(opts *bind.CallOpts, _chainId uint64) (struct {
	Enabled    bool
	DestBridge common.Address
}, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "isDestChainEnabled", _chainId)

	outstruct := new(struct {
		Enabled    bool
		DestBridge common.Address
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.Enabled = *abi.ConvertType(out[0], new(bool)).(*bool)
	outstruct.DestBridge = *abi.ConvertType(out[1], new(common.Address)).(*common.Address)

	return *outstruct, err

}

// IsDestChainEnabled is a free data retrieval call binding the contract method 0x8e3881a9.
//
// Solidity: function isDestChainEnabled(uint64 _chainId) view returns(bool enabled_, address destBridge_)
func (_Bridge *BridgeSession) IsDestChainEnabled(_chainId uint64) (struct {
	Enabled    bool
	DestBridge common.Address
}, error) {
	return _Bridge.Contract.IsDestChainEnabled(&_Bridge.CallOpts, _chainId)
}

// IsDestChainEnabled is a free data retrieval call binding the contract method 0x8e3881a9.
//
// Solidity: function isDestChainEnabled(uint64 _chainId) view returns(bool enabled_, address destBridge_)
func (_Bridge *BridgeCallerSession) IsDestChainEnabled(_chainId uint64) (struct {
	Enabled    bool
	DestBridge common.Address
}, error) {
	return _Bridge.Contract.IsDestChainEnabled(&_Bridge.CallOpts, _chainId)
}

// IsMessageFailed is a free data retrieval call binding the contract method 0x839c3791.
//
// Solidity: function isMessageFailed((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message, bytes _proof) view returns(bool)
func (_Bridge *BridgeCaller) IsMessageFailed(opts *bind.CallOpts, _message IBridgeMessage, _proof []byte) (bool, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "isMessageFailed", _message, _proof)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsMessageFailed is a free data retrieval call binding the contract method 0x839c3791.
//
// Solidity: function isMessageFailed((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message, bytes _proof) view returns(bool)
func (_Bridge *BridgeSession) IsMessageFailed(_message IBridgeMessage, _proof []byte) (bool, error) {
	return _Bridge.Contract.IsMessageFailed(&_Bridge.CallOpts, _message, _proof)
}

// IsMessageFailed is a free data retrieval call binding the contract method 0x839c3791.
//
// Solidity: function isMessageFailed((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message, bytes _proof) view returns(bool)
func (_Bridge *BridgeCallerSession) IsMessageFailed(_message IBridgeMessage, _proof []byte) (bool, error) {
	return _Bridge.Contract.IsMessageFailed(&_Bridge.CallOpts, _message, _proof)
}

// IsMessageReceived is a free data retrieval call binding the contract method 0x0ccd8b22.
//
// Solidity: function isMessageReceived((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message, bytes _proof) view returns(bool)
func (_Bridge *BridgeCaller) IsMessageReceived(opts *bind.CallOpts, _message IBridgeMessage, _proof []byte) (bool, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "isMessageReceived", _message, _proof)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsMessageReceived is a free data retrieval call binding the contract method 0x0ccd8b22.
//
// Solidity: function isMessageReceived((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message, bytes _proof) view returns(bool)
func (_Bridge *BridgeSession) IsMessageReceived(_message IBridgeMessage, _proof []byte) (bool, error) {
	return _Bridge.Contract.IsMessageReceived(&_Bridge.CallOpts, _message, _proof)
}

// IsMessageReceived is a free data retrieval call binding the contract method 0x0ccd8b22.
//
// Solidity: function isMessageReceived((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message, bytes _proof) view returns(bool)
func (_Bridge *BridgeCallerSession) IsMessageReceived(_message IBridgeMessage, _proof []byte) (bool, error) {
	return _Bridge.Contract.IsMessageReceived(&_Bridge.CallOpts, _message, _proof)
}

// IsMessageSent is a free data retrieval call binding the contract method 0x9939a2dc.
//
// Solidity: function isMessageSent((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message) view returns(bool)
func (_Bridge *BridgeCaller) IsMessageSent(opts *bind.CallOpts, _message IBridgeMessage) (bool, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "isMessageSent", _message)

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// IsMessageSent is a free data retrieval call binding the contract method 0x9939a2dc.
//
// Solidity: function isMessageSent((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message) view returns(bool)
func (_Bridge *BridgeSession) IsMessageSent(_message IBridgeMessage) (bool, error) {
	return _Bridge.Contract.IsMessageSent(&_Bridge.CallOpts, _message)
}

// IsMessageSent is a free data retrieval call binding the contract method 0x9939a2dc.
//
// Solidity: function isMessageSent((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message) view returns(bool)
func (_Bridge *BridgeCallerSession) IsMessageSent(_message IBridgeMessage) (bool, error) {
	return _Bridge.Contract.IsMessageSent(&_Bridge.CallOpts, _message)
}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_Bridge *BridgeCaller) LastUnpausedAt(opts *bind.CallOpts) (uint64, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "lastUnpausedAt")

	if err != nil {
		return *new(uint64), err
	}

	out0 := *abi.ConvertType(out[0], new(uint64)).(*uint64)

	return out0, err

}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_Bridge *BridgeSession) LastUnpausedAt() (uint64, error) {
	return _Bridge.Contract.LastUnpausedAt(&_Bridge.CallOpts)
}

// LastUnpausedAt is a free data retrieval call binding the contract method 0xe07baba6.
//
// Solidity: function lastUnpausedAt() view returns(uint64)
func (_Bridge *BridgeCallerSession) LastUnpausedAt() (uint64, error) {
	return _Bridge.Contract.LastUnpausedAt(&_Bridge.CallOpts)
}

// MessageStatus is a free data retrieval call binding the contract method 0x3c6cf473.
//
// Solidity: function messageStatus(bytes32 msgHash) view returns(uint8 status)
func (_Bridge *BridgeCaller) MessageStatus(opts *bind.CallOpts, msgHash [32]byte) (uint8, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "messageStatus", msgHash)

	if err != nil {
		return *new(uint8), err
	}

	out0 := *abi.ConvertType(out[0], new(uint8)).(*uint8)

	return out0, err

}

// MessageStatus is a free data retrieval call binding the contract method 0x3c6cf473.
//
// Solidity: function messageStatus(bytes32 msgHash) view returns(uint8 status)
func (_Bridge *BridgeSession) MessageStatus(msgHash [32]byte) (uint8, error) {
	return _Bridge.Contract.MessageStatus(&_Bridge.CallOpts, msgHash)
}

// MessageStatus is a free data retrieval call binding the contract method 0x3c6cf473.
//
// Solidity: function messageStatus(bytes32 msgHash) view returns(uint8 status)
func (_Bridge *BridgeCallerSession) MessageStatus(msgHash [32]byte) (uint8, error) {
	return _Bridge.Contract.MessageStatus(&_Bridge.CallOpts, msgHash)
}

// NextMessageId is a free data retrieval call binding the contract method 0xeefbf17e.
//
// Solidity: function nextMessageId() view returns(uint128)
func (_Bridge *BridgeCaller) NextMessageId(opts *bind.CallOpts) (*big.Int, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "nextMessageId")

	if err != nil {
		return *new(*big.Int), err
	}

	out0 := *abi.ConvertType(out[0], new(*big.Int)).(**big.Int)

	return out0, err

}

// NextMessageId is a free data retrieval call binding the contract method 0xeefbf17e.
//
// Solidity: function nextMessageId() view returns(uint128)
func (_Bridge *BridgeSession) NextMessageId() (*big.Int, error) {
	return _Bridge.Contract.NextMessageId(&_Bridge.CallOpts)
}

// NextMessageId is a free data retrieval call binding the contract method 0xeefbf17e.
//
// Solidity: function nextMessageId() view returns(uint128)
func (_Bridge *BridgeCallerSession) NextMessageId() (*big.Int, error) {
	return _Bridge.Contract.NextMessageId(&_Bridge.CallOpts)
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

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_Bridge *BridgeCaller) Paused(opts *bind.CallOpts) (bool, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "paused")

	if err != nil {
		return *new(bool), err
	}

	out0 := *abi.ConvertType(out[0], new(bool)).(*bool)

	return out0, err

}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_Bridge *BridgeSession) Paused() (bool, error) {
	return _Bridge.Contract.Paused(&_Bridge.CallOpts)
}

// Paused is a free data retrieval call binding the contract method 0x5c975abb.
//
// Solidity: function paused() view returns(bool)
func (_Bridge *BridgeCallerSession) Paused() (bool, error) {
	return _Bridge.Contract.Paused(&_Bridge.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_Bridge *BridgeCaller) PendingOwner(opts *bind.CallOpts) (common.Address, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "pendingOwner")

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_Bridge *BridgeSession) PendingOwner() (common.Address, error) {
	return _Bridge.Contract.PendingOwner(&_Bridge.CallOpts)
}

// PendingOwner is a free data retrieval call binding the contract method 0xe30c3978.
//
// Solidity: function pendingOwner() view returns(address)
func (_Bridge *BridgeCallerSession) PendingOwner() (common.Address, error) {
	return _Bridge.Contract.PendingOwner(&_Bridge.CallOpts)
}

// ProofReceipt is a free data retrieval call binding the contract method 0x6edbad04.
//
// Solidity: function proofReceipt(bytes32 msgHash) view returns(uint64 receivedAt, address preferredExecutor)
func (_Bridge *BridgeCaller) ProofReceipt(opts *bind.CallOpts, msgHash [32]byte) (struct {
	ReceivedAt        uint64
	PreferredExecutor common.Address
}, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "proofReceipt", msgHash)

	outstruct := new(struct {
		ReceivedAt        uint64
		PreferredExecutor common.Address
	})
	if err != nil {
		return *outstruct, err
	}

	outstruct.ReceivedAt = *abi.ConvertType(out[0], new(uint64)).(*uint64)
	outstruct.PreferredExecutor = *abi.ConvertType(out[1], new(common.Address)).(*common.Address)

	return *outstruct, err

}

// ProofReceipt is a free data retrieval call binding the contract method 0x6edbad04.
//
// Solidity: function proofReceipt(bytes32 msgHash) view returns(uint64 receivedAt, address preferredExecutor)
func (_Bridge *BridgeSession) ProofReceipt(msgHash [32]byte) (struct {
	ReceivedAt        uint64
	PreferredExecutor common.Address
}, error) {
	return _Bridge.Contract.ProofReceipt(&_Bridge.CallOpts, msgHash)
}

// ProofReceipt is a free data retrieval call binding the contract method 0x6edbad04.
//
// Solidity: function proofReceipt(bytes32 msgHash) view returns(uint64 receivedAt, address preferredExecutor)
func (_Bridge *BridgeCallerSession) ProofReceipt(msgHash [32]byte) (struct {
	ReceivedAt        uint64
	PreferredExecutor common.Address
}, error) {
	return _Bridge.Contract.ProofReceipt(&_Bridge.CallOpts, msgHash)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_Bridge *BridgeCaller) ProxiableUUID(opts *bind.CallOpts) ([32]byte, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "proxiableUUID")

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_Bridge *BridgeSession) ProxiableUUID() ([32]byte, error) {
	return _Bridge.Contract.ProxiableUUID(&_Bridge.CallOpts)
}

// ProxiableUUID is a free data retrieval call binding the contract method 0x52d1902d.
//
// Solidity: function proxiableUUID() view returns(bytes32)
func (_Bridge *BridgeCallerSession) ProxiableUUID() ([32]byte, error) {
	return _Bridge.Contract.ProxiableUUID(&_Bridge.CallOpts)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_Bridge *BridgeCaller) Resolve(opts *bind.CallOpts, _chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "resolve", _chainId, _name, _allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_Bridge *BridgeSession) Resolve(_chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _Bridge.Contract.Resolve(&_Bridge.CallOpts, _chainId, _name, _allowZeroAddress)
}

// Resolve is a free data retrieval call binding the contract method 0x3eb6b8cf.
//
// Solidity: function resolve(uint64 _chainId, bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_Bridge *BridgeCallerSession) Resolve(_chainId uint64, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _Bridge.Contract.Resolve(&_Bridge.CallOpts, _chainId, _name, _allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_Bridge *BridgeCaller) Resolve0(opts *bind.CallOpts, _name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "resolve0", _name, _allowZeroAddress)

	if err != nil {
		return *new(common.Address), err
	}

	out0 := *abi.ConvertType(out[0], new(common.Address)).(*common.Address)

	return out0, err

}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_Bridge *BridgeSession) Resolve0(_name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _Bridge.Contract.Resolve0(&_Bridge.CallOpts, _name, _allowZeroAddress)
}

// Resolve0 is a free data retrieval call binding the contract method 0xa86f9d9e.
//
// Solidity: function resolve(bytes32 _name, bool _allowZeroAddress) view returns(address)
func (_Bridge *BridgeCallerSession) Resolve0(_name [32]byte, _allowZeroAddress bool) (common.Address, error) {
	return _Bridge.Contract.Resolve0(&_Bridge.CallOpts, _name, _allowZeroAddress)
}

// SignalForFailedMessage is a free data retrieval call binding the contract method 0xd1aaa5df.
//
// Solidity: function signalForFailedMessage(bytes32 _msgHash) pure returns(bytes32)
func (_Bridge *BridgeCaller) SignalForFailedMessage(opts *bind.CallOpts, _msgHash [32]byte) ([32]byte, error) {
	var out []interface{}
	err := _Bridge.contract.Call(opts, &out, "signalForFailedMessage", _msgHash)

	if err != nil {
		return *new([32]byte), err
	}

	out0 := *abi.ConvertType(out[0], new([32]byte)).(*[32]byte)

	return out0, err

}

// SignalForFailedMessage is a free data retrieval call binding the contract method 0xd1aaa5df.
//
// Solidity: function signalForFailedMessage(bytes32 _msgHash) pure returns(bytes32)
func (_Bridge *BridgeSession) SignalForFailedMessage(_msgHash [32]byte) ([32]byte, error) {
	return _Bridge.Contract.SignalForFailedMessage(&_Bridge.CallOpts, _msgHash)
}

// SignalForFailedMessage is a free data retrieval call binding the contract method 0xd1aaa5df.
//
// Solidity: function signalForFailedMessage(bytes32 _msgHash) pure returns(bytes32)
func (_Bridge *BridgeCallerSession) SignalForFailedMessage(_msgHash [32]byte) ([32]byte, error) {
	return _Bridge.Contract.SignalForFailedMessage(&_Bridge.CallOpts, _msgHash)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_Bridge *BridgeTransactor) AcceptOwnership(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Bridge.contract.Transact(opts, "acceptOwnership")
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_Bridge *BridgeSession) AcceptOwnership() (*types.Transaction, error) {
	return _Bridge.Contract.AcceptOwnership(&_Bridge.TransactOpts)
}

// AcceptOwnership is a paid mutator transaction binding the contract method 0x79ba5097.
//
// Solidity: function acceptOwnership() returns()
func (_Bridge *BridgeTransactorSession) AcceptOwnership() (*types.Transaction, error) {
	return _Bridge.Contract.AcceptOwnership(&_Bridge.TransactOpts)
}

// Init is a paid mutator transaction binding the contract method 0xf09a4016.
//
// Solidity: function init(address _owner, address _addressManager) returns()
func (_Bridge *BridgeTransactor) Init(opts *bind.TransactOpts, _owner common.Address, _addressManager common.Address) (*types.Transaction, error) {
	return _Bridge.contract.Transact(opts, "init", _owner, _addressManager)
}

// Init is a paid mutator transaction binding the contract method 0xf09a4016.
//
// Solidity: function init(address _owner, address _addressManager) returns()
func (_Bridge *BridgeSession) Init(_owner common.Address, _addressManager common.Address) (*types.Transaction, error) {
	return _Bridge.Contract.Init(&_Bridge.TransactOpts, _owner, _addressManager)
}

// Init is a paid mutator transaction binding the contract method 0xf09a4016.
//
// Solidity: function init(address _owner, address _addressManager) returns()
func (_Bridge *BridgeTransactorSession) Init(_owner common.Address, _addressManager common.Address) (*types.Transaction, error) {
	return _Bridge.Contract.Init(&_Bridge.TransactOpts, _owner, _addressManager)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_Bridge *BridgeTransactor) Pause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Bridge.contract.Transact(opts, "pause")
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_Bridge *BridgeSession) Pause() (*types.Transaction, error) {
	return _Bridge.Contract.Pause(&_Bridge.TransactOpts)
}

// Pause is a paid mutator transaction binding the contract method 0x8456cb59.
//
// Solidity: function pause() returns()
func (_Bridge *BridgeTransactorSession) Pause() (*types.Transaction, error) {
	return _Bridge.Contract.Pause(&_Bridge.TransactOpts)
}

// ProcessMessage is a paid mutator transaction binding the contract method 0x16b205c1.
//
// Solidity: function processMessage((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message, bytes _proof) returns()
func (_Bridge *BridgeTransactor) ProcessMessage(opts *bind.TransactOpts, _message IBridgeMessage, _proof []byte) (*types.Transaction, error) {
	return _Bridge.contract.Transact(opts, "processMessage", _message, _proof)
}

// ProcessMessage is a paid mutator transaction binding the contract method 0x16b205c1.
//
// Solidity: function processMessage((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message, bytes _proof) returns()
func (_Bridge *BridgeSession) ProcessMessage(_message IBridgeMessage, _proof []byte) (*types.Transaction, error) {
	return _Bridge.Contract.ProcessMessage(&_Bridge.TransactOpts, _message, _proof)
}

// ProcessMessage is a paid mutator transaction binding the contract method 0x16b205c1.
//
// Solidity: function processMessage((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message, bytes _proof) returns()
func (_Bridge *BridgeTransactorSession) ProcessMessage(_message IBridgeMessage, _proof []byte) (*types.Transaction, error) {
	return _Bridge.Contract.ProcessMessage(&_Bridge.TransactOpts, _message, _proof)
}

// ProveMessageFailed is a paid mutator transaction binding the contract method 0x324c058e.
//
// Solidity: function proveMessageFailed((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message, bytes _proof) returns(bool)
func (_Bridge *BridgeTransactor) ProveMessageFailed(opts *bind.TransactOpts, _message IBridgeMessage, _proof []byte) (*types.Transaction, error) {
	return _Bridge.contract.Transact(opts, "proveMessageFailed", _message, _proof)
}

// ProveMessageFailed is a paid mutator transaction binding the contract method 0x324c058e.
//
// Solidity: function proveMessageFailed((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message, bytes _proof) returns(bool)
func (_Bridge *BridgeSession) ProveMessageFailed(_message IBridgeMessage, _proof []byte) (*types.Transaction, error) {
	return _Bridge.Contract.ProveMessageFailed(&_Bridge.TransactOpts, _message, _proof)
}

// ProveMessageFailed is a paid mutator transaction binding the contract method 0x324c058e.
//
// Solidity: function proveMessageFailed((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message, bytes _proof) returns(bool)
func (_Bridge *BridgeTransactorSession) ProveMessageFailed(_message IBridgeMessage, _proof []byte) (*types.Transaction, error) {
	return _Bridge.Contract.ProveMessageFailed(&_Bridge.TransactOpts, _message, _proof)
}

// ProveMessageReceived is a paid mutator transaction binding the contract method 0x6be4eb55.
//
// Solidity: function proveMessageReceived((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message, bytes _proof) returns(bool)
func (_Bridge *BridgeTransactor) ProveMessageReceived(opts *bind.TransactOpts, _message IBridgeMessage, _proof []byte) (*types.Transaction, error) {
	return _Bridge.contract.Transact(opts, "proveMessageReceived", _message, _proof)
}

// ProveMessageReceived is a paid mutator transaction binding the contract method 0x6be4eb55.
//
// Solidity: function proveMessageReceived((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message, bytes _proof) returns(bool)
func (_Bridge *BridgeSession) ProveMessageReceived(_message IBridgeMessage, _proof []byte) (*types.Transaction, error) {
	return _Bridge.Contract.ProveMessageReceived(&_Bridge.TransactOpts, _message, _proof)
}

// ProveMessageReceived is a paid mutator transaction binding the contract method 0x6be4eb55.
//
// Solidity: function proveMessageReceived((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message, bytes _proof) returns(bool)
func (_Bridge *BridgeTransactorSession) ProveMessageReceived(_message IBridgeMessage, _proof []byte) (*types.Transaction, error) {
	return _Bridge.Contract.ProveMessageReceived(&_Bridge.TransactOpts, _message, _proof)
}

// RecallMessage is a paid mutator transaction binding the contract method 0xd6ba38b2.
//
// Solidity: function recallMessage((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message, bytes _proof) returns()
func (_Bridge *BridgeTransactor) RecallMessage(opts *bind.TransactOpts, _message IBridgeMessage, _proof []byte) (*types.Transaction, error) {
	return _Bridge.contract.Transact(opts, "recallMessage", _message, _proof)
}

// RecallMessage is a paid mutator transaction binding the contract method 0xd6ba38b2.
//
// Solidity: function recallMessage((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message, bytes _proof) returns()
func (_Bridge *BridgeSession) RecallMessage(_message IBridgeMessage, _proof []byte) (*types.Transaction, error) {
	return _Bridge.Contract.RecallMessage(&_Bridge.TransactOpts, _message, _proof)
}

// RecallMessage is a paid mutator transaction binding the contract method 0xd6ba38b2.
//
// Solidity: function recallMessage((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message, bytes _proof) returns()
func (_Bridge *BridgeTransactorSession) RecallMessage(_message IBridgeMessage, _proof []byte) (*types.Transaction, error) {
	return _Bridge.Contract.RecallMessage(&_Bridge.TransactOpts, _message, _proof)
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

// RetryMessage is a paid mutator transaction binding the contract method 0xb916a0be.
//
// Solidity: function retryMessage((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message, bool _isLastAttempt) returns()
func (_Bridge *BridgeTransactor) RetryMessage(opts *bind.TransactOpts, _message IBridgeMessage, _isLastAttempt bool) (*types.Transaction, error) {
	return _Bridge.contract.Transact(opts, "retryMessage", _message, _isLastAttempt)
}

// RetryMessage is a paid mutator transaction binding the contract method 0xb916a0be.
//
// Solidity: function retryMessage((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message, bool _isLastAttempt) returns()
func (_Bridge *BridgeSession) RetryMessage(_message IBridgeMessage, _isLastAttempt bool) (*types.Transaction, error) {
	return _Bridge.Contract.RetryMessage(&_Bridge.TransactOpts, _message, _isLastAttempt)
}

// RetryMessage is a paid mutator transaction binding the contract method 0xb916a0be.
//
// Solidity: function retryMessage((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message, bool _isLastAttempt) returns()
func (_Bridge *BridgeTransactorSession) RetryMessage(_message IBridgeMessage, _isLastAttempt bool) (*types.Transaction, error) {
	return _Bridge.Contract.RetryMessage(&_Bridge.TransactOpts, _message, _isLastAttempt)
}

// SendMessage is a paid mutator transaction binding the contract method 0x6c334e2e.
//
// Solidity: function sendMessage((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message) payable returns(bytes32 msgHash_, (uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) message_)
func (_Bridge *BridgeTransactor) SendMessage(opts *bind.TransactOpts, _message IBridgeMessage) (*types.Transaction, error) {
	return _Bridge.contract.Transact(opts, "sendMessage", _message)
}

// SendMessage is a paid mutator transaction binding the contract method 0x6c334e2e.
//
// Solidity: function sendMessage((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message) payable returns(bytes32 msgHash_, (uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) message_)
func (_Bridge *BridgeSession) SendMessage(_message IBridgeMessage) (*types.Transaction, error) {
	return _Bridge.Contract.SendMessage(&_Bridge.TransactOpts, _message)
}

// SendMessage is a paid mutator transaction binding the contract method 0x6c334e2e.
//
// Solidity: function sendMessage((uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) _message) payable returns(bytes32 msgHash_, (uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) message_)
func (_Bridge *BridgeTransactorSession) SendMessage(_message IBridgeMessage) (*types.Transaction, error) {
	return _Bridge.Contract.SendMessage(&_Bridge.TransactOpts, _message)
}

// SuspendMessages is a paid mutator transaction binding the contract method 0x48548f25.
//
// Solidity: function suspendMessages(bytes32[] _msgHashes, bool _suspend) returns()
func (_Bridge *BridgeTransactor) SuspendMessages(opts *bind.TransactOpts, _msgHashes [][32]byte, _suspend bool) (*types.Transaction, error) {
	return _Bridge.contract.Transact(opts, "suspendMessages", _msgHashes, _suspend)
}

// SuspendMessages is a paid mutator transaction binding the contract method 0x48548f25.
//
// Solidity: function suspendMessages(bytes32[] _msgHashes, bool _suspend) returns()
func (_Bridge *BridgeSession) SuspendMessages(_msgHashes [][32]byte, _suspend bool) (*types.Transaction, error) {
	return _Bridge.Contract.SuspendMessages(&_Bridge.TransactOpts, _msgHashes, _suspend)
}

// SuspendMessages is a paid mutator transaction binding the contract method 0x48548f25.
//
// Solidity: function suspendMessages(bytes32[] _msgHashes, bool _suspend) returns()
func (_Bridge *BridgeTransactorSession) SuspendMessages(_msgHashes [][32]byte, _suspend bool) (*types.Transaction, error) {
	return _Bridge.Contract.SuspendMessages(&_Bridge.TransactOpts, _msgHashes, _suspend)
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

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_Bridge *BridgeTransactor) Unpause(opts *bind.TransactOpts) (*types.Transaction, error) {
	return _Bridge.contract.Transact(opts, "unpause")
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_Bridge *BridgeSession) Unpause() (*types.Transaction, error) {
	return _Bridge.Contract.Unpause(&_Bridge.TransactOpts)
}

// Unpause is a paid mutator transaction binding the contract method 0x3f4ba83a.
//
// Solidity: function unpause() returns()
func (_Bridge *BridgeTransactorSession) Unpause() (*types.Transaction, error) {
	return _Bridge.Contract.Unpause(&_Bridge.TransactOpts)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_Bridge *BridgeTransactor) UpgradeTo(opts *bind.TransactOpts, newImplementation common.Address) (*types.Transaction, error) {
	return _Bridge.contract.Transact(opts, "upgradeTo", newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_Bridge *BridgeSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _Bridge.Contract.UpgradeTo(&_Bridge.TransactOpts, newImplementation)
}

// UpgradeTo is a paid mutator transaction binding the contract method 0x3659cfe6.
//
// Solidity: function upgradeTo(address newImplementation) returns()
func (_Bridge *BridgeTransactorSession) UpgradeTo(newImplementation common.Address) (*types.Transaction, error) {
	return _Bridge.Contract.UpgradeTo(&_Bridge.TransactOpts, newImplementation)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_Bridge *BridgeTransactor) UpgradeToAndCall(opts *bind.TransactOpts, newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _Bridge.contract.Transact(opts, "upgradeToAndCall", newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_Bridge *BridgeSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _Bridge.Contract.UpgradeToAndCall(&_Bridge.TransactOpts, newImplementation, data)
}

// UpgradeToAndCall is a paid mutator transaction binding the contract method 0x4f1ef286.
//
// Solidity: function upgradeToAndCall(address newImplementation, bytes data) payable returns()
func (_Bridge *BridgeTransactorSession) UpgradeToAndCall(newImplementation common.Address, data []byte) (*types.Transaction, error) {
	return _Bridge.Contract.UpgradeToAndCall(&_Bridge.TransactOpts, newImplementation, data)
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

// BridgeAddressBannedIterator is returned from FilterAddressBanned and is used to iterate over the raw logs and unpacked data for AddressBanned events raised by the Bridge contract.
type BridgeAddressBannedIterator struct {
	Event *BridgeAddressBanned // Event containing the contract specifics and raw log

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
func (it *BridgeAddressBannedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BridgeAddressBanned)
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
		it.Event = new(BridgeAddressBanned)
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
func (it *BridgeAddressBannedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BridgeAddressBannedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BridgeAddressBanned represents a AddressBanned event raised by the Bridge contract.
type BridgeAddressBanned struct {
	Addr   common.Address
	Banned bool
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterAddressBanned is a free log retrieval operation binding the contract event 0x7113ce15c395851033544a97557341cdc71886964b54ff108a685d359ed4cdf8.
//
// Solidity: event AddressBanned(address indexed addr, bool banned)
func (_Bridge *BridgeFilterer) FilterAddressBanned(opts *bind.FilterOpts, addr []common.Address) (*BridgeAddressBannedIterator, error) {

	var addrRule []interface{}
	for _, addrItem := range addr {
		addrRule = append(addrRule, addrItem)
	}

	logs, sub, err := _Bridge.contract.FilterLogs(opts, "AddressBanned", addrRule)
	if err != nil {
		return nil, err
	}
	return &BridgeAddressBannedIterator{contract: _Bridge.contract, event: "AddressBanned", logs: logs, sub: sub}, nil
}

// WatchAddressBanned is a free log subscription operation binding the contract event 0x7113ce15c395851033544a97557341cdc71886964b54ff108a685d359ed4cdf8.
//
// Solidity: event AddressBanned(address indexed addr, bool banned)
func (_Bridge *BridgeFilterer) WatchAddressBanned(opts *bind.WatchOpts, sink chan<- *BridgeAddressBanned, addr []common.Address) (event.Subscription, error) {

	var addrRule []interface{}
	for _, addrItem := range addr {
		addrRule = append(addrRule, addrItem)
	}

	logs, sub, err := _Bridge.contract.WatchLogs(opts, "AddressBanned", addrRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BridgeAddressBanned)
				if err := _Bridge.contract.UnpackLog(event, "AddressBanned", log); err != nil {
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

// ParseAddressBanned is a log parse operation binding the contract event 0x7113ce15c395851033544a97557341cdc71886964b54ff108a685d359ed4cdf8.
//
// Solidity: event AddressBanned(address indexed addr, bool banned)
func (_Bridge *BridgeFilterer) ParseAddressBanned(log types.Log) (*BridgeAddressBanned, error) {
	event := new(BridgeAddressBanned)
	if err := _Bridge.contract.UnpackLog(event, "AddressBanned", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BridgeAdminChangedIterator is returned from FilterAdminChanged and is used to iterate over the raw logs and unpacked data for AdminChanged events raised by the Bridge contract.
type BridgeAdminChangedIterator struct {
	Event *BridgeAdminChanged // Event containing the contract specifics and raw log

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
func (it *BridgeAdminChangedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BridgeAdminChanged)
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
		it.Event = new(BridgeAdminChanged)
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
func (it *BridgeAdminChangedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BridgeAdminChangedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BridgeAdminChanged represents a AdminChanged event raised by the Bridge contract.
type BridgeAdminChanged struct {
	PreviousAdmin common.Address
	NewAdmin      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterAdminChanged is a free log retrieval operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_Bridge *BridgeFilterer) FilterAdminChanged(opts *bind.FilterOpts) (*BridgeAdminChangedIterator, error) {

	logs, sub, err := _Bridge.contract.FilterLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return &BridgeAdminChangedIterator{contract: _Bridge.contract, event: "AdminChanged", logs: logs, sub: sub}, nil
}

// WatchAdminChanged is a free log subscription operation binding the contract event 0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f.
//
// Solidity: event AdminChanged(address previousAdmin, address newAdmin)
func (_Bridge *BridgeFilterer) WatchAdminChanged(opts *bind.WatchOpts, sink chan<- *BridgeAdminChanged) (event.Subscription, error) {

	logs, sub, err := _Bridge.contract.WatchLogs(opts, "AdminChanged")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BridgeAdminChanged)
				if err := _Bridge.contract.UnpackLog(event, "AdminChanged", log); err != nil {
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
func (_Bridge *BridgeFilterer) ParseAdminChanged(log types.Log) (*BridgeAdminChanged, error) {
	event := new(BridgeAdminChanged)
	if err := _Bridge.contract.UnpackLog(event, "AdminChanged", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BridgeBeaconUpgradedIterator is returned from FilterBeaconUpgraded and is used to iterate over the raw logs and unpacked data for BeaconUpgraded events raised by the Bridge contract.
type BridgeBeaconUpgradedIterator struct {
	Event *BridgeBeaconUpgraded // Event containing the contract specifics and raw log

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
func (it *BridgeBeaconUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BridgeBeaconUpgraded)
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
		it.Event = new(BridgeBeaconUpgraded)
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
func (it *BridgeBeaconUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BridgeBeaconUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BridgeBeaconUpgraded represents a BeaconUpgraded event raised by the Bridge contract.
type BridgeBeaconUpgraded struct {
	Beacon common.Address
	Raw    types.Log // Blockchain specific contextual infos
}

// FilterBeaconUpgraded is a free log retrieval operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_Bridge *BridgeFilterer) FilterBeaconUpgraded(opts *bind.FilterOpts, beacon []common.Address) (*BridgeBeaconUpgradedIterator, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _Bridge.contract.FilterLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return &BridgeBeaconUpgradedIterator{contract: _Bridge.contract, event: "BeaconUpgraded", logs: logs, sub: sub}, nil
}

// WatchBeaconUpgraded is a free log subscription operation binding the contract event 0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e.
//
// Solidity: event BeaconUpgraded(address indexed beacon)
func (_Bridge *BridgeFilterer) WatchBeaconUpgraded(opts *bind.WatchOpts, sink chan<- *BridgeBeaconUpgraded, beacon []common.Address) (event.Subscription, error) {

	var beaconRule []interface{}
	for _, beaconItem := range beacon {
		beaconRule = append(beaconRule, beaconItem)
	}

	logs, sub, err := _Bridge.contract.WatchLogs(opts, "BeaconUpgraded", beaconRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BridgeBeaconUpgraded)
				if err := _Bridge.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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
func (_Bridge *BridgeFilterer) ParseBeaconUpgraded(log types.Log) (*BridgeBeaconUpgraded, error) {
	event := new(BridgeBeaconUpgraded)
	if err := _Bridge.contract.UnpackLog(event, "BeaconUpgraded", log); err != nil {
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

// BridgeMessageExecutedIterator is returned from FilterMessageExecuted and is used to iterate over the raw logs and unpacked data for MessageExecuted events raised by the Bridge contract.
type BridgeMessageExecutedIterator struct {
	Event *BridgeMessageExecuted // Event containing the contract specifics and raw log

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
func (it *BridgeMessageExecutedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BridgeMessageExecuted)
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
		it.Event = new(BridgeMessageExecuted)
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
func (it *BridgeMessageExecutedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BridgeMessageExecutedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BridgeMessageExecuted represents a MessageExecuted event raised by the Bridge contract.
type BridgeMessageExecuted struct {
	MsgHash [32]byte
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterMessageExecuted is a free log retrieval operation binding the contract event 0xe7d1e1f435233f7a187624ac11afaf32ee0da368cef8a5625be394412f619254.
//
// Solidity: event MessageExecuted(bytes32 indexed msgHash)
func (_Bridge *BridgeFilterer) FilterMessageExecuted(opts *bind.FilterOpts, msgHash [][32]byte) (*BridgeMessageExecutedIterator, error) {

	var msgHashRule []interface{}
	for _, msgHashItem := range msgHash {
		msgHashRule = append(msgHashRule, msgHashItem)
	}

	logs, sub, err := _Bridge.contract.FilterLogs(opts, "MessageExecuted", msgHashRule)
	if err != nil {
		return nil, err
	}
	return &BridgeMessageExecutedIterator{contract: _Bridge.contract, event: "MessageExecuted", logs: logs, sub: sub}, nil
}

// WatchMessageExecuted is a free log subscription operation binding the contract event 0xe7d1e1f435233f7a187624ac11afaf32ee0da368cef8a5625be394412f619254.
//
// Solidity: event MessageExecuted(bytes32 indexed msgHash)
func (_Bridge *BridgeFilterer) WatchMessageExecuted(opts *bind.WatchOpts, sink chan<- *BridgeMessageExecuted, msgHash [][32]byte) (event.Subscription, error) {

	var msgHashRule []interface{}
	for _, msgHashItem := range msgHash {
		msgHashRule = append(msgHashRule, msgHashItem)
	}

	logs, sub, err := _Bridge.contract.WatchLogs(opts, "MessageExecuted", msgHashRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BridgeMessageExecuted)
				if err := _Bridge.contract.UnpackLog(event, "MessageExecuted", log); err != nil {
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

// ParseMessageExecuted is a log parse operation binding the contract event 0xe7d1e1f435233f7a187624ac11afaf32ee0da368cef8a5625be394412f619254.
//
// Solidity: event MessageExecuted(bytes32 indexed msgHash)
func (_Bridge *BridgeFilterer) ParseMessageExecuted(log types.Log) (*BridgeMessageExecuted, error) {
	event := new(BridgeMessageExecuted)
	if err := _Bridge.contract.UnpackLog(event, "MessageExecuted", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BridgeMessageRecalledIterator is returned from FilterMessageRecalled and is used to iterate over the raw logs and unpacked data for MessageRecalled events raised by the Bridge contract.
type BridgeMessageRecalledIterator struct {
	Event *BridgeMessageRecalled // Event containing the contract specifics and raw log

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
func (it *BridgeMessageRecalledIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BridgeMessageRecalled)
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
		it.Event = new(BridgeMessageRecalled)
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
func (it *BridgeMessageRecalledIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BridgeMessageRecalledIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BridgeMessageRecalled represents a MessageRecalled event raised by the Bridge contract.
type BridgeMessageRecalled struct {
	MsgHash [32]byte
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterMessageRecalled is a free log retrieval operation binding the contract event 0xc6fbc1fa0145a394c9c414b2ae7bd634eb50dd888938bcd75692ae427b680fa2.
//
// Solidity: event MessageRecalled(bytes32 indexed msgHash)
func (_Bridge *BridgeFilterer) FilterMessageRecalled(opts *bind.FilterOpts, msgHash [][32]byte) (*BridgeMessageRecalledIterator, error) {

	var msgHashRule []interface{}
	for _, msgHashItem := range msgHash {
		msgHashRule = append(msgHashRule, msgHashItem)
	}

	logs, sub, err := _Bridge.contract.FilterLogs(opts, "MessageRecalled", msgHashRule)
	if err != nil {
		return nil, err
	}
	return &BridgeMessageRecalledIterator{contract: _Bridge.contract, event: "MessageRecalled", logs: logs, sub: sub}, nil
}

// WatchMessageRecalled is a free log subscription operation binding the contract event 0xc6fbc1fa0145a394c9c414b2ae7bd634eb50dd888938bcd75692ae427b680fa2.
//
// Solidity: event MessageRecalled(bytes32 indexed msgHash)
func (_Bridge *BridgeFilterer) WatchMessageRecalled(opts *bind.WatchOpts, sink chan<- *BridgeMessageRecalled, msgHash [][32]byte) (event.Subscription, error) {

	var msgHashRule []interface{}
	for _, msgHashItem := range msgHash {
		msgHashRule = append(msgHashRule, msgHashItem)
	}

	logs, sub, err := _Bridge.contract.WatchLogs(opts, "MessageRecalled", msgHashRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BridgeMessageRecalled)
				if err := _Bridge.contract.UnpackLog(event, "MessageRecalled", log); err != nil {
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

// ParseMessageRecalled is a log parse operation binding the contract event 0xc6fbc1fa0145a394c9c414b2ae7bd634eb50dd888938bcd75692ae427b680fa2.
//
// Solidity: event MessageRecalled(bytes32 indexed msgHash)
func (_Bridge *BridgeFilterer) ParseMessageRecalled(log types.Log) (*BridgeMessageRecalled, error) {
	event := new(BridgeMessageRecalled)
	if err := _Bridge.contract.UnpackLog(event, "MessageRecalled", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BridgeMessageReceivedIterator is returned from FilterMessageReceived and is used to iterate over the raw logs and unpacked data for MessageReceived events raised by the Bridge contract.
type BridgeMessageReceivedIterator struct {
	Event *BridgeMessageReceived // Event containing the contract specifics and raw log

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
func (it *BridgeMessageReceivedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BridgeMessageReceived)
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
		it.Event = new(BridgeMessageReceived)
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
func (it *BridgeMessageReceivedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BridgeMessageReceivedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BridgeMessageReceived represents a MessageReceived event raised by the Bridge contract.
type BridgeMessageReceived struct {
	MsgHash  [32]byte
	Message  IBridgeMessage
	IsRecall bool
	Raw      types.Log // Blockchain specific contextual infos
}

// FilterMessageReceived is a free log retrieval operation binding the contract event 0x3a7420670ebb84feae884388421d5f63bb1f9e073c54c8103e9e2ca7a98346e5.
//
// Solidity: event MessageReceived(bytes32 indexed msgHash, (uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) message, bool isRecall)
func (_Bridge *BridgeFilterer) FilterMessageReceived(opts *bind.FilterOpts, msgHash [][32]byte) (*BridgeMessageReceivedIterator, error) {

	var msgHashRule []interface{}
	for _, msgHashItem := range msgHash {
		msgHashRule = append(msgHashRule, msgHashItem)
	}

	logs, sub, err := _Bridge.contract.FilterLogs(opts, "MessageReceived", msgHashRule)
	if err != nil {
		return nil, err
	}
	return &BridgeMessageReceivedIterator{contract: _Bridge.contract, event: "MessageReceived", logs: logs, sub: sub}, nil
}

// WatchMessageReceived is a free log subscription operation binding the contract event 0x3a7420670ebb84feae884388421d5f63bb1f9e073c54c8103e9e2ca7a98346e5.
//
// Solidity: event MessageReceived(bytes32 indexed msgHash, (uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) message, bool isRecall)
func (_Bridge *BridgeFilterer) WatchMessageReceived(opts *bind.WatchOpts, sink chan<- *BridgeMessageReceived, msgHash [][32]byte) (event.Subscription, error) {

	var msgHashRule []interface{}
	for _, msgHashItem := range msgHash {
		msgHashRule = append(msgHashRule, msgHashItem)
	}

	logs, sub, err := _Bridge.contract.WatchLogs(opts, "MessageReceived", msgHashRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BridgeMessageReceived)
				if err := _Bridge.contract.UnpackLog(event, "MessageReceived", log); err != nil {
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

// ParseMessageReceived is a log parse operation binding the contract event 0x3a7420670ebb84feae884388421d5f63bb1f9e073c54c8103e9e2ca7a98346e5.
//
// Solidity: event MessageReceived(bytes32 indexed msgHash, (uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) message, bool isRecall)
func (_Bridge *BridgeFilterer) ParseMessageReceived(log types.Log) (*BridgeMessageReceived, error) {
	event := new(BridgeMessageReceived)
	if err := _Bridge.contract.UnpackLog(event, "MessageReceived", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BridgeMessageRetriedIterator is returned from FilterMessageRetried and is used to iterate over the raw logs and unpacked data for MessageRetried events raised by the Bridge contract.
type BridgeMessageRetriedIterator struct {
	Event *BridgeMessageRetried // Event containing the contract specifics and raw log

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
func (it *BridgeMessageRetriedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BridgeMessageRetried)
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
		it.Event = new(BridgeMessageRetried)
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
func (it *BridgeMessageRetriedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BridgeMessageRetriedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BridgeMessageRetried represents a MessageRetried event raised by the Bridge contract.
type BridgeMessageRetried struct {
	MsgHash [32]byte
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterMessageRetried is a free log retrieval operation binding the contract event 0x72d1525c4df70aedf1877ec89702311c795a01c082917308a30fb40059da2cc7.
//
// Solidity: event MessageRetried(bytes32 indexed msgHash)
func (_Bridge *BridgeFilterer) FilterMessageRetried(opts *bind.FilterOpts, msgHash [][32]byte) (*BridgeMessageRetriedIterator, error) {

	var msgHashRule []interface{}
	for _, msgHashItem := range msgHash {
		msgHashRule = append(msgHashRule, msgHashItem)
	}

	logs, sub, err := _Bridge.contract.FilterLogs(opts, "MessageRetried", msgHashRule)
	if err != nil {
		return nil, err
	}
	return &BridgeMessageRetriedIterator{contract: _Bridge.contract, event: "MessageRetried", logs: logs, sub: sub}, nil
}

// WatchMessageRetried is a free log subscription operation binding the contract event 0x72d1525c4df70aedf1877ec89702311c795a01c082917308a30fb40059da2cc7.
//
// Solidity: event MessageRetried(bytes32 indexed msgHash)
func (_Bridge *BridgeFilterer) WatchMessageRetried(opts *bind.WatchOpts, sink chan<- *BridgeMessageRetried, msgHash [][32]byte) (event.Subscription, error) {

	var msgHashRule []interface{}
	for _, msgHashItem := range msgHash {
		msgHashRule = append(msgHashRule, msgHashItem)
	}

	logs, sub, err := _Bridge.contract.WatchLogs(opts, "MessageRetried", msgHashRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BridgeMessageRetried)
				if err := _Bridge.contract.UnpackLog(event, "MessageRetried", log); err != nil {
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

// ParseMessageRetried is a log parse operation binding the contract event 0x72d1525c4df70aedf1877ec89702311c795a01c082917308a30fb40059da2cc7.
//
// Solidity: event MessageRetried(bytes32 indexed msgHash)
func (_Bridge *BridgeFilterer) ParseMessageRetried(log types.Log) (*BridgeMessageRetried, error) {
	event := new(BridgeMessageRetried)
	if err := _Bridge.contract.UnpackLog(event, "MessageRetried", log); err != nil {
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

// FilterMessageSent is a free log retrieval operation binding the contract event 0x9a4c6dce9e49d66f9d79b5f213b08c30c2bcef51424e23934a80f4865e1f7039.
//
// Solidity: event MessageSent(bytes32 indexed msgHash, (uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) message)
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

// WatchMessageSent is a free log subscription operation binding the contract event 0x9a4c6dce9e49d66f9d79b5f213b08c30c2bcef51424e23934a80f4865e1f7039.
//
// Solidity: event MessageSent(bytes32 indexed msgHash, (uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) message)
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

// ParseMessageSent is a log parse operation binding the contract event 0x9a4c6dce9e49d66f9d79b5f213b08c30c2bcef51424e23934a80f4865e1f7039.
//
// Solidity: event MessageSent(bytes32 indexed msgHash, (uint128,address,uint64,uint64,address,address,address,address,uint256,uint256,uint256,bytes,string) message)
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

// BridgeMessageSuspendedIterator is returned from FilterMessageSuspended and is used to iterate over the raw logs and unpacked data for MessageSuspended events raised by the Bridge contract.
type BridgeMessageSuspendedIterator struct {
	Event *BridgeMessageSuspended // Event containing the contract specifics and raw log

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
func (it *BridgeMessageSuspendedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BridgeMessageSuspended)
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
		it.Event = new(BridgeMessageSuspended)
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
func (it *BridgeMessageSuspendedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BridgeMessageSuspendedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BridgeMessageSuspended represents a MessageSuspended event raised by the Bridge contract.
type BridgeMessageSuspended struct {
	MsgHash    [32]byte
	Suspended  bool
	ReceivedAt uint64
	Raw        types.Log // Blockchain specific contextual infos
}

// FilterMessageSuspended is a free log retrieval operation binding the contract event 0xa3bf322f86f6b7b2fcb75744c1a9e22891ae257bbeb6b2a265627371e2651bcb.
//
// Solidity: event MessageSuspended(bytes32 msgHash, bool suspended, uint64 receivedAt)
func (_Bridge *BridgeFilterer) FilterMessageSuspended(opts *bind.FilterOpts) (*BridgeMessageSuspendedIterator, error) {

	logs, sub, err := _Bridge.contract.FilterLogs(opts, "MessageSuspended")
	if err != nil {
		return nil, err
	}
	return &BridgeMessageSuspendedIterator{contract: _Bridge.contract, event: "MessageSuspended", logs: logs, sub: sub}, nil
}

// WatchMessageSuspended is a free log subscription operation binding the contract event 0xa3bf322f86f6b7b2fcb75744c1a9e22891ae257bbeb6b2a265627371e2651bcb.
//
// Solidity: event MessageSuspended(bytes32 msgHash, bool suspended, uint64 receivedAt)
func (_Bridge *BridgeFilterer) WatchMessageSuspended(opts *bind.WatchOpts, sink chan<- *BridgeMessageSuspended) (event.Subscription, error) {

	logs, sub, err := _Bridge.contract.WatchLogs(opts, "MessageSuspended")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BridgeMessageSuspended)
				if err := _Bridge.contract.UnpackLog(event, "MessageSuspended", log); err != nil {
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

// ParseMessageSuspended is a log parse operation binding the contract event 0xa3bf322f86f6b7b2fcb75744c1a9e22891ae257bbeb6b2a265627371e2651bcb.
//
// Solidity: event MessageSuspended(bytes32 msgHash, bool suspended, uint64 receivedAt)
func (_Bridge *BridgeFilterer) ParseMessageSuspended(log types.Log) (*BridgeMessageSuspended, error) {
	event := new(BridgeMessageSuspended)
	if err := _Bridge.contract.UnpackLog(event, "MessageSuspended", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BridgeOwnershipTransferStartedIterator is returned from FilterOwnershipTransferStarted and is used to iterate over the raw logs and unpacked data for OwnershipTransferStarted events raised by the Bridge contract.
type BridgeOwnershipTransferStartedIterator struct {
	Event *BridgeOwnershipTransferStarted // Event containing the contract specifics and raw log

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
func (it *BridgeOwnershipTransferStartedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BridgeOwnershipTransferStarted)
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
		it.Event = new(BridgeOwnershipTransferStarted)
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
func (it *BridgeOwnershipTransferStartedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BridgeOwnershipTransferStartedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BridgeOwnershipTransferStarted represents a OwnershipTransferStarted event raised by the Bridge contract.
type BridgeOwnershipTransferStarted struct {
	PreviousOwner common.Address
	NewOwner      common.Address
	Raw           types.Log // Blockchain specific contextual infos
}

// FilterOwnershipTransferStarted is a free log retrieval operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_Bridge *BridgeFilterer) FilterOwnershipTransferStarted(opts *bind.FilterOpts, previousOwner []common.Address, newOwner []common.Address) (*BridgeOwnershipTransferStartedIterator, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _Bridge.contract.FilterLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return &BridgeOwnershipTransferStartedIterator{contract: _Bridge.contract, event: "OwnershipTransferStarted", logs: logs, sub: sub}, nil
}

// WatchOwnershipTransferStarted is a free log subscription operation binding the contract event 0x38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e22700.
//
// Solidity: event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner)
func (_Bridge *BridgeFilterer) WatchOwnershipTransferStarted(opts *bind.WatchOpts, sink chan<- *BridgeOwnershipTransferStarted, previousOwner []common.Address, newOwner []common.Address) (event.Subscription, error) {

	var previousOwnerRule []interface{}
	for _, previousOwnerItem := range previousOwner {
		previousOwnerRule = append(previousOwnerRule, previousOwnerItem)
	}
	var newOwnerRule []interface{}
	for _, newOwnerItem := range newOwner {
		newOwnerRule = append(newOwnerRule, newOwnerItem)
	}

	logs, sub, err := _Bridge.contract.WatchLogs(opts, "OwnershipTransferStarted", previousOwnerRule, newOwnerRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BridgeOwnershipTransferStarted)
				if err := _Bridge.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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
func (_Bridge *BridgeFilterer) ParseOwnershipTransferStarted(log types.Log) (*BridgeOwnershipTransferStarted, error) {
	event := new(BridgeOwnershipTransferStarted)
	if err := _Bridge.contract.UnpackLog(event, "OwnershipTransferStarted", log); err != nil {
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

// BridgePausedIterator is returned from FilterPaused and is used to iterate over the raw logs and unpacked data for Paused events raised by the Bridge contract.
type BridgePausedIterator struct {
	Event *BridgePaused // Event containing the contract specifics and raw log

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
func (it *BridgePausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BridgePaused)
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
		it.Event = new(BridgePaused)
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
func (it *BridgePausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BridgePausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BridgePaused represents a Paused event raised by the Bridge contract.
type BridgePaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterPaused is a free log retrieval operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_Bridge *BridgeFilterer) FilterPaused(opts *bind.FilterOpts) (*BridgePausedIterator, error) {

	logs, sub, err := _Bridge.contract.FilterLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return &BridgePausedIterator{contract: _Bridge.contract, event: "Paused", logs: logs, sub: sub}, nil
}

// WatchPaused is a free log subscription operation binding the contract event 0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258.
//
// Solidity: event Paused(address account)
func (_Bridge *BridgeFilterer) WatchPaused(opts *bind.WatchOpts, sink chan<- *BridgePaused) (event.Subscription, error) {

	logs, sub, err := _Bridge.contract.WatchLogs(opts, "Paused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BridgePaused)
				if err := _Bridge.contract.UnpackLog(event, "Paused", log); err != nil {
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
func (_Bridge *BridgeFilterer) ParsePaused(log types.Log) (*BridgePaused, error) {
	event := new(BridgePaused)
	if err := _Bridge.contract.UnpackLog(event, "Paused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BridgeUnpausedIterator is returned from FilterUnpaused and is used to iterate over the raw logs and unpacked data for Unpaused events raised by the Bridge contract.
type BridgeUnpausedIterator struct {
	Event *BridgeUnpaused // Event containing the contract specifics and raw log

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
func (it *BridgeUnpausedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BridgeUnpaused)
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
		it.Event = new(BridgeUnpaused)
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
func (it *BridgeUnpausedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BridgeUnpausedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BridgeUnpaused represents a Unpaused event raised by the Bridge contract.
type BridgeUnpaused struct {
	Account common.Address
	Raw     types.Log // Blockchain specific contextual infos
}

// FilterUnpaused is a free log retrieval operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_Bridge *BridgeFilterer) FilterUnpaused(opts *bind.FilterOpts) (*BridgeUnpausedIterator, error) {

	logs, sub, err := _Bridge.contract.FilterLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return &BridgeUnpausedIterator{contract: _Bridge.contract, event: "Unpaused", logs: logs, sub: sub}, nil
}

// WatchUnpaused is a free log subscription operation binding the contract event 0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa.
//
// Solidity: event Unpaused(address account)
func (_Bridge *BridgeFilterer) WatchUnpaused(opts *bind.WatchOpts, sink chan<- *BridgeUnpaused) (event.Subscription, error) {

	logs, sub, err := _Bridge.contract.WatchLogs(opts, "Unpaused")
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BridgeUnpaused)
				if err := _Bridge.contract.UnpackLog(event, "Unpaused", log); err != nil {
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
func (_Bridge *BridgeFilterer) ParseUnpaused(log types.Log) (*BridgeUnpaused, error) {
	event := new(BridgeUnpaused)
	if err := _Bridge.contract.UnpackLog(event, "Unpaused", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}

// BridgeUpgradedIterator is returned from FilterUpgraded and is used to iterate over the raw logs and unpacked data for Upgraded events raised by the Bridge contract.
type BridgeUpgradedIterator struct {
	Event *BridgeUpgraded // Event containing the contract specifics and raw log

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
func (it *BridgeUpgradedIterator) Next() bool {
	// If the iterator failed, stop iterating
	if it.fail != nil {
		return false
	}
	// If the iterator completed, deliver directly whatever's available
	if it.done {
		select {
		case log := <-it.logs:
			it.Event = new(BridgeUpgraded)
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
		it.Event = new(BridgeUpgraded)
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
func (it *BridgeUpgradedIterator) Error() error {
	return it.fail
}

// Close terminates the iteration process, releasing any pending underlying
// resources.
func (it *BridgeUpgradedIterator) Close() error {
	it.sub.Unsubscribe()
	return nil
}

// BridgeUpgraded represents a Upgraded event raised by the Bridge contract.
type BridgeUpgraded struct {
	Implementation common.Address
	Raw            types.Log // Blockchain specific contextual infos
}

// FilterUpgraded is a free log retrieval operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_Bridge *BridgeFilterer) FilterUpgraded(opts *bind.FilterOpts, implementation []common.Address) (*BridgeUpgradedIterator, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _Bridge.contract.FilterLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return &BridgeUpgradedIterator{contract: _Bridge.contract, event: "Upgraded", logs: logs, sub: sub}, nil
}

// WatchUpgraded is a free log subscription operation binding the contract event 0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b.
//
// Solidity: event Upgraded(address indexed implementation)
func (_Bridge *BridgeFilterer) WatchUpgraded(opts *bind.WatchOpts, sink chan<- *BridgeUpgraded, implementation []common.Address) (event.Subscription, error) {

	var implementationRule []interface{}
	for _, implementationItem := range implementation {
		implementationRule = append(implementationRule, implementationItem)
	}

	logs, sub, err := _Bridge.contract.WatchLogs(opts, "Upgraded", implementationRule)
	if err != nil {
		return nil, err
	}
	return event.NewSubscription(func(quit <-chan struct{}) error {
		defer sub.Unsubscribe()
		for {
			select {
			case log := <-logs:
				// New log arrived, parse the event and forward to the user
				event := new(BridgeUpgraded)
				if err := _Bridge.contract.UnpackLog(event, "Upgraded", log); err != nil {
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
func (_Bridge *BridgeFilterer) ParseUpgraded(log types.Log) (*BridgeUpgraded, error) {
	event := new(BridgeUpgraded)
	if err := _Bridge.contract.UnpackLog(event, "Upgraded", log); err != nil {
		return nil, err
	}
	event.Raw = log
	return event, nil
}
