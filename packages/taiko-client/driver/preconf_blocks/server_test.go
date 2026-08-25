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
	"github.com/labstack/echo/v4"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/stretchr/testify/suite"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

type PreconfBlockAPIServerTestSuite struct {
	testutils.ClientTestSuite
	s *PreconfBlockAPIServer
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

func (s *PreconfBlockAPIServerTestSuite) TestGetStatusReportsHighestSeen() {
	head, err := s.s.rpc.L2.BlockNumber(context.Background())
	s.Nil(err)

	tests := []struct {
		name             string
		seen             uint64
		imported         uint64
		wantUnsafe       uint64
		wantSyncedWithEE bool
	}{
		{
			name: "in sync", seen: head, imported: head,
			wantUnsafe: head, wantSyncedWithEE: true,
		},
		{
			// The incident: a backlog of cached envelopes the node could not import. Reporting
			// the imported head here is what let a stale node pass a preconfer client's parity
			// check and sequence from a 156-block-stale head.
			name: "behind the network", seen: head + 156, imported: head,
			wantUnsafe: head + 156, wantSyncedWithEE: false,
		},
		{
			// Right after a beacon sync the execution head can run ahead of anything seen over
			// gossip. That is not a backlog, and must not be reported as one.
			name: "ahead of gossip", seen: head / 2, imported: head,
			wantUnsafe: head, wantSyncedWithEE: true,
		},
	}

	for _, tt := range tests {
		s.T().Run(tt.name, func(t *testing.T) {
			s.s.highestSeenL2PayloadBlockID.Store(tt.seen)
			s.s.highestImportedL2PayloadBlockID.Store(tt.imported)

			rec := httptest.NewRecorder()
			c := echo.New().NewContext(httptest.NewRequest(http.MethodGet, "/status", nil), rec)
			s.Nil(s.s.GetStatus(c))
			s.Equal(http.StatusOK, rec.Code)

			var status Status
			s.Nil(json.Unmarshal(rec.Body.Bytes(), &status))

			s.Equal(tt.wantUnsafe, status.HighestUnsafeL2PayloadBlockID)
			s.Equal(tt.imported, status.HighestImportedL2PayloadBlockID)
			s.Equal(tt.wantSyncedWithEE, status.HighestUnsafeL2PayloadBlockID == head)
		})
	}
}

func (s *PreconfBlockAPIServerTestSuite) TestReportedHighestUnsafeL2Payload() {
	tests := []struct {
		name        string
		highestSeen uint64
		head        uint64
		want        uint64
	}{
		{name: "in sync", highestSeen: 100, head: 100, want: 100},
		{name: "behind the network", highestSeen: 256, head: 100, want: 256},
		// Right after a beacon sync the execution head runs ahead of anything seen over gossip.
		// That is not a backlog, and reporting it as one would exit the preconfer client.
		{name: "ahead of gossip", highestSeen: 40, head: 100, want: 100},
		// A payload further ahead than the envelope cache can bridge would otherwise keep the
		// node reporting itself out of sync forever.
		{name: "runaway block number", highestSeen: 1 << 40, head: 100, want: 100 + maxTrackedPayloads},
		{name: "exactly at the cap", highestSeen: 100 + maxTrackedPayloads, head: 100, want: 100 + maxTrackedPayloads},
	}

	for _, tt := range tests {
		s.T().Run(tt.name, func(t *testing.T) {
			s.Equal(tt.want, reportedHighestUnsafeL2Payload(tt.highestSeen, tt.head))
		})
	}
}

func (s *PreconfBlockAPIServerTestSuite) TestUpdateHighestSeenL2PayloadIsMonotonic() {
	s.s.highestSeenL2PayloadBlockID.Store(100)

	s.s.updateHighestSeenL2Payload(150)
	s.Equal(uint64(150), s.s.highestSeenL2PayloadBlockID.Load())

	// A late or out-of-order envelope never drags it back; only a proposal reorg does.
	s.s.updateHighestSeenL2Payload(120)
	s.Equal(uint64(150), s.s.highestSeenL2PayloadBlockID.Load())
}

func (s *PreconfBlockAPIServerTestSuite) TestShutdown() {
	s.Nil(s.s.Shutdown(context.Background()))
}

func TestPreconfBlockAPIServerTestSuite(t *testing.T) {
	suite.Run(t, new(PreconfBlockAPIServerTestSuite))
}
