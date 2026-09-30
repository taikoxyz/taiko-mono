# Runtime source notes for the L1 roadmap survey

Retrieved 2026-09-30 UTC through the `parallel_search_web_search` and live-enabled `parallel_search_web_fetch` tools. Sources are public. No private resource, secret, deployment key or Etherscan credential was accessed.

This is a compact extraction ledger, not vendored EIP content. The “date metadata” column is what the fetch service reported; it is **not** asserted to be an independently authenticated Git commit or publication timestamp. The observation date above is the relevant as-of date. For draft specifications, pin final launch revisions separately.

## Individual EIP observations

| EIP and fetched source | Status banner observed | Fetch date metadata |
|---|---|---|
| [EIP-2780: Resource-based intrinsic transaction gas](https://eips.ethereum.org/EIPS/eip-2780) | Review Standards Track: Core | 2026-09-23 |
| [EIP-3298: Remove storage-clear refund and refund cap](https://eips.ethereum.org/EIPS/eip-3298) | Draft Standards Track: Core | 2026-09-29 |
| [EIP-4788: Beacon block root in the EVM](https://eips.ethereum.org/EIPS/eip-4788) | Final Standards Track: Core | 2026-09-25 |
| [EIP-4844: Shard Blob Transactions](https://eips.ethereum.org/EIPS/eip-4844) | Final Standards Track: Core | 2026-09-28 |
| [EIP-7594: PeerDAS - Peer Data Availability Sampling](https://eips.ethereum.org/EIPS/eip-7594) | Final Standards Track: Core | 2026-09-24 |
| [EIP-7688: Forward compatible consensus data structures](https://eips.ethereum.org/EIPS/eip-7688) | Review Standards Track: Core | 2024-04-15 |
| [EIP-7702: Set Code for EOAs](https://eips.ethereum.org/EIPS/eip-7702) | Final Standards Track: Core | 2026-09-29 |
| [EIP-7708: ETH transfers emit a log](https://eips.ethereum.org/EIPS/eip-7708) | Review Standards Track: Core | 2026-09-22 |
| [EIP-7732: Enshrined Proposer-Builder Separation](https://eips.ethereum.org/EIPS/eip-7732) | Review Standards Track: Core | 2026-09-29 |
| [EIP-7778: Block Gas Accounting without Refunds](https://eips.ethereum.org/EIPS/eip-7778) | Review Standards Track: Core | 2024-10-01 |
| [EIP-7782: Reduce Block Latency](https://eips.ethereum.org/EIPS/eip-7782) | Draft Standards Track: Core | 2024-10-05 |
| [EIP-7805: Fork-choice enforced Inclusion Lists (FOCIL)](https://eips.ethereum.org/EIPS/eip-7805) | Draft Standards Track: Core | 2026-09-27 |
| [EIP-7825: Transaction Gas Limit Cap](https://eips.ethereum.org/EIPS/eip-7825) | Final Standards Track: Core | 2024-11-23 |
| [EIP-7843: SLOTNUM opcode](https://eips.ethereum.org/EIPS/eip-7843) | Review Standards Track: Core | 2026-09-23 |
| [EIP-7892: Blob Parameter Only Hardforks](https://eips.ethereum.org/EIPS/eip-7892) | Final Informational | 2026-09-30 |
| [EIP-7904: Compute Gas Cost Analysis](https://eips.ethereum.org/EIPS/eip-7904) | Review Informational | 2025-02-05 |
| [EIP-7906: Transaction Assertions via State Diff Opcode](https://eips.ethereum.org/EIPS/eip-7906) | Draft Standards Track: Core | 2026-09-28 |
| [EIP-7928: Block-Level Access Lists](https://eips.ethereum.org/EIPS/eip-7928) | Review Standards Track: Core | 2026-09-29 |
| [EIP-7954: Increase Maximum Contract Size](https://eips.ethereum.org/EIPS/eip-7954) | Review Standards Track: Core | 2026-09-24 |
| [EIP-7976: Increase Calldata Floor Cost](https://eips.ethereum.org/EIPS/eip-7976) | Review Standards Track: Core | 2025-06-18 |
| [EIP-7981: Increase Access List Cost](https://eips.ethereum.org/EIPS/eip-7981) | Review Standards Track: Core | 2024-12-27 |
| [EIP-7997: Deterministic Factory Contract](https://eips.ethereum.org/EIPS/eip-7997) | Review Standards Track: Core | 2025-08-03 |
| [EIP-8024: Backward compatible SWAPN, DUPN, EXCHANGE](https://eips.ethereum.org/EIPS/eip-8024) | Review Standards Track: Core | 2025-08-16 |
| [EIP-8037: State Creation Gas Cost Increase](https://eips.ethereum.org/EIPS/eip-8037) | Review Standards Track: Core | 2026-09-28 |
| [EIP-8038: State-access gas cost update](https://eips.ethereum.org/EIPS/eip-8038) | Review Standards Track: Core | 2025-10-03 |
| [EIP-8045: Exclude slashed validators from proposing](https://eips.ethereum.org/EIPS/eip-8045) | Review Standards Track: Core | 2026-09-24 |
| [EIP-8061: Increase exit and consolidation churn](https://eips.ethereum.org/EIPS/eip-8061) | Review Standards Track: Core | 2025-10-17 |
| [EIP-8070: eth/72 - Sparse Blobpool](https://eips.ethereum.org/EIPS/eip-8070) | Review Standards Track: Networking | 2025-10-29 |
| [EIP-8131: Unified Transaction Content Floor](https://eips.ethereum.org/EIPS/eip-8131) | Draft Standards Track: Core | 2026-09-29 |
| [EIP-8136: Cell-Level Deltas for Data Column Broadcast](https://eips.ethereum.org/EIPS/eip-8136) | Review Standards Track: Networking | 2025-01-23 |
| [EIP-8141: Frame Transaction](https://eips.ethereum.org/EIPS/eip-8141) | Draft Standards Track: Core | 2026-09-28 |
| [EIP-8142: Block-in-Blobs (BiB)](https://eips.ethereum.org/EIPS/eip-8142) | Draft Standards Track: Core | 2026-01-29 |
| [EIP-8151: Account Code Restricted ecRecover](https://eips.ethereum.org/EIPS/eip-8151) | Draft Standards Track: Core | 2026-09-18 |
| [EIP-8159: eth/71 - Block Access List Exchange](https://eips.ethereum.org/EIPS/eip-8159) | Review Standards Track: Networking | 2026-09-24 |
| [EIP-8198: Quick Slots](https://eips.ethereum.org/EIPS/eip-8198) | Draft Standards Track: Core | 2026-03-17 |
| [EIP-8246: Remove SELFDESTRUCT Burn](https://eips.ethereum.org/EIPS/eip-8246) | Last Call Standards Track: Core | 2026-05-01 |
| [EIP-8250: Keyed Nonces for Frame Transactions](https://eips.ethereum.org/EIPS/eip-8250) | Draft Standards Track: Core | 2026-09-26 |
| [EIP-8261: Gas Limit Schedule](https://eips.ethereum.org/EIPS/eip-8261) | Review Informational | 2026-09-23 |
| [EIP-8272: Recent Roots for Frame Transactions](https://eips.ethereum.org/EIPS/eip-8272) | Draft Standards Track: Core | 2026-09-26 |
| [EIP-8279: Block Access List Byte Floor](https://eips.ethereum.org/EIPS/eip-8279) | Draft Standards Track: Core | 2026-09-21 |
| [EIP-8282: Builder Execution Requests](https://eips.ethereum.org/EIPS/eip-8282) | Review Standards Track: Core | 2026-09-23 |
| [EIP-8298: SETCODEFROM Code Reuse Instruction](https://eips.ethereum.org/EIPS/eip-8298) | Draft Standards Track: Core | 2026-09-25 |
| [EIP-8368: CPSB Recalibration for New Gas Limit](https://eips.ethereum.org/EIPS/eip-8368) | Draft Standards Track: Core | 2026-09-26 |
| [EIP-8369: VOPS Profiles for FOCIL Eligibility](https://eips.ethereum.org/EIPS/eip-8369) | Draft Informational | 2026-09-26 |
| [EIP-8371: RowDAS - Distributed Blob Reconstruction](https://eips.ethereum.org/EIPS/eip-8371) | Draft Standards Track: Networking | 2026-08-05 |

## Meta and official pages

- [EIP-7773](https://eips.ethereum.org/EIPS/eip-7773): Review; Sepolia activation 2026-10-06 13:53:36 UTC; Hoodi/mainnet blank. Fetch metadata 2026-09-29. Eighteen Core EIPs in SFI plus separately listed Networking/Informational EIPs. No inference that the latter add consensus validity rules.
- [EIP-8081](https://eips.ethereum.org/EIPS/eip-8081): Draft; SFI contains 7805 and 8141. 8250, 8272, 8131, 8279, 7906 and 3298 are CFI. 8198, 8142, 8371, 8368, 8369, 8298 and 8151 are PFI. Activation fields blank. Fetch metadata 2026-09-26.
- [EIP-7723](https://eips.ethereum.org/EIPS/eip-7723): Last Call; defines stage transitions and the distinction between SFI and Included.
- [Glamsterdam roadmap page](https://ethereum.org/roadmap/glamsterdam/): testing on devnets; Q4 2026 expected, not confirmed; next milestone Sepolia October 6. Page last-update text August 6. Says meta Draft and describes 2780 as reducing transfer costs, both superseded by fetched EIP texts. An older `/en/roadmap/glamsterdam` search result says H1 2026 and must not drive the verdict.
- [Hegotá roadmap page](https://ethereum.org/roadmap/hegota/): in planning; Q2 2027 expected, not confirmed; page last-update text August 31. Names FOCIL and Frames SFI, remaining scope undecided.
- [September 7 priorities](https://blog.ethereum.org/2026/09/07/protocol-priorities): Hegotá engineering centers on Frames and FOCIL together; no appetite for much additional CL scope. Fast finality is a later research/upgrade direction, not a Hegotá finality guarantee.
- [September 7 tier list](https://blog.ethereum.org/2026/09/07/protocol-hegota-eips): opinion grades differ from meta states. 8198 receives B with demanding prerequisites; 8142 receives DFI opinion while remaining PFI in meta. The opinion recommends 8250/8272 accompanying Frames and 8369 accompanying FOCIL but does not itself move them to SFI.
- [November 6 Fusaka announcement](https://blog.ethereum.org/2025/11/06/fusaka-mainnet-announcement): announces mainnet December 3, 2025; BPO1 December 9 target/max 10/15; BPO2 January 7, 2026 target/max 14/21.
- [January 20 checkpoint](https://blog.ethereum.org/2026/01/20/checkpoint-8): explicitly reports those BPO changes as active, targets 14/max 21. This is the latest activated count affirmatively verified here, not an independent current node/RPC measurement.

## Semantic observations that affect Etna

- 8141 includes blob fields and fees, split execution/state gas, VERIFY/SENDER/DEFAULT frame modes, transaction invalidity checks, and separate public-mempool admission rules. The frame research owns the full mutual-exclusion verdict; do not infer it from the abstract.
- 7906 describes POST_TX assertions that roll back execution but leave the transaction valid and gas paid. It is not a gas-free loser construction.
- 8250 adds keyed nonce domains. Base 8141 remains a separate scheduled proposal and must be usable without assuming 8250 selected.
- 8272 uses `(source_id, slot, root)`, SLOTNUM and an 8191-slot usable window; this does not authorize Etna timers to use slots under R5.
- 8198 currently proposes 8-second slots with runtime timing and proportional per-block capacity changes. 7782 proposes 6-second slots with unchanged per-block capacity. They must not be presented as the same or as both scheduled.
- 7976 explicitly quotes 64 gas per calldata byte; 7981 adds access-list data charges. 8037/8038 introduce state accounting/cost changes; 8368 is a placeholder with reference limit/CPSB TBD.
- 7904 is now Compute Gas Cost Analysis, informational, recommending no repricing. 8261 is an informational preference schedule, not a validity guarantee that validators provide a particular gas limit.
- 7688 changes CL merkleization, relevant to authenticated SSZ proof adapters even without using lookahead.
- 4788 stores parent beacon block roots. It is not automatically an oracle for the current finalized execution root.

## Evidence limits

No statement about mainnet activation relies solely on EIP Final status. No future fork date, blob increase, public-relay policy, or frame client interoperability result was measured or guaranteed. Source contradictions were resolved in favor of directly fetched specifications/meta entries and explicitly recorded rather than silently merged. Launch must re-check moving Draft/Review/Last Call specifications.

