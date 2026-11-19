package apphash

import (
	"bytes"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"testing"
	"time"

	dbm "github.com/cometbft/cometbft-db"
	abci "github.com/cometbft/cometbft/abci/types"
	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	statepb "github.com/cometbft/cometbft/proto/tendermint/state"
	typespb "github.com/cometbft/cometbft/proto/tendermint/types"
	"github.com/cometbft/cometbft/state"
	"github.com/cometbft/cometbft/types"
	"golang.org/x/crypto/sha3"
)

type program struct {
	Generation string                      `json:"generation"`
	Initial    int64                       `json:"initial_height"`
	End        int64                       `json:"last_height"`
	Genesis    map[string]int64            `json:"genesis"`
	Updates    map[string]map[string]int64 `json:"updates"`
	Checkpoint int64                       `json:"checkpoint"`
}

type point struct {
	Key     string `json:"public_key"`
	Signer  string `json:"signer"`
	Address string `json:"ck_addr"`
}

type environment struct {
	program
	chainID, projectionSHA, programSHA string
	keys                               map[string]secp256k1eth.PubKey
}

type member struct {
	Key      string `json:"key"`
	Address  string `json:"address"`
	Power    int64  `json:"power"`
	Priority int64  `json:"priority"`
}

type setView struct {
	Members  []member `json:"members"`
	Proposer int      `json:"proposer"`
	Merkle   string   `json:"merkle"`
}

type commitment struct {
	Height   int64  `json:"height"`
	EL       string `json:"el"`
	ValBytes string `json:"val_bytes"`
	ValHash  string `json:"val_hash"`
	AppBytes string `json:"app_bytes"`
	AppHash  string `json:"app_hash"`
}

type databaseRow struct {
	Height int64    `json:"height"`
	Change int64    `json:"change"`
	Raw    string   `json:"raw"`
	Stored *setView `json:"stored"`
	Loaded *setView `json:"loaded"`
}

func check(t *testing.T, err error) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
	}
}

func hexBytes(t *testing.T, s string) []byte {
	t.Helper()
	out, err := hex.DecodeString(s)
	check(t, err)
	return out
}

func hexOf(b []byte) string { return hex.EncodeToString(b) }

func readJSON(t *testing.T, path string, dst any) string {
	t.Helper()
	raw, err := os.ReadFile(path)
	check(t, err)
	check(t, json.Unmarshal(raw, dst))
	return fmt.Sprintf("%x", sha256.Sum256(raw))
}

func load(t *testing.T, name string) environment {
	t.Helper()
	var programs struct {
		Schema string             `json:"schema"`
		Cases  map[string]program `json:"cases"`
	}
	programSHA := readJSON(t, "programs.json", &programs)
	selected, ok := programs.Cases[name]
	if !ok || programs.Schema != "etna-comet-apphash-programs-1" ||
		selected.Initial <= 0 || selected.End < selected.Initial || selected.End-selected.Initial >= 16 {
		t.Fatal("unrecognized bounded program")
	}
	var public struct {
		Schema     string `json:"schema"`
		VoteKey    point  `json:"voteKey"`
		Spectators []struct {
			Name string `json:"name"`
			point
		} `json:"spectators"`
		Deployment struct {
			Inbox string `json:"inbox"`
		} `json:"deployment"`
		Domains []struct {
			Generation string `json:"generation"`
			Inbox      string `json:"inbox"`
			ChainID    string `json:"chain_id"`
		} `json:"chainDomains"`
	}
	projectionSHA := readJSON(t, "public-votes.json", &public)
	if public.Schema != "etna-public-votes-1" {
		t.Fatal("wrong public projection")
	}
	var chainID string
	for _, domain := range public.Domains {
		if domain.Generation == selected.Generation && domain.Inbox == public.Deployment.Inbox {
			if chainID != "" {
				t.Fatal("ambiguous fixture chain")
			}
			chainID = domain.ChainID
		}
	}
	if chainID == "" {
		t.Fatal("missing fixture chain domain")
	}
	points := map[string]point{"A": public.VoteKey}
	for _, spectator := range public.Spectators {
		name := map[string]string{"a2": "B", "a3": "C", "a4": "H"}[spectator.Name]
		if name != "" {
			points[name] = spectator.point
		}
	}
	keys := make(map[string]secp256k1eth.PubKey)
	for name, p := range points {
		key, err := secp256k1eth.NewPubKeyFromBytes(hexBytes(t, p.Key[2:]))
		check(t, err)
		address := p.Address
		if name == "A" {
			address = p.Signer
		}
		if "0x"+hexOf(key.Address()) != address {
			t.Fatal("public key/address mismatch")
		}
		keys[name] = key
	}
	if len(keys) != 4 {
		t.Fatal("missing frozen public point")
	}
	return environment{selected, chainID, projectionSHA, programSHA, keys}
}

