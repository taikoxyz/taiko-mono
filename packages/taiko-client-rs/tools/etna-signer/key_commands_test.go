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

// keygen writes only the key: a signing state exists only once init-state logs its chain_id.
func TestKeygenWritesOnlyKey(t *testing.T) {
	binary := signerBinary(t)
	dir := t.TempDir()
	key := filepath.Join(dir, "key.json")
	out := commandJSON(t, binary, "keygen", "--priv-key", key)
	native, err := loadNativeKey(key)
	if err != nil || len(native.PubKey().Bytes()) != 33 {
		t.Fatalf("bootstrap did not create a stock native key: %v", err)
	}
	if len(out) != 2 || out["publicKey"] != "0x"+hex.EncodeToString(native.PubKey().Bytes()) || out["address"] != "0x"+hex.EncodeToString(native.PubKey().Address()) {
		t.Fatalf("unexpected public output: %v", out)
	}
	if info, err := os.Stat(key); err != nil || info.Mode().Perm() != 0600 {
		t.Fatalf("key permissions: %v %v", info, err)
	}
	if entries, _ := os.ReadDir(dir); len(entries) != 1 {
		t.Fatalf("keygen wrote more than the key: %v", entries)
	}
	other := t.TempDir()
	cmd := exec.Command(binary, "keygen", "--priv-key", filepath.Join(other, "key.json"), "--priv-state", filepath.Join(other, "state.json"))
	if output, err := cmd.CombinedOutput(); err == nil || !strings.Contains(string(output), "flag provided but not defined: -priv-state") {
		t.Fatalf("keygen accepted --priv-state: %v %s", err, output)
	}
	if entries, _ := os.ReadDir(other); len(entries) != 0 {
		t.Fatalf("refused keygen wrote files: %v", entries)
	}
	for _, which := range []string{"existing", "symlink"} {
		t.Run(which, func(t *testing.T) {
			dir := t.TempDir()
			k := filepath.Join(dir, "key")
			sentinel := []byte("must survive")
			if which == "existing" {
				os.WriteFile(k, sentinel, 0600)
			} else {
				os.Symlink(filepath.Join(dir, "absent"), k)
			}
			if output, err := exec.Command(binary, "keygen", "--priv-key", k).Output(); err == nil || len(output) != 0 {
				t.Fatalf("existing/alias output accepted: %v %s", err, output)
			}
			if b, err := os.ReadFile(k); err == nil && !bytes.Equal(b, sentinel) {
				t.Fatal("exclusive failure replaced existing output")
			}
			if _, err := os.Lstat(filepath.Join(dir, "absent")); !os.IsNotExist(err) {
				t.Fatal("keygen followed the symlink")
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

// popDomain is the EIP-712 domain of a registration digest: name, version, decimal chain ID and
// verifying contract.
type popDomain struct{ name, version, chain, contract string }

// testStakingDomain is the devnet L2 EtnaStaking domain: chain 167001 and its staking proxy.
var testStakingDomain = popDomain{"EtnaStaking", "1", "167001", "0x1670010000000000000000000000000000010003"}

// registrationDigest recomputes keccak256(0x1901 ‖ keccak256(domain) ‖ keccak256(typehash ‖
// owner)) from the domain's four fields, independently of the signer's code.
func registrationDigest(t *testing.T, d popDomain, owner string) []byte {
	t.Helper()
	id, ok := new(big.Int).SetString(d.chain, 10)
	if !ok {
		t.Fatalf("chain ID %q", d.chain)
	}
	word := func(address string) []byte { return append(make([]byte, 12), fromHex(t, address)...) }
	domain := bytes.Join([][]byte{
		testKeccak([]byte("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")),
		testKeccak([]byte(d.name)), testKeccak([]byte(d.version)), id.FillBytes(make([]byte, 32)), word(d.contract),
	}, nil)
	structure := append(testKeccak([]byte("Register(address owner)")), word(owner)...)
	return testKeccak(bytes.Join([][]byte{{0x19, 0x01}, testKeccak(domain), testKeccak(structure)}, nil))
}

// recoveredAddress is the Ethereum address that signature recovers over digest, or "" when it
// recovers none.
func recoveredAddress(t *testing.T, signature, digest []byte) string {
	t.Helper()
	compact := append([]byte{signature[64] + 27}, signature[:64]...)
	recovered, _, err := ecdsa.RecoverCompact(compact, digest)
	if err != nil {
		return ""
	}
	return "0x" + hex.EncodeToString(testKeccak(recovered.SerializeUncompressed()[1:])[12:])
}

// The registration PoP signs Register(owner) under the L2 EtnaStaking domain: name
// "EtnaStaking", version "1", the L2 chain ID and the staking proxy, so it binds the L2 chain,
// the staking contract and the owner that will send the registration. The digests and
// signatures are the shared Etna vectors' registration vectors, which the contracts check too; a
// signature recovers the key's address over that digest only.
func TestPopUsesTheL2StakingDomain(t *testing.T) {
	binary := signerBinary(t)
	raw, err := os.ReadFile("../../../../testdata/etna_vectors/vectors.json")
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
			Chain     string `json:"l2_chain_id"`
			Staking   string `json:"staking"`
			Owner     string `json:"owner"`
			Key       string `json:"key"`
			Digest    string `json:"digest"`
			Signature string `json:"pop_sig"`
		} `json:"register_digests"`
	}
	if err = json.Unmarshal(raw, &vectors); err != nil {
		t.Fatal(err)
	}
	names := map[string]bool{}
	for _, v := range vectors.Register {
		names[v.Name] = true
	}
	// Two owners for one key, and a key whose X has a leading zero byte, which the 33-byte public
	// key keeps.
	for _, name := range []string{"a2_owner_aa", "a2_owner_bb", "leading_zero_x_owner_aa"} {
		if !names[name] {
			t.Fatalf("missing registration vector %s", name)
		}
	}
	for _, v := range vectors.Register {
		t.Run(v.Name, func(t *testing.T) {
			var private, address string
			for _, k := range vectors.Keys {
				if k.PublicKey == v.Key {
					private, address = k.PrivateKey, k.Address
				}
			}
			if private == "" {
				t.Fatal("missing vector key")
			}
			domain := popDomain{"EtnaStaking", "1", v.Chain, v.Staking}
			digest := registrationDigest(t, domain, v.Owner)
			if got := "0x" + hex.EncodeToString(digest); got != v.Digest {
				t.Fatalf("registration digest %s, want %s", got, v.Digest)
			}
			dir := t.TempDir()
			key, state := filepath.Join(dir, "key"), filepath.Join(dir, "state")
			secret := new(big.Int).SetBytes(fromHex(t, private)).FillBytes(make([]byte, 32))
			privval.NewFilePV(secp256k1eth.PrivKey(secret), key, state).Save()
			before := readFile(t, state)
			got := commandJSON(t, binary, "pop", "--priv-key", key, "--owner", v.Owner, "--staking", v.Staking, "--l2-chain-id", v.Chain)
			if len(got) != 2 || got["publicKey"] != v.Key || got["signature"] != v.Signature {
				t.Fatalf("PoP mismatch: %v", got)
			}
			sig := fromHex(t, got["signature"])
			if len(sig) != 65 || sig[64] > 1 || new(big.Int).SetBytes(sig[32:64]).Cmp(new(big.Int).Rsh(new(big.Int).Set(secp256k1.Params().N), 1)) > 0 {
				t.Fatal("noncanonical signature")
			}
			if recoveredAddress(t, sig, digest) != address {
				t.Fatal("wrong recovered Ethereum address / double hashing")
			}
			// Any other domain recovers another address: the L1 chain ID, the Inbox as verifying
			// contract, the registry's old name or another version.
			for _, other := range []popDomain{
				{"EtnaStaking", "1", "1", v.Staking},
				{"EtnaStaking", "1", v.Chain, "0x" + strings.Repeat("11", 20)},
				{"EtnaStakingRegistry", "1", v.Chain, v.Staking},
				{"EtnaStaking", "2", v.Chain, v.Staking},
			} {
				if recoveredAddress(t, sig, registrationDigest(t, other, v.Owner)) == address {
					t.Fatalf("the PoP also verifies under %v", other)
				}
			}
			if !bytes.Equal(before, readFile(t, state)) {
				t.Fatal("PoP changed consensus HRS")
			}
		})
	}
}

// The L1 registry and L1 chain ID flags are gone: pop refuses them as unknown flags and prints
// nothing.
func TestPopRejectsTheOldFlags(t *testing.T) {
	binary := signerBinary(t)
	_, key, state := filePV(t)
	before := readFile(t, state)
	owner, registry := "0x"+strings.Repeat("a", 40), "0x"+strings.Repeat("2", 40)
	for _, c := range []struct {
		args    []string
		unknown string
	}{
		{[]string{"--registry", registry, "--l1-chain-id", "1"}, "-registry"},
		{[]string{"--staking", testStakingDomain.contract, "--l1-chain-id", "1"}, "-l1-chain-id"},
		{[]string{"--registry", registry, "--l2-chain-id", testStakingDomain.chain}, "-registry"},
	} {
		cmd := exec.Command(binary, append([]string{"pop", "--priv-key", key, "--owner", owner}, c.args...)...)
		var stderr bytes.Buffer
		cmd.Stderr = &stderr
		if out, err := cmd.Output(); err == nil || len(out) != 0 || !strings.Contains(stderr.String(), "flag provided but not defined: "+c.unknown) {
			t.Fatalf("pop %v: %v %s %s", c.args, err, out, stderr.String())
		}
	}
	if !bytes.Equal(before, readFile(t, state)) {
		t.Fatal("refused PoP changed consensus HRS")
	}
}

func TestPopRejectsInvalidInputsAndLegacyKeys(t *testing.T) {
	binary := signerBinary(t)
	_, key, state := filePV(t)
	base := []string{"pop", "--priv-key", key, "--owner", "0x" + strings.Repeat("a", 40), "--staking", "0x" + strings.Repeat("2", 40), "--l2-chain-id", "1"}
	before, _ := os.ReadFile(state)
	if out, err := exec.Command(binary, base...).Output(); err != nil || len(out) == 0 {
		t.Fatalf("valid PoP input refused: %v", err)
	}
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
	privval.NewFilePV(ed25519.GenPrivKey(), key, state).Key.Save()
	if out, err := exec.Command(binary, base...).Output(); err == nil || len(out) != 0 {
		t.Fatalf("legacy key accepted: %s", out)
	}
	after, _ := os.ReadFile(state)
	if !bytes.Equal(before, after) {
		t.Fatal("PoP modified state")
	}
}

func TestRuntimeRefusesLegacyConsensusIdentity(t *testing.T) {
	binary := signerBinary(t)
	_, key, state := filePV(t)
	privval.NewFilePV(ed25519.GenPrivKey(), key, state).Key.Save()
	// Unsupported transport makes even a buggy legacy loader exit promptly.
	out, err := exec.Command(binary, "--comet-signer-addr", "bad://transport", "--trust-socket", "/absent", "--supervisor-socket", "/absent-supervisor", "--chain-id", chain, "--priv-key", key, "--priv-state", state, "--domains-log", domainsLogOf(state)).CombinedOutput()
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
	// Independently derived with cast: the EtnaStaking domain, version 1, chain ID 2^256 - 1 and
	// staking 0x22..22, for owner 0xaa..aa.
	msg, err := registrationPreimage("0x"+strings.Repeat("a", 40), "0x"+strings.Repeat("2", 40), "115792089237316195423570985008687907853269984665640564039457584007913129639935")
	if err != nil {
		t.Fatal(err)
	}
	if got := "0x" + hex.EncodeToString(testKeccak(msg)); got != "0x50570e5da360c91dd1e3427d78c7a8076cda5aca0b49fe7a5025519739cdaa73" {
		t.Fatalf("full-width chain domain mismatch: %s", got)
	}
}
