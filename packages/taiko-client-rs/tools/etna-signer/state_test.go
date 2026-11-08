package main

import (
	"bytes"
	"errors"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	"github.com/cometbft/cometbft/privval"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
)

// stateLayout is one validator's separate key, per-chain state and domains-log directories.
type stateLayout struct{ key, hrs, log string }

// newStateLayout writes a stock native key and an initialized domains log, with the state
// directory and the log directory kept apart as the signer requires.
func newStateLayout(t *testing.T) stateLayout {
	t.Helper()
	root := t.TempDir()
	l := stateLayout{key: filepath.Join(root, "key", "key.json"), hrs: filepath.Join(root, "hrs"), log: filepath.Join(root, "domains", "domains.log")}
	for _, dir := range []string{filepath.Dir(l.key), l.hrs, filepath.Dir(l.log)} {
		if err := os.MkdirAll(dir, 0700); err != nil {
			t.Fatal(err)
		}
	}
	privval.NewFilePV(secp256k1eth.GenPrivKey(), l.key, filepath.Join(root, "unused-state.json")).Key.Save()
	if err := initDomainsLog(l.log); err != nil {
		t.Fatal(err)
	}
	return l
}

func (l stateLayout) state(chain string) string { return filepath.Join(l.hrs, chain+".json") }

func readFile(t *testing.T, path string) []byte {
	t.Helper()
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return raw
}

func TestInitDomainsLogIsExclusiveAndDurable(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "domains.log")
	if err := initDomainsLog(path); err != nil {
		t.Fatal(err)
	}
	if got := string(readFile(t, path)); got != "etna-signer-domains-v1\n" {
		t.Fatalf("domains log header: %q", got)
	}
	if info, err := os.Stat(path); err != nil || info.Mode().Perm() != 0600 {
		t.Fatalf("domains log mode: %v %v", info, err)
	}
	if err := initDomainsLog(path); !errors.Is(err, fs.ErrExist) {
		t.Fatalf("second init replaced the log: %v", err)
	}
	if got := string(readFile(t, path)); got != "etna-signer-domains-v1\n" {
		t.Fatalf("refused init changed the log: %q", got)
	}
	alias, target := filepath.Join(dir, "alias.log"), filepath.Join(dir, "target.log")
	if err := os.Symlink(target, alias); err != nil {
		t.Fatal(err)
	}
	if err := initDomainsLog(alias); err == nil {
		t.Fatal("symlinked domains log accepted")
	}
	if _, err := os.Lstat(target); !os.IsNotExist(err) {
		t.Fatal("init followed the symlink")
	}
}

func TestInitStateCreatesZeroHRSAndAppendsChain(t *testing.T) {
	l := newStateLayout(t)
	key := readFile(t, l.key)
	if err := initState(chain, l.key, l.state(chain), l.log); err != nil {
		t.Fatal(err)
	}
	if got := readFile(t, l.state(chain)); !bytes.Equal(got, zeroHRS()) {
		t.Fatalf("new state is not the stock zero HRS: %s", got)
	}
	if info, err := os.Stat(l.state(chain)); err != nil || info.Mode().Perm() != 0600 {
		t.Fatalf("state mode: %v %v", info, err)
	}
	if got := string(readFile(t, l.log)); got != domainsLogHeader+"\n"+chain+"\n" {
		t.Fatalf("log after first chain: %q", got)
	}
	// The stock loader reads it as an unsigned FilePV state.
	if loaded := privval.LoadFilePV(l.key, l.state(chain)); loaded.LastSignState.Height != 0 || len(loaded.LastSignState.Signature) != 0 {
		t.Fatal("initialized state is not unsigned")
	}
	first := readFile(t, l.state(chain))
	if err := initState("etna-test-2", l.key, l.state("etna-test-2"), l.log); err != nil {
		t.Fatal(err)
	}
	if got := string(readFile(t, l.log)); got != domainsLogHeader+"\n"+chain+"\n"+"etna-test-2\n" {
		t.Fatalf("log after second chain: %q", got)
	}
	if !bytes.Equal(readFile(t, l.state(chain)), first) || !bytes.Equal(readFile(t, l.key), key) {
		t.Fatal("a later chain changed an earlier HRS or the key")
	}
}

