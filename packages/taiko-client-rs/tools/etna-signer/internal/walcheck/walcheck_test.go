package walcheck

import (
	"encoding/hex"
	"os"
	"path/filepath"
	"testing"
	"time"

	dbm "github.com/cometbft/cometbft-db"
	cs "github.com/cometbft/cometbft/consensus"
	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	sm "github.com/cometbft/cometbft/state"
	"github.com/cometbft/cometbft/store"
	"github.com/cometbft/cometbft/types"
)

// node is a stopped validator home's data directory: its stock WAL and goleveldb stores.
type node struct {
	t    *testing.T
	data string
	wal  string
}

func newNode(t *testing.T) *node {
	t.Helper()
	data := t.TempDir()
	return &node{t: t, data: data, wal: filepath.Join(data, "cs.wal", "wal")}
}

// write appends messages to the WAL through stock BaseWAL, which starts an empty WAL with
// `#ENDHEIGHT 0`.
func (n *node) write(messages ...cs.WALMessage) {
	n.t.Helper()
	wal, err := cs.NewWAL(n.wal)
	if err != nil {
		n.t.Fatal(err)
	}
	if err = wal.Start(); err != nil {
		n.t.Fatal(err)
	}
	for _, message := range messages {
		if err = wal.WriteSync(message); err != nil {
			n.t.Fatal(err)
		}
	}
	if err = wal.Stop(); err != nil {
		n.t.Fatal(err)
	}
	wal.Wait()
}

// step is a round-state record, the kind of record stock writes for every step.
func step(height int64, round int32, name string) cs.WALMessage {
	return types.EventDataRoundState{Height: height, Round: round, Step: name}
}

// commit saves a stock state at lastHeight, for a generation whose initial height is initial,
// and a block at lastHeight when it is above zero; it returns that block's hash.
func (n *node) commit(initial, lastHeight int64) []byte {
	n.t.Helper()
	key := secp256k1eth.GenPrivKey()
	genesis := &types.GenesisDoc{ChainID: "etna-wal", InitialHeight: initial, GenesisTime: time.Unix(1, 0),
		ConsensusParams: types.DefaultConsensusParams(), Validators: []types.GenesisValidator{{PubKey: key.PubKey(), Power: 10}}}
	genesis.ConsensusParams.Validator.PubKeyTypes = []string{secp256k1eth.KeyType}
	if err := genesis.ValidateAndComplete(); err != nil {
		n.t.Fatal(err)
	}
	state, err := sm.MakeGenesisState(genesis)
	if err != nil {
		n.t.Fatal(err)
	}
	var hash []byte
	if lastHeight > 0 {
		state.LastBlockHeight, state.LastValidators = lastHeight, state.Validators.Copy()
		block, err := state.MakeBlock(lastHeight, nil, &types.Commit{Height: lastHeight - 1}, nil, state.Validators.Proposer.Address)
		if err != nil {
			n.t.Fatal(err)
		}
		parts, err := block.MakePartSet(types.BlockPartSizeBytes)
		if err != nil {
			n.t.Fatal(err)
		}
		blockDB, err := dbm.NewGoLevelDB("blockstore", n.data)
		if err != nil {
			n.t.Fatal(err)
		}
		id := types.BlockID{Hash: block.Hash(), PartSetHeader: parts.Header()}
		store.NewBlockStore(blockDB).SaveBlock(block, parts, &types.Commit{Height: lastHeight, BlockID: id})
		blockDB.Close()
		hash = block.Hash()
	}
	stateDB, err := dbm.NewGoLevelDB("state", n.data)
	if err != nil {
		n.t.Fatal(err)
	}
	defer stateDB.Close()
	if err = sm.NewStore(stateDB, sm.StoreOptions{}).Save(state); err != nil {
		n.t.Fatal(err)
	}
	return hash
}

func (n *node) live(marker int64) *Binding {
	n.t.Helper()
	binding, err := Live(n.wal, marker)
	if err != nil {
		n.t.Fatal(err)
	}
	return binding
}

func (n *node) check(height int64, saved Binding, predecessor []byte) Preflight {
	n.t.Helper()
	result, err := Check(n.wal, n.data, height, saved, predecessor)
	if err != nil {
		n.t.Fatal(err)
	}
	return result
}

// A live binding covers every flushed byte after the predecessor's marker; the startup check
// accepts it while those bytes are intact and pins the complete records after them, including
// those written later, as the startup prefix.
func TestLiveBindingAndEligiblePreflight(t *testing.T) {
	n := newNode(t)
	predecessor := n.commit(1, 4)
	n.write(step(4, 0, "RoundStepCommit"), cs.EndHeightMessage{Height: 4}, step(5, 0, "RoundStepNewHeight"), step(5, 0, "RoundStepPrevote"))
	saved := n.live(4)
	if saved == nil || saved.Length == 0 {
		t.Fatalf("no live binding: %+v", saved)
	}
	// Round-state records written while handling later input after the signature.
	n.write(step(5, 0, "RoundStepPrevoteWait"), step(5, 1, "RoundStepPropose"))
	result := n.check(5, *saved, predecessor)
	if !result.Eligible || result.Startup == nil || result.Startup.Length <= saved.Length || result.Startup.Marker != 4 {
		t.Fatalf("intact binding refused: %+v", result)
	}
	if again := n.live(4); *again != *result.Startup {
		t.Fatalf("startup prefix %+v is not every complete record %+v", result.Startup, again)
	}
}

