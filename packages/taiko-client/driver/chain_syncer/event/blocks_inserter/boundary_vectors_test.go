package blocksinserter

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"runtime"
	"slices"
	"strings"
	"testing"

	opeth "github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto/kzg4844"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer/event/derivation"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

type boundaryParent struct {
	Number            uint64 `json:"number"`
	Timestamp         uint64 `json:"timestamp"`
	GasLimit          uint64 `json:"gas_limit"`
	AnchorBlockNumber uint64 `json:"anchor_block_number"`
}

type boundaryBlock struct {
	Number            uint64 `json:"number"`
	Timestamp         uint64 `json:"timestamp"`
	Coinbase          string `json:"coinbase"`
	AnchorBlockNumber uint64 `json:"anchor_block_number"`
	GasLimit          uint64 `json:"gas_limit"`
	TransactionsRLP   string `json:"transactions_rlp_hex"`
	Forced            bool   `json:"is_forced_inclusion"`
}

type boundaryHeader struct {
	GasLimit          uint64 `json:"gas_limit"`
	ExtraData         string `json:"extra_data_hex"`
	AnchorBlockNumber uint64 `json:"anchor_block_number"`
	TransactionsRLP   string `json:"transactions_rlp_hex"`
	AnchorFirst       bool   `json:"anchor_first"`
}

type boundaryOutput struct {
	ExtractedManifests []string         `json:"extracted_manifests_rlp_hex"`
	SourceBlockCounts  []int            `json:"source_block_counts"`
	Blocks             []boundaryBlock  `json:"blocks"`
	Headers            []boundaryHeader `json:"headers"`
	NextParent         boundaryParent   `json:"next_parent"`
}

type boundarySource struct {
	Forced   bool    `json:"is_forced_inclusion"`
	HasBlobs bool    `json:"has_blobs"`
	Offset   uint64  `json:"offset"`
	Payload  *string `json:"payload_hex"`
}

type boundaryCase struct {
	Name     string `json:"name"`
	Category string `json:"category"`
	ChainID  uint64 `json:"chain_id"`
	Proposal struct {
		Timestamp          uint64 `json:"timestamp"`
		OriginBlockNumber  uint64 `json:"origin_block_number"`
		Proposer           string `json:"proposer"`
		ProposalID         uint64 `json:"proposal_id"`
		BasefeeSharingPctg uint8  `json:"basefee_sharing_pctg"`
	} `json:"proposal"`
	Parent   boundaryParent   `json:"parent"`
	Sources  []boundarySource `json:"sources"`
	Expected boundaryOutput   `json:"expected"`
}

func loadBoundaryVectors(t *testing.T) []boundaryCase {
	t.Helper()
	_, file, _, ok := runtime.Caller(0)
	require.True(t, ok)
	path := filepath.Join(filepath.Dir(file), "../../../../../../testdata/derivation_vectors/boundary_cases.json")
	if override := os.Getenv("TAIKO_DERIVATION_BOUNDARY_VECTORS"); override != "" {
		path = override
	}
	raw, err := os.ReadFile(path)
	require.NoError(t, err)
	var corpus struct {
		Version int            `json:"schema_version"`
		Cases   []boundaryCase `json:"cases"`
	}
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	require.NoError(t, decoder.Decode(&corpus))
	require.ErrorIs(t, decoder.Decode(new(any)), io.EOF)
	require.Equal(t, 1, corpus.Version)
	require.NotEmpty(t, corpus.Cases)
	seen := make(map[string]bool)
	for _, c := range corpus.Cases {
		require.NotEmpty(t, c.Name)
		require.False(t, seen[c.Name], "duplicate vector %q", c.Name)
		seen[c.Name] = true
		require.NotEmpty(t, c.Category, c.Name)
		require.Len(t, boundaryHex(t, c.Proposal.Proposer), common.AddressLength, c.Name)
		require.Less(t, c.Proposal.ProposalID, uint64(1)<<48, c.Name)
		require.Len(t, c.Expected.SourceBlockCounts, len(c.Sources), c.Name)
		require.Len(t, c.Expected.ExtractedManifests, len(c.Sources), c.Name)
		for _, encoded := range c.Expected.ExtractedManifests {
			boundaryHex(t, encoded)
		}
		total := 0
		for _, count := range c.Expected.SourceBlockCounts {
			require.Positive(t, count, c.Name)
			total += count
		}
		require.Len(t, c.Expected.Blocks, total, c.Name)
		require.Len(t, c.Expected.Headers, total, c.Name)
		for _, block := range c.Expected.Blocks {
			require.Len(t, boundaryHex(t, block.Coinbase), common.AddressLength, c.Name)
			boundaryHex(t, block.TransactionsRLP)
		}
		for _, header := range c.Expected.Headers {
			boundaryHex(t, header.ExtraData)
			boundaryHex(t, header.TransactionsRLP)
		}
	}
	return corpus.Cases
}

