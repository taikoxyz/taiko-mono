// Regenerates validator-state vectors using stock CometBFT v0.40.0.
// Invoke generate.sh. Only exported types.ValidatorSet methods run, in the order
// state/execution.go updateState and state/state.go MakeGenesisState call them.
package main

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math"
	"math/rand/v2"
	"os"
	"slices"
	"strings"

	"github.com/cometbft/cometbft/crypto"
	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	"github.com/cometbft/cometbft/types"
)

// update is one (key, power) change, as committee::validator_updates returns it; at a case's
// first step it is a genesis member.
type update struct {
	KeyHex string
	Power  int64
}

// step is the state after one height, or the error that height's updates raise. The first
// step of a case is its genesis. Updates are comma-separated `key:power` items and sets are
// comma-separated `key:power:priority` items in set order, where key indexes the top-level
// key table: strings, which the repository's JSON formatter never rewraps.
type step struct {
	Updates         string  `json:"updates"`
	Height          *uint64 `json:"height,omitempty"`
	Current         string  `json:"current,omitempty"`
	CurrentProposer *int    `json:"current_proposer,omitempty"`
	Next            string  `json:"next,omitempty"`
	NextProposer    *int    `json:"next_proposer,omitempty"`
	Error           string  `json:"error,omitempty"`
}

// rpcRebuild is what LoadValidators (the /validators RPC) returns for the set the live state
// holds as `next` at step Step: the full set stored at ChangeStep, advanced Blocks heights by
// one IncrementProposerPriority(Blocks).
type rpcRebuild struct {
	Seed           uint64 `json:"seed"`
	ChangeStep     int    `json:"change_step"`
	Step           int    `json:"step"`
	Blocks         int    `json:"blocks"`
	BulkPriorities string `json:"bulk_priorities"`
	BulkProposer   int    `json:"bulk_proposer"`
}

// vcase is one named sequence of steps.
type vcase struct {
	Name       string      `json:"name"`
	Steps      []step      `json:"steps"`
	RPCRebuild *rpcRebuild `json:"rpc_rebuild,omitempty"`
}

func must(err error) {
	if err != nil {
		panic(err)
	}
}

// pool[s] is the public key of GenPrivKeySecp256k1Eth(32 repetitions of byte s), s in 1..255.
// The key table lists them in seed order, so key index s-1 is seed s.
var (
	pool     [256]crypto.PubKey
	keyTable []string
	keyIndex = map[string]int{}
)

func init() {
	for s := 1; s < len(pool); s++ {
		pool[s] = secp256k1eth.GenPrivKeySecp256k1Eth(bytes.Repeat([]byte{byte(s)}, 32)).PubKey()
		keyHex := hex.EncodeToString(pool[s].Bytes())
		keyIndex[keyHex] = len(keyTable)
		keyTable = append(keyTable, keyHex)
	}
}

// encodeUpdates lists updates as `key:power` items, in their order.
func encodeUpdates(updates []update) string {
	items := make([]string, len(updates))
	for i, u := range updates {
		index, ok := keyIndex[u.KeyHex]
		if !ok {
			panic("update without a pool key")
		}
		items[i] = fmt.Sprintf("%d:%d", index, u.Power)
	}
	return strings.Join(items, ",")
}

// member is a committee member: a pool key seed and its voting power.
type member struct {
	seed  int
	power int64
}

func upd(seed int, power int64) update {
	return update{hex.EncodeToString(pool[seed].Bytes()), power}
}

func members(list ...member) []update {
	out := make([]update, len(list))
	for i, m := range list {
		out[i] = upd(m.seed, m.power)
	}
	return out
}

func validators(updates []update) []*types.Validator {
	out := make([]*types.Validator, len(updates))
	for i, u := range updates {
		raw, err := hex.DecodeString(u.KeyHex)
		must(err)
		key, err := secp256k1eth.NewPubKeyFromBytes(raw)
		must(err)
		out[i] = types.NewValidator(key, u.Power)
	}
	return out
}

