package prover

import (
	"context"
	"crypto/ecdsa"
	"math/big"
	"net/url"
	"os"
	"strconv"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethdb/memorydb"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-client/bindings"
	"github.com/taikoxyz/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-client/driver"
	"github.com/taikoxyz/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-client/pkg/jwt"
	"github.com/taikoxyz/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-client/proposer"
	guardianproversender "github.com/taikoxyz/taiko-client/prover/guardian_prover_sender"
	producer "github.com/taikoxyz/taiko-client/prover/proof_producer"
)

type ProverTestSuite struct {
	testutils.ClientTestSuite
	p        *Prover
	cancel   context.CancelFunc
	d        *driver.Driver
	proposer *proposer.Proposer
}

func (s *ProverTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	// Init prover
	l1ProverPrivKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROVER_PRIVATE_KEY")))
	s.Nil(err)

	ctx, cancel := context.WithCancel(context.Background())
	proverServerURL := s.initProver(ctx, l1ProverPrivKey)
	s.cancel = cancel

	// Init driver
	jwtSecret, err := jwt.ParseSecretFromFile(os.Getenv("JWT_SECRET"))
	s.Nil(err)
	s.NotEmpty(jwtSecret)

	d := new(driver.Driver)
	s.Nil(d.InitFromConfig(context.Background(), &driver.Config{
		ClientConfig: &rpc.ClientConfig{
			L1Endpoint:       os.Getenv("L1_NODE_WS_ENDPOINT"),
			L2Endpoint:       os.Getenv("L2_EXECUTION_ENGINE_WS_ENDPOINT"),
			L2EngineEndpoint: os.Getenv("L2_EXECUTION_ENGINE_AUTH_ENDPOINT"),
			TaikoL1Address:   common.HexToAddress(os.Getenv("TAIKO_L1_ADDRESS")),
			TaikoL2Address:   common.HexToAddress(os.Getenv("TAIKO_L2_ADDRESS")),
			JwtSecret:        string(jwtSecret),
		},
	}))
	s.d = d

	// Init proposer
	l1ProposerPrivKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROPOSER_PRIVATE_KEY")))
	s.Nil(err)

	prop := new(proposer.Proposer)

	proposeInterval := 1024 * time.Hour // No need to periodically propose transactions list in unit tests
	s.Nil(prop.InitFromConfig(context.Background(), &proposer.Config{
		ClientConfig: &rpc.ClientConfig{
			L1Endpoint:        os.Getenv("L1_NODE_WS_ENDPOINT"),
			L2Endpoint:        os.Getenv("L2_EXECUTION_ENGINE_WS_ENDPOINT"),
			TaikoL1Address:    common.HexToAddress(os.Getenv("TAIKO_L1_ADDRESS")),
			TaikoL2Address:    common.HexToAddress(os.Getenv("TAIKO_L2_ADDRESS")),
			TaikoTokenAddress: common.HexToAddress(os.Getenv("TAIKO_TOKEN_ADDRESS")),
		},
		AssignmentHookAddress:      common.HexToAddress(os.Getenv("ASSIGNMENT_HOOK_ADDRESS")),
		L1ProposerPrivKey:          l1ProposerPrivKey,
		L2SuggestedFeeRecipient:    common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")),
		ProposeInterval:            &proposeInterval,
		MaxProposedTxListsPerEpoch: 1,
		WaitReceiptTimeout:         12 * time.Second,
		ProverEndpoints:            []*url.URL{proverServerURL},
		OptimisticTierFee:          common.Big256,
		SgxTierFee:                 common.Big256,
		MaxTierFeePriceBumps:       3,
		TierFeePriceBump:           common.Big2,
		L1BlockBuilderTip:          common.Big0,
	}))

	s.proposer = prop
}

func (s *ProverTestSuite) TestName() {
	s.Equal("prover", s.p.Name())
}

