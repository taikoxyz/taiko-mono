// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "contracts/layer1/based/ITaikoInbox.sol";
import "./InboxTestBase.sol";

contract InboxTest_ProvabilityBond is InboxTestBase {
    function setUpOnEthereum() internal override {
        bondToken = deployBondToken();
        super.setUpOnEthereum();
    }

    function v4GetConfig() internal pure override returns (ITaikoInbox.Config memory config_) {
        config_ = super.v4GetConfig();
        config_.livenessBond = 100 ether;
        config_.provingWindow = 1 hours;
        config_.provabilityBond = 1000 ether;
        config_.extendedProvingWindow = 4 hours;
        config_.bondRewardPtcg = 50; // 50%
    }

    function test_inbox_provability_bond_debit_and_credit_proved_by_proposer_in_proving_window()
        external
    {
        vm.warp(1_000_000);

        uint256 bondBalance = 100_000 ether;

        // must be the same value as used by _proposeBatchesWithProverAuth
        uint96 proverFee = 5 ether; 
        setupBondTokenState(Alice, bondBalance, bondBalance);
        setupBondTokenState(Bob, bondBalance, bondBalance);

        ITaikoInbox.Config memory config = v4GetConfig();
        uint64[] memory batchIds = _proposeBatchesWithProverAuth(
            Alice,
            1,
            Bob,
            uint256(0x2), // Bob's singing key
            "txList"
        );

        assertEq(inbox.v4BondBalanceOf(Alice), bondBalance - config.provabilityBond - proverFee);

        vm.prank(Bob);
        _proveBatchesWithCorrectTransitions(batchIds);

        assertEq(inbox.v4BondBalanceOf(Alice), bondBalance - proverFee);
        assertEq(inbox.v4BondBalanceOf(Bob), bondBalance + proverFee);
    }
}
