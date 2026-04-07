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

	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/beaconsync"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/event"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/state"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer"
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
			L1Endpoint:         os.Getenv("L1_WS"),
			L2Endpoint:         os.Getenv("L2_WS"),
			L2EngineEndpoint:   os.Getenv("L2_AUTH"),
			InboxAddress:       common.HexToAddress(os.Getenv("INBOX")),
			TaikoAnchorAddress: common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
			JwtSecret:          string(jwtSecret),
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
		s.ParseL1HttpURLFromEnv(),
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
			L1Endpoint:         os.Getenv("L1_WS"),
			L2Endpoint:         os.Getenv("L2_WS"),
			L2EngineEndpoint:   os.Getenv("L2_AUTH"),
			JwtSecret:          string(jwtSecret),
			InboxAddress:       common.HexToAddress(os.Getenv("INBOX")),
			TaikoAnchorAddress: common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		},
		L1ProposerPrivKey:       l1ProposerPrivKey,
		L2SuggestedFeeRecipient: common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")),
		ProposeInterval:         1024 * time.Hour,
		MaxTxListsPerEpoch:      1,
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
	}, nil, nil))

	s.proposer = prop
}

func (s *EventHandlerTestSuite) TestProofsReceivedHandle() {
	handler := NewProofsReceivedEventHandler(s.RPCClient)

	meta := s.ProposeAndInsertValidBlock(s.proposer, s.eventSyncer)
	s.True(meta.IsShasta())

	s.Nil(handler.Handle(context.Background(), &shastaBindings.ShastaInboxClientProved{
		FirstNewProposalId: new(big.Int).Set(meta.Shasta().GetEventData().Id),
		LastProposalId:     new(big.Int).Set(meta.Shasta().GetEventData().Id),
		ActualProver:       crypto.PubkeyToAddress(s.KeyFromEnv("L1_PROPOSER_PRIVATE_KEY").PublicKey),
	}))
}

func TestEventHandlerTestSuite(t *testing.T) {
	suite.Run(t, new(EventHandlerTestSuite))
}
