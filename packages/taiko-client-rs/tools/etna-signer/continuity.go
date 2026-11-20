package main

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"syscall"
	"time"

	"github.com/cometbft/cometbft/crypto"
	"github.com/cometbft/cometbft/libs/log"
	"github.com/cometbft/cometbft/libs/protoio"
	"github.com/cometbft/cometbft/privval"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
	"github.com/cometbft/cometbft/types"
	"github.com/cosmos/gogoproto/proto"
)

// cometProcess is the Comet process the supervisor reports for this signer, over the
// authenticated supervisor channel: its PID, its kernel start time (clock ticks since boot, empty
// where the platform has none) and the store instance ID of the home it started on.
type cometProcess struct {
	PID           int
	Start         string
	StoreInstance string
}

// guardedPV signs for one full chain_id from that chain's schema-2 signer state. It applies stock
// FilePV's HRS rules exactly (CheckHRS, canonical sign bytes, vote-extension signatures, the
// same-HRS retry that returns the saved signature for identical bytes and restores the saved
// timestamp for a timestamp-only difference, and refusal of every other conflict or regression;
// SYNC-9-13), and adds RECOV-8.2-2's continuity: a durable binding to the consensus store
// instance and a durable minimum signable height. Every change is one atomic write of the whole
// state, durable before anything that depends on it is released.
//
// A crash outside a step needs no fence: nothing is released before the state is durable, and
// the disk holds either the old or the new state, so a restart that signs an unreleased step
// again cannot equivocate. A failed fsync makes the latest state uncertain (RECOV-8.2-3): the
// first one refuses every later request, cached retries included, and writes the fence that makes
// a restart refuse. A failed write before the atomic rename panics with the state unchanged.
//
// A death after a failed fsync and before a durable fence would leave no fence, and on the same
// boot the failed write-back's error is already cleared: a restart's fsync then succeeds over
// pages that never reached disk. So each step first makes an inflight marker naming this boot
// durable, with two more fsyncs before the state is written, and removes it once the state is
// durable; a restart on the same boot refuses a marker it finds (refuseInflight). A step costs
// four fsyncs.
type guardedPV struct {
	mu    sync.Mutex
	key   crypto.PrivKey
	pub   crypto.PubKey
	chain string
	path  string
	state signerState
	// syncFile flushes an opened state, temporary state or inflight marker; tests replace it to
	// fail as a disk does.
	syncFile func(*os.File) error
	// syncDir flushes the state's directory; tests replace it to count or fail.
	syncDir func(string) error
	// uncertain is the first synchronization failure; nothing is signed after it.
	uncertain error
	// admitted is the Comet process this signer last admitted a session for; nil before the
	// first admission of this signer process.
	admitted *cometProcess
	// replay is the same-height replay session of the admitted process, nil outside one.
	replay *replaySession
	// request is what the gate learned from the supervisor for the request it is passing on.
	request requestContext
	// refused holds the heights at which this process refused a request before it reached the
	// state (trust, a timeout, the supervisor channel), even before a session was admitted.
	refused map[int64]bool
	// stopArmed: the operator armed the stop on a precommit for a planned ruleset upgrade
	// (START-10.1-14b). The next precommit, nil or block, is persisted and returned as the last
	// signature and closes the gate; closed refuses every later request of this process.
	stopArmed bool
	closed    bool
	// reported: the closure was handed to the gate to tell the supervisor.
	reported bool
	logger   log.Logger
}

// replaySession is a restarted Comet process's same-height replay of the last signed height
// (RECOV-8.2-2). Fresh signing at that height stays closed until a request in an authenticated,
// uninterrupted replay attempt repeats the saved vote (stock's timestamp-only retry included):
// that confirms the last decision, and higher HRS at that height may then be signed, persisted
// with the pinned startup prefix while the attempt lasts. Anything else at that height, outside
// an authenticated attempt or after the attempt ended unconfirmed, raises the durable floor to
// height + 1, except while a recoverable tail is being repaired or after a transient refusal of
// a request at that height, which keep it closed until the supervisor's guarded restart.
type replaySession struct {
	height  int64
	startup replayBinding
	// repair: this start found a torn tail after all bound input, which stock repairs; it
	// cannot replay, and the supervisor starts the pair again.
	repair bool
	// confirmed is the replay attempt that confirmed the saved decision, 0 before.
	confirmed uint64
	// interrupted: a request at height was refused before reaching the signer state (trust, a
	// timeout, the supervisor channel), so the attempt may end unconfirmed without its fault.
	interrupted bool
}

