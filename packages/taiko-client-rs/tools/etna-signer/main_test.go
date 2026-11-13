package main

import (
	"context"
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

// serveArgs are the full serve flags; the absent Comet and trust sockets keep a signer that
// passed every startup check alive and retrying.
func serveArgs(key, state, log string) []string {
	return []string{"--comet-signer-addr", "unix:///nonexistent-comet.sock", "--trust-socket", "/nonexistent-trust.sock", "--chain-id", chain, "--priv-key", key, "--priv-state", state, "--domains-log", log}
}

// runSigner runs the real binary to its exit and returns the exit code and stderr.
func runSigner(t *testing.T, args ...string) (int, string) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, signerBinary(t), args...)
	var stderr strings.Builder
	cmd.Stderr = &stderr
	err := cmd.Run()
	if ctx.Err() != nil {
		t.Fatalf("signer stayed alive instead of refusing: %s", stderr.String())
	}
	var exit *exec.ExitError
	if err != nil && !errors.As(err, &exit) {
		t.Fatal(err)
	}
	return cmd.ProcessState.ExitCode(), stderr.String()
}

// signingFiles maps every regular file under root to its bytes. Lock files carry no data.
func signingFiles(t *testing.T, root string) map[string]string {
	t.Helper()
	files := map[string]string{}
	err := filepath.WalkDir(root, func(path string, entry fs.DirEntry, err error) error {
		if err != nil || entry.IsDir() || strings.HasSuffix(path, ".lock") {
			return err
		}
		target := ""
		if entry.Type()&fs.ModeSymlink != 0 {
			target, err = os.Readlink(path)
		} else {
			var raw []byte
			raw, err = os.ReadFile(path)
			target = string(raw)
		}
		files[path] = target
		return err
	})
	if err != nil {
		t.Fatal(err)
	}
	return files
}

func holdLock(t *testing.T, path string) {
	t.Helper()
	lock, err := os.OpenFile(path, os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { lock.Close() })
	if err = syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		t.Fatal(err)
	}
}

