package driver

import (
	"bytes"
	"compress/zlib"
	"context"
	"fmt"
	"math/big"
	"net/url"
	"os"
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/params"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/go-resty/resty/v2"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	softblocks "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/soft_blocks"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer"
)

type DriverTestSuite struct {
	testutils.ClientTestSuite
	cancel context.CancelFunc
	p      *proposer.Proposer
	d      *Driver
}

func (s *DriverTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	// InitFromConfig driver
	jwtSecret, err := jwt.ParseSecretFromFile(os.Getenv("JWT_SECRET"))
	s.Nil(err)
	s.NotEmpty(jwtSecret)

	d := new(Driver)
	ctx, cancel := context.WithCancel(context.Background())
	s.Nil(d.InitFromConfig(ctx, &Config{
		ClientConfig: &rpc.ClientConfig{
			L1Endpoint:       os.Getenv("L1_WS"),
			L2Endpoint:       os.Getenv("L2_WS"),
			L2EngineEndpoint: os.Getenv("L2_AUTH"),
			TaikoL1Address:   common.HexToAddress(os.Getenv("TAIKO_L1")),
			TaikoL2Address:   common.HexToAddress(os.Getenv("TAIKO_L2")),
			JwtSecret:        string(jwtSecret),
		},
	}))
	s.d = d
	s.cancel = cancel

	// InitFromConfig proposer
	s.InitProposer()
}

func (s *DriverTestSuite) TestName() {
	s.Equal("driver", s.d.Name())
}

func (s *DriverTestSuite) TestProcessL1Blocks() {
	l2Head1, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	s.Nil(s.d.ChainSyncer().BlobSyncer().ProcessL1Blocks(context.Background()))

	// Propose a valid L2 block
	s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().BlobSyncer())

	l2Head2, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	s.Greater(l2Head2.Number.Uint64(), l2Head1.Number.Uint64())

	// Empty blocks
	s.ProposeAndInsertEmptyBlocks(s.p, s.d.ChainSyncer().BlobSyncer())
	s.Nil(err)

	l2Head3, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	s.Greater(l2Head3.Number.Uint64(), l2Head2.Number.Uint64())

	for _, height := range []uint64{l2Head3.Number.Uint64(), l2Head3.Number.Uint64() - 1} {
		header, err := s.d.rpc.L2.HeaderByNumber(context.Background(), new(big.Int).SetUint64(height))
		s.Nil(err)

		txCount, err := s.d.rpc.L2.TransactionCount(context.Background(), header.Hash())
		s.Nil(err)
		s.GreaterOrEqual(txCount, uint(1))

		anchorTx, err := s.d.rpc.L2.TransactionInBlock(context.Background(), header.Hash(), 0)
		s.Nil(err)

		method, err := encoding.TaikoL2ABI.MethodById(anchorTx.Data())
		s.Nil(err)
		s.Contains(method.Name, "anchor")
	}
}

func (s *DriverTestSuite) TestCheckL1ReorgToHigherFork() {
	// TODO: Temporarily skip this test case when use l2_reth node.
	if os.Getenv("L2_NODE") == "l2_reth" {
		s.T().Skip()
	}
	var (
		testnetL1SnapshotID = s.SetL1Snapshot()
	)
	l1Head1, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	l2Head1, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	// Propose two L2 blocks
	s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().BlobSyncer())

	s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().BlobSyncer())

	l1Head2, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	l2Head2, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(l2Head2.Number.Uint64(), l2Head1.Number.Uint64())
	s.Greater(l1Head2.Number.Uint64(), l1Head1.Number.Uint64())

	res, err := s.RPCClient.CheckL1Reorg(
		context.Background(),
		l2Head2.Number,
	)
	s.Nil(err)
	s.False(res.IsReorged)

	// Reorg back to l2Head1
	s.RevertL1Snapshot(testnetL1SnapshotID)
	s.InitProposer()

	// Because of evm_revert operation, the nonce of the proposer need to be adjusted.
	// Propose ten blocks on another fork
	for i := 0; i < 10; i++ {
		s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().BlobSyncer())
	}

	l1Head4, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	s.Greater(l1Head4.Number.Uint64(), l1Head2.Number.Uint64())

	l2Head3, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	s.Equal(l2Head1.Number.Uint64()+10, l2Head3.Number.Uint64())

	parent, err := s.d.rpc.L2.HeaderByNumber(context.Background(), new(big.Int).SetUint64(l2Head1.Number.Uint64()+1))
	s.Nil(err)
	s.Equal(parent.ParentHash, l2Head1.Hash())
	s.NotEqual(parent.Hash(), l2Head2.ParentHash)
}

