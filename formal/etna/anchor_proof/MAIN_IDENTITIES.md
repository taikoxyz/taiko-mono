# Reading identities across the two Main recovery histories

## Interpretation erratum for the frozen model and fixtures

In EtnaAnchorProofRecovery.tla at lines 54–56 the distinct-symbol convention
for signed inputs applies within an immutable Main script. The same display
names appear in ShortFirst and DirectLong. Their concrete interpretation
depends on the data each symbol stands for in that script. This qualification
also applies to the H15–H17 and new-job tables in the frozen independent
oracle, its supplement and source report, and to comparisons with those tables
in the typed readers.

Both histories can share the old blocks through H14 and the P, short and long
jobs captured before L1 820. In particular, settling the old H14 through a
different suffix changes the parent height of its L1 checkpoint record while
preserving the EL and Comet identities of that old block. Even the unlanded
old-generation H15 prepared later can share its interpretation: its H14
parent and inherited anchor at L1 600 are common. An event's position after
the fork alone does not change its data.

At L1 820 the scripts consume different jobs. The two R141000 and Z141100
identities retain those different histories. At Z, the occupied slot-285
checkpoint heights and H14 parent words differ. This is a difference in
modeled protocol storage, independently of the saved ghost EL root and ledger.
Under the design's header-binding premises, the generation-1 first block
carries its own Z witness. The EL header uses the anchor state root and the EL
writes that root under EIP-4788. The committed envelope authenticates the
witness. Thus interpreting the two instances of the first block as identical
signed/header bytes would contradict the intended inputs (CONS-3.2-6,
CONS-3.3-2, PROOF-6.2-20). H16 and H17 inherit Z and descend from their own
first block. Read their EL, Comet and state-root symbols in the same scope.

The reference at L1 141200 also has a different parent history. The new job's
full block, terminal cut, saved terminal root, certificate and statement-bound
pair of attestations use that run's identities. `new` is a selector and
`n15` a driver/data tag. A shared spelling identifies the corresponding case.
It supplies no equality test on envelope bytes between cases. `BN` stands for
the supplied blob commitment in that case. If the two blob payload preimages
are identical, a common commitment interpretation is possible. If their
committed payloads differ, the corresponding opaque commitment is scoped
with its input. The comparison observes a symbolic ordered list and digest
constructor. It does not determine actual blob bytes or versioned hashes.
Similarly, backend roles may be shared while their attestations bind different
statements. The digest of an empty interior-cut list with unchanged domain,
p and h may be shared. Dependence follows the preimage of each field.

## Finite lifting argument

Fix the configuration, script k and its finite reachable component. Choose
an injective interpretation ρₖ of its opaque identity atoms into fresh names,
fixing genuinely shared identities. For example, E15new can denote a distinct
symbol indexed by k, disjoint from all fixed names. Apply the same choice at
every occurrence of that atom within k. Keep selectors, event and operation
tags, field names, role and committee names, sentinels, Booleans, numbers
(including generations, heights, timestamps, power and FI) fixed. Keep the
data tags as selectors, and interpret any opaque payload they designate in k.
No transition decodes bytes from a tag. This choice preserves every
within-script equality *and inequality* among identity atoms.

Extend ρₖ pointwise through records, sequences, finite functions and sets.
This includes snapshots and parent pointers, block and candidate fields,
receipt.before, job blocks/data, cuts, certificate fields, blob lists and
digest constructors, the 19-word statement and both attestations. Interpret
the literal constants and tables supplying or testing those identities,
including reader expectations, through the same map. Renaming state with a
fixed, unrenamed expected endpoint would change the question.

Init retains k in s. Take and Dispatch operate on s and one offered input.
Script selects offers by k and cursor, and every captured or selected job
belongs to s.jobs of that execution. No transition exchanges jobs between k's.
Identity comparisons in guards, safety predicates and observations use that
state, its predecessor/receipt, the chosen input and the matching constants.
Injection preserves equality, set membership and cardinality. Position,
sequence order and length, record fields, numeric ordering and arithmetic
survive unchanged. The At, Rec, Job, Origin and assignment selections in the
covered histories retain their keyed row. Constructors commute with the map.
Hence each step and stutter lifts, and the inverse on the image takes each
lifted step back. Induction gives the same guard decisions and predicate
truth values at each position. StateView retains k through s along with
cursor and predicate bits. The private ShortFirst witness also retains its
observation bit. Each first failure or witness in this finite family is
therefore preserved at its position under consistent per-script renaming.

This argument establishes per-run symbolic correspondence for the recorded
finite inputs. Concrete trie roots, EL execution, signed envelopes, blob
commitments and proof construction were outside the runs. A job from the
other history is outside the input alphabet. Cross-history byte identity,
binding and replay isolation therefore remain open.

## Trace data

The [typed projection](readback/output/dual-main-identity.json) retains the
full historical ID sequences and new statements directly from the terminal
states of both pinned logs. In each history, firstNewBlock.anchorID equals
Z141100.id, newJob.refID equals reference141200, and statement word 15
(one-based) equals that same reference. The printed EL/Comet/root triple
is E15new/K15new/S15new in both. ShortFirst retains H13 and stores parent 13
at H14. DirectLong lacks H13 and stores parent 12 at H14. R, Z, the H15
anchorID, the new reference and the complete new statement differ already in
the unrenamed logs.

The [manifest](evidence.json) binds the projection, helper and typed parser
bytes to the original producer rows and raw log SHA-256 values. Its file
digests identify evidence bytes only. No header, state or proof hash was
computed by this readback.