// requestContext is what the gate learned from the supervisor for one signing request: the log
// observer's view of the replay (only in a replay session at its height) and a source of the
// live WAL binding for a fresh signature outside an attempt.
type requestContext struct {
	observation *replayObservation
	live        func(height int64) *replayBinding
}

// newGuardedPV serves state, already read and authenticated, for chain at path.
func newGuardedPV(key crypto.PrivKey, chain, path string, state signerState) *guardedPV {
	return &guardedPV{key: key, pub: key.PubKey(), chain: chain, path: path, state: state, syncFile: (*os.File).Sync, syncDir: syncDirectory, logger: log.NewNopLogger()}
}

// GetPubKey is the registered key; it never waits for trust or continuity (START-10-6).
func (p *guardedPV) GetPubKey() (crypto.PubKey, error) {
	return p.pub, nil
}

// errBelowFloor marks a request at a height the signer's durable floor fences (RECOV-8.2-2).
var errBelowFloor = errors.New("height is fenced by the signer's durable floor (RECOV-8.2-2)")

// admit binds or fences the signer state for a session with report's process, durably, before
// the session may sign (RECOV-8.2-2). A never-used key/domain binds to its store instance and
// keeps no floor. For a key that has signed at H, a changed or absent binding (a rebuilt or
// imported store gets a fresh instance ID) raises the floor to at least H + 1 and binds the new
// instance; the floor never decreases. A Comet process other than the one this signer last
// admitted on the bound instance has to replay H: when the supervisor's startup check verified
// the saved replay binding, it enters a replay session; otherwise it is fenced the same way. A
// reconnect to the same live process on the same instance keeps the state (SYNC-9-4) and clears
// any replay confirmation, which a new request must earn again.
func (p *guardedPV) admit(report cometReport) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.uncertain != nil {
		return fmt.Errorf("%w: %w", errSigningStateUnsafe, p.uncertain)
	}
	proc := report.Process
	if !validStoreInstance(proc.StoreInstance) || proc.PID <= 0 {
		return errors.New("invalid Comet process report")
	}
	next := p.state
	reason := ""
	var replay *replaySession
	switch {
	case !next.signed():
		next.StoreInstance = proc.StoreInstance
	case next.StoreInstance != proc.StoreInstance:
		reason = "store instance changed or rebuilt"
	case p.admitted == nil || *p.admitted != proc:
		if replay = p.replayable(report.Replay); replay == nil {
			reason = "new Comet process; same-height replay not established"
		}
	case p.replay != nil:
		p.replay.confirmed = 0
	}
	if reason != "" {
		next.StoreInstance = proc.StoreInstance
		next.Floor = max(next.Floor, next.Height+1)
	}
	if next.StoreInstance != p.state.StoreInstance || next.Floor != p.state.Floor {
		if err := p.durably(func() error { return p.writeState(next) }); err != nil {
			return err
		}
		if reason != "" {
			p.logger.Info("signer_height_floor", "floor", next.Floor, "last_signed_height", next.Height, "store_instance", next.StoreInstance, "reason", reason)
		} else {
			p.logger.Info("signer_bound_store_instance", "store_instance", next.StoreInstance)
		}
		p.state = next
	}
	if p.admitted == nil || *p.admitted != proc {
		p.replay = replay
		if replay != nil {
			p.logger.Info("signer_replay_session", "height", replay.height, "repair", replay.repair, "startup_length", replay.startup.Length)
		}
	}
	admitted := proc
	p.admitted = &admitted
	return nil
}

// replayable is the replay session that report opens for the saved state, or nil: the report
// must verify exactly the saved binding of the last signature at its height, and pin a startup
// prefix that extends it.
func (p *guardedPV) replayable(report *replayReport) *replaySession {
	saved := p.state.Replay
	if report == nil || saved == nil || report.Height != p.state.Height || !report.Binding.equal(*saved) {
		return nil
	}
	startup := report.Startup
	if startup.Marker != saved.Marker || !bytes.Equal(startup.Predecessor, saved.Predecessor) || startup.Length < saved.Length || len(startup.Digest) != 32 {
		return nil
	}
	return &replaySession{height: p.state.Height, startup: startup, repair: report.Repair, interrupted: p.refused[p.state.Height]}
}

// replayHeight is the saved height of the current replay session.
func (p *guardedPV) replayHeight() (int64, bool) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.replay == nil {
		return 0, false
	}
	return p.replay.height, true
}

