package processor

import (
	"context"
	"encoding/json"
	"errors"
	"math/big"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/proof"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
)

func Test_sendProcessMessageCall(t *testing.T) {
	p := newTestProcessor(false)

	_, err := p.sendProcessMessageCall(
		context.Background(),
		1,
		&bridge.BridgeMessageSent{
			Message: bridge.IBridgeMessage{
				Id:          1,
				From:        common.HexToAddress("0xC4279588B8dA563D264e286E2ee7CE8c244444d6"),
				DestChainId: mock.MockChainID.Uint64(),
				SrcChainId:  mock.MockChainID.Uint64(),
				SrcOwner:    common.HexToAddress("0xC4279588B8dA563D264e286E2ee7CE8c244444d6"),
				DestOwner:   common.HexToAddress("0xC4279588B8dA563D264e286E2ee7CE8c244444d6"),
				To:          common.HexToAddress("0xC4279588B8dA563D264e286E2ee7CE8c244444d6"),
				Value:       big.NewInt(0),
				Fee:         mock.ProcessMessageTx.Cost().Uint64() + 1,
				GasLimit:    1,
				Data:        []byte{},
			},
			Raw: types.Log{
				Address: relayer.ZeroAddress,
				Topics: []common.Hash{
					relayer.ZeroHash,
				},
				Data: []byte{0xff},
			},
		}, []byte{})

	assert.Equal(t, err, errUnprocessable)
}

func TestSaveMessageStatusChangedEventSkipsLogsWithoutTopics(t *testing.T) {
	p := newTestProcessor(false)

	err := p.saveMessageStatusChangedEvent(
		context.Background(),
		&types.Receipt{
			TxHash: relayer.ZeroHash,
			Logs: []*types.Log{
				{},
			},
		},
		&bridge.BridgeMessageSent{
			Message: bridge.IBridgeMessage{
				SrcChainId:  mock.MockChainID.Uint64(),
				DestChainId: mock.MockChainID.Uint64(),
				SrcOwner:    common.HexToAddress("0xC4279588B8dA563D264e286E2ee7CE8c244444d6"),
			},
			MsgHash: relayer.ZeroHash,
			Raw: types.Log{
				BlockNumber: 1,
			},
		},
	)

	assert.Nil(t, err)
}

func Test_ProcessMessage_messageUnprocessable(t *testing.T) {
	p := newTestProcessor(true)
	body := &queue.QueueMessageSentBody{
		Event: &bridge.BridgeMessageSent{
			Message: bridge.IBridgeMessage{
				GasLimit:   1,
				SrcChainId: mock.MockChainID.Uint64(),
				Id:         1,
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

	shouldRequeue, _, err := p.processMessage(context.Background(), msg)

	assert.Nil(t, err)

	assert.Equal(t, false, shouldRequeue)
}

func Test_ProcessMessage_unprofitable(t *testing.T) {
	p := newTestProcessor(true)

	body := queue.QueueMessageSentBody{
		Event: &bridge.BridgeMessageSent{
			Message: bridge.IBridgeMessage{
				Id:          1,
				From:        common.HexToAddress("0xC4279588B8dA563D264e286E2ee7CE8c244444d6"),
				DestChainId: mock.MockChainID.Uint64(),
				SrcChainId:  mock.MockChainID.Uint64(),
				SrcOwner:    common.HexToAddress("0xC4279588B8dA563D264e286E2ee7CE8c244444d6"),
				DestOwner:   common.HexToAddress("0xC4279588B8dA563D264e286E2ee7CE8c244444d6"),
				To:          common.HexToAddress("0xC4279588B8dA563D264e286E2ee7CE8c244444d6"),
				Value:       big.NewInt(0),
				GasLimit:    600000,
				Fee:         1,
				Data:        []byte{},
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

	shouldRequeue, _, err := p.processMessage(context.Background(), msg)

	assert.Equal(
		t,
		err,
		relayer.ErrUnprofitable,
	)

	assert.False(t, shouldRequeue)
}

func TestGenerateEncodedSignalProofUsesDestChainCheckpoint(t *testing.T) {
	const (
		srcChainID  = uint64(1)
		destChainID = uint64(2)
	)

	repo := mock.NewEventRepository()
	repo.LatestCheckpointSyncedEventFunc = func(
		ctx context.Context,
		chainID uint64,
		syncedChainID uint64,
	) (uint64, error) {
		if chainID != destChainID || syncedChainID != srcChainID {
			return 0, errors.New("unexpected chain IDs")
		}

		return 10, nil
	}

	ethClient := &mock.EthClient{}
	prover, err := proof.New(ethClient)
	assert.Nil(t, err)

	p := &Processor{
		eventRepo:               repo,
		srcChainId:              big.NewInt(int64(srcChainID)),
		destChainId:             big.NewInt(int64(destChainID)),
		srcEthClient:            ethClient,
		srcCaller:               &mock.Caller{},
		prover:                  prover,
		srcSignalService:        &mock.SignalService{},
		srcSignalServiceAddress: common.HexToAddress("0x0000000000000000000000000000000000000001"),
		ethClientTimeout:        time.Second,
	}

	event := &bridge.BridgeMessageSent{
		MsgHash: [32]byte{0x01},
		Message: bridge.IBridgeMessage{
			SrcChainId:  srcChainID,
			DestChainId: destChainID,
			From:        common.HexToAddress("0x0000000000000000000000000000000000000002"),
			SrcOwner:    common.HexToAddress("0x0000000000000000000000000000000000000002"),
			DestOwner:   common.HexToAddress("0x0000000000000000000000000000000000000002"),
			To:          common.HexToAddress("0x0000000000000000000000000000000000000002"),
			GasLimit:    1,
		},
		Raw: types.Log{
			Address:     common.HexToAddress("0x0000000000000000000000000000000000000003"),
			BlockNumber: 1,
		},
	}

	_, err = p.generateEncodedSignalProof(context.Background(), event)
	assert.Nil(t, err)
}
