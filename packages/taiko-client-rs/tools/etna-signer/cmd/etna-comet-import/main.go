// etna-comet-import installs an authenticated checkpoint window into fresh offline stock stores.
package main

import (
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"strings"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client-rs/tools/etna-signer/internal/checkpoint"
)

func run(args []string) error {
	if len(args) == 0 || args[0] != "install" {
		return errors.New("expected install")
	}
	flags := flag.NewFlagSet("install", flag.ContinueOnError)
	home := flags.String("home", "", "absent stock home to create")
	stockDir := flags.String("stock-dir", "", "directory holding genesis.json, validator-state.bin and blocks.jsonl")
	appHash := flags.String("app-hash", "", "post-s AppHash ELHash(s) as 0x and 32 bytes")
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

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
