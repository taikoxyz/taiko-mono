// Disk lifecycle only. The unmodified F04 bootstrap_test.go and literal mapping
// vectors are private build inputs; -run selects this parent, not F04's tests.
package bootstrap_test

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"strings"
	"syscall"
	"testing"
	"time"

	dbm "github.com/cometbft/cometbft-db"
	cmtstate "github.com/cometbft/cometbft/proto/tendermint/state"
	"github.com/cometbft/cometbft/state"
	"github.com/cometbft/cometbft/types"
)

type validatorObservation struct {
	Height            int64   `json:"height"`
	LastHeightChanged int64   `json:"lastHeightChanged"`
	Set               setView `json:"set"`
}
type diskObservation struct {
	State                   stateView              `json:"state"`
	Validators              []validatorObservation `json:"validators"`
	Params                  types.ConsensusParams  `json:"params"`
	ParamsHeight            int64                  `json:"paramsHeight"`
	ParamsLastHeightChanged int64                  `json:"paramsLastHeightChanged"`
	AbsentHistoricalHeight  int64                  `json:"absentHistoricalHeight"`
}
type restartReceipt struct {
	Kind               string           `json:"kind"`
	Name               string           `json:"name"`
	Case               string           `json:"case"`
	Mode               string           `json:"mode"`
	Directory          string           `json:"directory"`
	ParentPID          int              `json:"parentPID"`
	WriterPID          int              `json:"writerPID"`
	ReaderPID          int              `json:"readerPID"`
	BootstrapCompleted bool             `json:"bootstrapCompleted"`
	WriterStop         string           `json:"writerStop"`
	ReaderReopened     bool             `json:"readerReopened"`
	StatePresent       bool             `json:"statePresent"`
	MissingRows        []int64          `json:"missingRows"`
	ParamsPresent      bool             `json:"paramsPresent"`
	ValidatorRows      []int64          `json:"validatorRows"`
	ParamsRow          int64            `json:"paramsRow"`
	Observation        *diskObservation `json:"observation"`
}
type workerMessage struct {
	Kind               string          `json:"kind"`
	PID                int             `json:"pid"`
	Case               string          `json:"case"`
	Mode               string          `json:"mode"`
	Directory          string          `json:"directory"`
	BootstrapCompleted bool            `json:"bootstrapCompleted"`
	Closed             bool            `json:"closed"`
	Result             *restartReceipt `json:"result"`
}

