// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../../Layer1Test.sol";

contract ERC20AirdropNoVerify is ERC20Airdrop {
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

// Simple mock - so that we do not need to deploy AddressManager (for these tests). With this
// contract we mock an ERC20Vault which mints tokens into a Vault (which holds the TKO).
contract MockAddressManager {
    address mockERC20Vault;

    constructor(address _mockERC20Vault) {
        mockERC20Vault = _mockERC20Vault;
    }

    function getAddress(uint64, /*chainId*/ bytes32 /*name*/ ) public view returns (address) {
        return mockERC20Vault;
    }
}

// It does nothing but:
// - stores the tokens for the airdrop
// - deployer can call approve() on token, and approving the AirdropERC20.sol contract so it acts on
// behalf
// - funds can later be withdrawn by the user
contract SimpleERC20Vault is OwnableUpgradeable {
    /// @notice Initializes the vault.
    function init() external initializer {
        __Ownable_init();
    }

    function approveAirdropContract(
        address token,
        address approvedActor,
        uint256 amount
    )
        public
        onlyOwner
    {
        BridgedERC20(token).approve(approvedActor, amount);
    }

    function withdrawFunds(address token, address to) public onlyOwner {
        BridgedERC20(token).transfer(to, BridgedERC20(token).balanceOf(address(this)));
    }
}

contract TestERC20Airdrop is Layer1Test {
    uint64 private claimStart;

    BridgedERC20 private token;
    SimpleERC20Vault private vault;
    ERC20Airdrop private airdrop;

    function setUpOnEthereum() internal override {
        vault = SimpleERC20Vault(
            deploy({
                name: "erc20_vault",
                impl: address(new SimpleERC20Vault()),
                data: abi.encodeCall(SimpleERC20Vault.init, ())
            })
        );

        token = BridgedERC20(
            deploy({
                name: "some_token",
                impl: address(new BridgedERC20()),
                data: abi.encodeCall(
                    BridgedERC20.init,
                    (address(0), address(resolver), randAddress(), 100, 18, "SOME", "Some Token")
                )
            })
        );

        claimStart = uint64(block.timestamp + 10);

        airdrop = ERC20Airdrop(
            deploy({
                name: "airdrop",
                impl: address(new ERC20AirdropNoVerify()),
                data: abi.encodeCall(
                    ERC20Airdrop.init,
                    (
                        address(0),
                        claimStart,
                        claimStart + 10_000,
                        bytes32(uint256(1)),
                        address(token),
                        address(vault)
                    )
                )
            })
        );
    }

    function test_erc20_airdrop_claim() public {
        vm.startPrank(address(vault), deployer);
        BridgedERC20(token).mint(address(vault), 1_000_000_000e18);
        BridgedERC20(token).approve(address(airdrop), 1_000_000_000e18);
        vm.stopPrank();

        // Vault shall have the balance
        assertEq(BridgedERC20(token).balanceOf(address(vault)), 1_000_000_000e18);

        vm.roll(block.number + 1);
        vm.warp(claimStart);

        vm.prank(Alice);
        airdrop.claim(Alice, 100, new bytes32[](3));

        // Check Alice balance
        assertEq(token.balanceOf(Alice), 100);
    }
}
