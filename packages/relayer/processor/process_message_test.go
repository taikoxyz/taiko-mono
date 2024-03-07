package processor

import (
	"context"
	"encoding/json"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
)

func Test_sendProcessMessageCall(t *testing.T) {
	// since we're padding the estimateGas, the cost is also padded atm;
	// need to turn profitableOnly off to pass
	p := newTestProcessor(false)

	_, err := p.sendProcessMessageCall(
		context.Background(),
		&bridge.BridgeMessageSent{
			Message: bridge.IBridgeMessage{
				DestChainId: mock.MockChainID.Uint64(),
				SrcChainId:  mock.MockChainID.Uint64(),
				Id:          big.NewInt(1),
				Fee:         new(big.Int).Add(mock.ProcessMessageTx.Cost(), big.NewInt(1)),
			},
			Raw: types.Log{
				Address: relayer.ZeroAddress,
				Topics: []common.Hash{
					relayer.ZeroHash,
				},
				Data: []byte{0xff},
			},
		}, []byte{})

	assert.Nil(t, err)

	assert.Equal(t, p.destNonce, mock.PendingNonce)
}

func Test_ProcessMessage_messageUnprocessable(t *testing.T) {
	p := newTestProcessor(true)
	body := &queue.QueueMessageSentBody{
		Event: &bridge.BridgeMessageSent{
			Message: bridge.IBridgeMessage{
				GasLimit:   big.NewInt(1),
				SrcChainId: mock.MockChainID.Uint64(),
				Id:         big.NewInt(1),
			},
			Raw: types.Log{
				Address: relayer.ZeroAddress,
				Topics: []common.Hash{
					relayer.ZeroHash,
				},
				Data: []byte{0xff},
			},
		},
		ID: 0,
	}

	marshalled, err := json.Marshal(body)
	assert.Nil(t, err)

	msg := queue.Message{
		Body: marshalled,
	}

	shouldRequeue, err := p.processMessage(context.Background(), msg)

	assert.Nil(t, nil)

	assert.Equal(t, false, shouldRequeue)
}

func Test_ProcessMessage_noChainId(t *testing.T) {
	p := newTestProcessor(true)

	body := queue.QueueMessageSentBody{
		Event: &bridge.BridgeMessageSent{
			Message: bridge.IBridgeMessage{
				SrcChainId: mock.MockChainID.Uint64(),
				GasLimit:   big.NewInt(1),
				Id:         big.NewInt(0),
			},
			MsgHash: mock.SuccessMsgHash,
			Raw: types.Log{
				Address: relayer.ZeroAddress,
				Topics: []common.Hash{
					relayer.ZeroHash,
				},
				Data: []byte{0xff},
			},
		},
		ID: 0,
	}

	marshalled, err := json.Marshal(body)
	assert.Nil(t, err)

	msg := queue.Message{
		Body: marshalled,
	}

	shouldRequeue, err := p.processMessage(context.Background(), msg)

	assert.EqualError(t, err, "p.generateEncodedSignalProof: message not received")

	assert.False(t, shouldRequeue)
}

func Test_ProcessMessage(t *testing.T) {
	p := newTestProcessor(true)

	body := queue.QueueMessageSentBody{
		Event: &bridge.BridgeMessageSent{
			Message: bridge.IBridgeMessage{
				GasLimit:    big.NewInt(1),
				DestChainId: mock.MockChainID.Uint64(),
				Fee:         big.NewInt(1000000000),
				SrcChainId:  mock.MockChainID.Uint64(),
				Id:          big.NewInt(1),
			},
			MsgHash: mock.SuccessMsgHash,
			Raw: types.Log{
				Address: relayer.ZeroAddress,
				Topics: []common.Hash{
					relayer.ZeroHash,
				},
				Data: []byte{0xff},
			},
		},
		ID: 0,
	}

	marshalled, err := json.Marshal(body)
	assert.Nil(t, err)

	msg := queue.Message{
		Body: marshalled,
	}

	shouldRequeue, err := p.processMessage(context.Background(), msg)

	assert.Nil(
		t,
		err,
	)

	assert.False(t, shouldRequeue)
}
