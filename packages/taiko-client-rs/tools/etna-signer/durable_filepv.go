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
// at all. So every signing step, cached retries included, costs exactly two fsyncs:
// the state file and its directory (SYNC-9-13).
//
// A crash needs no fence: no signature is released before both fsyncs succeed, and
// the disk holds either the old or the new HRS, so a restart that signs an
// unreleased step again cannot equivocate. A failed fsync makes the latest state
// uncertain (RECOV-8.2-3): the first one refuses every later request, cached HRS
// retries included, and writes the fence that makes a restart refuse. A failed
// stock write panics, so the in-memory state cannot otherwise run ahead of the file.
type durableFilePV struct {
	*privval.FilePV
	state string
	// syncFile flushes the opened state file; tests replace it to fail as a disk does.
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
// recorded is durable. A failed synchronization latches errSigningStateUnsafe and
// writes the fence; a failure to write the fence never clears the latch.
func (p *durableFilePV) signDurably(sign func() error) error {
	if p.uncertain != nil {
		return fmt.Errorf("%w: %w", errSigningStateUnsafe, p.uncertain)
	}
	err := sign() // A stock persistence panic exits before any signature is released.
	if syncErr := p.syncState(); syncErr != nil {
		p.uncertain = syncErr
		return fmt.Errorf("%w: fsync of signing state: %w", errSigningStateUnsafe, errors.Join(syncErr, writeFence(fencePath(p.state), syncErr)))
	}
	return err
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
