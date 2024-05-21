package testutils

import (
	"context"
	"crypto/ecdsa"
	"crypto/rand"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"net/url"
	"os"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/params"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/go-resty/resty/v2"
	"github.com/phayes/freeport"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/server"
)

func (s *ClientTestSuite) ProposeInvalidTxListBytes(proposer Proposer) {
	invalidTxListBytes := RandomBytes(256)

	s.Nil(proposer.ProposeTxList(context.Background(), invalidTxListBytes, 1))
}

func (s *ClientTestSuite) proposeEmptyBlockOp(ctx context.Context, proposer Proposer) {
	emptyTxListBytes, err := rlp.EncodeToBytes(types.Transactions{})
	s.Nil(err)
	s.Nil(proposer.ProposeTxList(ctx, emptyTxListBytes, 0))
}

func (s *ClientTestSuite) ProposeAndInsertEmptyBlocks(
	proposer Proposer,
	blobSyncer BlobSyncer,
) []*bindings.TaikoL1ClientBlockProposed {
	var events []*bindings.TaikoL1ClientBlockProposed

	l1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	sink := make(chan *bindings.TaikoL1ClientBlockProposed)

	sub, err := s.RPCClient.TaikoL1.WatchBlockProposed(nil, sink, nil, nil)
	s.Nil(err)
	defer func() {
		sub.Unsubscribe()
		close(sink)
	}()

	// RLP encoded empty list
	var emptyTxs []types.Transaction
	encoded, err := rlp.EncodeToBytes(emptyTxs)
	s.Nil(err)

	s.Nil(proposer.ProposeTxList(context.Background(), encoded, 0))

	s.ProposeInvalidTxListBytes(proposer)

	// Random bytes txList
	s.proposeEmptyBlockOp(context.Background(), proposer)

	events = append(events, []*bindings.TaikoL1ClientBlockProposed{<-sink, <-sink, <-sink}...)

	_, isPending, err := s.RPCClient.L1.TransactionByHash(context.Background(), events[len(events)-1].Raw.TxHash)
	s.Nil(err)
	s.False(isPending)

	newL1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(newL1Head.Number.Uint64(), l1Head.Number.Uint64())

	ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
	defer cancel()

	s.Nil(backoff.Retry(func() error {
		return blobSyncer.ProcessL1Blocks(ctx)
	}, backoff.NewExponentialBackOff()))

	s.Nil(s.RPCClient.WaitTillL2ExecutionEngineSynced(context.Background()))

	return events
}

// ProposeAndInsertValidBlock proposes an valid tx list and then insert it
// into L2 execution engine's local chain.
func (s *ClientTestSuite) ProposeAndInsertValidBlock(
	proposer Proposer,
	blobSyncer BlobSyncer,
) *bindings.TaikoL1ClientBlockProposed {
	l1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	l2Head, err := s.RPCClient.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	// Propose txs in L2 execution engine's mempool
	sink := make(chan *bindings.TaikoL1ClientBlockProposed)

	sub, err := s.RPCClient.TaikoL1.WatchBlockProposed(nil, sink, nil, nil)
	s.Nil(err)
	defer func() {
		sub.Unsubscribe()
		close(sink)
	}()

	baseFeeInfo, err := s.RPCClient.TaikoL2.GetBasefee(nil, l1Head.Number.Uint64()+1, uint32(l2Head.GasUsed))
	s.Nil(err)

	nonce, err := s.RPCClient.L2.PendingNonceAt(context.Background(), s.TestAddr)
	s.Nil(err)

	tx := types.NewTransaction(
		nonce,
		common.BytesToAddress(RandomBytes(32)),
		common.Big1,
		100000,
		new(big.Int).SetUint64(uint64(10*params.GWei)+baseFeeInfo.Basefee.Uint64()),
		[]byte{},
	)
	signedTx, err := types.SignTx(tx, types.LatestSignerForChainID(s.RPCClient.L2.ChainID), s.TestAddrPrivKey)
	s.Nil(err)
	s.Nil(s.RPCClient.L2.SendTransaction(context.Background(), signedTx))

	s.Nil(proposer.ProposeOp(context.Background()))

	event := <-sink

	_, isPending, err := s.RPCClient.L1.TransactionByHash(context.Background(), event.Raw.TxHash)
	s.Nil(err)
	s.False(isPending)

	receipt, err := s.RPCClient.L1.TransactionReceipt(context.Background(), event.Raw.TxHash)
	s.Nil(err)
	s.Equal(types.ReceiptStatusSuccessful, receipt.Status)

	newL1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(newL1Head.Number.Uint64(), l1Head.Number.Uint64())

	ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
	defer cancel()

	s.Nil(backoff.Retry(func() error {
		return blobSyncer.ProcessL1Blocks(ctx)
	}, backoff.NewExponentialBackOff()))

	s.Nil(s.RPCClient.WaitTillL2ExecutionEngineSynced(context.Background()))

	_, err = s.RPCClient.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	return event
}

