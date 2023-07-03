// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AddressManager} from "../contracts/common/AddressManager.sol";
import {AddressResolver} from "../contracts/common/AddressResolver.sol";
import {Bridge} from "../contracts/bridge/Bridge.sol";
import {BridgedERC20} from "../contracts/bridge/BridgedERC20.sol";
import {BridgeErrors} from "../contracts/bridge/BridgeErrors.sol";
import {FreeMintERC20} from "../contracts/test/erc20/FreeMintERC20.sol";
import {SignalService} from "../contracts/signal/SignalService.sol";
import {Test} from "forge-std/Test.sol";
import {TokenVault} from "../contracts/bridge/TokenVault.sol";

// PrankDestBridge lets us simulate a transaction to the TokenVault
// from a named Bridge, without having to test/run through the real Bridge code,
// outside the scope of the unit tests in the TokenVault.
contract PrankDestBridge {
    TokenVault destTokenVault;
    Context ctx;

    struct Context {
        bytes32 msgHash; // messageHash
        address sender;
        uint256 srcChainId;
    }

    constructor(TokenVault _tokenVault) {
        destTokenVault = _tokenVault;
    }

    function setTokenVault(address addr) public {
        destTokenVault = TokenVault(addr);
    }

    function context() public view returns (Context memory) {
        return ctx;
    }

    function sendReceiveERC20ToTokenVault(
        TokenVault.CanonicalERC20 calldata canonicalToken,
        address from,
        address to,
        uint256 amount,
        bytes32 msgHash,
        address srcChainTokenVault,
        uint256 srcChainId
    ) public {
        ctx.sender = srcChainTokenVault;
        ctx.msgHash = msgHash;
        ctx.srcChainId = srcChainId;

        destTokenVault.receiveERC20(canonicalToken, from, to, amount);

        ctx.sender = address(0);
        ctx.msgHash = bytes32(0);
        ctx.srcChainId = 0;
    }
}

