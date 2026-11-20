package bootstrap_test

import (
	"bytes"
	"crypto/sha256"
	_ "embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"reflect"
	"testing"
	"time"

	dbm "github.com/cometbft/cometbft-db"
	abci "github.com/cometbft/cometbft/abci/types"
	"github.com/cometbft/cometbft/crypto/ed25519"
	cmtstate "github.com/cometbft/cometbft/proto/tendermint/state"
	"github.com/cometbft/cometbft/state"
	"github.com/cometbft/cometbft/types"
)

const receiptSHA = "ffb50b92a5b22220b6a1e44821e2731c1b29466cdabbea12211ca4866b71bea6"

var caseIDs = []string{"origin-base", "origin-landed-alternate", "current-base", "current-first-alternate", "current-second-alternate"}

//go:embed mapping_vectors.json
var mappingJSON []byte

type symbolicSet struct {
	Keys       []int64 `json:"keys"`
	Powers     []int64 `json:"powers"`
	Priorities []int64 `json:"priorities"`
	Proposer   int64   `json:"proposer"`
}
type cometReceipt struct {
	AppHash       json.RawMessage `json:"appHash"`
	BlockID       json.RawMessage `json:"blockID"`
	Chain         json.RawMessage `json:"chain"`
	Height        int64           `json:"height"`
	InitialHeight int64           `json:"initialHeight"`
	Last          json.RawMessage `json:"last"`
	Next          symbolicSet     `json:"next"`
	ParamsChanged int64           `json:"paramsChanged"`
	Results       json.RawMessage `json:"results"`
	Time          int64           `json:"time"`
	ValChanged    int64           `json:"valChanged"`
	Validators    symbolicSet     `json:"validators"`
}
type headerReceipt struct {
	AppHash json.RawMessage `json:"appHash"`
	Chain   json.RawMessage `json:"chain"`
	Height  int64           `json:"height"`
	Next    json.RawMessage `json:"next"`
	Time    int64           `json:"time"`
}
type rawReceipt struct {
	L1 struct {
		Height     int64 `json:"height"`
		Origin     int64 `json:"origin"`
		OriginTime int64 `json:"originTime"`
		Generation int64 `json:"generation"`
		Finalized  bool  `json:"finalized"`
	} `json:"l1"`
	Peer struct {
		Header   headerReceipt `json:"header"`
		Preimage struct {
			First  symbolicSet `json:"first"`
			Second symbolicSet `json:"second"`
		} `json:"preimage"`
	} `json:"peer"`
}
type caseReceipt struct {
	ID           string `json:"id"`
	ImportHeight int64  `json:"import_height"`
	RawCase      int64  `json:"raw_case"`
	Observation  struct {
		Raw         rawReceipt `json:"raw"`
		Publication struct {
			Present bool     `json:"present"`
			Crash   bool     `json:"crash"`
			Durable []string `json:"durable"`
			Stores  struct {
				Comet cometReceipt `json:"comet"`
				App   struct {
					AppHash       json.RawMessage `json:"appHash"`
					Height        int64           `json:"height"`
					InitialHeight int64           `json:"initialHeight"`
					Chain         json.RawMessage `json:"chain"`
					Active        json.RawMessage `json:"active"`
					Pending       json.RawMessage `json:"pending"`
				} `json:"app"`
				EL struct {
					Hash      json.RawMessage `json:"hash"`
					Height    int64           `json:"height"`
					Ancestors []int64         `json:"ancestors"`
				} `json:"el"`
				Evidence struct {
					Markers    json.RawMessage `json:"markers"`
					Validators json.RawMessage `json:"validators"`
					Commits    json.RawMessage `json:"commits"`
				} `json:"evidence"`
			} `json:"stores"`
		} `json:"publication"`
		AtPublication struct {
			Trusted   bool    `json:"trusted"`
			Connected bool    `json:"connected"`
			Published bool    `json:"published"`
			HRS       []int64 `json:"hrs"`
		} `json:"atPublication"`
	} `json:"observation"`
}
type mappingVector struct {
	Domain string          `json:"domain"`
	Symbol json.RawMessage `json:"symbol"`
	SHA    string          `json:"sha256"`
}
type profile struct {
	First, Next, Last                symbolicSet
	FirstOrder, NextOrder, LastOrder []int64
	Raw                              int64
	Origin                           bool
	CurrentHash, NextHash            string
}

