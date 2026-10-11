package indexer

import (
	"context"
	"errors"
	"fmt"
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
	erc20 := mint
	erc20.Topics = append([]common.Hash(nil), mint.Topics[:3]...)
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

func malformedERC1155Logs(t *testing.T) map[string]types.Log {
	t.Helper()

	result := make(map[string]types.Log)

	for _, kind := range []string{"TransferSingle", "TransferBatch"} {
		base := nftIndexLog(t, kind, common.HexToAddress("0x1"), common.HexToAddress("0x2"), 1, 0, 0)
		for _, count := range []int{1, 2, 3, 5} {
			invalid := base
			invalid.Topics = append([]common.Hash(nil), base.Topics...)

			if count < 4 {
				invalid.Topics = invalid.Topics[:count]
			} else {
				invalid.Topics = append(invalid.Topics, common.Hash{})
			}

			result[fmt.Sprintf("%s topics %d", kind, count)] = invalid
		}

		invalid := base
		invalid.Data = []byte{1, 2, 3}
		result[kind+" malformed data"] = invalid
	}

	parsed, err := getParsedERC1155ABI()
	require.NoError(t, err)

	for _, lengths := range [][2]int{{2, 1}, {1, 2}} {
		invalid := nftIndexLog(t, "TransferBatch", common.HexToAddress("0x1"), common.HexToAddress("0x2"), 1, 0, 0)
		ids := []*big.Int{big.NewInt(8), big.NewInt(9)}[:lengths[0]]
		values := []*big.Int{big.NewInt(4), big.NewInt(5)}[:lengths[1]]
		invalid.Data, err = parsed.Events["TransferBatch"].Inputs.NonIndexed().Pack(ids, values)
		require.NoError(t, err)

		result[fmt.Sprintf("batch ids %d values %d", lengths[0], lengths[1])] = invalid
	}

	return result
}

func TestIndexNFTTransfersSkipsMalformedERC1155(t *testing.T) {
	for name, invalid := range malformedERC1155Logs(t) {
		t.Run(name, func(t *testing.T) {
			spy := &nftTransferSpy{}
			idx := &Indexer{nftBalanceRepo: spy}
			later := nftIndexLog(t, "TransferBatch", ZeroAddress, common.HexToAddress("0x2"), 2, 0, 0)
			require.NotPanics(t, func() {
				require.NoError(t, idx.indexNFTTransfers(context.Background(), big.NewInt(167), []types.Log{later, invalid}))
			})
			require.Len(t, spy.calls, 2)

			for n, call := range spy.calls {
				require.Equal(t, nftTransferRef(big.NewInt(167), later, uint(n)), call.ref)
				require.Equal(t, int64(8+n), call.increase.TokenID)
				require.Equal(t, int64(4+n), call.increase.Amount)
			}
		})
	}
}

func TestSaveERC1155TransferSkipsMalformed(t *testing.T) {
	for name, invalid := range malformedERC1155Logs(t) {
		t.Run(name, func(t *testing.T) {
			spy := &nftTransferSpy{}

			require.NotPanics(t, func() {
				require.NoError(t, (&Indexer{nftBalanceRepo: spy}).saveERC1155Transfer(context.Background(), big.NewInt(167), invalid))
			})
			require.Empty(t, spy.calls)
		})
	}
}

func TestSaveERC1155TransferPreservesABISetupError(t *testing.T) {
	valid := nftIndexLog(t, "TransferSingle", ZeroAddress, common.HexToAddress("0x2"), 1, 0, 0)
	originalErr := parsedERC1155ABIErr
	failure := errors.New("static ABI initialization failed")
	parsedERC1155ABIErr = failure

	t.Cleanup(func() { parsedERC1155ABIErr = originalErr })

	spy := &nftTransferSpy{}
	require.ErrorIs(t, (&Indexer{nftBalanceRepo: spy}).saveERC1155Transfer(context.Background(), big.NewInt(167), valid), failure)
	require.Empty(t, spy.calls)
}

func TestSaveERC1155TransferPreservesRepositoryError(t *testing.T) {
	for _, kind := range []string{"TransferSingle", "TransferBatch"} {
		t.Run(kind, func(t *testing.T) {
			valid := nftIndexLog(t, kind, ZeroAddress, common.HexToAddress("0x2"), 1, 0, 0)
			failure := errors.New("repository failed")
			spy := &nftTransferSpy{failure: failure}
			require.ErrorIs(t, (&Indexer{nftBalanceRepo: spy}).saveERC1155Transfer(context.Background(), big.NewInt(167), valid), failure)
			require.Len(t, spy.calls, 1)
		})
	}
}