func boundaryHex(t *testing.T, encoded string) []byte {
	t.Helper()
	require.Equal(t, strings.ToLower(encoded), encoded, "hex must be lowercase")
	raw, err := hex.DecodeString(encoded)
	require.NoError(t, err)
	return raw
}

// boundaryBlobServer only replaces blob availability: Fetch still runs its no-blob/offset
// guards, real KZG verification, real blob decoding and manifestFromBlobBytes.
type boundaryBlobServer struct {
	endpoint *url.URL
	hashes   map[string][][32]byte
}

func newBoundaryBlobServer(t *testing.T, cases []boundaryCase) *boundaryBlobServer {
	t.Helper()
	fixture := &boundaryBlobServer{hashes: make(map[string][][32]byte)}
	responses := make(map[string]rpc.BlobServerResponse)
	for _, c := range cases {
		for _, source := range c.Sources {
			if !source.HasBlobs {
				continue
			}
			key := boundaryBlobKey(source)
			if _, exists := fixture.hashes[key]; exists {
				continue
			}
			var blobs []*opeth.Blob
			if source.Payload == nil {
				// A committed blob with an invalid encoding, rather than a retriable missing sidecar.
				blob := new(opeth.Blob)
				blob[opeth.VersionOffset] = opeth.EncodingVersion + 1
				blobs = append(blobs, blob)
			} else {
				raw := boundaryHex(t, *source.Payload)
				// Offsets at the first-blob boundary can span multiple decoded blobs.
				for len(raw) > 0 || len(blobs) == 0 {
					size := min(len(raw), opeth.MaxBlobDataSize)
					blob := new(opeth.Blob)
					require.NoError(t, blob.FromData(opeth.Data(raw[:size])))
					blobs = append(blobs, blob)
					raw = raw[size:]
				}
			}
			for _, blob := range blobs {
				commitment, err := blob.ComputeKZGCommitment()
				require.NoError(t, err)
				hash := common.Hash(kzg4844.CalcBlobHashV1(sha256.New(), &commitment))
				fixture.hashes[key] = append(fixture.hashes[key], hash)
				responses["/blobs/"+hash.String()] = rpc.BlobServerResponse{
					VersionedHash: hash.String(), Commitment: hex.EncodeToString(commitment[:]), Data: blob.String(),
				}
			}
		}
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		response, ok := responses[r.URL.Path]
		if !ok {
			http.Error(w, "unexpected blob request", http.StatusNotFound)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		if err := json.NewEncoder(w).Encode(response); err != nil {
			t.Errorf("encode blob fixture: %v", err)
		}
	}))
	t.Cleanup(server.Close)
	var err error
	fixture.endpoint, err = url.Parse(server.URL)
	require.NoError(t, err)
	return fixture
}

func boundaryBlobKey(source boundarySource) string {
	if source.Payload == nil {
		return "invalid-blob-encoding"
	}
	return *source.Payload
}

func boundaryMetadata(c boundaryCase, blobs *boundaryBlobServer) *metadata.TaikoProposalMetadataShasta {
	event := &shastaBindings.ShastaInboxClientProposed{
		Id:                 new(big.Int).SetUint64(c.Proposal.ProposalID),
		Proposer:           common.HexToAddress(c.Proposal.Proposer),
		BasefeeSharingPctg: c.Proposal.BasefeeSharingPctg,
		Raw:                types.Log{BlockNumber: c.Proposal.OriginBlockNumber + 1},
	}
	for _, source := range c.Sources {
		var hashes [][32]byte
		if source.HasBlobs {
			hashes = blobs.hashes[boundaryBlobKey(source)]
		}
		event.Sources = append(event.Sources, shastaBindings.IInboxDerivationSource{
			IsForcedInclusion: source.Forced,
			BlobSlice: shastaBindings.LibBlobsBlobSlice{
				BlobHashes: hashes,
				Offset:     new(big.Int).SetUint64(source.Offset),
				Timestamp:  new(big.Int).SetUint64(c.Proposal.Timestamp),
			},
		})
	}
	return metadata.NewTaikoProposalMetadataShasta(event, c.Proposal.Timestamp)
}

func boundaryParentBlock(parent boundaryParent) *types.Block {
	return types.NewBlockWithHeader(&types.Header{
		Number: new(big.Int).SetUint64(parent.Number), Time: parent.Timestamp,
		GasLimit: parent.GasLimit, Difficulty: new(big.Int),
	})
}