// Every lost, malformed or ambiguous signing state refuses serving with exit 3, which the
// supervisor latches (RECOV-8.2-3); nothing is created, repaired or reset. A configuration or
// lock error exits 1.
func TestServeRefusalMatrix(t *testing.T) {
	write := func(path, content string) {
		if err := os.WriteFile(path, []byte(content), 0600); err != nil {
			t.Fatal(err)
		}
	}
	signedFor := func(l stateLayout, signerKey, domain string) {
		var key secp256k1eth.PrivKey
		if signerKey == "other" {
			key = secp256k1eth.GenPrivKey()
		} else {
			native, err := loadNativeKey(l.key)
			if err != nil {
				t.Fatal(err)
			}
			key = native
		}
		pv := privval.NewFilePV(key, filepath.Join(t.TempDir(), "k.json"), l.state(chain))
		request := voteRequest(tm.PrecommitType, 0, false)
		if err := pv.SignVote(domain, request.GetSignVoteRequest().Vote); err != nil {
			t.Fatal(err)
		}
	}
	for _, c := range []struct {
		name   string
		setup  func(l stateLayout) []string
		code   int
		stderr string
	}{
		{"log-missing", func(l stateLayout) []string { os.Remove(l.log); return nil }, 3, "domains log"},
		{"log-malformed-torn-append", func(l stateLayout) []string {
			f, _ := os.OpenFile(l.log, os.O_APPEND|os.O_WRONLY, 0)
			f.Write([]byte("bad"))
			f.Close()
			return nil
		}, 3, "domains log"},
		{"log-wrong-header", func(l stateLayout) []string { write(l.log, "etna-signer-domains-v0\n"+chain+"\n"); return nil }, 3, "domains log"},
		{"log-blank-line", func(l stateLayout) []string { write(l.log, domainsLogHeader+"\n"+chain+"\n\n"); return nil }, 3, "domains log"},
		{"log-invalid-line", func(l stateLayout) []string { write(l.log, domainsLogHeader+"\n"+chain+"\netna.other\n"); return nil }, 3, "domains log"},
		{"log-duplicate", func(l stateLayout) []string { write(l.log, domainsLogHeader+"\n"+chain+"\n"+chain+"\n"); return nil }, 3, "domains log"},
		{"log-symlink", func(l stateLayout) []string {
			copied := filepath.Join(t.TempDir(), "domains.log")
			write(copied, string(readFile(t, l.log)))
			os.Remove(l.log)
			if err := os.Symlink(copied, l.log); err != nil {
				t.Fatal(err)
			}
			return nil
		}, 3, "domains log"},
		{"chain-not-in-log", func(l stateLayout) []string {
			os.Remove(l.state(chain))
			write(l.log, domainsLogHeader+"\netna-other\n")
			write(l.state("etna-other"), string(zeroHRS()))
			return nil
		}, 3, "not initialized"},
		// An init-state interrupted before its log line leaves an unlogged zero state.
		{"unlogged-state", func(l stateLayout) []string { write(l.log, domainsLogHeader+"\n"); return nil }, 3, "not initialized"},
		{"logged-state-missing", func(l stateLayout) []string { os.Remove(l.state(chain)); return nil }, 3, "missing"},
		{"logged-state-directory-missing", func(l stateLayout) []string { os.RemoveAll(l.hrs); return nil }, 3, "missing"},
		{"hrs-unauthentic", func(l stateLayout) []string { write(l.state(chain), `{"height":"9","round":0,"step":3}`); return nil }, 3, "HRS"},
		{"hrs-signed-by-another-key", func(l stateLayout) []string { signedFor(l, "other", chain); return nil }, 3, "HRS"},
		{"hrs-signed-for-another-chain", func(l stateLayout) []string { signedFor(l, "own", "etna-other"); return nil }, 3, "HRS"},
		{"hrs-ambiguous-duplicate-field", func(l stateLayout) []string {
			write(l.state(chain), `{"height":"0","height":"0","round":0,"step":0}`)
			return nil
		}, 3, "HRS"},
		{"state-hardlinked", func(l stateLayout) []string {
			if err := os.Link(l.state(chain), filepath.Join(t.TempDir(), chain+".json")); err != nil {
				t.Fatal(err)
			}
			return nil
		}, 3, "exactly one filesystem link"},
		{"state-alias-of-another-chain", func(l stateLayout) []string {
			if err := initState("etna-other", l.key, l.state("etna-other"), l.log); err != nil {
				t.Fatal(err)
			}
			os.Remove(l.state(chain))
			if err := os.Symlink(l.state("etna-other"), l.state(chain)); err != nil {
				t.Fatal(err)
			}
			return nil
		}, 3, "etna-other.json"},
		{"retained-fence", func(l stateLayout) []string { write(fencePath(l.state(chain)), "evidence"); return nil }, 3, "fence"},
		// A signer that died while synchronizing its state on this boot (RECOV-8.2-3).
		{"inflight-this-boot", func(l stateLayout) []string { write(inflightPath(l.state(chain)), bootID()+"\n"); return nil }, 3, "inflight marker"},
		// The supervisor's marker beside the domains log outlives a fresh app store: a forced
		// kill before the fence, or an exit 3 whose fence write failed (ACCEPTANCE §7.7).
		{"retained-signer-unsafe-marker", func(l stateLayout) []string {
			write(unsafeMarkerPath(l.log, chain), "signer did not stop within 5s of SIGTERM and was killed\n")
			return nil
		}, 3, "signer-unsafe marker"},
		// Like the fence, any inode refuses, here a dangling alias.
		{"retained-signer-unsafe-marker-alias", func(l stateLayout) []string {
			if err := os.Symlink(filepath.Join(t.TempDir(), "absent"), unsafeMarkerPath(l.log, chain)); err != nil {
				t.Fatal(err)
			}
			return nil
		}, 3, "signer-unsafe marker"},
		{"missing-domains-log-flag", func(l stateLayout) []string {
			return serveArgs(l.key, l.state(chain), l.log)[:10]
		}, 1, "domains log"},
		{"key-owned", func(l stateLayout) []string { holdLock(t, l.key+".lock"); return nil }, 1, "another signer owns"},
		{"state-owned", func(l stateLayout) []string { holdLock(t, l.state(chain)+".lock"); return nil }, 1, "another signer owns"},
		{"state-named-for-another-chain", func(l stateLayout) []string {
			return serveArgs(l.key, filepath.Join(l.hrs, "state.json"), l.log)
		}, 1, "etna-test.json"},
		{"log-in-state-directory", func(l stateLayout) []string {
			moved := filepath.Join(l.hrs, "domains.log")
			if err := os.Rename(l.log, moved); err != nil {
				t.Fatal(err)
			}
			return serveArgs(l.key, l.state(chain), moved)
		}, 1, "outside the signing state directory"},
	} {
		t.Run(c.name, func(t *testing.T) {
			l := newStateLayout(t)
			if err := initState(chain, l.key, l.state(chain), l.log); err != nil {
				t.Fatal(err)
			}
			args := c.setup(l)
			if args == nil {
				args = serveArgs(l.key, l.state(chain), l.log)
			}
			root := filepath.Dir(l.hrs)
			before := signingFiles(t, root)
			code, stderr := runSigner(t, args...)
			if code != c.code || !strings.Contains(stderr, c.stderr) {
				t.Fatalf("exit %d (want %d), stderr %q (want %q)", code, c.code, stderr, c.stderr)
			}
			if after := signingFiles(t, root); len(after) != len(before) {
				t.Fatalf("refusal created or removed signing files: %v -> %v", before, after)
			} else {
				for path, content := range before {
					if after[path] != content {
						t.Fatalf("refusal changed %s", path)
					}
				}
			}
		})
	}
	// A healthy layout passes every check and keeps serving; a marker is per chain_id, so another
	// chain's marker, such as an older generation's, does not refuse this one, and an inflight
	// marker from an earlier boot is stale.
	l := newStateLayout(t)
	if err := initState(chain, l.key, l.state(chain), l.log); err != nil {
		t.Fatal(err)
	}
	write(unsafeMarkerPath(l.log, "etna-other"), "evidence")
	write(inflightPath(l.state(chain)), "earlier-boot\n")
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	if out, err := exec.CommandContext(ctx, signerBinary(t), serveArgs(l.key, l.state(chain), l.log)...).CombinedOutput(); ctx.Err() == nil {
		t.Fatalf("healthy signing state refused: %v %s", err, out)
	}
}

