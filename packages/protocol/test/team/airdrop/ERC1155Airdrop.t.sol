// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../TaikoTest.sol";
import "./LibDelegationSigUtil.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MockERC1155Airdrop is ERC1155Airdrop {
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
// contract we mock an ERC1155Vault which mints tokens into a Vault (which holds the TKOP).
contract MockAddressManager {
    address mockERC1155Vault;

    constructor(address _mockERC1155Vault) {
        mockERC1155Vault = _mockERC1155Vault;
    }

    function getAddress(uint64, /*chainId*/ bytes32 /*name*/ ) public view returns (address) {
        return mockERC1155Vault;
    }
}

// It does nothing but:
// - stores the tokens for the airdrop
// - owner can call setApprovalForAll() on token, and approving the AirdropERC1155.sol contract so
// it acts on
// behalf
// - funds can later be withdrawn by the user
contract SimpleERC1155Vault is OwnableUpgradeable {
    /// @notice Initializes the vault.
    function init() external initializer {
        __Ownable_init();
    }

    function approveAirdropContract(address token, address approvedActor) public onlyOwner {
        BridgedERC1155(token).setApprovalForAll(approvedActor, true);
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    )
        external
        pure
        returns (bytes4)
    {
        return SimpleERC1155Vault.onERC1155Received.selector;
    }
}

contract TestERC1155Airdrop is TaikoTest {
    address public owner = randAddress();

    uint256 public tokenId = 1;
    uint256 public mintSupply = 1_000_000;
    uint256 public claimableQuantity = 1;

    bytes32 public constant merkleRoot = bytes32(uint256(1));
    bytes32[] public merkleProof;
    uint64 public claimStart;
    uint64 public claimEnd;

    BridgedERC1155 token;
    MockERC1155Airdrop airdrop;
    MockAddressManager addressManager;
    SimpleERC1155Vault vault;

    function setUp() public {
        vm.startPrank(owner);

        // 1. We need to have a vault
        vault = SimpleERC1155Vault(
            deployProxy({
                name: "vault",
                impl: address(new SimpleERC1155Vault()),
                data: abi.encodeCall(SimpleERC1155Vault.init, ())
            })
        );

        // 2. Need to add it to the AddressManager (below here i'm just mocking it) so that we can
        // mint TKOP. Basically this step only required in this test. Only thing we need to be sure
        // on testnet/mainnet. Vault (which Airdrop transfers from) HAVE tokens.
        addressManager = new MockAddressManager(address(vault));

        // 3. Deploy a bridged TKOP token (but on mainnet it will be just a bridged token from L1 to
        // L2) - not necessary step on mainnet.
        token = BridgedERC1155(
            deployProxy({
                name: "tkop",
                impl: address(new BridgedERC1155()),
                data: abi.encodeCall(
                    BridgedERC1155.init,
                    (address(addressManager), randAddress(), 100, "TKOP", "Taiko Points Token")
                    )
            })
        );

        vm.stopPrank();

        // 5. Mint (AKA transfer) to the vault. This step on mainnet will be done by Taiko Labs. For
        // testing on A6 the imporatnt thing is: HAVE tokens in this vault!
        vm.prank(address(vault), owner);
        BridgedERC1155(token).mint(address(vault), tokenId, mintSupply);

        // 6. Deploy the airdrop contract, and set the claimStart, claimEnd and merkleRoot -> On
        // mainnet it will be separated into 2 tasks obviously, because first we deploy, then we set
        // those variables. On testnet (e.g. A6) it shall also be 2 steps easily. Deploy a contract,
        // then set merkle.
        claimStart = uint64(block.timestamp + 10);
        claimEnd = uint64(block.timestamp + 10_000);
        merkleProof = new bytes32[](3);

        vm.startPrank(owner);
        airdrop = MockERC1155Airdrop(
            deployProxy({
                name: "MockERC1155Airdrop",
                impl: address(new MockERC1155Airdrop()),
                data: abi.encodeCall(
                    ERC1155Airdrop.init,
                    (
                        claimStart,
                        claimEnd,
                        merkleRoot,
                        address(token),
                        address(vault),
                        claimableQuantity
                    )
                    )
            })
        );

        vm.stopPrank();

        // 7. Approval (Vault approves Airdrop contract to be the spender!) Has to be done on
        // testnet and mainnet too, obviously.
        vm.prank(address(vault), owner);
        BridgedERC1155(token).setApprovalForAll(address(airdrop), true);

        // Vault shall have the balance
        assertEq(BridgedERC1155(token).balanceOf(address(vault), tokenId), mintSupply);

        vm.roll(block.number + 1);
    }

    function test_claim() public {
        vm.warp(claimStart);
        vm.prank(Alice, Alice);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        airdrop.claim(Alice, tokenIds, merkleProof, "");

        // Check Alice balance
        assertEq(BridgedERC1155(token).balanceOf(Alice, tokenId), claimableQuantity);
    }
}
