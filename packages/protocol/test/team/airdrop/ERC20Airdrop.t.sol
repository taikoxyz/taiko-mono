// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../TaikoTest.sol";
import "./LibDelegationSigUtil.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

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
// - owner can call approve() on token, and approving the AirdropERC20.sol contract so it acts on
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

contract TestERC20Airdrop is TaikoTest {
    address public owner = randAddress();

    // Private Key: 0x1dc880d28041a41132437eae90c9e09c3b9e13438c2d0f6207804ceece623395
    address public Lily = 0x3447b15c1b0a27D339C812b98881eC64051068b3;

    bytes32 public constant merkleRoot = bytes32(uint256(1));
    bytes32[] public merkleProof;
    uint64 public claimStart;
    uint64 public claimEnd;

    BridgedERC20 token;
    MockERC20Airdrop airdrop;
    MockAddressManager addressManager;
    SimpleERC20Vault vault;

    function setUp() public {
        vm.startPrank(owner);

        // 1. We need to have a vault
        vault = SimpleERC20Vault(
            deployProxy({
                name: "vault",
                impl: address(new SimpleERC20Vault()),
                data: abi.encodeCall(SimpleERC20Vault.init, ())
            })
        );

        // 2. Need to add it to the AddressManager (below here i'm just mocking it) so that we can
        // mint TKO. Basically this step only required in this test. Only thing we need to be sure
        // on testnet/mainnet. Vault (which Airdrop transfers from) HAVE tokens.
        addressManager = new MockAddressManager(address(vault));

        // 3. Deploy a bridged TKO token (but on mainnet it will be just a bridged token from L1 to
        // L2) - not necessary step on mainnet.
        token = BridgedERC20(
            deployProxy({
                name: "tko",
                impl: address(new BridgedERC20()),
                data: abi.encodeCall(
                    BridgedERC20.init,
                    (address(0), address(addressManager), randAddress(), 100, 18, "TKO", "Taiko Token")
                    )
            })
        );

        vm.stopPrank();

        // 5. Mint (AKA transfer) to the vault. This step on mainnet will be done by Taiko Labs. For
        // testing on A6 the imporatnt thing is: HAVE tokens in this vault!
        vm.prank(address(vault), owner);
        BridgedERC20(token).mint(address(vault), 1_000_000_000e18);

        // 6. Deploy the airdrop contract, and set the claimStart, claimEnd and merkleRoot -> On
        // mainnet it will be separated into 2 tasks obviously, because first we deploy, then we set
        // those variables. On testnet (e.g. A6) it shall also be 2 steps easily. Deploy a contract,
        // then set merkle.
        claimStart = uint64(block.timestamp + 10);
        claimEnd = uint64(block.timestamp + 10_000);
        merkleProof = new bytes32[](3);

        vm.startPrank(owner);
        airdrop = MockERC20Airdrop(
            deployProxy({
                name: "MockERC20Airdrop",
                impl: address(new MockERC20Airdrop()),
                data: abi.encodeCall(
                    ERC20Airdrop.init,
                    (address(0), claimStart, claimEnd, merkleRoot, address(token), address(vault))
                    )
            })
        );

        vm.stopPrank();

        // 7. Approval (Vault approves Airdrop contract to be the spender!) Has to be done on
        // testnet and mainnet too, obviously.
        vm.prank(address(vault), owner);
        BridgedERC20(token).approve(address(airdrop), 1_000_000_000e18);

        // Vault shall have the balance
        assertEq(BridgedERC20(token).balanceOf(address(vault)), 1_000_000_000e18);

        vm.roll(block.number + 1);
    }

    function getAliceDelegatesToBobSignature()
        public
        view
        returns (address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s)
    {
        // Query user's nonce
        nonce = BridgedERC20(token).nonces(Bob);
        expiry = block.timestamp + 1_000_000;
        delegatee = Bob;

        LibDelegationSigUtil.Delegate memory delegate;
        delegate.delegatee = delegatee;
        delegate.nonce = nonce;
        delegate.expiry = expiry;
        bytes32 hash = LibDelegationSigUtil.getTypedDataHash(delegate, address(token));

        // 0x2 is Alice's private key
        (v, r, s) = vm.sign(0x1, hash);
    }

    function test_claimAndDelegate() public {
        vm.warp(claimStart);

        // 1. Alice puts together the HASH (for delegating BOB) and signs it too.
        (address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) =
            getAliceDelegatesToBobSignature();
        // 2. Encode data
        bytes memory delegationData = abi.encode(delegatee, nonce, expiry, v, r, s);
        vm.prank(Alice, Alice);
        airdrop.claimAndDelegate(Alice, 100, merkleProof, delegationData);

        // Check Alice balance
        assertEq(token.balanceOf(Alice), 100);
        // Check who is delegatee, shall be Bob
        assertEq(token.delegates(Alice), Bob);
    }

    function test_claimAndDelegate_with_wrong_delegation_data() public {
        vm.warp(claimStart);

        bytes memory delegation = bytes("");

        vm.expectRevert(); //invalid delegate signature
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
    }
}
