package chainsyncer

import (
	"context"
	"math/big"
	"os"
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/params"
	"github.com/holiman/uint256"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/state"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/preconf"
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
			L1Endpoint:                  os.Getenv("L1_HTTP"),
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
			L1RPCURL:                  os.Getenv("L1_HTTP"),
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
			L1RPCURL:                  os.Getenv("L1_HTTP"),
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
	s.p.RegisterTxMgrSelectorToBlobServer(s.BlobServer)

	s.shastaProposalBuilder = builder.NewBlobTransactionBuilder(
		s.RPCClient,
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

	protocolCfg, err := s.RPCClient.ShastaClients.Inbox.GetConfig(nil)
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
	s.Less(head.Time(), head2.Time())
	s.Equal(crypto.PubkeyToAddress(s.KeyFromEnv("L1_PROPOSER_PRIVATE_KEY").PublicKey), head2.Coinbase())
	s.GreaterOrEqual(len(head.Extra()), 1)
	s.GreaterOrEqual(len(head2.Extra()), 1)
	s.Equal(head.Extra()[0], head2.Extra()[0])
	s.Equal(protocolCfg.BasefeeSharingPctg, core.DecodeShastaBasefeeSharingPctg(head2.Header().Extra))

	l1StateRoot2, l1Height2, parentGasUsed2, err := s.RPCClient.GetSyncedL1SnippetFromAnchor(head2.Transactions()[0])
	s.Nil(err)
	s.Nil(err)
	s.NotEqual(common.Hash{}, l1StateRoot2)
	s.NotZero(l1Height2)
	s.Equal(l1Height, l1Height2)
	s.Zero(parentGasUsed2)
}

func (s *ChainSyncerTestSuite) TestShastaDerivationFetchDoesNotBlockPreconf() {
	ctx := context.Background()

	s.ForkIntoShasta(s.p, s.s.EventSyncer())

	waitCh := make(chan struct{})
	requestCh := make(chan struct{}, 1)
	s.BlobServer.SetRequestWaiter(waitCh)
	s.BlobServer.SetRequestNotifier(requestCh)
	defer func() {
		s.BlobServer.SetRequestWaiter(nil)
		s.BlobServer.SetRequestNotifier(nil)
	}()

	txCandidate, err := s.shastaProposalBuilder.BuildShasta(
		ctx,
		[]types.Transactions{{}},
		common.Big1,
		common.Address{},
	)
	s.Nil(err)
	s.Nil(s.p.SendTx(ctx, txCandidate))

	processErrCh := make(chan error, 1)
	go func() {
		processErrCh <- s.s.EventSyncer().ProcessL1Blocks(ctx)
	}()

	select {
	case <-requestCh:
	case <-time.After(5 * time.Second):
		close(waitCh)
		s.T().Fatal("timeout waiting for blob request")
	}

	parent, err := s.RPCClient.L2.HeaderByNumber(ctx, nil)
	s.Nil(err)

	baseFee, err := s.RPCClient.CalculateBaseFeeShasta(ctx, parent)
	s.Nil(err)

	u256BaseFee, overflow := uint256.FromBig(baseFee)
	s.False(overflow)

	payload := &eth.ExecutionPayload{
		ParentHash:    parent.Hash(),
		FeeRecipient:  s.TestAddr,
		PrevRandao:    eth.Bytes32(testutils.RandomHash()),
		BlockNumber:   eth.Uint64Quantity(parent.Number.Uint64() + 1),
		GasLimit:      eth.Uint64Quantity(parent.GasLimit),
		Timestamp:     eth.Uint64Quantity(parent.Time + 1),
		ExtraData:     parent.Extra,
		BaseFeePerGas: eth.Uint256Quantity(*u256BaseFee),
		Transactions:  []eth.Data{},
		Withdrawals:   &types.Withdrawals{},
	}

	preconfErrCh := make(chan error, 1)
	go func() {
		_, err := s.s.EventSyncer().BlocksInserterShasta().InsertPreconfBlocksFromEnvelopes(
			ctx,
			[]*preconf.Envelope{{Payload: payload}},
			false,
		)
		preconfErrCh <- err
	}()

	select {
	case err := <-preconfErrCh:
		s.ErrorContains(err, "no transactions data in the payload")
	case <-time.After(2 * time.Second):
		close(waitCh)
		s.T().Fatal("preconfirmation insert blocked while fetching derivation payloads")
	}

	close(waitCh)

	select {
	case err := <-processErrCh:
		s.Nil(err)
	case <-time.After(10 * time.Second):
		s.T().Fatal("timeout waiting for ProcessL1Blocks")
	}
}

func (s *ChainSyncerTestSuite) TestShastaValidBlobs() {
	s.ForkIntoShasta(s.p, s.s.EventSyncer())

	head, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)

	l1StateRoot, l1Height, _, err := s.RPCClient.GetSyncedL1SnippetFromAnchor(head.Transactions()[0])
	s.Nil(err)
	s.NotEqual(common.Hash{}, l1StateRoot)

	protocolCfg, err := s.RPCClient.ShastaClients.Inbox.GetConfig(nil)
	s.Nil(err)

	txCandidate, err := s.shastaProposalBuilder.BuildShasta(
		context.Background(),
		[]types.Transactions{{}},
		common.Big1,
		common.Address{},
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
	s.Equal(head.Extra()[0], head2.Extra()[0])
	s.Equal(protocolCfg.BasefeeSharingPctg, core.DecodeShastaBasefeeSharingPctg(head2.Header().Extra))

	l1StateRoot2, l1Height2, parentGasUsed, err := s.RPCClient.GetSyncedL1SnippetFromAnchor(head2.Transactions()[0])
	s.Nil(err)
	s.NotEqual(common.Hash{}, l1StateRoot2)
	s.NotZero(l1Height2)
	s.Less(l1Height, l1Height2)
	s.Zero(parentGasUsed)
}

func (s *ChainSyncerTestSuite) TestShastaProposalWithMultipleBlocks() {
	s.ForkIntoShasta(s.p, s.s.EventSyncer())

	head1, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)

	nonce, err := s.RPCClient.L2.NonceAt(context.Background(), s.TestAddr, nil)
	s.Nil(err)

	testTx1, err := testutils.AssembleAndSendTestTx(
		s.RPCClient.L2,
		s.TestAddrPrivKey,
		nonce,
		&s.TestAddr,
		common.Big1,
		nil,
	)
	s.Nil(err)

	testTx2, err := testutils.AssembleAndSendTestTx(
		s.RPCClient.L2,
		s.TestAddrPrivKey,
		nonce+1,
		&s.TestAddr,
		common.Big1,
		nil,
	)
	s.Nil(err)

	txCandidate, err := s.shastaProposalBuilder.BuildShasta(
		context.Background(),
		[]types.Transactions{{testTx1}, {testTx2}},
		common.Big1,
		common.Address{},
	)
	s.Nil(err)
	s.Nil(s.p.SendTx(context.Background(), txCandidate))
	s.Nil(s.s.EventSyncer().ProcessL1Blocks(context.Background()))

	head2, err := s.RPCClient.L2.BlockByNumber(context.Background(), new(big.Int).Add(head1.Number(), common.Big1))
	s.Nil(err)
	s.Equal(2, len(head2.Transactions()))
	s.Equal(testTx1.Hash(), head2.Transactions()[1].Hash())

	head3, err := s.RPCClient.L2.BlockByNumber(context.Background(), new(big.Int).Add(head1.Number(), common.Big2))
	s.Nil(err)
	s.Equal(2, len(head3.Transactions()))
	s.Equal(testTx2.Hash(), head3.Transactions()[1].Hash())
}

