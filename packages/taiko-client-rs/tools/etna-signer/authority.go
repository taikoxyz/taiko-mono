package main

import (
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"sync"

	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	cmtjson "github.com/cometbft/cometbft/libs/json"
	"github.com/cometbft/cometbft/privval"
	"github.com/cometbft/cometbft/types"
)

type authorityConfig struct {
	Root, Key, LegacyState      string
	L1ChainID, L2ChainID, Inbox string
	EnrollLegacy                bool
}

func (c authorityConfig) chainID(g uint64) (string, error) {
	if g >= 1<<48 || !canonicalHex(c.Inbox, 20) {
		return "", errors.New("invalid generation or Inbox")
	}
	preimage := make([]byte, 32)
	copy(preimage, []byte("ETNA_COMET_DOMAIN_V1"))
	for _, decimal := range []string{c.L1ChainID, c.L2ChainID} {
		v, ok := new(big.Int).SetString(decimal, 10)
		if !ok || v.Sign() < 0 || v.BitLen() > 256 || v.String() != decimal {
			return "", errors.New("chain IDs must be canonical decimal uint256")
		}
		preimage = append(preimage, v.FillBytes(make([]byte, 32))...)
	}
	inbox, _ := hex.DecodeString(c.Inbox[2:])
	preimage = append(preimage, make([]byte, 12)...)
	preimage = append(preimage, inbox...)
	preimage = append(preimage, new(big.Int).SetUint64(g).FillBytes(make([]byte, 32))...)
	return "etna-" + base64.RawURLEncoding.EncodeToString(keccak(preimage)), nil
}

type authorityBinding struct {
	Schema      uint64 `json:"schema"`
	Root        string `json:"root"`
	Key         string `json:"key"`
	LegacyState string `json:"legacy_state"`
	PublicKey   string `json:"public_key"`
	L1ChainID   string `json:"l1_chain_id"`
	L2ChainID   string `json:"l2_chain_id"`
	Inbox       string `json:"inbox"`
}
type authorityDomain struct {
	Generation uint64          `json:"generation"`
	Chain      string          `json:"chain"`
	State      string          `json:"state"`
	Origin     *recoveryOrigin `json:"recovery_origin"`
}
type authorityManifest struct {
	Binding        authorityBinding  `json:"binding"`
	MarkersPending bool              `json:"markers_pending"`
	LegacyDigest   string            `json:"legacy_digest"`
	Watermark      uint64            `json:"watermark"`
	Domains        []authorityDomain `json:"domains"`
}
type authority struct {
	config    authorityConfig
	binding   authorityBinding
	native    secp256k1eth.PrivKey
	manifest  authorityManifest
	pending   *authorityDomain
	locks     []*os.File
	mu        sync.Mutex
	closed    bool
	uncertain bool
}

func (a *authority) Close() {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.closed {
		return
	}
	a.closed = true
	for i := len(a.locks) - 1; i >= 0; i-- {
		a.locks[i].Close()
	}
}
func (a *authority) lock(path string) error {
	f, e := ownerLock(path)
	if e == nil {
		a.locks = append(a.locks, f)
	}
	return e
}
func (a *authority) manifestPath() string { return filepath.Join(a.config.Root, "manifest.json") }
func (a *authority) intentPath() string   { return filepath.Join(a.config.Root, "intent.json") }
func (a *authority) markerPaths() []string {
	return []string{a.config.Key + ".authority.json", a.config.LegacyState + ".authority.json"}
}

