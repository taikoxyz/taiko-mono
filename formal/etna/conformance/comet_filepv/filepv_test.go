package privval

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	cmtjson "github.com/cometbft/cometbft/libs/json"
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

func replayVote(t *testing.T, pv *FilePV, chain string, vote *pb.Vote, pub secp256k1eth.PubKey) (record, record) {
	t.Helper()
	check(t, vote.Type == pb.PrevoteType || (vote.Type == pb.PrecommitType && types.ProtoBlockIDIsNil(&vote.BlockID)),
		"fixture attempted a signing-only vote type")
	check(t, len(vote.Signature) == 0 && len(vote.Extension) == 0 && len(vote.ExtensionSignature) == 0,
		"fixture vote must be unsigned and extension-free")
	state := pv.LastSignState
	step := voteToStep(vote)
	later := vote.Height > state.Height ||
		(vote.Height == state.Height && (vote.Round > state.Round || (vote.Round == state.Round && step > state.Step)))
	check(t, !later, "fixture attempted a new signature")
	attempt := record{"chain": chain, "vote": observeVote(t, chain, vote)}
	err := pv.SignVote(chain, vote)
	response := observeVote(t, chain, vote)
	return attempt, record{"error": errorText(err), "vote": response,
		"verified": pub.VerifySignature(types.VoteSignBytes(chain, vote), vote.Signature)}
}

func TestFilePVRead(t *testing.T) {
	projection, rows := readProjection(t)
	pub, err := secp256k1eth.NewPubKeyFromBytes(publicBytes(t, projection.Key.PublicKey))
	check(t, err == nil, "construct native public vote key: %v", err)
	address := pub.Address()
	check(t, "0x"+hex.EncodeToString(address) == projection.Key.Signer, "wrong public vote address")

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
