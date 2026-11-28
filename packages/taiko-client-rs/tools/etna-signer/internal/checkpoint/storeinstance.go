package checkpoint

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"os"
	"path/filepath"
)

// StoreInstanceFile is a Comet home's store instance ID file in its data directory: 32 lowercase
// hex characters (128 random bits) and a newline, mode 0600. Every path that creates, imports,
// restores or rebuilds the stores writes a fresh one, and the validator's signer binds its key to
// it (RECOV-8.2-2). It is never copied from another home.
const StoreInstanceFile = "etna-store-instance"

// writeStoreInstance gives the fresh stores in data a fresh instance ID and returns it,
// atomically: a private temporary file with a random name (so a stale temporary from an
// interrupted run cannot block a retry), its fsync, a rename over any old ID and the directory's
// fsync. The validator's signer then fences through its last signed height until a committed
// chain covers it (RECOV-8.2-2).
func writeStoreInstance(data string) (string, error) {
	var id [16]byte
	if _, err := rand.Read(id[:]); err != nil {
		return "", err
	}
	value := hex.EncodeToString(id[:])
	temp, err := os.CreateTemp(data, "."+StoreInstanceFile+".*")
	if err != nil {
		return "", err
	}
	name := temp.Name()
	defer os.Remove(name)
	_, writeErr := temp.WriteString(value + "\n")
	if err = errors.Join(writeErr, temp.Chmod(0o600), temp.Sync(), temp.Close()); err != nil {
		return "", err
	}
	if err = os.Rename(name, filepath.Join(data, StoreInstanceFile)); err != nil {
		return "", err
	}
	return value, syncDir(data)
}
