# Overview

**See the fork diff page at [geth.taiko.xyz](https://geth.taiko.xyz).**

This package contains:

- The `fork.yaml` configuration which is used by [forkdiff](https://github.com/protolambda/forkdiff) to generate the `index.html`.
- The `main.go` file which is also used by [forkdiff](https://github.com/protolambda/forkdiff) to generate the `index.html` (just makes "Other changes" and "Ignored changes" lowercase to look cleaner).

## Steps to update the fork diff page

### Preview release

1. Make any desired changes to `fork.yaml`, and then open a PR.
2. Vercel will deploy a preview, check this preview and see if it looks good.
3. Merge the PR.

### Production release

1. Merge the fork-diff release branch.
