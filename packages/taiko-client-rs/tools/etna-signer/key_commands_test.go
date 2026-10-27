package main

import (
	"bytes"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"math/big"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/cometbft/cometbft/crypto/ed25519"
	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	"github.com/cometbft/cometbft/privval"
	"github.com/decred/dcrd/dcrec/secp256k1/v4"
	"github.com/decred/dcrd/dcrec/secp256k1/v4/ecdsa"
	"golang.org/x/crypto/sha3"
)

func commandJSON(t *testing.T, binary string, args ...string) map[string]string {
	t.Helper()
	var stderr bytes.Buffer
	cmd := exec.Command(binary, args...)
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		t.Fatalf("%s: %v %s", args[0], err, stderr.String())
	}
	var result map[string]string
	if err = json.Unmarshal(out, &result); err != nil {
		t.Fatalf("non-JSON stdout: %s", out)
	}
	return result
}

func TestKeygenCreatesExclusiveNativeFilePV(t *testing.T) {
	binary := buildSigner(t)
	dir := t.TempDir()
	key, state := filepath.Join(dir, "key.json"), filepath.Join(dir, "state.json")
	out := commandJSON(t, binary, "keygen", "--priv-key", key, "--priv-state", state)
	pv := privval.LoadFilePV(key, state)
	if pv.Key.PrivKey.Type() != secp256k1eth.KeyType || len(pv.Key.PubKey.Bytes()) != 33 {
		t.Fatal("bootstrap did not create a stock native key")
	}
	if len(out) != 2 || out["publicKey"] != "0x"+hex.EncodeToString(pv.Key.PubKey.Bytes()) || out["address"] != "0x"+hex.EncodeToString(pv.Key.Address) {
		t.Fatalf("unexpected public output: %v", out)
	}
	if pv.LastSignState.Height != 0 || pv.LastSignState.Round != 0 || pv.LastSignState.Step != 0 || len(pv.LastSignState.Signature) != 0 || len(pv.LastSignState.SignBytes) != 0 {
		t.Fatal("new bootstrap state is not empty")
	}
	for _, p := range []string{key, state} {
		info, err := os.Stat(p)
		if err != nil || info.Mode().Perm() != 0600 {
			t.Fatalf("signing file permissions: %v %v", info, err)
		}
	}
	for _, which := range []string{"key", "state", "both", "same", "symlink"} {
		t.Run(which, func(t *testing.T) {
			dir := t.TempDir()
			k, s := filepath.Join(dir, "key"), filepath.Join(dir, "state")
			sentinel := []byte("must survive")
			if which == "key" || which == "both" {
				os.WriteFile(k, sentinel, 0600)
			}
			if which == "state" || which == "both" {
				os.WriteFile(s, sentinel, 0600)
			}
			if which == "same" {
				s = k
			}
			if which == "symlink" {
				os.Symlink(filepath.Join(dir, "absent"), k)
			}
			cmd := exec.Command(binary, "keygen", "--priv-key", k, "--priv-state", s)
			if output, err := cmd.Output(); err == nil || len(output) != 0 {
				t.Fatalf("existing/alias output accepted: %v %s", err, output)
			}
			for _, p := range []string{k, s} {
				b, err := os.ReadFile(p)
				if err == nil && !bytes.Equal(b, sentinel) {
					t.Fatal("exclusive failure replaced existing output")
				}
			}
			if which == "key" || which == "symlink" {
				if _, err := os.Lstat(s); !os.IsNotExist(err) {
					t.Fatal("failure left new state")
				}
			}
			if which == "state" || which == "same" {
				if _, err := os.Lstat(k); !os.IsNotExist(err) {
					t.Fatal("failure left new key")
				}
			}
		})
	}
}

