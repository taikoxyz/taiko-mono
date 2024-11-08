// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../TaikoTest.sol";

contract TestBridgedERC20 is TaikoTest {
    address vault = randAddress();

    function setUpOnSourceChain() internal override {
        register("erc20_vault", vault);
    }

    function test_20Vault_migration__change_migration_status() public {
        vm.startPrank(deployer);
        BridgedERC20 btoken = deployBridgedToken("FOO");
        vm.stopPrank();

        vm.expectRevert();
        btoken.changeMigrationStatus(Emma, false);

        vm.startPrank(vault);
        btoken.changeMigrationStatus(Frank, false);
        btoken.changeMigrationStatus(address(0), false);
        btoken.changeMigrationStatus(address(0), true);
        btoken.changeMigrationStatus(Frank, true);
        vm.expectRevert();
        btoken.changeMigrationStatus(Frank, true);

        vm.stopPrank();
    }

    function test_20Vault_migration___only_vault_can_min__but_cannot_burn_when_migration_off()
        public
    {
        vm.startPrank(deployer);
        BridgedERC20 btoken = deployBridgedToken("BAR");
        vm.stopPrank();

        // only erc20_vault can brun and mint
        vm.prank(vault);
        btoken.mint(Bob, 1000);

        // Vault cannot burn only if it owns the tokens
        vm.expectRevert();
        vm.prank(Bob);
        btoken.burn(600);

        assertEq(btoken.balanceOf(Bob), 1000);

        // Owner can burn/mint
        vm.prank(deployer);
        btoken.mint(Bob, 1000);
    }

    function test_20Vault_migration__old_to_new() public {
        vm.startPrank(deployer);
        BridgedERC20 oldToken = deployBridgedToken("OLD");
        BridgedERC20 newToken = deployBridgedToken("NEW");
        vm.stopPrank();

        vm.startPrank(vault);
        oldToken.mint(Bob, 100);
        newToken.mint(Bob, 200);

        oldToken.changeMigrationStatus(address(newToken), false);
        newToken.changeMigrationStatus(address(oldToken), true);
        vm.stopPrank();

        // Testing oldToken
        // 1. minting is not possible for Bob, owner, or vault
        vm.prank(Bob);
        vm.expectRevert();
        oldToken.mint(Bob, 10);

        vm.prank(deployer);
        vm.expectRevert();
        oldToken.mint(Bob, 10);

        vm.prank(vault);
        vm.expectRevert();
        oldToken.mint(Bob, 10);

        // but can be done by the token owner - if migrating out phase
        vm.prank(Bob);
        oldToken.burn(10);
        assertEq(oldToken.balanceOf(Bob), 90);
        assertEq(newToken.balanceOf(Bob), 210);

        // Testing newToken
        // 1. Nobody can mint except the vault
        vm.prank(Bob);
        vm.expectRevert();
        newToken.mint(Bob, 10);

        vm.prank(deployer);
        newToken.mint(Bob, 10);

        vm.prank(vault);
        newToken.mint(Bob, 15);
        assertEq(newToken.balanceOf(Bob), 235);

        // Vault can only burn if it owns the tokens
        vm.prank(vault);
        vm.expectRevert();
        newToken.burn(25);
        assertEq(newToken.balanceOf(Bob), 235);

        // Imitate current bridge-back operation, as Bob gave approval (for bridging back) and then
        // ERC20Vault does the "transfer and burn"
        vm.prank(Bob);
        newToken.approve(vault, 25);

        // Following the "transfer and burn" pattern
        vm.prank(vault);
        newToken.transferFrom(Bob, vault, 25);

        vm.prank(vault);
        newToken.burn(25);

        assertEq(newToken.balanceOf(Bob), 210);
    }

    function deployBridgedToken(bytes32 name) internal returns (BridgedERC20) {
        address srcToken = randAddress();
        uint256 srcChainId = 1000;
        uint8 srcDecimals = 11;
        string memory _name = bytes32ToString(name);
        return BridgedERC20(
            deploy({
                name: name,
                impl: address(new BridgedERC20V2()),
                data: abi.encodeCall(
                    BridgedERC20.init,
                    (deployer, address(resolver), srcToken, srcChainId, srcDecimals, _name, _name)
                )
            })
        );
    }
}