func TestInitStateRefusesReinitAndExistingState(t *testing.T) {
	t.Run("logged", func(t *testing.T) {
		l := newStateLayout(t)
		if err := initState(chain, l.key, l.state(chain), l.log); err != nil {
			t.Fatal(err)
		}
		// A signed HRS must never be replaced by a fresh one.
		pv := privval.LoadFilePV(l.key, l.state(chain))
		if err := pv.SignVote(chain, &tm.Vote{Type: tm.PrevoteType, Height: 5, Timestamp: time.Unix(100, 0)}); err != nil {
			t.Fatal(err)
		}
		state, log := readFile(t, l.state(chain)), readFile(t, l.log)
		if err := initState(chain, l.key, l.state(chain), l.log); err == nil || !strings.Contains(err.Error(), "already initialized") {
			t.Fatalf("reinitialization accepted: %v", err)
		}
		if !bytes.Equal(readFile(t, l.state(chain)), state) || !bytes.Equal(readFile(t, l.log), log) {
			t.Fatal("refused reinitialization changed state or log")
		}
	})
	t.Run("unlogged-state", func(t *testing.T) {
		l := newStateLayout(t)
		if err := os.WriteFile(l.state(chain), []byte("existing HRS"), 0600); err != nil {
			t.Fatal(err)
		}
		log := readFile(t, l.log)
		if err := initState(chain, l.key, l.state(chain), l.log); err == nil {
			t.Fatal("existing state file replaced")
		}
		if !bytes.Equal(readFile(t, l.log), log) || string(readFile(t, l.state(chain))) != "existing HRS" {
			t.Fatal("refusal changed the log or the existing state")
		}
	})
	t.Run("missing-log", func(t *testing.T) {
		l := newStateLayout(t)
		if err := os.Remove(l.log); err != nil {
			t.Fatal(err)
		}
		if err := initState(chain, l.key, l.state(chain), l.log); err == nil {
			t.Fatal("state initialized without a domains log")
		}
		if _, err := os.Lstat(l.state(chain)); !os.IsNotExist(err) {
			t.Fatal("state created without a domains log")
		}
		if _, err := os.Lstat(l.log); !os.IsNotExist(err) {
			t.Fatal("init-state created a domains log")
		}
	})
}

func TestInitStateRefusesNameDirectoryAndChainMismatch(t *testing.T) {
	type input struct{ chain, state, log string }
	cases := map[string]func(stateLayout) input{
		"base-name": func(l stateLayout) input { return input{chain, filepath.Join(l.hrs, "x.json"), l.log} },
		"same-directory": func(l stateLayout) input {
			return input{chain, filepath.Join(filepath.Dir(l.log), chain+".json"), l.log}
		},
	}
	for _, c := range []string{"", "a/b", strings.Repeat("a", 51), "x\n", "a.b"} {
		c := c
		cases["chain-"+strings.NewReplacer("/", "slash", "\n", "newline").Replace(c)] = func(l stateLayout) input {
			return input{c, filepath.Join(l.hrs, c+".json"), l.log}
		}
	}
	for name, setup := range cases {
		t.Run(name, func(t *testing.T) {
			l := newStateLayout(t)
			in := setup(l)
			log := readFile(t, l.log)
			if err := initState(in.chain, l.key, in.state, in.log); err == nil {
				t.Fatalf("invalid chain/name/directory accepted: %q %s", in.chain, in.state)
			}
			if !bytes.Equal(readFile(t, l.log), log) {
				t.Fatal("refusal changed the domains log")
			}
			for _, dir := range []string{l.hrs, filepath.Dir(l.log)} {
				entries, err := os.ReadDir(dir)
				if err != nil {
					t.Fatal(err)
				}
				for _, entry := range entries {
					if strings.HasSuffix(entry.Name(), ".json") {
						t.Fatalf("refusal created state %s", entry.Name())
					}
				}
			}
		})
	}
	if err := validChainID(strings.Repeat("a", 50)); err != nil {
		t.Fatalf("stock-length chain ID refused: %v", err)
	}
	if err := validChainID("etna-AZaz09_-"); err != nil {
		t.Fatalf("Etna charset refused: %v", err)
	}
}