func (s *ProverTestSuite) TestInitError() {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	l1ProverPrivKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROVER_PRIVATE_KEY")))
	s.Nil(err)

	p := new(Prover)
	// Error should be "context canceled", instead is "Dial ethclient error:"
	s.ErrorContains(InitFromConfig(ctx, p, &Config{
		L1WsEndpoint:                      os.Getenv("L1_NODE_WS_ENDPOINT"),
		L1HttpEndpoint:                    os.Getenv("L1_NODE_HTTP_ENDPOINT"),
		L2WsEndpoint:                      os.Getenv("L2_EXECUTION_ENGINE_WS_ENDPOINT"),
		L2HttpEndpoint:                    os.Getenv("L2_EXECUTION_ENGINE_HTTP_ENDPOINT"),
		TaikoL1Address:                    common.HexToAddress(os.Getenv("TAIKO_L1_ADDRESS")),
		TaikoL2Address:                    common.HexToAddress(os.Getenv("TAIKO_L2_ADDRESS")),
		TaikoTokenAddress:                 common.HexToAddress(os.Getenv("TAIKO_TOKEN_ADDRESS")),
		AssignmentHookAddress:             common.HexToAddress(os.Getenv("ASSIGNMENT_HOOK_CONTRACT_ADDRESS")),
		L1ProverPrivKey:                   l1ProverPrivKey,
		Dummy:                             true,
		ProveUnassignedBlocks:             true,
		ProveBlockTxReplacementMultiplier: 2,
		RPCTimeout:                        10 * time.Minute,
		BackOffMaxRetrys:                  3,
	}), "dial tcp:")
}

func (s *ProverTestSuite) TestOnBlockProposed() {
	// Init prover
	l1ProverPrivKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROVER_PRIVATE_KEY")))
	s.Nil(err)
	s.p.cfg.L1ProverPrivKey = l1ProverPrivKey
	// Valid block
	e := s.ProposeAndInsertValidBlock(s.proposer, s.d.ChainSyncer().CalldataSyncer())
	s.Nil(s.p.onBlockProposed(context.Background(), e, func() {}))
	s.Nil(s.p.selectSubmitter(e.Meta.MinTier).SubmitProof(context.Background(), <-s.p.proofGenerationCh))

	// Empty blocks
	for _, e = range s.ProposeAndInsertEmptyBlocks(
		s.proposer,
		s.d.ChainSyncer().CalldataSyncer(),
	) {
		s.Nil(s.p.onBlockProposed(context.Background(), e, func() {}))

		s.Nil(s.p.selectSubmitter(e.Meta.MinTier).SubmitProof(context.Background(), <-s.p.proofGenerationCh))
	}
}

func (s *ProverTestSuite) TestOnBlockVerifiedEmptyBlockHash() {
	s.Nil(s.p.onBlockVerified(context.Background(), &bindings.TaikoL1ClientBlockVerified{
		BlockId:   common.Big1,
		BlockHash: common.Hash{},
	}))
}

func (s *ProverTestSuite) TestSubmitProofOp() {
	s.NotPanics(func() {
		s.p.submitProofOp(context.Background(), &producer.ProofWithHeader{
			BlockID: common.Big1,
			Meta:    &bindings.TaikoDataBlockMetadata{},
			Header:  &types.Header{},
			Proof:   []byte{},
			Tier:    encoding.TierOptimisticID,
			Opts:    &producer.ProofRequestOptions{},
		})
	})
	s.NotPanics(func() {
		s.p.submitProofOp(context.Background(), &producer.ProofWithHeader{
			BlockID: common.Big1,
			Meta:    &bindings.TaikoDataBlockMetadata{},
			Header:  &types.Header{},
			Proof:   []byte{},
			Tier:    encoding.TierOptimisticID,
			Opts:    &producer.ProofRequestOptions{},
		})
	})
}

