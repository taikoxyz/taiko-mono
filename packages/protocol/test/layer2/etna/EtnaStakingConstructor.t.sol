// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaStakingTestBase } from "./EtnaStakingTestBase.sol";
import { EtnaStaking } from "src/layer2/etna/EtnaStaking.sol";
import { IEtnaStaking } from "src/layer2/etna/iface/IEtnaStaking.sol";

contract EtnaStakingConstructorTest is EtnaStakingTestBase {
    // ---------------------------------------------------------------
    // constructor
    // ---------------------------------------------------------------

    function test_constructor_SetsTheImmutableViews() external view {
        assertEq(staking.token(), address(token), "token");
        assertEq(staking.l1ChainId(), L1_CHAIN_ID, "l1 chain id");
        assertEq(staking.inbox(), INBOX, "inbox");
        assertEq(staking.minStake(), MIN_STAKE, "min stake");
        assertEq(staking.vpUnit(), VP_UNIT, "vp unit");
        assertEq(staking.nMax(), N_MAX, "n max");
        assertEq(staking.missLimit(), MISS_LIMIT, "miss limit");
        assertEq(staking.missSlashBps(), MISS_SLASH_BPS, "miss slash bps");
        assertEq(staking.withdrawalDelay(), WITHDRAWAL_DELAY, "withdrawal delay");
        assertEq(staking.slashBountyBps(), SLASH_BOUNTY_BPS, "slash bounty bps");
        assertEq(staking.slashSink(), SLASH_SINK, "slash sink");
        assertEq(staking.forfeitBps(), FORFEIT_BPS, "forfeit bps");
        assertEq(staking.NO_EXIT(), 2 ** 48 - 1, "no-exit value");
        assertEq(
            staking.SYSTEM_CALLER(), 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE, "system caller"
        );
        assertEq(staking.MAX_SEATS(), 128, "seat records");
        assertEq(staking.bondCount(), 0, "no bond issued");
        assertEq(staking.lastGeneration(), 0, "no generation stored");
    }

    function test_constructor_RevertWhen_NMaxOutOfRange() external {
        IEtnaStaking.Config memory cfg = _config();
        cfg.nMax = 0;
        _assertInvalidConfig(cfg, "zero seats");
        cfg.nMax = 129;
        _assertInvalidConfig(cfg, "129 seats");

        cfg.nMax = 1;
        cfg.minStake = 1e27;
        assertEq(new EtnaStaking(cfg).nMax(), 1, "one seat");
        cfg.nMax = 128;
        assertEq(new EtnaStaking(cfg).nMax(), 128, "128 seats");
    }

    /// @dev minStake * nMax must reach 10^27, TAIKO's fixed supply: 10^27 / 128 base units exactly
    /// deploys and one less reverts.
    function test_constructor_RevertWhen_MinStakeTimesNMaxBelowSupply() external {
        IEtnaStaking.Config memory cfg = _config();
        cfg.nMax = 128;
        cfg.minStake = 7_812_499_999_999_999_999_999_999;
        _assertInvalidConfig(cfg, "one below the supply bound");

        cfg.minStake = 7_812_500_000_000_000_000_000_000;
        assertEq(new EtnaStaking(cfg).minStake(), cfg.minStake, "at the supply bound");
    }

    function test_constructor_RevertWhen_VpUnitBelowBound() external {
        IEtnaStaking.Config memory cfg = _config();
        cfg.vpUnit = 867_361_737;
        _assertInvalidConfig(cfg, "one below the bound");

        cfg.vpUnit = 867_361_738;
        assertEq(new EtnaStaking(cfg).vpUnit(), 867_361_738, "at the bound");
    }

    function test_constructor_RevertWhen_MinStakeBelowVpUnit() external {
        IEtnaStaking.Config memory cfg = _config();
        cfg.vpUnit = cfg.minStake + 1;
        _assertInvalidConfig(cfg, "vp unit above min stake");

        cfg.vpUnit = cfg.minStake;
        assertEq(new EtnaStaking(cfg).vpUnit(), cfg.minStake, "vp unit equal to min stake");
    }

    function test_constructor_RevertWhen_MissLimitOutOfRange() external {
        IEtnaStaking.Config memory cfg = _config();
        cfg.missLimit = 0;
        _assertInvalidConfig(cfg, "zero");
        cfg.missLimit = 65_536;
        _assertInvalidConfig(cfg, "65,536");

        cfg.missLimit = 1;
        assertEq(new EtnaStaking(cfg).missLimit(), 1, "one");
        cfg.missLimit = 65_535;
        assertEq(new EtnaStaking(cfg).missLimit(), 65_535, "65,535");
    }

    function test_constructor_RevertWhen_MissSlashBpsOutOfRange() external {
        IEtnaStaking.Config memory cfg = _config();
        cfg.missSlashBps = 0;
        _assertInvalidConfig(cfg, "zero");
        cfg.missSlashBps = 10_001;
        _assertInvalidConfig(cfg, "10,001");

        cfg.missSlashBps = 10_000;
        assertEq(new EtnaStaking(cfg).missSlashBps(), 10_000, "the whole stake");
    }

    function test_constructor_RevertWhen_SlashBountyBpsAtFull() external {
        IEtnaStaking.Config memory cfg = _config();
        cfg.slashBountyBps = 10_000;
        _assertInvalidConfig(cfg, "the whole slash");

        cfg.slashBountyBps = 0;
        assertEq(new EtnaStaking(cfg).slashBountyBps(), 0, "no bounty");
        cfg.slashBountyBps = 9999;
        assertEq(new EtnaStaking(cfg).slashBountyBps(), 9999, "9,999");
    }

    function test_constructor_RevertWhen_ForfeitBpsOutOfRange() external {
        IEtnaStaking.Config memory cfg = _config();
        cfg.forfeitBps = 0;
        _assertInvalidConfig(cfg, "zero");
        cfg.forfeitBps = 10_001;
        _assertInvalidConfig(cfg, "10,001");

        cfg.forfeitBps = 10_000;
        assertEq(new EtnaStaking(cfg).forfeitBps(), 10_000, "the whole stake");
    }

    function test_constructor_RevertWhen_WithdrawalDelayOutOfRange() external {
        IEtnaStaking.Config memory cfg = _config();
        cfg.withdrawalDelay = 0;
        _assertInvalidConfig(cfg, "zero");
        cfg.withdrawalDelay = 2 ** 48;
        _assertInvalidConfig(cfg, "2^48");

        cfg.withdrawalDelay = 2 ** 48 - 1;
        assertEq(new EtnaStaking(cfg).withdrawalDelay(), 2 ** 48 - 1, "2^48 - 1");
    }

    function test_constructor_RevertWhen_AddressOrL1ChainIdZero() external {
        IEtnaStaking.Config memory cfg = _config();
        cfg.token = address(0);
        _assertInvalidConfig(cfg, "token");

        cfg = _config();
        cfg.inbox = address(0);
        _assertInvalidConfig(cfg, "inbox");

        cfg = _config();
        cfg.slashSink = address(0);
        _assertInvalidConfig(cfg, "slash sink");

        cfg = _config();
        cfg.l1ChainId = 0;
        _assertInvalidConfig(cfg, "l1 chain id");
    }

    /// @dev A bridged token may refuse transfers to its own address, which would make every
    /// slash, forfeiture and penalty transfer revert, and with it every block-start call that
    /// penalizes a bond.
    function test_constructor_RevertWhen_SlashSinkIsToken() external {
        IEtnaStaking.Config memory cfg = _config();
        cfg.slashSink = cfg.token;
        vm.expectRevert(IEtnaStaking.SlashSinkIsToken.selector);
        new EtnaStaking(cfg);
    }

    // ---------------------------------------------------------------
    // init
    // ---------------------------------------------------------------

    function test_init_SetsOwnerOnce() external {
        assertEq(staking.owner(), STAKING_OWNER, "owner");
        assertEq(staking.pendingOwner(), address(0), "no pending owner");

        vm.expectRevert("Initializable: contract is already initialized");
        staking.init(Alice);
        assertEq(staking.owner(), STAKING_OWNER, "owner kept");
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    function _assertInvalidConfig(
        IEtnaStaking.Config memory _cfg,
        string memory _label
    )
        private
    {
        try new EtnaStaking(_cfg) returns (EtnaStaking deployed) {
            assertTrue(
                false, string.concat(_label, ": deployed at ", vm.toString(address(deployed)))
            );
        } catch (bytes memory err) {
            assertEq(err, abi.encodeWithSelector(IEtnaStaking.InvalidConfig.selector), _label);
        }
    }
}
