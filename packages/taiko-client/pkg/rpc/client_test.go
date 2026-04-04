package rpc

import (
	"context"
	"os"
	"reflect"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/require"
)

func newTestClient(t *testing.T) *Client {
	client, err := NewClient(context.Background(), &ClientConfig{
		L1Endpoint:                  os.Getenv("L1_WS"),
		L2Endpoint:                  os.Getenv("L2_WS"),
		InboxAddress:                common.HexToAddress(os.Getenv("INBOX")),
		TaikoWrapperAddress:         common.HexToAddress(os.Getenv("TAIKO_WRAPPER")),
		ForcedInclusionStoreAddress: common.HexToAddress(os.Getenv("FORCED_INCLUSION_STORE")),
		TaikoAnchorAddress:          common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		L2EngineEndpoint:            os.Getenv("L2_AUTH"),
		JwtSecret:                   os.Getenv("JWT_SECRET"),
	})

	require.Nil(t, err)
	require.NotNil(t, client)
	t.Cleanup(func() { closeTestClient(client) })

	return client
}

func TestNewClientShastaOnlyConfig(t *testing.T) {
	_, ok := reflect.TypeOf(ClientConfig{}).FieldByName("InboxAddress")
	require.True(t, ok)
}

func newTestClientWithTimeout(t *testing.T) *Client {
	client, err := NewClient(context.Background(), &ClientConfig{
		L1Endpoint:                  os.Getenv("L1_WS"),
		L2Endpoint:                  os.Getenv("L2_WS"),
		InboxAddress:                common.HexToAddress(os.Getenv("INBOX")),
		TaikoWrapperAddress:         common.HexToAddress(os.Getenv("TAIKO_WRAPPER")),
		ForcedInclusionStoreAddress: common.HexToAddress(os.Getenv("FORCED_INCLUSION_STORE")),
		TaikoAnchorAddress:          common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		L2EngineEndpoint:            os.Getenv("L2_AUTH"),
		JwtSecret:                   os.Getenv("JWT_SECRET"),
		Timeout:                     5 * time.Second,
	})
	require.Nil(t, err)
	require.NotNil(t, client)
	t.Cleanup(func() { closeTestClient(client) })

	return client
}

func closeTestClient(client *Client) {
	if client == nil {
		return
	}
	if client.L1 != nil {
		client.L1.Close()
	}
	if client.L2 != nil {
		client.L2.Close()
	}
	if client.L2CheckPoint != nil {
		client.L2CheckPoint.Close()
	}
	if client.L2Engine != nil {
		client.L2Engine.Close()
	}
}