func deriveBoundaryVector(t *testing.T, c boundaryCase, blobs *boundaryBlobServer) boundaryOutput {
	t.Helper()
	ctx := context.Background()
	cli := &rpc.Client{L2: &rpc.EthClient{ChainID: new(big.Int).SetUint64(c.ChainID)}}
	fetcher := derivation.NewDerivationSourceFetcher(cli, rpc.NewBlobDataSource(ctx, cli, blobs.endpoint))
	meta := boundaryMetadata(c, blobs)
	parent := boundaryParentBlock(c.Parent)
	anchorState := c.Parent.AnchorBlockNumber
	got := boundaryOutput{}
	// The production anchor signer/RPC boundary is represented by one distinctive input transaction.
	// Its contents are outside the contract; its position and the candidates following it are not.
	anchorTx := types.NewTx(&types.LegacyTx{Nonce: 0xfeed, Gas: 1_000_000, Data: []byte("boundary-anchor")})
	for sourceIndex := range c.Sources {
		payload, err := fetcher.Fetch(ctx, meta, sourceIndex)
		require.NoError(t, err, c.Name)
		got.ExtractedManifests = append(got.ExtractedManifests, boundaryManifestRLP(t, payload))
		derivation.PrepareSourcePayload(
			cli, payload, parent, meta, anchorState, meta.GetEventData().Sources[sourceIndex].IsForcedInclusion,
		)
		got.SourceBlockCounts = append(got.SourceBlockCounts, len(payload.BlockPayloads))
		for blockIndex := range payload.BlockPayloads {
			plan, err := assembleShastaBlockPlan(meta, payload, parent.Header(), blockIndex)
			require.NoError(t, err, c.Name)
			candidates, err := rlp.EncodeToBytes(plan.payload.Txs)
			require.NoError(t, err)
			got.Blocks = append(got.Blocks, boundaryBlock{
				Number: plan.payload.BlockID.Uint64(), Timestamp: plan.payload.Timestamp,
				Coinbase: hex.EncodeToString(plan.payload.SuggestedFeeRecipient[:]), AnchorBlockNumber: plan.anchorBlockID.Uint64(),
				GasLimit: plan.payload.GasLimit, TransactionsRLP: hex.EncodeToString(candidates),
				// This is event classification; forced behavior is checked through prepared fields/candidates.
				Forced: meta.GetEventData().Sources[sourceIndex].IsForcedInclusion,
			})
			txListBytes, err := preparePayloadTransactions(plan.payload, anchorTx)
			require.NoError(t, err)
			var txList types.Transactions
			require.NoError(t, rlp.DecodeBytes(txListBytes, &txList))
			require.NotEmpty(t, txList)
			anchorFirst := txList[0].Hash() == anchorTx.Hash()
			// Normalize the actual assembly result, removing the distinguished first anchor only.
			assembledCandidates, err := rlp.EncodeToBytes(txList[1:])
			require.NoError(t, err)
			got.Headers = append(got.Headers, boundaryHeader{
				GasLimit: plan.payload.GasLimit, ExtraData: hex.EncodeToString(plan.payload.ExtraData),
				AnchorBlockNumber: plan.anchorBlockID.Uint64(),
				TransactionsRLP:   hex.EncodeToString(assembledCandidates), AnchorFirst: anchorFirst,
			})
			parent = types.NewBlockWithHeader(&types.Header{
				Number: plan.payload.BlockID, Time: plan.payload.Timestamp, GasLimit: plan.payload.GasLimit,
				Extra: plan.payload.ExtraData, Coinbase: plan.payload.SuggestedFeeRecipient, Difficulty: new(big.Int),
			})
			// Real Anchor state is trusted at this layer; the modeled state never decreases.
			anchorState = max(anchorState, plan.anchorBlockID.Uint64())
		}
	}
	got.NextParent = boundaryParent{
		Number: parent.NumberU64(), Timestamp: parent.Time(), GasLimit: parent.GasLimit(), AnchorBlockNumber: anchorState,
	}
	return got
}

func compareBoundaryOutput(want, got boundaryOutput) error {
	if !slices.Equal(want.ExtractedManifests, got.ExtractedManifests) {
		return fmt.Errorf("extracted manifests: want %v, got %v", want.ExtractedManifests, got.ExtractedManifests)
	}
	if !slices.Equal(want.SourceBlockCounts, got.SourceBlockCounts) {
		return fmt.Errorf("source block counts: want %v, got %v", want.SourceBlockCounts, got.SourceBlockCounts)
	}
	if len(want.Blocks) != len(got.Blocks) || len(want.Headers) != len(got.Headers) {
		return fmt.Errorf(
			"block/header count: want %d/%d, got %d/%d",
			len(want.Blocks), len(want.Headers), len(got.Blocks), len(got.Headers),
		)
	}
	for i, block := range want.Blocks {
		if block != got.Blocks[i] {
			return fmt.Errorf("block[%d]: want %+v, got %+v", i, block, got.Blocks[i])
		}
	}
	for i, header := range want.Headers {
		if header != got.Headers[i] {
			return fmt.Errorf("header[%d]: want %+v, got %+v", i, header, got.Headers[i])
		}
	}
	if want.NextParent != got.NextParent {
		return fmt.Errorf("next parent: want %+v, got %+v", want.NextParent, got.NextParent)
	}
	return nil
}

