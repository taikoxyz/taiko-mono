package rpc

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestNewBeaconClientValidatesBeaconSpec(t *testing.T) {
	tests := []struct {
		name      string
		specBody  string
		wantError string
	}{
		{
			name:      "missing field",
			specBody:  `{"data":{"SLOTS_PER_EPOCH":"32"}}`,
			wantError: "invalid beacon spec SECONDS_PER_SLOT",
		},
		{
			name:      "wrong data type",
			specBody:  `{"data":[]}`,
			wantError: "cannot unmarshal array into Go struct field configSpecResponse.data",
		},
		{
			name:      "wrong field type",
			specBody:  `{"data":{"SECONDS_PER_SLOT":12,"SLOTS_PER_EPOCH":"32"}}`,
			wantError: "cannot unmarshal number into Go struct field ConfigSpec.data.SECONDS_PER_SLOT",
		},
		{
			name:      "negative value",
			specBody:  `{"data":{"SECONDS_PER_SLOT":"-1","SLOTS_PER_EPOCH":"32"}}`,
			wantError: "invalid beacon spec SECONDS_PER_SLOT",
		},
		{
			name:      "non decimal value",
			specBody:  `{"data":{"SECONDS_PER_SLOT":"0x10","SLOTS_PER_EPOCH":"32"}}`,
			wantError: "invalid beacon spec SECONDS_PER_SLOT",
		},
		{
			name:      "zero seconds per slot",
			specBody:  `{"data":{"SECONDS_PER_SLOT":"0","SLOTS_PER_EPOCH":"32"}}`,
			wantError: "invalid beacon spec SECONDS_PER_SLOT: must be greater than zero",
		},
		{
			name:      "zero slots per epoch",
			specBody:  `{"data":{"SECONDS_PER_SLOT":"12","SLOTS_PER_EPOCH":"0"}}`,
			wantError: "invalid beacon spec SLOTS_PER_EPOCH: must be greater than zero",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			server := newBeaconClientTestServer(tt.specBody)
			defer server.Close()

			var (
				client *BeaconClient
				err    error
			)
			require.NotPanics(t, func() {
				client, err = NewBeaconClient(server.URL, time.Second)
			})
			require.Nil(t, client)
			require.ErrorContains(t, err, tt.wantError)
		})
	}
}

func TestNewBeaconClientParsesBeaconSpec(t *testing.T) {
	server := newBeaconClientTestServer(`{"data":{"SECONDS_PER_SLOT":"12","SLOTS_PER_EPOCH":"32"}}`)
	defer server.Close()

	client, err := NewBeaconClient(server.URL, time.Second)
	require.NoError(t, err)
	require.Equal(t, uint64(12), client.SecondsPerSlot)
	require.Equal(t, uint64(32), client.SlotsPerEpoch)
	require.Equal(t, uint64(100), client.genesisTime)
}

func newBeaconClientTestServer(specBody string) *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		switch r.URL.Path {
		case genesisRequestURL:
			_, _ = w.Write([]byte(`{"data":{"genesis_time":"100"}}`))
		case getConfigSpecPath:
			_, _ = w.Write([]byte(specBody))
		default:
			http.NotFound(w, r)
		}
	}))
}
