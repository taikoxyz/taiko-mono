Analyze and improve the GitHub pull request: $ARGUMENTS

Follow these steps:

1. Use `gh pr view $ARGUMENTS` to get the pull request details
2. Analyze the code changes using `gh pr diff $ARGUMENTS`
3. Search the codebase for context around the modified files
4. Improve the PR title to concisely describe the changes, following conventional commit format
5. Enhance the PR description with:
   - Clear summary of what changed and why
   - Impact of the changes
   - Any breaking changes or migration notes
   - Note: "PR description updated by Claude AI (using comamnd: `/improve-pr-desc $ARGUMENTS`)"
6. Update the PR using `gh pr edit $ARGUMENTS`

Use GitHub CLI (`gh`) for all GitHub operations.
