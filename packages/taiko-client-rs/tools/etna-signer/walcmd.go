package main

import (
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"io"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client-rs/tools/etna-signer/internal/walcheck"
)

// The supervisor's WAL helpers (RECOV-8.2-2). The supervisor runs them as the Comet UID; the
// serving signer never reads Comet's files. Each prints one JSON object.

// walBindingCommand is `etna-signer wal-binding --wal W --marker M`: the live binding of the
// signing request Comet is waiting on, {"binding": null} when `#ENDHEIGHT M` is absent.
func walBindingCommand(args []string, out io.Writer) error {
	flags := flag.NewFlagSet("wal-binding", flag.ContinueOnError)
	wal := flags.String("wal", "", "Comet's consensus WAL head file")
	marker := flags.Int64("marker", -1, "the predecessor end-height marker")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if *wal == "" || *marker < 0 || flags.NArg() != 0 {
		return errors.New("wal-binding requires --wal and --marker")
	}
	binding, err := walcheck.Live(*wal, *marker)
	if err != nil {
		return err
	}
	return json.NewEncoder(out).Encode(map[string]any{"binding": binding})
}

// walPreflightCommand is `etna-signer wal-preflight`: the startup check of the signer's saved
// binding against a stopped node's WAL and stores.
func walPreflightCommand(args []string, out io.Writer) error {
	flags := flag.NewFlagSet("wal-preflight", flag.ContinueOnError)
	wal := flags.String("wal", "", "Comet's consensus WAL head file")
	dbDir := flags.String("db-dir", "", "Comet's goleveldb store directory")
	height := flags.Int64("height", 0, "the height of the last signature")
	marker := flags.Int64("marker", -1, "the bound predecessor end-height marker")
	length := flags.Int64("length", -1, "the bound prefix length")
	digest := flags.String("digest", "", "the bound prefix SHA-256, hex")
	predecessor := flags.String("predecessor", "", "the bound predecessor block hash, hex; empty at the initial height")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if *wal == "" || *dbDir == "" || *height <= 0 || *marker < 0 || *length < 0 || len(*digest) != 64 || flags.NArg() != 0 {
		return errors.New("wal-preflight requires --wal, --db-dir, --height, --marker, --length and --digest")
	}
	hash, err := hex.DecodeString(*predecessor)
	if err != nil {
		return err
	}
	result, err := walcheck.Check(*wal, *dbDir, *height, walcheck.Binding{Marker: *marker, Length: *length, Digest: *digest}, hash)
	if err != nil {
		return err
	}
	return json.NewEncoder(out).Encode(result)
}

// cometHeadCommand is `etna-signer comet-head --db-dir D`: the committed height of a stopped
// node and its block hash, {"height": n, "hash": "<hex>"}.
func cometHeadCommand(args []string, out io.Writer) error {
	flags := flag.NewFlagSet("comet-head", flag.ContinueOnError)
	dbDir := flags.String("db-dir", "", "Comet's goleveldb store directory")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if *dbDir == "" || flags.NArg() != 0 {
		return errors.New("comet-head requires --db-dir")
	}
	height, hash, err := walcheck.Head(*dbDir)
	if err != nil {
		return err
	}
	return json.NewEncoder(out).Encode(map[string]any{"height": height, "hash": hex.EncodeToString(hash)})
}
