# Etna Settlement TLA+ Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Deliver a runnable, bounded model of Etna landing/recovery interleavings.

**Architecture:** One TLA+ module, reusable TLC configurations and a small runner
under `formal/etna/`. Source mapping and explicit assumptions keep model results
distinct from contract or consensus verification.

**Tech Stack:** TLA+, TLC 1.7.4, Java 17+, POSIX shell or Python standard library.

**Spec:** `docs/superpowers/specs/2026-11-13-etna-settlement-tla-design.md`

## Global Constraints

- Source revision: `d18357214fab30ea512ae9858a11699806d72ba1`.
- All project files live in the existing repository; model home is `formal/etna/`.
- No production changes, dependency rebuilds, global installations or deployment.
- Paths in tracked artifacts are portable and repository-relative.
- Runs are bounded in wall time and memory; downloaded tools stay out of Git.

## Review Focus

- Recovery after a competing landing must not execute a stale expectedC.
- Explicit nonce invalidation must disable a still otherwise current authorization.
- Deadline equality is accepted; a later timestamp is rejected.
- Old-generation proof bytes must fail even at a reused recovery origin.
- Overlapping proofs must use actual c as landing parent and remain executable.

### Task 1: Model, executable configurations and evidence

**Files:**

- Create: `formal/etna/EtnaSettlement.tla`, `formal/etna/configs/*.cfg`.
- Create: `formal/etna/check.py`, `formal/etna/README.md`, `formal/etna/REPORT.md`.

**Interfaces:**

- Consumes: pinned Etna rules in the design.
- Produces: `check.py --java JAVA --tlc-jar JAR --output-dir DIR` runs baseline,
  negative controls and reachability checks; nonzero on unexpected outcomes.

- [x] Write bounded configurations and invariant expectations before the model.
- [x] Run the initial guard-disabled model and observe the expected invariant failure.
- [x] Enable normative guards and complete the model/source mapping.
- [x] Run all normal, negative-control and reachability configurations with TLC.
- [x] Independently review the complete diff and rerun the checks.
- [x] Fix material findings, rerun relevant checks, and record bounds/state counts.
- [x] Leave the dedicated local branch reviewable; do not publish without request.

Expected: baseline completes without violations; each negative control and witness
returns the exact expected invariant violation, not a parser/runtime error.
