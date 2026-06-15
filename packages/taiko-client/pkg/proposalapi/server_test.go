package proposalapi

import (
	"context"
	"encoding/json"
	"errors"
	"math/big"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

type fakeProposalSource struct {
	response *ProposalResponse
	err      error
	seenID   *big.Int
}

func (s *fakeProposalSource) ProposalByID(_ context.Context, id *big.Int) (*ProposalResponse, error) {
	s.seenID = new(big.Int).Set(id)
	return s.response, s.err
}

func TestValidateLoopbackAddress(t *testing.T) {
	t.Parallel()

	for _, addr := range []string{"127.0.0.1:9876", "localhost:9876", "[::1]:9876"} {
		if err := ValidateLoopbackAddress(addr); err != nil {
			t.Fatalf("expected %q to be accepted: %v", addr, err)
		}
	}

	for _, addr := range []string{":9876", "0.0.0.0:9876", "192.0.2.1:9876", "bad-address"} {
		if err := ValidateLoopbackAddress(addr); err == nil {
			t.Fatalf("expected %q to be rejected", addr)
		}
	}
}

func TestNewRPCSourceRequiresProposalLookupClients(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name   string
		client *rpc.Client
	}{
		{name: "nil client"},
		{name: "missing L1", client: &rpc.Client{}},
		{
			name: "missing L2",
			client: &rpc.Client{
				L1:            &rpc.EthClient{},
				ShastaClients: &rpc.ShastaClients{Inbox: &shastaBindings.ShastaInboxClient{}},
			},
		},
		{
			name: "missing L2 engine",
			client: &rpc.Client{
				L1:            &rpc.EthClient{},
				L2:            &rpc.EthClient{},
				ShastaClients: &rpc.ShastaClients{Inbox: &shastaBindings.ShastaInboxClient{}},
			},
		},
		{
			name: "missing inbox",
			client: &rpc.Client{
				L1:            &rpc.EthClient{},
				L2:            &rpc.EthClient{},
				L2Engine:      &rpc.EngineClient{},
				ShastaClients: &rpc.ShastaClients{},
			},
		},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			t.Parallel()
			if _, err := NewRPCSource(test.client); err == nil {
				t.Fatalf("expected NewRPCSource to reject %s", test.name)
			}
		})
	}
}

func TestGetProposalRejectsInvalidID(t *testing.T) {
	t.Parallel()

	server, err := New("127.0.0.1:0", &fakeProposalSource{})
	if err != nil {
		t.Fatalf("new server: %v", err)
	}

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/internal/shasta/proposals/not-a-number", nil)

	server.Handler().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusBadRequest {
		t.Fatalf("expected status %d, got %d", http.StatusBadRequest, recorder.Code)
	}
}

func TestGetProposalReturnsMetadata(t *testing.T) {
	t.Parallel()

	source := &fakeProposalSource{response: &ProposalResponse{
		ProposalHash: "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
		Proposal: Proposal{
			ID:                             42,
			Timestamp:                      1000,
			EndOfSubmissionWindowTimestamp: 1100,
			Proposer:                       "0x1111111111111111111111111111111111111111",
			ParentProposalHash:             "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
			OriginBlockNumber:              999,
			OriginBlockHash:                "0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
			BasefeeSharingPctg:             1,
			Sources: []DerivationSource{{
				IsForcedInclusion: true,
				BlobSlice: BlobSlice{
					BlobHashes: []string{
						"0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
					},
					Offset:    12,
					Timestamp: 990,
				},
			}},
		},
		Event: ProposalEvent{
			BlockNumber: 999,
			BlockHash:   "0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
			TxHash:      "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
			LogIndex:    3,
		},
	}}
	server, err := New("127.0.0.1:0", source)
	if err != nil {
		t.Fatalf("new server: %v", err)
	}

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/internal/shasta/proposals/42", nil)

	server.Handler().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected status %d, got %d: %s", http.StatusOK, recorder.Code, recorder.Body.String())
	}
	if source.seenID == nil || source.seenID.Uint64() != 42 {
		t.Fatalf("expected source to see proposal ID 42, got %v", source.seenID)
	}

	var response ProposalResponse
	if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if response.ProposalHash != source.response.ProposalHash {
		t.Fatalf("unexpected proposal hash: %s", response.ProposalHash)
	}
	if response.Proposal.ID != 42 {
		t.Fatalf("unexpected proposal ID: %d", response.Proposal.ID)
	}
	if len(response.Proposal.Sources) != 1 || len(response.Proposal.Sources[0].BlobSlice.BlobHashes) != 1 {
		t.Fatalf("expected source blob hashes to be encoded: %+v", response.Proposal.Sources)
	}
}

