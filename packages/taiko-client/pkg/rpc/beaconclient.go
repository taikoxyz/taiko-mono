package rpc

import (
	"context"
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/ethereum/go-ethereum/log"
	"github.com/pkg/errors"
	"github.com/prysmaticlabs/prysm/v5/api/client"
	"github.com/prysmaticlabs/prysm/v5/api/client/beacon"
	"github.com/prysmaticlabs/prysm/v5/api/server/structs"
)

var (
	// Request urls.
	sidecarsRequestURL = "/eth/v1/beacon/blob_sidecars/%d"
	genesisRequestURL  = "/eth/v1/beacon/genesis"
	getConfigSpecPath  = "/eth/v1/config/spec"
	beaconBlockBySlot  = "/eth/v2/beacon/blocks/%d"
)

// ConfigSpec is the config spec of the beacon node.
type ConfigSpec struct {
	SecondsPerSlot string `json:"SECONDS_PER_SLOT"`
	SlotsPerEpoch  string `json:"SLOTS_PER_EPOCH"`
}

// configSpecResponse is the response from the beacon node for fetching the config spec.
type configSpecResponse struct {
	Data ConfigSpec `json:"data"`
}

// GenesisResponse is the response from the beacon node for fetching the genesis time.
type GenesisResponse struct {
	Data struct {
		GenesisTime string `json:"genesis_time"`
	} `json:"data"`
}

// beaconBlockResponse is the response from the beacon node for fetching a beacon block.
type beaconBlockResponse struct {
	Data struct {
		Message struct {
			Body struct {
				ExecutionPayload *struct {
					BlockNumber string `json:"block_number"`
				} `json:"execution_payload"`
				ExecutionPayloadHeader *struct {
					BlockNumber string `json:"block_number"`
				} `json:"execution_payload_header"`
			} `json:"body"`
		} `json:"message"`
	} `json:"data"`
}

// BeaconClient is a client for the beacon node.
type BeaconClient struct {
	*beacon.Client
	timeout        time.Duration
	genesisTime    uint64
	SecondsPerSlot uint64
	SlotsPerEpoch  uint64
}

// NewBeaconClient returns a new beacon client.
func NewBeaconClient(endpoint string, timeout time.Duration) (*BeaconClient, error) {
	rateLimitedTransport := NewRateLimitedTransport(http.DefaultTransport, RateLimitMaxRetries)

	cli, err := beacon.NewClient(
		strings.TrimSuffix(endpoint, "/"),
		client.WithTimeout(timeout),
		client.WithRoundTripper(rateLimitedTransport),
	)
	if err != nil {
		return nil, err
	}

	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	// Get the genesis time.
	var genesisDetail GenesisResponse
	resBytes, err := cli.Get(ctx, cli.BaseURL().Path+genesisRequestURL)
	if err != nil {
		return nil, err
	}

	if err := json.Unmarshal(resBytes, &genesisDetail); err != nil {
		return nil, fmt.Errorf("failed to decode beacon genesis response: %w", err)
	}

	genesisTime, err := parseBeaconUint64("genesis_time", genesisDetail.Data.GenesisTime)
	if err != nil {
		return nil, err
	}

	// Get the seconds per slot and the slots per epoch.
	spec, err := getConfigSpec(ctx, cli)
	if err != nil {
		return nil, err
	}

	secondsPerSlot, err := parseBeaconPositiveUint64("SECONDS_PER_SLOT", spec.SecondsPerSlot)
	if err != nil {
		return nil, err
	}

	slotsPerEpoch, err := parseBeaconPositiveUint64("SLOTS_PER_EPOCH", spec.SlotsPerEpoch)
	if err != nil {
		return nil, err
	}

	log.Info(
		"L1 beacon info",
		"secondsPerSlot", secondsPerSlot,
		"slotsPerEpoch", slotsPerEpoch,
		"genesisTime", genesisTime,
	)

	return &BeaconClient{cli, timeout, genesisTime, secondsPerSlot, slotsPerEpoch}, nil
}

// parseBeaconUint64 parses a decimal value from a beacon node response. The value must be a
// non-negative integer that fits in an int64, since callers feed it into time.Duration arithmetic.
func parseBeaconUint64(name, value string) (uint64, error) {
	if value == "" {
		return 0, fmt.Errorf("beacon node response is missing %s", name)
	}
	parsed, err := strconv.ParseInt(value, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("invalid %s in beacon node response: %w", name, err)
	}
	if parsed < 0 {
		return 0, fmt.Errorf("invalid %s in beacon node response: must not be negative, got %s", name, value)
	}
	return uint64(parsed), nil
}

