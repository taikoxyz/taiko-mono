package proposer

import (
	"context"
	"math/big"
	"os"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-client/bindings"
	"github.com/taikoxyz/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-client/pkg/rpc"
)

type ProposerTestSuite struct {
	testutils.ClientTestSuite
	p      *Proposer
	cancel context.CancelFunc
}

func (s *ProposerTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()

	l1ProposerPrivKey, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROPOSER_PRIVATE_KEY")))
	s.Nil(err)

	p := new(Proposer)

	ctx, cancel := context.WithCancel(context.Background())

	s.Nil(p.InitFromConfig(ctx, &Config{
		ClientConfig: &rpc.ClientConfig{
			L1Endpoint:        os.Getenv("L1_NODE_WS_ENDPOINT"),
			L2Endpoint:        os.Getenv("L2_EXECUTION_ENGINE_HTTP_ENDPOINT"),
			TaikoL1Address:    common.HexToAddress(os.Getenv("TAIKO_L1_ADDRESS")),
			TaikoL2Address:    common.HexToAddress(os.Getenv("TAIKO_L2_ADDRESS")),
			TaikoTokenAddress: common.HexToAddress(os.Getenv("TAIKO_TOKEN_ADDRESS")),
		},
		AssignmentHookAddress:               common.HexToAddress(os.Getenv("ASSIGNMENT_HOOK_ADDRESS")),
		L1ProposerPrivKey:                   l1ProposerPrivKey,
		L2SuggestedFeeRecipient:             common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")),
		ProposeInterval:                     1024 * time.Hour,
		MaxProposedTxListsPerEpoch:          1,
		ProposeBlockTxReplacementMultiplier: 2,
		WaitReceiptTimeout:                  12 * time.Second,
		ProverEndpoints:                     s.ProverEndpoints,
		OptimisticTierFee:                   common.Big256,
		SgxTierFee:                          common.Big256,
		TierFeePriceBump:                    common.Big2,
		MaxTierFeePriceBumps:                3,
		ExtraData:                           "test",
		L1BlockBuilderTip:                   common.Big0,
	}))

	s.p = p
	s.cancel = cancel
}

func (s *ProposerTestSuite) TestName() {
	s.Equal("proposer", s.p.Name())
}

func (s *ProposerTestSuite) TestProposeOp() {
	// Propose txs in L2 execution engine's mempool
	sink := make(chan *bindings.TaikoL1ClientBlockProposed)

	sub, err := s.p.rpc.TaikoL1.WatchBlockProposed(nil, sink, nil, nil)
	s.Nil(err)
	defer func() {
		sub.Unsubscribe()
		close(sink)
	}()

	nonce, err := s.p.rpc.L2.PendingNonceAt(context.Background(), s.TestAddr)
	s.Nil(err)

	gaslimit := 21000

	parent, err := s.p.rpc.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)

	baseFee, err := s.p.rpc.TaikoL2.GetBasefee(nil, 1, uint32(parent.GasUsed()))
	s.Nil(err)

	to := common.BytesToAddress(testutils.RandomBytes(32))
	tx := types.NewTx(&types.DynamicFeeTx{
		ChainID:   s.RPCClient.L2.ChainID,
		Nonce:     nonce,
		GasTipCap: common.Big0,
		GasFeeCap: new(big.Int).SetUint64(baseFee.Uint64() * 2),
		Gas:       uint64(gaslimit),
		To:        &to,
		Value:     common.Big1,
	})

	signedTx, err := types.SignTx(tx, types.LatestSignerForChainID(s.p.rpc.L2.ChainID), s.TestAddrPrivKey)
	s.Nil(err)
	s.Nil(s.p.rpc.L2.SendTransaction(context.Background(), signedTx))

	s.Nil(s.p.ProposeOp(context.Background()))

	event := <-sink

	s.Equal(event.Meta.Coinbase, s.p.L2SuggestedFeeRecipient)

	_, isPending, err := s.p.rpc.L1.TransactionByHash(context.Background(), event.Raw.TxHash)
	s.Nil(err)
	s.False(isPending)

	receipt, err := s.p.rpc.L1.TransactionReceipt(context.Background(), event.Raw.TxHash)
	s.Nil(err)
	s.Equal(types.ReceiptStatusSuccessful, receipt.Status)
}

