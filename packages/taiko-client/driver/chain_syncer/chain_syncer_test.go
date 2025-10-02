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
	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
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
			PacayaInboxAddress:          common.HexToAddress(os.Getenv("PACAYA_INBOX")),
			ShastaInboxAddress:          common.HexToAddress(os.Getenv("SHASTA_INBOX")),
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
		common.HexToAddress(os.Getenv("PACAYA_INBOX")),
		common.HexToAddress(os.Getenv("SHASTA_INBOX")),
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
	basefeeSharingPctg, _ := core.DecodeShastaExtraData(head2.Header().Extra)
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
	basefeeSharingPctg, _ := core.DecodeShastaExtraData(head2.Header().Extra)
	s.Equal(uint8(75), basefeeSharingPctg)

	l1StateRoot2, l1Height2, parentGasUsed, err := s.RPCClient.GetSyncedL1SnippetFromAnchor(head2.Transactions()[0])
	s.Nil(err)
	s.NotEqual(common.Hash{}, l1StateRoot2)
	s.NotZero(l1Height2)
	s.Less(l1Height, l1Height2)
	s.Zero(parentGasUsed)
}

func (s *ChainSyncerTestSuite) TestShastaLowBondProposal() {
	// TODO: remove this `Skip()` when https://github.com/taikoxyz/taiko-mono/pull/20322 figures
	// out where to put `proverAuth`.
	s.T().Skip()
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
	basefeeSharingPctg, _ := core.DecodeShastaExtraData(head2.Header().Extra)
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

func (s *ChainSyncerTestSuite) TestShastaProposalsWithForcedInclusion() {
	s.ForkIntoShasta(s.p, s.s.EventSyncer())

	head, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)

	nonce, err := s.RPCClient.L2.NonceAt(context.Background(), s.TestAddr, nil)
	s.Nil(err)

	testTx, err := testutils.AssembleAndSendTestTx(
		s.RPCClient.L2,
		s.TestAddrPrivKey,
		nonce,
		&s.TestAddr,
		common.Big1,
		nil,
	)
	s.Nil(err)

	manifest := &manifest.DerivationSourceManifest{
		Blocks: []*manifest.BlockManifest{
			{
				Timestamp:         0,
				Coinbase:          s.TestAddr,
				AnchorBlockNumber: head.NumberU64(),
				GasLimit:          head.GasLimit(),
				Transactions:      types.Transactions{testTx},
			},
		},
	}

	derivationSourceManifestBytes, err := builder.EncodeDerivationSourceManifestShasta(manifest)
	s.Nil(err)

	b, err := builder.SplitToBlobs(derivationSourceManifestBytes)
	s.Nil(err)

	inbox := common.HexToAddress(os.Getenv("SHASTA_INBOX"))
	config, err := s.RPCClient.ShastaClients.Inbox.GetConfig(nil)
	s.Nil(err)
	data, err := encoding.ShastaInboxABI.Pack("saveForcedInclusion", shastaBindings.LibBlobsBlobReference{
		BlobStartIndex: 0,
		NumBlobs:       1,
		Offset:         common.Big0,
	})
	s.Nil(err)
	s.Nil(s.p.SendTx(context.Background(), &txmgr.TxCandidate{
		To:     &inbox,
		TxData: data,
		Blobs:  b,
		Value: new(big.Int).Mul(
			new(big.Int).SetUint64(config.ForcedInclusionFeeInGwei), new(big.Int).SetUint64(params.GWei)),
	}))

	time.Sleep(time.Duration(config.ForcedInclusionDelay*2) * time.Second)

	txCandidate, err := s.shastaProposalBuilder.BuildShasta(
		context.Background(),
		[]types.Transactions{{}},
		common.Big1,
		common.Address{},
		[]byte{},
	)
	s.Nil(err)
	txCandidate.GasLimit = 0
	s.Nil(s.p.SendTx(context.Background(), txCandidate))
	s.Nil(s.s.EventSyncer().ProcessL1Blocks(context.Background()))

	head2, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(head.NumberU64()+2, head2.NumberU64())
	s.Equal(common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")), head2.Coinbase())
	s.Equal(uint16(1), s.getBlockIndexInAnchor(head2))

	forcedIncludedHeader, err := s.RPCClient.L2.BlockByNumber(
		context.Background(),
		new(big.Int).SetUint64(head.NumberU64()+1),
	)
	s.Nil(err)
	s.Equal(head2.NumberU64()-1, forcedIncludedHeader.NumberU64())
	s.Equal(2, len(forcedIncludedHeader.Transactions()))
	s.Equal(testTx.Hash(), forcedIncludedHeader.Transactions()[1].Hash())
	s.Equal(crypto.PubkeyToAddress(s.KeyFromEnv("L1_PROPOSER_PRIVATE_KEY").PublicKey), forcedIncludedHeader.Coinbase())
	s.NotEqual(s.TestAddr, forcedIncludedHeader.Coinbase())
	s.Greater(head2.Header().Time, forcedIncludedHeader.Header().Time)
	s.Equal(uint16(0), s.getBlockIndexInAnchor(forcedIncludedHeader))
}

func TestChainSyncerTestSuite(t *testing.T) {
	suite.Run(t, new(ChainSyncerTestSuite))
}

func (s *ChainSyncerTestSuite) getBlockIndexInAnchor(block *types.Block) uint16 {
	method, err := encoding.ShastaAnchorABI.MethodById(block.Transactions()[0].Data())
	s.Nil(err)
	args := map[string]interface{}{}
	s.Nil(method.Inputs.UnpackIntoMap(args, block.Transactions()[0].Data()[4:]))
	blockIdx, ok := args["_blockIndex"].(uint16)
	s.True(ok)
	return blockIdx
}
