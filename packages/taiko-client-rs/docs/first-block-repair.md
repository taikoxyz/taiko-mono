# First-block repair

## The failure

CONS-3.1-9 covers every restart but one. Stock CometBFT v0.40.0 keeps its state at height 0
until it saves the state after a generation's first block, and its handshake accepts a block
store at most one block above that state. When `initial_height` is above 1 (every recovery
generation with c above 0, see [governance recovery](governance-recovery.md), and generation 0
when the Etna start S is above 0, see the [Unzen to Etna handoff](unzen-etna-handoff.md)), a
crash after CometBFT saved the first block and before it saved that block's state leaves the
block store at `initial_height` and the state at 0, and the handshake panics with
`StoreBlockHeight (<initial_height>) > StateBlockHeight + 1 (1)` whatever the app reports. The block was decided: more than 2/3 of the
first committee precommitted it. Never wipe the stores and let the committee propose again, and
never start fresh rounds to replace it (vector 9.t); keep the signers of affected validators
fenced until a recovered node holds that exact block.

`etna-comet-import repair-first-block` installs it. It is the offline store tool CONS-3.1-1
permits: it links the pinned CometBFT module, runs with CometBFT stopped and the signer fenced,
never runs consensus or signs, and the official executable starts only on the repaired home.

## Repair one node

1. Stop the supervisor (signer and Comet) and every restart controller (see
   [Stop the old services](governance-recovery.md#1-stop-the-old-services)). Keep the
   signer's key, HRS states and domains log untouched (RECOV-8.2-1..3). Stop the app and back up
   its directory (`cp -a /var/lib/taiko/app-g1 <safe place>`); snapshot the EL datadir if your
   storage allows it. The repair copies the Comet `data/` directory itself (block store with the
   seen commit, state store, WAL, evidence store) and never deletes any of them.
2. Start the EL and the app (`taiko-client abci`) as usual. The app aligns its EL with its own
   committed boundary, the generation origin or the first block if its Commit completed, before
   it opens the ABCI socket.
3. Run, on the stopped home (goleveldb stores at the default `db_dir`, `data/`):

   ```sh
   etna-comet-import repair-first-block --home /var/lib/etna/comet-g1 \
     --backup /var/lib/etna/comet-g1.first-block-backup --app tcp://127.0.0.1:26658
   ```

   It refuses a home whose stores CometBFT holds open, an existing backup path and one inside
   `data/`. It copies `data/` to `--backup` and syncs the copy. It reads the first block and its
   seen commit from the block store and checks them against the home's fixed genesis: the
   chain_id and height, an empty evidence list, and a commit holding more than 2/3 of the
   genesis committee's power for the block's full BlockID (block hash and part set). If the
   stored seen commit does not certify the block, it stops unless `--peer-export` holds the same
   block with a commit that does (see [Committee-wide crash](#committee-wide-crash)). It then
   asks the app for its committed boundary and, before it writes anything, refuses an app at
   another height and an app at the first height whose kept FinalizeBlock response is missing or
   carries another app hash. Only then does it write: first a fresh store instance ID
   (`data/etna-store-instance`), so the signer fences through the last height its key signed
   until a committed chain covers it (RECOV-8.2-2); then a peer's commit, if it needs one, as
   the seen commit; and then the block is applied as the stock handshake would have had its height
   check used `initial_height`: with the app at 0, InitChain from the genesis and stock
   `ApplyBlock`, so the app runs FinalizeBlock and Commit and executes the block on its EL; with
   the app already at the first height, stock's replay of the kept response. If the state store
   kept a response, a new FinalizeBlock result must equal it. Stock code saves the response and
   the state; the WAL stays as it is. It finally reads back the state, the block store (the
   block and a seen commit that certifies it) and the app's Info at the first height, and prints
   one JSON line naming the height, the BlockID, the app hash, `"source"` (`local`, `peer` or
   `peer_commit`), `"applied"` (`executed`, `replayed` or `already_repaired`), the backup and the
   new store instance ID (empty when the run changed nothing).

4. Start the supervisor. Comet's handshake finds its state, its block store and the app at the
   first height and resumes stock operation from the next one.

Exit 2 is an authenticated contradiction: a peer's certified first block that differs from the
stored one, an app hash that differs from the kept response, a FinalizeBlock result that
differs from the kept one, or an app at another height. Stop and investigate; keep the signers
fenced and every store. Exit 1 is any other failure, such as a commit that does not certify the
block, a missing kept response or an unreachable app. A refusal leaves the stores and their
store instance ID as stock left them (the backup aside); a failure after the first write, such as an app
that stops during InitChain or Commit, leaves the certified block and its certificate in the
block store, and stock's write order tells the rerun whether to execute or replay the block. Fix
the cause and rerun with a new `--backup` path. A rerun after the state was saved only checks
(`already_repaired`) and keeps the store instance ID; given a peer export, it also replaces a
seen commit that does not certify the block, under a fresh ID.

## Committee-wide crash

If several validators crashed in this window, the nodes that saved
the block hold it, possibly with nodes that never saved it (their handshake passes, and
consensus would start rounds at the first height). Fence every affected signer first. On a node
that holds the block, with Comet stopped, export it:

```sh
etna-comet-import export-first-block --home /var/lib/etna/comet-g1 > first-block.json
```

The export is one `blocks.jsonl` line (the original block, its own-height commit, the genesis
keys and powers), and only a block the genesis committee certified is exported. Give the same
file to every affected node. A node whose block store is empty installs exactly that block with
`repair-first-block ... --peer-export first-block.json`. A node that holds a block may pass the
export too: the repair refuses one that differs from its own (exit 2), and when the node's own
seen commit does not certify its block, it installs the export's commit as the seen commit
(`"source": "peer_commit"`). Restart the validators
only after enough of them, with more than 2/3 of the power, hold the block and its state. If no node retained the block and a
certificate for it, keep the signers fenced: the height cannot be decided again, and the
chain proceeds only through another governance recovery (spec section 8).

## A single affected node

A single affected node may instead move its stores aside and catch up with signing disabled
while the rest of the committee keeps committing: install a fresh home and app directory for
the same generation and genesis, as for a new full node, and let it block-sync from that genesis
through the first block and beyond, or import an authenticated 5.4 checkpoint on the decided
chain ([checkpoint import](checkpoint-import.md)). Either is a rebuilt store: the signer
stays fenced through the last height its key signed until the node has committed it
(RECOV-8.2-2).

## Rehearsal

Rehearse both the single-validator and the committee-wide crash with the pinned binaries before
a deployment relies on them (acceptance section 2, item 4).
