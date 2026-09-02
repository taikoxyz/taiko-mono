// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "forge-std/src/Test.sol";
import { IBridge } from "src/shared/bridge/IBridge.sol";
import { IResolver } from "src/shared/common/IResolver.sol";
import { LibNames } from "src/shared/libs/LibNames.sol";
import { ERC20Vault } from "src/shared/vault/ERC20Vault.sol";

contract Permit2ForkToken is ERC20 {
    constructor() ERC20("Fork", "FORK") { }

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}

/// @notice The smallest scaffolding an `ERC20Vault` needs to reach its token pull: a bridge to
/// address the outbound message to, and a vault registered on the destination chain.
contract ForkResolver is IResolver {
    address public immutable bridge;
    address public immutable destVault;
    uint64 public immutable destChainId;

    constructor(address _bridge, address _destVault, uint64 _destChainId) {
        bridge = _bridge;
        destVault = _destVault;
        destChainId = _destChainId;
    }

    function resolve(
        uint256 _chainId,
        bytes32 _name,
        bool _allowZeroAddress
    )
        external
        view
        returns (address addr_)
    {
        if (_name == LibNames.B_BRIDGE) addr_ = bridge;
        else if (_name == LibNames.B_ERC20_VAULT && _chainId == destChainId) addr_ = destVault;

        require(addr_ != address(0) || _allowZeroAddress, RESOLVED_TO_ZERO_ADDRESS());
    }
}

/// @notice Accepts the vault's outbound message so the send completes; the pull is what is under
/// test here, not the messaging.
contract ForkBridgeStub {
    function sendMessage(IBridge.Message calldata _message)
        external
        payable
        returns (bytes32 msgHash_, IBridge.Message memory message_)
    {
        message_ = _message;
        msgHash_ = keccak256(abi.encode(_message));
    }
}

