// Actual exported stock handshake over structural disk stores and an explicitly
// controlled ABCI app. No node, P2P, private key, signing or real EL is involved.
package bootstrap_test

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	dbm "github.com/cometbft/cometbft-db"
	abci "github.com/cometbft/cometbft/abci/types"
	"github.com/cometbft/cometbft/consensus"
	cmtstate "github.com/cometbft/cometbft/proto/tendermint/state"
	"github.com/cometbft/cometbft/proxy"
	"github.com/cometbft/cometbft/state"
	blockstore "github.com/cometbft/cometbft/store"
	"github.com/cometbft/cometbft/types"
)

type handshakeCase struct {
	Name                                      string
	StateHeight, Base, StoreHeight, AppHeight int64
	Mismatch                                  bool
	LastResponse                              int64
	AppBoundary                               string
	Origin                                    bool
	WantKind, WantReason                      string
	WantInit, WantFinalize, WantCommit        int
}

var handshakeCases = []handshakeCase{
	{Name: "consistent-no-replay", StateHeight: 4, Base: 4, StoreHeight: 4, AppHeight: 4, WantKind: "success"},
	{Name: "negative-info-height", StateHeight: 4, Base: 4, StoreHeight: 4, AppHeight: -1, WantKind: "error", WantReason: "got a negative last block height (-1) from the app"},
	{Name: "nonempty-apphash-mismatch", StateHeight: 4, Base: 4, StoreHeight: 4, AppHeight: 4, Mismatch: true, WantKind: "panic"},
	{Name: "app-ahead", StateHeight: 4, Base: 4, StoreHeight: 4, AppHeight: 5, WantKind: "error", WantReason: "error on replay: app block height (5) is higher than core (4)"},
	{Name: "app-below-store-base", StateHeight: 4, Base: 4, StoreHeight: 4, AppHeight: 2, WantKind: "error", WantReason: "error on replay: app block height (2) is too far below block store base (4)"},
	{Name: "state-ahead", StateHeight: 5, Base: 4, StoreHeight: 4, AppHeight: 4, WantKind: "panic", WantReason: "StateBlockHeight (5) > StoreBlockHeight (4)"},
	{Name: "store-too-far-ahead", StateHeight: 4, Base: 4, StoreHeight: 6, AppHeight: 4, WantKind: "panic", WantReason: "StoreBlockHeight (6) > StateBlockHeight + 1 (5)"},
	{Name: "missing-last-response", StateHeight: 4, Base: 4, StoreHeight: 5, AppHeight: 5, WantKind: "error", WantReason: "error on replay: no last ABCI response has been persisted"},
	{Name: "wrong-height-last-response", StateHeight: 4, Base: 4, StoreHeight: 5, AppHeight: 5, LastResponse: 4, WantKind: "error", WantReason: "error on replay: expected height 5 but last stored abci responses was at height 4"},
	{Name: "empty-store-equal", StateHeight: 4, AppHeight: 4, WantKind: "success"},
	{Name: "empty-store-mismatch", StateHeight: 4, AppHeight: 4, Mismatch: true, WantKind: "panic"},
	{Name: "empty-store-different-app-height", StateHeight: 4, AppHeight: 5, WantKind: "success"},
	{Name: "nonone-first-block-crash", StateHeight: 0, Base: 3, StoreHeight: 3, AppHeight: 0, Origin: true, WantKind: "panic", WantReason: "StoreBlockHeight (3) > StateBlockHeight + 1 (1)", WantInit: 1},
	{Name: "app-behind-finalize-boundary", StateHeight: 4, Base: 4, StoreHeight: 4, AppHeight: 3, AppBoundary: "FinalizeBlock", WantKind: "error", WantReason: "error on replay: controlled FinalizeBlock boundary", WantFinalize: 1},
	{Name: "app-behind-commit-boundary", StateHeight: 4, Base: 4, StoreHeight: 4, AppHeight: 3, AppBoundary: "Commit", WantKind: "error", WantReason: "error on replay: controlled Commit boundary", WantFinalize: 1, WantCommit: 1},
}