// setRequest records what the gate learned for the request it is passing on.
func (p *guardedPV) setRequest(request requestContext) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.request = request
}

// refusedAt records a refusal of a request at height before it reached the signer state.
func (p *guardedPV) refusedAt(height int64) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.refused == nil || len(p.refused) >= 64 {
		p.refused = map[int64]bool{}
	}
	p.refused[height] = true
	if p.replay != nil && p.replay.height == height {
		p.replay.interrupted = true
	}
}

// replayed applies the replay session to a request at its height, before the HRS answer: sameHRS
// requests repeat the saved HRS. It returns whether the request may proceed, whether a matching
// repeat confirms the saved decision (in an authenticated attempt, for a vote), and the binding
// to persist with a fresh signature. The caller holds mu.
func (p *guardedPV) replayed(sameHRS bool, step int8) (confirms bool, binding *replayBinding, err error) {
	r, observation := p.replay, p.request.observation
	inAttempt := observation != nil && observation.Open && observation.Height == r.height && !observation.Tainted && !r.repair
	// A repair, a replay error or another attempt clears admission.
	if r.confirmed != 0 && (observation == nil || observation.Tainted || (observation.Open && observation.Attempt != r.confirmed)) {
		r.confirmed = 0
	}
	switch {
	case sameHRS && inAttempt:
		// Stock's answer at the saved HRS; a proposal marks progress to the propose step only.
		return step != stepPropose, nil, nil
	case sameHRS && r.confirmed != 0:
		return false, nil, nil
	case r.confirmed != 0 && inAttempt:
		startup := r.startup
		return false, &startup, nil
	case r.confirmed != 0:
		return false, p.liveBinding(r.height), nil
	case inAttempt:
		return false, nil, errors.New("fresh signing at the replayed height stays closed until replay confirms the saved decision (RECOV-8.2-2)")
	}
	if r.repair || r.interrupted || (observation != nil && observation.Repaired) {
		return false, nil, errors.New("same-height replay was interrupted; signing at this height stays closed until the supervisor restarts the pair (RECOV-8.2-2)")
	}
	// Outside an authenticated attempt, unconfirmed: a skipped, failed or unverifiable replay.
	next := p.state
	next.Floor = max(next.Floor, r.height+1)
	if err = p.durably(func() error { return p.writeState(next) }); err != nil {
		return false, nil, err
	}
	p.state, p.replay = next, nil
	p.logger.Info("signer_height_floor", "floor", next.Floor, "last_signed_height", next.Height, "reason", "same-height replay not confirmed")
	return false, nil, fmt.Errorf("%w: height %d is below %d", errBelowFloor, r.height, next.Floor)
}

// liveBinding is the live WAL binding of a fresh signature at height, nil when unavailable.
func (p *guardedPV) liveBinding(height int64) *replayBinding {
	if p.request.live == nil {
		return nil
	}
	return p.request.live(height)
}

// equal compares two replay bindings field by field.
func (b replayBinding) equal(o replayBinding) bool {
	return b.Marker == o.Marker && b.Length == o.Length && bytes.Equal(b.Predecessor, o.Predecessor) && bytes.Equal(b.Digest, o.Digest)
}

// floor is the current durable minimum signable height.
func (p *guardedPV) floor() int64 {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.state.Floor
}

// admissible refuses, before any HRS check, a request this signer may not sign at all: another
// chain, uncertain state, no admitted session, or a height below the durable floor, which fences
// proposals and nil votes alike (RECOV-8.2-2). The caller holds mu.
func (p *guardedPV) admissible(chain string, height int64) error {
	switch {
	case chain != p.chain:
		return fmt.Errorf("signer serves chain %s, not %s", p.chain, chain)
	case p.uncertain != nil:
		return fmt.Errorf("%w: %w", errSigningStateUnsafe, p.uncertain)
	case p.admitted == nil:
		return errors.New("no Comet session has been bound to the signer state")
	case p.closed:
		return errors.New("the signer stopped after its precommit for a planned ruleset upgrade (START-10.1-14b)")
	case height < p.state.Floor:
		return fmt.Errorf("%w: height %d is below %d", errBelowFloor, height, p.state.Floor)
	}
	return nil
}

// lastSignState is the HRS in stock FilePV's type, so stock CheckHRS judges it.
func (p *guardedPV) lastSignState() privval.FilePVLastSignState {
	return privval.FilePVLastSignState{Height: p.state.Height, Round: p.state.Round, Step: p.state.Step, Signature: p.state.Signature, SignBytes: p.state.SignBytes}
}

