# Slot Chain learning deck

[Open the learning deck](slot-chain-learning-deck.html) for an introduction to the Slot Chain
design in [PR #22064](https://github.com/taikoxyz/taiko-mono/pull/22064), including the review
repairs merged through [PR #22134](https://github.com/taikoxyz/taiko-mono/pull/22134).

## Read and print

Open `slot-chain-learning-deck.html` from a repository checkout in a browser. The HTML is
self-contained and needs no build step or server. You can also download it alone; its relative
links to the PDF, models and READMEs require the surrounding `preconfirmation-v2` directory.
GitHub's file view shows the source; open the downloaded file to read the deck.

Use the browser's **Print → Save as PDF** command to export the deck. Enable background graphics
and disable browser headers and footers for the intended appearance. The HTML remains the
maintained artifact; no separate deck PDF is committed.

## Scope and provenance

This is a **non-normative learning companion** to the
[v2.28 specification at commit `c77efc25`](https://github.com/taikoxyz/taiko-mono/blob/c77efc25eba66fcc18b547ec851d170218bc2956/packages/protocol/docs/preconfirmation-v2/tex/main.tex).
The v2.28 label identifies a document revision, not an on-chain protocol version. Exact validity
rules, wire formats and implementation requirements belong to the specification. The design is a
reviewed candidate for implementation; compiled artifacts, measured gas, circuit conformance and
economic acceptance remain release gates.

The presentation style comes from the
[v15 learning deck at commit `fad5f961`](https://github.com/taikoxyz/taiko-mono/blob/fad5f96154c593b45c44097fcc1eddf442537eee/packages/protocol/docs/preconfirmation/slides/preconf-redesign-slides.html)
on `claude/taiko-preconfirmation-redesign-i0c4ls`. Its content has been rewritten for the current
Slot Chain design: the older architecture is obsolete and is not a second source of protocol
requirements.

When the specification changes, update the affected slides and their pinned source revision
together. Keep teaching examples distinct from measured implementation results.
