package processor

import (
	"context"
	"encoding/json"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/erc20vault"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/signalservice"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/encoding"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/proof"
	"log/slog"
	"math/big"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
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

func Test_generateEncodedSignalProof(t *testing.T) {
	// Test data is from this
	// https://holesky.etherscan.io/tx/0x086729ca21c2db5714560943a6522362c837c9cf6424dfcc7b8f15f132b7f934
	// https://relayer.hekla.taiko.xyz/events?address=0x1D2D1bb9D180541E88a6a682aCf3f61c1605B190&event=MessageSent
	privateKey, _ := crypto.HexToECDSA(dummyEcdsaKey)
	srcRpcClient, err := rpc.Dial("https://l1rpc.hekla.taiko.xyz")
	assert.Nil(t, err)
	srcEthClient, err := ethclient.Dial("https://l1rpc.hekla.taiko.xyz")
	assert.Nil(t, err)
	destEthClient, err := ethclient.Dial("https://rpc.hekla.taiko.xyz")
	assert.Nil(t, err)
	prover, err := proof.New(srcEthClient, encoding.CACHE_NOTHING)
	assert.Nil(t, err)
	destBridge, err := bridge.NewBridge(common.HexToAddress("0x1670090000000000000000000000000000000001"), destEthClient)
	assert.Nil(t, err)
	destERC20Vault, err := erc20vault.NewERC20Vault(
		common.HexToAddress("0x1670090000000000000000000000000000000002"),
		destEthClient,
	)
	assert.Nil(t, err)
	srcSignalService, err := signalservice.NewSignalService(
		common.HexToAddress("0x6Fc2fe9D9dd0251ec5E0727e826Afbb0Db2CBe0D"),
		srcEthClient,
	)
	assert.Nil(t, err)
	p := &Processor{
		eventRepo:                 &mock.EventRepository{},
		destBridge:                destBridge,
		srcEthClient:              srcEthClient,
		destEthClient:             destEthClient,
		destERC20Vault:            destERC20Vault,
		srcSignalService:          srcSignalService,
		srcSignalServiceAddress:   common.HexToAddress("0x6Fc2fe9D9dd0251ec5E0727e826Afbb0Db2CBe0D"),
		ecdsaKey:                  privateKey,
		prover:                    prover,
		srcCaller:                 srcRpcClient,
		profitableOnly:            false,
		headerSyncIntervalSeconds: 1,
		confTimeoutInSeconds:      900,
		confirmations:             1,
		queue:                     &mock.Queue{},
		backOffRetryInterval:      1 * time.Second,
		backOffMaxRetries:         1,
		ethClientTimeout:          10 * time.Second,
		srcChainId:                big.NewInt(17000),
		destChainId:               big.NewInt(167009),
		txmgr:                     &mock.TxManager{},
		cfg: &Config{
			DestBridgeAddress: common.HexToAddress("0x1670090000000000000000000000000000000001"),
		},
		maxMessageRetries:  5,
		destQuotaManager:   &mock.QuotaManager{},
		processingTxHashes: make(map[common.Hash]bool, 0),
	}
	sentMsg := &bridge.BridgeMessageSent{
		MsgHash: common.HexToHash("0x0ECBF53020C6ABFDAD937D293169F929BE7712C5576F125EAFFE33D891B9014E"),
		Message: bridge.IBridgeMessage{
			Id:          1636356,
			Fee:         0,
			GasLimit:    3000000,
			From:        common.HexToAddress("0x1d2d1bb9d180541e88a6a682acf3f61c1605b190"),
			SrcChainId:  17000,
			SrcOwner:    common.HexToAddress("0x1d2d1bb9d180541e88a6a682acf3f61c1605b190"),
			DestChainId: 167009,
			DestOwner:   common.HexToAddress("0x95f6077c7786a58fa070d98043b16df2b1593d2b"),
			To:          common.HexToAddress("0x95f6077c7786a58fa070d98043b16df2b1593d2b"),
			Value:       big.NewInt(0),
			Data:        common.Hex2Bytes("7f07c947000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000005c000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ca11bde05977b3631167028862be2a173976ca110000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000004e482ad56cb0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000022000000000000000000000000000000000000000000000000000000000000002e000000000000000000000000000000000000000000000000000000000000003a000000000000000000000000016700900000000000000000000000000000100010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000243659cfe6000000000000000000000000637b1e6e71007d033b5d4385179037c90665a2030000000000000000000000000000000000000000000000000000000000000000000000000000000016700900000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000243659cfe600000000000000000000000050216f60163ef399e22026fa1300aea8eeba34620000000000000000000000000000000000000000000000000000000000000000000000000000000016700900000000000000000000000000000100020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000243659cfe60000000000000000000000001063f4cf9eaaa67b5dc9750d96ec0bd885d10aee0000000000000000000000000000000000000000000000000000000000000000000000000000000016700900000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000243659cfe60000000000000000000000001063f4cf9eaaa67b5dc9750d96ec0bd885d10aee000000000000000000000000000000000000000000000000000000000000000000000000000000001670090000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000064d8f4648f0000000000000000000000000000000000000000000000000000000000028c61627269646765645f6572633230000000000000000000000000000000000000000000000000000000000000001baf1ab3686ace2fd47e11ac627f3cc626aec0ff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"),
		},
		Raw: types.Log{
			Address:     common.HexToAddress("0xA098b76a3Dd499D3F6D58D8AcCaFC8efBFd06807"),
			BlockNumber: 3019062,
		},
	}
	bytes, err := p.generateEncodedSignalProof(context.Background(), sentMsg)
	assert.Nil(t, err)
	slog.Info("value is", "value", common.Bytes2Hex(bytes))
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
