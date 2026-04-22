# Release workflow

## Testnet release PRs and main development

- All development work goes into the main branch.
- When we release a testnet, we will open a release branch e.g., [alpha-6](https://github.com/taikoxyz/taiko-mono/tree/alpha-6).
- For future releases we continue working on the main branch!
- For bug fixes first try to fix on `main` and cherry-pick into the release branch. If not possible due to large changes on main, fix on the release branch and check if a similar bug fix is needed on main.
