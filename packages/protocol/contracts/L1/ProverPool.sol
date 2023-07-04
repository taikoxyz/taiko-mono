//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/

pragma solidity ^0.8.20;

import { AddressResolver } from "../common/AddressResolver.sol";
import { EssentialContract } from "../common/EssentialContract.sol";
import { IProverPool } from "./IProverPool.sol";
import { LibMath } from "../libs/LibMath.sol";
import { TaikoToken } from "./TaikoToken.sol";
import { Proxied } from "../common/Proxied.sol";

contract ProverPool is EssentialContract, IProverPool {
    using LibMath for uint256;

    struct Prover {
        uint64 stakedAmount;
        uint32 rewardPerGas;
        uint32 currentCapacity;
    }

    // Make sure we only use one slot
    struct Staker {
        uint64 exitRequestedAt;
        uint64 exitAmount;
        uint32 maxCapacity;
        uint32 proverId; // 0 to indicate the staker is not a top prover
    }

    // Given that we only have 32 slots for the top provers, if the protocol
    // can support 1 block per second with an average proof time of 1 hour,
    // then we need a min capacity of 3600, which means each prover shall
    // provide a capacity of at least 3600/32=112.
    uint32 public constant MAX_CAPACITY_LOWER_BOUND = 128;
    uint64 public constant EXIT_PERIOD = 1 weeks;
    uint32 public constant SLASH_POINTS = 25; // basis points or 0.25%
    uint64 public constant MIN_STAKE_PER_CAPACITY = 10_000;
    uint64 public constant MIN_SLASH_AMOUNT = 1e8; // 1 token
    uint256 public constant MAX_NUM_PROVERS = 32;
    uint256 public constant MIN_CHANGE_DELAY = 1 hours;

    // Reserve more slots than necessary
    Prover[1024] public provers; // provers[0] is never used
    mapping(uint256 id => address prover) public idToProver;
    // Save the weights only when: stake / unstaked / slashed
    mapping(address staker => Staker) public stakers;

    uint256[47] private __gap;

    event Withdrawn(address indexed addr, uint64 amount);
    event Exited(address indexed addr, uint64 amount);
    event Slashed(address indexed addr, uint64 amount);
    event Staked(
        address indexed addr,
        uint64 amount,
        uint32 rewardPerGas,
        uint32 currentCapacity
    );

    error CHANGE_TOO_FREQUENT();
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
        unchecked {
            uint32[MAX_NUM_PROVERS] memory effectiveRewardPerGas;
            uint256[MAX_NUM_PROVERS] memory weights;
            uint256 totalWeight;
            Prover memory _prover;

            for (uint32 i; i < MAX_NUM_PROVERS; ++i) {
                _prover = provers[i + 1];
                if (_prover.currentCapacity != 0) {
                    // Keep the effective rewardPerGas in [75-125%] of feePerGas
                    if (_prover.rewardPerGas > feePerGas * 125 / 100) {
                        effectiveRewardPerGas[i] = feePerGas * 125 / 100;
                    } else if (_prover.rewardPerGas < feePerGas * 75 / 100) {
                        effectiveRewardPerGas[i] = feePerGas * 75 / 100;
                    } else {
                        effectiveRewardPerGas[i] = _prover.rewardPerGas;
                    }
                    weights[i] = _calcWeight(
                        _prover.stakedAmount, effectiveRewardPerGas[i]
                    );
                    totalWeight += weights[i];
                }
            }

            if (totalWeight == 0) {
                return (address(0), 0);
            }

            // Pick a prover using a pseudo random number
            bytes32 rand =
                keccak256(abi.encode(blockhash(block.number - 1), blockId));
            uint256 r = uint256(rand) % totalWeight + 1;
            uint256 z;
            uint32 id;

            while (z < r && id < MAX_NUM_PROVERS) {
                z += weights[id++];
            }
            assert(id > 0);
            provers[id].currentCapacity -= 1;

            // Note that prover ID is 1 bigger than its index
            return (idToProver[id], effectiveRewardPerGas[id - 1]);
        }
    }

    // Increases the capacity of the prover
    function releaseProver(address addr) external onlyFromProtocol {
        (Staker memory staker, Prover memory prover) = getStaker(addr);

        if (staker.proverId != 0 && prover.currentCapacity < staker.maxCapacity)
        {
            unchecked {
                provers[staker.proverId].currentCapacity += 1;
            }
        }
    }

    // Slashes a prover
    function slashProver(address addr) external onlyFromProtocol {
        (Staker memory staker, Prover memory prover) = getStaker(addr);

        // if the exit is mature, we do not count it in the total slash-able
        // amount
        uint256 slashableAmount = staker.exitRequestedAt > 0
            && block.timestamp <= staker.exitRequestedAt + EXIT_PERIOD
            ? prover.stakedAmount + staker.exitAmount
            : prover.stakedAmount;

        if (slashableAmount == 0) return;

        unchecked {
            uint64 amountToSlash = uint64(
                (slashableAmount * SLASH_POINTS / 10_000).max(MIN_SLASH_AMOUNT)
                    .min(slashableAmount)
            );

            if (amountToSlash <= staker.exitAmount) {
                stakers[addr].exitAmount -= amountToSlash;
            } else {
                stakers[addr].exitAmount = 0;

                uint64 _additional = amountToSlash - staker.exitAmount;

                if (prover.stakedAmount > _additional) {
                    provers[staker.proverId].stakedAmount -= _additional;
                } else {
                    provers[staker.proverId].stakedAmount = 0;
                }
            }
            emit Slashed(addr, amountToSlash);
        }
    }

    function stake(
        uint64 amount,
        uint32 rewardPerGas,
        uint32 maxCapacity
    )
        external
        nonReentrant
    {
        // Withdraw first
        _withdraw(msg.sender);
        // Force this prover to fully exit
        _exit(msg.sender, true);
        // Then stake again
        if (amount != 0) {
            _stake(msg.sender, amount, rewardPerGas, maxCapacity);
        } else if (rewardPerGas != 0 || maxCapacity != 0) {
            revert INVALID_PARAMS();
        }
    }

    function exit() external nonReentrant {
        _withdraw(msg.sender);
        _exit(msg.sender, true);
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
                prover = provers[staker.proverId];
            }
        }
    }

    // Returns the pool's current total capacity
    function getCapacity() public view returns (uint256 capacity) {
        unchecked {
            for (uint256 i = 1; i <= MAX_NUM_PROVERS; ++i) {
                capacity += provers[i].currentCapacity;
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
            _provers[i] = provers[i + 1];
            _stakers[i] = idToProver[i + 1];
        }
    }

    function _stake(
        address addr,
        uint64 amount,
        uint32 rewardPerGas,
        uint32 maxCapacity
    )
        private
    {
        // Check parameters
        if (
            maxCapacity < MAX_CAPACITY_LOWER_BOUND
                || amount / maxCapacity < MIN_STAKE_PER_CAPACITY
                || rewardPerGas == 0
        ) revert INVALID_PARAMS();

        // Reuse tokens that are exiting
        Staker storage staker = stakers[addr];

        unchecked {
            if (staker.exitAmount >= amount) {
                staker.exitAmount -= amount;
            } else {
                uint64 burnAmount = (amount - staker.exitAmount);
                TaikoToken(resolve("taiko_token", false)).burn(addr, burnAmount);
                staker.exitAmount = 0;
            }
        }

        staker.exitRequestedAt =
            staker.exitAmount == 0 ? 0 : uint64(block.timestamp);

        staker.maxCapacity = maxCapacity;

        // Find the prover id
        uint32 proverId = 1;
        for (uint32 i = 2; i <= MAX_NUM_PROVERS;) {
            if (provers[proverId].stakedAmount > provers[i].stakedAmount) {
                proverId = i;
            }
            unchecked {
                ++i;
            }
        }

        if (provers[proverId].stakedAmount >= amount) {
            revert PROVER_NOT_GOOD_ENOUGH();
        }

        // Force the replaced prover to exit
        address replaced = idToProver[proverId];
        if (replaced != address(0)) {
            _withdraw(replaced);
            _exit(replaced, false);
        }
        idToProver[proverId] = addr;
        staker.proverId = proverId;

        // Insert the prover in the top prover list
        provers[proverId] = Prover({
            stakedAmount: amount,
            rewardPerGas: rewardPerGas,
            currentCapacity: maxCapacity
        });

        emit Staked(addr, amount, rewardPerGas, maxCapacity);
    }

    // Perform a full exit for the given address
    function _exit(address addr, bool checkExitTimestamp) private {
        Staker storage staker = stakers[addr];
        if (staker.proverId == 0) return;

        Prover memory prover = provers[staker.proverId];
        if (prover.stakedAmount > 0) {
            if (
                checkExitTimestamp
                    && block.timestamp <= staker.exitRequestedAt + MIN_CHANGE_DELAY
            ) {
                revert CHANGE_TOO_FREQUENT();
            }

            staker.exitAmount += prover.stakedAmount;
            staker.exitRequestedAt = uint64(block.timestamp);
            staker.proverId = 0;
        }

        // Delete the prover but make it non-zero for cheaper rewrites
        // by keep rewardPerGas = 1
        provers[staker.proverId] = Prover(0, 1, 0);

        delete idToProver[staker.proverId];

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

    // Calculates the user weight's when it stakes/unstakes/slashed
    function _calcWeight(
        uint64 stakedAmount,
        uint32 rewardPerGas
    )
        private
        pure
        returns (uint64 weight)
    {
        assert(rewardPerGas > 0);
        unchecked {
            weight = stakedAmount / rewardPerGas / rewardPerGas;
            if (weight == 0) {
                weight = 1;
            }
        }
    }
}

contract ProxiedProverPool is Proxied, ProverPool { }
