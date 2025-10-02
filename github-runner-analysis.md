# GitHub Runner Performance Analysis

## Issues Found

### 1. **Syntax Error in eventindexer.yml (Lines 22 & 41)**

**Location**: `.github/workflows/eventindexer.yml`

**Problem**: Incorrect parenthesis closure in conditional expressions
```yaml
# Lines 22 & 41 - INCORRECT
if: ${{ github.event.pull_request.draft == false  && !startsWith(github.head_ref, 'release-please' && !startsWith(github.head_ref, 'dependabot')) }}
```

**Issue**: Missing closing parenthesis after `'release-please'` - the condition is malformed causing potential workflow failures.

**Fix**:
```yaml
if: ${{ github.event.pull_request.draft == false && !startsWith(github.head_ref, 'release-please') && !startsWith(github.head_ref, 'dependabot') }}
```

---

### 2. **Inefficient Caching Strategy**

**Problem**: Most workflows use `arc-runner-set` and `taiko-runner` custom runners but don't leverage caching effectively.

**Current State**:
- Only 3 workflows use `cache: true` for Go dependencies (taiko-client workflows)
- Custom runners (`arc-runner-set`, `taiko-runner`) used in 30+ workflows without explicit caching
- `pnpm` cache is only enabled in the shared action via `setup-node` with `cache: pnpm`

**Impact**:
- Repeated dependency downloads across workflow runs
- Slower build times for Protocol, Relayer, Eventindexer, Bridge UI

**Recommendations**:
```yaml
# For Go workflows - add caching
- uses: actions/setup-go@v5
  with:
    go-version: 1.23.0
    cache: true  # ← Add this

# For pnpm workflows - already good via action
# But could add cache key customization for monorepo optimization
```

---

### 3. **Unnecessary `continue-on-error` in Critical Step**

**Location**: `.github/workflows/protocol.yml:41-42`

```yaml
- name: Prepare environment
  continue-on-error: true  # ← DANGEROUS
  run: sudo apt-get update && sudo apt-get install -y git wget
```

**Problem**: If git installation fails, subsequent checkout will fail silently, wasting runner time.

**Fix**: Remove `continue-on-error: true` or handle error properly:
```yaml
- name: Prepare environment
  run: sudo apt-get update && sudo apt-get install -y git wget
```

---

### 4. **Redundant Git Installation Steps**

**Problem**: Multiple workflows install git unnecessarily:
- `protocol.yml:42` - installs git
- `relayer.yml:50` - installs git
- `eventindexer.yml:50` - installs git
- `bridge-ui--ci.yml:15` - installs git

**Impact**: Wasted 5-10 seconds per workflow run

**Explanation**:
- `ubuntu-latest` and most custom runners have git pre-installed
- `actions/checkout@v4` doesn't require separate git installation

**Fix**: Remove these steps unless proven necessary for custom runners:
```yaml
# Remove this step
- name: Install Git
  run: sudo apt-get update && sudo apt-get install -y git
```

---

### 5. **Sequential Job Dependencies Causing Bottlenecks**

**Location**: `.github/workflows/relayer.yml:42`

```yaml
test-relayer:
  runs-on: [arc-runner-set]
  needs: lint-relayer  # ← Forces sequential execution
```

**Problem**: Test job waits for lint to complete, adding ~2-4 minutes to total workflow time.

**Impact**:
- `relayer.yml`: lint → test (sequential)
- `eventindexer.yml`: lint → test (sequential)
- These could run in parallel

**Fix**: Remove `needs` dependency and let them run concurrently:
```yaml
test-relayer:
  runs-on: [arc-runner-set]
  # Remove: needs: lint-relayer
```

---

### 6. **Protocol Workflow Inefficiency**

**Location**: `.github/workflows/protocol.yml:82-92`

**Problem**: Redundant compilation steps:
```yaml
# Line 84 - compiles shared twice
- name: Shared-Unit tests
  run: pnpm compile:shared && pnpm test:shared && pnpm layout:shared

# Line 88 - recompiles shared + l2
- name: L2-Unit tests
  run: pnpm compile:shared && pnpm compile:l2 && pnpm test:l2 && pnpm layout:l2

# Line 92 - recompiles shared + l1
- name: L1-Unit tests
  run: pnpm compile:shared && pnpm compile:l1 && pnpm snapshot:l1 && pnpm layout:l1
```

**Impact**: `pnpm compile:shared` runs 3 times unnecessarily.

**Fix**: Separate compilation step:
```yaml
- name: Compile contracts
  working-directory: ./packages/protocol
  run: pnpm compile

- name: Shared-Unit tests
  working-directory: ./packages/protocol
  run: pnpm test:shared && pnpm layout:shared

- name: L2-Unit tests
  working-directory: ./packages/protocol
  run: pnpm test:l2 && pnpm layout:l2

- name: L1-Unit tests
  working-directory: ./packages/protocol
  run: pnpm snapshot:l1 && pnpm layout:l1
```

---

### 7. **Missing Foundry Caching**

**Problem**: Foundry toolchain installed in every run without caching:
```yaml
- name: Install Foundry
  uses: foundry-rs/foundry-toolchain@v1.4.0
  with:
    version: stable
```

**Impact**: Downloads and installs Foundry (~30-60 seconds) on every run.

**Recommendation**: Use foundry-rs/foundry-toolchain caching features:
```yaml
- name: Install Foundry
  uses: foundry-rs/foundry-toolchain@v1
  with:
    version: stable
    cache: true  # Enable caching if available
```

---

## Priority Fixes

### Critical (Fix Immediately)
1. **eventindexer.yml syntax errors** (lines 22, 41) - preventing proper workflow execution
2. **Remove `continue-on-error`** from protocol.yml:41 - causing silent failures

### High Impact (Significant Speed Improvement)
3. **Remove sequential dependencies** in relayer.yml & eventindexer.yml - save 2-4 min per run
4. **Optimize protocol compilation** - save 1-2 min per run
5. **Add Go caching** to all Go workflows - save 30-60 sec per run

### Medium Impact (Cleanup & Optimization)
6. **Remove redundant git installations** - save 5-10 sec per run
7. **Add Foundry caching** - save 30-60 sec per run

---

## Estimated Time Savings

| Workflow | Current | After Fixes | Savings |
|----------|---------|-------------|---------|
| Protocol | ~8-10 min | ~6-7 min | 20-25% |
| Relayer | ~5-6 min | ~3-4 min | 33-40% |
| Eventindexer | ~5-6 min | ~3-4 min | 33-40% |
| Taiko Client | ~25-30 min | ~23-27 min | 10-15% |

**Total potential improvement**: 20-35% faster CI times across all workflows.
