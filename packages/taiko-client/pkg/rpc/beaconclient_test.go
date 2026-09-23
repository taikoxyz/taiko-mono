package rpc

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"net/http"
	"net/http/httptest"
	"net/url"
	"slices"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	opeth "github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/crypto/kzg4844"
	prysmclient "github.com/prysmaticlabs/prysm/v5/api/client"
	"github.com/prysmaticlabs/prysm/v5/api/server/structs"
	"github.com/stretchr/testify/require"
)

// beaconStub is a minimal fake beacon node whose responses can be mutated per test.
type beaconStub struct {
	pathPrefix   string
	genesisBody  string
	genesisCode  int
	specBody     string
	specCode     int
	blobsBody    string
	blobsCode    int
	sidecarsBody string
	sidecarsCode int
	// rateLimited is the number of first blob requests answered with 429.
	rateLimited int
	// blobsDropConnection makes the blobs endpoint close the connection without answering.
	blobsDropConnection bool

	mu       sync.Mutex
	requests []url.URL
}

func newBeaconStub() *beaconStub {
	return &beaconStub{
		genesisBody:  `{"data":{"genesis_time":"100"}}`,
		genesisCode:  http.StatusOK,
		specBody:     `{"data":{"SECONDS_PER_SLOT":"12","SLOTS_PER_EPOCH":"32"}}`,
		specCode:     http.StatusOK,
		blobsBody:    `{"execution_optimistic":false,"finalized":true,"data":[]}`,
		blobsCode:    http.StatusOK,
		sidecarsBody: `{"data":[]}`,
		sidecarsCode: http.StatusOK,
	}
}

func (s *beaconStub) serve(t *testing.T) *httptest.Server {
	t.Helper()
	respond := func(w http.ResponseWriter, code int, body string) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(code)
		_, _ = w.Write([]byte(body))
	}
	server := httptest.NewServer(http.StripPrefix(s.pathPrefix, http.HandlerFunc(
		func(w http.ResponseWriter, r *http.Request) {
			switch {
			case r.URL.Path == genesisRequestURL:
				respond(w, s.genesisCode, s.genesisBody)
			case r.URL.Path == getConfigSpecPath:
				respond(w, s.specCode, s.specBody)
			case strings.HasPrefix(r.URL.Path, "/eth/v1/beacon/blobs/"):
				if s.recordRequest(r) <= s.rateLimited {
					respond(w, http.StatusTooManyRequests, "")
					return
				}
				if s.blobsDropConnection {
					// net/http closes the connection without answering, as it does when a handler panics.
					panic(http.ErrAbortHandler)
				}
				respond(w, s.blobsCode, s.blobsBody)
			case strings.HasPrefix(r.URL.Path, "/eth/v1/beacon/blob_sidecars/"):
				s.recordRequest(r)
				respond(w, s.sidecarsCode, s.sidecarsBody)
			default:
				http.NotFound(w, r)
			}
		},
	)))
	t.Cleanup(server.Close)
	return server
}

// recordRequest records a blob or blob sidecar request, and returns how many were received so far.
func (s *beaconStub) recordRequest(r *http.Request) int {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.requests = append(s.requests, *r.URL)
	return len(s.requests)
}

// blobRequests returns the URLs of the blob and blob sidecar requests received so far, in order.
func (s *beaconStub) blobRequests() []url.URL {
	s.mu.Lock()
	defer s.mu.Unlock()
	return slices.Clone(s.requests)
}

// blobsBody encodes a blobs endpoint response serving the given blobs, in the given (block) order.
func blobsBody(t *testing.T, blobs ...*opeth.Blob) string {
	t.Helper()
	body, err := json.Marshal(map[string]any{
		"execution_optimistic": false,
		"finalized":            true,
		"data":                 append([]*opeth.Blob{}, blobs...), // never null
	})
	require.NoError(t, err)
	return string(body)
}

