// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ProverChecker } from "src/layer1/core/impl/ProverChecker.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

contract ProverCheckerTest is CommonTest {
    ProverChecker internal proverChecker;

    address internal prover1 = address(0x1001);
    address internal prover2 = address(0x1002);
    address internal prover3 = address(0x1003);

    event ProverUpdated(address indexed prover, bool enabled);

    function setUp() public virtual override {
        super.setUp();

        ProverChecker impl = new ProverChecker();
        proverChecker = ProverChecker(
            address(
                new ERC1967Proxy(address(impl), abi.encodeCall(ProverChecker.init, (address(this))))
            )
        );
    }

    // ---------------------------------------------------------------
    // init tests
    // ---------------------------------------------------------------

    function test_init_setsOwner() public view {
        assertEq(proverChecker.owner(), address(this));
    }

    function test_init_startsWithZeroProverCount() public view {
        assertEq(proverChecker.proverCount(), 0);
    }

    // ---------------------------------------------------------------
    // setProver tests
    // ---------------------------------------------------------------

    function test_setProver_enablesProver() public {
        vm.expectEmit(true, false, false, true);
        emit ProverUpdated(prover1, true);

        proverChecker.setProver(prover1, true);

        (bool isWhitelisted, uint256 count) = proverChecker.isProverWhitelisted(prover1);
        assertTrue(isWhitelisted);
        assertEq(count, 1);
        assertEq(proverChecker.proverCount(), 1);
    }

    function test_setProver_disablesProver() public {
        proverChecker.setProver(prover1, true);

        vm.expectEmit(true, false, false, true);
        emit ProverUpdated(prover1, false);

        proverChecker.setProver(prover1, false);

        (bool isWhitelisted, uint256 count) = proverChecker.isProverWhitelisted(prover1);
        assertFalse(isWhitelisted);
        assertEq(count, 0);
        assertEq(proverChecker.proverCount(), 0);
    }

    function test_setProver_multipleProvers() public {
        proverChecker.setProver(prover1, true);
        proverChecker.setProver(prover2, true);
        proverChecker.setProver(prover3, true);

        assertEq(proverChecker.proverCount(), 3);

        (bool isWhitelisted1,) = proverChecker.isProverWhitelisted(prover1);
        (bool isWhitelisted2,) = proverChecker.isProverWhitelisted(prover2);
        (bool isWhitelisted3,) = proverChecker.isProverWhitelisted(prover3);

        assertTrue(isWhitelisted1);
        assertTrue(isWhitelisted2);
        assertTrue(isWhitelisted3);

        // Disable one
        proverChecker.setProver(prover2, false);
        assertEq(proverChecker.proverCount(), 2);

        (isWhitelisted2,) = proverChecker.isProverWhitelisted(prover2);
        assertFalse(isWhitelisted2);
    }

    function test_setProver_RevertWhen_CallerNotOwner() public {
        vm.prank(prover1);
        vm.expectRevert();
        proverChecker.setProver(prover1, true);
    }

    function test_setProver_RevertWhen_AlreadyEnabled() public {
        proverChecker.setProver(prover1, true);

        vm.expectRevert(ProverChecker.ProverAlreadySet.selector);
        proverChecker.setProver(prover1, true);
    }

    function test_setProver_RevertWhen_AlreadyDisabled() public {
        vm.expectRevert(ProverChecker.ProverAlreadySet.selector);
        proverChecker.setProver(prover1, false);
    }

    // ---------------------------------------------------------------
    // isProverWhitelisted tests
    // ---------------------------------------------------------------

    function test_isProverWhitelisted_returnsFalseWhenNotWhitelisted() public {
        proverChecker.setProver(prover1, true);

        (bool isWhitelisted, uint256 count) = proverChecker.isProverWhitelisted(prover2);
        assertFalse(isWhitelisted);
        assertEq(count, 1);
    }

    function test_isProverWhitelisted_returnsFalseWhenCountIsZero() public view {
        (bool isWhitelisted, uint256 count) = proverChecker.isProverWhitelisted(prover1);
        assertFalse(isWhitelisted);
        assertEq(count, 0);
    }

    function test_isProverWhitelisted_returnsCorrectCount() public {
        proverChecker.setProver(prover1, true);
        proverChecker.setProver(prover2, true);

        (, uint256 count1) = proverChecker.isProverWhitelisted(prover1);
        (, uint256 count2) = proverChecker.isProverWhitelisted(prover2);
        (, uint256 count3) = proverChecker.isProverWhitelisted(prover3);

        assertEq(count1, 2);
        assertEq(count2, 2);
        assertEq(count3, 2);
    }
}
