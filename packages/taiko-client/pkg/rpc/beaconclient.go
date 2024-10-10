package rpc

import (
	"context"
	"encoding/json"
	"fmt"
	"math/big"
	"strconv"
	"strings"
	"time"

	"github.com/ethereum/go-ethereum/log"
	"github.com/prysmaticlabs/prysm/v5/api/client"
	"github.com/prysmaticlabs/prysm/v5/api/client/beacon"
	"github.com/prysmaticlabs/prysm/v5/api/server/structs"
)

var (
	// Request urls.
	sidecarsRequestURL = "/eth/v1/beacon/blob_sidecars/%d"
	genesisRequestURL  = "/eth/v1/beacon/genesis"
	proposerDutiesURL  = "/eth/v1/validator/duties/proposer/%d"
)

type ConfigSpec struct {
	SecondsPerSlot string `json:"SECONDS_PER_SLOT"`
}

// ProposerDuty represents a single proposer duty
type ProposerDuty struct {
	Pubkey         string `json:"pubkey"`
	ValidatorIndex string `json:"validator_index"`
	Slot           string `json:"slot"`
}

// ProposerDutiesResponse represents the API response structure
type ProposerDutiesResponse struct {
	Data []ProposerDuty `json:"data"`
}

type GenesisResponse struct {
	Data struct {
		GenesisTime string `json:"genesis_time"`
	} `json:"data"`
}

type BeaconClient struct {
	*beacon.Client

	timeout        time.Duration
	genesisTime    uint64
	secondsPerSlot uint64
	slotsPerEpoch  uint64
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

	log.Info("L1 genesis time", "time", genesisTime)

	// Get the seconds per slot.
	spec, err := cli.GetConfigSpec(ctx)
	if err != nil {
		return nil, err
	}

	secondsPerSlot, err := strconv.Atoi(spec.Data.(map[string]interface{})["SECONDS_PER_SLOT"].(string))
	if err != nil {
		return nil, err
	}

	log.Info("L1 seconds per slot", "seconds", secondsPerSlot)

	slotsPerEpoch := 32

	return &BeaconClient{
		cli,
		timeout,
		uint64(genesisTime),
		uint64(secondsPerSlot),
		uint64(slotsPerEpoch),
	}, nil
}

func (c *BeaconClient) GetGenesisTime() uint64 {
	return c.genesisTime
}

func (c *BeaconClient) GetSecondsPerSlot() uint64 {
	return c.secondsPerSlot
}

func (c *BeaconClient) GetGenesisSlot() uint64 {
	return 0
}

func (c *BeaconClient) GetSlotsPerEpoch() uint64 {
	return c.slotsPerEpoch
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

func (c *BeaconClient) GetProposerDuties(ctx context.Context, epoch *big.Int) ([]ProposerDuty, error) {
	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	resBytes, err := c.Get(ctxWithTimeout, c.BaseURL().Path+fmt.Sprintf(proposerDutiesURL, epoch.Uint64()))
	if err != nil {
		return nil, err
	}

	var duties ProposerDutiesResponse
	if err = json.Unmarshal(resBytes, &duties); err != nil {
		return nil, err
	}

	return duties.Data, nil
}

// timeToSlot returns the slots of the given timestamp.
func (c *BeaconClient) timeToSlot(timestamp uint64) (uint64, error) {
	if timestamp < c.genesisTime {
		return 0, fmt.Errorf("provided timestamp (%v) precedes genesis time (%v)", timestamp, c.genesisTime)
	}
	return (timestamp - c.genesisTime) / c.secondsPerSlot, nil
}