// SignVote applies stock FilePV's signVote to the durable state.
func (p *guardedPV) SignVote(chain string, vote *tm.Vote) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	if err := p.admissible(chain, vote.Height); err != nil {
		return err
	}
	var step int8
	switch vote.Type {
	case tm.PrevoteType:
		step = stepPrevote
	case tm.PrecommitType:
		step = stepPrecommit
	default:
		return fmt.Errorf("error signing vote: unknown vote type %v", vote.Type)
	}
	lss := p.lastSignState()
	sameHRS, err := lss.CheckHRS(vote.Height, vote.Round, step)
	if err != nil {
		return fmt.Errorf("error signing vote: %w", err)
	}
	signBytes := types.VoteSignBytes(chain, vote)
	// Stock always signs the extension of a non-nil precommit, even an empty one; prevotes and
	// nil precommits carry none.
	var extSig []byte
	if vote.Type == tm.PrecommitType && !types.ProtoBlockIDIsNil(&vote.BlockID) {
		if extSig, err = p.key.Sign(types.VoteExtensionSignBytes(chain, vote)); err != nil {
			return fmt.Errorf("error signing vote: %w", err)
		}
	} else if len(vote.Extension) > 0 {
		return errors.New("error signing vote: unexpected vote extension - extensions are only allowed in non-nil precommits")
	}
	confirms, binding, err := p.continuity(vote.Height, sameHRS, step)
	if err != nil {
		return err
	}
	if sameHRS {
		timestamp, restored, err := p.repeat(signBytes, votesDifferOnlyByTimestamp)
		if err != nil {
			return fmt.Errorf("error signing vote: %w", err)
		}
		if confirms {
			p.confirm()
		}
		if restored {
			vote.Timestamp = timestamp
		}
		vote.Signature = p.state.Signature
		vote.ExtensionSignature = extSig
		p.closeAfterPrecommit(step)
		return nil
	}
	sig, err := p.key.Sign(signBytes)
	if err != nil {
		return fmt.Errorf("error signing vote: %w", err)
	}
	if err = p.record(vote.Height, vote.Round, step, signBytes, sig, binding); err != nil {
		return err
	}
	vote.Signature = sig
	vote.ExtensionSignature = extSig
	p.closeAfterPrecommit(step)
	return nil
}

// armStop arms the stop on a precommit (START-10.1-14b, RECOV-8.2-2). Under the signing lock, so
// it serializes with every request: when the last signature already is a precommit, the gate
// closes at once.
func (p *guardedPV) armStop() (bool, int64, int32) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if !p.stopArmed {
		p.stopArmed = true
		p.logger.Info("signer_stop_on_precommit_armed", "last_height", p.state.Height, "last_round", p.state.Round, "last_step", p.state.Step)
	}
	if !p.closed && p.state.signed() && p.state.Step == stepPrecommit {
		p.closed = true
	}
	if p.closed && !p.reported {
		p.reported = true
		return true, p.state.Height, p.state.Round
	}
	return false, 0, 0
}

// closeAfterPrecommit closes an armed gate after a precommit was persisted and is being
// returned. The caller holds mu.
func (p *guardedPV) closeAfterPrecommit(step int8) {
	if p.stopArmed && step == stepPrecommit && !p.closed {
		p.closed = true
		p.logger.Info("signer_stopped_after_precommit", "height", p.state.Height, "round", p.state.Round)
	}
}

// stoppedAfter hands a new closure to the gate once.
func (p *guardedPV) stoppedAfter() (bool, int64, int32) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.closed && !p.reported {
		p.reported = true
		return true, p.state.Height, p.state.Round
	}
	return false, 0, 0
}

// SignProposal applies stock FilePV's signProposal to the durable state.
func (p *guardedPV) SignProposal(chain string, proposal *tm.Proposal) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	if err := p.admissible(chain, proposal.Height); err != nil {
		return err
	}
	lss := p.lastSignState()
	sameHRS, err := lss.CheckHRS(proposal.Height, proposal.Round, stepPropose)
	if err != nil {
		return fmt.Errorf("error signing proposal: %w", err)
	}
	signBytes := types.ProposalSignBytes(chain, proposal)
	_, binding, err := p.continuity(proposal.Height, sameHRS, stepPropose)
	if err != nil {
		return err
	}
	if sameHRS {
		timestamp, restored, err := p.repeat(signBytes, proposalsDifferOnlyByTimestamp)
		if err != nil {
			return fmt.Errorf("error signing proposal: %w", err)
		}
		if restored {
			proposal.Timestamp = timestamp
		}
		proposal.Signature = p.state.Signature
		return nil
	}
	sig, err := p.key.Sign(signBytes)
	if err != nil {
		return fmt.Errorf("error signing proposal: %w", err)
	}
	if err = p.record(proposal.Height, proposal.Round, stepPropose, signBytes, sig, binding); err != nil {
		return err
	}
	proposal.Signature = sig
	return nil
}

