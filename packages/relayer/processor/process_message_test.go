package processor

import (
	"context"
	"encoding/json"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/pkg/errors"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/mock"
	"github.com/taikoxyz/taiko-mono/packages/relayer/queue"
)

func Test_sendProcessMessageCall(t *testing.T) {
	// since we're padding the estimateGas, the cost is also padded atm;
	// need to turn profitableOnly off to pass
	p := newTestProcessor(false)

	_, err := p.sendProcessMessageCall(
		context.Background(),
		&bridge.BridgeMessageSent{
			Message: bridge.IBridgeMessage{
				DestChainId: mock.MockChainID,
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
	body := &queue.QueueMessageBody{
		Event: &bridge.BridgeMessageSent{
			Message: bridge.IBridgeMessage{
				GasLimit: big.NewInt(1),
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

	err = p.processMessage(context.Background(), msg)
	assert.EqualError(t, err, "message is unprocessable")
}

func Test_ProcessMessage_gasLimit0(t *testing.T) {
	p := newTestProcessor(true)

	body := queue.QueueMessageBody{
		Event: &bridge.BridgeMessageSent{
			Message: bridge.IBridgeMessage{
				GasLimit: big.NewInt(0),
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

	err = p.processMessage(context.Background(), msg)
	assert.EqualError(t, errors.New("only user can process this, gasLimit set to 0"), err.Error())
}

func Test_ProcessMessage_noChainId(t *testing.T) {
	p := newTestProcessor(true)

	body := queue.QueueMessageBody{
		Event: &bridge.BridgeMessageSent{
			Message: bridge.IBridgeMessage{
				GasLimit: big.NewInt(1),
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

	err = p.processMessage(context.Background(), msg)
	assert.EqualError(t, err, "bind.NewKeyedTransactorWithChainID: no chain id specified")
}

func Test_ProcessMessage(t *testing.T) {
	p := newTestProcessor(true)

	body := queue.QueueMessageBody{
		Event: &bridge.BridgeMessageSent{
			Message: bridge.IBridgeMessage{
				GasLimit:    big.NewInt(1),
				DestChainId: mock.MockChainID,
				Fee:         big.NewInt(1000000000),
				SrcChainId:  mock.MockChainID,
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

	err = p.processMessage(context.Background(), msg)

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
