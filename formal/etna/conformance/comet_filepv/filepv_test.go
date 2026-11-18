package privval

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	cmtjson "github.com/cometbft/cometbft/libs/json"
	privvalproto "github.com/cometbft/cometbft/proto/tendermint/privval"
	pb "github.com/cometbft/cometbft/proto/tendermint/types"
	"github.com/cometbft/cometbft/types"
)

const (
	nilSeed     = "precommit_nil"
	prevoteSeed = "prevote_a_r1"
)

type publicVote struct {
	Name      string            `json:"name"`
	Chain     string            `json:"chain_id"`
	SignBytes string            `json:"sign_bytes"`
	Signature string            `json:"signature"`
	Vote      map[string]string `json:"vote"`
}

type publicVotes struct {
	Key struct {
		PublicKey string `json:"public_key"`
		Signer    string `json:"signer"`
	} `json:"voteKey"`
	Cases []publicVote `json:"voteCases"`
}

type record map[string]any

type rank struct {
	Height int64 `json:"height"`
	Round  int32 `json:"round"`
	Step   int8  `json:"step"`
}

func check(t *testing.T, ok bool, format string, args ...any) {
	t.Helper()
	if !ok {
		t.Fatalf(format, args...)
	}
}

func readProjection(t *testing.T) (publicVotes, map[string]publicVote) {
	t.Helper()
	raw, err := os.ReadFile("public-votes.json")
	check(t, err == nil, "read public votes: %v", err)
	var published publicVotes
	err = json.Unmarshal(raw, &published)
	check(t, err == nil, "decode public votes: %v", err)
	selected := make(map[string]publicVote)
	for _, row := range published.Cases {
		switch row.Name {
		case nilSeed, prevoteSeed, "prevote_b_r1", "gen1_precommit_a":
			_, duplicate := selected[row.Name]
			check(t, !duplicate, "duplicate public row: %s", row.Name)
			selected[row.Name] = row
		}
	}
	check(t, len(selected) == 4, "missing public FilePV rows")
	return published, selected
}

func publicBytes(t *testing.T, value string) []byte {
	t.Helper()
	raw, err := hex.DecodeString(strings.TrimPrefix(value, "0x"))
	check(t, err == nil && "0x"+hex.EncodeToString(raw) == value && len(raw) > 0,
		"invalid public byte string")
	return raw
}

func publicHash(t *testing.T, value string) []byte {
	t.Helper()
	if value == "0x"+strings.Repeat("0", 64) {
		return nil
	}
	raw := publicBytes(t, value)
	check(t, len(raw) == 32, "invalid public hash width")
	return raw
}

func integer(t *testing.T, value string, size int) int64 {
	t.Helper()
	n, err := strconv.ParseInt(value, 10, size)
	check(t, err == nil, "invalid public integer: %v", err)
	return n
}

func timeAt(seconds, nanos int64) time.Time {
	return time.Unix(seconds, nanos).UTC()
}

func unsignedVote(t *testing.T, row publicVote, address []byte) *pb.Vote {
	t.Helper()
	v := row.Vote
	return &pb.Vote{
		Type:             pb.SignedMsgType(integer(t, v["voteType"], 8)),
		Height:           integer(t, v["height"], 64),
		Round:            int32(integer(t, v["round"], 32)),
		Timestamp:        timeAt(integer(t, v["timestampSeconds"], 64), integer(t, v["timestampNanos"], 32)),
		ValidatorAddress: address,
		BlockID: pb.BlockID{
			Hash: publicHash(t, v["blockHash"]),
			PartSetHeader: pb.PartSetHeader{
				Total: uint32(integer(t, v["partsTotal"], 32)),
				Hash:  publicHash(t, v["partsHash"]),
			},
		},
	}
}

func stateFile(seed string) string {
	return "/tmp/output/state/" + seed + ".json"
}

func stateFields(hrs rank, signature, signBytes []byte) record {
	return record{
		"height": hrs.Height, "round": hrs.Round, "step": hrs.Step,
		"signature": hex.EncodeToString(signature), "signBytes": hex.EncodeToString(signBytes),
	}
}