type appCalls struct{ Info, InitChain, FinalizeBlock, Commit int }
type initObservation struct {
	Chain         string
	InitialHeight int64
	Time          string
	Validators    int
	AppVersion    uint64
}
type controlledHandshakeApp struct {
	abci.BaseApplication
	height           int64
	hash             []byte
	initHash         []byte
	boundary         string
	calls            appCalls
	init             *initObservation
	finalizedHeights []int64
}

func (a *controlledHandshakeApp) Info(context.Context, *abci.RequestInfo) (*abci.ResponseInfo, error) {
	a.calls.Info++
	return &abci.ResponseInfo{LastBlockHeight: a.height, LastBlockAppHash: append([]byte(nil), a.hash...), AppVersion: 0}, nil
}
func (a *controlledHandshakeApp) InitChain(_ context.Context, r *abci.RequestInitChain) (*abci.ResponseInitChain, error) {
	a.calls.InitChain++
	a.init = &initObservation{r.ChainId, r.InitialHeight, r.Time.UTC().Format(time.RFC3339Nano), len(r.Validators), r.ConsensusParams.Version.App}
	return &abci.ResponseInitChain{AppHash: append([]byte(nil), a.initHash...)}, nil
}
func (a *controlledHandshakeApp) FinalizeBlock(_ context.Context, r *abci.RequestFinalizeBlock) (*abci.ResponseFinalizeBlock, error) {
	a.calls.FinalizeBlock++
	a.finalizedHeights = append(a.finalizedHeights, r.Height)
	if a.boundary == "FinalizeBlock" {
		return nil, errors.New("controlled FinalizeBlock boundary")
	}
	if a.boundary != "Commit" {
		return nil, errors.New("unexpected controlled FinalizeBlock call")
	}
	return &abci.ResponseFinalizeBlock{AppHash: append([]byte(nil), a.hash...), TxResults: []*abci.ExecTxResult{}}, nil
}
func (a *controlledHandshakeApp) Commit(context.Context, *abci.RequestCommit) (*abci.ResponseCommit, error) {
	a.calls.Commit++
	return nil, errors.New("controlled Commit boundary")
}

type handshakeResult struct {
	Kind      string `json:"kind"`
	Reason    string `json:"reason"`
	PanicType string `json:"panicType"`
}

// Recovery is restricted to the exact exported call, never fixture setup,
// lifecycle start/stop, independent observers or the direct typed-error probe.
func callHandshake(ctx context.Context, h *consensus.Handshaker, app proxy.AppConns) (result handshakeResult, callErr error) {
	defer func() {
		if p := recover(); p != nil {
			result = handshakeResult{"panic", fmt.Sprint(p), fmt.Sprintf("%T", p)}
		}
	}()
	if err := h.HandshakeWithContext(ctx, app); err != nil {
		return handshakeResult{"error", err.Error(), ""}, err
	}
	return handshakeResult{"success", "", ""}, nil
}

type handshakeObservation struct {
	StateHeight                  int64            `json:"stateHeight"`
	InitialHeight                int64            `json:"initialHeight"`
	BlockBase                    int64            `json:"blockBase"`
	BlockHeight                  int64            `json:"blockHeight"`
	AppHeight                    int64            `json:"appHeight"`
	AppHash                      string           `json:"appHash"`
	LastResponseHeight           int64            `json:"lastResponseHeight"`
	ExtraValidatorHistory        bool             `json:"extraValidatorHistory"`
	Result                       handshakeResult  `json:"result"`
	Calls                        appCalls         `json:"calls"`
	InitRequest                  *initObservation `json:"initRequest"`
	FinalizedHeights             []int64          `json:"finalizedHeights"`
	NBlocks                      int              `json:"nBlocks"`
	TypedReplay                  string           `json:"typedReplay"`
	HandshakePreservesTypedError bool             `json:"handshakePreservesTypedError"`
	StateBefore                  stateView        `json:"stateBefore"`
	StateAfter                   stateView        `json:"stateAfter"`
	StateBeforeSha256            string           `json:"stateBeforeSha256"`
	StateAfterSha256             string           `json:"stateAfterSha256"`
	BlockBeforeSha256            string           `json:"blockBeforeSha256"`
	BlockAfterSha256             string           `json:"blockAfterSha256"`
}
type handshakeEnvelope struct {
	Kind        string               `json:"kind"`
	Name        string               `json:"name"`
	Directory   string               `json:"directory"`
	ParentPID   int                  `json:"parentPID"`
	WorkerPID   int                  `json:"workerPID"`
	Observation handshakeObservation `json:"observation"`
}