func (s *ProverTestSuite) TestOnBlockVerified() {
	id := testutils.RandomHash().Big().Uint64()
	s.Nil(s.p.onBlockVerified(context.Background(), &bindings.TaikoL1ClientBlockVerified{
		BlockId: testutils.RandomHash().Big(),
		Raw: types.Log{
			BlockHash:   testutils.RandomHash(),
			BlockNumber: id,
		},
	}))
}

func (s *ProverTestSuite) TestContestWrongBlocks() {
	s.p.cfg.ContesterMode = false
	e := s.ProposeAndInsertValidBlock(s.proposer, s.d.ChainSyncer().CalldataSyncer())
	s.Nil(s.p.onTransitionProved(context.Background(), &bindings.TaikoL1ClientTransitionProved{
		BlockId: e.BlockId,
		Tier:    e.Meta.MinTier,
	}))
	s.p.cfg.ContesterMode = true

	// Submit a wrong proof at first.
	sink := make(chan *bindings.TaikoL1ClientTransitionProved)
	header, err := s.p.rpc.L2.HeaderByNumber(context.Background(), e.BlockId)
	s.Nil(err)

	sub, err := s.p.rpc.TaikoL1.WatchTransitionProved(nil, sink, nil)
	s.Nil(err)
	defer func() {
		sub.Unsubscribe()
		close(sink)
	}()

	s.Nil(s.p.proveOp())
	proofWithHeader := <-s.p.proofGenerationCh
	proofWithHeader.Opts.BlockHash = testutils.RandomHash()
	s.Nil(s.p.selectSubmitter(e.Meta.MinTier).SubmitProof(context.Background(), proofWithHeader))

	event := <-sink
	s.Equal(header.Number.Uint64(), event.BlockId.Uint64())
	s.Equal(common.BytesToHash(proofWithHeader.Opts.BlockHash[:]), common.BytesToHash(event.Tran.BlockHash[:]))
	s.NotEqual(header.Hash(), common.BytesToHash(event.Tran.BlockHash[:]))
	s.Equal(header.ParentHash, common.BytesToHash(event.Tran.ParentHash[:]))

	// Contest the transition.
	contestedSink := make(chan *bindings.TaikoL1ClientTransitionContested)
	contestedSub, err := s.p.rpc.TaikoL1.WatchTransitionContested(nil, contestedSink, nil)
	s.Nil(err)
	defer func() {
		contestedSub.Unsubscribe()
		close(contestedSink)
	}()

	contesterKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_CONTRACT_OWNER_PRIVATE_KEY")))
	s.Nil(err)

	s.NotNil(s.initProver(
		context.Background(),
		contesterKey,
	))
	s.p.cfg.ContesterMode = true

	s.Greater(header.Number.Uint64(), uint64(0))
	s.Nil(s.p.onTransitionProved(context.Background(), event))

	contestedEvent := <-contestedSink
	s.Equal(header.Number.Uint64(), contestedEvent.BlockId.Uint64())
	s.Equal(header.Hash(), common.BytesToHash(contestedEvent.Tran.BlockHash[:]))
	s.Equal(header.ParentHash, common.BytesToHash(contestedEvent.Tran.ParentHash[:]))

	s.Nil(s.p.onTransitionContested(context.Background(), contestedEvent))

	s.p.cfg.GuardianProverAddress = common.HexToAddress(os.Getenv("GUARDIAN_PROVER_CONTRACT_ADDRESS"))
	s.True(s.p.IsGuardianProver())

	s.p.rpc.GuardianProver, err = bindings.NewGuardianProver(s.p.cfg.GuardianProverAddress, s.p.rpc.L1)
	s.Nil(err)

	approvedSink := make(chan *bindings.GuardianProverApproved)
	approvedSub, err := s.p.rpc.GuardianProver.WatchApproved(nil, approvedSink, [](*big.Int){})
	s.Nil(err)
	defer func() {
		approvedSub.Unsubscribe()
		close(approvedSink)
	}()

	s.Nil(s.p.selectSubmitter(encoding.TierGuardianID).SubmitProof(context.Background(), <-s.p.proofGenerationCh))
	approvedEvent := <-approvedSink

	s.Equal(header.Number.Uint64(), approvedEvent.OperationId.Uint64())
}