// openAuthority fences legacy and all domains before reading enrollment metadata. It never
// creates a new domain HRS; only authorize may do so after fresh private session validation.
func openAuthority(c authorityConfig) (_ *authority, err error) {
	if _, err = c.chainID(0); err != nil {
		return nil, err
	}
	for _, p := range []*string{&c.Key, &c.LegacyState} {
		*p, err = existingFile(*p)
		if err != nil {
			return nil, err
		}
		if err = singleLinkState(*p); err != nil {
			return nil, err
		}
	}
	native, err := loadNativeKey(c.Key)
	if err != nil {
		return nil, err
	}
	a := &authority{config: c, native: native}
	defer func() {
		if err != nil {
			a.Close()
		}
	}()
	if err = a.lock(c.Key + ".lock"); err != nil {
		return nil, err
	}
	if err = a.lock(c.LegacyState + ".lock"); err != nil {
		return nil, err
	}
	// Existing external markers require the original registry to exist, even with enrollment set.
	var markers []*authorityBinding
	for _, p := range a.markerPaths() {
		var marker authorityBinding
		e := readAuthorityJSON(p, &marker)
		if e == nil {
			markers = append(markers, &marker)
		} else if os.IsNotExist(e) {
			markers = append(markers, nil)
		} else {
			return nil, e
		}
	}
	if c.Root == "" {
		return nil, errors.New("authority root required")
	}
	if markers[0] == nil && markers[1] == nil && c.EnrollLegacy {
		if err = os.MkdirAll(c.Root, 0700); err != nil {
			return nil, err
		}
		if err = syncDirectory(filepath.Dir(c.Root)); err != nil {
			return nil, err
		}
	}
	c.Root, err = filepath.EvalSymlinks(c.Root)
	if err != nil {
		return nil, err
	}
	c.Root, err = filepath.Abs(c.Root)
	if err != nil {
		return nil, err
	}
	a.config = c
	if err = a.lock(filepath.Join(c.Root, "owner.lock")); err != nil {
		return nil, err
	}
	a.binding = authorityBinding{1, c.Root, c.Key, c.LegacyState, hex.EncodeToString(native.PubKey().Bytes()), c.L1ChainID, c.L2ChainID, c.Inbox}
	for _, m := range markers {
		if m != nil && *m != a.binding {
			return nil, errors.New("authority marker binding mismatch")
		}
	}
	err = readAuthorityJSON(a.manifestPath(), &a.manifest)
	if os.IsNotExist(err) {
		if markers[0] != nil || markers[1] != nil {
			return nil, errors.New("authority registry missing behind enrollment marker")
		}
		if !c.EnrollLegacy {
			return nil, errors.New("explicit legacy enrollment required")
		}
		entries, e := os.ReadDir(c.Root)
		if e != nil {
			return nil, e
		}
		for _, entry := range entries {
			if entry.Name() != "owner.lock" {
				return nil, errors.New("nonempty uninitialized authority root")
			}
		}
		legacyChain, _ := c.chainID(0)
		if _, err = validateHRS(c.LegacyState, legacyChain, native.PubKey()); err != nil {
			return nil, err
		}
		raw, e := os.ReadFile(c.LegacyState)
		if e != nil {
			return nil, e
		}
		a.manifest = authorityManifest{Binding: a.binding, MarkersPending: true, LegacyDigest: hex.EncodeToString(keccak(raw)), Domains: []authorityDomain{{Generation: 0, Chain: legacyChain, State: c.LegacyState}}}
		if err = publishAuthority(a.manifestPath(), a.manifest); err != nil {
			return nil, err
		}
	} else if err != nil {
		return nil, err
	}
	if a.manifest.Binding != a.binding || len(a.manifest.Domains) == 0 {
		return nil, errors.New("invalid authority manifest binding")
	}
	if a.manifest.MarkersPending {
		if !c.EnrollLegacy || a.manifest.Watermark != 0 || len(a.manifest.Domains) != 1 {
			return nil, errors.New("incomplete legacy enrollment requires explicit resume")
		}
		raw, e := os.ReadFile(c.LegacyState)
		if e != nil {
			return nil, e
		}
		if hex.EncodeToString(keccak(raw)) != a.manifest.LegacyDigest {
			return nil, errors.New("legacy HRS changed during enrollment")
		}
		data, _ := json.Marshal(a.binding)
		for i, p := range a.markerPaths() {
			if markers[i] == nil {
				if err = exclusiveDurable(p, data); err != nil {
					return nil, err
				}
			}
		}
		a.manifest.MarkersPending = false
		if err = publishAuthority(a.manifestPath(), a.manifest); err != nil {
			return nil, err
		}
	} else if markers[0] == nil || markers[1] == nil {
		return nil, errors.New("authority enrollment marker missing")
	}
	var last uint64
	for i, d := range a.manifest.Domains {
		chain, e := c.chainID(d.Generation)
		if e != nil {
			return nil, e
		}
		expected := filepath.Join(c.Root, chain+".json")
		if i == 0 {
			expected = c.LegacyState
		}
		if d.Chain != chain || d.State != expected || (i == 0 && d.Generation != 0) || (i > 0 && d.Generation <= last) || (d.Generation == 0 && d.Origin != nil) || (d.Generation > 0 && (d.Origin == nil || d.Origin.Generation == nil || *d.Origin.Generation != d.Generation)) {
			return nil, errors.New("invalid authority domain entry")
		}
		if _, err = validateHRS(d.State, d.Chain, native.PubKey()); err != nil {
			return nil, err
		}
		if i > 0 {
			if err = a.lock(d.State + ".lock"); err != nil {
				return nil, err
			}
		}
		last = d.Generation
	}
	if a.manifest.Watermark != last {
		return nil, errors.New("inconsistent authority watermark")
	}
	var intent authorityDomain
	err = readAuthorityJSON(a.intentPath(), &intent)
	if err == nil {
		if intent.Generation == last {
			if !reflect.DeepEqual(intent, a.manifest.Domains[len(a.manifest.Domains)-1]) {
				return nil, errors.New("conflicting completed intent")
			}
			if err = os.Remove(a.intentPath()); err != nil {
				return nil, err
			}
			if err = syncDirectory(c.Root); err != nil {
				return nil, err
			}
		} else {
			expected, e := c.chainID(intent.Generation)
			if e != nil || intent.Generation < last || intent.Chain != expected || intent.State != filepath.Join(c.Root, expected+".json") || intent.Origin == nil {
				return nil, errors.New("invalid transition intent")
			}
			if _, e = os.Lstat(intent.State); e == nil {
				unsigned, e := validateHRS(intent.State, intent.Chain, native.PubKey())
				if e != nil || !unsigned {
					return nil, errors.New("ambiguous or signed un-enrolled HRS")
				}
			} else if !os.IsNotExist(e) {
				return nil, e
			}
			a.pending = &intent
		}
	} else if !os.IsNotExist(err) {
		return nil, err
	}
	allowed := map[string]bool{"manifest.json": true, "intent.json": a.pending != nil}
	for _, domain := range a.manifest.Domains {
		if filepath.Dir(domain.State) == c.Root {
			allowed[filepath.Base(domain.State)] = true
		}
	}
	if a.pending != nil {
		allowed[filepath.Base(a.pending.State)] = true
	}
	entries, e := os.ReadDir(c.Root)
	if e != nil {
		return nil, e
	}
	for _, entry := range entries {
		if strings.HasSuffix(entry.Name(), ".json") && !allowed[entry.Name()] {
			return nil, errors.New("orphan state in authority root")
		}
	}

	return a, nil
}
func (a *authority) authorize(chain string, r *trustResponse) (_ types.PrivValidator, err error) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.uncertain {
		return nil, errStateUncertain
	}
	if a.closed {
		return nil, errors.New("authority closed")
	}
	if r == nil {
		return nil, errors.New("missing authorization")
	}
	if err := trusted(r, chain); err != nil {
		return nil, err
	}
	g := *r.Generation
	expected, err := a.config.chainID(g)
	if err != nil || chain != expected || r.Target.Inbox != a.config.Inbox {
		return nil, errors.New("deployment domain mismatch")
	}
	if g < a.manifest.Watermark || (a.pending != nil && g < a.pending.Generation) {
		return nil, errors.New("superseded signing domain")
	}
	if g > 0 {
		if err = validRecovery(r); err != nil {
			return nil, err
		}
	} else if r.RecoveryOrigin != nil {
		return nil, errors.New("generation zero has recovery origin")
	}
	for _, d := range a.manifest.Domains {
		if d.Generation == g {
			if !reflect.DeepEqual(d.Origin, r.RecoveryOrigin) {
				return nil, errors.New("recovery origin changed")
			}
			if _, err = validateHRS(d.State, chain, a.native.PubKey()); err != nil {
				return nil, err
			}
			return &authorizedPV{authority: a, domain: d}, nil
		}
	}
	a.uncertain = true // Any transition failure requires restart and durable-state inspection.
	defer func() {
		if err != nil {
			err = fmt.Errorf("%w: %w", errStateUncertain, err)
		}
	}()
	d := authorityDomain{Generation: g, Chain: chain, State: filepath.Join(a.config.Root, chain+".json"), Origin: r.RecoveryOrigin}
	if err = a.recordIntent(d); err != nil {
		return nil, err
	}
	if err = a.stageDomain(d); err != nil {
		return nil, err
	}
	if err = a.publishDomain(d); err != nil {
		return nil, err
	}
	if err = os.Remove(a.intentPath()); err != nil {
		return nil, err
	}
	if err = syncDirectory(a.config.Root); err != nil {
		return nil, err
	}
	a.pending = nil
	a.uncertain = false
	return &authorizedPV{authority: a, domain: d}, nil
}

