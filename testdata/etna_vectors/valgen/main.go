// Command valgen computes Etna validator-state vectors (spec appendix A, ENC-A-29a) with stock
// CometBFT v0.40.0.
//
// It reads on stdin
//
//	{"keys": [{"name", "private_key"}],
//	 "chains": [{"name", "chain_id", "start_height", "end_height", "genesis_time",
//	             "genesis": [{"key", "power"}],
//	             "updates": [{"height", "changes": [{"key", "power"}]}]}]}
//
// and writes on stdout
//
//	{"keys": [{"name", "public_key", "address"}],
//	 "chains": [{"name", "states": [{"height", "current", "current_proposer", "next",
//	             "next_proposer", "preimage", "hash"}]}]}
//
// where each set is a list of {"key", "ck_prefix", "ck_x", "voting_power", "proposer_priority"} in
// CometBFT's set order. Integers are decimal strings.
//
// Every state comes from CometBFT's own code; nothing that produces an output is reimplemented:
//
//   - The state at a chain's start height o is state.MakeGenesisState of a genesis doc with
//     initial_height o + 1 and the chain's genesis validators (state/state.go:329-367: Validators is
//     types.NewValidatorSet(vals) and NextValidators is types.NewValidatorSet(vals)
//     .CopyIncrementProposerPriority(1), lines 344-345). The Etna app's InitChain returns no
//     validators (spec RECOV-8-11); if it did, consensus/replay.go:349-355 would build the two sets
//     the same way.
//   - Every later height h is committed with BlockExecutor.ApplyVerifiedBlock
//     (state/execution.go:255-260) against an ABCI app, run through a local proxy client, whose
//     FinalizeBlock returns the chain's validator updates for h. applyBlock (lines 288-389) checks
//     the updates' key type against the consensus params, converts them with
//     types.PB2TM.ValidatorUpdates and calls the unexported updateState (lines 737-804).
//     ApplyVerifiedBlock only skips block validation; the blocks carry absent LastCommit
//     signatures, which no validator-state rule reads.
//
// As a check that the vectors mean what the spec says, every height is also recomputed by
// mirroring updateState's three validator-set lines with exported CometBFT functions
// (execution.go:746 NextValidators.Copy, 750-757 UpdateWithChangeSet, 760
// IncrementProposerPriority(1), and 795-797 Validators = old NextValidators). That mirror must
// agree with ApplyVerifiedBlock, and so must the same switch written as the full new committee
// (every member at its power and every leaving member at 0) instead of the changes alone.
//
// generate.py runs it with `go run .` from this directory; no other module imports it.
package main

import (
	"bytes"
	"context"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math/big"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"

	dbm "github.com/cometbft/cometbft-db"
	abci "github.com/cometbft/cometbft/abci/types"
	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	"github.com/cometbft/cometbft/libs/log"
	"github.com/cometbft/cometbft/mempool"
	"github.com/cometbft/cometbft/proxy"
	sm "github.com/cometbft/cometbft/state"
	"github.com/cometbft/cometbft/store"
	"github.com/cometbft/cometbft/types"
	"golang.org/x/crypto/sha3"
)

type keyIn struct {
	Name       string `json:"name"`
	PrivateKey string `json:"private_key"`
}

type member struct {
	Key   string `json:"key"`
	Power string `json:"power"`
}

type update struct {
	Height  string   `json:"height"`
	Changes []member `json:"changes"`
}

type chainIn struct {
	Name        string   `json:"name"`
	ChainID     string   `json:"chain_id"`
	StartHeight string   `json:"start_height"`
	EndHeight   string   `json:"end_height"`
	GenesisTime string   `json:"genesis_time"`
	Genesis     []member `json:"genesis"`
	Updates     []update `json:"updates"`
}

type input struct {
	Keys   []keyIn   `json:"keys"`
	Chains []chainIn `json:"chains"`
}

type keyOut struct {
	Name      string `json:"name"`
	PublicKey string `json:"public_key"`
	Address   string `json:"address"`
}

