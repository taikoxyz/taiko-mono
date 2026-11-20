package boundary

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"testing"
	"time"

	dbm "github.com/cometbft/cometbft-db"
	cfg "github.com/cometbft/cometbft/config"
	"github.com/cometbft/cometbft/consensus"
	"github.com/cometbft/cometbft/libs/log"
	sm "github.com/cometbft/cometbft/state"
	"github.com/cometbft/cometbft/store"
	cmt "github.com/cometbft/cometbft/types"
)

var terminalCases = []string{"terminal-a", "terminal-b", "missing-commit", "subthreshold", "wrong-domain", "wrong-slot"}

type countingEvidence struct {
	sm.EmptyEvidencePool
	checks int
}

func (e *countingEvidence) CheckEvidence(items cmt.EvidenceList) error {
	e.checks++
	if len(items) != 0 {
		return fmt.Errorf("unexpected evidence in terminal fixture")
	}
	return nil
}
func databaseRows(t *testing.T, db dbm.DB) map[string]string {
	t.Helper()
	it, err := db.Iterator(nil, nil)
	need(t, err == nil, "database iterator: %v", err)
	defer func() { need(t, it.Close() == nil, "close database iterator") }()
	rows := make(map[string]string)
	for ; it.Valid(); it.Next() {
		rows[hx(it.Key())] = hx(it.Value())
	}
	need(t, it.Error() == nil, "database iteration failed")
	return rows
}
func makeTerminalCommit(t *testing.T, s publicSetup, rowName string, vals *cmt.ValidatorSet, wrongSlot bool) *cmt.Commit {
	t.Helper()
	index, validator := vals.GetByAddress(s.signer.Address())
	need(t, validator != nil && index == 0, "actual public signer ordinal")
	vote := s.vote(t, rowName, index)
	sigs := make([]cmt.CommitSig, vals.Size())
	for i := range sigs {
		sigs[i] = cmt.NewCommitSigAbsent()
	}
	at := index
	if wrongSlot {
		at = 1
	}
	sigs[at] = vote.CommitSig()
	commit := &cmt.Commit{Height: vote.Height, Round: vote.Round, BlockID: vote.BlockID, Signatures: sigs}
	need(t, commit.ValidateBasic() == nil, "published commit shape")
	return commit
}
func terminalState(t *testing.T, s publicSetup, vals *cmt.ValidatorSet, chain string) sm.State {
	t.Helper()
	params := *cmt.DefaultConsensusParams()
	params.Validator.PubKeyTypes = []string{s.signer.Type()}
	params.Version.App = 17
	params.ABCI.VoteExtensionsEnableHeight = 0
	need(t, params.ValidateBasic() == nil && !params.ABCI.VoteExtensionsEnabled(1000) && !params.ABCI.VoteExtensionsEnabled(1001), "valid non-extension parameters")
	version := sm.InitStateVersion
	version.Consensus.App = params.Version.App
	return sm.State{Version: version, ChainID: chain, InitialHeight: 1, LastBlockHeight: 1000,
		LastBlockID: s.vote(t, "precommit_a", 0).BlockID, LastBlockTime: time.Unix(1699999999, 0).UTC(),
		LastValidators: vals.Copy(), Validators: vals.Copy(), NextValidators: vals.Copy(),
		LastHeightValidatorsChanged: 1001, ConsensusParams: params, LastHeightConsensusParamsChanged: 1001,
		AppHash: bytes.Repeat([]byte{0x10}, 32), LastResultsHash: bytes.Repeat([]byte{0x20}, 32)}
}
func verification(err error) observation {
	result, reason, kind := "accept", "", ""
	var got, needed int64
	if err != nil {
		reason, kind = err.Error(), fmt.Sprintf("%T", err)
		var insufficient cmt.ErrNotEnoughVotingPowerSigned
		switch {
		case errors.As(err, &insufficient):
			result, got, needed = "insufficient-power", insufficient.Got, insufficient.Needed
		case strings.HasPrefix(reason, "invalid commit -- wrong block ID: "):
			result = "block-id"
		case strings.HasPrefix(reason, "wrong signature (#"):
			result = "signature"
		case strings.HasPrefix(reason, "validator address mismatch at index "):
			result = "address"
		default:
			result = "unrecognized"
		}
	}
	return observation{"result": result, "reason": reason, "errorType": kind, "got": got, "needed": needed}
}
func constructorContext(t *testing.T, s publicSetup, state sm.State, seen, fallback *cmt.Commit) observation {
	t.Helper()
	index, val := state.LastValidators.GetByAddress(s.signer.Address())
	need(t, val != nil, "constructor signer membership")
	signatureIndex, signed := int32(-1), int64(0)
	if seen != nil {
		for i, sig := range seen.Signatures {
			if sig.BlockIDFlag == cmt.BlockIDFlagCommit {
				_, signer := state.LastValidators.GetByAddress(sig.ValidatorAddress)
				need(t, signer != nil, "known supplied signature address")
				signed += signer.VotingPower
				if bytes.Equal(sig.ValidatorAddress, s.signer.Address()) {
					signatureIndex = int32(i)
				}
			}
		}
	}
	return observation{"api": "consensus.NewState", "accepted": false, "panicType": "", "panicReason": "", "wrappedError": "",
		"verificationChain": state.ChainID, "signerIndex": index, "signatureIndex": signatureIndex,
		"seenPresent": seen != nil, "fallbackPresent": fallback != nil, "signedPower": signed, "totalPower": state.LastValidators.TotalVotingPower()}
}

