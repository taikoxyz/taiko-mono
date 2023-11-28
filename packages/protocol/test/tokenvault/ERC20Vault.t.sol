// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../TaikoTest.sol";

// For native USDC E2E tests
import { FiatTokenProxy } from
    "../helper/usdc/FiatTokenProxy/centre-tokens/contracts/v1/FiatTokenProxy.sol";
import { FiatTokenV2_1 } from
    "../helper/usdc/FiatTokenV2_1/centre-tokens/contracts/v2/FiatTokenV2_1.sol";
import { ERC20NativeRegistry } from
    "../../contracts/tokenvault/erc20/registry/ERC20NativeRegistry.sol";
import { UsdcAdapter } from "../../contracts/tokenvault/erc20/adapters/UsdcAdapter.sol";
import { BridgedERC20Adapter } from
    "../../contracts/tokenvault/erc20/adapters/BridgedERC20Adapter.sol";

// PrankDestBridge lets us simulate a transaction to the ERC20Vault
// from a named Bridge, without having to test/run through the real Bridge code,
// outside the scope of the unit tests in the ERC20Vault.
contract PrankDestBridge {
    ERC20Vault destERC20Vault;
    TContext ctx;

    struct TContext {
        bytes32 msgHash; // messageHash
        address sender;
        uint64 srcChainId;
    }

    constructor(ERC20Vault _erc20Vault) {
        destERC20Vault = _erc20Vault;
    }

    function setERC20Vault(address addr) public {
        destERC20Vault = ERC20Vault(addr);
    }

    function context() public view returns (TContext memory) {
        return ctx;
    }

    function sendReceiveERC20ToERC20Vault(
        ERC20Vault.CanonicalERC20 calldata canonicalToken,
        address from,
        address to,
        uint256 amount,
        bytes32 msgHash,
        address srcChainERC20Vault,
        uint64 srcChainId,
        uint256 mockLibInvokeMsgValue
    )
        public
    {
        ctx.sender = srcChainERC20Vault;
        ctx.msgHash = msgHash;
        ctx.srcChainId = srcChainId;

        // We need this in order to 'mock' the LibBridgeInvoke's
        //  (success,retVal) =
        //     message.to.call{ value: message.value, gas: gasLimit
        // }(message.data);
        // The problem (with foundry) is that this way it is not able to deploy
        // a contract
        // most probably due to some deployment address nonce issue. (Seems a
        // known issue).
        destERC20Vault.receiveToken{ value: mockLibInvokeMsgValue }(
            canonicalToken, from, to, amount
        );

        ctx.sender = address(0);
        ctx.msgHash = bytes32(0);
        ctx.srcChainId = 0;
    }
}

contract UpdatedBridgedERC20 is BridgedERC20 {
    function helloWorld() public pure returns (string memory) {
        return "helloworld";
    }
}

