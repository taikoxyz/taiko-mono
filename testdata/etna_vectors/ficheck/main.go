// Command ficheck checks the Etna forced-inclusion eligibility vectors against go-ethereum.
//
// Usage: go run . ../vectors.json
//
// For each case in fi_eligibility it decodes the raw bytes with types.Transaction.UnmarshalBinary
// and enforces what go-ethereum can confirm about the case's rule (Etna spec 7.2):
//
//   - eligible: decodes, re-encodes to the same bytes, is type 0, 1, 2 or 4, has a typed chain id
//     equal to l2_chain_id, a sender under LatestSignerForChainID(l2_chain_id) and gas at most
//     l2_block_gas_limit;
//   - noncanonical: fails to decode, or re-encodes to different bytes;
//   - type: fails to decode, or is type 3 and otherwise eligible;
//   - chain_id: decodes and re-encodes to the same bytes, has no sender under l2_chain_id but one
//     under its own chain id, and gas within the limit;
//   - signature: fails to decode or has no sender; a decoded case re-encodes to the same bytes and
//     has the L2 chain id and gas within the limit;
//   - gas_limit: decodes, re-encodes to the same bytes and is eligible apart from its gas;
//   - width: no constraint (go-ethereum reads some fields into unbounded big integers).
//
// For every ineligible case a note records go-ethereum's verdict: rejected at decoding, or decoded
// with or without a sender under l2_chain_id. It prints every violation and exits 1 if there is
// any; otherwise it prints the notes. generate.py runs it from this directory after writing
// vectors.json; no other module imports it.
package main

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"os"
	"runtime/debug"
	"strconv"
	"strings"

	"github.com/ethereum/go-ethereum/core/types"
)

const gethPath = "github.com/ethereum/go-ethereum"

type fiCase struct {
	Name     string `json:"name"`
	Raw      string `json:"raw"`
	Eligible bool   `json:"eligible"`
	Rule     string `json:"rule"`
}

type vectors struct {
	FI *struct {
		L2ChainID       string   `json:"l2_chain_id"`
		L2BlockGasLimit string   `json:"l2_block_gas_limit"`
		Cases           []fiCase `json:"cases"`
	} `json:"fi_eligibility"`
}

type checker struct {
	chainID  *big.Int
	gasLimit uint64
	signer   types.Signer
}

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintln(os.Stderr, "usage: ficheck <vectors.json>")
		os.Exit(2)
	}
	cases, violations, notes, err := run(os.Args[1])
	if err != nil {
		fmt.Fprintln(os.Stderr, "ficheck:", err)
		os.Exit(1)
	}
	for _, v := range violations {
		fmt.Println(v)
	}
	if len(violations) > 0 {
		fmt.Printf("ficheck: %d violation(s) in %d cases against %s\n",
			len(violations), cases, gethVersion())
		os.Exit(1)
	}
	fmt.Printf("ficheck: %d cases agree with %s\n", cases, gethVersion())
	for _, n := range notes {
		fmt.Println(n)
	}
}

func run(path string) (int, []string, []string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return 0, nil, nil, err
	}
	var v vectors
	if err := json.Unmarshal(data, &v); err != nil {
		return 0, nil, nil, fmt.Errorf("decode %s: %w", path, err)
	}
	if v.FI == nil || len(v.FI.Cases) == 0 {
		return 0, nil, nil, errors.New("no fi_eligibility cases")
	}
	chainID, ok := new(big.Int).SetString(v.FI.L2ChainID, 10)
	if !ok || chainID.Sign() <= 0 {
		return 0, nil, nil, fmt.Errorf("l2_chain_id %q is not a positive decimal", v.FI.L2ChainID)
	}
	gasLimit, err := strconv.ParseUint(v.FI.L2BlockGasLimit, 10, 64)
	if err != nil {
		return 0, nil, nil, fmt.Errorf("l2_block_gas_limit: %w", err)
	}
	c := checker{chainID: chainID, gasLimit: gasLimit, signer: types.LatestSignerForChainID(chainID)}

	var violations, notes []string
	seen := make(map[string]bool)
	for _, tc := range v.FI.Cases {
		if seen[tc.Name] {
			violations = append(violations, tc.Name+": duplicate case name")
		}
		seen[tc.Name] = true
		problems, note := c.check(tc)
		for _, problem := range problems {
			violations = append(violations, fmt.Sprintf("%s (%s): %s", tc.Name, tc.Rule, problem))
		}
		if note != "" {
			notes = append(notes, fmt.Sprintf("note: %s (%s): %s", tc.Name, tc.Rule, note))
		}
	}
	return len(v.FI.Cases), violations, notes, nil
}

// problems collects the violations of one case.
type problems []string

func (p *problems) add(format string, args ...any) {
	*p = append(*p, fmt.Sprintf(format, args...))
}

