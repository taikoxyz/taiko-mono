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

// unsafeMarkerSuffix names the supervisor's signer-unsafe marker for one chain_id. The
// supervisor writes it beside the domains log, on that log's own volume, whenever it records an
// exit 3, a fence or a signer it had to kill, so the evidence survives a fresh app store.
const unsafeMarkerSuffix = ".signer-unsafe"

// unsafeMarkerPath is chain's signer-unsafe marker in the directory of the domains log at log.
func unsafeMarkerPath(log, chain string) string {
	return filepath.Join(filepath.Dir(log), chain+unsafeMarkerSuffix)
}

// refuseFence refuses every existing inode, including malformed records and
// aliases. Absence must be positively established before loading signing authority.
func refuseFence(path string) error {
	return refuseEvidence(path, "signer fence")
}

// refuseUnsafeMarker refuses the supervisor's signer-unsafe marker by the same rule as the fence:
// any inode, or any Lstat error but absence, is uncertain signing state (RECOV-8.2-3).
func refuseUnsafeMarker(path string) error {
	return refuseEvidence(path, "signer-unsafe marker")
}

// refuseEvidence is errSigningStateUnsafe unless Lstat establishes that nothing exists at path.
func refuseEvidence(path, what string) error {
	if _, err := os.Lstat(path); !os.IsNotExist(err) {
		return fmt.Errorf("%w: inspect retained %s %s (%v)", errSigningStateUnsafe, what, path, err)
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
