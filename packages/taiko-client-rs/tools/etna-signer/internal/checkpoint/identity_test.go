package checkpoint

import (
	"fmt"
	dbm "github.com/cometbft/cometbft-db"
	"os"
	"path/filepath"
	"testing"
)

func TestStoreIdentityBindsEachRoleAndRejectsReplacement(t *testing.T) {
	home, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(filepath.Join(home, "data"), 0700); err != nil {
		t.Fatal(err)
	}
	id := [32]byte{1}
	claim := func(fixed bool) {
		t.Helper()
		if err := os.WriteFile(filepath.Join(home, ".etna-stock-staging.json"), []byte(fmt.Sprintf(`{"schema":1,"installation_id":"0x%x","fixed_origin":%t}`, id, fixed)), 0600); err != nil {
			t.Fatal(err)
		}
	}
	claim(true)
	if err := BindStoreIdentity(home, id, true); err != nil {
		t.Fatal(err)
	}
	if err := CheckStoreIdentity(home, id); err != nil {
		t.Fatal(err)
	}
	if err := CheckStoreIdentity(home, [32]byte{2}); err == nil {
		t.Fatal("foreign operation accepted")
	}
	claim(true)
	if err := BindStoreIdentity(home, id, true); err == nil {
		t.Fatal("fixed-origin stage accepted existing stores")
	}
	data := filepath.Join(home, "data")
	evidence, err := dbm.NewGoLevelDB("evidence", data)
	if err != nil {
		t.Fatal(err)
	}
	if err = evidence.SetSync([]byte("new-stock-record"), []byte("normal progress")); err != nil {
		t.Fatal(err)
	}
	evidence.Close()
	if err = CheckStoreIdentity(home, id); err != nil {
		t.Fatal(err)
	}
	if err = os.Rename(filepath.Join(data, "evidence.db"), filepath.Join(data, "old-evidence")); err != nil {
		t.Fatal(err)
	}
	if err = os.Rename(filepath.Join(data, "state.db"), filepath.Join(data, "evidence.db")); err != nil {
		t.Fatal(err)
	}
	foreign, err := dbm.NewGoLevelDB("state", data)
	if err != nil {
		t.Fatal(err)
	}
	foreign.Close()
	if err = CheckStoreIdentity(home, id); err == nil {
		t.Fatal("mixed databases accepted")
	}
	claim(false)
	if err = BindStoreIdentity(home, id, false); err == nil {
		t.Fatal("existing role marker overwritten")
	}
}