// Independent literal expectations come from the reviewed two-update stock
// prefix, not from the adapter or from reconstructed M10 transition code.
func literalProfile(id string) profile {
	gFirst := symbolicSet{[]int64{1, 2}, []int64{3, 2}, []int64{-2, 2}, 1}
	gNext := symbolicSet{[]int64{1, 2}, []int64{3, 2}, []int64{1, -1}, 2}
	aHash := "a1cb5fa4a11a059e10f2629c6a7b4bf4bf1bb01598b2bb4da4a4ca478fb6f70e"
	p := profile{First: symbolicSet{[]int64{1, 2}, []int64{3, 2}, []int64{-1, 1}, 1}, Next: symbolicSet{[]int64{2, 3}, []int64{2, 4}, []int64{2, -1}, 2}, Last: gNext,
		FirstOrder: []int64{1, 2}, NextOrder: []int64{3, 2}, LastOrder: []int64{1, 2}, CurrentHash: aHash, NextHash: "c1cbd8a15aed6a0569b390471f1d0a6aee586c9804adccbc04de4ba4cd25511b"}
	switch id {
	case "origin-base", "origin-landed-alternate":
		p.First = gFirst
		p.Next = gNext
		p.Last = symbolicSet{}
		p.FirstOrder = []int64{1, 2}
		p.NextOrder = []int64{1, 2}
		p.LastOrder = nil
		p.Origin = true
		p.NextHash = aHash
		if id == "origin-landed-alternate" {
			p.Raw = 11
		}
	case "current-base":
	case "current-first-alternate":
		p.First = symbolicSet{[]int64{1, 2}, []int64{3, 5}, []int64{4, -4}, 2}
		p.Next.Priorities = []int64{-1, 1}
		p.FirstOrder = []int64{2, 1}
		p.Raw = 11
		p.CurrentHash = "caf5c7c9ee3d63b4b76b0843f55d8f239f96bf9243174c52722a268c3339f81e"
	case "current-second-alternate":
		p.Next.Powers = []int64{3, 4}
		p.Next.Priorities = []int64{2, -2}
		p.Raw = 20
		p.NextHash = "0d42f105847f1adf13f2cf5ec7572b6782696d0a21f18e0e7df2342db139de70"
	default:
		panic("unexpected case ID")
	}
	return p
}
func mustJSON(v any) json.RawMessage {
	b, err := json.Marshal(v)
	if err != nil {
		panic(err)
	}
	return b
}
func canonical(raw json.RawMessage) ([]byte, error) {
	var v any
	d := json.NewDecoder(bytes.NewReader(raw))
	d.UseNumber()
	if err := d.Decode(&v); err != nil {
		return nil, err
	}
	return json.Marshal(v)
}
func sameSymbol(a, b json.RawMessage) bool {
	x, e := canonical(a)
	y, f := canonical(b)
	return e == nil && f == nil && bytes.Equal(x, y)
}
func symbolEqual(raw json.RawMessage, v any) bool { return sameSymbol(raw, mustJSON(v)) }
func kp(s symbolicSet) any                        { return []any{s.Keys, s.Powers} }

