package indexer

import (
	"context"
	"errors"
	"math/big"
	"sync"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

func TestIsERC20Transfer(t *testing.T) {
	token := common.HexToAddress("0x73FaC9201494f0bd17B9892B9fae4d52fe3BD377")
	from := common.BytesToHash(common.HexToAddress("0x1").Bytes())
	to := common.BytesToHash(common.HexToAddress("0x2").Bytes())
	tokenID := common.BigToHash(common.Big1)

	tests := []struct {
		name string
		log  types.Log
		want bool
	}{
		{
			name: "token transfer",
			log:  types.Log{Address: token, Topics: []common.Hash{logTransferSigHash, from, to}},
			want: true,
		},
		{
			// EIP-7708 ETH transfer logs share the ERC20 Transfer signature and topic count,
			// but the system address has no code to answer symbol() or decimals().
			name: "eip-7708 eth transfer",
			log:  types.Log{Address: params.SystemAddress, Topics: []common.Hash{logTransferSigHash, from, to}},
			want: false,
		},
		{
			name: "nft transfer",
			log:  types.Log{Address: token, Topics: []common.Hash{logTransferSigHash, from, to, tokenID}},
			want: false,
		},
		{
			name: "other event",
			log:  types.Log{Address: token, Topics: []common.Hash{common.HexToHash("0x1234"), from, to}},
			want: false,
		},
		{
			name: "no topics",
			log:  types.Log{Address: token},
			want: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.want, (&Indexer{}).isERC20Transfer(context.Background(), tt.log))
		})
	}
}

// The spy records repository applications, without duplicating balance arithmetic.
type erc20TransferSpy struct {
	eventindexer.ERC20BalanceRepository
	mu       sync.Mutex
	calls    []erc20TransferCall
	failHash string
	failure  error
	cancel   context.CancelFunc
}

type erc20TransferCall struct {
	ref      eventindexer.TransferLogRef
	increase eventindexer.UpdateERC20BalanceOpts
	decrease eventindexer.UpdateERC20BalanceOpts
}

func (s *erc20TransferSpy) IncreaseAndDecreaseBalancesInTx(
	_ context.Context, ref eventindexer.TransferLogRef,
	increase, decrease eventindexer.UpdateERC20BalanceOpts,
) (*eventindexer.ERC20Balance, *eventindexer.ERC20Balance, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.calls = append(s.calls, erc20TransferCall{ref, increase, decrease})

	if s.cancel != nil {
		s.cancel()
	}

	if ref.TxHash == s.failHash {
		return nil, nil, s.failure
	}

	return nil, nil, nil
}

func erc20IndexFixture(spy *erc20TransferSpy) (*Indexer, common.Address) {
	token := common.HexToAddress("0x1234")

	return &Indexer{
		contractToMetadataMutex: &sync.Mutex{},
		erc20BalanceRepo:        spy,
		contractToMetadata:      map[common.Address]*eventindexer.ERC20Metadata{token: {ID: 1}},
	}, token
}

func erc20IndexLog(token, from, to common.Address, block uint64, tx, index uint) types.Log {
	return types.Log{
		Address: token, BlockNumber: block, TxIndex: tx, Index: index,
		TxHash: common.BigToHash(new(big.Int).SetUint64(block*100 + uint64(tx))),
		Topics: []common.Hash{logTransferSigHash, common.BytesToHash(from.Bytes()), common.BytesToHash(to.Bytes())},
		Data:   common.LeftPadBytes(big.NewInt(10).Bytes(), 32),
	}
}

func TestIndexERC20TransfersOrderAndFiltering(t *testing.T) {
	spy := &erc20TransferSpy{}
	idx, token := erc20IndexFixture(spy)
	alice, bob := common.HexToAddress("0x1"), common.HexToAddress("0x2")
	mint := erc20IndexLog(token, ZeroAddress, alice, 1, 0, 0)
	outgoing := erc20IndexLog(token, alice, bob, 1, 0, 1)
	nextTx := erc20IndexLog(token, alice, bob, 1, 1, 0)
	nextBlock := erc20IndexLog(token, alice, bob, 2, 0, 0)
	nft := mint
	nft.Topics = append(append([]common.Hash(nil), mint.Topics...), common.Hash{})
	other := mint
	other.Topics = []common.Hash{common.HexToHash("0xff")}
	system := mint
	system.Address = params.SystemAddress
	logs := []types.Log{nextBlock, nextTx, outgoing, nft, other, system, {}, mint}
	original := append([]types.Log(nil), logs...)
	require.NoError(t, idx.indexERC20Transfers(context.Background(), big.NewInt(167), logs))
	require.Equal(t, original, logs, "the caller's slice may be shared with NFT indexing")
	require.Len(t, spy.calls, 4)

	for n, log := range []types.Log{mint, outgoing, nextTx, nextBlock} {
		require.Equal(t, eventindexer.TransferLogRef{
			ChainID: 167, TxHash: log.TxHash.Hex(), LogIndex: log.Index, Kind: eventindexer.TransferKindERC20,
		}, spy.calls[n].ref)
	}

	require.Empty(t, spy.calls[0].decrease)
	require.Equal(t, alice.Hex(), spy.calls[0].increase.Address)
	require.Equal(t, alice.Hex(), spy.calls[1].decrease.Address)
	require.Equal(t, bob.Hex(), spy.calls[1].increase.Address)
	require.Equal(t, "10", spy.calls[1].decrease.Amount)
}

func TestIndexERC20TransfersStopsOnError(t *testing.T) {
	failure := errors.New("repository failed")
	spy := &erc20TransferSpy{failure: failure}
	idx, token := erc20IndexFixture(spy)
	first := erc20IndexLog(token, ZeroAddress, common.HexToAddress("0x1"), 1, 0, 0)
	later := erc20IndexLog(token, ZeroAddress, common.HexToAddress("0x1"), 2, 0, 0)
	spy.failHash = first.TxHash.Hex()
	// The spy intentionally accepts cancelled contexts: launching the later save
	// is itself a failure, regardless of goroutine scheduling or repository guards.
	require.ErrorIs(t, idx.indexERC20Transfers(context.Background(), big.NewInt(167), []types.Log{later, first}), failure)
	require.Len(t, spy.calls, 1)
	require.Equal(t, first.TxHash.Hex(), spy.calls[0].ref.TxHash)
}

func TestIndexERC20TransfersCancellation(t *testing.T) {
	for _, preCancelled := range []bool{true, false} {
		t.Run(map[bool]string{true: "before first log", false: "between logs"}[preCancelled], func(t *testing.T) {
			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()
			spy := &erc20TransferSpy{cancel: cancel}
			idx, token := erc20IndexFixture(spy)
			first := erc20IndexLog(token, ZeroAddress, common.HexToAddress("0x1"), 1, 0, 0)
			later := erc20IndexLog(token, ZeroAddress, common.HexToAddress("0x1"), 2, 0, 0)
			wantCalls := 1

			if preCancelled {
				cancel()

				wantCalls = 0
			}

			require.ErrorIs(t, idx.indexERC20Transfers(ctx, big.NewInt(167), []types.Log{first, later}), context.Canceled)
			require.Len(t, spy.calls, wantCalls)
		})
	}
}