func logicalDBHash(t *testing.T, db dbm.DB) string {
	t.Helper()
	iterator, err := db.Iterator(nil, nil)
	if err != nil {
		t.Fatal(err)
	}
	hash := sha256.New()
	for ; iterator.Valid(); iterator.Next() {
		key, value := iterator.Key(), iterator.Value()
		fmt.Fprintf(hash, "%d:", len(key))
		hash.Write(key)
		fmt.Fprintf(hash, "%d:", len(value))
		hash.Write(value)
	}
	if err := iterator.Error(); err != nil {
		t.Fatal(err)
	}
	if err := iterator.Close(); err != nil {
		t.Fatal(err)
	}
	return hex.EncodeToString(hash.Sum(nil))
}
func storageBlock(t *testing.T, s state.State, h int64) *types.Block {
	t.Helper()
	// Unsigned structural storage input. SaveBlock is not commit verification.
	commit := &types.Commit{}
	if h != s.InitialHeight {
		commit.Height = h - 1
		commit.BlockID = s.LastBlockID
		commit.Signatures = []types.CommitSig{{BlockIDFlag: types.BlockIDFlagAbsent}, {BlockIDFlag: types.BlockIDFlagAbsent}}
	}
	block := types.MakeBlock(h, nil, commit, nil)
	block.Populate(s.Version.Consensus, s.ChainID, time.Unix(100+h, 0).UTC(), s.LastBlockID, s.Validators.Hash(), s.NextValidators.Hash(), s.ConsensusParams.Hash(), s.AppHash, s.LastResultsHash, s.Validators.Proposer.Address)
	return block
}
func executeHandshakeCase(t *testing.T, c handshakeCase, dir string) handshakeObservation {
	t.Helper()
	id := "current-base"
	if c.Origin {
		id = "origin-base"
	}
	receipt := loadCases(t)[id]
	if err := auditReceipt(receipt); err != nil {
		t.Fatal(err)
	}
	s := adaptState(receipt)
	assertState(t, s, id)
	s.LastBlockHeight = c.StateHeight
	stateDB, err := dbm.NewGoLevelDB("state", dir)
	if err != nil {
		t.Fatal(err)
	}
	stateStore := state.NewStore(stateDB, state.StoreOptions{})
	if err := stateStore.Bootstrap(s); err != nil {
		t.Fatal(err)
	}
	// This extra independently literal row is solely the app-behind storage
	// premise consumed by ExecCommitBlock's unsigned CommitInfo construction.
	extra := c.AppBoundary != ""
	if extra {
		vs := adaptSet(literalProfile("origin-base").First)
		proto, err := vs.ToProto()
		if err != nil {
			t.Fatal(err)
		}
		info := cmtstate.ValidatorsInfo{LastHeightChanged: 3, ValidatorSet: proto}
		raw, err := info.Marshal()
		if err != nil {
			t.Fatal(err)
		}
		if err := stateDB.SetSync([]byte("validatorsKey:3"), raw); err != nil {
			t.Fatal(err)
		}
		checkRow(t, stateDB, stateStore, 3, expectedState("origin-base").Validators)
	}
	if c.LastResponse != 0 {
		if err := stateStore.SaveFinalizeBlockResponse(c.LastResponse, &abci.ResponseFinalizeBlock{AppHash: append([]byte(nil), s.AppHash...)}); err != nil {
			t.Fatal(err)
		}
		if _, err := stateStore.LoadLastFinalizeBlockResponse(c.LastResponse); err != nil {
			t.Fatal(err)
		}
	}
	if err := stateStore.Close(); err != nil {
		t.Fatal(err)
	}
	stateDB, err = dbm.NewGoLevelDB("state", dir)
	if err != nil {
		t.Fatal(err)
	}
	defer func() {
		if err := stateDB.Close(); err != nil {
			t.Error(err)
		}
	}()
	stateStore = state.NewStore(stateDB, state.StoreOptions{})
	loaded, err := stateStore.Load()
	if err != nil {
		t.Fatal(err)
	}
	if d := firstDifference(observeState(loaded), observeState(s)); d != "" {
		t.Fatal("disk fixture state mismatch: " + d)
	}
	responseHeight := int64(0)
	responseRaw := diskGet(t, stateDB, "lastABCIResponseKey")
	if len(responseRaw) != 0 {
		var info cmtstate.ABCIResponsesInfo
		if err := info.Unmarshal(responseRaw); err != nil {
			t.Fatal(err)
		}
		responseHeight = info.Height
		if info.ResponseFinalizeBlock == nil || !bytes.Equal(info.ResponseFinalizeBlock.AppHash, loaded.AppHash) {
			t.Fatal("unexpected raw last-response payload")
		}
	}
	if responseHeight != c.LastResponse {
		t.Fatal("missing/wrong raw last-response height")
	}
	blockDB, err := dbm.NewGoLevelDB("blocks", dir)
	if err != nil {
		t.Fatal(err)
	}
	blocks := blockstore.NewBlockStore(blockDB)
	if c.StoreHeight != 0 {
		for h := c.Base; h <= c.StoreHeight; h++ {
			block := storageBlock(t, loaded, h)
			parts, err := block.MakePartSet(types.BlockPartSizeBytes)
			if err != nil {
				t.Fatal(err)
			}
			blocks.SaveBlock(block, parts, &types.Commit{Height: h})
		}
	}
	if err := blockDB.Close(); err != nil {
		t.Fatal(err)
	}
	blockDB, err = dbm.NewGoLevelDB("blocks", dir)
	if err != nil {
		t.Fatal(err)
	}
	defer func() {
		if err := blockDB.Close(); err != nil {
			t.Error(err)
		}
	}()
	blocks = blockstore.NewBlockStore(blockDB)
	if blocks.Base() != c.Base || blocks.Height() != c.StoreHeight {
		t.Fatal("actual blockstore base/height mismatch")
	}
	appHash := append([]byte(nil), loaded.AppHash...)
	if c.Mismatch {
		appHash = bytes.Repeat([]byte{0xA5}, 32)
	}
	app := &controlledHandshakeApp{height: c.AppHeight, hash: appHash, initHash: append([]byte(nil), loaded.AppHash...), boundary: c.AppBoundary, finalizedHeights: []int64{}}
	conns := proxy.NewAppConns(proxy.NewLocalClientCreator(app), proxy.NopMetrics())
	if err := conns.Start(); err != nil {
		t.Fatal(err)
	}
	genesis := &types.GenesisDoc{ChainID: loaded.ChainID, InitialHeight: loaded.InitialHeight, GenesisTime: loaded.LastBlockTime, ConsensusParams: &loaded.ConsensusParams, AppHash: loaded.AppHash}
	for _, v := range loaded.Validators.Validators {
		genesis.Validators = append(genesis.Validators, types.GenesisValidator{PubKey: v.PubKey, Power: v.VotingPower})
	}
	h := consensus.NewHandshaker(stateStore, loaded, blocks, genesis)
	observation := handshakeObservation{StateHeight: loaded.LastBlockHeight, InitialHeight: loaded.InitialHeight, BlockBase: blocks.Base(), BlockHeight: blocks.Height(), AppHeight: c.AppHeight, AppHash: hex.EncodeToString(appHash), LastResponseHeight: responseHeight, ExtraValidatorHistory: extra, StateBefore: observeState(loaded), StateBeforeSha256: logicalDBHash(t, stateDB), BlockBeforeSha256: logicalDBHash(t, blockDB)}
	result, handshakeErr := callHandshake(context.Background(), h, conns)
	// Exported Handshake formats replay errors with %v. Verify typed refusal
	// separately through actual ReplayBlocks, never imply errors.As survived.
	if c.Name == "app-ahead" || c.Name == "app-below-store-base" {
		_, typedErr := h.ReplayBlocksWithContext(context.Background(), loaded, appHash, c.AppHeight, conns)
		if c.Name == "app-ahead" {
			var typed state.ErrAppBlockHeightTooHigh
			if !errors.As(typedErr, &typed) || typed.AppHeight != 5 || typed.CoreHeight != 4 {
				t.Fatalf("wrong typed high replay: %v", typedErr)
			}
			observation.TypedReplay = "ErrAppBlockHeightTooHigh"
		} else {
			var typed state.ErrAppBlockHeightTooLow
			if !errors.As(typedErr, &typed) || typed.AppHeight != 2 || typed.StoreBase != 4 {
				t.Fatalf("wrong typed low replay: %v", typedErr)
			}
			observation.TypedReplay = "ErrAppBlockHeightTooLow"
		}
		var high state.ErrAppBlockHeightTooHigh
		var low state.ErrAppBlockHeightTooLow
		observation.HandshakePreservesTypedError = errors.As(handshakeErr, &high) || errors.As(handshakeErr, &low)
		if observation.HandshakePreservesTypedError {
			t.Fatal("unexpected typed exported Handshake error")
		}
	}
	if err := conns.Stop(); err != nil {
		t.Fatal(err)
	}
	observation.Result = result
	observation.Calls = app.calls
	observation.InitRequest = app.init
	observation.FinalizedHeights = app.finalizedHeights
	observation.NBlocks = h.NBlocks()
	after, err := stateStore.Load()
	if err != nil {
		t.Fatal(err)
	}
	observation.StateAfter = observeState(after)
	observation.StateAfterSha256 = logicalDBHash(t, stateDB)
	observation.BlockAfterSha256 = logicalDBHash(t, blockDB)
	if app.calls != (appCalls{1, c.WantInit, c.WantFinalize, c.WantCommit}) || h.NBlocks() != 0 {
		t.Fatalf("unexpected ABCI calls/blocks: %+v/%d", app.calls, h.NBlocks())
	}
	if observation.BlockBeforeSha256 != observation.BlockAfterSha256 {
		t.Fatal("handshake changed structural blockstore")
	}
	if !c.Origin && observation.StateBeforeSha256 != observation.StateAfterSha256 {
		t.Fatal("non-init handshake changed state store")
	}
	if c.Origin {
		want := loaded.Copy()
		want.LastResultsHash = unhex("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
		if d := firstDifference(observeState(after), observeState(want)); d != "" {
			t.Fatal("unexpected known-stop InitChain state field: " + d)
		}
		if app.init == nil || app.init.Chain != loaded.ChainID || app.init.InitialHeight != 3 || app.init.Time != "1970-01-01T00:01:40Z" || app.init.Validators != 2 || app.init.AppVersion != 0 {
			t.Fatalf("wrong InitChain request: %+v", app.init)
		}
	}
	if c.WantFinalize != 0 && !reflect.DeepEqual(app.finalizedHeights, []int64{4}) {
		t.Fatal("wrong FinalizeBlock height")
	}
	expectedReason := c.WantReason
	if c.Mismatch {
		expectedReason = fmt.Sprintf("state.AppHash does not match AppHash after replay. Got\n%X, expected %X.\n\nState: %v\n\nDid you reset CometBFT without resetting your application's data?", appHash, loaded.AppHash, loaded)
	}
	// Only the exact AppHash omission's unexpected nil result is an admissible
	// mutant failure. All other mismatches are setup/behavior failures.
	if !(c.Mismatch && result.Kind == "success" && result.Reason == "" && result.PanicType == "") {
		if result.Kind != c.WantKind || result.Reason != expectedReason || (result.Kind == "panic" && result.PanicType != "string") {
			t.Fatalf("unexpected actual Handshake outcome: %+v", result)
		}
	}
	return observation
}

func TestHandshakeWorker(t *testing.T) {
	name, dir := os.Getenv("ETNA_HANDSHAKE_CASE"), os.Getenv("ETNA_HANDSHAKE_DIR")
	var selected *handshakeCase
	for i := range handshakeCases {
		if handshakeCases[i].Name == name {
			selected = &handshakeCases[i]
		}
	}
	if selected == nil {
		t.Fatal("missing explicit handshake worker case")
	}
	canonical, err := filepath.EvalSymlinks(dir)
	if err != nil || canonical != dir || !strings.HasPrefix(dir, "/tmp/output/handshake/") {
		t.Fatal("noncanonical handshake output binding")
	}
	observation := executeHandshakeCase(t, *selected, dir)
	receipt := handshakeEnvelope{Kind: "handshake", Name: name, Directory: dir, ParentPID: os.Getppid(), WorkerPID: os.Getpid(), Observation: observation}
	fd := os.NewFile(3, "handshake-receipt")
	defer fd.Close()
	if err := json.NewEncoder(fd).Encode(receipt); err != nil {
		t.Fatal(err)
	}
}
func startHandshakeWorker(t *testing.T, name, dir string) *ownedWorker {
	t.Helper()
	executable, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	cmd := exec.CommandContext(ctx, executable, "-test.run=^TestHandshakeWorker$", "-test.count=1", "-test.timeout=8s")
	cmd.Env = append(os.Environ(), "ETNA_HANDSHAKE_CASE="+name, "ETNA_HANDSHAKE_DIR="+dir)
	r, w, err := os.Pipe()
	if err != nil {
		cancel()
		t.Fatal(err)
	}
	worker := &ownedWorker{cmd: cmd, cancel: cancel, pipe: r}
	cmd.ExtraFiles = []*os.File{w}
	cmd.Stdout = &worker.output
	cmd.Stderr = &worker.output
	if err := cmd.Start(); err != nil {
		r.Close()
		w.Close()
		cancel()
		t.Fatal(err)
	}
	t.Cleanup(func() {
		cancel()
		r.Close()
		if !worker.waited {
			_ = cmd.Process.Kill()
			_ = worker.wait()
		}
	})
	if err := w.Close(); err != nil {
		t.Fatal(err)
	}
	return worker
}
func TestCheckpointHandshake(t *testing.T) {
	for _, c := range handshakeCases {
		t.Run(c.Name, func(t *testing.T) {
			dir := filepath.Join(os.Getenv("ETNA_RESTART_OUTPUT"), "handshake", c.Name)
			if err := os.MkdirAll(dir, 0700); err != nil {
				t.Fatal(err)
			}
			worker := startHandshakeWorker(t, c.Name, dir)
			raw, err := io.ReadAll(io.LimitReader(worker.pipe, (1<<20)+1))
			if err != nil {
				t.Fatal(err)
			}
			if len(raw) == 0 || len(raw) > 1<<20 {
				if len(raw) > 1<<20 {
					_ = worker.cmd.Process.Kill()
				}
				err := worker.wait()
				t.Fatalf("missing/oversized handshake receipt: %v; worker output %s", err, worker.output.String())
			}
			var receipt handshakeEnvelope
			decoder := json.NewDecoder(bytes.NewReader(raw))
			decoder.DisallowUnknownFields()
			if err := decoder.Decode(&receipt); err != nil {
				t.Fatal(err)
			}
			var extra any
			if err := decoder.Decode(&extra); err != io.EOF {
				t.Fatal("extra handshake receipt")
			}
			if err := worker.wait(); err != nil || worker.output.String() != "PASS\n" {
				t.Fatalf("handshake worker failed: %v %s", err, worker.output.String())
			}
			if receipt.Kind != "handshake" || receipt.Name != c.Name || receipt.Directory != dir || receipt.ParentPID != os.Getpid() || receipt.WorkerPID != worker.cmd.Process.Pid || receipt.WorkerPID == os.Getpid() {
				t.Fatal("wrong owned handshake worker receipt")
			}
			logReceipt(t, receipt)
			if c.Mismatch && receipt.Observation.Result.Kind == "success" {
				t.Errorf("missing-handshake-apphash-guard id=%s expected=panic got=success", c.Name)
			}
		})
	}
}
