# Overview

This package contains:

- An `index.html` which shows the diff between [taiko-geth](https://github.com/taikoxyz/taiko-geth) and [go-ethereum](https://github.com/ethereum/go-ethereum).
- The `fork.yaml` configuration which is used by [forkdiff](https://github.com/protolambda/forkdiff) to generate the `index.html`.
- The `main.go` file which is also used by [forkdiff](https://github.com/protolambda/forkdiff) to generate the `index.html` (just makes "Other changes" and "Ignored changes" lowercase to look cleaner).

## Steps to update the fork diff page

To update the `index.html` (which shows the diff):

1. Clone [forkdiff](https://github.com/protolambda/forkdiff), [taiko-geth](https://github.com/taikoxyz/taiko-geth), and [go-ethereum](https://github.com/ethereum/go-ethereum) into the same working directory.
2. Make any of the desired updates to `fork.yaml` and then copy `fork.yaml` from this package to the root of the forkdiff repo.
3. From the root of the forkdiff repo, run `go run main.go -repo ../taiko-geth/ -upstream-repo ../go-ethereum/`.
4. Copy the output `index.html` to this package and commit it.
