package indexer

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestNewBeaconClient(t *testing.T) {
	testCases := []struct {
		name            string
		beaconURL       string
		genesisResponse interface{}
		specResponse    interface{}
		genesisStatus   int
		specStatus      int
		expectedError   bool
	}{
		{
			name:      "successful NewBeaconClient",
			beaconURL: "https://l1beacon.hekla.taiko.xyz",
			genesisResponse: GenesisResponse{
				Data: GenesisData{GenesisTime: "100"},
			},
			specResponse: GetSpecResponse{
				Data: map[string]string{"SECONDS_PER_SLOT": "10"},
			},
			genesisStatus: http.StatusOK,
			specStatus:    http.StatusOK,
			expectedError: false,
		},
		{
			name:            "error fetching genesis time",
			beaconURL:       "https://l1beacon.hekla.taiko.xyz",
			genesisResponse: "error",
			specResponse: GetSpecResponse{
				Data: map[string]string{"SECONDS_PER_SLOT": "10"},
			},
			genesisStatus: http.StatusInternalServerError,
			specStatus:    http.StatusOK,
			expectedError: true,
		},
		{
			name:      "error fetching seconds per slot",
			beaconURL: "https://l1beacon.hekla.taiko.xyz",
			genesisResponse: GenesisResponse{
				Data: GenesisData{GenesisTime: "100"},
			},
			specResponse:  "error",
			genesisStatus: http.StatusOK,
			specStatus:    http.StatusInternalServerError,
			expectedError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			server := httptest.NewServer(
				http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					var jsonData []byte
					var status int
					switch r.URL.Path {
					case "/eth/v1/beacon/genesis":
						jsonData, _ = json.Marshal(tc.genesisResponse)
						status = tc.genesisStatus
					case "/eth/v1/config/spec":
						jsonData, _ = json.Marshal(tc.specResponse)
						status = tc.specStatus
					default:
						return
					}
					w.WriteHeader(status)
					w.Write(jsonData)
				}))
			defer server.Close()

			cfg := &Config{BeaconURL: server.URL}
			client, err := NewBeaconClient(cfg, time.Second*10)

			if tc.expectedError {
				assert.Error(t, err)
			} else {
				assert.NotNil(t, client)
			}
		})
	}
}

func TestGetBlobs(t *testing.T) {
	testCases := []struct {
		name          string
		blockID       uint64
		response      BlobsResponse
		expectedBlobs []BlobData
		httpStatus    int
		expectedError bool
	}{
		{
			name:    "successful get blob",
			blockID: 123,
			response: BlobsResponse{
				Data: []BlobData{
					{
						Index:         "1",
						Blob:          "00001",
						KzgCommitment: "0x83ae1d",
					},
				},
			},
			expectedBlobs: []BlobData{
				{
					Index:         "1",
					Blob:          "00001",
					KzgCommitment: "0x83ae1d",
				},
			},
			httpStatus:    http.StatusOK,
			expectedError: false,
		},
		{
			name:          "Internal server error",
			blockID:       123,
			httpStatus:    http.StatusInternalServerError,
			expectedError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			server := httptest.NewServer(
				http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					w.WriteHeader(tc.httpStatus)
					if tc.httpStatus == http.StatusOK {
						jsonData, _ := json.Marshal(tc.response)
						w.Write(jsonData)
					}
				}))
			defer server.Close()

			client := &BeaconClient{
				Client:    server.Client(),
				beaconURL: server.URL,
			}

			response, err := client.getBlobs(context.Background(), tc.blockID)
			if tc.expectedError {
				assert.Error(t, err)
			} else {
				assert.Equal(t, tc.expectedBlobs, response.Data)
			}
		})
	}
}

func TestTimeToSlot(t *testing.T) {
	eventTime := time.Now().Unix()
	genesisTime := eventTime - 1000

	testCases := []struct {
		name          string
		client        *BeaconClient
		timestamp     uint64
		expectedSlot  uint64
		expectedError bool
	}{
		{
			name: "Successful if timestamp is after genesis time",
			client: &BeaconClient{
				genesisTime:    uint64(genesisTime),
				secondsPerSlot: 12,
			},
			timestamp:     uint64(eventTime),
			expectedSlot:  1000 / 12,
			expectedError: false,
		},
		{
			name: "Fails if timestamp is before genesis time",
			client: &BeaconClient{
				genesisTime:    uint64(genesisTime),
				secondsPerSlot: 12,
			},
			timestamp:     uint64(genesisTime - 500),
			expectedSlot:  0,
			expectedError: true,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			slot, err := tc.client.timeToSlot(tc.timestamp)

			if tc.expectedError {
				assert.Error(t, err)
			} else {
				assert.Equal(t, tc.expectedSlot, slot)
			}
		})
	}
}
