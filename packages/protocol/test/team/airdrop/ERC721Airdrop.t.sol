// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../TaikoTest.sol";

contract MockERC721Airdrop is ERC721Airdrop {
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
// contract we mock an ERC721Vault which mints tokens into a Vault (which holds the TKOP).
contract MockAddressManager {
    address mockERC721Vault;

    constructor(address _mockERC721Vault) {
        mockERC721Vault = _mockERC721Vault;
    }

    function getAddress(uint64, /*chainId*/ bytes32 /*name*/ ) public view returns (address) {
        return mockERC721Vault;
    }
}

// It does nothing but:
// - stores the tokens for the airdrop
// - owner can call setApprovalForAll() on token, and approving the AirdropERC721.sol contract so
// it acts on
// behalf
// - funds can later be withdrawn by the user
contract SimpleERC721Vault is EssentialContract {
    /// @notice Initializes the vault.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    function approveAirdropContract(address token, address approvedActor) public onlyOwner {
        BridgedERC721(token).setApprovalForAll(approvedActor, true);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    )
        external
        pure
        returns (bytes4)
    {
        return SimpleERC721Vault.onERC721Received.selector;
    }
}

contract TestERC721Airdrop is TaikoTest {
    address public owner = randAddress();

    uint256 public mintSupply = 5;

    bytes32 public constant merkleRoot = bytes32(uint256(1));
    bytes32[] public merkleProof;
    uint64 public claimStart;
    uint64 public claimEnd;

    BridgedERC721 token;
    MockERC721Airdrop airdrop;
    MockAddressManager addressManager;
    SimpleERC721Vault vault;

    function setUp() public {
        vm.startPrank(owner);

        // 1. We need to have a vault
        vault = SimpleERC721Vault(
            deployProxy({
                name: "vault",
                impl: address(new SimpleERC721Vault()),
                data: abi.encodeCall(SimpleERC721Vault.init, (address(0)))
            })
        );

        // 2. Need to add it to the AddressManager (below here i'm just mocking it) so that we can
        // mint TKOP. Basically this step only required in this test. Only thing we need to be sure
        // on testnet/mainnet. Vault (which Airdrop transfers from) HAVE tokens.
        addressManager = new MockAddressManager(address(vault));

        // 3. Deploy a bridged TKOP token (but on mainnet it will be just a bridged token from L1 to
        // L2) - not necessary step on mainnet.
        token = BridgedERC721(
            deployProxy({
                name: "tkop",
                impl: address(new BridgedERC721()),
                data: abi.encodeCall(
                    BridgedERC721.init,
                    (
                        address(0),
                        address(addressManager),
                        randAddress(),
                        100,
                        "TKOP",
                        "Taiko Points Token"
                    )
                    )
            })
        );

        vm.stopPrank();

        vm.startPrank(address(vault));
        // 5. Mint 5 NFTs token ids from 0 - 4 to the vault. This step on mainnet will be done by
        // Taiko Labs. For
        // testing on A6 the important thing is: HAVE tokens in this vault!
        for (uint256 i; i != mintSupply; ++i) {
            BridgedERC721(token).mint(address(vault), i);
        }

        vm.stopPrank();

        // 6. Deploy the airdrop contract, and set the claimStart, claimEnd and merkleRoot -> On
        // mainnet it will be separated into 2 tasks obviously, because first we deploy, then we set
        // those variables. On testnet (e.g. A6) it shall also be 2 steps easily. Deploy a contract,
        // then set merkle.
        claimStart = uint64(block.timestamp + 10);
        claimEnd = uint64(block.timestamp + 10_000);
        merkleProof = new bytes32[](3);

        vm.startPrank(owner);
        airdrop = MockERC721Airdrop(
            deployProxy({
                name: "MockERC721Airdrop",
                impl: address(new MockERC721Airdrop()),
                data: abi.encodeCall(
                    ERC721Airdrop.init,
                    (address(0), claimStart, claimEnd, merkleRoot, address(token), address(vault))
                    )
            })
        );

        vm.stopPrank();

        // 7. Approval (Vault approves Airdrop contract to be the spender!) Has to be done on
        // testnet and mainnet too, obviously.
        vm.prank(address(vault), owner);
        BridgedERC721(token).setApprovalForAll(address(airdrop), true);

        // Vault shall have the balance
        assertEq(BridgedERC721(token).balanceOf(address(vault)), mintSupply);

        vm.roll(block.number + 1);
    }

    function test_claim() public {
        vm.warp(claimStart);
        vm.prank(Alice, Alice);
        uint256[] memory tokenIds = new uint256[](5);
        // Airdrop all the minted tokens
        for (uint256 i; i != mintSupply; ++i) {
            tokenIds[i] = i;
        }

        airdrop.claim(Alice, tokenIds, merkleProof);

        // Check Alice balance
        assertEq(BridgedERC721(token).balanceOf(Alice), mintSupply);
    }
}
