package rpc

import (
	"context"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestGetProposeInputs(t *testing.T) {
	client := newTestClientWithTimeout(t)

	_, err := client.GetShastaProposalInputs(context.Background())

	require.Nil(t, err)
}