func observeSet(t *testing.T, vals *types.ValidatorSet) *setView {
	t.Helper()
	if vals.IsNilOrEmpty() {
		return nil
	}
	if vals.Proposer == nil {
		t.Fatal("missing stored proposer")
	}
	view := &setView{Proposer: -1, Merkle: hexOf(vals.Hash())}
	for index, val := range vals.Validators {
		m := member{hexOf(val.PubKey.Bytes()), hexOf(val.Address), val.VotingPower, val.ProposerPriority}
		if bytes.Equal(val.Address, vals.Proposer.Address) {
			if m != (member{hexOf(vals.Proposer.PubKey.Bytes()), hexOf(vals.Proposer.Address),
				vals.Proposer.VotingPower, vals.Proposer.ProposerPriority}) {
				t.Fatal("stored proposer differs from its member")
			}
			view.Proposer = index
		}
		view.Members = append(view.Members, m)
	}
	if view.Proposer < 0 {
		t.Fatal("stored proposer is not a member")
	}
	return view
}

func fromView(t *testing.T, view *setView) *types.ValidatorSet {
	t.Helper()
	proto := new(typespb.ValidatorSet)
	for _, m := range view.Members {
		key, err := secp256k1eth.NewPubKeyFromBytes(hexBytes(t, m.Key))
		check(t, err)
		item := types.NewValidator(key, m.Power)
		item.ProposerPriority = m.Priority
		if hexOf(item.Address) != m.Address {
			t.Fatal("detached validator address mismatch")
		}
		encoded, err := item.ToProto()
		check(t, err)
		proto.Validators = append(proto.Validators, encoded)
	}
	proto.Proposer = proto.Validators[view.Proposer]
	out, err := types.ValidatorSetFromProto(proto)
	check(t, err)
	return out
}

func keccak(raw []byte) []byte {
	sponge := sha3.NewLegacyKeccak256()
	_, _ = sponge.Write(raw)
	return sponge.Sum(nil)
}

func word(value uint64) []byte {
	result := make([]byte, 32)
	binary.BigEndian.PutUint64(result[24:], value)
	return result
}

func tag(value string) []byte {
	result := make([]byte, 32)
	copy(result, value)
	return result
}

func setABI(t *testing.T, set *setView) []byte {
	t.Helper()
	out := word(uint64(len(set.Members)))
	for _, m := range set.Members {
		key := hexBytes(t, m.Key)
		out = append(out, word(uint64(key[0]))...)
		out = append(out, key[1:]...)
		out = append(out, word(uint64(m.Power))...)
		priority := word(uint64(m.Priority))
		if m.Priority < 0 {
			for i := range priority[:24] {
				priority[i] = 0xff
			}
		}
		out = append(out, priority...)
	}
	return out
}

