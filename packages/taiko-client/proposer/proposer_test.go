package proposer

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/math"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/miner"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/beaconsync"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/blob"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/state"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/utils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	builder "github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer/transaction_builder"
)

type ProposerTestSuite struct {
	testutils.ClientTestSuite
	s      *blob.Syncer
	p      *Proposer
	cancel context.CancelFunc
}

func (s *ProposerTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	state2, err := state.New(context.Background(), s.RPCClient)
	s.Nil(err)

	syncer, err := blob.NewSyncer(
		context.Background(),
		s.RPCClient,
		state2,
		beaconsync.NewSyncProgressTracker(s.RPCClient.L2, 1*time.Hour),
		0,
		nil,
		nil,
	)
	s.Nil(err)
	s.s = syncer

	l1ProposerPrivKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROPOSER_PRIVATE_KEY")))
	s.Nil(err)

	p := new(Proposer)

	ctx, cancel := context.WithCancel(context.Background())
	jwtSecret, err := jwt.ParseSecretFromFile(os.Getenv("JWT_SECRET"))
	s.Nil(err)
	s.NotEmpty(jwtSecret)

	s.Nil(p.InitFromConfig(ctx, &Config{
		ClientConfig: &rpc.ClientConfig{
			L1Endpoint:        os.Getenv("L1_WS"),
			L2Endpoint:        os.Getenv("L2_HTTP"),
			L2EngineEndpoint:  os.Getenv("L2_AUTH"),
			JwtSecret:         string(jwtSecret),
			TaikoL1Address:    common.HexToAddress(os.Getenv("TAIKO_L1")),
			TaikoL2Address:    common.HexToAddress(os.Getenv("TAIKO_L2")),
			TaikoTokenAddress: common.HexToAddress(os.Getenv("TAIKO_TOKEN")),
		},
		L1ProposerPrivKey:          l1ProposerPrivKey,
		L2SuggestedFeeRecipient:    common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")),
		MinProposingInternal:       0,
		ProposeInterval:            1024 * time.Hour,
		MaxProposedTxListsPerEpoch: 1,
		ExtraData:                  "test",
		ProposeBlockTxGasLimit:     10_000_000,
		TxmgrConfigs: &txmgr.CLIConfig{
			L1RPCURL:                  os.Getenv("L1_WS"),
			NumConfirmations:          0,
			SafeAbortNonceTooLowCount: txmgr.DefaultBatcherFlagValues.SafeAbortNonceTooLowCount,
			PrivateKey:                common.Bytes2Hex(crypto.FromECDSA(l1ProposerPrivKey)),
			FeeLimitMultiplier:        txmgr.DefaultBatcherFlagValues.FeeLimitMultiplier,
			FeeLimitThresholdGwei:     txmgr.DefaultBatcherFlagValues.FeeLimitThresholdGwei,
			MinBaseFeeGwei:            txmgr.DefaultBatcherFlagValues.MinBaseFeeGwei,
			MinTipCapGwei:             txmgr.DefaultBatcherFlagValues.MinTipCapGwei,
			ResubmissionTimeout:       txmgr.DefaultBatcherFlagValues.ResubmissionTimeout,
			ReceiptQueryInterval:      1 * time.Second,
			NetworkTimeout:            txmgr.DefaultBatcherFlagValues.NetworkTimeout,
			TxSendTimeout:             txmgr.DefaultBatcherFlagValues.TxSendTimeout,
			TxNotInMempoolTimeout:     txmgr.DefaultBatcherFlagValues.TxNotInMempoolTimeout,
		},
		PrivateTxmgrConfigs: &txmgr.CLIConfig{
			L1RPCURL:                  os.Getenv("L1_WS"),
			NumConfirmations:          0,
			SafeAbortNonceTooLowCount: txmgr.DefaultBatcherFlagValues.SafeAbortNonceTooLowCount,
			PrivateKey:                common.Bytes2Hex(crypto.FromECDSA(l1ProposerPrivKey)),
			FeeLimitMultiplier:        txmgr.DefaultBatcherFlagValues.FeeLimitMultiplier,
			FeeLimitThresholdGwei:     txmgr.DefaultBatcherFlagValues.FeeLimitThresholdGwei,
			MinBaseFeeGwei:            txmgr.DefaultBatcherFlagValues.MinBaseFeeGwei,
			MinTipCapGwei:             txmgr.DefaultBatcherFlagValues.MinTipCapGwei,
			ResubmissionTimeout:       txmgr.DefaultBatcherFlagValues.ResubmissionTimeout,
			ReceiptQueryInterval:      1 * time.Second,
			NetworkTimeout:            txmgr.DefaultBatcherFlagValues.NetworkTimeout,
			TxSendTimeout:             txmgr.DefaultBatcherFlagValues.TxSendTimeout,
			TxNotInMempoolTimeout:     txmgr.DefaultBatcherFlagValues.TxNotInMempoolTimeout,
		},
	}, nil, nil))

	s.p = p
	s.cancel = cancel
}

