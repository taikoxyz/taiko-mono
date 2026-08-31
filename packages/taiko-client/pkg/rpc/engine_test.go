package rpc

import (
	"context"
	"os"
	"testing"

	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/stretchr/testify/require"
)

func TestL2EngineForbidden(t *testing.T) {
	c, err := NewJWTEngineClient(os.Getenv("L2_AUTH"), "invalid-jwt-secret")
	require.Nil(t, err)
	require.NotNil(t, c)

	_, err = c.ForkchoiceUpdate(
		context.Background(),
		&engine.ForkchoiceStateV1{},
		&engine.PayloadAttributes{},
	)
	require.ErrorContains(t, err, "Unauthorized")

	_, err = c.NewPayload(
		context.Background(),
		&engine.ExecutableData{},
	)
	require.ErrorContains(t, err, "Unauthorized")

	_, err = c.GetPayload(
		context.Background(),
		&engine.PayloadID{},
	)
	require.ErrorContains(t, err, "Unauthorized")

	_, err = c.ExchangeTransitionConfiguration(context.Background(), &engine.TransitionConfigurationV1{
		TerminalTotalDifficulty: (*hexutil.Big)(common.Big0),
		TerminalBlockHash:       common.Hash{},
		TerminalBlockNumber:     0,
	})
	require.ErrorContains(t, err, "Unauthorized")
}