func TestDomainsLogRejectsMalformed(t *testing.T) {
	for name, content := range map[string]string{
		"wrong-header": "etna-signer-domains-v2\netna-test\n",
		"no-header":    "",
		"torn-header":  "etna-signer-domains-v1",
		"torn-append":  "etna-signer-domains-v1\netna-test\netna-te",
		"duplicate":    "etna-signer-domains-v1\netna-test\netna-test\n",
		"blank-line":   "etna-signer-domains-v1\n\netna-test\n",
		"invalid-line": "etna-signer-domains-v1\netna.test\n",
		"oversize":     "etna-signer-domains-v1\n" + strings.Repeat(strings.Repeat("a", 49)+"\n", 1<<20/50+1),
	} {
		t.Run(name, func(t *testing.T) {
			l := newStateLayout(t)
			if err := os.WriteFile(l.log, []byte(content), 0600); err != nil {
				t.Fatal(err)
			}
			f, err := os.Open(l.log)
			if err != nil {
				t.Fatal(err)
			}
			defer f.Close()
			if _, err := readDomainsLog(f); err == nil {
				t.Fatal("malformed domains log accepted")
			}
			if err := initState("etna-other", l.key, l.state("etna-other"), l.log); err == nil {
				t.Fatal("init-state appended to a malformed domains log")
			}
			if _, err := os.Lstat(l.state("etna-other")); !os.IsNotExist(err) {
				t.Fatal("malformed log still created state")
			}
			if string(readFile(t, l.log)) != content {
				t.Fatal("refusal changed the malformed log")
			}
		})
	}
	l := newStateLayout(t)
	if err := os.WriteFile(l.log, []byte(domainsLogHeader+"\netna-test\netna-other\n"), 0600); err != nil {
		t.Fatal(err)
	}
	f, err := os.Open(l.log)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	logged, err := readDomainsLog(f)
	if err != nil || len(logged) != 2 || !logged["etna-test"] || !logged["etna-other"] {
		t.Fatalf("well-formed log: %v %v", logged, err)
	}
}

func TestInitStateRefusesWhileKeyOwned(t *testing.T) {
	l := newStateLayout(t)
	lock, err := os.OpenFile(l.key+".lock", os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		t.Fatal(err)
	}
	defer lock.Close()
	if err = syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		t.Fatal(err)
	}
	log := readFile(t, l.log)
	if err := initState(chain, l.key, l.state(chain), l.log); err == nil || !strings.Contains(err.Error(), "another signer owns") {
		t.Fatalf("init-state ran beside a key owner: %v", err)
	}
	if _, err := os.Lstat(l.state(chain)); !os.IsNotExist(err) || !bytes.Equal(readFile(t, l.log), log) {
		t.Fatal("refused init-state changed the state or log")
	}
}

// The operator commands reach the same functions through the real binary.
func TestInitCommandsCreateLogAndState(t *testing.T) {
	binary := signerBinary(t)
	l := newStateLayout(t)
	fresh := filepath.Join(t.TempDir(), "domains.log")
	if out, err := exec.Command(binary, "init-domains-log", "--domains-log", fresh).CombinedOutput(); err != nil {
		t.Fatalf("init-domains-log: %v %s", err, out)
	}
	if got := string(readFile(t, fresh)); got != domainsLogHeader+"\n" {
		t.Fatalf("CLI log: %q", got)
	}
	args := []string{"init-state", "--chain-id", chain, "--priv-key", l.key, "--priv-state", l.state(chain), "--domains-log", l.log}
	if out, err := exec.Command(binary, args...).CombinedOutput(); err != nil {
		t.Fatalf("init-state: %v %s", err, out)
	}
	if !bytes.Equal(readFile(t, l.state(chain)), zeroHRS()) || string(readFile(t, l.log)) != domainsLogHeader+"\n"+chain+"\n" {
		t.Fatal("CLI init-state wrote the wrong state or log")
	}
	if out, err := exec.Command(binary, args...).CombinedOutput(); err == nil || !strings.Contains(string(out), "already initialized") {
		t.Fatalf("CLI reinitialization accepted: %v %s", err, out)
	}
	if out, err := exec.Command(binary, "init-state", "--chain-id", chain, "--priv-key", l.key).CombinedOutput(); err == nil {
		t.Fatalf("incomplete init-state flags accepted: %s", out)
	}
}
