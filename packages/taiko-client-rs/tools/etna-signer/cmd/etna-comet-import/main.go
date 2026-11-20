// etna-comet-import reads and verifies independent stock state for export and installs
// authenticated checkpoint windows into fresh offline stock stores.
package main

import (
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client-rs/tools/etna-signer/internal/checkpoint"
)

func run(args []string) error {
	if len(args) != 0 && args[0] == "verify-export" {
		return verifyExport(args[1:])
	}
	if len(args) != 0 && args[0] == "snapshot-height" {
		return snapshotHeight(args[1:])
	}
	if len(args) == 0 || args[0] != "install" {
		return errors.New("expected install, snapshot-height or verify-export")
	}
	flags := flag.NewFlagSet("install", flag.ContinueOnError)
	home := flags.String("home", "", "absent stock home to create")
	stockDir := flags.String("stock-dir", "", "directory holding genesis.json, validator-state.bin and blocks.jsonl")
	appHash := flags.String("app-hash", "", "post-s AppHash appHash(ELHash(s), valStateHash(s)) as 0x and 32 bytes")
	nMax := flags.Int64("n-max", 0, "authenticated committee cap n_max (1..4096), which fixes block.max_bytes")
	if err := flags.Parse(args[1:]); err != nil {
		return err
	}
	if flags.NArg() != 0 {
		return errors.New("unexpected positional arguments")
	}
	if *home == "" || *stockDir == "" || *appHash == "" || *nMax == 0 {
		return errors.New("install requires --home, --stock-dir, --app-hash and --n-max")
	}
	if *nMax < 1 || *nMax > checkpoint.MaxNMax {
		return fmt.Errorf("--n-max must be in 1..%d", checkpoint.MaxNMax)
	}
	if len(*appHash) != 66 || !strings.HasPrefix(*appHash, "0x") {
		return errors.New("--app-hash must be 0x and 32 bytes")
	}
	hash, err := hex.DecodeString((*appHash)[2:])
	if err != nil {
		return fmt.Errorf("--app-hash: %w", err)
	}
	report, err := checkpoint.Install(*home, *stockDir, hash, *nMax)
	if err != nil {
		return err
	}
	return json.NewEncoder(os.Stdout).Encode(report)
}

// snapshotHeight prints, as one JSON line, the height x of the committed state in a stopped
// stock state snapshot; the export it can serve is the one at checkpoint x + 1.
func snapshotHeight(args []string) error {
	flags := flag.NewFlagSet("snapshot-height", flag.ContinueOnError)
	dir := flags.String("comet-state-dir", "", "offline snapshot directory containing the stock state.db")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if flags.NArg() != 0 || *dir == "" {
		return errors.New("snapshot-height requires only --comet-state-dir")
	}
	report, err := checkpoint.SnapshotHeight(*dir)
	if err != nil {
		return err
	}
	return json.NewEncoder(os.Stdout).Encode(report)
}

func verifyExport(args []string) error {
	flags := flag.NewFlagSet("verify-export", flag.ContinueOnError)
	dir := flags.String("comet-state-dir", "", "offline snapshot directory containing the stock state.db")
	path := flags.String("validator-state", "", "authenticated s-1 validator-state preimage")
	chainID := flags.String("chain-id", "", "generation's full Comet chain ID")
	height := flags.Int64("height", -1, "height s-1 of the stock state")
	initial := flags.Int64("initial-height", 0, "original stock InitialHeight")
	blockHash := flags.String("block-hash", "", "hex predecessor Comet block hash (empty at genesis)")
	appHash := flags.String("app-hash", "", "hex app_hash of the authenticated header at s")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if flags.NArg() != 0 || *dir == "" || *path == "" || *chainID == "" ||
		*initial < 1 || *height < *initial-1 {
		return errors.New("verify-export requires the stock state dir, preimage and predecessor identity")
	}
	block, err := hex.DecodeString(*blockHash)
	if err != nil || (*height != *initial-1 && len(block) != 32) || (*height == *initial-1 && len(block) != 0) {
		return errors.New("invalid predecessor block hash")
	}
	app, err := hex.DecodeString(*appHash)
	if err != nil || len(app) != 32 {
		return errors.New("invalid authenticated app hash")
	}
	f, err := os.Open(*path)
	if err != nil {
		return err
	}
	defer f.Close()
	preimage, err := io.ReadAll(io.LimitReader(f, checkpoint.MaxValidatorStateBytes+1))
	if err != nil {
		return err
	}
	return checkpoint.VerifyExportState(*dir, preimage, checkpoint.ExportIdentity{
		ChainID: *chainID, Height: *height, InitialHeight: *initial, LastBlockHash: block, AppHash: app,
	})
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		if errors.Is(err, checkpoint.ErrExportValStateMismatch) {
			os.Exit(2)
		}
		os.Exit(1)
	}
}
