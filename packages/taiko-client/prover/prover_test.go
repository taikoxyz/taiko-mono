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
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
	proofSubmitter "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_submitter"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_submitter/transaction"
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
			L1Endpoint:         os.Getenv("L1_WS"),
			L2Endpoint:         os.Getenv("L2_WS"),
			L2EngineEndpoint:   os.Getenv("L2_AUTH"),
			PacayaInboxAddress: common.HexToAddress(os.Getenv("PACAYA_INBOX")),
			ShastaInboxAddress: common.HexToAddress(os.Getenv("SHASTA_INBOX")),
			TaikoAnchorAddress: common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
			JwtSecret:          string(jwtSecret),
		},
		BlobServerEndpoint: s.BlobServer.URL(),
	}))
	s.d = d

	// Init proposer
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
		BlobAllowed:             true,
	}, txmgrProposer, txmgrProposer))

	s.proposer = prop
	s.proposer.RegisterTxMgrSelectorToBlobServer(s.BlobServer)
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
		PacayaInboxAddress:    common.HexToAddress(os.Getenv("PACAYA_INBOX")),
		ShastaInboxAddress:    common.HexToAddress(os.Getenv("SHASTA_INBOX")),
		TaikoAnchorAddress:    common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		TaikoTokenAddress:     common.HexToAddress(os.Getenv("TAIKO_TOKEN")),
		L1ProverPrivKey:       l1ProverPrivKey,
		Dummy:                 true,
		ProveUnassignedBlocks: true,
		RPCTimeout:            10 * time.Minute,
		BackOffRetryInterval:  3 * time.Second,
		BackOffMaxRetries:     12,
	}, s.txmgr, s.txmgr))
}

func (s *ProverTestSuite) TestOnBatchProposed() {
	s.ForkIntoShasta(s.proposer, s.d.ChainSyncer().EventSyncer())

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

	// Prove the first Shasta proposal proposed in `ForkIntoShasta`.
	header, err := s.RPCClient.L1.HeaderByHash(context.Background(), eventLog.BlockHash)
	s.Nil(err)
	meta := metadata.NewTaikoProposalMetadataShasta(payload, header.Time)
	s.Nil(s.p.eventHandlers.batchProposedHandler.Handle(context.Background(), meta, func() {}))
	req := <-s.p.proofSubmissionCh
	s.Nil(s.p.requestProofOp(req.Meta))
	s.Nil(s.p.aggregateOp(<-s.p.batchesAggregationNotifyShasta, true))
	s.Nil(s.p.proofSubmitterShasta.BatchSubmitProofs(context.Background(), <-s.p.batchProofGenerationCh))

	// Propose and prove the second Shasta proposal.
	m := s.ProposeAndInsertValidBlock(s.proposer, s.d.ChainSyncer().EventSyncer())
	s.Nil(s.p.eventHandlers.batchProposedHandler.Handle(context.Background(), m, func() {}))
	req = <-s.p.proofSubmissionCh
	s.Nil(s.p.requestProofOp(req.Meta))
	s.Nil(s.p.aggregateOp(<-s.p.batchesAggregationNotifyShasta, true))
	s.Nil(s.p.proofSubmitterShasta.BatchSubmitProofs(context.Background(), <-s.p.batchProofGenerationCh))
}

func (s *ProverTestSuite) TestSubmitProofAggregationOp() {
	s.NotPanics(func() {
		s.p.withRetry(func() error {
			return s.p.submitProofAggregationOp(&proofProducer.BatchProofs{
				ProofResponses: []*proofProducer.ProofResponse{
					{
						BatchID: common.Big1,
						Meta:    &metadata.TaikoDataBlockMetadataPacaya{},
						Proof:   []byte{},
						Opts:    &proofProducer.ProofRequestOptionsPacaya{},
					},
				},
				BatchProof:        []byte{},
				BatchIDs:          []*big.Int{common.Big1},
				ProofType:         proofProducer.ProofTypeOp,
				SgxGethBatchProof: []byte{},
			})
		})
	})
}

