package checkpoint

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"net"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"testing"
	"time"

	dbm "github.com/cometbft/cometbft-db"
	abciserver "github.com/cometbft/cometbft/abci/server"
	abci "github.com/cometbft/cometbft/abci/types"
	"github.com/cometbft/cometbft/consensus"
	"github.com/cometbft/cometbft/crypto/merkle"
	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	"github.com/cometbft/cometbft/libs/log"
	pb "github.com/cometbft/cometbft/proto/tendermint/types"
	"github.com/cometbft/cometbft/proxy"
	sm "github.com/cometbft/cometbft/state"
	bs "github.com/cometbft/cometbft/store"
	"github.com/cometbft/cometbft/types"
)

// firstHeight is the fixtures' generation initial_height, above 1 as for a recovery generation
// or a nonzero Etna start.
const firstHeight = 71

// firstBlockApp is a deterministic ABCI app with the Etna app's height rules: Info reports 0
// until Commit, InitChain answers the same app hash every time, and FinalizeBlock of the first
// block answers the same result every time (CONS-3.1-9).
type firstBlockApp struct {
	abci.BaseApplication
	mu sync.Mutex
	// genesisHash is InitChain's app hash, the one the first block's header carries.
	genesisHash []byte
	// committed is 0 or firstHeight; committedHash the app hash after it.
	committed     int64
	committedHash []byte
	pending       []byte
	// salt changes the FinalizeBlock result, standing for an app that answers differently.
	salt string
	// failInitChain makes that many InitChain calls fail, as an app that stops mid-repair.
	failInitChain int
	calls         []string
}

func (a *firstBlockApp) record(call string) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.calls = append(a.calls, call)
}

func (a *firstBlockApp) callLog() []string {
	a.mu.Lock()
	defer a.mu.Unlock()
	return append([]string(nil), a.calls...)
}

func (a *firstBlockApp) resetCalls() {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.calls = nil
}

func (a *firstBlockApp) Info(context.Context, *abci.RequestInfo) (*abci.ResponseInfo, error) {
	a.mu.Lock()
	defer a.mu.Unlock()
	return &abci.ResponseInfo{AppVersion: 1, LastBlockHeight: a.committed, LastBlockAppHash: a.committedHash}, nil
}

func (a *firstBlockApp) InitChain(context.Context, *abci.RequestInitChain) (*abci.ResponseInitChain, error) {
	a.record("InitChain")
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.failInitChain > 0 {
		a.failInitChain--
		return nil, errors.New("the app stopped")
	}
	return &abci.ResponseInitChain{AppHash: a.genesisHash}, nil
}

// resultHash is the app hash after block hash h.
func (a *firstBlockApp) resultHash(h []byte) []byte {
	sum := sha256.Sum256(append(append([]byte("after:"), h...), a.salt...))
	return sum[:]
}

func (a *firstBlockApp) FinalizeBlock(_ context.Context, req *abci.RequestFinalizeBlock) (*abci.ResponseFinalizeBlock, error) {
	a.record("FinalizeBlock")
	a.mu.Lock()
	defer a.mu.Unlock()
	a.pending = a.resultHash(req.Hash)
	return finalizeResponse(len(req.Txs), a.pending), nil
}

func (a *firstBlockApp) Commit(context.Context, *abci.RequestCommit) (*abci.ResponseCommit, error) {
	a.record("Commit")
	a.mu.Lock()
	defer a.mu.Unlock()
	a.committed, a.committedHash = firstHeight, a.pending
	return &abci.ResponseCommit{}, nil
}

// finalizeResponse is the Etna result: one fixed ExecTxResult per transaction (CONS-3.1-8).
func finalizeResponse(txs int, appHash []byte) *abci.ResponseFinalizeBlock {
	results := make([]*abci.ExecTxResult, txs)
	for i := range results {
		results[i] = &abci.ExecTxResult{}
	}
	return &abci.ResponseFinalizeBlock{TxResults: results, AppHash: appHash}
}

// serve runs app behind a stock ABCI socket server and returns its address.
func serve(t *testing.T, app abci.Application) string {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	server := abciserver.NewSocketServerWithListener(listener, app)
	server.SetLogger(log.NewNopLogger())
	if err = server.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = server.Stop() })
	return "tcp://" + listener.Addr().String()
}

// firstBlockFixture is one generation's genesis, committee keys and certified first block.
type firstBlockFixture struct {
	genesis *types.GenesisDoc
	keys    []secp256k1eth.PrivKey
	vals    *types.ValidatorSet
	// state is the stock state InitChain leaves: height 0 with InitChain's app hash.
	state  sm.State
	block  *types.Block
	parts  *types.PartSet
	id     types.BlockID
	commit *types.Commit
	app    *firstBlockApp
}

