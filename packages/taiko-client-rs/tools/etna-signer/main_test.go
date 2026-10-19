package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"time"
)

func TestProductionStartupNeverCreatesSigningFilesAndLocksExistingState(t *testing.T) {
	binary := filepath.Join(t.TempDir(), "etna-signer")
	if output, err := exec.Command("go", "build", "-mod=readonly", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build helper: %v %s", err, output)
	}
	signerDir := t.TempDir()
	key, state := filepath.Join(signerDir, "key.json"), filepath.Join(signerDir, "state.json")
	args := []string{"--comet-signer-addr", "unix:///nonexistent-comet.sock", "--trust-socket", "/nonexistent-trust.sock", "--chain-id", chain, "--priv-key", key, "--priv-state", state}
	if out, err := exec.Command(binary, args...).CombinedOutput(); err == nil || !strings.Contains(string(out), "existing signing file") {
		t.Fatalf("missing files accepted: %v %s", err, out)
	}
	for _, p := range []string{key, state} {
		if _, err := os.Stat(p); !os.IsNotExist(err) {
			t.Fatalf("startup created signing file %s", p)
		}
	}
	_, key, state = filePV(t)
	args[len(args)-3] = key
	args[len(args)-1] = state
	before, err := os.ReadFile(state)
	if err != nil {
		t.Fatal(err)
	}
	lock, err := os.OpenFile(state+".lock", os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		t.Fatal(err)
	}
	defer lock.Close()
	if err = syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		t.Fatal(err)
	}
	if out, err := exec.Command(binary, args...).CombinedOutput(); err == nil || !strings.Contains(string(out), "another signer owns") {
		t.Fatalf("concurrent FilePV owner accepted: %v %s", err, out)
	}
	after, _ := os.ReadFile(state)
	if string(before) != string(after) {
		t.Fatal("lock rejection changed actual signing state")
	}
}

func TestStateSymlinkUsesCanonicalOwnerLock(t *testing.T) {
	binary := buildSigner(t)
	_, key, state := filePV(t)
	alias := filepath.Join(t.TempDir(), "state-alias.json")
	if err := os.Symlink(state, alias); err != nil {
		t.Fatal(err)
	}
	lock, err := os.OpenFile(state+".lock", os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		t.Fatal(err)
	}
	defer lock.Close()
	if err = syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		t.Fatal(err)
	}
	before, _ := os.ReadFile(state)
	helper := exec.Command(binary, "--comet-signer-addr", "unix:///absent-comet.sock", "--trust-socket", "/absent-trust.sock", "--chain-id", chain, "--priv-key", key, "--priv-state", alias)
	var output strings.Builder
	helper.Stdout = &output
	helper.Stderr = &output
	if err = helper.Start(); err != nil {
		t.Fatal(err)
	}
	done := make(chan error, 1)
	go func() { done <- helper.Wait() }()
	select {
	case err = <-done:
		if err == nil || !strings.Contains(output.String(), "another signer owns") {
			t.Fatalf("alias owner was accepted: %v %s", err, output.String())
		}
	case <-time.After(2 * time.Second):
		helper.Process.Kill()
		<-done
		t.Fatal("state symlink bypassed canonical owner lock; second helper stayed alive")
	}
	after, _ := os.ReadFile(state)
	if string(before) != string(after) {
		t.Fatal("rejected alias modified actual state")
	}
	if info, e := os.Lstat(alias); e != nil || info.Mode()&os.ModeSymlink == 0 {
		t.Fatal("signer replaced the state symlink")
	}
}

func TestHardlinkedStateCannotSplitSigningHistory(t *testing.T) {
	binary := buildSigner(t)
	_, key, state := filePV(t)
	alias := filepath.Join(t.TempDir(), "state-hardlink.json")
	if err := os.Link(state, alias); err != nil {
		t.Fatal(err)
	}
	before, _ := os.ReadFile(state)
	for _, path := range []string{state, alias} {
		helper := exec.Command(binary, "--comet-signer-addr", "unix:///absent-comet.sock", "--trust-socket", "/absent-trust.sock", "--chain-id", chain, "--priv-key", key, "--priv-state", path)
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
			if err == nil || !strings.Contains(output.String(), "exactly one filesystem link") {
				t.Fatalf("multiply-linked state accepted: %v %s", err, output.String())
			}
		case <-time.After(2 * time.Second):
			helper.Process.Kill()
			<-done
			t.Fatal("multiply-linked state stayed alive")
		}
	}
	after, _ := os.ReadFile(state)
	if string(before) != string(after) {
		t.Fatal("hardlink rejection modified signing state")
	}
}
