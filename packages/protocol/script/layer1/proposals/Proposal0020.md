# PROPOSAL-0020: Security Council Revamp (9 → 5 Members, New Thresholds)

> **DRAFT — do not submit yet.** The forum discussion link is pending, and the agent
> rotation in [Prerequisites](#prerequisites) must happen before execution.

## Executive Summary

This proposal restructures the Security Council:

- **Removed (5):** Chainbound, Halborn, Drew Van der Werff, Toni Wahrstätter, Gattaca
- **Retained (4):** Taiko Labs, L2BEAT, Aragon, Nethermind
- **Added (1):** Gustavo Gonzalez (independent member), seat
  `0xAC5898b0FFFd23F4Ef09F0E50Fa1bC4896eF7163` (EOA)
- **Standard proposal threshold:** 5/9 → **3/5**
- **Emergency proposal threshold:** 7/9 → **4/5**
- **SignerList `minSignerListLength`:** 8 → **4** (contract-documented floor: must be ≥ the
  emergency `minApprovals`; 4 preserves the current one-removal headroom pattern)

## Prerequisites

1. **Seat choice (accepted trade-off)**: the new seat is the EOA
   `0xAC5898b0FFFd23F4Ef09F0E50Fa1bC4896eF7163`, hardcoded as `NEW_MEMBER` in
   `Proposal0020.s.sol`. Unlike the other seats (Safes with appointed agents), rotating
   or recovering this seat's key requires a DAO proposal; a hardware wallet is strongly
   recommended, and the same key also derives the seat's emergency-decryption keypair.
2. **Taiko Labs agent rotation — required before EXECUTION**: the seat address is
   currently the encryption agent appointed by the Taiko Labs Safe
   (`0xb47fE76aC588101BFBdA9E68F66433bA51E8029a`). Any time between proposal creation and
   final execution — recommended when the proposal is forwarded to the veto stage —
   Taiko Labs must call `EncryptionRegistry.appointAgent(replacementEOA)`. Rotation
   timing does not disturb approvals: membership is snapshotted at creation, agent
   resolution is current-state, and approvals are recorded per seat owner. If the
   proposal executes while the appointment still stands, the Taiko Labs seat cannot
   approve new proposals until Taiko Labs rotates (recoverable at any time, but the
   council effectively runs 4-seated meanwhile). The dryrun simulates this rotation and
   `checkPostState` asserts the invariant.
3. **No in-flight proposals**: confirm no open Standard or Emergency multisig proposals at
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

Ordering is mandatory: Action 1 must precede Action 3 (`removeSigners` reverts if the list
would drop below `minSignerListLength`, currently 8), and Actions 4–5 must follow Action 3
(`minApprovals ≤ addresslistLength()` is checked against the then-current list).

| # | Target | Call |
| - | ------ | ---- |
| 1 | SignerList `0x0F95E6968EC1B28c794CF1aD99609431de5179c2` | `updateSettings((0x2eFDb93a3B87b930E553d504db67Ee41c69C42d1, 4))` |
| 2 | SignerList | `addSigners([0xAC5898b0FFFd23F4Ef09F0E50Fa1bC4896eF7163])` |
| 3 | SignerList | `removeSigners([Chainbound, Halborn, Drew, Toni, Gattaca])` |
| 4 | Standard Multisig `0xD7dA1C25E915438720692bC55eb3a7170cA90321` | `updateMultisigSettings((true, 3, 864000, SignerList, 1209600))` |
| 5 | Emergency Multisig `0x2AffADEb2ef5e1F2a7F58964ee191F1e88317ECd` | `updateMultisigSettings((true, 4, SignerList, 1209600))` |
| 6 | EncryptionRegistry `0x2eFDb93a3B87b930E553d504db67Ee41c69C42d1` | `removeUnused()` |

The exact per-action calldata is produced by `Proposal0020.s.sol` (`P=0020 pnpm proposal`)
and committed as `Proposal0020.action.md`.

Member addresses (from the on-chain SignerList census, cross-checked against
`security-council-profiles.json` in `taikoxyz/dao-ui-mono`):

| Member | Seat (Safe) | Disposition |
| ------ | ----------- | ----------- |
| Taiko Labs | `0xb47fE76aC588101BFBdA9E68F66433bA51E8029a` | retained |
| L2BEAT | `0xf1cF63589A1e012F9124182c9eAa36B5333e5f06` | retained |
| Aragon | `0xb284810536C0dAB6A8e48153B58588A9B9e0F701` | retained |
| Nethermind | `0x5353c607e6eca6C63FEC5c6C0F5CC3a5348d5c95` | retained |
| Gustavo Gonzalez (independent) | `0xAC5898b0FFFd23F4Ef09F0E50Fa1bC4896eF7163` (EOA) | added |
| Chainbound | `0x436a1075099A145417EBFc74BBaC9605e3e4f1A7` | removed |
| Halborn | `0x0F40268Ec0Dc8D88CF2f22E227A29a0b478b6351` | removed |
| Drew Van der Werff | `0x25d3E89bAcE2040Ed3aF7c4c7B505cfBB72fD6f1` | removed |
| Toni Wahrstätter | `0xa384E224A3F3D664F43eBE33395eF0DCcE67e894` | removed |
| Gattaca | `0x6268d189E011Aa53A2f09A1FE159445BeB3d878E` | removed |

### Current vs. New Settings

| Parameter | Current | New |
| --------- | ------- | --- |
| SignerList members | 9 | 5 |
| SignerList `minSignerListLength` | 8 | 4 |
| Standard `minApprovals` | 5 | 3 |
| Standard `destinationProposalDuration` | 864,000 (10 days) | unchanged |
| Standard `proposalExpirationPeriod` | 1,209,600 (14 days) | unchanged |
| Emergency `minApprovals` | 7 | 4 |
| Emergency `proposalExpirationPeriod` | 1,209,600 (14 days) | unchanged |

## Post-execution steps

1. The new member EOA registers its encryption key via dao.taiko.xyz
   (`setOwnPublicKey`, only possible once listed); until then the seat can approve
   emergency proposals but cannot decrypt them.
2. Taiko Labs' replacement agent registers its key the same way (rotation wiped the
   stored key).
