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
	"github.com/ethereum/go-ethereum/core/types"

	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

const (
	defaultReadHeaderTimeout = 5 * time.Second
	defaultRequestTimeout    = rpc.DefaultRpcTimeout
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
	mux.Handle(proposalPathPrefix, http.TimeoutHandler(
		http.HandlerFunc(server.handleProposal),
		defaultRequestTimeout,
		`{"error":"request timed out"}`+"\n",
	))
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
		proposalFromEvent(event, header),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to hash proposal: %w", err)
	}

	return buildProposalResponse(event, header, common.Hash(proposalHash))
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
	if err := json.NewEncoder(w).Encode(map[string]string{"error": message}); err != nil {
		return
	}
}

func proposalFromEvent(
	event *shastaBindings.ShastaInboxClientProposed,
	header *types.Header,
) shastaBindings.IInboxProposal {
	originBlockNumber := new(big.Int)
	if header.Number != nil {
		originBlockNumber = new(big.Int).Sub(header.Number, common.Big1)
	}
	return shastaBindings.IInboxProposal{
		Id:                             cloneBig(event.Id),
		Timestamp:                      new(big.Int).SetUint64(header.Time),
		EndOfSubmissionWindowTimestamp: cloneBig(event.EndOfSubmissionWindowTimestamp),
		Proposer:                       event.Proposer,
		ParentProposalHash:             event.ParentProposalHash,
		OriginBlockNumber:              originBlockNumber,
		OriginBlockHash:                header.ParentHash,
		BasefeeSharingPctg:             event.BasefeeSharingPctg,
		Sources:                        event.Sources,
	}
}

func buildProposalResponse(
	event *shastaBindings.ShastaInboxClientProposed,
	header *types.Header,
	proposalHash common.Hash,
) (*ProposalResponse, error) {
	proposalID, err := checkedUint64("proposal ID", event.Id)
	if err != nil {
		return nil, err
	}
	endOfSubmissionWindowTimestamp, err := checkedUint64(
		"end of submission window timestamp",
		event.EndOfSubmissionWindowTimestamp,
	)
	if err != nil {
		return nil, err
	}
	originBlockNumber, err := eventOriginBlockNumber(header)
	if err != nil {
		return nil, err
	}
	sources := make([]DerivationSource, 0, len(event.Sources))
	for _, source := range event.Sources {
		blobHashes := make([]string, 0, len(source.BlobSlice.BlobHashes))
		for _, blobHash := range source.BlobSlice.BlobHashes {
			blobHashes = append(blobHashes, common.Hash(blobHash).Hex())
		}
		offset, err := checkedUint64("blob slice offset", source.BlobSlice.Offset)
		if err != nil {
			return nil, err
		}
		timestamp, err := checkedUint64("blob slice timestamp", source.BlobSlice.Timestamp)
		if err != nil {
			return nil, err
		}
		sources = append(sources, DerivationSource{
			IsForcedInclusion: source.IsForcedInclusion,
			BlobSlice: BlobSlice{
				BlobHashes: blobHashes,
				Offset:     offset,
				Timestamp:  timestamp,
			},
		})
	}

	return &ProposalResponse{
		ProposalHash: proposalHash.Hex(),
		Proposal: Proposal{
			ID:                             proposalID,
			Timestamp:                      header.Time,
			EndOfSubmissionWindowTimestamp: endOfSubmissionWindowTimestamp,
			Proposer:                       event.Proposer.Hex(),
			ParentProposalHash:             common.Hash(event.ParentProposalHash).Hex(),
			OriginBlockNumber:              originBlockNumber,
			OriginBlockHash:                header.ParentHash.Hex(),
			BasefeeSharingPctg:             event.BasefeeSharingPctg,
			Sources:                        sources,
		},
		Event: ProposalEvent{
			BlockNumber: event.Raw.BlockNumber,
			BlockHash:   event.Raw.BlockHash.Hex(),
			TxHash:      event.Raw.TxHash.Hex(),
			LogIndex:    event.Raw.Index,
		},
	}, nil
}

func cloneBig(value *big.Int) *big.Int {
	if value == nil {
		return new(big.Int)
	}
	return new(big.Int).Set(value)
}

func checkedUint64(name string, value *big.Int) (uint64, error) {
	if value == nil {
		return 0, fmt.Errorf("%s is nil", name)
	}
	if !value.IsUint64() {
		return 0, fmt.Errorf("%s does not fit in uint64: %s", name, value.String())
	}
	return value.Uint64(), nil
}

func eventOriginBlockNumber(header *types.Header) (uint64, error) {
	if header == nil || header.Number == nil {
		return 0, errors.New("proposal L1 header number is missing")
	}
	if header.Number.Sign() == 0 {
		return 0, errors.New("proposal L1 header has no parent block")
	}
	return checkedUint64("origin block number", new(big.Int).Sub(header.Number, common.Big1))
}