func (s *ProverTestSuite) TestProveExpiredUnassignedBlock() {
	e := s.ProposeAndInsertValidBlock(s.proposer, s.d.ChainSyncer().CalldataSyncer())
	sink := make(chan *bindings.TaikoL1ClientTransitionProved)

	header, err := s.p.rpc.L2.HeaderByNumber(context.Background(), e.BlockId)
	s.Nil(err)

	sub, err := s.p.rpc.TaikoL1.WatchTransitionProved(nil, sink, nil)
	s.Nil(err)
	defer func() {
		sub.Unsubscribe()
		close(sink)
	}()

	e.AssignedProver = common.BytesToAddress(testutils.RandomHash().Bytes())
	s.p.cfg.GuardianProverAddress = common.Address{}
	s.Nil(s.p.onProvingWindowExpired(context.Background(), e))
	s.Nil(s.p.selectSubmitter(e.Meta.MinTier).SubmitProof(context.Background(), <-s.p.proofGenerationCh))

	event := <-sink
	s.Equal(header.Number.Uint64(), event.BlockId.Uint64())
	s.Equal(header.Hash(), common.BytesToHash(event.Tran.BlockHash[:]))
	s.Equal(header.ParentHash, common.BytesToHash(event.Tran.ParentHash[:]))
}

func (s *ProverTestSuite) TestSelectSubmitter() {
	submitter := s.p.selectSubmitter(encoding.TierGuardianID - 1)
	s.NotNil(submitter)
	s.Equal(encoding.TierGuardianID, submitter.Tier())
}

func (s *ProverTestSuite) TestSelectSubmitterNotFound() {
	submitter := s.p.selectSubmitter(encoding.TierGuardianID + 1)
	s.Nil(submitter)
}

func (s *ProverTestSuite) TestGetSubmitterByTier() {
	submitter := s.p.getSubmitterByTier(encoding.TierGuardianID)
	s.NotNil(submitter)
	s.Equal(encoding.TierGuardianID, submitter.Tier())
	s.Nil(s.p.getSubmitterByTier(encoding.TierGuardianID + 1))
}

func (s *ProverTestSuite) TestGetProvingWindowNotFound() {
	_, err := s.p.getProvingWindow(&bindings.TaikoL1ClientBlockProposed{
		Meta: bindings.TaikoDataBlockMetadata{
			MinTier: encoding.TierGuardianID + 1,
		},
	})
	s.ErrorIs(err, errTierNotFound)
}

func (s *ProverTestSuite) TestIsBlockVerified() {
	vars, err := s.p.rpc.TaikoL1.GetStateVariables(nil)
	s.Nil(err)

	verified, err := s.p.isBlockVerified(new(big.Int).SetUint64(vars.B.LastVerifiedBlockId))
	s.Nil(err)
	s.True(verified)

	verified, err = s.p.isBlockVerified(new(big.Int).SetUint64(vars.B.LastVerifiedBlockId + 1))
	s.Nil(err)
	s.False(verified)
}

func (s *ProverTestSuite) TestProveOp() {
	e := s.ProposeAndInsertValidBlock(s.proposer, s.d.ChainSyncer().CalldataSyncer())
	sink := make(chan *bindings.TaikoL1ClientTransitionProved)

	header, err := s.p.rpc.L2.HeaderByNumber(context.Background(), e.BlockId)
	s.Nil(err)

	sub, err := s.p.rpc.TaikoL1.WatchTransitionProved(nil, sink, nil)
	s.Nil(err)
	defer func() {
		sub.Unsubscribe()
		close(sink)
	}()

	s.Nil(s.p.proveOp())
	s.Nil(s.p.selectSubmitter(e.Meta.MinTier).SubmitProof(context.Background(), <-s.p.proofGenerationCh))

	event := <-sink
	s.Equal(header.Number.Uint64(), event.BlockId.Uint64())
	s.Equal(header.Hash(), common.BytesToHash(event.Tran.BlockHash[:]))
	s.Equal(header.ParentHash, common.BytesToHash(event.Tran.ParentHash[:]))
}