func (s *ProverTestSuite) TestOnBatchesVerified() {
	s.NotPanics(func() {
		s.NotNil(s.p.eventHandlers.batchesVerifiedHandler.HandlePacaya(
			context.Background(),
			&pacayaBindings.TaikoInboxClientBatchesVerified{
				BatchId: testutils.RandomHash().Big().Uint64(),
				Raw: types.Log{
					BlockHash:   testutils.RandomHash(),
					BlockNumber: testutils.RandomHash().Big().Uint64(),
				},
			}))
	})
}

func (s *ProverTestSuite) TestProveOp() {
	m := s.ProposeAndInsertValidBlock(s.proposer, s.d.ChainSyncer().EventSyncer())
	s.True(m.IsPacaya())

	sink1 := make(chan *pacayaBindings.TaikoInboxClientBatchesProved)
	sub1, err := s.p.rpc.PacayaClients.TaikoInbox.WatchBatchesProved(nil, sink1)
	s.Nil(err)
	defer func() {
		sub1.Unsubscribe()
		close(sink1)
	}()
	s.Nil(s.p.proveOp())

	req := <-s.p.proofSubmissionCh
	s.Nil(s.p.requestProofOp(req.Meta))
	s.Nil(s.p.aggregateOp(<-s.p.batchesAggregationNotifyPacaya, false))
	s.Nil(s.p.proofSubmitterPacaya.BatchSubmitProofs(context.Background(), <-s.p.batchProofGenerationCh))

	var (
		blockHash  common.Hash
		parentHash common.Hash
		blockID    *big.Int
	)

	e := <-sink1
	tran := e.Transitions[len(e.Transitions)-1]
	blockHash = common.BytesToHash(tran.BlockHash[:])
	parentHash = common.BytesToHash(tran.ParentHash[:])
	batch, err := s.p.rpc.GetBatchByID(context.Background(), new(big.Int).SetUint64(e.BatchIds[len(e.BatchIds)-1]))
	s.Nil(err)
	blockID = new(big.Int).SetUint64(batch.LastBlockId)

	header, err := s.p.rpc.L2.HeaderByNumber(context.Background(), blockID)
	s.Nil(err)

	s.Equal(header.Hash(), blockHash)
	s.Equal(header.ParentHash, parentHash)
}

func (s *ProverTestSuite) TestProveMultiBlobBatch() {
	m := s.ProposeAndInsertValidBlock(s.proposer, s.d.ChainSyncer().EventSyncer())
	s.True(m.IsPacaya())

	l2Head1, err := s.RPCClient.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.NotZero(l2Head1.Number.Uint64())

	var (
		batchSize    = 2
		txNumInBatch = 500
	)

	proposeMultiBlockBatch := func() {
		// Propose a batch which contains two blobs.
		var txsBatch = make([]types.Transactions, batchSize)
		testAddrNonce, err := s.RPCClient.L2.NonceAt(context.Background(), s.TestAddr, nil)
		s.Nil(err)

		for i := 0; i < batchSize; i++ {
			for j := 0; j < txNumInBatch; j++ {
				to := common.BytesToAddress(testutils.RandomBytes(32))

				tx, err := testutils.AssembleAndSendTestTx(
					s.RPCClient.L2,
					s.TestAddrPrivKey,
					uint64(i*txNumInBatch+int(testAddrNonce)+j),
					&to,
					common.Big1,
					[]byte{1},
				)
				s.Nil(err)
				txsBatch[i] = append(txsBatch[i], tx)
			}
		}

		s.Nil(s.proposer.ProposeTxListPacaya(context.Background(), txsBatch, common.Hash{}))
		s.Nil(s.d.ChainSyncer().EventSyncer().ProcessL1Blocks(context.Background()))
	}

	proposeMultiBlockBatch()
	l2Head2, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(l2Head1.Number.Uint64()+uint64(batchSize), l2Head2.Number().Uint64())
	s.Equal(txNumInBatch+1, l2Head2.Transactions().Len())

	s.Nil(s.p.proveOp())

	for req := range s.p.proofSubmissionCh {
		if !req.Meta.IsPacaya() {
			continue
		}
		s.Nil(s.p.requestProofOp(req.Meta))
		s.Nil(s.p.aggregateOp(<-s.p.batchesAggregationNotifyPacaya, false))
		s.Nil(s.p.proofSubmitterPacaya.BatchSubmitProofs(context.Background(), <-s.p.batchProofGenerationCh))
		if req.Meta.Pacaya().GetLastBlockID() >= l2Head2.Number().Uint64() {
			break
		}
	}

	proposeMultiBlockBatch()

	l2Head3, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(l2Head2.Number().Uint64()+uint64(batchSize), l2Head3.Number().Uint64())
	s.Equal(txNumInBatch+1, l2Head3.Transactions().Len())

	s.Nil(s.p.proveOp())

	for req := range s.p.proofSubmissionCh {
		s.Nil(s.p.requestProofOp(req.Meta))
		s.Nil(s.p.aggregateOp(<-s.p.batchesAggregationNotifyPacaya, false))
		s.Nil(s.p.proofSubmitterPacaya.BatchSubmitProofs(context.Background(), <-s.p.batchProofGenerationCh))
		if req.Meta.Pacaya().GetLastBlockID() >= l2Head3.Number().Uint64() {
			break
		}
	}
}