contract TestTokenVault is Test {
    AddressManager addressManager;
    Bridge bridge;
    TokenVault tokenVault;
    TokenVault destChainIdTokenVault;
    PrankDestBridge destChainIdBridge;
    FreeMintERC20 erc20;
    SignalService signalService;
    uint256 destChainId = 7;

    address public constant Alice = 0x10020FCb72e27650651B05eD2CEcA493bC807Ba4;
    address public constant Bob = 0x200708D76eB1B69761c23821809d53F65049939e;

    function setUp() public {
        vm.startPrank(Alice);
        vm.deal(Alice, 1 ether);
        vm.deal(Bob, 1 ether);

        addressManager = new AddressManager();
        addressManager.init();

        tokenVault = new TokenVault();
        tokenVault.init(address(addressManager));
        destChainIdTokenVault = new TokenVault();
        destChainIdTokenVault.init(address(addressManager));

        erc20 = new FreeMintERC20("ERC20", "ERC20");
        erc20.mint(Alice);

        bridge = new Bridge();
        bridge.init(address(addressManager));

        destChainIdBridge = new PrankDestBridge(tokenVault);

        signalService = new SignalService();
        signalService.init(address(addressManager));

        addressManager.setAddress(block.chainid, "bridge", address(bridge));

        addressManager.setAddress(block.chainid, "signal_service", address(signalService));

        addressManager.setAddress(block.chainid, "token_vault", address(tokenVault));

        addressManager.setAddress(destChainId, "token_vault", address(destChainIdTokenVault));

        addressManager.setAddress(destChainId, "bridge", address(destChainIdBridge));

        vm.stopPrank();
    }

    function test_send_erc20_revert_if_allowance_not_set() public {
        vm.startPrank(Alice);

        vm.expectRevert("ERC20: insufficient allowance");
        tokenVault.sendERC20(destChainId, Bob, address(erc20), 1 wei, 1000000, 1, Bob, "");
    }

    function test_send_erc20_no_processing_fee() public {
        vm.startPrank(Alice);

        uint256 amount = 2 wei;
        erc20.approve(address(tokenVault), amount);

        uint256 aliceBalanceBefore = erc20.balanceOf(Alice);
        uint256 tokenVaultBalanceBefore = erc20.balanceOf(address(tokenVault));

        tokenVault.sendERC20(destChainId, Bob, address(erc20), amount, 1000000, 0, Bob, "");

        uint256 aliceBalanceAfter = erc20.balanceOf(Alice);
        uint256 tokenVaultBalanceAfter = erc20.balanceOf(address(tokenVault));

        assertEq(aliceBalanceBefore - aliceBalanceAfter, amount);
        assertEq(tokenVaultBalanceAfter - tokenVaultBalanceBefore, amount);
    }

    function test_send_erc20_processing_fee_reverts_if_msg_value_too_low() public {
        vm.startPrank(Alice);

        uint256 amount = 2 wei;
        erc20.approve(address(tokenVault), amount);

        vm.expectRevert();
        tokenVault.sendERC20(destChainId, Bob, address(erc20), amount, 1000000, amount - 1, Bob, "");
    }

    function test_send_erc20_processing_fee() public {
        vm.startPrank(Alice);

        uint256 amount = 2 wei;
        erc20.approve(address(tokenVault), amount);

        uint256 aliceBalanceBefore = erc20.balanceOf(Alice);
        uint256 tokenVaultBalanceBefore = erc20.balanceOf(address(tokenVault));

        tokenVault.sendERC20{value: amount}(
            destChainId, Bob, address(erc20), amount, 1000000, amount - 1, Bob, ""
        );

        uint256 aliceBalanceAfter = erc20.balanceOf(Alice);
        uint256 tokenVaultBalanceAfter = erc20.balanceOf(address(tokenVault));

        assertEq(aliceBalanceBefore - aliceBalanceAfter, amount);
        assertEq(tokenVaultBalanceAfter - tokenVaultBalanceBefore, amount);
    }

    function test_send_erc20_reverts_invalid_amount() public {
        vm.startPrank(Alice);

        uint256 amount = 0;

        vm.expectRevert(TokenVault.TOKENVAULT_INVALID_AMOUNT.selector);
        tokenVault.sendERC20(destChainId, Bob, address(erc20), amount, 1000000, 0, Bob, "");
    }

    function test_send_erc20_reverts_invalid_token_address() public {
        vm.startPrank(Alice);

        uint256 amount = 1;

        vm.expectRevert(TokenVault.TOKENVAULT_INVALID_TOKEN.selector);
        tokenVault.sendERC20(destChainId, Bob, address(0), amount, 1000000, 0, Bob, "");
    }

    function test_send_erc20_reverts_invalid_to() public {
        vm.startPrank(Alice);

        uint256 amount = 1;

        vm.expectRevert(TokenVault.TOKENVAULT_INVALID_TO.selector);
        tokenVault.sendERC20(destChainId, address(0), address(erc20), amount, 1000000, 0, Bob, "");
    }

    function test_receive_erc20_canonical_to_dest_chain_transfers_from_canonical_token() public {
        vm.startPrank(Alice);

        uint256 srcChainId = block.chainid;
        vm.chainId(destChainId);

        erc20.mint(address(tokenVault));

        uint256 amount = 1;
        address to = Bob;

        uint256 tokenVaultBalanceBefore = erc20.balanceOf(address(tokenVault));
        uint256 toBalanceBefore = erc20.balanceOf(to);

        destChainIdBridge.sendReceiveERC20ToTokenVault(
            erc20ToCanonicalERC20(destChainId),
            Alice,
            to,
            amount,
            bytes32(0),
            address(tokenVault),
            srcChainId
        );

        uint256 tokenVaultBalanceAfter = erc20.balanceOf(address(tokenVault));
        assertEq(tokenVaultBalanceBefore - tokenVaultBalanceAfter, amount);

        uint256 toBalanceAfter = erc20.balanceOf(to);
        assertEq(toBalanceAfter - toBalanceBefore, amount);
    }

    function test_receive_erc20_non_canonical_to_dest_chain_deploys_new_bridged_token_and_mints()
        public
    {
        vm.startPrank(Alice);

        uint256 srcChainId = block.chainid;
        vm.chainId(destChainId);

        uint256 amount = 1;

        destChainIdBridge.setTokenVault(address(destChainIdTokenVault));

        address bridgedAddressBefore =
            destChainIdTokenVault.canonicalToBridged(srcChainId, address(erc20));
        assertEq(bridgedAddressBefore == address(0), true);

        destChainIdBridge.sendReceiveERC20ToTokenVault(
            erc20ToCanonicalERC20(srcChainId),
            Alice,
            Bob,
            amount,
            bytes32(0),
            address(tokenVault),
            srcChainId
        );

        address bridgedAddressAfter =
            destChainIdTokenVault.canonicalToBridged(srcChainId, address(erc20));
        assertEq(bridgedAddressAfter != address(0), true);
        BridgedERC20 bridgedERC20 = BridgedERC20(bridgedAddressAfter);

        assertEq(bridgedERC20.balanceOf(Bob), amount);
    }

    function erc20ToCanonicalERC20(uint256 chainId)
        internal
        view
        returns (TokenVault.CanonicalERC20 memory)
    {
        return TokenVault.CanonicalERC20({
            chainId: chainId,
            addr: address(erc20),
            decimals: erc20.decimals(),
            symbol: erc20.symbol(),
            name: erc20.name()
        });
    }
}
