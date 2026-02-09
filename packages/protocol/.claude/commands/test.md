---
argument-hint: [l1|l2|shared] (optional - defaults to all tests)
description: Run Taiko protocol tests with specified scope (l1, l2, shared, or all)
---

Use the protocol-test-runner agent to run protocol tests with scope: $if($ARGUMENTS)$ARGUMENTS$else all$endif. Provide a clean error-only report without verbose output.