// sidecarsBody encodes a blob sidecars endpoint response reporting commitments[i] for blobs[i].
func sidecarsBody(t *testing.T, blobs []*opeth.Blob, commitments []kzg4844.Commitment) string {
	t.Helper()
	sidecars := make([]*structs.Sidecar, len(blobs))
	for i := range blobs {
		sidecars[i] = &structs.Sidecar{
			Index:         strconv.Itoa(i),
			Blob:          blobs[i].String(),
			KzgCommitment: hexutil.Encode(commitments[i][:]),
		}
	}
	body, err := json.Marshal(structs.SidecarsResponse{Data: sidecars})
	require.NoError(t, err)
	return string(body)
}

func TestNewBeaconClientParsesBeaconMetadata(t *testing.T) {
	server := newBeaconStub().serve(t)

	client, err := NewBeaconClient(server.URL, DefaultRpcTimeout)
	require.NoError(t, err)
	require.Equal(t, uint64(100), client.genesisTime)
	require.Equal(t, uint64(12), client.SecondsPerSlot)
	require.Equal(t, uint64(32), client.SlotsPerEpoch)
}

func TestNewBeaconClientRejectsMalformedBeaconMetadata(t *testing.T) {
	tests := []struct {
		name      string
		mutate    func(s *beaconStub)
		wantError string
	}{
		{
			name:      "null genesis body",
			mutate:    func(s *beaconStub) { s.genesisBody = "null" },
			wantError: "genesis_time",
		},
		{
			name:      "negative genesis time",
			mutate:    func(s *beaconStub) { s.genesisBody = `{"data":{"genesis_time":"-1"}}` },
			wantError: "genesis_time",
		},
		{
			name:      "spec request fails",
			mutate:    func(s *beaconStub) { s.specCode = http.StatusInternalServerError },
			wantError: "configSpecPath",
		},
		{
			name:      "spec data is not an object",
			mutate:    func(s *beaconStub) { s.specBody = `{"data":[]}` },
			wantError: "beacon config spec",
		},
		{
			name:      "spec field is not a string",
			mutate:    func(s *beaconStub) { s.specBody = `{"data":{"SECONDS_PER_SLOT":12,"SLOTS_PER_EPOCH":"32"}}` },
			wantError: "beacon config spec",
		},
		{
			name:      "spec field is missing",
			mutate:    func(s *beaconStub) { s.specBody = `{"data":{"SLOTS_PER_EPOCH":"32"}}` },
			wantError: "SECONDS_PER_SLOT",
		},
		{
			name:      "zero seconds per slot",
			mutate:    func(s *beaconStub) { s.specBody = `{"data":{"SECONDS_PER_SLOT":"0","SLOTS_PER_EPOCH":"32"}}` },
			wantError: "SECONDS_PER_SLOT",
		},
		{
			name:      "zero slots per epoch",
			mutate:    func(s *beaconStub) { s.specBody = `{"data":{"SECONDS_PER_SLOT":"12","SLOTS_PER_EPOCH":"0"}}` },
			wantError: "SLOTS_PER_EPOCH",
		},
		{
			name: "seconds per slot wraps a duration to zero",
			mutate: func(s *beaconStub) {
				s.specBody = `{"data":{"SECONDS_PER_SLOT":"9223372036854775808","SLOTS_PER_EPOCH":"32"}}`
			},
			wantError: "SECONDS_PER_SLOT",
		},
		{
			name: "seconds per slot wraps a duration negative",
			mutate: func(s *beaconStub) {
				s.specBody = `{"data":{"SECONDS_PER_SLOT":"18446744073709551615","SLOTS_PER_EPOCH":"32"}}`
			},
			wantError: "SECONDS_PER_SLOT",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			stub := newBeaconStub()
			tt.mutate(stub)
			server := stub.serve(t)

			var (
				client *BeaconClient
				err    error
			)
			require.NotPanics(t, func() {
				client, err = NewBeaconClient(server.URL, DefaultRpcTimeout)
			})
			require.Nil(t, client)
			require.ErrorContains(t, err, tt.wantError)
		})
	}
}

