package rpc

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/require"
)

func newTestClient(t *testing.T) *Client {
	client, err := NewClient(context.Background(), &ClientConfig{
		L1Endpoint:        os.Getenv("L1_WS"),
		L2Endpoint:        os.Getenv("L2_WS"),
		TaikoL1Address:    common.HexToAddress(os.Getenv("TAIKO_L1")),
		TaikoL2Address:    common.HexToAddress(os.Getenv("TAIKO_L2")),
		TaikoTokenAddress: common.HexToAddress(os.Getenv("TAIKO_TOKEN")),
		L2EngineEndpoint:  os.Getenv("L2_AUTH"),
		JwtSecret:         os.Getenv("JWT_SECRET"),
	})

	require.Nil(t, err)
	require.NotNil(t, client)

	return client
}

func newTestClientWithTimeout(t *testing.T) *Client {
	client, err := NewClient(context.Background(), &ClientConfig{
		L1Endpoint:        os.Getenv("L1_WS"),
		L2Endpoint:        os.Getenv("L2_WS"),
		TaikoL1Address:    common.HexToAddress(os.Getenv("TAIKO_L1")),
		TaikoL2Address:    common.HexToAddress(os.Getenv("TAIKO_L2")),
		TaikoTokenAddress: common.HexToAddress(os.Getenv("TAIKO_TOKEN")),
		L2EngineEndpoint:  os.Getenv("L2_AUTH"),
		JwtSecret:         os.Getenv("JWT_SECRET"),
		Timeout:           5 * time.Second,
	})

	require.Nil(t, err)
	require.NotNil(t, client)

	return client
}