func (s *DriverTestSuite) TestCheckL1ReorgToLowerFork() {
	var (
		testnetL1SnapshotID = s.SetL1Snapshot()
	)
	l1Head1, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	l2Head1, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	// Propose two L2 blocks
	s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().BlobSyncer())
	time.Sleep(3 * time.Second)
	s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().BlobSyncer())

	l1Head2, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	l2Head2, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(l2Head2.Number.Uint64(), l2Head1.Number.Uint64())
	s.Greater(l1Head2.Number.Uint64(), l1Head1.Number.Uint64())

	res, err := s.RPCClient.CheckL1Reorg(
		context.Background(),
		l2Head2.Number,
	)
	s.Nil(err)
	s.False(res.IsReorged)

	// Reorg back to l2Head1
	s.RevertL1Snapshot(testnetL1SnapshotID)
	s.InitProposer()

	l1Head3, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.GreaterOrEqual(l1Head3.Number.Uint64(), l1Head1.Number.Uint64())

	// Propose one blocks on another fork
	s.ProposeValidBlock(s.p)

	l1Head4, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	s.Greater(l1Head4.Number.Uint64(), l1Head3.Number.Uint64())
	s.Less(l1Head4.Number.Uint64(), l1Head2.Number.Uint64())

	s.Nil(s.d.ChainSyncer().BlobSyncer().ProcessL1Blocks(context.Background()))

	l2Head3, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	parent, err := s.d.rpc.L2.HeaderByHash(context.Background(), l2Head3.ParentHash)
	s.Nil(err)
	s.Equal(l2Head3.Number.Uint64(), l2Head2.Number.Uint64()-1)
	s.Equal(parent.Hash(), l2Head1.Hash())
}

func (s *DriverTestSuite) TestCheckL1ReorgToSameHeightFork() {
	var (
		testnetL1SnapshotID = s.SetL1Snapshot()
	)
	l1Head1, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	l2Head1, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	// Propose two L2 blocks
	s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().BlobSyncer())
	time.Sleep(3 * time.Second)
	s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().BlobSyncer())

	l1Head2, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	l2Head2, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(l2Head2.Number.Uint64(), l2Head1.Number.Uint64())
	s.Greater(l1Head2.Number.Uint64(), l1Head1.Number.Uint64())

	res, err := s.RPCClient.CheckL1Reorg(
		context.Background(),
		l2Head2.Number,
	)
	s.Nil(err)
	s.False(res.IsReorged)

	// Reorg back to l2Head1
	s.RevertL1Snapshot(testnetL1SnapshotID)
	s.InitProposer()

	l1Head3, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.GreaterOrEqual(l1Head3.Number.Uint64(), l1Head1.Number.Uint64())

	// Propose two blocks on another fork
	s.ProposeValidBlock(s.p)
	time.Sleep(3 * time.Second)
	s.ProposeValidBlock(s.p)

	l1Head4, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	s.Greater(l1Head4.Number.Uint64(), l1Head3.Number.Uint64())

	s.Nil(s.d.ChainSyncer().BlobSyncer().ProcessL1Blocks(context.Background()))

	l2Head3, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	parent, err := s.d.rpc.L2.HeaderByHash(context.Background(), l2Head3.ParentHash)
	s.Nil(err)
	s.Equal(l2Head3.Number.Uint64(), l2Head2.Number.Uint64())
	s.NotEqual(l2Head3.Hash(), l2Head2.Hash())
	s.Equal(parent.ParentHash, l2Head1.Hash())
}

func (s *DriverTestSuite) TestDoSyncNoNewL2Blocks() {
	s.Nil(s.d.l2ChainSyncer.Sync())
}

func (s *DriverTestSuite) TestStartClose() {
	s.Nil(s.d.Start())
	s.cancel()
	s.d.Close(s.d.ctx)
}

func (s *DriverTestSuite) TestL1Current() {
	// propose and insert a block
	s.ProposeAndInsertEmptyBlocks(s.p, s.d.ChainSyncer().BlobSyncer())
	// reset L1 current with increased height
	s.Nil(s.d.state.ResetL1Current(s.d.ctx, common.Big1))
}

