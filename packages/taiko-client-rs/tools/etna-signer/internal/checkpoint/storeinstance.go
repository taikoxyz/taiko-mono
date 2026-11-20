package checkpoint

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"os"
	"path/filepath"
	"syscall"
)

// StoreInstanceFile is a Comet home's store instance ID file in its data directory: 32 lowercase
// hex characters (128 random bits) and a newline, mode 0600. Every path that creates, imports,
// restores or rebuilds the stores writes a fresh one, and the validator's signer binds its key to
// it (RECOV-8.2-2). It is never copied from another home.
const StoreInstanceFile = "etna-store-instance"

// writeStoreInstance gives the fresh stores in data a fresh instance ID, atomically: an exclusive
// temporary file, its fsync, a rename and the directory's fsync.
func writeStoreInstance(data string) (err error) {
	random := make([]byte, 16)
	if _, err = rand.Read(random); err != nil {
		return err
	}
	temporary := filepath.Join(data, "."+StoreInstanceFile+".tmp")
	f, err := os.OpenFile(temporary, os.O_WRONLY|os.O_CREATE|os.O_EXCL|syscall.O_NOFOLLOW, 0600)
	if err != nil {
		return err
	}
	_, writeErr := f.Write([]byte(hex.EncodeToString(random) + "\n"))
	if err = errors.Join(writeErr, f.Sync(), f.Close()); err != nil {
		return errors.Join(err, os.Remove(temporary))
	}
	if err = os.Rename(temporary, filepath.Join(data, StoreInstanceFile)); err != nil {
		return errors.Join(err, os.Remove(temporary))
	}
	return syncDir(data)
}