func TestGetProposalMapsNotFound(t *testing.T) {
	t.Parallel()

	server, err := New("127.0.0.1:0", &fakeProposalSource{err: ErrProposalNotFound})
	if err != nil {
		t.Fatalf("new server: %v", err)
	}

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/internal/shasta/proposals/7", nil)

	server.Handler().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusNotFound {
		t.Fatalf("expected status %d, got %d", http.StatusNotFound, recorder.Code)
	}
}

func TestGetProposalMapsSourceErrors(t *testing.T) {
	t.Parallel()

	server, err := New("127.0.0.1:0", &fakeProposalSource{err: errors.New("rpc unavailable")})
	if err != nil {
		t.Fatalf("new server: %v", err)
	}

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/internal/shasta/proposals/7", nil)

	server.Handler().ServeHTTP(recorder, request)

	if recorder.Code != http.StatusBadGateway {
		t.Fatalf("expected status %d, got %d", http.StatusBadGateway, recorder.Code)
	}
}

func TestShutdownFallsBackToCloseWhenContextIsCanceled(t *testing.T) {
	t.Parallel()

	httpServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	}))
	defer httpServer.Close()

	server := &Server{server: httpServer.Config}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	if err := server.Shutdown(ctx); err != nil {
		t.Fatalf("shutdown with canceled context: %v", err)
	}

	if response, err := http.Get(httpServer.URL); err == nil {
		_ = response.Body.Close()
		t.Fatalf("expected server to be closed")
	}
}

func TestBuildProposalResponse(t *testing.T) {
	t.Parallel()

	var (
		parentProposalHash = common.HexToHash("0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
		eventBlockHash     = common.HexToHash("0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc")
		originBlockHash    = common.HexToHash("0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")
		txHash             = common.HexToHash("0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee")
		blobHash           = common.HexToHash("0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd")
		proposalHash       = common.HexToHash("0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
		proposer           = common.HexToAddress("0x1111111111111111111111111111111111111111")
	)

	event := &shastaBindings.ShastaInboxClientProposed{
		Id:                             big.NewInt(42),
		Proposer:                       proposer,
		ParentProposalHash:             parentProposalHash,
		EndOfSubmissionWindowTimestamp: big.NewInt(1100),
		BasefeeSharingPctg:             3,
		Sources: []shastaBindings.IInboxDerivationSource{{
			IsForcedInclusion: true,
			BlobSlice: shastaBindings.LibBlobsBlobSlice{
				BlobHashes: [][32]byte{blobHash},
				Offset:     big.NewInt(12),
				Timestamp:  big.NewInt(990),
			},
		}},
		Raw: types.Log{
			BlockNumber: 1000,
			BlockHash:   eventBlockHash,
			TxHash:      txHash,
			Index:       7,
		},
	}
	header := &types.Header{
		Number:     big.NewInt(1000),
		ParentHash: originBlockHash,
		Time:       1000,
	}

	response, err := buildProposalResponse(event, header, proposalHash)
	if err != nil {
		t.Fatalf("build response: %v", err)
	}

	if response.ProposalHash != proposalHash.Hex() {
		t.Fatalf("unexpected proposal hash: %s", response.ProposalHash)
	}
	if response.Proposal.ID != 42 {
		t.Fatalf("unexpected proposal ID: %d", response.Proposal.ID)
	}
	if response.Proposal.Timestamp != 1000 {
		t.Fatalf("unexpected proposal timestamp: %d", response.Proposal.Timestamp)
	}
	if response.Proposal.OriginBlockNumber != 999 || response.Proposal.OriginBlockHash != originBlockHash.Hex() {
		t.Fatalf("unexpected origin: %+v", response.Proposal)
	}
	if response.Event.BlockNumber != 1000 || response.Event.BlockHash != eventBlockHash.Hex() {
		t.Fatalf("unexpected event block: %+v", response.Event)
	}
	if response.Event.LogIndex != 7 || response.Event.TxHash != txHash.Hex() {
		t.Fatalf("unexpected event: %+v", response.Event)
	}
	if len(response.Proposal.Sources) != 1 {
		t.Fatalf("expected one source, got %d", len(response.Proposal.Sources))
	}
	if response.Proposal.Sources[0].BlobSlice.BlobHashes[0] != blobHash.Hex() {
		t.Fatalf("unexpected blob hash: %+v", response.Proposal.Sources[0].BlobSlice.BlobHashes)
	}
}
