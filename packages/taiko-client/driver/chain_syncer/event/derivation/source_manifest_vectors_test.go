package derivation

import (
	"encoding/hex"
	"encoding/json"
	"math/big"
	"os"
	"path/filepath"
	"runtime"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/params"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

type manifestVector struct {
	Name     string `json:"name"`
	Family   string `json:"family"`
	Payload  string `json:"payload_hex"`
	Offset   int    `json:"offset"`
	Default  bool   `json:"expect_default"`
	Expected string `json:"expected_manifest_rlp_hex"`
}

func loadManifestVectors(t *testing.T) []manifestVector {
	t.Helper()
	_, file, _, ok := runtime.Caller(0)
	require.True(t, ok)
	path := filepath.Join(filepath.Dir(file), "../../../../../../testdata/derivation_vectors/manifest_cases.json")
	raw, err := os.ReadFile(path)
	require.NoError(t, err)
	var corpus struct {
		Version int              `json:"schema_version"`
		Cases   []manifestVector `json:"cases"`
	}
	require.NoError(t, json.Unmarshal(raw, &corpus))
	require.Equal(t, 1, corpus.Version)
	require.NotEmpty(t, corpus.Cases)
	return corpus.Cases
}

func vectorBytes(t *testing.T, encoded string) []byte {
	t.Helper()
	raw, err := hex.DecodeString(encoded)
	require.NoError(t, err)
	return raw
}

func vectorFetcher() *DerivationSourceFetcher {
	return &DerivationSourceFetcher{cli: &rpc.Client{L2: &rpc.EthClient{ChainID: params.TaikoInternalNetworkID}}}
}

func normalizeSourceRLP(t *testing.T, payload *DerivationSourcePayload) []byte {
	t.Helper()
	m := &manifest.DerivationSourceManifest{}
	if payload.Default {
		m.Blocks = []*manifest.BlockManifest{{}}
	} else {
		for _, block := range payload.BlockPayloads {
			m.Blocks = append(m.Blocks, &block.BlockManifest)
		}
	}
	b, err := rlp.EncodeToBytes(m)
	require.NoError(t, err)
	return b
}

// A lost grammar check must retain the hostile source and fail these expectations.
func TestManifestVectorsF9(t *testing.T) { testManifestVectors(t, "f9") }

func TestManifestVectorsF8(t *testing.T) { testManifestVectors(t, "f8") }

func testManifestVectors(t *testing.T, family string) {
	t.Helper()
	for _, v := range loadManifestVectors(t) {
		if v.Family != family {
			continue
		}
		t.Run(v.Name, func(t *testing.T) {
			meta := shastaMetaWithTimestamp(1000)
			meta.GetEventData().Sources[0].BlobSlice.Offset = big.NewInt(int64(v.Offset))
			got, err := vectorFetcher().manifestFromBlobBytes(vectorBytes(t, v.Payload), meta, 0)
			require.NoError(t, err)
			require.Equal(t, v.Default, got.Default)
			require.Equal(t, vectorBytes(t, v.Expected), normalizeSourceRLP(t, got))
		})
	}
}

func TestManifestVectorsSourceIsolation(t *testing.T) {
	vectors := loadManifestVectors(t)
	for _, forced := range []bool{false, true} {
		for _, v := range vectors {
			if v.Name != "type2_parity_2" && v.Name != "type2_control" &&
				v.Name != "late_bad_transaction" && v.Name != "two_valid_blocks" {
				continue
			}
			t.Run(v.Name+map[bool]string{false: "_ordinary", true: "_forced"}[forced], func(t *testing.T) {
				meta := shastaMetaWithTimestamp(1000)
				meta.GetEventData().Sources = append(meta.GetEventData().Sources, meta.GetEventData().Sources[0])
				meta.GetEventData().Sources[1].IsForcedInclusion = forced
				got, err := vectorFetcher().manifestFromBlobBytes(vectorBytes(t, v.Payload), meta, 1)
				require.NoError(t, err)
				require.Equal(t, v.Default || forced && v.Name == "two_valid_blocks", got.Default)
				// Fetch a distinct, valid neighboring source with the same fetcher and proposal.
				for _, control := range vectors {
					if control.Name != "type2_control" {
						continue
					}
					neighbor, err := vectorFetcher().manifestFromBlobBytes(vectorBytes(t, control.Payload), meta, 0)
					require.NoError(t, err)
					require.False(t, neighbor.Default)
					require.Equal(t, vectorBytes(t, control.Expected), normalizeSourceRLP(t, neighbor))
				}
			})
		}
	}
}

func TestManifestVectorsInheritedMetadata(t *testing.T) {
	for _, v := range loadManifestVectors(t) {
		if v.Name != "type2_parity_2" {
			continue
		}
		meta := shastaMetaWithTimestamp(101)
		got, err := vectorFetcher().manifestFromBlobBytes(vectorBytes(t, v.Payload), meta, 0)
		require.NoError(t, err)
		require.True(t, got.Default)
		// This is the existing syncer's default-source expansion before inheritance.
		got.BlockPayloads = []*BlockPayload{{}}
		got.ParentBlock = types.NewBlock(
			&types.Header{Number: big.NewInt(0), Time: 100, GasLimit: 10_000_000}, &types.Body{}, nil, nil,
		)
		meta.GetEventData().Proposer = common.HexToAddress("0x9999")
		ApplyInheritedMetadata(got, meta.GetEventData(), 101, 4, params.TaikoInternalNetworkID)
		require.Len(t, got.BlockPayloads, 1)
		block := got.BlockPayloads[0]
		require.Equal(t, uint64(101), block.Timestamp)
		require.Equal(t, uint64(10_000_000), block.GasLimit)
		require.Equal(t, uint64(4), block.AnchorBlockNumber)
		require.Equal(t, meta.GetEventData().Proposer, block.Coinbase)
		require.Empty(t, block.Transactions)
	}
}