func rowHeights(id string) ([]int64, int64) {
	if id == "origin-base" {
		return []int64{3, 4}, 3
	}
	if id == "current-base" {
		return []int64{4, 5, 6}, 5
	}
	panic("unexpected restart fixture")
}
func diskGet(t *testing.T, db dbm.DB, key string) []byte {
	t.Helper()
	raw, err := db.Get([]byte(key))
	if err != nil {
		t.Fatal(err)
	}
	return raw
}
func presenceProblem(t *testing.T, db dbm.DB, id string) string {
	t.Helper()
	if len(diskGet(t, db, "stateKey")) == 0 {
		return "missing-state"
	}
	rows, height := rowHeights(id)
	for _, h := range rows {
		if len(diskGet(t, db, fmt.Sprintf("validatorsKey:%d", h))) == 0 {
			return "missing-validator-history"
		}
	}
	if len(diskGet(t, db, fmt.Sprintf("consensusParamsKey:%d", height))) == 0 {
		return "missing-params"
	}
	return ""
}
func readDisk(t *testing.T, db dbm.DB, store state.Store, id string) *restartReceipt {
	t.Helper()
	rows, height := rowHeights(id)
	result := &restartReceipt{ValidatorRows: rows, ParamsRow: height, MissingRows: []int64{}}
	loaded, err := store.Load()
	if err != nil {
		t.Fatal(err)
	}
	result.StatePresent = len(diskGet(t, db, "stateKey")) != 0
	for _, h := range rows {
		if len(diskGet(t, db, fmt.Sprintf("validatorsKey:%d", h))) == 0 {
			result.MissingRows = append(result.MissingRows, h)
		}
	}
	result.ParamsPresent = len(diskGet(t, db, fmt.Sprintf("consensusParamsKey:%d", height))) != 0
	if !result.StatePresent && reflect.DeepEqual(result.MissingRows, rows) && !result.ParamsPresent {
		if !loaded.IsEmpty() {
			t.Fatal("absent raw state returned nonempty loaded state")
		}
		for _, h := range rows {
			set, err := store.LoadValidators(h)
			var missing state.ErrNoValSetForHeight
			if set != nil || !errors.As(err, &missing) || missing.Height != h {
				t.Fatalf("unexpected missing validator result height=%d err=%v", h, err)
			}
		}
		_, err := store.LoadConsensusParams(height)
		if err == nil || err.Error() != fmt.Sprintf("could not find consensus params for height #%d: value retrieved from db is empty", height) {
			t.Fatalf("unexpected missing params result: %v", err)
		}
		return result
	}
	if problem := presenceProblem(t, db, id); problem != "" {
		t.Fatal("partial Bootstrap data: " + problem)
	}
	// Reuse F04's independently literal field, raw row and getter observers.
	assertState(t, loaded, id)
	expected := expectedState(id)
	obs := &diskObservation{State: observeState(loaded), Validators: []validatorObservation{}, Params: literalParams(), ParamsHeight: height}
	for _, h := range rows {
		want := expected.Validators
		if h == height+1 {
			want = expected.Next
		}
		if h == height-1 {
			want = expected.Last
		}
		checkRow(t, db, store, h, want)
		var info cmtstate.ValidatorsInfo
		if err := info.Unmarshal(diskGet(t, db, fmt.Sprintf("validatorsKey:%d", h))); err != nil {
			t.Fatal(err)
		}
		vs, err := types.ValidatorSetFromProto(info.ValidatorSet)
		if err != nil {
			t.Fatal(err)
		}
		obs.Validators = append(obs.Validators, validatorObservation{h, info.LastHeightChanged, observeSet(vs)})
	}
	checkParams(t, db, store, height)
	var params cmtstate.ConsensusParamsInfo
	if err := params.Unmarshal(diskGet(t, db, fmt.Sprintf("consensusParamsKey:%d", height))); err != nil {
		t.Fatal(err)
	}
	obs.Params = types.ConsensusParamsFromProto(params.ConsensusParams)
	obs.ParamsLastHeightChanged = params.LastHeightChanged
	if id == "origin-base" {
		obs.AbsentHistoricalHeight = 2
		set, err := store.LoadValidators(2)
		var missing state.ErrNoValSetForHeight
		if set != nil || !errors.As(err, &missing) || missing.Height != 2 || len(diskGet(t, db, "validatorsKey:2")) != 0 {
			t.Fatal("origin historical row 2 must remain absent")
		}
	}
	result.Observation = obs
	return result
}

