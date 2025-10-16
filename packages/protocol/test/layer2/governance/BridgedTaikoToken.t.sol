// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../../shared/CommonTest.sol";
import "src/layer2/mainnet/BridgedTaikoToken.sol";
import "src/shared/common/EssentialContract.sol";

contract BridgedTaikoTokenTest is CommonTest {
    BridgedTaikoToken token;

    function deployBridgedTaikoToken() internal returns (BridgedTaikoToken) {
        return BridgedTaikoToken(
            deploy({
                name: "taiko_token",
                impl: address(new BridgedTaikoToken(deployer)),
                data: abi.encodeCall(BridgedTaikoToken.init, (address(0)))
            })
        );
    }

    function setUpOnTaiko() internal override {
        token = deployBridgedTaikoToken();
    }

    function test_init() public view {
        assertEq(token.name(), "Taiko Token");
        assertEq(token.symbol(), "TAIKO");
        assertEq(token.owner(), deployer);
    }

    function test_mint_and_burn() public {
        uint256 mintAmount = 1000 ether;
        uint256 burnAmount = 500 ether;

        vm.startPrank(deployer);
        token.mint(Alice, mintAmount);
        assertEq(token.balanceOf(Alice), mintAmount);

        token.mint(deployer, mintAmount);
        assertEq(token.balanceOf(deployer), mintAmount);
        token.burn(burnAmount);
        assertEq(token.balanceOf(deployer), mintAmount - burnAmount);
    }

    function test_mint_unauthorized() public {
        vm.prank(Alice);
        vm.expectRevert();
        token.mint(Bob, 1000 ether);
    }

    function test_burn_unauthorized() public {
        vm.prank(Alice);
        vm.expectRevert();
        token.burn(500 ether);
    }

    function test_canonical() public view {
        (address canonicalAddr, uint256 chainId) = token.canonical();
        assertEq(canonicalAddr, 0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800);
        assertEq(chainId, 1);
    }

    function test_pause() public {
        uint256 mintAmount = 1000 ether;

        vm.startPrank(deployer);
        token.pause();

        vm.expectRevert(EssentialContract.INVALID_PAUSE_STATUS.selector);
        token.mint(Alice, mintAmount);
    }
}
