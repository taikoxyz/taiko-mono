package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

// fenceSuffix names a chain's fence beside its own HRS state, never in the app store or Comet home.
const fenceSuffix = ".uncertain"

// fencePath is the fence of the HRS state at state.
func fencePath(state string) string { return state + fenceSuffix }

// refuseFence refuses every existing inode, including malformed records and
// aliases. Absence must be positively established before loading signing authority.
func refuseFence(path string) error {
	if _, err := os.Lstat(path); !os.IsNotExist(err) {
		return fmt.Errorf("%w: inspect retained signer fence %s (%v)", errSigningStateUnsafe, path, err)
	}
	return nil
}

// writeFence records at the fence path that a state or directory fsync failed, so the latest
// HRS is uncertain (RECOV-8.2-3) and a restarted signer refuses it. It never replaces an
// existing inode, which is already a fence. It fsyncs the record, then its directory, and joins
// every error: the caller has latched already, and its exit 3 makes the supervisor latch on
// another volume even when this record's own directory fsync fails.
func writeFence(path string, cause error) error {
	record, err := json.Marshal(map[string]any{"schema": 1, "operation": "FilePV signing", "state": strings.TrimSuffix(path, fenceSuffix), "error": cause.Error()})
	if err != nil {
		return fmt.Errorf("signer fence %s: %w", path, err)
	}
	var errs []error
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	switch {
	case err == nil:
		_, err = f.Write(append(record, '\n'))
		errs = append(errs, err, f.Sync(), f.Close())
	case !errors.Is(err, fs.ErrExist):
		return fmt.Errorf("signer fence %s: %w", path, err)
	}
	if err = errors.Join(append(errs, syncDirectory(filepath.Dir(path)))...); err != nil {
		return fmt.Errorf("signer fence %s: %w", path, err)
	}
	return nil
}