type entryOut struct {
	Key              string `json:"key"`
	CkPrefix         string `json:"ck_prefix"`
	CkX              string `json:"ck_x"`
	VotingPower      string `json:"voting_power"`
	ProposerPriority string `json:"proposer_priority"`
}

type stateOut struct {
	Height          string     `json:"height"`
	Current         []entryOut `json:"current"`
	CurrentProposer string     `json:"current_proposer"`
	Next            []entryOut `json:"next"`
	NextProposer    string     `json:"next_proposer"`
	Preimage        string     `json:"preimage"`
	Hash            string     `json:"hash"`
}

type chainOut struct {
	Name   string     `json:"name"`
	States []stateOut `json:"states"`
}

type output struct {
	Keys   []keyOut   `json:"keys"`
	Chains []chainOut `json:"chains"`
}

// keyring maps key names to secp256k1eth public keys and addresses back to names.
type keyring struct {
	pub    map[string]secp256k1eth.PubKey
	byAddr map[string]string
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "valgen:", err)
		os.Exit(1)
	}
}

func run() error {
	dec := json.NewDecoder(os.Stdin)
	dec.DisallowUnknownFields()
	var in input
	if err := dec.Decode(&in); err != nil {
		return fmt.Errorf("decode input: %w", err)
	}
	ring := keyring{pub: map[string]secp256k1eth.PubKey{}, byAddr: map[string]string{}}
	out := output{Keys: make([]keyOut, 0, len(in.Keys))}
	for _, k := range in.Keys {
		raw, err := decodeHex(k.PrivateKey, 32)
		if err != nil {
			return fmt.Errorf("key %s: %w", k.Name, err)
		}
		pub := secp256k1eth.PrivKey(raw).PubKey().(secp256k1eth.PubKey)
		if _, dup := ring.pub[k.Name]; dup {
			return fmt.Errorf("duplicate key name %s", k.Name)
		}
		addr := string(pub.Address())
		if _, dup := ring.byAddr[addr]; dup {
			return fmt.Errorf("key %s repeats an address", k.Name)
		}
		ring.pub[k.Name] = pub
		ring.byAddr[addr] = k.Name
		out.Keys = append(out.Keys, keyOut{
			Name:      k.Name,
			PublicKey: "0x" + hex.EncodeToString(pub.Bytes()),
			Address:   "0x" + hex.EncodeToString(pub.Address()),
		})
	}
	for _, c := range in.Chains {
		states, err := runChain(ring, c)
		if err != nil {
			return fmt.Errorf("chain %s: %w", c.Name, err)
		}
		out.Chains = append(out.Chains, chainOut{Name: c.Name, States: states})
	}
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", " ")
	return enc.Encode(out)
}

// app is the ABCI application: FinalizeBlock returns the scripted validator updates of the height.
type app struct {
	abci.BaseApplication
	updates map[int64][]abci.ValidatorUpdate
}

func (a *app) FinalizeBlock(
	ctx context.Context, req *abci.RequestFinalizeBlock,
) (*abci.ResponseFinalizeBlock, error) {
	res, err := a.BaseApplication.FinalizeBlock(ctx, req)
	if err != nil {
		return nil, err
	}
	res.ValidatorUpdates = a.updates[req.Height]
	return res, nil
}

