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

	return client
}
