// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BuildProposal } from "../governance/BuildProposal.sol";
import { LibL1Addrs as L1 } from "src/layer1/mainnet/LibL1Addrs.sol";
import { Controller } from "src/shared/governance/Controller.sol";

// To print the proposal action data: `P=0024 pnpm proposal`
// To dryrun the proposal on L1: `P=0024 pnpm proposal:dryrun:l1`
/// @custom:security-contact security@taiko.xyz
contract Proposal0024 is BuildProposal {
    /// @dev The `MainnetInbox` implementation the inbox proxy upgrades to: the live configuration
    /// with `basefeeSharingPctg` raised from 75 to 100. Deployed by `DeployInboxUpgradeL1` on
    /// Ethereum mainnet.
    /// https://codediff.taiko.xyz/?addr=0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f&newimpl=0xA18431d42C8dF9778905fBEa912aCF1881b49D2e&chainid=1
    address public constant MAINNET_INBOX_NEW_IMPL = 0xA18431d42C8dF9778905fBEa912aCF1881b49D2e;

    error ImplementationNotDeployed();

    function buildL1Actions() internal pure override returns (Controller.Action[] memory) {
        return buildL1Actions(MAINNET_INBOX_NEW_IMPL);
    }

    /// @dev Encodes the L1 leg against an injectable implementation so tests can assert the
    /// encoding while the constant above is still a placeholder.
    /// @param _inboxImpl The implementation the inbox proxy upgrades to.
    /// @return actions The single L1 action.
    function buildL1Actions(address _inboxImpl)
        internal
        pure
        returns (Controller.Action[] memory actions)
    {
        require(_inboxImpl != address(0), ImplementationNotDeployed());

        actions = new Controller.Action[](1);

        // 0: Upgrade the inbox to the implementation that pays the whole basefee to the coinbase.
        // Immutables only: the new implementation carries the live proof verifier, proposer
        // checker, prover whitelist, signal service and bond token, and the same numeric
        // configuration apart from basefeeSharingPctg. No initializer runs, and the proxy's
        // storage (core state, proposal hashes, forced inclusion queue, bonds) is untouched.
        // Proposals already made keep the percentage they were proposed with; the first propose
        // after execution carries 100.
        actions[0] = buildUpgradeAction(L1.INBOX, _inboxImpl);
    }
}
