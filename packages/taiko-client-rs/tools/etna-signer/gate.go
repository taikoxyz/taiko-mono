package main

import (
	"bufio"
	"bytes"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"sync/atomic"
	"time"

	"github.com/cometbft/cometbft/privval"
	pv "github.com/cometbft/cometbft/proto/tendermint/privval"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
	"github.com/cometbft/cometbft/types"
)

const maxControlFrame = 16 * 1024

type blockRef struct {
	Height *uint64 `json:"height"`
	Hash   string  `json:"hash"`
}
type target struct {
	L1Number   *uint64 `json:"l1_number"`
	L1Hash     string  `json:"l1_hash"`
	Height     *uint64 `json:"height"`
	Hash       string  `json:"hash"`
	Generation *uint64 `json:"generation"`
	Inbox      string  `json:"inbox"`
}
type trustResponse struct {
	SchemaVersion uint64    `json:"schema_version"`
	SessionID     string    `json:"session_id"`
	ChainID       *string   `json:"chain_id"`
	Generation    *uint64   `json:"generation"`
	Ready         bool      `json:"trust_ready"`
	Syncing       bool      `json:"syncing"`
	Phase         string    `json:"phase"`
	Target        *target   `json:"target"`
	Committed     *blockRef `json:"committed_head"`
	Trusted       *blockRef `json:"trusted_consensus_head"`
	Reason        *string   `json:"reason"`
}
type gate struct {
	path       string
	timeout    time.Duration
	session    atomic.Pointer[string]
	authorized func(*trustResponse)
}

func newGate(path string, timeout time.Duration) *gate { return &gate{path: path, timeout: timeout} }

// Every request gets its own bounded local connection. Deadlines close abandoned I/O;
// authorization is never cached across requests or transport sessions.
func (g *gate) query(op string, session string) (*trustResponse, error) {
	deadline := time.Now().Add(g.timeout)
	c, err := net.DialTimeout("unix", g.path, g.timeout)
	if err != nil {
		return nil, err
	}
	defer c.Close()
	if err = c.SetDeadline(deadline); err != nil {
		return nil, err
	}
	request := map[string]any{"schema_version": 1, "op": op}
	if op == "check_session" {
		request["session_id"] = session
	}
	if err = json.NewEncoder(c).Encode(request); err != nil {
		return nil, err
	}
	line, err := bufio.NewReader(io.LimitReader(c, maxControlFrame+1)).ReadBytes('\n')
	if err != nil {
		return nil, err
	}
	if len(line) > maxControlFrame {
		return nil, errors.New("oversize control response")
	}
	// Unknown fields, trailing JSON, absent booleans and duplicate keys fail closed.
	var fields map[string]json.RawMessage
	if err = json.Unmarshal(line, &fields); err != nil {
		return nil, err
	}
	required := []string{"schema_version", "session_id", "chain_id", "generation", "trust_ready", "syncing", "phase", "target", "committed_head", "trusted_consensus_head", "reason"}
	for _, field := range required {
		if _, ok := fields[field]; !ok {
			return nil, fmt.Errorf("missing %s", field)
		}
	}
	for _, field := range []string{"schema_version", "session_id", "trust_ready", "syncing", "phase"} {
		if bytes.Equal(bytes.TrimSpace(fields[field]), []byte("null")) {
			return nil, fmt.Errorf("null %s", field)
		}
	}
	decoder := json.NewDecoder(bytes.NewReader(line))
	decoder.DisallowUnknownFields()
	var res trustResponse
	if err = decoder.Decode(&res); err != nil {
		return nil, err
	}
	if res.SchemaVersion != 1 || res.SessionID == "" {
		return nil, errors.New("invalid control version/session")
	}
	// Decode into tokens too, rejecting duplicate object keys at every nesting level.
	if err = uniqueJSON(json.NewDecoder(bytes.NewReader(line))); err != nil {
		return nil, err
	}
	return &res, nil
}
func uniqueJSON(d *json.Decoder) error {
	token, err := d.Token()
	if err != nil {
		return err
	}
	delim, ok := token.(json.Delim)
	if !ok {
		return nil
	}
	seen := map[string]bool{}
	for d.More() {
		if delim == '{' {
			key, e := d.Token()
			if e != nil {
				return e
			}
			s := key.(string)
			if seen[s] {
				return errors.New("duplicate control field")
			}
			seen[s] = true
		}
		if err := uniqueJSON(d); err != nil {
			return err
		}
	}
	_, err = d.Token()
	return err
}
func canonicalHex(s string, n int) bool {
	if len(s) != 2+n*2 || s[:2] != "0x" {
		return false
	}
	for _, c := range s[2:] {
		if !(c >= '0' && c <= '9' || c >= 'a' && c <= 'f') {
			return false
		}
	}
	_, err := hex.DecodeString(s[2:])
	return err == nil
}
func validHead(h *blockRef) bool { return h != nil && h.Height != nil && canonicalHex(h.Hash, 32) }
func (g *gate) authorize(chain string) error {
	sessionPtr := g.session.Load()
	if sessionPtr == nil {
		g.begin()
		return errors.New("no Comet trust session; retry after rearm")
	}
	session := *sessionPtr
	r, err := g.query("check_session", session)
	if err != nil {
		return err
	}
	if r.SessionID != session {
		g.begin()
		return errors.New("trust session changed; rearmed closed for next request")
	}
	if r.ChainID == nil || *r.ChainID != chain || !r.Ready || r.Syncing || r.Phase != "ready" || r.Generation == nil || r.Target == nil || !validHead(r.Committed) || !validHead(r.Trusted) {
		return errors.New("checkpoint trust is closed or belongs to another session/chain")
	}
	t := r.Target
	if t.Generation == nil || *t.Generation != *r.Generation || t.Height == nil || t.L1Number == nil || !canonicalHex(t.L1Hash, 32) || !canonicalHex(t.Hash, 32) || !canonicalHex(t.Inbox, 20) || *r.Committed.Height < *t.Height || *r.Committed.Height != *r.Trusted.Height || r.Committed.Hash != r.Trusted.Hash || (*r.Committed.Height == *t.Height && r.Committed.Hash != t.Hash) {
		return errors.New("inconsistent trusted checkpoint")
	}
	if g.authorized != nil {
		g.authorized(r)
	}
	return nil
}

