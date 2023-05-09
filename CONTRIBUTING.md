# Taiko contributing guide

**Table of contents:**

- [Make a contribution](#make-a-contribution)
- [Claim a Taiko Contributor GitPOAP](#claim-a-taiko-contributor-gitpoap)
- [Coding standards](#coding-standards)
- [Documentation standards](#documentation-standards)

# Make a contribution

Here are some ways you can contribute:

- Open a new issue [here](https://github.com/taikoxyz/taiko-mono/issues) (please check the issue does not already exist).
- Work on an existing issue (check out the [good first issues list](https://github.com/orgs/taikoxyz/projects/9/views/31) on our public project board).

> Check out the [coding standards](#coding-standards) and [documentation standards](#documentation-standards) before you start working on a pull request.

# Claim a Taiko Contributor GitPOAP

A Taiko Contributor GitPOAP is rewarded to anyone that merges in a pull request to one of Taiko's GitHub repositories (you can see which repositories here: [2023 Taiko Contributor GitPOAP](https://www.gitpoap.io/gp/893)).

After your pull request is merged, a bot will automatically leave a comment with instructions to receive your GitPOAP. You only receive a Taiko Contributor GitPOAP for the first pull request you merge in a given year.

# Coding standards

### Pull requests

Specify the scope of your change with a [conventional commit](https://www.conventionalcommits.org/en/v1.0.0/) in the PR title (for example, `feat(scope): description of feature`). This will be squashed and merged into the `main` branch. You can find the full list of allowed scopes [here](https://github.com/taikoxyz/taiko-mono/blob/main/.github/workflows/lint-pr.yml#L19).

Because we squash all of the changes into a single commit, please try to keep the PR limited to the scope specified in the commit message. This commit message will end up in the automated changelog by checking which packages are affected by the commit.

For example, `feat(scope): description of feature` should only impact the `scope` package. If your change is a global one, you can use `feat: description of feature`, for example.

### Source code comments

Follow the [NatSpec format](https://docs.soliditylang.org/en/latest/natspec-format.html) for documenting smart contract source code. Please adhere to a few additional standards:

- Choose `/** */` over `///` for multi-line NatSpec comments to save column space.
- Omit the usage of `@notice` and let the compiler automatically pick it up to save column space.
  - For example: `/** @notice This is a notice */` becomes `/** This is a notice */`.

# Documentation standards

Use the [Microsoft Writing Style Guide](https://learn.microsoft.com/en-us/style-guide/welcome/) as a base point of reference for writing style.

### Philosophy

- Create the minimum viable documentation.
- Don't repeat yourself, use links to existing documentation or inherit it.
- Keep documentation close to what it's describing (for example, in the source code).

### Document types

Group documentation under one of the four categories (adopted from [Diátaxis](https://diataxis.fr/)):

- Concepts
- Guides
- Reference
- Resources

### Creating content

If you are interested in creating some content (video, blog post, tweet thread, visuals, etc.), you are absolutely free to do so. It's useful to get a peer review on these, if you need a peer review please reach out to the community / team on the [Taiko Discord](https://discord.gg/taikoxyz).

If you are looking for some more guidance on creating content, you can consult the [Taiko content guide](https://hackmd.io/@taikolabs/BJurgF1bn).
