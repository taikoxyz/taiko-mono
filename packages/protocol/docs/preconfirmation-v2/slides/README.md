# Slot Chain learning deck

[Open the 30-slide learning deck](slot-chain-learning-deck.html) for an introduction to the
Slot Chain design and partial Solidity implementation in
[PR #22139](https://github.com/taikoxyz/taiko-mono/pull/22139). Start with the implementation map
to distinguish available code from the protocol flows still specified and modeled.

## Read and print

Open `slot-chain-learning-deck.html` from a repository checkout in a browser. The HTML is
self-contained and needs no build step or server. You can also download it alone; its relative
links to the PDF, models and documentation require the surrounding `preconfirmation-v2` directory.
GitHub's file view shows the source; open the downloaded file to read the deck.

Use the browser's **Print → Save as PDF** command to export the deck. Enable background graphics
and disable browser headers and footers for the intended appearance. The HTML remains the
maintained artifact; no separate deck PDF is committed.

## Scope and provenance

This is a **non-normative learning companion** to the
[v2.28 specification at commit `b7896b7`](https://github.com/taikoxyz/taiko-mono/blob/b7896b758ef5500ce9b67064ba645c4416d8cfb5/packages/protocol/docs/preconfirmation-v2/tex/main.tex),
checked against the draft implementation at that same commit on 2026-09-17.
The v2.28 label identifies a document revision, not an on-chain protocol version. Exact validity
rules, wire formats and implementation requirements belong to the specification. Its source is
byte-identical to the deck's former `c77efc25` pin; the update brings provenance and implementation
coverage forward to the consolidated PR, which supersedes #22138 and #22064.

The [implementation status and source map](../implementation-status.md) records available code,
missing components and the meaning of the conformance evidence. The Registry/facets, proof helpers,
root deployment machinery and shared libraries have source and tests. The full Settlement,
Queue, Market, Router/control plane, V2 bridge and L2 execution paths remain incomplete. The
settlement, recovery, bridge and migration slides describe specified behavior, not a deployed system.
The genesis and migration-timing slides explain the bounded pause and abort conditions separately
from root bootstrap. Complete release artifacts, measured gas, real circuits, calibrated economics
and independent review remain gates.

The presentation style comes from the
[v15 learning deck at commit `fad5f961`](https://github.com/taikoxyz/taiko-mono/blob/fad5f96154c593b45c44097fcc1eddf442537eee/packages/protocol/docs/preconfirmation/slides/preconf-redesign-slides.html)
on `claude/taiko-preconfirmation-redesign-i0c4ls`. Its content has been rewritten for the current
Slot Chain design: the older architecture is obsolete and is not a second source of protocol
requirements.

## Keeping the deck synchronized

1. Read `tex/main.tex`, the affected executable models and the implementation at one immutable
   commit. A matching v2.28 label alone is insufficient. Resolve any disagreement before claiming
   conformance; the deck must not silently choose a new protocol rule.
2. Check source presence against `utils/slotchain/conformance-ledger.v2.28.json` and
   `utils/slotchain/artifact-ownership.json` under `packages/protocol`. Update
   `../implementation-status.md`, the implementation/readiness slides and the parent README together.
   Keep the ledger's own normative pin distinct from the deck's snapshot; repinning a slide does
   not revalidate or promote a ledger row.
3. Update all footer links, the title/source slides and this provenance section to the reviewed
   commit. Verify each line anchor still names the intended rule. Preserve historical style links
   as historical references.
4. Keep teaching examples separate from measured implementation results. Run the model suites
   behind changed examples and the relevant contract checks if implementation claims change.
5. Open the HTML at desktop and narrow widths, follow chapter/Next links, and print at the declared
   1280 × 720 page size. Check for clipping, broken local links and one printed page per slide.
   Update every slide counter if slides are added or removed.