func (s *ProverTestSuite) TestSetApprovalAmount() {
	opts, err := bind.NewKeyedTransactorWithChainID(s.p.proverPrivateKey, s.p.rpc.L1.ChainID)
	s.Nil(err)

	tx, err := s.p.rpc.TaikoToken.Approve(opts, s.p.cfg.AssignmentHookAddress, common.Big0)
	s.Nil(err)

	_, err = rpc.WaitReceipt(context.Background(), s.p.rpc.L1, tx)
	s.Nil(err)

	allowance, err := s.p.rpc.TaikoToken.Allowance(nil, s.p.proverAddress, s.p.cfg.AssignmentHookAddress)
	s.Nil(err)

	s.Equal(0, allowance.Cmp(common.Big0))

	// Max that can be approved
	amt, ok := new(big.Int).SetString("58764887351446156758749765621197442946723800609510499661540524634076971270144", 10)
	s.True(ok)

	s.p.cfg.Allowance = amt

	s.Nil(s.p.setApprovalAmount(context.Background(), s.p.cfg.AssignmentHookAddress))

	allowance, err = s.p.rpc.TaikoToken.Allowance(nil, s.p.proverAddress, s.p.cfg.AssignmentHookAddress)
	s.Nil(err)

	s.Equal(0, amt.Cmp(allowance))
}

func (s *ProverTestSuite) TestGetBlockProofStatus() {
	parent, err := s.p.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	e := s.ProposeAndInsertValidBlock(s.proposer, s.d.ChainSyncer().CalldataSyncer())

	// No proof submitted
	status, err := rpc.GetBlockProofStatus(context.Background(), s.p.rpc, e.BlockId, s.p.proverAddress)
	s.Nil(err)
	s.False(status.IsSubmitted)

	// Valid proof submitted
	sink := make(chan *bindings.TaikoL1ClientTransitionProved)

	sub, err := s.p.rpc.TaikoL1.WatchTransitionProved(nil, sink, nil)
	s.Nil(err)
	defer func() {
		sub.Unsubscribe()
		close(sink)
	}()

	s.Nil(s.p.proveOp())
	s.Nil(s.p.selectSubmitter(e.Meta.MinTier).SubmitProof(context.Background(), <-s.p.proofGenerationCh))

	status, err = rpc.GetBlockProofStatus(context.Background(), s.p.rpc, e.BlockId, s.p.proverAddress)
	s.Nil(err)

	s.True(status.IsSubmitted)
	s.False(status.Invalid)
	s.Equal(parent.Hash(), status.ParentHeader.Hash())
	s.Equal(s.p.proverAddress, status.CurrentTransitionState.Prover)

	// Invalid proof submitted
	parent, err = s.p.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	e = s.ProposeAndInsertValidBlock(s.proposer, s.d.ChainSyncer().CalldataSyncer())

	status, err = rpc.GetBlockProofStatus(context.Background(), s.p.rpc, e.BlockId, s.p.proverAddress)
	s.Nil(err)
	s.False(status.IsSubmitted)

	s.Nil(s.p.proveOp())
	proofWithHeader := <-s.p.proofGenerationCh
	proofWithHeader.Opts.BlockHash = testutils.RandomHash()
	s.Nil(s.p.selectSubmitter(e.Meta.MinTier).SubmitProof(context.Background(), proofWithHeader))

	status, err = rpc.GetBlockProofStatus(context.Background(), s.p.rpc, e.BlockId, s.p.proverAddress)
	s.Nil(err)
	s.True(status.IsSubmitted)
	s.True(status.Invalid)
	s.Equal(parent.Hash(), status.ParentHeader.Hash())
	s.Equal(s.p.proverAddress, status.CurrentTransitionState.Prover)
	s.Equal(proofWithHeader.Opts.BlockHash, common.BytesToHash(status.CurrentTransitionState.BlockHash[:]))
}

