// etna-comet-import verifies and installs public checkpoint data into fresh offline stock stores.
package main

import (
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client-rs/tools/etna-signer/internal/checkpoint"
)

func run(args []string) error {
	if len(args) == 0 {
		return errors.New("expected verify, install, export, bind-stores or check-stores")
	}
	flags := flag.NewFlagSet(args[0], flag.ContinueOnError)
	pkg := flags.String("package", "", "stock package JSON")
	home := flags.String("home", "", "fresh install or offline export home")
	comet := flags.String("trusted-comet-hash", "", "own L1 verified Comet hash")
	el := flags.String("trusted-el-hash", "", "own L1 verified execution hash")
	val := flags.String("trusted-val-state-hash", "", "own L1 verified validator-state hash")
	preimage := flags.String("validator-state", "", "raw terminal preimage file")
	first := flags.Int64("first-height", 0, "first included height")
	last := flags.Int64("last-height", 0, "last included height")
	limit := flags.Int64("max-package-bytes", checkpoint.MaxStreamPackageBytes, "complete package disk-spool byte limit")
	output := flags.String("output", "", "new export JSON file")
	spoolParent := flags.String("spool-parent", "", "owned discardable parent for bounded package spool")
	installationID := flags.String("installation-id", "", "32-byte local installation identity")
	fixedOrigin := flags.Bool("fixed-origin", false, "bind fresh empty fixed-origin stores")
	if err := flags.Parse(args[1:]); err != nil {
		return err
	}
	if flags.NArg() != 0 {
		return errors.New("unexpected positional arguments")
	}
	if args[0] == "bind-stores" || args[0] == "check-stores" {
		if *home == "" || len(*installationID) != 66 || (*installationID)[:2] != "0x" {
			return errors.New("store identity requires home and 32-byte 0x installation-id")
		}
		raw, err := hex.DecodeString((*installationID)[2:])
		if err != nil {
			return err
		}
		var id [32]byte
		copy(id[:], raw)
		if args[0] == "bind-stores" {
			err = checkpoint.BindStoreIdentity(*home, id, *fixedOrigin)
		} else {
			if *fixedOrigin {
				return errors.New("check-stores does not accept fixed-origin")
			}
			err = checkpoint.CheckStoreIdentity(*home, id)
		}
		if err != nil {
			return err
		}
		return json.NewEncoder(os.Stdout).Encode(struct{}{})
	}
	if args[0] == "export" {
		if *home == "" || *preimage == "" || *output == "" {
			return errors.New("export requires home, validator-state and output")
		}
		preimageFile, err := os.Open(*preimage)
		if err != nil {
			return err
		}
		defer preimageFile.Close()
		raw, err := io.ReadAll(io.LimitReader(preimageFile, checkpoint.MaxValidatorStateBytes+1))
		if err != nil {
			return err
		}
		if len(raw) > checkpoint.MaxValidatorStateBytes {
			return errors.New("oversized validator-state preimage")
		}
		f, err := os.OpenFile(*output, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
		if err != nil {
			return err
		}
		defer f.Close()
		if err = checkpoint.ExportTo(f, *home, *first, *last, raw); err != nil {
			return err
		}
		return f.Sync()
	}
	if args[0] != "verify" && args[0] != "install" {
		return errors.New("unknown command")
	}
	if *pkg == "" || *comet == "" || *el == "" || *val == "" {
		return errors.New("verify/install require package and three separately trusted hashes")
	}
	if args[0] == "install" && *home == "" {
		return errors.New("install requires fresh home")
	}
	f, err := os.Open(*pkg)
	if err != nil {
		return err
	}
	defer f.Close()
	v, err := checkpoint.VerifyStream(f, checkpoint.Trust{CometHash: *comet, ELHash: *el, ValStateHash: *val}, *spoolParent, *limit)
	if err != nil {
		return err
	}
	defer v.Close()
	if args[0] == "install" {
		if *home == "" {
			return errors.New("install requires fresh home")
		}
		if err = checkpoint.Install(*home, v); err != nil {
			return err
		}
	}
	return json.NewEncoder(os.Stdout).Encode(v.Report())
}

// writeFailure emits a proof receipt only for a verifier-produced contradiction.
func writeFailure(stdout, stderr io.Writer, err error) int {
	fmt.Fprintln(stderr, err)
	var contradiction *checkpoint.ContradictionError
	if errors.As(err, &contradiction) {
		if err := json.NewEncoder(stdout).Encode(contradiction.Receipt()); err == nil {
			return 2
		}
	}
	var storage *checkpoint.StorageError
	var path *os.PathError
	if errors.As(err, &storage) || errors.As(err, &path) {
		return 3
	}
	return 1
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		os.Exit(writeFailure(os.Stdout, os.Stderr, err))
	}
}