func TestProductionStartupNeverCreatesSigningFilesAndLocksExistingState(t *testing.T) {
	binary := signerBinary(t)
	signerDir := t.TempDir()
	key, state, log := filepath.Join(signerDir, "key.json"), filepath.Join(signerDir, "hrs", chain+".json"), filepath.Join(signerDir, "domains", "domains.log")
	if out, err := exec.Command(binary, serveArgs(key, state, log)...).CombinedOutput(); err == nil || !strings.Contains(string(out), "existing signing file") {
		t.Fatalf("missing files accepted: %v %s", err, out)
	}
	for _, p := range []string{key, state, log} {
		if _, err := os.Stat(p); !os.IsNotExist(err) {
			t.Fatalf("startup created signing file %s", p)
		}
	}
	_, key, state = filePV(t)
	before := readFile(t, state)
	holdLock(t, state+".lock")
	if out, err := exec.Command(binary, serveArgs(key, state, domainsLogOf(state))...).CombinedOutput(); err == nil || !strings.Contains(string(out), "another signer owns") {
		t.Fatalf("concurrent FilePV owner accepted: %v %s", err, out)
	}
	if string(before) != string(readFile(t, state)) {
		t.Fatal("lock rejection changed actual signing state")
	}
}

func TestStateSymlinkUsesCanonicalOwnerLock(t *testing.T) {
	binary := signerBinary(t)
	_, key, state := filePV(t)
	alias := filepath.Join(t.TempDir(), chain+".json")
	if err := os.Symlink(state, alias); err != nil {
		t.Fatal(err)
	}
	holdLock(t, state+".lock")
	before := readFile(t, state)
	helper := exec.Command(binary, serveArgs(key, alias, domainsLogOf(state))...)
	var output strings.Builder
	helper.Stdout = &output
	helper.Stderr = &output
	if err := helper.Start(); err != nil {
		t.Fatal(err)
	}
	done := make(chan error, 1)
	go func() { done <- helper.Wait() }()
	select {
	case err := <-done:
		if err == nil || !strings.Contains(output.String(), "another signer owns") {
			t.Fatalf("alias owner was accepted: %v %s", err, output.String())
		}
	case <-time.After(2 * time.Second):
		helper.Process.Kill()
		<-done
		t.Fatal("state symlink bypassed canonical owner lock; second helper stayed alive")
	}
	if string(before) != string(readFile(t, state)) {
		t.Fatal("rejected alias modified actual state")
	}
	if info, e := os.Lstat(alias); e != nil || info.Mode()&os.ModeSymlink == 0 {
		t.Fatal("signer replaced the state symlink")
	}
}

func TestHardlinkedStateCannotSplitSigningHistory(t *testing.T) {
	_, key, state := filePV(t)
	alias := filepath.Join(t.TempDir(), chain+".json")
	if err := os.Link(state, alias); err != nil {
		t.Fatal(err)
	}
	before := readFile(t, state)
	for _, path := range []string{state, alias} {
		code, stderr := runSigner(t, serveArgs(key, path, domainsLogOf(state))...)
		if code != exitSigningStateUnsafe || !strings.Contains(stderr, "exactly one filesystem link") {
			t.Fatalf("multiply-linked state accepted: exit %d %s", code, stderr)
		}
	}
	if string(before) != string(readFile(t, state)) {
		t.Fatal("hardlink rejection modified signing state")
	}
}

// A refusal makes at most two trust queries, so a timeout above 2 s could leave a refused
// request unanswered past CometBFT's fixed 5 s signer read timeout, and Comet retries an
// unanswered request instead of giving up on it (SYNC-9-11). The binary refuses to start.
func TestTrustTimeoutAbove2sIsRejected(t *testing.T) {
	for _, c := range []struct {
		timeout time.Duration
		valid   bool
	}{
		{-time.Second, false},
		{0, false},
		{time.Nanosecond, true},
		{time.Second, true},
		{2 * time.Second, true},
		{2001 * time.Millisecond, false},
		{10 * time.Second, false},
	} {
		if got := validTrustTimeout(c.timeout); got != c.valid {
			t.Errorf("validTrustTimeout(%v) = %v, want %v", c.timeout, got, c.valid)
		}
	}
	dir := t.TempDir()
	args := append(serveArgs(filepath.Join(dir, "key.json"), filepath.Join(dir, chain+".json"), filepath.Join(dir, "domains.log")), "--trust-timeout", "2001ms")
	if code, stderr := runSigner(t, args...); code != 1 || !strings.Contains(stderr, "timeout must be in (0,2s]") {
		t.Fatalf("exit %d, stderr %q", code, stderr)
	}
}