func runChain(ring keyring, c chainIn) ([]stateOut, error) {
	start, err := strconv.ParseInt(c.StartHeight, 10, 64)
	if err != nil {
		return nil, fmt.Errorf("start_height: %w", err)
	}
	end, err := strconv.ParseInt(c.EndHeight, 10, 64)
	if err != nil || end < start {
		return nil, fmt.Errorf("end_height %q", c.EndHeight)
	}
	genesisTime, err := strconv.ParseInt(c.GenesisTime, 10, 64)
	if err != nil {
		return nil, fmt.Errorf("genesis_time: %w", err)
	}

	params := types.DefaultConsensusParams()
	params.Validator.PubKeyTypes = []string{secp256k1eth.KeyType}
	genDoc := &types.GenesisDoc{
		ChainID:         c.ChainID,
		GenesisTime:     time.Unix(genesisTime, 0).UTC(),
		InitialHeight:   start + 1,
		ConsensusParams: params,
	}
	for _, m := range c.Genesis {
		pub, power, err := ring.member(m)
		if err != nil {
			return nil, fmt.Errorf("genesis: %w", err)
		}
		genDoc.Validators = append(genDoc.Validators, types.GenesisValidator{
			PubKey: pub, Power: power, Name: m.Key,
		})
	}
	state, err := sm.MakeGenesisState(genDoc)
	if err != nil {
		return nil, err
	}

	scripted := map[int64][]abci.ValidatorUpdate{}
	for _, u := range c.Updates {
		h, err := strconv.ParseInt(u.Height, 10, 64)
		if err != nil || h <= start || h > end {
			return nil, fmt.Errorf("update height %q", u.Height)
		}
		if _, dup := scripted[h]; dup {
			return nil, fmt.Errorf("two updates at %d", h)
		}
		for _, m := range u.Changes {
			pub, power, err := ring.member(m)
			if err != nil {
				return nil, fmt.Errorf("update %d: %w", h, err)
			}
			scripted[h] = append(scripted[h], types.TM2PB.NewValidatorUpdate(pub, power))
		}
	}

	stateStore := sm.NewStore(dbm.NewMemDB(), sm.StoreOptions{})
	if err := stateStore.Save(state); err != nil {
		return nil, err
	}
	conns := proxy.NewAppConns(proxy.NewLocalClientCreator(&app{updates: scripted}), proxy.NopMetrics())
	if err := conns.Start(); err != nil {
		return nil, err
	}
	defer func() { _ = conns.Stop() }()
	exec := sm.NewBlockExecutor(
		stateStore, log.NewNopLogger(), conns.Consensus(), &mempool.NopMempool{},
		sm.EmptyEvidencePool{}, store.NewBlockStore(dbm.NewMemDB()),
	)

	first, err := ring.state(start, state)
	if err != nil {
		return nil, err
	}
	states := []stateOut{first}
	for h := start + 1; h <= end; h++ {
		changes, err := types.PB2TM.ValidatorUpdates(scripted[h])
		if err != nil {
			return nil, err
		}
		// The mirror's sets, from the update as returned and as the whole new committee.
		var mirrored [2][2]*types.ValidatorSet
		for i, form := range [][]*types.Validator{changes, fullCommittee(state.NextValidators, changes)} {
			cur, nxt, err := mirror(state, form)
			if err != nil {
				return nil, fmt.Errorf("height %d: mirror %d: %w", h, i, err)
			}
			mirrored[i] = [2]*types.ValidatorSet{cur, nxt}
		}

		block, blockID, err := makeBlock(state, h, genesisTime)
		if err != nil {
			return nil, fmt.Errorf("height %d: %w", h, err)
		}
		next, err := exec.ApplyVerifiedBlock(state, blockID, block)
		if err != nil {
			return nil, fmt.Errorf("height %d: %w", h, err)
		}
		if next.LastBlockHeight != h {
			return nil, fmt.Errorf("height %d: LastBlockHeight %d", h, next.LastBlockHeight)
		}
		for i, sets := range mirrored {
			if !sameSet(sets[0], next.Validators) || !sameSet(sets[1], next.NextValidators) {
				return nil, fmt.Errorf("height %d: updateState mirror %d differs", h, i)
			}
		}
		state = next
		out, err := ring.state(h, state)
		if err != nil {
			return nil, err
		}
		states = append(states, out)
	}
	return states, nil
}