// Removing an extraction/metadata check, changing inheritance order, candidate order,
// anchor prepending, header gas reservation or extraData encoding must fail a vector.
func TestDerivationBoundaryVectors(t *testing.T) {
	cases := loadBoundaryVectors(t)
	blobs := newBoundaryBlobServer(t, cases)
	for _, c := range cases {
		t.Run(c.Name, func(t *testing.T) {
			require.NoError(t, compareBoundaryOutput(c.Expected, deriveBoundaryVector(t, c, blobs)))
		})
	}
}

func TestDerivationBoundaryFetchGuards(t *testing.T) {
	cases := loadBoundaryVectors(t)
	blobs := newBoundaryBlobServer(t, cases)
	guards := 0
	for _, c := range cases {
		meta := boundaryMetadata(c, blobs)
		for i, source := range c.Sources {
			if source.HasBlobs && source.Offset <= uint64(manifest.BlobBytes-64) {
				continue
			}
			guards++
			t.Run(fmt.Sprintf("%s/source_%d", c.Name, i), func(t *testing.T) {
				// A nil data source makes crossing either production guard fail immediately.
				payload, err := derivation.NewDerivationSourceFetcher(nil, nil).Fetch(context.Background(), meta, i)
				require.NoError(t, err)
				require.True(t, payload.Default)
			})
		}
	}
	require.Positive(t, guards, "corpus must exercise pre-fetch guards")
}

func reverseBoundaryTransactions(t *testing.T, encoded string) string {
	t.Helper()
	var txs []rlp.RawValue
	require.NoError(t, rlp.DecodeBytes(boundaryHex(t, encoded), &txs))
	require.GreaterOrEqual(t, len(txs), 2)
	txs[0], txs[1] = txs[1], txs[0]
	raw, err := rlp.EncodeToBytes(txs)
	require.NoError(t, err)
	return hex.EncodeToString(raw)
}

func TestDerivationBoundaryMutationControls(t *testing.T) {
	cases := loadBoundaryVectors(t)
	blobs := newBoundaryBlobServer(t, cases)
	for _, c := range cases {
		for index, block := range c.Expected.Blocks {
			var candidates []rlp.RawValue
			require.NoError(t, rlp.DecodeBytes(boundaryHex(t, block.TransactionsRLP), &candidates))
			if len(candidates) < 2 || bytes.Equal(candidates[0], candidates[1]) {
				continue
			}
			got := deriveBoundaryVector(t, c, blobs)
			require.NoError(t, compareBoundaryOutput(c.Expected, got))
			mutations := map[string]func(*boundaryOutput){
				"extracted_manifest": func(v *boundaryOutput) { v.ExtractedManifests[0] = "c0" },
				"timestamp":          func(v *boundaryOutput) { v.Blocks[index].Timestamp++ },
				"candidate_order": func(v *boundaryOutput) {
					v.Blocks[index].TransactionsRLP = reverseBoundaryTransactions(t, v.Blocks[index].TransactionsRLP)
				},
				"header_candidates": func(v *boundaryOutput) {
					v.Headers[index].TransactionsRLP = reverseBoundaryTransactions(t, v.Headers[index].TransactionsRLP)
				},
				"header_gas":         func(v *boundaryOutput) { v.Headers[index].GasLimit++ },
				"extra_data":         func(v *boundaryOutput) { v.Headers[index].ExtraData += "00" },
				"anchor_target":      func(v *boundaryOutput) { v.Headers[index].AnchorBlockNumber++ },
				"anchor_first":       func(v *boundaryOutput) { v.Headers[index].AnchorFirst = false },
				"next_parent":        func(v *boundaryOutput) { v.NextParent.Timestamp++ },
				"source_block_count": func(v *boundaryOutput) { v.SourceBlockCounts[0]++ },
				"forced_flag":        func(v *boundaryOutput) { v.Blocks[index].Forced = !v.Blocks[index].Forced },
			}
			for name, mutate := range mutations {
				t.Run(name, func(t *testing.T) {
					want := c.Expected
					want.ExtractedManifests = slices.Clone(want.ExtractedManifests)
					want.SourceBlockCounts = slices.Clone(want.SourceBlockCounts)
					want.Blocks = slices.Clone(want.Blocks)
					want.Headers = slices.Clone(want.Headers)
					mutate(&want)
					require.Error(t, compareBoundaryOutput(want, got), "mutated expected output must be rejected")
				})
			}
			return
		}
	}
	t.Fatal("corpus must contain at least two distinct candidate transactions for the ordering mutation")
}
