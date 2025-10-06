package testutils

import (
	"context"
	"crypto/ecdsa"
	"crypto/rand"
	"math/big"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/params"
	"github.com/phayes/freeport"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

func (s *ClientTestSuite) proposeEmptyBlockOp(ctx context.Context, proposer Proposer, l2BaseFee *big.Int) {
	s.Nil(proposer.ProposeTxLists(ctx, []types.Transactions{{}}, common.Hash{}, l2BaseFee, false))
}

func (s *ClientTestSuite) ProposeAndInsertEmptyBlocks(
	proposer Proposer,
	chainSyncer ChainSyncer,
) []metadata.TaikoProposalMetaData {
	// Sync all pending L2 blocks at first.
	s.NotPanics(func() {
		if err := chainSyncer.ProcessL1Blocks(context.Background()); err != nil {
			log.Warn("Failed to process L1 blocks", "error", err)
		}
	})

	var metadataList []metadata.TaikoProposalMetaData

	l1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	// Propose txs in L2 execution engine's mempool
	sink1 := make(chan *pacayaBindings.TaikoInboxClientBatchProposed)
	sub1, err := s.RPCClient.PacayaClients.TaikoInbox.WatchBatchProposed(nil, sink1)
	s.Nil(err)

	defer func() {
		sub1.Unsubscribe()
		close(sink1)
	}()

	l2BaseFee, err := s.RPCClient.L2.SuggestGasPrice(context.Background())
	s.Nil(err)

	// RLP encoded empty list
	s.Nil(proposer.ProposeTxLists(context.Background(), []types.Transactions{{}}, common.Hash{}, l2BaseFee, false))
	s.Nil(chainSyncer.ProcessL1Blocks(context.Background()))

	// Valid transactions lists.
	s.ProposeValidBlock(proposer)
	s.Nil(chainSyncer.ProcessL1Blocks(context.Background()))

	// Random bytes txList
	s.proposeEmptyBlockOp(context.Background(), proposer, l2BaseFee)
	s.Nil(chainSyncer.ProcessL1Blocks(context.Background()))

	var txHash common.Hash
	for i := 0; i < 3; i++ {
		event := <-sink1
		metadataList = append(metadataList, metadata.NewTaikoDataBlockMetadataPacaya(event))
		txHash = event.Raw.TxHash
	}

	_, isPending, err := s.RPCClient.L1.TransactionByHash(context.Background(), txHash)
	s.Nil(err)
	s.False(isPending)

	newL1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(newL1Head.Number.Uint64(), l1Head.Number.Uint64())

	s.Nil(s.RPCClient.WaitTillL2ExecutionEngineSynced(context.Background()))

	return metadataList
}

// ProposeAndInsertValidBlock proposes a valid tx list and then insert it
// into L2 execution engine's local chain.
func (s *ClientTestSuite) ProposeAndInsertValidBlock(
	proposer Proposer,
	chainSyncer ChainSyncer,
) metadata.TaikoProposalMetaData {
	// Sync all pending L2 blocks at first.
	s.NotPanics(func() {
		if err := chainSyncer.ProcessL1Blocks(context.Background()); err != nil {
			log.Warn("Failed to process L1 blocks", "error", err)
		}
	})

	l1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	// Propose txs in L2 execution engine's mempool
	sink1 := make(chan *pacayaBindings.TaikoInboxClientBatchProposed)
	sub1, err := s.RPCClient.PacayaClients.TaikoInbox.WatchBatchProposed(nil, sink1)
	s.Nil(err)

	defer func() {
		sub1.Unsubscribe()
		close(sink1)
	}()

	nonce, err := s.RPCClient.L2.NonceAt(context.Background(), s.TestAddr, nil)
	s.Nil(err)

	tx := types.NewTransaction(
		nonce,
		common.BytesToAddress(RandomBytes(32)),
		common.Big0,
		100_000,
		new(big.Int).SetUint64(uint64(10*params.GWei)),
		[]byte{},
	)
	signedTx, err := types.SignTx(tx, types.LatestSignerForChainID(s.RPCClient.L2.ChainID), s.TestAddrPrivKey)
	s.Nil(err)
	err = s.RPCClient.L2.SendTransaction(context.Background(), signedTx)
	if err != nil {
		// If the transaction is underpriced, we just ignore it.
		s.Equal("replacement transaction underpriced", err.Error())
	}
	s.Nil(proposer.ProposeOp(context.Background()))

	event := <-sink1
	meta := metadata.NewTaikoDataBlockMetadataPacaya(event)
	txHash := event.Raw.TxHash

	_, isPending, err := s.RPCClient.L1.TransactionByHash(context.Background(), txHash)
	s.Nil(err)
	s.False(isPending)

	receipt, err := s.RPCClient.L1.TransactionReceipt(context.Background(), txHash)
	s.Nil(err)
	s.Equal(types.ReceiptStatusSuccessful, receipt.Status)

	newL1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(newL1Head.Number.Uint64(), l1Head.Number.Uint64())

	ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
	defer cancel()

	s.Nil(backoff.Retry(func() error { return chainSyncer.ProcessL1Blocks(ctx) }, backoff.NewExponentialBackOff()))

	s.Nil(s.RPCClient.WaitTillL2ExecutionEngineSynced(context.Background()))

	_, err = s.RPCClient.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	return meta
}

func (s *ClientTestSuite) ProposeValidBlock(proposer Proposer) {
	l1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	l2Head, err := s.RPCClient.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	// Propose txs in L2 execution engine's mempool
	sink1 := make(chan *pacayaBindings.TaikoInboxClientBatchProposed)
	sub1, err := s.RPCClient.PacayaClients.TaikoInbox.WatchBatchProposed(nil, sink1)
	s.Nil(err)

	defer func() {
		sub1.Unsubscribe()
		close(sink1)
	}()

	nonce, err := s.RPCClient.L2.PendingNonceAt(context.Background(), s.TestAddr)
	s.Nil(err)

	tx := types.NewTransaction(
		nonce,
		common.BytesToAddress(RandomBytes(32)),
		common.Big0,
		100_000,
		new(big.Int).SetUint64(uint64(10*params.GWei)+l2Head.BaseFee.Uint64()),
		[]byte{},
	)
	signedTx, err := types.SignTx(tx, types.LatestSignerForChainID(s.RPCClient.L2.ChainID), s.TestAddrPrivKey)
	s.Nil(err)
	s.Nil(s.RPCClient.L2.SendTransaction(context.Background(), signedTx))

	s.Nil(proposer.ProposeOp(context.Background()))

	event := <-sink1
	txHash := event.Raw.TxHash

	_, isPending, err := s.RPCClient.L1.TransactionByHash(context.Background(), txHash)
	s.Nil(err)
	s.False(isPending)

	receipt, err := s.RPCClient.L1.TransactionReceipt(context.Background(), txHash)
	s.Nil(err)
	s.Equal(types.ReceiptStatusSuccessful, receipt.Status)

	newL1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(newL1Head.Number.Uint64(), l1Head.Number.Uint64())
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

// SignatureFromRSV creates the signature bytes from r,s,v.
func SignatureFromRSV(r, s string, v byte) []byte {
	return append(append(hexutil.MustDecode(r), hexutil.MustDecode(s)...), v)
}

// AssembleAndSendTestTx assembles a test transaction, and sends it to the given node.
func AssembleAndSendTestTx(
	client *rpc.EthClient,
	key *ecdsa.PrivateKey,
	nonce uint64,
	to *common.Address,
	value *big.Int,
	data []byte,
) (*types.Transaction, error) {
	auth, err := bind.NewKeyedTransactorWithChainID(key, client.ChainID)
	if err != nil {
		return nil, err
	}

	tx, err := auth.Signer(auth.From, types.NewTx(&types.DynamicFeeTx{
		To:        to,
		Nonce:     nonce,
		Value:     value,
		GasTipCap: new(big.Int).SetUint64(1 * params.GWei),
		GasFeeCap: new(big.Int).SetUint64(2 * params.GWei),
		Gas:       2_100_000,
		Data:      data,
	}))
	if err != nil {
		return nil, err
	}

	return tx, client.SendTransaction(context.Background(), tx)
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
