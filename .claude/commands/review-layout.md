---
description: Review storage layout changes for upgrade compatibility issues
argument-hint: [base-branch] (defaults to main)
allowed-tools: Read, Grep, Glob, Bash(git *), Bash(gh *)
---

You are a senior smart contract security engineer reviewing storage layout changes. Your task is to think hard about potential storage layout collisions or corruptions in the changes of this branch.

**Base branch:** $if($ARGUMENTS)$ARGUMENTS$else main$endif

## Task

Review all \*\_Layout.sol file changes in packages/protocol/contracts/ comparing against the base branch and analyze for upgrade compatibility issues.

### Steps

1. Find changed layout files:

```bash
git diff --name-only $if($ARGUMENTS)$ARGUMENTS$else main$endif...HEAD | grep '_Layout\.sol$'
```

2. For each changed file, analyze the git diff for:

   - ❌ **CRITICAL**: Variable reordering, type changes(of different size), removed variables, inheritance changes
   - ⚠️ **WARNING**: Variables inserted mid-storage (verify if upgradeable)
   - ✅ **SAFE**: Variables appended at end, storage gaps added/reduced properly

3. Determine if contracts are upgradeable (UUPS/Transparent Proxy patterns)

### Output Format

Output your review using this markdown structure:

```markdown
## 🔍 Storage Layout Review

**Base branch:** `$if($ARGUMENTS)$ARGUMENTS$else main$endif`

**Changed files:** X layout file(s)

### Summary

[Brief: Critical issues? Warnings? All safe?]

### Detailed Analysis

#### ❌ Critical Issues

- `File.sol:45` - Variable removed (orphaned storage), variables reordered, inheritance order changed or anything that breaks the storage layout

#### ⚠️ Warnings

- `File.sol:123` - Variable types have been changed, but the size remains the same. Everything looks ok, but better to double check

#### ✅ Safe Changes

- `File.sol` - Appended new variable at end

### Recommendations

[Actionable next steps]

---

_🤖 Automated review - When running in GitHub Actions, this will be posted as a PR comment automatically_
```

**Key Safety Rules:**

- Safe: Append variables at end, add/reduce storage gaps
- Dangerous: Reorder, remove, change types(with different sizes), alter inheritance
