package event

import (
	"context"
	"crypto/ecdsa"
	"math/big"
	"os"
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/stretchr/testify/suite"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/beaconsync"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/state"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	builder "github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer/transaction_builder"
)

type shastaTestProposer struct {
	rpc     *rpc.Client
	txMgr   txmgr.TxManager
	builder *builder.BlobTransactionBuilder
}

func newShastaTestProposer(s *EventSyncerTestSuite, key *ecdsa.PrivateKey) *shastaTestProposer {
	return &shastaTestProposer{
		rpc:   s.RPCClient,
		txMgr: s.TxMgr("test-proposer", key),
		builder: builder.NewBlobTransactionBuilder(
			s.RPCClient,
			common.HexToAddress(os.Getenv("INBOX")),
			common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")),
			1_000_000,
		),
	}
}

func (p *shastaTestProposer) InitFromCli(context.Context, *cli.Context) error { return nil }
func (p *shastaTestProposer) Name() string                                    { return "test-proposer" }
func (p *shastaTestProposer) Start() error                                    { return nil }
func (p *shastaTestProposer) Close(context.Context)                           {}

func (p *shastaTestProposer) SendTx(ctx context.Context, txCandidate *txmgr.TxCandidate) error {
	_, err := p.txMgr.Send(ctx, *txCandidate)
	return err
}

func (p *shastaTestProposer) ProposeOp(ctx context.Context) error {
	poolContent, err := p.rpc.GetPoolContent(
		ctx,
		common.Address{},
		uint32(manifest.MaxBlockGasLimit),
		uint64(eth.MaxBlobDataSize*eth.MaxBlobsPerBlobTx),
		nil,
		1024,
		0,
		nil,
	)
	if err != nil {
		return err
	}

	txLists := make([]types.Transactions, 0, len(poolContent))
	for _, txList := range poolContent {
		if len(txList.TxList) == 0 {
			continue
		}
		txLists = append(txLists, txList.TxList)
	}

	if len(txLists) == 0 {
		txLists = []types.Transactions{{}}
	}

	return p.ProposeTxLists(ctx, txLists)
}

func (p *shastaTestProposer) ProposeTxLists(ctx context.Context, txLists []types.Transactions) error {
	txCandidate, err := p.builder.BuildShasta(ctx, txLists)
	if err != nil {
		return err
	}
	return p.SendTx(ctx, txCandidate)
}

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
		s.ParseL1HttpURLFromEnv(),
		nil,
	)
	s.Nil(err)
	s.s = syncer

	s.initProposer()
}

func (s *EventSyncerTestSuite) TestEventSyncRobustness() {
	ctx := context.Background()

	meta := s.ProposeAndInsertValidBlock(s.p, s.s)
	s.True(meta.IsShasta())
	s.NotNil(meta.Shasta())

	block, err := s.RPCClient.L2.BlockByNumber(ctx, nil)
	s.Nil(err)

	coreState, err := s.s.rpc.GetCoreStateShasta(&bind.CallOpts{Context: ctx})
	s.Nil(err)

	txListBytes, err := rlp.EncodeToBytes(block.Transactions())
	s.Nil(err)

	parent, err := s.RPCClient.L2ParentByCurrentBlockID(
		context.Background(),
		block.Number(),
	)
	s.Nil(err)

	// Reset the L2 chain.
	s.SetHead(common.Big1)

	difficulty, err := encoding.CalculateShastaDifficulty(parent.Difficulty, block.Number())
	s.Nil(err)

	attributes := &engine.PayloadAttributes{
		Timestamp:             block.Time(),
		Random:                common.BytesToHash(difficulty),
		SuggestedFeeRecipient: block.Coinbase(),
		Withdrawals:           make([]*types.Withdrawal, 0),
		BlockMetadata: &engine.BlockMetadata{
			Beneficiary: block.Coinbase(),
			GasLimit:    block.GasLimit(),
			Timestamp:   block.Time(),
			TxList:      txListBytes,
			MixHash:     common.BytesToHash(difficulty),
			ExtraData:   block.Extra(),
		},
		BaseFeePerGas: block.BaseFee(),
		L1Origin: &rawdb.L1Origin{
			BlockID:       block.Number(),
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
			SafeBlockHash:      common.Hash(coreState.LastFinalizedBlockHash),
			FinalizedBlockHash: common.Hash(coreState.LastFinalizedBlockHash),
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
	shastaCfg, err := s.RPCClient.ShastaClients.Inbox.GetConfig(nil)
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
			sharingPctg := uint64(shastaCfg.BasefeeSharingPctg)

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

func (s *EventSyncerTestSuite) TestKnownBatchSendsProposal() {
	ctx := context.Background()

	// Record L1 head before proposing so we know where to reset the cursor.
	l1HeadBefore, err := s.RPCClient.L1.HeaderByNumber(ctx, nil)
	s.Nil(err)

	// Insert blocks using the default syncer (no channel) — normal insertion path.
	s.ProposeAndInsertValidBlock(s.p, s.s)

	// Create a new syncer WITH a proposal channel to capture known-batch proposals.
	// This simulates a restart: fresh syncer state, but blocks already in canonical chain.
	proposalCh := make(chan *encoding.LastSeenProposal, 10)
	state2, err := state.New(ctx, s.RPCClient)
	s.Nil(err)

	syncer2, err := NewSyncer(
		ctx,
		s.RPCClient,
		state2,
		beaconsync.NewSyncProgressTracker(s.RPCClient.L2, 1*time.Hour),
		s.ParseL1HttpURLFromEnv(),
		proposalCh,
	)
	s.Nil(err)

	// Reset L1Current to before the proposal to force reprocessing of the same events.
	state2.SetL1Current(l1HeadBefore)

	// Process L1 blocks — should hit the known-batch fast path since blocks exist.
	s.Nil(syncer2.ProcessL1Blocks(ctx))

	// Wait for proposals while draining the channel.
	// Known-batch proposals should have PreconfChainReorged=false (not a reorg)
	// and a valid LastBlockID so the preconf server can advance its canonical tip.
	proposalCount := 0
	deadline := time.After(1 * time.Second)
	for {
		select {
		case proposal := <-proposalCh:
			s.False(proposal.PreconfChainReorged, "Known batch should not be marked as reorged")
			s.Greater(proposal.LastBlockID, uint64(0))
			proposalCount++
		case <-deadline:
			s.Greater(proposalCount, 0, "Expected at least one proposal from known-batch fast path")
			return
		}
	}
}

func (s *EventSyncerTestSuite) initProposer() {
	s.p = newShastaTestProposer(s, s.KeyFromEnv("L1_PROPOSER_PRIVATE_KEY"))
}

func TestEventSyncerTestSuite(t *testing.T) {
	suite.Run(t, new(EventSyncerTestSuite))
}
