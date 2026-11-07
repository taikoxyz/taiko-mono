package checkpoint

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"syscall"

	dbm "github.com/cometbft/cometbft-db"
	"github.com/syndtr/goleveldb/leveldb/opt"
)

// The leading zero and namespace cannot be confused with a stock v0.40 state,
// blockstore or evidence key. The value also binds the role, preventing swaps.
const storeIdentityKey = "\x00etna/app-import/db-identity/v1"

var storeRoles = [...]string{"state", "blockstore", "evidence"}

func storeIdentityValue(role string, id [32]byte) []byte {
	return append([]byte(role+"\x00"), id[:]...)
}

// checkIdentityClaim permits writes only into an explicit, controller-owned,
// unpublished stock home. Fixed-genesis initialization must create all three DBs.
func checkIdentityClaim(home string, id [32]byte, fixed bool) error {
	if err := checkParents(filepath.Join(home, "data", "entry")); err != nil {
		return err
	}
	path := filepath.Join(home, ".etna-stock-staging.json")
	info, err := os.Lstat(path)
	if err != nil {
		return err
	}
	stat, ok := info.Sys().(*syscall.Stat_t)
	if !ok || !info.Mode().IsRegular() || info.Mode().Perm()&0077 != 0 || stat.Nlink != 1 || stat.Uid != uint32(os.Geteuid()) || info.Size() > 2048 {
		return errors.New("unprotected stock identity claim")
	}
	b, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	var claim struct {
		Schema int    `json:"schema"`
		ID     string `json:"installation_id"`
		Fixed  bool   `json:"fixed_origin"`
	}
	if err = json.Unmarshal(b, &claim); err != nil || claim.Schema != 1 || claim.ID != "0x"+hex.EncodeToString(id[:]) || claim.Fixed != fixed || id == [32]byte{} {
		return errors.New("invalid stock identity claim")
	}
	return nil
}

// BindStoreIdentity reserves a private key inside each of the three genuine stock databases.
// At a fixed origin they must all be absent. A nonorigin bootstrap requires preexisting
// databases that the controller has just verified and installed into its own staging tree.
func BindStoreIdentity(home string, id [32]byte, fixedOrigin bool) error {
	if err := checkIdentityClaim(home, id, fixedOrigin); err != nil {
		return err
	}
	data := filepath.Join(home, "data")
	for _, role := range storeRoles {
		if fixedOrigin {
			if _, err := os.Lstat(filepath.Join(data, role+".db")); !errors.Is(err, os.ErrNotExist) {
				return errors.New("fixed origin requires fresh stock stores")
			}
		} else {
			db, err := openReadOnly(home, role)
			if err != nil {
				return err
			}
			prior, readErr := db.Get([]byte(storeIdentityKey))
			closeErr := db.Close()
			if readErr != nil {
				return readErr
			}
			if closeErr != nil {
				return closeErr
			}
			if prior != nil {
				return errors.New("stock store already has an import identity")
			}
		}
	}
	for _, role := range storeRoles {
		db, err := dbm.NewGoLevelDBWithOpts(role, data, &opt.Options{ErrorIfExist: fixedOrigin, ErrorIfMissing: !fixedOrigin})
		if err != nil {
			return err
		}
		writeErr := db.SetSync([]byte(storeIdentityKey), storeIdentityValue(role, id))
		closeErr := db.Close()
		if writeErr != nil {
			return writeErr
		}
		if closeErr != nil {
			return closeErr
		}
		if err = syncDir(filepath.Join(data, role+".db")); err != nil {
			return err
		}
	}
	if err := syncDir(data); err != nil {
		return err
	}
	if err := CheckStoreIdentity(home, id); err != nil {
		return err
	}
	if err := os.Remove(filepath.Join(home, ".etna-stock-staging.json")); err != nil {
		return err
	}
	return syncDir(home)
}

// CheckStoreIdentity checks the actual LevelDB key in each role under stock's read-only lock.
// A live writer, missing store, foreign installation or role substitution fails closed.
func CheckStoreIdentity(home string, id [32]byte) error {
	if id == [32]byte{} {
		return errors.New("invalid empty stock installation identity")
	}
	for _, role := range storeRoles {
		db, err := openReadOnly(home, role)
		if err != nil {
			return err
		}
		got, readErr := db.Get([]byte(storeIdentityKey))
		closeErr := db.Close()
		if readErr != nil {
			return readErr
		}
		if closeErr != nil {
			return closeErr
		}
		if !bytes.Equal(got, storeIdentityValue(role, id)) {
			return errors.New("stock database installation or role mismatch: " + role)
		}
	}
	return nil
}
