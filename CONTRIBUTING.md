# Contributing guide

This contributing guide is divided into the following sections:

1. [Make a contribution](#make-a-contribution)
2. [Claim a GitPOAP](#claim-a-gitpoap)
3. [Git standards](#git-standards)
4. [Documentation style guide](#documentation-style-guide)

# Make a contribution

We use [GitHub issues](https://github.com/taikoxyz/taiko-mono/issues) to track work. We use [GitHub discussions](https://github.com/taikoxyz/taiko-mono/discussions) to ask questions and talk about ideas.

## Opening a new issue

If you are opening a new issue, try to be descriptive as possible. Also please check if an existing issue already exists for it already.

## Working on an issue

If you are looking for a good issue to start with, look for issues tagged with "good first issue". Once you've found an issue to work on, you can assign it to yourself on GitHub and/or leave a comment that you're picking it up. Take a look at our [git standards](#git-standards).

## Ask questions and start discussions

You can participate in questions and discussions under our [GitHub discussions](https://github.com/taikoxyz/taiko-mono/discussions).

# Claim a GitPOAP

We are rewarding community contributions with a GitPOAP. This guide explains the requirements to claim a GitPOAP.

## XXXX Taiko Contributor GitPOAP

The XXXX Taiko Contributor GitPOAP is intended for anyone who makes a meaningful contribution to Taiko during the year XXXX. You can only earn this in the following ways:

- Receive an accepted answer under [GitHub Discussions](https://github.com/taikoxyz/taiko-mono/discussions)
- Merge in a change to one of [our GitHub repos](https://github.com/taikoxyz)

## How do I receive my GitPOAP?

There are two ways to receive a GitPOAP:

- If you merged in a pull request, the gitpoap-bot should have left you a comment to receive your GitPOAP like so:
  ![](/assets/images/2022-12-14-09-30-37.png)
- If you made another contribution which fits the requirements of the GitPOAP, please ping the team on Discord so we can issue a GitPOAP manually.

# Git standards

## Creating commits

Try to specify the scope of your change via a [conventional commit](https://www.conventionalcommits.org/en/v1.0.0/) (eg. `enhance(docs): improve some section`) or specifying the scope in brackets (eg. `[docs] improve some section`).

## Submitting a PR

Please make sure to use a conventional commit in your PR title (eg. `feat(scope): description of feature`). This will be squashed and merged into the `main` branch.

## GitHub Actions

Each commit will automatically trigger the GitHub Actions to run. If any commit message in your push or the HEAD commit of your PR contains the strings [skip ci], [ci skip], [no ci], [skip actions], or [actions skip] workflows triggered on the push or pull_request events will be skipped.

# Documentation style guide

Many standards are adopted from [Google dev docs highlights](https://developers.google.com/style/highlights).

## Philosophy

- Create the [minimum viable documentation](https://google.github.io/styleguide/docguide/best_practices.html#minimum-viable-documentation).
- Don't repeat yourself, use links to existing documentation or inherit it.
- Keep documentation close to what it's describing, also called high cohesion (eg. describing a smart contract should be documented as comments in the source code).

## Document types

Group documentation under one of the four categories (adopted from [Diátaxis](https://diataxis.fr/)):

- Tutorials
- Guides
- Concepts
- Reference

## Tone and content

- [Use descriptive link text](https://developers.google.com/style/link-text).
- [Write accessibly](https://developers.google.com/style/accessibility).
- [Write for a global audience](https://developers.google.com/style/translation).

## Language and grammar

- [Use second person](https://developers.google.com/style/person): "you" rather than "we".
- [Use active voice](https://developers.google.com/style/voice): make clear who's performing the action.
- [Put conditional clauses before instructions](https://developers.google.com/style/clause-order), not after.

## Formatting, punctuation, and organization

- [Use sentence case](https://developers.google.com/style/capitalization) for document titles and section headings.
- [Use numbered lists](https://developers.google.com/style/lists#types-of-lists) for sequences.
- [Use bulleted lists](https://developers.google.com/style/lists#types-of-lists) for most other lists.
- [Use description lists](https://developers.google.com/style/lists#types-of-lists) for pairs of related pieces of data.
- [Use serial commas](https://developers.google.com/style/commas).
- [Use unambiguous date formatting](https://developers.google.com/style/dates-times).

## Source code comments

Follow the [NatSpec format](https://docs.soliditylang.org/en/v0.8.16/natspec-format.html) for documenting smart contract source code. Please adhere to a few additional standards:

- Choose `/** */` over `///` for multi-line NatSpec comments, to save column space
- Omit the usage of `@notice`, this will be automatically picked up so it will save column space and improve readability
- Take advantage of inheritance for docs (such as documenting the interface), if you need to specify inherited docs use `@inheritdoc`

## Images

- Use SVG files or crushed PNG images.
- Provide alt text.