// validatorUpdates has committee::validator_updates' shape: every old member at power 0,
// overwritten by the new committee's members, sorted by compressed key; nothing when the two
// committees are identical.
func validatorUpdates(old, new []member) []update {
	same := len(old) == len(new)
	byKey := map[string]int64{}
	for _, m := range old {
		byKey[upd(m.seed, 0).KeyHex] = 0
	}
	for _, m := range new {
		byKey[upd(m.seed, 0).KeyHex] = m.power
	}
	if same {
		powers := map[int]int64{}
		for _, m := range old {
			powers[m.seed] = m.power
		}
		for _, m := range new {
			if power, ok := powers[m.seed]; !ok || power != m.power {
				same = false
			}
		}
	}
	if same {
		return []update{}
	}
	keys := make([]string, 0, len(byKey))
	for key := range byKey {
		keys = append(keys, key)
	}
	slices.Sort(keys)
	out := make([]update, len(keys))
	for i, key := range keys {
		out[i] = update{key, byKey[key]}
	}
	return out
}

// chain holds CometBFT's State.Validators (cur) and State.NextValidators (next) after height.
type chain struct {
	height    uint64
	cur, next *types.ValidatorSet
	steps     []step
}

// snapshot lists a set as `key:power:priority` items in set order, with the index of its
// stored proposer.
func snapshot(vals *types.ValidatorSet) (string, *int) {
	if vals.Proposer == nil {
		panic("no stored proposer")
	}
	items := make([]string, len(vals.Validators))
	proposer := -1
	for i, v := range vals.Validators {
		index, ok := keyIndex[hex.EncodeToString(v.PubKey.Bytes())]
		if !ok {
			panic("validator without a pool key")
		}
		items[i] = fmt.Sprintf("%d:%d:%d", index, v.VotingPower, v.ProposerPriority)
		if bytes.Equal(v.Address, vals.Proposer.Address) {
			proposer = i
		}
	}
	if proposer < 0 {
		panic("stored proposer is not in its set")
	}
	return strings.Join(items, ","), &proposer
}

func (c *chain) record(updates []update) {
	height := c.height
	s := step{Updates: encodeUpdates(updates), Height: &height}
	s.Current, s.CurrentProposer = snapshot(c.cur)
	s.Next, s.NextProposer = snapshot(c.next)
	c.steps = append(c.steps, s)
}

// genesis is MakeGenesisState: Validators = NewValidatorSet(vals), NextValidators =
// NewValidatorSet(vals).CopyIncrementProposerPriority(1). NewValidatorSet panics on invalid
// members; the panic is recorded as the step's error and ends the case.
func genesis(height uint64, list []update) (c *chain, ok bool) {
	c = &chain{height: height}
	defer func() {
		if r := recover(); r != nil {
			c.steps = append(c.steps, step{Updates: encodeUpdates(list), Error: fmt.Sprint(r)})
			ok = false
		}
	}()
	c.cur = types.NewValidatorSet(validators(list))
	c.next = types.NewValidatorSet(validators(list)).CopyIncrementProposerPriority(1)
	c.record(list)
	return c, true
}

// advance is updateState for height+1: next' = NextValidators.Copy(), updated with the
// change set if there is one, then IncrementProposerPriority(1); Validators' =
// NextValidators.Copy(). An UpdateWithChangeSet error is recorded and ends the case.
func (c *chain) advance(updates []update) bool {
	n := c.next.Copy()
	if len(updates) > 0 {
		if err := n.UpdateWithChangeSet(validators(updates)); err != nil {
			c.steps = append(c.steps, step{Updates: encodeUpdates(updates), Error: err.Error()})
			return false
		}
	}
	n.IncrementProposerPriority(1)
	c.cur, c.next = c.next.Copy(), n
	c.height++
	c.record(updates)
	return true
}

func (c *chain) idle(blocks int) {
	for range blocks {
		if !c.advance([]update{}) {
			panic("an empty update failed")
		}
	}
}

