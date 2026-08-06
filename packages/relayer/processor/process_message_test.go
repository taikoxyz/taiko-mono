package processor

import (
	"context"
	"encoding/json"
	"errors"
	"math/big"
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/prometheus/client_golang/prometheus/testutil"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/taikol2"
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

// receiptTxManager is a mock.TxManager whose Send returns a fixed receipt,
// letting tests control the actual on-chain cost of a processed message.
type receiptTxManager struct {
	mock.TxManager
	receipt *types.Receipt
}

func (t *receiptTxManager) Send(ctx context.Context, candidate txmgr.TxCandidate) (*types.Receipt, error) {
	return t.receipt, nil
}

func messageProcessedLog(
	t *testing.T,
	message bridge.IBridgeMessage,
	stats bridge.BridgeProcessingStats,
) *types.Log {
	t.Helper()

	bridgeABI, err := bridge.BridgeMetaData.GetAbi()
	require.NoError(t, err)

	messageProcessed := bridgeABI.Events["MessageProcessed"]
	data, err := messageProcessed.Inputs.NonIndexed().Pack(message, stats)
	require.NoError(t, err)

	return &types.Log{
		Address: common.HexToAddress("0xC4279588B8dA563D264e286E2ee7CE8c244444d6"),
		Topics:  []common.Hash{messageProcessed.ID, common.Hash(mock.SuccessMsgHash)},
		Data:    data,
	}
}

func Test_sendProcessMessageCall_afterTransactingProfitability(t *testing.T) {
	newEvent := func(fee uint64) *bridge.BridgeMessageSent {
		return &bridge.BridgeMessageSent{
			MsgHash: mock.SuccessMsgHash,
			Message: bridge.IBridgeMessage{
				Id:          1,
				From:        common.HexToAddress("0xC4279588B8dA563D264e286E2ee7CE8c244444d6"),
				DestChainId: mock.MockChainID.Uint64(),
				SrcChainId:  mock.MockChainID.Uint64(),
				SrcOwner:    common.HexToAddress("0xC4279588B8dA563D264e286E2ee7CE8c244444d6"),
				DestOwner:   common.HexToAddress("0xC4279588B8dA563D264e286E2ee7CE8c244444d6"),
				To:          common.HexToAddress("0xC4279588B8dA563D264e286E2ee7CE8c244444d6"),
				Value:       big.NewInt(0),
				Fee:         fee,
				GasLimit:    100000,
				Data:        []byte{},
			},
			Raw: types.Log{
				Address: relayer.ZeroAddress,
				Topics: []common.Hash{
					relayer.ZeroHash,
				},
				Data: []byte{0xff},
			},
		}
	}

	tests := []struct {
		name              string
		fee               uint64
		baseFee           int64
		gasUsedInFeeCalc  uint32
		gasUsed           uint64
		effectiveGasPrice int64
		wantProfitable    bool
	}{
		{
			// The actual cost exceeds the pre-send estimate, but the Bridge's
			// 1_500_000 wei relayer payout covers it.
			name:              "relayer fee covers actual cost",
			fee:               200_000_000,
			baseFee:           1_000,
			gasUsedInFeeCalc:  1_000,
			gasUsed:           1_500,
			effectiveGasPrice: 1_000,
			wantProfitable:    true,
		},
		{
			// The Bridge pays (maxFee + baseFee) / 2 =
			// (1_000_000 + 100_000) / 2 = 550_000 wei. That is less than
			// the 1_000_000 wei transaction cost even though the fee cap covers it.
			name:              "fee cap covers actual cost but relayer fee does not",
			fee:               100_000_000,
			baseFee:           100,
			gasUsedInFeeCalc:  1_000,
			gasUsed:           1_000,
			effectiveGasPrice: 1_000,
			wantProfitable:    false,
		},
		{
			// The transaction cost is larger than uint64. It must remain
			// unprofitable instead of wrapping below the relayer fee.
			name:              "actual cost exceeds uint64",
			fee:               ^uint64(0),
			baseFee:           1,
			gasUsedInFeeCalc:  ^uint32(0),
			gasUsed:           ^uint64(0),
			effectiveGasPrice: 2,
			wantProfitable:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			event := newEvent(tt.fee)
			receipt := &types.Receipt{
				Status:            types.ReceiptStatusSuccessful,
				GasUsed:           tt.gasUsed,
				EffectiveGasPrice: big.NewInt(tt.effectiveGasPrice),
				BlockNumber:       big.NewInt(1),
			}
			receipt.Logs = []*types.Log{messageProcessedLog(t, event.Message, bridge.BridgeProcessingStats{
				GasUsedInFeeCalc:   tt.gasUsedInFeeCalc,
				ProcessedByRelayer: true,
			})}

			p := newTestProcessor(true)
			p.destEthClient = &blockByNumberEthClient{
				EthClient: &mock.EthClient{},
				block:     processorBlockWithBaseFee(big.NewInt(tt.baseFee)),
			}
			p.txmgr = &receiptTxManager{receipt: receipt}

			profBefore := testutil.ToFloat64(relayer.ProfitableMessageAfterTransacting)
			unprofBefore := testutil.ToFloat64(relayer.UnprofitableMessageAfterTransacting)

			_, err := p.sendProcessMessageCall(context.Background(), 1, event, []byte{})
			require.NoError(t, err)

			profDelta := testutil.ToFloat64(relayer.ProfitableMessageAfterTransacting) - profBefore
			unprofDelta := testutil.ToFloat64(relayer.UnprofitableMessageAfterTransacting) - unprofBefore

			if tt.wantProfitable {
				assert.Equal(t, float64(1), profDelta)
				assert.Equal(t, float64(0), unprofDelta)
			} else {
				assert.Equal(t, float64(0), profDelta)
				assert.Equal(t, float64(1), unprofDelta)
			}
		})
	}
}

func TestGetBaseFee_Layer2UsesHeaderBaseFee(t *testing.T) {
	p := newTestProcessor(false)
	p.taikoL2 = &taikol2.TaikoL2{}
	p.destEthClient = &blockByNumberEthClient{
		EthClient: &mock.EthClient{},
		block:     processorBlockWithBaseFee(big.NewInt(123)),
	}

	got, err := p.getBaseFee(context.Background())

	assert.NoError(t, err)
	assert.Equal(t, big.NewInt(123), got)
}

func TestGetBaseFee_Layer2MissingBaseFeeFails(t *testing.T) {
	p := newTestProcessor(false)
	p.taikoL2 = &taikol2.TaikoL2{}
	p.destEthClient = &blockByNumberEthClient{EthClient: &mock.EthClient{}, block: processorBlockWithBaseFee(nil)}

	got, err := p.getBaseFee(context.Background())

	assert.Nil(t, got)
	assert.ErrorIs(t, err, relayer.ErrMissingDestBaseFee)
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

type blockByNumberEthClient struct {
	*mock.EthClient
	block *types.Block
}

func (c *blockByNumberEthClient) BlockByNumber(ctx context.Context, number *big.Int) (*types.Block, error) {
	return c.block, nil
}

func processorBlockWithBaseFee(baseFee *big.Int) *types.Block {
	header := *mock.Header
	header.BaseFee = baseFee

	return types.NewBlockWithHeader(&header)
}
