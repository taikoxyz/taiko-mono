// Selected stock CometBFT header admission, without consensus or EL execution.
package comet_test

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/cometbft/cometbft/crypto/ed25519"
	"github.com/cometbft/cometbft/libs/log"
	"github.com/cometbft/cometbft/state"
	"github.com/cometbft/cometbft/types"
)

type anchor struct {
	Number int64 `json:"l1Number"`
	Time   int64 `json:"l1Timestamp"`
}
type observation struct {
	Present bool `json:"present"`
	Raw     struct {
		Generation int64 `json:"generation"`
		Parent     struct {
			Height int64 `json:"height"`
			Time   int64 `json:"elTimestamp"`
		} `json:"parent"`
		Origin struct {
			Height int64 `json:"height"`
			Number int64 `json:"l1Number"`
			Time   int64 `json:"l1Timestamp"`
		} `json:"origin"`
		Anchor anchor `json:"anchor"`
	} `json:"raw"`
	Header struct {
		Generation   int64  `json:"generation"`
		Height       int64  `json:"height"`
		ParentHeight int64  `json:"parentHeight"`
		BFTTime      int64  `json:"bftTime"`
		ELTime       int64  `json:"elTimestamp"`
		Anchor       anchor `json:"anchor"`
		EmptyID      bool   `json:"lastBlockIDEmpty"`
		EmptyCommit  bool   `json:"lastCommitEmpty"`
	} `json:"header"`
}
type receipt struct {
	ID          string      `json:"id"`
	Observation observation `json:"observation"`
}

// This pool accepts only the disclosed empty-evidence premise. A call counter
// proves successful admission reached the exported executor's evidence step.
type emptyEvidence struct {
	state.EmptyEvidencePool
	calls int
}

func (p *emptyEvidence) CheckEvidence(e types.EvidenceList) error {
	p.calls++
	if len(e) != 0 {
		return fmt.Errorf("fixture premise requires empty evidence")
	}
	return nil
}

func receipts(t *testing.T) map[string]receipt {
	t.Helper()
	data, err := os.ReadFile(os.Getenv("ETNA_RECOVERY_TIME_FIXTURE"))
	if err != nil {
		t.Fatal(err)
	}
	// Independent frozen byte identity; Python also verifies model provenance.
	got := fmt.Sprintf("%x", sha256.Sum256(data))
	if got != "ac047ee026a0e97f8db54a514a52d6638a3660bcaeba6e2265e9a405bfd07735" {
		t.Fatalf("wrong receipt bytes: %s", got)
	}
	var fixture struct {
		Schema string    `json:"schema"`
		Cases  []receipt `json:"cases"`
	}
	if err := json.Unmarshal(data, &fixture); err != nil {
		t.Fatal(err)
	}
	if fixture.Schema != "etna-recovery-time-replay-1" || len(fixture.Cases) != 3 {
		t.Fatal("wrong receipt schema/count")
	}
	expected := map[string][4]int64{"equal-times": {1, 103, 3, 3}, "parent-dominates": {3, 103, 3, 4}, "later-anchor": {1, 104, 4, 4}}
	result := make(map[string]receipt)
	for _, c := range fixture.Cases {
		want, ok := expected[c.ID]
		o := c.Observation
		if _, duplicate := result[c.ID]; !ok || duplicate {
			t.Fatal("unexpected/duplicate receipt")
		}
		if !o.Present || o.Raw.Generation != 1 || o.Raw.Parent.Height != 12 || o.Raw.Parent.Time != want[0] ||
			o.Raw.Origin.Height != 12 || o.Raw.Origin.Number != 103 || o.Raw.Origin.Time != 3 ||
			o.Raw.Anchor != (anchor{want[1], want[2]}) || o.Header.Generation != 1 || o.Header.Height != 13 ||
			o.Header.ParentHeight != 12 || o.Header.BFTTime != 3 || o.Header.ELTime != want[3] ||
			o.Header.Anchor != o.Raw.Anchor || !o.Header.EmptyID || !o.Header.EmptyCommit {
			t.Fatalf("wrong literal receipt premises: %+v", c)
		}
		result[c.ID] = c
	}
	return result
}