func (s *ProverTestSuite) TestSetApprovalAlreadySetHigher() {
	originalAllowance, err := s.p.rpc.TaikoToken.Allowance(&bind.CallOpts{}, s.p.proverAddress, s.p.cfg.TaikoL1Address)
	s.Nil(err)

	amt := common.Big1
	s.p.cfg.Allowance = amt

	s.Nil(s.p.setApprovalAmount(context.Background(), s.p.cfg.TaikoL1Address))

	allowance, err := s.p.rpc.TaikoToken.Allowance(&bind.CallOpts{}, s.p.proverAddress, s.p.cfg.TaikoL1Address)
	s.Nil(err)

	s.Equal(0, allowance.Cmp(originalAllowance))
}

func TestProverTestSuite(t *testing.T) {
	suite.Run(t, new(ProverTestSuite))
}

func (s *ProverTestSuite) initProver(
	ctx context.Context,
	key *ecdsa.PrivateKey,
) *url.URL {
	proverServerURL := testutils.LocalRandomProverEndpoint()
	port, err := strconv.Atoi(proverServerURL.Port())
	s.Nil(err)

	decimal, err := s.RPCClient.TaikoToken.Decimals(nil)
	s.Nil(err)

	allowance := new(big.Int).Exp(big.NewInt(1_000_000_100), new(big.Int).SetUint64(uint64(decimal)), nil)

	p := new(Prover)
	s.Nil(InitFromConfig(ctx, p, &Config{
		L1WsEndpoint:          os.Getenv("L1_NODE_WS_ENDPOINT"),
		L1HttpEndpoint:        os.Getenv("L1_NODE_HTTP_ENDPOINT"),
		L2WsEndpoint:          os.Getenv("L2_EXECUTION_ENGINE_WS_ENDPOINT"),
		L2HttpEndpoint:        os.Getenv("L2_EXECUTION_ENGINE_HTTP_ENDPOINT"),
		TaikoL1Address:        common.HexToAddress(os.Getenv("TAIKO_L1_ADDRESS")),
		TaikoL2Address:        common.HexToAddress(os.Getenv("TAIKO_L2_ADDRESS")),
		TaikoTokenAddress:     common.HexToAddress(os.Getenv("TAIKO_TOKEN_ADDRESS")),
		AssignmentHookAddress: common.HexToAddress(os.Getenv("ASSIGNMENT_HOOK_ADDRESS")),
		L1ProverPrivKey:       key,
		Dummy:                 true,
		ProveUnassignedBlocks: true,
		Capacity:              1024,
		MinOptimisticTierFee:  common.Big1,
		MinSgxTierFee:         common.Big1,
		HTTPServerPort:        uint64(port),
		WaitReceiptTimeout:    12 * time.Second,
		DatabasePath:          "",
		Allowance:             allowance,
		RPCTimeout:            3 * time.Second,
		BackOffMaxRetrys:      3,
		L1NodeVersion:         "1.0.0",
		L2NodeVersion:         "0.1.0",
	}))
	p.srv = s.NewTestProverServer(
		key,
		proverServerURL,
	)

	p.guardianProverSender = guardianproversender.New(
		key,
		p.cfg.GuardianProverHealthCheckServerEndpoint,
		memorydb.New(),
		p.rpc,
		p.proverAddress,
	)

	s.p = p

	return proverServerURL
}