func observeState(state FilePVLastSignState) record {
	return stateFields(rank{state.Height, state.Round, state.Step}, state.Signature, state.SignBytes)
}

func readStateBytes(t *testing.T, path string) ([]byte, record) {
	t.Helper()
	info, err := os.Lstat(path)
	if os.IsNotExist(err) {
		return nil, nil
	}
	check(t, err == nil, "stat actual state: %v", err)
	check(t, info.Mode().IsRegular(), "actual state is not regular")
	raw, err := os.ReadFile(path)
	check(t, err == nil, "read actual state: %v", err)
	hash := sha256.Sum256(raw)
	return raw, record{
		"path": path, "sha256": hex.EncodeToString(hash[:]), "bytes": len(raw),
		"mode": "0" + strconv.FormatUint(uint64(info.Mode().Perm()), 8),
	}
}

func rehydrate(t *testing.T, path string) (FilePV, record) {
	t.Helper()
	raw, disk := readStateBytes(t, path)
	check(t, disk != nil, "reader state file missing")
	var state FilePVLastSignState
	err := cmtjson.Unmarshal(raw, &state)
	check(t, err == nil, "decode actual FilePV state: %v", err)
	state.filePath = path
	return FilePV{LastSignState: state}, disk
}

func processIdentity(t *testing.T) record {
	t.Helper()
	namespace, err := os.Readlink("/proc/self/ns/pid")
	check(t, err == nil, "read native process namespace: %v", err)
	raw, err := os.ReadFile("/proc/self/stat")
	check(t, err == nil, "read native process start: %v", err)
	nameEnd := strings.LastIndexByte(string(raw), ')')
	check(t, nameEnd >= 0, "process stat missing executable name")
	fields := strings.Fields(string(raw[nameEnd+1:]))
	check(t, len(fields) > 19, "process stat missing start tick")
	return record{"pid": os.Getpid(), "namespace": namespace, "startTicks": fields[19]}
}

func logReceipt(t *testing.T, value record) {
	t.Helper()
	value["process"] = processIdentity(t)
	raw, err := json.Marshal(value)
	check(t, err == nil, "encode native receipt: %v", err)
	t.Logf("receipt=%s", raw)
}

func TestFilePVWrite(t *testing.T) {
	_, rows := readProjection(t)
	for _, seed := range []struct {
		name string
		hrs  rank
	}{
		{nilSeed, rank{1000, 0, 3}},
		{prevoteSeed, rank{1000, 1, 2}},
	} {
		t.Run(seed.name, func(t *testing.T) {
			path := stateFile(seed.name)
			_, err := os.Lstat(path)
			check(t, os.IsNotExist(err), "writer state path must start absent: %v", err)
			row := rows[seed.name]
			signBytes, sig := publicBytes(t, row.SignBytes), publicBytes(t, row.Signature)
			check(t, len(sig) == 65, "wrong public signature width")
			attempt := stateFields(seed.hrs, sig, signBytes)
			pv := FilePV{LastSignState: FilePVLastSignState{filePath: path}}
			pv.saveSigned(seed.hrs.Height, seed.hrs.Round, seed.hrs.Step, signBytes, sig)
			_, disk := readStateBytes(t, path)
			logReceipt(t, record{
				"schema": "etna-comet-filepv-writer-1", "seed": seed.name, "path": path,
				"attempt": attempt, "stateAfter": observeState(pv.LastSignState), "diskAfter": disk,
			})
			check(t, disk != nil, "O01 persistence id=%s: state file missing after saveSigned", seed.name)
		})
	}
}

type readerCase struct {
	name        string
	seed        string
	row         string
	change      func(*pb.Vote)
	wrongChain  bool
	dropBytes   bool
	dropSig     bool
	checkRank   *rank
	expectPanic bool
}

