package rpc

import (
	"context"
	"encoding/json"
	"fmt"
	"math/big"
	"strings"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/require"
)

// fakeL1 serves eth_chainId plus eth_getBlockByHash / eth_getBlockByNumber from the given header JSON
// bodies (an unknown hash or number answers null, i.e. not found).
func newFakeL1(t *testing.T, byHash map[common.Hash]string, byNumber map[uint64]string) *Client {
	t.Helper()
	url, _ := newFakeRPCServerFunc(t, func(method string, params []json.RawMessage) string {
		switch method {
		case "eth_chainId":
			return `"0x1"`
		case "eth_getBlockByHash":
			var hash common.Hash
			require.NoError(t, json.Unmarshal(params[0], &hash))
			if body, ok := byHash[hash]; ok {
				return body
			}
		case "eth_getBlockByNumber":
			var number string
			require.NoError(t, json.Unmarshal(params[0], &number))
			var n uint64
			_, err := fmt.Sscanf(number, "0x%x", &n)
			require.NoError(t, err)
			if body, ok := byNumber[n]; ok {
				return body
			}
		}
		return "null"
	})

	l1, err := NewEthClient(context.Background(), url, time.Second)
	require.NoError(t, err)
	return &Client{L1: l1}
}

// decodedHeaderHash returns the hash go-ethereum computes for a header JSON body.
func decodedHeaderHash(t *testing.T, body string) common.Hash {
	t.Helper()
	var header types.Header
	require.NoError(t, json.Unmarshal([]byte(body), &header))
	return header.Hash()
}

func TestEtnaAnchorBlockNumber_GenesisIsZero(t *testing.T) {
	n, err := (&Client{}).EtnaAnchorBlockNumber(context.Background(), &types.Header{Number: big.NewInt(0)})
	require.NoError(t, err)
	require.Zero(t, n)
}

func TestEtnaAnchorHeader_RequiresRoot(t *testing.T) {
	_, err := (&Client{}).EtnaAnchorHeader(context.Background(), &types.Header{Number: big.NewInt(5)})
	require.ErrorContains(t, err, "missing L1 anchor block hash")

	zero := common.Hash{}
	_, err = (&Client{}).EtnaAnchorHeader(
		context.Background(),
		&types.Header{Number: big.NewInt(5), ParentBeaconRoot: &zero},
	)
	require.ErrorContains(t, err, "missing L1 anchor block hash")
}

func TestEtnaAnchorBlockNumber_ResolvesRootOnL1(t *testing.T) {
	anchorBody := fakeHeaderJSON(77)
	root := decodedHeaderHash(t, anchorBody)
	c := newFakeL1(t, map[common.Hash]string{root: anchorBody}, nil)

	n, err := c.EtnaAnchorBlockNumber(context.Background(), &types.Header{Number: big.NewInt(5), ParentBeaconRoot: &root})
	require.NoError(t, err)
	require.Equal(t, uint64(77), n)
}

func TestEtnaAnchorBlockNumber_UnknownRootIsNotFound(t *testing.T) {
	c := newFakeL1(t, nil, nil)
	root := common.HexToHash("0xab")

	_, err := c.EtnaAnchorBlockNumber(context.Background(), &types.Header{Number: big.NewInt(5), ParentBeaconRoot: &root})
	require.Error(t, err)
	require.True(t, strings.Contains(err.Error(), "not found"))
}

func TestIsEtnaAnchorReorged(t *testing.T) {
	anchorBody := fakeHeaderJSON(77)
	root := decodedHeaderHash(t, anchorBody)
	replacedBody := strings.Replace(anchorBody, `"extraData":"0x"`, `"extraData":"0x01"`, 1)
	header := &types.Header{Number: big.NewInt(5), ParentBeaconRoot: &root}

	// The anchor block is still canonical at its height.
	c := newFakeL1(t, map[common.Hash]string{root: anchorBody}, map[uint64]string{77: anchorBody})
	reorged, err := c.isEtnaAnchorReorged(context.Background(), header)
	require.NoError(t, err)
	require.False(t, reorged)

	// Another block replaced the anchor block at its height.
	c = newFakeL1(t, map[common.Hash]string{root: anchorBody}, map[uint64]string{77: replacedBody})
	reorged, err = c.isEtnaAnchorReorged(context.Background(), header)
	require.NoError(t, err)
	require.True(t, reorged)

	// The L1 node no longer knows the anchor block.
	c = newFakeL1(t, nil, nil)
	reorged, err = c.isEtnaAnchorReorged(context.Background(), header)
	require.NoError(t, err)
	require.True(t, reorged)

	// A missing root is an error, not a reorg.
	_, err = c.isEtnaAnchorReorged(context.Background(), &types.Header{Number: big.NewInt(5)})
	require.ErrorContains(t, err, "missing L1 anchor block hash")
}
