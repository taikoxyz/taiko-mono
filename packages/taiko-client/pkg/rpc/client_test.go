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
		L1Endpoint:                  os.Getenv("L1_HTTP"),
		L2Endpoint:                  os.Getenv("L2_WS"),
		PacayaInboxAddress:          common.HexToAddress(os.Getenv("PACAYA_INBOX")),
		ShastaInboxAddress:          common.HexToAddress(os.Getenv("SHASTA_INBOX")),
		TaikoWrapperAddress:         common.HexToAddress(os.Getenv("TAIKO_WRAPPER")),
		ForcedInclusionStoreAddress: common.HexToAddress(os.Getenv("FORCED_INCLUSION_STORE")),
		ProverSetAddress:            common.HexToAddress(os.Getenv("PROVER_SET")),
		TaikoAnchorAddress:          common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		TaikoTokenAddress:           common.HexToAddress(os.Getenv("TAIKO_TOKEN")),
		L2EngineEndpoint:            os.Getenv("L2_AUTH"),
		JwtSecret:                   os.Getenv("JWT_SECRET"),
	})

	require.Nil(t, err)
	require.NotNil(t, client)

	return client
}

func newTestClientWithTimeout(t *testing.T) *Client {
	client, err := NewClient(context.Background(), &ClientConfig{
		L1Endpoint:                  os.Getenv("L1_HTTP"),
		L2Endpoint:                  os.Getenv("L2_WS"),
		PacayaInboxAddress:          common.HexToAddress(os.Getenv("PACAYA_INBOX")),
		ShastaInboxAddress:          common.HexToAddress(os.Getenv("SHASTA_INBOX")),
		TaikoWrapperAddress:         common.HexToAddress(os.Getenv("TAIKO_WRAPPER")),
		ForcedInclusionStoreAddress: common.HexToAddress(os.Getenv("FORCED_INCLUSION_STORE")),
		ProverSetAddress:            common.HexToAddress(os.Getenv("PROVER_SET")),
		TaikoAnchorAddress:          common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		TaikoTokenAddress:           common.HexToAddress(os.Getenv("TAIKO_TOKEN")),
		L2EngineEndpoint:            os.Getenv("L2_AUTH"),
		JwtSecret:                   os.Getenv("JWT_SECRET"),
		Timeout:                     5 * time.Second,
	})
	require.Nil(t, err)
	require.NotNil(t, client)

	return client
}
