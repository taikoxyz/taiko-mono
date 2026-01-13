package testutils

import (
	"context"
	"crypto/ecdsa"
	"crypto/rand"
	"math/big"
	"os"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	consensus "github.com/ethereum/go-ethereum/consensus/taiko"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/params"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/phayes/freeport"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	anchortxconstructor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/anchor_tx_constructor"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
)

func (s *ClientTestSuite) proposeEmptyBlockOp(ctx context.Context, proposer Proposer) {
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
	sink1 := make(chan *pacayaBindings.TaikoInboxClientBatchProposed)
	sink2 := make(chan *shastaBindings.ShastaInboxClientProposed)
	sub1, err := s.RPCClient.PacayaClients.TaikoInbox.WatchBatchProposed(nil, sink1)
	s.Nil(err)
	sub2, err := s.RPCClient.ShastaClients.Inbox.WatchProposed(nil, sink2, nil, nil)
	s.Nil(err)

	defer func() {
		sub1.Unsubscribe()
		close(sink1)
		sub2.Unsubscribe()
		close(sink2)
	}()

	// RLP encoded empty list
	s.InitShastaGenesisProposal()
	s.Nil(proposer.ProposeTxLists(context.Background(), []types.Transactions{{}}))
	s.Nil(chainSyncer.ProcessL1Blocks(context.Background()))

	// Valid transactions lists.
	s.InitShastaGenesisProposal()
	s.ProposeValidBlock(proposer)
	s.Nil(chainSyncer.ProcessL1Blocks(context.Background()))

	// Random bytes txList
	s.InitShastaGenesisProposal()
	s.proposeEmptyBlockOp(context.Background(), proposer)
	s.Nil(chainSyncer.ProcessL1Blocks(context.Background()))

	var txHash common.Hash
	for i := 0; i < 3; i++ {
		select {
		case event := <-sink1:
			metadataList = append(metadataList, metadata.NewTaikoDataBlockMetadataPacaya(event))
			txHash = event.Raw.TxHash
		case event := <-sink2:
			header, err := s.RPCClient.L1.HeaderByHash(context.Background(), event.Raw.BlockHash)
			s.Nil(err)
			meta := metadata.NewTaikoProposalMetadataShasta(event, header.Time)
			metadataList = append(metadataList, meta)
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
	sink2 := make(chan *shastaBindings.ShastaInboxClientProposed)
	sub2, err := s.RPCClient.ShastaClients.Inbox.WatchProposed(nil, sink2, nil, nil)
	s.Nil(err)

	defer func() {
		sub1.Unsubscribe()
		close(sink1)
		sub2.Unsubscribe()
		close(sink2)
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

	s.InitShastaGenesisProposal()
	s.Nil(proposer.ProposeOp(context.Background()))

	var (
		meta   metadata.TaikoProposalMetaData
		txHash common.Hash
	)
	select {
	case event := <-sink1:
		meta = metadata.NewTaikoDataBlockMetadataPacaya(event)
		txHash = event.Raw.TxHash
	case event := <-sink2:
		header, err := s.RPCClient.L1.HeaderByHash(context.Background(), event.Raw.BlockHash)
		s.Nil(err)
		meta = metadata.NewTaikoProposalMetadataShasta(event, header.Time)
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
	sink2 := make(chan *shastaBindings.ShastaInboxClientProposed)
	sub1, err := s.RPCClient.PacayaClients.TaikoInbox.WatchBatchProposed(nil, sink1)
	s.Nil(err)
	sub2, err := s.RPCClient.ShastaClients.Inbox.WatchProposed(nil, sink2, nil, nil)
	s.Nil(err)

	defer func() {
		sub1.Unsubscribe()
		close(sink1)
		sub2.Unsubscribe()
		close(sink2)
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

	s.InitShastaGenesisProposal()
	s.Nil(proposer.ProposeOp(context.Background()))

	var (
		txHash common.Hash
	)
	select {
	case event := <-sink1:
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

func (s *ClientTestSuite) ForkIntoShasta(proposer Proposer, chainSyncer ChainSyncer) {
	defer s.L1Mine()
	head, err := s.RPCClient.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	// Already forked into Shasta (timestamp-based).
	if head.Time >= s.RPCClient.ShastaClients.ForkTime {
		log.Debug("Already forked into Shasta")
		s.InitShastaGenesisProposal()
		return
	}

	s.SetNextBlockTimestamp(s.RPCClient.ShastaClients.ForkTime)
	s.L1Mine()

	s.InitShastaGenesisProposal()
	s.Nil(proposer.ProposeTxLists(context.Background(), []types.Transactions{{}}))
	s.Nil(chainSyncer.ProcessL1Blocks(context.Background()))

	headBlock, err := s.RPCClient.L2.BlockByNumber(context.Background(), nil)
	s.Nil(err)
	s.GreaterOrEqual(1, len(headBlock.Transactions()))
}

func (s *ClientTestSuite) InitShastaGenesisProposal() {
	var (
		txMgr = s.TxMgr("initShastaGenesisProposal", s.KeyFromEnv("L1_CONTRACT_OWNER_PRIVATE_KEY"))
		inbox = common.HexToAddress(os.Getenv("SHASTA_INBOX"))
	)
	l1Head, err := s.RPCClient.L1.HeaderByNumber(context.Background(), nil)
	s.Nil(err)

	if l1Head.Time >= s.RPCClient.ShastaClients.ForkTime {
		proposalHash, err := s.RPCClient.ShastaClients.Inbox.GetProposalHash(nil, common.Big0)
		s.Nil(err)
		if proposalHash != (common.Hash{}) {
			return
		}
		l2Head, err := s.RPCClient.L2.HeaderByNumber(context.Background(), nil)
		s.Nil(err)

		data, err := encoding.ShastaInboxABI.Pack("activate", l2Head.Hash())
		s.Nil(err)
		_, err = txMgr.Send(context.Background(), txmgr.TxCandidate{TxData: data, To: &inbox})
		s.Nil(err)
		return
	}
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
	// Propose an empty block at genesis.
	t := s.TxMgr("proposer", key)
	inbox := common.HexToAddress(os.Getenv("PROVER_SET"))
	params := &encoding.BatchParams{
		Proposer:   crypto.PubkeyToAddress(key.PublicKey),
		Coinbase:   common.HexToAddress(RandomHash().Hex()),
		BlobParams: encoding.BlobParams{ByteOffset: 0, ByteSize: 0},
		Blocks: []pacayaBindings.ITaikoInboxBlockParams{{
			NumTransactions: 0,
			TimeShift:       0,
			SignalSlots:     make([][32]byte, 0),
		}},
	}
	encoded, err := encoding.EncodeBatchParamsWithForcedInclusion(nil, params)
	s.Nil(err)

	emptyTxlistBytes, err := utils.EncodeAndCompressTxList(types.Transactions{})
	s.Nil(err)

	data, err := encoding.TaikoInboxABI.Pack("proposeBatch", encoded, emptyTxlistBytes)
	s.Nil(err)

	sink := make(chan *pacayaBindings.TaikoInboxClientBatchProposed, 1)
	sub, err := s.RPCClient.PacayaClients.TaikoInbox.WatchBatchProposed(nil, sink)
	s.Nil(err)
	defer func() {
		sub.Unsubscribe()
		close(sink)
	}()
	_, err = t.Send(
		context.Background(),
		txmgr.TxCandidate{TxData: data, To: &inbox, Blobs: nil, GasLimit: 1_000_000},
	)
	s.Nil(encoding.TryParsingCustomError(err))
	e := <-sink
	s.NotNil(e)

	// After received the event, we start building the payload.
	difficulty, err := encoding.CalculatePacayaDifficulty(new(big.Int).SetUint64(e.Info.LastBlockId))
	s.Nil(err)

	parent, err := s.RPCClient.L2.HeaderByNumber(
		context.Background(),
		new(big.Int).Sub(new(big.Int).SetUint64(e.Info.LastBlockId), common.Big1),
	)
	s.Nil(err)

	baseFee, err := s.RPCClient.CalculateBaseFeePacaya(
		context.Background(), parent, e.Info.LastBlockTimestamp, &e.Info.BaseFeeConfig,
	)
	s.Nil(err)

	anchorBlock, err := s.RPCClient.L1.HeaderByNumber(context.Background(), new(big.Int).SetUint64(e.Info.AnchorBlockId))
	s.Nil(err)

	anchorTxConstructor, err := anchortxconstructor.New(s.RPCClient)
	s.Nil(err)
	anchor, err := anchorTxConstructor.AssembleAnchorV3Tx(
		context.Background(),
		anchorBlock.Number,
		anchorBlock.Root,
		parent,
		&e.Info.BaseFeeConfig,
		[][32]byte{},
		new(big.Int).SetUint64(e.Info.LastBlockId),
		baseFee,
	)
	s.Nil(err)

	txListBytes, err := rlp.EncodeToBytes(types.Transactions{anchor})
	s.Nil(err)

	// Call engine APIs to insert the base block.
	s.forkTo(&engine.PayloadAttributes{
		Timestamp:             e.Info.LastBlockTimestamp,
		Random:                common.BytesToHash(difficulty),
		SuggestedFeeRecipient: e.Info.Coinbase,
		Withdrawals:           []*types.Withdrawal{},
		BlockMetadata: &engine.BlockMetadata{
			Beneficiary: e.Info.Coinbase,
			GasLimit:    uint64(e.Info.GasLimit) + consensus.AnchorV3V4GasLimit,
			Timestamp:   e.Info.LastBlockTimestamp,
			TxList:      txListBytes,
			MixHash:     common.Hash(difficulty),
			ExtraData:   e.Info.ExtraData[:],
		},
		BaseFeePerGas: baseFee,
		L1Origin: &rawdb.L1Origin{
			BlockID:            new(big.Int).SetUint64(e.Info.LastBlockId),
			L1BlockHeight:      new(big.Int).SetUint64(e.Raw.BlockNumber),
			L2BlockHash:        common.Hash{},
			L1BlockHash:        e.Raw.BlockHash,
			BuildPayloadArgsID: [8]byte{},
		},
	}, parent.Hash())

	head, err := s.RPCClient.L2.HeaderByNumber(context.Background(), nil)
	s.Nil(err)
	s.Equal(common.Big1, head.Number)
}