func TestGetBlobsRequestsVersionedHashesAndMatchesBlobs(t *testing.T) {
	first, _, firstHash := testBlobWithCommitment(t, []byte("first"))
	second, _, secondHash := testBlobWithCommitment(t, []byte("second"))

	stub := newBeaconStub()
	// The spec returns blobs in block order, whatever the order of the requested hashes.
	stub.blobsBody = blobsBody(t, first, second)
	client, err := NewBeaconClient(stub.serve(t).URL, DefaultRpcTimeout)
	require.NoError(t, err)

	// Timestamp 184 falls in slot 7 with genesis at 100 and 12-second slots.
	blobs, err := client.GetBlobs(context.Background(), 184, []common.Hash{secondHash, firstHash, secondHash})
	require.NoError(t, err)
	require.Equal(t, []*opeth.Blob{second, first, second}, blobs)

	requests := stub.blobRequests()
	require.Len(t, requests, 1)
	require.Equal(t, "/eth/v1/beacon/blobs/7", requests[0].Path)
	require.Equal(t, []string{secondHash.Hex(), firstHash.Hex()}, requests[0].Query()["versioned_hashes"])
}

func TestGetBlobsIgnoresUnrequestedAndRepeatedBlobs(t *testing.T) {
	blob, _, blobHash := testBlobWithCommitment(t, []byte("requested"))
	other, _, _ := testBlobWithCommitment(t, []byte("other"))

	stub := newBeaconStub()
	// A node that ignores the filter, or lists a blob twice, still yields exactly the requested blobs.
	stub.blobsBody = blobsBody(t, other, blob, blob)
	client, err := NewBeaconClient(stub.serve(t).URL, DefaultRpcTimeout)
	require.NoError(t, err)

	blobs, err := client.GetBlobs(context.Background(), 100, []common.Hash{blobHash})
	require.NoError(t, err)
	require.Equal(t, []*opeth.Blob{blob}, blobs)
}

func TestGetBlobsRetriesRateLimitedRequests(t *testing.T) {
	blob, _, blobHash := testBlobWithCommitment(t, []byte("derivation data"))

	stub := newBeaconStub()
	stub.rateLimited = 1
	stub.blobsBody = blobsBody(t, blob)
	client, err := NewBeaconClient(stub.serve(t).URL, DefaultRpcTimeout)
	require.NoError(t, err)

	blobs, err := client.GetBlobs(context.Background(), 100, []common.Hash{blobHash})
	require.NoError(t, err)
	require.Equal(t, []*opeth.Blob{blob}, blobs)
	require.Len(t, stub.blobRequests(), 2)
}

func TestGetBlobsKeepsEndpointPath(t *testing.T) {
	blob, _, blobHash := testBlobWithCommitment(t, []byte("derivation data"))

	stub := newBeaconStub()
	stub.pathPrefix = "/beacon"
	stub.blobsBody = blobsBody(t, blob)
	client, err := NewBeaconClient(stub.serve(t).URL+stub.pathPrefix, DefaultRpcTimeout)
	require.NoError(t, err)

	blobs, err := client.GetBlobs(context.Background(), 100, []common.Hash{blobHash})
	require.NoError(t, err)
	require.Equal(t, []*opeth.Blob{blob}, blobs)
}

func TestGetBlobsWithoutVersionedHashesSendsNoRequest(t *testing.T) {
	stub := newBeaconStub()
	client, err := NewBeaconClient(stub.serve(t).URL, DefaultRpcTimeout)
	require.NoError(t, err)

	// Without versioned hashes the endpoint would return every blob in the block.
	blobs, err := client.GetBlobs(context.Background(), 100, nil)
	require.NoError(t, err)
	require.Empty(t, blobs)
	require.Empty(t, stub.blobRequests())
}