func (s *ProverTestSuite) TestAggregateProofsAlreadyProved() {
	// Init batch prover
	var (
		l1ProverPrivKey = s.KeyFromEnv("L1_PROVER_PRIVATE_KEY")
		batchSize       = 2
	)
	decimal, err := s.RPCClient.PacayaClients.TaikoToken.Decimals(nil)
	s.Nil(err)
	batchProver := new(Prover)
	s.Nil(InitFromConfig(context.Background(), batchProver, &Config{
		L1WsEndpoint:          os.Getenv("L1_WS"),
		L2WsEndpoint:          os.Getenv("L2_WS"),
		L2HttpEndpoint:        os.Getenv("L2_HTTP"),
		PacayaInboxAddress:    common.HexToAddress(os.Getenv("PACAYA_INBOX")),
		ShastaInboxAddress:    common.HexToAddress(os.Getenv("SHASTA_INBOX")),
		TaikoAnchorAddress:    common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		ProverSetAddress:      common.HexToAddress(os.Getenv("PROVER_SET")),
		TaikoTokenAddress:     common.HexToAddress(os.Getenv("TAIKO_TOKEN")),
		L1ProverPrivKey:       l1ProverPrivKey,
		Dummy:                 true,
		ProveUnassignedBlocks: true,
		Allowance:             new(big.Int).Exp(big.NewInt(1_000_000_100), new(big.Int).SetUint64(uint64(decimal)), nil),
		RPCTimeout:            3 * time.Second,
		BackOffRetryInterval:  3 * time.Second,
		BackOffMaxRetries:     12,
		SGXProofBufferSize:    uint64(batchSize),
		ZKVMProofBufferSize:   uint64(batchSize),
	}, s.txmgr, s.txmgr))

	for i := 0; i < batchSize; i++ {
		_ = s.ProposeAndInsertValidBlock(s.proposer, s.d.ChainSyncer().EventSyncer())
	}

	sink1 := make(chan *pacayaBindings.TaikoInboxClientBatchesProved, batchSize)
	sub1, err := s.p.rpc.PacayaClients.TaikoInbox.WatchBatchesProved(nil, sink1)
	s.Nil(err)
	defer func() {
		sub1.Unsubscribe()
		close(sink1)
	}()

	s.Nil(s.p.proveOp())
	s.Nil(batchProver.proveOp())
	for i := 0; i < batchSize; i++ {
		req1 := <-s.p.proofSubmissionCh
		s.Nil(s.p.requestProofOp(req1.Meta))
		req2 := <-batchProver.proofSubmissionCh
		s.Nil(batchProver.requestProofOp(req2.Meta))
		s.Nil(s.p.aggregateOp(<-s.p.batchesAggregationNotifyPacaya, false))
		s.Nil(s.p.proofSubmitterPacaya.BatchSubmitProofs(context.Background(), <-s.p.batchProofGenerationCh))
	}
	s.Nil(batchProver.aggregateOp(<-batchProver.batchesAggregationNotifyPacaya, false))
	s.ErrorIs(
		batchProver.proofSubmitterPacaya.BatchSubmitProofs(context.Background(), <-batchProver.batchProofGenerationCh),
		proofSubmitter.ErrInvalidProof,
	)
}

