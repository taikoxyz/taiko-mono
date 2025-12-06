package event

import (
	"context"
	"math/big"
	"os"
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	consensus "github.com/ethereum/go-ethereum/consensus/taiko"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/beaconsync"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/state"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer"
)

type EventSyncerTestSuite struct {
	testutils.ClientTestSuite
	s *Syncer
	p testutils.Proposer
}

func (s *EventSyncerTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	state2, err := state.New(context.Background(), s.RPCClient)
	s.Nil(err)

	syncer, err := NewSyncer(
		context.Background(),
		s.RPCClient,
		state2,
		beaconsync.NewSyncProgressTracker(s.RPCClient.L2, 1*time.Hour),
		s.BlobServer.URL(),
		nil,
	)
	s.Nil(err)
	s.s = syncer

	s.initProposer()
}

func (s *EventSyncerTestSuite) TestEventSyncRobustness() {
	ctx := context.Background()

	meta := s.ProposeAndInsertValidBlock(s.p, s.s)
	s.True(meta.IsPacaya())
	s.Equal(1, len(meta.Pacaya().GetBlocks()))

	block, err := s.RPCClient.L2.BlockByNumber(ctx, new(big.Int).SetUint64(meta.Pacaya().GetLastBlockID()))
	s.Nil(err)

	lastVerifiedBlockInfo, err := s.s.rpc.GetLastVerifiedTransitionPacaya(ctx)
	s.Nil(err)

	txListBytes, err := rlp.EncodeToBytes(block.Transactions())
	s.Nil(err)

	parent, err := s.RPCClient.L2ParentByCurrentBlockID(
		context.Background(),
		new(big.Int).SetUint64(meta.Pacaya().GetLastBlockID()),
	)
	s.Nil(err)

	// Reset the L2 chain.
	s.SetHead(common.Big1)

	difficulty, err := encoding.CalculatePacayaDifficulty(new(big.Int).SetUint64(meta.Pacaya().GetLastBlockID()))
	s.Nil(err)

	attributes := &engine.PayloadAttributes{
		Timestamp:             meta.Pacaya().GetLastBlockTimestamp(),
		Random:                common.BytesToHash(difficulty),
		SuggestedFeeRecipient: meta.GetCoinbase(),
		Withdrawals:           make([]*types.Withdrawal, 0),
		BlockMetadata: &engine.BlockMetadata{
			Beneficiary: meta.GetCoinbase(),
			GasLimit:    uint64(meta.Pacaya().GetGasLimit()) + consensus.AnchorV3V4GasLimit,
			Timestamp:   meta.Pacaya().GetLastBlockTimestamp(),
			TxList:      txListBytes,
			MixHash:     common.BytesToHash(difficulty),
			ExtraData:   meta.Pacaya().GetExtraData(),
		},
		BaseFeePerGas: block.BaseFee(),
		L1Origin: &rawdb.L1Origin{
			BlockID:       new(big.Int).SetUint64(meta.Pacaya().GetLastBlockID()),
			L2BlockHash:   common.Hash{}, // Will be set by taiko-geth.
			L1BlockHeight: meta.GetRawBlockHeight(),
			L1BlockHash:   meta.GetRawBlockHash(),
		},
	}

	step0 := func() *engine.ForkChoiceResponse {
		fcRes, err := s.RPCClient.L2Engine.ForkchoiceUpdate(
			ctx,
			&engine.ForkchoiceStateV1{HeadBlockHash: parent.Hash()},
			attributes,
		)
		s.Nil(err)
		s.Equal(engine.VALID, fcRes.PayloadStatus.Status)
		s.True(true, fcRes.PayloadID != nil)
		return fcRes
	}

	step1 := func(fcRes *engine.ForkChoiceResponse) *engine.ExecutableData {
		payload, err := s.RPCClient.L2Engine.GetPayload(ctx, fcRes.PayloadID)
		s.Nil(err)
		return payload
	}

	step2 := func(payload *engine.ExecutableData) *engine.ExecutableData {
		execStatus, err := s.RPCClient.L2Engine.NewPayload(ctx, payload)
		s.Nil(err)
		s.Equal(engine.VALID, execStatus.Status)
		return payload
	}

	step3 := func(payload *engine.ExecutableData) {
		fcRes, err := s.RPCClient.L2Engine.ForkchoiceUpdate(ctx, &engine.ForkchoiceStateV1{
			HeadBlockHash:      payload.BlockHash,
			SafeBlockHash:      lastVerifiedBlockInfo.Ts.BlockHash,
			FinalizedBlockHash: lastVerifiedBlockInfo.Ts.BlockHash,
		}, nil)
		s.Nil(err)
		s.Equal(engine.VALID, fcRes.PayloadStatus.Status)
	}

	loopSize := 10
	for i := 0; i < loopSize; i++ {
		step0()
	}

	for i := 0; i < loopSize; i++ {
		step1(step0())
	}

	for i := 0; i < loopSize; i++ {
		step2(step1(step0()))
	}

	step3(step2(step1(step0())))
}

func (s *EventSyncerTestSuite) TestProcessL1Blocks() {
	s.Nil(s.s.ProcessL1Blocks(context.Background()))
}

