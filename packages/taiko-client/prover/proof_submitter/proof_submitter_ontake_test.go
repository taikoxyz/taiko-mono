package submitter

import (
	"bytes"
	"context"
	"os"
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum-optimism/optimism/op-service/txmgr/metrics"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	ontakeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/ontake"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/beaconsync"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/blob"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/state"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer"
	producer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_submitter/transaction"
)

type ProofSubmitterTestSuite struct {
	testutils.ClientTestSuite
	submitterOntake        *ProofSubmitterOntake
	submitterPacaya        *ProofSubmitterPacaya
	contesterOntake        *ProofContesterOntake
	blobSyncer             *blob.Syncer
	proposer               *proposer.Proposer
	proofCh                chan *producer.ProofResponse
	batchProofGenerationCh chan *producer.BatchProofs
	aggregationNotify      chan uint16
}

func (s *ProofSubmitterTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	s.proofCh = make(chan *producer.ProofResponse, 1024)
	s.batchProofGenerationCh = make(chan *producer.BatchProofs, 1024)
	s.aggregationNotify = make(chan uint16, 1)

	var (
		builder = transaction.NewProveBlockTxBuilder(
			s.RPCClient,
			common.HexToAddress(os.Getenv("TAIKO_INBOX")),
			common.Address{},
			common.HexToAddress(os.Getenv("GUARDIAN_PROVER_CONTRACT")),
			common.HexToAddress(os.Getenv("GUARDIAN_PROVER_MINORITY")),
		)
		l1ProverPrivKey = s.KeyFromEnv("L1_PROVER_PRIVATE_KEY")
	)

	txMgr, err := txmgr.NewSimpleTxManager(
		"proofSubmitterTestSuite",
		log.Root(),
		new(metrics.NoopTxMetrics),
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

	// Protocol proof tiers
	s.submitterOntake, err = NewProofSubmitterOntake(
		s.RPCClient,
		&producer.OptimisticProofProducer{},
		s.proofCh,
		s.batchProofGenerationCh,
		s.aggregationNotify,
		rpc.ZeroAddress,
		common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		"test",
		0,
		txMgr,
		nil,
		builder,
		[]*rpc.TierProviderTierWithID{},
		false,
		0*time.Second,
		0,
		30*time.Minute,
	)
	s.Nil(err)
	s.submitterPacaya, err = NewProofSubmitterPacaya(
		s.RPCClient,
		&producer.OptimisticProofProducer{},
		s.proofCh,
		s.batchProofGenerationCh,
		s.aggregationNotify,
		rpc.ZeroAddress,
		common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		0,
		txMgr,
		nil,
		builder,
	)
	s.Nil(err)
	s.contesterOntake = NewProofContester(
		s.RPCClient,
		0,
		txMgr,
		nil,
		rpc.ZeroAddress,
		"test",
		builder,
	)

	// Init calldata syncer
	testState, err := state.New(context.Background(), s.RPCClient)
	s.Nil(err)
	s.Nil(testState.ResetL1Current(context.Background(), common.Big0))

	tracker := beaconsync.NewSyncProgressTracker(s.RPCClient.L2, 30*time.Second)

	s.blobSyncer, err = blob.NewSyncer(
		context.Background(),
		s.RPCClient,
		testState,
		tracker,
		s.BlobServer.URL(),
	)
	s.Nil(err)

	// Init proposer
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
	}, txMgr, txMgr))

	s.proposer = prop
	s.proposer.RegisterTxMgrSelctorToBlobServer(s.BlobServer)
}