func encode(t *testing.T, e environment, h int64, current, next *setView) commitment {
	t.Helper()
	a, b := setABI(t, current), setABI(t, next)
	val := bytes.Join([][]byte{tag("ETNA_VAL_STATE_V1"), word(uint64(h)), word(192),
		word(uint64(current.Proposer)), word(uint64(192 + len(a))), word(uint64(next.Proposer)), a, b}, nil)
	valHash := keccak(val)
	el := sha256.Sum256([]byte(fmt.Sprintf("etna-apphash fixture %s:%d", e.Generation, h)))
	app := bytes.Join([][]byte{tag("ETNA_APP_HASH_V1"), el[:], valHash}, nil)
	return commitment{h, hexOf(el[:]), hexOf(val), hexOf(valHash), hexOf(app), hexOf(keccak(app))}
}

func names(powers map[string]int64) []string {
	out := make([]string, 0, len(powers))
	for name := range powers {
		out = append(out, name)
	}
	sort.Strings(out)
	return out
}

func genesis(t *testing.T, e environment) state.State {
	t.Helper()
	params := types.DefaultConsensusParams()
	params.Validator.PubKeyTypes = []string{secp256k1eth.KeyType}
	params.Version.App = 1
	doc := &types.GenesisDoc{ChainID: e.chainID, InitialHeight: e.Initial,
		GenesisTime: time.Unix(1_700_000_000+e.Initial, 0).UTC(), ConsensusParams: params}
	for _, name := range names(e.Genesis) {
		key := e.keys[name]
		if key == nil {
			t.Fatal("unrecognized genesis key")
		}
		doc.Validators = append(doc.Validators, types.GenesisValidator{Address: key.Address(), PubKey: key, Power: e.Genesis[name]})
	}
	base, err := state.MakeGenesisState(doc)
	check(t, err)
	commit := encode(t, e, e.Initial-1, observeSet(t, base.Validators), observeSet(t, base.NextValidators))
	doc.AppHash = hexBytes(t, commit.AppHash)
	base, err = state.MakeGenesisState(doc)
	check(t, err)
	// Model the application's Info version assignment; no ABCI handshake runs.
	base.Version.Consensus.App = 1
	return base
}

type validationCase struct {
	Name       string     `json:"name"`
	Commitment commitment `json:"commitment"`
	Header     string     `json:"header"`
	Block      string     `json:"block"`
	Error      string     `json:"error"`
}

// Exercise the public stock validator with a genuine empty initial commit.
// Each fresh block differs from the baseline only in its AppHash field.
func initialValidation(t *testing.T, e environment, s state.State) []validationCase {
	t.Helper()
	var result []validationCase
	var baseline []byte
	for _, name := range []string{"matching", "current-priority", "next-priority", "current-proposer", "next-proposer", "height", "el"} {
		a := observeSet(t, fromView(t, observeSet(t, s.Validators)))
		b := observeSet(t, fromView(t, observeSet(t, s.NextValidators)))
		h := e.Initial - 1
		switch name {
		case "current-priority":
			a.Members[0].Priority++
		case "next-priority":
			b.Members[0].Priority++
		case "current-proposer":
			a.Proposer = (a.Proposer + 1) % len(a.Members)
		case "next-proposer":
			b.Proposer = (b.Proposer + 1) % len(b.Members)
		case "height":
			h++
		}
		c := encode(t, e, h, a, b)
		if name == "el" {
			app := hexBytes(t, c.AppBytes)
			app[32] ^= 1
			c.EL = hexOf(app[32:64])
			c.AppBytes, c.AppHash = hexOf(app), hexOf(keccak(app))
		}
		block, err := s.MakeBlock(e.Initial, []types.Tx{types.Tx("public-apphash-fixture")}, &types.Commit{}, nil, s.Validators.Proposer.Address)
		check(t, err)
		block.AppHash = hexBytes(t, c.AppHash)
		err = s.ValidateBlock(block)
		message := ""
		if err != nil {
			message = err.Error()
		}
		want := ""
		if name != "matching" {
			want = fmt.Sprintf("wrong Block.Header.AppHash.  Expected %X, got %X", s.AppHash, block.AppHash)
		}
		if message != want {
			t.Fatalf("initial appHash validation %s: expected %q got %q", name, want, message)
		}
		hp := block.Header.ToProto()
		hp.AppHash = s.AppHash
		normalized, err := hp.Marshal()
		check(t, err)
		if name == "matching" {
			baseline = normalized
		} else if !bytes.Equal(baseline, normalized) {
			t.Fatal("initial control changed a non-AppHash header field")
		}
		header, err := block.Header.ToProto().Marshal()
		check(t, err)
		bp, err := block.ToProto()
		check(t, err)
		raw, err := bp.Marshal()
		check(t, err)
		result = append(result, validationCase{name, c, hexOf(header), hexOf(raw), message})
	}
	return result
}