// newFirstBlockFixture builds a genesis at firstHeight with n equal validators and a first
// block carrying envelope, committed by the first signers validators in set order.
func newFirstBlockFixture(t *testing.T, n, signers int, envelope string) *firstBlockFixture {
	t.Helper()
	f := &firstBlockFixture{app: &firstBlockApp{genesisHash: bytes.Repeat([]byte{0x11}, 32)}}
	var genVals []types.GenesisValidator
	for i := 0; i < n; i++ {
		key := secp256k1eth.PrivKey(bytes.Repeat([]byte{byte(7 + i)}, 32))
		f.keys = append(f.keys, key)
		genVals = append(genVals, types.GenesisValidator{PubKey: key.PubKey(), Power: 10})
	}
	f.genesis = &types.GenesisDoc{GenesisTime: time.Unix(100, 0).UTC(), ChainID: "etna-first-block", InitialHeight: firstHeight, ConsensusParams: etnaParams(), Validators: genVals, AppState: json.RawMessage(`{}`)}
	if err := f.genesis.ValidateAndComplete(); err != nil {
		t.Fatal(err)
	}
	state, err := sm.MakeGenesisState(f.genesis)
	if err != nil {
		t.Fatal(err)
	}
	state.Version.Consensus.App = 1
	state.AppHash = f.app.genesisHash
	state.LastResultsHash = merkle.HashFromByteSlices(nil)
	f.state, f.vals = state, state.Validators
	f.block, f.parts, f.id, f.commit = f.makeBlock(t, envelope, signers)
	return f
}

// makeBlock builds the first block with envelope as its one transaction, committed by the
// first signers members of the committee in set order.
func (f *firstBlockFixture) makeBlock(t *testing.T, envelope string, signers int) (*types.Block, *types.PartSet, types.BlockID, *types.Commit) {
	t.Helper()
	block, err := f.state.MakeBlock(firstHeight, []types.Tx{types.Tx(envelope)}, &types.Commit{}, nil, f.vals.GetProposer().Address)
	if err != nil {
		t.Fatal(err)
	}
	parts, err := block.MakePartSet(types.BlockPartSizeBytes)
	if err != nil {
		t.Fatal(err)
	}
	id := types.BlockID{Hash: block.Hash(), PartSetHeader: parts.Header()}
	commit := &types.Commit{Height: firstHeight, Round: 0, BlockID: id}
	for index, val := range f.vals.Validators {
		if index >= signers {
			commit.Signatures = append(commit.Signatures, types.CommitSig{BlockIDFlag: types.BlockIDFlagAbsent})
			continue
		}
		var key secp256k1eth.PrivKey
		for _, k := range f.keys {
			if bytes.Equal(k.PubKey().Address(), val.Address) {
				key = k
			}
		}
		vote := &types.Vote{Type: pb.PrecommitType, Height: firstHeight, Round: 0, BlockID: id, Timestamp: block.Time.Add(time.Second), ValidatorAddress: val.Address, ValidatorIndex: int32(index)}
		if vote.Signature, err = key.Sign(types.VoteSignBytes(f.genesis.ChainID, vote.ToProto())); err != nil {
			t.Fatal(err)
		}
		commit.Signatures = append(commit.Signatures, vote.CommitSig())
	}
	return block, parts, id, commit
}

// home writes a stopped home as stock leaves it after a crash between saving the first block
// and saving its state: genesis, the post-InitChain state at height 0, the block with its seen
// commit unless withBlock is false, and a WAL.
func (f *firstBlockFixture) home(t *testing.T, withBlock bool) string {
	t.Helper()
	home := filepath.Join(t.TempDir(), "comet")
	for _, dir := range []string{"config", "data/cs.wal"} {
		if err := os.MkdirAll(filepath.Join(home, dir), 0o700); err != nil {
			t.Fatal(err)
		}
	}
	if err := f.genesis.SaveAs(filepath.Join(home, "config/genesis.json")); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(home, "data/cs.wal/wal"), []byte("#ENDHEIGHT 71 and the votes"), 0o600); err != nil {
		t.Fatal(err)
	}
	f.withStores(t, home, func(states sm.Store, blocks *bs.BlockStore) {
		if err := states.Save(f.state); err != nil {
			t.Fatal(err)
		}
		if withBlock {
			blocks.SaveBlock(f.block, f.parts, f.commit)
		}
	})
	return home
}

// withStores opens home's stock state and block stores read-write for visit.
func (f *firstBlockFixture) withStores(t *testing.T, home string, visit func(sm.Store, *bs.BlockStore)) {
	t.Helper()
	data := filepath.Join(home, "data")
	stateDB, err := dbm.NewGoLevelDB("state", data)
	if err != nil {
		t.Fatal(err)
	}
	defer stateDB.Close()
	blockDB, err := dbm.NewGoLevelDB("blockstore", data)
	if err != nil {
		t.Fatal(err)
	}
	defer blockDB.Close()
	visit(sm.NewStore(stateDB, sm.StoreOptions{}), bs.NewBlockStore(blockDB))
}

