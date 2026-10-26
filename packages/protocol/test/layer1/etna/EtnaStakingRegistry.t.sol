// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IEtnaStakingRegistry } from "src/layer1/etna/iface/IEtnaStakingRegistry.sol";
import { EtnaInboxBootstrap } from "src/layer1/etna/impl/EtnaInboxBootstrap.sol";
import { EtnaStakingRegistry } from "src/layer1/etna/impl/EtnaStakingRegistry.sol";
import { TaikoToken } from "src/layer1/mainnet/TaikoToken.sol";
import { CommonTest } from "test/shared/CommonTest.sol";

contract EtnaStakingRegistryTest is CommonTest {
    uint256 internal constant MIN_STAKE = 1000 ether;
    uint256 internal constant ACTIVATION_DELAY = 10;
    uint256 internal constant EXIT_DELAY = 20;
    uint256 internal constant WITHDRAWAL_DELAY = 30;
    uint256 internal constant SLASH_BOUNTY_BPS = 1000;
    address internal constant SLASH_SINK = address(0x5151);
    uint64 internal constant L2_CHAIN_ID = 167_001;

    TaikoToken internal token;
    address internal inbox;
    EtnaStakingRegistry internal registry;

    function setUpOnEthereum() internal virtual override {
        token = deployTaikoToken();
    }

    function setUp() public virtual override {
        super.setUp();
        inbox = address(
            new ERC1967Proxy(
                address(new EtnaInboxBootstrap()),
                abi.encodeCall(EtnaInboxBootstrap.init, (address(this)))
            )
        );
        registry = EtnaStakingRegistry(
            address(
                new ERC1967Proxy(
                    address(new EtnaStakingRegistry(_config())),
                    abi.encodeCall(EtnaStakingRegistry.init, (address(0)))
                )
            )
        );
    }

    // ---------------------------------------------------------------
    // constructor and init
    // ---------------------------------------------------------------

    function test_constructor_SetsImmutables() external view {
        assertEq(address(registry.token()), address(token), "token");
        assertEq(registry.minStake(), MIN_STAKE, "min stake");
        assertEq(registry.activationDelay(), ACTIVATION_DELAY, "activation delay");
        assertEq(registry.exitDelay(), EXIT_DELAY, "exit delay");
        assertEq(registry.withdrawalDelay(), WITHDRAWAL_DELAY, "withdrawal delay");
        assertEq(registry.slashBountyBps(), SLASH_BOUNTY_BPS, "slash bounty");
        assertEq(registry.slashSink(), SLASH_SINK, "slash sink");
        assertEq(registry.l2ChainId(), L2_CHAIN_ID, "l2 chain id");
        assertEq(registry.inbox(), inbox, "inbox");
        assertEq(registry.NO_EXIT(), 2 ** 48 - 1, "no-exit sentinel");
        assertEq(registry.MAX_ENTRIES(), 4096, "capacity");
    }

    function test_init_SetsTheOwnerOnce() external {
        assertEq(registry.owner(), address(this), "owner defaults to the caller");
        vm.expectRevert("Initializable: contract is already initialized");
        registry.init(Alice);
    }

    function test_constructor_RevertWhen_DelayOutOfRange() external {
        for (uint256 i; i < 3; ++i) {
            IEtnaStakingRegistry.Config memory cfg = _withDelay(i, 0);
            vm.expectRevert(IEtnaStakingRegistry.InvalidConfig.selector);
            new EtnaStakingRegistry(cfg);

            cfg = _withDelay(i, 2 ** 32);
            vm.expectRevert(IEtnaStakingRegistry.InvalidConfig.selector);
            new EtnaStakingRegistry(cfg);

            new EtnaStakingRegistry(_withDelay(i, 1));
            new EtnaStakingRegistry(_withDelay(i, 2 ** 32 - 1));
        }
    }

    function test_constructor_RevertWhen_BountyAboveTenThousand() external {
        IEtnaStakingRegistry.Config memory cfg = _config();
        cfg.slashBountyBps = 10_001;
        vm.expectRevert(IEtnaStakingRegistry.InvalidConfig.selector);
        new EtnaStakingRegistry(cfg);

        cfg.slashBountyBps = 10_000;
        assertEq(new EtnaStakingRegistry(cfg).slashBountyBps(), 10_000);
        cfg.slashBountyBps = 0;
        assertEq(new EtnaStakingRegistry(cfg).slashBountyBps(), 0);
    }

    function test_constructor_RevertWhen_ZeroOrCodelessParameters() external {
        IEtnaStakingRegistry.Config memory cfg = _config();
        cfg.token = address(0);
        vm.expectRevert(IEtnaStakingRegistry.InvalidConfig.selector);
        new EtnaStakingRegistry(cfg);

        cfg = _config();
        cfg.minStake = 0;
        vm.expectRevert(IEtnaStakingRegistry.InvalidConfig.selector);
        new EtnaStakingRegistry(cfg);

        cfg = _config();
        cfg.slashSink = address(0);
        vm.expectRevert(IEtnaStakingRegistry.InvalidConfig.selector);
        new EtnaStakingRegistry(cfg);

        cfg = _config();
        cfg.l2ChainId = 0;
        vm.expectRevert(IEtnaStakingRegistry.InvalidConfig.selector);
        new EtnaStakingRegistry(cfg);

        cfg = _config();
        cfg.inbox = address(0);
        vm.expectRevert(IEtnaStakingRegistry.InvalidConfig.selector);
        new EtnaStakingRegistry(cfg);

        cfg.inbox = Alice;
        vm.expectRevert(IEtnaStakingRegistry.InvalidConfig.selector);
        new EtnaStakingRegistry(cfg);
    }

    // ---------------------------------------------------------------
    // views
    // ---------------------------------------------------------------

    function test_views_AreEmptyBeforeTheFirstRegistration() external {
        assertEq(registry.checkpointCount(), 0, "checkpoints");
        assertEq(registry.entryCount(), 0, "entries");
        assertEq(registry.entriesRoot(), bytes32(0), "root of no entry");
        assertEq(registry.freeSlotCount(), 0, "free slots");
        assertEq(registry.ownerOf(0), address(0), "owner");
        assertEq(registry.exitConfirmedAtL1(0), 0, "confirmation");
        assertFalse(registry.keyUsed(Alice), "key");

        vm.expectRevert(IEtnaStakingRegistry.UnknownCheckpoint.selector);
        registry.checkpointAt(0);
        vm.expectRevert(IEtnaStakingRegistry.UnknownBond.selector);
        registry.entryAt(0);
    }

    function test_registerDigest_IsEip712OverTheOwner() external {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("EtnaStakingRegistry"),
                keccak256("1"),
                block.chainid,
                address(registry)
            )
        );
        bytes32 structHash = keccak256(abi.encode(keccak256("Register(address owner)"), Alice));
        bytes32 expected = keccak256(abi.encodePacked(hex"1901", domainSeparator, structHash));
        assertEq(registry.registerDigest(Alice), expected, "digest");
        assertTrue(registry.registerDigest(Bob) != expected, "binds the owner");

        // The domain follows the current chain id rather than one cached at deployment.
        vm.chainId(block.chainid + 1);
        assertTrue(registry.registerDigest(Alice) != expected, "binds the chain id");
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _config() private view returns (IEtnaStakingRegistry.Config memory) {
        return IEtnaStakingRegistry.Config({
            token: address(token),
            minStake: MIN_STAKE,
            activationDelay: ACTIVATION_DELAY,
            exitDelay: EXIT_DELAY,
            withdrawalDelay: WITHDRAWAL_DELAY,
            slashBountyBps: SLASH_BOUNTY_BPS,
            slashSink: SLASH_SINK,
            l2ChainId: L2_CHAIN_ID,
            inbox: inbox
        });
    }

    /// @dev Returns the default config with delay `_which` (0 activation, 1 exit, 2 withdrawal)
    /// set to `_delay`.
    function _withDelay(
        uint256 _which,
        uint256 _delay
    )
        private
        view
        returns (IEtnaStakingRegistry.Config memory cfg_)
    {
        cfg_ = _config();
        if (_which == 0) cfg_.activationDelay = _delay;
        else if (_which == 1) cfg_.exitDelay = _delay;
        else cfg_.withdrawalDelay = _delay;
    }
}
