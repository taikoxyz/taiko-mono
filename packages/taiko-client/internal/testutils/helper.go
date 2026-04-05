package testutils

import (
	"context"
	"crypto/ecdsa"
	"crypto/rand"
	"math/big"
	"os"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	consensus "github.com/ethereum/go-ethereum/consensus/taiko"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/miner"
	"github.com/ethereum/go-ethereum/params"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/phayes/freeport"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	anchortxconstructor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/anchor_tx_constructor"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	builder "github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer/transaction_builder"
)

func (s *ClientTestSuite) proposeEmptyBlockOp(ctx context.Context, proposer Proposer) {
	s.L1Mine()
	s.Nil(proposer.ProposeTxLists(ctx, []types.Transactions{{}}))
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
	sink := make(chan *shastaBindings.ShastaInboxClientProposed)
	sub, err := s.RPCClient.ShastaClients.Inbox.WatchProposed(nil, sink, nil, nil)
	s.Nil(err)

	defer func() {
		sub.Unsubscribe()
		close(sink)
	}()

	// RLP encoded empty list
	s.L1Mine()
	s.Nil(proposer.ProposeTxLists(context.Background(), []types.Transactions{{}}))
	s.Nil(chainSyncer.ProcessL1Blocks(context.Background()))

	// Valid transactions lists.
	s.ProposeValidBlock(proposer)
	s.Nil(chainSyncer.ProcessL1Blocks(context.Background()))

	// Random bytes txList
	s.proposeEmptyBlockOp(context.Background(), proposer)
	s.Nil(chainSyncer.ProcessL1Blocks(context.Background()))

	var txHash common.Hash
	for i := 0; i < 3; i++ {
		event := <-sink
		header, err := s.RPCClient.L1.HeaderByHash(context.Background(), event.Raw.BlockHash)
		s.Nil(err)
		meta := metadata.NewTaikoProposalMetadataShasta(event, header.Time)
		metadataList = append(metadataList, meta)
		txHash = event.Raw.TxHash
	}

	_, isPending, err := s.RPCClient.L1.TransactionByHash(context.Background(), txHash)
	s.Nil(err)
	s.False(isPending)

	newL1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(newL1Head.Number.Uint64(), l1Head.Number.Uint64())

	s.Nil(s.RPCClient.WaitTillL2ExecutionEngineSynced(context.Background()))
	s.L1Mine()

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
	sink := make(chan *shastaBindings.ShastaInboxClientProposed)
	sub, err := s.RPCClient.ShastaClients.Inbox.WatchProposed(nil, sink, nil, nil)
	s.Nil(err)

	defer func() {
		sub.Unsubscribe()
		close(sink)
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
		// If the transaction is underpriced or a replacement is not allowed, we just ignore it.
		// Geth returns "replacement transaction underpriced", Nethermind returns "ReplacementNotAllowed"
		if os.Getenv("L2_NODE") == "l2_nmc" {
			s.Equal("ReplacementNotAllowed", err.Error())
		} else {
			s.Equal("replacement transaction underpriced", err.Error())
		}
	}

	s.L1Mine()
	s.Nil(proposer.ProposeOp(context.Background()))

	var (
		meta   metadata.TaikoProposalMetaData
		txHash common.Hash
	)
	event := <-sink
	header, err := s.RPCClient.L1.HeaderByHash(context.Background(), event.Raw.BlockHash)
	s.Nil(err)
	meta = metadata.NewTaikoProposalMetadataShasta(event, header.Time)
	txHash = event.Raw.TxHash

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
	s.L1Mine()

	return meta
}