func makeBlock(t *testing.T, c receipt, nonemptyCommit bool) (state.State, *types.Block) {
	t.Helper()
	// Compressed Edwards25519 basepoint: a valid public point, no seed/private
	// key/signing API. This is a seeded committee premise, not Etna key mapping.
	key, err := hex.DecodeString("5866666666666666666666666666666666666666666666666666666666666666")
	if err != nil {
		t.Fatal(err)
	}
	pub := ed25519.PubKey(key)
	app := sha256.Sum256([]byte("seeded-application-state"))
	s, err := state.MakeGenesisState(&types.GenesisDoc{
		GenesisTime: time.Unix(c.Observation.Raw.Origin.Time, 0).UTC(), ChainID: "etna-first-block-boundary", InitialHeight: 13,
		Validators: []types.GenesisValidator{{PubKey: pub, Power: 1}}, AppHash: app[:],
	})
	if err != nil {
		t.Fatal(err)
	}
	if s.LastBlockHeight != 0 || s.InitialHeight != 13 || !s.LastBlockID.IsZero() || !s.LastBlockTime.Equal(time.Unix(3, 0)) ||
		s.Validators.Size() != 1 || s.NextValidators.Size() != 1 || s.LastValidators.Size() != 0 {
		t.Fatal("wrong genesis state premises")
	}
	commit := &types.Commit{}
	if nonemptyCommit {
		commit.Signatures = []types.CommitSig{types.NewCommitSigAbsent()}
	}
	// Opaque receipt bytes carry the distinct EL/anchor/generation metadata into
	// block data. Comet validates its hash; it does not execute an Etna EL/STF.
	payload, err := json.Marshal(c)
	if err != nil {
		t.Fatal(err)
	}
	b, err := s.MakeBlock(c.Observation.Header.Height, []types.Tx{payload}, commit, nil, pub.Address())
	if err != nil {
		t.Fatal(err)
	}
	b.Time = time.Unix(c.Observation.Header.BFTTime, 0).UTC()
	return s, b
}

func validate(t *testing.T, s state.State, b *types.Block, want string) {
	t.Helper()
	pool := &emptyEvidence{}
	// Fresh executor on every call avoids its already-validated-block cache.
	executor := state.NewBlockExecutor(nil, log.NewNopLogger(), nil, nil, pool, nil)
	err := executor.ValidateBlock(s, b)
	if want == "" {
		if err != nil {
			t.Errorf("expected admission, got %v", err)
		}
		if pool.calls != 1 {
			t.Errorf("expected one evidence check, got %d", pool.calls)
		}
	} else {
		if err == nil || err.Error() != want {
			t.Errorf("expected exact rejection %q, got %v", want, err)
		}
		if pool.calls != 0 {
			t.Errorf("rejected header reached evidence pool %d times", pool.calls)
		}
	}
}

func TestFirstBlockBoundary(t *testing.T) {
	cases := receipts(t)
	for _, id := range []string{"equal-times", "parent-dominates", "later-anchor"} {
		t.Run(id, func(t *testing.T) { s, b := makeBlock(t, cases[id], false); validate(t, s, b, "") })
	}
	baseline := cases["equal-times"]
	t.Run("wrong-bft-time", func(t *testing.T) {
		for _, offset := range []time.Duration{time.Second, time.Nanosecond} {
			s, b := makeBlock(t, baseline, false)
			b.Time = b.Time.Add(offset)
			// +1ns preserves floor(seconds), but exact BFT time equality still rejects.
			if offset == time.Nanosecond && b.Time.Unix() != s.LastBlockTime.Unix() {
				t.Fatal("nanosecond control changed seconds")
			}
			t.Logf("wrong BFT time offset=%s; actual=%s genesis=%s", offset, b.Time.Format(time.RFC3339Nano), s.LastBlockTime.Format(time.RFC3339Nano))
			validate(t, s, b, fmt.Sprintf("block time %v is not equal to genesis time %v", b.Time, s.LastBlockTime))
		}
	})
	t.Run("wrong-initial-height", func(t *testing.T) {
		s, b := makeBlock(t, baseline, false)
		b.Height = 14
		if s.InitialHeight != 13 || s.LastBlockHeight != 0 || b.Height != 14 {
			t.Fatal("wrong height control premises")
		}
		// Pinned upstream formats the actual/expected arguments in reverse order.
		validate(t, s, b, "wrong Block.Header.Height. Expected 14 for initial block, got 13")
	})
	t.Run("retained-last-block-id", func(t *testing.T) {
		s, b := makeBlock(t, baseline, false)
		hash := sha256.Sum256([]byte("retained-comet-header"))
		parts := sha256.Sum256([]byte("retained-comet-parts"))
		b.LastBlockID = types.BlockID{Hash: hash[:], PartSetHeader: types.PartSetHeader{Total: 1, Hash: parts[:]}}
		if s.LastBlockID.IsZero() == false || b.LastBlockID.IsZero() {
			t.Fatal("wrong retained ID control premises")
		}
		validate(t, s, b, fmt.Sprintf("wrong Block.Header.LastBlockID.  Expected %v, got %v", s.LastBlockID, b.LastBlockID))
	})
	t.Run("nonempty-last-commit", func(t *testing.T) {
		s, b := makeBlock(t, baseline, true)
		if len(b.LastCommit.Signatures) != 1 || b.LastCommit.Height != 0 {
			t.Fatal("wrong first commit control premises")
		}
		validate(t, s, b, "initial block can't have LastCommit signatures")
	})
}
