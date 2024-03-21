package sender_test

import (
	"context"
	"math/big"
	"os"
	"runtime"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/holiman/uint256"
	"github.com/stretchr/testify/suite"
	"golang.org/x/sync/errgroup"

	"github.com/taikoxyz/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-client/internal/utils"
	"github.com/taikoxyz/taiko-client/pkg/sender"
)

type SenderTestSuite struct {
	testutils.ClientTestSuite
	sender *sender.Sender
}

func (s *SenderTestSuite) TestSendTransaction() {
	var (
		opts   = s.sender.GetOpts(context.Background())
		client = s.RPCClient.L1
		eg     errgroup.Group
	)
	eg.SetLimit(runtime.NumCPU())
	for i := 0; i < 8; i++ {
		i := i
		eg.Go(func() error {
			to := common.BigToAddress(big.NewInt(int64(i)))
			tx := types.NewTx(&types.DynamicFeeTx{
				ChainID:   client.ChainID,
				To:        &to,
				GasFeeCap: opts.GasFeeCap,
				GasTipCap: opts.GasTipCap,
				Gas:       21000000,
				Value:     big.NewInt(1),
				Data:      nil,
			})

			_, err := s.sender.SendTransaction(tx)
			return err
		})
	}
	s.Nil(eg.Wait())

	for _, confirmCh := range s.sender.TxToConfirmChannels() {
		confirm := <-confirmCh
		s.Nil(confirm.Err)
	}
}

func (s *SenderTestSuite) TestSendRawTransaction() {
	nonce, err := s.RPCClient.L1.NonceAt(context.Background(), s.sender.Address(), nil)
	s.Nil(err)

	var eg errgroup.Group
	eg.SetLimit(runtime.NumCPU())
	for i := 0; i < 5; i++ {
		i := i
		eg.Go(func() error {
			addr := common.BigToAddress(big.NewInt(int64(i)))
			_, err := s.sender.SendRawTransaction(
				context.Background(),
				nonce+uint64(i),
				&addr,
				big.NewInt(1),
				nil,
				nil,
			)
			return err
		})
	}
	s.Nil(eg.Wait())

	for _, confirmCh := range s.sender.TxToConfirmChannels() {
		confirm := <-confirmCh
		s.Nil(confirm.Err)
	}
}

// Test touch max gas price and replacement.
func (s *SenderTestSuite) TestReplacement() {
	send := s.sender
	client := s.RPCClient.L1
	opts := send.GetOpts(context.Background())

	// Let max gas price be 2 times of the gas fee cap.
	send.MaxGasFee = opts.GasFeeCap.Uint64() * 2

	nonce, err := client.NonceAt(context.Background(), opts.From, nil)
	s.Nil(err)

	pendingNonce, err := client.PendingNonceAt(context.Background(), opts.From)
	s.Nil(err)
	// Run test only if mempool has no pending transactions.
	if pendingNonce > nonce {
		return
	}

	nonce++
	baseTx := &types.DynamicFeeTx{
		ChainID:   client.ChainID,
		To:        &common.Address{},
		GasFeeCap: big.NewInt(int64(send.MaxGasFee - 1)),
		GasTipCap: big.NewInt(int64(send.MaxGasFee - 1)),
		Nonce:     nonce,
		Gas:       21000,
		Value:     big.NewInt(1),
		Data:      nil,
	}
	rawTx, err := opts.Signer(opts.From, types.NewTx(baseTx))
	s.Nil(err)
	err = client.SendTransaction(context.Background(), rawTx)
	s.Nil(err)

	ctx := context.Background()
	// Replace the transaction with a higher nonce.
	_, err = send.SendRawTransaction(ctx, nonce, &common.Address{}, big.NewInt(1), nil, nil)
	s.Nil(err)

	time.Sleep(time.Second * 6)
	// Send a transaction with a next nonce and let all the transactions be confirmed.
	_, err = send.SendRawTransaction(ctx, nonce-1, &common.Address{}, big.NewInt(1), nil, nil)
	s.Nil(err)

	for _, confirmCh := range send.TxToConfirmChannels() {
		confirm := <-confirmCh
		// Check the replaced transaction's gasFeeTap touch the max gas price.
		if confirm.CurrentTx.Nonce() == nonce {
			s.Equal(send.MaxGasFee, confirm.CurrentTx.GasFeeCap().Uint64())
		}
		s.Nil(confirm.Err)
	}

	_, err = client.TransactionReceipt(context.Background(), rawTx.Hash())
	s.Equal("not found", err.Error())
}