func (s *EventSyncerTestSuite) TestProcessL1BlocksReorg() {
	s.ProposeAndInsertEmptyBlocks(s.p, s.s)
	s.Nil(s.s.ProcessL1Blocks(context.Background()))
}

func (s *EventSyncerTestSuite) TestTreasuryIncomeAllAnchors() {
	treasury := common.HexToAddress(os.Getenv("TREASURY"))
	s.NotZero(treasury.Big().Uint64())

	balance, err := s.RPCClient.L2.BalanceAt(context.Background(), treasury, nil)
	s.Nil(err)

	headBefore, err := s.RPCClient.L2.BlockNumber(context.Background())
	s.Nil(err)

	s.ProposeAndInsertEmptyBlocks(s.p, s.s)

	headAfter, err := s.RPCClient.L2.BlockNumber(context.Background())
	s.Nil(err)

	balanceAfter, err := s.RPCClient.L2.BalanceAt(context.Background(), treasury, nil)
	s.Nil(err)

	s.Greater(headAfter, headBefore)
	s.Equal(1, balanceAfter.Cmp(balance))
}

func (s *EventSyncerTestSuite) TestTreasuryIncome() {
	treasury := common.HexToAddress(os.Getenv("TREASURY"))
	s.NotZero(treasury.Big().Uint64())

	balance, err := s.RPCClient.L2.BalanceAt(context.Background(), treasury, nil)
	s.Nil(err)

	headBefore, err := s.RPCClient.L2.BlockNumber(context.Background())
	s.Nil(err)

	s.ProposeAndInsertEmptyBlocks(s.p, s.s)
	s.ProposeAndInsertValidBlock(s.p, s.s)

	headAfter, err := s.RPCClient.L2.BlockNumber(context.Background())
	s.Nil(err)

	balanceAfter, err := s.RPCClient.L2.BalanceAt(context.Background(), treasury, nil)
	s.Nil(err)

	s.Greater(headAfter, headBefore)
	s.True(balanceAfter.Cmp(balance) > 0)

	var hasNoneAnchorTxs bool
	pacayaCfg, err := s.RPCClient.GetProtocolConfigs(nil)
	s.Nil(err)

	for i := headBefore + 1; i <= headAfter; i++ {
		block, err := s.RPCClient.L2.BlockByNumber(context.Background(), new(big.Int).SetUint64(i))
		s.Nil(err)
		s.GreaterOrEqual(block.Transactions().Len(), 1)
		s.Greater(block.BaseFee().Uint64(), uint64(0))

		for j, tx := range block.Transactions() {
			if j == 0 {
				continue
			}

			hasNoneAnchorTxs = true
			receipt, err := s.RPCClient.L2.TransactionReceipt(context.Background(), tx.Hash())
			s.Nil(err)

			fee := new(big.Int).Mul(block.BaseFee(), new(big.Int).SetUint64(receipt.GasUsed))
			sharingPctg := uint64(pacayaCfg.BaseFeeConfig().SharingPctg)

			feeCoinbase := new(big.Int).Div(
				new(big.Int).Mul(fee, new(big.Int).SetUint64(sharingPctg)),
				new(big.Int).SetUint64(100),
			)
			feeTreasury := new(big.Int).Sub(fee, feeCoinbase)
			balance = new(big.Int).Add(balance, feeTreasury)
		}
	}

	s.True(hasNoneAnchorTxs)
	s.Zero(balanceAfter.Cmp(balance))
}

func (s *EventSyncerTestSuite) initProposer() {
	var (
		l1ProposerPrivKey = s.KeyFromEnv("L1_PROPOSER_PRIVATE_KEY")
		prop              = new(proposer.Proposer)
	)

	jwtSecret, err := jwt.ParseSecretFromFile(os.Getenv("JWT_SECRET"))
	s.Nil(err)
	s.NotEmpty(jwtSecret)

	s.Nil(prop.InitFromConfig(context.Background(), &proposer.Config{
		ClientConfig: &rpc.ClientConfig{
			L1Endpoint:                  os.Getenv("L1_WS"),
			L2Endpoint:                  os.Getenv("L2_WS"),
			L2EngineEndpoint:            os.Getenv("L2_AUTH"),
			JwtSecret:                   string(jwtSecret),
			PacayaInboxAddress:          common.HexToAddress(os.Getenv("PACAYA_INBOX")),
			ShastaInboxAddress:          common.HexToAddress(os.Getenv("SHASTA_INBOX")),
			TaikoWrapperAddress:         common.HexToAddress(os.Getenv("TAIKO_WRAPPER")),
			ForcedInclusionStoreAddress: common.HexToAddress(os.Getenv("FORCED_INCLUSION_STORE")),
			ProverSetAddress:            common.HexToAddress(os.Getenv("PROVER_SET")),
			TaikoAnchorAddress:          common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
			TaikoTokenAddress:           common.HexToAddress(os.Getenv("TAIKO_TOKEN")),
		},
		L1ProposerPrivKey:       l1ProposerPrivKey,
		L2SuggestedFeeRecipient: common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")),
		ProposeInterval:         1024 * time.Hour,
		MaxTxListsPerEpoch:      1,
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

	s.p = prop
	s.p.RegisterTxMgrSelectorToBlobServer(s.BlobServer)
}

func TestEventSyncerTestSuite(t *testing.T) {
	suite.Run(t, new(EventSyncerTestSuite))
}