func TestGetBlobsRejectsResponsesWithoutRequestedBlobs(t *testing.T) {
	_, _, blobHash := testBlobWithCommitment(t, []byte("requested"))
	other, _, _ := testBlobWithCommitment(t, []byte("other"))
	var nonCanonical opeth.Blob
	for i := range nonCanonical {
		nonCanonical[i] = 0xff // every field element exceeds the BLS modulus
	}

	tests := []struct {
		name      string
		body      string
		wantError string
	}{
		{name: "null response", body: "null", wantError: "missing data"},
		{name: "null data", body: `{"data":null}`, wantError: "missing data"},
		{name: "null blob", body: `{"data":[null]}`, wantError: "null blob"},
		{name: "blob of the wrong length", body: `{"data":["0x0102"]}`, wantError: "decode beacon blobs response"},
		{name: "no blobs", body: blobsBody(t), wantError: "did not return blob"},
		{name: "blob with another versioned hash", body: blobsBody(t, other), wantError: "did not return blob"},
		{name: "non-canonical blob", body: blobsBody(t, &nonCanonical), wantError: "compute KZG commitment"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			stub := newBeaconStub()
			stub.blobsBody = tt.body
			client, err := NewBeaconClient(stub.serve(t).URL, DefaultRpcTimeout)
			require.NoError(t, err)

			var blobs []*opeth.Blob
			require.NotPanics(t, func() {
				blobs, err = client.GetBlobs(context.Background(), 100, []common.Hash{blobHash})
			})
			require.Nil(t, blobs)
			require.ErrorContains(t, err, tt.wantError)
			// The node serves the endpoint, so the deprecated one is not asked.
			require.Len(t, stub.blobRequests(), 1)
		})
	}
}

func TestGetBlobsFallsBackToBlobSidecarsWhenBlobsEndpointNotFound(t *testing.T) {
	first, firstCommitment, firstHash := testBlobWithCommitment(t, []byte("first"))
	second, secondCommitment, secondHash := testBlobWithCommitment(t, []byte("second"))

	stub := newBeaconStub()
	stub.blobsCode = http.StatusNotFound
	stub.blobsBody = `{"code":404,"message":"NOT_FOUND"}`
	stub.sidecarsBody = sidecarsBody(
		t,
		[]*opeth.Blob{first, second},
		[]kzg4844.Commitment{firstCommitment, secondCommitment},
	)
	client, err := NewBeaconClient(stub.serve(t).URL, DefaultRpcTimeout)
	require.NoError(t, err)

	blobs, err := client.GetBlobs(context.Background(), 184, []common.Hash{secondHash, firstHash, secondHash})
	require.NoError(t, err)
	require.Equal(t, []*opeth.Blob{second, first, second}, blobs)

	requests := stub.blobRequests()
	require.Len(t, requests, 2)
	require.Equal(t, "/eth/v1/beacon/blobs/7", requests[0].Path)
	require.Equal(t, "/eth/v1/beacon/blob_sidecars/7", requests[1].Path)
}

func TestGetBlobsFallsBackToBlobSidecarsWhenBlobsEndpointDropsConnection(t *testing.T) {
	blob, commitment, blobHash := testBlobWithCommitment(t, []byte("derivation data"))

	stub := newBeaconStub()
	// Prysm v6.1.0 to v7.1.7 panics on the blobs endpoint when a requested blob appears twice in the block,
	// while its blob sidecars endpoint still serves the blob.
	stub.blobsDropConnection = true
	stub.sidecarsBody = sidecarsBody(t, []*opeth.Blob{blob}, []kzg4844.Commitment{commitment})
	client, err := NewBeaconClient(stub.serve(t).URL, DefaultRpcTimeout)
	require.NoError(t, err)

	blobs, err := client.GetBlobs(context.Background(), 100, []common.Hash{blobHash})
	require.NoError(t, err)
	require.Equal(t, []*opeth.Blob{blob}, blobs)

	requests := stub.blobRequests()
	require.Equal(t, "/eth/v1/beacon/blob_sidecars/0", requests[len(requests)-1].Path)
}