// Only this exact API call is covered by recovery. Setup, conversion and validation are outside it.
func callConstructor(state sm.State, executor *sm.BlockExecutor, blocks *store.BlockStore, ev *countingEvidence, context observation) (cs *consensus.State) {
	defer func() {
		if value := recover(); value != nil {
			context["accepted"] = false
			context["panicType"] = fmt.Sprintf("%T", value)
			context["panicReason"] = fmt.Sprint(value)
			if err, ok := value.(error); ok {
				switch {
				case errors.Is(err, cmt.ErrVoteInvalidSignature):
					context["wrappedError"] = "types.ErrVoteInvalidSignature"
				case errors.Is(err, cmt.ErrVoteInvalidValidatorAddress):
					context["wrappedError"] = "types.ErrVoteInvalidValidatorAddress"
				case errors.Is(err, cmt.ErrVoteInvalidValidatorIndex):
					context["wrappedError"] = "types.ErrVoteInvalidValidatorIndex"
				}
			}
		}
	}()
	cs = consensus.NewState(cfg.DefaultConsensusConfig(), state.Copy(), executor, blocks, nil, ev)
	context["accepted"] = true
	return cs
}
func expectedConstructor(t *testing.T, s publicSetup, name string, state sm.State) (string, string, string) {
	t.Helper()
	switch name {
	case "terminal-a", "terminal-b":
		return "", "", ""
	case "missing-commit":
		return "string", "failed to reconstruct last commit; commit for height 1000 not found", ""
	case "subthreshold":
		return "string", "failed to reconstruct last commit; extended commit does not have +2/3 majority", ""
	case "wrong-domain":
		return "*fmt.wrapError", fmt.Sprintf("failed to reconstruct vote set from commit: failed to verify vote with ChainID %s and PubKey %v: invalid signature", s.rows["gen1_precommit_a"].ChainID, s.signer), "types.ErrVoteInvalidSignature"
	case "wrong-slot":
		address, _ := state.LastValidators.GetByIndex(1)
		return "*fmt.wrapError", fmt.Sprintf("failed to reconstruct vote set from commit: vote.ValidatorAddress (%X) does not match address (%X) for vote.ValidatorIndex (1)\nEnsure the genesis file is correct across all validators: invalid validator address", s.signer.Address(), address), "types.ErrVoteInvalidValidatorAddress"
	}
	t.Fatalf("unrecognized constructor case")
	return "", "", ""
}
func terminalCase(t *testing.T, s publicSetup, name string, used map[string]bool) {
	path := t.TempDir()
	need(t, !used[path], "store directory reused across branches")
	used[path] = true
	power, rowName, chain := int64(3), "precommit_a", s.rows["precommit_a"].ChainID
	if name == "subthreshold" {
		power = 2
	}
	if name == "terminal-b" {
		rowName = "precommit_b"
	}
	if name == "wrong-domain" {
		chain = s.rows["gen1_precommit_a"].ChainID
	}
	vals := s.validators(t, power)
	state := terminalState(t, s, vals, chain)
	var selected *cmt.Commit
	if name != "missing-commit" {
		selected = makeTerminalCommit(t, s, rowName, vals, name == "wrong-slot")
	}
	var initialVerify any
	if name == "terminal-a" || name == "terminal-b" {
		err := vals.VerifyCommit(s.rows[rowName].ChainID, selected.BlockID, 1000, selected)
		need(t, err == nil, "genuine public own-target commit verification before storing: %v", err)
		initialVerify = observation{"chain": s.rows[rowName].ChainID, "target": blockID(selected.BlockID), "height": int64(1000), "verification": verification(err)}
	}
	var stateDB, blockDB dbm.DB
	defer func() {
		var stateErr, blockErr error
		if stateDB != nil {
			stateErr = stateDB.Close()
		}
		if blockDB != nil {
			blockErr = blockDB.Close()
		}
		need(t, stateErr == nil && blockErr == nil, "close remaining store handles: %v / %v", stateErr, blockErr)
	}()
	stateDB, err := dbm.NewDB("state", dbm.GoLevelDBBackend, path)
	need(t, err == nil, "open writer stateDB: %v", err)
	blockDB, err = dbm.NewDB("block", dbm.GoLevelDBBackend, path)
	need(t, err == nil, "open writer blockDB: %v", err)
	stateStore := sm.NewStore(stateDB, sm.StoreOptions{})
	blocks := store.NewBlockStore(blockDB)
	need(t, stateStore.Bootstrap(state) == nil, "bootstrap state")
	if selected != nil {
		need(t, blocks.SaveSeenCommit(1000, selected) == nil, "save selected seen commit")
	}
	writerState, writerBlocks := databaseRows(t, stateDB), databaseRows(t, blockDB)
	stateErr, blockErr := stateDB.Close(), blocks.Close()
	stateDB, blockDB = nil, nil
	need(t, stateErr == nil && blockErr == nil, "close both writers: %v / %v", stateErr, blockErr)
	stateDB, err = dbm.NewDB("state", dbm.GoLevelDBBackend, path)
	need(t, err == nil, "reopen stateDB: %v", err)
	blockDB, err = dbm.NewDB("block", dbm.GoLevelDBBackend, path)
	need(t, err == nil, "reopen blockDB: %v", err)
	stateStore = sm.NewStore(stateDB, sm.StoreOptions{})
	blocks = store.NewBlockStore(blockDB)
	loaded, err := stateStore.Load()
	need(t, err == nil && loaded.Equals(state), "actual reopened state differs")
	seen, fallback := blocks.LoadSeenCommit(1000), blocks.LoadBlockCommit(1000)
	need(t, (seen == nil) == (selected == nil) && fallback == nil, "actual reopened commit presence")
	if selected != nil {
		before, _ := selected.ToProto().Marshal()
		after, _ := seen.ToProto().Marshal()
		need(t, bytes.Equal(before, after), "actual reopened seen commit bytes")
	}
	storedValidators := make([]observation, 0, 3)
	for _, height := range []int64{1000, 1001, 1002} {
		set, err := stateStore.LoadValidators(height)
		need(t, err == nil, "actual reopened validators %d: %v", height, err)
		storedValidators = append(storedValidators, observation{"height": height, "set": setView(t, set)})
	}
	ev := &countingEvidence{}
	executor := sm.NewBlockExecutor(stateStore, log.NewNopLogger(), nil, nil, ev, blocks)
	context := constructorContext(t, s, loaded, seen, fallback)
	cs := callConstructor(loaded, executor, blocks, ev, context)
	need(t, (cs != nil) == context["accepted"].(bool), "constructor pointer and acceptance disagree")
	wantType, wantReason, wantWrapped := expectedConstructor(t, s, name, loaded)
	result := observation{"schema": "etna-terminal-receipt-1", "case": name, "publicInputSha256": s.digest,
		"initialVerify": initialVerify, "stateProto": hx(loaded.Bytes()), "stateParent": blockID(loaded.LastBlockID), "stateHeight": loaded.LastBlockHeight,
		"initialHeight": loaded.InitialHeight, "stateChain": loaded.ChainID, "stateSeconds": loaded.LastBlockTime.Unix(), "stateNanos": loaded.LastBlockTime.Nanosecond(),
		"lastValidators": setView(t, loaded.LastValidators), "validators": setView(t, loaded.Validators), "nextValidators": setView(t, loaded.NextValidators),
		"writerStateRows": writerState, "writerBlockRows": writerBlocks, "reopenedStateRows": databaseRows(t, stateDB), "reopenedBlockRows": databaseRows(t, blockDB),
		"storedValidators": storedValidators, "seen": commitView(t, seen, chain), "fallback": commitView(t, fallback, chain),
		"storeBase": blocks.Base(), "storeHeight": blocks.Height(), "freshStores": true, "reopened": true,
		"constructor": context, "voteExtensions1000": loaded.ConsensusParams.ABCI.VoteExtensionsEnabled(1000), "voteExtensions1001": loaded.ConsensusParams.ABCI.VoteExtensionsEnabled(1001)}
	if selected != nil {
		result["explicitVerify"] = verification(loaded.LastValidators.VerifyCommit(chain, loaded.LastBlockID, 1000, seen))
	} else {
		result["explicitVerify"] = nil
	}
	if cs != nil && (name == "terminal-a" || name == "terminal-b") {
		rs := cs.GetRoundState()
		need(t, rs.Height == 1001 && rs.LastCommit != nil && rs.LastCommit.GetHeight() == 1000, "actual reconstructed height/last commit")
		majority, has := rs.LastCommit.TwoThirdsMajority()
		need(t, has, "actual reconstructed majority absent")
		votes := make([]any, vals.Size())
		bitset := make([]bool, vals.Size())
		for i := range votes {
			votes[i] = voteView(rs.LastCommit.GetByIndex(int32(i)), chain)
			bitset[i] = rs.LastCommit.BitArray().GetIndex(i)
		}
		reconstructed := rs.LastCommit.MakeExtendedCommit(loaded.ConsensusParams.ABCI).ToCommit()
		result["roundState"] = observation{"height": rs.Height, "round": rs.Round, "commitHeight": rs.LastCommit.GetHeight(), "commitRound": rs.LastCommit.GetRound(), "majority": blockID(majority), "hasMajority": has, "anyQuorum": rs.LastCommit.HasTwoThirdsAny(), "votes": votes, "bits": bitset, "commit": commitView(t, reconstructed, chain)}
		// State.MakeBlock fills parentA for both branches; commit/time come from the actual reconstructed votes.
		child, err := loaded.MakeBlock(1001, nil, reconstructed, nil, loaded.Validators.GetProposer().Address)
		need(t, err == nil && child.ValidateBasic() == nil, "actual normal successor shape: %v", err)
		need(t, child.LastBlockID.Equals(loaded.LastBlockID) && child.Time.After(loaded.LastBlockTime), "normal successor parent/time predicates")
		header, err := child.Header.ToProto().Marshal()
		need(t, err == nil, "header serialization")
		proto, err := child.ToProto()
		need(t, err == nil, "block serialization")
		encoded, err := proto.Marshal()
		need(t, err == nil, "block encoding")
		childResult := verification(executor.ValidateBlock(loaded, child))
		result["successor"] = observation{"height": child.Height, "parent": blockID(child.LastBlockID), "lastCommit": commitView(t, child.LastCommit, chain), "seconds": child.Time.Unix(), "nanos": child.Time.Nanosecond(), "headerProto": hx(header), "blockProto": hx(encoded), "hash": hx(child.Hash()), "verification": childResult, "evidenceChecks": ev.checks}
		want := "accept"
		if name == "terminal-b" {
			want = "block-id"
		}
		if result["explicitVerify"].(observation)["result"] != want {
			t.Errorf("terminal-binding id=%s api=VerifyCommit expected=%s got=%s", name, want, result["explicitVerify"].(observation)["result"])
		}
		if childResult["result"] != want {
			t.Errorf("terminal-binding id=%s api=ValidateBlock expected=%s got=%s", name, want, childResult["result"])
		}
		if name == "terminal-b" && childResult["result"] == "block-id" {
			wantReason := fmt.Sprintf("invalid commit -- wrong block ID: want %v, got %v", loaded.LastBlockID, reconstructed.BlockID)
			need(t, childResult["reason"] == wantReason && result["explicitVerify"].(observation)["reason"] == wantReason, "exact B commit binding refusal")
		}
	} else {
		result["roundState"], result["successor"] = nil, nil
	}
	raw, err := json.Marshal(result)
	need(t, err == nil, "receipt encoding")
	t.Logf("receipt=%s", raw)
	accepted := context["accepted"].(bool)
	wantAccepted := wantType == ""
	if accepted != wantAccepted || context["panicType"] != wantType || context["panicReason"] != wantReason || context["wrappedError"] != wantWrapped {
		t.Errorf("terminal-constructor id=%s expectedAccepted=%t gotAccepted=%t type=%v reason=%v wrapped=%v", name, wantAccepted, accepted, context["panicType"], context["panicReason"], context["wrappedError"])
	}
}
func TestTerminalSeenCommit(t *testing.T) {
	s := loadPublic(t)
	used := make(map[string]bool)
	for _, name := range terminalCases {
		t.Run(name, func(t *testing.T) { terminalCase(t, s, name, used) })
	}
}
