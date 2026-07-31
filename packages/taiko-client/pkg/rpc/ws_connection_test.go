package rpc

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/gorilla/websocket"
	"github.com/stretchr/testify/require"
)

type wsRPCRequest struct {
	ID     json.RawMessage `json:"id"`
	Method string          `json:"method"`
}

func TestWebSocketRPCTimeoutReconnects(t *testing.T) {
	var connections atomic.Int32
	firstBlockNumberRead := make(chan struct{})
	upgrader := websocket.Upgrader{CheckOrigin: func(*http.Request) bool { return true }}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			return
		}
		defer conn.Close()

		connection := connections.Add(1)
		for {
			_, data, err := conn.ReadMessage()
			if err != nil {
				return
			}

			var request wsRPCRequest
			if err := json.Unmarshal(data, &request); err != nil {
				return
			}

			var result string
			switch request.Method {
			case "eth_chainId":
				result = "0x1"
			case "eth_blockNumber":
				if connection == 1 {
					// Simulate a half-open connection: reads and writes still succeed,
					// but the server never returns the RPC response.
					close(firstBlockNumberRead)
					continue
				}
				result = "0x2a"
			default:
				continue
			}

			response := struct {
				JSONRPC string          `json:"jsonrpc"`
				ID      json.RawMessage `json:"id"`
				Result  string          `json:"result"`
			}{JSONRPC: "2.0", ID: request.ID, Result: result}
			if err := conn.WriteJSON(response); err != nil {
				return
			}
		}
	}))
	defer server.Close()

	client, err := NewEthClient(
		context.Background(),
		"ws"+strings.TrimPrefix(server.URL, "http"),
		200*time.Millisecond,
	)
	require.NoError(t, err)
	defer client.Close()

	firstCallDone := make(chan error, 1)
	go func() {
		_, err := client.BlockNumber(context.Background())
		firstCallDone <- err
	}()

	select {
	case <-firstBlockNumberRead:
	case <-time.After(time.Second):
		t.Fatal("server did not receive the first eth_blockNumber request")
	}

	err = <-firstCallDone
	require.ErrorIs(t, err, context.DeadlineExceeded)

	blockNumber, err := client.BlockNumber(context.Background())
	require.NoError(t, err)
	require.Equal(t, uint64(42), blockNumber)
	require.Equal(t, int32(2), connections.Load())
}
