//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

// import { console2 } from "forge-std/console2.sol";

import { AddressResolver } from "../common/AddressResolver.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { IProverPool } from "./IProverPool.sol";
import { TaikoToken } from "./TaikoToken.sol";
import { Proxied } from "../common/Proxied.sol";

contract ProverPool is EssentialContract, IProverPool {
    // 8 bytes or 1 uint64
    struct Prover {
        uint32 stakedAmount;
        uint16 rewardPerGas;
        uint16 currentCapacity;
    }

    // Make sure we only use one slot
    struct Staker {
        uint64 exitRequestedAt;
        uint32 exitAmount;
        uint16 maxCapacity;
        uint8 proverId; // 0 to indicate the staker is not a top prover
    }

    // Given that we only have 32 slots for the top provers, if the protocol
    // can support 1 block per second with an average proof time of 1 hour,
    // then we need a min capacity of 3600, which means each prover shall
    // provide a capacity of at least 3600/32=112.
    uint32 public constant MAX_CAPACITY_LOWER_BOUND = 128;
    uint64 public constant EXIT_PERIOD = 1 weeks;
    uint64 public constant ONE_TKO = 1e8;
    uint32 public constant SLASH_POINTS = 500; // basis points
    uint32 public constant MIN_STAKE_PER_CAPACITY = 10_000;
    uint256 public constant MAX_NUM_PROVERS = 32;

    // reserve more slots than necessary
    uint256[10_000] private proverData;
    mapping(uint256 id => address prover) public idToProver;
    mapping(address staker => Staker) public stakers;

    uint256[48] private __gap;

    event Withdrawn(address indexed addr, uint32 amount);
    event Exited(address indexed addr, uint32 amount);
    event Slashed(address indexed addr, uint32 amount);
    event Staked(
        address indexed addr,
        uint32 amount,
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
        (uint256[MAX_NUM_PROVERS] memory weights, uint256 totalWeight) =
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
        uint32 slashableAmount = staker.exitRequestedAt > 0
            && block.timestamp <= staker.exitRequestedAt + EXIT_PERIOD
            ? prover.stakedAmount + staker.exitAmount
            : prover.stakedAmount;

        uint32 amountToSlash;

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

            uint32 _additional = amountToSlash - staker.exitAmount;
            if (prover.stakedAmount > _additional) {
                prover.stakedAmount -= _additional;
            } else {
                prover.stakedAmount = 0;
            }
            _saveProver(staker.proverId, prover);
        }

        emit Slashed(addr, amountToSlash);
    }

    function stake(
        uint32 amount,
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

    function getProvers()
        public
        view
        returns (Prover[] memory _provers, address[] memory _stakers)
    {
        _provers = new Prover[](MAX_NUM_PROVERS);
        _stakers = new address[](MAX_NUM_PROVERS);
        for (uint256 i; i < MAX_NUM_PROVERS; ++i) {
            _provers[i] = _loadProver(i + 1);
            _stakers[i] = idToProver[i + 1];
        }
    }
    //Returns each prover's weight dynamically based on feePerGas.

    function getWeights(uint32 feePerGas)
        public
        view
        returns (uint256[MAX_NUM_PROVERS] memory weights, uint256 totalWeight)
    {
        for (uint8 i; i < MAX_NUM_PROVERS; ++i) {
            Prover memory prover = _loadProver(i + 1);
            weights[i] = _calcWeight(prover, feePerGas);
            totalWeight += weights[i];
        }
    }

    function _stake(
        address addr,
        uint32 amount,
        uint16 rewardPerGas,
        uint16 maxCapacity
    )
        private
    {
        // Check parameters
        if (
            maxCapacity < MAX_CAPACITY_LOWER_BOUND
                || amount * ONE_TKO / maxCapacity < MIN_STAKE_PER_CAPACITY
                || rewardPerGas == 0
        ) revert INVALID_PARAMS();

        // Reuse tokens that are exiting
        Staker storage staker = stakers[addr];
        if (staker.exitAmount >= amount) {
            staker.exitAmount -= amount;
        } else {
            uint64 burnAmount = (amount - staker.exitAmount) * ONE_TKO;
            TaikoToken(resolve("taiko_token", false)).burn(addr, burnAmount);
            staker.exitAmount = 0;
        }

        staker.exitRequestedAt =
            staker.exitAmount == 0 ? 0 : uint64(block.timestamp);

        staker.maxCapacity = maxCapacity;

        // Prepare a list 33 provers for comparison
        Prover[MAX_NUM_PROVERS + 1] memory provers;
        provers[0] = Prover(amount, rewardPerGas, maxCapacity);

        for (uint8 i; i < MAX_NUM_PROVERS; ++i) {
            provers[i + 1] = _loadProver(i + 1);
        }

        // Find the prover id
        uint8 proverId;
        for (uint8 i = 1; i < MAX_NUM_PROVERS + 1; ++i) {
            if (provers[proverId].stakedAmount > provers[i].stakedAmount) {
                proverId = i;
            }
        }

        if (proverId == 0) {
            revert PROVER_NOT_GOOD_ENOUGH();
        }

        // Force the replaced prover to exit
        address replaced = idToProver[proverId];
        // if (replaced != address(0)) {
        _withdraw(replaced);
        _exit(replaced);
        // }
        idToProver[proverId] = addr;

        // Assign the staker this proverId
        staker.proverId = proverId;

        // Insert the prover in the top prover list
        _saveProver(
            proverId,
            Prover({
                stakedAmount: amount,
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

        Prover memory prover = _loadProver(staker.proverId);
        if (prover.stakedAmount > 0) {
            staker.exitAmount += prover.stakedAmount;
            staker.exitRequestedAt = uint64(block.timestamp);
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
            addr, staker.exitAmount * ONE_TKO
        );

        emit Withdrawn(addr, staker.exitAmount);
        staker.exitRequestedAt = 0;
        staker.exitAmount = 0;
        return true;
    }

    // Returns the prover's dynamic weight based on the current feePerGas
    function _calcWeight(
        Prover memory prover,
        uint32 feePerGas
    )
        private
        pure
        returns (uint256)
    {
        if (
            prover.currentCapacity == 0 || prover.stakedAmount == 0
                || prover.rewardPerGas == 0
        ) {
            return 0;
        } else {
            return (uint256(prover.stakedAmount) * feePerGas * feePerGas)
                / prover.rewardPerGas / prover.rewardPerGas;
        }
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

        prover.stakedAmount = uint32(data >> 32);
        prover.rewardPerGas = uint16(uint32(data) >> 16);
        prover.currentCapacity = uint16(data);
    }

    function _saveProver(uint256 proverId, Prover memory prover) private {
        assert(proverId > 0 && proverId <= MAX_NUM_PROVERS);

        uint256 data = uint256(prover.stakedAmount) << 32
            | uint256(prover.rewardPerGas) << 16 //
            | uint256(prover.currentCapacity);

        uint256 idx = proverId - 1;
        uint256 slot = idx / 4;
        uint256 offset = (idx % 4) * 64;

        proverData[slot] &= ~(uint256(type(uint64).max) << offset);
        proverData[slot] |= data << offset;
    }
}

contract ProxiedProverPool is Proxied, ProverPool { }
