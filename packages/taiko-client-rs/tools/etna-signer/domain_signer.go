package main

import (
	"errors"

	"github.com/cometbft/cometbft/crypto"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
)

// domainSigner exposes identity for Comet's initial handshake without enrolling or loading
// a new domain. gate.handle replaces it with the freshly authorized domain for one request.
type domainSigner struct{ authority *authority }

func (s *domainSigner) GetPubKey() (crypto.PubKey, error) { return s.authority.native.PubKey(), nil }
func (*domainSigner) SignVote(string, *tm.Vote) error {
	return errors.New("domain requires private authorization")
}
func (*domainSigner) SignProposal(string, *tm.Proposal) error {
	return errors.New("domain requires private authorization")
}

// authorizedPV serializes FilePV access under the key-wide owner, rereads authoritative HRS,
// and rechecks retirement even if a caller retains a previously authorized handle.
type authorizedPV struct {
	authority *authority
	domain    authorityDomain
}

func (p *authorizedPV) GetPubKey() (crypto.PubKey, error) { return p.authority.native.PubKey(), nil }
func (p *authorizedPV) sign(chain string, sign func(*durableFilePV) error) error {
	a := p.authority
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.closed || a.uncertain || chain != p.domain.Chain || p.domain.Generation != a.manifest.Watermark || (a.pending != nil && a.pending.Generation > p.domain.Generation) {
		return errors.New("domain authority closed or superseded")
	}
	if _, err := validateHRS(p.domain.State, chain, a.native.PubKey()); err != nil {
		return err
	}
	return sign(loadDurableFilePV(a.config.Key, p.domain.State))
}
func (p *authorizedPV) SignVote(chain string, v *tm.Vote) error {
	if p.domain.Origin != nil && v.Height <= int64(*p.domain.Origin.Height) {
		return errors.New("cannot sign retained recovery prefix")
	}
	return p.sign(chain, func(pv *durableFilePV) error { return pv.SignVote(chain, v) })
}
func (p *authorizedPV) SignProposal(chain string, v *tm.Proposal) error {
	if p.domain.Origin != nil && v.Height <= int64(*p.domain.Origin.Height) {
		return errors.New("cannot sign retained recovery prefix")
	}
	return p.sign(chain, func(pv *durableFilePV) error { return pv.SignProposal(chain, v) })
}