// recordIntent durably retires all earlier generations before creating any new state.
// Caller holds the authority mutex after independently verifying private authorization.
func (a *authority) recordIntent(d authorityDomain) error {
	if a.pending != nil {
		if !reflect.DeepEqual(d, *a.pending) {
			return errors.New("pending transition differs from authorization")
		}
		return nil
	}
	if _, err := os.Lstat(d.State); !os.IsNotExist(err) {
		return errors.New("orphan signing state")
	}
	data, _ := json.Marshal(d)
	if err := exclusiveDurable(a.intentPath(), data); err != nil {
		return err
	}
	a.pending = &d
	return nil
}

// stageDomain only exclusively creates a stock unsigned HRS under an already durable intent.
func (a *authority) stageDomain(d authorityDomain) error {
	if a.pending == nil || !reflect.DeepEqual(d, *a.pending) {
		return errors.New("domain creation requires matching intent")
	}
	if _, err := os.Lstat(d.State); os.IsNotExist(err) {
		pv := privval.NewFilePV(a.native, a.config.Key, d.State)
		data, e := cmtjson.MarshalIndent(pv.LastSignState, "", "  ")
		if e != nil {
			return e
		}
		if err = exclusiveDurable(d.State, data); err != nil {
			return err
		}
	} else if err != nil {
		return err
	}
	unsigned, err := validateHRS(d.State, d.Chain, a.native.PubKey())
	if err != nil || !unsigned {
		return errors.New("new domain state is not provably unsigned")
	}
	return nil
}

// publishDomain commits enrollment and the monotonic watermark atomically before signing.
func (a *authority) publishDomain(d authorityDomain) error {
	if err := a.lock(d.State + ".lock"); err != nil {
		return err
	}
	next := a.manifest
	next.Domains = append(append([]authorityDomain(nil), next.Domains...), d)
	next.Watermark = d.Generation
	if err := publishAuthority(a.manifestPath(), next); err != nil {
		return err
	}
	a.manifest = next
	return nil
}
