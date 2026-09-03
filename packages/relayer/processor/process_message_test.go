package processor

import (
	"context"
	"encoding/json"
	"errors"
	"math/big"
	"strings"
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
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
func newProcessMessageEvent(fee uint64) *bridge.BridgeMessageSent {
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

func Test_sendProcessMessageCall_afterTransactingProfitability(t *testing.T) {
	tests := []struct {
		name                  string
		fee                   uint64
		latestBaseFee         int64
		canonicalBlockBaseFee int64
		receiptBlockBaseFee   int64
		gasUsedInFeeCalc      uint32
		gasUsed               uint64
		effectiveGasPrice     int64
		wantProfitable        bool
	}{
		{
			// The actual cost exceeds the pre-send estimate, but the Bridge's
			// 1_500_000 wei relayer payout covers it.
			name:                  "relayer fee covers actual cost",
			fee:                   200_000_000,
			latestBaseFee:         1_000,
			canonicalBlockBaseFee: 1_000,
			receiptBlockBaseFee:   1_000,
			gasUsedInFeeCalc:      1_000,
			gasUsed:               1_500,
			effectiveGasPrice:     1_000,
			wantProfitable:        true,
		},
		{
			// The Bridge pays (maxFee + baseFee) / 2 =
			// (1_000_000 + 100_000) / 2 = 550_000 wei. That is less than
			// the 1_000_000 wei transaction cost even though the fee cap covers it.
			// The canonical block at the same number has a different base fee,
			// modeling a reorg between receipt retrieval and profitability evaluation.
			name:                  "fee cap covers actual cost but relayer fee does not",
			fee:                   100_000_000,
			latestBaseFee:         100,
			canonicalBlockBaseFee: 1_000,
			receiptBlockBaseFee:   100,
			gasUsedInFeeCalc:      1_000,
			gasUsed:               1_000,
			effectiveGasPrice:     1_000,
			wantProfitable:        false,
		},
		{
			// The transaction cost is larger than uint64. It must remain
			// unprofitable instead of wrapping below the relayer fee.
			name:                  "actual cost exceeds uint64",
			fee:                   ^uint64(0),
			latestBaseFee:         1,
			canonicalBlockBaseFee: 1,
			receiptBlockBaseFee:   1,
			gasUsedInFeeCalc:      ^uint32(0),
			gasUsed:               ^uint64(0),
			effectiveGasPrice:     2,
			wantProfitable:        false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			event := newProcessMessageEvent(tt.fee)
			receiptBlockHash := common.HexToHash("0x1234")
			receipt := &types.Receipt{
				Status:            types.ReceiptStatusSuccessful,
				GasUsed:           tt.gasUsed,
				EffectiveGasPrice: big.NewInt(tt.effectiveGasPrice),
				BlockHash:         receiptBlockHash,
				BlockNumber:       big.NewInt(1),
			}
			receipt.Logs = []*types.Log{messageProcessedLog(t, event.Message, bridge.BridgeProcessingStats{
				GasUsedInFeeCalc:   tt.gasUsedInFeeCalc,
				ProcessedByRelayer: true,
			})}

			p := newTestProcessor(true)
			p.destEthClient = &profitabilityEthClient{
				EthClient:        &mock.EthClient{},
				receiptBlockHash: receiptBlockHash,
				latestBlock: processorBlockWithBaseFee(
					big.NewInt(tt.latestBaseFee),
				),
				canonicalBlock: processorBlockWithBaseFee(
					big.NewInt(tt.canonicalBlockBaseFee),
				),
				receiptBlockHeader: processorHeaderWithBaseFee(
					big.NewInt(tt.receiptBlockBaseFee),
				),
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

func Test_sendProcessMessageCall_afterTransactingProfitabilityEvaluationErrors(t *testing.T) {
	tests := []struct {
		name              string
		effectiveGasPrice *big.Int
	}{
		{
			name: "missing effective gas price",
		},
		{
			name:              "missing MessageProcessed event",
			effectiveGasPrice: big.NewInt(1),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			p := newTestProcessor(true)
			p.txmgr = &receiptTxManager{receipt: &types.Receipt{
				Status:            types.ReceiptStatusSuccessful,
				GasUsed:           1,
				EffectiveGasPrice: tt.effectiveGasPrice,
			}}

			before := testutil.ToFloat64(relayer.AfterTransactingProfitabilityEvaluationErrors)

			_, err := p.sendProcessMessageCall(
				context.Background(),
				1,
				newProcessMessageEvent(100_000_000),
				[]byte{},
			)
			require.NoError(t, err)

			after := testutil.ToFloat64(relayer.AfterTransactingProfitabilityEvaluationErrors)
			assert.Equal(t, float64(1), after-before)
		})
	}
}

func Test_sendProcessMessageCall_afterTransactingProfitabilitySkipsNilReceiptLogs(t *testing.T) {
	p := newTestProcessor(true)
	p.txmgr = &receiptTxManager{receipt: &types.Receipt{
		Status:            types.ReceiptStatusSuccessful,
		GasUsed:           1,
		EffectiveGasPrice: big.NewInt(1),
		Logs:              []*types.Log{nil},
	}}

	before := testutil.ToFloat64(relayer.AfterTransactingProfitabilityEvaluationErrors)

	_, err := p.sendProcessMessageCall(
		context.Background(),
		1,
		newProcessMessageEvent(100_000_000),
		[]byte{},
	)
	require.NoError(t, err)

	after := testutil.ToFloat64(relayer.AfterTransactingProfitabilityEvaluationErrors)
	assert.Equal(t, float64(1), after-before)
}

func Test_relayerFeeFromReceipt_timesOutHeaderLookup(t *testing.T) {
	event := newProcessMessageEvent(100_000_000)
	receipt := &types.Receipt{
		BlockHash: common.HexToHash("0x1234"),
		Logs: []*types.Log{messageProcessedLog(t, event.Message, bridge.BridgeProcessingStats{
			GasUsedInFeeCalc:   1,
			ProcessedByRelayer: true,
		})},
	}

	p := newTestProcessor(true)
	p.ethClientTimeout = 10 * time.Millisecond
	p.destEthClient = &blockingHeaderEthClient{EthClient: &mock.EthClient{}}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	watchdog := time.AfterFunc(250*time.Millisecond, cancel)
	defer watchdog.Stop()

	_, err := p.relayerFeeFromReceipt(ctx, receipt, event)
	require.ErrorIs(t, err, context.DeadlineExceeded)
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

type profitabilityEthClient struct {
	*mock.EthClient
	latestBlock        *types.Block
	canonicalBlock     *types.Block
	receiptBlockHash   common.Hash
	receiptBlockHeader *types.Header
}

type blockingHeaderEthClient struct {
	*mock.EthClient
}

func (c *blockingHeaderEthClient) HeaderByHash(ctx context.Context, hash common.Hash) (*types.Header, error) {
	<-ctx.Done()

	return nil, ctx.Err()
}

func (c *profitabilityEthClient) BlockByNumber(ctx context.Context, number *big.Int) (*types.Block, error) {
	if number == nil {
		return c.latestBlock, nil
	}

	return c.canonicalBlock, nil
}

func (c *profitabilityEthClient) HeaderByHash(ctx context.Context, hash common.Hash) (*types.Header, error) {
	if hash != c.receiptBlockHash {
		return nil, errors.New("unexpected receipt block hash")
	}

	return c.receiptBlockHeader, nil
}

func (c *blockByNumberEthClient) BlockByNumber(ctx context.Context, number *big.Int) (*types.Block, error) {
	return c.block, nil
}

func processorBlockWithBaseFee(baseFee *big.Int) *types.Block {
	return types.NewBlockWithHeader(processorHeaderWithBaseFee(baseFee))
}

func processorHeaderWithBaseFee(baseFee *big.Int) *types.Header {
	header := *mock.Header
	header.BaseFee = baseFee

	return &header
}

// msgStatusErrBridge fails the message status read, as an unreachable destination node would.
type msgStatusErrBridge struct {
	mock.Bridge
	err error
}

func (b *msgStatusErrBridge) MessageStatus(_ *bind.CallOpts, _ [32]byte) (uint8, error) {
	return 0, b.err
}

func Test_eventStatusFromMsgHash(t *testing.T) {
	p := newTestProcessor(false)

	status, err := p.eventStatusFromMsgHash(context.Background(), mock.SuccessMsgHash)

	require.NoError(t, err)
	assert.Equal(t, relayer.EventStatusNew, status)
}

func Test_eventStatusFromMsgHashReturnsTheCallError(t *testing.T) {
	p := newTestProcessor(false)
	p.destBridge = &msgStatusErrBridge{err: errors.New("dial tcp: connect: connection refused")}

	// An unreadable status must not read as EventStatusNew, which is the value a zero would give:
	// that would send a claim for a message that may already be processed.
	status, err := p.eventStatusFromMsgHash(context.Background(), mock.SuccessMsgHash)

	require.ErrorContains(t, err, "svc.destBridge.MessageStatus")
	assert.Equal(t, relayer.EventStatus(0), status)
}

// blockErrClient fails the block lookup the base fee is derived from.
type blockErrClient struct {
	mock.EthClient
}

func (c *blockErrClient) BlockByNumber(_ context.Context, _ *big.Int) (*types.Block, error) {
	return nil, errors.New("dial tcp: connect: connection refused")
}

func Test_getBaseFeeReturnsTheBlockError(t *testing.T) {
	p := newTestProcessor(false)
	p.destEthClient = &blockErrClient{}

	baseFee, err := p.getBaseFee(context.Background())

	require.ErrorContains(t, err, "connection refused")
	assert.Nil(t, baseFee)
}

func Test_relayerFeeFromReceiptIgnoresUnrelatedLogs(t *testing.T) {
	p := newTestProcessor(false)

	// Logs from another contract, or for another message, must not be decoded as this claim's
	// MessageProcessed event: the fee that comes out drives the profitability accounting.
	receipt := &types.Receipt{
		Logs: []*types.Log{
			nil,
			{Address: common.HexToAddress("0xdead"), Topics: []common.Hash{{}, {}}},
			{Address: p.cfg.DestBridgeAddress, Topics: []common.Hash{{}}},
		},
	}

	fee, err := p.relayerFeeFromReceipt(
		context.Background(),
		receipt,
		&bridge.BridgeMessageSent{MsgHash: [32]byte{1}},
	)

	require.Error(t, err)
	assert.Nil(t, fee)
}

// balanceErrClient fails the balance read the relayer gauge is fed from.
type balanceErrClient struct {
	mock.EthClient
}

func (c *balanceErrClient) BalanceAt(_ context.Context, _ common.Address, _ *big.Int) (*big.Int, error) {
	return nil, errors.New("dial tcp: connect: connection refused")
}

func Test_logRelayerBalanceToleratesAFailedRead(t *testing.T) {
	p := newTestProcessor(false)
	p.destEthClient = &balanceErrClient{}

	before := testutil.ToFloat64(relayer.RelayerKeyBalanceGauge)

	// The balance is only reported, never acted on, so a node that will not answer must not stop
	// the claim that triggered the read.
	assert.NotPanics(t, func() { p.logRelayerBalance(context.Background()) })

	assert.Equal(t, before, testutil.ToFloat64(relayer.RelayerKeyBalanceGauge),
		"a failed read must not publish a stale or zero balance")
}

func Test_saveMessageStatusChangedEventSkipsAReceiptWithoutTheEvent(t *testing.T) {
	repo := mock.NewEventRepository()
	p := newTestProcessor(false)
	p.eventRepo = repo

	// Nothing in this receipt is a MessageStatusChanged, so there is no status to record. Saving
	// anything here would put a row with a zero status into the event table.
	receipt := &types.Receipt{
		TxHash: common.HexToHash("0xabc"),
		Logs: []*types.Log{
			nil,
			{Topics: []common.Hash{}},
			{Topics: []common.Hash{common.HexToHash("0xdead")}},
		},
	}

	err := p.saveMessageStatusChangedEvent(context.Background(), receipt, &bridge.BridgeMessageSent{
		Message: bridge.IBridgeMessage{SrcChainId: 1, DestChainId: 2},
	})

	require.NoError(t, err)
	assert.Equal(t, 0, repo.SavedCount())
}

// singleReceiptClient returns a receipt whose logs the test controls.
type singleReceiptClient struct {
	mock.EthClient
	receipt *types.Receipt
}

func (c *singleReceiptClient) TransactionReceipt(
	_ context.Context,
	_ common.Hash,
) (*types.Receipt, error) {
	return c.receipt, nil
}

func Test_processSingleSkipsLogsThatAreNotMessageSent(t *testing.T) {
	p := newTestProcessor(false)

	txHash := mock.SucceedTxHash
	p.targetTxHash = &txHash
	p.srcEthClient = &singleReceiptClient{receipt: &types.Receipt{
		Logs: []*types.Log{
			{Topics: []common.Hash{}},
			{Topics: []common.Hash{common.HexToHash("0xdead")}},
		},
	}}

	// A targeted transaction that emitted no MessageSent has nothing to claim, and that is a
	// clean outcome rather than an error.
	assert.NoError(t, p.processSingle(context.Background()))
}

// The row the processor writes for its own claim used to carry nothing but the transaction
// hash. The API reads the claimer off a MessageStatusChanged row through the block it was
// mined in, and this row is the first one it finds for any message the relayer claimed, so
// those messages came back with no claimer at all. The whole log is stored now, in the shape
// the indexer stores it, and keyed the way the indexer keys it, so the two writers' rows for
// one message are one series.
func Test_saveMessageStatusChangedEventStoresTheWholeLog(t *testing.T) {
	repo := mock.NewEventRepository()
	p := newTestProcessor(false)
	p.eventRepo = repo

	bridgeAbi, err := abi.JSON(strings.NewReader(bridge.BridgeABI))
	require.NoError(t, err)

	msgHash := common.HexToHash("0x789cd5dcc77d50bec34b6458af936a3bfa802f3aa8b8466c07b2c6b663c92575")
	claimTxHash := common.HexToHash("0x27a4811c18012da320c7a1bf4d788aeca068ac2e34a5f2ff73df33fa5f0e4b44")
	blockHash := common.HexToHash("0xabababababababababababababababababababababababababababababababab")

	statusLog := &types.Log{
		Address:     common.HexToAddress("0xC4279588B8dA563D264e286E2ee7CE8c244444d6"),
		Topics:      []common.Hash{bridgeAbi.Events["MessageStatusChanged"].ID, msgHash},
		Data:        common.LeftPadBytes([]byte{uint8(relayer.EventStatusDone)}, 32),
		BlockNumber: 16,
		TxHash:      claimTxHash,
		TxIndex:     1,
		BlockHash:   blockHash,
		Index:       3,
	}

	err = p.saveMessageStatusChangedEvent(
		context.Background(),
		&types.Receipt{TxHash: claimTxHash, Logs: []*types.Log{statusLog}},
		&bridge.BridgeMessageSent{
			MsgHash: msgHash,
			Message: bridge.IBridgeMessage{
				SrcChainId:  1,
				DestChainId: 2,
				SrcOwner:    common.HexToAddress("0xC4279588B8dA563D264e286E2ee7CE8c244444d6"),
			},
			Raw: types.Log{BlockNumber: 7},
		},
	)
	require.NoError(t, err)

	saved := repo.SavedEvents()
	require.Len(t, saved, 1)

	// The same shape the indexer writes, so one reader serves both
	stored := &bridge.BridgeMessageStatusChanged{}
	require.NoError(t, json.Unmarshal(saved[0].Data, stored), "the stored row must be a complete log")
	assert.Equal(t, claimTxHash, stored.Raw.TxHash)
	assert.Equal(t, uint(1), stored.Raw.TxIndex)
	assert.Equal(t, blockHash, stored.Raw.BlockHash)
	assert.Equal(t, uint64(16), stored.Raw.BlockNumber)
	assert.Equal(t, uint8(relayer.EventStatusDone), stored.Status)
	assert.Equal(t, msgHash, common.Hash(stored.MsgHash))

	// Keyed the way the indexer keys the same log: the chain the status was emitted on, the
	// other chain, and the block it was emitted in
	assert.Equal(t, relayer.EventStatusDone, saved[0].Status)
	assert.Equal(t, int64(2), saved[0].ChainID)
	assert.Equal(t, int64(1), saved[0].DestChainID)
	assert.Equal(t, uint64(16), saved[0].EmittedBlockID)
	assert.Equal(t, msgHash.Hex(), saved[0].MsgHash)
}

// Everything the bridge calls while processing runs before the bridge emits its own status:
// the invoked contract, and destOwner when it is refunded. Either can emit a log with the
// bridge event's signature and this message's hash, and a scan that matched on the signature
// alone took the first such log - a spoofed DONE ahead of the bridge's RETRIABLE, which the
// API would then have reported as a successful claim. Only the bridge's own log is the status.
func Test_saveMessageStatusChangedEventIgnoresAStatusLogAnotherContractEmitted(t *testing.T) {
	repo := mock.NewEventRepository()
	p := newTestProcessor(false)
	p.eventRepo = repo

	bridgeAbi, err := abi.JSON(strings.NewReader(bridge.BridgeABI))
	require.NoError(t, err)

	msgHash := common.HexToHash("0x789cd5dcc77d50bec34b6458af936a3bfa802f3aa8b8466c07b2c6b663c92575")
	claimTxHash := common.HexToHash("0x27a4811c18012da320c7a1bf4d788aeca068ac2e34a5f2ff73df33fa5f0e4b44")
	destOwner := common.HexToAddress("0x000000000000000000000000000000000000dEaD")

	statusLog := func(from common.Address, status relayer.EventStatus, index uint) *types.Log {
		return &types.Log{
			Address:     from,
			Topics:      []common.Hash{bridgeAbi.Events["MessageStatusChanged"].ID, msgHash},
			Data:        common.LeftPadBytes([]byte{uint8(status)}, 32),
			BlockNumber: 16,
			TxHash:      claimTxHash,
			TxIndex:     1,
			BlockHash:   common.HexToHash("0xabababababababababababababababababababababababababababababababab"),
			Index:       index,
		}
	}

	receipt := &types.Receipt{
		TxHash: claimTxHash,
		Logs: []*types.Log{
			// The refund reached destOwner, a contract, before the bridge recorded the outcome
			statusLog(destOwner, relayer.EventStatusDone, 3),
			// A log from the bridge without the indexed hash is not this event either
			{
				Address: p.cfg.DestBridgeAddress,
				Topics:  []common.Hash{bridgeAbi.Events["MessageStatusChanged"].ID},
				Data:    common.LeftPadBytes([]byte{uint8(relayer.EventStatusDone)}, 32),
			},
			statusLog(p.cfg.DestBridgeAddress, relayer.EventStatusRetriable, 5),
		},
	}

	err = p.saveMessageStatusChangedEvent(context.Background(), receipt, &bridge.BridgeMessageSent{
		MsgHash: msgHash,
		Message: bridge.IBridgeMessage{SrcChainId: 1, DestChainId: 2, DestOwner: destOwner},
	})
	require.NoError(t, err)

	saved := repo.SavedEvents()
	require.Len(t, saved, 1)
	assert.Equal(t, relayer.EventStatusRetriable, saved[0].Status,
		"the attempt failed; a claim reported here would be false")

	stored := &bridge.BridgeMessageStatusChanged{}
	require.NoError(t, json.Unmarshal(saved[0].Data, stored))
	assert.Equal(t, p.cfg.DestBridgeAddress, stored.Raw.Address)
	assert.Equal(t, uint(5), stored.Raw.Index)
}
