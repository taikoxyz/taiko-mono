package main

import (
	"os"
	"path/filepath"

	"github.com/cometbft/cometbft/privval"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
)

// durableFilePV completes stock FilePV's state persistence before publishing a
// signature. FilePV synchronously writes and renames its state, but does not
// fsync the containing directory, and cached HRS retries do not write at all.
type durableFilePV struct {
	*privval.FilePV
	state string
}

func loadDurableFilePV(key, state string) *durableFilePV {
	return &durableFilePV{FilePV: privval.LoadFilePV(key, state), state: state}
}

// syncState also runs for cached signatures: a prior synchronization may have
// failed after FilePV updated its in-memory last-sign state.
func (p *durableFilePV) syncState() error {
	f, err := os.Open(p.state)
	if err != nil {
		return err
	}
	if err = f.Sync(); err != nil {
		f.Close()
		return err
	}
	if err = f.Close(); err != nil {
		return err
	}
	return syncDirectory(filepath.Dir(p.state))
}

func (p *durableFilePV) SignVote(chain string, vote *tm.Vote) error {
	signed := *vote
	if err := p.FilePV.SignVote(chain, &signed); err != nil {
		return err
	}
	if err := p.syncState(); err != nil {
		return err
	}
	*vote = signed
	return nil
}

func (p *durableFilePV) SignProposal(chain string, proposal *tm.Proposal) error {
	signed := *proposal
	if err := p.FilePV.SignProposal(chain, &signed); err != nil {
		return err
	}
	if err := p.syncState(); err != nil {
		return err
	}
	*proposal = signed
	return nil
}
