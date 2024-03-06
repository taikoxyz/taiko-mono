package testutils

import (
	"context"
	"crypto/ecdsa"
	"crypto/rand"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/go-resty/resty/v2"
	"github.com/phayes/freeport"

	"github.com/taikoxyz/taiko-client/bindings"
	"github.com/taikoxyz/taiko-client/prover/server"
)

func (s *ClientTestSuite) ProposeInvalidTxListBytes(proposer Proposer) {
	invalidTxListBytes := RandomBytes(256)

	s.Nil(proposer.ProposeTxList(context.Background(), invalidTxListBytes, 1))
	for _, confirmCh := range proposer.GetSender().TxToConfirmChannels() {
		confirm := <-confirmCh
		s.Nil(confirm.Err)
	}
}

func (s *ClientTestSuite) ProposeAndInsertEmptyBlocks(
	proposer Proposer,
	calldataSyncer CalldataSyncer,
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
	for _, confirmCh := range proposer.GetSender().TxToConfirmChannels() {
		confirm := <-confirmCh
		s.Nil(confirm.Err)
	}

	s.ProposeInvalidTxListBytes(proposer)

	// Random bytes txList
	s.Nil(proposer.ProposeEmptyBlockOp(context.Background()))

	events = append(events, []*bindings.TaikoL1ClientBlockProposed{<-sink, <-sink, <-sink}...)

	_, isPending, err := s.RPCClient.L1.TransactionByHash(context.Background(), events[len(events)-1].Raw.TxHash)
	s.Nil(err)
	s.False(isPending)

	newL1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(newL1Head.Number.Uint64(), l1Head.Number.Uint64())

	syncProgress, err := s.RPCClient.L2.SyncProgress(context.Background())
	s.Nil(err)
	s.Nil(syncProgress)

	ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
	defer cancel()

	s.Nil(calldataSyncer.ProcessL1Blocks(ctx, newL1Head))

	return events
}

// ProposeAndInsertValidBlock proposes an valid tx list and then insert it
// into L2 execution engine's local chain.
func (s *ClientTestSuite) ProposeAndInsertValidBlock(
	proposer Proposer,
	calldataSyncer CalldataSyncer,
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

	baseFee, err := s.RPCClient.TaikoL2.GetBasefee(nil, 0, uint32(l2Head.GasUsed))
	s.Nil(err)

	nonce, err := s.RPCClient.L2.PendingNonceAt(context.Background(), s.TestAddr)
	s.Nil(err)

	tx := types.NewTransaction(
		nonce,
		common.BytesToAddress(RandomBytes(32)),
		common.Big1,
		100000,
		baseFee,
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

	_, err = s.RPCClient.L2.SyncProgress(context.Background())
	s.Nil(err)

	ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
	defer cancel()

	s.Nil(calldataSyncer.ProcessL1Blocks(ctx, newL1Head))

	_, err = s.RPCClient.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

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
		ProverPrivateKey:        proverPrivKey,
		MinOptimisticTierFee:    common.Big1,
		MinSgxTierFee:           common.Big1,
		MaxExpiry:               24 * time.Hour,
		TaikoL1Address:          common.HexToAddress(os.Getenv("TAIKO_L1_ADDRESS")),
		AssignmentHookAddress:   common.HexToAddress(os.Getenv("ASSIGNMENT_HOOK_ADDRESS")),
		ProposeConcurrencyGuard: make(chan struct{}, 1024),
		RPC:                     s.RPCClient,
		ProtocolConfigs:         &protocolConfig,
		LivenessBond:            protocolConfig.LivenessBond,
		IsGuardian:              true,
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
		log.Crit("Failed to get local free random port", "err", err)
	}
	return port
}

// LocalRandomProverEndpoint returns a local free random prover endpoint.
func LocalRandomProverEndpoint() *url.URL {
	port := RandomPort()

	proverEndpoint, err := url.Parse(fmt.Sprintf("http://localhost:%v", port))
	if err != nil {
		log.Crit("Failed to parse local prover endpoint", "err", err)
	}

	return proverEndpoint
}

// SignatureFromRSV creates the signature bytes from r,s,v.
func SignatureFromRSV(r, s string, v byte) []byte {
	return append(append(hexutil.MustDecode(r), hexutil.MustDecode(s)...), v)
}
