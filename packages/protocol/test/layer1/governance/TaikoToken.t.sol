// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "test/shared/CommonTest.sol";

contract TaikoTokenTest is CommonTest {
    TaikoToken internal token;

    event VotingPowerRenounced(address indexed account);

    function setUpOnEthereum() internal override {
        token = deployTaikoToken();
    }

    function _seed(address _to, uint256 _amount) internal {
        token.transfer(_to, _amount);
        vm.prank(_to);
        token.delegate(_to);
    }

    function _advance() internal {
        mineOneBlockAndWrap(1);
    }

    function test_init() public view {
        assertEq(token.name(), "Taiko Token");
        assertEq(token.symbol(), "TAIKO");
        assertEq(token.totalSupply(), 1_000_000_000 ether);
    }

    function test_renounceVotingPower_succeeds() public {
        _seed(Alice, 100 ether);
        _advance();

        assertEq(token.getVotes(Alice), 100 ether);
        assertFalse(token.hasRenouncedVotingPower(Alice));

        vm.expectEmit();
        emit VotingPowerRenounced(Alice);
        vm.prank(Alice);
        token.renounceVotingPower();

        assertTrue(token.hasRenouncedVotingPower(Alice));
        assertEq(token.getVotes(Alice), 0);
    }

    function test_renounceVotingPower_doesNotReduceTotalVotingSupply() public {
        _seed(Alice, 100 ether);
        _seed(Bob, 50 ether);
        _advance();

        uint256 t1 = block.timestamp - 1;
        uint256 supplyBefore = token.getPastTotalSupply(t1);

        vm.prank(Alice);
        token.renounceVotingPower();
        _advance();

        uint256 t2 = block.timestamp - 1;
        uint256 supplyAfter = token.getPastTotalSupply(t2);

        assertEq(supplyAfter, supplyBefore);
        assertEq(token.getPastVotes(Alice, t2), 0);
        assertEq(token.getPastVotes(Bob, t2), 50 ether);
    }

    function test_renounceVotingPower_RevertWhen_AlreadyRenounced() public {
        vm.startPrank(Alice);
        token.renounceVotingPower();

        vm.expectRevert(TaikoToken.TT_VOTING_POWER_RENOUNCED.selector);
        token.renounceVotingPower();
        vm.stopPrank();
    }

    function test_renounceVotingPower_RevertWhen_HardcodedNonVotingAccount() public {
        vm.prank(token.TAIKO_FOUNDATION_TREASURY());
        vm.expectRevert(TaikoToken.TT_NON_VOTING_ACCOUNT.selector);
        token.renounceVotingPower();

        vm.prank(token.TAIKO_DAO_CONTROLLER());
        vm.expectRevert(TaikoToken.TT_NON_VOTING_ACCOUNT.selector);
        token.renounceVotingPower();

        vm.prank(token.TAIKO_ERC20_VAULT());
        vm.expectRevert(TaikoToken.TT_NON_VOTING_ACCOUNT.selector);
        token.renounceVotingPower();
    }

    function test_delegate_afterRenounce_doesNotRestoreVotes() public {
        _seed(Alice, 100 ether);
        vm.prank(Alice);
        token.renounceVotingPower();

        vm.prank(Alice);
        token.delegate(Bob);
        _advance();

        assertEq(token.getVotes(Alice), 0);
        assertEq(token.getPastVotes(Alice, block.timestamp - 1), 0);
    }

    function test_getPastVotes_returnsZeroForRenouncedAccount() public {
        _seed(Alice, 100 ether);
        _advance();

        uint256 tBefore = block.timestamp - 1;
        assertEq(token.getPastVotes(Alice, tBefore), 100 ether);

        vm.prank(Alice);
        token.renounceVotingPower();
        _advance();

        assertEq(token.getPastVotes(Alice, tBefore), 0);
        assertEq(token.getPastVotes(Alice, block.timestamp - 1), 0);
    }

    function test_renouncedAccount_canStillTransferAndReceive() public {
        _seed(Alice, 100 ether);

        vm.prank(Alice);
        token.renounceVotingPower();

        vm.prank(Alice);
        token.transfer(Bob, 30 ether);
        assertEq(token.balanceOf(Alice), 70 ether);
        assertEq(token.balanceOf(Bob), 30 ether);

        token.transfer(Alice, 10 ether);
        assertEq(token.balanceOf(Alice), 80 ether);

        _advance();
        assertEq(token.getVotes(Alice), 0);
        assertEq(token.getPastVotes(Alice, block.timestamp - 1), 0);
    }

    function test_hasRenouncedVotingPower_returnsExpected() public {
        assertFalse(token.hasRenouncedVotingPower(Alice));
        assertFalse(token.hasRenouncedVotingPower(Bob));

        vm.prank(Alice);
        token.renounceVotingPower();

        assertTrue(token.hasRenouncedVotingPower(Alice));
        assertFalse(token.hasRenouncedVotingPower(Bob));
    }

    function test_inboundDelegatorLosesPower_whenDelegateRenounces() public {
        token.transfer(Bob, 75 ether);
        vm.prank(Bob);
        token.delegate(Alice);
        _advance();

        assertEq(token.getVotes(Alice), 75 ether);

        vm.prank(Alice);
        token.renounceVotingPower();
        _advance();

        uint256 t = block.timestamp - 1;
        assertEq(token.getVotes(Alice), 0);
        assertEq(token.getPastVotes(Alice, t), 0);

        vm.prank(Bob);
        token.delegate(Carol);
        _advance();

        assertEq(token.getVotes(Carol), 75 ether);
    }
}