// BeginSession is performed after the official transport handshake and before the
// transport becomes visible to SignerServer, including every reconnection.
func (g *gate) begin() error {
	g.session.Store(nil)
	response, err := g.query("begin_session", "")
	if err != nil {
		return err
	}
	if response.Ready || !response.Syncing {
		return errors.New("begin_session did not close trust")
	}
	g.session.Store(&response.SessionID)
	return nil
}
func (g *gate) dialer(base privval.SocketDialer) privval.SocketDialer {
	return func() (net.Conn, error) {
		g.session.Store(nil)
		conn, err := base()
		if err != nil {
			return nil, err
		}
		if err = g.begin(); err != nil {
			conn.Close()
			return nil, err
		}
		return &reconnectingConn{Conn: conn}, nil
	}
}
func (g *gate) handle(signer types.PrivValidator, req pv.Message, chain string) (pv.Message, error) {
	var signing, invalid bool
	var requestChain string
	switch r := req.Sum.(type) {
	case *pv.Message_SignVoteRequest:
		signing = true
		invalid = r == nil || r.SignVoteRequest == nil || r.SignVoteRequest.Vote == nil
		if !invalid {
			requestChain = r.SignVoteRequest.ChainId
			vote := r.SignVoteRequest.Vote
			_, blockErr := types.BlockIDFromProto(&vote.BlockID)
			invalid = blockErr != nil || vote.Height <= 0 || vote.Round < 0 || (vote.Type != tm.PrevoteType && vote.Type != tm.PrecommitType)
		}
	case *pv.Message_SignProposalRequest:
		signing = true
		invalid = r == nil || r.SignProposalRequest == nil || r.SignProposalRequest.Proposal == nil
		if !invalid {
			requestChain = r.SignProposalRequest.ChainId
			proposal := r.SignProposalRequest.Proposal
			_, blockErr := types.BlockIDFromProto(&proposal.BlockID)
			invalid = blockErr != nil || proposal.Type != tm.ProposalType || proposal.Height <= 0 || proposal.Round < 0 || proposal.PolRound < -1 || proposal.PolRound >= proposal.Round
		}
	case *pv.Message_PubKeyRequest:
		if r == nil || r.PubKeyRequest == nil {
			return pv.Message{}, errors.New("nil pubkey request")
		}
	case *pv.Message_PingRequest:
	default:
		return pv.Message{}, errors.New("unsupported signer request")
	}
	if signing {
		var err error
		if invalid || requestChain != chain {
			err = errors.New("invalid signing request or chain ID")
		} else {
			err = g.authorize(chain)
		}
		if err != nil {
			remote := &pv.RemoteSignerError{Code: 1, Description: "checkpoint trust denied: " + err.Error()}
			switch req.Sum.(type) {
			case *pv.Message_SignVoteRequest:
				return pv.Message{Sum: &pv.Message_SignedVoteResponse{SignedVoteResponse: &pv.SignedVoteResponse{Error: remote}}}, err
			default:
				return pv.Message{Sum: &pv.Message_SignedProposalResponse{SignedProposalResponse: &pv.SignedProposalResponse{Error: remote}}}, err
			}
		}
	}
	return privval.DefaultValidationRequestHandler(signer, req, chain)
}
