package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
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
// chain ID, which binds the generation (RECOV-8.2-5), the phase, the app's only readiness
// field, and, in a ready reply, the one height the app admits for signing. The app reports
// phase "ready" only after its own checkpoint target and InitChain checks (SYNC-9-5,
// RECOV-8.2-4), so every other snapshot field is ignored here.
type trustResponse struct {
	SchemaVersion uint64  `json:"schema_version"`
	SessionID     string  `json:"session_id"`
	ChainID       *string `json:"chain_id"`
	Phase         string  `json:"phase"`
	Reason        *string `json:"reason"`
	// EligibleHeight is the only height the app admits for signing (SYNC-9-10): the one after
	// its durable committed boundary, the generation's initial_height before its first commit,
	// or s + 1 right after a 5.4 import at s. A ready reply without it refuses.
	EligibleHeight *uint64 `json:"eligible_height"`
}

// errControlUnavailable marks a trust query that never got a reply: an absent or restarting
// app, a refused connection or an expired deadline. A malformed reply is not unavailable.
var errControlUnavailable = errors.New("checkpoint trust control unavailable")

// errTrustPending marks a refusal that the same signing request may still see cleared: no
// session yet, a session begun just now, a phase that is not ready yet, or an unavailable app.
// Any other refusal, such as a halted app, another chain or another height, is final.
var errTrustPending = errors.New("checkpoint trust pending")

// signingHold bounds the trust decision for one signing request. While the decision is
// pending the gate polls the app every trustPoll, as SYNC-9-6a holds a request during the
// remaining comparison, so the first request of a fresh session, such as the step a restarted
// Comet replays after a refusal, waits for that session's check instead of being refused at
// once (SYNC-9-12). A refusal reaches Comet well before its fixed 5 s signer read timeout,
// after which Comet would retry the request instead of giving up on it (SYNC-9-11), and an
// authorized step keeps 1.5 s for FilePV's four fsyncs.
const signingHold = 3500 * time.Millisecond

// trustPoll is the pause between two trust rounds of one held signing request.
const trustPoll = 100 * time.Millisecond