// repeat answers a request at the saved HRS as stock does: identical sign bytes return the
// saved signature, a timestamp-only difference returns it with the saved timestamp, and anything
// else is conflicting data. The saved state is synchronized again before the signature is
// released, since an earlier synchronization may have failed. It returns the saved timestamp and
// whether the request's timestamp must be replaced by it.
func (p *guardedPV) repeat(signBytes []byte, differOnlyByTimestamp func(last, next []byte) (time.Time, bool, error)) (time.Time, bool, error) {
	identical := bytes.Equal(signBytes, p.state.SignBytes)
	timestamp, same := time.Time{}, identical
	if !identical {
		var err error
		if timestamp, same, err = differOnlyByTimestamp(p.state.SignBytes, signBytes); err != nil {
			return time.Time{}, false, err
		}
	}
	if !same {
		return time.Time{}, false, errors.New("conflicting data")
	}
	if err := p.durably(p.syncState); err != nil {
		return time.Time{}, false, err
	}
	return timestamp, !identical, nil
}

// continuity is the replay binding a fresh signature at height records, and whether a repeat of
// the saved HRS confirms a replay session: inside a replay session at its height its rules apply
// (replayed); everywhere else a fresh signature records the live binding of its flushed WAL input.
func (p *guardedPV) continuity(height int64, sameHRS bool, step int8) (bool, *replayBinding, error) {
	if p.replay != nil && height == p.replay.height {
		return p.replayed(sameHRS, step)
	}
	if sameHRS {
		return false, nil, nil
	}
	return false, p.liveBinding(height), nil
}

// confirm records that the current replay attempt confirmed the saved decision.
func (p *guardedPV) confirm() {
	if p.replay != nil && p.request.observation != nil {
		p.replay.confirmed = p.request.observation.Attempt
		p.logger.Info("signer_replay_confirmed", "height", p.replay.height, "attempt", p.replay.confirmed)
	}
}

// record persists a new HRS, its sign bytes, its signature and its replay binding (nil when
// same-height replay is unavailable) in one atomic write before the signature is released. A
// signature above a replay session's height ends that session.
func (p *guardedPV) record(height int64, round int32, step int8, signBytes, sig []byte, binding *replayBinding) error {
	next := p.state
	next.Height, next.Round, next.Step, next.SignBytes, next.Signature, next.Replay = height, round, step, signBytes, sig, binding
	if binding != nil && (binding.Marker >= height || binding.Marker < 0) {
		next.Replay = nil
	}
	if err := p.durably(func() error { return p.writeState(next) }); err != nil {
		return err
	}
	p.state = next
	if p.replay != nil && height > p.replay.height {
		p.replay = nil
	}
	return nil
}

// durably runs one persistence step under a durable inflight marker (markInflight). A marker that
// cannot be created or written panics like a failed write (exit 2, which the supervisor restarts).
// A failed fsync, of the marker or within the step, latches errSigningStateUnsafe and writes the
// fence: the state volume is failing. A failure to write the fence never clears the latch, and
// the inflight marker stays as same-boot evidence. A panic within the step removes the step's
// marker first, as the state is unchanged.
func (p *guardedPV) durably(step func() error) error {
	if p.uncertain != nil {
		return fmt.Errorf("%w: %w", errSigningStateUnsafe, p.uncertain)
	}
	if markErr := markInflight(inflightPath(p.path), p.syncFile, p.syncDir); markErr != nil {
		if errors.Is(markErr, errInflightWrite) {
			panic(markErr)
		}
		p.uncertain = markErr
		return fmt.Errorf("%w: %w", errSigningStateUnsafe, errors.Join(markErr, writeFence(fencePath(p.path), markErr)))
	}
	if err := p.underMarker(step); err != nil {
		p.uncertain = err
		return fmt.Errorf("%w: fsync of signing state: %w", errSigningStateUnsafe, errors.Join(err, writeFence(fencePath(p.path), err)))
	}
	// The state is durable whatever happens to the marker. One left behind makes the next
	// step's exclusive create panic and the restart on this boot refuse: both fail closed.
	if rmErr := os.Remove(inflightPath(p.path)); rmErr != nil {
		fmt.Fprintf(os.Stderr, "inflight marker not removed after a durable signing step: %v\n", rmErr)
	}
	return nil
}