func (s *ProposerTestSuite) TestProposeTxLists() {
	p := s.p
	ctx := p.ctx
	cfg := s.p.Config

	txBuilder := builder.NewBlobTransactionBuilder(
		p.rpc,
		p.L1ProposerPrivKey,
		cfg.TaikoL1Address,
		cfg.ProverSetAddress,
		cfg.L2SuggestedFeeRecipient,
		cfg.ProposeBlockTxGasLimit,
		cfg.ExtraData,
		config.NewChainConfig(s.p.protocolConfigs),
	)

	emptyTxListBytes, err := rlp.EncodeToBytes(types.Transactions{})
	s.Nil(err)
	txListsBytes := [][]byte{emptyTxListBytes}
	txCandidates := make([]txmgr.TxCandidate, len(txListsBytes))
	for i, txListBytes := range txListsBytes {
		compressedTxListBytes, err := utils.Compress(txListBytes)
		if err != nil {
			log.Warn("Failed to compress transactions list", "index", i, "error", err)
			break
		}

		candidate, err := txBuilder.Build(
			p.ctx,
			p.IncludeParentMetaHash,
			compressedTxListBytes,
		)
		if err != nil {
			log.Warn("Failed to build TaikoL1.proposeBlock transaction", "error", err)
			break
		}

		// trigger the error
		candidate.GasLimit = 10_000_000

		txCandidates[i] = *candidate
	}

	for _, txCandidate := range txCandidates {
		txMgr, _ := p.txmgrSelector.Select()
		receipt, err := txMgr.Send(ctx, txCandidate)
		s.Nil(err)
		s.Nil(encoding.TryParsingCustomErrorFromReceipt(ctx, p.rpc.L1, p.proposerAddress, receipt))
	}
}

func (s *ProposerTestSuite) TestProposeOpNoEmptyBlock() {
	defer s.Nil(s.s.ProcessL1Blocks(context.Background()))

	p := s.p

	batchSize := 100

	var err error
	for i := 0; i < batchSize; i++ {
		to := common.BytesToAddress(testutils.RandomBytes(32))
		_, err = testutils.SendDynamicFeeTx(s.RPCClient.L2, s.TestAddrPrivKey, &to, nil, nil)
		s.Nil(err)
	}

	var preBuiltTxList []*miner.PreBuiltTxList
	for i := 0; i < 3 && len(preBuiltTxList) == 0; i++ {
		preBuiltTxList, err = s.RPCClient.GetPoolContent(
			context.Background(),
			p.proposerAddress,
			p.protocolConfigs.BlockMaxGasLimit,
			rpc.BlockMaxTxListBytes,
			p.LocalAddresses,
			p.MaxProposedTxListsPerEpoch,
			0,
			p.chainConfig,
		)
		time.Sleep(time.Second)
	}
	s.Nil(err)
	s.Equal(true, len(preBuiltTxList) > 0)

	var (
		blockMinGasLimit    uint64 = math.MaxUint64
		blockMinTxListBytes uint64 = math.MaxUint64
	)
	for _, txs := range preBuiltTxList {
		if txs.EstimatedGasUsed <= blockMinGasLimit {
			blockMinGasLimit = txs.EstimatedGasUsed
		} else {
			break
		}
		if txs.BytesLength <= blockMinTxListBytes {
			blockMinTxListBytes = txs.BytesLength
		} else {
			break
		}
	}

	// Start proposer
	p.LocalAddressesOnly = false
	p.MinGasUsed = blockMinGasLimit
	p.MinTxListBytes = blockMinTxListBytes
	p.ProposeInterval = time.Second
	p.MinProposingInternal = time.Minute
	s.Nil(p.ProposeOp(context.Background()))
}

func (s *ProposerTestSuite) TestName() {
	s.Equal("proposer", s.p.Name())
}

func (s *ProposerTestSuite) TestProposeOp() {
	// Propose txs in L2 execution engine's mempool
	sink := make(chan *bindings.LibProposingBlockProposed)

	sub, err := s.p.rpc.LibProposing.WatchBlockProposed(nil, sink, nil, nil)
	s.Nil(err)
	defer func() {
		sub.Unsubscribe()
		close(sink)
	}()

	sink2 := make(chan *bindings.LibProposingBlockProposedV2)

	sub2, err := s.p.rpc.LibProposing.WatchBlockProposedV2(nil, sink2, nil)
	s.Nil(err)
	defer func() {
		sub2.Unsubscribe()
		close(sink2)
	}()

	to := common.BytesToAddress(testutils.RandomBytes(32))
	_, err = testutils.SendDynamicFeeTx(s.p.rpc.L2, s.TestAddrPrivKey, &to, common.Big1, nil)
	s.Nil(err)

	s.Nil(s.p.ProposeOp(context.Background()))

	var (
		meta metadata.TaikoBlockMetaData
	)
	select {
	case event := <-sink:
		meta = metadata.NewTaikoDataBlockMetadataLegacy(event)
	case event := <-sink2:
		meta = metadata.NewTaikoDataBlockMetadataOntake(event)
	}

	s.Equal(meta.GetCoinbase(), s.p.L2SuggestedFeeRecipient)

	_, isPending, err := s.p.rpc.L1.TransactionByHash(context.Background(), meta.GetTxHash())
	s.Nil(err)
	s.False(isPending)

	receipt, err := s.p.rpc.L1.TransactionReceipt(context.Background(), meta.GetTxHash())
	s.Nil(err)
	s.Equal(types.ReceiptStatusSuccessful, receipt.Status)
}

func (s *ProposerTestSuite) TestProposeEmptyBlockOp() {
	s.p.MinProposingInternal = 1 * time.Second
	s.p.lastProposedAt = time.Now().Add(-10 * time.Second)
	s.Nil(s.p.ProposeOp(context.Background()))
}

func (s *ProposerTestSuite) TestUpdateProposingTicker() {
	s.p.ProposeInterval = 1 * time.Hour
	s.NotPanics(s.p.updateProposingTicker)

	s.p.ProposeInterval = 0
	s.NotPanics(s.p.updateProposingTicker)
}

func (s *ProposerTestSuite) TestStartClose() {
	s.Nil(s.p.Start())
	s.cancel()
	s.NotPanics(func() { s.p.Close(s.p.ctx) })
}

func TestProposerTestSuite(t *testing.T) {
	suite.Run(t, new(ProposerTestSuite))
}
