package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestInstallRequiresHomeStockDirAppHashAndNMax(t *testing.T) {
	work := t.TempDir()
	home := filepath.Join(work, "comet")
	full := []string{"--home", home, "--stock-dir", work, "--app-hash", "0x" + strings.Repeat("09", 32), "--n-max", "128"}
	for drop := 0; drop < len(full); drop += 2 {
		args := append([]string{"install"}, full[:drop]...)
		args = append(args, full[drop+2:]...)
		if err := run(args); err == nil || !strings.Contains(err.Error(), "install requires --home, --stock-dir, --app-hash and --n-max") {
			t.Fatalf("accepted install without %s: %v", full[drop], err)
		}
	}
	for _, hash := range []string{"09", "0x09", "0x" + strings.Repeat("09", 33), "0x" + strings.Repeat("zz", 32)} {
		if err := run([]string{"install", "--home", home, "--stock-dir", work, "--app-hash", hash, "--n-max", "128"}); err == nil || !strings.Contains(err.Error(), "--app-hash") {
			t.Fatalf("accepted app hash %q: %v", hash, err)
		}
	}
	for _, nMax := range []string{"-1", "4097", "x"} {
		if err := run([]string{"install", "--home", home, "--stock-dir", work, "--app-hash", "0x" + strings.Repeat("09", 32), "--n-max", nMax}); err == nil || !strings.Contains(err.Error(), "n-max") {
			t.Fatalf("accepted n_max %q: %v", nMax, err)
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
