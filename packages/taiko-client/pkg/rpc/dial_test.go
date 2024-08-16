package rpc

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/jwt"
)

func TestDialEngineClientWithBackoff(t *testing.T) {
	jwtSecret, err := jwt.ParseSecretFromFile(os.Getenv("JWT_SECRET"))

	require.Nil(t, err)
	require.NotEmpty(t, jwtSecret)

	client, err := DialEngineClientWithBackoff(
		context.Background(),
		os.Getenv("L2_AUTH"),
		string(jwtSecret),
		12*time.Second,
		10,
	)

	require.Nil(t, err)

	var result engine.ExecutableData
	err = client.CallContext(context.Background(), &result, "engine_getPayloadV1", engine.PayloadID{})

	require.Equal(t, engine.UnsupportedFork.Error(), err.Error())
}

func TestDialClientWithBackoff(t *testing.T) {
	client, err := DialClientWithBackoff(
		context.Background(),
		os.Getenv("L2_WS"),
		12*time.Second,
		10,
	)
	require.Nil(t, err)

	genesis, err := client.HeaderByNumber(context.Background(), common.Big0)
	require.Nil(t, err)

	require.Equal(t, common.Big0.Uint64(), genesis.Number.Uint64())
}

func TestDialClientWithBackoff_CtxError(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	_, err := DialClientWithBackoff(
		ctx,
		"invalid",
		-1,
		10,
	)
	require.NotNil(t, err)
}

func TestDialEngineClientWithBackoff_CtxError(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	jwtSecret, err := jwt.ParseSecretFromFile(os.Getenv("JWT_SECRET"))
	require.Nil(t, err)
	require.NotEmpty(t, jwtSecret)

	_, err2 := DialEngineClientWithBackoff(
		ctx,
		"invalid",
		string(jwtSecret),
		-1,
		10,
	)
	require.NotNil(t, err2)
}