func auditReceipt(c caseReceipt) error {
	p := literalProfile(c.ID)
	height := int64(4)
	last := any([]any{"WindowValidators", 4})
	results := any([]any{"FixedExecTxResult"})
	blockHeight := int64(4)
	clock := int64(102)
	valChanged := int64(6)
	paramsChanged := int64(5)
	if p.Origin {
		height = 2
		last = []any{}
		results = []any{}
		blockHeight = 0
		clock = 100
		valChanged = 3
		paramsChanged = 3
	}
	raw := c.Observation.Raw
	pub := c.Observation.Publication
	s := pub.Stores.Comet
	a := pub.Stores.App
	if c.ImportHeight != height || c.RawCase != p.Raw || raw.L1.Height != height || raw.L1.Origin != 2 || raw.L1.OriginTime != 100 || raw.L1.Generation != 1 || !raw.L1.Finalized {
		return fmt.Errorf("raw context")
	}
	if !pub.Present || pub.Crash || !reflect.DeepEqual(pub.Durable, []string{"app", "comet", "el", "evidence"}) || !c.Observation.AtPublication.Published || c.Observation.AtPublication.Trusted || c.Observation.AtPublication.Connected || !reflect.DeepEqual(c.Observation.AtPublication.HRS, []int64{1, 9, 2}) {
		return fmt.Errorf("publication markers")
	}
	if s.Height != blockHeight || s.InitialHeight != 3 || s.Time != clock || s.ValChanged != valChanged || s.ParamsChanged != paramsChanged {
		return fmt.Errorf("published scalar fields")
	}
	if !symbolEqual(s.Chain, []any{"Chain", 1}) || !symbolEqual(s.AppHash, []any{"EL", height}) || !symbolEqual(s.Last, last) || !symbolEqual(s.Results, results) {
		return fmt.Errorf("published symbolic fields")
	}
	if !reflect.DeepEqual(s.Validators, p.First) || !reflect.DeepEqual(s.Next, p.Next) {
		return fmt.Errorf("published validator pair")
	}
	if a.Height != blockHeight || a.InitialHeight != 3 || !symbolEqual(a.Chain, []any{"Chain", 1}) || !symbolEqual(a.AppHash, []any{"EL", height}) || !symbolEqual(a.Active, kp(p.First)) || !symbolEqual(a.Pending, kp(p.Next)) {
		return fmt.Errorf("app publication")
	}
	if pub.Stores.EL.Height != height || !symbolEqual(pub.Stores.EL.Hash, []any{"EL", height}) {
		return fmt.Errorf("EL publication")
	}
	peerProfile := literalProfile("current-base")
	if p.Raw == 11 {
		peerProfile = literalProfile("current-first-alternate")
	}
	if p.Raw == 20 {
		peerProfile = literalProfile("current-second-alternate")
	}
	if !reflect.DeepEqual(raw.Peer.Preimage.First, peerProfile.First) || !reflect.DeepEqual(raw.Peer.Preimage.Second, peerProfile.Next) {
		return fmt.Errorf("raw landed pair")
	}
	hdr := raw.Peer.Header
	headerChain := int64(1)
	headerTime := int64(102)
	if p.Origin {
		headerChain = 0
		headerTime = 20
	}
	if hdr.Height != height || hdr.Time != headerTime || !symbolEqual(hdr.Chain, []any{"Chain", headerChain}) || !symbolEqual(hdr.AppHash, []any{"EL", height - 1}) || !symbolEqual(hdr.Next, []any{"Validators", kp(peerProfile.First)}) {
		return fmt.Errorf("raw retained header")
	}
	e := pub.Stores.Evidence
	if p.Origin {
		if !symbolEqual(s.BlockID, []any{}) || !reflect.DeepEqual(pub.Stores.EL.Ancestors, []int64{2}) || !symbolEqual(e.Markers, []any{}) || !symbolEqual(e.Validators, []any{}) || !symbolEqual(e.Commits, []any{}) {
			return fmt.Errorf("origin history markers")
		}
	} else {
		if !reflect.DeepEqual(pub.Stores.EL.Ancestors, []int64{2, 3, 4}) || !symbolEqual(e.Markers, []any{[]any{"Evidence", 3}}) || !symbolEqual(e.Validators, []any{"WindowValidators", 4}) || !symbolEqual(e.Commits, []any{"WindowCommits", 4}) {
			return fmt.Errorf("current history markers")
		}
		if !sameSymbol(s.BlockID, vectors()["block-id-"+c.ID].Symbol) {
			return fmt.Errorf("published BlockID symbol")
		}
	}
	return nil
}