// stockHandshake runs the pinned stock Handshaker on home against app, as CometBFT does at
// startup, and returns its error or panic.
func (f *firstBlockFixture) stockHandshake(t *testing.T, home string, app abci.Application) (err error) {
	t.Helper()
	f.withStores(t, home, func(states sm.Store, blocks *bs.BlockStore) {
		state, e := states.LoadFromDBOrGenesisDoc(f.genesis)
		if e != nil {
			t.Fatal(e)
		}
		conns := proxy.NewAppConns(proxy.NewLocalClientCreator(app), proxy.NopMetrics())
		conns.SetLogger(log.NewNopLogger())
		if e = conns.Start(); e != nil {
			t.Fatal(e)
		}
		defer func() { _ = conns.Stop() }()
		handshaker := consensus.NewHandshaker(states, state, blocks, f.genesis)
		handshaker.SetLogger(log.NewNopLogger())
		defer func() {
			if r := recover(); r != nil {
				err = fmt.Errorf("stock handshake panicked: %v", r)
			}
		}()
		err = handshaker.Handshake(conns)
	})
	return err
}

// stored reads home's state height and app hash and its block store height.
func (f *firstBlockFixture) stored(t *testing.T, home string) (stateHeight int64, appHash []byte, storeHeight int64) {
	t.Helper()
	f.withStores(t, home, func(states sm.Store, blocks *bs.BlockStore) {
		state, err := states.Load()
		if err != nil {
			t.Fatal(err)
		}
		stateHeight, appHash, storeHeight = state.LastBlockHeight, state.AppHash, blocks.Height()
	})
	return
}

// tree reads every regular file under root by its relative path.
func tree(t *testing.T, root string) map[string]string {
	t.Helper()
	files := map[string]string{}
	err := filepath.WalkDir(root, func(path string, entry fs.DirEntry, err error) error {
		if err != nil || entry.IsDir() {
			return err
		}
		raw, err := os.ReadFile(path)
		rel, _ := filepath.Rel(root, path)
		files[rel] = string(raw)
		return err
	})
	if err != nil {
		t.Fatal(err)
	}
	return files
}

func (f *firstBlockFixture) repair(t *testing.T, home, addr, peer string) (RepairReport, string, error) {
	t.Helper()
	backup := filepath.Join(t.TempDir(), "backup")
	report, err := RepairFirstBlock(RepairOptions{Home: home, Backup: backup, App: addr, PeerExport: peer})
	return report, backup, err
}

var instancePattern = regexp.MustCompile(`^[0-9a-f]{32}\n$`)

// readInstance checks the store instance ID file's format and mode and returns its value.
func readInstance(t *testing.T, home string) string {
	t.Helper()
	path := filepath.Join(home, "data", StoreInstanceFile)
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	raw, _ := os.ReadFile(path)
	if info.Mode().Perm() != 0o600 || !instancePattern.Match(raw) {
		t.Fatalf("store instance %q mode %v", raw, info.Mode())
	}
	return strings.TrimSpace(string(raw))
}

// TestStockHandshakeStopsOnTheFirstBlockAndTheRepairResumesIt reproduces the CONS-3.1-9
// first-block failure with the pinned stock Handshaker: initial_height 71, the block and its
// seen commit saved, the state still at 0, so stock panics whatever the app reports. The repair
// preserves the original stores, verifies the certified block, applies it through the app
// (InitChain, FinalizeBlock and Commit, as stock's real-app replay would), writes a fresh store
// instance ID, and the unmodified stock handshake then completes (vector 9.q).
func TestStockHandshakeStopsOnTheFirstBlockAndTheRepairResumesIt(t *testing.T) {
	f := newFirstBlockFixture(t, 4, 3, "certified-envelope")
	home := f.home(t, true)
	err := f.stockHandshake(t, home, f.app)
	if err == nil || !strings.Contains(err.Error(), "StoreBlockHeight (71) > StateBlockHeight + 1 (1)") {
		t.Fatalf("stock handshake did not stop on the first block: %v", err)
	}
	f.app.resetCalls()
	original := tree(t, filepath.Join(home, "data"))

	report, backup, err := f.repair(t, home, serve(t, f.app), "")
	if err != nil {
		t.Fatal(err)
	}
	if got := tree(t, backup); fmt.Sprint(got) != fmt.Sprint(original) {
		t.Fatalf("the backup is not the original data directory:\n%v\n%v", got, original)
	}
	if got := f.app.callLog(); strings.Join(got, ",") != "InitChain,FinalizeBlock,Commit" {
		t.Fatalf("app calls %v", got)
	}
	afterHash := f.app.resultHash(f.id.Hash)
	want := RepairReport{Height: firstHeight, BlockID: BlockID{Hash: hexBytes(f.id.Hash), Parts: PartSet{Total: f.id.PartSetHeader.Total, Hash: hexBytes(f.id.PartSetHeader.Hash)}}, AppHash: hexBytes(afterHash), Source: "local", Applied: "executed", Backup: backup, StoreInstance: readInstance(t, home)}
	if report != want {
		t.Fatalf("report %+v, want %+v", report, want)
	}
	if h, hash, store := f.stored(t, home); h != firstHeight || !bytes.Equal(hash, afterHash) || store != firstHeight {
		t.Fatalf("stored state %d %X, block store %d", h, hash, store)
	}
	if wal, _ := os.ReadFile(filepath.Join(home, "data/cs.wal/wal")); string(wal) != "#ENDHEIGHT 71 and the votes" {
		t.Fatalf("the WAL changed: %q", wal)
	}
	if err = f.stockHandshake(t, home, f.app); err != nil {
		t.Fatalf("the stock handshake still stops after the repair: %v", err)
	}

	// A rerun only checks, and changes nothing, the store instance ID included.
	again, _, err := f.repair(t, home, serve(t, f.app), "")
	if err != nil || again.Applied != "already_repaired" || again.AppHash != want.AppHash || again.StoreInstance != "" || readInstance(t, home) != want.StoreInstance {
		t.Fatalf("rerun %+v: %v", again, err)
	}
}

