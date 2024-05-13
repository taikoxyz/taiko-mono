---
title: Contributing
description: Learn how to contribute to Taiko.
---

We'd love for any contribution you can make to Taiko. Welcome to the contributing manual!

**Table of contents:**

- [Make a contribution](#make-a-contribution)
- [Coding standards](#coding-standards)
- [Documentation standards](#documentation-standards)

## Make a contribution

Thank you for exploring the opportunity to contribute to Taiko.xyz. Whether you're an experienced developer or just starting, we value and welcome your unique contributions.

**Here are some ways you can contribute:**

- Open a new issue [here](https://github.com/taikoxyz/taiko-mono/issues) (please check the issue does not already exist).
- Work on an existing issue (check out the [good first issues list](https://github.com/orgs/taikoxyz/projects/9/views/31) on our public project board).

Please comment on the issue that you're interested in working on. Also, check out the [coding standards](#coding-standards) and [documentation standards](#documentation-standards) before you start working on the pull request.

Once the pull request is merged to one of Taiko's GitHub repositories (you can see which repositories here: [2024 Taiko Contributor GitPOAP](https://www.gitpoap.io/gp/1092)), you will be automatically awarded a Taiko Contributor GitPOAP. Opening a good new issue (not a spam issue) is also eligible for a GitPOAP, just leave a comment and we will manually invoke a GitHub bot that will send the GitPOAP.

You can learn how to best contribute to Taiko by watching the [“Taiko Contributing Guide - Community Workshop”](https://www.youtube.com/watch?v=xMDSHT5C29c) video on our YouTube channel.

## Coding standards

This section describes our coding standards at Taiko.

### Pull requests

**Basic requirements for PRs**

Before we can consider your contributions, please have a look at the following requirements:

- Any contribution must follow the standards documented in this file.
- The scope must be larger than a simple rename, or typo fix. We kindly request that small, incremental updates be combined into more substantial pull requests. This approach will streamline our development and ensure focus on core improvements.

Specify the scope of your change with a [conventional commit](https://www.conventionalcommits.org/en/v1.0.0/) in the PR title (for example, `feat(scope): description of feature`). This will be squashed and merged into the `main` branch. You can find the full list of allowed scopes [here](https://github.com/taikoxyz/taiko-mono/blob/main/.github/workflows/validate-pr-title.yml#L28).

Because we squash all of the changes into a single commit, please try to keep the PR limited to the scope specified in the commit message. This commit message will end up in the automated changelog by checking which packages are affected by the commit.

For example, `feat(scope): description of feature` should only impact the `scope` package. If your change is a global one, you can use `feat: description of feature`, for example.

**Note:
The taiko team will evaluate all PRs and may close any pull requests that do not follow the standards outlined in this document.
Please note, small pull requests will not be considered for future airdrops. We encourage contributions that make significant enhancements to the project.**

### Source code comments

Follow the [NatSpec format](https://docs.soliditylang.org/en/latest/natspec-format.html) for documenting smart contract source code. Please adhere to a few additional standards:

#### Comment style

Choose `///` over `/** */` for multi-line NatSpec comments for consistency. All NatSpec comments should use `///` instead of `/** */`. Additional explanatory comments should use `//`, even for multi-line comments.

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

#### Mentioning other files in the repo

To mention another contract file in the repo use the standard like this:

```solidity
/// @notice See the documentation in {IProverPool}
```

If you are referring to some struct or function within the file you can use the standard like this:

```solidity
/// @notice See the struct in {TaikoData.Config}
```

#### Documenting interfaces

To document the implementing contract of an interface, you cannot use `@inheritdoc`, it is not supported for contracts. Thus, you should mention a statement like so:

```solidity
/// @notice See the documentation in {IProverPool}
```

You can then mention implementation specific details by adding a `@dev` tag:

```solidity
/// @notice See the documentation in {IProverPool}
/// @dev This implementation uses a ProverPool of size 32.
```

#### Documenting internal functions and structs

Internal functions and structs should commented with a `@dev` tag, and you can also comment the contents of the struct with explanatory comments.

#### Documenting user-facing functions versus internal functions

All user-facing functions should be fully documented with NatSpec. Internal functions should always be commented with a `@dev` tag, not a `@notice` tag.

#### Explanatory comments

Explanatory comments use `//`. There is a common idea that the code describes the documentation. There are pros to this approach. One of the pros is that you remove the coupling between documentation and the code it's describing, that's why we should always strive for the [minimum viable documentation](https://google.github.io/styleguide/docguide/best_practices.html#minimum-viable-documentation) (one of our core documentation [philosophies](#philosophies)). It can also appear cleaner.

It's important that our codebase is well documented with **explanatory comments**. Thus, in addition to the standard NatSpec documentation which we should apply, we should comment the more complex things in our codebase for higher readability. More important than commenting _what_ we should be concerned with commenting _why_. The _what_ does not need to be commented for obvious things, of course the code is able to achieve that. We should comment the _what_ for more complex things to aid in the reader for more quickly understanding the code. In addition to that, we should strive to answer the _why_ with comments in our code.

Keep in mind the advantage of having minimum viable documentation. Keep the comments close to the code which it is describing, so that it does not easily go stale or out of date.

#### Annotation ordering

There are several annotations used in NatSpec, this is the order of precedence we use from top to bottom:

- @title
- @author [we don't use this tag]
- @notice
- @dev
- @param
- @return
- @inheritdoc
- @custom [we don't use this tag unless we define the convention for it here]

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
