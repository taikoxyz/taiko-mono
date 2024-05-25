// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../TaikoTest.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";

contract MockERC20Airdrop is ERC20Airdrop {
    function _verifyMerkleProof(
        bytes32[] calldata, /*proof*/
        bytes32, /*merkleRoot*/
        bytes32 /*value*/
    )
        internal
        pure
        override
        returns (bool)
    {
        return true;
    }
}

contract TestERC20Airdrop is TaikoTest {
    address public owner = randAddress();

    // Private Key: 0x1dc880d28041a41132437eae90c9e09c3b9e13438c2d0f6207804ceece623395
    address public Lily = 0x3447b15c1b0a27D339C812b98881eC64051068b3;

    bytes32 public constant merkleRoot = bytes32(uint256(1));
    bytes32[] public merkleProof;
    uint64 public claimStart;
    uint64 public claimEnd;

    MockERC20 token;
    MockERC20Airdrop airdrop;

    function setUp() public {
        vm.startPrank(owner);

        // 1. Deploy a mock ERC20 TKO token (but on mainnet it will be just a bridged token from L1
        // to
        // L2) - not necessary step on mainnet.
        token = new MockERC20();

        // 6. Deploy the airdrop contract, and set the claimStart, claimEnd and merkleRoot -> On
        // mainnet it will be separated into 2 tasks obviously, because first we deploy, then we set
        // those variables. On testnet (e.g. A6) it shall also be 2 steps easily. Deploy a contract,
        // then set merkle.
        claimStart = uint64(block.timestamp + 10);
        claimEnd = uint64(block.timestamp + 10_000);
        merkleProof = new bytes32[](3);

        airdrop = MockERC20Airdrop(
            deployProxy({
                name: "MockERC20Airdrop",
                impl: address(new MockERC20Airdrop()),
                data: abi.encodeCall(
                    ERC20Airdrop.init, (address(0), claimStart, claimEnd, merkleRoot, IERC20(token))
                )
            })
        );

        // 5. Mint (AKA transfer) to the airdrop contract. This step on mainnet will be done by
        // Taiko Labs. For
        // testing, the important thing is: HAVE tokens in this vault!
        MockERC20(token).mint(address(airdrop), 50_000_000_000e18);

        // Airdrop contract shall have the balance
        assertEq(IERC20(token).balanceOf(address(airdrop)), 50_000_000_000e18);

        vm.stopPrank();
        vm.roll(block.number + 1);
    }

    function test_claim() public {
        vm.warp(claimStart);

        vm.startPrank(Alice);
        airdrop.claim(Alice, 100, merkleProof);

        // Check Alice balance
        assertEq(token.balanceOf(Alice), 100);

        vm.stopPrank();
    }

    function test_withdraw_funds() public {
        vm.startPrank(owner);

        // Get remaining balance
        uint256 balance = token.balanceOf(address(airdrop));
        airdrop.withdrawERC20(token);

        // Check owner balance
        assertEq(token.balanceOf(owner), balance);
        vm.stopPrank();
    }
}
