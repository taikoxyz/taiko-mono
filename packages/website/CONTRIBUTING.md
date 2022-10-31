# Contributing

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

#### Source code comments

In general, you should follow the [NatSpec format](https://docs.soliditylang.org/en/v0.8.16/natspec-format.html) for documentating smart contract source code. Please adhere to a few additional standards:

- Use `/** */` over `///` for multiline NatSpec comments
- Omit the usage of `@notice`, this should be automatically picked up so it will save space and improve readability
- Take advantage of inheritance for docs (such as documenting the interface), if you need to specify inherited docs use `@inheritdoc`

### Sources

- [Diátaxis](https://diataxis.fr/)
- [Google dev docs highlights](https://developers.google.com/style/highlights)
- [Google docs styleguide](https://google.github.io/styleguide/docguide/)
