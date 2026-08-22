# PROPOSAL-0020: Security Council Revamp (9 → 5 Members, New Thresholds)

## Executive Summary

This proposal restructures the Security Council:

- **Removed (6):** Chainbound, Halborn, Drew Van der Werff, Toni Wahrstätter, Gattaca,
  Nethermind
- **Retained (3):** Taiko Labs, L2BEAT, Aragon
- **Added (2):** Gustavo Gonzalez (independent member), seat
  `0xe63E61BbB3aa1b82d44471AbcAb490102C17c986` (EOA); Daniel Wang, seat
  `0xF74F2bBaEd41e3e4AbAcbA24563a5Ce5aB071C8A` (EOA)
- **Standard proposal threshold:** 5/9 → **3/5**
- **Emergency proposal threshold:** 7/9 → **4/5**
- **SignerList `minSignerListLength`:** 8 → **4** (contract-documented floor: must be ≥ the
  emergency `minApprovals`; 4 preserves the current one-removal headroom pattern)

## Prerequisites

1. **The new seat addresses must hold no agent appointment at EXECUTION**: neither new
   seat — `0xe63E61BbB3aa1b82d44471AbcAb490102C17c986` (Gustavo Gonzalez) nor
   `0xF74F2bBaEd41e3e4AbAcbA24563a5Ce5aB071C8A` (Daniel Wang) — is any seat's appointed
   encryption agent today (verified on-chain), and both must remain unappointed through
   execution — once an agent's address is listed as its own seat, its approvals credit
   that seat instead, leaving the appointing seat without a valid approver until it
   rotates (recoverable at any time, but that seat cannot approve meanwhile). The dryrun
   simulates the release if an appointment appears before execution, and
   `checkPostState` asserts the invariant. The rule is permanent: after execution, no
   seat may appoint a listed seat address (including these two) as its agent. This
   proposal does not touch the Taiko Labs seat's current agent appointment.
2. **No in-flight proposals**: confirm no open Standard or Emergency multisig proposals at
   execution time (members removed here can still act on proposals created earlier, whose
   census is snapshotted, until they expire after 14 days).

## Technical Specification

Unlike protocol upgrades, these actions are **not** routed through the DAO Controller
(`controller.taiko.eth`) — the Aragon permissions (`UPDATE_SIGNER_LIST_PERMISSION`,
`UPDATE_SIGNER_LIST_SETTINGS_PERMISSION`, `UPDATE_MULTISIG_SETTINGS_PERMISSION`) are
granted to the DAO (`0x9CDf589C941ee81D75F34d3755671d614f7cf261`) only, so the
`BuildProposal` pipeline does not apply. The proposal is created on the Standard Multisig
with the six actions below as direct `IDAO.Action` entries (precedent: Proposal0008's
settings change and the 2025-06-02 / 2026-01-19 membership changes all executed directly
from the DAO). `allowFailureMap` is fixed to 0 by the multisig, so any reverting action
aborts execution.

Ordering: two dependencies are contract-enforced. Action 1 must precede Action 3
(`removeSigners` reverts if the list would drop below `minSignerListLength`, currently 8),
and Action 2 must precede Action 3 (removing 6 of the current 9 members would leave 3,
below even the new floor of 4; adding first takes the list to 11, so the removals land at
5). Actions 4–5 are placed after Action 3 defensively: `minApprovals ≤
addresslistLength()` is checked against the then-current list, which the new thresholds
(3, 4) satisfy at every intermediate size (9 → 11 after Action 2 → 5 after Action 3).

| #   | Target                                                          | Call                                                                                                   |
| --- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| 1   | SignerList `0x0F95E6968EC1B28c794CF1aD99609431de5179c2`         | `updateSettings((0x2eFDb93a3B87b930E553d504db67Ee41c69C42d1, 4))`                                      |
| 2   | SignerList                                                      | `addSigners([0xe63E61BbB3aa1b82d44471AbcAb490102C17c986, 0xF74F2bBaEd41e3e4AbAcbA24563a5Ce5aB071C8A])` |
| 3   | SignerList                                                      | `removeSigners([Chainbound, Halborn, Drew, Toni, Gattaca, Nethermind])`                                |
| 4   | Standard Multisig `0xD7dA1C25E915438720692bC55eb3a7170cA90321`  | `updateMultisigSettings((true, 3, 864000, SignerList, 1209600))`                                       |
| 5   | Emergency Multisig `0x2AffADEb2ef5e1F2a7F58964ee191F1e88317ECd` | `updateMultisigSettings((true, 4, SignerList, 1209600))`                                               |
| 6   | EncryptionRegistry `0x2eFDb93a3B87b930E553d504db67Ee41c69C42d1` | `removeUnused()`                                                                                       |