// The repair replaces the store instance ID only once every check passed and immediately before
// it changes the stores (RECOV-8.2-2): a refusal, whatever its cause, and a rerun that only checks
// leave the ID the home had, so they never fence the signer needlessly.
func TestRepairWritesTheStoreInstanceOnlyWhenItChangesTheStores(t *testing.T) {
	const prior = "0123456789abcdef0123456789abcdef"
	withInstance := func(t *testing.T, home string) {
		t.Helper()
		if err := os.WriteFile(filepath.Join(home, "data", StoreInstanceFile), []byte(prior+"\n"), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	other := newFirstBlockFixture(t, 4, 3, "another-envelope")
	contradicting, err := encodeFirstBlock(other.block, other.commit, other.vals)
	if err != nil {
		t.Fatal(err)
	}
	for _, tc := range []struct {
		name    string
		signers int
		setup   func(*firstBlockFixture, string)
		peer    func(*testing.T) string
		want    string
	}{
		{name: "uncertified", signers: 2, want: "does not certify"},
		{name: "app at another height", signers: 3, setup: func(f *firstBlockFixture, _ string) {
			f.app.committed, f.app.committedHash = 5, bytes.Repeat([]byte{0x33}, 32)
		}, want: "first-block contradiction"},
		{name: "another certified block", signers: 3, peer: func(t *testing.T) string { return writeExport(t, contradicting) }, want: "first-block contradiction"},
		{name: "not the first-block failure", signers: 3, setup: func(f *firstBlockFixture, home string) {
			f.withStores(t, home, func(_ sm.Store, blocks *bs.BlockStore) {
				next := &types.Block{Header: f.block.Header}
				next.Height, next.LastCommit = firstHeight+1, f.commit
				parts, err := next.MakePartSet(types.BlockPartSizeBytes)
				if err != nil {
					t.Fatal(err)
				}
				blocks.SaveBlock(next, parts, &types.Commit{Height: firstHeight + 1, BlockID: types.BlockID{Hash: next.Hash(), PartSetHeader: parts.Header()}, Signatures: f.commit.Signatures})
			})
		}, want: "not the first-block failure"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			f := newFirstBlockFixture(t, 4, tc.signers, "certified-envelope")
			home := f.home(t, true)
			withInstance(t, home)
			if tc.setup != nil {
				tc.setup(f, home)
			}
			peer := ""
			if tc.peer != nil {
				peer = tc.peer(t)
			}
			if _, _, err := f.repair(t, home, serve(t, f.app), peer); err == nil || !strings.Contains(err.Error(), tc.want) {
				t.Fatalf("got %v, want %q", err, tc.want)
			}
			if got := readInstance(t, home); got != prior {
				t.Fatalf("a refused repair replaced the store instance ID with %s", got)
			}
		})
	}
	f := newFirstBlockFixture(t, 4, 3, "certified-envelope")
	home := f.home(t, true)
	withInstance(t, home)
	report, _, err := f.repair(t, home, serve(t, f.app), "")
	if err != nil || report.StoreInstance == prior || report.StoreInstance != readInstance(t, home) {
		t.Fatalf("a repair that changed the stores reported %+v (%v), ID %s", report, err, readInstance(t, home))
	}
}

// When the app committed the first block before the crash, stock kept its FinalizeBlock
// response; the repair replays that response instead of executing the block again, as stock's
// mock-app replay does. Without the response, or with one the app's hash contradicts, it stops.
func TestRepairReplaysTheKeptResponseOfAnAppThatCommitted(t *testing.T) {
	for _, tc := range []struct {
		name, kept string
		wantErr    string
	}{
		{"replayed", "same", ""},
		{"missing response", "none", "kept no FinalizeBlock response"},
		{"contradicting response", "other", "first-block contradiction"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			f := newFirstBlockFixture(t, 1, 1, "certified-envelope")
			home := f.home(t, true)
			after := f.app.resultHash(f.id.Hash)
			f.app.committed, f.app.committedHash = firstHeight, after
			if tc.kept != "none" {
				hash := after
				if tc.kept == "other" {
					hash = bytes.Repeat([]byte{0x22}, 32)
				}
				f.withStores(t, home, func(states sm.Store, _ *bs.BlockStore) {
					if err := states.SaveFinalizeBlockResponse(firstHeight, finalizeResponse(1, hash)); err != nil {
						t.Fatal(err)
					}
				})
			}
			report, _, err := f.repair(t, home, serve(t, f.app), "")
			if calls := f.app.callLog(); len(calls) != 0 {
				t.Fatalf("an app that committed was asked to %v", calls)
			}
			if tc.wantErr != "" {
				if err == nil || !strings.Contains(err.Error(), tc.wantErr) {
					t.Fatalf("got %+v, %v", report, err)
				}
				if h, _, _ := f.stored(t, home); h != 0 {
					t.Fatalf("a refused repair saved state %d", h)
				}
				return
			}
			if err != nil || report.Applied != "replayed" || report.AppHash != hexBytes(after) {
				t.Fatalf("got %+v, %v", report, err)
			}
			if err = f.stockHandshake(t, home, f.app); err != nil {
				t.Fatal(err)
			}
		})
	}
}

