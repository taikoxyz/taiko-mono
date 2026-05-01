package rpc

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
	"github.com/stretchr/testify/require"
)

func TestSubscribeEvent(t *testing.T) {
	sub := SubscribeEvent("test", func(_ context.Context) (event.Subscription, error) {
		return event.NewSubscription(func(_ <-chan struct{}) error { return nil }), nil
	})
	require.NotNil(t, sub)
	sub.Unsubscribe()
}

func TestSubscribeChainHead(t *testing.T) {
	client := newTestClient(t)
	sub := SubscribeChainHead(client.L1, make(chan *types.Header, 1024))
	require.NotNil(t, sub)
	sub.Unsubscribe()
}

func TestPollChainHead_DeliversAndStops(t *testing.T) {
	var blockNum atomic.Uint64
	blockNum.Store(100)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		var req struct {
			ID     int    `json:"id"`
			Method string `json:"method"`
		}
		_ = json.Unmarshal(body, &req)
		var result string
		switch req.Method {
		case "eth_chainId":
			result = `"0x1"`
		case "eth_getBlockByNumber":
			n := blockNum.Add(1)
			result = fmt.Sprintf(
				`{"number":"0x%x","hash":"0x%064x","parentHash":"0x%064x","stateRoot":"0x%064x","transactionsRoot":"0x%064x","receiptsRoot":"0x%064x","logsBloom":"0x%0512x","difficulty":"0x0","gasLimit":"0x0","gasUsed":"0x0","timestamp":"0x0","extraData":"0x","mixHash":"0x%064x","nonce":"0x0000000000000000","sha3Uncles":"0x%064x","miner":"0x%040x","size":"0x0","totalDifficulty":"0x0","uncles":[],"transactions":[]}`,
				n, n, n-1, 0, 0, 0, 0, 0, 0, 0,
			)
		default:
			result = `null`
		}
		fmt.Fprintf(w, `{"jsonrpc":"2.0","id":%d,"result":%s}`, req.ID, result)
	}))
	t.Cleanup(srv.Close)

	c, err := NewEthClient(context.Background(), srv.URL, time.Second)
	require.NoError(t, err)
	require.True(t, c.IsHTTP())

	ch := make(chan *types.Header, 4)
	sub := pollChainHead(context.Background(), c, ch, 20*time.Millisecond)

	select {
	case h := <-ch:
		require.NotNil(t, h)
		require.Greater(t, h.Number.Uint64(), uint64(99))
	case <-time.After(2 * time.Second):
		t.Fatal("no header delivered")
	}

	sub.Unsubscribe()
	select {
	case _, ok := <-sub.Err():
		require.False(t, ok, "Err channel must close on Unsubscribe")
	case <-time.After(2 * time.Second):
		t.Fatal("Unsubscribe did not close Err channel")
	}
}