func (s *ChainSyncerTestSuite) TestShastaProposalWithOneBlobAndMultipleBlocks() {
	s.ForkIntoShasta(s.p, s.s.EventSyncer())

	head1, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)

	nonce, err := s.RPCClient.L2.NonceAt(context.Background(), s.TestAddr, nil)
	s.Nil(err)

	batches := 100
	txBatch := make([]types.Transactions, batches)
	txsInBatch := 1

	for i := 0; i < batches; i++ {
		for j := 0; j < txsInBatch; j++ {
			testTx, err := testutils.AssembleAndSendTestTx(
				s.RPCClient.L2,
				s.TestAddrPrivKey,
				nonce,
				&s.TestAddr,
				common.Big1,
				nil,
			)
			s.Nil(err)
			txBatch[i] = append(txBatch[i], testTx)
			nonce++
		}
	}

	txCandidate, err := s.shastaProposalBuilder.BuildShasta(
		context.Background(),
		txBatch,
		common.Big1,
		common.Address{},
	)
	s.Nil(err)

	l1Head, err := s.RPCClient.L1.BlockByNumber(context.Background(), nil)
	s.Nil(err)

	s.SetNextBlockTimestamp(l1Head.Time() + uint64(batches)*uint64(txsInBatch))
	s.Nil(s.p.SendTx(context.Background(), txCandidate))
	s.Nil(s.s.EventSyncer().ProcessL1Blocks(context.Background()))

	for i := 1; i <= batches; i++ {
		head, err := s.RPCClient.L2.BlockByNumber(
			context.Background(),
			new(big.Int).SetUint64(head1.Number().Uint64()+uint64(i)),
		)
		s.Nil(err)
		s.Equal(txsInBatch+1, len(head.Transactions()))
	}
}

