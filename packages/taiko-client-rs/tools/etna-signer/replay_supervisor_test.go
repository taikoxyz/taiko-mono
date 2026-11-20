package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"

	dbm "github.com/cometbft/cometbft-db"
	cs "github.com/cometbft/cometbft/consensus"
	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
	sm "github.com/cometbft/cometbft/state"
	"github.com/cometbft/cometbft/store"
	"github.com/cometbft/cometbft/types"
)

// stoppedComet writes a stopped node's stock stores into data: the committed state at height and
// its block, whose hash it returns, and a stock WAL ending with `#ENDHEIGHT height` and a
// round-state record of the next height.
func stoppedComet(t *testing.T, data string, height int64) []byte {
	t.Helper()
	key := secp256k1eth.GenPrivKey()
	genesis := &types.GenesisDoc{ChainID: chain, InitialHeight: 1, GenesisTime: time.Unix(1, 0),
		ConsensusParams: types.DefaultConsensusParams(), Validators: []types.GenesisValidator{{PubKey: key.PubKey(), Power: 10}}}
	genesis.ConsensusParams.Validator.PubKeyTypes = []string{secp256k1eth.KeyType}
	if err := genesis.ValidateAndComplete(); err != nil {
		t.Fatal(err)
	}
	state, err := sm.MakeGenesisState(genesis)
	if err != nil {
		t.Fatal(err)
	}
	state.LastBlockHeight, state.LastValidators = height, state.Validators.Copy()
	block, err := state.MakeBlock(height, nil, &types.Commit{Height: height - 1}, nil, state.Validators.Proposer.Address)
	if err != nil {
		t.Fatal(err)
	}
	parts, err := block.MakePartSet(types.BlockPartSizeBytes)
	if err != nil {
		t.Fatal(err)
	}
	blockDB, err := dbm.NewGoLevelDB("blockstore", data)
	if err != nil {
		t.Fatal(err)
	}
	store.NewBlockStore(blockDB).SaveBlock(block, parts, &types.Commit{Height: height, BlockID: types.BlockID{Hash: block.Hash(), PartSetHeader: parts.Header()}})
	blockDB.Close()
	stateDB, err := dbm.NewGoLevelDB("state", data)
	if err != nil {
		t.Fatal(err)
	}
	if err = sm.NewStore(stateDB, sm.StoreOptions{}).Save(state); err != nil {
		t.Fatal(err)
	}
	stateDB.Close()
	wal, err := cs.NewWAL(filepath.Join(data, "cs.wal", "wal"))
	if err != nil {
		t.Fatal(err)
	}
	if err = wal.Start(); err != nil {
		t.Fatal(err)
	}
	for _, message := range []cs.WALMessage{types.EventDataRoundState{Height: height, Step: "RoundStepCommit"}, cs.EndHeightMessage{Height: height}, types.EventDataRoundState{Height: height + 1, Step: "RoundStepPrevote"}} {
		if err = wal.WriteSync(message); err != nil {
			t.Fatal(err)
		}
	}
	if err = wal.Stop(); err != nil {
		t.Fatal(err)
	}
	wal.Wait()
	return block.Hash()
}