func (s *DriverTestSuite) InitProposer() {
	p := new(proposer.Proposer)

	jwtSecret, err := jwt.ParseSecretFromFile(os.Getenv("JWT_SECRET"))
	s.Nil(err)
	s.NotEmpty(jwtSecret)

	l1ProposerPrivKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROPOSER_PRIVATE_KEY")))
	s.Nil(err)

	s.Nil(p.InitFromConfig(context.Background(), &proposer.Config{
		ClientConfig: &rpc.ClientConfig{
			L1Endpoint:        os.Getenv("L1_WS"),
			L2Endpoint:        os.Getenv("L2_WS"),
			L2EngineEndpoint:  os.Getenv("L2_AUTH"),
			JwtSecret:         string(jwtSecret),
			TaikoL1Address:    common.HexToAddress(os.Getenv("TAIKO_L1")),
			TaikoL2Address:    common.HexToAddress(os.Getenv("TAIKO_L2")),
			TaikoTokenAddress: common.HexToAddress(os.Getenv("TAIKO_TOKEN")),
		},
		L1ProposerPrivKey:          l1ProposerPrivKey,
		L2SuggestedFeeRecipient:    common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")),
		ProposeInterval:            1024 * time.Hour,
		MaxProposedTxListsPerEpoch: 1,
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
	s.p = p
}

func (s *DriverTestSuite) TestInsertSoftBlocks() {
	var (
		port = uint64(testutils.RandomPort())
		err  error
	)
	s.d.softblockServer, err = softblocks.New(
		"*",
		nil,
		s.d.ChainSyncer().BlobSyncer(),
		s.RPCClient,
	)
	s.Nil(err)
	go func() { s.d.softblockServer.Start(port) }()
	defer s.d.softblockServer.Shutdown(s.d.ctx)

	url, err := url.Parse(fmt.Sprintf("http://localhost:%v", port))
	s.Nil(err)

	l2Head1, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	s.Nil(s.d.ChainSyncer().BlobSyncer().ProcessL1Blocks(context.Background()))

	// Propose a valid L2 block
	s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().BlobSyncer())

	l2Head2, err := s.d.rpc.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	l1Head1, err := s.d.rpc.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	s.Greater(l2Head2.Number.Uint64(), l2Head1.Number.Uint64())

	res, err := resty.New().R().Get(url.String() + "/healthz")
	s.Nil(err)
	s.True(res.IsSuccess())

	preconferPrivKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROPOSER_PRIVATE_KEY")))
	s.Nil(err)

	preconferAddress := crypto.PubkeyToAddress(preconferPrivKey.PublicKey)

	nonce, err := s.RPCClient.L2.PendingNonceAt(context.Background(), s.TestAddr)
	s.Nil(err)

	tx := types.NewTransaction(
		nonce,
		common.BytesToAddress(testutils.RandomBytes(32)),
		common.Big0,
		100_000,
		new(big.Int).SetUint64(uint64(10*params.GWei)),
		[]byte{},
	)
	signedTx, err := types.SignTx(tx, types.LatestSignerForChainID(s.RPCClient.L2.ChainID), s.TestAddrPrivKey)
	s.Nil(err)
	s.Nil(s.RPCClient.L2.SendTransaction(context.Background(), signedTx))

	b, err := encodeAndCompressTxList([]*types.Transaction{signedTx})
	s.Nil(err)

	txBatch := softblocks.TransactionBatch{
		BlockID:          l2Head2.Number.Uint64() + 1,
		ID:               0,
		TransactionsList: b,
		BatchMarker:      softblocks.BatchMarkerEmpty,
		Signature:        "",
		BlockParams: &softblocks.SoftBlockParams{
			AnchorBlockID:   l1Head1.Number.Uint64(),
			AnchorStateRoot: l1Head1.Root,
			Timestamp:       l1Head1.Time + 12,
			Coinbase:        preconferAddress,
		},
	}

	payload, err := rlp.EncodeToBytes(txBatch)
	s.Nil(err)
	s.NotEmpty(payload)

	sig, err := crypto.Sign(crypto.Keccak256(payload), preconferPrivKey)
	s.Nil(err)
	txBatch.Signature = common.Bytes2Hex(sig)

	// Try to propose a soft block
	res, err = resty.New().
		R().
		SetBody(&softblocks.BuildSoftBlockRequestBody{
			TransactionBatch: txBatch,
		}).
		Post(url.String() + "/softBlocks")
	s.Nil(err)
	s.True(res.IsSuccess())

	// Propose a valid L2 block
	s.ProposeAndInsertValidBlock(s.p, s.d.ChainSyncer().BlobSyncer())
}

func TestDriverTestSuite(t *testing.T) {
	suite.Run(t, new(DriverTestSuite))
}

// encodeAndCompressTxList encodes and compresses the given transactions list.
func encodeAndCompressTxList(txs types.Transactions) ([]byte, error) {
	b, err := rlp.EncodeToBytes(txs)
	if err != nil {
		return nil, err
	}

	return compress(b)
}

// compress compresses the given txList bytes using zlib.
func compress(txListBytes []byte) ([]byte, error) {
	var b bytes.Buffer
	w := zlib.NewWriter(&b)
	defer w.Close()

	if _, err := w.Write(txListBytes); err != nil {
		return nil, err
	}

	if err := w.Flush(); err != nil {
		return nil, err
	}

	return b.Bytes(), nil
}
