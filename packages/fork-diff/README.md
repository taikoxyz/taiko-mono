# Overview

**See the fork diff page at [geth.taiko.xyz](https://geth.taiko.xyz).**

This package contains:

- The `fork.yaml` configuration which is used by [forkdiff](https://github.com/protolambda/forkdiff) to generate the `index.html`.
- The `main.go` file which is also used by [forkdiff](https://github.com/protolambda/forkdiff) to generate the `index.html` (just makes "Other changes" and "Ignored changes" lowercase to look cleaner).

## Steps to update the fork diff page

First update `version_config.json` to the geth version you want to compare against the `taiko` branch of `taiko-geth`.

### Preview release

1. Make any desired changes to `fork.yaml`, and then open a PR.
2. Vercel will deploy a preview, check this preview and see if it looks good.
3. Merge the PR.

### Production release

1. Merge the fork-diff release branch.

### Manual workflow dispatch

> Delete this step after implementing git tag workflow in taiko-geth.

There is a workflow dispatch you can use to manually trigger a preview or production release via the GitHub UI, because there could be a diff on the `taiko` branch in `taiko-geth`, and we don't use git tags there (yet). If doing a manual workflow dispatch make sure to first do it in preview and make sure it looks good!

> It is possible that state expiry might be unnecessary in a world where Verkle Tries succeed at their goals.

can anyone explain this like im 5. i dont even know what a verkle trie is outside of ppl saying merkle tries r annoying and these r better.
