package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/cometbft/cometbft/privval"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
)

// durableFilePV completes stock FilePV's state persistence before publishing a
// signature. FilePV synchronously writes and renames its state, but does not
// fsync the containing directory, and cached HRS retries do not write at all.
//
// The first failed synchronization refuses every later request, cached HRS retries
// included, because the in-memory state may then be ahead of what survives a crash.
// A failed stock write panics, so the in-memory state cannot otherwise run ahead of
// the file.
type durableFilePV struct {
	*privval.FilePV
	state string
	// fence is the write-ahead uncertainty record beside this chain's HRS.
	fence string
	// syncFile flushes the opened state file; tests replace it to fail as a disk does.
	syncFile func(*os.File) error
	// uncertain is the first synchronization failure; nothing is signed after it.
	uncertain error
}

func loadDurableFilePV(key, state string) *durableFilePV {
	return &durableFilePV{FilePV: privval.LoadFilePV(key, state), state: state, fence: uncertaintyPath(state), syncFile: (*os.File).Sync}
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
	return syncDirectory(filepath.Dir(p.state))
}

// signDurably runs one stock signing step and succeeds only once the state it
// recorded is durable; a failed synchronization latches errSigningStateUnsafe.
func (p *durableFilePV) signDurably(sign func() error) error {
	if p.uncertain != nil {
		return fmt.Errorf("%w: %w", errSigningStateUnsafe, p.uncertain)
	}
	if err := armUncertainty(p.fence, "FilePV signing", p.state); err != nil {
		p.uncertain = err
		return err
	}
	err := sign() // A stock persistence panic deliberately leaves the fence armed.
	if err := p.syncState(); err != nil {
		p.uncertain = err
		return fmt.Errorf("%w: %w", errSigningStateUnsafe, err)
	}
	if finishErr := finishUncertainty(p.fence); finishErr != nil {
		p.uncertain = finishErr
		return finishErr
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
