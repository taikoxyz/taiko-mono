package rpc

import (
	"context"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestGetProposeInputProposals(t *testing.T) {
	client := newTestClientWithTimeout(t)

	_, err := client.GetProposeInputProposals(context.Background())

	require.Nil(t, err)
}
