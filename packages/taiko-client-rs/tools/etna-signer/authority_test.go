package main

import (
	"bytes"
	"encoding/json"
	"github.com/cometbft/cometbft/privval"
	pv "github.com/cometbft/cometbft/proto/tendermint/privval"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

func authorityFixture(t *testing.T) authorityConfig {
	t.Helper()
	_, key, state := filePV(t)
	return authorityConfig{Root: filepath.Join(t.TempDir(), "authority"), Key: key, LegacyState: state, L1ChainID: "1", L2ChainID: "167001", Inbox: "0x" + strings.Repeat("1", 40), EnrollLegacy: true}
}
func readyDomain(t *testing.T, c authorityConfig, g uint64) (string, *trustResponse) {
	t.Helper()
	chain, err := c.chainID(g)
	if err != nil {
		t.Fatal(err)
	}
	value := snapshot(true)
	value["chain_id"] = chain
	value["generation"] = g
	target := value["target"].(map[string]any)
	target["generation"] = g
	target["inbox"] = c.Inbox
	if g > 0 {
		target["height"] = 6
		value["committed_head"].(map[string]any)["height"] = 6
		value["trusted_consensus_head"].(map[string]any)["height"] = 6
		value["recovery_origin"] = map[string]any{"generation": g, "height": 6, "l1_number": 9, "l1_hash": "0x" + strings.Repeat("a", 64), "l1_timestamp": 100, "el_hash": target["hash"], "comet_hash": target["comet_hash"], "forced_cursor": 0, "committee_hash": "0x" + strings.Repeat("d", 64)}
	}
	raw, _ := json.Marshal(value)
	var r trustResponse
	if err = json.Unmarshal(raw, &r); err != nil {
		t.Fatal(err)
	}
	return chain, &r
}
func authorityVote(h int64) *tm.Vote {
	return &tm.Vote{Type: tm.PrevoteType, Height: h, Timestamp: time.Unix(100, 0)}
}
func TestRecoveryDomainRetainsLegacyHRS(t *testing.T) {
	c := authorityFixture(t)
	oldChain, oldReady := readyDomain(t, c, 0)
	p := privval.LoadFilePV(c.Key, c.LegacyState)
	if err := p.SignVote(oldChain, authorityVote(20)); err != nil {
		t.Fatal(err)
	}
	legacyBefore, _ := os.ReadFile(c.LegacyState)
	keyBefore, _ := os.ReadFile(c.Key)
	a, err := openAuthority(c)
	if err != nil {
		t.Fatal(err)
	}
	defer a.Close()
	newChain, newReady := readyDomain(t, c, 2)
	signer, err := a.authorize(newChain, newReady)
	if err != nil {
		t.Fatal(err)
	}
	vote := authorityVote(7)
	if err = signer.SignVote(newChain, vote); err != nil {
		t.Fatal(err)
	}
	signature := append([]byte(nil), vote.Signature...)
	retry := authorityVote(7)
	if err = signer.SignVote(newChain, retry); err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(signature, retry.Signature) {
		t.Fatal("same-HRS retry changed")
	}
	if err = signer.SignVote(newChain, authorityVote(6)); err == nil {
		t.Fatal("height regression signed")
	}
	if _, err = a.authorize(oldChain, oldReady); err == nil {
		t.Fatal("superseded domain authorized")
	}
	legacyAfter, _ := os.ReadFile(c.LegacyState)
	keyAfter, _ := os.ReadFile(c.Key)
	if !bytes.Equal(legacyBefore, legacyAfter) {
		t.Fatal("legacy HRS changed")
	}
	if !bytes.Equal(keyBefore, keyAfter) {
		t.Fatal("key changed")
	}
	a.Close()
	c.EnrollLegacy = false
	a, err = openAuthority(c)
	if err != nil {
		t.Fatal(err)
	}
	defer a.Close()
	if _, err = a.authorize(oldChain, oldReady); err == nil {
		t.Fatal("restart reopened superseded domain")
	}
	signer, err = a.authorize(newChain, newReady)
	if err != nil {
		t.Fatal(err)
	}
	retry = authorityVote(7)
	if err = signer.SignVote(newChain, retry); err != nil || !bytes.Equal(signature, retry.Signature) {
		t.Fatal("restart lost retry", err)
	}
}
func TestAuthorityAliasesAndFullWidthDeployment(t *testing.T) {
	c := authorityFixture(t)
	a, err := openAuthority(c)
	if err != nil {
		t.Fatal(err)
	}
	defer a.Close()
	alias := filepath.Join(t.TempDir(), "alias")
	if err = os.Symlink(c.LegacyState, alias); err != nil {
		t.Fatal(err)
	}
	other := c
	other.LegacyState = alias
	other.Root = filepath.Join(t.TempDir(), "other")
	if b, e := openAuthority(other); e == nil {
		b.Close()
		t.Fatal("alias got second owner")
	}
	a.Close()
	other = c
	other.L1ChainID = "1606938044258990275541962092341162602522202993782792835301377"
	if b, e := openAuthority(other); e == nil {
		b.Close()
		t.Fatal("full width deployment binding lost")
	}
}
func TestAuthorityMissingEnrolledStateNeverRecreated(t *testing.T) {
	c := authorityFixture(t)
	a, err := openAuthority(c)
	if err != nil {
		t.Fatal(err)
	}
	chain, r := readyDomain(t, c, 1)
	if _, err = a.authorize(chain, r); err != nil {
		t.Fatal(err)
	}
	a.Close()
	path := filepath.Join(c.Root, chain+".json")
	if err = os.Remove(path); err != nil {
		t.Fatal(err)
	}
	if b, e := openAuthority(c); e == nil {
		b.Close()
		t.Fatal("missing enrolled state accepted")
	}
	if _, e := os.Stat(path); !os.IsNotExist(e) {
		t.Fatal("missing HRS recreated")
	}
}
func TestAuthorityRequiresExplicitEnrollment(t *testing.T) {
	c := authorityFixture(t)
	c.EnrollLegacy = false
	if a, e := openAuthority(c); e == nil {
		a.Close()
		t.Fatal("implicit enrollment accepted")
	}
}

func TestAuthorityPendingTransitionFencesAcrossRestart(t *testing.T) {
	for _, stage := range []string{"intent", "unsigned", "signed-orphan", "manifest"} {
		t.Run(stage, func(t *testing.T) {
			c := authorityFixture(t)
			a, err := openAuthority(c)
			if err != nil {
				t.Fatal(err)
			}
			old, oldReady := readyDomain(t, c, 0)
			next, r := readyDomain(t, c, 2)
			d := authorityDomain{Generation: 2, Chain: next, State: filepath.Join(a.config.Root, next+".json"), Origin: r.RecoveryOrigin}
			data, _ := json.Marshal(d)
			if err = exclusiveDurable(a.intentPath(), data); err != nil {
				t.Fatal(err)
			}
			if stage != "intent" {
				p := privval.NewFilePV(a.native, c.Key, d.State)
				p.LastSignState.Save()
				if stage == "signed-orphan" {
					if err = p.SignVote(next, authorityVote(7)); err != nil {
						t.Fatal(err)
					}
				}
			}
			if stage == "manifest" {
				a.manifest.Domains = append(a.manifest.Domains, d)
				a.manifest.Watermark = 2
				if err = publishAuthority(a.manifestPath(), a.manifest); err != nil {
					t.Fatal(err)
				}
			}
			before, _ := os.ReadFile(c.LegacyState)
			a.Close()
			a, err = openAuthority(c)
			if stage == "signed-orphan" {
				if err == nil {
					a.Close()
					t.Fatal("signed orphan reopened")
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			defer a.Close()
			if _, err = a.authorize(old, oldReady); err == nil {
				t.Fatal("pending intent reopened old domain")
			}
			p, err := a.authorize(next, r)
			if err != nil {
				t.Fatal(err)
			}
			if err = p.SignVote(next, authorityVote(7)); err != nil {
				t.Fatal(err)
			}
			after, _ := os.ReadFile(c.LegacyState)
			if !bytes.Equal(before, after) {
				t.Fatal("old HRS changed")
			}
		})
	}
}
func TestAuthorityMarkerLossOrRegistryLossFailsClosed(t *testing.T) {
	for _, remove := range []string{"manifest.json", "key-marker", "state-marker"} {
		t.Run(remove, func(t *testing.T) {
			c := authorityFixture(t)
			a, e := openAuthority(c)
			if e != nil {
				t.Fatal(e)
			}
			a.Close()
			path := filepath.Join(c.Root, remove)
			if remove == "key-marker" {
				path = c.Key + ".authority.json"
			}
			if remove == "state-marker" {
				path = c.LegacyState + ".authority.json"
			}
			if e = os.Remove(path); e != nil {
				t.Fatal(e)
			}
			if a, e = openAuthority(c); e == nil {
				a.Close()
				t.Fatal("lost authority recreated")
			}
		})
	}
}
func TestAuthorityRejectsAmbiguousLegacyAndWrongSignedDomain(t *testing.T) {
	for _, mode := range []string{"wrong-domain", "missing-signature", "missing-height", "bad-signature"} {
		t.Run(mode, func(t *testing.T) {
			c := authorityFixture(t)
			chain, _ := readyDomain(t, c, 0)
			if mode == "wrong-domain" {
				chain = "other"
			}
			p := privval.LoadFilePV(c.Key, c.LegacyState)
			if e := p.SignVote(chain, authorityVote(20)); e != nil {
				t.Fatal(e)
			}
			if mode != "wrong-domain" {
				raw, _ := os.ReadFile(c.LegacyState)
				var v map[string]any
				json.Unmarshal(raw, &v)
				if mode == "missing-signature" {
					delete(v, "signature")
				}
				if mode == "missing-height" {
					delete(v, "height")
				}
				if mode == "bad-signature" {
					v["signature"] = "AAAA"
				}
				raw, _ = json.Marshal(v)
				os.WriteFile(c.LegacyState, raw, 0600)
			}
			before, _ := os.ReadFile(c.LegacyState)
			if a, e := openAuthority(c); e == nil {
				a.Close()
				t.Fatal("ambiguous legacy enrolled")
			}
			after, _ := os.ReadFile(c.LegacyState)
			if !bytes.Equal(before, after) {
				t.Fatal("legacy modified")
			}
		})
	}
}
func TestAuthorityHandshakeDoesNotCreateDomain(t *testing.T) {
	c := authorityFixture(t)
	a, e := openAuthority(c)
	if e != nil {
		t.Fatal(e)
	}
	defer a.Close()
	chain, r := readyDomain(t, c, 1)
	r.Ready = false
	r.Syncing = true
	r.Phase = "acquiring"
	path := control(t, func(map[string]any) any { return r })
	g := armed(path)
	s := &domainSigner{authority: a}
	req := pv.Message{Sum: &pv.Message_PubKeyRequest{PubKeyRequest: &pv.PubKeyRequest{ChainId: chain}}}
	if _, e = g.handle(s, req, chain); e != nil {
		t.Fatal(e)
	}
	if _, e = g.handle(s, pv.Message{Sum: &pv.Message_PingRequest{PingRequest: &pv.PingRequest{}}}, chain); e != nil {
		t.Fatal(e)
	}
	req = pv.Message{Sum: &pv.Message_SignVoteRequest{SignVoteRequest: &pv.SignVoteRequest{ChainId: chain, Vote: authorityVote(7)}}}
	if _, e = g.handle(s, req, chain); e == nil {
		t.Fatal("closed trust signed")
	}
	if _, e = os.Stat(filepath.Join(c.Root, chain+".json")); !os.IsNotExist(e) {
		t.Fatal("handshake created new domain HRS")
	}
}

func TestAuthorityOrphanAndIncompleteMetadataFailClosed(t *testing.T) {
	for _, mode := range []string{"orphan", "missing-watermark", "null-pending", "corrupt-enrolled"} {
		t.Run(mode, func(t *testing.T) {
			c := authorityFixture(t)
			a, e := openAuthority(c)
			if e != nil {
				t.Fatal(e)
			}
			next, _ := readyDomain(t, c, 1)
			a.Close()
			if mode == "orphan" {
				p := privval.NewFilePV(a.native, c.Key, filepath.Join(c.Root, next+".json"))
				p.LastSignState.Save()
				if e = p.SignVote(next, authorityVote(7)); e != nil {
					t.Fatal(e)
				}
			} else if mode == "corrupt-enrolled" {
				os.WriteFile(c.LegacyState, []byte("{}"), 0600)
			} else {
				path := filepath.Join(c.Root, "manifest.json")
				raw, _ := os.ReadFile(path)
				var fields map[string]any
				json.Unmarshal(raw, &fields)
				if mode == "missing-watermark" {
					delete(fields, "watermark")
				} else {
					fields["markers_pending"] = nil
				}
				raw, _ = json.Marshal(fields)
				os.WriteFile(path, raw, 0600)
			}
			if a, e = openAuthority(c); e == nil {
				a.Close()
				t.Fatal("ambiguous authority reopened")
			}
		})
	}
}

func TestAuthorityDomainMatchesFullWidthProtocolVectors(t *testing.T) {
	raw, e := os.ReadFile("../../../../testdata/etna_vectors/vectors.json")
	if e != nil {
		t.Fatal(e)
	}
	var vectors struct {
		Domains []struct {
			L1         string `json:"l1_chain_id"`
			L2         string `json:"l2_chain_id"`
			Inbox      string `json:"inbox"`
			Generation string `json:"generation"`
			Chain      string `json:"chain_id"`
		} `json:"chain_domains"`
	}
	if e = json.Unmarshal(raw, &vectors); e != nil {
		t.Fatal(e)
	}
	if len(vectors.Domains) == 0 {
		t.Fatal("missing domain vectors")
	}
	for _, v := range vectors.Domains {
		g, e := strconv.ParseUint(v.Generation, 10, 64)
		if e != nil {
			t.Fatal(e)
		}
		actual, e := (authorityConfig{L1ChainID: v.L1, L2ChainID: v.L2, Inbox: v.Inbox}).chainID(g)
		if e != nil || actual != v.Chain {
			t.Fatalf("domain mismatch %s: %s %v", v.Chain, actual, e)
		}
	}
}
func TestAuthorityRetainedHandleAndConcurrentRequestsCannotRegress(t *testing.T) {
	c := authorityFixture(t)
	a, e := openAuthority(c)
	if e != nil {
		t.Fatal(e)
	}
	defer a.Close()
	old, r := readyDomain(t, c, 0)
	oldPV, e := a.authorize(old, r)
	if e != nil {
		t.Fatal(e)
	}
	next, r := readyDomain(t, c, 1)
	one, e := a.authorize(next, r)
	if e != nil {
		t.Fatal(e)
	}
	two, e := a.authorize(next, r)
	if e != nil {
		t.Fatal(e)
	}
	if e = one.SignVote(next, authorityVote(9)); e != nil {
		t.Fatal(e)
	}
	if e = two.SignVote(next, authorityVote(8)); e == nil {
		t.Fatal("second handle regressed HRS")
	}
	if e = oldPV.SignVote(old, authorityVote(20)); e == nil {
		t.Fatal("retired handle signed")
	}
}

func TestAuthorityInterruptedLegacyMarkerPublication(t *testing.T) {
	for _, count := range []int{0, 1, 2} {
		t.Run(strconv.Itoa(count), func(t *testing.T) {
			c := authorityFixture(t)
			a, e := openAuthority(c)
			if e != nil {
				t.Fatal(e)
			}
			a.manifest.MarkersPending = true
			if e = publishAuthority(a.manifestPath(), a.manifest); e != nil {
				t.Fatal(e)
			}
			for i, path := range a.markerPaths() {
				if i >= count {
					if e = os.Remove(path); e != nil {
						t.Fatal(e)
					}
				}
			}
			a.Close()
			before, _ := os.ReadFile(c.LegacyState)
			resume := c
			resume.EnrollLegacy = false
			if b, e := openAuthority(resume); e == nil {
				b.Close()
				t.Fatal("incomplete enrollment resumed implicitly")
			}
			a, e = openAuthority(c)
			if e != nil {
				t.Fatal(e)
			}
			a.Close()
			a, e = openAuthority(c)
			if e != nil {
				t.Fatal(e)
			}
			a.Close()
			after, _ := os.ReadFile(c.LegacyState)
			if !bytes.Equal(before, after) {
				t.Fatal("enrollment rewrote legacy HRS")
			}
		})
	}
}
func TestAuthorityRecoveryCannotSignAtOrBeforeOrigin(t *testing.T) {
	c := authorityFixture(t)
	a, e := openAuthority(c)
	if e != nil {
		t.Fatal(e)
	}
	defer a.Close()
	next, r := readyDomain(t, c, 1)
	p, e := a.authorize(next, r)
	if e != nil {
		t.Fatal(e)
	}
	if e = p.SignVote(next, authorityVote(6)); e == nil {
		t.Fatal("recovery signed retained prefix")
	}
}
