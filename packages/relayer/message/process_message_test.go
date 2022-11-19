package message

import (
	"context"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/pkg/errors"
	"github.com/stretchr/testify/assert"
	"github.com/taikochain/taiko-mono/packages/relayer"
	"github.com/taikochain/taiko-mono/packages/relayer/contracts"
	"github.com/taikochain/taiko-mono/packages/relayer/mock"
)

func Test_getLatestNonce(t *testing.T) {
	p := newTestProcessor()

	err := p.getLatestNonce(context.Background(), &bind.TransactOpts{})
	assert.Nil(t, err)

	assert.Equal(t, p.destNonce, mock.PendingNonce)
}

func Test_waitForConfirmations(t *testing.T) {
	p := newTestProcessor()

	err := p.waitForConfirmations(context.TODO(), mock.SucceedTxHash, uint64(mock.BlockNum))
	assert.Nil(t, err)
}

func Test_sendProcessMessageCall(t *testing.T) {
	p := newTestProcessor()

	_, err := p.sendProcessMessageCall(
		context.Background(),
		&contracts.BridgeMessageSent{
			Message: contracts.IBridgeMessage{
				DestChainId: mock.MockChainID,
			},
		}, []byte{})

	assert.Nil(t, err)

	assert.Equal(t, p.destNonce, mock.PendingNonce)
}

func Test_ProcessMessage_messageNotReceived(t *testing.T) {
	p := newTestProcessor()

	err := p.ProcessMessage(context.Background(), &contracts.BridgeMessageSent{
		Message: contracts.IBridgeMessage{
			GasLimit: big.NewInt(1),
		},
	}, &relayer.Event{})
	assert.EqualError(t, err, "message not received")
}

func Test_ProcessMessage_gasLimit0(t *testing.T) {
	p := newTestProcessor()

	err := p.ProcessMessage(context.Background(), &contracts.BridgeMessageSent{}, &relayer.Event{})
	assert.EqualError(t, errors.New("only user can process this, gasLimit set to 0"), err.Error())
}

func Test_ProcessMessage_noChainId(t *testing.T) {
	p := newTestProcessor()

	err := p.ProcessMessage(context.Background(), &contracts.BridgeMessageSent{
		Message: contracts.IBridgeMessage{
			GasLimit: big.NewInt(1),
		},
		Signal: mock.SuccessSignal,
	}, &relayer.Event{})
	assert.EqualError(t, err, "p.sendProcessMessageCall: bind.NewKeyedTransactorWithChainID: no chain id specified")
}

func Test_ProcessMessage(t *testing.T) {
	p := newTestProcessor()

	err := p.ProcessMessage(context.Background(), &contracts.BridgeMessageSent{
		Message: contracts.IBridgeMessage{
			GasLimit:    big.NewInt(1),
			DestChainId: mock.MockChainID,
		},
		Signal: mock.SuccessSignal,
	}, &relayer.Event{})

	assert.Nil(
		t,
		err,
	)
}
