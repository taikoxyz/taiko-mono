package rpc

import (
	"context"
	"encoding/json"
	"fmt"
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
)

// ConfigSpec is the config spec of the beacon node.
type ConfigSpec struct {
	SecondsPerSlot string `json:"SECONDS_PER_SLOT"`
	SlotsPerEpoch  string `json:"SLOTS_PER_EPOCH"`
}

// GenesisResponse is the response from the beacon node for fetching the genesis time.
type GenesisResponse struct {
	Data struct {
		GenesisTime string `json:"genesis_time"`
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
	cli, err := beacon.NewClient(strings.TrimSuffix(endpoint, "/"), client.WithTimeout(timeout))
	if err != nil {
		return nil, err
	}

	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	// Get the genesis time.
	var genesisDetail *GenesisResponse
	resBytes, err := cli.Get(ctx, cli.BaseURL().Path+genesisRequestURL)
	if err != nil {
		return nil, err
	}

	if err := json.Unmarshal(resBytes, &genesisDetail); err != nil {
		return nil, err
	}

	genesisTime, err := strconv.Atoi(genesisDetail.Data.GenesisTime)
	if err != nil {
		return nil, err
	}

	// Get the seconds per slot.
	spec, err := getConfigSpec(ctx, cli)
	if err != nil {
		return nil, err
	}

	secondsPerSlot, err := strconv.Atoi(spec.Data.(map[string]interface{})["SECONDS_PER_SLOT"].(string))
	if err != nil {
		return nil, err
	}

	slotsPerEpoch, err := strconv.Atoi(spec.Data.(map[string]interface{})["SLOTS_PER_EPOCH"].(string))
	if err != nil {
		return nil, err
	}

	log.Info(
		"L1 beacon info",
		"secondsPerSlot", secondsPerSlot,
		"slotsPerEpoch", slotsPerEpoch,
		"genesisTime", genesisTime,
	)

	return &BeaconClient{cli, timeout, uint64(genesisTime), uint64(secondsPerSlot), uint64(slotsPerEpoch)}, nil
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

	var sidecars *structs.SidecarsResponse
	if err = json.Unmarshal(resBytes, &sidecars); err != nil {
		return nil, err
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

// EpochOfTimestamp converts a unix timestamp into the L1 epoch number
// using the beacon chain genesis time and slot configuration.
func (c *BeaconClient) EpochOfTimestamp(ts uint64) (uint64, error) {
	slot, err := c.timeToSlot(ts)
	if err != nil {
		return 0, err
	}
	return slot / c.SlotsPerEpoch, nil
}

// getConfigSpec retrieve the current configs of the network used by the beacon node.
func getConfigSpec(ctx context.Context, c *beacon.Client) (*structs.GetSpecResponse, error) {
	body, err := c.Get(ctx, c.BaseURL().Path+getConfigSpecPath)
	if err != nil {
		return nil, errors.Wrap(err, "error requesting configSpecPath")
	}
	fsr := &structs.GetSpecResponse{}
	err = json.Unmarshal(body, fsr)
	if err != nil {
		return nil, err
	}
	return fsr, nil
}
