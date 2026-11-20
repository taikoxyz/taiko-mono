package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/cometbft/cometbft/crypto"
	cmtbytes "github.com/cometbft/cometbft/libs/bytes"
	cmtjson "github.com/cometbft/cometbft/libs/json"
	"github.com/cometbft/cometbft/libs/protoio"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
)

// signerStateSchema is the version of a chain's persisted signer state. Schema 2 keeps stock
// FilePV's HRS fields (height, round, step, signature, signbytes, encoded as stock FilePV
// encodes them) and adds, in the same file and the same atomic write, the RECOV-8.2-2
// continuity binding: the chain ID, the store instance the key is bound to, the minimum signable
// height and the replay binding of the last signature. The stock FilePV state that earlier
// signers wrote has no schema; it and every other schema are refused without migration.
const signerStateSchema = 2

// storeInstanceLen is the length of a store instance ID: 128 random bits as lowercase hex.
const storeInstanceLen = 32

// signerState is one chain_id's durable signer state (schema 2).
type signerState struct {
	Schema  int32  `json:"schema"`
	ChainID string `json:"chain_id"`
	// The stock FilePV HRS (RECOV-8.2-1, SYNC-9-13): the last signed height, round and step,
	// its canonical sign bytes and its signature.
	Height    int64             `json:"height"`
	Round     int32             `json:"round"`
	Step      int8              `json:"step"`
	Signature []byte            `json:"signature,omitempty"`
	SignBytes cmtbytes.HexBytes `json:"signbytes,omitempty"`
	// StoreInstance is the consensus store instance the key is bound to in this domain: empty
	// until the first session binds it, which happens before the first signature (RECOV-8.2-2).
	StoreInstance string `json:"store_instance"`
	// Floor is the minimum signable height. It never decreases, and every proposal and vote
	// below it, nil votes included, is refused before the HRS changes (RECOV-8.2-2).
	Floor int64 `json:"floor"`
	// Replay binds the last signature to its committed predecessor and to the flushed WAL
	// prefix that stock replay needs to repeat it; null when same-height replay is unavailable.
	Replay *replayBinding `json:"replay"`
}

// replayBinding is the RECOV-8.2-2 binding of the last signing decision at height H to the WAL
// that can replay it: the bytes following the predecessor end-height marker (`#ENDHEIGHT H-1`,
// or `#ENDHEIGHT 0` at the generation's initial height) through the input record that triggered
// the signature, by length and SHA-256, and the predecessor block's hash (empty at the
// generation's initial height).
type replayBinding struct {
	Marker      int64             `json:"marker"`
	Predecessor cmtbytes.HexBytes `json:"predecessor"`
	Length      int64             `json:"wal_length"`
	Digest      cmtbytes.HexBytes `json:"wal_sha256"`
}

// zeroState is chain's unsigned schema-2 state, as init-state creates it.
func zeroState(chain string) signerState {
	return signerState{Schema: signerStateSchema, ChainID: chain}
}

// encode is the state's one canonical encoding, written whole by every persistence.
func (s signerState) encode() []byte {
	raw, err := cmtjson.MarshalIndent(s, "", "  ")
	if err != nil {
		panic(err)
	}
	return raw
}

// zeroStateBytes is chain's unsigned state byte for byte, as init-state writes it.
func zeroStateBytes(chain string) []byte {
	return zeroState(chain).encode()
}

// signed reports whether the key has signed in this domain.
func (s signerState) signed() bool {
	return s.Height != 0 || s.Round != 0 || s.Step != 0 || len(s.Signature) != 0 || len(s.SignBytes) != 0
}

// validStoreInstance accepts exactly 32 lowercase hex characters.
func validStoreInstance(id string) bool {
	if len(id) != storeInstanceLen {
		return false
	}
	for _, r := range id {
		if !(r >= '0' && r <= '9' || r >= 'a' && r <= 'f') {
			return false
		}
	}
	return true
}

// stateFields are the keys of a schema-2 state; signature and signbytes appear only once signed.
var stateFields = map[string]bool{"schema": true, "chain_id": true, "height": true, "round": true, "step": true, "signature": false, "signbytes": false, "store_instance": true, "floor": true, "replay": true}

