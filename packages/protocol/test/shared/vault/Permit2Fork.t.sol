// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "forge-std/src/Test.sol";
import { IPermit2 } from "src/shared/vault/IPermit2.sol";

contract Permit2ForkToken is ERC20 {
    constructor() ERC20("Fork", "FORK") { }

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}

/// @notice Mirrors the Permit2 branch of `ERC20Vault._pullTokens` exactly, so the fork test
/// exercises the same interface and the same call shape the vault uses.
contract Permit2Puller {
    address public constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    function pull(address _token, uint256 _amount, bytes memory _permit2) external {
        (uint256 nonce, uint256 deadline, bytes memory signature) =
            abi.decode(_permit2, (uint256, uint256, bytes));

        IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({ token: _token, amount: _amount }),
            nonce: nonce,
            deadline: deadline
        });
        IPermit2.SignatureTransferDetails memory details =
            IPermit2.SignatureTransferDetails({ to: address(this), requestedAmount: _amount });

        IPermit2(PERMIT2).permitTransferFrom(permit, details, msg.sender, signature);
    }
}

/// @notice Validates `IPermit2` against the real deployed Permit2 rather than a mock.
/// @dev The unit tests pin the function selector, but `nonce` and `deadline` are both `uint256`,
/// so transposing them would leave the selector unchanged and a self-consistent mock would agree
/// with the mistake. Only the real contract, which derives the EIP-712 digest itself from the
/// struct we hand it, can reject a wrong field order. Skipped when no RPC is configured.
contract TestPermit2Fork is Test {
    address private constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    uint256 private constant AlicePK = 0xA11CE;

    bytes32 private constant TOKEN_PERMISSIONS_TYPEHASH =
        keccak256("TokenPermissions(address token,uint256 amount)");

    bytes32 private constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    function _fork() private returns (bool) {
        string memory rpc = vm.envOr("PERMIT2_FORK_RPC_URL", string(""));
        if (bytes(rpc).length == 0) return false;
        vm.createSelectFork(rpc);
        return PERMIT2.code.length != 0;
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

    function test_real_permit2_accepts_our_struct_layout() public {
        if (!_fork()) {
            emit log("skipped: set PERMIT2_FORK_RPC_URL to run against real Permit2");
            return;
        }

        address alice = vm.addr(AlicePK);
        Permit2ForkToken token = new Permit2ForkToken();
        token.mint(alice, 100 ether);

        vm.prank(alice);
        token.approve(PERMIT2, type(uint256).max);

        Permit2Puller puller = new Permit2Puller();

        uint256 amount = 5 ether;
        // Deliberately far apart: if `nonce` and `deadline` were transposed, the real Permit2
        // would read a deadline of 12345 (long past) or a nonce of a timestamp, and reject.
        uint256 nonce = 12_345;
        uint256 deadline = block.timestamp + 1 hours;

        bytes memory sig = _sign(address(token), amount, nonce, deadline, address(puller));

        vm.prank(alice);
        puller.pull(address(token), amount, abi.encode(nonce, deadline, sig));

        assertEq(token.balanceOf(address(puller)), amount);
        assertEq(token.balanceOf(alice), 100 ether - amount);
    }

    /// @dev The same signature must not be redeemable twice against the real contract.
    function test_real_permit2_rejects_a_replayed_nonce() public {
        if (!_fork()) return;

        address alice = vm.addr(AlicePK);
        Permit2ForkToken token = new Permit2ForkToken();
        token.mint(alice, 100 ether);

        vm.prank(alice);
        token.approve(PERMIT2, type(uint256).max);

        Permit2Puller puller = new Permit2Puller();

        uint256 amount = 1 ether;
        uint256 nonce = 999;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(address(token), amount, nonce, deadline, address(puller));
        bytes memory blob = abi.encode(nonce, deadline, sig);

        vm.prank(alice);
        puller.pull(address(token), amount, blob);

        vm.prank(alice);
        vm.expectRevert();
        puller.pull(address(token), amount, blob);
    }
}

interface IPermit2Domain {
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