func openDB(t *testing.T, dir string) dbm.DB {
	t.Helper()
	db, err := dbm.NewGoLevelDB("state", dir)
	check(t, err)
	return db
}

func readRows(t *testing.T, db dbm.DB, from, to int64) []databaseRow {
	t.Helper()
	var result []databaseRow
	store := state.NewStore(db, state.StoreOptions{})
	for h := from; h <= to; h++ {
		raw, err := state.EtnaAppHashRawValidatorRow(db, h)
		check(t, err)
		if len(raw) == 0 {
			t.Fatalf("missing raw validator row at %d", h)
		}
		var info statepb.ValidatorsInfo
		check(t, info.Unmarshal(raw))
		var stored *setView
		if info.ValidatorSet != nil {
			v, err := types.ValidatorSetFromProto(info.ValidatorSet)
			check(t, err)
			stored = observeSet(t, v)
		}
		lookedUp, err := store.LoadValidators(h)
		check(t, err)
		result = append(result, databaseRow{h, info.LastHeightChanged, hexOf(raw), stored, observeSet(t, lookedUp)})
	}
	return result
}

type observation struct {
	Height     int64      `json:"height"`
	Current    *setView   `json:"current"`
	Next       *setView   `json:"next"`
	Commitment commitment `json:"commitment"`
}

func record(t *testing.T, e environment, s state.State, h int64) observation {
	t.Helper()
	a, b := observeSet(t, s.Validators), observeSet(t, s.NextValidators)
	c := encode(t, e, h, a, b)
	if c.AppHash != hexOf(s.AppHash) {
		t.Fatal("state differs from reference commitment")
	}
	return observation{h, a, b, c}
}

type frame struct {
	Header types.Header
	ID     types.BlockID
}

func (f frame) bytes(t *testing.T) []byte {
	t.Helper()
	h, err := f.Header.ToProto().Marshal()
	check(t, err)
	id := f.ID.ToProto()
	b, err := id.Marshal()
	check(t, err)
	raw, err := json.Marshal([]string{hexOf(h), hexOf(b)})
	check(t, err)
	return raw
}

// Only an initial-height input is an actual block. Later inputs feed the
// stock validator state transition directly, with an explicit synthetic ID.
func inputFrame(t *testing.T, e environment, s state.State, h int64) frame {
	t.Helper()
	if h == e.Initial {
		b, err := s.MakeBlock(h, []types.Tx{types.Tx("public-apphash-fixture")}, &types.Commit{}, nil, s.Validators.Proposer.Address)
		check(t, err)
		check(t, s.ValidateBlock(b))
		parts, err := b.MakePartSet(types.BlockPartSizeBytes)
		check(t, err)
		return frame{b.Header, types.BlockID{Hash: b.Hash(), PartSetHeader: parts.Header()}}
	}
	header := types.Header{Height: h}
	header.Populate(s.Version.Consensus, s.ChainID, s.LastBlockTime.Add(time.Second), s.LastBlockID,
		s.Validators.Hash(), s.NextValidators.Hash(), s.ConsensusParams.Hash(), s.AppHash,
		s.LastResultsHash, s.Validators.Proposer.Address)
	raw, err := header.ToProto().Marshal()
	check(t, err)
	part := sha256.Sum256(append([]byte("synthetic-state-input-part"), raw...))
	return frame{header, types.BlockID{Hash: header.Hash(), PartSetHeader: types.PartSetHeader{Total: 1, Hash: part[:]}}}
}

