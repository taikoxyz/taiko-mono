package preconfblocks

import (
	"context"
	"encoding/json"
	"math/big"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"
	lru "github.com/hashicorp/golang-lru/v2"
	"github.com/labstack/echo/v4"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/preconf"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

type PreconfBlockAPIServerTestSuite struct {
	testutils.ClientTestSuite
	s *PreconfBlockAPIServer
}

type stubTopicPeerLister struct {
	peers     []peer.ID
	lastTopic string
}

func (s *stubTopicPeerLister) ListPeers(topic string) []peer.ID {
	s.lastTopic = topic
	return s.peers
}

func (s *PreconfBlockAPIServerTestSuite) SetupTest() {
	s.ClientTestSuite.SetupTest()
	server, err := New(
		"*",
		nil,
		common.Address{},
		common.HexToAddress(os.Getenv("TAIKO_ANCHOR")),
		nil,
		s.RPCClient,
		nil,
	)
	s.Nil(err)
	s.s = server
	go func() {
		s.NotPanics(func() {
			log.Error("Start test preconfirmation block server", "error", s.s.Start(uint64(testutils.RandomPort())))
		})
	}()
}

func (s *PreconfBlockAPIServerTestSuite) TestCheckLookaheadHandover() {
	curr := common.HexToAddress("0xAAA0000000000000000000000000000000000000")
	next := common.HexToAddress("0xBBB0000000000000000000000000000000000000")

	la := &Lookahead{
		CurrOperator: curr,
		NextOperator: next,
		CurrRanges: []SlotRange{
			{Start: 0, End: 32}, // Full epoch 0
		},
		NextRanges: []SlotRange{
			{Start: 32, End: 64}, // Next epoch 1
		},
		UpdatedAt: time.Now().UTC(),
	}

	tests := []struct {
		name       string
		globalSlot uint64
		wantErr    error
	}{
		// Inside CurrRanges
		{name: "curr range early slot", globalSlot: 10, wantErr: nil},
		{name: "curr range at handover slot", globalSlot: 28, wantErr: nil},
		{name: "curr range after handover", globalSlot: 30, wantErr: nil},

		// Inside NextRanges (next epoch)
		{name: "next range next epoch", globalSlot: 33, wantErr: nil},

		// Slot outside all ranges
		{name: "outside all ranges", globalSlot: 70, wantErr: errSlotOutsideSequencingWindow},
	}

	for _, tt := range tests {
		s.T().Run(tt.name, func(t *testing.T) {
			s.s.lookahead = la
			s.s.rpc.L1Beacon = &rpc.BeaconClient{
				SlotsPerEpoch: 32,
			}

			s.Equal(tt.wantErr, s.s.CheckLookaheadHandover(tt.globalSlot))
		})
	}
}

func (s *PreconfBlockAPIServerTestSuite) TestCanShutdown() {
	curr := common.HexToAddress("0xAAA0000000000000000000000000000000000000")
	next := common.HexToAddress("0xBBB0000000000000000000000000000000000000")

	la := &Lookahead{
		CurrOperator: curr,
		NextOperator: next,
		CurrRanges:   []SlotRange{{Start: 0, End: 24}},
		NextRanges:   []SlotRange{{Start: 24, End: 32}},
		UpdatedAt:    time.Now().UTC(),
	}
	// Ranges entirely in the future, to exercise the imminence margin.
	laFuture := &Lookahead{
		CurrOperator: curr,
		NextOperator: next,
		CurrRanges:   []SlotRange{{Start: 100, End: 124}},
		NextRanges:   []SlotRange{{Start: 200, End: 208}},
		UpdatedAt:    time.Now().UTC(),
	}

	tests := []struct {
		name         string
		setLookahead bool
		setBeacon    bool
		lookahead    *Lookahead
		globalSlot   uint64
		want         bool
	}{
		{name: "lookahead nil → safe", setLookahead: false, setBeacon: true, globalSlot: 10, want: true},
		{name: "beacon nil → safe", setLookahead: true, setBeacon: false, globalSlot: 10, want: true},
		{name: "slot inside curr range → unsafe", setLookahead: true, setBeacon: true, globalSlot: 10, want: false},
		{name: "slot at curr range boundary start → unsafe", setLookahead: true, setBeacon: true, globalSlot: 0, want: false},
		{
			name:         "slot at curr range boundary end-1 → unsafe",
			setLookahead: true, setBeacon: true, globalSlot: 23, want: false,
		},
		{name: "slot inside next range → unsafe", setLookahead: true, setBeacon: true, globalSlot: 28, want: false},
		{
			name:         "slot at next range boundary end-1 → unsafe",
			setLookahead: true, setBeacon: true, globalSlot: 31, want: false,
		},
		{name: "slot outside both ranges → safe", setLookahead: true, setBeacon: true, globalSlot: 50, want: true},
		{
			name:         "curr range starts beyond margin → safe",
			setLookahead: true, setBeacon: true, lookahead: laFuture,
			globalSlot: 100 - shutdownImminenceMarginSlots - 1, want: true,
		},
		{
			name:         "curr range starts exactly at margin → unsafe",
			setLookahead: true, setBeacon: true, lookahead: laFuture,
			globalSlot: 100 - shutdownImminenceMarginSlots, want: false,
		},
		{
			name:         "slot just before curr range start → unsafe",
			setLookahead: true, setBeacon: true, lookahead: laFuture, globalSlot: 99, want: false,
		},
		{
			name:         "next range starts exactly at margin → unsafe",
			setLookahead: true, setBeacon: true, lookahead: laFuture,
			globalSlot: 200 - shutdownImminenceMarginSlots, want: false,
		},
		{
			name:         "between ranges, both beyond margin → safe",
			setLookahead: true, setBeacon: true, lookahead: laFuture, globalSlot: 150, want: true,
		},
		{
			name:         "past all ranges → safe",
			setLookahead: true, setBeacon: true, lookahead: laFuture, globalSlot: 208, want: true,
		},
	}

	for _, tt := range tests {
		s.T().Run(tt.name, func(t *testing.T) {
			if tt.setLookahead {
				if tt.lookahead != nil {
					s.s.lookahead = tt.lookahead
				} else {
					s.s.lookahead = la
				}
			} else {
				s.s.lookahead = nil
			}
			if tt.setBeacon {
				s.s.rpc.L1Beacon = &rpc.BeaconClient{SlotsPerEpoch: 32}
			} else {
				s.s.rpc.L1Beacon = nil
			}
			s.Equal(tt.want, s.s.CanShutdown(tt.globalSlot))
		})
	}
}

func (s *PreconfBlockAPIServerTestSuite) TestJWTSkipPath() {
	cases := []struct {
		path string
		want bool
	}{
		{"/", true},
		{"/healthz", true},
		{"/status", true},
		{"/preconfBlocks", false},
		{"/ws", false},
		{"/anything-else", false},
		{"", false},
	}

	for _, tc := range cases {
		s.T().Run(tc.path, func(t *testing.T) {
			e := echo.New()
			req := httptest.NewRequest(http.MethodGet, "http://example.com"+tc.path, nil)
			rec := httptest.NewRecorder()
			c := e.NewContext(req, rec)
			c.SetPath(tc.path)
			s.Equal(tc.want, jwtSkipPath(c))
		})
	}
}

func (s *PreconfBlockAPIServerTestSuite) TestTryPutEnvelopeIntoCache() {
	totalCached := s.s.envelopesCache.totalCached
	isForcedInculsion := true
	peerID := new(peer.ID)

	msg := &eth.ExecutionPayloadEnvelope{
		ExecutionPayload: &eth.ExecutionPayload{
			BlockNumber: eth.Uint64Quantity(new(big.Int).SetBytes(testutils.RandomBytes(32)).Uint64()),
			BlockHash:   common.BytesToHash(testutils.RandomBytes(32)),
		},
		Signature:         &[65]byte{},
		IsForcedInclusion: &isForcedInculsion,
	}

	s.s.tryPutEnvelopeIntoCache(msg, *peerID)
	s.Equal(totalCached+1, s.s.envelopesCache.totalCached)

	cached := s.s.envelopesCache.getLatestEnvelope()
	s.NotNil(cached)
	s.Equal(msg.ExecutionPayload.BlockNumber, cached.Payload.BlockNumber)
	s.Equal(msg.ExecutionPayload.BlockHash, cached.Payload.BlockHash)
	s.Equal(*msg.IsForcedInclusion, cached.IsForcedInclusion)
	s.Equal(msg.Signature, cached.Signature)

	s.s.tryPutEnvelopeIntoCache(msg, *peerID)
	s.Equal(totalCached+1, s.s.envelopesCache.totalCached)
}

func TestStatusReportsHighestCachedPayload(t *testing.T) {
	const (
		initialBlockID = uint64(100)
		cachedBlockID  = uint64(101)
	)
	server := &PreconfBlockAPIServer{
		echo:                          echo.New(),
		rpc:                           new(rpc.Client),
		envelopesCache:                newEnvelopeQueue(),
		highestUnsafeL2PayloadBlockID: initialBlockID,
	}
	msg := &eth.ExecutionPayloadEnvelope{
		ExecutionPayload: &eth.ExecutionPayload{
			BlockNumber: eth.Uint64Quantity(cachedBlockID),
			BlockHash:   common.BytesToHash(testutils.RandomBytes(32)),
		},
	}

	server.tryPutEnvelopeIntoCache(msg, peer.ID("remote"))
	server.tryPutEnvelopeIntoCache(&eth.ExecutionPayloadEnvelope{
		ExecutionPayload: &eth.ExecutionPayload{
			BlockNumber: eth.Uint64Quantity(initialBlockID - 1),
			BlockHash:   common.BytesToHash(testutils.RandomBytes(32)),
		},
	}, peer.ID("remote"))

	recorder := httptest.NewRecorder()
	ctx := server.echo.NewContext(httptest.NewRequest(http.MethodGet, "/status", nil), recorder)
	if err := server.GetStatus(ctx); err != nil {
		t.Fatal(err)
	}

	var status Status
	if err := json.Unmarshal(recorder.Body.Bytes(), &status); err != nil {
		t.Fatal(err)
	}
	if status.HighestUnsafeL2PayloadBlockID != cachedBlockID {
		t.Fatalf("highest unsafe L2 payload block ID = %d, want %d", status.HighestUnsafeL2PayloadBlockID, cachedBlockID)
	}
}

func TestImportMissingAncientsDoesNotConsumeRequestWithoutTopicPeers(t *testing.T) {
	requests, err := lru.New[common.Hash, struct{}](maxTrackedPayloads)
	if err != nil {
		t.Fatal(err)
	}
	parentHash := common.HexToHash("0x1234")
	topicPeers := new(stubTopicPeerLister)
	server := &PreconfBlockAPIServer{
		rpc:                 &rpc.Client{L2: &rpc.EthClient{ChainID: big.NewInt(167)}},
		envelopesCache:      newEnvelopeQueue(),
		blockRequestsCache:  requests,
		gossipSubTopicPeers: topicPeers,
	}
	payload := &preconf.Envelope{Payload: &eth.ExecutionPayload{
		BlockNumber: eth.Uint64Quantity(2),
		ParentHash:  parentHash,
	}}

	if err := server.ImportMissingAncientsFromCache(context.Background(), payload, nil); err == nil {
		t.Fatal("expected missing parent error")
	}
	if requests.Contains(parentHash) {
		t.Fatal("request without topic peers was added to the de-duplication cache")
	}
	if topicPeers.lastTopic != "/taiko/167/0/requestPreconfBlocks" {
		t.Fatalf("request topic = %q, want %q", topicPeers.lastTopic, "/taiko/167/0/requestPreconfBlocks")
	}
}

func TestHasPreconfBlockRequestPeers(t *testing.T) {
	server := &PreconfBlockAPIServer{
		rpc: &rpc.Client{L2: &rpc.EthClient{ChainID: big.NewInt(167)}},
		gossipSubTopicPeers: &stubTopicPeerLister{
			peers: []peer.ID{"peer"},
		},
	}

	if !server.hasPreconfBlockRequestPeers() {
		t.Fatal("expected request topic with a connected peer to be ready")
	}
}

func (s *PreconfBlockAPIServerTestSuite) TestShutdown() {
	s.Nil(s.s.Shutdown(context.Background()))
}

func TestPreconfBlockAPIServerTestSuite(t *testing.T) {
	suite.Run(t, new(PreconfBlockAPIServerTestSuite))
}