func (s *ClientTestSuite) ProposeValidBlock(
	proposer Proposer,
) *bindings.TaikoL1ClientBlockProposed {
	l1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	l2Head, err := s.RPCClient.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	// Propose txs in L2 execution engine's mempool
	sink := make(chan *bindings.TaikoL1ClientBlockProposed)

	sub, err := s.RPCClient.TaikoL1.WatchBlockProposed(nil, sink, nil, nil)
	s.Nil(err)
	defer func() {
		sub.Unsubscribe()
		close(sink)
	}()

	baseFeeInfo, err := s.RPCClient.TaikoL2.GetBasefee(nil, l1Head.Number.Uint64()+1, uint32(l2Head.GasUsed))
	s.Nil(err)

	nonce, err := s.RPCClient.L2.PendingNonceAt(context.Background(), s.TestAddr)
	s.Nil(err)

	tx := types.NewTransaction(
		nonce,
		common.BytesToAddress(RandomBytes(32)),
		common.Big1,
		100000,
		new(big.Int).SetUint64(uint64(10*params.GWei)+baseFeeInfo.Basefee.Uint64()),
		[]byte{},
	)
	signedTx, err := types.SignTx(tx, types.LatestSignerForChainID(s.RPCClient.L2.ChainID), s.TestAddrPrivKey)
	s.Nil(err)
	s.Nil(s.RPCClient.L2.SendTransaction(context.Background(), signedTx))

	s.Nil(proposer.ProposeOp(context.Background()))

	event := <-sink

	_, isPending, err := s.RPCClient.L1.TransactionByHash(context.Background(), event.Raw.TxHash)
	s.Nil(err)
	s.False(isPending)

	receipt, err := s.RPCClient.L1.TransactionReceipt(context.Background(), event.Raw.TxHash)
	s.Nil(err)
	s.Equal(types.ReceiptStatusSuccessful, receipt.Status)

	newL1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(newL1Head.Number.Uint64(), l1Head.Number.Uint64())

	return event
}

// NewTestProverServer starts a new prover server that has channel listeners to respond and react
// to requests for capacity, which provers can call.
func (s *ClientTestSuite) NewTestProverServer(
	proverPrivKey *ecdsa.PrivateKey,
	url *url.URL,
) *server.ProverServer {
	protocolConfig, err := s.RPCClient.TaikoL1.GetConfig(nil)
	s.Nil(err)

	srv, err := server.New(&server.NewProverServerOpts{
		ProverPrivateKey:      proverPrivKey,
		MinOptimisticTierFee:  common.Big1,
		MinSgxTierFee:         common.Big1,
		MinSgxAndZkVMTierFee:  common.Big1,
		MinEthBalance:         common.Big1,
		MinTaikoTokenBalance:  common.Big1,
		MaxExpiry:             24 * time.Hour,
		TaikoL1Address:        common.HexToAddress(os.Getenv("TAIKO_L1_ADDRESS")),
		ProverSetAddress:      common.HexToAddress(os.Getenv("PROVER_SET_ADDRESS")),
		AssignmentHookAddress: common.HexToAddress(os.Getenv("ASSIGNMENT_HOOK_ADDRESS")),
		RPC:                   s.RPCClient,
		ProtocolConfigs:       &protocolConfig,
		LivenessBond:          protocolConfig.LivenessBond,
	})
	s.Nil(err)

	go func() {
		if err := srv.Start(fmt.Sprintf(":%v", url.Port())); !errors.Is(err, http.ErrServerClosed) {
			log.Error("Failed to start prover server", "error", err)
		}
	}()

	// Wait till the server fully started.
	s.Nil(backoff.Retry(func() error {
		res, err := resty.New().R().Get(url.String() + "/healthz")
		if err != nil {
			return err
		}
		if !res.IsSuccess() {
			return fmt.Errorf("invalid response status code: %d", res.StatusCode())
		}

		return nil
	}, backoff.NewExponentialBackOff()))

	return srv
}

// RandomHash generates a random blob of data and returns it as a hash.
func RandomHash() common.Hash {
	var hash common.Hash
	if n, err := rand.Read(hash[:]); n != common.HashLength || err != nil {
		panic(err)
	}
	return hash
}

// RandomBytes generates a random bytes.
func RandomBytes(size int) (b []byte) {
	b = make([]byte, size)
	if _, err := rand.Read(b); err != nil {
		log.Crit("Generate random bytes error", "error", err)
	}
	return
}

// RandomPort returns a local free random port.
func RandomPort() int {
	port, err := freeport.GetFreePort()
	if err != nil {
		log.Crit("Failed to get local free random port", "error", err)
	}
	return port
}

// LocalRandomProverEndpoint returns a local free random prover endpoint.
func LocalRandomProverEndpoint() *url.URL {
	port := RandomPort()

	proverEndpoint, err := url.Parse(fmt.Sprintf("http://localhost:%v", port))
	if err != nil {
		log.Crit("Failed to parse local prover endpoint", "error", err)
	}

	return proverEndpoint
}

// SignatureFromRSV creates the signature bytes from r,s,v.
func SignatureFromRSV(r, s string, v byte) []byte {
	return append(append(hexutil.MustDecode(r), hexutil.MustDecode(s)...), v)
}

// SendDynamicFeeTx sends a dynamic transaction, used for tests.
func SendDynamicFeeTx(
	client *rpc.EthClient,
	priv *ecdsa.PrivateKey,
	to *common.Address,
	value *big.Int,
	data []byte,
) (*types.Transaction, error) {
	head, err := client.HeaderByNumber(context.Background(), nil)
	if err != nil {
		return nil, err
	}

	auth, err := bind.NewKeyedTransactorWithChainID(priv, client.ChainID)
	if err != nil {
		return nil, err
	}

	nonce, err := client.PendingNonceAt(context.Background(), auth.From)
	if err != nil {
		return nil, err
	}

	gasTipCap, err := client.SuggestGasTipCap(context.Background())
	if err != nil {
		return nil, err
	}

	tx, err := auth.Signer(auth.From, types.NewTx(&types.DynamicFeeTx{
		To:        to,
		Nonce:     nonce,
		Value:     value,
		GasTipCap: gasTipCap,
		GasFeeCap: new(big.Int).Add(
			gasTipCap,
			new(big.Int).Mul(head.BaseFee, big.NewInt(2)),
		),
		Gas:  2100_000,
		Data: data,
	}))
	if err != nil {
		return nil, err
	}
	if err = client.SendTransaction(context.Background(), tx); err != nil {
		return nil, err
	}
	return tx, nil
}
