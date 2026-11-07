package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// uncertaintyPath remains beside the original HRS across authority generations.
// It never depends on the app store or a newly activated generation's directory.
func uncertaintyPath(state string) string { return state + ".uncertain" }

// clearUncertainty refuses every existing inode, including malformed records and
// aliases. Absence must be positively established before loading signing authority.
func clearUncertainty(path string) error {
	if _, err := os.Lstat(path); !os.IsNotExist(err) {
		return fmt.Errorf("%w: inspect retained signer fence %s (%v)", errStateUncertain, path, err)
	}
	return nil
}

// armUncertainty durably records the possibility of an interrupted mutation before
// FilePV or authority metadata can change. A failed arm never permits the mutation.
// No post-failure write is needed to make a later process refuse uncertain state.
func armUncertainty(path, operation, state string) error {
	data, err := json.Marshal(map[string]any{"schema": 1, "operation": operation, "state": state})
	if err == nil {
		err = exclusiveDurable(path, append(data, '\n'))
	}
	if err != nil {
		return fmt.Errorf("%w: cannot arm signer fence %s: %w", errStateUncertain, path, err)
	}
	return nil
}

// finishUncertainty is called only after all changed signing bytes and authority
// metadata have been synchronized. An interrupted cleanup can conservatively leave
// the fence behind; an absent fence can never expose an unsynchronized mutation.
func finishUncertainty(path string) error {
	if err := os.Remove(path); err != nil {
		return fmt.Errorf("%w: retain signer fence %s: %w", errStateUncertain, path, err)
	}
	if err := syncDirectory(filepath.Dir(path)); err != nil {
		return fmt.Errorf("%w: signer fence cleanup: %w", errStateUncertain, err)
	}
	return nil
}
