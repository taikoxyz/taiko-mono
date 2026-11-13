package blocksinserter

import (
	"bytes"
	"context"
	"encoding/hex"
	"encoding/json"
	"io"
	"math/big"
	"os"
	"path/filepath"
	"runtime"
	"testing"

	"github.com/ethereum/go-ethereum/rlp"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/event/derivation"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// These extraction-only fixtures cover both sides of Unzen; the Lean model remains Unzen-only.
func TestDerivationClientForkSelection(t *testing.T) {
	_, file, _, ok := runtime.Caller(0)
	require.True(t, ok)
	path := filepath.Join(filepath.Dir(file), "../../../../../../testdata/derivation_vectors/fork_selection_cases.json")
	raw, err := os.ReadFile(path)
	require.NoError(t, err)
	var corpus struct {
		Version int `json:"schema_version"`
		Cases   []struct {
			Name              string `json:"name"`
			ChainID           uint64 `json:"chain_id"`
			ProposalTimestamp uint64 `json:"proposal_timestamp"`
			Payload           string `json:"payload_hex"`
			ExpectedRLP       string `json:"expected_manifest_rlp_hex"`
		} `json:"cases"`
	}
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	require.NoError(t, decoder.Decode(&corpus))
	require.ErrorIs(t, decoder.Decode(new(any)), io.EOF)
	require.Equal(t, 1, corpus.Version)
	require.Len(t, corpus.Cases, 12)
	cases := make([]boundaryCase, len(corpus.Cases))
	seen := make(map[string]bool)
	for i, fixture := range corpus.Cases {
		require.NotEmpty(t, fixture.Name)
		require.False(t, seen[fixture.Name], "duplicate fork vector %q", fixture.Name)
		seen[fixture.Name] = true
		cases[i].Name = fixture.Name
		cases[i].ChainID = fixture.ChainID
		cases[i].Proposal.Timestamp = fixture.ProposalTimestamp
		cases[i].Proposal.ProposalID = 8
		cases[i].Sources = []boundarySource{{HasBlobs: true, Payload: &fixture.Payload}}
	}
	blobs := newBoundaryBlobServer(t, cases)
	for i, c := range cases {
		t.Run(c.Name, func(t *testing.T) {
			ctx := context.Background()
			cli := &rpc.Client{L2: &rpc.EthClient{ChainID: new(big.Int).SetUint64(c.ChainID)}}
			fetcher := derivation.NewDerivationSourceFetcher(cli, rpc.NewBlobDataSource(ctx, cli, blobs.endpoint))
			meta := boundaryMetadata(c, blobs)
			// Blob availability time is independent; the cap must use the landed proposal time.
			meta.GetEventData().Sources[0].BlobSlice.Timestamp = big.NewInt(7)
			payload, err := fetcher.Fetch(ctx, meta, 0)
			require.NoError(t, err)
			require.Equal(t, corpus.Cases[i].ExpectedRLP, boundaryManifestRLP(t, payload))
		})
	}
}

func boundaryManifestRLP(t *testing.T, payload *derivation.DerivationSourcePayload) string {
	t.Helper()
	extracted := &manifest.DerivationSourceManifest{}
	if payload.Default {
		extracted.Blocks = []*manifest.BlockManifest{{}}
	} else {
		for _, block := range payload.BlockPayloads {
			extracted.Blocks = append(extracted.Blocks, &block.BlockManifest)
		}
	}
	raw, err := rlp.EncodeToBytes(extracted)
	require.NoError(t, err)
	return hex.EncodeToString(raw)
}