func loadCases(t *testing.T) map[string]caseReceipt {
	t.Helper()
	path := os.Getenv("ETNA_CHECKPOINT_IMPORT_FIXTURE")
	if path == "" {
		t.Fatal("missing frozen fixture binding")
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	sum := sha256.Sum256(raw)
	if hex.EncodeToString(sum[:]) != receiptSHA || os.Getenv("ETNA_CHECKPOINT_IMPORT_SHA256") != receiptSHA {
		t.Fatal("frozen receipt byte hash mismatch")
	}
	// The collector first invokes F03.load_fixture (duplicate-field rejecting)
	// and its full schema/provenance validator. Native exact-byte checks bind this
	// typed projection to those same validated bytes before JSON decoding.
	var fixture struct {
		Schema string        `json:"schema"`
		Cases  []caseReceipt `json:"cases"`
	}
	if err = json.Unmarshal(raw, &fixture); err != nil {
		t.Fatal(err)
	}
	if fixture.Schema != "etna-checkpoint-import-replay-1" || len(fixture.Cases) != 5 {
		t.Fatal("wrong fixture/schema")
	}
	out := map[string]caseReceipt{}
	for i, c := range fixture.Cases {
		if c.ID != caseIDs[i] {
			t.Fatal("missing/reordered/duplicate receipt")
		}
		out[c.ID] = c
	}
	return out
}
func vectors() map[string]mappingVector {
	var v map[string]mappingVector
	if err := json.Unmarshal(mappingJSON, &v); err != nil {
		panic(err)
	}
	return v
}
func opaque(domain string, raw json.RawMessage) []byte {
	canonical, err := canonical(raw)
	if err != nil {
		panic(err)
	}
	sum := sha256.Sum256(append([]byte("etna-bootstrap/"+domain+"\x00"), canonical...))
	return append([]byte(nil), sum[:]...)
}
func unhex(s string) []byte {
	b, err := hex.DecodeString(s)
	if err != nil {
		panic(err)
	}
	return b
}
func publicKeys() map[int64]ed25519.PubKey {
	return map[int64]ed25519.PubKey{1: ed25519.PubKey(unhex("5866666666666666666666666666666666666666666666666666666666666666")), 2: ed25519.PubKey(unhex("58666666666666666666666666666666666666666666666666666666666666e6")), 3: ed25519.PubKey(unhex("c9a3f86aae465f0e56513864510f3997561fa2c9e85ea21dc2292309f3cd6022"))}
}
func adaptSet(s symbolicSet) *types.ValidatorSet {
	if len(s.Keys) == 0 {
		return types.NewValidatorSet(nil)
	}
	keys := publicKeys()
	members := []*types.Validator{}
	for i, k := range s.Keys {
		members = append(members, types.NewValidator(keys[k], s.Powers[i]))
	}
	// NewValidatorSet sorts/increments. Landed snapshots override BOTH priority
	// and stored proposer afterward by identity; do not infer either by index.
	vs := types.NewValidatorSet(members)
	for i, k := range s.Keys {
		_, v := vs.GetByAddressMut(keys[k].Address())
		v.ProposerPriority = s.Priorities[i]
	}
	_, proposer := vs.GetByAddressMut(keys[s.Proposer].Address())
	vs.Proposer = proposer.Copy()
	return vs
}
func adaptState(c caseReceipt) state.State {
	s := c.Observation.Publication.Stores.Comet
	out := state.State{Version: state.InitStateVersion, ChainID: "etna-symbolic-chain-1", InitialHeight: s.InitialHeight, LastBlockHeight: s.Height, LastBlockTime: time.Unix(s.Time, 0).UTC(),
		Validators: adaptSet(s.Validators), NextValidators: adaptSet(s.Next), LastValidators: types.NewValidatorSet(nil), LastHeightValidatorsChanged: s.ValChanged,
		ConsensusParams: *types.DefaultConsensusParams(), LastHeightConsensusParamsChanged: s.ParamsChanged, AppHash: opaque("el", s.AppHash)}
	if s.Height != 0 {
		out.LastValidators = adaptSet(symbolicSet{[]int64{1, 2}, []int64{3, 2}, []int64{1, -1}, 2})
		out.LastBlockID = types.BlockID{Hash: opaque("block-id", s.BlockID), PartSetHeader: types.PartSetHeader{Total: 1, Hash: opaque("block-parts", s.BlockID)}}
		out.LastResultsHash = state.TxResultsHash([]*abci.ExecTxResult{{Code: 0, Data: nil, GasWanted: 0, GasUsed: 0}})
	}
	return out
}

type memberView struct {
	Key             int64
	Public, Address string
	Power, Priority int64
}
type setView struct {
	Members  []memberView
	Proposer memberView
	Total    int64
}
type versionView struct {
	Block, App uint64
	Software   string
}
type stateView struct {
	Version                        versionView
	ChainID                        string
	InitialHeight, LastBlockHeight int64
	LastBlockTime                  string
	LastBlockIDHash                string
	PartTotal                      uint32
	PartHash                       string
	LastResultsHash, AppHash       string
	ValChanged, ParamsChanged      int64
	Last, Validators, Next         setView
	Params                         types.ConsensusParams
}

// Observer identity/address vectors are literal and separate from publicKeys(),
// so a mapper's key/address substitution cannot self-confirm through an inverse.
func literalMember(key int64, power, priority int64) memberView {
	switch key {
	case 1:
		return memberView{1, "5866666666666666666666666666666666666666666666666666666666666666", "cb05c9fac26332f9abc5f4f50b47e39edab18bd5", power, priority}
	case 2:
		return memberView{2, "58666666666666666666666666666666666666666666666666666666666666e6", "695c607b1e0b4f5d354d473c1bba4e6e7b64f0e6", power, priority}
	case 3:
		return memberView{3, "c9a3f86aae465f0e56513864510f3997561fa2c9e85ea21dc2292309f3cd6022", "eaffb2d9fb00afd9ae8ddd9ec24f839e3258139a", power, priority}
	default:
		panic("unknown literal public identity")
	}
}
func observeMember(v *types.Validator) memberView {
	if v == nil {
		return memberView{}
	}
	pub := hex.EncodeToString(v.PubKey.Bytes())
	key := int64(0)
	for _, k := range []int64{1, 2, 3} {
		if pub == literalMember(k, 0, 0).Public {
			key = k
		}
	}
	return memberView{key, pub, hex.EncodeToString(v.Address), v.VotingPower, v.ProposerPriority}
}
func observeSet(vs *types.ValidatorSet) setView {
	out := setView{Members: []memberView{}}
	if vs.IsNilOrEmpty() {
		return out
	}
	for _, v := range vs.Validators {
		out.Members = append(out.Members, observeMember(v))
	}
	out.Proposer = observeMember(vs.Proposer)
	out.Total = vs.TotalVotingPower()
	return out
}
func literalSet(s symbolicSet, order []int64) setView {
	out := setView{Members: []memberView{}}
	for _, key := range order {
		for i, k := range s.Keys {
			if k == key {
				v := literalMember(k, s.Powers[i], s.Priorities[i])
				out.Members = append(out.Members, v)
				out.Total += v.Power
				if k == s.Proposer {
					out.Proposer = v
				}
			}
		}
	}
	return out
}
func literalParams() types.ConsensusParams {
	return types.ConsensusParams{Block: types.BlockParams{MaxBytes: 55600190, MaxGas: -1}, Evidence: types.EvidenceParams{MaxAgeNumBlocks: 100000, MaxAgeDuration: 48 * time.Hour, MaxBytes: 1048576}, Validator: types.ValidatorParams{PubKeyTypes: []string{"ed25519"}}, Version: types.VersionParams{App: 0}, ABCI: types.ABCIParams{VoteExtensionsEnableHeight: 0}, Authority: types.AuthorityParams{Authority: ""}}
}
func observeState(s state.State) stateView {
	return stateView{versionView{s.Version.Consensus.Block, s.Version.Consensus.App, s.Version.Software}, s.ChainID, s.InitialHeight, s.LastBlockHeight, s.LastBlockTime.UTC().Format(time.RFC3339Nano), hex.EncodeToString(s.LastBlockID.Hash), s.LastBlockID.PartSetHeader.Total, hex.EncodeToString(s.LastBlockID.PartSetHeader.Hash), hex.EncodeToString(s.LastResultsHash), hex.EncodeToString(s.AppHash), s.LastHeightValidatorsChanged, s.LastHeightConsensusParamsChanged, observeSet(s.LastValidators), observeSet(s.Validators), observeSet(s.NextValidators), s.ConsensusParams}
}
func expectedState(id string) stateView {
	p := literalProfile(id)
	v := vectors()
	out := stateView{Version: versionView{11, 0, "0.39.0"}, ChainID: "etna-symbolic-chain-1", InitialHeight: 3, LastBlockHeight: 4, LastBlockTime: "1970-01-01T00:01:42Z", PartTotal: 1,
		LastResultsHash: "6e340b9cffb37a989ca544e6bb780a2c78901d3fb33738768511a30617afa01d", AppHash: v["el4"].SHA, ValChanged: 6, ParamsChanged: 5, Last: literalSet(p.Last, p.LastOrder), Validators: literalSet(p.First, p.FirstOrder), Next: literalSet(p.Next, p.NextOrder), Params: literalParams()}
	if p.Origin {
		out.LastBlockHeight = 0
		out.LastBlockTime = "1970-01-01T00:01:40Z"
		out.PartTotal = 0
		out.LastResultsHash = ""
		out.AppHash = v["el2"].SHA
		out.ValChanged = 3
		out.ParamsChanged = 3
	} else {
		out.LastBlockIDHash = v["block-id-"+id].SHA
		out.PartHash = v["block-parts-"+id].SHA
	}
	return out
}
func firstDifference(a, b any) string {
	var visit func(reflect.Value, reflect.Value, string) string
	visit = func(x, y reflect.Value, path string) string {
		if !x.IsValid() || !y.IsValid() {
			if x.IsValid() != y.IsValid() {
				return path
			}
			return ""
		}
		if x.Type() != y.Type() {
			return path
		}
		switch x.Kind() {
		case reflect.Struct:
			for i := 0; i < x.NumField(); i++ {
				next := x.Type().Field(i).Name
				if path != "" {
					next = path + "." + next
				}
				if d := visit(x.Field(i), y.Field(i), next); d != "" {
					return d
				}
			}
		case reflect.Slice, reflect.Array:
			if x.Len() != y.Len() {
				return path + ".length"
			}
			for i := 0; i < x.Len(); i++ {
				if d := visit(x.Index(i), y.Index(i), fmt.Sprintf("%s[%d]", path, i)); d != "" {
					return d
				}
			}
		default:
			if !reflect.DeepEqual(x.Interface(), y.Interface()) {
				return path
			}
		}
		return ""
	}
	return visit(reflect.ValueOf(a), reflect.ValueOf(b), "")
}
func assertState(t *testing.T, s state.State, id string) {
	t.Helper()
	if reason := firstDifference(observeState(s), expectedState(id)); reason != "" {
		t.Fatalf("state-field mismatch id=%s field=%s", id, reason)
	}
}

func bootstrap(t *testing.T, c caseReceipt) (state.State, dbm.DB, state.Store) {
	t.Helper()
	if err := auditReceipt(c); err != nil {
		t.Fatalf("receipt audit id=%s: %v", c.ID, err)
	}
	s := adaptState(c)
	assertState(t, s, c.ID)
	if err := s.Validators.ValidateBasic(); err != nil {
		t.Fatal(err)
	}
	if err := s.NextValidators.ValidateBasic(); err != nil {
		t.Fatal(err)
	}
	if err := s.ConsensusParams.ValidateBasic(); err != nil {
		t.Fatal(err)
	}
	db := dbm.NewMemDB()
	t.Cleanup(func() { _ = db.Close() })
	store := state.NewStore(db, state.StoreOptions{})
	if err := store.Bootstrap(s); err != nil {
		t.Fatal(err)
	}
	if err := store.Close(); err != nil {
		t.Fatal(err)
	}
	reopened := state.NewStore(db, state.StoreOptions{})
	loaded, err := reopened.Load()
	if err != nil {
		t.Fatal(err)
	}
	assertState(t, loaded, c.ID)
	return loaded, db, reopened
}
func checkRow(t *testing.T, db dbm.DB, store state.Store, height int64, want setView) {
	t.Helper()
	got, err := store.LoadValidators(height)
	if err != nil {
		t.Fatalf("validator lookup height=%d: %v", height, err)
	}
	if d := firstDifference(observeSet(got), want); d != "" {
		t.Fatalf("validator lookup height=%d field=%s", height, d)
	}
	raw, err := db.Get([]byte(fmt.Sprintf("validatorsKey:%d", height)))
	if err != nil {
		t.Fatal(err)
	}
	var info cmtstate.ValidatorsInfo
	if err := info.Unmarshal(raw); err != nil {
		t.Fatal(err)
	}
	if info.LastHeightChanged != height || info.ValidatorSet == nil {
		t.Fatalf("validator row metadata height=%d", height)
	}
	parsed, err := types.ValidatorSetFromProto(info.ValidatorSet)
	if err != nil {
		t.Fatal(err)
	}
	if d := firstDifference(observeSet(parsed), want); d != "" {
		t.Fatalf("raw validator row height=%d field=%s", height, d)
	}
}
func checkParams(t *testing.T, db dbm.DB, store state.Store, height int64) {
	t.Helper()
	params, err := store.LoadConsensusParams(height)
	if err != nil {
		t.Fatal(err)
	}
	if d := firstDifference(params, literalParams()); d != "" {
		t.Fatalf("params field=%s", d)
	}
	raw, err := db.Get([]byte(fmt.Sprintf("consensusParamsKey:%d", height)))
	if err != nil {
		t.Fatal(err)
	}
	var info cmtstate.ConsensusParamsInfo
	if err := info.Unmarshal(raw); err != nil {
		t.Fatal(err)
	}
	if info.LastHeightChanged != height {
		t.Fatal("params change-height metadata")
	}
	if d := firstDifference(types.ConsensusParamsFromProto(info.ConsensusParams), literalParams()); d != "" {
		t.Fatalf("raw params field=%s", d)
	}
}
func checkNextBlock(t *testing.T, s state.State, id string) {
	t.Helper()
	p := literalProfile(id)
	height := int64(5)
	timestamp := int64(103)
	commit := &types.Commit{}
	if p.Origin {
		height = 3
		timestamp = 100
	} else {
		commit.Height = 4
		commit.BlockID = s.LastBlockID
		for _, v := range s.LastValidators.Validators {
			commit.Signatures = append(commit.Signatures, types.CommitSig{BlockIDFlag: types.BlockIDFlagCommit, ValidatorAddress: v.Address, Timestamp: time.Unix(103, 0).UTC()})
		}
	}
	block, err := s.MakeBlock(height, nil, commit, nil, s.Validators.Proposer.Address)
	if err != nil {
		t.Fatal(err)
	}
	expected := expectedState(id)
	if block.Height != height || block.Time.Unix() != timestamp || block.Time.Nanosecond() != 0 || block.ChainID != expected.ChainID || block.Version.Block != 11 || block.Version.App != 0 || hex.EncodeToString(block.ValidatorsHash) != p.CurrentHash || hex.EncodeToString(block.NextValidatorsHash) != p.NextHash || hex.EncodeToString(block.AppHash) != expected.AppHash || hex.EncodeToString(block.LastResultsHash) != expected.LastResultsHash || hex.EncodeToString(block.LastBlockID.Hash) != expected.LastBlockIDHash || block.LastBlockID.PartSetHeader.Total != expected.PartTotal || hex.EncodeToString(block.LastBlockID.PartSetHeader.Hash) != expected.PartHash || !bytes.Equal(block.ConsensusHash, literalParams().Hash()) || hex.EncodeToString(block.ProposerAddress) != expected.Validators.Proposer.Address {
		t.Fatal("next-block header projection mismatch")
	}
	for _, sig := range commit.Signatures {
		if len(sig.Signature) != 0 {
			t.Fatal("unsigned timestamp premise gained signature bytes")
		}
	}
	// Never call non-genesis ValidateBlock/VerifyCommit: these unsigned records
	// are only inputs to MakeBlock's timestamp/header construction.
}

func TestCheckpointBootstrap(t *testing.T) {
	cases := loadCases(t)
	for _, id := range caseIDs {
		t.Run(id, func(t *testing.T) {
			c := cases[id]
			s, db, store := bootstrap(t, c)
			height := s.LastBlockHeight + 1
			if s.LastBlockHeight == 0 {
				height = s.InitialHeight
			}
			want := expectedState(id)
			checkRow(t, db, store, height, want.Validators)
			checkRow(t, db, store, height+1, want.Next)
			checkParams(t, db, store, height)
			checkNextBlock(t, s, id)
		})
	}
	t.Run("last-validator-lookup", func(t *testing.T) {
		for _, id := range caseIDs {
			s, db, store := bootstrap(t, cases[id])
			height := int64(4)
			if s.LastBlockHeight == 0 {
				height = 2
			}
			got, err := store.LoadValidators(height)
			raw, rawErr := db.Get([]byte(fmt.Sprintf("validatorsKey:%d", height)))
			if rawErr != nil {
				t.Fatal(rawErr)
			}
			var missing state.ErrNoValSetForHeight
			typed := errors.As(err, &missing) && missing.Height == height
			if s.LastBlockHeight == 0 {
				if !typed || got != nil || len(raw) != 0 {
					t.Fatalf("origin historical row must remain absent: %v", err)
				}
				continue
			}
			if err != nil {
				preserved := firstDifference(observeSet(s.LastValidators), expectedState(id).Last) == ""
				if typed && got == nil && len(raw) == 0 && preserved {
					t.Errorf("missing-bootstrap-last id=%s height=4 typed=ErrNoValSetForHeight nilset=true row=absent serialized-last=preserved", id)
				} else {
					t.Errorf("unexpected-last-lookup id=%s err=%v typed=%t nilset=%t rowBytes=%d preserved=%t", id, err, typed, got == nil, len(raw), preserved)
				}
				continue
			}
			checkRow(t, db, store, height, expectedState(id).Last)
		}
	})
	t.Run("observer-controls", func(t *testing.T) {
		for name, v := range vectors() {
			if got := hex.EncodeToString(opaque(v.Domain, v.Symbol)); got != v.SHA {
				t.Fatalf("literal mapping vector %s mismatch", name)
			}
		}
		base := adaptState(cases["current-base"])
		want := expectedState("current-base")
		controls := []struct {
			name, want string
			mutate     func(*state.State)
		}{
			{"initial", "InitialHeight", func(s *state.State) { s.InitialHeight = 5 }},
			{"height", "LastBlockHeight", func(s *state.State) { s.LastBlockHeight = 3 }},
			{"time", "LastBlockTime", func(s *state.State) { s.LastBlockTime = s.LastBlockTime.Add(time.Nanosecond) }},
			{"app", "AppHash", func(s *state.State) {
				s.AppHash = opaque("el", cases["current-base"].Observation.Raw.Peer.Header.AppHash)
			}},
			{"results", "LastResultsHash", func(s *state.State) { s.LastResultsHash = nil }},
			{"block-id", "LastBlockIDHash", func(s *state.State) { s.LastBlockID.Hash = nil }},
			{"block-parts", "PartTotal", func(s *state.State) { s.LastBlockID.PartSetHeader.Total = 2 }},
			{"val-change", "ValChanged", func(s *state.State) { s.LastHeightValidatorsChanged = 5 }},
			{"param-change", "ParamsChanged", func(s *state.State) { s.LastHeightConsensusParamsChanged = 4 }},
			{"priority", "Validators.Members[0].Priority", func(s *state.State) { s.Validators.Validators[0].ProposerPriority = 0 }},
			{"power", "Validators.Members[0].Power", func(s *state.State) { s.Validators.Validators[0].VotingPower = 4 }},
			{"order", "Next.Members[0].Key", func(s *state.State) {
				s.NextValidators.Validators[0], s.NextValidators.Validators[1] = s.NextValidators.Validators[1], s.NextValidators.Validators[0]
			}},
			{"proposer", "Next.Proposer.Key", func(s *state.State) { s.NextValidators.Proposer = s.NextValidators.Validators[0].Copy() }},
			{"params", "Params.Authority.Authority", func(s *state.State) { s.ConsensusParams.Authority.Authority = "changed" }},
			{"version", "Version.Block", func(s *state.State) { s.Version.Consensus.Block = 12 }},
		}
		for _, control := range controls {
			s := base.Copy()
			control.mutate(&s)
			if got := firstDifference(observeState(s), want); got != control.want {
				t.Fatalf("observer control %s wanted %s got %s", control.name, control.want, got)
			}
		}
		c := cases["current-base"]
		c.Observation.Publication.Stores.Comet.Time = 40
		if err := auditReceipt(c); err == nil || err.Error() != "published scalar fields" {
			t.Fatal("receipt premise time observer failed")
		}
		if d := firstDifference(observeState(adaptState(cases["origin-base"])), observeState(adaptState(cases["origin-landed-alternate"]))); d != "" {
			t.Fatalf("origin alternate changed fixed genesis field=%s", d)
		}
		alternate := adaptState(cases["current-first-alternate"])
		if alternate.NextValidators.Proposer.ProposerPriority != -1 || alternate.NextValidators.Validators[0].ProposerPriority != 1 {
			t.Fatal("stored previous winner was normalized to highest priority")
		}
	})
}
