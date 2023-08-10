# Contributing manual

**Table of contents:**

- [Make a contribution](#make-a-contribution)
- [Coding standards](#coding-standards)
- [Documentation standards](#documentation-standards)

## Make a contribution

Here are some ways you can contribute:

- Open a new issue [here](https://github.com/taikoxyz/taiko-mono/issues) (please check the issue does not already exist).
- Work on an existing issue (check out the [good first issues list](https://github.com/orgs/taikoxyz/projects/9/views/31) on our public project board).

Please comment on the issue that you're interested in working on. Also, check out the [coding standards](#coding-standards) and [documentation standards](#documentation-standards) before you start working on the pull request.

Once the pull request is merged to one of Taiko's GitHub repositories (you can see which repositories here: [2023 Taiko Contributor GitPOAP](https://www.gitpoap.io/gp/893)), you will be automatically awarded a Taiko Contributor GitPOAP. Opening a good new issue (not a spam issue) is also eligible for a GitPOAP, just leave a comment and we will manually invoke a GitHub bot that will send the GitPOAP.

## Coding standards

This section describes our coding standards at Taiko.

### Pull requests

Specify the scope of your change with a [conventional commit](https://www.conventionalcommits.org/en/v1.0.0/) in the PR title (for example, `feat(scope): description of feature`). This will be squashed and merged into the `main` branch. You can find the full list of allowed scopes [here](https://github.com/taikoxyz/taiko-mono/blob/main/.github/workflows/lint-pr.yml#L19).

Because we squash all of the changes into a single commit, please try to keep the PR limited to the scope specified in the commit message. This commit message will end up in the automated changelog by checking which packages are affected by the commit.

For example, `feat(scope): description of feature` should only impact the `scope` package. If your change is a global one, you can use `feat: description of feature`, for example.

### Source code comments

Follow the [NatSpec format](https://docs.soliditylang.org/en/latest/natspec-format.html) for documenting smart contract source code. Please adhere to a few additional standards:

#### Multi-line comments

Choose `/** */` over `///` for multi-line NatSpec comments to save column space.

#### Notice tag

Omit the usage of `@notice` and let the compiler automatically pick it up to save column space. For example, this:

```
/// @notice This is a notice.
```

becomes this:

```
/// This is a notice.
```

#### Annotation indentation

For multi-line annotations, do not "align". For example, this is **wrong**:

```
/**
 * Here is a comment.
 * @param someParam Here is a long parameter blah blah blah
 *        and I wrap it to here.
 * @return someThing Here is a long return parameter blah
 *                   and I wrap it to here.
 */
```

This is **correct**:

```
/**
 * Here is a comment.
 * @param someParam Here is a long parameter blah blah blah
 * and I wrap it to here.
 * @return someThing Here is a long return parameter blah
 * and I wrap it to here.
 */
```

#### Extra line breaks

Use extra line breaks as you see fit. By default, do not use them unless it improves the readability.

This is **preferred**:

```
/**
 * Here is a comment.
 * @param someParam Here is a long parameter blah blah blah
 * and I wrap it to here.
 * @return someThing Here is a long return parameter blah
 * and I wrap it to here.
 */
```

This is also **okay**:

```
/**
 * Here is a comment.
 *
 * @param someParam Here is a long parameter blah blah blah
 * and I wrap it to here.
 * @return someThing Here is a long return parameter blah
 * and I wrap it to here.
 */
```

#### Additional comments

You can use additional comments with `//`. These can be above what it is describing **or** to the side. Try to remain consistent in what you are commenting. Do not use `/* */`. You can align comments on the side or not, whichever improves readability.

This is **correct**:

```
struct Some {
  // This is foo
  uint256 foo;
  uint256 bar; // This is bar
}
```

This is **wrong**:

```
struct Some {
  uint256 foo; /* This is foo */
}
```

#### Periods

Periods are optional for comments, but recommended if it's a proper sentence. However, remain consistent in whatever file or section you are commenting.

This is **correct**:

```
struct Some {
  // This is foo
  uint256 foo;
}
```

This is **wrong**:

```
struct Some {
  // This is foo.
  uint256 foo;
  // This is bar
  uint256 bar;
}
```

## Documentation standards

This section describes our documentation standards at Taiko.

### Philosophies

- Create the minimum viable documentation.
- Don't repeat yourself, use links to existing documentation or inherit it.
- Keep documentation close to what it's describing (for example, in the source code).

### Writing style

Use the [Microsoft Writing Style Guide](https://learn.microsoft.com/en-us/style-guide/welcome/) as a base point of reference for writing style. Generally, don't worry too much about things like typos. What's more important is following the basic [philosophies](#philosophies) outlined above and following structural standards for highly readable and minimal documentation.

### Creating content

If you are interested in creating some content (video, blog post, tweet thread, visuals, etc.), you are absolutely free to do so. It's useful to get a peer review on these, if you need a peer review please reach out to the community / team on the [Taiko Discord](https://discord.gg/taikoxyz).

If you are looking for some more guidance on creating content, you can consult the [Taiko content guide](https://hackmd.io/@taikolabs/BJurgF1bn).
