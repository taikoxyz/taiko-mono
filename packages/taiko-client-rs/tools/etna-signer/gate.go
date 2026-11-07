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

// controlSchema is the app's one private trust-control wire version. Every response carries
// recovery_origin: null for generation zero, the authenticated origin after recovery.
const controlSchema = 1

type blockRef struct {
	Height *uint64 `json:"height"`
	Hash   string  `json:"hash"`
}
type target struct {
	L1Number     *uint64 `json:"l1_number"`
	L1Hash       string  `json:"l1_hash"`
	Height       *uint64 `json:"height"`
	Hash         string  `json:"hash"`
	CometHash    string  `json:"comet_hash"`
	ValStateHash string  `json:"val_state_hash"`
	Generation   *uint64 `json:"generation"`
	Inbox        string  `json:"inbox"`
}
type recoveryOrigin struct {
	Generation    *uint64 `json:"generation"`
	Height        *uint64 `json:"height"`
	L1Number      *uint64 `json:"l1_number"`
	L1Hash        string  `json:"l1_hash"`
	L1Timestamp   *uint64 `json:"l1_timestamp"`
	ELHash        string  `json:"el_hash"`
	CometHash     string  `json:"comet_hash"`
	ForcedCursor  *uint64 `json:"forced_cursor"`
	CommitteeHash string  `json:"committee_hash"`
}
type trustResponse struct {
	RecoveryOrigin *recoveryOrigin `json:"recovery_origin"`
	SchemaVersion  uint64          `json:"schema_version"`
	SessionID      string          `json:"session_id"`
	ChainID        *string         `json:"chain_id"`
	Generation     *uint64         `json:"generation"`
	Ready          bool            `json:"trust_ready"`
	Syncing        bool            `json:"syncing"`
	Phase          string          `json:"phase"`
	Target         *target         `json:"target"`
	Committed      *blockRef       `json:"committed_head"`
	Trusted        *blockRef       `json:"trusted_consensus_head"`
	Reason         *string         `json:"reason"`
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

// stopIfUncertain asks the process owner to exit, so the supervisor durably halts
// instead of automatically restarting a signer whose latest state needs inspection.
func (g *gate) stopIfUncertain(err error) bool {
	if !errors.Is(err, errStateUncertain) {
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
	// Unknown fields, trailing JSON, absent booleans and duplicate keys fail closed.
	var fields map[string]json.RawMessage
	if err = json.Unmarshal(line, &fields); err != nil {
		return nil, err
	}
	// recovery_origin is always present and nullable; trusted binds it to the generation.
	required := []string{"schema_version", "session_id", "chain_id", "generation", "recovery_origin", "trust_ready", "syncing", "phase", "target", "committed_head", "trusted_consensus_head", "reason"}
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
	if res.SchemaVersion != controlSchema || res.SessionID == "" {
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

// validRecovery binds the fixed authenticated origin independently of the moving checkpoint.
func validRecovery(r *trustResponse) error {
	o := r.RecoveryOrigin
	if o == nil || o.Generation == nil || r.Generation == nil || *o.Generation != *r.Generation || *o.Generation == 0 || *o.Generation >= 1<<48 || o.Height == nil || *o.Height >= 1<<48 || o.L1Number == nil || o.L1Timestamp == nil || o.ForcedCursor == nil || *o.ForcedCursor >= 1<<48 || !canonicalHex(o.L1Hash, 32) || !canonicalHex(o.ELHash, 32) || !canonicalHex(o.CometHash, 32) || !canonicalHex(o.CommitteeHash, 32) || r.Target == nil || r.Target.Height == nil || r.Target.L1Number == nil || *r.Target.Height < *o.Height || *r.Target.L1Number < *o.L1Number {
		return errors.New("missing or inconsistent authenticated recovery origin")
	}
	if *r.Target.Height == *o.Height && (r.Target.Hash != o.ELHash || r.Target.CometHash != o.CometHash) {
		return errors.New("recovery checkpoint contradicts origin")
	}
	return nil
}

// trusted is shared by every signature and the post-refusal reconnect gate.
func trusted(r *trustResponse, chain string) error {
	if r == nil || r.SessionID == "" || r.SchemaVersion != controlSchema {
		return errors.New("invalid private authorization")
	}
	if r.ChainID == nil || *r.ChainID != chain || !r.Ready || r.Syncing || r.Phase != "ready" || r.Generation == nil || r.Target == nil || !validHead(r.Committed) || !validHead(r.Trusted) {
		return errors.New("checkpoint trust is closed or belongs to another session/chain")
	}
	t := r.Target
	if t.Generation == nil || *t.Generation != *r.Generation || t.Height == nil || t.L1Number == nil || !canonicalHex(t.L1Hash, 32) || !canonicalHex(t.Hash, 32) || !canonicalHex(t.CometHash, 32) || !canonicalHex(t.ValStateHash, 32) || !canonicalHex(t.Inbox, 20) || *r.Committed.Height < *t.Height || *r.Committed.Height != *r.Trusted.Height || r.Committed.Hash != r.Trusted.Hash || (*r.Committed.Height == *t.Height && r.Committed.Hash != t.Hash) {
		return errors.New("inconsistent trusted checkpoint")
	}
	if *r.Generation > 0 {
		return validRecovery(r)
	}
	if r.RecoveryOrigin != nil {
		return errors.New("unexpected recovery origin")
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

func (g *gate) authorize(chain string) error { _, err := g.check(chain); return err }

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
	if response.Ready || !response.Syncing {
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
// a refused or timed-out signing request, once trust has returned. Stock Comet never
// retries a refused request; only a restarted Comet's WAL replay asks for that step again,
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
			var response *trustResponse
			response, err = g.check(chain)
			if err == nil {
				if domain, ok := signer.(*domainSigner); ok {
					signer, err = domain.authority.authorize(chain, response)
				} else if *response.Generation != 0 {
					// Without --authority-root the only HRS is generation zero's (RECOV-8.2-1/8.2-5).
					err = errors.New("recovered generations require authority mode")
				}
			}
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
