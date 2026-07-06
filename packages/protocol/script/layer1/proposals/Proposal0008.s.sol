// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../governance/BuildProposal.sol";

// To print the proposal action data: `P=0008 pnpm proposal`
// To dryrun the proposal on L1: `P=0008 pnpm proposal:dryrun:l1`
contract Proposal0008 is BuildProposal {
    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) {
        actions = new Controller.Action[](1);

        // Update the Standard Multisig plugin's destinationProposalDuration
        // from 1_814_400 (21 days) to 864_000 (10 days).
        // All other MultisigSettings fields remain unchanged:
        //   onlyListed: true
        //   minApprovals: 5
        //   signerList: L1.DAO_SIGNER_LIST (0x0F95E6968EC1B28c794CF1aD99609431de5179c2)
        //   proposalExpirationPeriod: 1_209_600 (14 days)
        actions[0] = Controller.Action({
            target: L1.DAO_STANDARD_MULTISIG,
            value: 0,
            data: abi.encodeWithSignature(
                "updateMultisigSettings((bool,uint16,uint32,address,uint32))",
                true, // onlyListed
                uint16(5), // minApprovals
                uint32(864_000), // destinationProposalDuration (10 days)
                L1.DAO_SIGNER_LIST, // signerList
                uint32(1_209_600) // proposalExpirationPeriod (14 days)
            )
        });
    }
}
