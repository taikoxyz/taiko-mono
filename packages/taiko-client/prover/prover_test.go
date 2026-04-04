package prover

import (
	"context"
	"crypto/ecdsa"
	"math/big"
	"os"
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

type ProverTestSuite struct {
	testutils.ClientTestSuite
	p        *Prover
	cancel   context.CancelFunc
	d        *driver.Driver
	proposer *proposer.Proposer
	txmgr    *txmgr.SimpleTxManager
}

func (s *ProverTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	// Init prover
	var (
		prop              = new(proposer.Proposer)
		l1ProverPrivKey   = s.KeyFromEnv("L1_PROVER_PRIVATE_KEY")
		l1ProposerPrivKey = s.KeyFromEnv("L1_PROPOSER_PRIVATE_KEY")
		err               error
	)

	s.txmgr, err = txmgr.NewSimpleTxManager(
		"prover_test",
		log.Root(),
		&metrics.TxMgrMetrics,
		txmgr.CLIConfig{
			L1RPCURL:                  os.Getenv("L1_WS"),
			NumConfirmations:          0,
			SafeAbortNonceTooLowCount: txmgr.DefaultBatcherFlagValues.SafeAbortNonceTooLowCount,
			PrivateKey:                common.Bytes2Hex(crypto.FromECDSA(l1ProverPrivKey)),
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
	)
	s.Nil(err)

	txmgrProposer, err := txmgr.NewSimpleTxManager(
		"prover_test",
		log.Root(),
		&metrics.TxMgrMetrics,
		txmgr.CLIConfig{
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
	)
	s.Nil(err)

	ctx, cancel := context.WithCancel(context.Background())
	s.initProver(ctx, l1ProverPrivKey)
	s.cancel = cancel

	// Init driver
	jwtSecret, err := jwt.ParseSecretFromFile(os.Getenv("JWT_SECRET"))
	s.Nil(err)
	s.NotEmpty(jwtSecret)

	d := new(driver.Driver)
	s.Nil(d.InitFromConfig(context.Background(), &driver.Config{
		ClientConfig: &rpc.ClientConfig{
			L1Endpoint:              os.Getenv("L1_WS"),
			L2Endpoint:              os.Getenv("L2_WS"),
			L2EngineEndpoint:        os.Getenv("L2_AUTH"),
			InboxAddress:            common.HexToAddress(os.Getenv("INBOX")),
			PreconfWhitelistAddress: common.HexToAddress(os.Getenv("PRECONF_WHITELIST")),
			TaikoAnchorAddress:      common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
			JwtSecret:               string(jwtSecret),
		},
		BlobServerEndpoint: s.ParseL1HttpURLFromEnv(),
	}))
	s.d = d

	// Init proposer
	s.Nil(prop.InitFromConfig(context.Background(), &proposer.Config{
		ClientConfig: &rpc.ClientConfig{
			L1Endpoint:                  os.Getenv("L1_WS"),
			L2Endpoint:                  os.Getenv("L2_WS"),
			L2EngineEndpoint:            os.Getenv("L2_AUTH"),
			JwtSecret:                   string(jwtSecret),
			InboxAddress:                common.HexToAddress(os.Getenv("INBOX")),
			PreconfWhitelistAddress:     common.HexToAddress(os.Getenv("PRECONF_WHITELIST")),
			ForcedInclusionStoreAddress: common.HexToAddress(os.Getenv("FORCED_INCLUSION_STORE")),
			TaikoAnchorAddress:          common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		},
		L1ProposerPrivKey:       l1ProposerPrivKey,
		L2SuggestedFeeRecipient: common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")),
		ProposeInterval:         1024 * time.Hour,
		MaxTxListsPerEpoch:      1,
	}, txmgrProposer, txmgrProposer))

	s.proposer = prop
}

func (s *ProverTestSuite) TestName() {
	s.Equal("prover", s.p.Name())
}

func (s *ProverTestSuite) TestInitError() {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	var (
		l1ProverPrivKey = s.KeyFromEnv("L1_PROVER_PRIVATE_KEY")
		p               = new(Prover)
	)

	s.NotNil(InitFromConfig(ctx, p, &Config{
		L1WsEndpoint:          os.Getenv("L1_WS"),
		L2WsEndpoint:          os.Getenv("L2_WS"),
		L2HttpEndpoint:        os.Getenv("L2_HTTP"),
		InboxAddress:          common.HexToAddress(os.Getenv("INBOX")),
		TaikoAnchorAddress:    common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		L1ProverPrivKey:       l1ProverPrivKey,
		Dummy:                 true,
		ProveUnassignedBlocks: true,
		RPCTimeout:            10 * time.Minute,
		BackOffRetryInterval:  3 * time.Second,
		BackOffMaxRetries:     12,
	}, s.txmgr, s.txmgr))
}

func (s *ProverTestSuite) TestOnBatchProposed() {
	// Init prover
	var l1ProverPrivKey = s.KeyFromEnv("L1_PROVER_PRIVATE_KEY")
	s.p.cfg.L1ProverPrivKey = l1ProverPrivKey

	coreState, err := s.RPCClient.GetCoreStateShasta(nil)
	s.Nil(err)
	s.Equal(uint64(2), coreState.NextProposalId.Uint64())
	payload, eventLog, err := s.RPCClient.GetProposalByIDShasta(context.Background(), common.Big1)
	s.Nil(err)
	s.NotNil(payload)
	s.NotNil(eventLog)

	// Prove the first Shasta proposal inserted by shared test setup.
	header, err := s.RPCClient.L1.HeaderByHash(context.Background(), eventLog.BlockHash)
	s.Nil(err)
	meta := metadata.NewTaikoProposalMetadataShasta(payload, header.Time)
	s.Nil(s.p.eventHandlers.batchProposedHandler.Handle(context.Background(), meta, func() {}))
	req := <-s.p.proofSubmissionCh
	s.Nil(s.p.requestProofOp(req.Meta))
	s.Nil(s.p.aggregateOp(<-s.p.batchesAggregationNotifyShasta))
	s.Nil(s.p.submitProofAggregationOp(<-s.p.batchProofGenerationCh))

	// Propose and prove the second Shasta proposal.
	m := s.ProposeAndInsertValidBlock(s.proposer, s.d.ChainSyncer().EventSyncer())
	s.Nil(s.p.eventHandlers.batchProposedHandler.Handle(context.Background(), m, func() {}))
	req = <-s.p.proofSubmissionCh
	s.Nil(s.p.requestProofOp(req.Meta))
	s.Nil(s.p.aggregateOp(<-s.p.batchesAggregationNotifyShasta))
	s.Nil(s.p.submitProofAggregationOp(<-s.p.batchProofGenerationCh))
}

func (s *ProverTestSuite) TestGetSubmitterShastaOnly() {
	s.NotPanics(func() {
		submitter, err := s.p.getSubmitter(&proofProducer.BatchProofs{
			ProofResponses: []*proofProducer.ProofResponse{
				{
					BatchID: common.Big1,
					Meta:    metadata.NewTaikoProposalMetadataShasta(&shastaBindings.ShastaInboxClientProposed{}, 0),
					Proof:   []byte{},
					Opts:    &proofProducer.ProofRequestOptionsShasta{},
				},
			},
			BatchProof: []byte{},
			BatchIDs:   []*big.Int{common.Big1},
			ProofType:  proofProducer.ProofTypeOp,
		})
		s.Nil(err)
		s.NotNil(submitter)
	})
}

func (s *ProverTestSuite) TearDownTest() {
	defer s.ClientTestSuite.TearDownTest()

	if s.p.ctx.Err() == nil {
		s.cancel()
	}
	s.p.Close(context.Background())
}

func TestProverTestSuite(t *testing.T) {
	suite.Run(t, new(ProverTestSuite))
}

func (s *ProverTestSuite) initProver(ctx context.Context, key *ecdsa.PrivateKey) {
	proposerKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROPOSER_PRIVATE_KEY")))
	s.Nil(err)
	s.NotNil(proposerKey)

	jwtSecret, err := jwt.ParseSecretFromFile(os.Getenv("JWT_SECRET"))
	s.Nil(err)
	s.NotEmpty(jwtSecret)

	p := new(Prover)
	s.Nil(InitFromConfig(ctx, p, &Config{
		L1WsEndpoint:           os.Getenv("L1_WS"),
		L2WsEndpoint:           os.Getenv("L2_WS"),
		L2HttpEndpoint:         os.Getenv("L2_HTTP"),
		L2EngineEndpoint:       os.Getenv("L2_AUTH"),
		JwtSecret:              string(jwtSecret),
		InboxAddress:           common.HexToAddress(os.Getenv("INBOX")),
		TaikoAnchorAddress:     common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		L1ProverPrivKey:        key,
		Dummy:                  true,
		ProveUnassignedBlocks:  true,
		LocalProposerAddresses: []common.Address{crypto.PubkeyToAddress(proposerKey.PublicKey)},
		RPCTimeout:             3 * time.Second,
		BackOffRetryInterval:   3 * time.Second,
		BackOffMaxRetries:      12,
		SGXProofBufferSize:     1,
		ZKVMProofBufferSize:    1,
		BlockConfirmations:     0,
	}, s.txmgr, s.txmgr))
	s.p = p
}