func (s *ProverTestSuite) TestAggregateProofs() {
	// Init a batch prover
	var (
		l1ProverPrivKey = s.KeyFromEnv("L1_PROVER_PRIVATE_KEY")
		batchSize       = 2
	)
	decimal, err := s.RPCClient.PacayaClients.TaikoToken.Decimals(nil)
	s.Nil(err)
	batchProver := new(Prover)
	s.Nil(InitFromConfig(context.Background(), batchProver, &Config{
		L1WsEndpoint:          os.Getenv("L1_WS"),
		L2WsEndpoint:          os.Getenv("L2_WS"),
		L2HttpEndpoint:        os.Getenv("L2_HTTP"),
		PacayaInboxAddress:    common.HexToAddress(os.Getenv("PACAYA_INBOX")),
		ShastaInboxAddress:    common.HexToAddress(os.Getenv("SHASTA_INBOX")),
		TaikoAnchorAddress:    common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		ProverSetAddress:      common.HexToAddress(os.Getenv("PROVER_SET")),
		TaikoTokenAddress:     common.HexToAddress(os.Getenv("TAIKO_TOKEN")),
		L1ProverPrivKey:       l1ProverPrivKey,
		Dummy:                 true,
		ProveUnassignedBlocks: true,
		Allowance:             new(big.Int).Exp(big.NewInt(1_000_000_100), new(big.Int).SetUint64(uint64(decimal)), nil),
		RPCTimeout:            3 * time.Second,
		BackOffRetryInterval:  3 * time.Second,
		BackOffMaxRetries:     12,
		SGXProofBufferSize:    uint64(batchSize),
		ZKVMProofBufferSize:   uint64(batchSize),
	}, s.txmgr, s.txmgr))

	for i := 0; i < batchSize; i++ {
		_ = s.ProposeAndInsertValidBlock(s.proposer, s.d.ChainSyncer().EventSyncer())
	}

	sink := make(chan *pacayaBindings.TaikoInboxClientBatchesProved, batchSize)
	sub, err := s.p.rpc.PacayaClients.TaikoInbox.WatchBatchesProved(nil, sink)
	s.Nil(err)
	defer func() {
		sub.Unsubscribe()
		close(sink)
	}()

	s.Nil(batchProver.proveOp())
	for i := 0; i < batchSize; i++ {
		req := <-batchProver.proofSubmissionCh
		s.Nil(batchProver.requestProofOp(req.Meta))
	}
	proofType := <-batchProver.batchesAggregationNotifyPacaya
	s.Nil(batchProver.aggregateOp(proofType, false))
	s.Nil(batchProver.proofSubmitterPacaya.BatchSubmitProofs(context.Background(), <-batchProver.batchProofGenerationCh))
}

func (s *ProverTestSuite) TestSetApprovalAlreadySetHigher() {
	s.p.cfg.Allowance = common.Big256
	s.Nil(s.p.setApprovalAmount(context.Background(), s.p.cfg.PacayaInboxAddress))

	originalAllowance, err := s.p.rpc.PacayaClients.TaikoToken.Allowance(
		nil,
		s.p.ProverAddress(),
		s.p.cfg.PacayaInboxAddress,
	)
	s.Nil(err)
	s.NotZero(originalAllowance.Uint64())

	s.p.cfg.Allowance = new(big.Int).Sub(originalAllowance, common.Big1)

	s.Nil(s.p.setApprovalAmount(context.Background(), s.p.cfg.PacayaInboxAddress))

	allowance, err := s.p.rpc.PacayaClients.TaikoToken.Allowance(nil, s.p.ProverAddress(), s.p.cfg.PacayaInboxAddress)
	s.Nil(err)

	s.Zero(allowance.Cmp(originalAllowance))
}

