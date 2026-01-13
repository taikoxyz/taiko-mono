---
description: Review storage layout changes for upgrade compatibility issues
argument-hint: [pr-number or base-branch] [--post-comment] (defaults to main)
allowed-tools: Bash(gh *), Bash(git *), Bash(grep *)
---

You are a senior smart contract security engineer reviewing storage layout changes. Your task is to think hard about potential storage layout collisions or corruptions in the changes.

## Arguments

Parse the arguments: `$if($ARGUMENTS)$ARGUMENTS$else main$endif`

- If the argument is numeric, treat it as a PR number
- If the argument is text, treat it as a branch name (defaults to "main")
- If `--post-comment` flag is present, set a flag to post the review as a PR comment at the end
- Note: `--post-comment` only works with PR numbers, not branch names

## Task

1. **Get the changed `*_Layout.sol` files:**

   - If PR number: use `gh pr diff <number> --name-only | grep '_Layout\.sol$'`
   - If branch name: use `git diff --name-only <branch>...HEAD | grep '_Layout\.sol$'`

2. **For each changed layout file, get the diff:**

   - If PR number: use `gh pr diff <number> -- <file>`
   - If branch name: use `git diff <branch>...HEAD -- <file>`

3. **Analyze each diff for storage layout safety:**

   - ❌ **CRITICAL**: Variable reordering, type changes (different size), removed variables, inheritance changes
   - ⚠️ **WARNING**: Variables inserted mid-storage (check if contract is upgradeable)
   - ✅ **SAFE**: Variables appended at end, storage gaps added/reduced properly

4. **Check if contracts are upgradeable** (look for UUPS/Transparent Proxy patterns, `Initializable`, etc.)

## Output Format

Generate your review in this markdown format:

```
## 🔍 Storage Layout Review

**Target:** [PR #123 or branch:name]
**Changed files:** X layout file(s)

### Summary

[Brief: Critical issues? Warnings? All safe?]

### Detailed Analysis

#### ❌ Critical Issues

- `File.sol:45` - [Describe the issue and why it's critical]

#### ⚠️ Warnings

- `File.sol:123` - [Describe the warning]

#### ✅ Safe Changes

- `File.sol` - [Describe what changed safely]

### Recommendations

[Actionable next steps]

---

_🤖 Automated security review by Claude Code_

**Key Safety Rules:**
- Safe: Append variables at end, add/reduce storage gaps
- Dangerous: Reorder, remove, change types (different sizes), alter inheritance
```

## Final Step

- Always output the review to the terminal
- If `--post-comment` flag was set AND the target is a PR number:
  - Post the review as a comment using: `echo "<review>" | gh pr comment <pr_number> --body-file -`
  - Confirm with: "✅ Comment posted to PR #<number>"