3. Update `security-council-profiles.json` in `taikoxyz/dao-ui-mono`; record execution in
   `deployments/mainnet-contract-logs-L1.md`.

## Building and submitting via the DAO UI

`Proposal0020.s.sol` is the reviewed source of truth. It builds on
`script/layer1/governance/BuildDirectProposal.sol` — the direct-DAO sibling of
`BuildProposal` for governance-stack changes (see Technical Specification) — so the
proposal file contains only the member addresses, the new settings, the six actions, and
the dryrun assertions; all print/dryrun/verify machinery lives in the base. The proposal
is created through the Taiko DAO UI (dao.taiko.xyz), which pins the metadata to IPFS and
assembles the `createProposal` call; the script supplies the six actions to paste into the
UI's custom-action (calldata) form and verifies the result on-chain afterwards:

```bash
# 1. Print the actions (writes Proposal0020.action.md; METADATA_URI not needed — the UI pins it):
P=0020 pnpm proposal
# 2. Fork rehearsal: baseline checks, proposal creation, simulated agent rotation, DAO
#    execution, post-state asserts:
SENDER=0x<member-or-agent> P=0020 pnpm proposal:dryrun:l1
# 3. Review Proposal0020.action.md; have a second member re-run + diff
# 4. In the DAO UI: new standard proposal; fill title/summary/description/resources from
#    Proposal0020.metadata.json; add the six actions via the custom-action (calldata) form,
#    in order (the UI decodes each pasted calldata against the verified ABI — eyeball it)
# 5. Submit; note the new proposal id, then byte-verify what landed on-chain:
PROPOSAL_ID=<id> P=0020 pnpm proposal:verify
# 6. Share the verify command with every approver — approve only if it prints "Verify OK"
```

Direct-submission fallback (bypassing the UI): pre-pin the metadata yourself and pass
`METADATA_URI=ipfs://<CID>` to the `print` mode to get the full `createProposal` calldata.

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
