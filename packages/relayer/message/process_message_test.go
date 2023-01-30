package message

import (
	"context"
	"math/big"
	"testing"

	"github.com/pkg/errors"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/mock"
)

func Test_sendProcessMessageCall(t *testing.T) {
	p := newTestProcessor(true)

	_, err := p.sendProcessMessageCall(
		context.Background(),
		&bridge.BridgeMessageSent{
			Message: bridge.IBridgeMessage{
				DestChainId:   mock.MockChainID,
				ProcessingFee: new(big.Int).Add(mock.ProcessMessageTx.Cost(), big.NewInt(1)),
			},
		}, []byte{})

	assert.Nil(t, err)

	assert.Equal(t, p.destNonce, mock.PendingNonce)
}

func Test_ProcessMessage_messageNotReceived(t *testing.T) {
	p := newTestProcessor(true)

	err := p.ProcessMessage(context.Background(), &bridge.BridgeMessageSent{
		Message: bridge.IBridgeMessage{
			GasLimit: big.NewInt(1),
		},
	}, &relayer.Event{})
	assert.EqualError(t, err, "message not received")
}

func Test_ProcessMessage_gasLimit0(t *testing.T) {
	p := newTestProcessor(true)

	err := p.ProcessMessage(context.Background(), &bridge.BridgeMessageSent{}, &relayer.Event{})
	assert.EqualError(t, errors.New("only user can process this, gasLimit set to 0"), err.Error())
}

func Test_ProcessMessage_noChainId(t *testing.T) {
	p := newTestProcessor(true)

	err := p.ProcessMessage(context.Background(), &bridge.BridgeMessageSent{
		Message: bridge.IBridgeMessage{
			GasLimit: big.NewInt(1),
		},
		MsgHash: mock.SuccessMsgHash,
	}, &relayer.Event{})
	assert.EqualError(t, err, "p.sendProcessMessageCall: bind.NewKeyedTransactorWithChainID: no chain id specified")
}

func Test_ProcessMessage(t *testing.T) {
	p := newTestProcessor(true)

	err := p.ProcessMessage(context.Background(), &bridge.BridgeMessageSent{
		Message: bridge.IBridgeMessage{
			GasLimit:      big.NewInt(1),
			DestChainId:   mock.MockChainID,
			ProcessingFee: big.NewInt(1000000000),
		},
		MsgHash: mock.SuccessMsgHash,
	}, &relayer.Event{})

	assert.Nil(
		t,
		err,
	)
}

// func Test_ProcessMessage_unprofitable(t *testing.T) {
// 	p := newTestProcessor(true)

// 	err := p.ProcessMessage(context.Background(), &bridge.BridgeMessageSent{
// 		Message: bridge.IBridgeMessage{
// 			GasLimit:    big.NewInt(1),
// 			DestChainId: mock.MockChainID,
// 		},
// 		Signal: mock.SuccessMsgHash,
// 	}, &relayer.Event{})

// 	assert.EqualError(
// 		t,
// 		err,
// 		"p.sendProcessMessageCall: "+relayer.ErrUnprofitable.Error(),
// 	)
// }