// A node whose block store never saved the first block, while the committee decided it, applies
// exactly that certified block from a peer's export instead of letting fresh rounds replace it
// (vector 9.t); the export is the blocks.jsonl line format.
func TestRepairInstallsTheCertifiedBlockFromAPeerExport(t *testing.T) {
	f := newFirstBlockFixture(t, 4, 3, "certified-envelope")
	peerHome := f.home(t, true)
	item, err := ExportFirstBlock(peerHome)
	if err != nil {
		t.Fatal(err)
	}
	export := filepath.Join(t.TempDir(), "first-block.json")
	raw, _ := json.Marshal(item)
	if err = os.WriteFile(export, raw, 0o600); err != nil {
		t.Fatal(err)
	}
	home := f.home(t, false)
	if _, _, err = f.repair(t, home, serve(t, f.app), ""); err == nil || !strings.Contains(err.Error(), "holds no block") {
		t.Fatalf("repaired a store without a block or export: %v", err)
	}
	if calls := f.app.callLog(); len(calls) != 0 {
		t.Fatalf("app calls %v", calls)
	}
	report, _, err := f.repair(t, home, serve(t, f.app), export)
	if err != nil || report.Source != "peer" || report.Applied != "executed" || report.BlockID.Hash != hexBytes(f.id.Hash) {
		t.Fatalf("got %+v, %v", report, err)
	}
	f.withStores(t, home, func(_ sm.Store, blocks *bs.BlockStore) {
		if meta := blocks.LoadBlockMeta(firstHeight); meta == nil || !meta.BlockID.Equals(f.id) || !sameCommit(blocks.LoadSeenCommit(firstHeight), f.commit) {
			t.Fatal("the certified block and its commit are not in the block store")
		}
	})
	if err = f.stockHandshake(t, home, f.app); err != nil {
		t.Fatal(err)
	}
}

// damaged is commit with its first signature corrupted: it still decodes and names the same
// BlockID, but no longer certifies it.
func damaged(commit *types.Commit) *types.Commit {
	broken := commit.Clone()
	broken.Signatures[0].Signature = append([]byte(nil), broken.Signatures[0].Signature...)
	broken.Signatures[0].Signature[3] ^= 0xff
	return broken
}

// stockLastCommit reconstructs home's LastCommit from its seen commit as stock consensus does
// when it starts above the handshake (votesFromSeenCommit), returning its panic or quorum error.
func (f *firstBlockFixture) stockLastCommit(t *testing.T, home string) (err error) {
	t.Helper()
	f.withStores(t, home, func(states sm.Store, blocks *bs.BlockStore) {
		state, e := states.Load()
		if e != nil {
			t.Fatal(e)
		}
		defer func() {
			if r := recover(); r != nil {
				err = fmt.Errorf("stock LastCommit reconstruction panicked: %v", r)
			}
		}()
		seen := blocks.LoadSeenCommit(state.LastBlockHeight)
		if seen == nil {
			err = errors.New("no seen commit")
			return
		}
		if !seen.ToVoteSet(state.ChainID, state.LastValidators).HasTwoThirdsMajority() {
			err = errors.New("the seen commit has no +2/3")
		}
	})
	return err
}

// writeExport writes item as a peer export file.
func writeExport(t *testing.T, item Block) string {
	t.Helper()
	export := filepath.Join(t.TempDir(), "first-block.json")
	raw, _ := json.Marshal(item)
	if err := os.WriteFile(export, raw, 0o600); err != nil {
		t.Fatal(err)
	}
	return export
}

