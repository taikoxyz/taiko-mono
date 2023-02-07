# Taiko contributing guide

**Table of contents:**

- [Make a contribution](#make-a-contribution)
- [Claim a Taiko Contributor GitPOAP](#claim-a-taiko-contributor-gitpoap)
- [Coding standards](#coding-standards)
- [Documentation standards](#documentation-standards)

# Make a contribution

Here are some ways you can contribute:

- Open a new issue [here](https://github.com/taikoxyz/taiko-mono/issues).
- Work on an existing issue (check out the [good first issues list](https://github.com/taikoxyz/taiko-mono/labels/good%20first%20issue)).

> Check out the [coding standards](#coding-standards) and [documentation standards](#documentation-standards) before you start working on a pull request.

# Claim a Taiko Contributor GitPOAP

A Taiko Contributor GitPOAP is rewarded to anyone that merges in a pull request to one of Taiko's GitHub repositories (for example: [2023 Taiko Contributor GitPOAP](https://www.gitpoap.io/gp/893)).

After your pull request is merged, a bot will automatically leave a comment with instructions to receive your GitPOAP. You only receive a Taiko Contributor GitPOAP for the first pull request you merge in a given year.

# Coding standards

### Pull requests

Specify the scope of your change with a [conventional commit](https://www.conventionalcommits.org/en/v1.0.0/) in the PR title (for example, `feat(scope): description of feature`). This will be squashed and merged into the `main` branch.

Because we squash all of the changes into a single commit, please try to keep the PR limited to the scope specified in the commit message. This commit message will end up in the automated changelog by checking which packages are affected by the commit. For example, `feat(scope): description of feature` should only impact the `scope` package. If your change is a global one, you can use `feat: description of feature`, for example.

### Source code comments

Follow the [NatSpec format](https://docs.soliditylang.org/en/latest/natspec-format.html) for documenting smart contract source code. Please adhere to a few additional standards:

- Choose `/** */` over `///` for multi-line NatSpec comments to save column space.
- Omit the usage of `@notice` and let the compiler automatically pick it up to save column space.
  - For example: `/** @notice This is a notice */` becomes `/** This is a notice */`.

# Documentation standards

Use the [Microsoft Writing Style Guide](https://learn.microsoft.com/en-us/style-guide/welcome/) as a base point of reference.

### Philosophy

- Create the minimum viable documentation.
- Don't repeat yourself, use links to existing documentation or inherit it.
- Keep documentation close to what it's describing (for example, in the source code).

### Document types

Group documentation under one of the four categories (adopted from [Diátaxis](https://diataxis.fr/)):

- How to
- Concepts
- Tutorials
- Reference

### Images

- Use SVG files or crushed PNG images.
- Provide alt text.
