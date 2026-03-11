// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/src/Test.sol";

import { ICircleFiatToken } from "src/shared/thirdparty/ICircleFiatToken.sol";
import { CircleArtifactTestBase } from "test/shared/helpers/CircleArtifactTestBase.sol";

contract TestCircleFiatToken is Test, CircleArtifactTestBase {
    function test_deploy_fiat_token_initializes_metadata_and_roles() public {
        (address impl, address proxy) = _deployTestUSDC();
        ICircleFiatToken token = ICircleFiatToken(proxy);

        assertEq(_proxyImplementation(proxy), impl);
        assertEq(_proxyAdmin(proxy), PROXY_ADMIN);
        assertEq(token.name(), "USD Coin");
        assertEq(token.symbol(), "USDC");
        assertEq(token.decimals(), 6);
        assertEq(token.masterMinter(), MASTER_MINTER);
        assertEq(token.owner(), TOKEN_OWNER);
        assertEq(token.pauser(), PAUSER);
        assertEq(token.blacklister(), BLACKLISTER);
    }

    function test_mint_decreases_configured_minter_allowance() public {
        (, address proxy) = _deployTestUSDC();
        ICircleFiatToken token = ICircleFiatToken(proxy);
        uint256 amount = 25_000_000;

        vm.prank(MASTER_MINTER);
        token.configureMinter(address(this), type(uint256).max);

        uint256 allowanceBefore = token.minterAllowance(address(this));
        token.mint(address(0xBEEF), amount);

        assertEq(token.balanceOf(address(0xBEEF)), amount);
        assertEq(token.totalSupply(), amount);
        assertEq(token.minterAllowance(address(this)), allowanceBefore - amount);
    }
}