func (c *chain) apply(updates []update) {
	if !c.advance(updates) {
		panic("unexpected change-set error: " + c.steps[len(c.steps)-1].Error)
	}
}

func (c *chain) fail(updates []update) {
	if c.advance(updates) {
		panic("change set unexpectedly accepted")
	}
}

func (c *chain) done(name string) vcase {
	return vcase{Name: name, Steps: c.steps}
}

func start(height uint64, list ...member) *chain {
	c, ok := genesis(height, members(list...))
	if !ok {
		panic("unexpected genesis error: " + c.steps[0].Error)
	}
	return c
}

// seedOf is the pool seed of key.
func seedOf(key crypto.PubKey) int {
	for s := 1; s < len(pool); s++ {
		if bytes.Equal(pool[s].Bytes(), key.Bytes()) {
			return s
		}
	}
	panic("validator without a pool key")
}

func committee(vals *types.ValidatorSet) []member {
	out := make([]member, len(vals.Validators))
	for i, v := range vals.Validators {
		out[i] = member{seedOf(v.PubKey), v.VotingPower}
	}
	return out
}

func priorities(vals *types.ValidatorSet) string {
	fields := make([]string, len(vals.Validators))
	for i, v := range vals.Validators {
		fields[i] = fmt.Sprint(v.ProposerPriority)
	}
	return strings.Join(fields, ",")
}

const maxTotal = types.MaxTotalVotingPower