// RECOV-8.2-2 end to end with the real supervisor, signer, stock WAL and stores, and a Comet
// stand-in that writes stock JSON consensus records to the supervisor's log pipe:
//  1. A live prevote at H5 records the binding the supervisor computed: #ENDHEIGHT 4, the bytes
//     after it and block 4's hash from the stopped stores.
//  2. After a signer crash the supervisor restarts the pair; its startup check verifies the
//     binding and pins the startup prefix. The observer sees the replay of H5 open: the prevote's
//     timestamp-only retry returns the saved signature and timestamp (13.e) and confirms it, and
//     the precommit is signed during the replay, bound to the startup prefix (2.k, 12.a).
//  3. After another crash, stock falls through on a replay error: the saved precommit requested
//     again live cannot confirm, and the signer persists the floor 6 (2.j).
func TestSupervisedSameHeightReplay(t *testing.T) {
	python, err := exec.LookPath("python3")
	if err != nil {
		t.Fatal(err)
	}
	binary := signerBinary(t)
	_, key, state := filePV(t)
	controlPath := control(t, func(request map[string]any) any { return snapshotAt(request["op"] != "begin_session", 5) })
	root := shortTemp(t)
	home, store := filepath.Join(root, "comet"), filepath.Join(root, "app")
	for _, path := range []string{filepath.Join(home, "config"), filepath.Join(home, "data"), store} {
		if err := os.MkdirAll(path, 0700); err != nil {
			t.Fatal(err)
		}
	}
	block4 := stoppedComet(t, filepath.Join(home, "data"), 4)
	if err := os.Symlink(controlPath, filepath.Join(store, "checkpoint-trust.sock")); err != nil {
		t.Fatal(err)
	}
	listener, laddr, transportKey := noiseComet(t, home, root)
	config := append([]byte("log_format = \"json\"\n"), validatorConfig(laddr)...)
	if err := os.WriteFile(filepath.Join(home, "config", "config.toml"), config, 0600); err != nil {
		t.Fatal(err)
	}
	genesis, _ := json.Marshal(map[string]any{"chain_id": chain})
	if err := os.WriteFile(filepath.Join(home, "config", "genesis.json"), genesis, 0600); err != nil {
		t.Fatal(err)
	}
	// Comet start n writes the lines of <root>/log.<n> to its stdout as they appear.
	starts := filepath.Join(root, "comet-starts")
	stand := `import os,time
p=os.environ['COMET_STARTS']
open(p,'a').write('start\n')
n=len(open(p).read().split())
log=os.path.join(os.path.dirname(p),'log.%d'%n)
done=0
while True:
    lines=open(log).read().splitlines() if os.path.exists(log) else []
    for line in lines[done:]:
        print(line, flush=True)
    done=len(lines)
    time.sleep(.02)
`
	cometCommand, _ := json.Marshal([]string{python, "-c", stand})
	pids := filepath.Join(root, "signer-pids")
	signerCommand, _ := json.Marshal([]string{"/bin/sh", "-c", `echo $$ >> "$SIGNER_PIDS"; exec "$0" "$@"`, binary})
	environment := supervisorEnvironment(home, store, key, state, "ETNA_SIGNER_COMMAND_JSON="+string(signerCommand),
		"ETNA_SIGNER_BIN="+binary, "ETNA_COMET_COMMAND_JSON="+string(cometCommand), "COMET_STARTS="+starts,
		"SIGNER_PIDS="+pids, transportKey, cometManifest(t, root, python))
	logs, err := os.Create(filepath.Join(root, "supervisor.log"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		logs.Close()
		if t.Failed() {
			contents, _ := os.ReadFile(logs.Name())
			t.Logf("supervisor output: %s", contents)
		}
	})
	consensusLog := func(start int, records ...map[string]any) {
		t.Helper()
		f, err := os.OpenFile(filepath.Join(root, fmt.Sprintf("log.%d", start)), os.O_WRONLY|os.O_CREATE|os.O_APPEND, 0600)
		if err != nil {
			t.Fatal(err)
		}
		defer f.Close()
		for _, record := range records {
			record["module"], record["level"] = "consensus", "info"
			raw, _ := json.Marshal(record)
			f.Write(append(raw, '\n'))
		}
	}
	supervisor := exec.Command(python, "../../script/etna_validator.py")
	supervisor.Env, supervisor.Stdout, supervisor.Stderr = environment, logs, logs
	if err := supervisor.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { stopTestProcess(t, supervisor) })
	lines := func(path string) []string {
		raw, _ := os.ReadFile(path)
		return strings.Fields(string(raw))
	}
	waitFor := func(description string, condition func() bool) {
		t.Helper()
		deadline := time.Now().Add(10 * time.Second)
		for !condition() && time.Now().Before(deadline) {
			time.Sleep(20 * time.Millisecond)
		}
		if !condition() {
			t.Fatal(description)
		}
	}
	crash := func(pairs int) {
		t.Helper()
		pid, err := strconv.Atoi(lines(pids)[pairs-1])
		if err != nil {
			t.Fatal(err)
		}
		if err := syscall.Kill(pid, syscall.SIGKILL); err != nil {
			t.Fatal(err)
		}
		waitFor("the supervisor did not restart the pair", func() bool { return len(lines(pids)) == pairs+1 && len(lines(starts)) == pairs+1 })
	}
	signed := func(raw []byte) map[string]json.RawMessage {
		var fields map[string]json.RawMessage
		if err := json.Unmarshal(raw, &fields); err != nil {
			t.Fatal(err)
		}
		return fields
	}
	replayOf := func() map[string]any {
		var replay map[string]any
		if err := json.Unmarshal(signed(readFile(t, state))["replay"], &replay); err != nil {
			t.Fatal(err)
		}
		return replay
	}

	// 1. A live prevote records its binding.
	conn := acceptSigner(t, listener)
	sigA, remote := released(signerExchange(t, conn, heightVote(tm.PrevoteType, 5, 1)))
	if remote != nil || len(sigA) != 65 {
		t.Fatalf("live prevote: %v", remote)
	}
	live := replayOf()
	if live == nil || live["marker"] != "4" || !strings.EqualFold(live["predecessor"].(string), fmt.Sprintf("%X", block4)) {
		t.Fatalf("live binding: %v", live)
	}

	// Round-state records written after the signature extend the WAL past the bound prefix.
	wal, err := cs.NewWAL(filepath.Join(home, "data", "cs.wal", "wal"))
	if err != nil {
		t.Fatal(err)
	}
	if err = wal.Start(); err != nil {
		t.Fatal(err)
	}
	if err = wal.WriteSync(types.EventDataRoundState{Height: 5, Step: "RoundStepPrevoteWait"}); err != nil {
		t.Fatal(err)
	}
	if err = wal.Stop(); err != nil {
		t.Fatal(err)
	}
	wal.Wait()

	// 2. A crash, then an eligible replay confirms the prevote and signs the precommit.
	consensusLog(2, map[string]any{"_msg": "Catchup by replaying consensus messages", "height": 5})
	crash(1)
	waitFor("no eligible preflight", func() bool {
		contents, _ := os.ReadFile(logs.Name())
		return bytes.Contains(contents, []byte("etna_supervisor_replay_preflight: height 5 eligible"))
	})
	conn = acceptSigner(t, listener)
	retry := heightVote(tm.PrevoteType, 5, 1)
	retry.GetSignVoteRequest().Vote.Timestamp = time.Unix(500, 0)
	reply := signerExchange(t, conn, retry)
	response := reply.GetSignedVoteResponse()
	if response == nil || response.Error != nil || !bytes.Equal(response.Vote.Signature, sigA) || !response.Vote.Timestamp.Equal(time.Unix(100, 0)) {
		t.Fatalf("the replayed prevote did not get the saved signature and timestamp: %v", response)
	}
	if signature, remote := released(signerExchange(t, conn, heightVote(tm.PrecommitType, 5, 1))); remote != nil || len(signature) == 0 {
		t.Fatalf("the replayed precommit was refused: %v", remote)
	}
	startup := replayOf()
	liveLength, _ := strconv.Atoi(live["wal_length"].(string))
	startupLength, _ := strconv.Atoi(startup["wal_length"].(string))
	if startup["marker"] != "4" || startup["predecessor"] != live["predecessor"] || startupLength <= liveLength {
		t.Fatalf("the replayed precommit is not bound to the pinned startup prefix: %v (live %v)", startup, live)
	}
	if fields := signed(readFile(t, state)); string(fields["step"]) != "3" || string(fields["floor"]) != `"0"` {
		t.Fatalf("after the replay: step %s floor %s", fields["step"], fields["floor"])
	}
	consensusLog(2, map[string]any{"_msg": "Replay: Done"})

	// 3. After another crash, stock falls through on a replay error.
	consensusLog(3, map[string]any{"_msg": "error on catchup replay; proceeding to start state anyway", "err": "boom"})
	crash(2)
	conn = acceptSigner(t, listener)
	time.Sleep(200 * time.Millisecond)
	if signature, remote := released(signerExchange(t, conn, heightVote(tm.PrecommitType, 5, 1))); remote == nil || len(signature) != 0 || !strings.Contains(remote.Description, "durable floor") {
		t.Fatalf("a live repeat after a replay error was not fenced: %v", remote)
	}
	if fields := signed(readFile(t, state)); string(fields["floor"]) != `"6"` {
		t.Fatalf("floor %s", fields["floor"])
	}
}