The exact per-action calldata is produced by `Proposal0020.s.sol` (`P=0020 pnpm proposal`)
and committed as `Proposal0020.action.md`.

Action 6 removes the delisted members from the registry's account enumeration only; their
`appointerOf`/agent mappings persist. This is harmless — an unlisted appointer can never
resolve for approvals — but their former agent addresses stay reserved and cannot be
appointed by other seats. See `removeUnused()` in
[EncryptionRegistry.sol](https://github.com/taikoxyz/dao-contracts/blob/dao-contracts-v1.0.0/src/EncryptionRegistry.sol);
the dryrun's `checkPostState` asserts the pruning.

Member addresses (from the on-chain SignerList census, cross-checked against
`security-council-profiles.json` in `taikoxyz/dao-ui-mono`):

| Member                         | Seat (Safe)                                        | Disposition |
| ------------------------------ | -------------------------------------------------- | ----------- |
| Taiko Labs                     | `0xb47fE76aC588101BFBdA9E68F66433bA51E8029a`       | retained    |
| L2BEAT                         | `0xf1cF63589A1e012F9124182c9eAa36B5333e5f06`       | retained    |
| Aragon                         | `0xb284810536C0dAB6A8e48153B58588A9B9e0F701`       | retained    |
| Gustavo Gonzalez (independent) | `0xe63E61BbB3aa1b82d44471AbcAb490102C17c986` (EOA) | added       |
| Daniel Wang                    | `0xF74F2bBaEd41e3e4AbAcbA24563a5Ce5aB071C8A` (EOA) | added       |
| Nethermind                     | `0x5353c607e6eca6C63FEC5c6C0F5CC3a5348d5c95`       | removed     |
| Chainbound                     | `0x436a1075099A145417EBFc74BBaC9605e3e4f1A7`       | removed     |
| Halborn                        | `0x0F40268Ec0Dc8D88CF2f22E227A29a0b478b6351`       | removed     |
| Drew Van der Werff             | `0x25d3E89bAcE2040Ed3aF7c4c7B505cfBB72fD6f1`       | removed     |
| Toni Wahrstätter               | `0xa384E224A3F3D664F43eBE33395eF0DCcE67e894`       | removed     |
| Gattaca                        | `0x6268d189E011Aa53A2f09A1FE159445BeB3d878E`       | removed     |

### Current vs. New Settings

| Parameter                              | Current             | New       |
| -------------------------------------- | ------------------- | --------- |
| SignerList members                     | 9                   | 5         |
| SignerList `minSignerListLength`       | 8                   | 4         |
| Standard `minApprovals`                | 5                   | 3         |
| Standard `destinationProposalDuration` | 864,000 (10 days)   | unchanged |
| Standard `proposalExpirationPeriod`    | 1,209,600 (14 days) | unchanged |
| Emergency `minApprovals`               | 7                   | 4         |
| Emergency `proposalExpirationPeriod`   | 1,209,600 (14 days) | unchanged |

## Post-execution steps

1. Each new member EOA registers its encryption key via dao.taiko.xyz
   (`setOwnPublicKey`, only possible once listed); until then the seat can approve
   emergency proposals but cannot decrypt them.
2. Update `security-council-profiles.json` in `taikoxyz/dao-ui-mono`; record execution in
   `deployments/mainnet-contract-logs-L1.md`.

## Building and submitting via the DAO UI

`Proposal0020.s.sol` is the reviewed source of truth. It builds on
`script/layer1/governance/BuildDirectProposal.sol` — the direct-DAO sibling of
`BuildProposal` for governance-stack changes (see Technical Specification) — so the
proposal file contains only the member addresses, the new settings, the six actions, and
the dryrun assertions; all print/dryrun machinery lives in the base. Every call to the
governance contracts is typed against
`script/layer1/governance/IAragonGovernance.sol` (compiler-derived selectors and named
struct fields, no hand-encoded signatures); the dryrun exercises the declarations
against the fork (`appointAgent` only until the Taiko Labs agent rotation lands
on-chain — see that file's header for the full fidelity anchors). The proposal is
created through the Taiko DAO UI (dao.taiko.xyz), which pins the metadata to IPFS and
assembles the `createProposal` call; the script supplies the six actions to paste into the
UI's custom-action (calldata) form:

```bash
# 1. Print the actions (writes Proposal0020.action.md; METADATA_URI not needed — the UI pins it):
P=0020 pnpm proposal
# 2. Fork rehearsal: baseline checks, proposal creation, simulated agent rotation, DAO
#    execution, post-state asserts:
SENDER=0x<member-or-agent> P=0020 pnpm proposal:dryrun:l1
# 3. Review Proposal0020.action.md; have a second member re-run + diff
# 4. In the DAO UI: new standard proposal; fill the fields from "DAO UI fields" below;
#    add the six actions via the custom-action (calldata) form, in order (the UI decodes
#    each pasted calldata against the verified ABI — eyeball it)
# 5. Submit, then confirm what landed on-chain matches this repo before approving —
#    compare each stored action against Proposal0020.action.md (approvers should too):
cast call 0xD7dA1C25E915438720692bC55eb3a7170cA90321 \
  "getProposal(uint256)(bool,uint16,(uint16,uint64,uint64),bytes,(address,uint256,bytes)[],address)" \
  <PROPOSAL_ID> --rpc-url <ETHEREUM_RPC>
```

The `getProposal` output tuple mirrors `IMultisig.getProposal` in
`script/layer1/governance/IAragonGovernance.sol`; the dryrun rehearses this comparison
(it asserts the stored actions match `buildDaoActions()` after creation).

Direct-submission fallback (bypassing the UI): pre-pin the metadata yourself and pass
`METADATA_URI=ipfs://<CID>` to the `print` mode to get the full `createProposal` calldata.

### DAO UI fields

The UI pins these verbatim to IPFS as the proposal metadata — this is what the Security
Council and, during the veto window, TAIKO holders read. Paste them exactly:

- **Title:** Security Council Revamp: 9 to 5 Members, New Thresholds
- **Summary:** Restructures the Security Council to 5 members (Taiko Labs, L2BEAT, Aragon,
  Gustavo Gonzalez, Daniel Wang), sets the standard proposal threshold to 3/5 and the
  emergency proposal threshold to 4/5.
- **Description:** Removes Chainbound, Halborn, Drew Van der Werff, Toni Wahrstätter,
  Gattaca and Nethermind; retains Taiko Labs, L2BEAT and Aragon; adds Gustavo Gonzalez as
  an independent member (seat `0xe63E61BbB3aa1b82d44471AbcAb490102C17c986`) and Daniel
  Wang (seat `0xF74F2bBaEd41e3e4AbAcbA24563a5Ce5aB071C8A`). Lowers the SignerList
  `minSignerListLength` from 8 to 4, the standard multisig `minApprovals` from 5 to 3,
  and the emergency multisig `minApprovals` from 7 to 4. All other settings (the 10-day
  veto duration and 14-day proposal expiration) are unchanged. Full technical
  specification, including the exact actions and their mandatory ordering:
  https://github.com/taikoxyz/taiko-mono/blob/main/packages/protocol/script/layer1/proposals/Proposal0020.md
- **Resources:** the forum discussion link, plus the specification URL above.

## Verification

Verify current on-chain state before submission:

```bash
cast call 0x0F95E6968EC1B28c794CF1aD99609431de5179c2 "addresslistLength()(uint256)" --rpc-url <ETHEREUM_RPC>   # 9
cast call 0x0F95E6968EC1B28c794CF1aD99609431de5179c2 "settings()(address,uint16)" --rpc-url <ETHEREUM_RPC>    # ER, 8
cast call 0xD7dA1C25E915438720692bC55eb3a7170cA90321 "multisigSettings()" --rpc-url <ETHEREUM_RPC>            # 5/9
cast call 0x2AffADEb2ef5e1F2a7F58964ee191F1e88317ECd "multisigSettings()" --rpc-url <ETHEREUM_RPC>            # 7/9
```

## Forum Discussion

TBD — to be posted before proposal creation.

## Security Contacts

- Primary: security@taiko.xyz
