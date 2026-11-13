package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"sync"
	"sync/atomic"
	"time"

	"github.com/cometbft/cometbft/privval"
	pv "github.com/cometbft/cometbft/proto/tendermint/privval"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
	"github.com/cometbft/cometbft/types"
)

const maxControlFrame = 16 * 1024

// controlSchema is the app's one private trust-control wire version.
const controlSchema = 1

// trustResponse is the part of the app's trust snapshot that the gate reads: the session, the
// chain ID, which binds the generation (RECOV-8.2-5), and the phase, the app's only readiness
// field. The app reports phase "ready" only after its own checkpoint target, validator-state and
// InitChain checks (SYNC-9-5, RECOV-8.2-4), so every other snapshot field is ignored here.
type trustResponse struct {
	SchemaVersion uint64  `json:"schema_version"`
	SessionID     string  `json:"session_id"`
	ChainID       *string `json:"chain_id"`
	Phase         string  `json:"phase"`
	Reason        *string `json:"reason"`
}
type gate struct {
	path        string
	timeout     time.Duration
	session     atomic.Pointer[string]
	authorized  func(*trustResponse)
	connecting  func(*trustResponse)
	denialPath  string
	denials     uint64
	observation sync.Mutex
	transportMu sync.Mutex
	transports  map[*trackedConn]struct{}
	stopping    bool
	// terminal distinguishes uncertain signing persistence from recoverable trust loss.
	terminal chan error
}

func newGate(path string, timeout time.Duration) *gate {
	return &gate{path: path, timeout: timeout, terminal: make(chan error, 1)}
}

