package indexer

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"time"

	"golang.org/x/exp/slog"
)

var (
	blobURL    = "eth/v1/beacon/blob_sidecars"
	genesisURL = "eth/v1/beacon/genesis"
	configURL  = "eth/v1/config/spec"
)

type GetSpecResponse struct {
	Data map[string]string `json:"data"`
}

type GenesisResponse struct {
	Data struct {
		GenesisTime string `json:"genesis_time"`
	} `json:"data"`
}

type BeaconClient struct {
	*http.Client
	beaconURL      string
	genesisTime    uint64
	secondsPerSlot uint64
}

type BlobsResponse struct {
	Data []struct {
		Index            string `json:"index"`
		Blob             string `json:"blob"`
		KzgCommitment    string `json:"kzg_commitment"`
		KzgCommitmentHex []byte `json:"-"`
	} `json:"data"`
}

func NewBeaconClient(cfg *Config, timeout time.Duration) (*BeaconClient, error) {
	httpClient := &http.Client{Timeout: timeout}

	// Get the genesis time.
	url := fmt.Sprintf("%s/%s", cfg.BeaconURL, genesisURL)
	genesisTime, err := getGenesisTime(url, httpClient)
	if err != nil {
		return nil, fmt.Errorf("failed to get genesis time: %v", err)
	}

	url = fmt.Sprintf("%s/%s", cfg.BeaconURL, configURL)
	// Get the seconds per slot.
	secondsPerSlot, err := getConfigValue(url, "SECONDS_PER_SLOT", httpClient)
	if err != nil {
		return nil, fmt.Errorf("failed to get SECONDS_PER_SLOT: %v", err)
	}

	secondsPerSlotUint64, err := strconv.ParseUint(secondsPerSlot, 10, 64)
	if err != nil {
		return nil, err
	}

	slog.Info("beaconClientInfo", "secondsPerSlot", secondsPerSlotUint64, "genesisTime", genesisTime)

	return &BeaconClient{
		beaconURL:      cfg.BeaconURL,
		genesisTime:    genesisTime,
		secondsPerSlot: secondsPerSlotUint64,
	}, nil
}

func getGenesisTime(endpoint string, client *http.Client) (uint64, error) {
	res, err := client.Get(endpoint)
	if err != nil {
		return 0, err
	}
	defer res.Body.Close()

	var genesisDetail GenesisResponse
	if err := json.NewDecoder(res.Body).Decode(&genesisDetail); err != nil {
		return 0, err
	}

	return strconv.ParseUint(genesisDetail.Data.GenesisTime, 10, 64)
}

func getConfigValue(endpoint, key string, client *http.Client) (string, error) {
	res, err := client.Get(endpoint)
	if err != nil {
		return "", err
	}
	defer res.Body.Close()

	var spec GetSpecResponse
	if err := json.NewDecoder(res.Body).Decode(&spec); err != nil {
		return "", err
	}

	value, ok := spec.Data[key]
	if !ok {
		return "", fmt.Errorf("key %s not found in config spec", key)
	}

	return value, nil
}

func (c *BeaconClient) getBlobs(ctx context.Context, blockID uint64) (*BlobsResponse, error) {
	url := fmt.Sprintf("%s/%s/%v", c.beaconURL, blobURL, blockID)
	response, err := http.Get(url)
	if err != nil {
		return nil, err
	}
	defer response.Body.Close()

	body, err := io.ReadAll(response.Body)
	if err != nil {
		return nil, err
	}

	var responseData BlobsResponse
	if err := json.Unmarshal(body, &responseData); err != nil {
		return nil, err
	}

	return &responseData, nil
}

func (c *BeaconClient) timeToSlot(timestamp uint64) (uint64, error) {
	if timestamp < c.genesisTime {
		return 0, fmt.Errorf("provided timestamp (%v) precedes genesis time (%v)", timestamp, c.genesisTime)
	}
	return (timestamp - c.genesisTime) / c.secondsPerSlot, nil
}
