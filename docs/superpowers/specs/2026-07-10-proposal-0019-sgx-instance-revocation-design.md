# Proposal 0019 SGX Instance Revocation Design

## Goal

Extend Proposal 0019 so execution revokes the two pre-Unzen SGX instance signing keys in the
same atomic DAO transaction that revokes their MRENCLAVE measurements and activates the
ZK-required verifier.

## On-chain Preconditions

- The SGX-geth verifier is `0x41e79EB4F03aBB5DF8716B759528dc5d8f6a84Ee`.
- The SGX-reth verifier is `0x9D3C595BFf6Ff7D2b2CbdEcF94aD917eB2fCFFd8`.
- Both verifiers are owned by `controller.taiko.eth`.
- Both currently have `nextInstanceId() == 1`; instance ID `0` is the sole registered instance.
- `deleteInstances([0])` succeeds when called by the DAO controller.

These values must be rechecked immediately before final proposal publication. If either verifier
has registered another pre-Unzen instance, every such instance ID must also be included in the
revocation action.

## Proposal Actions

Increase the L1 action array from 20 to 22 actions. Keep actions 0 through 17 unchanged, then:

1. Call `SGXGETH_VERIFIER.deleteInstances([0])`.
2. Call `SGXRETH_VERIFIER.deleteInstances([0])`.
3. Upgrade the Inbox to the Unzen implementation.
4. Call `Inbox.init3()` to void the stale forced inclusion.

The two deletion actions execute after the old MRENCLAVEs are untrusted and before the Inbox
starts using `ZK_REQUIRED_VERIFIER`. All actions are atomic: any failed deletion or subsequent
action reverts the entire DAO execution.

## Availability Model

Deleting the two existing registrations temporarily removes both SGX proof legs until
`admin.taiko.eth` registers replacement instances with `registerInstance`. This does not interrupt
protocol proving because the same transaction activates `ZK_REQUIRED_VERIFIER`, which accepts the
`RISC0 + SP1` proof combination. The operational prerequisite is that both ZK proving paths are
live when the proposal executes.

The proposal will not owner-add replacement instances with `addInstances`, because that path
bypasses normal remote attestation.

## Code and Documentation Changes

- Add a minimal proposal-local SGX verifier interface for `deleteInstances(uint256[])`.
- Encode the same one-element instance ID array for both verifier actions.
- Update action numbering and the executive summary in `Proposal0019.md`.
- Replace the documented follow-up deletion with an execution-time and post-execution assertion.
- Update proposal tests to assert the two new targets and calldata.
- Regenerate the proposal action file once all existing Unzen placeholder constants are populated.

## Verification

- Run the Proposal 0019 unit tests and confirm the action count, ordering, targets, and calldata.
- Dry-run the proposal against a mainnet fork once the remaining Unzen constants are populated.
- Confirm the dry-run deletes both `instances(0)` entries and still completes the Inbox upgrade and
  `init3()` call atomically.
- Re-read `nextInstanceId()` and all live instance slots before publishing the final action data.