// stopIfUncertain asks the process owner to exit with exitSigningStateUnsafe, so the
// supervisor durably halts instead of automatically restarting a signer whose latest state
// needs inspection (RECOV-8.2-3).
func (g *gate) stopIfUncertain(err error) bool {
	if !errors.Is(err, errSigningStateUnsafe) {
		return false
	}
	select {
	case g.terminal <- err:
	default:
	}
	return true
}

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
	request := map[string]any{"schema_version": controlSchema, "op": op}
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
	// Duplicate keys at any depth make the reply ambiguous and fail closed.
	if err = uniqueJSON(json.NewDecoder(bytes.NewReader(line))); err != nil {
		return nil, err
	}
	var fields map[string]json.RawMessage
	if err = json.Unmarshal(line, &fields); err != nil {
		return nil, err
	}
	// Only the gate's four fields are required; other fields are ignored. chain_id is null
	// before InitChain, so begin_session accepts it and trusted denies it.
	for _, field := range []string{"schema_version", "session_id", "chain_id", "phase"} {
		raw, ok := fields[field]
		if !ok {
			return nil, fmt.Errorf("missing %s", field)
		}
		if field != "chain_id" && bytes.Equal(bytes.TrimSpace(raw), []byte("null")) {
			return nil, fmt.Errorf("null %s", field)
		}
	}
	// Decode from the exact keys only: encoding/json matches struct fields case-insensitively,
	// so a later "Phase" or "CHAIN_ID" would otherwise override the real key.
	var res trustResponse
	for field, target := range map[string]any{"schema_version": &res.SchemaVersion, "session_id": &res.SessionID, "chain_id": &res.ChainID, "phase": &res.Phase, "reason": &res.Reason} {
		if raw, ok := fields[field]; ok {
			if err = json.Unmarshal(raw, target); err != nil {
				return nil, fmt.Errorf("%s: %w", field, err)
			}
		}
	}
	if res.SchemaVersion != controlSchema || res.SessionID == "" {
		return nil, errors.New("invalid control version/session")
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

// trusted is shared by every signature and the post-refusal reconnect gate. The phase is the
// app's only readiness field: every value other than the exact string "ready" denies
// (SYNC-9-10/9-11), and so does another or a null chain_id. The session is matched by the
// caller.
func trusted(r *trustResponse, chain string) error {
	if r == nil || r.ChainID == nil || *r.ChainID != chain || r.Phase != "ready" {
		reason := ""
		if r != nil && r.Reason != nil {
			reason = ": " + *r.Reason
		}
		return fmt.Errorf("checkpoint trust is not ready for chain %s%s", chain, reason)
	}
	return nil
}
func (g *gate) check(chain string) (*trustResponse, error) {
	if g.isStopping() {
		return nil, errors.New("signer stopped")
	}
	sessionPtr := g.session.Load()
	if sessionPtr == nil {
		g.begin()
		return nil, errors.New("no Comet trust session; retry after rearm")
	}
	session := *sessionPtr
	r, err := g.query("check_session", session)
	if err != nil {
		return nil, err
	}
	if r.SessionID != session {
		g.begin()
		return nil, errors.New("trust session changed; rearmed closed for next request")
	}
	if err = trusted(r, chain); err != nil {
		return nil, err
	}
	if g.authorized != nil {
		g.authorized(r)
	}
	return r, nil
}

// publishObservation never contains private signing data or grants authorization. Failure
// stops this process rather than silently disabling the supervisor's refusal detection.
func (g *gate) publishObservation(denied bool) {
	g.observation.Lock()
	defer g.observation.Unlock()
	if denied {
		g.denials++
	}
	if g.denialPath == "" {
		return
	}
	session := ""
	if current := g.session.Load(); current != nil {
		session = *current
	}
	data, _ := json.Marshal(map[string]any{"sequence": g.denials, "session_id": session})
	temporary, err := os.CreateTemp(filepath.Dir(g.denialPath), ".signer-observation-")
	if err != nil {
		panic("cannot persist signer observation")
	}
	defer os.Remove(temporary.Name())
	if _, err := temporary.Write(data); err != nil {
		temporary.Close()
		panic("cannot persist signer observation")
	}
	if err := temporary.Close(); err != nil {
		panic("cannot close signer observation")
	}
	if err := os.Rename(temporary.Name(), g.denialPath); err != nil {
		panic("cannot publish signer observation")
	}
}

// BeginSession follows the official transport handshake and precedes exposing the
// transport to SignerServer, including every reconnection. It returns the new session.
func (g *gate) begin() (string, error) {
	if g.isStopping() {
		return "", errors.New("signer stopped")
	}
	g.session.Store(nil)
	response, err := g.query("begin_session", "")
	if err != nil {
		return "", err
	}
	if response.Phase == "ready" {
		return "", errors.New("begin_session did not close trust")
	}
	g.transportMu.Lock()
	if g.stopping {
		g.transportMu.Unlock()
		return "", errors.New("signer stopped")
	}
	g.session.Store(&response.SessionID)
	g.transportMu.Unlock()
	g.publishObservation(false)
	return response.SessionID, nil
}

// dialer connects to Comet first and then begins the transport's session, so Comet's
// startup GetPubKey succeeds even when trust can only return after Comet has synced.
func (g *gate) dialer(base privval.SocketDialer) privval.SocketDialer {
	return func() (net.Conn, error) {
		if g.isStopping() {
			return nil, errors.New("signer stopped")
		}
		g.session.Store(nil)
		conn, err := base()
		if err != nil {
			return nil, err
		}
		conn, err = g.trackTransport(conn)
		if err != nil {
			return nil, err
		}
		if _, err = g.begin(); err != nil {
			conn.Close()
			return nil, err
		}
		return &reconnectingConn{Conn: conn}, nil
	}
}

// trustedDialer serves --await-trust, which the supervisor uses only for its restart after
// a refused signing request, once trust has returned. Every refusal, a timed-out trust query
// included, is an explicit error answered before Comet's fixed 5 s signer read timeout: stock
// Comet gives up at once on a request answered with an error and never retries it, whereas it
// retries any other failure (no answer within that timeout, a dropped connection, a malformed
// answer). Only a restarted Comet's WAL replay asks for the refused step again,
// and that request must not race the app's asynchronous check of the fresh session. So the
// first transport begins its session but is exposed to Comet only after that session
// passes trusted; until then dialing fails and SignerDialerEndpoint retries. One pending
// session spans those retries, because every begin_session restarts the app's check. It is
// begun again only when the app reports another current session, as after an app restart.
// Comet is not running yet, so nothing is lost meanwhile. Later reconnects dial at once, as
// without the flag: a running Comet's request made while no signer is connected fails as a
// connection error after Comet's own retries, which the signer never sees or reports,
// whereas a refusal on a closed session is published for the supervisor's recovery.
func (g *gate) trustedDialer(base privval.SocketDialer, chain string) privval.SocketDialer {
	reconnect := g.dialer(base)
	pending, connected := "", false // pending: begun, not yet exposed to Comet
	return func() (net.Conn, error) {
		if g.isStopping() {
			return nil, errors.New("signer stopped")
		}
		if connected {
			return reconnect()
		}
		if pending != "" {
			r, err := g.query("check_session", pending)
			if err != nil {
				return nil, err // Keep the session: the app may be briefly unavailable.
			}
			if r.SessionID == pending {
				if err = trusted(r, chain); err != nil {
					return nil, fmt.Errorf("awaiting checkpoint trust before connecting to Comet: %w", err)
				}
				conn, err := base()
				if err != nil {
					return nil, err
				}
				conn, err = g.trackTransport(conn)
				if err != nil {
					return nil, err
				}
				connected = true
				if g.connecting != nil {
					g.connecting(r)
				}
				return &reconnectingConn{Conn: conn}, nil
			}
			// Another current session means this one can never become Ready.
		}
		session, err := g.begin()
		pending = session
		if err != nil {
			return nil, err
		}
		return nil, errors.New("began a fresh trust session; awaiting checkpoint trust before connecting to Comet")
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
			// The signer serves exactly one full chain_id, whose own HRS state init-state
			// created; a recovered generation is another chain_id with another state
			// (RECOV-8.2-1/8.2-5). So the request's chain, matched above, and this fresh
			// check bind every signature to that state (RECOV-8.2-4, SYNC-9-10).
			_, err = g.check(chain)
		}
		if err != nil {
			if !g.stopIfUncertain(err) {
				g.publishObservation(true)
			}

			remote := &pv.RemoteSignerError{Code: 1, Description: "checkpoint trust denied: " + err.Error()}
			switch req.Sum.(type) {
			case *pv.Message_SignVoteRequest:
				return pv.Message{Sum: &pv.Message_SignedVoteResponse{SignedVoteResponse: &pv.SignedVoteResponse{Error: remote}}}, err
			default:
				return pv.Message{Sum: &pv.Message_SignedProposalResponse{SignedProposalResponse: &pv.SignedProposalResponse{Error: remote}}}, err
			}
		}
	}
	response, err := privval.DefaultValidationRequestHandler(signer, req, chain)
	g.stopIfUncertain(err)
	return response, err
}
