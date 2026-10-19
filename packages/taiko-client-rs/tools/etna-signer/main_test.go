package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
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
