// etna-comet-import verifies and installs public checkpoint data into fresh offline stock stores.
package main

import (
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
		return errors.New("expected verify, install or export")
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
	if err := flags.Parse(args[1:]); err != nil {
		return err
	}
	if flags.NArg() != 0 {
		return errors.New("unexpected positional arguments")
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
	v, err := checkpoint.VerifyStream(f, checkpoint.Trust{CometHash: *comet, ELHash: *el, ValStateHash: *val}, "", *limit)
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
func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		var contradiction *checkpoint.ContradictionError
		if errors.As(err, &contradiction) {
			os.Exit(2)
		}
		os.Exit(1)
	}
}