// check returns the ways go-ethereum's view of a case contradicts the case's rule, and for an
// ineligible case a note on how go-ethereum treats it.
func (c checker) check(tc fiCase) (problems, string) {
	var p problems
	raw, err := decodeHex(tc.Raw)
	if err != nil {
		p.add("raw: %v", err)
		return p, ""
	}
	if tc.Eligible != (tc.Rule == "eligible") {
		p.add("eligible = %t disagrees with the rule", tc.Eligible)
	}
	tx := new(types.Transaction)
	decodeErr := tx.UnmarshalBinary(raw)

	switch tc.Rule {
	case "eligible":
		if c.decodes(&p, tx, raw, decodeErr) {
			c.supportedType(&p, tx)
			c.l2ChainID(&p, tx)
			c.sender(&p, tx)
			c.gasWithinLimit(&p, tx)
		}
	case "noncanonical":
		if decodeErr == nil && reencodes(tx, raw) {
			p.add("decodes and re-encodes to the same bytes")
		}
	case "type":
		if decodeErr == nil {
			if tx.Type() != types.BlobTxType {
				p.add("decodes as supported type %d", tx.Type())
			} else if c.decodes(&p, tx, raw, nil) {
				c.l2ChainID(&p, tx)
				c.sender(&p, tx)
				c.gasWithinLimit(&p, tx)
			}
		}
	case "chain_id":
		if c.decodes(&p, tx, raw, decodeErr) {
			c.supportedType(&p, tx)
			if _, err := types.Sender(c.signer, tx); !errors.Is(err, types.ErrInvalidChainId) {
				p.add("sender under the L2 chain id: want ErrInvalidChainId, got %v", err)
			}
			if _, err := types.Sender(types.LatestSignerForChainID(tx.ChainId()), tx); err != nil {
				p.add("no sender under its own chain id %d: %v", tx.ChainId(), err)
			}
			c.gasWithinLimit(&p, tx)
		}
	case "signature":
		if decodeErr == nil {
			if from, err := types.Sender(c.signer, tx); err == nil {
				p.add("sender %s recovers", from.Hex())
			}
			c.decodes(&p, tx, raw, nil)
			c.supportedType(&p, tx)
			c.l2ChainID(&p, tx)
			c.gasWithinLimit(&p, tx)
		}
	case "gas_limit":
		if c.decodes(&p, tx, raw, decodeErr) {
			c.supportedType(&p, tx)
			c.l2ChainID(&p, tx)
			c.sender(&p, tx)
			if tx.Gas() <= c.gasLimit {
				p.add("gas %d is within the limit %d", tx.Gas(), c.gasLimit)
			}
		}
	case "width":
		// Spec 7.2 widths are stricter than go-ethereum's decoder for big-integer fields.
	default:
		p.add("unknown rule")
	}
	if tc.Rule == "eligible" {
		return p, ""
	}
	return p, verdict(c.signer, tx, raw, decodeErr)
}

// verdict says whether go-ethereum rejects a case at decoding or decodes it, and whether it then
// recovers a sender under the L2 chain id.
func verdict(signer types.Signer, tx *types.Transaction, raw []byte, decodeErr error) string {
	if decodeErr != nil {
		return fmt.Sprintf("go-ethereum rejects it at decoding: %v", decodeErr)
	}
	same := reencodes(tx, raw)
	from, err := types.Sender(signer, tx)
	if err != nil {
		return fmt.Sprintf("go-ethereum decodes it (re-encodes: %t) but finds no sender: %v", same, err)
	}
	return fmt.Sprintf("go-ethereum decodes it (re-encodes: %t) with sender %s", same, from.Hex())
}

// decodes reports whether the transaction decoded and re-encodes to exactly raw.
func (c checker) decodes(p *problems, tx *types.Transaction, raw []byte, decodeErr error) bool {
	if decodeErr != nil {
		p.add("does not decode: %v", decodeErr)
		return false
	}
	if !reencodes(tx, raw) {
		p.add("re-encodes to different bytes")
		return false
	}
	return true
}

func (c checker) supportedType(p *problems, tx *types.Transaction) {
	switch tx.Type() {
	case types.LegacyTxType, types.AccessListTxType, types.DynamicFeeTxType, types.SetCodeTxType:
	default:
		p.add("type %d is not eligible", tx.Type())
	}
}

func (c checker) l2ChainID(p *problems, tx *types.Transaction) {
	if tx.Type() != types.LegacyTxType && tx.ChainId().Cmp(c.chainID) != 0 {
		p.add("chain id %d, want %d", tx.ChainId(), c.chainID)
	}
}

func (c checker) sender(p *problems, tx *types.Transaction) {
	if _, err := types.Sender(c.signer, tx); err != nil {
		p.add("no sender: %v", err)
	}
}

func (c checker) gasWithinLimit(p *problems, tx *types.Transaction) {
	if tx.Gas() > c.gasLimit {
		p.add("gas %d is above the limit %d", tx.Gas(), c.gasLimit)
	}
}

func reencodes(tx *types.Transaction, raw []byte) bool {
	enc, err := tx.MarshalBinary()
	return err == nil && bytes.Equal(enc, raw)
}

func decodeHex(s string) ([]byte, error) {
	if !strings.HasPrefix(s, "0x") {
		return nil, fmt.Errorf("%q has no 0x prefix", s)
	}
	return hex.DecodeString(s[2:])
}

// gethVersion names the go-ethereum module this binary was built with.
func gethVersion() string {
	if info, ok := debug.ReadBuildInfo(); ok {
		for _, dep := range info.Deps {
			if dep.Path == gethPath {
				return gethPath + " " + dep.Version
			}
		}
	}
	return gethPath
}