func (s *ProverTestSuite) TearDownTest() {
	defer s.ClientTestSuite.TearDownTest()

	if s.p.ctx.Err() == nil {
		s.cancel()
	}
	s.p.Close(context.Background())
}

func (s *ProverTestSuite) TestInvalidPacayaProof() {
	l1Current, err := s.p.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	m := s.ProposeAndInsertValidBlock(s.proposer, s.d.ChainSyncer().EventSyncer())
	s.True(m.IsPacaya())
	s.Nil(s.p.proveOp())

	var req *proofProducer.ProofRequestBody
	for r := range s.p.proofSubmissionCh {
		if r.Meta.IsPacaya() && r.Meta.Pacaya().GetBatchID().Uint64() == m.Pacaya().GetBatchID().Uint64() {
			req = r
			break
		}
	}
	s.NotNil(req)
	s.True(req.Meta.IsPacaya())
	s.Equal(m.Pacaya().GetBatchID().Uint64(), req.Meta.Pacaya().GetBatchID().Uint64())

	// Submit a valid proof.
	s.Nil(s.p.proofSubmitterPacaya.RequestProof(context.Background(), m))
	s.Nil(s.p.aggregateOp(<-s.p.batchesAggregationNotifyPacaya, false))
	batchRes := <-s.p.batchProofGenerationCh
	res := batchRes.ProofResponses[0]
	s.Equal(m.Pacaya().GetBatchID().Uint64(), res.Meta.Pacaya().GetBatchID().Uint64())
	s.NotEmpty(res.Opts.PacayaOptions().Headers)

	// Submit two conflict proofs
	sender := transaction.NewSender(
		s.p.rpc,
		s.txmgr,
		s.p.privateTxmgr,
		s.d.ProverSetAddress,
		s.proposer.ProposeBatchTxGasLimit,
	)
	builder := transaction.NewProveBatchesTxBuilder(
		s.RPCClient,
		common.HexToAddress(os.Getenv("PACAYA_INBOX")),
		common.HexToAddress(os.Getenv("SHASTA_INBOX")),
		common.Address{},
	)
	originalRoot := res.Opts.PacayaOptions().Headers[len(res.Opts.PacayaOptions().Headers)-1].Root
	res.Opts.PacayaOptions().Headers[len(res.Opts.PacayaOptions().Headers)-1].Root = testutils.RandomHash()
	s.Nil(sender.SendBatchProof(
		context.Background(),
		builder.BuildProveBatchesPacaya(batchRes),
		batchRes,
	))

	// Transition should be created, and blockHash should not be zero.
	transition, err := s.p.rpc.PacayaClients.TaikoInbox.GetTransitionByParentHash(
		nil,
		req.Meta.Pacaya().GetBatchID().Uint64(),
		res.Opts.PacayaOptions().Headers[len(res.Opts.PacayaOptions().Headers)-1].ParentHash,
	)
	s.Nil(err)
	s.Equal(
		res.Opts.PacayaOptions().Headers[len(res.Opts.PacayaOptions().Headers)-1].ParentHash,
		common.BytesToHash(transition.ParentHash[:]),
	)
	s.NotEqual([32]byte{}, transition.BlockHash)

	// Inbox should not be paused.
	paused, err := s.p.rpc.PacayaClients.TaikoInbox.Paused(nil)
	s.Nil(err)
	s.False(paused)

	s.p.sharedState.SetL1Current(l1Current)
	s.p.sharedState.SetLastHandledPacayaBatchID(0)

	s.Nil(s.p.proveOp())
	for r := range s.p.proofSubmissionCh {
		if r.Meta.IsPacaya() && r.Meta.Pacaya().GetBatchID().Uint64() == m.Pacaya().GetBatchID().Uint64() {
			req = r
			break
		}
	}

	res.Opts.PacayaOptions().Headers[len(res.Opts.PacayaOptions().Headers)-1].Root = originalRoot
	s.Nil(sender.SendBatchProof(
		context.Background(),
		builder.BuildProveBatchesPacaya(batchRes),
		batchRes,
	))

	// BlockHash of the transition should be zero now, and Inbox should be paused.
	transition, err = s.p.rpc.PacayaClients.TaikoInbox.GetTransitionByParentHash(
		nil,
		req.Meta.Pacaya().GetBatchID().Uint64(),
		res.Opts.PacayaOptions().Headers[len(res.Opts.PacayaOptions().Headers)-1].ParentHash,
	)
	s.Nil(err)
	s.Equal(
		res.Opts.PacayaOptions().Headers[len(res.Opts.PacayaOptions().Headers)-1].ParentHash,
		common.BytesToHash(transition.ParentHash[:]),
	)
	s.Equal([32]byte{}, transition.BlockHash)

	paused, err = s.p.rpc.PacayaClients.TaikoInbox.Paused(nil)
	s.Nil(err)
	s.True(paused)

	// Unpause the TaikoInbox contract
	data, err := encoding.TaikoInboxABI.Pack("unpause")
	s.Nil(err)
	receipt, err := s.TxMgr("unpauseTaikoInbox", s.KeyFromEnv("L1_CONTRACT_OWNER_PRIVATE_KEY")).
		Send(
			context.Background(),
			txmgr.TxCandidate{TxData: data, To: &s.p.cfg.PacayaInboxAddress},
		)
	s.Nil(err)
	s.Equal(types.ReceiptStatusSuccessful, receipt.Status)

	// Then submit a valid proof again
	s.p.sharedState.SetL1Current(l1Current)
	s.p.sharedState.SetLastHandledPacayaBatchID(0)

	s.Nil(s.p.proveOp())
	for r := range s.p.proofSubmissionCh {
		if r.Meta.IsPacaya() && r.Meta.Pacaya().GetBatchID().Uint64() == m.Pacaya().GetBatchID().Uint64() {
			req = r
			break
		}
	}

	s.Nil(sender.SendBatchProof(
		context.Background(),
		builder.BuildProveBatchesPacaya(batchRes),
		batchRes,
	))

	// BlockHash of the transition should not be zero now, and Inbox should be unpaused.
	transition, err = s.p.rpc.PacayaClients.TaikoInbox.GetTransitionByParentHash(
		nil,
		req.Meta.Pacaya().GetBatchID().Uint64(),
		res.Opts.PacayaOptions().Headers[len(res.Opts.PacayaOptions().Headers)-1].ParentHash,
	)
	s.Nil(err)
	s.Equal(
		res.Opts.PacayaOptions().Headers[len(res.Opts.PacayaOptions().Headers)-1].ParentHash,
		common.BytesToHash(transition.ParentHash[:]),
	)
	s.NotEqual([32]byte{}, transition.BlockHash)

	paused, err = s.p.rpc.PacayaClients.TaikoInbox.Paused(nil)
	s.Nil(err)
	s.False(paused)
}