type gate struct {
	path    string
	timeout time.Duration
	// hold is the trust decision budget of one signing request; zero makes one round of at
	// most two queries, each bounded by timeout.
	hold        time.Duration
	session     atomic.Pointer[string]
	authorized  func(*trustResponse)
	unavailable func(error)
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

// Every request gets its own bounded local connection, which ends by deadline or after
// timeout, whichever comes first. Authorization is never cached across requests or transport
// sessions. A query that gets no reply is errControlUnavailable.
func (g *gate) query(op string, session string, deadline time.Time) (*trustResponse, error) {
	if limit := time.Now().Add(g.timeout); limit.Before(deadline) {
		deadline = limit
	}
	wait := time.Until(deadline)
	if wait <= 0 {
		return nil, fmt.Errorf("%w: trust decision deadline passed", errControlUnavailable)
	}
	c, err := net.DialTimeout("unix", g.path, wait)
	if err != nil {
		return nil, fmt.Errorf("%w: %w", errControlUnavailable, err)
	}
	defer c.Close()
	if err = c.SetDeadline(deadline); err != nil {
		return nil, fmt.Errorf("%w: %w", errControlUnavailable, err)
	}
	request := map[string]any{"schema_version": controlSchema, "op": op}
	if op == "check_session" {
		request["session_id"] = session
	}
	if err = json.NewEncoder(c).Encode(request); err != nil {
		return nil, fmt.Errorf("%w: %w", errControlUnavailable, err)
	}
	line, err := bufio.NewReader(io.LimitReader(c, maxControlFrame+1)).ReadBytes('\n')
	if err != nil {
		if len(line) > maxControlFrame {
			return nil, errors.New("oversize control response")
		}
		return nil, fmt.Errorf("%w: %w", errControlUnavailable, err)
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
	// Only the gate's four fields are always required; other fields are ignored. chain_id is
	// null before InitChain, so begin_session accepts it and a signing request does not.
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
	for field, target := range map[string]any{"schema_version": &res.SchemaVersion, "session_id": &res.SessionID, "chain_id": &res.ChainID, "phase": &res.Phase, "reason": &res.Reason, "eligible_height": &res.EligibleHeight} {
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

// verdict judges one check_session reply for a signing request at height. The phase is the
// app's only readiness field: every value other than the exact string "ready" refuses
// (SYNC-9-10/9-11). A halted app and another chain_id are final; another closed phase, and a
// null chain_id before InitChain, are pending. A ready reply admits only its eligible height,
// and any other height is refused before FilePV changes the HRS (SYNC-9-10). The session is
// matched by the caller.
func verdict(r *trustResponse, chain string, height int64) error {
	reason := ""
	if r.Reason != nil {
		reason = ": " + *r.Reason
	}
	switch {
	case r.Phase == "halted":
		return fmt.Errorf("checkpoint trust halted for chain %s%s", chain, reason)
	case r.ChainID != nil && *r.ChainID != chain:
		return fmt.Errorf("checkpoint trust is for chain %q, not %s", *r.ChainID, chain)
	case r.Phase != "ready" || r.ChainID == nil:
		return fmt.Errorf("%w: checkpoint trust is not ready for chain %s%s", errTrustPending, chain, reason)
	case r.EligibleHeight == nil || *r.EligibleHeight == 0 || *r.EligibleHeight > math.MaxInt64:
		return errors.New("ready checkpoint trust names no eligible height")
	case height <= 0 || uint64(height) != *r.EligibleHeight:
		return fmt.Errorf("height %d is not the eligible height %d after the app's committed boundary (SYNC-9-10)", height, *r.EligibleHeight)
	}
	return nil
}

// authorize decides one signing request at height within the gate's hold: it repeats trust
// rounds while the decision is pending and time remains, and returns the first final answer.
// Without a hold it makes one round of at most two queries.
func (g *gate) authorize(chain string, height int64) error {
	budget := g.hold
	if budget <= 0 {
		budget = 2 * g.timeout
	}
	deadline := time.Now().Add(budget)
	for {
		err := g.check(chain, height, deadline)
		if err == nil || g.hold <= 0 || !errors.Is(err, errTrustPending) || time.Until(deadline) <= trustPoll || g.isStopping() {
			return err
		}
		time.Sleep(trustPoll)
	}
}

// check is one trust round for the transport's current session: it begins a fresh closed
// session when there is none, or when the app reports another current session, as after an
// app restart, and otherwise judges the session's check_session reply (verdict).
func (g *gate) check(chain string, height int64, deadline time.Time) error {
	if g.isStopping() {
		return errors.New("signer stopped")
	}
	sessionPtr := g.session.Load()
	if sessionPtr == nil {
		if _, err := g.begin(deadline); err != nil {
			return err
		}
		return fmt.Errorf("%w: began a fresh closed trust session", errTrustPending)
	}
	session := *sessionPtr
	r, err := g.query("check_session", session, deadline)
	if errors.Is(err, errControlUnavailable) {
		return fmt.Errorf("%w: %w", errTrustPending, err)
	}
	if err != nil {
		return err
	}
	if r.SessionID != session {
		if _, err = g.begin(deadline); err != nil {
			return err
		}
		return fmt.Errorf("%w: trust session changed; began a fresh closed session", errTrustPending)
	}
	if err = verdict(r, chain, height); err != nil {
		return err
	}
	if g.authorized != nil {
		g.authorized(r)
	}
	return nil
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

// begin opens a fresh closed session for the current transport (SYNC-9-4) and publishes it.
// An unavailable app is errTrustPending and leaves the transport without a session; a reply
// that does not close trust is final.
func (g *gate) begin(deadline time.Time) (string, error) {
	if g.isStopping() {
		return "", errors.New("signer stopped")
	}
	g.session.Store(nil)
	response, err := g.query("begin_session", "", deadline)
	if errors.Is(err, errControlUnavailable) {
		return "", fmt.Errorf("%w: %w", errTrustPending, err)
	}
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

// dialer connects to Comet promptly and begins the connection's own closed session before
// exposing it, so Comet's first GetPubKey, which has only its 3 s accept and 5 s read timeouts,
// is answered even when trust can return only after Comet has synced (START-10-6, SYNC-9-12).
// PubKey and Ping never wait for trust. If the app cannot begin a session now, the connection
// is exposed without one and its first signing request begins it; the empty session published
// then tells the supervisor that this transport connected. Every reconnect, including one after
// a transport timeout to the same Comet process, starts a new closed session with the HRS on
// disk intact (SYNC-9-4).
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
		if _, err = g.begin(time.Now().Add(g.timeout)); err != nil {
			if g.isStopping() {
				conn.Close()
				return nil, err
			}
			if g.unavailable != nil {
				g.unavailable(err)
			}
			g.publishObservation(false)
		}
		return &reconnectingConn{Conn: conn}, nil
	}
}

func (g *gate) handle(signer types.PrivValidator, req pv.Message, chain string) (pv.Message, error) {
	var signing, invalid bool
	var requestChain string
	var height int64
	switch r := req.Sum.(type) {
	case *pv.Message_SignVoteRequest:
		signing = true
		invalid = r == nil || r.SignVoteRequest == nil || r.SignVoteRequest.Vote == nil
		if !invalid {
			requestChain = r.SignVoteRequest.ChainId
			vote := r.SignVoteRequest.Vote
			height = vote.Height
			_, blockErr := types.BlockIDFromProto(&vote.BlockID)
			invalid = blockErr != nil || vote.Height <= 0 || vote.Round < 0 || (vote.Type != tm.PrevoteType && vote.Type != tm.PrecommitType)
		}
	case *pv.Message_SignProposalRequest:
		signing = true
		invalid = r == nil || r.SignProposalRequest == nil || r.SignProposalRequest.Proposal == nil
		if !invalid {
			requestChain = r.SignProposalRequest.ChainId
			proposal := r.SignProposalRequest.Proposal
			height = proposal.Height
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
			// check of the session and eligible height bind every signature to that state
			// (RECOV-8.2-4, SYNC-9-10).
			err = g.authorize(chain, height)
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
