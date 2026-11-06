"""A standard-library model of stock CometBFT v0.40.0's validator-set arithmetic.

Written from the CometBFT v0.40.0 source, independently of `valgen/` (which runs CometBFT itself):

- genesis (state/state.go:344-345): `current = NewValidatorSet(vals)` and
  `next = NewValidatorSet(vals).CopyIncrementProposerPriority(1)`;
- a committed height (state/execution.go:746-760, 795-796): `next' = next.Copy()`, then
  `UpdateWithChangeSet(updates)` when FinalizeBlock returned any, then
  `IncrementProposerPriority(1)`; the new current set is the old next set, stored proposer included;
- `NewValidatorSet` (types/validator_set.go:77-88) is `updateWithChangeSet(vals)` on an empty set
  followed by `IncrementProposerPriority(1)`;
- `updateWithChangeSet` (lines 652-707): a new member gets priority `-(T + (T >> 3))`, where T
  is the total power with the updates applied and the removals not yet (lines 487-512, 537-558);
  an updated member keeps its priority; then the removals, `RescalePriorities(2 * total)`,
  centering, and the sort by power descending and address ascending (lines 951-958);
- `IncrementProposerPriority(1)` (lines 131-153): `RescalePriorities(2 * total)`, centering, then
  every priority gains its power and the member with the highest priority, ties to the lowest
  address (types/validator.go:66-86), loses the total and becomes the stored proposer;
- `RescalePriorities` (lines 158-178): when `diff = max - min > diffMax`, every priority is divided
  by `ceil(diff / diffMax)` with Go's integer division, which truncates toward zero;
- centering (lines 196-210, 242-250): every priority loses `floor(sum / n)`, the quotient of
  `big.Int.Div`, which is Euclidean (floor for n > 0), not truncation.

Every stored set therefore has a priority sum in [0, n - 1]. The int64 clipping of `safeAddClip`
and `safeSubClip` cannot trigger while the total power is at most `MaxTotalVotingPower`, so the
model asserts instead of clipping.

`generate.py` stops if this model and CometBFT disagree on any state; `test_vectors.py` replays
every chain in `vectors.json` with it.
"""

MAX_TOTAL_VOTING_POWER = (2**63 - 1) // 8
INT64_MIN, INT64_MAX = -(2**63), 2**63 - 1


class Member:
    __slots__ = ("key", "power", "priority")

    def __init__(self, key, power, priority=0):
        self.key, self.power, self.priority = key, power, priority

    def copy(self):
        return Member(self.key, self.power, self.priority)


class ValSet:
    """Members in CometBFT's set order and the key of the stored proposer."""

    __slots__ = ("members", "proposer")

    def __init__(self, members, proposer):
        self.members, self.proposer = members, proposer

    def copy(self):
        return ValSet([m.copy() for m in self.members], self.proposer)

    def entries(self):
        """`[key, votingPower, proposerPriority]` per member, in set order."""
        return [[m.key, m.power, m.priority] for m in self.members]

    def proposer_index(self):
        (index,) = [i for i, m in enumerate(self.members) if m.key == self.proposer]
        return index

    def total(self):
        return sum(m.power for m in self.members)


class Model:
    """Replays CometBFT's validator-set updates. `address` maps a key to its 20-byte address as
    lowercase hex (equal-length hex strings compare like the bytes). `events` collects every
    priority-window bound reached, every floor-rounded centering and every proposer tie."""

    def __init__(self, address):
        self.address = address
        self.events = []
        self.height, self.step = None, None

    def _sort(self, members):
        members.sort(key=lambda m: (-m.power, self.address[m.key]))

    def _rescale(self, members, diff_max):
        priorities = [m.priority for m in members]
        diff = max(priorities) - min(priorities)
        if diff_max <= 0 or diff < diff_max:
            return
        event = {"kind": "rescale", "diff": diff, "diff_max": diff_max, "fires": diff > diff_max}
        if diff > diff_max:
            ratio = (diff + diff_max - 1) // diff_max
            event["ratio"] = ratio
            # Go's `/=` truncates toward zero; these members would differ under floor division.
            event["truncated"] = [m.key for m in members if m.priority < 0 and m.priority % ratio]
            for m in members:
                q = abs(m.priority) // ratio
                m.priority = q if m.priority >= 0 else -q
            priorities = [m.priority for m in members]
            assert max(priorities) - min(priorities) <= diff_max
        self._log(event)

    def _center(self, members):
        total = sum(m.priority for m in members)
        shift = total // len(members)  # big.Int.Div: Euclidean, so floor for a positive divisor
        if total < 0 and total % len(members):
            self._log({"kind": "center", "sum": total, "count": len(members), "shift": shift})
        for m in members:
            m.priority -= shift
            assert INT64_MIN <= m.priority <= INT64_MAX

    def _increment(self, valset):
        """`IncrementProposerPriority(1)` in place."""
        members, total = valset.members, valset.total()
        self._rescale(members, 2 * total)
        self._center(members)
        for m in members:
            m.priority += m.power
            assert m.priority <= INT64_MAX
        top = max(m.priority for m in members)
        tied = sorted((m for m in members if m.priority == top), key=lambda m: self.address[m.key])
        if len(tied) > 1:
            self._log({"kind": "tie", "tied": [m.key for m in tied], "proposer": tied[0].key})
        tied[0].priority -= total
        valset.proposer = tied[0].key

    def _update(self, valset, changes):
        """`UpdateWithChangeSet(changes)` in place; `changes` is `[(key, power)]`."""
        assert len({k for k, _ in changes}) == len(changes), "duplicate change"
        members = {m.key: m for m in valset.members}
        updates = [(k, p) for k, p in changes if p > 0]
        removals = [k for k, p in changes if p == 0]
        assert all(p >= 0 for _, p in changes) and all(k in members for k in removals)
        total = valset.total()
        total += sum(p - (members[k].power if k in members else 0) for k, p in updates)
        for key, power in updates:
            assert power <= MAX_TOTAL_VOTING_POWER
            if key in members:
                members[key].power = power
            else:
                members[key] = Member(key, power, -(total + (total >> 3)))
        for key in removals:
            del members[key]
        assert members, "empty validator set"
        result = list(members.values())
        assert sum(m.power for m in result) <= MAX_TOTAL_VOTING_POWER
        self._rescale(result, 2 * sum(m.power for m in result))
        self._center(result)
        self._sort(result)
        valset.members = result

    def _log(self, event):
        self.events.append({"height": self.height, "step": self.step, **event})

    def genesis(self, height, validators):
        """`(current, next)` that `MakeGenesisState` builds from `[(key, power)]`."""
        self.height = height
        base = ValSet([], None)
        self.step = "genesis"
        self._update(base, list(validators))
        self._increment(base)
        current = base.copy()
        self.step = "genesis_next"
        following = base.copy()
        self._increment(following)
        return current, following

    def commit(self, height, previous_next, changes):
        """`(current, next)` after committing `height` with FinalizeBlock's `changes`."""
        self.height = height
        following = previous_next.copy()
        if changes:
            self.step = "update"
            self._update(following, list(changes))
        self.step = "increment"
        self._increment(following)
        return previous_next.copy(), following


def replay(address, start, end, genesis, updates):
    """Every `(height, current, next)` from `start` to `end`, and the events, of a chain whose
    genesis validators are `genesis` and whose FinalizeBlock returns `updates[h]` at height h."""
    model = Model(address)
    current, following = model.genesis(start, genesis)
    states = [(start, current, following)]
    for height in range(start + 1, end + 1):
        current, following = model.commit(height, following, updates.get(height, ()))
        states.append((height, current, following))
    return states, model.events