// RECOV-8.2-2 vectors 2.c/2.g/2.h/2.i/2.o: every way stock cannot replay the bound decision is
// ineligible, and the reason is reported.
func TestPreflightRefusals(t *testing.T) {
	setup := func(t *testing.T) (*node, Binding, []byte) {
		n := newNode(t)
		predecessor := n.commit(1, 4)
		n.write(cs.EndHeightMessage{Height: 4}, step(5, 0, "RoundStepPrevote"))
		return n, *n.live(4), predecessor
	}
	for _, c := range []struct {
		name   string
		mutate func(n *node, saved *Binding, predecessor *[]byte, height *int64)
	}{
		// 2.c/2.o: the marker is gone, as after the 1 GiB limit or a rebuilt WAL.
		{"missing-marker", func(n *node, _ *Binding, _ *[]byte, _ *int64) {
			os.RemoveAll(filepath.Dir(n.wal))
			n.write(step(5, 0, "RoundStepPrevote"))
		}},
		// 2.i: an import at s starts a fresh WAL with #ENDHEIGHT 0, never #ENDHEIGHT s.
		{"fresh-wal-after-import", func(n *node, _ *Binding, _ *[]byte, _ *int64) {
			os.RemoveAll(filepath.Dir(n.wal))
			n.write()
		}},
		{"damaged-prefix", func(n *node, saved *Binding, _ *[]byte, _ *int64) {
			saved.Digest = hex.EncodeToString(make([]byte, 32))
		}},
		{"truncated-prefix", func(n *node, saved *Binding, _ *[]byte, _ *int64) { saved.Length += 1 }},
		{"other-predecessor", func(n *node, _ *Binding, predecessor *[]byte, _ *int64) { *predecessor = make([]byte, 32) }},
		// 2.h: the stores moved past the predecessor (block sync).
		{"stores-not-at-the-predecessor", func(n *node, _ *Binding, _ *[]byte, height *int64) { *height = 6 }},
		{"decided-height", func(n *node, _ *Binding, _ *[]byte, _ *int64) { n.write(cs.EndHeightMessage{Height: 5}) }},
	} {
		t.Run(c.name, func(t *testing.T) {
			n, saved, predecessor := setup(t)
			height := int64(5)
			c.mutate(n, &saved, &predecessor, &height)
			if result := n.check(height, saved, predecessor); result.Eligible || result.Repair || result.Reason == "" {
				t.Fatalf("eligible: %+v", result)
			}
		})
	}
}

// A torn record after all signer-bound input is a recoverable tail (vector 2.l): not eligible
// for this start and flagged for stock repair, with the intact prefix pinned. A torn record
// inside the bound prefix is damage (no repair flag).
func TestTornTail(t *testing.T) {
	n := newNode(t)
	predecessor := n.commit(1, 4)
	n.write(cs.EndHeightMessage{Height: 4}, step(5, 0, "RoundStepPrevote"))
	saved := *n.live(4)
	n.write(step(5, 0, "RoundStepPrecommit"))
	whole, err := os.ReadFile(n.wal)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(n.wal, whole[:len(whole)-3], 0600); err != nil {
		t.Fatal(err)
	}
	result := n.check(5, saved, predecessor)
	if result.Eligible || !result.Repair || result.Startup == nil || result.Startup.Length != saved.Length {
		t.Fatalf("torn tail: %+v", result)
	}
	inside := saved
	inside.Length = saved.Length + 10
	if result = n.check(5, inside, predecessor); result.Eligible || result.Repair {
		t.Fatalf("torn bound prefix: %+v", result)
	}
}

// At the generation's initial height the predecessor is genesis: the marker is #ENDHEIGHT 0 and
// the stores hold no block, here at a non-one initial height.
func TestInitialHeightBindsGenesis(t *testing.T) {
	n := newNode(t)
	n.commit(1201, 0)
	n.write(step(1201, 0, "RoundStepPrevote"))
	saved := n.live(0)
	if saved == nil {
		t.Fatal("no #ENDHEIGHT 0 in a fresh WAL")
	}
	if result := n.check(1201, *saved, nil); !result.Eligible {
		t.Fatalf("genesis predecessor refused: %+v", result)
	}
	if result := n.check(1202, *saved, nil); result.Eligible {
		t.Fatalf("#ENDHEIGHT 0 bound a later height: %+v", result)
	}
}

// Without the marker a live signature records that same-height replay is unavailable.
func TestLiveWithoutMarker(t *testing.T) {
	n := newNode(t)
	n.write(step(7, 0, "RoundStepPrevote"))
	if binding := n.live(6); binding != nil {
		t.Fatalf("binding without #ENDHEIGHT 6: %+v", binding)
	}
	if binding, err := Live(filepath.Join(t.TempDir(), "absent", "wal"), 6); err != nil || binding != nil {
		t.Fatalf("absent WAL: %+v %v", binding, err)
	}
}
