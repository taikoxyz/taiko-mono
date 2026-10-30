package balanceMonitor

import (
	"context"
	"encoding/json"
	"math/big"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/rpc"
)

type erc20RPCMock struct {
	decimals      uint8
	decimalsCalls int
}

func (*erc20RPCMock) GetCode(_ context.Context, _ common.Address, _ json.RawMessage) (hexutil.Bytes, error) {
	return hexutil.Bytes{1}, nil
}

func (m *erc20RPCMock) Call(_ context.Context, args json.RawMessage, _ json.RawMessage) (hexutil.Bytes, error) {
	var call struct {
		Data  string `json:"data"`
		Input string `json:"input"`
	}
	if err := json.Unmarshal(args, &call); err != nil {
		return nil, err
	}
	if call.Data == "" {
		call.Data = call.Input
	}
	callData, err := hexutil.Decode(call.Data)
	if err != nil {
		return nil, err
	}
	if len(callData) < 4 {
		return nil, nil
	}

	result := new(big.Int)
	switch {
	case len(callData) == 4:
		m.decimalsCalls++
		result.SetUint64(uint64(m.decimals))
	case string(callData[:4]) == string(crypto.Keccak256([]byte("balanceOf(address)"))[:4]):
		result.Exp(big.NewInt(10), new(big.Int).SetUint64(uint64(m.decimals)), nil)
	case string(callData[:4]) == string(crypto.Keccak256([]byte("bondBalanceOf(address)"))[:4]):
		// The mock has no bonded balance.
	default:
		return nil, nil
	}

	return hexutil.Bytes(result.FillBytes(make([]byte, 32))), nil
}

func newERC20RPCClient(t *testing.T, decimals uint8) (*ethclient.Client, *erc20RPCMock) {
	t.Helper()

	server := rpc.NewServer()
	mock := &erc20RPCMock{decimals: decimals}
	if err := server.RegisterName("eth", mock); err != nil {
		t.Fatalf("failed to register mock RPC API: %v", err)
	}
	t.Cleanup(server.Stop)

	rpcClient := rpc.DialInProc(server)
	t.Cleanup(rpcClient.Close)
	return ethclient.NewClient(rpcClient), mock
}

func TestCheckErc20BalanceCachesDecimalsPerChain(t *testing.T) {
	l1Client, l1RPC := newERC20RPCClient(t, 18)
	l2Client, l2RPC := newERC20RPCClient(t, 6)
	t.Cleanup(l1Client.Close)
	t.Cleanup(l2Client.Close)

	b := &BalanceMonitor{erc20DecimalsCache: make(map[tokenDecimalsKey]uint8)}
	tokenAddress := common.HexToAddress("0x00000000000000000000000000000000000000ab")
	holderAddress := common.HexToAddress("0x00000000000000000000000000000000000000cd")

	l1Balance := b.checkErc20Balance(context.Background(), l1Client, "L1", tokenAddress, holderAddress)
	l2Balance := b.checkErc20Balance(context.Background(), l2Client, "L2", tokenAddress, holderAddress)
	if l1Balance != 1 || l2Balance != 1 {
		t.Fatalf("expected normalized balances of 1 on both chains, got L1=%v L2=%v", l1Balance, l2Balance)
	}
	if l1RPC.decimalsCalls != 1 || l2RPC.decimalsCalls != 1 {
		t.Fatalf("expected decimals to be fetched once per chain, got L1=%d L2=%d", l1RPC.decimalsCalls, l2RPC.decimalsCalls)
	}

	// Rechecking each chain should use its own cached value.
	b.checkErc20Balance(context.Background(), l1Client, "L1", tokenAddress, holderAddress)
	b.checkErc20Balance(context.Background(), l2Client, "L2", tokenAddress, holderAddress)
	if l1RPC.decimalsCalls != 1 || l2RPC.decimalsCalls != 1 {
		t.Fatalf("expected cached decimals on subsequent checks, got L1=%d L2=%d", l1RPC.decimalsCalls, l2RPC.decimalsCalls)
	}
}

// TestStartReturnsImmediately proves the fix for the shutdown deadlock: Start
// must return right away and run the check loop in a background goroutine.
//
// Pre-fix, Start ran the loop on the caller's goroutine and only returned once
// the context was cancelled, so the CLI wrapper could never reach its signal
// handling or deferred Close. On the pre-fix code this test times out.
func TestStartReturnsImmediately(t *testing.T) {
	b := &BalanceMonitor{interval: time.Millisecond}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	b.ctx = ctx

	done := make(chan error, 1)
	go func() { done <- b.Start() }()

	select {
	case err := <-done:
		if err != nil {
			t.Fatalf("Start() returned unexpected error: %v", err)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("Start() blocked; it must return immediately and run the loop in a goroutine")
	}
}

// TestCloseWaitsForEventLoop proves the graceful-shutdown half: after Start,
// Close must block until the background loop exits on context cancellation, so
// the RPC clients are not closed while the loop is still using them.
//
// Pre-fix, Close had no WaitGroup and returned immediately, so the "Close must
// not have returned yet" assertion fails against the original code.
func TestCloseWaitsForEventLoop(t *testing.T) {
	b := &BalanceMonitor{interval: time.Millisecond}
	ctx, cancel := context.WithCancel(context.Background())
	b.ctx = ctx

	if err := b.Start(); err != nil {
		t.Fatalf("Start() returned error: %v", err)
	}

	// Close must block while the event loop is still running.
	closed := make(chan struct{})
	go func() {
		b.Close(context.Background())
		close(closed)
	}()

	select {
	case <-closed:
		t.Fatal("Close() returned before the event loop exited; it must wait for the loop")
	case <-time.After(200 * time.Millisecond):
		// Expected: Close is still waiting.
	}

	// Cancelling the context lets the loop exit, after which Close returns.
	cancel()

	select {
	case <-closed:
	case <-time.After(2 * time.Second):
		t.Fatal("Close() blocked after context cancellation; the loop did not exit")
	}
}
