// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";

// To print the proposal action data: `P=0019 pnpm proposal`
// To dryrun the proposal on L1: `P=0019 pnpm proposal:dryrun:l1`
contract Proposal0019 is BuildProposal {
    // Deployed mainnet implementation addresses (DeployUnzenContracts on chain 1).
    // TODO(unzen): fill in after running DeployUnzenContracts and update Proposal0019.md.
    // The build reverts while these are zero so the action file cannot be generated with
    // placeholder addresses.
    address public constant MAINNET_INBOX_NEW_IMPL = address(0);

    // New AnyTwoVerifier: SGX_RETH + (RISC0 or SP1), or RISC0 + SP1. Every accepted
    // combination contains at least one ZK proof. Baked into MAINNET_INBOX_NEW_IMPL as an
    // immutable; listed here for documentation and verification only.
    // TODO(unzen): fill in after running DeployUnzenContracts.
    address public constant ANY_TWO_VERIFIER = address(0);

    // Sub-verifiers wired into ANY_TWO_VERIFIER (all reused from Proposal0017, live on mainnet).
    address public constant SGXRETH_VERIFIER = 0x9D3C595BFf6Ff7D2b2CbdEcF94aD917eB2fCFFd8;
    address public constant RISC0_RETH_VERIFIER = 0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b;
    address public constant SP1_RETH_VERIFIER = 0x73A0Db393ef87ce781ac7957bE10D6628432100F;

    error ImplementationNotDeployed();

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        require(MAINNET_INBOX_NEW_IMPL != address(0), ImplementationNotDeployed());

        actions = new Controller.Action[](2);

        // Upgrade the Inbox to the Unzen implementation: forced inclusions re-enabled
        // (submission + mandatory processing of due inclusions) and the AnyTwoVerifier
        // (at least one ZK proof per batch) baked in as the proof verifier.
        actions[0] = buildUpgradeAction(L1.INBOX, MAINNET_INBOX_NEW_IMPL);

        // Void the stale forced inclusion queue entry (head=2, tail=3) queued during the
        // June 2026 incident. Its blob has expired from the blob retention window and can no
        // longer be derived, so it must be skipped before the due-check is re-enabled.
        actions[1] = Controller.Action({
            target: L1.INBOX, value: 0, data: abi.encodeCall(IProposal0019Inbox.init3, ())
        });
    }
}

interface IProposal0019Inbox {
    function init3() external;
}
