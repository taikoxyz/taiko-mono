// etna-comet-import reads and verifies independent stock state for export, installs
// authenticated checkpoint windows into fresh offline stock stores, and repairs a generation's
// first block after the stock handshake stopped on it (CONS-3.1-9).
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

	"github.com/cometbft/cometbft/libs/log"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client-rs/tools/etna-signer/internal/checkpoint"
)

func run(args []string) error {
	if len(args) != 0 && args[0] == "verify-export" {
		return verifyExport(args[1:])
	}
	if len(args) != 0 && args[0] == "snapshot-height" {
		return snapshotHeight(args[1:])
	}
	if len(args) != 0 && args[0] == "export-first-block" {
		return exportFirstBlock(args[1:])
	}
	if len(args) != 0 && args[0] == "repair-first-block" {
		return repairFirstBlock(args[1:])
	}
	if len(args) == 0 || args[0] != "install" {
		return errors.New("expected install, snapshot-height, verify-export, export-first-block or repair-first-block")
	}
	flags := flag.NewFlagSet("install", flag.ContinueOnError)
	home := flags.String("home", "", "absent stock home to create")
	stockDir := flags.String("stock-dir", "", "directory holding genesis.json, validator-state.bin and blocks.jsonl")
	appHash := flags.String("app-hash", "", "post-s AppHash appHash(ELHash(s), valStateHash(s)) as 0x and 32 bytes")
	if err := flags.Parse(args[1:]); err != nil {
		return err
	}
	if flags.NArg() != 0 {
		return errors.New("unexpected positional arguments")
	}
	if *home == "" || *stockDir == "" || *appHash == "" {
		return errors.New("install requires --home, --stock-dir and --app-hash")
	}
	if len(*appHash) != 66 || !strings.HasPrefix(*appHash, "0x") {
		return errors.New("--app-hash must be 0x and 32 bytes")
	}
	hash, err := hex.DecodeString((*appHash)[2:])
	if err != nil {
		return fmt.Errorf("--app-hash: %w", err)
	}
	report, err := checkpoint.Install(*home, *stockDir, hash)
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

// exportFirstBlock prints, as one blocks.jsonl line, the certified first block of a stopped
// node's generation: the original block, its own-height commit and the genesis committee.
func exportFirstBlock(args []string) error {
	flags := flag.NewFlagSet("export-first-block", flag.ContinueOnError)
	home := flags.String("home", "", "stopped stock home holding the generation's first block")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if flags.NArg() != 0 || *home == "" {
		return errors.New("export-first-block requires only --home")
	}
	item, err := checkpoint.ExportFirstBlock(*home)
	if err != nil {
		return err
	}
	return json.NewEncoder(os.Stdout).Encode(item)
}

// repairFirstBlock repairs a stopped home whose stock handshake stops on the generation's first
// block (CONS-3.1-9), printing one JSON report line.
func repairFirstBlock(args []string) error {
	flags := flag.NewFlagSet("repair-first-block", flag.ContinueOnError)
	home := flags.String("home", "", "stopped stock home whose handshake stops on the first block")
	backup := flags.String("backup", "", "absent directory, outside <home>/data, receiving a copy of <home>/data")
	app := flags.String("app", "", "the running app's ABCI address (tcp://host:port or unix://path)")
	peer := flags.String("peer-export", "", "optional export-first-block output of a peer of the same genesis")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if flags.NArg() != 0 || *home == "" || *backup == "" || *app == "" {
		return errors.New("repair-first-block requires --home, --backup and --app")
	}
	report, err := checkpoint.RepairFirstBlock(checkpoint.RepairOptions{
		Home: *home, Backup: *backup, App: *app, PeerExport: *peer,
		Logger: log.NewTMLogger(log.NewSyncWriter(os.Stderr)),
	})
	if err != nil {
		return err
	}
	return json.NewEncoder(os.Stdout).Encode(report)
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		if errors.Is(err, checkpoint.ErrExportValStateMismatch) || errors.Is(err, checkpoint.ErrFirstBlockContradiction) {
			os.Exit(2)
		}
		os.Exit(1)
	}
}
