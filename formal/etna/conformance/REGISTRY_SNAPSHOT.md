# Positional Registry snapshots and recovery selection

This is a selected finite execution and byte-encoding component for the reviewed
current Etna bundle `2e6763e21bc236cfcda6011d164b32040f9e0c8d`. It is not a
current Registry implementation, an authenticated L1 proof, or an authorized
RECOV-8.1 recovery. The historical native Registry has different admission rules.

`registry_snapshot.py` checks explicit width and every positional entry. An
internal empty slot hashes its all-zero fields at its real slot index; padding
outside width is a raw zero hash. A separate width3 vector needs four leaves.
Width is an authenticated input, not occupied cardinality. This component does
not choose a policy for trimming trailing empty slots.

ENC-A-5 applies to the quoted tags in ENC-A-37/39: tags are right-zero-padded
**bytes32**, followed by static ABI words. A registry leaf preimage is224 bytes,
a set-key preimage128 bytes; neither has a dynamic string offset or tail.
Checkpoint word0 is `l1Block | (width << 48)`, followed by entriesRoot. The entry
words are X, effStake, and `prefix | (active << 8) | (exit << 56)`. Confirmation,
owner and pending top-up storage do not enter those bytes. The byte reader
requires supplied registered-entry fields; it does not replace registration's
curve/PoP validation or authenticate caller-provided L1 storage.

Selection filters by `active <= snapshot < exit` and
`eff >= max(s_min, vp_unit)`, rejects duplicate eligible keys, ranks by descending
stake then ascending set key, takes n_max, and outputs ascending set-key order.
Power uses integer floor and must fit the fixed aggregate cap. Symbolic model
key order maps to public points freshly sorted by the actual bytes32 set-key
hash; the model does not pretend small symbolic ranks are hash values.

The main selected model history registers A/B in block1, exits A in2 effective3,
closes3, and uses a mocked proved terminal snapshot3 landing in4. Confirmation4
and unit withdrawal delay allow withdrawal and C's fresh slot0 registration in5.
The hole between those calls is transient within5. It is **not** an authenticated
end-of-block5 hole. C becomes active and receives a pending top-up in6; explicit
activation in7 can precede or follow recovery. Both orders select from final
closed block7. The final-R members in the model represent external snapshot
selection after block close, not an Inbox contract write deferred until close.
B's later activation in8 changes live selection without rewriting origin7.
Land consumes the actual terminal committee snapshot7, not live snapshot8.

A separate route withdraws and closes5 with slot0 empty and slot1 surviving,
registers C in6, tops up in7, and activates in8. Its closed-hole witness and its
full progress witness are distinct from the main R7-maturity witness. Both
routes close block8 explicitly rather than stopping at an unclosed horizon.
Every business transaction, including refused Land, must start before that
block's explicit close. Land7 and refused Land8 occur before Close8. The current
model and observer enforce this; the old model and independent World shared an
omission that allowed Land after Close8. The corrected main safety observation
is613 generated/281 distinct states/queue0; full main/order/restored witnesses
have32 transitions/8 closes/141 literal byte refinements. Old625/289 results and
raw logs remain historical; the retained old post-close trace now refuses.
See [prefix-repair evidence](../REPORT.md#y-prefix-final-review-repairs).

Recovery lists include issued withdrawn A, a valid B prefix followed by an
unissued id, a wrong lifetime key, and descending ids. The complete business
state is unchanged on every refused list; a withdrawn id never targets the new
occupant of its former slot. Recovery does not advance landed coverage.

The model uses two slots, three issued lifetimes plus one unissued id, blocks1..8,
unit delays, symbolic s_min4/vp_unit2/n_max1, and fixed selected call offers. Those
parameters do not establish governance dispersion. Concrete byte/selection
vectors use `Q=10^23`, minStake4Q and vp_unit2Q. A finite safety result applies
only to this graph; a named invariant witness establishes existence. Neither
closes R01/P01 or K01 authentication/client/guest/runtime requirements.

`audit(text, case)` checks complete Init, every offered input, every decision,
all business fields and observer terms, then derives packed storage/root vectors
from each actual closed snapshot. `current_receipt` separately binds the fixed
`registry-origin-selection` claim to current documents, exact source/config,
complete native argv/cwd, raw capture hash and healthy native outcome. Source
selection alone remains `NOT_EVALUATED`. This relies on the trusted execution
collector, not a metadata sidecar as independent proof of execution.

Validation status and actual runs belong in REPORT.md and the task report; this
guide does not infer execution from source presence. No key or signing inputs
are created by these components.