func (s *ProverTestSuite) TestForceAggregate() {
	batchSize := 3
	restoreMonitorInterval := proofSubmitter.SetProofBufferMonitorInterval(50 * time.Millisecond)
	defer restoreMonitorInterval()
	// Init a batch prover
	l1ProverPrivKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROVER_PRIVATE_KEY")))
	s.Nil(err)
	decimal, err := s.RPCClient.PacayaClients.TaikoToken.Decimals(nil)
	s.Nil(err)
	s.NotZero(decimal)
	batchProver := new(Prover)
	s.Nil(InitFromConfig(context.Background(), batchProver, &Config{
		L1WsEndpoint:          os.Getenv("L1_WS"),
		L2WsEndpoint:          os.Getenv("L2_WS"),
		L2HttpEndpoint:        os.Getenv("L2_HTTP"),
		PacayaInboxAddress:    common.HexToAddress(os.Getenv("PACAYA_INBOX")),
		ShastaInboxAddress:    common.HexToAddress(os.Getenv("SHASTA_INBOX")),
		TaikoAnchorAddress:    common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		TaikoTokenAddress:     common.HexToAddress(os.Getenv("TAIKO_TOKEN")),
		ProverSetAddress:      common.HexToAddress(os.Getenv("PROVER_SET")),
		L1ProverPrivKey:       l1ProverPrivKey,
		Dummy:                 true,
		ProveUnassignedBlocks: true,
		Allowance: new(big.Int).Exp(
			big.NewInt(1_000_000_000),
			new(big.Int).SetUint64(uint64(decimal)),
			nil,
		),
		RPCTimeout:                3 * time.Second,
		BackOffRetryInterval:      3 * time.Second,
		BackOffMaxRetries:         12,
		SGXProofBufferSize:        uint64(batchSize),
		ZKVMProofBufferSize:       uint64(batchSize),
		ForceBatchProvingInterval: 500 * time.Millisecond,
	}, s.txmgr, s.txmgr))

	for i := 0; i < 1; i++ {
		_ = s.ProposeAndInsertValidBlock(s.proposer, s.d.ChainSyncer().EventSyncer())
	}

	sink := make(chan *pacayaBindings.TaikoInboxClientBatchesProved, batchSize)
	sub, err := s.p.rpc.PacayaClients.TaikoInbox.WatchBatchesProved(nil, sink)
	s.Nil(err)
	defer func() {
		sub.Unsubscribe()
		close(sink)
	}()

	s.Nil(batchProver.proveOp())
	req1 := <-batchProver.proofSubmissionCh
	s.Nil(batchProver.requestProofOp(req1.Meta))

	select {
	case proofType := <-batchProver.batchesAggregationNotifyPacaya:
		log.Info("Received agg request", "proofType", proofType)
		s.Nil(batchProver.aggregateOp(proofType, false))
	case <-time.After(3 * time.Second):
		s.Fail("timeout waiting for agg request")
	}
	s.Nil(batchProver.proofSubmitterPacaya.BatchSubmitProofs(context.Background(), <-batchProver.batchProofGenerationCh))
}