// The stored block's seen commit is damaged while a peer's export certifies the same BlockID:
// the repair installs the peer's verified commit as the seen commit before it touches the app,
// so the block it applies carries a certificate stock consensus can rebuild its LastCommit from
// (CONS-3.1-9). Before that, nothing runs: without the export it refuses with no app call.
func TestRepairInstallsAVerifiedPeerCommitOverADamagedSeenCommit(t *testing.T) {
	f := newFirstBlockFixture(t, 4, 3, "certified-envelope")
	item, err := ExportFirstBlock(f.home(t, true))
	if err != nil {
		t.Fatal(err)
	}
	export := writeExport(t, item)
	home := f.home(t, false)
	f.withStores(t, home, func(_ sm.Store, blocks *bs.BlockStore) {
		blocks.SaveBlock(f.block, f.parts, damaged(f.commit))
	})
	if _, _, err = f.repair(t, home, serve(t, f.app), ""); err == nil || !strings.Contains(err.Error(), "does not certify") {
		t.Fatalf("applied a block whose seen commit does not certify it: %v", err)
	}
	if calls := f.app.callLog(); len(calls) != 0 {
		t.Fatalf("app calls %v", calls)
	}
	original := tree(t, filepath.Join(home, "data"))

	report, backup, err := f.repair(t, home, serve(t, f.app), export)
	if err != nil || report.Source != "peer_commit" || report.Applied != "executed" || report.BlockID.Hash != hexBytes(f.id.Hash) {
		t.Fatalf("got %+v, %v", report, err)
	}
	if got := tree(t, backup); fmt.Sprint(got) != fmt.Sprint(original) {
		t.Fatal("the backup is not the original data directory with its damaged seen commit")
	}
	f.withStores(t, home, func(_ sm.Store, blocks *bs.BlockStore) {
		if !sameCommit(blocks.LoadSeenCommit(firstHeight), f.commit) {
			t.Fatal("the seen commit is not the peer's verified commit")
		}
	})
	if err = f.stockHandshake(t, home, f.app); err != nil {
		t.Fatal(err)
	}
	if err = f.stockLastCommit(t, home); err != nil {
		t.Fatal(err)
	}
	if again, _, err := f.repair(t, home, serve(t, f.app), ""); err != nil || again.Applied != "already_repaired" || again.Source != "local" {
		t.Fatalf("rerun %+v: %v", again, err)
	}
}

// A home an earlier run left with the first block applied but a seen commit that does not
// certify it (the app and EL committed, so the block cannot be applied again) converges: a rerun
// with a peer export of the same certified block installs its commit as the seen commit and
// checks everything else.
func TestRepairRerunConvergesOnAnAppliedBlockWithADamagedSeenCommit(t *testing.T) {
	f := newFirstBlockFixture(t, 4, 3, "certified-envelope")
	item, err := ExportFirstBlock(f.home(t, true))
	if err != nil {
		t.Fatal(err)
	}
	home := f.home(t, true)
	if _, _, err = f.repair(t, home, serve(t, f.app), ""); err != nil {
		t.Fatal(err)
	}
	f.withStores(t, home, func(_ sm.Store, blocks *bs.BlockStore) {
		if err := blocks.SaveSeenCommit(firstHeight, damaged(f.commit)); err != nil {
			t.Fatal(err)
		}
	})
	if err = f.stockLastCommit(t, home); err == nil {
		t.Fatal("stock consensus accepts the damaged seen commit")
	}
	f.app.resetCalls()
	if _, _, err = f.repair(t, home, serve(t, f.app), ""); err == nil || !strings.Contains(err.Error(), "does not certify") {
		t.Fatalf("accepted a damaged seen commit: %v", err)
	}
	report, _, err := f.repair(t, home, serve(t, f.app), writeExport(t, item))
	if err != nil || report.Applied != "already_repaired" || report.Source != "peer_commit" {
		t.Fatalf("got %+v, %v", report, err)
	}
	if calls := f.app.callLog(); len(calls) != 0 {
		t.Fatalf("app calls %v on an applied block", calls)
	}
	if err = f.stockHandshake(t, home, f.app); err != nil {
		t.Fatal(err)
	}
	if err = f.stockLastCommit(t, home); err != nil {
		t.Fatal(err)
	}
}

// Every check that can refuse runs before the first store write or app call: an app at another
// height, an app that committed without a kept response and a peer export whose commit does not
// certify its block leave the stores and the app as they were, and a state that names the first
// block over an empty block store is not the first-block failure. A failure after the first write
// (the app stops in InitChain after the peer's block was saved) converges on a rerun, which finds
// the certified block in the block store.
func TestRepairRefusesBeforeItWritesAndConvergesAfterALaterFailure(t *testing.T) {
	f := newFirstBlockFixture(t, 4, 3, "certified-envelope")
	item, err := ExportFirstBlock(f.home(t, true))
	if err != nil {
		t.Fatal(err)
	}
	export := writeExport(t, item)
	unchanged := func(home string) {
		t.Helper()
		if h, _, store := f.stored(t, home); h != 0 || store != 0 {
			t.Fatalf("a refused repair changed the stores: state %d, block store %d", h, store)
		}
		if calls := f.app.callLog(); len(calls) != 0 {
			t.Fatalf("a refused repair called the app: %v", calls)
		}
	}
	for _, tc := range []struct {
		name      string
		committed int64
		want      string
	}{
		{"app at another height", 5, "first-block contradiction"},
		{"app committed without a kept response", firstHeight, "kept no FinalizeBlock response"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			home := f.home(t, false)
			f.app.committed, f.app.committedHash = tc.committed, bytes.Repeat([]byte{0x33}, 32)
			defer func() { f.app.committed, f.app.committedHash = 0, nil }()
			if _, _, err := f.repair(t, home, serve(t, f.app), export); err == nil || !strings.Contains(err.Error(), tc.want) {
				t.Fatalf("got %v, want %q", err, tc.want)
			}
			unchanged(home)
		})
	}
	t.Run("uncertified peer export", func(t *testing.T) {
		home := f.home(t, false)
		broken := item
		raw, _ := damaged(f.commit).ToProto().Marshal()
		broken.Commit = hexBytes(raw)
		if _, _, err := f.repair(t, home, serve(t, f.app), writeExport(t, broken)); err == nil || !strings.Contains(err.Error(), "peer export's commit does not certify") {
			t.Fatalf("applied an uncertified peer export: %v", err)
		}
		unchanged(home)
	})
	t.Run("state at the first height over an empty block store", func(t *testing.T) {
		home := f.home(t, false)
		f.withStores(t, home, func(states sm.Store, _ *bs.BlockStore) {
			state := f.state.Copy()
			state.LastBlockHeight, state.LastBlockID, state.LastValidators = firstHeight, f.id, state.Validators.Copy()
			if err := states.Save(state); err != nil {
				t.Fatal(err)
			}
		})
		if _, _, err := f.repair(t, home, serve(t, f.app), export); err == nil || !strings.Contains(err.Error(), "not the first-block failure") {
			t.Fatalf("got %v", err)
		}
		if _, _, store := f.stored(t, home); store != 0 || len(f.app.callLog()) != 0 {
			t.Fatal("a refused repair changed the block store or called the app")
		}
	})
	t.Run("the app stops after the block was saved", func(t *testing.T) {
		home := f.home(t, false)
		f.app.failInitChain = 1
		if _, _, err := f.repair(t, home, serve(t, f.app), export); err == nil || !strings.Contains(err.Error(), "InitChain") {
			t.Fatalf("got %v", err)
		}
		if h, _, store := f.stored(t, home); h != 0 || store != firstHeight {
			t.Fatalf("state %d, block store %d after the stopped app", h, store)
		}
		f.app.resetCalls()
		report, _, err := f.repair(t, home, serve(t, f.app), "")
		if err != nil || report.Source != "local" || report.Applied != "executed" {
			t.Fatalf("rerun %+v: %v", report, err)
		}
		if err = f.stockHandshake(t, home, f.app); err != nil {
			t.Fatal(err)
		}
		if err = f.stockLastCommit(t, home); err != nil {
			t.Fatal(err)
		}
	})
}

