package main

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"github.com/cometbft/cometbft/privval"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
)

// durableFilePV completes stock FilePV's state persistence before publishing a
// signature. FilePV writes its state through an O_SYNC temporary file and a rename,
// but does not fsync the containing directory, and cached HRS retries do not write
// at all. So every signing step, cached retries included, fsyncs the state file and its
// directory (SYNC-9-13).
//
// A crash outside a signing step needs no fence: no signature is released before both
// fsyncs succeed, and the disk holds either the old or the new HRS, so a restart that
// signs an unreleased step again cannot equivocate. A failed fsync makes the latest state
// uncertain (RECOV-8.2-3): the first one refuses every later request, cached HRS retries
// included, and writes the fence that makes a restart refuse. A failed stock write panics
// before its rename, so the state on disk is unchanged.
//
// A death after a failed fsync and before a durable fence would leave no fence, and on
// the same boot the failed write-back's error is already cleared: a restart's fsync then
// succeeds over pages that never reached disk. So each step first makes an inflight
// marker naming this boot durable, with two more fsyncs before stock FilePV writes, and
// removes it once the state is durable; a restart on the same boot refuses a marker it
// finds (refuseInflight). A step costs four fsyncs.
type durableFilePV struct {
	*privval.FilePV
	state string
	// syncFile flushes the opened state file or inflight marker; tests replace it to fail
	// as a disk does.
	syncFile func(*os.File) error
	// syncDir flushes the state's directory; tests replace it to count or fail.
	syncDir func(string) error
	// uncertain is the first synchronization failure; nothing is signed after it.
	uncertain error
}

func loadDurableFilePV(key, state string) *durableFilePV {
	return &durableFilePV{FilePV: privval.LoadFilePV(key, state), state: state, syncFile: (*os.File).Sync, syncDir: syncDirectory}
}

// syncState also runs for cached signatures: a prior synchronization may have
// failed after FilePV updated its in-memory last-sign state.
func (p *durableFilePV) syncState() error {
	f, err := os.Open(p.state)
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
	return p.syncDir(filepath.Dir(p.state))
}

// signDurably runs one stock signing step and succeeds only once the state it
// recorded is durable. It runs the step only once the inflight marker is durable, so a
// failure there leaves the state unchanged. A marker that cannot be created or written
// panics like a failed stock write (exit 2, which the supervisor restarts). A failed
// fsync of the marker, or of the state after the step, latches errSigningStateUnsafe
// and writes the fence: the HRS volume is failing. A failure to write the fence never
// clears the latch, and the inflight marker stays as same-boot evidence. A stock panic
// removes the step's marker first (signUnderMarker), so it restarts too.
func (p *durableFilePV) signDurably(sign func() error) error {
	if p.uncertain != nil {
		return fmt.Errorf("%w: %w", errSigningStateUnsafe, p.uncertain)
	}
	if markErr := markInflight(inflightPath(p.state), p.syncFile, p.syncDir); markErr != nil {
		if errors.Is(markErr, errInflightWrite) {
			panic(markErr)
		}
		p.uncertain = markErr
		return fmt.Errorf("%w: %w", errSigningStateUnsafe, errors.Join(markErr, writeFence(fencePath(p.state), markErr)))
	}
	err := p.signUnderMarker(sign)
	if syncErr := p.syncState(); syncErr != nil {
		p.uncertain = syncErr
		return fmt.Errorf("%w: fsync of signing state: %w", errSigningStateUnsafe, errors.Join(syncErr, writeFence(fencePath(p.state), syncErr)))
	}
	// The state is durable whatever happens to the marker. One left behind makes the next
	// step's exclusive create panic and the restart on this boot refuse: both fail closed.
	if rmErr := os.Remove(inflightPath(p.state)); rmErr != nil {
		fmt.Fprintf(os.Stderr, "inflight marker not removed after a durable signing step: %v\n", rmErr)
	}
	return err
}

// signUnderMarker runs one stock signing step under its durable inflight marker. A stock
// persistence panic (a failed temporary write or rename, or a corrupt last-sign state) comes
// at or before FilePV's atomic rename, so the HRS on disk and in the page cache is unchanged
// and none of this step's state fsyncs ran: there is nothing uncertain for the marker to
// record. It is removed before the panic goes on, so the process exits 2 and the supervisor
// restarts it like any crash, without an operator. No signature is released either way.
func (p *durableFilePV) signUnderMarker(sign func() error) error {
	defer func() {
		if recovered := recover(); recovered != nil {
			_ = os.Remove(inflightPath(p.state))
			panic(recovered)
		}
	}()
	return sign()
}

func (p *durableFilePV) SignVote(chain string, vote *tm.Vote) error {
	signed := *vote
	if err := p.signDurably(func() error { return p.FilePV.SignVote(chain, &signed) }); err != nil {
		return err
	}
	*vote = signed
	return nil
}

func (p *durableFilePV) SignProposal(chain string, proposal *tm.Proposal) error {
	signed := *proposal
	if err := p.signDurably(func() error { return p.FilePV.SignProposal(chain, &signed) }); err != nil {
		return err
	}
	*proposal = signed
	return nil
}
