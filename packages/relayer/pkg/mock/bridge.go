package mock

import (
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
)

var (
	SuccessMsgHash = [32]byte{0x1}
	SuccessId      = big.NewInt(1)
	FailSignal     = [32]byte{0x2}
)

var dummyAddress = "0x63FaC9201494f0bd17B9892B9fae4d52fe3BD377"

var ProcessMessageTx = types.NewTransaction(
	PendingNonce,
	common.HexToAddress(dummyAddress),
	big.NewInt(1),
	100,
	big.NewInt(10),
	nil,
)

type Bridge struct {
}

func (b *Bridge) SuspendMessages(
	opts *bind.TransactOpts,
	_msgHashes [][32]byte,
	_toSuspend bool,
) (*types.Transaction, error) {
	return ProcessMessageTx, nil
}

func (b *Bridge) IsMessageSent(opts *bind.CallOpts, _message bridge.IBridgeMessage) (bool, error) {
	return false, nil
}

func (b *Bridge) GetInvocationDelays(opts *bind.CallOpts) (*big.Int, *big.Int, error) {
	return common.Big0, common.Big0, nil
}
func (b *Bridge) ProofReceipt(opts *bind.CallOpts, msgHash [32]byte) (struct {
	ReceivedAt        uint64
	PreferredExecutor common.Address
}, error) {
	return struct {
		ReceivedAt        uint64
		PreferredExecutor common.Address
	}{
		ReceivedAt:        0,
		PreferredExecutor: relayer.ZeroAddress,
	}, nil
}

func (b *Bridge) FilterMessageReceived(
	opts *bind.FilterOpts,
	msgHash [][32]byte,
) (*bridge.BridgeMessageReceivedIterator, error) {
	return &bridge.BridgeMessageReceivedIterator{}, nil
}

func (b *Bridge) FilterMessageSent(
	opts *bind.FilterOpts,
	signal [][32]byte,
) (*bridge.BridgeMessageSentIterator, error) {
	return &bridge.BridgeMessageSentIterator{}, nil
}

func (b *Bridge) FilterMessageStatusChanged(
	opts *bind.FilterOpts,
	signal [][32]byte,
) (*bridge.BridgeMessageStatusChangedIterator, error) {
	return &bridge.BridgeMessageStatusChangedIterator{}, nil
}

func (b *Bridge) MessageStatus(opts *bind.CallOpts, msgHash [32]byte) (uint8, error) {
	if msgHash == SuccessMsgHash {
		return uint8(relayer.EventStatusNew), nil
	}

	if msgHash == FailSignal {
		return uint8(relayer.EventStatusFailed), nil
	}

	return uint8(relayer.EventStatusDone), nil
}

func (b *Bridge) ProcessMessage(
	opts *bind.TransactOpts,
	_message bridge.IBridgeMessage,
	_proof []byte,
) (*types.Transaction, error) {
	return ProcessMessageTx, nil
}

func (b *Bridge) ParseMessageSent(log types.Log) (*bridge.BridgeMessageSent, error) {
	return &bridge.BridgeMessageSent{}, nil
}

func (b *Bridge) SendMessage(opts *bind.TransactOpts, _message bridge.IBridgeMessage) (*types.Transaction, error) {
	return ProcessMessageTx, nil
}

func (b *Bridge) IsMessageReceived(opts *bind.CallOpts, _message bridge.IBridgeMessage, _proof []byte) (bool, error) {
	return true, nil
}