func (s *ClientTestSuite) ProposeValidBlock(proposer Proposer) {
	l1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	l2Head, err := s.RPCClient.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	// Propose txs in L2 execution engine's mempool
	sink := make(chan *shastaBindings.ShastaInboxClientProposed)
	sub, err := s.RPCClient.ShastaClients.Inbox.WatchProposed(nil, sink, nil, nil)
	s.Nil(err)

	defer func() {
		sub.Unsubscribe()
		close(sink)
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

	s.L1Mine()
	s.Nil(proposer.ProposeOp(context.Background()))

	var txHash common.Hash
	event := <-sink
	txHash = event.Raw.TxHash

	_, isPending, err := s.RPCClient.L1.TransactionByHash(context.Background(), txHash)
	s.Nil(err)
	s.False(isPending)

	receipt, err := s.RPCClient.L1.TransactionReceipt(context.Background(), txHash)
	s.Nil(err)
	s.Equal(types.ReceiptStatusSuccessful, receipt.Status)

	newL1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Greater(newL1Head.Number.Uint64(), l1Head.Number.Uint64())
	s.L1Mine()
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

func (s *ClientTestSuite) resetToBaseBlock(key *ecdsa.PrivateKey) {
	ctx := context.Background()
	s.L1Mine()

	txCandidate, err := builder.NewBlobTransactionBuilder(
		s.RPCClient,
		common.HexToAddress(os.Getenv("INBOX")),
		common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")),
		10_000_000,
	).Build(ctx, []types.Transactions{{}})
	s.Nil(err)

	proposedCh := make(chan *shastaBindings.ShastaInboxClientProposed, 1)
	sub, err := s.RPCClient.ShastaClients.Inbox.WatchProposed(nil, proposedCh, nil, nil)
	s.Nil(err)
	defer func() {
		sub.Unsubscribe()
		close(proposedCh)
	}()

	_, err = s.TxMgr("proposer", key).Send(ctx, *txCandidate)
	s.Nil(err)

	proposed := <-proposedCh
	s.NotNil(proposed)
	s.Equal(0, proposed.Id.Cmp(common.Big1))

	anchorBlock, err := s.RPCClient.L1.HeaderByHash(ctx, proposed.Raw.BlockHash)
	s.Nil(err)

	s.insertBaseShastaBlock(ctx, anchorBlock, proposed)
	s.Nil(s.RPCClient.WaitTillL2ExecutionEngineSynced(ctx))
	// Leave a fresh L1 block after the shared bootstrap proposal so tests can
	// immediately submit their own next proposal without tripping Inbox's
	// one-proposal-per-L1-block guard.
	s.L1Mine()

	head, err := s.RPCClient.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Zero(head.Number.Cmp(common.Big1))
}

func (s *ClientTestSuite) insertBaseShastaBlock(
	ctx context.Context,
	anchorBlock *types.Header,
	proposed *shastaBindings.ShastaInboxClientProposed,
) {
	parent, err := s.RPCClient.L2.HeaderByNumber(ctx, common.Big0)
	s.Nil(err)

	baseFee, err := s.RPCClient.CalculateBaseFee(ctx, parent)
	s.Nil(err)

	anchorConstructor, err := anchortxconstructor.New(s.RPCClient)
	s.Nil(err)

	blockID := proposed.Id
	anchorTx, err := anchorConstructor.AssembleAnchorV4Tx(
		ctx,
		parent,
		anchorBlock.Number,
		anchorBlock.Hash(),
		anchorBlock.Root,
		proposed.EndOfSubmissionWindowTimestamp,
		blockID,
		baseFee,
	)
	s.Nil(err)

	txListBytes, err := rlp.EncodeToBytes(types.Transactions{anchorTx})
	s.Nil(err)

	difficulty, err := encoding.CalculateShastaDifficulty(parent.Difficulty, blockID)
	s.Nil(err)

	extraData, err := encoding.EncodeShastaExtraData(proposed.BasefeeSharingPctg, proposed.Id)
	s.Nil(err)

	txListHash := crypto.Keccak256Hash(txListBytes)
	payloadID := (&miner.BuildPayloadArgs{
		Parent:       parent.Hash(),
		Timestamp:    anchorBlock.Time,
		FeeRecipient: common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")),
		Random:       common.BytesToHash(difficulty),
		Withdrawals:  make([]*types.Withdrawal, 0),
		Version:      engine.PayloadV2,
		TxListHash:   &txListHash,
		Extra:        extraData,
	}).Id()

	l1Origin := &rawdb.L1Origin{
		BlockID:            blockID,
		L2BlockHash:        common.Hash{},
		L1BlockHeight:      new(big.Int).SetUint64(proposed.Raw.BlockNumber),
		L1BlockHash:        proposed.Raw.BlockHash,
		BuildPayloadArgsID: payloadID,
	}

	s.forkTo(&engine.PayloadAttributes{
		Timestamp:             anchorBlock.Time,
		Random:                common.BytesToHash(difficulty),
		SuggestedFeeRecipient: common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")),
		Withdrawals:           []*types.Withdrawal{},
		BlockMetadata: &engine.BlockMetadata{
			Beneficiary: common.HexToAddress(os.Getenv("L2_SUGGESTED_FEE_RECIPIENT")),
			GasLimit:    parent.GasLimit + consensus.AnchorV3V4GasLimit,
			Timestamp:   anchorBlock.Time,
			TxList:      txListBytes,
			MixHash:     common.BytesToHash(difficulty),
			BatchID:     proposed.Id,
			ExtraData:   extraData,
		},
		BaseFeePerGas: baseFee,
		L1Origin:      l1Origin,
	}, parent.Hash())

	head, err := s.RPCClient.L2.HeaderByNumber(ctx, blockID)
	s.Nil(err)

	l1Origin.L2BlockHash = head.Hash()
	_, err = s.RPCClient.L2Engine.UpdateL1Origin(ctx, l1Origin)
	s.Nil(err)
	_, err = s.RPCClient.L2Engine.SetHeadL1Origin(ctx, blockID)
	s.Nil(err)
	_, err = s.RPCClient.L2Engine.SetBatchToLastBlock(ctx, proposed.Id, blockID)
	s.Nil(err)
}
