// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../TaikoTest.sol";

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

    TaikoToken token;
    ERC20Airdrop airdrop;

    function setUp() public {
        claimStart = uint64(block.timestamp + 10);
        claimEnd = uint64(block.timestamp + 10_000);
        merkleProof = new bytes32[](3);

        token =    TaikoToken(  deployProxy({
            name: "taiko_token",
            impl: address(new TaikoToken()),
            data: abi.encodeCall(TaikoToken.init, ("Taiko Token", "TKO", owner)) }));


        airdrop = ERC20Airdrop(
            deployProxy({
                name: "MockERC20Airdrop",
                impl: address(new MockERC20Airdrop()),
                data: abi.encodeCall(
                    ERC20Airdrop.init, (claimStart, claimEnd, merkleRoot, address(token), owner)
                    )
            })
        );

        vm.roll(block.number + 1);
    }

    function test_claimAndDelegate_with_wrong_delegation_data() public {
        vm.warp(claimStart);

        bytes memory delegation = bytes("");

        vm.expectRevert("ERC20: insufficient allowance"); // no allowance
        vm.prank(Lily, Lily);
        airdrop.claimAndDelegate(Lily, 100, merkleProof, delegation);

        vm.prank(owner, owner);
        token.approve(address(airdrop), 1_000_000_000e18);

        vm.expectRevert(); // cannot decode the delegation data
        vm.prank(Lily, Lily);
        airdrop.claimAndDelegate(Lily, 100, merkleProof, delegation);

        address delegatee = randAddress();
        uint256 nonce = 1;
        uint256 expiry = block.timestamp + 10_000;
        uint8 v;
        bytes32 r;
        bytes32 s;

        delegation = abi.encode(delegatee, nonce, expiry, v, r, s);

        vm.expectRevert(); // signature invalid
        vm.prank(Lily, Lily);
        airdrop.claimAndDelegate(Lily, 100, merkleProof, delegation);

        // TODO(daniel): add a new test by initializing the right value for the above 6 variables.
    }
}