// parseSignerState decodes and authenticates chain's state. Unsigned means exactly the zero
// state, never an arbitrary HRS; a signed HRS must carry the registered key's signature over
// chain's canonical sign bytes for that height and round. Duplicate, unknown or missing keys, a
// missing or other schema (no migration), another chain ID, an invalid store instance, a floor
// above H + 1 and an inconsistent replay binding are all ambiguous.
func parseSignerState(raw []byte, chain string, pub crypto.PubKey) (signerState, error) {
	var s signerState
	if err := uniqueJSON(json.NewDecoder(bytes.NewReader(raw))); err != nil {
		return s, err
	}
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(raw, &fields); err != nil {
		return s, err
	}
	schema, ok := fields["schema"]
	if !ok {
		return s, fmt.Errorf("signer state has no schema; only schema %d is read and earlier states are refused without migration", signerStateSchema)
	}
	if string(bytes.TrimSpace(schema)) != fmt.Sprint(signerStateSchema) {
		return s, fmt.Errorf("signer state schema %s is not %d; refused without migration", bytes.TrimSpace(schema), signerStateSchema)
	}
	for key := range fields {
		if _, known := stateFields[key]; !known {
			return s, fmt.Errorf("unknown signer state field %q", key)
		}
	}
	for key, required := range stateFields {
		v, ok := fields[key]
		if required && !ok {
			return s, fmt.Errorf("missing signer state field %q", key)
		}
		if ok && key != "replay" && bytes.Equal(bytes.TrimSpace(v), []byte("null")) {
			return s, fmt.Errorf("null signer state field %q", key)
		}
	}
	if err := cmtjson.Unmarshal(raw, &s); err != nil {
		return s, err
	}
	if s.ChainID != chain {
		return s, fmt.Errorf("signer state is for chain %q, not %s", s.ChainID, chain)
	}
	if s.StoreInstance != "" && !validStoreInstance(s.StoreInstance) {
		return s, errors.New("invalid store instance ID")
	}
	if s.Floor < 0 {
		return s, errors.New("negative height floor")
	}
	if !s.signed() {
		if s.Floor != 0 || s.Replay != nil {
			return s, errors.New("an unsigned state carries no floor or replay binding")
		}
		return s, nil
	}
	if err := authenticateHRS(s, chain, pub); err != nil {
		return s, err
	}
	// Binding precedes the first signature, and a floor is raised to at most H + 1 at a fence;
	// every later signature is at or above it.
	if s.StoreInstance == "" {
		return s, errors.New("a signed state must be bound to a store instance")
	}
	if s.Floor > s.Height+1 {
		return s, fmt.Errorf("height floor %d is above H + 1 = %d", s.Floor, s.Height+1)
	}
	if r := s.Replay; r != nil {
		if r.Marker < 0 || r.Marker >= s.Height || r.Length < 0 || len(r.Digest) != 32 || (len(r.Predecessor) != 0 && len(r.Predecessor) != 32) {
			return s, errors.New("invalid replay binding")
		}
	}
	return s, nil
}

// authenticateHRS checks a signed HRS with stock codecs: the registered key's signature over the
// canonical sign bytes, whose type, chain ID, height and round must match the HRS.
func authenticateHRS(s signerState, chain string, pub crypto.PubKey) error {
	if s.Height <= 0 || s.Round < 0 || len(s.Signature) == 0 || len(s.SignBytes) == 0 || !pub.VerifySignature(s.SignBytes, s.Signature) {
		return errors.New("ambiguous or unauthentic HRS")
	}
	var domain string
	var height, round int64
	switch s.Step {
	case stepPropose:
		var p tm.CanonicalProposal
		if err := protoio.UnmarshalDelimited(s.SignBytes, &p); err != nil {
			return err
		}
		if p.Type != tm.ProposalType {
			return errors.New("invalid proposal HRS")
		}
		domain, height, round = p.ChainID, p.Height, p.Round
	case stepPrevote, stepPrecommit:
		var v tm.CanonicalVote
		if err := protoio.UnmarshalDelimited(s.SignBytes, &v); err != nil {
			return err
		}
		if (s.Step == stepPrevote && v.Type != tm.PrevoteType) || (s.Step == stepPrecommit && v.Type != tm.PrecommitType) {
			return errors.New("invalid vote HRS")
		}
		domain, height, round = v.ChainID, v.Height, v.Round
	default:
		return errors.New("invalid HRS step")
	}
	if domain != chain || height != s.Height || round != int64(s.Round) {
		return errors.New("signed HRS domain/height/round mismatch")
	}
	return nil
}

// Stock FilePV's HRS steps.
const (
	stepPropose   int8 = 1
	stepPrevote   int8 = 2
	stepPrecommit int8 = 3
)