func TestGetBlobsRejectsBlobSidecarNotMatchingItsCommitment(t *testing.T) {
	_, commitment, blobHash := testBlobWithCommitment(t, []byte("reported"))
	other, _, _ := testBlobWithCommitment(t, []byte("served"))

	stub := newBeaconStub()
	stub.blobsCode = http.StatusNotFound
	// The sidecar reports the requested commitment, but carries another blob.
	stub.sidecarsBody = sidecarsBody(t, []*opeth.Blob{other}, []kzg4844.Commitment{commitment})
	client, err := NewBeaconClient(stub.serve(t).URL, DefaultRpcTimeout)
	require.NoError(t, err)

	blobs, err := client.GetBlobs(context.Background(), 100, []common.Hash{blobHash})
	require.Nil(t, blobs)
	require.ErrorContains(t, err, "did not return blob")
}

func TestGetBlobsReportsBlobsEndpointErrorWhenBlobSidecarsFallbackFails(t *testing.T) {
	_, _, blobHash := testBlobWithCommitment(t, []byte("derivation data"))

	stub := newBeaconStub()
	stub.blobsCode = http.StatusNotFound
	// Nimbus v26.8.0+ answers the removed endpoint with 410 Gone.
	stub.sidecarsCode = http.StatusGone
	client, err := NewBeaconClient(stub.serve(t).URL, DefaultRpcTimeout)
	require.NoError(t, err)

	blobs, err := client.GetBlobs(context.Background(), 100, []common.Hash{blobHash})
	require.Nil(t, blobs)
	require.ErrorIs(t, err, prysmclient.ErrNotFound)
	require.ErrorContains(t, err, "code=410")
	require.Len(t, stub.blobRequests(), 2)
}

func TestGetBlobsDoesNotFallBackToBlobSidecarsOnOtherStatuses(t *testing.T) {
	blob, commitment, blobHash := testBlobWithCommitment(t, []byte("derivation data"))

	// Nodes serving the endpoint answer 400 (Lighthouse, Lodestar, Grandine) or 5xx for blobs they cannot serve.
	for _, code := range []int{
		http.StatusBadRequest,
		http.StatusInternalServerError,
		http.StatusServiceUnavailable,
	} {
		t.Run(strconv.Itoa(code), func(t *testing.T) {
			stub := newBeaconStub()
			stub.blobsCode = code
			stub.sidecarsBody = sidecarsBody(t, []*opeth.Blob{blob}, []kzg4844.Commitment{commitment})
			client, err := NewBeaconClient(stub.serve(t).URL, DefaultRpcTimeout)
			require.NoError(t, err)

			blobs, err := client.GetBlobs(context.Background(), 100, []common.Hash{blobHash})
			require.Nil(t, blobs)
			require.ErrorContains(t, err, strconv.Itoa(code))
			require.Len(t, stub.blobRequests(), 1)
		})
	}
}

func TestShouldTryBlobSidecars(t *testing.T) {
	blobsURL := "http://beacon/eth/v1/beacon/blobs/0"
	droppedConnection := &url.Error{Op: "Get", URL: blobsURL, Err: io.EOF}
	doneCtx, cancel := context.WithCancel(context.Background())
	cancel()

	tests := []struct {
		name string
		ctx  context.Context
		err  error
		want bool
	}{
		{"not found", context.Background(), fmt.Errorf("code=404: %w", prysmclient.ErrNotFound), true},
		{"dropped connection", context.Background(), droppedConnection, true},
		{"other status", context.Background(), fmt.Errorf("code=400: %w", prysmclient.ErrNotOK), false},
		{"timeout", context.Background(), &url.Error{Op: "Get", URL: blobsURL, Err: context.DeadlineExceeded}, false},
		{
			"exhausted rate limit retries",
			context.Background(),
			&url.Error{Op: "Get", URL: blobsURL, Err: &RateLimitError{URL: blobsURL, Attempts: RateLimitMaxRetries}},
			false,
		},
		{"done context", doneCtx, droppedConnection, false},
		{"malformed response", context.Background(), errors.New("failed to decode beacon blobs response"), false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			require.Equal(t, tt.want, shouldTryBlobSidecars(tt.ctx, tt.err))
		})
	}
}

