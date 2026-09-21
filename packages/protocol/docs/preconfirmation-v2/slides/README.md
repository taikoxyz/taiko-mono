# Slot Chain learning deck

[Open the 28-slide learning deck](slot-chain-learning-deck.html) for an introduction to the
Slot Chain v3.0 design and partial Solidity implementation in
[PR #22139](https://github.com/taikoxyz/taiko-mono/pull/22139). Start with the implementation map
to distinguish available code from the protocol flows still specified and modeled, then read the
header-anchor, bridging, governance and upgrade slides, which are where v3.0 differs from v2.28.

## Read and print

Open `slot-chain-learning-deck.html` from a repository checkout in a browser. The HTML is
self-contained and needs no build step or server. You can also download it alone; its relative
links to the specification source, models and documentation require the surrounding
`preconfirmation-v2` directory. GitHub's file view shows the source; open the downloaded file to
read the deck.

Use the browser's **Print → Save as PDF** command to export the deck. Enable background graphics
and disable browser headers and footers for the intended appearance. The HTML remains the
maintained artifact; no separate deck PDF is committed.

## Scope and provenance

This is a **non-normative learning companion** to the v3.0 specification in
[`tex/main.tex`](../tex/main.tex) as revised in PR #22139. The v3.0 label identifies a document
revision, not an on-chain protocol version. Exact validity rules, wire formats and implementation
requirements belong to the specification. The committed `slot-chain-spec.pdf` is still the v2.28
build and is stale until it is rebuilt from the source; the deck links to it with that caveat.

The v3.0 revision builds on the anchor-free L2 of
[issue #22147](https://github.com/taikoxyz/taiko-mono/issues/22147), reuses the existing
SignalService, Bridge and vaults, and upgrades the existing L1 Inbox proxy in place under the
existing DAO governance. The v2.28 anchor system transaction, fresh V2 bridge/custody design,
immutable timelock/version-manager/router stack, CREATE3 root factory and legacy genesis campaign
are removed from the design; the deck no longer teaches them.

The [implementation status and source map](../implementation-status.md) records available code,
missing components and the meaning of the conformance evidence. The Registry/facets, schedule
proof helpers, historical header proofs and shared libraries have source and tests. Settlement,
ForcedQueue, ScheduleOracle, AggregatorSeatMarket, the L2 client fork rules and the circuits remain
specified only. Complete release artifacts, measured gas, real circuits, calibrated economics and
independent review remain gates.

The presentation style comes from the
[v15 learning deck at commit `fad5f961`](https://github.com/taikoxyz/taiko-mono/blob/fad5f96154c593b45c44097fcc1eddf442537eee/packages/protocol/docs/preconfirmation/slides/preconf-redesign-slides.html)
on `claude/taiko-preconfirmation-redesign-i0c4ls`. Its content has been rewritten for the current
Slot Chain design: the older architectures (v15 and v2.28) are obsolete and are not a second
source of protocol requirements.

## Keeping the deck synchronized

1. Read `tex/main.tex`, the affected executable models and the implementation at one immutable
   commit. A matching v3.0 label alone is insufficient. Resolve any disagreement before claiming
   conformance; the deck must not silently choose a new protocol rule.
2. Check source presence against `utils/slotchain/conformance-ledger.v3.0.json` and
   `utils/slotchain/artifact-ownership.json` under `packages/protocol`. Update
   `../implementation-status.md`, the implementation/readiness slides and the parent README together.
   Keep the ledger's own normative pin distinct from the deck's snapshot; repinning a slide does
   not revalidate or promote a ledger row.
3. Update all footer links, the title/source slides and this provenance section to the reviewed
   commit once one exists. Verify each section reference still names the intended rule. Preserve
   historical style links as historical references.
4. Keep teaching examples separate from measured implementation results. Run the model suites
   behind changed examples and the relevant contract checks if implementation claims change.
5. Open the HTML at desktop and narrow widths, follow chapter/Next links, and print at the declared
   1280 × 720 page size. Check for clipping, broken local links and one printed page per slide.
   Update every slide counter if slides are added or removed.