// Only the parent-selected -test.run invokes this helper in a distinct process.
// Its private receipt FD is independent of Go's stdout/test protocol.
func TestRestartWorker(t *testing.T) {
	role := os.Getenv("ETNA_RESTART_ROLE")
	if role == "" {
		t.Fatal("worker needs an explicit parent-owned role")
	}
	fd := os.NewFile(3, "receipt")
	if fd == nil {
		t.Fatal("missing private receipt descriptor")
	}
	defer fd.Close()
	if role == "no-ack" {
		return
	}
	if role == "failed-worker" {
		os.Exit(23)
	}
	id, mode, dir := os.Getenv("ETNA_RESTART_CASE"), os.Getenv("ETNA_RESTART_MODE"), os.Getenv("ETNA_RESTART_DIR")
	msg := workerMessage{Kind: role, PID: os.Getpid(), Case: id, Mode: mode, Directory: dir}
	if role == "wrong-child" {
		msg.PID++
		if err := json.NewEncoder(fd).Encode(msg); err != nil {
			t.Fatal(err)
		}
		return
	}
	// Each reader independently opens and validates the same frozen F03 bytes.
	cases := loadCases(t)
	c, ok := cases[id]
	if !ok {
		t.Fatal("missing frozen restart case")
	}
	if err := auditReceipt(c); err != nil {
		t.Fatal(err)
	}
	canonical, err := filepath.EvalSymlinks(dir)
	if err != nil || canonical != dir || !strings.HasPrefix(dir, "/tmp/output/databases/") {
		t.Fatal("database directory is not the parent's canonical output binding")
	}
	db, err := dbm.NewGoLevelDB("state", dir)
	if err != nil {
		t.Fatal(err)
	}
	store := state.NewStore(db, state.StoreOptions{})
	if role == "writer" {
		s := adaptState(c)
		assertState(t, s, id)
		if err := s.Validators.ValidateBasic(); err != nil {
			t.Fatal(err)
		}
		if err := s.NextValidators.ValidateBasic(); err != nil {
			t.Fatal(err)
		}
		if err := s.ConsensusParams.ValidateBasic(); err != nil {
			t.Fatal(err)
		}
		if err := store.Bootstrap(s); err != nil {
			t.Fatal(err)
		}
		msg.BootstrapCompleted = true
		if mode == "clean-close" {
			if err := store.Close(); err != nil {
				t.Fatal(err)
			}
			msg.Closed = true
		} else if mode != "kill-after-ack" {
			t.Fatal("unknown writer mode")
		}
		if err := json.NewEncoder(fd).Encode(msg); err != nil {
			t.Fatal(err)
		}
		if err := fd.Close(); err != nil {
			t.Fatal(err)
		}
		if mode == "kill-after-ack" {
			for {
				time.Sleep(time.Hour)
			}
		}
	} else if role == "reader" {
		msg.Result = readDisk(t, db, store, id)
		if err := store.Close(); err != nil {
			t.Fatal(err)
		}
		msg.Closed = true
		if err := json.NewEncoder(fd).Encode(msg); err != nil {
			t.Fatal(err)
		}
	} else {
		t.Fatal("unknown worker role")
	}
}

type ownedWorker struct {
	cmd    *exec.Cmd
	cancel context.CancelFunc
	pipe   *os.File
	output bytes.Buffer
	waited bool
}