func testKeccak(b []byte) []byte { h := sha3.NewLegacyKeccak256(); h.Write(b); return h.Sum(nil) }
func fromHex(t *testing.T, s string) []byte {
	t.Helper()
	b, err := hex.DecodeString(strings.TrimPrefix(s, "0x"))
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func TestPopMatchesCanonicalContractVectorsAndRecoversEthereumAddress(t *testing.T) {
	binary := buildSigner(t)
	// This is the schema-4 fixture copied verbatim from the pinned protocol commit by Task 1.
	raw, err := os.ReadFile("../../crates/abci/testdata/v1-vectors.json")
	if err != nil {
		t.Fatal(err)
	}
	var vectors struct {
		Keys []struct {
			PrivateKey string `json:"private_key"`
			PublicKey  string `json:"public_key"`
			Address    string `json:"ck_addr"`
		} `json:"keys"`
		Register []struct {
			Name      string `json:"name"`
			Chain     string `json:"l1_chain_id"`
			Registry  string `json:"registry"`
			Owner     string `json:"owner"`
			Key       string `json:"key"`
			Digest    string `json:"digest"`
			Signature string `json:"pop_sig"`
		} `json:"register_digests"`
	}
	if err = json.Unmarshal(raw, &vectors); err != nil {
		t.Fatal(err)
	}
	if len(vectors.Register) == 0 {
		t.Fatal("missing canonical vectors")
	}
	for _, v := range vectors.Register {
		t.Run(v.Name, func(t *testing.T) {
			var private, address string
			for _, k := range vectors.Keys {
				if k.PublicKey == v.Key {
					private = k.PrivateKey
					address = k.Address
				}
			}
			if private == "" {
				t.Fatal("missing vector key")
			}
			dir := t.TempDir()
			key, state := filepath.Join(dir, "key"), filepath.Join(dir, "state")
			pv := privval.NewFilePV(secp256k1eth.PrivKey(fromHex(t, private)), key, state)
			pv.Save()
			before, _ := os.ReadFile(state)
			got := commandJSON(t, binary, "pop", "--priv-key", key, "--owner", v.Owner, "--registry", v.Registry, "--l1-chain-id", v.Chain)
			if len(got) != 2 || got["publicKey"] != v.Key || got["signature"] != v.Signature {
				t.Fatalf("PoP mismatch: %v", got)
			}
			sig := fromHex(t, got["signature"])
			if len(sig) != 65 || sig[64] > 1 || new(big.Int).SetBytes(sig[32:64]).Cmp(new(big.Int).Rsh(new(big.Int).Set(secp256k1.Params().N), 1)) > 0 {
				t.Fatal("noncanonical signature")
			}
			compact := append([]byte{sig[64] + 27}, sig[:64]...)
			recovered, _, err := ecdsa.RecoverCompact(compact, fromHex(t, v.Digest))
			if err != nil {
				t.Fatal(err)
			}
			if "0x"+hex.EncodeToString(testKeccak(recovered.SerializeUncompressed()[1:])[12:]) != address {
				t.Fatal("wrong recovered Ethereum address / double hashing")
			}
			after, _ := os.ReadFile(state)
			if !bytes.Equal(before, after) {
				t.Fatal("PoP changed consensus HRS")
			}
		})
	}
}

func TestPopRejectsInvalidInputsAndLegacyKeys(t *testing.T) {
	binary := buildSigner(t)
	_, key, state := filePV(t)
	base := []string{"pop", "--priv-key", key, "--owner", "0x" + strings.Repeat("a", 40), "--registry", "0x" + strings.Repeat("2", 40), "--l1-chain-id", "1"}
	before, _ := os.ReadFile(state)
	for _, c := range []struct {
		index int
		value string
	}{{2, "/absent-key"}, {4, "0x1234"}, {4, "0x" + strings.Repeat("z", 40)}, {6, ""}, {8, "-1"}, {8, "1.5"}, {8, new(big.Int).Lsh(big.NewInt(1), 256).String()}, {8, "0x1"}} {
		args := append([]string(nil), base...)
		args[c.index] = c.value
		if out, err := exec.Command(binary, args...).Output(); err == nil || len(out) != 0 {
			t.Fatalf("invalid PoP input accepted: %v %s", args, out)
		}
	}
	legacy := privval.NewFilePV(ed25519.GenPrivKey(), key, state)
	legacy.Save()
	if out, err := exec.Command(binary, base...).Output(); err == nil || len(out) != 0 {
		t.Fatalf("legacy key accepted: %s", out)
	}
	after, _ := os.ReadFile(state)
	if !bytes.Equal(before, after) {
		t.Fatal("PoP modified state")
	}
}

func TestRuntimeRefusesLegacyConsensusIdentity(t *testing.T) {
	binary := buildSigner(t)
	dir := t.TempDir()
	key, state := filepath.Join(dir, "key"), filepath.Join(dir, "state")
	p := privval.NewFilePV(ed25519.GenPrivKey(), key, state)
	p.Save()
	// Unsupported transport makes even a buggy legacy loader exit promptly.
	out, err := exec.Command(binary, "--comet-signer-addr", "bad://transport", "--trust-socket", "/absent", "--chain-id", chain, "--priv-key", key, "--priv-state", state).CombinedOutput()
	if err == nil || !strings.Contains(string(out), "secp256k1eth") {
		t.Fatalf("legacy consensus key reached runtime: %v %s", err, out)
	}
}

func TestNativeKeyLoaderRejectsMalformedStockKeys(t *testing.T) {
	_, key, _ := filePV(t)
	original, err := os.ReadFile(key)
	if err != nil {
		t.Fatal(err)
	}
	for _, which := range []string{"zero", "order", "short", "off_curve", "wrong_public_key", "wrong_address"} {
		t.Run(which, func(t *testing.T) {
			var raw map[string]any
			if err := json.Unmarshal(original, &raw); err != nil {
				t.Fatal(err)
			}
			switch which {
			case "zero":
				raw["priv_key"].(map[string]any)["value"] = base64.StdEncoding.EncodeToString(make([]byte, 32))
			case "order":
				raw["priv_key"].(map[string]any)["value"] = base64.StdEncoding.EncodeToString(secp256k1.Params().N.Bytes())
			case "short":
				raw["priv_key"].(map[string]any)["value"] = base64.StdEncoding.EncodeToString([]byte{1})
			case "off_curve":
				raw["pub_key"].(map[string]any)["value"] = base64.StdEncoding.EncodeToString(append([]byte{2}, bytes.Repeat([]byte{255}, 32)...))
			case "wrong_public_key":
				priv := make(secp256k1eth.PrivKey, 32)
				priv[31] = 1
				raw["pub_key"].(map[string]any)["value"] = base64.StdEncoding.EncodeToString(priv.PubKey().Bytes())
			case "wrong_address":
				raw["address"] = strings.Repeat("0", 40)
			}
			encoded, err := json.Marshal(raw)
			if err != nil {
				t.Fatal(err)
			}
			if err = os.WriteFile(key, encoded, 0600); err != nil {
				t.Fatal(err)
			}
			if _, err = loadNativeKey(key); err == nil {
				t.Fatal("malformed/mismatched stock identity accepted")
			}
		})
	}
}

func TestRegistrationPreimagePreservesFullUint256ChainID(t *testing.T) {
	// Independently derived by pinned protocol generate.py::register_digest using cast.
	msg, err := registrationPreimage("0x"+strings.Repeat("a", 40), "0x"+strings.Repeat("2", 40), "115792089237316195423570985008687907853269984665640564039457584007913129639935")
	if err != nil {
		t.Fatal(err)
	}
	if got := "0x" + hex.EncodeToString(testKeccak(msg)); got != "0x0e20801264a9c46bd56482dce34d9911033663c0cee339053cbb3944924cf8d6" {
		t.Fatalf("full-width chain domain mismatch: %s", got)
	}
}