// Only a block that more than 2/3 of the genesis committee certified, for the full BlockID, is
// applied; a peer's different certified block contradicts the stored one; an app whose result
// differs from the one stock kept stops the repair before stock saves anything.
func TestRepairRefusesUncertifiedAndContradictingFirstBlocks(t *testing.T) {
	t.Run("two thirds not reached", func(t *testing.T) {
		f := newFirstBlockFixture(t, 4, 2, "certified-envelope")
		home := f.home(t, true)
		if _, _, err := f.repair(t, home, serve(t, f.app), ""); err == nil || !strings.Contains(err.Error(), "does not certify") {
			t.Fatalf("applied a block with half the power: %v", err)
		}
		if calls := f.app.callLog(); len(calls) != 0 {
			t.Fatalf("app calls %v", calls)
		}
	})
	t.Run("a different certified block", func(t *testing.T) {
		f := newFirstBlockFixture(t, 4, 3, "certified-envelope")
		home := f.home(t, true)
		other := newFirstBlockFixture(t, 4, 3, "another-envelope")
		item, err := encodeFirstBlock(other.block, other.commit, other.vals)
		if err != nil {
			t.Fatal(err)
		}
		export := filepath.Join(t.TempDir(), "first-block.json")
		raw, _ := json.Marshal(item)
		if err = os.WriteFile(export, raw, 0o600); err != nil {
			t.Fatal(err)
		}
		_, _, err = f.repair(t, home, serve(t, f.app), export)
		if !errors.Is(err, ErrFirstBlockContradiction) {
			t.Fatalf("accepted a second certified block: %v", err)
		}
		if h, _, _ := f.stored(t, home); h != 0 || len(f.app.callLog()) != 0 {
			t.Fatal("a contradiction changed the stores or the app")
		}
	})
	t.Run("a FinalizeBlock result unlike the kept one", func(t *testing.T) {
		f := newFirstBlockFixture(t, 1, 1, "certified-envelope")
		home := f.home(t, true)
		f.withStores(t, home, func(states sm.Store, _ *bs.BlockStore) {
			if err := states.SaveFinalizeBlockResponse(firstHeight, finalizeResponse(1, f.app.resultHash(f.id.Hash))); err != nil {
				t.Fatal(err)
			}
		})
		f.app.salt = "the EL now executes differently"
		_, _, err := f.repair(t, home, serve(t, f.app), "")
		if !errors.Is(err, ErrFirstBlockContradiction) {
			t.Fatalf("accepted a different result: %v", err)
		}
		if h, _, _ := f.stored(t, home); h != 0 {
			t.Fatal("stock saved the state after a different result")
		}
		if calls := strings.Join(f.app.callLog(), ","); calls != "InitChain,FinalizeBlock" {
			t.Fatalf("the app committed a different result: %v", calls)
		}
	})
}