func TestParseBeaconUint64(t *testing.T) {
	tests := []struct {
		name      string
		value     string
		want      uint64
		wantError string
	}{
		{name: "decimal", value: "12", want: 12},
		{name: "zero", value: "0", want: 0},
		{name: "above int64", value: "9223372036854775808", want: 1 << 63},
		{name: "max uint64", value: "18446744073709551615", want: math.MaxUint64},
		{name: "empty", value: "", wantError: "missing"},
		{name: "negative", value: "-1", wantError: "invalid"},
		{name: "leading plus", value: "+12", wantError: "invalid"},
		{name: "hex", value: "0x10", wantError: "invalid"},
		{name: "exceeds uint64", value: "18446744073709551616", wantError: "invalid"},
		{name: "surrounding whitespace", value: " 12", wantError: "invalid"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := parseBeaconUint64("SECONDS_PER_SLOT", tt.value)
			if tt.wantError != "" {
				require.ErrorContains(t, err, tt.wantError)
				require.ErrorContains(t, err, "SECONDS_PER_SLOT")
				return
			}
			require.NoError(t, err)
			require.Equal(t, tt.want, got)
		})
	}
}

func TestParseBeaconPositiveUint64RejectsZero(t *testing.T) {
	got, err := parseBeaconPositiveUint64("SLOTS_PER_EPOCH", "32")
	require.NoError(t, err)
	require.Equal(t, uint64(32), got)

	_, err = parseBeaconPositiveUint64("SLOTS_PER_EPOCH", "0")
	require.ErrorContains(t, err, "SLOTS_PER_EPOCH")
	require.ErrorContains(t, err, "greater than zero")
}

func TestParseBeaconDurationSeconds(t *testing.T) {
	tests := []struct {
		name      string
		value     string
		want      uint64
		wantError string
	}{
		{name: "mainnet", value: "12", want: 12},
		{
			name:  "largest representable",
			value: strconv.FormatUint(maxBeaconDurationSeconds, 10),
			want:  maxBeaconDurationSeconds,
		},
		{name: "missing", value: "", wantError: "missing"},
		{name: "zero", value: "0", wantError: "greater than zero"},
		{
			name:      "one above the bound",
			value:     strconv.FormatUint(maxBeaconDurationSeconds+1, 10),
			wantError: "at most",
		},
		{name: "wraps a duration to zero", value: "9223372036854775808", wantError: "at most"},
		{name: "max uint64", value: "18446744073709551615", wantError: "at most"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := parseBeaconDurationSeconds("SECONDS_PER_SLOT", tt.value)
			if tt.wantError != "" {
				require.ErrorContains(t, err, tt.wantError)
				require.ErrorContains(t, err, "SECONDS_PER_SLOT")
				return
			}
			require.NoError(t, err)
			require.Equal(t, tt.want, got)
		})
	}
}

// TestSecondsPerSlotBoundKeepsLookaheadTickerPositive pins maxBeaconDurationSeconds to the reason it
// exists: the driver derives its lookahead ticker interval from SecondsPerSlot with
// `time.Second * time.Duration(d.rpc.L1Beacon.SecondsPerSlot) / 3` (driver/driver.go), and
// time.NewTicker panics on a non-positive interval.
func TestSecondsPerSlotBoundKeepsLookaheadTickerPositive(t *testing.T) {
	lookaheadTickerInterval := func(secondsPerSlot uint64) time.Duration {
		return time.Second * time.Duration(secondsPerSlot) / 3
	}

	for _, secondsPerSlot := range []uint64{1, 12, maxBeaconDurationSeconds} {
		interval := lookaheadTickerInterval(secondsPerSlot)
		require.Greater(t, interval, time.Duration(0), "seconds per slot %d", secondsPerSlot)
		require.NotPanics(t, func() { time.NewTicker(interval).Stop() })
	}

	// Past the bound the product wraps, which is exactly what the parser now rejects.
	require.Equal(t, time.Duration(0), lookaheadTickerInterval(1<<63))
	require.Less(t, lookaheadTickerInterval(math.MaxUint64), time.Duration(0))
	require.Less(t, lookaheadTickerInterval(maxBeaconDurationSeconds+1), time.Duration(0))
}