// parseBeaconPositiveUint64 is parseBeaconUint64 for values that are later used as divisors.
func parseBeaconPositiveUint64(name, value string) (uint64, error) {
	parsed, err := parseBeaconUint64(name, value)
	if err != nil {
		return 0, err
	}
	if parsed == 0 {
		return 0, fmt.Errorf("invalid %s in beacon node response: must be greater than zero", name)
	}
	return parsed, nil
}

// GetBlobs returns the sidecars for a given slot.
func (c *BeaconClient) GetBlobs(ctx context.Context, time uint64) ([]*structs.Sidecar, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	slot, err := c.timeToSlot(time)
	if err != nil {
		return nil, err
	}
	resBytes, err := c.Get(ctxWithTimeout, c.BaseURL().Path+fmt.Sprintf(sidecarsRequestURL, slot))
	if err != nil {
		return nil, err
	}

	var sidecars structs.SidecarsResponse
	if err = json.Unmarshal(resBytes, &sidecars); err != nil {
		return nil, fmt.Errorf("failed to decode beacon blob sidecars response: %w", err)
	}
	if sidecars.Data == nil {
		return nil, errors.New("beacon blob sidecars response is missing data")
	}

	return sidecars.Data, nil
}

// timeToSlot returns the slots of the given timestamp.
func (c *BeaconClient) timeToSlot(timestamp uint64) (uint64, error) {
	if timestamp < c.genesisTime {
		return 0, fmt.Errorf("provided timestamp (%v) precedes genesis time (%v)", timestamp, c.genesisTime)
	}
	return (timestamp - c.genesisTime) / c.SecondsPerSlot, nil
}

func (c *BeaconClient) CurrentSlot() uint64 {
	return (uint64(time.Now().UTC().Unix()) - c.genesisTime) / c.SecondsPerSlot
}

func (c *BeaconClient) CurrentEpoch() uint64 {
	return c.CurrentSlot() / c.SlotsPerEpoch
}

func (c *BeaconClient) SlotInEpoch() uint64 {
	return c.CurrentSlot() % c.SlotsPerEpoch
}

func (c *BeaconClient) TimestampOfSlot(slot uint64) uint64 {
	return c.genesisTime + slot*c.SecondsPerSlot
}

// ExecutionBlockNumberByTimestamp returns the execution layer block number whose timestamp is
// greater than or equal to the provided timestamp by walking backwards through beacon slots.
func (c *BeaconClient) ExecutionBlockNumberByTimestamp(ctx context.Context, timestamp uint64) (*big.Int, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	slot, err := c.timeToSlot(timestamp)
	if err != nil {
		return nil, fmt.Errorf("failed to convert timestamp to slot: %w", err)
	}

	return c.executionBlockNumberBySlot(ctxWithTimeout, slot)
}

// executionBlockNumberBySlot fetches the execution block number for a specific beacon slot.
func (c *BeaconClient) executionBlockNumberBySlot(ctx context.Context, slot uint64) (*big.Int, error) {
	body, err := c.Get(ctx, c.BaseURL().Path+fmt.Sprintf(beaconBlockBySlot, slot))
	if err != nil {
		return nil, fmt.Errorf("failed to fetch beacon block for slot %d: %w", slot, err)
	}

	var resp beaconBlockResponse
	if err := json.Unmarshal(body, &resp); err != nil {
		return nil, fmt.Errorf("failed to unmarshal beacon block response for slot %d: %w", slot, err)
	}

	var blockNumberStr string
	switch {
	case resp.Data.Message.Body.ExecutionPayload != nil:
		blockNumberStr = resp.Data.Message.Body.ExecutionPayload.BlockNumber
	case resp.Data.Message.Body.ExecutionPayloadHeader != nil:
		blockNumberStr = resp.Data.Message.Body.ExecutionPayloadHeader.BlockNumber
	default:
		return nil, client.ErrNotFound
	}

	blockNumber, err := strconv.ParseUint(blockNumberStr, 10, 64)
	if err != nil {
		return nil, fmt.Errorf("failed to parse execution block number: %w", err)
	}

	return new(big.Int).SetUint64(blockNumber), nil
}

// getConfigSpec retrieves the current configs of the network used by the beacon node.
func getConfigSpec(ctx context.Context, c *beacon.Client) (*ConfigSpec, error) {
	body, err := c.Get(ctx, c.BaseURL().Path+getConfigSpecPath)
	if err != nil {
		return nil, errors.Wrap(err, "error requesting configSpecPath")
	}
	var spec configSpecResponse
	if err := json.Unmarshal(body, &spec); err != nil {
		return nil, fmt.Errorf("failed to decode beacon config spec response: %w", err)
	}
	return &spec.Data, nil
}
