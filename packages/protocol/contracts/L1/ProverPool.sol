//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../common/AddressResolver.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { IProverPool } from "./IProverPool.sol";
import { TaikoToken } from "./TaikoToken.sol";
import { Proxied } from "../common/Proxied.sol";

contract ProverPool is EssentialContract, IProverPool {
    // 1 uint64
    struct Prover {
        uint32 weight;
        uint16 rewardPerGas;
        uint16 currentCapacity;
    }

    // Make sure we only use 1 slot
    struct Staker {
        uint64 exitRequestedAt;
        uint64 exitAmount;
        uint64 stakedAmount;
        uint16 maxCapacity;
        uint8 proverId; // 0 to indicate the staker is not a top prover
    }

    struct ProverInfo {
        address addr;
        Prover prover;
        Staker staker;
    }

    // Given that we only have 32 slots for the top provers, if the protocol
    // can support 1 block per second with an average proof time of 1 hour,
    // then we need a min capacity of 3600, which means each prover shall
    // provide a capacity of at least 3600/32=112.
    uint32 public constant MAX_CAPACITY_LOWER_BOUND = 128;
    uint64 public constant EXIT_PERIOD = 1 weeks;
    uint32 public constant SLASH_POINTS = 500; // basis points
    uint64 public constant MIN_STAKE_PER_CAPACITY = 100 * 1e8; // 100 Taiko
        // token
    uint256 public constant MAX_NUM_PROVERS = 32;

    // reserve more slots than necessary
    uint256[10_000] private proverData;
    mapping(uint256 id => address prover) public idToProver;
    // Save the weights only when: stake / unstaked / slashed
    mapping(address staker => Staker) public stakers;

    uint256[48] private __gap;

    event Withdrawn(address indexed addr, uint64 amount);
    event Exited(address indexed addr, uint64 amount);
    event Slashed(address indexed addr, uint64 amount);

    event Staked(
        address indexed addr,
        uint64 amount,
        uint16 rewardPerGas,
        uint16 currentCapacity
    );

    error INVALID_PARAMS();
    error NO_MATURE_EXIT();
    error PROVER_NOT_GOOD_ENOUGH();
    error UNAUTHORIZED();

    modifier onlyFromProtocol() {
        if (resolve("taiko", false) != msg.sender) {
            revert UNAUTHORIZED();
        }
        _;
    }

    function init(address _addressManager) external initializer {
        EssentialContract._init(_addressManager);
    }

    function assignProver(
        uint64 blockId,
        uint32 feePerGas
    )
        external
        onlyFromProtocol
        returns (address prover, uint32 rewardPerGas)
    {
        (uint32[MAX_NUM_PROVERS] memory weights, uint256 totalWeight) =
            getWeights(feePerGas);

        if (totalWeight == 0) {
            return (address(0), 0);
        }

        // Pick a prover using a pseudo random number
        bytes32 rand =
            keccak256(abi.encode(blockhash(block.number - 1), blockId));
        uint256 r = uint256(rand) % totalWeight + 1;
        uint256 z;
        uint8 id;
        unchecked {
            while (z < r && id < MAX_NUM_PROVERS) {
                z += weights[id++];
            }
            Prover memory _prover = _loadProver(id);
            _prover.currentCapacity -= 1;
            _saveProver(id, _prover);

            // Note that prover ID is 1 bigger than its index
            return (idToProver[id], _prover.rewardPerGas);
        }
    }

    // Increases the capacity of the prover
    function releaseProver(address addr) external onlyFromProtocol {
        (Staker memory staker, Prover memory prover) = getStaker(addr);

        if (staker.proverId != 0 && prover.currentCapacity < staker.maxCapacity)
        {
            unchecked {
                prover.currentCapacity += 1;
                _saveProver(staker.proverId, prover);
            }
        }
    }

    // Slashes a prover
    function slashProver(address addr) external onlyFromProtocol {
        (Staker memory staker, Prover memory prover) = getStaker(addr);

        // if the exit is mature, we do not count it in the total slash-able
        // amount
        uint64 slashableAmount = staker.exitRequestedAt > 0
            && block.timestamp <= staker.exitRequestedAt + EXIT_PERIOD
            ? staker.stakedAmount + staker.exitAmount
            : staker.stakedAmount;

        uint64 amountToSlash;

        if (slashableAmount > 0) {
            amountToSlash = slashableAmount * SLASH_POINTS / 10_000;
            // make sure we can slash even if  totalAmount is as small as 1
            if (amountToSlash == 0) amountToSlash = 1;
        }

        if (amountToSlash == 0) {
            // do nothing
        } else if (amountToSlash <= staker.exitAmount) {
            stakers[addr].exitAmount -= amountToSlash;
        } else {
            stakers[addr].exitAmount = 0;

            uint64 _additional = amountToSlash - staker.exitAmount;
            if (staker.stakedAmount > _additional) {
                stakers[addr].stakedAmount -= _additional;
            } else {
                stakers[addr].stakedAmount = 0;
            }

            prover.weight = _calcWeight(
                staker.maxCapacity,
                stakers[addr].stakedAmount,
                prover.rewardPerGas
            );

            _saveProver(staker.proverId, prover);
        }

        emit Slashed(addr, amountToSlash);
    }

    function stake(
        uint64 amount,
        uint16 rewardPerGas,
        uint16 maxCapacity
    )
        external
        nonReentrant
    {
        // Withdraw first
        _withdraw(msg.sender);
        // Force this prover to fully exit
        _exit(msg.sender);
        // Then stake again
        if (amount == 0) {
            if (rewardPerGas != 0 || maxCapacity != 0) {
                revert INVALID_PARAMS();
            }
        } else {
            _stake(msg.sender, amount, rewardPerGas, maxCapacity);
        }
    }

    function exit() external nonReentrant {
        _withdraw(msg.sender);
        _exit(msg.sender);
    }

    // Withdraws staked tokens back from matured an exit
    function withdraw() external nonReentrant {
        if (!_withdraw(msg.sender)) revert NO_MATURE_EXIT();
    }

    // Returns a staker's information
    function getStaker(address addr)
        public
        view
        returns (Staker memory staker, Prover memory prover)
    {
        staker = stakers[addr];
        if (staker.proverId != 0) {
            unchecked {
                prover = _loadProver(staker.proverId);
            }
        }
    }

    // Returns the pool's current total capacity
    function getCapacity() public view returns (uint256 capacity) {
        unchecked {
            for (uint256 i; i < MAX_NUM_PROVERS;) {
                capacity += _loadProver(i + 1).currentCapacity;
                ++i;
            }
        }
    }

    function getProvers() public view returns (ProverInfo[] memory _provers) {
        _provers = new ProverInfo[](MAX_NUM_PROVERS);
        for (uint256 i; i < MAX_NUM_PROVERS; ++i) {
            address addr = idToProver[i + 1];
            _provers[i].addr = addr;
            _provers[i].prover = _loadProver(i + 1);
            _provers[i].staker = stakers[addr];
        }
    }

    //Returns each prover's weight dynamically based on feePerGas.
    function getWeights(uint32 /*feePerGas*/ )
        public
        view
        returns (uint32[MAX_NUM_PROVERS] memory weights, uint256 totalWeight)
    {
        for (uint8 i; i < MAX_NUM_PROVERS; ++i) {
            Prover memory prover = _loadProver(i + 1);
            weights[i] = prover.currentCapacity == 0 ? 0 : prover.weight;
            totalWeight += weights[i];
        }
    }

    function _stake(
        address addr,
        uint64 amount,
        uint16 rewardPerGas,
        uint16 maxCapacity
    )
        private
    {
        // Check parameters
        if (
            maxCapacity < MAX_CAPACITY_LOWER_BOUND
                || amount / maxCapacity < MIN_STAKE_PER_CAPACITY
                || rewardPerGas == 0
        ) revert INVALID_PARAMS();

        // Find the smallest prover's id
        uint8 proverId = 1;
        for (uint8 i = 2; i <= MAX_NUM_PROVERS; ++i) {
            if (
                stakers[idToProver[proverId]].stakedAmount
                    > stakers[idToProver[i]].stakedAmount
            ) {
                proverId = i;
            }
        }

        if (stakers[idToProver[proverId]].stakedAmount >= amount) {
            revert PROVER_NOT_GOOD_ENOUGH();
        }

        // Reuse tokens that are exiting
        Staker storage staker = stakers[addr];

        if (staker.exitAmount >= amount) {
            staker.exitAmount -= amount;
        } else {
            uint64 burnAmount = amount - staker.exitAmount;
            TaikoToken(resolve("taiko_token", false)).burn(addr, burnAmount);
            staker.exitAmount = 0;
        }

        staker.exitRequestedAt =
            staker.exitAmount == 0 ? 0 : uint64(block.timestamp);

        staker.stakedAmount = amount;
        staker.maxCapacity = maxCapacity;
        staker.proverId = proverId;

        // Force the replaced prover to exit
        address replaced = idToProver[proverId];
        if (replaced != address(0)) {
            // replaced can actually be address(0)
            _withdraw(replaced);
            _exit(replaced);
        }

        idToProver[proverId] = addr;

        // Insert the prover in the top prover list
        _saveProver(
            proverId,
            Prover({
                weight: _calcWeight(maxCapacity, amount, rewardPerGas),
                rewardPerGas: rewardPerGas,
                currentCapacity: maxCapacity
            })
        );

        emit Staked(addr, amount, rewardPerGas, maxCapacity);
    }

    // Perform a full exit for the given address
    function _exit(address addr) private {
        Staker storage staker = stakers[addr];
        if (staker.proverId == 0) return;

        delete idToProver[staker.proverId];

        // Delete the prover but make it non-zero for cheaper rewrites
        // by keep rewardPerGas = 1
        _saveProver(staker.proverId, Prover(0, 1, 0));

        if (staker.stakedAmount > 0) {
            staker.exitRequestedAt = uint64(block.timestamp);
            staker.exitAmount += staker.stakedAmount;
            staker.stakedAmount = 0;
            staker.proverId = 0;
        }

        emit Exited(addr, staker.exitAmount);
    }

    function _withdraw(address addr) private returns (bool success) {
        Staker storage staker = stakers[addr];
        if (
            staker.exitAmount == 0 || staker.exitRequestedAt == 0
                || block.timestamp <= staker.exitRequestedAt + EXIT_PERIOD
        ) {
            return false;
        }

        TaikoToken(AddressResolver(this).resolve("taiko_token", false)).mint(
            addr, staker.exitAmount
        );

        emit Withdrawn(addr, staker.exitAmount);
        staker.exitRequestedAt = 0;
        staker.exitAmount = 0;
        return true;
    }

    function _saveProver(uint256 proverId, Prover memory prover) private {
        assert(proverId > 0 && proverId <= MAX_NUM_PROVERS);

        uint256 data = uint256(prover.weight) << 32
            | uint256(prover.rewardPerGas) << 16 //
            | uint256(prover.currentCapacity);

        uint256 idx = proverId - 1;
        uint256 slot = idx / 4;
        uint256 offset = (idx % 4) * 64;

        proverData[slot] &= ~(uint256(type(uint64).max) << offset);
        proverData[slot] |= data << offset;
    }

    function _loadProver(uint256 proverId)
        private
        view
        returns (Prover memory prover)
    {
        assert(proverId > 0 && proverId <= MAX_NUM_PROVERS);

        uint256 idx = proverId - 1;
        uint256 slot = idx / 4;
        uint256 offset = (idx % 4) * 64;
        uint64 data = uint64(proverData[slot] >> offset);

        prover.weight = uint32(data >> 32);
        prover.rewardPerGas = uint16(uint32(data) >> 16);
        prover.currentCapacity = uint16(data);
    }

    // Calculates the user weight's when it stakes/unstakes/slashed
    function _calcWeight(
        uint16 currentCapacity,
        uint64 stakedAmount,
        uint16 rewardPerGas
    )
        private
        pure
        returns (uint32)
    {
        if (currentCapacity == 0 || stakedAmount == 0 || rewardPerGas == 0) {
            return 0;
        } else {
            return uint32(stakedAmount / rewardPerGas);
        }
    }
}

contract ProxiedProverPool is Proxied, ProverPool { }
