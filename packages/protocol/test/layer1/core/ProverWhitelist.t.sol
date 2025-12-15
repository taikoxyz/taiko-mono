// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ProverWhitelist } from "src/layer1/core/impl/ProverWhitelist.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

contract ProverWhitelistTest is CommonTest {
    ProverWhitelist internal proverWhitelist;

    address internal prover1 = address(0x1001);
    address internal prover2 = address(0x1002);
    address internal prover3 = address(0x1003);

    event ProverWhitelisted(address indexed prover, bool enabled);

    function setUp() public virtual override {
        super.setUp();

        ProverWhitelist impl = new ProverWhitelist();
        proverWhitelist = ProverWhitelist(
            address(
                new ERC1967Proxy(
                    address(impl), abi.encodeCall(ProverWhitelist.init, (address(this)))
                )
            )
        );
    }

    // ---------------------------------------------------------------
    // init tests
    // ---------------------------------------------------------------

    function test_init_setsOwner() public view {
        assertEq(proverWhitelist.owner(), address(this));
    }

    function test_init_startsWithZeroProverCount() public view {
        assertEq(proverWhitelist.proverCount(), 0);
    }

    // ---------------------------------------------------------------
    // whitelistProver tests
    // ---------------------------------------------------------------

    function test_whitelistProver_enablesProver() public {
        vm.expectEmit(true, false, false, true);
        emit ProverWhitelisted(prover1, true);

        proverWhitelist.whitelistProver(prover1, true);

        (bool isWhitelisted, uint256 count) = proverWhitelist.isProverWhitelisted(prover1);
        assertTrue(isWhitelisted);
        assertEq(count, 1);
        assertEq(proverWhitelist.proverCount(), 1);
    }

    function test_whitelistProver_disablesProver() public {
        proverWhitelist.whitelistProver(prover1, true);

        vm.expectEmit(true, false, false, true);
        emit ProverWhitelisted(prover1, false);

        proverWhitelist.whitelistProver(prover1, false);

        (bool isWhitelisted, uint256 count) = proverWhitelist.isProverWhitelisted(prover1);
        assertFalse(isWhitelisted);
        assertEq(count, 0);
        assertEq(proverWhitelist.proverCount(), 0);
    }

    function test_whitelistProver_multipleProvers() public {
        proverWhitelist.whitelistProver(prover1, true);
        proverWhitelist.whitelistProver(prover2, true);
        proverWhitelist.whitelistProver(prover3, true);

        assertEq(proverWhitelist.proverCount(), 3);

        (bool isWhitelisted1,) = proverWhitelist.isProverWhitelisted(prover1);
        (bool isWhitelisted2,) = proverWhitelist.isProverWhitelisted(prover2);
        (bool isWhitelisted3,) = proverWhitelist.isProverWhitelisted(prover3);

        assertTrue(isWhitelisted1);
        assertTrue(isWhitelisted2);
        assertTrue(isWhitelisted3);

        // Disable one
        proverWhitelist.whitelistProver(prover2, false);
        assertEq(proverWhitelist.proverCount(), 2);

        (isWhitelisted2,) = proverWhitelist.isProverWhitelisted(prover2);
        assertFalse(isWhitelisted2);
    }

    function test_whitelistProver_RevertWhen_CallerNotOwner() public {
        vm.prank(prover1);
        vm.expectRevert();
        proverWhitelist.whitelistProver(prover1, true);
    }

    function test_whitelistProver_RevertWhen_AlreadyEnabled() public {
        proverWhitelist.whitelistProver(prover1, true);

        vm.expectRevert(ProverWhitelist.ProverWhitelistedAlready.selector);
        proverWhitelist.whitelistProver(prover1, true);
    }

    function test_whitelistProver_RevertWhen_AlreadyDisabled() public {
        vm.expectRevert(ProverWhitelist.ProverWhitelistedAlready.selector);
        proverWhitelist.whitelistProver(prover1, false);
    }

    // ---------------------------------------------------------------
    // isProverWhitelisted tests
    // ---------------------------------------------------------------

    function test_isProverWhitelisted_returnsFalseWhenNotWhitelisted() public {
        proverWhitelist.whitelistProver(prover1, true);

        (bool isWhitelisted, uint256 count) = proverWhitelist.isProverWhitelisted(prover2);
        assertFalse(isWhitelisted);
        assertEq(count, 1);
    }

    function test_isProverWhitelisted_returnsFalseWhenCountIsZero() public view {
        (bool isWhitelisted, uint256 count) = proverWhitelist.isProverWhitelisted(prover1);
        assertFalse(isWhitelisted);
        assertEq(count, 0);
    }

    function test_isProverWhitelisted_returnsCorrectCount() public {
        proverWhitelist.whitelistProver(prover1, true);
        proverWhitelist.whitelistProver(prover2, true);

        (, uint256 count1) = proverWhitelist.isProverWhitelisted(prover1);
        (, uint256 count2) = proverWhitelist.isProverWhitelisted(prover2);
        (, uint256 count3) = proverWhitelist.isProverWhitelisted(prover3);

        assertEq(count1, 2);
        assertEq(count2, 2);
        assertEq(count3, 2);
    }
}