func readerCases() []readerCase {
	return []readerCase{
		{name: "nil-exact", seed: nilSeed, row: nilSeed},
		{name: "nil-time", seed: nilSeed, row: nilSeed, change: func(v *pb.Vote) {
			v.Timestamp = timeAt(1700000000, 124)
		}},
		{name: "prevote-exact", seed: prevoteSeed, row: prevoteSeed},
		{name: "prevote-conflict", seed: prevoteSeed, row: "prevote_b_r1"},
		{name: "wrong-chain", seed: nilSeed, row: nilSeed, wrongChain: true},
		{name: "height-regression", seed: nilSeed, row: nilSeed, change: func(v *pb.Vote) {
			v.Height, v.Round = 999, 2
		}},
		{name: "round-regression", seed: prevoteSeed, row: nilSeed},
		{name: "step-regression", seed: nilSeed, row: prevoteSeed, change: func(v *pb.Vote) {
			v.Round = 0
		}},
		{name: "missing-sign-bytes", seed: nilSeed, row: nilSeed, dropBytes: true, dropSig: true},
		{name: "missing-signature", seed: nilSeed, dropSig: true, checkRank: &rank{1000, 0, 3}, expectPanic: true},
		{name: "advance-check", seed: nilSeed, checkRank: &rank{1000, 1, 2}},
	}
}

func errorText(err error) string {
	if err != nil {
		return err.Error()
	}
	return ""
}

func checkedHRS(t *testing.T, state *FilePVLastSignState, attempt rank, expectPanic bool) (result record) {
	t.Helper()
	if expectPanic {
		// Catch only the documented incomplete-state panic around this one CheckHRS call.
		defer func() {
			recovered := recover()
			if recovered != nil {
				message, ok := recovered.(string)
				if !ok || message != "pv: Signature is nil but SignBytes is not!" {
					panic(recovered)
				}
				result = record{"reuse": false, "error": "", "panic": message}
			}
		}()
	}
	reuse, err := state.CheckHRS(attempt.Height, attempt.Round, attempt.Step)
	return record{"reuse": reuse, "error": errorText(err), "panic": ""}
}

func observeVote(t *testing.T, chain string, vote *pb.Vote) record {
	t.Helper()
	wire, err := vote.Marshal()
	check(t, err == nil, "marshal actual vote: %v", err)
	return record{
		"wire": hex.EncodeToString(wire), "signBytes": hex.EncodeToString(types.VoteSignBytes(chain, vote)),
		"seconds": vote.Timestamp.Unix(), "nanos": vote.Timestamp.Nanosecond(),
		"signature":          hex.EncodeToString(vote.Signature),
		"extensionSignature": hex.EncodeToString(vote.ExtensionSignature),
	}
}

func requirePublicReplay(t *testing.T, pv *FilePV, vote *pb.Vote) {
	t.Helper()
	check(t, pv.Key.PrivKey == nil, "fixture contains a private key")
	check(t, vote.Type == pb.PrevoteType || (vote.Type == pb.PrecommitType && types.ProtoBlockIDIsNil(&vote.BlockID)),
		"fixture attempted a signing-only vote type")
	check(t, len(vote.Signature) == 0 && len(vote.Extension) == 0 && len(vote.ExtensionSignature) == 0,
		"fixture vote must be unsigned and extension-free")
	state := pv.LastSignState
	step := voteToStep(vote)
	later := vote.Height > state.Height ||
		(vote.Height == state.Height && (vote.Round > state.Round || (vote.Round == state.Round && step > state.Step)))
	check(t, !later, "fixture attempted a new signature")
}

func replayVote(t *testing.T, pv *FilePV, chain string, vote *pb.Vote, pub secp256k1eth.PubKey) (record, record) {
	t.Helper()
	requirePublicReplay(t, pv, vote)
	attempt := record{"chain": chain, "vote": observeVote(t, chain, vote)}
	err := pv.SignVote(chain, vote)
	response := observeVote(t, chain, vote)
	return attempt, record{"error": errorText(err), "vote": response,
		"verified": pub.VerifySignature(types.VoteSignBytes(chain, vote), vote.Signature)}
}

