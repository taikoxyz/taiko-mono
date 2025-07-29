Analyze and improve the GitHub pull request: $ARGUMENTS

Follow these steps:

1. **Fetch PR Details**
   - Use `gh pr view $ARGUMENTS --json title,body,author,state,number,url` to get comprehensive PR metadata
   - Check PR status and ensure it's open before proceeding

2. **Analyze Code Changes**
   - Review the diff using `gh pr diff $ARGUMENTS`
   - Identify the scope and nature of changes (feature, fix, refactor, etc.)
   - Note any patterns or architectural decisions

3. **Gather Context**
   - Search the codebase for related code and documentation
   - Check for related issues using `gh pr view $ARGUMENTS --json linkedIssues`
   - Review commit history with `gh pr view $ARGUMENTS --json commits`

4. **Improve PR Title**
   - Follow conventional commit format: `type(scope): description`
   - Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
   - Keep it concise (50-72 characters) and descriptive
   - Use imperative mood (e.g., "Add" not "Added")

5. **Enhance PR Description**
   Structure the description with these sections:
   
   ```markdown
   ## Summary
   [1-2 sentence overview of the changes]
   
   ## Motivation
   [Why these changes are needed]
   
   ## Changes
   - [Bullet points of specific changes]
   - [Group by logical components]
   
   ## Testing
   [How the changes were tested]
   
   ## Breaking Changes
   [Any breaking changes or migration notes, if applicable]
   
   ## Related Issues
   [References to related issues/PRs]
   
   ---
   *PR description updated by Claude AI (using command: `/improve-pr-desc $ARGUMENTS`)*
   ```

6. **Preserve Valid Content**
   - Keep accurate information from the original description
   - Remove outdated, incorrect, or redundant content
   - Maintain any important context or decisions mentioned by the author

7. **Update the PR**
   - Use `gh pr edit $ARGUMENTS --title "new title" --body "new description"`
   - Ensure markdown formatting is preserved
   - Verify the update was successful

Use GitHub CLI (`gh`) for all GitHub operations. If the PR number is not provided, try to infer it from the current branch using `gh pr view`.
