package chainsyncer

import (
	"context"

	"os"
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/state"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer"
	builder "github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer/transaction_builder"
)

type ChainSyncerTestSuite struct {
	testutils.ClientTestSuite
	s                     *L2ChainSyncer
	p                     testutils.Proposer
	shastaProposalBuilder *builder.BlobTransactionBuilder
}

func (s *ChainSyncerTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	state, err := state.New(context.Background(), s.RPCClient)
	s.Nil(err)

	syncer, err := New(
		context.Background(),
		s.RPCClient,
		s.ShastaStateIndexer,
		state,
		false,
		1*time.Hour,
		s.BlobServer.URL(),
		nil,
	)
	s.Nil(err)
	s.s = syncer

	var (
		l1ProposerPrivKey = s.KeyFromEnv("L1_PROPOSER_PRIVATE_KEY")
		prop              = new(proposer.Proposer)
	)
	jwtSecret, err := jwt.ParseSecretFromFile(os.Getenv("JWT_SECRET"))
	s.Nil(err)

	s.Nil(prop.InitFromConfig(context.Background(), &proposer.Config{
		ClientConfig: &rpc.ClientConfig{
			L1Endpoint:                  os.Getenv("L1_WS"),
			L2Endpoint:                  os.Getenv("L2_WS"),
			L2EngineEndpoint:            os.Getenv("L2_AUTH"),
			JwtSecret:                   string(jwtSecret),
			TaikoInboxAddress:           common.HexToAddress(os.Getenv("TAIKO_INBOX")),
			ProverSetAddress:            common.HexToAddress(os.Getenv("PROVER_SET")),
			TaikoWrapperAddress:         common.HexToAddress(os.Getenv("TAIKO_WRAPPER")),
			ForcedInclusionStoreAddress: common.HexToAddress(os.Getenv("FORCED_INCLUSION_STORE")),
			TaikoAnchorAddress:          common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
			TaikoTokenAddress:           common.HexToAddress(os.Getenv("TAIKO_TOKEN")),
		},
		BlobAllowed:             true,
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
	s.Nil(prop.ShastaIndexer().Start())
	s.p.RegisterTxMgrSelectorToBlobServer(s.BlobServer)

	s.shastaProposalBuilder = builder.NewBlobTransactionBuilder(
		s.RPCClient,
		prop.ShastaIndexer(),
		l1ProposerPrivKey,
		common.HexToAddress(os.Getenv("TAIKO_INBOX")),
		common.HexToAddress(os.Getenv("TAIKO_WRAPPER")),
		common.HexToAddress(os.Getenv("PROVER_SET")),
		common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")),
		1_000_000,
		nil,
		true,
	)
}

func (s *ChainSyncerTestSuite) TestGetInnerSyncers() {
	s.NotNil(s.s.BeaconSyncer())
	s.NotNil(s.s.EventSyncer())
}

func (s *ChainSyncerTestSuite) TestSync() {
	s.Nil(s.s.Sync())
}

func (s *ChainSyncerTestSuite) TestAheadOfProtocolVerifiedHead() {
	s.True(s.s.AheadOfHeadToSync(0))
}

func (s *ChainSyncerTestSuite) TestShastaInvalidBlobs() {
	s.ForkIntoShasta(s.p, s.s.EventSyncer())

	head, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)

	txCandidate, err := s.shastaProposalBuilder.BuildShasta(
		context.Background(),
		[]types.Transactions{{}},
		nil,
		common.Big1,
		common.Address{},
	)
	s.Nil(err)
	b, err := builder.SplitToBlobs([]byte{0x1})
	s.Nil(err)
	txCandidate.Blobs = b
	s.Nil(s.p.SendTx(context.Background(), txCandidate))
	s.Nil(s.s.EventSyncer().ProcessL1Blocks(context.Background()))

	head2, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(head.NumberU64()+1, head2.NumberU64())
	s.Equal(1, len(head2.Transactions()))
	s.Equal(head.GasLimit(), head2.GasLimit())
}

func TestChainSyncerTestSuite(t *testing.T) {
	suite.Run(t, new(ChainSyncerTestSuite))
}
