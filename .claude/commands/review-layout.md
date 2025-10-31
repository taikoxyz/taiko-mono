---
description: Review storage layout changes for upgrade compatibility issues
argument-hint: [pr-number or base-branch] (defaults to main)
allowed-tools: Bash(gh *), Bash(git *), Bash(grep *)
---

You are a senior smart contract security engineer reviewing storage layout changes. Your task is to think hard about potential storage layout collisions or corruptions in the changes.

## Task

Review all \*\_Layout.sol file changes and analyze for upgrade compatibility issues. This command works with both PR numbers and branch names.

### Steps

**First, detect if argument is a PR number (numeric) or branch name:**

```bash
# Check if argument is numeric (PR number) or text (branch name)
ARG="$if($ARGUMENTS)$ARGUMENTS$else main$endif"
if [[ "$ARG" =~ ^[0-9]+$ ]]; then
  echo "Mode: PR Review (PR #$ARG)"
else
  echo "Mode: Branch Comparison (comparing against: $ARG)"
fi
```

**Then, based on the mode, get the changed files and diffs:**

**If argument is a PR number (numeric):**

```bash
# Get PR details
gh pr view "$ARG" --json baseRefName,headRefName,number,title

# Get changed layout files
gh pr diff "$ARG" --name-only | grep '_Layout\.sol$'

# For each changed file, get the diff
gh pr diff "$ARG" -- path/to/File_Layout.sol
```

**If argument is a branch name (text):**

```bash
# Get changed layout files
git diff --name-only "${ARG}...HEAD" | grep '_Layout\.sol$'

# For each changed file, get the diff
git diff "${ARG}...HEAD" -- path/to/File_Layout.sol
```

**Analyze each diff for:**

- ❌ **CRITICAL**: Variable reordering, type changes (different size), removed variables, inheritance changes
- ⚠️ **WARNING**: Variables inserted mid-storage (verify if upgradeable)
- ✅ **SAFE**: Variables appended at end, storage gaps added/reduced properly

**Determine if contracts are upgradeable** (UUPS/Transparent Proxy patterns)

### Output Format

Output your review using this markdown structure:

## 🔍 Storage Layout Review

**Target:** `$if($ARGUMENTS)$ARGUMENTS$else main$endif`
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

_🤖 Automated security review_

**Key Safety Rules:**

- Safe: Append variables at end, add/reduce storage gaps
- Dangerous: Reorder, remove, change types (different sizes), alter inheritance