// makeBlock builds block h on state. ApplyVerifiedBlock does not validate it; FinalizeBlock and
// buildLastCommitInfo only need its height and a LastCommit as large as the set that signed h - 1.
func makeBlock(state sm.State, h, genesisTime int64) (*types.Block, types.BlockID, error) {
	lastCommit := &types.Commit{}
	if h > state.InitialHeight {
		lastCommit = &types.Commit{
			Height:  h - 1,
			BlockID: state.LastBlockID,
		}
		for range state.LastValidators.Validators {
			lastCommit.Signatures = append(lastCommit.Signatures, types.NewCommitSigAbsent())
		}
	}
	block := types.MakeBlock(h, nil, lastCommit, nil)
	block.Populate(
		state.Version.Consensus, state.ChainID,
		time.Unix(genesisTime+h-state.InitialHeight, 0).UTC(), state.LastBlockID,
		state.Validators.Hash(), state.NextValidators.Hash(),
		state.ConsensusParams.Hash(), state.AppHash, state.LastResultsHash,
		state.Validators.GetProposer().Address,
	)
	parts, err := block.MakePartSet(types.BlockPartSizeBytes)
	if err != nil {
		return nil, types.BlockID{}, err
	}
	return block, types.BlockID{Hash: block.Hash(), PartSetHeader: parts.Header()}, nil
}

// mirror recomputes the two sets updateState installs (execution.go:746-760, 795-796).
func mirror(state sm.State, changes []*types.Validator) (*types.ValidatorSet, *types.ValidatorSet, error) {
	nValSet := state.NextValidators.Copy()
	if len(changes) > 0 {
		if err := nValSet.UpdateWithChangeSet(changes); err != nil {
			return nil, nil, err
		}
	}
	nValSet.IncrementProposerPriority(1)
	return state.NextValidators.Copy(), nValSet, nil
}

// fullCommittee writes the change set as the whole new committee: every member of the pending set
// after the changes at its power, and every member the changes remove at power 0. Both forms leave
// CometBFT in the same state (computeNewPriorities keeps an unchanged member's priority).
func fullCommittee(pending *types.ValidatorSet, changes []*types.Validator) []*types.Validator {
	if len(changes) == 0 {
		return nil
	}
	power := map[string]int64{}
	keys := map[string]*types.Validator{}
	for _, v := range append(append([]*types.Validator{}, pending.Validators...), changes...) {
		power[string(v.Address)] = v.VotingPower
		keys[string(v.Address)] = v
	}
	addrs := make([]string, 0, len(power))
	for a := range power {
		addrs = append(addrs, a)
	}
	sort.Strings(addrs)
	out := make([]*types.Validator, 0, len(addrs))
	for _, a := range addrs {
		out = append(out, types.NewValidator(keys[a].PubKey, power[a]))
	}
	return out
}

func sameSet(a, b *types.ValidatorSet) bool {
	if len(a.Validators) != len(b.Validators) {
		return false
	}
	for i := range a.Validators {
		x, y := a.Validators[i], b.Validators[i]
		if !bytes.Equal(x.Address, y.Address) || x.VotingPower != y.VotingPower ||
			x.ProposerPriority != y.ProposerPriority {
			return false
		}
	}
	return bytes.Equal(a.Proposer.Address, b.Proposer.Address)
}

func (r keyring) member(m member) (secp256k1eth.PubKey, int64, error) {
	pub, ok := r.pub[m.Key]
	if !ok {
		return nil, 0, fmt.Errorf("unknown key %q", m.Key)
	}
	power, err := strconv.ParseInt(m.Power, 10, 64)
	if err != nil || power < 0 {
		return nil, 0, fmt.Errorf("power %q of %s", m.Power, m.Key)
	}
	return pub, power, nil
}

// state is valStateHash(x) of the sets CometBFT holds after committing height x.
func (r keyring) state(x int64, s sm.State) (stateOut, error) {
	current, currentProposer, err := r.set(s.Validators)
	if err != nil {
		return stateOut{}, fmt.Errorf("height %d current: %w", x, err)
	}
	next, nextProposer, err := r.set(s.NextValidators)
	if err != nil {
		return stateOut{}, fmt.Errorf("height %d next: %w", x, err)
	}
	preimage := encode(x, s.Validators, currentProposer, s.NextValidators, nextProposer)
	digest := sha3.NewLegacyKeccak256()
	digest.Write(preimage)
	return stateOut{
		Height:          strconv.FormatInt(x, 10),
		Current:         current,
		CurrentProposer: strconv.Itoa(currentProposer),
		Next:            next,
		NextProposer:    strconv.Itoa(nextProposer),
		Preimage:        "0x" + hex.EncodeToString(preimage),
		Hash:            "0x" + hex.EncodeToString(digest.Sum(nil)),
	}, nil
}