func publicKey(t *testing.T, projection publicVotes) (secp256k1eth.PubKey, []byte) {
	t.Helper()
	pub, err := secp256k1eth.NewPubKeyFromBytes(publicBytes(t, projection.Key.PublicKey))
	check(t, err == nil, "construct native public vote key: %v", err)
	address := pub.Address()
	check(t, "0x"+hex.EncodeToString(address) == projection.Key.Signer, "wrong public vote address")
	return pub, address
}

func TestFilePVRead(t *testing.T) {
	projection, rows := readProjection(t)
	pub, address := publicKey(t, projection)

	for _, test := range readerCases() {
		t.Run(test.name, func(t *testing.T) {
			path := stateFile(test.seed)
			pv, beforeDisk := rehydrate(t, path)
			if test.dropBytes {
				pv.LastSignState.SignBytes = nil
			}
			if test.dropSig {
				pv.LastSignState.Signature = nil
			}
			stateBefore := observeState(pv.LastSignState)

			var attempt any
			var response record
			operation := "SignVote"
			if test.checkRank != nil {
				operation = "CheckHRS"
				attempt = *test.checkRank
				response = checkedHRS(t, &pv.LastSignState, *test.checkRank, test.expectPanic)
			} else {
				row := rows[test.row]
				chain := row.Chain
				if test.wrongChain {
					chain = rows["gen1_precommit_a"].Chain
				}
				vote := unsignedVote(t, row, address)
				if test.change != nil {
					test.change(vote)
				}
				attempt, response = replayVote(t, &pv, chain, vote, pub)
			}
			_, afterDisk := readStateBytes(t, path)
			logReceipt(t, record{
				"schema": "etna-comet-filepv-reader-1", "seed": test.seed, "path": path,
				"operation": operation, "attempt": attempt, "reply": response,
				"stateBefore": stateBefore, "stateAfter": observeState(pv.LastSignState),
				"diskBefore": beforeDisk, "diskAfter": afterDisk,
			})
			if test.name == "nil-time" {
				vote := response["vote"].(record)
				check(t, vote["seconds"] == int64(1700000000) && vote["nanos"] == 123,
					"O01 cached-time id=%s: expected 1700000000/123, got %d/%d",
					test.name, vote["seconds"], vote["nanos"])
			}
		})
	}
}

type handlerCall struct {
	row        string
	change     func(*pb.Vote)
	wrongChain bool
	refused    bool
}

type handlerEpisode struct {
	name  string
	seed  string
	calls []handlerCall
}

func handlerEpisodes() []handlerEpisode {
	nilReplay := handlerCall{row: nilSeed}
	prevoteReplay := handlerCall{row: prevoteSeed}
	return []handlerEpisode{
		{"nil-exact", nilSeed, []handlerCall{nilReplay}},
		{"nil-time", nilSeed, []handlerCall{{row: nilSeed, change: func(v *pb.Vote) {
			v.Timestamp = timeAt(1700000000, 124)
		}}}},
		{"wrong-chain-retry", nilSeed, []handlerCall{{row: nilSeed, wrongChain: true, refused: true}, nilReplay}},
		{"prevote-conflict-retry", prevoteSeed, []handlerCall{{row: "prevote_b_r1", refused: true}, prevoteReplay}},
		{"height-regression", nilSeed, []handlerCall{{row: nilSeed, refused: true, change: func(v *pb.Vote) {
			v.Height, v.Round = 999, 2
		}}}},
		{"round-regression", prevoteSeed, []handlerCall{{row: nilSeed, refused: true}}},
		{"step-regression", nilSeed, []handlerCall{{row: prevoteSeed, refused: true, change: func(v *pb.Vote) {
			v.Round = 0
		}}}},
		{"prevote-exact", prevoteSeed, []handlerCall{prevoteReplay}},
	}
}

