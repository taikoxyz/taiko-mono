package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// TestInstallRequiresHomeStockDirAndAppHash: install takes exactly --home, --stock-dir and
// --app-hash. The genesis consensus params are fixed, so the removed --n-max is an unknown flag.
func TestInstallRequiresHomeStockDirAndAppHash(t *testing.T) {
	work := t.TempDir()
	home := filepath.Join(work, "comet")
	full := []string{"--home", home, "--stock-dir", work, "--app-hash", "0x" + strings.Repeat("09", 32)}
	for drop := 0; drop < len(full); drop += 2 {
		args := append([]string{"install"}, full[:drop]...)
		args = append(args, full[drop+2:]...)
		if err := run(args); err == nil || !strings.Contains(err.Error(), "install requires --home, --stock-dir and --app-hash") {
			t.Fatalf("accepted install without %s: %v", full[drop], err)
		}
	}
	for _, hash := range []string{"09", "0x09", "0x" + strings.Repeat("09", 33), "0x" + strings.Repeat("zz", 32)} {
		if err := run([]string{"install", "--home", home, "--stock-dir", work, "--app-hash", hash}); err == nil || !strings.Contains(err.Error(), "--app-hash") {
			t.Fatalf("accepted app hash %q: %v", hash, err)
		}
	}
	for _, nMax := range []string{"128", "1"} {
		if err := run(append([]string{"install"}, append(full, "--n-max", nMax)...)); err == nil || !strings.Contains(err.Error(), "flag provided but not defined: -n-max") {
			t.Fatalf("accepted --n-max %s: %v", nMax, err)
		}
	}
	for _, args := range [][]string{nil, {"verify"}, append([]string{"export"}, full...)} {
		if err := run(args); err == nil {
			t.Fatalf("accepted command %q", args)
		}
	}
	if _, err := os.Lstat(home); !os.IsNotExist(err) {
		t.Fatalf("rejected input touched the home: %v", err)
	}
}

func TestSnapshotHeightRequiresOnlyTheStateDir(t *testing.T) {
	dir := t.TempDir()
	for _, args := range [][]string{
		{"snapshot-height"},
		{"snapshot-height", "--comet-state-dir", dir, "extra"},
	} {
		if err := run(args); err == nil || !strings.Contains(err.Error(), "requires only --comet-state-dir") {
			t.Fatalf("accepted %q: %v", args, err)
		}
	}
	if err := run([]string{"snapshot-height", "--comet-state-dir", dir}); err == nil ||
		!strings.Contains(err.Error(), "open stock state snapshot") {
		t.Fatalf("read a height without a state store: %v", err)
	}
	if entries, err := os.ReadDir(dir); err != nil || len(entries) != 0 {
		t.Fatalf("a read-only snapshot read wrote %v: %v", entries, err)
	}
}

func TestFirstBlockCommandsRequireTheirFlags(t *testing.T) {
	work := t.TempDir()
	full := []string{"--home", filepath.Join(work, "comet"), "--backup", filepath.Join(work, "backup"), "--app", "tcp://127.0.0.1:1"}
	for drop := 0; drop < len(full); drop += 2 {
		args := append([]string{"repair-first-block"}, full[:drop]...)
		args = append(args, full[drop+2:]...)
		if err := run(args); err == nil || !strings.Contains(err.Error(), "repair-first-block requires --home, --backup and --app") {
			t.Fatalf("accepted repair-first-block without %s: %v", full[drop], err)
		}
	}
	for _, args := range [][]string{{"export-first-block"}, {"export-first-block", "--home", work, "extra"}} {
		if err := run(args); err == nil || !strings.Contains(err.Error(), "export-first-block requires only --home") {
			t.Fatalf("accepted %q: %v", args, err)
		}
	}
	if err := run([]string{"repair-first-block", "--home", work, "--backup", filepath.Join(work, "backup"), "--app", "tcp://127.0.0.1:1"}); err == nil || !strings.Contains(err.Error(), "genesis.json") {
		t.Fatalf("repaired a home without a genesis: %v", err)
	}
	if _, err := os.Lstat(filepath.Join(work, "backup")); !os.IsNotExist(err) {
		t.Fatalf("a refused repair wrote its backup: %v", err)
	}
}
