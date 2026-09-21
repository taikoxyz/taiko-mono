package rpc

import (
	"context"
	"math"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/prysmaticlabs/prysm/v5/api/server/structs"
	"github.com/stretchr/testify/require"
)

// beaconStub is a minimal fake beacon node whose responses can be mutated per test.
type beaconStub struct {
	genesisBody  string
	genesisCode  int
	specBody     string
	specCode     int
	sidecarsBody string
	sidecarsCode int
}

func newBeaconStub() *beaconStub {
	return &beaconStub{
		genesisBody:  `{"data":{"genesis_time":"100"}}`,
		genesisCode:  http.StatusOK,
		specBody:     `{"data":{"SECONDS_PER_SLOT":"12","SLOTS_PER_EPOCH":"32"}}`,
		specCode:     http.StatusOK,
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
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.URL.Path == genesisRequestURL:
			respond(w, s.genesisCode, s.genesisBody)
		case r.URL.Path == getConfigSpecPath:
			respond(w, s.specCode, s.specBody)
		case strings.HasPrefix(r.URL.Path, "/eth/v1/beacon/blob_sidecars/"):
			respond(w, s.sidecarsCode, s.sidecarsBody)
		default:
			http.NotFound(w, r)
		}
	}))
	t.Cleanup(server.Close)
	return server
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

func TestGetBlobsRejectsNullSidecarsResponse(t *testing.T) {
	stub := newBeaconStub()
	stub.sidecarsBody = "null"
	server := stub.serve(t)

	client, err := NewBeaconClient(server.URL, DefaultRpcTimeout)
	require.NoError(t, err)

	var sidecars []*structs.Sidecar
	require.NotPanics(t, func() {
		sidecars, err = client.GetBlobs(context.Background(), 100)
	})
	require.Nil(t, sidecars)
	require.Error(t, err)
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