func namedCases() []vcase {
	var cases []vcase

	c := start(0, member{1, 10})
	c.idle(3)
	cases = append(cases, c.done("genesis_1"))

	c = start(41, member{4, 7}, member{1, 30}, member{3, 7}, member{2, 12})
	c.idle(8)
	cases = append(cases, c.done("genesis_4"))

	big := make([]member, 120)
	for i := range big {
		big[i] = member{i + 1, 1 + int64(i*37%100)}
	}
	c = start(1_000_000, big...)
	c.idle(1)
	cases = append(cases, c.done("genesis_120"))

	// One heavy add starts at -(P + P>>3), below every existing priority, and is still the
	// lowest after the height's IncrementProposerPriority(1).
	old := []member{{1, 40}, {2, 30}, {3, 20}, {4, 10}}
	c = start(0, old...)
	c.idle(3)
	c.apply(validatorUpdates(old, append(slices.Clone(old), member{5, 100})))
	lowest := c.next.Validators[0]
	for _, v := range c.next.Validators {
		if v.ProposerPriority < lowest.ProposerPriority {
			lowest = v
		}
	}
	if seedOf(lowest.PubKey) != 5 {
		panic("added member is not the lowest")
	}
	c.idle(3)
	cases = append(cases, c.done("added_member_ends_lowest"))

	// The change set removes the proposer stored in the NextValidators it applies to.
	old = []member{{1, 25}, {2, 25}, {3, 25}, {4, 25}}
	c = start(0, old...)
	c.idle(2)
	removed := seedOf(c.next.Proposer.PubKey)
	var kept []member
	for _, m := range old {
		if m.seed != removed {
			kept = append(kept, m)
		}
	}
	c.apply(validatorUpdates(old, kept))
	c.idle(3)
	cases = append(cases, c.done("stored_proposer_removed"))

	old = []member{{1, 10}, {2, 20}, {3, 30}, {4, 40}}
	c = start(0, old...)
	c.idle(2)
	c.apply(validatorUpdates(old, []member{{1, 50}, {2, 20}, {3, 5}, {4, 40}}))
	c.idle(4)
	cases = append(cases, c.done("power_only_change"))

	// A lone same-power entry, then the validator_updates shape where unchanged members repeat
	// their power next to a real change.
	old = []member{{1, 10}, {2, 20}, {3, 30}}
	c = start(0, old...)
	c.idle(2)
	c.apply(members(member{2, 20}))
	c.idle(1)
	c.apply(validatorUpdates(old, []member{{1, 15}, {2, 20}, {3, 30}}))
	c.idle(2)
	cases = append(cases, c.done("same_power_update"))

	// A 1,000,000 member joins three power-1 members at -(P + P>>3) and swings by a million
	// per height. Dropping it to power 1 leaves priorities about 10^5 times wider than
	// 2·total, so UpdateWithChangeSet rescales by a large ratio; raising it back restarts the
	// swing from that tiny window.
	low := []member{{1, 1}, {2, 1}, {3, 1}, {4, 1}}
	high := []member{{1, 1}, {2, 1}, {3, 1}, {4, 1_000_000}}
	c = start(0, low[:3]...)
	c.idle(1)
	c.apply(validatorUpdates(low[:3], high))
	c.idle(2)
	if priorityDiff(c.next) <= 1000*2*4 {
		panic("no large rescale")
	}
	c.apply(validatorUpdates(high, low))
	c.idle(3)
	c.apply(validatorUpdates(low, high))
	c.idle(3)
	cases = append(cases, c.done("rescale_trigger"))

	old = []member{{1, 7}, {2, 7}, {3, 7}, {4, 7}, {5, 7}}
	c = start(0, old...)
	c.idle(10)
	c.apply(validatorUpdates(old, append(slices.Clone(old), member{6, 7})))
	c.idle(5)
	cases = append(cases, c.done("priority_ties"))

	// Total MaxTotalVotingPower - 1; replacing a third keeps it there while the updated total
	// before removals, which prices the new member, is about 4/3 of the maximum.
	third := maxTotal / 3
	old = []member{{1, third}, {2, third}, {3, maxTotal - 2*third - 1}}
	c = start(0, old...)
	c.idle(3)
	c.apply(validatorUpdates(old, []member{{1, third}, {3, maxTotal - 2*third - 1}, {4, third}}))
	c.idle(3)
	cases = append(cases, c.done("near_max_total"))

	old = []member{{1, 10}, {2, 20}, {3, 30}}
	c = start(0, old...)
	c.idle(2)
	c.apply(validatorUpdates(old, []member{{4, 15}, {5, 25}, {6, 35}, {7, 5}}))
	c.idle(3)
	cases = append(cases, c.done("full_replacement"))

	cases = append(cases, rpcRebuildDiverges())

	failures := []struct {
		name    string
		updates []update
	}{
		{"duplicate_update", members(member{2, 5}, member{2, 9})},
		{"remove_unknown", members(member{1, 10}, member{9, 0})},
		{"remove_all", members(member{1, 0}, member{2, 0}, member{3, 0})},
		{"negative_power", members(member{1, -1})},
		{"power_overflow", members(member{1, maxTotal + 1})},
		{"total_overflow", members(member{1, maxTotal})},
	}
	for _, e := range failures {
		c = start(0, member{1, 10}, member{2, 20}, member{3, 30})
		c.idle(1)
		c.fail(e.updates)
		cases = append(cases, c.done(e.name))
	}

	c, ok := genesis(0, members(member{1, 10}, member{2, 0}))
	if ok {
		panic("zero genesis power accepted")
	}
	cases = append(cases, c.done("genesis_zero_power"))
	return cases
}

// priorityDiff is the max-min spread of a set's priorities.
func priorityDiff(vals *types.ValidatorSet) int64 {
	lo, hi := int64(math.MaxInt64), int64(math.MinInt64)
	for _, v := range vals.Validators {
		lo, hi = min(lo, v.ProposerPriority), max(hi, v.ProposerPriority)
	}
	return hi - lo
}

// fuzz draws the random parts of the vectors from one seeded generator.
type fuzz struct{ *rand.Rand }

// committee draws distinct pool keys with powers 1..100.
func (f fuzz) committee(lo, hi int) []member {
	perm := f.Perm(len(pool) - 1)
	out := make([]member, lo+f.IntN(hi-lo+1))
	for i := range out {
		out[i] = member{perm[i] + 1, 1 + f.Int64N(100)}
	}
	return out
}