// The repair runs only offline on a stopped Comet home of a generation above height 1, and
// never overwrites or nests its backup.
func TestRepairRefusesARunningCometAndAnUnusableBackup(t *testing.T) {
	f := newFirstBlockFixture(t, 1, 1, "certified-envelope")
	home := f.home(t, true)
	addr := serve(t, f.app)
	db, err := dbm.NewGoLevelDB("state", filepath.Join(home, "data"))
	if err != nil {
		t.Fatal(err)
	}
	if _, backup, err := f.repair(t, home, addr, ""); err == nil || !strings.Contains(err.Error(), "is CometBFT stopped?") {
		t.Fatalf("repaired a home Comet holds: %v", err)
	} else if _, e := os.Lstat(backup); !errors.Is(e, os.ErrNotExist) {
		t.Fatalf("a refused repair wrote its backup: %v", e)
	}
	db.Close()
	existing := t.TempDir()
	for backup, message := range map[string]string{
		existing:                            "must not exist",
		filepath.Join(home, "data", "copy"): "outside the data directory",
		filepath.Join(home, "data"):         "outside the data directory",
	} {
		if _, err = RepairFirstBlock(RepairOptions{Home: home, Backup: backup, App: addr}); err == nil || !strings.Contains(err.Error(), message) {
			t.Fatalf("backup %s: %v", backup, err)
		}
	}
	if _, err = os.Stat(filepath.Join(home, "data", StoreInstanceFile)); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("a refused repair wrote a store instance ID: %v", err)
	}
	f.genesis.InitialHeight = 1
	one := filepath.Join(t.TempDir(), "comet")
	if err = os.MkdirAll(filepath.Join(one, "config"), 0o700); err != nil {
		t.Fatal(err)
	}
	if err = f.genesis.SaveAs(filepath.Join(one, "config/genesis.json")); err != nil {
		t.Fatal(err)
	}
	if _, err = RepairFirstBlock(RepairOptions{Home: one, Backup: filepath.Join(t.TempDir(), "b"), App: addr}); err == nil || !strings.Contains(err.Error(), "nothing to repair") {
		t.Fatalf("repaired a generation starting at height 1: %v", err)
	}
	if calls := f.app.callLog(); len(calls) != 0 {
		t.Fatalf("app calls %v", calls)
	}
}

// The offline tools read goleveldb stores in <home>/data only. A home whose config.toml keeps its
// stores elsewhere (another db_dir, absolute or relative, in any key spelling) or in another
// backend is refused before anything is read, copied or written; the stock default, spelled out
// or implied by a config without the keys or by no config.toml at all, is accepted.
func TestFirstBlockToolsRefuseStoresOutsideTheStockDefault(t *testing.T) {
	f := newFirstBlockFixture(t, 1, 1, "certified-envelope")
	for _, tc := range []struct {
		config string
		want   string
	}{
		{`db_dir = "elsewhere"`, "only the stock default db_dir"},
		{`DB_Dir = "elsewhere"`, "only the stock default db_dir"},
		{`db_dir = "/srv/comet/data"`, "only the stock default db_dir"},
		{`db_dir = ""`, "only the stock default db_dir"},
		{`db_dir = 7`, "only the stock default db_dir"},
		{"db_dir = \"data\"\nDB_DIR = \"other\"", "only the stock default db_dir"},
		{`db_backend = "pebbledb"`, "only goleveldb stores"},
		{`DB_BACKEND = "pebbledb"`, "only goleveldb stores"},
		{`db_backend = = "goleveldb"`, "config.toml"},
	} {
		t.Run(tc.config, func(t *testing.T) {
			home := f.home(t, true)
			if err := os.WriteFile(filepath.Join(home, "config/config.toml"), []byte(tc.config+"\n"), 0o600); err != nil {
				t.Fatal(err)
			}
			if _, err := ExportFirstBlock(home); err == nil || !strings.Contains(err.Error(), tc.want) {
				t.Fatalf("export: %v", err)
			}
			_, backup, err := f.repair(t, home, serve(t, f.app), "")
			if err == nil || !strings.Contains(err.Error(), tc.want) {
				t.Fatalf("repair: %v", err)
			}
			if _, e := os.Lstat(backup); !errors.Is(e, os.ErrNotExist) {
				t.Fatalf("a refused repair wrote its backup: %v", e)
			}
			if h, _, _ := f.stored(t, home); h != 0 || len(f.app.callLog()) != 0 {
				t.Fatal("a refused repair changed the stores or called the app")
			}
		})
	}
	for _, config := range []string{"", "moniker = \"a\"\n[p2p]\npex = false", `db_dir = "data"`, `db_dir = "./data"`, `db_backend = "goleveldb"`} {
		t.Run("accepted "+config, func(t *testing.T) {
			home := f.home(t, true)
			if err := os.WriteFile(filepath.Join(home, "config/config.toml"), []byte(config+"\n"), 0o600); err != nil {
				t.Fatal(err)
			}
			if _, err := ExportFirstBlock(home); err != nil {
				t.Fatal(err)
			}
		})
	}
	t.Run("absolute stock path", func(t *testing.T) {
		home := f.home(t, true)
		config := fmt.Sprintf("db_dir = %q\n", filepath.Join(home, "data"))
		if err := os.WriteFile(filepath.Join(home, "config/config.toml"), []byte(config), 0o600); err != nil {
			t.Fatal(err)
		}
		if _, err := ExportFirstBlock(home); err != nil {
			t.Fatal(err)
		}
	})
}