func (s *ProposerTestSuite) TestProposeOpLocalsOnly() {
	s.p.LocalAddresses = []common.Address{common.BytesToAddress(testutils.RandomBytes(20))}
	s.p.LocalAddressesOnly = true

	// Propose txs in L2 execution engine's mempool
	sink := make(chan *bindings.TaikoL1ClientBlockProposed)

	sub, err := s.p.rpc.TaikoL1.WatchBlockProposed(nil, sink, nil, nil)
	s.Nil(err)
	defer func() {
		sub.Unsubscribe()
		close(sink)
	}()

	s.Error(errNoNewTxs, s.p.ProposeOp(context.Background()))
}

func (s *ProposerTestSuite) TestProposeEmptyBlockOp() {
	s.Nil(s.p.ProposeEmptyBlockOp(context.Background()))
}

func (s *ProposerTestSuite) TestCustomProposeOpHook() {
	flag := false

	s.p.CustomProposeOpHook = func() error {
		flag = true
		return nil
	}

	s.Nil(s.p.ProposeOp(context.Background()))
	s.True(flag)
}

func (s *ProposerTestSuite) TestSendProposeBlockTx() {
	sender := s.p.GetSender()
	s.SetL1Automine(false)
	defer s.SetL1Automine(true)

	s.Nil(sender.SetNonce(nil, true))

	fee := big.NewInt(10000)
	opts := sender.Opts
	opts.Value = fee
	s.Greater(opts.GasTipCap.Uint64(), uint64(0))

	nonce, err := s.RPCClient.L1.PendingNonceAt(context.Background(), s.p.proposerAddress)
	s.Nil(err)

	txID, err := sender.SendRawTransaction(nonce, &common.Address{}, common.Big1, nil)
	s.Nil(err)
	tx := sender.GetUnconfirmedTx(txID)

	encoded, err := rlp.EncodeToBytes([]types.Transaction{})
	s.Nil(err)
	var newTx *types.Transaction
	if s.p.BlobAllowed {
		newTx, err = s.p.makeProposeBlockTxWithBlobHash(context.Background(), encoded)
	} else {
		newTx, err = s.p.makeProposeBlockTx(
			context.Background(),
			encoded,
		)
	}
	s.Nil(err)

	txID, err = sender.SendRawTransaction(nonce, newTx.To(), newTx.Value(), newTx.Data())
	s.Nil(err)
	newTx = sender.GetUnconfirmedTx(txID)

	s.Greater(newTx.GasTipCap().Uint64(), tx.GasTipCap().Uint64())
}

func (s *ProposerTestSuite) TestAssignProverSuccessFirstRound() {
	s.SetL1Automine(false)
	defer s.SetL1Automine(true)

	_, _, fee, err := s.p.proverSelector.AssignProver(context.Background(), s.p.tierFees, testutils.RandomHash())

	s.Nil(err)
	s.Equal(fee.Uint64(), s.p.OptimisticTierFee.Uint64())
}

func (s *ProposerTestSuite) TestUpdateProposingTicker() {
	s.p.ProposeInterval = 1 * time.Hour
	s.NotPanics(s.p.updateProposingTicker)

	s.p.ProposeInterval = 0
	s.NotPanics(s.p.updateProposingTicker)
}

func (s *ProposerTestSuite) TestStartClose() {
	s.Nil(s.p.Start())
	s.cancel()
	s.NotPanics(func() { s.p.Close(context.Background()) })
}

func TestProposerTestSuite(t *testing.T) {
	suite.Run(t, new(ProposerTestSuite))
}
