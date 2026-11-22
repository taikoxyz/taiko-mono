// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { EtnaVoteKeys } from "./EtnaVoteKeys.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { EtnaStaking } from "src/layer2/etna/EtnaStaking.sol";
import { IEtnaStaking } from "src/layer2/etna/iface/IEtnaStaking.sol";
import { TestERC20 } from "test/mocks/TestERC20.sol";
import { CommonTest } from "test/shared/CommonTest.sol";
import { EtnaTestKeys } from "test/shared/etna/EtnaTestKeys.sol";

/// @title EtnaStakingTestBase
/// @notice Deploys a staking proxy on chain 167001 with the reference parameters, staking a
/// mintable stand-in for the bridged TAIKO token.
/// @dev `_fund` mints, so a test may stake more than TAIKO's fixed 10^27 supply. That is test
/// scaffolding, not a reachable state.
abstract contract EtnaStakingTestBase is CommonTest {
    /// @dev The ERC-7201 base slot T of `taiko.etna.staking`.
    bytes32 internal constant T =
        0x5cfa9ae4fa3ccb6db5189dbaff84335bb566ebd2f7442638272a1d81ccb19e00;

    /// @dev The L2 chain id the base runs on.
    uint256 internal constant L2_CHAIN_ID = 167_001;

    /// @dev The reference parameters.
    uint256 internal constant L1_CHAIN_ID = 1;
    address internal constant INBOX = 0x1111111111111111111111111111111111111111;
    uint256 internal constant MIN_STAKE = 7_812_500 ether;
    uint256 internal constant VP_UNIT = 1e9;
    uint256 internal constant N_MAX = 128;
    uint256 internal constant MISS_LIMIT = 3600;
    uint256 internal constant MISS_SLASH_BPS = 1000;
    uint256 internal constant WITHDRAWAL_DELAY = 302_402;
    uint256 internal constant SLASH_BOUNTY_BPS = 1000;
    address internal constant SLASH_SINK = address(0x5151);
    uint256 internal constant FORFEIT_BPS = 1000;

    /// @dev The staking owner, the DAO's execution address on L2.
    address internal constant STAKING_OWNER = address(0xDA0);

    /// @dev The `exitHeight` of a bond with no exit set.
    uint48 internal constant NO_EXIT = type(uint48).max;

    TestERC20 internal token;
    EtnaStaking internal staking;

    function setUp() public virtual override {
        super.setUp();
        vm.chainId(L2_CHAIN_ID);
        token = new TestERC20("Bridged Taiko Token", "TAIKO");
        staking = _deploy(_config());
    }

    /// @dev The reference configuration, staking `token`.
    function _config() internal view returns (IEtnaStaking.Config memory) {
        return IEtnaStaking.Config({
            token: address(token),
            l1ChainId: L1_CHAIN_ID,
            inbox: INBOX,
            minStake: MIN_STAKE,
            vpUnit: VP_UNIT,
            nMax: N_MAX,
            missLimit: MISS_LIMIT,
            missSlashBps: MISS_SLASH_BPS,
            withdrawalDelay: WITHDRAWAL_DELAY,
            slashBountyBps: SLASH_BOUNTY_BPS,
            slashSink: SLASH_SINK,
            forfeitBps: FORFEIT_BPS
        });
    }

    /// @dev Deploys a staking implementation with `_cfg` behind a proxy initialized to
    /// `STAKING_OWNER`.
    function _deploy(IEtnaStaking.Config memory _cfg) internal returns (EtnaStaking) {
        return EtnaStaking(
            address(
                new ERC1967Proxy(
                    address(new EtnaStaking(_cfg)),
                    abi.encodeCall(EtnaStaking.init, (STAKING_OWNER))
                )
            )
        );
    }

    /// @dev Mints `_amount` to `_staker`, who approves `staking` for any amount.
    function _fund(address _staker, uint256 _amount) internal {
        token.mint(_staker, _amount);
        vm.prank(_staker);
        token.approve(address(staking), type(uint256).max);
    }

    /// @dev Funds `_owner` with `_amount`, which then registers the consensus key of `_pk` at
    /// `staking`, staking it.
    function _register(
        uint256 _pk,
        address _owner,
        uint256 _amount
    )
        internal
        returns (uint256 bondId_)
    {
        _fund(_owner, _amount);
        bytes memory publicKey = EtnaTestKeys.publicKey(_pk);
        bytes memory pop = EtnaVoteKeys.popSig(_pk, staking, _owner);
        vm.prank(_owner);
        bondId_ = staking.register(publicKey, _amount, pop);
    }

    /// @dev Returns the raw key-to-seat word of `_ckAddr`, at keccak256(abi.encode(ckAddr, T + 2)).
    function _keySeatWord(address _ckAddr) internal view returns (bytes32) {
        return vm.load(address(staking), keccak256(abi.encode(_ckAddr, uint256(T) + 2)));
    }

    /// @dev Requests the exit of bond `_bondId` as its owner.
    function _requestExit(uint256 _bondId) internal {
        vm.prank(staking.bondAt(_bondId).owner);
        staking.requestExit(_bondId);
    }

    /// @dev `keccak256(abi.encode(uint256(keccak256(_namespace)) - 1)) & ~0xff`.
    function _erc7201(string memory _namespace) internal pure returns (bytes32) {
        return
            keccak256(abi.encode(uint256(keccak256(bytes(_namespace))) - 1))
                & ~bytes32(uint256(0xff));
    }

    /// @dev Asserts `seatOfBond(_bondId)`.
    function _assertSeatOfBond(
        uint256 _bondId,
        bool _holdsSeat,
        uint8 _seat,
        string memory _label
    )
        internal
        view
    {
        (bool holdsSeat, uint8 seat) = staking.seatOfBond(_bondId);
        assertEq(holdsSeat, _holdsSeat, string.concat(_label, ": holdsSeat"));
        assertEq(seat, _seat, string.concat(_label, ": seat"));
    }

    /// @dev Asserts `bondInSeat(_seat)`.
    function _assertBondInSeat(
        uint8 _seat,
        bool _occupied,
        uint256 _bondId,
        string memory _label
    )
        internal
        view
    {
        (bool occupied, uint256 bondId) = staking.bondInSeat(_seat);
        assertEq(occupied, _occupied, string.concat(_label, ": occupied"));
        assertEq(bondId, _bondId, string.concat(_label, ": bond id"));
    }

    /// @dev Asserts `bondForKey(_ckAddr)`.
    function _assertBondForKey(
        address _ckAddr,
        bool _registered,
        uint256 _bondId,
        string memory _label
    )
        internal
        view
    {
        (bool registered, uint256 bondId) = staking.bondForKey(_ckAddr);
        assertEq(registered, _registered, string.concat(_label, ": registered"));
        assertEq(bondId, _bondId, string.concat(_label, ": bond id"));
    }
}
