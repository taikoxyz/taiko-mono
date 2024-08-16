package rpc

import (
	"context"
	"net/url"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/require"
)

func TestGetBlobsFromBlobScan(t *testing.T) {
	blobScanEndpoint, err := url.Parse("https://api.holesky.blobscan.com")
	require.Nil(t, err)
	require.NotNil(t, blobScanEndpoint)
	ds := NewBlobDataSource(
		context.Background(),
		&Client{},
		blobScanEndpoint,
		nil,
	)
	sidecars, err := ds.GetBlobs(
		context.Background(),
		0,
		common.HexToHash("0x0145185449c57dee4e6c921b702e5d572fbeb026f96c220a6a17b79d157d921b"),
	)
	require.Nil(t, err)
	require.NotNil(t, sidecars)
	require.NotNil(t, sidecars[0].Blob)
}
