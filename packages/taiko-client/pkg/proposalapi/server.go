package proposalapi

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"net"
	"net/http"
	"strings"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"

	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

const (
	defaultReadHeaderTimeout = 5 * time.Second
	proposalPathPrefix       = "/internal/shasta/proposals/"
)

var ErrProposalNotFound = errors.New("proposal not found")

type Source interface {
	ProposalByID(context.Context, *big.Int) (*ProposalResponse, error)
}

type Server struct {
	addr    string
	source  Source
	handler http.Handler
	server  *http.Server
}

type ProposalResponse struct {
	ProposalHash string        `json:"proposal_hash"`
	Proposal     Proposal      `json:"proposal"`
	Event        ProposalEvent `json:"event"`
}

type Proposal struct {
	ID                             uint64             `json:"id"`
	Timestamp                      uint64             `json:"timestamp"`
	EndOfSubmissionWindowTimestamp uint64             `json:"end_of_submission_window_timestamp"`
	Proposer                       string             `json:"proposer"`
	ParentProposalHash             string             `json:"parent_proposal_hash"`
	OriginBlockNumber              uint64             `json:"origin_block_number"`
	OriginBlockHash                string             `json:"origin_block_hash"`
	BasefeeSharingPctg             uint8              `json:"basefee_sharing_pctg"`
	Sources                        []DerivationSource `json:"sources"`
}

type DerivationSource struct {
	IsForcedInclusion bool      `json:"is_forced_inclusion"`
	BlobSlice         BlobSlice `json:"blob_slice"`
}

type BlobSlice struct {
	BlobHashes []string `json:"blob_hashes"`
	Offset     uint64   `json:"offset"`
	Timestamp  uint64   `json:"timestamp"`
}

type ProposalEvent struct {
	BlockNumber uint64 `json:"block_number"`
	BlockHash   string `json:"block_hash"`
	TxHash      string `json:"tx_hash"`
	LogIndex    uint   `json:"log_index"`
}

func New(addr string, source Source) (*Server, error) {
	if source == nil {
		return nil, errors.New("proposal source is required")
	}
	if err := ValidateLoopbackAddress(addr); err != nil {
		return nil, err
	}

	server := &Server{addr: addr, source: source}
	mux := http.NewServeMux()
	mux.HandleFunc(proposalPathPrefix, server.handleProposal)
	server.handler = mux
	return server, nil
}

func (s *Server) Handler() http.Handler {
	return s.handler
}

func (s *Server) Start() error {
	s.server = &http.Server{
		Addr:              s.addr,
		Handler:           s.handler,
		ReadHeaderTimeout: defaultReadHeaderTimeout,
	}
	if err := s.server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		return err
	}
	return nil
}

func (s *Server) Shutdown(ctx context.Context) error {
	if s.server == nil {
		return nil
	}
	if ctx.Err() != nil {
		return s.server.Close()
	}
	return s.server.Shutdown(ctx)
}

type RPCSource struct {
	client *rpc.Client
}

func NewRPCSource(client *rpc.Client) (*RPCSource, error) {
	if client == nil {
		return nil, errors.New("rpc client is required")
	}
	if client.L1 == nil {
		return nil, errors.New("L1 client is required")
	}
	if client.L2 == nil {
		return nil, errors.New("L2 client is required")
	}
	if client.L2Engine == nil {
		return nil, errors.New("L2 engine client is required")
	}
	if client.ShastaClients == nil || client.ShastaClients.Inbox == nil {
		return nil, errors.New("Shasta inbox client is required")
	}
	return &RPCSource{client: client}, nil
}

func (s *RPCSource) ProposalByID(ctx context.Context, id *big.Int) (*ProposalResponse, error) {
	event, _, err := s.client.GetProposalByID(ctx, id)
	if err != nil {
		if strings.Contains(err.Error(), "proposal event not found") {
			return nil, ErrProposalNotFound
		}
		return nil, err
	}

	header, err := s.client.L1.HeaderByHash(ctx, event.Raw.BlockHash)
	if err != nil {
		return nil, fmt.Errorf("failed to get proposal L1 header: %w", err)
	}

	proposalHash, err := s.client.ShastaClients.Inbox.HashProposal(
		&bind.CallOpts{Context: ctx},
		proposalFromEvent(event, header.Time),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to hash proposal: %w", err)
	}

	return buildProposalResponse(event, header.Time, common.Hash(proposalHash)), nil
}