func TestProverTestSuite(t *testing.T) {
	suite.Run(t, new(ProverTestSuite))
}

func (s *ProverTestSuite) initProver(ctx context.Context, key *ecdsa.PrivateKey) {
	decimal, err := s.RPCClient.PacayaClients.TaikoToken.Decimals(nil)
	s.Nil(err)

	proposerKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROPOSER_PRIVATE_KEY")))
	s.Nil(err)
	s.NotNil(proposerKey)

	p := new(Prover)
	s.Nil(InitFromConfig(ctx, p, &Config{
		L1WsEndpoint:           os.Getenv("L1_WS"),
		L2WsEndpoint:           os.Getenv("L2_WS"),
		L2HttpEndpoint:         os.Getenv("L2_HTTP"),
		PacayaInboxAddress:     common.HexToAddress(os.Getenv("PACAYA_INBOX")),
		ShastaInboxAddress:     common.HexToAddress(os.Getenv("SHASTA_INBOX")),
		TaikoAnchorAddress:     common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		TaikoTokenAddress:      common.HexToAddress(os.Getenv("TAIKO_TOKEN")),
		ProverSetAddress:       common.HexToAddress(os.Getenv("PROVER_SET")),
		L1ProverPrivKey:        key,
		Dummy:                  true,
		ProveUnassignedBlocks:  true,
		LocalProposerAddresses: []common.Address{crypto.PubkeyToAddress(proposerKey.PublicKey)},
		Allowance:              new(big.Int).Exp(big.NewInt(1_000_000_100), new(big.Int).SetUint64(uint64(decimal)), nil),
		RPCTimeout:             3 * time.Second,
		BackOffRetryInterval:   3 * time.Second,
		BackOffMaxRetries:      12,
		SGXProofBufferSize:     1,
		ZKVMProofBufferSize:    1,
		BlockConfirmations:     0,
	}, s.txmgr, s.txmgr))
	s.p = p
}