// Test nonce too low.
func (s *SenderTestSuite) TestNonceTooLow() {
	client := s.RPCClient.L1
	send := s.sender
	opts := s.sender.GetOpts(context.Background())

	nonce, err := client.NonceAt(context.Background(), opts.From, nil)
	s.Nil(err)
	pendingNonce, err := client.PendingNonceAt(context.Background(), opts.From)
	s.Nil(err)
	// Run test only if mempool has no pending transactions.
	if pendingNonce > nonce {
		return
	}

	txID, err := send.SendRawTransaction(
		context.Background(),
		nonce-3,
		&common.Address{},
		big.NewInt(1),
		nil,
		nil,
	)
	s.Nil(err)
	confirm := <-send.TxToConfirmChannel(txID)
	s.Nil(confirm.Err)
	s.Equal(nonce, confirm.CurrentTx.Nonce())
}

func (s *SenderTestSuite) TestAdjustGas() {
	send := s.sender
	dynamicTx := &types.DynamicFeeTx{}
	blobTx := &types.BlobTx{}

	for _, val := range []uint64{1, 20, 50, 100, 200, 1000, 10000, 20000} {
		expectGasFeeCap := val + val*(send.GasGrowthRate)/100
		expectGasTipCap := val + val*(send.GasGrowthRate)/100
		expectGasTipCap = utils.Min(expectGasFeeCap, utils.Min(expectGasTipCap, send.MaxGasFee))

		dynamicTx.GasFeeCap = new(big.Int).SetUint64(val)
		dynamicTx.GasTipCap = new(big.Int).SetUint64(val)
		send.AdjustGasFee(dynamicTx)
		s.Equal(expectGasFeeCap, dynamicTx.GasFeeCap.Uint64(), "val: %d", val)
		s.Equal(expectGasTipCap, dynamicTx.GasTipCap.Uint64(), "val: %d", val)

		blobTx.GasFeeCap = uint256.NewInt(val)
		blobTx.GasTipCap = uint256.NewInt(val)
		send.AdjustGasFee(blobTx)
		s.Equal(expectGasFeeCap, blobTx.GasFeeCap.Uint64(), "val: %d", val)
		s.Equal(expectGasTipCap, blobTx.GasTipCap.Uint64(), "val: %d", val)

		expectGasTipCap = utils.Max(val*(send.GasGrowthRate+100)/100, val+1)
		blobTx.BlobFeeCap = uint256.NewInt(val)
		send.AdjustBlobGasFee(blobTx)
		s.Equal(expectGasTipCap, blobTx.BlobFeeCap.Uint64(), "val: %d", val)
	}
}

func (s *SenderTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()
	s.SetL1Automine(true)

	ctx := context.Background()
	priv, err := crypto.ToECDSA(common.FromHex(os.Getenv("L1_PROPOSER_PRIVATE_KEY")))
	s.Nil(err)

	s.sender, err = sender.NewSender(ctx, &sender.Config{
		MaxGasFee:      20000000000,
		GasGrowthRate:  50,
		MaxRetrys:      0,
		GasLimit:       2000000,
		MaxWaitingTime: time.Second * 10,
	}, s.RPCClient.L1, priv)
	s.Nil(err)
}

func (s *SenderTestSuite) TearDownTest() {
	s.SetL1Automine(false)
	s.sender.Close()
	s.ClientTestSuite.TearDownTest()
}

func TestSenderTestSuite(t *testing.T) {
	suite.Run(t, new(SenderTestSuite))
}
