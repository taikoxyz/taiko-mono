package indexer

import (
	"context"
	"errors"
	"math/big"
	"runtime"
	"sync"
	"sync/atomic"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/require"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

type nftTransferCall struct {
	ref                eventindexer.TransferLogRef
	increase, decrease eventindexer.UpdateNFTBalanceOpts
}

type nftTransferSpy struct {
	eventindexer.NFTBalanceRepository
	inFlight, maxActive atomic.Int32
	mu                  sync.Mutex
	calls               []nftTransferCall
	failure             error
	cancel              context.CancelFunc
}

func (s *nftTransferSpy) IncreaseAndDecreaseBalancesInTx(
	_ context.Context, ref eventindexer.TransferLogRef, increase, decrease eventindexer.UpdateNFTBalanceOpts,
) (*eventindexer.NFTBalance, *eventindexer.NFTBalance, error) {
	active := s.inFlight.Add(1)
	defer s.inFlight.Add(-1)

	for old := s.maxActive.Load(); active > old; old = s.maxActive.Load() {
		if s.maxActive.CompareAndSwap(old, active) {
			break
		}
	}
	// Yield before recording so the recording mutex cannot conceal overlapping calls.
	for n := 0; n < 100; n++ {
		runtime.Gosched()
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	s.calls = append(s.calls, nftTransferCall{ref, increase, decrease})

	if s.cancel != nil {
		s.cancel()
	}

	return nil, nil, s.failure
}

func nftIndexLog(t *testing.T, kind string, from, to common.Address, block uint64, tx, index uint) types.Log {
	t.Helper()

	l := types.Log{Address: common.HexToAddress("0x1234"), BlockNumber: block, TxIndex: tx, Index: index,
		TxHash: common.BigToHash(new(big.Int).SetUint64(block*100 + uint64(tx)))}

	if kind == "ERC721" {
		l.Topics = []common.Hash{logTransferSigHash, common.BytesToHash(from.Bytes()), common.BytesToHash(to.Bytes()), common.BigToHash(big.NewInt(7))}
		return l
	}

	parsed, err := getParsedERC1155ABI()
	require.NoError(t, err)

	l.Topics = []common.Hash{parsed.Events[kind].ID, {}, common.BytesToHash(from.Bytes()), common.BytesToHash(to.Bytes())}

	if kind == "TransferSingle" {
		l.Data, err = parsed.Events[kind].Inputs.NonIndexed().Pack(big.NewInt(7), big.NewInt(3))
	} else {
		l.Data, err = parsed.Events[kind].Inputs.NonIndexed().Pack([]*big.Int{big.NewInt(8), big.NewInt(9)}, []*big.Int{big.NewInt(4), big.NewInt(5)})
	}

	require.NoError(t, err)

	return l
}

func TestIndexNFTTransfersOrderAndFiltering(t *testing.T) {
	spy := &nftTransferSpy{}
	idx := &Indexer{nftBalanceRepo: spy}
	alice, bob := common.HexToAddress("0x1"), common.HexToAddress("0x2")
	mint := nftIndexLog(t, "ERC721", ZeroAddress, alice, 1, 0, 0)
	outgoing := nftIndexLog(t, "ERC721", alice, bob, 1, 0, 1)
	single := nftIndexLog(t, "TransferSingle", ZeroAddress, alice, 1, 1, 0)
	batch := nftIndexLog(t, "TransferBatch", alice, bob, 2, 0, 0)
	// Identical ordering tuples retain caller order even when transaction hashes differ.
	tied := batch
	tied.TxHash = common.HexToHash("0x9999")
	erc20 := erc20IndexLog(mint.Address, ZeroAddress, alice, 1, 0, 0)
	logs := []types.Log{batch, tied, single, outgoing, erc20, {}, {Topics: []common.Hash{common.HexToHash("0xff")}}, mint}
	original := append([]types.Log(nil), logs...)
	require.NoError(t, idx.indexNFTTransfers(context.Background(), big.NewInt(167), logs))
	require.Equal(t, original, logs)
	require.Len(t, spy.calls, 7)
	require.Equal(t, int32(1), spy.maxActive.Load())

	expected := []types.Log{mint, outgoing, single, batch, batch, tied, tied}
	batchIndexes := []uint{0, 0, 0, 0, 1, 0, 1}

	for n, l := range expected {
		require.Equal(t, nftTransferRef(big.NewInt(167), l, batchIndexes[n]), spy.calls[n].ref)
	}

	require.Empty(t, spy.calls[0].decrease)
	require.Equal(t, alice.Hex(), spy.calls[0].increase.Address)
	require.Equal(t, int64(7), spy.calls[0].increase.TokenID)
	require.Equal(t, "ERC721", spy.calls[0].increase.ContractType)
	require.Equal(t, alice.Hex(), spy.calls[1].decrease.Address)
	require.Equal(t, bob.Hex(), spy.calls[1].increase.Address)
	require.Equal(t, "ERC1155", spy.calls[2].increase.ContractType)
	require.Empty(t, spy.calls[2].decrease)
	require.Equal(t, int64(3), spy.calls[2].increase.Amount)
	require.Equal(t, int64(8), spy.calls[3].increase.TokenID)
	require.Equal(t, int64(4), spy.calls[3].decrease.Amount)
	require.Equal(t, int64(9), spy.calls[4].increase.TokenID)
	require.Equal(t, int64(5), spy.calls[4].increase.Amount)
}

func TestIndexNFTTransfersStopsOnError(t *testing.T) {
	failure := errors.New("repository failed")
	spy := &nftTransferSpy{failure: failure}
	first := nftIndexLog(t, "TransferBatch", ZeroAddress, common.HexToAddress("0x1"), 1, 0, 0)
	later := nftIndexLog(t, "ERC721", ZeroAddress, common.HexToAddress("0x1"), 2, 0, 0)
	err := (&Indexer{nftBalanceRepo: spy}).indexNFTTransfers(context.Background(), big.NewInt(167), []types.Log{later, first})
	require.ErrorIs(t, err, failure)
	require.Contains(t, err.Error(), "i.saveNFTTransfer")
	require.Len(t, spy.calls, 1)
	require.Equal(t, nftTransferRef(big.NewInt(167), first, 0), spy.calls[0].ref)
}

func TestIndexNFTTransfersCancellation(t *testing.T) {
	for _, preCancelled := range []bool{true, false} {
		t.Run(map[bool]string{true: "before first log", false: "between logs"}[preCancelled], func(t *testing.T) {
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			spy := &nftTransferSpy{cancel: cancel}
			first := nftIndexLog(t, "ERC721", ZeroAddress, common.HexToAddress("0x1"), 1, 0, 0)
			later := nftIndexLog(t, "TransferSingle", ZeroAddress, common.HexToAddress("0x1"), 2, 0, 0)
			want := 1

			if preCancelled {
				cancel()

				want = 0
			}

			require.ErrorIs(t, (&Indexer{nftBalanceRepo: spy}).indexNFTTransfers(ctx, big.NewInt(167), []types.Log{first, later}), context.Canceled)
			require.Len(t, spy.calls, want)
		})
	}
}
