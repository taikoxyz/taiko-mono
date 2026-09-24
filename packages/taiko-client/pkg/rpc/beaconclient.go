package rpc

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"math/big"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"
	"github.com/pkg/errors"
	"github.com/prysmaticlabs/prysm/v5/api/client"
	"github.com/prysmaticlabs/prysm/v5/api/client/beacon"
)

var (
	// Request urls.
	blobsRequestURL   = "/eth/v1/beacon/blobs/%d"
	genesisRequestURL = "/eth/v1/beacon/genesis"
	getConfigSpecPath = "/eth/v1/config/spec"
	beaconBlockBySlot = "/eth/v2/beacon/blocks/%d"
)

// blobsResponse is the response from the beacon node for fetching blobs.
type blobsResponse struct {
	Data []*eth.Blob `json:"data"`
}

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

	secondsPerSlot, err := parseBeaconDurationSeconds("SECONDS_PER_SLOT", spec.SecondsPerSlot)
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

// parseBeaconUint64 parses a decimal uint64 value from a beacon node response. The Beacon API
// serialises these values as base-10 uint64 strings, so anything else is rejected.
func parseBeaconUint64(name, value string) (uint64, error) {
	if value == "" {
		return 0, fmt.Errorf("beacon node response is missing %s", name)
	}
	parsed, err := strconv.ParseUint(value, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("invalid %s in beacon node response: %w", name, err)
	}
	return parsed, nil
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

// maxBeaconDurationSeconds is the largest number of seconds that still converts into a positive
// time.Duration. Above it the product silently wraps: `time.Second * time.Duration(1<<63)` is zero
// and `time.Second * time.Duration(math.MaxUint64)` is negative, either of which panics the
// `time.NewTicker` call that derives the driver's lookahead interval from SECONDS_PER_SLOT.
const maxBeaconDurationSeconds = uint64(math.MaxInt64 / int64(time.Second))

// parseBeaconDurationSeconds is parseBeaconPositiveUint64 for values that are later converted into
// a time.Duration of seconds.
func parseBeaconDurationSeconds(name, value string) (uint64, error) {
	parsed, err := parseBeaconPositiveUint64(name, value)
	if err != nil {
		return 0, err
	}
	if parsed > maxBeaconDurationSeconds {
		return 0, fmt.Errorf(
			"invalid %s in beacon node response: must be at most %d seconds, got %d",
			name,
			maxBeaconDurationSeconds,
			parsed,
		)
	}
	return parsed, nil
}

// GetBlobs returns the blobs with the given versioned hashes, in the same order, from the beacon block at the
// slot of the given timestamp. Beacon nodes return blobs without their KZG commitments, in block order per the
// spec (Lighthouse keeps the request order instead), so every returned blob is matched to a versioned hash by
// recomputing its commitment: a beacon node can make this call fail, but it cannot make it return a blob that
// does not match the requested versioned hash.
func (c *BeaconClient) GetBlobs(ctx context.Context, timestamp uint64, blobHashes []common.Hash) ([]*eth.Blob, error) {
	if len(blobHashes) == 0 {
		return nil, nil
	}

	ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, c.timeout)
	defer cancel()

	slot, err := c.timeToSlot(timestamp)
	if err != nil {
		return nil, err
	}

	// The endpoint takes unique versioned hashes, while a proposal may reference the same blob twice.
	uniqueHashes := make([]common.Hash, 0, len(blobHashes))
	seen := make(map[common.Hash]struct{}, len(blobHashes))
	for _, blobHash := range blobHashes {
		if _, ok := seen[blobHash]; !ok {
			seen[blobHash] = struct{}{}
			uniqueHashes = append(uniqueHashes, blobHash)
		}
	}

	blobs, err := c.getBlobs(ctxWithTimeout, slot, uniqueHashes)
	if err != nil {
		return nil, err
	}
	return matchBlobs(blobs, blobHashes)
}

// getBlobs fetches the blobs with the given versioned hashes from the beacon block at the given slot.
func (c *BeaconClient) getBlobs(ctx context.Context, slot uint64, blobHashes []common.Hash) ([]*eth.Blob, error) {
	query := url.Values{}
	for _, blobHash := range blobHashes {
		query.Add("versioned_hashes", blobHash.Hex())
	}

	// client.Get escapes a query string into the path, so the request is built here.
	requestURL := c.BaseURL().ResolveReference(&url.URL{
		Path:     c.BaseURL().Path + fmt.Sprintf(blobsRequestURL, slot),
		RawQuery: query.Encode(),
	})
	// A nil body, unlike http.NoBody, lets RateLimitedTransport retry the request on 429.
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, requestURL.String(), nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/json")

	res, err := c.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return nil, client.Non200Err(res)
	}

	resBytes, err := io.ReadAll(io.LimitReader(res.Body, client.MaxBodySize))
	if err != nil {
		return nil, fmt.Errorf("failed to read beacon blobs response: %w", err)
	}

	var blobs blobsResponse
	if err := json.Unmarshal(resBytes, &blobs); err != nil {
		return nil, fmt.Errorf("failed to decode beacon blobs response: %w", err)
	}
	if blobs.Data == nil {
		return nil, errors.New("beacon blobs response is missing data")
	}
	for _, blob := range blobs.Data {
		if blob == nil {
			return nil, errors.New("beacon blobs response contains a null blob")
		}
	}

	return blobs.Data, nil
}

// matchBlobs returns, for each of the given versioned hashes, the blob whose KZG commitment hashes to it.
func matchBlobs(blobs []*eth.Blob, blobHashes []common.Hash) ([]*eth.Blob, error) {
	byHash := make(map[common.Hash]*eth.Blob, len(blobs))
	for _, blob := range blobs {
		commitment, err := blob.ComputeKZGCommitment()
		if err != nil {
			return nil, fmt.Errorf("failed to compute KZG commitment of beacon blob: %w", err)
		}
		byHash[eth.KZGToVersionedHash(commitment)] = blob
	}

	matched := make([]*eth.Blob, 0, len(blobHashes))
	for _, blobHash := range blobHashes {
		blob, ok := byHash[blobHash]
		if !ok {
			return nil, fmt.Errorf("beacon node did not return blob %s", blobHash)
		}
		matched = append(matched, blob)
	}

	return matched, nil
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
