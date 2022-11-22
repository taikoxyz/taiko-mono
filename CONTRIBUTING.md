# Contributing guide

## Table of contents

1. [Issue guide](#issue-guide)
2. [Coding style guide](#coding-style-guide)
3. [Documentation style guide](#documentation-style-guide)

## Issue guide

As an open source project, you are free to open issues and work on issues. Please comment on the issue discussion if you are thinking of contributing or picking something up, so as to not overlap on any work.

### Finding an issue to work on

If you are looking for a good issue to start with, look for issues tagged with "good first issue".

### Opening a new issue

If you are opening a new issue, try to be descriptive as possible. Also please check if an existing issue already exists for it already.

## Coding style guide

### Source code comments

Follow the [NatSpec format](https://docs.soliditylang.org/en/v0.8.16/natspec-format.html) for documentating smart contract source code. Please adhere to a few additional standards:

- Choose `/** */` over `///` for multi-line NatSpec comments, to save column space
- Omit the usage of `@notice`, this will be automatically picked up so it will save column space and improve readability
- Take advantage of inheritance for docs (such as documenting the interface), if you need to specify inherited docs use `@inheritdoc`

### Git standards

#### Commits

Try to specify the scope of your change via a [conventional commit](https://www.conventionalcommits.org/en/v1.0.0/) (eg. `enhance(docs): improve some section`) or specifying the scope in brackets (eg. `[docs] improve some section`).

## Documentation style guide

### Document types

Group documentation under one of the four categories:

- Tutorials
- Guides
- Concepts
- Reference

### Philosophy

- Aim for "better" instead of "perfect" -- any enhancement is a worthwhile improvement.
- Create the minimum viable documentation.
- Don't repeat yourself, use links to existing documentation or inherit it.
- Generate documentation automatically from source code whenever possible.
- Keep your comments as close as possible to the actual source code it is describing.

### Standards

#### Tone and content

- [Use descriptive link text](https://developers.google.com/style/link-text).
- [Write accessibly](https://developers.google.com/style/accessibility).
- [Write for a global audience](https://developers.google.com/style/translation).

#### Language and grammar

- [Use second person](https://developers.google.com/style/person): "you" rather than "we".
- [Use active voice](https://developers.google.com/style/voice): make clear who's performing the action.
- [Put conditional clauses before instructions](https://developers.google.com/style/clause-order), not after.

#### Formatting, punctuation, and organization

- [Use sentence case](https://developers.google.com/style/capitalization) for document titles and section headings.
- [Use numbered lists](https://developers.google.com/style/lists#types-of-lists) for sequences.
- [Use bulleted lists](https://developers.google.com/style/lists#types-of-lists) for most other lists.
- [Use description lists](https://developers.google.com/style/lists#types-of-lists) for pairs of related pieces of data.
- [Use serial commas](https://developers.google.com/style/commas).
- [Use unambiguous date formatting](https://developers.google.com/style/dates-times).

#### Images

- Use SVG files or crushed PNG images.
- Provide alt text.

#### Code blocks

- Do not use `$` in shell blocks.

  Incorrect ❌:

  ```sh
  $ echo "this is worse for copy paste"
  ```

  Correct ✅:

  ```sh
  echo "this is better for copy paste"
  ```

- Escape new lines.

  Incorrect ❌:

  ```sh
  echo "going to pretend that this"
  && echo "is some really long command"
  ```

  Correct ✅:

  ```sh
  echo "at least the command" \
  && echo "looks good when copy pastad"
  ```

## References

- [Diátaxis](https://diataxis.fr/)
- [Google dev docs highlights](https://developers.google.com/style/highlights)
- [Google docs styleguide](https://google.github.io/styleguide/docguide/)