contract TestERC20Vault is TaikoTest {
    TaikoToken tko;
    AddressManager addressManager;
    Bridge bridge;
    ERC20Vault erc20Vault;
    ERC20Vault destChainIdERC20Vault;
    PrankDestBridge destChainIdBridge;
    FreeMintERC20 erc20;
    SignalService signalService;
    uint64 destChainId = 7;

    //For native USDC support tests!
    FiatTokenProxy proxyContract_L1;
    FiatTokenV2_1 fiatTokenV2_2_L1;
    FiatTokenProxy proxyContract_L2;
    FiatTokenV2_1 fiatTokenV2_2_L2;
    address proxyOwner; // aka proxy admin too !
    address minterRoleConfigurator; // The one who configures who can mint

    ERC20NativeRegistry erc20NativeRegistryL2; //Only need to deploy this on L2, since on L1, it is
        // 'native'
        // anyways

    // Dummy for implementation storage setting
    address THROWAWAY_ADDRESS = 0x0000000000000000000000000000000000000001;

    string constant NAME = "USD Coin";
    string constant SYMBOL = "USDC";
    string constant CURRENCY = "USD";
    uint8 constant DECIMALS = 6;

    function setUp() public {
        vm.startPrank(Carol);
        vm.deal(Alice, 1 ether);
        vm.deal(Carol, 1 ether);
        vm.deal(Bob, 1 ether);

        tko = TaikoToken(
            LibDeployHelper.deployProxy({
                name: "taiko_token",
                impl: address(new TaikoToken()),
                data: bytes.concat(
                    TaikoToken.init.selector, abi.encode("Taiko Token", "TTKOk", address(this))
                    )
            })
        );

        addressManager = AddressManager(
            LibDeployHelper.deployProxy({
                name: "address_manager",
                impl: address(new AddressManager()),
                data: bytes.concat(AddressManager.init.selector)
            })
        );

        addressManager.setAddress(uint64(block.chainid), "taiko_token", address(tko));

        erc20Vault = ERC20Vault(
            LibDeployHelper.deployProxy({
                name: "erc20_vault",
                impl: address(new ERC20Vault()),
                data: bytes.concat(BaseVault.init.selector, abi.encode(address(addressManager)))
            })
        );

        destChainIdERC20Vault = ERC20Vault(
            LibDeployHelper.deployProxy({
                name: "erc20_vault",
                impl: address(new ERC20Vault()),
                data: bytes.concat(BaseVault.init.selector, abi.encode(address(addressManager)))
            })
        );

        erc20NativeRegistryL2 = ERC20NativeRegistry(
            LibDeployHelper.deployProxy({
                name: "erc20_native_registry",
                impl: address(new ERC20NativeRegistry()),
                data: bytes.concat(
                    ERC20NativeRegistry.init.selector, abi.encode(address(addressManager))
                    )
            })
        );

        erc20 = new FreeMintERC20("ERC20", "ERC20");
        erc20.mint(Alice);

        bridge = Bridge(
            payable(
                LibDeployHelper.deployProxy({
                    name: "bridge",
                    impl: address(new Bridge()),
                    data: bytes.concat(Bridge.init.selector, abi.encode(addressManager)),
                    registerTo: address(addressManager),
                    owner: address(0)
                })
            )
        );

        destChainIdBridge = new PrankDestBridge(erc20Vault);
        vm.deal(address(destChainIdBridge), 100 ether);

        signalService = SignalService(
            LibDeployHelper.deployProxy({
                name: "signal_service",
                impl: address(new SignalService()),
                data: bytes.concat(SignalService.init.selector),
                registerTo: address(0),
                owner: address(0)
            })
        );

        addressManager.setAddress(uint64(block.chainid), "bridge", address(bridge));

        addressManager.setAddress(uint64(block.chainid), "signal_service", address(signalService));

        addressManager.setAddress(uint64(block.chainid), "erc20_vault", address(erc20Vault));

        addressManager.setAddress(destChainId, "erc20_vault", address(destChainIdERC20Vault));

        addressManager.setAddress(
            destChainId, "erc20_native_registry", address(erc20NativeRegistryL2)
        );
        addressManager.setAddress(destChainId, "bridge", address(destChainIdBridge));

        address bridgedERC20 = address(new BridgedERC20());

        addressManager.setAddress(destChainId, "bridged_erc20", bridgedERC20);

        // For adapter we only need the implementation - hence they will be an extension of the
        // ERC20Vaults
        address usdcAdapterImp = address(new UsdcAdapter());

        addressManager.setAddress(destChainId, "usdc_adapter", usdcAdapterImp);
        addressManager.setAddress(uint64(block.chainid), "usdc_adapter", usdcAdapterImp);

        address bridgedERC20AdapterImp = address(new BridgedERC20Adapter());

        addressManager.setAddress(destChainId, "bridged_erc20_adapter", bridgedERC20AdapterImp);
        addressManager.setAddress(
            uint64(block.chainid), "bridged_erc20_adapter", bridgedERC20AdapterImp
        );

        addressManager.setAddress(uint64(block.chainid), "bridged_erc20", bridgedERC20);

        proxyOwner = vm.addr(0x12);
        minterRoleConfigurator = vm.addr(0x13);

        //L1 -> Native
        fiatTokenV2_2_L1 = new FiatTokenV2_1();
        proxyContract_L1 = new FiatTokenProxy(address(fiatTokenV2_2_L1));

        // L2 -> Deployed by Taiko - but meant to be native
        fiatTokenV2_2_L2 = new FiatTokenV2_1();
        proxyContract_L2 = new FiatTokenProxy(address(fiatTokenV2_2_L2));

        vm.stopPrank();

        // Config the USDC (on both chains)
        vm.startPrank(proxyOwner);
        FiatTokenV2_1(address(proxyContract_L1)).initialize(
            NAME,
            SYMBOL,
            CURRENCY,
            DECIMALS,
            minterRoleConfigurator,
            THROWAWAY_ADDRESS,
            THROWAWAY_ADDRESS,
            proxyOwner
        );

        //// Do the V2 initialization
        // console.log("Initializing V2...");
        FiatTokenV2_1(address(proxyContract_L1)).initializeV2(NAME);

        // // Do the V2_1 initialization
        // console.log("Initializing V2.1...");
        FiatTokenV2_1(address(proxyContract_L1)).initializeV2_1(THROWAWAY_ADDRESS);

        FiatTokenV2_1(address(proxyContract_L2)).initialize(
            NAME,
            SYMBOL,
            CURRENCY,
            DECIMALS,
            minterRoleConfigurator,
            THROWAWAY_ADDRESS,
            THROWAWAY_ADDRESS,
            proxyOwner
        );

        //// Do the V2 initialization
        // console.log("Initializing V2...");
        FiatTokenV2_1(address(proxyContract_L2)).initializeV2(NAME);

        // // Do the V2_1 initialization
        // console.log("Initializing V2.1...");
        FiatTokenV2_1(address(proxyContract_L2)).initializeV2_1(THROWAWAY_ADDRESS);

        vm.stopPrank();
        // Set the registry
        vm.prank(Carol, Carol);
        erc20NativeRegistryL2.changeCustomToken(
            address(proxyContract_L1),
            address(proxyContract_L2),
            "usdc_adapter",
            uint64(block.chainid),
            false
        );

        vm.prank(minterRoleConfigurator, minterRoleConfigurator);
        FiatTokenV2_1(address(proxyContract_L1)).configureMinter(
            address(erc20Vault), type(uint256).max
        );

        vm.prank(minterRoleConfigurator, minterRoleConfigurator);
        FiatTokenV2_1(address(proxyContract_L2)).configureMinter(
            address(destChainIdERC20Vault), type(uint256).max
        );

        // Mint 10 tokens to Alice
        vm.prank(address(erc20Vault), address(erc20Vault));
        FiatTokenV2_1(address(proxyContract_L1)).mint(Alice, 10);
    }

    function test_20Vault_send_erc20_revert_if_allowance_not_set() public {
        vm.startPrank(Alice);

        vm.expectRevert("ERC20: insufficient allowance");
        erc20Vault.sendToken(
            ERC20Vault.BridgeTransferOp(
                destChainId, Bob, address(erc20), 1 wei, 1_000_000, 1, Bob, ""
            )
        );
    }

    function test_20Vault_send_erc20_no_processing_fee() public {
        vm.startPrank(Alice);

        uint256 amount = 2 wei;
        erc20.approve(address(erc20Vault), amount);

        uint256 aliceBalanceBefore = erc20.balanceOf(Alice);
        uint256 erc20VaultBalanceBefore = erc20.balanceOf(address(erc20Vault));

        erc20Vault.sendToken(
            ERC20Vault.BridgeTransferOp(
                destChainId, Bob, address(erc20), amount, 1_000_000, 0, Bob, ""
            )
        );

        uint256 aliceBalanceAfter = erc20.balanceOf(Alice);
        uint256 erc20VaultBalanceAfter = erc20.balanceOf(address(erc20Vault));

        assertEq(aliceBalanceBefore - aliceBalanceAfter, amount);
        assertEq(erc20VaultBalanceAfter - erc20VaultBalanceBefore, amount);
    }

    function test_20Vault_send_erc20_processing_fee_reverts_if_msg_value_too_low() public {
        vm.startPrank(Alice);

        uint256 amount = 2 wei;
        erc20.approve(address(erc20Vault), amount);

        vm.expectRevert();
        erc20Vault.sendToken(
            ERC20Vault.BridgeTransferOp(
                destChainId, Bob, address(erc20), amount, 1_000_000, amount - 1, Bob, ""
            )
        );
    }

    function test_20Vault_send_erc20_processing_fee() public {
        vm.startPrank(Alice);

        uint256 amount = 2 wei;
        erc20.approve(address(erc20Vault), amount);

        uint256 aliceBalanceBefore = erc20.balanceOf(Alice);
        uint256 erc20VaultBalanceBefore = erc20.balanceOf(address(erc20Vault));

        erc20Vault.sendToken{ value: amount }(
            ERC20Vault.BridgeTransferOp(
                destChainId,
                Bob,
                address(erc20),
                amount - 1, // value: (msg.value - fee)
                1_000_000,
                amount - 1,
                Bob,
                ""
            )
        );

        uint256 aliceBalanceAfter = erc20.balanceOf(Alice);
        uint256 erc20VaultBalanceAfter = erc20.balanceOf(address(erc20Vault));

        assertEq(aliceBalanceBefore - aliceBalanceAfter, 1);
        assertEq(erc20VaultBalanceAfter - erc20VaultBalanceBefore, 1);
    }

    function test_20Vault_send_erc20_reverts_invalid_amount() public {
        vm.startPrank(Alice);

        uint256 amount = 0;

        vm.expectRevert(ERC20Vault.VAULT_INVALID_AMOUNT.selector);
        erc20Vault.sendToken(
            ERC20Vault.BridgeTransferOp(
                destChainId, Bob, address(erc20), amount, 1_000_000, 0, Bob, ""
            )
        );
    }

    function test_20Vault_send_erc20_reverts_invalid_token_address() public {
        vm.startPrank(Alice);

        uint256 amount = 1;

        vm.expectRevert(ERC20Vault.VAULT_INVALID_TOKEN.selector);
        erc20Vault.sendToken(
            ERC20Vault.BridgeTransferOp(destChainId, Bob, address(0), amount, 1_000_000, 0, Bob, "")
        );
    }

    function test_20Vault_receive_erc20_canonical_to_dest_chain_transfers_from_canonical_token()
        public
    {
        vm.startPrank(Alice);

        uint64 srcChainId = uint64(block.chainid);
        vm.chainId(destChainId);

        erc20.mint(address(erc20Vault));

        uint256 amount = 1;
        address to = Bob;

        uint256 erc20VaultBalanceBefore = erc20.balanceOf(address(erc20Vault));
        uint256 toBalanceBefore = erc20.balanceOf(to);

        destChainIdBridge.sendReceiveERC20ToERC20Vault(
            erc20ToCanonicalERC20(destChainId),
            Alice,
            to,
            amount,
            bytes32(0),
            address(erc20Vault),
            srcChainId,
            0
        );

        uint256 erc20VaultBalanceAfter = erc20.balanceOf(address(erc20Vault));
        assertEq(erc20VaultBalanceBefore - erc20VaultBalanceAfter, amount);

        uint256 toBalanceAfter = erc20.balanceOf(to);
        assertEq(toBalanceAfter - toBalanceBefore, amount);
    }

    function test_20Vault_receiveTokens_erc20_with_ether_to_dave() public {
        vm.startPrank(Alice);

        uint64 srcChainId = uint64(block.chainid);
        vm.chainId(destChainId);

        erc20.mint(address(erc20Vault));

        uint256 amount = 1;
        uint256 etherAmount = 0.1 ether;
        address to = David;

        uint256 erc20VaultBalanceBefore = erc20.balanceOf(address(erc20Vault));
        uint256 toBalanceBefore = erc20.balanceOf(to);

        destChainIdBridge.sendReceiveERC20ToERC20Vault(
            erc20ToCanonicalERC20(destChainId),
            Alice,
            to,
            amount,
            bytes32(0),
            address(erc20Vault),
            srcChainId,
            etherAmount
        );

        uint256 erc20VaultBalanceAfter = erc20.balanceOf(address(erc20Vault));
        assertEq(erc20VaultBalanceBefore - erc20VaultBalanceAfter, amount);

        uint256 toBalanceAfter = erc20.balanceOf(to);
        assertEq(toBalanceAfter - toBalanceBefore, amount);
        assertEq(David.balance, etherAmount);
    }

    function test_20Vault_receive_erc20_non_canonical_to_dest_chain_deploys_new_bridged_token_and_mints(
    )
        public
    {
        vm.startPrank(Alice);

        uint64 srcChainId = uint64(block.chainid);
        vm.chainId(destChainId);

        uint256 amount = 1;

        destChainIdBridge.setERC20Vault(address(destChainIdERC20Vault));

        address bridgedAddressBefore =
            destChainIdERC20Vault.canonicalToBridged(srcChainId, address(erc20));
        assertEq(bridgedAddressBefore == address(0), true);

        destChainIdBridge.sendReceiveERC20ToERC20Vault(
            erc20ToCanonicalERC20(srcChainId),
            Alice,
            Bob,
            amount,
            bytes32(0),
            address(erc20Vault),
            srcChainId,
            0
        );

        address bridgedAddressAfter =
            destChainIdERC20Vault.canonicalToBridged(srcChainId, address(erc20));
        assertEq(bridgedAddressAfter != address(0), true);
        BridgedERC20 bridgedERC20 = BridgedERC20(bridgedAddressAfter);

        assertEq(bridgedERC20.name(), unicode"Bridged ERC20 (⭀31337)");
        assertEq(bridgedERC20.symbol(), unicode"ERC20.t");
        assertEq(bridgedERC20.balanceOf(Bob), amount);
    }

    function erc20ToCanonicalERC20(uint64 chainId)
        internal
        view
        returns (ERC20Vault.CanonicalERC20 memory)
    {
        return ERC20Vault.CanonicalERC20({
            chainId: chainId,
            addr: address(erc20),
            decimals: erc20.decimals(),
            symbol: erc20.symbol(),
            name: erc20.name()
        });
    }

    function usdcCanonicalToken(uint64 chainId)
        internal
        view
        returns (ERC20Vault.CanonicalERC20 memory)
    {
        return ERC20Vault.CanonicalERC20({
            chainId: chainId,
            addr: address(proxyContract_L1),
            decimals: FiatTokenV2_1(address(proxyContract_L2)).decimals(),
            symbol: FiatTokenV2_1(address(proxyContract_L2)).symbol(),
            name: FiatTokenV2_1(address(proxyContract_L2)).name()
        });
    }

    function test_20Vault_upgrade_bridged_tokens_20() public {
        vm.startPrank(Alice);

        uint64 srcChainId = uint64(block.chainid);
        vm.chainId(destChainId);

        uint256 amount = 1;

        destChainIdBridge.setERC20Vault(address(destChainIdERC20Vault));

        address bridgedAddressBefore =
            destChainIdERC20Vault.canonicalToBridged(srcChainId, address(erc20));
        assertEq(bridgedAddressBefore == address(0), true);

        destChainIdBridge.sendReceiveERC20ToERC20Vault(
            erc20ToCanonicalERC20(srcChainId),
            Alice,
            Bob,
            amount,
            bytes32(0),
            address(erc20Vault),
            srcChainId,
            0
        );

        address bridgedAddressAfter =
            destChainIdERC20Vault.canonicalToBridged(srcChainId, address(erc20));
        assertEq(bridgedAddressAfter != address(0), true);

        try UpdatedBridgedERC20(bridgedAddressAfter).helloWorld() {
            fail();
        } catch {
            // It should not yet support this function call
        }

        // Upgrade the implementation of that contract
        // so that it supports now the 'helloWorld' call
        UpdatedBridgedERC20 newBridgedContract = new UpdatedBridgedERC20();
        vm.stopPrank();
        vm.prank(Carol, Carol);
        BridgedERC20(payable(bridgedAddressAfter)).upgradeTo(address(newBridgedContract));

        vm.prank(Alice, Alice);
        try UpdatedBridgedERC20(bridgedAddressAfter).helloWorld() {
            // It should support now this function call
        } catch {
            fail();
        }
    }

    function test_20Vault_bridge_native_usdc_to_l2() public {
        vm.startPrank(Alice);

        uint64 srcChainId = uint64(block.chainid);
        vm.chainId(destChainId);

        uint256 amount = 1;

        destChainIdBridge.setERC20Vault(address(destChainIdERC20Vault));

        address bridgedAddressBefore =
            destChainIdERC20Vault.canonicalToBridged(srcChainId, address(erc20));
        assertEq(bridgedAddressBefore == address(0), true);

        destChainIdBridge.sendReceiveERC20ToERC20Vault(
            usdcCanonicalToken(srcChainId),
            Alice,
            Bob,
            amount,
            bytes32(0),
            address(erc20Vault),
            srcChainId,
            0
        );

        address bridgedAddressAfter =
            destChainIdERC20Vault.canonicalToBridged(srcChainId, address(proxyContract_L1));

        BridgedERC20 bridgedERC20 = BridgedERC20(bridgedAddressAfter);

        assertEq(bridgedERC20.name(), unicode"USD Coin");
        assertEq(bridgedERC20.balanceOf(Bob), amount);
    }

    function test_20Vault_bridge_native_usdc_back_to_l1() public {
        vm.startPrank(Alice);

        uint64 srcChainId = uint64(block.chainid);
        vm.chainId(destChainId);

        uint256 amount = 1;

        destChainIdBridge.setERC20Vault(address(destChainIdERC20Vault));

        address bridgedAddressBefore =
            destChainIdERC20Vault.canonicalToBridged(srcChainId, address(erc20));
        assertEq(bridgedAddressBefore == address(0), true);

        console2.log("Bob is:", Bob);
        console2.log("proxyContract_L1 is:", address(proxyContract_L1));
        console2.log("proxyContract_L2 is:", address(proxyContract_L2));

        destChainIdBridge.sendReceiveERC20ToERC20Vault(
            usdcCanonicalToken(srcChainId),
            Alice,
            Bob,
            amount,
            bytes32(0),
            address(erc20Vault),
            srcChainId,
            0
        );

        address bridgedAddressAfter =
            destChainIdERC20Vault.canonicalToBridged(srcChainId, address(proxyContract_L1));

        BridgedERC20 bridgedERC20 = BridgedERC20(bridgedAddressAfter);

        console.log("BirdgedAddress is:", address(bridgedERC20));
        console.log("Supply is:", bridgedERC20.totalSupply());

        assertEq(bridgedERC20.name(), unicode"USD Coin");
        assertEq(bridgedERC20.balanceOf(Bob), amount);

        uint256 bobBalanceBefore = bridgedERC20.balanceOf(Bob);
        uint256 erc20VaultBalanceBefore = bridgedERC20.balanceOf(address(destChainIdERC20Vault));

        assertEq(bobBalanceBefore, 1);
        assertEq(erc20VaultBalanceBefore, 0);

        vm.stopPrank();

        // Setters for the "destination chain" to be able to bridge back
        vm.prank(Carol, Carol);
        addressManager.setAddress(uint64(block.chainid), "bridge", address(bridge));
        vm.prank(Carol, Carol);
        addressManager.setAddress(uint64(block.chainid), "signal_service", address(signalService));

        vm.prank(Bob, Bob);
        bridgedERC20.approve(address(destChainIdERC20Vault), amount);

        // Supply is 1
        assertEq(bridgedERC20.totalSupply(), 1);

        vm.prank(Bob, Bob);
        destChainIdERC20Vault.sendToken(
            ERC20Vault.BridgeTransferOp(
                srcChainId, Bob, address(bridgedERC20), amount, 1_000_000, 0, Bob, ""
            )
        );

        uint256 bobBalanceAfter = bridgedERC20.balanceOf(Alice);
        uint256 erc20VaultBalanceAfter = bridgedERC20.balanceOf(address(destChainIdERC20Vault));

        assertEq(bobBalanceAfter, 0);
        assertEq(erc20VaultBalanceAfter, 0);
        // Supply is 0
        assertEq(bridgedERC20.totalSupply(), 0);
    }

    // This tests a scenario, when for example - for whatever reason - circle gets the ownership of
    // the native token but revokes the minterRole from us.
    function test_20Vault_bridge_native_usdc_to_l2_but_after_circle_revoked_minter_role() public {
        vm.startPrank(Alice);

        uint64 srcChainId = uint64(block.chainid);
        vm.chainId(destChainId);

        uint256 amount = 1;

        destChainIdBridge.setERC20Vault(address(destChainIdERC20Vault));

        address bridgedAddressBefore =
            destChainIdERC20Vault.canonicalToBridged(srcChainId, address(erc20));
        assertEq(bridgedAddressBefore == address(0), true);

        destChainIdBridge.sendReceiveERC20ToERC20Vault(
            usdcCanonicalToken(srcChainId),
            Alice,
            Bob,
            amount,
            bytes32(0),
            address(erc20Vault),
            srcChainId,
            0
        );

        address bridgedAddressAfter =
            destChainIdERC20Vault.canonicalToBridged(srcChainId, address(proxyContract_L1));

        BridgedERC20 bridgedERC20 = BridgedERC20(bridgedAddressAfter);

        assertEq(bridgedERC20.name(), unicode"USD Coin");
        assertEq(bridgedERC20.balanceOf(Bob), amount);

        vm.stopPrank();

        // Imitating circle revoke minter role.
        vm.prank(minterRoleConfigurator, minterRoleConfigurator);
        FiatTokenV2_1(address(proxyContract_L1)).removeMinter(address(erc20Vault));

        vm.prank(minterRoleConfigurator, minterRoleConfigurator);
        FiatTokenV2_1(address(proxyContract_L2)).removeMinter(address(destChainIdERC20Vault));

        // Circle revoked minter role, we cannot bridge now USDC from L1 to L2, but we can
        // mint our bridged "USDC ⭀31337" style, tho it cannot be considered native
        vm.prank(Carol, Carol);
        erc20NativeRegistryL2.changeCustomToken(
            address(proxyContract_L1), address(proxyContract_L2), "usdc_adapter", srcChainId, true
        );

        vm.startPrank(Alice, Alice);
        destChainIdBridge.sendReceiveERC20ToERC20Vault(
            usdcCanonicalToken(srcChainId),
            Alice,
            Bob,
            amount,
            bytes32(0),
            address(erc20Vault),
            srcChainId,
            0
        );

        address bridgedAddressAfterRevokedMinterRole =
            destChainIdERC20Vault.canonicalToBridged(srcChainId, address(proxyContract_L1));

        assertEq((bridgedAddressAfter != bridgedAddressAfterRevokedMinterRole), true);
    }
}