// underMarker runs step under its durable inflight marker. A panic within it (a failed write or
// rename) comes at or before the atomic rename, so the state on disk and in the page cache is
// unchanged and none of this step's state fsyncs ran: there is nothing uncertain for the marker
// to record. It is removed before the panic goes on, so the process exits 2 and the supervisor
// restarts it like any crash, without an operator.
func (p *guardedPV) underMarker(step func() error) error {
	defer func() {
		if recovered := recover(); recovered != nil {
			_ = os.Remove(inflightPath(p.path))
			panic(recovered)
		}
	}()
	return step()
}

// syncState flushes the state file and then its directory, for a cached retry that writes
// nothing.
func (p *guardedPV) syncState() error {
	f, err := os.Open(p.path)
	if err != nil {
		return err
	}
	if err = p.syncFile(f); err != nil {
		f.Close()
		return err
	}
	if err = f.Close(); err != nil {
		return err
	}
	return p.syncDir(filepath.Dir(p.path))
}

// writeState replaces the state with next atomically: an exclusive random temporary file in the
// state's directory, its fsync, a rename over the state and the directory's fsync. A failed
// create, write, close or rename panics with the state unchanged; a failed fsync is returned.
func (p *guardedPV) writeState(next signerState) error {
	suffix := make([]byte, 8)
	if _, err := rand.Read(suffix); err != nil {
		panic(fmt.Errorf("signer state temporary name: %w", err))
	}
	temporary := p.path + ".tmp-" + hex.EncodeToString(suffix)
	f, err := os.OpenFile(temporary, os.O_WRONLY|os.O_CREATE|os.O_EXCL|syscall.O_NOFOLLOW, 0600)
	if err != nil {
		panic(fmt.Errorf("signer state temporary file: %w", err))
	}
	fail := func(cause error) {
		f.Close()
		os.Remove(temporary)
		panic(fmt.Errorf("signer state write: %w", cause))
	}
	if _, err = f.Write(next.encode()); err != nil {
		fail(err)
	}
	if err = p.syncFile(f); err != nil {
		f.Close()
		os.Remove(temporary)
		return err
	}
	if err = f.Close(); err != nil {
		os.Remove(temporary)
		panic(fmt.Errorf("signer state write: %w", err))
	}
	if err = os.Rename(temporary, p.path); err != nil {
		os.Remove(temporary)
		panic(fmt.Errorf("signer state rename: %w", err))
	}
	return p.syncDir(filepath.Dir(p.path))
}

// votesDifferOnlyByTimestamp is stock FilePV's checkVotesOnlyDifferByTimestamp: it compares the
// canonical votes with equal timestamps and returns the saved timestamp.
func votesDifferOnlyByTimestamp(last, next []byte) (time.Time, bool, error) {
	var lastVote, newVote tm.CanonicalVote
	if err := protoio.UnmarshalDelimited(last, &lastVote); err != nil {
		return time.Time{}, false, fmt.Errorf("saved sign bytes are not a vote: %w", err)
	}
	if err := protoio.UnmarshalDelimited(next, &newVote); err != nil {
		return time.Time{}, false, fmt.Errorf("sign bytes are not a vote: %w", err)
	}
	saved := lastVote.Timestamp
	lastVote.Timestamp, newVote.Timestamp = time.Time{}, time.Time{}
	return saved, proto.Equal(&newVote, &lastVote), nil
}

// proposalsDifferOnlyByTimestamp is stock FilePV's checkProposalsOnlyDifferByTimestamp.
func proposalsDifferOnlyByTimestamp(last, next []byte) (time.Time, bool, error) {
	var lastProposal, newProposal tm.CanonicalProposal
	if err := protoio.UnmarshalDelimited(last, &lastProposal); err != nil {
		return time.Time{}, false, fmt.Errorf("saved sign bytes are not a proposal: %w", err)
	}
	if err := protoio.UnmarshalDelimited(next, &newProposal); err != nil {
		return time.Time{}, false, fmt.Errorf("sign bytes are not a proposal: %w", err)
	}
	saved := lastProposal.Timestamp
	lastProposal.Timestamp, newProposal.Timestamp = time.Time{}, time.Time{}
	return saved, proto.Equal(&newProposal, &lastProposal), nil
}
