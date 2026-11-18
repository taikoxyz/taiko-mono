# Exact workspace SPEC correspondence

The historical authority remains commit
`d18357214fab30ea512ae9858a11699806d72ba1`, blob
`649548c58d6629dd85143b33efd3644a3bb71509`, SHA-256
`4d81d5dadcee3eb94ff554ec5a8144a47888dd5a8263ac5852422a0f1d1dd71b`.
The current reviewed workspace is main commit
`9c832234b4681fbc5eccdbaf9c9303b7869f91f4`, SPEC blob
`033f7ffd28ab9c3de7188948fb67eabfe9d180e6`, SHA-256
`7875c10373114ca5eaa7b164d2bfa844b4f5bbbede2ebfa252bb59246efd96de`.
This supersedes the previously reviewed workspace `991e06f6`; it leaves
historical native sources, vectors, source manifests and their authority intact.
The guard still accepts only canonical bytes or this single reviewed exact
revision. Other revisions and even a one-byte modification are refused.

The change in [#22410](https://github.com/taikoxyz/taiko-mono/pull/22410)
is normative. It moves the L2 fork boundary and EIP-4788 lookup into the
SignalService, and moves L1 legacy checkpoint forwarding into the Etna Inbox.
The current review permits only the bounded historical subsets below.

| Amended clauses                       | Selected consumers and scope                                                                                                                                                                                                                                                                                                                                                 | Unverified obligation                                                                                                                                                                                                                                                                                                                       |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| START-10-5                            | The unchanged initialization tail still checks the Registry, initializes the committee snapshot and generation/nonce, and restricts recovery to the owner. Registry admission/lifecycle cases execute contracts `89f419915de4b73bb57c53bf970f6dea9e8e8c8c` with explicit mock Inbox inputs. Existing settlement/publication replays observe ordinary L1 checkpoint save/get. | Single-syncer deployment, Unzen forwarding through Etna Inbox, forwarding failure behavior and cutoff before/after the start write, L2 beaconRootsFrom configuration, EIP-4788 lookup and checkpoint-store closure. Historical L1/L2 contract variants do not execute this refactor.                                                        |
| START-10-5a, START-10-5c, START-10-5d | The unchanged start-record/generation semantics used by bounded start/recovery models remain historical subsets. None of the selected native consumers performs an actual Unzen migration or originWriter implementation check.                                                                                                                                              | SignalService implementation validation at S, rewritten-start retry through the Inbox forwarder, and the changed Unzen prove sink and deployment order.                                                                                                                                                                                     |
| PROOF-6.2-46a, PARAM-11-12a           | Selected proving models treat validated execution/proofs as premises; no selected consumer proves the L2 implementation slot. Public Comet vote, canonical-byte, FilePV and synchronous signer-handler tests consume unchanged CONS-3.1 and double-sign rules.                                                                                                               | Guest authentication of the built-in L2 SignalService implementation at S and correct per-chain deployment manifest.                                                                                                                                                                                                                        |
| SYNC-9-5a, SYNC-9-16                  | Existing signer/trust models assume authenticated matching trust evidence and test the gate after that premise. Import/Bootstrap tests exercise selected historical stock storage and arithmetic, not the live switching-network trust procedure.                                                                                                                            | The new implementation check at S and the additional beaconRootsFrom() comparison against the node's own fork configuration, including local overrides, at EVERY trust target. A first landing does not settle the latter check; later snapshot joins must perform it too. Required authenticated L2 state availability remains unverified. |

N01/O01/O02 execute pinned CometBFT
`0880b4d378f347ab16e54ec677ff50d803f37d62`; their public vote and cached
replay oracles are unchanged by these amendments. N02/N03/N04 and O03 use
the historical Registry source above; a mock generation or active snapshot
cannot prove the new migration, client trust or committee-recovery procedure.
Other old bounded models and native receipts retain their original inputs and
limits. Passing this correspondence guard is not evidence that the current
SignalService design is implemented, deployed or fully verified.

Feedback [4611583127](https://github.com/taikoxyz/taiko-mono/pull/22387#discussion_r4611583127)
exposed a merge-result validation gap: branch-only tests used canonical SPEC
bytes, while hosted CI used the newer main SPEC. Validation must exercise the
reviewed merge-result bytes as well as the branch snapshot. Advancing main can
invalidate this exact correspondence again and requires another source review.