func applyFrame(t *testing.T, e environment, s state.State, f frame) state.State {
	t.Helper()
	response := &abci.ResponseFinalizeBlock{TxResults: []*abci.ExecTxResult{{}}}
	updates := e.Updates[strconv.FormatInt(f.Header.Height, 10)]
	for _, name := range names(updates) {
		key := e.keys[name]
		if key == nil {
			t.Fatal("unknown update identity")
		}
		response.ValidatorUpdates = append(response.ValidatorUpdates, types.TM2PB.NewValidatorUpdate(key, updates[name]))
	}
	out, err := state.EtnaAppHashUpdate(s, f.ID, &f.Header, response)
	check(t, err)
	if out.AppHash != nil {
		t.Fatal("stock transition unexpectedly assigned an application hash")
	}
	c := encode(t, e, f.Header.Height, observeSet(t, out.Validators), observeSet(t, out.NextValidators))
	out.AppHash = hexBytes(t, c.AppHash)
	return out
}

type framePair struct {
	Height       int64           `json:"height"`
	Running      string          `json:"running"`
	Reopened     string          `json:"reopened"`
	Input        json.RawMessage `json:"input"`
	ResumedInput json.RawMessage `json:"resumed_input"`
}

type checkpointReceipt struct {
	PreState     string        `json:"pre_state"`
	DerivedState string        `json:"derived_state"`
	RunningState string        `json:"running_state"`
	Bootstrapped string        `json:"bootstrapped"`
	Continued    []framePair   `json:"continued"`
	Final        string        `json:"final"`
	BootRows     []databaseRow `json:"boot_rows"`
	FinalRows    []databaseRow `json:"final_rows"`
}

func withBootstrapMarkers(s state.State, h int64) state.State {
	s.LastHeightValidatorsChanged = h + 2
	s.LastHeightConsensusParamsChanged = h + 1
	return s
}

func checkpoint(t *testing.T, e environment, states map[int64]state.State, frozen map[int64]frame) *checkpointReceipt {
	t.Helper()
	h := e.Checkpoint
	pre := states[h-1].Copy()
	pre.Validators = fromView(t, observeSet(t, pre.Validators))
	pre.NextValidators = fromView(t, observeSet(t, pre.NextValidators))
	preimage := record(t, e, pre, h-1)
	input := frozen[h]
	if preimage.Commitment.AppHash != hexOf(input.Header.AppHash) ||
		preimage.Current.Merkle != hexOf(input.Header.ValidatorsHash) ||
		preimage.Next.Merkle != hexOf(input.Header.NextValidatorsHash) {
		t.Fatal("detached pre-state does not match frozen transition frame")
	}
	derived := applyFrame(t, e, pre, input)
	if !derived.Equals(states[h]) {
		t.Fatal("detached single update differs from uninterrupted state")
	}
	boundary := withBootstrapMarkers(derived, h)
	dir := t.TempDir()
	db := openDB(t, dir)
	check(t, state.NewStore(db, state.StoreOptions{}).Bootstrap(boundary))
	check(t, db.Close())
	db = openDB(t, dir)
	store := state.NewStore(db, state.StoreOptions{})
	resumed, err := store.Load()
	check(t, err)
	if !boundary.Equals(resumed) {
		t.Fatal("bootstrap reload differs from full expected state")
	}
	result := &checkpointReceipt{PreState: hexOf(pre.Bytes()), DerivedState: hexOf(derived.Bytes()),
		RunningState: hexOf(states[h].Bytes()), Bootstrapped: hexOf(resumed.Bytes()), BootRows: readRows(t, db, h, h+2)}
	for i := h + 1; i <= e.End; i++ {
		proposed := inputFrame(t, e, resumed, i)
		expected, actual := frozen[i].bytes(t), proposed.bytes(t)
		if !bytes.Equal(expected, actual) {
			t.Fatalf("full resumed input differs at %d", i)
		}
		resumed = applyFrame(t, e, resumed, frozen[i])
		if !resumed.Equals(withBootstrapMarkers(states[i], h)) {
			t.Fatalf("full resumed state differs at %d", i)
		}
		result.Continued = append(result.Continued, framePair{i, hexOf(states[i].Bytes()), hexOf(resumed.Bytes()), expected, actual})
		check(t, store.Save(resumed))
	}
	check(t, db.Close())
	db = openDB(t, dir)
	final, err := state.NewStore(db, state.StoreOptions{}).Load()
	check(t, err)
	if !final.Equals(resumed) {
		t.Fatal("final persistent state differs")
	}
	result.Final = hexOf(final.Bytes())
	result.FinalRows = readRows(t, db, h+3, e.End+2)
	check(t, db.Close())
	return result
}

