package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

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
	for _, args := range [][]string{nil, {"verify"}, append([]string{"export"}, full...)} {
		if err := run(args); err == nil {
			t.Fatalf("accepted command %q", args)
		}
	}
	if _, err := os.Lstat(home); !os.IsNotExist(err) {
		t.Fatalf("rejected input touched the home: %v", err)
	}
}