func (s *ChainSyncerTestSuite) TestShastaProposalWithTooMuchBlocks() {
	s.ForkIntoShasta(s.p, s.s.EventSyncer())

	head1, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)

	nonce, err := s.RPCClient.L2.NonceAt(context.Background(), s.TestAddr, nil)
	s.Nil(err)

	txBatch := make([]types.Transactions, manifest.ProposalMaxBlocks+1)

	for i := 0; i < len(txBatch); i++ {
		testTx, err := testutils.AssembleAndSendTestTx(
			s.RPCClient.L2,
			s.TestAddrPrivKey,
			nonce,
			&s.TestAddr,
			common.Big1,
			nil,
		)
		s.Nil(err)
		txBatch[i] = types.Transactions{testTx}
		nonce++
	}

	txCandidate, err := s.shastaProposalBuilder.BuildShasta(
		context.Background(),
		txBatch,
		common.Big1,
		common.Address{},
	)
	s.Nil(err)
	s.Nil(s.p.SendTx(context.Background(), txCandidate))
	s.Nil(s.s.EventSyncer().ProcessL1Blocks(context.Background()))

	head2, err := s.RPCClient.L2.BlockByNumber(context.Background(), new(big.Int).Add(head1.Number(), common.Big1))
	s.Nil(err)
	s.Equal(head1.NumberU64()+1, head2.NumberU64())
	s.Equal(1, len(head2.Transactions()))
}

func (s *ChainSyncerTestSuite) TestShastaProposalsWithInvalidForcedInclusion() {
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

	testTx2, err := testutils.AssembleAndSendTestTx(
		s.RPCClient.L2,
		s.TestAddrPrivKey,
		nonce+1,
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
			{
				Timestamp:         0,
				Coinbase:          s.TestAddr,
				AnchorBlockNumber: head.NumberU64(),
				GasLimit:          head.GasLimit(),
				Transactions:      types.Transactions{testTx2},
			},
		},
	}

	derivationSourceManifestBytes, err := builder.EncodeSourceManifestShasta(manifest)
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
	)
	s.Nil(err)
	txCandidate.GasLimit = 0
	s.Nil(s.p.SendTx(context.Background(), txCandidate))
	s.Nil(s.s.EventSyncer().ProcessL1Blocks(context.Background()))

	head2, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(head.NumberU64()+2, head2.NumberU64())
	s.Equal(common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")), head2.Coinbase())

	forcedIncludedHeader1, err := s.RPCClient.L2.BlockByNumber(
		context.Background(),
		new(big.Int).SetUint64(head.NumberU64()+1),
	)
	s.Nil(err)
	s.Equal(head2.NumberU64()-1, forcedIncludedHeader1.NumberU64())
	s.Equal(1, len(forcedIncludedHeader1.Transactions()))
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

	derivationSourceManifestBytes, err := builder.EncodeSourceManifestShasta(manifest)
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
	)
	s.Nil(err)
	txCandidate.GasLimit = 0
	s.Nil(s.p.SendTx(context.Background(), txCandidate))
	s.Nil(s.s.EventSyncer().ProcessL1Blocks(context.Background()))

	head2, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(head.NumberU64()+2, head2.NumberU64())
	s.Equal(common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")), head2.Coinbase())

	forcedIncludedHeader1, err := s.RPCClient.L2.BlockByNumber(
		context.Background(),
		new(big.Int).SetUint64(head.NumberU64()+1),
	)
	s.Nil(err)
	s.Equal(head2.NumberU64()-1, forcedIncludedHeader1.NumberU64())
	s.Equal(2, len(forcedIncludedHeader1.Transactions()))
	s.Equal(testTx.Hash(), forcedIncludedHeader1.Transactions()[1].Hash())
	s.Equal(crypto.PubkeyToAddress(s.KeyFromEnv("L1_PROPOSER_PRIVATE_KEY").PublicKey), forcedIncludedHeader1.Coinbase())
	s.NotEqual(s.TestAddr, forcedIncludedHeader1.Coinbase())
	s.Greater(head2.Header().Time, forcedIncludedHeader1.Header().Time)
}

func TestChainSyncerTestSuite(t *testing.T) {
	suite.Run(t, new(ChainSyncerTestSuite))
}
