package main

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"math/big"
	"os"
	"path/filepath"
	"strings"

	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	cmtjson "github.com/cometbft/cometbft/libs/json"
	"github.com/cometbft/cometbft/privval"
	"golang.org/x/crypto/sha3"
)

// publicIdentity is the public-only bootstrap output; all bytes use 0x hex.
type publicIdentity struct {
	PublicKey string `json:"publicKey"`
	Address   string `json:"address"`
}

// loadNativeKey uses the stock FilePV codec, including its scalar/point validation.
// Reject inconsistent metadata instead of silently replacing its public identity.
func loadNativeKey(path string) (secp256k1eth.PrivKey, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var key privval.FilePVKey
	if err = cmtjson.Unmarshal(raw, &key); err != nil {
		return nil, fmt.Errorf("invalid FilePV key: %w", err)
	}
	native, ok := key.PrivKey.(secp256k1eth.PrivKey)
	if !ok {
		return nil, errors.New("Etna consensus requires a secp256k1eth FilePV key")
	}
	pub := native.PubKey()
	if key.PubKey == nil || !pub.Equals(key.PubKey) || !bytes.Equal(pub.Address(), key.Address) {
		return nil, errors.New("inconsistent FilePV public key/address")
	}
	return native, nil
}

// keygen is the only command allowed to create new signing files. It encodes
// stock FilePV structures, but never uses Save's replace-existing semantics.
func keygen(args []string, out io.Writer) error {
	flags := flag.NewFlagSet("keygen", flag.ContinueOnError)
	keyPath := flags.String("priv-key", "", "new FilePV private key path (must not exist)")
	statePath := flags.String("priv-state", "", "new FilePV state path (must not exist)")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if *keyPath == "" || *statePath == "" || flags.NArg() != 0 {
		return errors.New("keygen requires --priv-key and --priv-state only")
	}
	pv := privval.NewFilePV(secp256k1eth.GenPrivKey(), *keyPath, *statePath)
	keyBytes, err := cmtjson.MarshalIndent(pv.Key, "", "  ")
	if err != nil {
		return err
	}
	stateBytes, err := cmtjson.MarshalIndent(pv.LastSignState, "", "  ")
	if err != nil {
		return err
	}
	if err = createSigningFiles(*keyPath, *statePath, keyBytes, stateBytes); err != nil {
		return err
	}
	return json.NewEncoder(out).Encode(publicIdentity{"0x" + hex.EncodeToString(pv.Key.PubKey.Bytes()), "0x" + hex.EncodeToString(pv.Key.Address)})
}

// createSigningFiles reserves both paths exclusively before writing either file.
// Any failure removes only files this invocation created; existing files and
// symlinks are never overwritten. Parents must already exist in private storage.
func createSigningFiles(keyPath, statePath string, keyBytes, stateBytes []byte) (err error) {
	paths := []string{keyPath, statePath}
	var opened []*os.File
	defer func() {
		for i, file := range opened {
			file.Close()
			if err != nil {
				os.Remove(paths[i])
			}
		}
	}()
	for _, path := range paths {
		file, e := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
		if e != nil {
			return fmt.Errorf("exclusive bootstrap output: %w", e)
		}
		opened = append(opened, file)
	}
	for i, data := range [][]byte{keyBytes, stateBytes} {
		if _, err = opened[i].Write(data); err != nil {
			return err
		}
		if err = opened[i].Sync(); err != nil {
			return err
		}
	}
	for _, path := range paths {
		dir, e := os.Open(filepath.Dir(path))
		if e != nil {
			return e
		}
		e = dir.Sync()
		dir.Close()
		if e != nil {
			return e
		}
	}
	return nil
}

// keccak returns the Ethereum legacy Keccak-256 hash, not FIPS SHA3-256.
func keccak(data []byte) []byte {
	h := sha3.NewLegacyKeccak256()
	_, _ = h.Write(data)
	return h.Sum(nil)
}

// addressWord ABI-encodes a 20-byte Ethereum address in one 32-byte word.
func addressWord(address string) ([]byte, error) {
	if len(address) != 42 || !strings.HasPrefix(address, "0x") {
		return nil, errors.New("address must be 0x-prefixed 20-byte hex")
	}
	raw, err := hex.DecodeString(address[2:])
	if err != nil {
		return nil, errors.New("address must be 0x-prefixed 20-byte hex")
	}
	return append(make([]byte, 12), raw...), nil
}

// registrationPreimage returns 0x1901 || domainSeparator || structHash, matching
// EtnaStakingRegistry.registerDigest. Stock Sign hashes this exactly once.
func registrationPreimage(owner, registry, chain string) ([]byte, error) {
	ownerWord, err := addressWord(owner)
	if err != nil {
		return nil, fmt.Errorf("owner: %w", err)
	}
	registryWord, err := addressWord(registry)
	if err != nil {
		return nil, fmt.Errorf("registry: %w", err)
	}
	if chain == "" || strings.IndexFunc(chain, func(c rune) bool { return c < '0' || c > '9' }) != -1 {
		return nil, errors.New("L1 chain ID must be a decimal uint256")
	}
	id, ok := new(big.Int).SetString(chain, 10)
	if !ok || id.Sign() < 0 || id.BitLen() > 256 {
		return nil, errors.New("L1 chain ID must be a decimal uint256")
	}
	domain := append(keccak([]byte("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")), keccak([]byte("EtnaStakingRegistry"))...)
	domain = append(domain, keccak([]byte("1"))...)
	domain = append(domain, id.FillBytes(make([]byte, 32))...)
	domain = append(domain, registryWord...)
	structure := append(keccak([]byte("Register(address owner)")), ownerWord...)
	preimage := append([]byte{0x19, 0x01}, keccak(domain)...)
	return append(preimage, keccak(structure)...), nil
}

// pop signs an offline registration proof. It never loads, creates, locks, or
// writes consensus HRS state and emits only public key and recoverable signature.
func pop(args []string, out io.Writer) error {
	flags := flag.NewFlagSet("pop", flag.ContinueOnError)
	keyPath := flags.String("priv-key", "", "existing native FilePV key")
	owner := flags.String("owner", "", "registration owner's Ethereum address")
	registry := flags.String("registry", "", "EtnaStakingRegistry address")
	chain := flags.String("l1-chain-id", "", "decimal L1 chain ID (uint256)")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if *keyPath == "" || flags.NArg() != 0 {
		return errors.New("pop requires --priv-key, --owner, --registry and --l1-chain-id")
	}
	preimage, err := registrationPreimage(*owner, *registry, *chain)
	if err != nil {
		return err
	}
	key, err := loadNativeKey(*keyPath)
	if err != nil {
		return err
	}
	signature, err := key.Sign(preimage)
	if err != nil {
		return err
	}
	result := struct {
		PublicKey string `json:"publicKey"`
		Signature string `json:"signature"`
	}{"0x" + hex.EncodeToString(key.PubKey().Bytes()), "0x" + hex.EncodeToString(signature)}
	return json.NewEncoder(out).Encode(result)
}
