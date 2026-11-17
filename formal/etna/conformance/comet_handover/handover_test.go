package handover

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"os"
	"reflect"
	"testing"
	"time"

	abci "github.com/cometbft/cometbft/abci/types"
	"github.com/cometbft/cometbft/crypto/ed25519"
	"github.com/cometbft/cometbft/state"
	"github.com/cometbft/cometbft/types"
)

type member struct {
	Identity string `json:"identity"`
	Public   string `json:"public"`
	Address  string `json:"address"`
	Power    int64  `json:"power"`
	Priority int64  `json:"priority"`
}
type setView struct {
	Members  []member `json:"members"`
	Proposer *member  `json:"proposer"`
}
type row struct {
	Height             int64   `json:"height"`
	InitialHeight      int64   `json:"initialHeight"`
	ChangeHeight       int64   `json:"changeHeight"`
	Last               setView `json:"last"`
	Current            setView `json:"current"`
	Next               setView `json:"next"`
	HeaderHeight       int64   `json:"headerHeight"`
	ValidatorsHash     string  `json:"validatorsHash"`
	NextValidatorsHash string  `json:"nextValidatorsHash"`
}
type step struct {
	Height  int64            `json:"height"`
	Updates map[string]int64 `json:"updates"`
}
type literals struct {
	Programs     map[string][]step           `json:"programs"`
	Observations map[string]map[string][]row `json:"observations"`
}

// Input public points only: the Ed25519 base point, its negation, and its double.
// There is no secret key, signing call, random fixture or upstream test import.
func public(identity string) ed25519.PubKey {
	encoded := map[string]string{"A": "5866666666666666666666666666666666666666666666666666666666666666", "B": "58666666666666666666666666666666666666666666666666666666666666e6", "C": "c9a3f86aae465f0e56513864510f3997561fa2c9e85ea21dc2292309f3cd6022"}[identity]
	raw, err := hex.DecodeString(encoded)
	if err != nil || len(raw) != 32 {
		panic("invalid public input")
	}
	return ed25519.PubKey(raw)
}
func observeMember(v *types.Validator) *member {
	if v == nil {
		return nil
	}
	encoded := hex.EncodeToString(v.PubKey.Bytes())
	identity := "unknown"
	// Explicit identities in raw receipts; expected public bytes/addresses are
	// independently frozen in literals.json and never derived from this mapper.
	for _, key := range []string{"A", "B", "C"} {
		if bytes.Equal(v.PubKey.Bytes(), public(key)) {
			identity = key
		}
	}
	return &member{identity, encoded, hex.EncodeToString(v.Address), v.VotingPower, v.ProposerPriority}
}
func observeSet(v *types.ValidatorSet) setView {
	out := setView{Members: []member{}, Proposer: observeMember(v.Proposer)}
	for _, member := range v.Validators {
		out.Members = append(out.Members, *observeMember(member))
	}
	return out
}
func observe(t *testing.T, s state.State) row {
	t.Helper()
	height := s.LastBlockHeight + 1
	if s.LastBlockHeight == 0 {
		height = s.InitialHeight
	}
	// Empty unsigned structural commit: MakeBlock hash projection only, never
	// ValidateBlock/commit admission. Post-genesis MedianTime is the zero time.
	block, err := s.MakeBlock(height, nil, &types.Commit{}, nil, s.Validators.Proposer.Address)
	if err != nil {
		t.Fatal(err)
	}
	return row{s.LastBlockHeight, s.InitialHeight, s.LastHeightValidatorsChanged, observeSet(s.LastValidators), observeSet(s.Validators), observeSet(s.NextValidators), block.Height, hex.EncodeToString(block.ValidatorsHash), hex.EncodeToString(block.NextValidatorsHash)}
}
func encoded(v any) []byte {
	raw, err := json.Marshal(v)
	if err != nil {
		panic(err)
	}
	return raw
}

func TestWeightedHandover(t *testing.T) {
	raw, err := os.ReadFile("literals.json")
	if err != nil {
		t.Fatal(err)
	}
	var literal literals
	if err = json.Unmarshal(raw, &literal); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"unchanged", "unequal", "add-remove", "replacement", "overlapping"} {
		t.Run(name, func(t *testing.T) {
			genesis := &types.GenesisDoc{ChainID: "etna-handover-public", InitialHeight: 11, GenesisTime: time.Unix(100, 0).UTC(), ConsensusParams: types.DefaultConsensusParams(), Validators: []types.GenesisValidator{{Address: public("A").Address(), PubKey: public("A"), Power: 3}, {Address: public("B").Address(), PubKey: public("B"), Power: 1}}}
			s, err := state.MakeGenesisState(genesis)
			if err != nil {
				t.Fatal(err)
			}
			observations := []row{observe(t, s)}
			states := []state.State{s}
			snapshots := [][]byte{append([]byte{}, s.Bytes()...)}
			immutable := true
			transitions := 0
			for height := int64(11); height <= 16; height++ {
				updates := []*types.Validator{}
				for _, step := range literal.Programs[name] {
					if step.Height == height {
						for _, key := range []string{"A", "B", "C"} {
							if power, ok := step.Updates[key]; ok {
								updates = append(updates, types.NewValidator(public(key), power))
							}
						}
					}
				}
				header := &types.Header{Height: height, Time: time.Unix(100+height, 0).UTC()}
				response := &abci.ResponseFinalizeBlock{}
				inputBefore := encoded([]any{updates, header, response})
				next, err := state.EtnaConformanceUpdateState(s, types.BlockID{}, header, response, updates)
				if err != nil {
					t.Fatal(err)
				}
				transitions++
				if !bytes.Equal(inputBefore, encoded([]any{updates, header, response})) {
					immutable = false
				}
				for i, old := range states {
					if !bytes.Equal(snapshots[i], old.Bytes()) {
						immutable = false
					}
				}
				s = next
				observations = append(observations, observe(t, s))
				states = append(states, s)
				snapshots = append(snapshots, append([]byte{}, s.Bytes()...))
			}
			receipt := struct {
				Name           string `json:"name"`
				Transitions    int    `json:"transitions"`
				InputUnchanged bool   `json:"inputUnchanged"`
				Observations   []row  `json:"observations"`
			}{name, transitions, immutable, observations}
			t.Logf("receipt=%s", encoded(receipt))
			if !immutable || transitions != 6 {
				t.Error("handover-input-or-progress-mismatch id=" + name)
			}
			if !reflect.DeepEqual(observations, literal.Observations["normal"][name]) {
				t.Error("handover-observation-mismatch id=" + name)
			}
		})
	}
}