/// @notice Validates `ERC20Vault`'s Permit2 pull against the real deployed Permit2 rather than a
/// mock, by driving the vault's own `sendTokenWithPermit2`.
/// @dev The unit tests pin the function selector, but `nonce` and `deadline` are both `uint256`, so
/// transposing them would leave the selector unchanged and a self-consistent mock would agree with
/// the mistake. Only the real contract, which derives the EIP-712 digest itself from the struct it
/// is handed, can reject a wrong field order.
/// @dev Requires `PERMIT2_FORK_RPC_URL`; without it every test here reports as *skipped* rather
/// than passed, so an unconfigured run cannot be mistaken for a green one. With it set, a chain
/// that has no Permit2 fails loudly instead of skipping quietly -- that is a misconfigured RPC, not
/// an absent one.
contract TestPermit2Fork is Test {
    address private constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    uint256 private constant AlicePK = 0xA11CE;
    uint64 private constant DEST_CHAIN_ID = 167_000;

    bytes32 private constant TOKEN_PERMISSIONS_TYPEHASH =
        keccak256("TokenPermissions(address token,uint256 amount)");

    bytes32 private constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    /// @dev Selects the fork, or skips the calling test when no RPC is configured. Returns the
    /// deployed vault so each test drives the real contract rather than a copy of its pull.
    function _forkAndDeployVault() private returns (ERC20Vault vault_) {
        string memory rpc = vm.envOr("PERMIT2_FORK_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            emit log("skipped: set PERMIT2_FORK_RPC_URL to run against real Permit2");
            vm.skip(true);
            return ERC20Vault(address(0));
        }

        vm.createSelectFork(rpc);
        require(
            PERMIT2.code.length != 0,
            "PERMIT2_FORK_RPC_URL points at a chain with no Permit2 deployed"
        );

        address resolver = address(
            new ForkResolver(address(new ForkBridgeStub()), address(0xDE57), DEST_CHAIN_ID)
        );
        vault_ = ERC20Vault(
            address(
                new ERC1967Proxy(
                    address(new ERC20Vault(resolver, address(0))),
                    abi.encodeCall(ERC20Vault.init, (address(this)))
                )
            )
        );
    }

    function _op(
        address _token,
        uint256 _amount
    )
        private
        pure
        returns (ERC20Vault.BridgeTransferOp memory)
    {
        return ERC20Vault.BridgeTransferOp({
            destChainId: DEST_CHAIN_ID,
            destOwner: address(0),
            to: address(0xB0B),
            fee: 0,
            token: _token,
            gasLimit: 1_000_000,
            amount: _amount
        });
    }

    /// @dev Signs the canonical Permit2 digest, reading the domain separator from the deployed
    /// contract so the test cannot drift from the real signing domain.
    function _sign(
        address _token,
        uint256 _amount,
        uint256 _nonce,
        uint256 _deadline,
        address _spender
    )
        private
        view
        returns (bytes memory)
    {
        bytes32 domainSeparator = IPermit2Domain(PERMIT2).DOMAIN_SEPARATOR();
        bytes32 permissions = keccak256(abi.encode(TOKEN_PERMISSIONS_TYPEHASH, _token, _amount));
        bytes32 structHash = keccak256(
            abi.encode(PERMIT_TRANSFER_FROM_TYPEHASH, permissions, _spender, _nonce, _deadline)
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AlicePK, digest);
        return abi.encodePacked(r, s, v);
    }

    function test_real_permit2_accepts_the_vaults_call() public {
        ERC20Vault vault = _forkAndDeployVault();

        address alice = vm.addr(AlicePK);
        Permit2ForkToken token = new Permit2ForkToken();
        token.mint(alice, 100 ether);

        vm.prank(alice);
        token.approve(PERMIT2, type(uint256).max);

        uint256 amount = 5 ether;
        // Deliberately far apart: if `nonce` and `deadline` were transposed, the real Permit2
        // would read a deadline of 12345 (long past) or a nonce of a timestamp, and reject.
        uint256 nonce = 12_345;
        uint256 deadline = block.timestamp + 1 hours;

        bytes memory sig = _sign(address(token), amount, nonce, deadline, address(vault));

        vm.prank(alice);
        vault.sendTokenWithPermit2(_op(address(token), amount), nonce, deadline, sig);

        assertEq(token.balanceOf(address(vault)), amount);
        assertEq(token.balanceOf(alice), 100 ether - amount);
    }

    /// @dev The same signature must not be redeemable twice against the real contract.
    function test_real_permit2_rejects_a_replayed_nonce() public {
        ERC20Vault vault = _forkAndDeployVault();

        address alice = vm.addr(AlicePK);
        Permit2ForkToken token = new Permit2ForkToken();
        token.mint(alice, 100 ether);

        vm.prank(alice);
        token.approve(PERMIT2, type(uint256).max);

        uint256 amount = 1 ether;
        uint256 nonce = 999;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(address(token), amount, nonce, deadline, address(vault));

        vm.prank(alice);
        vault.sendTokenWithPermit2(_op(address(token), amount), nonce, deadline, sig);

        vm.prank(alice);
        vm.expectRevert();
        vault.sendTokenWithPermit2(_op(address(token), amount), nonce, deadline, sig);

        // Exactly one pull went through.
        assertEq(token.balanceOf(address(vault)), amount);
    }

    /// @dev Transposing `nonce` and `deadline` leaves the selector untouched, so only the real
    /// contract can catch it: it reads the nonce as a deadline and rejects the signature as
    /// expired. A mock built on the same struct would agree with the mistake instead.
    function test_real_permit2_rejects_a_transposed_nonce_and_deadline() public {
        ERC20Vault vault = _forkAndDeployVault();

        address alice = vm.addr(AlicePK);
        Permit2ForkToken token = new Permit2ForkToken();
        token.mint(alice, 100 ether);

        vm.prank(alice);
        token.approve(PERMIT2, type(uint256).max);

        uint256 amount = 1 ether;
        uint256 nonce = 999;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(address(token), amount, nonce, deadline, address(vault));

        // Arguments swapped at the entrypoint: `999` now lands where the deadline belongs.
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSignature("SignatureExpired(uint256)", nonce));
        vault.sendTokenWithPermit2(_op(address(token), amount), deadline, nonce, sig);

        assertEq(token.balanceOf(address(vault)), 0);
    }
}

interface IPermit2Domain {
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
