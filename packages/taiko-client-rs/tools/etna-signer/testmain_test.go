package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"testing"
)

// signerBuild holds the one etna-signer binary that every test in this process shares.
var signerBuild struct {
	once sync.Once
	dir  string
	path string
	err  error
}

// TestMain only removes the shared signer binary after the tests. The build itself stays
// lazy, so the re-exec helper children of the process tests never rebuild it.
func TestMain(m *testing.M) {
	m.Run()
	if signerBuild.dir != "" {
		os.RemoveAll(signerBuild.dir)
	}
}

// signerBinary builds etna-signer on first use and returns the shared binary's path.
func signerBinary(t *testing.T) string {
	t.Helper()
	signerBuild.once.Do(func() {
		dir, err := os.MkdirTemp("", "etna-signer-bin-")
		if err != nil {
			signerBuild.err = err
			return
		}
		signerBuild.dir = dir
		path := filepath.Join(dir, "etna-signer")
		if output, err := exec.Command("go", "build", "-mod=readonly", "-o", path, ".").CombinedOutput(); err != nil {
			signerBuild.err = fmt.Errorf("%v %s", err, output)
			return
		}
		signerBuild.path = path
	})
	if signerBuild.err != nil {
		t.Fatalf("build helper: %v", signerBuild.err)
	}
	return signerBuild.path
}
