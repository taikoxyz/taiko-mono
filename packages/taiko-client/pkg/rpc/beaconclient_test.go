package rpc

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestBeaconClient(t *testing.T) {
	client, err := NewBeaconClient("https://eth2-beacon-mainnet.nodereal.io/v1/9eac528e9a82485dbeeddb7eaa2bfa3b/", time.Second*30)
	assert.NoError(t, err)

	_, err = client.GetBlobs(context.Background(), 1)
	assert.NoError(t, err)
}
