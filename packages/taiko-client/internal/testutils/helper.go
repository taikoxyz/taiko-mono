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

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

func (s *ClientTestSuite) proposeEmptyBlockOp(ctx context.Context, proposer Proposer) {
	s.Nil(proposer.ProposeTxLists(ctx, []types.Transactions{{}}))
}

func (s *ClientTestSuite) ProposeAndInsertEmptyBlocks(
	proposer Proposer,
	blobSyncer BlobSyncer,
) []metadata.TaikoBlockMetaData {
	var metadataList []metadata.TaikoBlockMetaData

	l1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	sink := make(chan *bindings.TaikoL1ClientBlockProposed)
	sub, err := s.RPCClient.TaikoL1.WatchBlockProposed(nil, sink, nil, nil)
	s.Nil(err)
	defer func() {
		sub.Unsubscribe()
		close(sink)
	}()

	sink2 := make(chan *bindings.TaikoL1ClientBlockProposedV2)
	sub2, err := s.RPCClient.TaikoL1.WatchBlockProposedV2(nil, sink2, nil)
	s.Nil(err)
	defer func() {
		sub2.Unsubscribe()
		close(sink2)
	}()

	// RLP encoded empty list
	s.Nil(proposer.ProposeTxLists(context.Background(), []types.Transactions{{}}))
	s.Nil(blobSyncer.ProcessL1Blocks(context.Background()))

	// Valid transactions lists.
	s.ProposeValidBlock(proposer)
	s.Nil(blobSyncer.ProcessL1Blocks(context.Background()))

	// Random bytes txList
	s.proposeEmptyBlockOp(context.Background(), proposer)
	s.Nil(blobSyncer.ProcessL1Blocks(context.Background()))

	var txHash common.Hash
	for i := 0; i < 3; i++ {
		select {
		case event := <-sink:
			metadataList = append(metadataList, metadata.NewTaikoDataBlockMetadataLegacy(event))
			txHash = event.Raw.TxHash
		case event := <-sink2:
			metadataList = append(metadataList, metadata.NewTaikoDataBlockMetadataOntake(event))
			txHash = event.Raw.TxHash
		}
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

// ProposeAndInsertValidBlock proposes an valid tx list and then insert it
// into L2 execution engine's local chain.
func (s *ClientTestSuite) ProposeAndInsertValidBlock(
	proposer Proposer,
	blobSyncer BlobSyncer,
) metadata.TaikoBlockMetaData {
	l1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	// Propose txs in L2 execution engine's mempool
	sink := make(chan *bindings.TaikoL1ClientBlockProposed)
	sub, err := s.RPCClient.TaikoL1.WatchBlockProposed(nil, sink, nil, nil)
	s.Nil(err)

	sink2 := make(chan *bindings.TaikoL1ClientBlockProposedV2)
	sub2, err := s.RPCClient.TaikoL1.WatchBlockProposedV2(nil, sink2, nil)
	s.Nil(err)

	defer func() {
		sub.Unsubscribe()
		sub2.Unsubscribe()
		close(sink)
		close(sink2)
	}()

	nonce, err := s.RPCClient.L2.PendingNonceAt(context.Background(), s.TestAddr)
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
	s.Nil(s.RPCClient.L2.SendTransaction(context.Background(), signedTx))

	s.Nil(proposer.ProposeOp(context.Background()))

	var (
		txHash common.Hash
		meta   metadata.TaikoBlockMetaData
	)
	select {
	case event := <-sink:
		txHash = event.Raw.TxHash
		meta = metadata.NewTaikoDataBlockMetadataLegacy(event)
	case event := <-sink2:
		txHash = event.Raw.TxHash
		meta = metadata.NewTaikoDataBlockMetadataOntake(event)
	}

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

	s.Nil(backoff.Retry(func() error {
		return blobSyncer.ProcessL1Blocks(ctx)
	}, backoff.NewExponentialBackOff()))

	s.Nil(s.RPCClient.WaitTillL2ExecutionEngineSynced(context.Background()))

	_, err = s.RPCClient.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	return meta
}

func (s *ClientTestSuite) ProposeValidBlock(
	proposer Proposer,
) {
	l1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	state, err := s.RPCClient.GetProtocolStateVariables(nil)
	s.Nil(err)

	l2Head, err := s.RPCClient.L2.HeaderByNumber(context.Background(), new(big.Int).SetUint64(state.B.NumBlocks-1))
	s.Nil(err)

	// Propose txs in L2 execution engine's mempool
	sink := make(chan *bindings.TaikoL1ClientBlockProposed)
	sink2 := make(chan *bindings.TaikoL1ClientBlockProposedV2)

	sub, err := s.RPCClient.TaikoL1.WatchBlockProposed(nil, sink, nil, nil)
	s.Nil(err)

	sub2, err := s.RPCClient.TaikoL1.WatchBlockProposedV2(nil, sink2, nil)
	s.Nil(err)

	defer func() {
		sub.Unsubscribe()
		sub2.Unsubscribe()
		close(sink)
		close(sink2)
	}()

	ontakeForkHeight, err := s.RPCClient.TaikoL2.OntakeForkHeight(nil)
	s.Nil(err)

	baseFee, err := s.RPCClient.CalculateBaseFee(
		context.Background(),
		l2Head,
		l1Head.Number,
		l2Head.Number.Uint64()+1 >= ontakeForkHeight,
		&encoding.InternlDevnetProtocolConfig.BaseFeeConfig,
		l1Head.Time,
	)
	s.Nil(err)

	nonce, err := s.RPCClient.L2.PendingNonceAt(context.Background(), s.TestAddr)
	s.Nil(err)

	tx := types.NewTransaction(
		nonce,
		common.BytesToAddress(RandomBytes(32)),
		common.Big0,
		100_000,
		new(big.Int).SetUint64(uint64(10*params.GWei)+baseFee.Uint64()),
		[]byte{},
	)
	signedTx, err := types.SignTx(tx, types.LatestSignerForChainID(s.RPCClient.L2.ChainID), s.TestAddrPrivKey)
	s.Nil(err)
	s.Nil(s.RPCClient.L2.SendTransaction(context.Background(), signedTx))

	s.Nil(proposer.ProposeOp(context.Background()))

	var txHash common.Hash
	select {
	case event := <-sink:
		txHash = event.Raw.TxHash
	case event := <-sink2:
		txHash = event.Raw.TxHash
	}

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

func SendDynamicFeeTxWithNonce(
	client *rpc.EthClient,
	priv *ecdsa.PrivateKey,
	nonce uint64,
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