// set lists a validator set in CometBFT's order and finds the index of its stored proposer
// (ValidatorSet.Proposer, which GetProposer returns without recomputing once it is set).
func (r keyring) set(vs *types.ValidatorSet) ([]entryOut, int, error) {
	if vs.Proposer == nil {
		return nil, 0, fmt.Errorf("no stored proposer")
	}
	proposer, _ := vs.GetByAddress(vs.Proposer.Address)
	if proposer < 0 {
		return nil, 0, fmt.Errorf("stored proposer is not a member")
	}
	if !sort.IsSorted(types.ValidatorsByVotingPower(vs.Validators)) {
		return nil, 0, fmt.Errorf("set is not in ValidatorsByVotingPower order")
	}
	entries := make([]entryOut, 0, len(vs.Validators))
	for _, v := range vs.Validators {
		name, ok := r.byAddr[string(v.Address)]
		if !ok {
			return nil, 0, fmt.Errorf("unknown validator %X", v.Address)
		}
		pub := v.PubKey.Bytes()
		entries = append(entries, entryOut{
			Key:              name,
			CkPrefix:         strconv.Itoa(int(pub[0])),
			CkX:              "0x" + hex.EncodeToString(pub[1:]),
			VotingPower:      strconv.FormatInt(v.VotingPower, 10),
			ProposerPriority: strconv.FormatInt(v.ProposerPriority, 10),
		})
	}
	return entries, int(proposer), nil
}

// encode is ENC-A-29a's preimage: abi.encode(bytes32("ETNA_VAL_STATE_V1"), uint256(x), current,
// uint256(currentProposer), next, uint256(nextProposer)) with each set a dynamic
// (uint8, bytes32, uint64, int64)[] array.
func encode(x int64, current *types.ValidatorSet, cp int, next *types.ValidatorSet, np int) []byte {
	var out []byte
	tag := make([]byte, 32)
	copy(tag, "ETNA_VAL_STATE_V1")
	currentLen := 32 + 128*len(current.Validators)
	out = append(out, tag...)
	out = append(out, uword(big.NewInt(x))...)
	out = append(out, uword(big.NewInt(6*32))...)
	out = append(out, uword(big.NewInt(int64(cp)))...)
	out = append(out, uword(big.NewInt(int64(6*32+currentLen)))...)
	out = append(out, uword(big.NewInt(int64(np)))...)
	for _, set := range []*types.ValidatorSet{current, next} {
		out = append(out, uword(big.NewInt(int64(len(set.Validators))))...)
		for _, v := range set.Validators {
			pub := v.PubKey.Bytes()
			out = append(out, uword(big.NewInt(int64(pub[0])))...)
			out = append(out, pub[1:]...)
			out = append(out, uword(new(big.Int).SetUint64(uint64(v.VotingPower)))...)
			out = append(out, sword(v.ProposerPriority)...)
		}
	}
	return out
}

// uword is a non-negative integer as a 32-byte big-endian word.
func uword(v *big.Int) []byte {
	if v.Sign() < 0 || v.BitLen() > 256 {
		panic("uword out of range")
	}
	return v.FillBytes(make([]byte, 32))
}

// sword is an int64 sign-extended to 32 bytes.
func sword(v int64) []byte {
	out := make([]byte, 32)
	if v < 0 {
		for i := range out {
			out[i] = 0xff
		}
	}
	binary.BigEndian.PutUint64(out[24:], uint64(v))
	return out
}

func decodeHex(s string, size int) ([]byte, error) {
	if !strings.HasPrefix(s, "0x") {
		return nil, fmt.Errorf("%q has no 0x prefix", s)
	}
	b, err := hex.DecodeString(s[2:])
	if err != nil {
		return nil, err
	}
	if len(b) != size {
		return nil, fmt.Errorf("%q is %d bytes, want %d", s, len(b), size)
	}
	return b, nil
}
