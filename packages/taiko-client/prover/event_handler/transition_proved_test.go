package handler

import (
	"context"
	"math/big"
	"os"
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/stretchr/testify/suite"

	ontakeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/ontake"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/beaconsync"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/event"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/state"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

type EventHandlerTestSuite struct {
	testutils.ClientTestSuite
	d           *driver.Driver
	proposer    *proposer.Proposer
	eventSyncer *event.Syncer
}

func (s *EventHandlerTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	// Init driver
	jwtSecret, err := jwt.ParseSecretFromFile(os.Getenv("JWT_SECRET"))
	s.Nil(err)
	s.NotEmpty(jwtSecret)

	d := new(driver.Driver)
	s.Nil(d.InitFromConfig(context.Background(), &driver.Config{
		ClientConfig: &rpc.ClientConfig{
			L1Endpoint:       os.Getenv("L1_WS"),
			L2Endpoint:       os.Getenv("L2_WS"),
			L2EngineEndpoint: os.Getenv("L2_AUTH"),
			TaikoL1Address:   common.HexToAddress(os.Getenv("TAIKO_INBOX")),
			TaikoL2Address:   common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
			JwtSecret:        string(jwtSecret),
		},
	}))
	s.d = d

	// Init calldata syncer
	testState, err := state.New(context.Background(), s.RPCClient)
	s.Nil(err)
	s.Nil(testState.ResetL1Current(context.Background(), common.Big0))

	tracker := beaconsync.NewSyncProgressTracker(s.RPCClient.L2, 30*time.Second)
	s.eventSyncer, err = event.NewSyncer(
		context.Background(),
		s.RPCClient,
		testState,
		tracker,
		nil,
		nil,
	)
	s.Nil(err)

	// Init proposer
	var (
		l1ProposerPrivKey = s.KeyFromEnv("L1_PROPOSER_PRIVATE_KEY")
		prop              = new(proposer.Proposer)
	)

	s.Nil(prop.InitFromConfig(context.Background(), &proposer.Config{
		ClientConfig: &rpc.ClientConfig{
			L1Endpoint:                  os.Getenv("L1_WS"),
			L2Endpoint:                  os.Getenv("L2_WS"),
			L2EngineEndpoint:            os.Getenv("L2_AUTH"),
			JwtSecret:                   string(jwtSecret),
			TaikoL1Address:              common.HexToAddress(os.Getenv("TAIKO_INBOX")),
			TaikoWrapperAddress:         common.HexToAddress(os.Getenv("TAIKO_WRAPPER")),
			ForcedInclusionStoreAddress: common.HexToAddress(os.Getenv("FORCED_INCLUSION_STORE")),
			ProverSetAddress:            common.HexToAddress(os.Getenv("PROVER_SET")),
			TaikoL2Address:              common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
			TaikoTokenAddress:           common.HexToAddress(os.Getenv("TAIKO_TOKEN")),
		},
		L1ProposerPrivKey:          l1ProposerPrivKey,
		L2SuggestedFeeRecipient:    common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")),
		ProposeInterval:            1024 * time.Hour,
		MaxProposedTxListsPerEpoch: 1,
		TxmgrConfigs: &txmgr.CLIConfig{
			L1RPCURL:                  os.Getenv("L1_WS"),
			NumConfirmations:          1,
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
			NumConfirmations:          1,
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

	s.proposer = prop
}

func (s *EventHandlerTestSuite) TestTransitionProvedHandle() {
	handler := NewTransitionProvedEventHandler(
		s.RPCClient,
		make(chan *proofProducer.ContestRequestBody),
		make(chan *proofProducer.ProofRequestBody),
		true,
		false,
	)
	m := s.ProposeAndInsertValidBlock(s.proposer, s.eventSyncer)
	if !m.IsPacaya() {
		s.Nil(handler.Handle(context.Background(), &ontakeBindings.TaikoL1ClientTransitionProvedV2{
			BlockId:    m.Ontake().GetBlockID(),
			Tier:       m.Ontake().GetMinTier(),
			ProposedIn: m.Ontake().GetRawBlockHeight().Uint64(),
		}))
	}
}

func (s *EventHandlerTestSuite) TestBachesProvedHandle() {
	proofRequestBodyCh := make(chan *proofProducer.ProofRequestBody, 1)

	handler := NewTransitionProvedEventHandler(
		s.RPCClient,
		make(chan *proofProducer.ContestRequestBody, 1),
		proofRequestBodyCh,
		true,
		false,
	)

	s.ForkIntoPacaya(s.proposer, s.eventSyncer)

	m := s.ProposeAndInsertValidBlock(s.proposer, s.eventSyncer)
	s.True(m.IsPacaya())

	batch, err := s.RPCClient.GetBatchByID(context.Background(), m.Pacaya().GetBatchID())
	s.Nil(err)

	block, err := s.RPCClient.L2.HeaderByNumber(context.Background(), new(big.Int).SetUint64(batch.LastBlockId))
	s.Nil(err)

	s.Nil(handler.HandlePacaya(context.Background(), &pacayaBindings.TaikoInboxClientBatchesProved{
		BatchIds: []uint64{m.Pacaya().GetBatchID().Uint64()},
		Transitions: []pacayaBindings.ITaikoInboxTransition{{
			ParentHash: block.ParentHash,
			BlockHash:  block.Hash(),
			StateRoot:  testutils.RandomHash(),
		}},
	}))

	s.Equal(m, (<-proofRequestBodyCh).Meta)
}

func TestTransitionProvedEventHandlerTestSuite(t *testing.T) {
	suite.Run(t, new(EventHandlerTestSuite))
}