func ValidateLoopbackAddress(addr string) error {
	host, _, err := net.SplitHostPort(addr)
	if err != nil {
		return fmt.Errorf("invalid local proposal API address: %w", err)
	}
	if host == "" {
		return errors.New("local proposal API address must bind to an explicit loopback host")
	}
	if strings.EqualFold(host, "localhost") {
		return nil
	}
	ip := net.ParseIP(host)
	if ip == nil || !ip.IsLoopback() {
		return fmt.Errorf("local proposal API address must bind to loopback, got %q", host)
	}
	return nil
}

func (s *Server) handleProposal(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	id, ok := parseProposalID(r.URL.Path)
	if !ok {
		writeError(w, http.StatusBadRequest, "invalid proposal ID")
		return
	}

	response, err := s.source.ProposalByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, ErrProposalNotFound) {
			writeError(w, http.StatusNotFound, err.Error())
			return
		}
		writeError(w, http.StatusBadGateway, err.Error())
		return
	}
	if response == nil {
		writeError(w, http.StatusNotFound, ErrProposalNotFound.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to encode response")
	}
}

func parseProposalID(path string) (*big.Int, bool) {
	rawID := strings.TrimPrefix(path, proposalPathPrefix)
	if rawID == "" || rawID == path || strings.Contains(rawID, "/") {
		return nil, false
	}
	id, ok := new(big.Int).SetString(rawID, 10)
	if !ok || id.Sign() < 0 {
		return nil, false
	}
	return id, true
}

func writeError(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]string{"error": message})
}

func proposalFromEvent(
	event *shastaBindings.ShastaInboxClientProposed,
	timestamp uint64,
) shastaBindings.IInboxProposal {
	return shastaBindings.IInboxProposal{
		Id:                             cloneBig(event.Id),
		Timestamp:                      new(big.Int).SetUint64(timestamp),
		EndOfSubmissionWindowTimestamp: cloneBig(event.EndOfSubmissionWindowTimestamp),
		Proposer:                       event.Proposer,
		ParentProposalHash:             event.ParentProposalHash,
		OriginBlockNumber:              new(big.Int).SetUint64(event.Raw.BlockNumber),
		OriginBlockHash:                event.Raw.BlockHash,
		BasefeeSharingPctg:             event.BasefeeSharingPctg,
		Sources:                        event.Sources,
	}
}

func buildProposalResponse(
	event *shastaBindings.ShastaInboxClientProposed,
	timestamp uint64,
	proposalHash common.Hash,
) *ProposalResponse {
	sources := make([]DerivationSource, 0, len(event.Sources))
	for _, source := range event.Sources {
		blobHashes := make([]string, 0, len(source.BlobSlice.BlobHashes))
		for _, blobHash := range source.BlobSlice.BlobHashes {
			blobHashes = append(blobHashes, common.Hash(blobHash).Hex())
		}
		sources = append(sources, DerivationSource{
			IsForcedInclusion: source.IsForcedInclusion,
			BlobSlice: BlobSlice{
				BlobHashes: blobHashes,
				Offset:     bigToUint64(source.BlobSlice.Offset),
				Timestamp:  bigToUint64(source.BlobSlice.Timestamp),
			},
		})
	}

	return &ProposalResponse{
		ProposalHash: proposalHash.Hex(),
		Proposal: Proposal{
			ID:                             bigToUint64(event.Id),
			Timestamp:                      timestamp,
			EndOfSubmissionWindowTimestamp: bigToUint64(event.EndOfSubmissionWindowTimestamp),
			Proposer:                       event.Proposer.Hex(),
			ParentProposalHash:             common.Hash(event.ParentProposalHash).Hex(),
			OriginBlockNumber:              event.Raw.BlockNumber,
			OriginBlockHash:                event.Raw.BlockHash.Hex(),
			BasefeeSharingPctg:             event.BasefeeSharingPctg,
			Sources:                        sources,
		},
		Event: ProposalEvent{
			BlockNumber: event.Raw.BlockNumber,
			BlockHash:   event.Raw.BlockHash.Hex(),
			TxHash:      event.Raw.TxHash.Hex(),
			LogIndex:    event.Raw.Index,
		},
	}
}

func cloneBig(value *big.Int) *big.Int {
	if value == nil {
		return new(big.Int)
	}
	return new(big.Int).Set(value)
}

func bigToUint64(value *big.Int) uint64 {
	if value == nil {
		return 0
	}
	return value.Uint64()
}