func startWorker(t *testing.T, role, id, mode, dir string) *ownedWorker {
	t.Helper()
	executable, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	cmd := exec.CommandContext(ctx, executable, "-test.run=^TestRestartWorker$", "-test.count=1", "-test.timeout=8s")
	cmd.Env = append(os.Environ(), "ETNA_RESTART_ROLE="+role, "ETNA_RESTART_CASE="+id, "ETNA_RESTART_MODE="+mode, "ETNA_RESTART_DIR="+dir)
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
	if err := w.Close(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		cancel()
		r.Close()
		if !worker.waited {
			_ = cmd.Process.Kill()
			_ = cmd.Wait()
			worker.waited = true
		}
	})
	return worker
}
func (w *ownedWorker) wait() error { err := w.cmd.Wait(); w.waited = true; return err }
func (w *ownedWorker) message() (workerMessage, error) {
	var message workerMessage
	raw, err := io.ReadAll(io.LimitReader(w.pipe, (1<<20)+1))
	if err != nil {
		return message, err
	}
	if len(raw) == 0 {
		return message, fmt.Errorf("no-ack")
	}
	if len(raw) > 1<<20 {
		return message, fmt.Errorf("oversized worker receipt")
	}
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&message); err != nil {
		return message, err
	}
	var extra any
	if err := decoder.Decode(&extra); err != io.EOF {
		return message, fmt.Errorf("extra worker receipt")
	}
	if message.PID != w.cmd.Process.Pid {
		return message, fmt.Errorf("wrong-child")
	}
	return message, nil
}
func logReceipt(t *testing.T, v any) {
	t.Helper()
	raw, err := json.Marshal(v)
	if err != nil {
		t.Fatal(err)
	}
	t.Log("receipt=" + string(raw))
}
func runPersistence(t *testing.T, name, id, mode string) {
	dir := filepath.Join(os.Getenv("ETNA_RESTART_OUTPUT"), "databases", name)
	if err := os.MkdirAll(dir, 0700); err != nil {
		t.Fatal(err)
	}
	canonical, err := filepath.EvalSymlinks(dir)
	if err != nil || canonical != dir {
		t.Fatal("noncanonical database output")
	}
	writer := startWorker(t, "writer", id, mode, dir)
	ack, err := writer.message()
	if err != nil {
		t.Fatalf("writer readiness: %v", err)
	}
	if ack.Kind != "writer" || ack.Case != id || ack.Mode != mode || ack.Directory != dir || !ack.BootstrapCompleted || ack.Result != nil || ack.Closed != (mode == "clean-close") {
		t.Fatal("writer receipt binding mismatch")
	}
	stop := "closed"
	if mode == "kill-after-ack" {
		// The owned process handle is the only signal target. No ACK-provided PID
		// is used as a process selector; Go's handle remains held until Wait.
		if err := writer.cmd.Process.Kill(); err != nil {
			t.Fatal(err)
		}
		err := writer.wait()
		var exited *exec.ExitError
		if !errors.As(err, &exited) {
			t.Fatalf("writer not killed: %v", err)
		}
		status, ok := exited.Sys().(syscall.WaitStatus)
		if !ok || !status.Signaled() || status.Signal() != syscall.SIGKILL {
			t.Fatalf("wrong writer termination: %v", err)
		}
		if writer.output.Len() != 0 {
			t.Fatalf("writer extra output: %s", writer.output.String())
		}
		stop = "SIGKILL"
	} else {
		if err := writer.wait(); err != nil || writer.output.String() != "PASS\n" {
			t.Fatalf("clean writer failed: %v %s", err, writer.output.String())
		}
	}
	// A genuinely separate process opens the SAME directory after writer Wait.
	reader := startWorker(t, "reader", id, mode, dir)
	read, err := reader.message()
	if err != nil {
		t.Fatalf("reader receipt: %v", err)
	}
	if err := reader.wait(); err != nil || reader.output.String() != "PASS\n" {
		t.Fatalf("reader failed: %v %s", err, reader.output.String())
	}
	if read.Kind != "reader" || read.PID == ack.PID || read.PID == os.Getpid() || read.Case != id || read.Mode != mode || read.Directory != dir || !read.Closed || read.BootstrapCompleted || read.Result == nil {
		t.Fatal("reader receipt binding mismatch")
	}
	result := read.Result
	result.Kind = "persistence"
	result.Name = name
	result.Case = id
	result.Mode = mode
	result.Directory = dir
	result.ParentPID = os.Getpid()
	result.WriterPID = ack.PID
	result.ReaderPID = read.PID
	result.BootstrapCompleted = true
	result.WriterStop = stop
	result.ReaderReopened = true
	logReceipt(t, result)
	if !result.StatePresent {
		heights, params := rowHeights(id)
		formatted := []string{}
		for _, h := range heights {
			formatted = append(formatted, fmt.Sprint(h))
		}
		t.Errorf("missing-bootstrap-batch id=%s state=absent validators=%s params=%d", id, strings.Join(formatted, ","), params)
	}
}
func runReadinessControl(t *testing.T, name string) {
	role := map[string]string{"readiness-no-ack": "no-ack", "readiness-wrong-child": "wrong-child", "readiness-failed-worker": "failed-worker"}[name]
	worker := startWorker(t, role, "current-base", "kill-after-ack", "/tmp/output/databases/unused-control")
	_, problem := worker.message()
	waited := worker.wait()
	reason := ""
	if role == "failed-worker" {
		var exit *exec.ExitError
		if problem == nil || problem.Error() != "no-ack" || !errors.As(waited, &exit) || exit.ExitCode() != 23 || worker.output.Len() != 0 {
			t.Fatalf("failed worker was not refused: %v %v", problem, waited)
		}
		reason = "worker-failed"
	} else {
		if problem == nil || problem.Error() != role || waited != nil || worker.output.String() != "PASS\n" {
			t.Fatalf("readiness control not refused: %v %v %s", problem, waited, worker.output.String())
		}
		reason = role
	}
	logReceipt(t, map[string]any{"kind": "readiness", "name": name, "reason": reason, "readerStarted": false, "ownedChildReaped": true})
}
func runObserverControls(t *testing.T) {
	dir := filepath.Join(os.Getenv("ETNA_RESTART_OUTPUT"), "observer-controls")
	if err := os.Mkdir(dir, 0700); err != nil {
		t.Fatal(err)
	}
	db, err := dbm.NewGoLevelDB("state", dir)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	// Independent test-only raw-row seeding keeps these observer controls live
	// under the upstream Bootstrap omission too. It is not Bootstrap evidence.
	s := adaptState(loadCases(t)["current-base"])
	want := expectedState("current-base")
	if err := db.SetSync([]byte("stateKey"), s.Bytes()); err != nil {
		t.Fatal(err)
	}
	for _, item := range []struct {
		h  int64
		vs *types.ValidatorSet
	}{{4, s.LastValidators}, {5, s.Validators}, {6, s.NextValidators}} {
		proto, err := item.vs.ToProto()
		if err != nil {
			t.Fatal(err)
		}
		info := cmtstate.ValidatorsInfo{LastHeightChanged: item.h, ValidatorSet: proto}
		raw, err := info.Marshal()
		if err != nil {
			t.Fatal(err)
		}
		if err := db.SetSync([]byte(fmt.Sprintf("validatorsKey:%d", item.h)), raw); err != nil {
			t.Fatal(err)
		}
	}
	param := cmtstate.ConsensusParamsInfo{LastHeightChanged: 5, ConsensusParams: s.ConsensusParams.ToProto()}
	raw, err := param.Marshal()
	if err != nil {
		t.Fatal(err)
	}
	if err := db.SetSync([]byte("consensusParamsKey:5"), raw); err != nil {
		t.Fatal(err)
	}
	if p := presenceProblem(t, db, "current-base"); p != "" {
		t.Fatal(p)
	}
	stateRaw := diskGet(t, db, "stateKey")
	if err := db.DeleteSync([]byte("stateKey")); err != nil {
		t.Fatal(err)
	}
	if p := presenceProblem(t, db, "current-base"); p != "missing-state" {
		t.Fatal("missing state control: " + p)
	}
	if err := db.SetSync([]byte("stateKey"), stateRaw); err != nil {
		t.Fatal(err)
	}
	if err := db.DeleteSync([]byte("validatorsKey:4")); err != nil {
		t.Fatal(err)
	}
	if p := presenceProblem(t, db, "current-base"); p != "missing-validator-history" {
		t.Fatal("missing history control: " + p)
	}
	changed := s.Copy()
	changed.InitialHeight++
	if p := firstDifference(observeState(changed), want); p != "InitialHeight" {
		t.Fatal("state observer control: " + p)
	}
	changed = s.Copy()
	changed.LastValidators.Validators[0].ProposerPriority++
	if p := firstDifference(observeSet(changed.LastValidators), want.Last); p != "Members[0].Priority" {
		t.Fatal("validator observer control: " + p)
	}
	logReceipt(t, map[string]any{"kind": "observer-controls", "name": "observer-controls", "detected": []string{"missing-state", "missing-validator-history", "wrong-state-field", "wrong-validator-priority"}})
}
func TestCheckpointRestart(t *testing.T) {
	for _, item := range []struct{ name, id, mode string }{
		{"origin-clean-close", "origin-base", "clean-close"}, {"current-clean-close", "current-base", "clean-close"},
		{"origin-kill-after-ack", "origin-base", "kill-after-ack"}, {"current-kill-after-ack", "current-base", "kill-after-ack"},
	} {
		t.Run(item.name, func(t *testing.T) { runPersistence(t, item.name, item.id, item.mode) })
	}
	for _, name := range []string{"readiness-no-ack", "readiness-wrong-child", "readiness-failed-worker"} {
		t.Run(name, func(t *testing.T) { runReadinessControl(t, name) })
	}
	t.Run("observer-controls", runObserverControls)
}