func observeHandlerResponse(t *testing.T, response privvalproto.Message, err error, chain string, pub secp256k1eth.PubKey) (record, string) {
	t.Helper()
	wire, marshalErr := response.Marshal()
	check(t, marshalErr == nil, "marshal actual handler response: %v", marshalErr)
	reply := record{
		"wire": hex.EncodeToString(wire), "union": fmt.Sprintf("%T", response.Sum),
		"vote": nil, "error": nil, "verified": false,
	}
	signed := response.GetSignedVoteResponse()
	if signed == nil {
		return reply, "unexpected response"
	}
	reply["union"] = "SignedVoteResponse"
	reply["vote"] = observeVote(t, chain, &signed.Vote)
	verified := pub.VerifySignature(types.VoteSignBytes(chain, &signed.Vote), signed.Vote.Signature)
	reply["verified"] = verified
	if signed.Error != nil {
		reply["error"] = record{"code": signed.Error.Code, "description": signed.Error.Description}
	}
	switch {
	case signed.Error != nil && err != nil && !verified:
		return reply, "refusal"
	case signed.Error == nil && err == nil && verified:
		return reply, "cached vote"
	default:
		return reply, "unexpected response"
	}
}

func callHandler(t *testing.T, pv *FilePV, requested, configured string, vote *pb.Vote,
	pub secp256k1eth.PubKey) (record, string) {
	t.Helper()
	requirePublicReplay(t, pv, vote)
	request := mustWrapMsg(&privvalproto.SignVoteRequest{ChainId: requested, Vote: vote})
	message := request.GetSignVoteRequest()
	check(t, message != nil && message.Vote == vote, "wrong actual handler request")
	wire, err := request.Marshal()
	check(t, err == nil, "marshal actual handler request: %v", err)
	// Capture the request before the handler can modify the shared Vote pointer.
	attempt := record{
		"wire": hex.EncodeToString(wire), "requestedChain": message.ChainId, "configuredChain": configured,
		"vote": observeVote(t, message.ChainId, message.Vote),
	}
	path := pv.LastSignState.filePath
	stateBefore := observeState(pv.LastSignState)
	_, diskBefore := readStateBytes(t, path)
	response, err := DefaultValidationRequestHandler(pv, request, configured)
	stateAfter := observeState(pv.LastSignState)
	_, diskAfter := readStateBytes(t, path)
	reply, outcome := observeHandlerResponse(t, response, err, configured, pub)
	var goError any
	if err != nil {
		goError = err.Error()
	}
	return record{
		"request": attempt, "response": reply, "goError": goError, "voteAfter": observeVote(t, configured, vote),
		"stateBefore": stateBefore, "stateAfter": stateAfter, "diskBefore": diskBefore, "diskAfter": diskAfter,
	}, outcome
}

func TestFilePVHandler(t *testing.T) {
	projection, rows := readProjection(t)
	pub, address := publicKey(t, projection)
	for _, episode := range handlerEpisodes() {
		t.Run(episode.name, func(t *testing.T) {
			path := stateFile(episode.seed)
			pv, disk := rehydrate(t, path)
			configured := rows[episode.seed].Chain
			calls := make([]record, 0, len(episode.calls))
			var mismatch string
			for i, call := range episode.calls {
				row := rows[call.row]
				vote := unsignedVote(t, row, address)
				if call.change != nil {
					call.change(vote)
				}
				requested := row.Chain
				if call.wrongChain {
					requested = rows["gen1_precommit_a"].Chain
				}
				observed, outcome := callHandler(t, &pv, requested, configured, vote, pub)
				calls = append(calls, observed)
				want := "cached vote"
				if call.refused {
					want = "refusal"
				}
				if outcome != want && mismatch == "" {
					mismatch = fmt.Sprintf("O02 handler id=%s: call %d expected %s, got %s",
						episode.name, i+1, want, outcome)
				}
			}
			logReceipt(t, record{
				"schema": "etna-comet-filepv-handler-1", "seed": episode.seed, "path": path,
				"loadedDisk": disk, "calls": calls,
			})
			check(t, mismatch == "", "%s", mismatch)
		})
	}
}