// next draws a committee switch: each member leaves with probability 3/10, changes its power
// with probability 3/10 and otherwise keeps it; up to 5 fresh keys join. It never empties the
// set.
func (f fuzz) next(old []member) []member {
	var out []member
	in := map[int]bool{}
	for _, m := range old {
		in[m.seed] = true
		switch r := f.IntN(10); {
		case r < 3:
		case r < 6:
			out = append(out, member{m.seed, 1 + f.Int64N(100)})
		default:
			out = append(out, m)
		}
	}
	adds := f.IntN(6)
	if len(out) == 0 && adds == 0 {
		adds = 1
	}
	for _, s := range f.Perm(len(pool) - 1) {
		if adds == 0 {
			break
		}
		if !in[s+1] {
			out = append(out, member{s + 1, 1 + f.Int64N(100)})
			adds--
		}
	}
	return out
}

// randomCases are sequences of 50 heights with a committee switch every 5 to 20 heights.
func randomCases() []vcase {
	f := fuzz{rand.New(rand.NewPCG(22280, 2026))}
	var cases []vcase
	for i := range 8 {
		current := f.committee(4, 10)
		c := start(f.Uint64N(1_000_000), current...)
		until := 5 + f.IntN(16)
		for range 50 {
			until--
			if until > 0 {
				c.idle(1)
				continue
			}
			nextCommittee := f.next(current)
			c.apply(validatorUpdates(current, nextCommittee))
			current = committee(c.next)
			until = 5 + f.IntN(16)
		}
		cases = append(cases, c.done(fmt.Sprintf("random_%d", i)))
	}
	return cases
}

// rpcRebuildDiverges finds the first seed s whose random committee (4 to 12 members),
// after 0 to 10 idle heights and one switch, has a height within 1,000 where the
// LoadValidators rebuild differs from the live state. LoadValidators reads the full set
// stored at the change (NextValidators after the switch's height, stored for that height + 2)
// and calls IncrementProposerPriority(k) once for the k heights since: one rescale for all
// k, where updateState rescales at every height.
func rpcRebuildDiverges() vcase {
	for seed := uint64(1); seed <= 100_000; seed++ {
		f := fuzz{rand.New(rand.NewPCG(22280, seed))}
		old := f.committee(4, 12)
		c := start(0, old...)
		c.idle(f.IntN(11))
		c.apply(validatorUpdates(old, f.next(old)))
		change := len(c.steps) - 1
		proto, err := c.next.ToProto()
		must(err)
		for k := 1; k <= 1000; k++ {
			c.idle(1)
			stored, err := types.ValidatorSetFromProto(proto)
			must(err)
			stored.IncrementProposerPriority(int32(k))
			if priorities(stored) == priorities(c.next) &&
				bytes.Equal(stored.Proposer.Address, c.next.Proposer.Address) {
				continue
			}
			bulkProposer := -1
			for i, v := range stored.Validators {
				if !bytes.Equal(v.Address, c.next.Validators[i].Address) {
					panic("rebuild reordered the set")
				}
				if bytes.Equal(v.Address, stored.Proposer.Address) {
					bulkProposer = i
				}
			}
			out := c.done("rpc_rebuild_diverges")
			out.RPCRebuild = &rpcRebuild{seed, change, change + k, k, priorities(stored), bulkProposer}
			return out
		}
	}
	panic("no LoadValidators divergence within 100,000 seeds")
}

func main() {
	cases := append(namedCases(), randomCases()...)
	output, err := json.MarshalIndent(struct {
		Source string   `json:"source"`
		Keys   []string `json:"keys"`
		Cases  []vcase  `json:"cases"`
	}{"github.com/cometbft/cometbft v0.40.0 types.ValidatorSet; secp256k1eth; Go 1.27.2; generate.sh; seeded PCG(22280, 2026) and PCG(22280, seed)", keyTable, cases}, "", "  ")
	must(err)
	must(os.WriteFile(os.Args[1], append(output, '\n'), 0o644))
}