func saveReceipt(t *testing.T, name string, value any) {
	t.Helper()
	raw, err := json.Marshal(value)
	check(t, err)
	path := filepath.Join(os.Getenv("ETNA_APPHASH_RECEIPTS"), name+".json")
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	check(t, err)
	_, writeErr := f.Write(raw)
	closeErr := f.Close()
	check(t, writeErr)
	check(t, closeErr)
	t.Logf("receipt %s %d %x", name, len(raw), sha256.Sum256(raw))
}

func runProgram(t *testing.T, name string) {
	t.Helper()
	e := load(t, name)
	dir := t.TempDir()
	db := openDB(t, dir)
	store := state.NewStore(db, state.StoreOptions{})
	s := genesis(t, e)
	validation := initialValidation(t, e, s)
	states := map[int64]state.State{e.Initial - 1: s}
	inputs := make(map[int64]frame)
	observations := []observation{record(t, e, s, e.Initial-1)}
	check(t, store.Save(s))
	for h := e.Initial; h <= e.End; h++ {
		f := inputFrame(t, e, s, h)
		inputs[h] = f
		s = applyFrame(t, e, s, f)
		states[h] = s
		observations = append(observations, record(t, e, s, h))
		check(t, store.Save(s))
	}
	check(t, db.Close())
	db = openDB(t, dir)
	reopened, err := state.NewStore(db, state.StoreOptions{}).Load()
	check(t, err)
	if !s.Equals(reopened) {
		t.Fatal("uninterrupted store reload differs from full state")
	}
	rows := readRows(t, db, e.Initial, e.End+2)
	check(t, db.Close())
	saveReceipt(t, name, map[string]any{"schema": "etna-apphash-projection-1", "program": name,
		"program_sha256": e.programSHA, "projection_sha256": e.projectionSHA,
		"observations": observations, "rows": rows})
	var resumed *checkpointReceipt
	if e.Checkpoint != 0 {
		resumed = checkpoint(t, e, states, inputs)
	}
	var trace []map[string]any
	for h := e.Initial; h <= e.End; h++ {
		trace = append(trace, map[string]any{"height": h, "input": json.RawMessage(inputs[h].bytes(t)),
			"state": hexOf(states[h].Bytes())})
	}
	saveReceipt(t, name+"-frames", map[string]any{"schema": "etna-stock-apphash-frames-1",
		"program": name, "program_sha256": e.programSHA, "projection_sha256": e.projectionSHA,
		"genesis": hexOf(states[e.Initial-1].Bytes()), "trace": trace, "reopened": hexOf(reopened.Bytes()), "checkpoint": resumed,
		"initial_validation": validation})
}

func TestAppHash(t *testing.T) {
	for _, name := range []string{"late-rescale", "recovery-origin"} {
		t.Run(name, func(t *testing.T) { runProgram(t, name) })
	}
}
