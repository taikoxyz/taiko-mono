# C — falsification record

**Non-normative.** Rule text lives in [SPEC.md](../../SPEC.md). Appendix C states operating requirements and cost reasoning, and declares itself not a validity rule: "This appendix states operating requirements, not validity rules." Under [../README.md](../README.md#what-an-id-means-a-citation-handle-plus-a-type) these IDs have type `assumption`, so **this file has no accept/reject vectors**: nothing conforms to an assumption and no block or landing can violate one. An assumption is falsified by a **measurement**, not by an implementation.

Each entry therefore records what would count as evidence for the assumption and which measurement would falsify it. A falsified assumption is a finding for the spec owner — it changes a budget or a target, not the validity of a block. Cases are labelled `.a`, `.b`, `...` but are not accept/reject cases.

## COST-C-1

| Case | Measurement | Reading |
|---|---|---|
| 1.a | funded budget lines and reconciled spend for validators, proving, landing, historical data and on-call, over one epoch | supports if every named category is funded and reconciled; falsifies if any is unfunded |
| 1.b | a period with low or zero transaction load, FI backlog consumption, repeated DA, discarded competitive work and retries | falsifies if the measured cost of these conditions is not covered by the budget |
| 1.c | on-call rota and its payment records | falsifies if on-call service is unpaid or unfunded |

## COST-C-2

| Case | Measurement | Reading |
|---|---|---|
| 2.a | L1 accounting of landing transactions: burned base fee, blob fees, tips, and any protocol-side inflow | supports if landing yields no protocol revenue; falsifies if any protocol revenue from landing exists |
| 2.b | total landing and proving cost for a period against the operating budget | falsifies if any landing or proving cost falls outside the budget |

## COST-C-3

| Case | Measurement | Reading |
|---|---|---|
| 3.a | contract and deployment inspection: `land` is permissionless, with no allowlist, funded-only or operator-only path | falsifies if any exclusive landing path exists |
| 3.b | an unfunded address lands a valid batch during the funded period | supports if it can land |

## COST-C-4

| Case | Measurement | Reading |
|---|---|---|
| 4.a | the compensation formula and actual disbursements to landers | falsifies if any payment scales with FI entries consumed or with FI fee value |
| 4.b | FI fee flow: fees stay in the Inbox and are swept to the fixed treasury | supports if no lander receives an FI fee |

## COST-C-5

| Case | Measurement | Reading |
|---|---|---|
| 5.a | disbursement records: is any payment keyed to the address that submitted a landing transaction | falsifies if a per-landing bounty paid to the submitting address exists |
| 5.b | copy test: a third party reproduces a public blob transaction and lands it | falsifies if the copy cannot land or if the landing binds a recipient; supports if the submitter is unidentified on chain |

## COST-C-6

| Case | Measurement | Reading |
|---|---|---|
| 6.a | measured block interval and measured interval between L1 inclusions of successive successful landings, under sustained target load | supplies the numbers the budget must cover; falsifies the target if it is not met |
| 6.b | a funded budget naming currency, owner and period, with a treasury balance or commitment behind it | falsifies "funding is in place" if only cost estimates exist |
| 6.c | measured cost at the targets compared with the funded amount | falsifies if measured cost exceeds funding |

## COST-C-7

| Case | Measurement | Reading |
|---|---|---|
| 7.a | a proposer's own zk-heavy and data-heavy blocks: fees paid against fees received | supports if the net fee is zero; falsifies if a proposer pays a net fee for its own load |
| 7.b | search for a further binding limit on a proposer's own block content | falsifies "bounded only by" if any limit other than per-block gas, zk gas and 124,000 bytes binds |

## COST-C-8

| Case | Measurement | Reading |
|---|---|---|
| 8.a | a zk-heavy, low-EVM-gas block metered under the pinned zk-gas rules and limits | supports if zk gas can approach `L2_BLOCK_ZK_GAS_LIMIT`; falsifies if metering holds it far below |
| 8.b | the same workload at the zk limit | supports if it is admitted at the limit with little EVM gas used |

## COST-C-9

| Case | Measurement | Reading |
|---|---|---|
| 9.a | maximum-size blocks filled with incompressible data; measured payload size | supports if this is the largest payload case; falsifies if another fill pattern yields more payload bytes |
| 9.b | a mixed population of blocks compared with the incompressible case | supports if none is larger |

## COST-C-10

| Case | Measurement | Reading |
|---|---|---|
| 10.a | the pinned K; m = largest multiple of K not above 6; 900/m computed | supports if it reproduces about 150 when K divides 6, 225 at K = 4 and 180 at K = 5; falsifies if the arithmetic differs |
| 10.b | measured landing rate at sustained load | falsifies if the achieved rate is below the funded figure |
| 10.c | landing heights checked against multiples of K | supports if every landing ends at a grid point |

## COST-C-11

| Case | Measurement | Reading |
|---|---|---|
| 11.a | blobs per L1 slot at the funded landing rate (landings per hour times six blobs, divided by L1 slots per hour) | supports if about 3; falsifies if the measured demand per slot is higher |
| 11.b | the L1 slot duration used in that division | falsifies the figure if the L1 slot is not the assumed 12 s — see [Q-C-5](../review/C.md#q-c-5) |

## COST-C-12

| Case | Measurement | Reading |
|---|---|---|
| 12.a | budget documents with separate proving, blob and landing lines | supports if all three lines exist |
| 12.b | each line compared with the sustained worst case | falsifies if any line is below that case |

## Not covered

| Rule | Gap | Question |
|---|---|---|
| COST-C-1 to COST-C-12 | no accept/reject case can exist: an assumption is falsified by measurement, not by an implementation | [../README.md](../README.md#what-an-id-means-a-citation-handle-plus-a-type) |
| COST-C-5 | a "must not" sits inside an appendix that declares itself non-normative | [Q-C-1](../review/C.md#q-c-1) |
| COST-C-6, COST-C-10 | the funded worst case is defined against targets that are not validity rules | [Q-C-2](../review/C.md#q-c-2) |
| COST-C-6 | what evidence counts as "funding is in place" | [Q-C-3](../review/C.md#q-c-3) |
| COST-C-10 | which funded figure applies before K is pinned | [Q-C-4](../review/C.md#q-c-4) |
| COST-C-11 | the L1 slot duration is assumed but never stated | [Q-C-5](../review/C.md#q-c-5) |
