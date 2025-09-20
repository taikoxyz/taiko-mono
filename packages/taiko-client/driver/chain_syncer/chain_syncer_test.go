package chainsyncer

import (
	"context"
	"math/big"

	"os"
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
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

	l1StateRoot, l1Height, parentGasUsed, err := s.RPCClient.GetSyncedL1SnippetFromAnchor(head.Transactions()[0])
	s.Nil(err)
	s.NotEqual(common.Hash{}, l1StateRoot)
	s.Equal(common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")), head.Coinbase())
	s.NotZero(l1Height)
	s.Zero(parentGasUsed)

	txCandidate, err := s.shastaProposalBuilder.BuildShasta(
		context.Background(),
		[]types.Transactions{{}},
		nil,
		common.Big1,
		common.Address{},
		[]byte{},
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
	s.Equal(head.Time()+1, head2.Time())
	s.Equal(crypto.PubkeyToAddress(s.KeyFromEnv("L1_PROPOSER_PRIVATE_KEY").PublicKey), head2.Coinbase())
	s.GreaterOrEqual(len(head.Extra()), 1)
	s.GreaterOrEqual(len(head2.Extra()), 1)
	s.Equal(head.Extra()[0], head2.Extra()[0])
	basefeeSharingPctg := core.DecodeExtraData(head2.Header().Extra)
	s.Equal(uint8(75), basefeeSharingPctg)

	l1StateRoot2, l1Height2, parentGasUsed2, err := s.RPCClient.GetSyncedL1SnippetFromAnchor(head2.Transactions()[0])
	s.Nil(err)
	s.Nil(err)
	s.Equal(common.Hash{}, l1StateRoot2)
	s.NotZero(l1Height2)
	s.Equal(l1Height, l1Height2)
	s.Zero(parentGasUsed2)
}

func (s *ChainSyncerTestSuite) TestShastaValidBlobs() {
	s.ForkIntoShasta(s.p, s.s.EventSyncer())

	head, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)

	l1StateRoot, l1Height, _, err := s.RPCClient.GetSyncedL1SnippetFromAnchor(head.Transactions()[0])
	s.Nil(err)
	s.NotEqual(common.Hash{}, l1StateRoot)

	txCandidate, err := s.shastaProposalBuilder.BuildShasta(
		context.Background(),
		[]types.Transactions{{}},
		nil,
		common.Big1,
		common.Address{},
		[]byte{},
	)
	s.Nil(err)
	s.Nil(s.p.SendTx(context.Background(), txCandidate))
	s.Nil(s.s.EventSyncer().ProcessL1Blocks(context.Background()))

	head2, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(head.NumberU64()+1, head2.NumberU64())
	s.Equal(1, len(head2.Transactions()))
	s.Equal(head.GasLimit(), head2.GasLimit())
	s.Less(head.Time(), head2.Time())
	s.Equal(head.Coinbase(), head2.Coinbase())
	s.Equal(head.Extra(), head2.Extra())
	basefeeSharingPctg := core.DecodeExtraData(head2.Header().Extra)
	s.Equal(uint8(75), basefeeSharingPctg)

	l1StateRoot2, l1Height2, parentGasUsed, err := s.RPCClient.GetSyncedL1SnippetFromAnchor(head2.Transactions()[0])
	s.Nil(err)
	s.NotEqual(common.Hash{}, l1StateRoot2)
	s.NotZero(l1Height2)
	s.Less(l1Height, l1Height2)
	s.Zero(parentGasUsed)
}

func (s *ChainSyncerTestSuite) TestShastaLowBondProposal() {
	s.ForkIntoShasta(s.p, s.s.EventSyncer())

	head, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)

	l1StateRoot, l1Height, _, err := s.RPCClient.GetSyncedL1SnippetFromAnchor(head.Transactions()[0])
	s.Nil(err)
	s.NotEqual(common.Hash{}, l1StateRoot)

	proposalId := new(big.Int).Add(s.ShastaStateIndexer.GetLastProposal().Proposal.Id, common.Big1)
	proposer := s.ShastaStateIndexer.GetLastProposal().Proposal.Proposer
	provingFeeGwei := new(big.Int).SetUint64(281474976710655)

	uint48Type, _ := abi.NewType("uint48", "", nil)
	addressType, _ := abi.NewType("address", "", nil)
	args := abi.Arguments{
		{Name: "proposalId", Type: uint48Type},
		{Name: "proposer", Type: addressType},
		{Name: "provingFeeGwei", Type: uint48Type},
	}

	data, err := args.Pack(proposalId, proposer, provingFeeGwei)
	s.Nil(err)

	// Sign the message with L1_PROVER_PRIVATE_KEY
	signature, err := crypto.Sign(crypto.Keccak256Hash(data).Bytes(), s.KeyFromEnv("L1_PROVER_PRIVATE_KEY"))
	s.Nil(err)

	auth := &encoding.ProverAuth{
		ProposalId:     proposalId,
		Proposer:       proposer,
		ProvingFeeGwei: provingFeeGwei,
		Signature:      signature,
	}
	s.NotNil(auth)

	encodedAuth, err := encoding.EncodeProverAuth(auth)
	s.Nil(err)

	info, err := s.RPCClient.ShastaClients.Anchor.GetDesignatedProver(nil, proposalId, proposer, encodedAuth)
	s.Nil(err)
	s.True(info.IsLowBondProposal)

	txCandidate, err := s.shastaProposalBuilder.BuildShasta(
		context.Background(),
		[]types.Transactions{{}},
		nil,
		common.Big1,
		common.Address{},
		encodedAuth,
	)
	s.Nil(err)
	s.Nil(s.p.SendTx(context.Background(), txCandidate))
	s.Nil(s.s.EventSyncer().ProcessL1Blocks(context.Background()))

	head2, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(head.NumberU64()+1, head2.NumberU64())
	s.Equal(1, len(head2.Transactions()))
	s.Equal(head.GasLimit(), head2.GasLimit())
	s.Less(head.Time(), head2.Time())
	s.Equal(crypto.PubkeyToAddress(s.KeyFromEnv("L1_PROPOSER_PRIVATE_KEY").PublicKey), head2.Coinbase())
	basefeeSharingPctg := core.DecodeExtraData(head2.Header().Extra)
	s.Equal(uint8(75), basefeeSharingPctg)
	s.GreaterOrEqual(len(head2.Header().Extra), 2)
	isLowBondProposal := head2.Header().Extra[1]&0x01 == 0x01
	s.True(isLowBondProposal)

	l1StateRoot2, l1Height2, parentGasUsed, err := s.RPCClient.GetSyncedL1SnippetFromAnchor(head2.Transactions()[0])
	s.Nil(err)
	s.Equal(common.Hash{}, l1StateRoot2)
	s.NotZero(l1Height2)
	s.Equal(l1Height, l1Height2)
	s.Zero(parentGasUsed)
}

func TestChainSyncerTestSuite(t *testing.T) {
	suite.Run(t, new(ChainSyncerTestSuite))
}