func (s *ProofSubmitterTestSuite) TestGetRandomBumpedSubmissionDelay() {
	var l1ProverPrivKey = s.KeyFromEnv("L1_PROVER_PRIVATE_KEY")
	txMgr, err := txmgr.NewSimpleTxManager(
		"proofSubmitterTestSuite",
		log.Root(),
		new(metrics.NoopTxMetrics),
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

	submitter1, err := NewProofSubmitterOntake(
		s.RPCClient,
		&producer.OptimisticProofProducer{},
		s.proofCh,
		s.batchProofGenerationCh,
		s.aggregationNotify,
		common.Address{},
		common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		"test",
		0,
		txMgr,
		nil,
		s.submitterOntake.txBuilder,
		s.submitterOntake.tiers,
		false,
		time.Duration(0),
		0,
		30*time.Minute,
	)
	s.Nil(err)

	delay, err := submitter1.getRandomBumpedSubmissionDelay(time.Now())
	s.Nil(err)
	s.Zero(delay)

	submitter2, err := NewProofSubmitterOntake(
		s.RPCClient,
		&producer.OptimisticProofProducer{},
		s.proofCh,
		s.batchProofGenerationCh,
		s.aggregationNotify,
		common.Address{},
		common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		"test",
		0,
		txMgr,
		nil,
		s.submitterOntake.txBuilder,
		s.submitterOntake.tiers,
		false,
		1*time.Hour,
		0,
		30*time.Minute,
	)
	s.Nil(err)
	delay, err = submitter2.getRandomBumpedSubmissionDelay(time.Now())
	s.Nil(err)
	s.NotZero(delay)
	s.Greater(delay.Seconds(), 1*time.Hour.Seconds())
	s.Less(
		delay.Seconds(),
		time.Hour.Seconds()*(1+(submissionDelayRandomBumpRange/100)),
	)
}

func (s *ProofSubmitterTestSuite) TestProofSubmitterRequestProofDeadlineExceeded() {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	s.ErrorContains(
		s.submitterOntake.RequestProof(
			ctx,
			&metadata.TaikoDataBlockMetadataOntake{TaikoDataBlockMetadataV2: ontakeBindings.TaikoDataBlockMetadataV2{Id: 256}},
		),
		"context deadline exceeded",
	)
}

func (s *ProofSubmitterTestSuite) TestProofSubmitterSubmitProofMetadataNotFound() {
	s.Error(
		s.submitterOntake.SubmitProof(
			context.Background(), &producer.ProofResponse{
				BlockID: common.Big256,
				Meta:    &metadata.TaikoDataBlockMetadataOntake{},
				Opts:    &producer.ProofRequestOptionsOntake{},
				Proof:   bytes.Repeat([]byte{0xff}, 100),
			},
		),
	)
}

func (s *ProofSubmitterTestSuite) TestSubmitProofs() {
	for _, m := range s.ProposeAndInsertEmptyBlocks(s.proposer, s.blobSyncer) {
		if m.IsPacaya() {
			s.Nil(s.submitterPacaya.RequestProof(context.Background(), m))
			proofResponse := <-s.proofCh
			s.Nil(s.submitterPacaya.SubmitProof(context.Background(), proofResponse))
			continue
		}
		s.Nil(s.submitterOntake.RequestProof(context.Background(), m))
		proofResponse := <-s.proofCh
		s.Nil(s.submitterOntake.SubmitProof(context.Background(), proofResponse))
	}
}

func (s *ProofSubmitterTestSuite) TestGuardianSubmitProofs() {
	for _, m := range s.ProposeAndInsertEmptyBlocks(s.proposer, s.blobSyncer) {
		if m.IsPacaya() {
			continue
		}
		s.Nil(s.submitterOntake.RequestProof(context.Background(), m))
		proofResponse := <-s.proofCh
		proofResponse.Tier = encoding.TierGuardianMajorityID
		s.Nil(s.submitterOntake.SubmitProof(context.Background(), proofResponse))
	}
}

func (s *ProofSubmitterTestSuite) TestProofSubmitterRequestProofCancelled() {
	ctx, cancel := context.WithCancel(context.Background())
	go func() { time.AfterFunc(2*time.Second, func() { cancel() }) }()

	s.ErrorContains(
		s.submitterOntake.RequestProof(
			ctx,
			&metadata.TaikoDataBlockMetadataOntake{TaikoDataBlockMetadataV2: ontakeBindings.TaikoDataBlockMetadataV2{Id: 256}},
		),
		"context canceled",
	)
}

func TestProofSubmitterTestSuite(t *testing.T) {
	suite.Run(t, new(ProofSubmitterTestSuite))
}
